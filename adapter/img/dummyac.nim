{.push raises: [].}

import std/posix
import std/strutils

import utils/sandbox
import utils/twtstr

const STDIN_FILENO = 0
const STDOUT_FILENO = 1

proc puts(s: string) =
  if s.len > 0:
    var n = 0
    while n < s.len:
      let i = write(STDOUT_FILENO, unsafeAddr s[n], s.len - n)
      assert i >= 0
      n += i

proc die(s: string) {.noreturn.} =
  puts(s)
  quit(1)

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

proc convertToDummyAscii(rgbaData: seq[uint8], width, height: int): string =
  result = ""
  result.add("[DUMMY-ASCII-CODEC]\n")
  result.add("Image size: " & $width & "x" & $height & "\n")
  result.add("Data size: " & $rgbaData.len & " bytes\n")

proc main() =
  let f = getEnvEmpty("MAPPED_URI_SCHEME").after('+')
  case getEnvEmpty("MAPPED_URI_PATH")
  of "decode":
    if f != "dummyac":
      die("Cha-Control: ConnectionError 1 unknown format " & f)
    
    enterNetworkSandbox()
    
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
      puts("Cha-Image-Dimensions: " & $width & "x" & $height & "\n\n")
      quit(0)
    
    let rgbaData = readAll()
    let asciiArt = convertToDummyAscii(rgbaData, width, height)
    puts("Cha-Image-Dimensions: " & $width & "x" & $height & "\n\n")
    puts(asciiArt)
    
  of "encode":
    die("Cha-Control: ConnectionError 1 encoding not supported for DummyAC\n")
  else:
    die("Cha-Control: ConnectionError 1 not implemented\n")

main()

{.pop.}