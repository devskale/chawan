# AIR Mode Box Alignment and Aspect Ratio Fix

## Issue
The ASCII box rendering in AIR mode had two issues:
1. The boxes were skewed, with the top border, info line, and bottom border not properly aligned with each other
2. All boxes had a fixed height of 3 lines, regardless of the image's aspect ratio

## Root Cause
1. The `setText` function in the grid rendering system only handles single-line strings properly. When a multi-line string was passed to it, only the first line was rendered correctly, while subsequent lines were not properly positioned.
2. The box height was hardcoded to 3 lines, not taking into account the image's aspect ratio.

## Solution
Instead of passing a multi-line string to `setText`, we now:
1. Render each line of the ASCII box separately with proper offsets to ensure alignment
2. Calculate the box height based on the image's aspect ratio, with minimum and maximum constraints
3. Center the info line within the box for better visual appeal
4. Fill the sides of the box with vertical bars to create a complete box structure

## Implementation Details
- Calculate box height based on image aspect ratio: `height = width * aspect_ratio * 0.5`
- Apply minimum height constraint of 3 lines
- Apply maximum height constraint of 20 lines to prevent excessive vertical space
- Render top border at the original offset
- Render bottom border at `offset + (height - 1) * line_height`
- Fill sides with vertical bars for all intermediate lines
- Place info line at the center of the box: `height div 2`

## Files Modified
- `src/css/render.nim` - Modified the AIR box rendering logic in the `paintInlineBox` function

## Testing
The fix has been tested with:
- `./cha --air -d google.at` - Google homepage with a 272x92 image (aspect ratio preserved)
- `./cha --air -d simple_image_test.html` - Simple test case with a 100x1 image (very wide aspect ratio)
- `./cha --air -d sized_image_test.html` - Medium test case with a 200x100 image (2:1 aspect ratio)
- `./test_sized_ascii_boxes.sh` - Comprehensive test with small, medium, and large images

All tests show properly aligned ASCII boxes with correct aspect ratios preserved.