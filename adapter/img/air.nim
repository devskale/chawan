{.push raises: [].}

import std/posix
import std/strutils

import utils/sandbox
import utils/twtstr

const STDIN_FILENO = 0
const STDOUT_FILENO = 1

# ASCII character set ordered by density (from sparse to dense)
const AsciiChars = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@']

# Convert RGB to grayscale using luminance formula
proc toGrayscale(r, g, b: uint8): uint8 =
  # Standard luminance formula: 0.299*R + 0.587*G + 0.114*B
  return uint8(0.299 * float(r) + 0.587 * float(g) + 0.114 * float(b))

# Map grayscale value to ASCII character
proc grayToAscii(gray: uint8): char =
  let index = int(float(gray) * float(AsciiChars.len - 1) / 255.0)
  return AsciiChars[index]

# Write string to stdout
proc puts(s: string) =
  if s.len > 0:
    var n = 0
    while n < s.len:
      let i = write(STDOUT_FILENO, unsafeAddr s[n], s.len - n)
      assert i >= 0
      n += i

# Exit with error message
proc die(s: string) {.noreturn.} =
  puts(s)
  quit(1)

# Read all data from stdin
proc readAll(): seq[uint8] =
  var buffer = newSeq[uint8](4096)
  var data = newSeq[uint8]()
  var n: int
  
  while true:
    n = read(STDIN_FILENO, unsafeAddr buffer[0], buffer.len)
    if n <= 0:
      break
    data.add(buffer[0..<n])
  
  return data

# Convert RGBA data to ASCII art
proc convertToAscii(rgbaData: seq[uint8], width, height: int): string =
  result = ""
  
  # Process pixel data row by row
  for y in 0..<height:
    for x in 0..<width:
      let idx = (y * width + x) * 4  # 4 bytes per pixel (RGBA)
      if idx + 3 < rgbaData.len:
        let r = rgbaData[idx]
        let g = rgbaData[idx + 1]
        let b = rgbaData[idx + 2]
        let a = rgbaData[idx + 3]
        
        # Handle transparency (simple approach: transparent pixels become spaces)
        if a < 128:  # Less than 50% opacity
          result.add(' ')
        else:
          let gray = toGrayscale(r, g, b)
          result.add(grayToAscii(gray))
      else:
        result.add(' ')  # Default to space if data is missing
    
    # Add newline at the end of each row
    result.add('\n')

# Main function
proc main() =
  let f = getEnvEmpty("MAPPED_URI_SCHEME").after('+')
  case getEnvEmpty("MAPPED_URI_PATH")
  of "decode":
    # For AIR mode, we don't actually decode image formats
    # Instead, we convert RGBA data to ASCII art
    if f != "air":
      die("Cha-Control: ConnectionError 1 unknown format " & f)
    
    enterNetworkSandbox()
    
    # Parse headers
    var width = 0
    var height = 0
    var infoOnly = false
    
    for hdr in getEnvEmpty("REQUEST_HEADERS").split('\n'):
      let parts = hdr.split(':')
      if parts.len >= 2:
        let key = parts[0].strip()
        let value = parts[1].strip()
        
        if key == "Cha-Image-Info-Only":
          infoOnly = (value == "1")
        elif key == "Cha-Image-Dimensions":
          let dims = value.split('x')
          if dims.len == 2:
            try:
              width = parseInt(dims[0])
              height = parseInt(dims[1])
            except ValueError:
              die("Cha-Control: ConnectionError 1 invalid dimensions\n")
    
    if width <= 0 or height <= 0:
      die("Cha-Control: ConnectionError 1 invalid dimensions\n")
    
    if infoOnly:
      # Just return the dimensions
      puts("Cha-Image-Dimensions: " & $width & "x" & $height & "\n\n")
      quit(0)
    
    # Read RGBA data from stdin
    let rgbaData = readAll()
    
    # Convert to ASCII art
    let asciiArt = convertToAscii(rgbaData, width, height)
    
    # Output the ASCII art
    puts("Cha-Image-Dimensions: " & $width & "x" & $height & "\n\n")
    puts(asciiArt)
    
  of "encode":
    # AIR mode doesn't support encoding
    die("Cha-Control: ConnectionError 1 encoding not supported for AIR\n")
  else:
    die("Cha-Control: ConnectionError 1 not implemented\n")

main()

{.pop.} # raises: []