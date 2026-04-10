# Feature Plan: ASCII Art Image Rendering

**Branch:** `feature/img-ascii`
**Design doc:** `doc/img-ascii.md`
**Status:** Planning

---

## Overview

Add `"ascii"` as a fourth `display.image-mode` that converts decoded RGBA image
data into colored Unicode block characters rendered in the terminal's text
layer. Works on any terminal, no graphics protocol required.

## Steps

Each step is a single commit. Detail is intentionally light — we'll
investigate and plan each step fully before implementing it.

---

### Step 1: Add `imAscii` to `ImageMode` enum and wire it through

**Goal:** The enum exists, compiles, and all existing `case` branches that
dispatch on `imageMode` handle the new variant (even if just `discard`).

**Files:**
- `src/config/conftypes.nim` — add `imAscii = "ascii"`
- `src/local/term.nim` — add `of imAscii: discard` to every `case` on `imageMode`
- `src/local/pager.nim` — same
- Any other file with exhaustive `case` on `ImageMode`

**Validate:** `make` succeeds, `make test` passes.

---

### Step 2: Auto-detection fallback to ASCII

**Goal:** When `display.image-mode = "auto"` and neither Kitty nor Sixel is
detected, fall back to `imAscii` instead of staying at `imNone`.

**Files:**
- `src/local/term.nim` — in DA1 response handler, after no Sixel detected,
  and after Kitty check, set `term.imageMode = imAscii` as fallback
- Test: `cha -V` in a non-Sixel, non-Kitty terminal should report ascii mode

**Validate:** `make && make test`. Manual: `cha -o 'display.image-mode=auto'` in
macOS Terminal (no sixel) → images enabled with ascii mode.

---

### Step 3: ASCII conversion function (in-process, pager-side)

**Goal:** A pure Nim function `rgbaToAsciiGrid(data: pointer, w, h: int,
  cellW, cellH: int, quality: int): SimpleFlexibleGrid` that takes raw RGBA
pixels and produces colored text lines using Unicode block elements (2×2
sub-pixel resolution per cell).

**Files:**
- New: `src/local/asciiart.nim` — the conversion logic
  - Block character lookup table (16 chars for 2×2 bit patterns)
  - Area-average downsampling: for each cell, average RGBA of source pixels
    in the corresponding ppc×ppl region, split into 2×2 quadrants
  - Alpha handling: blend against white background
  - Color modes based on quality:
    - low (1–30): monochrome, default fg/bg
    - medium (31–70): `toEightBit()` → ANSI 256-color fg
    - high (71–100): truecolor RGB fg
  - Returns `SimpleFlexibleGrid` (compatible with buffer's line format)

**Validate:** Unit test — convert a known 4×4 RGBA gradient to expected block
characters and colors. `make test`.

---

### Step 4: Hook ASCII art into pager image pipeline (decode + resize)

**Goal:** When `imageMode == imAscii`, the pager decodes and resizes images
as usual, then converts to ASCII grid instead of encoding to Sixel/PNG.

**Detail before starting:** Trace `loadCachedImage()` → `loadCachedImage0()`
→ `loadCachedImage2()` → `loadCachedImage3()` in `src/local/pager.nim`.
Understand how `CachedImage.data` is set and how `CanvasImage` is created.
Determine where to intercept for ASCII mode.

**Files:**
- `src/local/pager.nim`:
  - In `loadCachedImage2()`, add `of imAscii` branch that skips the Sixel/PNG
    encode step and instead calls `rgbaToAsciiGrid()` on the decoded RGBA data
  - Store the resulting `SimpleFlexibleGrid` in `CachedImage` (add a new field
    or repurpose `data`)
  - In `initImages()`, for ASCII mode, skip `term.addImage()` / `CanvasImage`
    management entirely

**Validate:** `make`. No visual test yet — just compiles.

---

### Step 5: Overlay ASCII art into the paint loop

**Goal:** When the pager paints buffer lines, ASCII art images are spliced into
the text at the correct position, replacing the blank cells where the image
sits.

**Detail before starting:** Study `drawBuffer()` in `src/local/pager.nim` and
`requestLinesSync()` in `src/server/bufferiface.nim`. Understand how
`SimpleFlexibleLine` is streamed line-by-line and how the image's `PosBitmap`
y/height maps to line indices. Determine whether to:
- (a) Modify the line data before painting (splice ASCII lines into
      `iface.lines`), or
- (b) Intercept in `drawBuffer()` and replace lines at image positions.

**Files:**
- `src/local/pager.nim` — in `drawBuffer()` (or equivalent), for each line
  being painted, check if an ASCII-art `CachedImage` covers this line range,
  and substitute the ASCII art line content at the correct x-offset
- `src/server/bufferiface.nim` — possibly add `CachedImage.asciiGrid` field
  or a separate lookup structure

**Validate:** `make`. Manual: `echo '<html><body><img src="data:image/png;base64,..."></body></html>' | cha -T text/html -d -o 'buffer.images=true' -o 'display.image-mode=ascii'` —
should show colored block characters instead of blank space.

---

### Step 6: Standalone image viewing support

**Goal:** `cha photo.jpg` with `image-mode=ascii` shows ASCII art via the
existing `img2html` mailcap path.

**Detail before starting:** Verify that the existing `DefaultMailcap` entry
for `image/*` (which calls `img2html` to wrap in `<img>` tag) already works
with ASCII mode, or if any changes are needed.

**Files:**
- Likely no changes needed — `img2html` produces `<img>` tags which go
  through the normal image pipeline. Verify and add a test if not.

**Validate:** `make && make test`. Manual: `cha -o 'buffer.images=true' -o 'display.image-mode=ascii' test/fixtures/some-small-image.png` — shows ASCII art.

---

### Step 7: Configuration option for quality

**Goal:** Add `display.ascii-image-quality` config option (1–100, default 50).

**Files:**
- `src/local/pager.nim` — read `pager.config{"asciiImageQuality"}` and pass
  to `rgbaToAsciiGrid()`
- `doc/config.md` — document the new option

**Validate:** `make`. Manual: compare quality 10 (monochrome) vs 90 (truecolor).

---

### Step 8: Resize support and edge cases

**Goal:** Images that are larger than the terminal width are scaled down.
Very small images (1×1) and edge cases (image partially visible at screen
edge) are handled correctly.

**Detail before starting:** Study how the existing pipeline handles resize
(`cgi-bin:resize`, `Cha-Image-Target-Dimensions` header). Determine if ASCII
mode can reuse the same resize step or if it needs its own scaling.

**Files:**
- `src/local/pager.nim` — ensure resize step runs before ASCII conversion
- `src/local/asciiart.nim` — handle edge cases in `rgbaToAsciiGrid()`

**Validate:** `make && make test`. Manual: large image scaled to terminal width.

---

### Step 9: Optional — extract to CGI process

**Goal:** Move ASCII conversion to `adapter/img/ascii.nim` as a standalone
CGI program, matching the pattern used by all other codecs.

**Files:**
- New: `adapter/img/ascii.nim`
- `res/urimethodmap` — add `img-codec+x-ascii: cgi-bin:ascii`
- `Makefile` — add `ascii` to `protocols_bin`
- `src/local/pager.nim` — switch to CGI-based encode for ASCII mode

**Validate:** `make && make test`.

---

## Commit convention

Each step = one commit. Format:
```
feat(img-ascii): step N — short description
```
