# Chawan Build and Development Guide

## Build Commands
- `make` - Build all binaries (release mode by default)
- `make TARGET=debug` - Build in debug mode with native debugger
- `make TARGET=release` - Build optimized release binaries
- `make TARGET=release0` - Release build with stack traces enabled
- `make TARGET=release1` - Release build with native debugger
- `make clean` - Remove build artifacts
- `make distclean` - Remove all build outputs
- `make install` - Install to system (requires sudo)
- `make uninstall` - Remove from system

## Test Commands
- `make test` - Run all test suites
- `make test_js` - Run JavaScript engine tests
- `make test_layout` - Run CSS layout engine tests
- `make test_net` - Run network protocol tests
- `make test_md` - Run markdown rendering tests

### Running Individual Tests
- Layout tests: `cd test/layout && ./run.sh`
- JS tests: `cd test/js && ./run.sh`
- Network tests: `cd test/net && ./run.sh`
- Markdown tests: `cd test/md && ./run.sh`

## Code Style Guidelines

### Compiler Configuration
- Uses `--styleCheck:usages` and `--styleCheck:hint` for style enforcement
- Uses `--panics:on` for panic handling
- Memory management: `--mm:refc` (reference counting)
- Threads: `--threads:off` (disabled)
- Experimental: `--experimental:strictDefs` in debug builds

### Import Organization
```nim
# Standard library imports first
import std/options
import std/os
import std/tables

# Local module imports (use relative paths)
import config/config
import utils/myposix
```

### Pragmas and Attributes
- `{.push raises: [].}` - Disable exception raising for entire file
- `{.used.}` - Mark symbol as used to avoid warnings
- `{.deprecated: "message".}` - Mark deprecated functions
- `{.cast(noSideEffect).}` - Mark as side-effect free

### Function Definitions
- Use `func` for pure functions (no side effects)
- Use `proc` for procedures with side effects
- Use `*` suffix for exported/public symbols
- Use `auto` return types in templates where appropriate

### Conditional Compilation
```nim
when defined(debug):
  # Debug-specific code
when defined(release):
  # Release-specific code
when nimvm:
  # Compile-time code
```

### Error Handling
- Use `Result[T, E]` type for operations that can fail
- Use `Opt[T]` for optional values
- Use `Err[E]` for error-only results
- Prefer templates like `ok()` and `err()` for result construction

### Type Definitions
- Use generics extensively: `Result[T, E]`, `Opt[T]`
- Use `when` conditions in type definitions for conditional types
- Follow naming conventions: PascalCase for types, camelCase for fields

### Constants and Complex Expressions
```nim
const VersionStr = block:
  var s = "Chawan v0.3"
  when defined(debug):
    s &= " (debug)"
  else:
    s &= " (release)"
  s
```

### Naming Conventions
- Types: PascalCase (`Result`, `ConfigTable`)
- Functions/Procedures: camelCase (`parseConfig`, `renderPage`)
- Constants: PascalCase or SCREAMING_SNAKE_CASE
- Fields: camelCase with `*` for public
- Templates: camelCase with `*` for public

### Error Handling Patterns
- Use `{.raises: [].}` to document exception-free procedures
- Prefer Result types over exceptions for expected errors
- Use `try/except` only for truly exceptional cases