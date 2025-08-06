# Implementation Plan

- [x] 1. Create minimal ASCII placeholder system
  - Create simple function that returns a single ASCII block character "[IMG]" for any image
  - Add basic configuration option to enable ASCII mode in display settings
  - Test that ASCII placeholder appears instead of broken image indicators
  - _Requirements: 1.1_

- [x] 2. Implement basic image dimension detection
  - Extend ASCII placeholder to show actual image dimensions like "[IMG 100x50]"
  - Read image dimensions from existing codec system
  - Test dimension display with various image formats
  - _Requirements: 1.4_

- [x] 3. Add simple single-character ASCII conversion
  - Convert entire image to single ASCII character based on average brightness
  - Use basic character set: " ", ".", "#", "@" based on luminance
  - Display single character repeated to approximate image dimensions
  - Test with high contrast and low contrast images
  - _Requirements: 1.1, 1.3_

- [x] 4. Implement proper image scaling for ASCII dimensions
  - Calculate appropriate ASCII art dimensions based on terminal character size
  - Scale images to fit within reasonable ASCII grid (e.g., max 80x24 characters)
  - Preserve aspect ratio during scaling
  - Test scaling with various image sizes and aspect ratios
  - _Requirements: 1.3, 2.2_

- [x] 5. Create basic luminance-based ASCII conversion
  - Implement pixel-to-character conversion using luminance calculation
  - Use basic ASCII character set: " .:-=+*#%@" (10 levels)
  - Convert each pixel region to corresponding ASCII character
  - Test conversion accuracy with grayscale test images
  - _Requirements: 1.1, 1.3_

- [x] 6. Add ASCII configuration options
  - Add ascii-max-width and ascii-max-height configuration settings
  - Implement configuration parsing for ASCII-specific options
  - Allow users to control ASCII art dimensions
  - Test configuration changes take effect
  - _Requirements: 2.1, 2.2_

- [x] 7. Integrate ASCII mode with image display selection
  - Add "ascii" option to display.image-mode configuration
  - Modify image display logic to use ASCII when mode is set to "ascii"
  - Test ASCII mode selection works correctly
  - _Requirements: 1.2, 3.1_

- [x] 8. Create ASCII image codec following existing pattern
  - Implement minimal ASCII codec that follows img-codec interface
  - Handle RGBA input and produce ASCII text output
  - Process basic headers for image dimensions
  - Test codec integration with existing image loading system
  - _Requirements: 4.3_

- [x] 9. Integrate ASCII images with CSS tree building system (**REVISED APPROACH**)
  - **DISCOVERY**: ASCII integration happens in `src/css/csstree.nim`, not rendering
  - Modified `addImage()` function to generate ASCII art when NetworkBitmap unavailable
  - Extended configuration pipeline: Config → BufferConfig → Window → EnvironmentSettings
  - Implemented ASCII art as universal fallback for failed image loads
  - **RESULT**: ASCII art now displays instead of `[img]` placeholders
  - _Requirements: 3.4_
  
  **Key Lessons Learned:**
  - Image placeholders are generated during CSS tree building, not rendering
  - ASCII art works best as fallback mechanism rather than separate rendering mode
  - Configuration must flow through multiple system layers to reach integration points
  - The `addImage()` function in `csstree.nim` is the critical integration point

- [x] 10. Add extended ASCII character sets (**UPDATED APPROACH**)
  - Modify `addImage()` in `src/css/csstree.nim` to use configurable character sets
  - Access imageMode configuration from TreeFrame context
  - Implement character set selection based on user configuration
  - Test visual quality improvement with extended character sets
  - **Challenge**: Need to access configuration from CSS tree building context
  - _Requirements: 2.1_

- [x] 11. Implement actual image-to-ASCII conversion (**NEW PRIORITY**)
  - **CURRENT STATE**: Static ASCII art is generated regardless of actual image content
  - Integrate with image loading pipeline to get actual RGBA pixel data
  - Call ASCII codec when images are successfully loaded but imageMode is ASCII
  - Convert real image data to ASCII art using luminance-based algorithms
  - **Challenge**: Bridge between successful image loading and ASCII generation
  - _Requirements: 1.1, 2.3_

- [ ] 12. Implement conditional ASCII mode behavior (**NEW INSIGHT**)
  - **CURRENT STATE**: ASCII art shows for all image modes when bitmap unavailable
  - Add imageMode checking in `addImage()` function
  - Show ASCII art only when `display.image-mode=ascii` or as fallback
  - Preserve original `[img]` placeholder for other modes when appropriate
  - **Challenge**: Access imageMode configuration from TreeFrame context
  - _Requirements: 3.1, 3.2_

