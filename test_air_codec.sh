#!/bin/bash

# Test script for AIR codec
echo "Testing AIR codec directly..."

# Create a simple RGBA test image (4x4 pixels)
# We'll create a simple pattern with different colors using Python
python3 -c "
import sys
# Create 4x4 RGBA data
# First row: red, red, green, green
# Second row: blue, blue, white, white
# Third row: white, black, black, black
# Fourth row: black, white, white, white
data = bytearray()
# Row 1
data.extend([255, 0, 0, 255]*2)   # 2 red pixels
data.extend([0, 255, 0, 255]*2)   # 2 green pixels
# Row 2
data.extend([0, 0, 255, 255]*2)   # 2 blue pixels
data.extend([255, 255, 255, 255]*2)  # 2 white pixels
# Row 3
data.extend([255, 255, 255, 255]) # 1 white pixel
data.extend([0, 0, 0, 255]*3)     # 3 black pixels
# Row 4
data.extend([0, 0, 0, 255])       # 1 black pixel
data.extend([255, 255, 255, 255]*3)  # 3 white pixels
sys.stdout.buffer.write(data)
" > test_rgba_data.bin

# Test the AIR codec directly
echo "Testing AIR codec with 4x4 RGBA data:"
MAPPED_URI_SCHEME=img-codec+air MAPPED_URI_PATH=decode REQUEST_HEADERS='Cha-Image-Dimensions: 4x4' ./target/release/libexec/chawan/cgi-bin/air < test_rgba_data.bin