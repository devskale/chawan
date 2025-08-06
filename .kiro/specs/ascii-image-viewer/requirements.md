# Requirements Document

## Introduction

This feature adds ASCII-based image viewing capability to Chawan that works universally across all terminal emulators without requiring external libraries or special terminal features. The ASCII image viewer provides fallback ASCII art representations when images cannot be loaded or displayed through graphics protocols, ensuring visual content is always accessible in any terminal environment.

## Key Architectural Insights Discovered

Through implementation, we discovered that Chawan's image handling occurs in multiple phases:

1. **CSS Tree Building** (`src/css/csstree.nim`): Where image placeholders are initially generated when NetworkBitmap is unavailable
2. **Image Loading** (`src/html/dom.nim`): Where images are fetched and decoded via codec system  
3. **Rendering** (`src/css/render.nim`): Where loaded images are positioned and displayed

The primary integration point for ASCII images is in the CSS tree building phase, not the rendering phase as originally assumed.

## Requirements

### Requirement 1

**User Story:** As a Chawan user, I want to view images as ASCII art when images cannot be loaded, so that I can see visual content universally without relying on terminal-specific graphics protocols.

#### Acceptance Criteria

1. WHEN an image is encountered but NetworkBitmap is unavailable THEN the system SHALL generate ASCII art representation instead of simple text placeholders
2. WHEN display.image-mode is set to "ascii" THEN the system SHALL prefer ASCII rendering over graphics protocols
3. WHEN displaying ASCII images THEN the system SHALL provide recognizable visual representations
4. WHEN images fail to load THEN the system SHALL fall back to ASCII art rather than showing broken image indicators

**Implementation Note:** ASCII art is generated in `addImage()` function in `src/css/csstree.nim` when `bmp == nil or bmp.cacheId == -1`.

### Requirement 2

**User Story:** As a Chawan user, I want ASCII image quality to be configurable, so that I can balance between visual detail and terminal space usage.

#### Acceptance Criteria

1. WHEN configuring ASCII image settings THEN the system SHALL provide options for different ASCII character sets (basic, extended, block characters)
2. WHEN setting image dimensions THEN the system SHALL allow configuration of maximum width and height for ASCII images
3. WHEN choosing rendering quality THEN the system SHALL provide options for different dithering algorithms (none, Floyd-Steinberg, ordered)
4. WHEN displaying images THEN the system SHALL respect user-configured brightness and contrast adjustments

### Requirement 3

**User Story:** As a Chawan user, I want ASCII images to integrate seamlessly with existing image handling, so that the feature works transparently with current workflows.

#### Acceptance Criteria

1. WHEN images are successfully loaded THEN the system SHALL display them using the configured graphics protocol (Sixel, Kitty, etc.)
2. WHEN images fail to load or graphics protocols are unavailable THEN the system SHALL automatically fall back to ASCII rendering
3. WHEN display.image-mode is "ascii" THEN the system SHALL generate ASCII art even for successfully loaded images
4. WHEN processing images THEN the system SHALL integrate with existing CSS tree building and rendering pipeline

**Implementation Note:** The fallback mechanism is built into the CSS tree building phase, ensuring ASCII art is always available regardless of image loading success.

### Requirement 4

**User Story:** As a Chawan developer, I want the ASCII image system to be self-contained, so that it doesn't introduce external dependencies or complicate the build process.

#### Acceptance Criteria

1. WHEN building Chawan THEN the ASCII image feature SHALL not require additional external libraries
2. WHEN implementing image conversion THEN the system SHALL use only existing image processing capabilities in Chawan
3. WHEN adding ASCII rendering THEN the system SHALL integrate with existing image adapter architecture
4. WHEN processing images THEN the system SHALL reuse existing color space conversion and scaling utilities

### Requirement 5

**User Story:** As a Chawan user, I want ASCII images to be performant, so that page loading and scrolling remain responsive.

#### Acceptance Criteria

1. WHEN converting images to ASCII THEN the system SHALL complete conversion within reasonable time limits (< 500ms for typical web images)
2. WHEN displaying multiple ASCII images THEN the system SHALL not significantly impact page rendering performance
3. WHEN caching ASCII representations THEN the system SHALL store converted images to avoid repeated processing
4. WHEN memory usage exceeds limits THEN the system SHALL implement appropriate cleanup and garbage collection