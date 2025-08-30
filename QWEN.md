# Chawan Browser Project

## Project Overview

Chawan is a TUI (Text-based User Interface) web browser with support for CSS, inline images, and JavaScript. It can display websites in a manner similar to major graphical browsers but runs in a terminal. It supports multiple protocols including HTTP(S), FTP, Gopher, Gemini, Finger, and Spartan.

Key features:
- Multi-processing, incremental loading of documents
- HTML5 support with various encodings (UTF-8, Shift_JIS, GBK, etc.)
- CSS-based layout engine supporting flow layout, table layout, and flexbox
- JavaScript support (disabled by default)
- Inline image support with Sixel or Kitty graphics protocols
- User-programmable keybindings (defaults are vi-like)
- Supports bookmarks, history, and cookies
- Can be used as a terminal pager

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

# Build the project using gmake (GNU make)
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

Chawan supports inline images through two protocols:
1. **Sixel**: Widely supported format
2. **Kitty**: Technically superior protocol with better transparency support

Image codecs are implemented as local CGI programs that convert between encoded formats and RGBA data. Supported input formats include PNG, JPEG, GIF, BMP, WebP, and SVG.

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