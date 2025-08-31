#!/bin/bash

# Test script for the DummyAC codec

echo "Testing DummyAC codec integration..."

# Test 1: Verify the codec binary exists
if [ -f "./target/release/libexec/chawan/cgi-bin/dummyac" ]; then
    echo "✓ DummyAC codec binary exists"
else
    echo "✗ DummyAC codec binary not found"
    exit 1
fi

# Test 2: Test the codec directly
echo "Testing codec functionality..."
OUTPUT=$(env MAPPED_URI_SCHEME=img-codec+dummyac MAPPED_URI_PATH=decode REQUEST_HEADERS=$'Cha-Image-Dimensions: 50x30' bash -c 'echo "test data" | ./target/release/libexec/chawan/cgi-bin/dummyac')

if echo "$OUTPUT" | grep -q "DUMMY-ASCII-CODEC"; then
    echo "✓ Codec functionality test passed"
else
    echo "✗ Codec functionality test failed"
    echo "Output: $OUTPUT"
    exit 1
fi

# Test 3: Test info-only mode
echo "Testing info-only mode..."
OUTPUT=$(env MAPPED_URI_SCHEME=img-codec+dummyac MAPPED_URI_PATH=decode REQUEST_HEADERS=$'Cha-Image-Info-Only: 1\nCha-Image-Dimensions: 50x30' bash -c 'echo "test data" | ./target/release/libexec/chawan/cgi-bin/dummyac')

if echo "$OUTPUT" | grep -q "Cha-Image-Dimensions: 50x30"; then
    echo "✓ Info-only mode test passed"
else
    echo "✗ Info-only mode test failed"
    echo "Output: $OUTPUT"
    exit 1
fi

echo "All tests passed! DummyAC codec is working correctly."