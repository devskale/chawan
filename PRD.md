Chawan ASCII Image Rendering — Product Requirements Document (PRD)

## Summary

Add built-in ASCII image rendering to Chawan, a terminal web browser with JavaScript support, and make it the default image display method. The ASCII renderer must work in any POSIX-compatible terminal without relying on Sixel or Kitty graphics protocols. It should integrate cleanly with Chawan’s existing layout/rendering pipeline, respect CSS sizing, and provide configurable quality/performance trade-offs. We may optionally deprecate or disable Sixel/Kitty paths in this branch to keep the implementation focused.

## Goals

- Default, portable image display: Render <img> (and later <canvas>, <video> poster frames) as ASCII in all terminals.
- Integrate with existing layout engine: Respect CSS width/height, max/min constraints, and clipping.
- Good perceptual quality by default: Color-aware mapping with Unicode half-blocks; reasonable fallback to plain ASCII.
- Configurable: Character set, color mode, dithering, and performance knobs.
- Performant and robust: Cache results, avoid blocking the UI, degrade gracefully to placeholders.

## Non-goals (initial scope)

- Animated images (GIF/APNG/WebP) playback; treat as static first frame.
- Background-image rendering in CSS (keep “[img]” placeholder for now).
- Arbitrary CSS transforms on images (rotate/scale/skew) beyond sizing.
- Perfect color management; we can use a simple sRGB transfer/gamma.

## User stories

- As a user on a minimal terminal (no Sixel/Kitty), I can see images rendered as ASCII without extra configuration.
- As a power user, I can choose between ASCII ramps, block-drawing, and braille modes and tune dithering and color depth.
- As a reader, page layout remains stable; images occupy the right amount of space and don’t break line-wrapping.

## Current architecture overview (grounded in repo)

- Layout and rendering:
  - `src/css/layout.nim` computes box sizes for images (InlineImageBox) and text; uses `ppc` (pixels-per-column) and `ppl` (pixels-per-line) to map CSS px to terminal cells.
  - `src/css/render.nim` paints text/backgrounds into a terminal grid. For images, it currently marks background and hands off to the terminal image pipeline. Background images show a placeholder (“[img]”).
- Image pipeline (today):
  - DOM image loading in `src/html/dom.nim` determines intrinsic dimensions and sets up `NetworkBitmap` with `imageId`/`cacheId` headers (e.g., “Cha-Image-Dimensions”).
  - Pager/terminal paths encode and display images using either Sixel or Kitty:
	 - Sixel: `adapter/img/sixel.nim` encodes frames; `src/local/term.nim` manages placement/cropping and emits control sequences.
	 - Kitty: similar flow with different control sequences.
  - Canvas rendering: `src/html/domcanvas.nim` sends vector/text commands to `adapter/img/canvas.nim`, which rasterizes into a bitmap.
- Available low-level helpers:
  - Pixel formats and colors: `types/color.nim`, `types/bitmap.nim`, `types/canvastypes.nim`.
  - Image IO: STB image bindings exist (`adapter/img/stbi.nim`) and resizing helpers (`adapter/img/resize.nim`, `bonus/stbir2/`). These enable in-process decode/resize.

Key takeaway: We can compute the final terminal grid size for images in the renderer; we have in-repo decoders/resizers; and we already output colorful text with precise width handling. This favors an in-grid ASCII renderer integrated into `render.nim` rather than going through the terminal image overlay path.

## Requirements

Functional
- R1: Render HTML <img> as ASCII within the terminal grid at the correct size (CSS width/height/min/max). Respect clipping against the viewport/clip box.
- R2: Fallback to a placeholder (“[img]” or alt text) while decoding/rasterizing asynchronously.
- R3: Use color by default; support monochrome fallback.
- R4: Honor `object-fit: contain|cover|fill` minimally (initially treat as contain/scale-to-fit; document limitations).
- R5: Cache ASCII renderings per image, size, and settings to avoid repeated work during scroll or reflow.

Quality/perception
- R6: Exposure/contrast/gamma tuned for legible ASCII; configurable ramp and gamma.
- R7: Default character set should be Unicode half-blocks with foreground/background truecolor (approx. 2× vertical resolution per text row).
- R8: Optional modes: plain ASCII ramp; Braille (2×4 dot) mode; 256-color quantized mode.

Performance
- R9: Keep first meaningful paint responsive; offload decode + ASCII conversion off the main render pass.
- R10: Tile or line-based incremental rendering for large images; enable early partial paints.
- R11: Cap memory via an LRU for ASCII caches; clear on terminal resize or setting changes.

Configurability
- R12: New settings under `display.ascii.*` and a top-level `display.image-mode = ascii|sixel|kitty|auto` with `ascii` as the default on this branch.

