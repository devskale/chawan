# Design Document

## Overview

The ASCII image viewer feature adds a new image display mode to Chawan that converts images to ASCII art representations. This provides universal image viewing capability that works in any terminal emulator without requiring special graphics protocol support. The feature integrates with Chawan's existing image processing pipeline and codec system, adding "ascii" as a new display mode alongside "sixel" and "kitty".

## Architecture

### Actual Integration Points (Discovered Through Implementation)

The ASCII image viewer integrates with Chawan's architecture differently than originally planned:

1. **CSS Tree Building** (`src/css/csstree.nim`): **PRIMARY INTEGRATION POINT** - ASCII art is generated in the `addImage()` function when NetworkBitmap is unavailable
2. **Configuration System**: Extended `EnvironmentSettings` and `DisplayConfig` to support `imageMode: Option[ImageMode]`
3. **Image Loading Pipeline**: Modified `loadResource()` in `src/html/dom.nim` to call ASCII codec when imageMode is ASCII
4. **Fallback Mechanism**: ASCII art serves as universal fallback when images fail to load, regardless of configured image mode

### Revised High-Level Flow

```
Image Element → CSS Tree Building → Check NetworkBitmap → 
  ├─ Available: Create Image Node
  └─ Unavailable: Generate ASCII Art → Add as Text Node → Render
```

**Key Discovery**: ASCII integration happens during CSS tree construction, not during rendering. The `addImage()` function in `csstree.nim` is the critical integration point.

### Architecture Lessons Learned

1. **Image Placeholders**: The original `[img]` placeholder was generated in CSS tree building, not rendering
2. **Fallback Strategy**: ASCII art works best as a universal fallback rather than a separate rendering mode
3. **Configuration Flow**: imageMode must be passed through: Config → BufferConfig → Window → EnvironmentSettings
4. **Integration Complexity**: The image loading pipeline is more complex than initially understood, with multiple phases and fallback mechanisms

## Components and Interfaces

### 1. ASCII Image Converter (`adapter/img/ascii.nim`)

**Purpose**: Core component that converts RGBA pixel data to ASCII art

**Key Functions**:
- `convertToAscii(pixels: ptr uint8, width, height: int, config: AsciiConfig): string`
- `calculateLuminance(r, g, b: uint8): uint8`
- `mapLuminanceToChar(luminance: uint8, charset: AsciiCharset): char`
- `applyDithering(pixels: var seq[uint8], width, height: int, algorithm: DitheringAlgorithm)`

**Interfaces**:
```nim
type
  AsciiCharset* = enum
    acBasic      # " .:-=+*#%@"
    acExtended   # includes more ASCII chars
    acBlocks     # Unicode block characters

  DitheringAlgorithm* = enum
    daNone
    daFloydSteinberg
    daOrdered

  AsciiConfig* = object
    charset*: AsciiCharset
    maxWidth*: int
    maxHeight*: int
    dithering*: DitheringAlgorithm
    brightness*: float32  # -1.0 to 1.0
    contrast*: float32    # 0.0 to 2.0
```

### 2. ASCII Image Codec (`adapter/img/ascii_codec.nim`)

**Purpose**: CGI-style program that implements the img-codec interface for ASCII conversion

**Key Functions**:
- Reads RGBA data from stdin
- Applies ASCII conversion using configured parameters
- Outputs ASCII text representation
- Handles dimension and configuration headers

**Headers Supported**:
- Input: `Cha-Image-Dimensions`, `Cha-Ascii-Config`
- Output: `Cha-Image-Dimensions` (character dimensions)

### 3. Configuration Extensions (`src/config/config.nim`)

**Purpose**: Extends existing configuration system to support ASCII image settings

**New Configuration Options**:
```toml
[display]
image-mode = "ascii"  # New option alongside "auto", "sixel", "kitty", "none"
ascii-charset = "basic"  # "basic", "extended", "blocks"
ascii-max-width = 80
ascii-max-height = 24
ascii-dithering = "floyd-steinberg"  # "none", "floyd-steinberg", "ordered"
ascii-brightness = 0.0  # -1.0 to 1.0
ascii-contrast = 1.0    # 0.0 to 2.0
```

### 4. CSS Tree Integration (`src/css/csstree.nim`) - **ACTUAL PRIMARY COMPONENT**