- [ ] 13. Implement caching for ASCII conversions
  - Cache converted ASCII representations to avoid repeated processing
  - Integrate with existing image caching infrastructure
  - Test caching improves performance on repeated image loads
  - _Requirements: 5.3_

- [ ] 14. Add error handling and fallback mechanisms
  - Handle conversion failures gracefully with placeholder text
  - Add memory limits for large image conversions
  - Provide user-friendly error messages
  - Test error conditions and recovery
  - _Requirements: 4.1, 4.2_

- [ ] 15. Make ASCII the default image display mode
  - Change default image-mode from "auto" to "ascii"
  - Ensure ASCII works as primary image display method
  - Test ASCII mode works universally across different terminals
  - _Requirements: 1.2, 3.1_

- [ ] 16. Create comprehensive test suite and documentation
  - Write tests for all ASCII conversion functionality
  - Test ASCII images with various formats and sizes
  - Create user documentation for ASCII image configuration
  - Test end-to-end ASCII image display in web pages
  - _Requirements: 1.4, 5.4_
##
 Future Tasks Based on Lessons Learned

### High Priority (Core Functionality)

- [ ] 17. Implement true image-to-ASCII conversion for loaded images
  - Modify image loading pipeline to populate NetworkBitmap.asciiData when imageMode is ASCII
  - Call ASCII codec during successful image loads, not just failures
  - Store ASCII representation in NetworkBitmap for use by CSS tree building
  - Test with actual web images to generate real ASCII art from image content
  - _Requirements: 1.1, 1.3_

- [ ] 18. Add configuration access to CSS tree building
  - Pass imageMode configuration to TreeFrame or make it globally accessible
  - Enable conditional ASCII art generation based on user preferences
  - Implement proper fallback hierarchy: Graphics → ASCII → Placeholder
  - Test configuration changes affect ASCII art generation
  - _Requirements: 2.1, 3.1_

### Medium Priority (Quality Improvements)

- [ ] 19. Implement basic dithering support (**MOVED FROM TASK 11**)
  - Add simple Floyd-Steinberg dithering algorithm to ASCII codec
  - Improve ASCII art quality for images with gradients
  - Make dithering optional via configuration
  - Test dithering effectiveness on various image types
  - _Requirements: 2.3_

- [ ] 20. Add brightness and contrast adjustments (**MOVED FROM TASK 12**)
  - Implement brightness adjustment (-1.0 to 1.0 range) in ASCII codec
  - Add contrast adjustment (0.0 to 2.0 range)
  - Allow users to fine-tune ASCII art appearance
  - Test adjustments improve visibility of different image types
  - _Requirements: 2.3_

### Low Priority (Polish and Optimization)

- [ ] 21. Optimize ASCII art for terminal display
  - Handle line wrapping and terminal width constraints
  - Improve multi-line ASCII art positioning
  - Add support for color ASCII art in compatible terminals
  - Test ASCII art display across different terminal emulators
  - _Requirements: 1.3, 5.2_

- [ ] 22. Implement NetworkBitmap.asciiData caching
  - Cache ASCII representations in NetworkBitmap objects
  - Avoid regenerating ASCII art for repeated image displays
  - Integrate with existing image caching infrastructure
  - Test caching improves performance on repeated image loads
  - _Requirements: 5.3_

## Architecture Insights for Future Development

### Key Integration Points Discovered
1. **CSS Tree Building** (`src/css/csstree.nim`): Primary ASCII integration point
2. **Image Loading** (`src/html/dom.nim`): Where ASCII codec should be called for loaded images
3. **Configuration Pipeline**: Must flow through Config → BufferConfig → Window → EnvironmentSettings
4. **NetworkBitmap**: Should store ASCII data alongside image data

### Critical Success Factors
1. **Fallback Strategy**: ASCII art works best as universal fallback, not separate mode
2. **Configuration Access**: Need reliable way to access imageMode in CSS tree building
3. **Performance**: ASCII generation should not block page rendering
4. **Integration**: Must work with existing image loading and caching systems

### Technical Debt to Address
1. **Static ASCII Art**: Current implementation generates same ASCII art regardless of image content
2. **Configuration Access**: imageMode not easily accessible from CSS tree building context
3. **Mode Behavior**: ASCII art currently shows for all modes when bitmap unavailable
4. **Codec Integration**: ASCII codec exists but not integrated with successful image loads