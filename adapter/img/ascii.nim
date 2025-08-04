{.push raises: [].}

# ASCII image placeholder system
# This module provides basic ASCII representation for images

type
  AsciiDimensions* = object
    width*: int
    height*: int

  AsciiScaleConfig* = object
    maxWidth*: int
    maxHeight*: int
    terminalWidth*: int
    terminalHeight*: int

  AsciiConfig* = object
    maxWidth*: int32
    maxHeight*: int32

proc getAsciiPlaceholder*(): string =
  ## Returns a simple ASCII placeholder for any image
  return "[IMG]"

proc getAsciiPlaceholderWithDimensions*(width, height: int): string =
  ## Returns an ASCII placeholder showing actual image dimensions
  return "[IMG " & $width & "x" & $height & "]"

# Basic character set for luminance mapping (10 levels as specified in requirements)
const BasicCharset = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@']

proc calculateAsciiDimensions*(pixelWidth, pixelHeight: int, config: AsciiScaleConfig): AsciiDimensions =
  ## Calculate appropriate ASCII art dimensions based on pixel dimensions and configuration
  ## Preserves aspect ratio within 20% error and respects maximum dimensions
  if pixelWidth <= 0 or pixelHeight <= 0:
    return AsciiDimensions(width: 1, height: 1)
  
  # Character aspect ratio compensation
  # Terminal characters are typically taller than they are wide (roughly 2:1 ratio)
  const CharAspectRatio = 2.0  # height/width ratio of terminal characters
  
  # Calculate effective maximum dimensions (leave some margin)
  let maxWidth = min(config.maxWidth, config.terminalWidth - 2)
  let maxHeight = min(config.maxHeight, config.terminalHeight - 2)
  
  # Ensure we have reasonable bounds
  if maxWidth < 1 or maxHeight < 1:
    return AsciiDimensions(width: 1, height: 1)
  
  # Calculate the target aspect ratio accounting for character shape
  let pixelAspectRatio = pixelWidth.float / pixelHeight.float
  let targetAsciiAspectRatio = pixelAspectRatio / CharAspectRatio
  
  # Start with a reasonable base size based on image dimensions
  # Use a scaling factor that gives reasonable results for typical images
  let baseScale = 0.1  # This means ~10 pixels per ASCII character
  var asciiWidth = max(1, int(pixelWidth.float * baseScale + 0.5))
  var asciiHeight = max(1, int(pixelHeight.float * baseScale + 0.5))
  
  # Apply aspect ratio correction to ensure proper proportions
  let currentAspectRatio = asciiWidth.float / asciiHeight.float
  if abs(currentAspectRatio - targetAsciiAspectRatio) > 0.01:  # If aspect ratio is off
    if targetAsciiAspectRatio > currentAspectRatio:
      # Need to increase width or decrease height
      asciiWidth = max(1, int(asciiHeight.float * targetAsciiAspectRatio + 0.5))
    else:
      # Need to increase height or decrease width
      asciiHeight = max(1, int(asciiWidth.float / targetAsciiAspectRatio + 0.5))
  
  # Scale down if we exceed maximum dimensions while preserving aspect ratio
  if asciiWidth > maxWidth or asciiHeight > maxHeight:
    let widthScale = maxWidth.float / asciiWidth.float
    let heightScale = maxHeight.float / asciiHeight.float
    let scale = min(widthScale, heightScale)
    
    asciiWidth = max(1, int(asciiWidth.float * scale + 0.5))
    asciiHeight = max(1, int(asciiHeight.float * scale + 0.5))
  
  # Handle very small images - ensure minimum reasonable size
  if asciiWidth < 2 and asciiHeight < 2:
    if targetAsciiAspectRatio > 1.0:
      # Wide image - make it at least 2 wide
      asciiWidth = 2
      asciiHeight = max(1, int(2.0 / targetAsciiAspectRatio + 0.5))
    else:
      # Tall image - make it at least 2 tall
      asciiHeight = 2
      asciiWidth = max(1, int(2.0 * targetAsciiAspectRatio + 0.5))
    
    # Ensure we don't exceed limits
    asciiWidth = min(asciiWidth, maxWidth)
    asciiHeight = min(asciiHeight, maxHeight)
  
  # Handle extreme aspect ratios that would result in 1-pixel dimensions
  if asciiWidth == 1 and targetAsciiAspectRatio < 0.1:
    # Very tall image - increase width to maintain reasonable aspect ratio
    let minWidth = max(2, int(asciiHeight.float * 0.1 + 0.5))  # At least 10:1 ratio
    asciiWidth = min(minWidth, maxWidth)
  elif asciiHeight == 1 and targetAsciiAspectRatio > 10.0:
    # Very wide image - increase height to maintain reasonable aspect ratio  
    let minHeight = max(2, int(asciiWidth.float * 0.1 + 0.5))  # At least 10:1 ratio
    asciiHeight = min(minHeight, maxHeight)
  
  # Final safety bounds
  asciiWidth = max(1, min(asciiWidth, maxWidth))
  asciiHeight = max(1, min(asciiHeight, maxHeight))
  
  return AsciiDimensions(width: asciiWidth, height: asciiHeight)

