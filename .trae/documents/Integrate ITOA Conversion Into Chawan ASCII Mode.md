## Goals
- Replace bordered-box placeholder with real ASCII art using the ITOA luminance ramp while keeping current config: `display.image-mode = "ascii"` and `display.ascii-color`.
- Preserve Sixel/Kitty paths and auto-detection; only affect `imAscii`.

## Key Integration Points
- Config enums already include `imAscii` in `src/config/conftypes.nim:32`.
- Terminal renderer entry points:
  - ASCII output switch in `src/local/term.nim:1297–1300`.
  - ASCII renderer function at `src/local/term.nim:1927`.
  - `asciiColor` read and default at `src/local/term.nim:955–956` and `src/local/term.nim:1922`.
- Pager image pipeline:
  - Current ASCII branch at `src/local/pager.nim:1387–1395` bypasses decode.
  - Normal image decode/caching path at `src/local/pager.nim:1247–1367` and use in `src/local/pager.nim:1396–1407`.

## Phase 0: Baseline
- Build: run `make` to confirm current tree compiles.
- Sanity run: `./cha sites/coffee.html` with `display.image-mode = "ascii"` shows existing bordered boxes.

## Phase 1: Test img2ascii Conversion (Standalone)
- Create a minimal Nim utility (no app dependencies) that:
  - Reads RGBA bytes and dimensions.
  - Implements ITOA ramp `' .:-=+*#%@'` (from `/Users/johannwaldherr/code/brewing/chas/itoa/README.md:28–33`).
  - Aggregates pixels into terminal-cell sized blocks using `ppc/ppl` to map pixels→cells.
  - Outputs monochrome ASCII using a single tone, driven by `asciiColor`.
- Use `sites/coffee.jpeg` as input via the existing decoder path documented in `doc/cha-image.7:133–171`.
- Verify visually on the terminal and adjust block sizes if needed.
- Build check after adding the utility: `make`.

## Phase 2: Pager Decode for ASCII Mode
- Change ASCII path to request raw RGBA instead of bypassing decode:
  - In `src/local/pager.nim:1387–1395`, replace `loadAsciiImage` usage with a decode/cached-data path mirroring the Sixel/Kitty pre-step:
    - Call `img-codec+{type}:decode` with full RGBA output (not info-only).
    - Store resulting `Blob` into `CachedImage.data` with `preludeLen = 0`.
  - Then create `CanvasImage` via `term.loadImage(...)` passing the RGBA `Blob` and standard placement params.
- Keep caching behavior consistent with the existing logic.
- Build: `make`.

## Phase 3: Terminal ASCII Renderer (ITOA Algorithm)
- Update `src/local/term.nim:1927` implementation:
  - Read `image.data` as RGBA stream (big-endian 8-bit per component) with known `image.width/height`.
  - Derive visible region `realwpx/realhpx` and map to cells using `term.attrs.ppc/ppl` (like current box code).
  - For each cell:
    - Compute average luminance: `0.299R + 0.587G + 0.114B` over the block.
    - Map to ramp `' .:-=+*#%@'`.
    - Monochrome: use `asciiColor` SGR once per frame or once per line (`src/local/term.nim:955–956`, `src/local/term.nim:1941–1942`).
  - Write lines at `cursorGoto(x, y + row)`; remove the placeholder border/fill logic.
- Keep damage tracking, clipping, and positioning intact.
- Build: `make`.

## Phase 4: Stepwise Verification
- Run `./cha sites/coffee.html` with `image-mode = "ascii"` using `res/config.toml:95` or page-local config.
- Confirm proportional sizing and clipping match pager math.
- Change `display.ascii-color` (e.g., `gray`, `red`, `#808080`) and verify tone application.
- Switch to `"sixel"`/`"kitty"` and ensure unchanged behavior.

## Phase 5: Optional Enhancements (Follow-up)
- Add `display.ascii-color-mode = "tone" | "source"`:
  - `source` sets per-character foreground color from averaged RGB (ITOA color mode).
  - Default remains `tone` for consistency with PRD.
- Consider a config `ascii-ramp` to customize character ramp.

## Risks & Mitigations
- Performance: aggregation per cell is O(n) over visible pixels; mitigate by precomputing row strides and avoiding per-char SGR changes.
- Header parsing: RGBA decode is specified to stream raw bytes with dimensions in headers (`doc/cha-image.7:133–171`); avoid header dependence by using `image.width/height` only.
- Terminal differences: stick to plain ASCII and ANSI SGR per PRD; add color mode only as an opt-in later.

## Acceptance
- AC1–AC5 from `/Users/johannwaldherr/code/brewing/chas/chawan/prd.ascii.md:74–79` satisfied with real ASCII art replacing boxes.
- Tests: compile via `make` at each phase; run coffee sample; verify color and clipping.
