# Chawan Browser Project

## Project Overview

Chawan is a TUI (Text-based User Interface) web browser with support for CSS, inline images, and JavaScript. It can display websites in a manner similar to major graphical browsers but runs in a terminal. It supports multiple protocols including HTTP(S), FTP, Gopher, Gemini, Finger, and Spartan.

Key features:
- Multi-processing, incremental loading of documents
- HTML5 support with various encodings (UTF-8, Shift_JIS, GBK, etc.)
- CSS-based layout engine supporting flow layout, table layout, and flexbox
- JavaScript support (disabled by default)
- Inline image support with Sixel or Kitty graphics protocols
- ASCII Image Rendering (AIR) mode for terminal-compatible image display
- User-programmable keybindings (defaults are vi-like)
- Supports bookmarks, history, and cookies
- Can be used as a terminal pager

## Development Goal
implement AIR (ascii image rendering) mode.
cha --air google.at
air mode renders images into ascii characters. this allows terminal browsing in all basic terminals.

### Development Concept
Deeply understand the image rendering pipeline
add a dummy ascii codec (DummyAC)
integrate the DummyAC into the image rendering pipeline.
verify the dummyAC with real live websites, eg cha --air google.at, or cha --air -d google.at
only after successfully verifying the architectural setup. move on with implementing ascii codec.
   choose wisely to integrate a pre existing codec or develop a new one.

**Status**: ✅ COMPLETE - The basic AIR mode has been successfully implemented and integrated.
The `--air` flag now works as intended, allowing terminal browsing with ASCII image rendering.

## Recent Achievement: Improved AIR Mode Box Rendering

We've successfully implemented significant improvements to the AIR mode ASCII box rendering:

1. **Fixed Box Alignment Issues**: Resolved skewed rendering where box elements (top border, info line, bottom border) were not properly aligned
2. **Implemented Aspect Ratio Preservation**: ASCII boxes now maintain proper proportions based on the original image dimensions
3. **Added Visual Enhancements**: Created complete box structures with vertical side borders and centered info lines

These improvements provide a much better visual representation of images in terminal environments while maintaining compatibility across all terminal types.

## Main Lessons Learned

1. **Grid Rendering Limitations**: The `setText` function in Chawan's grid rendering system only properly handles single-line strings. Multi-line strings require individual line rendering with proper offset calculations.

2. **Aspect Ratio Implementation**: Properly preserving image aspect ratios in ASCII rendering requires careful calculation considering character dimensions (characters are typically taller than they are wide).

3. **Visual Design Principles**: Centering informational elements within containers and providing complete border structures significantly improves the visual appeal and readability of ASCII art representations.

4. **Constraint Management**: Implementing minimum and maximum size constraints prevents visual issues with extremely small or large images while maintaining proportional representation.

## Development Status

1 [X] Implement Dummy Ascii Codec
2 [X] Add ASCII image mode to configuration system
3 [X] Integrate ASCII mode into terminal image pipeline
4 [X] Test dummy ASCII rendering end-to-end
5 [X] Add --air command line flag for easy usage
6 [X] Implement size-aware ASCII boxes with proper dimensions
7 [X] Fix box alignment issues
8 [X] Implement aspect ratio preservation for ASCII boxes

## Current Implementation

The AIR (ASCII Image Rendering) mode has been successfully implemented and integrated into Chawan. Users can now easily enable ASCII image rendering with the `--air` flag:

```bash
# Enable AIR mode for browsing
./cha --air google.at

# Enable AIR mode with dump output
./cha --air -d google.at
```

The implementation includes:
- A working AIR codec that converts RGBA pixel data to ASCII art using a character set ordered by density
- Integration with Chawan's image pipeline and configuration system
- Proper error handling and debugging output
- A convenient `--air` command line flag that automatically enables image processing and sets the display mode
- **Size-aware ASCII boxes that accurately represent image dimensions**
- **Properly aligned boxes with aspect ratio preservation**

## Next Steps for Improvement

### 1. Improve ASCII Rendering Quality
The current implementation now uses size-aware boxes with proper dimension representation. Future improvements could include:

- **Advanced character mapping**: Implement multiple character sets for different rendering qualities and styles
- **Brightness/contrast adjustment**: Add algorithms to optimize character selection for better visual contrast
- **Dithering techniques**: Implement better dithering methods for smoother gradients and more detailed ASCII art
- **Multi-size rendering**: Generate different ASCII art versions for various terminal sizes and resolutions

