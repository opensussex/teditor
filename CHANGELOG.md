# Changelog

## [Unreleased]

### Fixed
- **Ctrl-W e command palette robustness**: Fixed keyboard event handling in modal dialogs (command palette and save prompt) to be consistent and reliable:
  1. Clear pending keyboard events before entering modal loop
  2. Use proper polling (`PollKeyEvent`) instead of blocking `GetKeyEvent`
  3. Clear remaining events after exiting modal
  
  This prevents keyboard buffer issues that caused the command palette to work once but fail on subsequent invocations.

- **Ctrl-W e command palette detection**: Fixed HandleLeader procedure to check for `kbASCII` flag instead of `0`. The Keyboard unit sets the `kbASCII` flag for ASCII characters, so the original check would never match. This fix enables:
  - Ctrl-W e - Command palette (`:exit` to quit)
  - Ctrl-W c - Copy selection
  - Ctrl-W x - Cut selection
  - Ctrl-W v - Paste
  - Ctrl-W s - Save prompt
  - Ctrl-W h - Toggle help (not yet implemented)

### Technical Details

**Issue 1: HandleLeader flag check**
```pascal
// Before:
if GetKeyEventFlags(k) = 0 then  // Never matches ASCII chars

// After:
if GetKeyEventFlags(k) = kbASCII then  // Correctly matches ASCII chars
```

**Issue 2: Modal dialog keyboard handling**
```pascal
// Before:
k := GetKeyEvent;  // Blocking call, can leave events in buffer

// After:
{ Clear any pending keyboard events before starting }
while PollKeyEvent <> 0 do
  GetKeyEvent;

{ Wait for keyboard event }
while PollKeyEvent = 0 do
  Sleep(10);

k := GetKeyEvent;
k := TranslateKeyEvent(k);

{ Clear any remaining keyboard events after exiting }
while PollKeyEvent <> 0 do
  GetKeyEvent;
```

The keyboard buffer wasn't being properly managed, causing leftover events to interfere with subsequent modal dialog invocations.

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
