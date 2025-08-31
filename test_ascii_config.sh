#!/bin/bash

# Test script for ASCII image mode configuration

echo "Testing ASCII image mode configuration..."

# Test 1: Verify the configuration file can be parsed
echo "Testing configuration parsing..."
CONFIG_OUTPUT=$(./target/release/bin/cha --dump-config -c test_ascii_config.toml 2>&1)

if echo "$CONFIG_OUTPUT" | grep -q "imageMode: air"; then
    echo "✓ ASCII image mode configuration parsed correctly"
else
    echo "✗ ASCII image mode configuration parsing failed"
    echo "Output: $CONFIG_OUTPUT"
    exit 1
fi

# Test 2: Verify the air codec is available
if [ -f "./target/release/libexec/chawan/cgi-bin/air" ]; then
    echo "✓ AIR codec binary exists"
else
    echo "✗ AIR codec binary not found"
    exit 1
fi

# Test 3: Test the air codec directly
echo "Testing AIR codec functionality..."
OUTPUT=$(env MAPPED_URI_SCHEME=img-codec+air MAPPED_URI_PATH=decode REQUEST_HEADERS=$'Cha-Image-Dimensions: 50x30' bash -c 'echo "test data" | ./target/release/libexec/chawan/cgi-bin/air')

if echo "$OUTPUT" | grep -q "Cha-Control: ConnectionError"; then
    # This is expected since we're not providing valid RGBA data
    echo "✓ AIR codec responds as expected"
else
    echo "✗ AIR codec test failed"
    echo "Output: $OUTPUT"
    exit 1
fi

echo "All ASCII image mode configuration tests passed!"