### 2. Enhanced Image Processing
- **Color support**: Add ANSI color codes to ASCII art for terminals that support them, creating colored ASCII representations
- **Animation support**: Handle animated images (GIFs) by rendering frame sequences for basic animation support

### 3. Performance Optimization
- **Caching mechanisms**: Implement caching for ASCII art results to avoid reprocessing the same images
- **Streaming processing**: Process images incrementally for large images to improve responsiveness
- **Memory management**: Optimize memory usage for image data handling and processing

### 4. User Experience Improvements
- **Progressive loading**: Show low-resolution ASCII art while loading higher-resolution versions for better perceived performance
- **Configurable density**: Allow users to adjust the character set density and rendering style
- **Responsive design**: Adapt ASCII art based on container size and terminal dimensions

### 5. Integration with Layout Engine
- **CSS integration**: Allow CSS to control ASCII art rendering parameters for fine-grained customization
- **Text flow optimization**: Better integration with text layout to avoid overlapping and improve readability

## Technical Implementation Plan

### Phase 1: Size-Aware Rendering
1. Modify the CSS rendering engine to calculate appropriate ASCII art dimensions
2. Implement aspect ratio preservation algorithms
3. Add terminal size detection and adaptation

### Phase 2: Enhanced Character Mapping
1. Implement multiple character sets for different rendering qualities
2. Add brightness/contrast adjustment algorithms
3. Integrate with terminal color detection

### Phase 3: Performance and Caching
1. Add image caching for ASCII art results
2. Implement progressive rendering
3. Optimize memory usage for large images

The foundation for AIR mode is now complete and working. The next steps will focus on making the ASCII rendering more sophisticated and visually appealing while maintaining compatibility with all terminal types.

## Project Structure

```
├── adapter/                    # Protocol and format adapters
│   ├── format/                 # Format converters (Markdown, Gopher, etc.)
│   ├── img/                    # Image codecs and processors
│   ├── protocol/               # Protocol handlers (HTTP, FTP, etc.)
│   └── tools/                  # Utility tools
├── doc/                        # Documentation
├── lib/                        # External libraries
│   ├── chame0/                 # HTML parser
│   ├── chagashi0/              # Character encoding library
│   └── monoucha0/              # JavaScript engine (QuickJS wrapper)
├── res/                        # Resources (config files, Unicode data)
├── src/                        # Main source code
│   ├── config/                 # Configuration handling
│   ├── css/                    # CSS parsing, cascading, layout, rendering
│   ├── html/                   # DOM implementation
│   ├── io/                     # I/O operations
│   ├── local/                  # Local (pager) implementation
│   ├── server/                 # Server processes (loader, buffer)
│   ├── types/                  # Data types
│   └── utils/                  # Utility functions
├── target/                     # Build output directory
└── test/                       # Tests
```

## Building and Running

### Prerequisites

1. Unix-like operating system (Linux, *BSD, Haiku, macOS)
2. Nim compiler version 2.0.0 or newer (ideally 2.2.4)
3. Dependencies:
   - OpenSSL or LibreSSL
   - libssh2
   - brotli
   - pkg-config
   - GNU make

### Compilation on macOS

On macOS, you can install the dependencies using Homebrew:

```bash
# Install dependencies
brew install nim openssl libssh2 brotli pkg-config

# Clone the repository
git clone https://git.sr.ht/~bptato/chawan
cd chawan

# Build the project using gmake (GNU make) - NOTE: On macOS, you MUST use gmake
gmake

# Install (optional)
sudo gmake install
```

Note: On macOS, you need to use `gmake` instead of `make` as the project requires GNU make features.

### Compilation on other Unix-like systems

```bash
# Clone the repository
git clone https://git.sr.ht/~bptato/chawan
cd chawan

# Build the project
make

# Install (optional)
sudo make install
```

### Running

```bash
# Open in visual mode (shows keybindings)
./target/release/bin/cha -V

# Open a website
./target/release/bin/cha example.org

# View a markdown file
./target/release/bin/cha README.md

# View man pages
./target/release/bin/mancha cha

# Enable ASCII Image Rendering mode
./target/release/bin/cha --air google.at

# Enable ASCII Image Rendering mode with dump output
./target/release/bin/cha --air -d google.at
```

If you've installed the binaries to your system, you can omit the path:

```bash
# Open in visual mode (shows keybindings)
cha -V

# Open a website
cha example.org

# View a markdown file
cha README.md

# View man pages
mancha cha
```