**Purpose**: Generates ASCII art during CSS tree building when images are unavailable

**Key Implementation**:
```nim
proc addImage(frame: var TreeFrame; bmp: NetworkBitmap) =
  if bmp != nil and bmp.cacheId != -1:
    # Create proper image node
    frame.add(StyledNode(t: stImage, bmp: bmp, ...))
  else:
    # Generate ASCII art fallback
    let asciiArt = generateAsciiArt()
    frame.addText(asciiArt)
```

**Critical Insight**: This is where ASCII images are actually created, not in the rendering phase.

### 5. Configuration Pipeline Extensions

**Purpose**: Pass imageMode configuration through the system

**Key Changes**:
- Extended `EnvironmentSettings` with `imageMode*: Option[ImageMode]`
- Modified `newWindow()` to accept imageMode parameter
- Updated buffer creation to pass `config.imageMode` to window
- Enabled image loading pipeline to check imageMode for ASCII codec calls

## Data Models

### ASCII Image Representation

ASCII images are represented as multi-line strings with embedded formatting information:

```nim
type
  AsciiImage* = object
    content*: string        # The ASCII art content
    width*: int            # Character width
    height*: int           # Character height (lines)
    originalWidth*: int    # Original pixel width
    originalHeight*: int   # Original pixel height
```

### Character Mapping

The system uses predefined character sets for luminance mapping:

```nim
const
  BasicCharset = " .:-=+*#%@"
  ExtendedCharset = " .'`^\",:;Il!i><~+_-?][}{1)(|\\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"
  BlockCharset = " ░▒▓█"
```

## Error Handling

### Graceful Degradation

1. **Invalid Image Data**: Fall back to placeholder text like "[Invalid Image]"
2. **Memory Constraints**: Automatically reduce image dimensions if conversion would exceed memory limits
3. **Configuration Errors**: Use default ASCII settings if custom configuration is invalid
4. **Terminal Size Limits**: Automatically scale images to fit within terminal dimensions

### Error Reporting

- Use existing Chawan error reporting mechanisms
- Log ASCII conversion errors to debug output
- Provide user-friendly error messages for configuration issues

## Testing Strategy

### Unit Tests

1. **ASCII Conversion Logic**:
   - Test luminance calculation accuracy
   - Verify character mapping for different charsets
   - Test dithering algorithm implementations
   - Validate aspect ratio preservation

2. **Configuration Parsing**:
   - Test all ASCII configuration options
   - Verify default value handling
   - Test invalid configuration handling

3. **Integration Tests**:
   - Test ASCII mode selection in image-mode "auto"
   - Verify ASCII images render correctly in different terminal sizes
   - Test ASCII images with various image formats (PNG, JPEG, GIF, WebP, SVG)

### Performance Tests

1. **Conversion Speed**: Ensure ASCII conversion completes within 500ms for typical web images
2. **Memory Usage**: Verify memory usage remains reasonable for large images
3. **Caching**: Test that converted ASCII images are properly cached and reused

### Visual Tests

1. **Character Set Quality**: Compare visual quality across different character sets
2. **Dithering Effectiveness**: Evaluate dithering algorithms for different image types
3. **Aspect Ratio**: Verify images maintain proper proportions in ASCII form

## Implementation Considerations

### Performance Optimizations

1. **Lazy Conversion**: Only convert images to ASCII when they need to be displayed
2. **Caching**: Cache ASCII representations to avoid repeated conversion
3. **Streaming**: Process large images in chunks to reduce memory usage
4. **Parallel Processing**: Use multiple threads for dithering operations on large images

### Memory Management

1. **Bounded Memory**: Limit maximum image size for ASCII conversion
2. **Cleanup**: Properly deallocate temporary buffers used during conversion
3. **Reuse**: Reuse conversion buffers across multiple images

### Terminal Compatibility

1. **Character Width**: Handle terminals with different character width assumptions
2. **Unicode Support**: Gracefully fall back to basic ASCII if Unicode block characters aren't supported
3. **Color Support**: Prepare for future color ASCII support while maintaining monochrome compatibility

### Integration with Existing Systems

1. **Codec System**: Reuse existing image decoding infrastructure
2. **Configuration**: Extend existing configuration system without breaking changes
3. **Rendering**: Integrate with existing text rendering without disrupting other display modes
4. **Caching**: Use existing image caching mechanisms for ASCII representations