import adapter/img/ascii

# Create a simple 4x4 test image with RGBA data
# Each pixel is 4 bytes: R, G, B, A
let testData = [
  # Row 1: Black to white gradient
  0'u8, 0, 0, 255,     # Black
  85'u8, 85, 85, 255,  # Dark gray
  170'u8, 170, 170, 255, # Light gray
  255'u8, 255, 255, 255, # White
  
  # Row 2: Same gradient
  0'u8, 0, 0, 255,
  85'u8, 85, 85, 255,
  170'u8, 170, 170, 255,
  255'u8, 255, 255, 255,
  
  # Row 3: Same gradient
  0'u8, 0, 0, 255,
  85'u8, 85, 85, 255,
  170'u8, 170, 170, 255,
  255'u8, 255, 255, 255,
  
  # Row 4: Same gradient
  0'u8, 0, 0, 255,
  85'u8, 85, 85, 255,
  170'u8, 170, 170, 255,
  255'u8, 255, 255, 255
]

# Test the ASCII conversion
let asciiResult = convertToAscii(cast[ptr uint8](unsafeAddr testData[0]), 4, 4)
echo "ASCII conversion result:"
echo asciiResult
echo "---"

# Test single character conversion
let singleCharResult = convertToSingleCharAscii(cast[ptr uint8](unsafeAddr testData[0]), 4, 4)
echo "Single character conversion result:"
echo singleCharResult
echo "---"