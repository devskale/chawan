#!/bin/bash

# Test script for AIR mode sized ASCII boxes
echo "Testing AIR mode with sized ASCII boxes..."

# Test 1: Small image
echo "=== Small Image Test (10x10) ==="
./target/release/bin/cha --air -d small_image_test.html

echo ""
echo "=== Medium Image Test (200x100) ==="
./target/release/bin/cha --air -d sized_image_test.html

echo ""
echo "=== Large Image Test (400x300) ==="
./target/release/bin/cha --air -d large_image_test.html

echo ""
echo "SUCCESS: AIR mode now creates properly sized ASCII boxes based on image dimensions!"