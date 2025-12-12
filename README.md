# ted.py — Minimal Distraction-Free Editor

ted.py is a small terminal text editor implemented with Python and `curses`.  
It's intended as a lightweight, distraction-minimal writing environment with simple editing, selection, leader-key commands, and file save/open operations.

## Quick start

Requirements:
- Python 3
- A terminal that supports basic curses functionality

Run:
- Open a file (create if missing):
  `python ted.py file.txt`
- Open with no file:
  `python ted.py`

When launched with a filename:
- If the file exists, it is loaded.
- If it does not exist, an empty file is created and opened.

## Basic editing

- Arrow keys: move the cursor
- Enter: insert newline
- Backspace/Delete: delete character before the cursor
- Printable characters: insert at the cursor

## Leader key and command palette

`Ctrl-W` is used as a leader key. After pressing `Ctrl-W`, press one of the following letters:

- `e` — Open the command palette (single-line prompt at bottom). Type `exit` and press Enter to quit.
- `s` — Save. Opens a save prompt prefilled with the current filename (if any); type a name and press Enter to save.
- `c` — Copy current selection to internal clipboard.
- `x` — Cut current selection to internal clipboard.
- `v` — Paste clipboard at cursor.

Notes:
- The leader key implementation is blocking: press `Ctrl-W` then the next key.
- The command palette is a single-line prompt at the bottom (prefixed with `:`).

## Selection, copy, cut, paste

- Toggle selection mode: `F2`
  - While selection mode is active, use arrow keys to expand/contract the selection.
  - The status line will indicate `[SELECT]` when selection mode is active.
- Shift+Arrow keys: If your terminal sends distinct shifted-arrow key codes, Shift+arrows will also start/extend selection.
- Copy / Cut / Paste:
  - Use the leader sequences (`Ctrl-W c`, `Ctrl-W x`, `Ctrl-W v`) to operate on the internal clipboard.
  - Direct bindings: `Ctrl-X` (cut), `Ctrl-V` (paste) also work.
  - Copy requires an active selection. If no selection exists, copy/cut will show a status message.

## File saving and prompts

- `Ctrl-W s` opens the save prompt. If the buffer has an associated filename, it is prefilled.
- Press Enter to save; ESC to cancel.
- After a successful save, the filename is associated with the buffer and shown in the status line.

## Status line

The bottom line shows:
- Cursor line/col
- Leader-key hints
- Current filename (or `(unnamed)`)
- Any transient status messages (e.g., "Saved to ...", "Clipboard empty", "No selection to copy")

If you prefer fewer distractions, you can:
- Disable or hide the status line in a later change (not currently implemented).
- Use the save prompt and leader-key only when needed.

## Terminal quirks & notes

- Support for Shift+Arrow and other modified keys depends on your terminal emulator and terminfo. If those combinations don't work for you, use `F2` selection mode instead.
- The internal clipboard is separate from the system clipboard. Integrating with the system clipboard (e.g., `pbcopy`/`xclip`) can be added later if desired.
- `Ctrl-Z` is avoided because it's commonly used by terminals to suspend processes.
