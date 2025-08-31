# ASCII image codec - dummy implementation
# Converts images to ASCII text representations for terminal display

{.push raises: [].}

import std/posix
import std/strutils

import io/dynstream
import types/opt
import utils/sandbox
import utils/twtstr

proc puts(os: PosixStream; s: string) =
  doAssert os.writeDataLoop(s)

proc die(os: PosixStream; s: string) {.noreturn.} =
  os.puts(s)
  quit(1)

proc parseDimensions(os: PosixStream; s: string; allowZero: bool): (int, int) =
  let s = s.split('x')
  if s.len != 2:
    os.die("Cha-Control: ConnectionError InternalError wrong dimensions")
  let w = parseIntP(s[0]).get(-1)
  let h = parseIntP(s[1]).get(-1)
  if w < 0 or h < 0 or not allowZero and (w == 0 or h == 0):
    os.die("Cha-Control: ConnectionError InternalError wrong dimensions")
  return (w, h)

proc encode(os: PosixStream; width, height: int) =
  # Generate dummy ASCII placeholder
  let placeholder = "[IMG " & $width & "x" & $height & "]"
  
  # Output the ASCII representation
  os.puts(placeholder)

proc main() =
  let os = newPosixStream(STDOUT_FILENO)
  if getEnvEmpty("MAPPED_URI_PATH") == "encode":
    var width = 0
    var height = 0
    
    # Parse headers to get image dimensions
    for hdr in getEnvEmpty("REQUEST_HEADERS").split('\n'):
      let s = hdr.after(':').strip()
      case hdr.until(':')
      of "Cha-Image-Dimensions":
        (width, height) = os.parseDimensions(s, allowZero = false)
    
    if width == 0 or height == 0:
      quit(0) # done...
    
    # Read input data (even though we don't use it for dummy implementation)
    let n = width * height
    let L = n * 4
    let ps = newPosixStream(STDIN_FILENO)
    let src = ps.readDataLoopOrMmap(L)
    if src == nil:
      os.die("Cha-Control: ConnectionError InternalError failed to read input")
    
    enterNetworkSandbox() # don't swallow stat
    
    # Generate dummy ASCII output
    os.encode(width, height)
    
    deallocMem(src)
  else:
    os.die("Cha-Control: ConnectionError InternalError not implemented\n")

main()

{.pop.} # raises: []