Reliability
- R13: Deterministic output across terminals with 24-bit color support; graceful degradation to 256/16 colors.
- R14: Support double-width terminals and maintain correct string width accounting (use `utils/strwidth`).

## Design overview

High-level approach: In-grid ASCII renderer
- Add a new image mode `imAscii` and a renderer path inside `src/css/render.nim`’s image painting branch. Instead of scheduling a terminal image overlay, we convert the source bitmap to a run of styled text lines and write them to the grid using `grid.setText(...)` with appropriate foreground/background colors.
- Decode and resize images in-process using `adapter/img/stbi.nim` and `adapter/img/resize.nim`. Do not rely on external adapters or terminal-specific protocols.
- Cache per (image cacheId, computed cell width/height, charset, color mode, dithering, gamma) to reuse across paints.

Why not reuse Sixel/Kitty or build an external “ascii adapter”?
- Sixel/Kitty paths require terminal protocol support and binary upload; ASCII does not. We’d only be packaging text to then re-inject it; in-grid rendering is simpler and integrates with text selection/copy.
- Keeping it in-process avoids another IPC hop and lets layout control line breaks precisely.

## Detailed rendering algorithm

Inputs
- Source: decoded RGBA bitmap (w×h), sRGB.
- Target: terminal cell grid size for the image box: cw = ceil(cssWidth / ppc), ch = ceil(cssHeight / ppl), where `ppc` and `ppl` come from the rendering state.
- Settings: charset (ascii|blocks|braille), color mode (truecolor|256|16|mono), dithering (none|bayer4|bayer8|floyd), gamma/contrast.

Pipeline
1) Decode (once per image source):
	- Use STB bindings (`adapter/img/stbi.nim`) to decode the first frame to 8-bit RGBA.
	- Store in an `ImagePixels` cache keyed by `cacheId`.
2) Scale to target pixel size:
	- Compute target pixel dimensions from cw/ch and chosen mapping:
	  - ASCII ramp: 1 cell ≈ ppc×ppl pixels.
	  - Half-block mode (default): 1 char cell covers ppc×ppl pixels but encodes two sub-rows (top/bottom) using foreground/background colors with ‘▀’ (U+2580) or ‘▄’.
	  - Braille mode: 1 char encodes a 2×4 pixel grid; effective target pixel grid is (2×cw, 4×ch).
	- Use `adapter/img/resize.nim` or `bonus/stbir2` to resize source to the target grid.
3) Color/luminance mapping per cell:
	- Compute per subcell stats (mean RGB, variance) and luminance Y ≈ 0.2126R + 0.7152G + 0.0722B (sRGB). Apply gamma if configured.
	- Dithering: apply ordered Bayer (fast) by default; allow Floyd–Steinberg as opt-in for higher quality.
4) Character selection:
	- Half-block (default):
	  - For each cell, compute top and bottom average colors. Choose ‘▀’ and set FG = top color, BG = bottom color. If using ‘▄’, invert roles. For uniform cells, ‘█’ or ‘ ’ may be chosen to reduce color state churn.
	- ASCII ramp:
	  - Map luminance to a ramp like “ .:-=+*#%@” (configurable). With color mode on, use foreground color = mean RGB; background follows grid default.
	- Braille:
	  - Threshold 2×4 subcells and set the corresponding dots in U+2800..U+28FF; choose a single representative color.
5) Emit grid lines:
	- Build per-line strings with minimal format runs (batch adjacent chars sharing FG/BG). Use `grid.setText(...)` with computed `Format` that includes 24-bit or 256-color as supported by the terminal config.
6) Cache:
	- Store a compact representation per line (string + runs of color formats). Invalidate on terminal resize or settings change.

Edge cases
- Very small images: ensure minimum of 1×1 cell; avoid tiny dithering noise.
- Transparency: blend source over page background color when computing cell colors. If page background is not known (transparent), assume terminal default or `state.bgcolor` from `render.nim`.
- Cropping/clipping: compute the visible cell rect intersecting with `clipBox` and only emit within that range.
- Non-integer scaling: rely on high-quality resizer; avoid per-pixel aliasing by favoring downscale with filter.

## Integration points in code

- New enum value in terminal/image mode: `imAscii` in `src/local/term.nim` (used for config; not used for overlay drawing).
- Renderer hook: `src/css/render.nim` — in the `InlineImageBox` branch (see around image painting), add an ASCII path that:
  - Determines cw/ch from `ibox.imgstate.size` and `state.attrs.ppc/ppl`.
  - Requests/caches `AsciiTexture` (decoded + resized + mapped) through a new module (e.g., `src/utils/asciiimage.nim`).
  - Emits lines via `grid.setText(...)` with appropriate `Format` runs.
