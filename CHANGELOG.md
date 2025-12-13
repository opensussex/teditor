# Changelog

## [Unreleased]

### Fixed
- **Ctrl-W e command palette**: Fixed HandleLeader procedure to check for `kbASCII` flag instead of `0`. The Keyboard unit sets the `kbASCII` flag for ASCII characters, so the original check would never match. This fix enables:
  - Ctrl-W e - Command palette (`:exit` to quit)
  - Ctrl-W c - Copy selection
  - Ctrl-W x - Cut selection
  - Ctrl-W v - Paste
  - Ctrl-W s - Save prompt
  - Ctrl-W h - Toggle help (not yet implemented)

### Technical Details
**Before:**
```pascal
if GetKeyEventFlags(k) = 0 then  // Never matches ASCII chars
```

**After:**
```pascal
if GetKeyEventFlags(k) = kbASCII then  // Correctly matches ASCII chars
```

The issue was that ASCII characters have the `kbASCII` flag set by the Keyboard unit's `TranslateKeyEvent()` function, so checking for flags = 0 would never match any printable character.

## [1.0.0] - 2025-12-13

### Added
- Initial Free Pascal port of ted.py
- Full text editing functionality
- Selection mode with visual highlighting
- Copy/cut/paste operations
- Leader key system (Ctrl-W)
- File operations with autosave
- Command palette
- Status bar with line/column display