proc createAsciiScaleConfig*(terminalWidth, terminalHeight: int, 
                            maxWidth = 80, maxHeight = 24): AsciiScaleConfig =
  ## Create an ASCII scale configuration with terminal dimensions and optional max limits
  return AsciiScaleConfig(
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    terminalWidth: terminalWidth,
    terminalHeight: terminalHeight
  )

proc createAsciiScaleConfig*(terminalWidth, terminalHeight: int, 
                            config: AsciiConfig): AsciiScaleConfig =
  ## Create an ASCII scale configuration from AsciiConfig
  return AsciiScaleConfig(
    maxWidth: int(config.maxWidth),
    maxHeight: int(config.maxHeight),
    terminalWidth: terminalWidth,
    terminalHeight: terminalHeight
  )

proc calculateLuminance*(r, g, b: uint8): uint8 =
  ## Calculate luminance using standard RGB to grayscale conversion
  ## Uses the formula: Y = 0.299*R + 0.587*G + 0.114*B
  let rWeight = uint32(r) * 299
  let gWeight = uint32(g) * 587
  let bWeight = uint32(b) * 114
  return uint8((rWeight + gWeight + bWeight) div 1000)

proc mapLuminanceToChar*(luminance: uint8): char =
  ## Map luminance value (0-255) to ASCII character
  ## Uses basic character set: ' ', '.', '#', '@'
  let index = min(int(luminance) * BasicCharset.len div 256, BasicCharset.high)
  return BasicCharset[index]

proc convertToSingleCharAscii*(pixels: ptr uint8, width, height: int, 
                              scaleConfig: AsciiScaleConfig): string =
  ## Convert entire image to single ASCII character based on average brightness
  ## pixels: RGBA pixel data (4 bytes per pixel)
  ## Returns single character repeated to approximate image dimensions with proper scaling
  if pixels == nil or width <= 0 or height <= 0:
    return getAsciiPlaceholder()
  
  var totalLuminance: uint64 = 0
  let pixelCount = width * height
  
  # Calculate average luminance across all pixels
  for i in 0 ..< pixelCount:
    let pixelOffset = i * 4  # RGBA = 4 bytes per pixel
    let r = cast[ptr UncheckedArray[uint8]](pixels)[pixelOffset]
    let g = cast[ptr UncheckedArray[uint8]](pixels)[pixelOffset + 1]
    let b = cast[ptr UncheckedArray[uint8]](pixels)[pixelOffset + 2]
    # Skip alpha channel for luminance calculation
    
    totalLuminance += uint64(calculateLuminance(r, g, b))
  
  let avgLuminance = uint8(totalLuminance div uint64(pixelCount))
  let asciiChar = mapLuminanceToChar(avgLuminance)
  
  # Calculate proper ASCII dimensions using the new scaling system
  let dimensions = calculateAsciiDimensions(width, height, scaleConfig)
  
  # Create ASCII representation
  var asciiResult = ""
  for y in 0 ..< dimensions.height:
    for x in 0 ..< dimensions.width:
      asciiResult.add(asciiChar)
    if y < dimensions.height - 1:  # Don't add newline after last row
      asciiResult.add('\n')
  
  return asciiResult