- Decode/cache service: `src/utils/asciiimage.nim` (new)
  - API: `getAsciiTexture(cacheId: int, cssW, cssH: float, ppc, ppl: int, settings: AsciiSettings): Future[AsciiTexture]`
  - Internals: pull bytes from loader cache by `cacheId` (synchronous if available), decode via STB, resize, map to chars, return a structured texture.
  - LRU and invalidation on resize.
- Settings wiring: `src/config/*.nim` to add `display.image-mode` and `display.ascii.*` keys; `doc/cha-image.7` and `doc/cha-config.5` updates.

## Configuration surface (proposed)

- display.image-mode: ascii | sixel | kitty | auto (default: ascii on this branch)
- display.ascii.charset: blocks | ascii | braille (default: blocks)
- display.ascii.color: truecolor | 256 | 16 | mono (default: truecolor)
- display.ascii.dither: bayer4 | bayer8 | floyd | none (default: bayer8)
- display.ascii.gamma: float (default: 2.2)
- display.ascii.contrast: float (default: 1.0)
- display.ascii.max-cache-mb: int (default: 64)

## Performance considerations

- Work partitioning: Decode + resize + ASCII map performed off the immediate paint path. If not ready, emit placeholder and schedule an invalidate.
- Incremental paint: For large images, produce lines in chunks (e.g., 16 rows) to allow progressive display.
- Caching: Two-level cache — decoded RGBA (by `cacheId`) and rendered ASCII (by `cacheId` + size + settings). LRU with memory cap; purge on terminal resize.
- Minimizing format churn: Coalesce same-color runs per line to avoid excessive SGR switches.

## Risks and mitigations

- Decoding in-process introduces dependencies: We reuse in-repo STB bindings; avoid system libraries.
- Color correctness varies by terminal: Offer 256/16 color modes and monochrome; document differences.
- Mixed-width glyphs: Use only width-1 glyphs (block elements, ASCII, braille) and verify with `utils/strwidth`.
- Large images: Enforce max cells or downscale aggressively to viewport-limited size.

## Testing strategy

- Unit tests:
  - Character mapping: verify luminance-to-ramp and half-block color pairing on synthetic inputs.
  - Dithering correctness against known small patterns.
  - String width accounting across modes.
- Integration tests:
  - Golden snapshots: render fixed PNGs at given ppc/ppl and compare ASCII output (allow small tolerances if needed by using semantic diff: ramps + color run lengths).
  - Layout compliance: ensure CSS width/height constraints are respected.
  - Performance smoke: measure render time for 1024×768 → 80×24 cell mapping.
- Manual TTY tests across terminals (truecolor, 256-color).

## Documentation updates

- `doc/cha-image.7`: Add ASCII as a supported output format; make it the default; describe trade-offs and settings.
- `doc/cha-config.5`: New `display.ascii.*` settings.
- `doc/cha-terminal.7`: Note Unicode blocks and color requirements; mention fallbacks.
- README.md: Short section showcasing ASCII images with a screenshot.

## Milestones

1) Spike/prototype (1–2 days)
	- Inline prototype that maps a decoded bitmap to half-block ASCII for a fixed size; prove quality and speed.
2) Decode + resize service (1–2 days)
	- Implement in-process decode using STB; basic LRU for decoded bitmaps; hook into loader cache.
3) Renderer integration (2–3 days)
	- Add `imAscii` mode and `render.nim` ASCII path for InlineImageBox; initial placeholder fallback; monochrome ramp working.
4) Color + half-block + dithering (2–3 days)
	- Truecolor output; Bayer dithering; quality tuning and settings.
5) Caching + incremental paint (1–2 days)
	- Render cache per size/settings; progressive line emission.
6) Config/docs/tests (1–2 days)
	- Wire settings; write docs; add unit/integration tests; basic visuals.
7) Stretch goals (post-MVP)
	- Braille mode; background-image support; canvas/video frames; Floyd–Steinberg; gamma calibration.

## Success criteria

- Default build renders images as ASCII on standard terminals with no extra config.
- Subjective visual quality: images are recognizable and readable in default mode; copy/paste preserves layout.
- Performance: first paint of a typical article page with 3–5 images completes within a small, configurable budget and doesn’t freeze the UI.

## Open questions

- Where to perform decode scheduling: during DOM image load vs. on-demand during first paint? (Initial proposal: on-demand with caching, to avoid work for off-screen images.)
- How to select page background for alpha compositing consistently (document background vs. terminal default)?
- Should ASCII rendering be opt-out (auto-detect Sixel/Kitty and prefer ASCII regardless), or respect `auto` mode to pick the “best” available?

## Decision log (initial)

- D1: Implement in-grid ASCII rendering in `render.nim`; do not introduce an external adapter for ASCII.
- D2: Use half-block Unicode with truecolor as the default mode; fallback ramps available via settings.
- D3: Decode images in-process via STB; maintain caches for decoded and rendered assets.


