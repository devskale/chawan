#!/bin/bash

# Test the AIR codec directly
echo "Testing AIR codec directly..."

# Create a simple 4x4 RGBA image (64 bytes)
printf '\x00\x00\x00\xff\x40\x40\x40\xff\x80\x80\x80\xff\xc0\xc0\xc0\xff' > test.rgba
printf '\x20\x20\x20\xff\x60\x60\x60\xff\xa0\xa0\xa0\xff\xe0\xe0\xe0\xff' >> test.rgba
printf '\x10\x10\x10\xff\x50\x50\x50\xff\x90\x90\x90\xff\xd0\xd0\xd0\xff' >> test.rgba
printf '\x30\x30\x30\xff\x70\x70\x70\xff\xb0\xb0\xb0\xff\xf0\xf0\xf0\xff' >> test.rgba

# Test the decode functionality
echo "Testing decode functionality..."
export MAPPED_URI_SCHEME="img-codec+air"
export MAPPED_URI_PATH="decode"
export REQUEST_HEADERS="Cha-Image-Dimensions: 4x4"

echo "Input: 4x4 RGBA image"
echo "Output:"
cat test.rgba | ./target/release/libexec/chawan/cgi-bin/air

# Clean up
rm test.rgba

echo "Test completed."