# Design Document

## Overview

The ASCII image rendering feature extends Chawan's existing image processing pipeline to support text-based image display. This enables full browser functionality on terminals that don't support modern image protocols like Sixel or Kitty graphics.

The design leverages Chawan's existing img-codec+ URI scheme system by adding a new ASCII codec that converts RGBA image data to text representations. The feature integrates seamlessly with the current image mode detection and configuration system.

## Architecture

### High-Level Flow

1. **Image Detection**: When `display.image-mode` is set to "ascii" or auto-detected for terminals without graphics support
2. **Image Processing**: Images are decoded using existing codecs (stbi, jebp, nanosvg) to RGBA data
3. **ASCII Conversion**: A new `img-codec+x-ascii` codec converts RGBA data to ASCII text representation
4. **Terminal Display**: ASCII text is rendered through the existing terminal canvas system

### Integration Points

- **Configuration System**: Extends `ImageMode` enum with `imAscii = "ascii"`
- **Image Codec Pipeline**: Adds new ASCII codec following existing patterns
- **Terminal Canvas**: ASCII images render as text cells in the terminal grid
- **Caching System**: ASCII representations are cached like other image formats

## Components and Interfaces

### 1. Configuration Extension

**File**: `src/config/conftypes.nim`
- Extend `ImageMode` enum to include `imAscii = "ascii"`
- Add ASCII-specific configuration options

**New Configuration Options**:
```toml
[display]
image-mode = "ascii"  # or "auto" with fallback
ascii-width = 80      # max width for ASCII images
ascii-charset = "extended"  # "basic", "extended", "unicode"
ascii-quality = 50    # 1-100, affects character density
```

### 2. ASCII Image Codec

**File**: `adapter/img/ascii.nim`
- Implements the img-codec+x-ascii:encode interface
- Converts RGBA bitmap data to ASCII text representation
- Supports multiple character sets and quality levels

**Interface**:
- **Input**: RGBA bitmap data via stdin (following existing codec pattern)
- **Headers**: 
  - `Cha-Image-Dimensions`: source image dimensions
  - `Cha-Image-Quality`: ASCII quality level (1-100)
  - `Cha-Image-Ascii-Width`: target width in characters
- **Output**: ASCII text representation with newlines

### 3. ASCII Conversion Algorithm

**Character Sets**:
- **Basic**: ` .:-=+*#%@` (10 characters, high compatibility)
- **Extended**: ` .'`^",:;Il!i><~+_-?][}{1)(|\/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$` (70 characters)
- **Unicode**: Block characters `█▉▊▋▌▍▎▏` for higher fidelity

**Conversion Process**:
1. **Resize**: Scale image to target ASCII dimensions maintaining aspect ratio
2. **Luminance**: Convert RGB to grayscale using standard luminance formula
3. **Character Mapping**: Map brightness values to character set
4. **Dithering**: Optional Floyd-Steinberg dithering for better quality

### 4. Terminal Integration

**File**: `src/local/term.nim`
- Extend image mode detection to include ASCII
- Handle ASCII images as text in the terminal canvas
- Manage ASCII image positioning and display

**Changes**:
- Add `imAscii` handling in image mode detection
- ASCII images render as regular text cells
- No special terminal protocols needed

### 5. URI Method Mapping

**File**: `res/urimethodmap`
- Add mapping: `img-codec+x-ascii: cgi-bin:ascii`

## Data Models

### ASCII Image Representation

```nim
type
  AsciiImage* = object
    width*: int        # width in characters
    height*: int       # height in characters  
    data*: string      # ASCII representation with embedded newlines
    charset*: AsciiCharset
    quality*: int      # quality level used for generation

  AsciiCharset* = enum
    acBasic = "basic"
    acExtended = "extended" 
    acUnicode = "unicode"
```

### Configuration Extensions

```nim
type
  ImageMode* = enum
    imNone = "none"
    imSixel = "sixel"
    imKitty = "kitty"
    imAscii = "ascii"  # NEW

  DisplayConfig* = object
    # ... existing fields ...
    asciiWidth*: Option[int32]
    asciiCharset*: Option[AsciiCharset]
    asciiQuality*: Option[int32]
```

## Error Handling

### Graceful Degradation
- **Codec Failure**: Display placeholder text with image dimensions and type
- **Memory Limits**: Automatically reduce ASCII image size for large images
- **Invalid Configuration**: Fall back to basic ASCII charset and default quality

### Error Messages
- Clear error reporting through existing Cha-Control headers
- Fallback ASCII representations for unsupported image formats
- Informative placeholder text when conversion fails

### Fallback Strategy
```
1. Try ASCII conversion with specified quality
2. If memory/size limits exceeded, reduce quality and retry
3. If conversion still fails, show text placeholder: "[IMAGE: type WxH]"
4. Log errors through existing error handling system
```

## Testing Strategy

### Unit Tests
- **ASCII Conversion**: Test character mapping algorithms with known inputs
- **Configuration**: Verify ASCII mode detection and configuration parsing
- **Integration**: Test codec interface compliance with existing patterns

### Integration Tests
- **End-to-End**: Load web pages with images in ASCII mode
- **Performance**: Measure ASCII conversion time for various image sizes
- **Compatibility**: Test with different terminal types and sizes

### Test Cases
1. **Basic Functionality**: Simple images convert to recognizable ASCII
2. **Aspect Ratio**: ASCII images maintain proportional dimensions
3. **Character Sets**: All supported character sets produce valid output
4. **Quality Levels**: Different quality settings produce appropriate detail
5. **Large Images**: Memory and performance handling for large images
6. **Edge Cases**: Empty images, single-pixel images, very wide/tall images

### Performance Benchmarks
- Target: ASCII conversion should complete within 100ms for typical web images
- Memory: ASCII codec should use minimal memory overhead
- Caching: ASCII representations should cache and reuse efficiently

## Implementation Phases

### Phase 1: Core ASCII Codec
- Implement basic ASCII conversion algorithm
- Add img-codec+x-ascii URI mapping
- Support basic character set only
- Simple brightness-to-character mapping

### Phase 2: Configuration Integration  
- Extend ImageMode enum with imAscii
- Add ASCII-specific configuration options
- Implement auto-detection fallback to ASCII mode
- Add configuration validation

### Phase 3: Enhanced Quality
- Implement extended and Unicode character sets
- Add Floyd-Steinberg dithering option
- Optimize conversion algorithm performance
- Add quality-based scaling

### Phase 4: Polish and Testing
- Comprehensive test suite
- Performance optimization
- Error handling improvements
- Documentation and examples

## Security Considerations

- **Memory Safety**: Bounds checking for image dimensions and ASCII buffer allocation
- **Resource Limits**: Prevent excessive memory usage with large images
- **Input Validation**: Validate image dimensions and quality parameters
- **Sandboxing**: ASCII codec runs in same sandbox as other image codecs

## Performance Considerations

### Optimization Strategies
- **Lazy Loading**: Generate ASCII only when images are visible
- **Caching**: Cache ASCII representations to avoid regeneration
- **Streaming**: Process large images in chunks to reduce memory usage
- **Parallel Processing**: Convert multiple images concurrently when possible

### Memory Management
- **Bounded Allocation**: Limit ASCII image size based on terminal dimensions
- **Efficient Storage**: Store ASCII as compressed strings when cached
- **Cleanup**: Proper cleanup of temporary buffers during conversion

### Scalability
- **Large Images**: Automatic downscaling before ASCII conversion
- **Multiple Images**: Queue-based processing to prevent resource exhaustion
- **Terminal Size**: Adaptive sizing based on current terminal dimensions