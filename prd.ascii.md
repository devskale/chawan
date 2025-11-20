Chawan ASCII Image Mode — Product Requirements (PRD)

## 1. Summary
- Introduce an ASCII image rendering mode in Chawan that draws images as ASCII art boxes in terminals that do not support inline images or when configured by the user. Initial phase focuses on simple bordered boxes sized by pixel→cell geometry and colored via a configurable tone.

## 2. Problem Statement
- Many terminals lack Sixel/Kitty support or users prefer low-bandwidth rendering. Chawan should degrade gracefully by representing images in a readable, consistent ASCII form without breaking layout or performance.

## 3. Objectives & Success Metrics
- Objectives:
  - Provide a reliable ASCII rendering fallback configurable via `display.image-mode`.
  - Keep integration minimal: no disruption to Sixel/Kitty paths.
  - Maintain layout fidelity using cell-based aspect computation.
- Success Metrics:
  - Build passes; `./cha sites/coffee.html` shows ASCII boxes when `image-mode = "ascii"`.
  - Color tone applied from `display.ascii-color` across terminals.
  - No regressions for Sixel/Kitty modes; auto-detection unchanged.

## 4. Scope
- In-Scope (Phase 1):
  - ASCII boxes (border + fill), sizing by pixel/cell geometry.
  - Config options: `image-mode = "ascii"`, `ascii-color`.
  - Pager and terminal integration, docs, and tests.
- Out-of-Scope (Phase 1):
  - Content-aware dithering/shading.
  - Transparency blending.
  - Auto fallback switching beyond existing detection logic.

## 5. Users & Use Cases
- Terminal users on limited environments (SSH, minimal emulators).
- Developers validating page layout without image capabilities.
- Users preferring non-binary output modes for logging or capture.

## 6. Functional Requirements
- FR1: Configurable image mode with new enum value `ascii`.
- FR2: Uniform ASCII box rendering sized per visible region.
- FR3: Apply color tone from `display.ascii-color`.
- FR4: Integrate with existing image model (`CanvasImage`) and draw after text grid.
- FR5: Maintain backward compatibility with `sixel` and `kitty`.

## 7. Non‑Functional Requirements
- NFR1: Minimal performance overhead vs text output.
- NFR2: Consistent rendering in monospace terminals.
- NFR3: No security changes; no external dependencies introduced.
- NFR4: Code adheres to project style and architecture conventions.

## 8. Architecture Overview
- Config:
  - `display.image-mode = "auto" | "none" | "sixel" | "kitty" | "ascii"`.
  - `display.ascii-color = <color>` (CSS color or hex).
- Pipeline integration:
  - Pager (`src/local/pager.nim`) creates logical `CanvasImage` entries directly in ASCII mode, bypassing decode/encode.
  - Terminal (`src/local/term.nim`) positions images and renders ASCII boxes post text output.
- Data model:
  - Reuse `CanvasImage` for positions, dimensions, and damage tracking.
  - No binary payload required for ASCII path.

## 9. Configuration & DX
- Example:
  ```toml
  [buffer]
  images = true

  [display]
  image-mode = "ascii"
  ascii-color = "gray"
  ```
- CLI/Test Flow:
  - Build: `make`
  - Run: `./cha sites/coffee.html`
  - Adjust tone: set `ascii-color` to `red`, `brightcyan`, or `#808080`.

## 10. Acceptance Criteria
- AC1: ASCII mode displays bordered boxes in place of images.
- AC2: Box dimensions reflect pixel→cell geometry and visible clipping.
- AC3: Color tone applied correctly.
- AC4: Sixel/Kitty behavior unchanged; auto mode remains intact.
- AC5: Documentation updated; config options documented.

## 11. Test Plan
- Build verification: `make`; ensure success.
- Functional tests:
  - Launch `./cha sites/coffee.html` with `image-mode = "ascii"`.
  - Verify multiple image sizes render boxes proportionally.
  - Change `ascii-color` and verify tone in output.
- Compatibility checks:
  - Switch to `image-mode = "sixel"` / `"kitty"` and verify unaffected behavior on capable terminals.
- Headless/dump:
  - Confirm text rendering remains correct; ASCII boxes are present (best-effort).

## 12. Risks & Assumptions
- Risk: Some terminals may render line art differently (charset variations).
- Risk: Complex page overlays may interact with ASCII boxes (menu overlays).
- Assumption: Monospace rendering and ANSI color support is available.

## 13. Rollout Plan
- Phase 1 (POC): ASCII boxes with color tone.
- Phase 2: Dithering/shading ramp; transparency-aware fills; more config options.
- Phase 3: Fallback improvements and extended testing suite.

## 14. Future Work
- Shading/Dithering: luminance→ASCII ramp mapping.
- Transparency handling: outline-only or alpha thresholds.
- Configurability: outline/fill characters; complexity levels; per-site overrides.
- Performance: refined damage tracking for large pages.

## 15. AI‑IDE Work Items
- Analyze: map image pipeline, config parsing, terminal output branches.
- Implement: add `imAscii` enum, parse `ascii-color`, terminal renderer, pager integration.
- Verify: build (`make`), run sample pages, color/size checks.
- Document: update config docs and PRD.
- Plan Next: write tasks for shading and transparency features.

## 16. Change Log
- POC implemented: ASCII boxes mode (`imAscii`), `ascii-color` option, terminal/pager integration, docs and tests completed.
