{.push raises: [].}

import std/os
import std/posix
import std/strutils

import ascii
import io/dynstream
import types/opt
import utils/sandbox
import utils/twtstr

const STDIN_FILENO = 0
const STDOUT_FILENO = 1

proc writeAll(data: pointer; size: int) =
  var n = 0
  while n < size:
    let i = write(STDOUT_FILENO, addr cast[ptr UncheckedArray[uint8]](data)[n],
      int(size) - n)
    assert i >= 0
    n += i

proc puts(s: string) =
  if s.len > 0:
    writeAll(unsafeAddr s[0], s.len)

proc die(s: string) {.noreturn.} =
  puts(s)
  quit(1)

proc parseDimensions(s: string): (int, int) =
  let parts = s.split('x')
  if parts.len != 2:
    die("Cha-Control: ConnectionError InternalError wrong dimensions")
  let w = parseIntP(parts[0]).get(-1)
  let h = parseIntP(parts[1]).get(-1)
  if w < 0 or h < 0:
    die("Cha-Control: ConnectionError InternalError wrong dimensions")
  return (w, h)

proc main() =
  case getEnv("MAPPED_URI_PATH")
  of "decode":
    # ASCII codec doesn't support decoding - it only converts to ASCII
    die("Cha-Control: ConnectionError InternalError ASCII codec decode not supported\n")
  of "encode":
    enterNetworkSandbox()
    
    var width = 0
    var height = 0
    var asciiConfig = AsciiConfig(maxWidth: 80, maxHeight: 24)
    var terminalWidth = 80
    var terminalHeight = 24
    
    # Parse headers
    for hdr in getEnv("REQUEST_HEADERS").split('\n'):
      let value = hdr.after(':').strip()
      case hdr.until(':')
      of "Cha-Image-Dimensions":
        (width, height) = parseDimensions(value)
      of "Cha-Ascii-Max-Width":
        let w = parseIntP(value).get(-1)
        if w > 0:
          asciiConfig.maxWidth = int32(w)
      of "Cha-Ascii-Max-Height":
        let h = parseIntP(value).get(-1)
        if h > 0:
          asciiConfig.maxHeight = int32(h)
      of "Cha-Terminal-Width":
        let w = parseIntP(value).get(-1)
        if w > 0:
          terminalWidth = w
      of "Cha-Terminal-Height":
        let h = parseIntP(value).get(-1)
        if h > 0:
          terminalHeight = h
    
    if width <= 0 or height <= 0:
      die("Cha-Control: ConnectionError InternalError invalid dimensions\n")
    
    # Read RGBA pixel data from stdin
    let pixelCount = width * height
    let dataSize = pixelCount * 4  # RGBA = 4 bytes per pixel
    let ps = newPosixStream(STDIN_FILENO)
    let src = ps.readDataLoopOrMmap(dataSize)
    if src == nil:
      die("Cha-Control: ConnectionError InternalError failed to read input\n")
    
    # Create ASCII scale configuration
    let scaleConfig = createAsciiScaleConfig(terminalWidth, terminalHeight, asciiConfig)
    
    # Convert to ASCII
    let asciiResult = convertToAscii(cast[ptr uint8](src.p), width, height, scaleConfig)
    
    # Calculate ASCII dimensions for output headers
    let asciiDimensions = calculateAsciiDimensions(width, height, scaleConfig)
    
    # Output headers
    puts("Cha-Image-Dimensions: " & $asciiDimensions.width & "x" & $asciiDimensions.height & "\n")
    puts("Cha-Image-Format: ascii\n")
    puts("\n")
    
    # Output ASCII data
    puts(asciiResult)
    
    # Clean up
    deallocMem(src)
  else:
    die("Cha-Control: ConnectionError InternalError not implemented\n")

main()

{.pop.} # raises: []