# Backward compatibility version with default scaling
proc convertToSingleCharAscii*(pixels: ptr uint8, width, height: int): string =
  ## Convert entire image to single ASCII character with default scaling configuration
  let defaultConfig = AsciiScaleConfig(
    maxWidth: 80,
    maxHeight: 24,
    terminalWidth: 80,
    terminalHeight: 24
  )
  return convertToSingleCharAscii(pixels, width, height, defaultConfig)

proc convertToAscii*(pixels: ptr uint8, width, height: int, 
                    scaleConfig: AsciiScaleConfig): string =
  ## Convert image to ASCII art using luminance-based pixel-to-character conversion
  ## Each pixel region is converted to corresponding ASCII character based on luminance
  ## pixels: RGBA pixel data (4 bytes per pixel)
  ## Returns multi-line ASCII art representation
  if pixels == nil or width <= 0 or height <= 0:
    return getAsciiPlaceholder()
  
  # Calculate proper ASCII dimensions
  let dimensions = calculateAsciiDimensions(width, height, scaleConfig)
  
  # Calculate how many pixels each ASCII character represents
  let pixelsPerCharX = width.float / dimensions.width.float
  let pixelsPerCharY = height.float / dimensions.height.float
  
  var asciiResult = ""
  
  # Process each ASCII character position
  for asciiY in 0 ..< dimensions.height:
    for asciiX in 0 ..< dimensions.width:
      # Calculate the pixel region this ASCII character represents
      let startPixelX = int(asciiX.float * pixelsPerCharX)
      let endPixelX = min(int((asciiX + 1).float * pixelsPerCharX), width)
      let startPixelY = int(asciiY.float * pixelsPerCharY)
      let endPixelY = min(int((asciiY + 1).float * pixelsPerCharY), height)
      
      # Calculate average luminance for this region
      var totalLuminance: uint64 = 0
      var pixelCount = 0
      
      for pixelY in startPixelY ..< endPixelY:
        for pixelX in startPixelX ..< endPixelX:
          let pixelOffset = (pixelY * width + pixelX) * 4  # RGBA = 4 bytes per pixel
          let r = cast[ptr UncheckedArray[uint8]](pixels)[pixelOffset]
          let g = cast[ptr UncheckedArray[uint8]](pixels)[pixelOffset + 1]
          let b = cast[ptr UncheckedArray[uint8]](pixels)[pixelOffset + 2]
          # Skip alpha channel for luminance calculation
          
          totalLuminance += uint64(calculateLuminance(r, g, b))
          inc pixelCount
      
      # Convert average luminance to ASCII character
      let avgLuminance = if pixelCount > 0: uint8(totalLuminance div uint64(pixelCount)) else: 0'u8
      let asciiChar = mapLuminanceToChar(avgLuminance)
      asciiResult.add(asciiChar)
    
    # Add newline after each row except the last
    if asciiY < dimensions.height - 1:
      asciiResult.add('\n')
  
  return asciiResult

proc convertToAscii*(pixels: ptr uint8, width, height: int): string =
  ## Convert image to ASCII art with default scaling configuration
  let defaultConfig = AsciiScaleConfig(
    maxWidth: 80,
    maxHeight: 24,
    terminalWidth: 80,
    terminalHeight: 24
  )
  return convertToAscii(pixels, width, height, defaultConfig)

{.pop.} # raises: []