## Development

### Code Organization

The codebase is organized into several key modules:

1. **Main Process (src/main.nim)**: Entry point and command-line argument parsing
2. **Pager (src/local/pager.nim)**: User interface and buffer management
3. **Loader (src/server/loader.nim)**: Resource loading and protocol handling
4. **Buffer (src/server/buffer.nim)**: HTML parsing and rendering
5. **DOM (src/html/dom.nim)**: Document Object Model implementation
6. **CSS (src/css/)**: CSS parsing, cascading, layout, and rendering
7. **JavaScript (lib/monoucha0/)**: QuickJS integration

### Process Model

Chawan uses a multi-process architecture:
```
cha (main process)
├── forkserver (forked immediately at startup)
│   ├── loader
│   ├── buffer(s)
│   └── local CGI scripts
├── mailcap processes (e.g. md2html, feh, ...)
└── editor (e.g. vi)
```

### Configuration

Configuration is handled through TOML files. The default configuration is in `res/config.toml`. Users can override settings in `~/.chawan/config.toml` or `~/.config/chawan/config.toml`.

Key configuration sections:
- `[start]`: Startup options
- `[buffer]`: Buffer behavior (styling, images, scripting)
- `[display]`: Display settings (colors, image mode)
- `[network]`: Network settings
- `[input]`: Input handling

### Image Support

Chawan supports inline images through multiple protocols:
1. **Sixel**: Widely supported format
2. **Kitty**: Technically superior protocol with better transparency support
3. **ASCII Image Rendering (AIR)**: Terminal-compatible ASCII art rendering

Image codecs are implemented as local CGI programs that convert between encoded formats and RGBA data. Supported input formats include PNG, JPEG, GIF, BMP, WebP, and SVG.

To enable ASCII image rendering mode, you can either use the convenient `--air` flag:

```bash
# Enable AIR mode with the --air flag
./cha --air google.at

# Enable AIR mode with dump output
./cha --air -d google.at
```

Or configure Chawan manually with:
```toml
[buffer]
images = true

[display]
image-mode = "air"
```

### JavaScript

JavaScript is implemented using QuickJS through the Monoucha library. It's disabled by default but can be enabled with `buffer.scripting = true` in the configuration.

### CSS Implementation

The CSS engine supports most CSS 2.1 features plus selected CSS 3 features:
- Selectors (including pseudo-classes and pseudo-elements)
- Box model and positioning
- Flexbox layout
- Media queries
- Custom properties (variables)

Layout is performed on a fixed-point coordinate system and then converted to character-based positions.

## Development Conventions

### Coding Style

- Camel case for everything except types/constants (PascalCase) and C library functions (snake_case)
- 80 characters per line
- No blank lines inside procedures
- Semicolons instead of commas for parameter separation
- Comments should explain non-obvious code

### Error Handling

- Use Result/Opt/Option instead of exceptions
- Specify `{.push raises: [].}` at the beginning of files and `{.pop.}` at the end
- Avoid implicit initialization; explicitly initialize objects

### Debugging

- Use `eprint` for debugging output
- Console buffer can be accessed with M-c M-c
- For pager debugging: `cha [...] -o start.console-buffer=false 2>a`
- gdb can be used with debug builds

## Testing

Tests are located in the `test/` directory:
- `test/js/`: JavaScript tests
- `test/layout/`: Layout tests
- `test/md/`: Markdown tests
- `test/net/`: Network tests

Run tests with:
```bash
# On macOS
gmake test

# On other Unix-like systems
make test
```

## Documentation

Documentation is available as man pages and Markdown files in the `doc/` directory:
- Architecture: `doc/architecture.md`
- Building: `doc/build.md`
- Configuration: `doc/config.md`
- CSS support: `doc/css.md`
- Image support: `doc/image.md`
- Hacking guide: `doc/hacking.md`
- Protocol support: `doc/protocols.md`
- Troubleshooting: `doc/troubleshooting.md`
- URI method map: `doc/urimethodmap.md`

## Contributing

For development information, see `doc/hacking.md`. Key points:
- Follow the NEP1 style guide
- Avoid exceptions; use Result/Opt/Option
- Handle cyclic imports with global function pointers
- Add tests for bug fixes and new features

For bug reports and patches, use the mailing list at ~bptato/chawan-devel@lists.sr.ht or the ticket tracker at https://todo.sr.ht/~bptato/chawan.
