# ASCII Art Image Rendering (`img-ascii`)

**Status:** Draft  
**Branch:** `feature/img-ascii`

---

## 1. Motivation

Chawan currently supports inline image display via two terminal graphics
protocols: **DEC Sixel** and **Kitty graphics protocol**. These work well on
capable terminals, but many common terminal emulators (e.g. macOS Terminal,
iTerm2 without sixel, screen/tmux without graphics passthrough, legacy
terminals, SSH sessions to remote hosts) cannot display them at all.

When `display.image-mode` is set to `"none"` or when no graphics protocol is
detected, images are completely invisible — the user sees blank space where
images should be. This is a poor experience for a web browser.

This feature adds a third image display mode: **`"ascii"`**. It converts
decoded RGBA image data into colored Unicode block characters, producing a
text-based approximation of the image directly in the terminal's text layer.
This works on **any** terminal emulator, including those with no graphics
support whatsoever.

---

## 2. How Images Currently Work in Chawan

Understanding the full image pipeline is essential before designing this
feature. Here is a comprehensive description of the existing architecture.

### 2.1 Image Lifecycle

The image pipeline has six stages:

```
Fetch → Decode (info) → Decode (full RGBA) → Resize → Encode → Display
```

Each stage is a separate CGI process communicating via the loader.

### 2.2 Stage 1: Fetch

When the HTML parser encounters an `<img>` element (or an inline SVG), it
calls `loadImage` (`src/html/dom.nim`). The browser's fetch API downloads the
image data through the loader process. The response body is saved to a
**cache file** on disk.

Key types:
- `NetworkBitmap` (`src/types/bitmap.nim`): metadata object — `width`,
  `height`, `cacheId`, `imageId`, `vector`, `contentType`. Does **not**
  contain pixel data itself.
- `HTMLImageElement.bitmap` (`src/html/dom.nim`): points to a `NetworkBitmap`
  once the image's dimensions are known.

### 2.3 Stage 2: Decode (info-only)

After fetching, a request is sent to `img-codec+{type}:decode` with the header
`Cha-Image-Info-Only: 1`. The decoder CGI reads just enough to determine the
image dimensions, outputs `Cha-Image-Dimensions: {w}x{h}`, and discards the
rest.

Decoders are mapped in `res/urimethodmap`:
- `img-codec+png/jpeg/gif/bmp/x-unknown` → `cgi-bin:stbi` (adapter/img/stbi.nim)
- `img-codec+webp` → `cgi-bin:jebp` (adapter/img/jebp.nim)
- `img-codec+svg+xml` → `cgi-bin:nanosvg` (adapter/img/nanosvg.nim)
- `img-codec+x-cha-canvas` → `cgi-bin:canvas` (adapter/img/canvas.nim)

### 2.4 Stage 3: Display Path — Buffer → Pager → Terminal

#### In the Buffer Process

The CSS layout engine positions images in `renderImage()` (`src/css/render.nim`).
It creates a `PosBitmap` (positioned bitmap) with cell-level `x`, `y` coordinates
and pixel-level `offx`, `offy`, `width`, `height`, plus a reference to the
`NetworkBitmap`.

The buffer sends `PosBitmap` objects to the pager as part of the line data
(`getLinesCmd`, `src/server/buffer.nim`), filtered to only include images
visible in the requested slice.

#### In the Pager (Main Process)

`initImages()` (`src/local/pager.nim`) processes the `PosBitmap` list:

1. For each image, calculate `CanvasImageDimensions` via
   `term.positionImage()` — this maps pixel coordinates to cell coordinates
   and determines cropping offsets.
2. Try to reuse an existing `CanvasImage` from the terminal's frame (e.g. if
   the user scrolled, the image may already be on screen).
