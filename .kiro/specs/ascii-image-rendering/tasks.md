# Implementation Plan

## Phase 1: Dummy ASCII Rendering (Proof of Concept)

- [ ] 1. Add ASCII image mode to configuration system
  - Add `imAscii = "ascii"` to ImageMode enum in src/config/conftypes.nim
  - Update configuration parsing to recognize "ascii" image mode
  - Test configuration loading with display.image-mode = "ascii"
  - _Requirements: 6.1_

- [ ] 2. Create dummy ASCII image codec
  - Create adapter/img/ascii.nim with basic CGI structure following sixel.nim pattern
  - Implement simple dummy output that generates fixed ASCII placeholder (e.g., "[IMG WxH]")
  - Add img-codec+x-ascii mapping to res/urimethodmap
  - Test codec can be invoked through URI method mapping
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 3. Integrate ASCII mode into terminal image pipeline
  - Extend image mode detection in src/local/term.nim to handle imAscii
  - Add ASCII mode handling in image processing pipeline (similar to sixel/kitty)
  - Ensure ASCII images are treated as text in terminal canvas
  - _Requirements: 1.1, 2.4_

- [ ] 4. Test dummy ASCII rendering end-to-end
  - Build Chawan with ASCII support
  - Test with `cha --config display.image-mode=ascii google.at`
  - Verify images show as ASCII placeholders instead of being skipped
  - Confirm no crashes or errors in ASCII mode
  - _Requirements: 1.4, 4.1_

## Phase 2: Basic ASCII Conversion (After Dummy Works)

- [ ] 5. Implement basic ASCII conversion algorithm
  - Replace dummy output with actual RGBA to ASCII conversion
  - Implement simple brightness-to-character mapping using basic charset ` .:-=+*#%@`
  - Add basic image resizing to fit terminal width
  - _Requirements: 1.2, 1.3, 3.2_

- [ ] 6. Test basic ASCII conversion with live websites
  - Test ASCII image rendering with `cha --config display.image-mode=ascii` on various sites
  - Verify images are recognizable as ASCII representations
  - Test performance with multiple images on a page
  - _Requirements: 4.1, 5.1_

## Phase 3: Enhanced ASCII Features (Future)

- [ ] 7. Add extended character sets and quality options
  - Implement extended ASCII character set (70 characters)
  - Add Unicode block character support
  - Add configurable quality levels and width constraints
  - _Requirements: 3.1, 3.3, 3.4_

- [ ] 8. Implement advanced features
  - Add Floyd-Steinberg dithering for better quality
  - Implement caching for ASCII representations
  - Add comprehensive error handling and fallbacks
  - _Requirements: 5.3, 4.2, 4.3_

- [ ] 9. Performance optimization and testing
  - Optimize ASCII conversion performance
  - Add comprehensive test suite
  - Implement memory usage limits for large images
  - _Requirements: 5.1, 5.2, 4.4_

- [ ] 10. Final polish and documentation
  - Add configuration validation and user feedback
  - Update documentation with ASCII mode usage
  - Add examples and troubleshooting guide
  - _Requirements: 6.3, 6.4_