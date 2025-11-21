## Goals
- Adopt ITOA’s img→ASCII conversion approach (brightness mapping with optional color) to replace ASCII boxes with real ASCII art in Chawan’s `image-mode = "ascii"`.
- Keep Sixel/Kitty paths intact and retain current config semantics.
- Validate progressively, compiling with `make` at each milestone and testing on multiple sites.

## Approach
- Converter: implement a Nim-based img→ASCII converter inspired by ITOA (mapping luminance to a character ramp ` .:-=+*#%@`), with optional ANSI color output.
- Rendering: emit ASCII art directly in terminal at image positions, honoring pixel→cell geometry (`ppc`/`ppl`) and clipping.
- Pipeline: in ASCII mode, decode and resize images (reuse existing decoders), then convert to ASCII instead of Sixel/Kitty encoding.

## Phased Plan
### Phase 0: Baseline & Readiness
- Confirm current ASCII box mode works and project compiles: `make`.
- Gather sample inputs: use `sites/coffee.jpeg` and `sites/coffee.html`.
- Define character ramp and a minimal mapping function (monochrome-only for first pass).

### Phase 1: Standalone img2ascii Test (Local Harness)
- Build a small Nim test harness (no Chawan integration yet) that:
  - Loads `sites/coffee.jpeg` via the existing `stbi` decoder (RGBA).
  - Downscales to target cell geometry (1 char ≈ `ppc`×`ppl` pixels).
  - Maps block luminance to ASCII chars (ramp ` .:-=+*#%@`).
  - Prints output to stdout using pure text (monochrome).
- Verify converter correctness visually.
- Compile Chawan to ensure no breakage: `make`.

### Phase 2: Monochrome ASCII Integration in Chawan
- Pager (`loadCachedImage`) in `imAscii` branch:
  - Decode + optional resize (reuse existing CGI/codec path).
  - Run converter in-process to produce ASCII lines (monochrome).
- Terminal output:
  - Replace box renderer with line-by-line ASCII emission at the computed image position.
  - Handle cropping & damage via existing positioning (`offx`, `offy`, `dispw`, `disph`).
- Compile: `make`.
- Test: `./cha sites/coffee.html` and confirm ASCII content replaces images.

### Phase 3: Optional Color Output (ANSI)
- Extend converter to emit ANSI foreground colors per character by approximating pixel color (or average block color).
- Respect `display.color-mode`: if monochrome/ANSI/eight-bit/true-color, quantize accordingly; fall back to monochrome if needed.
- Add config switch if necessary (e.g., `display.ascii-color-mode = "mono" | "ansi" | "rgb"`), default to mono for stability.
- Compile: `make`.
- Test again on `coffee.html`.

### Phase 4: Geometry & Performance Hardening
- Aspect ratio calibration:
  - Make block size configurable or auto-derived from `ppc`/`ppl` (one char per cell), ensuring minimal distortion.
- Cropping:
  - Ensure partial lines at image edges are correctly clipped.
- Damage tracking:
  - Integrate with existing `lineDamage` strategy to redraw only affected lines.
- Compile: `make`.

### Phase 5: Step-by-step Site Testing
- Expand test sites list in `sites/sites.md` (add several pages with images):
  - `https://en.wikipedia.org/wiki/Coffee`
  - `https://developer.mozilla.org/en-US/docs/Web/HTML/Element/img`
  - `https://text.npr.org` (control; low images)
  - `https://unsplash.com/s/photos/coffee` (image heavy)
  - `https://news.ycombinator.com` (control; no images)
- For each site:
  - Run `./cha <url>` with `image-mode = "ascii"`.
  - Observe ASCII rendering, clipping, and color behavior.
  - Recompile between changes: `make`.

## Integration Details
- Converter API (internal):
  - Input: RGBA buffer + target char width/height (cells), optional color flag.
  - Output: sequence of strings (one per terminal line), plus a per-cell color array if color enabled.
- Pager flow (`imAscii`):
  - Decode → resize → convert → store ASCII payload in a lightweight structure (parallel to `CanvasImage` or new ASCII payload).
- Terminal flow:
  - At `outputImages`, render ASCII lines with `cursorGoto` + text; apply SGR for color if enabled.
  - Clear behavior aligns with text damage strategy (no Sixel/Kitty cleanup required).

## Config & Defaults
- Keep `display.image-mode = "ascii"`.
- Keep `display.ascii-color` for border or mono baseline if color mode stays off.
- Optionally add `display.ascii-color-mode` later (Phase 3); default `mono`.

## Validation & Rollback
- After each change:
  - `make` to ensure compilation.
  - Test with `coffee.html` first; then run expanded sites.
- If regressions in Kitty/Sixel appear, immediately gate ASCII path and revert the dispatcher branch.

## Deliverables
- Converter module (Nim) and integration in pager/term.
- Updated docs: configuration and a short usage guide.
- Updated test sites list.

## Risks & Mitigations
- Terminal differences in color support: fall back to monochrome automatically.
- Performance on large images: enforce downscale to cell grid and avoid per-pixel SGRs; use block averages.
- Layering with menus: clear/redraw sequences to avoid overlap artifacts.

## Timeline (Sequenced Steps)
1) Phase 0 baseline
2) Phase 1 converter harness
3) Phase 2 mono integration
4) Phase 3 color option
5) Phase 4 geometry & performance
6) Phase 5 multi-site tests

## Confirmation
- Once approved, I will begin Phase 1 (standalone converter test), verify with `make`, then proceed incrementally through integration and site testing as outlined.