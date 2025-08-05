type
  NetworkBitmap* = ref object
    width*: int
    height*: int
    cacheId*: int
    imageId*: int
    contentType*: string
    asciiData*: string  # Store ASCII art representation for ASCII mode
