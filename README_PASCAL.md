# ted.pas - Free Pascal Port

This is a Free Pascal port of the ted.py terminal text editor.

## Compilation

```bash
fpc ted.pas
```

This produces a standalone executable `ted` (~940KB).

## Usage

```bash
# Open a file (create if missing)
./ted filename.txt

# Open without a file
./ted
```

## Key Differences from Python Version

### Technical Implementation

1. **Terminal Library**:
   - Python version: Uses `curses` library
   - Pascal version: Uses Free Pascal's `Video` and `Keyboard` units
   - Both provide similar terminal control capabilities

2. **Language Features**:
   - **Memory Management**: Pascal uses manual object lifecycle (Create/Free) vs Python's automatic garbage collection
   - **String Handling**: Pascal uses 1-based string indexing vs Python's 0-based
   - **Type System**: Pascal is statically typed with explicit type declarations

3. **Data Structures**:
   - Python: `list` of strings for text buffer
   - Pascal: `TStringList` class for text buffer
   - Both provide similar operations (Add, Insert, Delete)

4. **Event Loop**:
   - Python: `curses.getch()` with timeout
   - Pascal: `PollKeyEvent()` + `GetKeyEvent()` with Sleep()
   - Both achieve non-blocking input for autosave

5. **Rendering**:
   - Python: Uses curses functions (`addstr`, `attron`, etc.)
   - Pascal: Direct `VideoBuf` manipulation with attribute bytes
   - Attribute format: `$70` = reverse video (white on black)

### Keyboard Constants

The Pascal version defines keyboard scan codes explicitly:
- `kbLeft = $4B00`, `kbRight = $4D00`
- `kbUp = $4800`, `kbDown = $5000`
- `kbHome = $4700`, `kbEnd = $4F00`
- `kbF2 = $3C00`

These are standard PC BIOS scan codes.

### Functional Equivalence

All features from the Python version are preserved:
- ✅ Text editing (insert, delete, newline)
- ✅ Cursor movement (arrows, home, end)
- ✅ Selection mode (F2 toggle)
- ✅ Copy/Cut/Paste (Ctrl-W c/x/v or Ctrl-X/Ctrl-V)
- ✅ File operations (open, save, autosave)
- ✅ Leader key commands (Ctrl-W)
- ✅ Command palette (`:exit` to quit)
- ✅ Status bar with line/column display
- ✅ Autosave every 5 seconds
- ✅ Status message expiration (3 seconds)

### Performance

- **Startup**: Pascal version is faster (compiled vs interpreted)
- **Memory**: Pascal version uses less memory (~1MB vs Python interpreter overhead)
- **Binary Size**: ~940KB standalone executable (no runtime dependencies)
- **Rendering**: Similar performance (both use direct terminal buffer access)

### Portability

- **Python version**: Requires Python 3 + curses (Unix-like systems)
- **Pascal version**: Requires Free Pascal compiler, produces native binary
- **Runtime**: Pascal version has no runtime dependencies after compilation

## Building from Source

### Requirements
- Free Pascal Compiler (FPC) 3.2.2 or later
- Linux/Unix system (for Video/Keyboard units)

### Install FPC on Ubuntu/Debian
```bash
sudo apt-get install fp-compiler
```

### Compile
```bash
fpc ted.pas
```

### Run
```bash
./ted myfile.txt
```

## Code Structure

The Pascal version maintains the same single-class architecture:

```pascal
TSimpleEditor = class
  - Text buffer (TStringList)
  - Cursor position (cx, cy)
  - Scroll offsets (scroll_x, scroll_y)
  - Selection state (sel_active, sel_anchor_x, sel_anchor_y)
  - File operations (OpenFile, SaveFile, Autosave)
  - Rendering (Draw method with VideoBuf manipulation)
  - Input handling (HandleKey, HandleLeader)
  - Main loop (Run method)
end;
```

## Known Limitations

1. **Terminal Requirement**: Requires a proper terminal with TERM environment variable set
2. **No Shift+Arrow**: Shift+Arrow key detection depends on terminal capabilities (use F2 selection mode instead)
3. **Internal Clipboard**: No system clipboard integration (same as Python version)
4. **Single Buffer**: Can only edit one file at a time (same as Python version)

## Advantages of Pascal Version

1. **No Dependencies**: Single executable, no interpreter needed
2. **Fast Startup**: Compiled code starts instantly
3. **Low Memory**: Minimal memory footprint
4. **Type Safety**: Compile-time type checking prevents many runtime errors
5. **Portable Binary**: Can be distributed as a single file

## Disadvantages

1. **Compilation Required**: Changes require recompilation
2. **Platform Specific**: Binary must be recompiled for different architectures
3. **Less Dynamic**: No runtime code evaluation (not needed for this application)

## Future Enhancements

Potential improvements (same as Python version):
- Syntax highlighting
- Multiple buffers/tabs
- System clipboard integration
- Configuration file support
- Undo/redo functionality
- Search and replace
- Line numbers display

## License

GPL v3 (same as original Python version)
