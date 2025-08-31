#!/bin/bash

# Test script for the new --air flag
echo "Testing the new --air flag..."

# Test 1: Help text should show --air option
echo "Test 1: Checking help text..."
./target/release/bin/cha --help | grep -- "--air" > /dev/null
if [ $? -eq 0 ]; then
    echo "✓ Help text correctly shows --air option"
else
    echo "✗ Help text does not show --air option"
fi

# Test 2: --air flag should enable AIR mode
echo "Test 2: Testing --air flag functionality..."
OUTPUT=$(./target/release/bin/cha --air -d simple_image_test.html 2>&1)
if echo "$OUTPUT" | grep -q "Image mode set to: air"; then
    echo "✓ --air flag correctly enables AIR mode"
else
    echo "✗ --air flag does not enable AIR mode"
fi

# Test 3: --air flag should enable images
if echo "$OUTPUT" | grep -q "AIR mode is active!"; then
    echo "✓ --air flag correctly enables image processing"
else
    echo "✗ --air flag does not enable image processing"
fi

echo ""
echo "All tests completed!"
echo ""
echo "You can now use the --air flag to easily enable ASCII Image Rendering mode:"
echo "  ./cha --air google.at"
echo "  ./cha --air -d google.at  # for dump mode"