3. If not found in the terminal, look up the pager's `CachedImage` cache.
4. If not cached, start the **full decode → resize → encode** pipeline:
   - `loadCachedImage()` → `loadCachedImage0()` → fetches raw RGBA from
     cache via `img-codec+{type}:decode` (full decode this time)
   - If image needs resizing → calls `cgi-bin:resize` (adapter/img/resize.nim)
   - Then encodes to the display format:
     - **Sixel**: calls `img-codec+x-sixel:encode` (adapter/img/sixel.nim)
     - **Kitty**: calls `img-codec+png:encode` (adapter/img/stbi.nim)
   - The encoded result is mmapped into a `Blob` and stored in `CachedImage`.

#### In the Terminal (`src/local/term.nim`)

`CanvasImage` objects are managed in a linked list per frame. The terminal
handles:
- **Damage tracking**: which images need to be redrawn after scroll/resize
- **Z-order overlap detection**: opaque images covering others are removed
- **Sixel cropping**: vertical cropping in ~O(1) using a lookup table appended
  to the sixel data ("halfdump" mode)
- **Output**: `outputSixelImage()` emits DCS escape sequences;
  `outputKittyImage()` emits APC escape sequences with base64-encoded PNG data

### 2.5 ImageMode Detection

The `ImageMode` enum (`src/config/conftypes.nim`):
```nim
ImageMode = enum
  imNone = "none"
  imSixel = "sixel"
  imKitty = "kitty"
```

Auto-detection in `src/local/term.nim`:
- If terminal responds to DA1 (`\e[?4c`) with parameter 4, Sixel is assumed.
- If terminal type is `xterm-kitty`, Kitty mode is used.
- Zellij is explicitly blacklisted.
- User can override via `display.image-mode` config.

### 2.6 Color System

Relevant types from `src/types/color.nim`:
- `ARGBColor`: machine-endian 32-bit color with alpha
- `RGBAColorBE`: machine-independent big-endian RGBA (4 bytes, packed)
- `CellColor`: terminal cell color — either `ctNone` (default), `ctANSI`
  (0–255), or `ctRGB` (true 24-bit color)
- `Format`: packed 64-bit value containing `bgcolor` (26-bit `CellColor`),
  `fgcolor` (26-bit `CellColor`), and `FormatMode` flags (bold, italic, etc.)

The render pipeline writes `FlexibleGrid` (array of `FlexibleLine` = string +
`FormatCell` sequence) which the pager paints using SGR escape sequences for
color and style.

---

## 3. Design

### 3.1 Overview

The ASCII mode inserts itself as an alternative to Sixel/Kitty in the
**pager-side encoding pipeline**. Instead of encoding RGBA data to a terminal
graphics protocol, it converts RGBA pixels into colored text (Unicode block
elements) that becomes part of the normal text layer.

```
RGBA data (from decode/resize)
    │
    ├─[sixel mode]──→ img-codec+x-sixel:encode → Sixel escape seqs
    ├─[kitty mode]──→ img-codec+png:encode     → Kitty APC seqs
    └─[ascii mode]──→ img-codec+x-ascii:encode → colored text lines
                      (adapter/img/ascii.nim)
```

### 3.2 New ImageMode: `imAscii`

Add a new member to the `ImageMode` enum:

```nim
ImageMode = enum
  imNone = "none"
  imSixel = "sixel"
  imKitty = "kitty"
  imAscii = "ascii"
```

Config value: `display.image-mode = "ascii"` or `display.image-mode = "auto"`
(with auto-detection falling back to ascii when neither sixel nor kitty is
available).

### 3.3 ASCII Encoder: `adapter/img/ascii.nim`

A new CGI program `cgi-bin:ascii` that:

**Input** (via stdin, as RGBA pixel data):
- `Cha-Image-Dimensions: {w}x{h}` — source image dimensions
- `Cha-Image-Target-Dimensions: {tw}x{th}` — target cell grid size (optional,
  defaults to image dimensions scaled to terminal cell aspect ratio)
- `Cha-Image-Quality: {1..100}` — controls dithering/detail level (optional)
- Raw RGBA data (big-endian, 4 bytes per pixel)

**Output** (via stdout):
- `Cha-Image-Ascii-Lines: {n}` — number of output lines
- `Cha-Image-Ascii-Width: {w}` — character width of each line
- Empty line (CGI header terminator)
- Text data: one line of colored text per row of cells

