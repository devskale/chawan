{.push raises: [].}

# ASCII image placeholder system
# This module provides basic ASCII representation for images

proc getAsciiPlaceholder*(): string =
  ## Returns a simple ASCII placeholder for any image
  return "[IMG]"

proc getAsciiPlaceholderWithDimensions*(width, height: int): string =
  ## Returns an ASCII placeholder showing actual image dimensions
  return "[IMG " & $width & "x" & $height & "]"

# Basic character set for luminance mapping
const BasicCharset = [' ', '.', '#', '@']

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

proc convertToSingleCharAscii*(pixels: ptr uint8, width, height: int): string =
  ## Convert entire image to single ASCII character based on average brightness
  ## pixels: RGBA pixel data (4 bytes per pixel)
  ## Returns single character repeated to approximate image dimensions
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
  
  # Calculate reasonable ASCII dimensions (scale down from pixel dimensions)
  # Use a simple scaling factor to make ASCII art readable
  let maxAsciiWidth = 80
  let maxAsciiHeight = 24
  
  var asciiWidth = width div 8  # Approximate character width scaling
  var asciiHeight = height div 16  # Approximate character height scaling
  
  # Ensure minimum size
  if asciiWidth < 1: asciiWidth = 1
  if asciiHeight < 1: asciiHeight = 1
  
  # Respect maximum dimensions
  if asciiWidth > maxAsciiWidth: asciiWidth = maxAsciiWidth
  if asciiHeight > maxAsciiHeight: asciiHeight = maxAsciiHeight
  
  # Create ASCII representation
  var asciiResult = ""
  for y in 0 ..< asciiHeight:
    for x in 0 ..< asciiWidth:
      asciiResult.add(asciiChar)
    if y < asciiHeight - 1:  # Don't add newline after last row
      asciiResult.add('\n')
  
  return asciiResult

{.pop.} # raises: []