# AIR Mode Box Alignment Fix

## Issue
The ASCII box rendering in AIR mode was skewed, with the top border, info line, and bottom border not properly aligned with each other.

## Root Cause
The `setText` function in the grid rendering system only handles single-line strings properly. When a multi-line string was passed to it, only the first line was rendered correctly, while subsequent lines were not properly positioned.

## Solution
Instead of passing a multi-line string to `setText`, we now render each line of the ASCII box separately:
1. Top border line
2. Info line (with dimensions)
3. Bottom border line

Each line is rendered with its own offset, ensuring proper vertical alignment.

## Files Modified
- `src/css/render.nim` - Modified the AIR box rendering logic in the `paintInlineBox` function

## Testing
The fix has been tested with:
- `./cha --air -d google.at` - Google homepage with a 272x92 image
- `./cha --air -d debug_box.html` - Simple test case with a 100x50 image
- `./cha --air -d simple_image_test.html` - Another test case

All tests show properly aligned ASCII boxes.