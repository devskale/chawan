#!/bin/bash

# Final test script for AIR mode with real websites
echo "Testing AIR mode with real websites..."

# Create AIR configuration file
cat > air_config.toml << 'EOF'
[buffer]
images = true

[display]
image-mode = "air"
EOF

echo "Created AIR configuration file: air_config.toml"
echo ""
echo "To test AIR mode with a real website, you can run:"
echo "  ./target/release/bin/cha --config=air_config.toml google.at"
echo ""
echo "Or with command line options:"
echo "  ./target/release/bin/cha -o 'buffer.images=true' -o 'display.image-mode=air' google.at"
echo ""
echo "In visual mode (without -d), images will be converted to ASCII art and displayed in the terminal."
echo "In dump mode (with -d), you'll see placeholders like [AIR-IMAGE: widthxheight] because images are"
echo "loaded asynchronously and the page is rendered before images are processed."