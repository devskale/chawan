{.push raises: [].}

# ASCII image placeholder system
# This module provides basic ASCII representation for images

proc getAsciiPlaceholder*(): string =
  ## Returns a simple ASCII placeholder for any image
  return "[IMG]"

proc getAsciiPlaceholderWithDimensions*(width, height: int): string =
  ## Returns an ASCII placeholder showing actual image dimensions
  return "[IMG " & $width & "x" & $height & "]"

{.pop.} # raises: []