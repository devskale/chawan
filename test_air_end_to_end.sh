#!/bin/bash

# Test script for AIR mode end-to-end
echo "Testing AIR mode end-to-end..."

# Create a test HTML file with a local image
cat > test_air_image.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AIR Mode Test</title>
</head>
<body>
    <h1>AIR Mode Test</h1>
    <p>This is a test of the AIR (ASCII Image Rendering) mode.</p>
    <img src="test_image.png" alt="Test Image" width="4" height="4">
</body>
</html>
EOF

# Create a simple test image (4x4 PNG)
# We'll create a minimal PNG file with the same pattern as our RGBA test
python3 -c "
import sys
import zlib
import struct

# PNG signature
png_data = bytearray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

# IHDR chunk
ihdr_data = struct.pack('>IIBBBBB', 4, 4, 8, 6, 0, 0, 0)  # width=4, height=4, bit_depth=8, color_type=6 (RGBA), compression=0, filter=0, interlace=0
ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data) & 0xffffffff
png_data.extend(struct.pack('>I', len(ihdr_data)))
png_data.extend(b'IHDR')
png_data.extend(ihdr_data)
png_data.extend(struct.pack('>I', ihdr_crc))

# IDAT chunk - image data
# Create image data (4 rows of 4 pixels, each pixel 4 bytes RGBA)
image_data = bytearray()
# Row 1: red, red, green, green
image_data.extend([0, 255, 0, 0, 255, 255, 0, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255])
# Row 2: blue, blue, white, white
image_data.extend([0, 0, 0, 255, 255, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255])
# Row 3: white, black, black, black
image_data.extend([0, 255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255])
# Row 4: black, white, white, white
image_data.extend([0, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255])

# Compress the image data
compressed_data = zlib.compress(bytes(image_data))

# Create IDAT chunk
idat_data = compressed_data
idat_crc = zlib.crc32(b'IDAT' + idat_data) & 0xffffffff
png_data.extend(struct.pack('>I', len(idat_data)))
png_data.extend(b'IDAT')
png_data.extend(idat_data)
png_data.extend(struct.pack('>I', idat_crc))

# IEND chunk
iend_crc = zlib.crc32(b'IEND') & 0xffffffff
png_data.extend(struct.pack('>I', 0))
png_data.extend(b'IEND')
png_data.extend(struct.pack('>I', iend_crc))

# Write the PNG file
with open('test_image.png', 'wb') as f:
    f.write(png_data)
" > /dev/null 2>&1

echo "Created test files. Now testing AIR mode..."

# Test with the correct AIR configuration
echo "Running: ./target/release/bin/cha -d -o 'buffer.images=true' -o 'display.image-mode=air' test_air_image.html"
./target/release/bin/cha -d -o 'buffer.images=true' -o 'display.image-mode=air' test_air_image.html