The text output format encodes both the character content and per-cell colors
using a simple binary protocol compatible with Chawan's `FlexibleGrid`:

```
For each line:
  - uint16: byte length of the string
  - string bytes (UTF-8)
  - uint16: number of format cells
  For each format cell:
    - uint16: position (in character width units)
    - uint64: Format (packed bgcolor + fgcolor + flags)
```

This reuses the `SimpleFlexibleLine` / `SimpleFlexibleGrid` serialization that
the buffer already uses for line data (`src/server/bufferiface.nim`), so the
pager can parse it with existing deserialization code.

#### 3.3.1 Character Set

Unicode block elements provide 2×2 sub-pixel resolution per terminal cell:

| Character | Codepoint | Pixels Set |
|-----------|-----------|------------|
| ` ` (space) | U+0020 | none (transparent/background) |
| `▘` | U+2598 | top-left |
| `▝` | U+259D | top-right |
| `▀` | U+2580 | top-left + top-right |
| `▖` | U+2596 | bottom-left |
| `▌` | U+258C | top-left + bottom-left |
| `▞` | U+259E | top-left + bottom-right |
| `▛` | U+259B | top-left + top-right + bottom-left |
| `▗` | U+2597 | bottom-right |
| `▚` | U+259A | top-left + bottom-right |
| `▜` | U+259C | top-left + top-right + bottom-right |
| `▄` | U+2584 | bottom-left + bottom-right |
| `▙` | U+2599 | top-left + bottom-left + bottom-right |
| `▟` | U+259F | top-right + bottom-left + bottom-right |
| `█` | U+2588 | all four pixels |

This gives 16 levels per cell (4 sub-pixels × 2 states), which combined with
per-cell foreground color produces a reasonable approximation.

#### 3.3.2 Color Quantization

Two strategies, selectable via quality parameter:

**Low quality (1–30): No color — use the "braille art" approach with a single
foreground color:**
- Sample the 2×2 pixel block's average luminance.
- Map to one of the 16 block characters above.
- Use a fixed foreground color (e.g. default/white) on default background.
- Result: purely monochrome ASCII art, works even on 8-color terminals.

**Medium quality (31–70): ANSI 256-color quantization:**
- For each cell, compute the average RGB of the 2×2 pixel block.
- Map to the nearest 256-color ANSI color using `toEightBit()` from
  `src/types/color.nim` (already implemented).
- Use that as the foreground color; background stays default.

**High quality (71–100): Full RGB (truecolor) per cell:**
- For each cell, compute average RGB of the 2×2 pixel block.
- Use `cellColor(ctRGB, ...)` as the foreground color.
- Terminals supporting truecolor will show accurate colors; others will
  fall back to nearest ANSI color automatically.

#### 3.3.3 Scaling

The encoder must scale the source image to the target cell grid. Each cell
represents a `ppc × ppl` (pixels-per-cell × pixels-per-line) area. Typical
values: ppc=8–12, ppl=16–24.

Two approaches:
1. **Nearest-neighbor** (fastest): each 2×2 sub-pixel block maps directly to
   the corresponding source pixels (or nearest). Good for pixel art.
2. **Area-average** (better quality): average all source pixels within each
   sub-pixel block's region. Reduces aliasing on photographs.

We use area-average by default (quality ≥ 50), nearest-neighbor for lower
quality.

#### 3.3.4 Transparency Handling

- Fully transparent pixels (alpha = 0): treated as background (space).
- Semi-transparent pixels: alpha-blended against a white background
  (matching the typical browser canvas color).
- The `Cha-Image-Sixel-Transparent` header is not needed since ASCII art has
  no native transparency.

### 3.4 Pager Integration

#### 3.4.1 Modified `loadCachedImage2()`

In `src/local/pager.nim`, the function `loadCachedImage2()` currently picks
the encoder based on `imageMode`:

```nim
case pager.term.imageMode
of imSixel:
  url = parseURL0("img-codec+x-sixel:encode")
  ...
of imKitty:
  url = parseURL0("img-codec+png:encode")
of imNone: assert false
```

Add the ASCII case:

```nim
of imAscii:
  url = parseURL0("img-codec+x-ascii:encode")
  headers.add("Cha-Image-Target-Dimensions",
    $cachedImage.width & 'x' & $cachedImage.height)
```

#### 3.4.2 Text Layer Insertion

Unlike Sixel/Kitty, ASCII art images are part of the text layer. This means
they must be inserted into the `FlexibleGrid` at the correct position, rather
than being rendered as separate escape sequences.

Approach: **replace the image's cell region in the grid with the ASCII art
lines.**

In `src/local/pager.nim`, after receiving the encoded ASCII data, parse it
as `SimpleFlexibleGrid` lines. Then, when painting the buffer's line data,
splice these lines in at the image's y-position, overwriting the cell-width
columns starting at the image's x-position.

This is simpler than the Sixel/Kitty path because:
- No `CanvasImage` management (no linked list, no damage tracking, no Z-order)
- No scroll-related re-encoding
- Images survive terminal scroll naturally (they're just text)
- No need for `term.outputSixelImage()` / `term.outputKittyImage()`

However, it means:
- ASCII images are "painted over" the text layer — overlapping elements may
  not render correctly (acceptable trade-off for a fallback mode)
- Redraw cost is zero (text layer is already redrawn on scroll)

#### 3.4.3 Integration Point

The cleanest integration point is in `initImages()`. For ASCII mode, instead
of creating `CanvasImage` objects and calling `term.addImage()`, we:

1. Load and decode the image as usual (RGBA from cache).
2. Resize if needed (same as Sixel/Kitty path).
3. Send to `img-codec+x-ascii:encode` instead of sixel/png encoder.
4. Store the resulting `SimpleFlexibleGrid` in the `CachedImage` (alongside
   the encoded blob).
5. When painting lines, overlay the ASCII art grid at the image's position.

Alternatively (simpler but less clean): perform the ASCII conversion
entirely in-process in the pager, without a separate CGI process. This avoids
IPC overhead and simplifies the code, since the conversion is purely
computational (no external dependencies needed). Given that the pager already
links against `src/types/color.nim` which provides `toEightBit()`, this is
feasible.

**Recommendation:** Start with an in-process implementation in the pager. If
performance is an issue for large images, move to a CGI process later.

### 3.5 URIMethodMap Entry

Add to `res/urimethodmap`:
```
img-codec+x-ascii:	cgi-bin:ascii
```

And to the Makefile's `protocols_bin` list.

### 3.6 Configuration

New config options:

```toml
[display]
# Existing:
image-mode = "auto"  # "none", "sixel", "kitty", "ascii", "auto"

# New:
ascii-image-quality = 50  # 1..100; controls color depth and detail
```

In "auto" mode, the detection order becomes:
1. Kitty (if `TERM=xterm-kitty`)
2. Sixel (if DA1 reports parameter 4)
3. **ASCII** (always available as fallback)

### 3.7 Standalone Image Viewing

The default mailcap entries (`DefaultMailcap` in `src/local/pager.nim`) wrap
standalone images in HTML via `img2html`. Since `img2html` produces an `<img>`
tag, the ASCII rendering path is automatically used when viewing standalone
images (e.g. `cha photo.jpg`) in ASCII mode. No changes needed here.

---

## 4. Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `adapter/img/ascii.nim` | ASCII art encoder CGI program (if CGI approach) |

### Modified Files

| File | Change |
|------|--------|
| `src/config/conftypes.nim` | Add `imAscii = "ascii"` to `ImageMode` enum |
| `src/local/term.nim` | Handle `imAscii` in image mode auto-detection (always available as fallback); skip `CanvasImage` management for ASCII mode |
| `src/local/pager.nim` | Add ASCII path in `loadCachedImage2()`; overlay ASCII grid in paint loop; add `ascii-image-quality` config option |
| `src/server/buffer.nim` | No changes needed (buffer sends `PosBitmap` regardless of display mode) |
| `src/css/render.nim` | No changes needed |
| `res/urimethodmap` | Add `img-codec+x-ascii: cgi-bin:ascii` entry |
| `Makefile` | Add `ascii` to `protocols_bin` |

---

## 5. Implementation Plan

### Phase 1: Core ASCII Renderer (in-process, pager-side)

1. Add `imAscii` to `ImageMode` enum.
2. Implement ASCII conversion function in pager:
   - Input: `Blob` of RGBA data, width, height, target cell dimensions
   - Output: `SimpleFlexibleGrid` of colored text lines
   - Use Unicode block characters with 2×2 sub-pixel resolution
   - Support 256-color and truecolor output
3. Wire up in `loadCachedImage2()` and `loadCachedImage3()` — instead of
   creating a `CanvasImage`, store the `SimpleFlexibleGrid` in `CachedImage`.
4. Overlay ASCII art in the paint loop (insert lines at image position).
5. Test with `display.image-mode = "ascii"`.

### Phase 2: Auto-Detection & Config

1. Make "auto" mode fall back to ASCII when neither Sixel nor Kitty is
   detected.
2. Add `display.ascii-image-quality` config option.
3. Implement quality levels (mono / 256-color / truecolor).

### Phase 3: Performance & Polish

1. Cache ASCII art grids (avoid re-converting on scroll).
2. Consider moving to CGI process for large images if needed.
3. Handle edge cases: very small images (1×1), very large images,
   non-integer cell aspect ratios, CJK double-width characters in image
   region.
4. Consider optional dithering (Floyd-Steinberg) for monochrome mode.

### Phase 4: Standalone Encoder (optional)

1. Extract ASCII renderer into `adapter/img/ascii.nim` as a CGI program.
2. Add `img-codec+x-ascii` to urimethodmap and Makefile.
3. Update pager to use CGI path when available.

---

## 6. Alternatives Considered

### 6.1 Half-Block Only (▀ and ▄)

Using only `▀` (upper half) and `▄` (lower half) with foreground and
background colors gives 2 sub-pixel rows per cell. This is simpler but
produces noticeably lower quality than the 2×2 block element approach. We
use the full 16-character set.

### 6.2 Braille Characters (U+2800–U+28FF)

Braille patterns provide 2×4 = 8 sub-pixels per cell (higher resolution).
However:
- Many terminals render Braille characters with inconsistent widths
  (especially with CJK/double-width font issues).
- The dot positions don't align to a clean grid in many fonts.
- Block elements are more widely and consistently supported.

We use block elements for reliability.

### 6.3 External Tool (jp2a, timg, chafa)

Delegating to external ASCII art tools would be simpler to implement but:
- Adds a runtime dependency.
- IPC overhead for every image.
- Harder to integrate with Chawan's color system.
- Those tools may not be available on all platforms.

We implement our own encoder for full control and zero dependencies.

### 6.4 Pre-Rendered in Buffer Process

We could convert images to ASCII in the buffer process and send them as part
of the line data, avoiding any pager-side image handling. However:
- The pager needs to know the terminal's `ppc`/`ppl` for correct scaling,
  but the buffer doesn't have this information.
- The buffer process may be running on a different machine (future: remote
  buffer support).
- It would couple the buffer to a specific display mode.

We keep the conversion in the pager where terminal metrics are available.

---

## 7. Risks & Limitations

- **Quality**: ASCII art is inherently low-resolution. Photos will look
  blocky. This is a conscious trade-off for universal compatibility.
- **Performance**: Converting a large image to ASCII art is CPU-bound.
  For a 1000×1000 pixel image at 8×16 cell size, we process ~125×62 cells
  with 2×2 sub-pixel sampling — fast enough for interactive use.
- **Scrolling**: ASCII art images are part of the text layer, so they scroll
  naturally. However, the pager may need to re-convert if the terminal
  window is resized (cell dimensions change).
- **Text Selection**: ASCII art images are selectable as text, which may be
  confusing but is arguably better than invisible images.
- **CJK Terminals**: On terminals with double-width CJK characters, the block
  element characters are typically single-width. The image width calculation
  must use `strwidth()` (already available in `utils/strwidth.nim`) to handle
  this correctly.
