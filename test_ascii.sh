#!/bin/bash

# Test script for AIR mode
echo "Testing AIR mode with simple image..."

# Build the project first
make

# Test with the simple image test file
echo "Running: ./target/release/bin/cha --config=test_air_config.toml simple_image_test.html"
./target/release/bin/cha --config=test_air_config.toml simple_image_test.html