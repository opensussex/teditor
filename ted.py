#!/usr/bin/env python3
import curses
import os
import sys

CTRL_W = 23  # Ctrl-W ASCII code
CTRL_X = 24  # Ctrl-X cut (direct)
CTRL_V = 22  # Ctrl-V paste (direct)


class SimpleEditor:
    def __init__(self, stdscr, filename=None):
        self.stdscr = stdscr
        # Text buffer: list of lines
        self.lines = [""]
        # Cursor in buffer coordinates
        self.cx = 0
        self.cy = 0
        # Scroll offsets
        self.scroll_x = 0
        self.scroll_y = 0
        # Determine window size
        self.update_size()
        # Flag to quit
        self.should_quit = False

        # Selection state
        self.sel_active = False
        self.sel_anchor = (0, 0)  # (ax, ay)
        # Clipboard (simple string, may contain newlines)
        self.clipboard = ""
        # Selection-mode (toggle with F2). When enabled, normal arrows extend selection.
        self.sel_mode = False

        # Filename and status
        self.filename = None
        self.status_message = ""

        # If a filename provided on startup, open/create it
        if filename:
            self.open_file(filename)

    def update_size(self):
        self.max_y, self.max_x = self.stdscr.getmaxyx()
        # Reserve last line for status / command entry
        self.view_height = max(1, self.max_y - 1)
        self.view_width = max(1, self.max_x)

    def clamp_cursor(self):
        # Ensure cursor is within valid buffer positions
        self.cy = max(0, min(self.cy, len(self.lines) - 1))
        line_len = len(self.lines[self.cy])
        self.cx = max(0, min(self.cx, line_len))

    def ensure_visible(self):
        # Vertical scrolling
        if self.cy < self.scroll_y:
            self.scroll_y = self.cy
        elif self.cy >= self.scroll_y + self.view_height:
            self.scroll_y = self.cy - self.view_height + 1

        # Horizontal scrolling
        if self.cx < self.scroll_x:
            self.scroll_x = self.cx
        elif self.cx >= self.scroll_x + self.view_width:
            self.scroll_x = self.cx - self.view_width + 1

    def insert_char(self, ch):
        # If selection active, replace selection with inserted char
        if self.sel_active:
            self.delete_selection()
            self.clear_selection()
        line = self.lines[self.cy]
        self.lines[self.cy] = line[: self.cx] + ch + line[self.cx :]
        self.cx += len(ch)

    def backspace(self):
        if self.sel_active:
            self.delete_selection()
            self.clear_selection()
            return

        if self.cx > 0:
            line = self.lines[self.cy]
            # Remove char before cursor
            self.lines[self.cy] = line[: self.cx - 1] + line[self.cx :]
            self.cx -= 1
        else:
            # Join with previous line if any
            if self.cy > 0:
                prev_len = len(self.lines[self.cy - 1])
                self.lines[self.cy - 1] += self.lines[self.cy]
                del self.lines[self.cy]
                self.cy -= 1
                self.cx = prev_len

    def newline(self):
        if self.sel_active:
            self.delete_selection()
            self.clear_selection()
        line = self.lines[self.cy]
        new_line = line[self.cx :]
        self.lines[self.cy] = line[: self.cx]
        self.cy += 1
        self.lines.insert(self.cy, new_line)
        self.cx = 0

    def draw(self):
        self.stdscr.erase()
        # Draw visible lines with selection highlight if active
        sel_range = None
        if self.sel_active:
            (ax, ay), (bx, by) = self.get_selection_bounds()
            sel_range = (ax, ay, bx, by)  # start_x, start_y, end_x, end_y

        for i in range(self.view_height):
            lineno = self.scroll_y + i
            if lineno >= len(self.lines):
                break
            text = self.lines[lineno]
            # Apply horizontal scroll
            visible = text[self.scroll_x : self.scroll_x + self.view_width]
            try:
                if sel_range is None:
                    self.stdscr.addstr(i, 0, visible)
                else:
                    # Determine selection slice for this line (if any)
                    start_x, start_y, end_x, end_y = sel_range
                    # selection is [start, end) exclusive of end
                    if start_y == end_y == lineno:
                        # Single-line selection
                        s = max(start_x, self.scroll_x)
                        e = min(end_x, self.scroll_x + self.view_width)
                        pre = text[self.scroll_x : s]
                        mid = text[s:e]
                        post = text[e : self.scroll_x + self.view_width]
                        try:
                            self.stdscr.addstr(i, 0, pre)
                            if mid:
                                self.stdscr.attron(curses.A_REVERSE)
                                self.stdscr.addstr(i, len(pre), mid)
                                self.stdscr.attroff(curses.A_REVERSE)
                            if post:
                                self.stdscr.addstr(i, len(pre) + len(mid), post)
                        except curses.error:
                            pass
                    elif lineno == start_y:
                        # Selection starts on this line to end of line
                        s = max(start_x, self.scroll_x)
                        e = min(len(text), self.scroll_x + self.view_width)
                        pre = text[self.scroll_x : s]
                        mid = text[s:e]
                        post = text[e : self.scroll_x + self.view_width]
                        try:
                            self.stdscr.addstr(i, 0, pre)
                            if mid:
                                self.stdscr.attron(curses.A_REVERSE)
                                self.stdscr.addstr(i, len(pre), mid)
                                self.stdscr.attroff(curses.A_REVERSE)
                            if post:
                                self.stdscr.addstr(i, len(pre) + len(mid), post)
                        except curses.error:
                            pass
                    elif lineno == end_y:
                        # Selection ends on this line from start of line
                        s = self.scroll_x
                        e = min(end_x, self.scroll_x + self.view_width)
                        pre = text[self.scroll_x : s]
                        mid = text[s:e]
                        post = text[e : self.scroll_x + self.view_width]
                        try:
                            self.stdscr.addstr(i, 0, pre)
                            if mid:
                                self.stdscr.attron(curses.A_REVERSE)
                                self.stdscr.addstr(i, len(pre), mid)
                                self.stdscr.attroff(curses.A_REVERSE)
                            if post:
                                self.stdscr.addstr(i, len(pre) + len(mid), post)
                        except curses.error:
                            pass
                    elif start_y < lineno < end_y:
                        # Entire line selected
                        sel_text = text[self.scroll_x : self.scroll_x + self.view_width]
                        try:
                            if sel_text:
                                self.stdscr.attron(curses.A_REVERSE)
                                self.stdscr.addstr(i, 0, sel_text)
                                self.stdscr.attroff(curses.A_REVERSE)
                        except curses.error:
                            pass
                    else:
                        # Not selected
                        try:
                            self.stdscr.addstr(i, 0, visible)
                        except curses.error:
                            pass
            except curses.error:
                # ignore if writing to bottom-right corner triggers an exception
                pass

        # Status line (bottom) — include leader hints and selection mode indicator; show filename and status_message
        sel_mode_text = " [SELECT]" if self.sel_mode else ""
        file_text = f" file: {self.filename}" if self.filename else " file: (unnamed)"
        status_core = "Ln {}/{} Col {}/{}  --".format(
            self.cy + 1,
            max(1, len(self.lines)),
            self.cx + 1,
            max(1, len(self.lines[self.cy]) if self.lines else 1),
        )
        status = "{} Ctrl-W e:Command | Ctrl-W c:Copy Ctrl-W x:Cut Ctrl-W v:Paste Ctrl-W s:Save | F2:Select Mode | Shift+Arrows:Select{}{} ".format(
            status_core, sel_mode_text, file_text
        )
        # If we have a status message (like saved), append it
        if self.status_message:
            status += " -- " + self.status_message

        # Fill status line
        try:
            # Show status on last line
            self.stdscr.addstr(self.max_y - 1, 0, status[: self.max_x - 1])
            # Clear rest of status line
            if len(status) < self.max_x:
                self.stdscr.addstr(
                    self.max_y - 1, len(status), " " * (self.max_x - len(status) - 1)
                )
        except curses.error:
            pass

        # Move actual terminal cursor to visible position (unless selection active and cursor is on status)
        vis_y = self.cy - self.scroll_y
        vis_x = self.cx - self.scroll_x
        # don't move if outside view
        if 0 <= vis_y < self.view_height and 0 <= vis_x < self.view_width:
            try:
                self.stdscr.move(vis_y, vis_x)
            except curses.error:
                pass
        # Refresh
        self.stdscr.refresh()

    # Selection helpers
    def clear_selection(self):
        self.sel_active = False
        self.sel_anchor = (0, 0)

    def get_selection_bounds(self):
        # Returns ordered ((start_x, start_y), (end_x, end_y))
        ax, ay = self.sel_anchor
        bx, by = self.cx, self.cy
        if (ay, ax) <= (by, bx):
            return (ax, ay), (bx, by)
        else:
            return (bx, by), (ax, ay)

    def get_selected_text(self):
        if not self.sel_active:
            return ""
        (sx, sy), (ex, ey) = self.get_selection_bounds()
        if sy == ey:
            return self.lines[sy][sx:ex]
        parts = []
        parts.append(self.lines[sy][sx:])
        for line_no in range(sy + 1, ey):
            parts.append(self.lines[line_no])
        parts.append(self.lines[ey][:ex])
        return "\n".join(parts)

    def delete_selection(self):
        # Remove selected text and place cursor at start of selection
        if not self.sel_active:
            return
        (sx, sy), (ex, ey) = self.get_selection_bounds()
        if sy == ey:
            line = self.lines[sy]
            new_line = line[:sx] + line[ex:]
            self.lines[sy] = new_line
            self.cx = sx
            self.cy = sy
        else:
            # First line keeps content before sx
            first_part = self.lines[sy][:sx]
            # Last line keeps content after ex
            last_part = self.lines[ey][ex:]
            # Remove middle lines
            del self.lines[sy : ey + 1]
            # Insert merged line
            self.lines.insert(sy, first_part + last_part)
            self.cx = sx
            self.cy = sy

    def copy_selection(self):
        if not self.sel_active:
            self.status_message = "No selection to copy"
            return
        self.clipboard = self.get_selected_text()
        self.status_message = "Copied selection"

    def cut_selection(self):
        if not self.sel_active:
            self.status_message = "No selection to cut"
            return
        self.copy_selection()
        self.delete_selection()
        self.clear_selection()
        # After deletion, clamp and ensure visibility
        self.clamp_cursor()
        self.ensure_visible()
        self.status_message = "Cut selection"

    def paste_clipboard(self):
        if not self.clipboard:
            self.status_message = "Clipboard empty"
            return
        if self.sel_active:
            self.delete_selection()
            self.clear_selection()
        pieces = self.clipboard.split("\n")
        if len(pieces) == 1:
            # Single-line paste
            line = self.lines[self.cy]
            insert = pieces[0]
            self.lines[self.cy] = line[: self.cx] + insert + line[self.cx :]
            self.cx += len(insert)
        else:
            # Multi-line paste
            first = pieces[0]
            last = pieces[-1]
            middle = pieces[1:-1]
            line = self.lines[self.cy]
            before = line[: self.cx]
            after = line[self.cx :]
            # Replace current line with before+first
            self.lines[self.cy] = before + first
            insert_at = self.cy + 1
            # Insert middle lines
            for m in middle:
                self.lines.insert(insert_at, m)
                insert_at += 1
            # Insert last + after
            self.lines.insert(insert_at, last + after)
            # Move cursor to end of inserted content on last inserted line
            self.cy = insert_at
            self.cx = len(last)

        self.clamp_cursor()
        self.ensure_visible()
        self.status_message = "Pasted"

    def handle_shift_movement(self, key):
        # Called when shift+arrow detected; start or extend selection and move cursor
        if not self.sel_active:
            # start selection anchor at current cursor
            self.sel_anchor = (self.cx, self.cy)
            self.sel_active = True

        # Move cursor according to key but keep selection active
        if key == getattr(curses, "KEY_SLEFT", -1):
            # Move left
            if self.cx > 0:
                self.cx -= 1
            else:
                if self.cy > 0:
                    self.cy -= 1
                    self.cx = len(self.lines[self.cy])
        elif key == getattr(curses, "KEY_SRIGHT", -1):
            # Move right
            if self.cx < len(self.lines[self.cy]):
                self.cx += 1
            else:
                if self.cy + 1 < len(self.lines):
                    self.cy += 1
                    self.cx = 0
        elif key == getattr(curses, "KEY_SUP", -1):
            # Move up
            if self.cy > 0:
                self.cy -= 1
                self.cx = min(self.cx, len(self.lines[self.cy]))
        elif key == getattr(curses, "KEY_SDOWN", -1):
            # Move down
            if self.cy + 1 < len(self.lines):
                self.cy += 1
                self.cx = min(self.cx, len(self.lines[self.cy]))

        self.clamp_cursor()
        self.ensure_visible()

    def handle_leader(self):
        """
        Called when Ctrl-W is pressed. Waits for the next key and dispatches:
        e -> open command palette
        c -> copy selection
        x -> cut selection
        v -> paste clipboard
        s -> save (open save prompt)
        """
        # Blocking read for the next key
        next_ch = self.stdscr.getch()
        if next_ch == -1:
            return
        # Handle resize quickly
        if next_ch in (curses.KEY_RESIZE,):
            self.update_size()
            return

        # Map letters (case-insensitive)
        try:
            ch_char = chr(next_ch).lower()
        except Exception:
            ch_char = None

        if ch_char == "e":
            self.open_command_palette()
        elif ch_char == "c":
            self.copy_selection()
        elif ch_char == "x":
            self.cut_selection()
        elif ch_char == "v":
            self.paste_clipboard()
        elif ch_char == "s":
            # Open save prompt, prefill with current filename if present
            self.save_prompt(prefill=self.filename)
        else:
            # Unrecognized leader sequence: ignore
            pass

    def handle_key(self, ch):
        # Detect shift-arrow keys (not all terminals support these)
        sleft = getattr(curses, "KEY_SLEFT", None)
        sright = getattr(curses, "KEY_SRIGHT", None)
        sup = getattr(curses, "KEY_SUP", None)
        sdown = getattr(curses, "KEY_SDOWN", None)

        # Toggle selection mode with F2
        if ch == getattr(curses, "KEY_F2", -1):
            self.sel_mode = not self.sel_mode
            if self.sel_mode:
                # start selection anchor
                self.sel_active = True
                self.sel_anchor = (self.cx, self.cy)
            # If turning off sel_mode we keep the selection active so user can copy/cut
            return

        # If selection mode is active, use normal arrows to extend selection
        if self.sel_mode and ch in (
            curses.KEY_LEFT,
            curses.KEY_RIGHT,
            curses.KEY_UP,
            curses.KEY_DOWN,
        ):
            if ch == curses.KEY_LEFT:
                if self.cx > 0:
                    self.cx -= 1
                else:
                    if self.cy > 0:
                        self.cy -= 1
                        self.cx = len(self.lines[self.cy])
            elif ch == curses.KEY_RIGHT:
                if self.cx < len(self.lines[self.cy]):
                    self.cx += 1
                else:
                    if self.cy + 1 < len(self.lines):
                        self.cy += 1
                        self.cx = 0
            elif ch == curses.KEY_UP:
                if self.cy > 0:
                    self.cy -= 1
                    self.cx = min(self.cx, len(self.lines[self.cy]))
            elif ch == curses.KEY_DOWN:
                if self.cy + 1 < len(self.lines):
                    self.cy += 1
                    self.cx = min(self.cx, len(self.lines[self.cy]))
            # Ensure selection is active and anchored
            if not self.sel_active:
                self.sel_active = True
                self.sel_anchor = (self.cx, self.cy)
            self.clamp_cursor()
            self.ensure_visible()
            return

        # Movement with Shift -> selection (if terminal reports shifted arrows)
        if ch in (sleft, sright, sup, sdown):
            self.handle_shift_movement(ch)
            return

        # Movement without selection mode clears selection
        if ch == curses.KEY_LEFT:
            if self.cx > 0:
                self.cx -= 1
            else:
                if self.cy > 0:
                    self.cy -= 1
                    self.cx = len(self.lines[self.cy])
            self.clear_selection()
        elif ch == curses.KEY_RIGHT:
            if self.cx < len(self.lines[self.cy]):
                self.cx += 1
            else:
                if self.cy + 1 < len(self.lines):
                    self.cy += 1
                    self.cx = 0
            self.clear_selection()
        elif ch == curses.KEY_UP:
            if self.cy > 0:
                self.cy -= 1
                self.cx = min(self.cx, len(self.lines[self.cy]))
            self.clear_selection()
        elif ch == curses.KEY_DOWN:
            if self.cy + 1 < len(self.lines):
                self.cy += 1
                self.cx = min(self.cx, len(self.lines[self.cy]))
            self.clear_selection()
        elif ch in (curses.KEY_HOME,):
            self.cx = 0
            self.clear_selection()
        elif ch in (curses.KEY_END,):
            self.cx = len(self.lines[self.cy])
            self.clear_selection()
        elif ch in (10, 13):  # Enter
            self.newline()
            self.clear_selection()
        elif ch in (curses.KEY_BACKSPACE, 127, 8):
            self.backspace()
            self.clear_selection()
        elif ch == CTRL_W:
            # Leader key: wait for next key to decide
            self.handle_leader()
            # Keep selection behavior: leader actions manage selection themselves
        elif ch == CTRL_X:
            # Cut (direct)
            self.cut_selection()
        elif ch == CTRL_V:
            # Paste (direct)
            self.paste_clipboard()
            self.clear_selection()
        elif ch in (curses.KEY_RESIZE,):
            self.update_size()
        else:
            # Printable characters
            if 0 <= ch <= 255:
                if chr(ch).isprintable():
                    self.insert_char(chr(ch))
                    self.clear_selection()
            # ignore other special keys

        self.clamp_cursor()
        self.ensure_visible()

    def open_command_palette(self):
        """
        Open a single-line command prompt at the bottom. Enter submits the command,
        ESC cancels. Typing 'exit' then Enter will quit the editor.
        """
        prompt = ":"
        cmd_chars = []
        # Ensure cursor visible
        try:
            curses.curs_set(1)
        except curses.error:
            pass

        while True:
            # Render prompt + current input on bottom line
            try:
                display = prompt + "".join(cmd_chars)
                # Clip to available width - leave last column safe
                display = display[: self.max_x - 1]
                self.stdscr.addstr(self.max_y - 1, 0, display)
                # Clear rest of line if any
                if len(display) < self.max_x:
                    self.stdscr.addstr(
                        self.max_y - 1,
                        len(display),
                        " " * (self.max_x - len(display) - 1),
                    )
                # Move cursor to end of input
                self.stdscr.move(self.max_y - 1, len(display))
                self.stdscr.refresh()
            except curses.error:
                pass

            ch = self.stdscr.getch()
            if ch in (10, 13):  # Enter: submit
                cmd = "".join(cmd_chars).strip()
                if cmd == "exit":
                    self.should_quit = True
                break
            elif ch in (27,):  # ESC: cancel
                break
            elif ch in (curses.KEY_RESIZE,):
                # Update sizes and continue rendering
                self.update_size()
                continue
            elif ch in (curses.KEY_BACKSPACE, 127, 8):
                if cmd_chars:
                    cmd_chars.pop()
            else:
                # printable characters only
                if 0 <= ch <= 255:
                    c = chr(ch)
                    if c.isprintable():
                        # Append if there's room
                        if len(prompt) + len(cmd_chars) < self.max_x - 1:
                            cmd_chars.append(c)

        # After closing the command palette, redraw to refresh screen content and status
        try:
            curses.curs_set(1)
        except curses.error:
            pass
        self.stdscr.touchwin()
        self.stdscr.refresh()

    def save_prompt(self, prefill=None):
        """
        Open a single-line save prompt at the bottom. If prefill provided, prefill the filename.
        Enter: save to given filename (if non-empty). ESC: cancel.
        """
        prompt = "Save as: "
        cmd_chars = list(prefill) if prefill else []
        # Ensure cursor visible
        try:
            curses.curs_set(1)
        except curses.error:
            pass

        while True:
            try:
                display = prompt + "".join(cmd_chars)
                display = display[: self.max_x - 1]
                self.stdscr.addstr(self.max_y - 1, 0, display)
                if len(display) < self.max_x:
                    self.stdscr.addstr(
                        self.max_y - 1,
                        len(display),
                        " " * (self.max_x - len(display) - 1),
                    )
                # Move cursor to end of input
                self.stdscr.move(self.max_y - 1, len(display))
                self.stdscr.refresh()
            except curses.error:
                pass

            ch = self.stdscr.getch()
            if ch in (10, 13):  # Enter -> save
                filename = "".join(cmd_chars).strip()
                if filename:
                    try:
                        self.save_file(filename)
                        self.status_message = f"Saved to {filename}"
                    except Exception as e:
                        self.status_message = f"Error saving: {e}"
                else:
                    self.status_message = "Save cancelled (empty filename)"
                break
            elif ch in (27,):  # ESC
                self.status_message = "Save cancelled"
                break
            elif ch in (curses.KEY_RESIZE,):
                self.update_size()
                continue
            elif ch in (curses.KEY_BACKSPACE, 127, 8):
                if cmd_chars:
                    cmd_chars.pop()
            else:
                if 0 <= ch <= 255:
                    c = chr(ch)
                    if c.isprintable():
                        if len(prompt) + len(cmd_chars) < self.max_x - 1:
                            cmd_chars.append(c)

        # After closing the save prompt, redraw to refresh screen content and status
        try:
            curses.curs_set(1)
        except curses.error:
            pass
        self.stdscr.touchwin()
        self.stdscr.refresh()

    def save_file(self, filename):
        # Write buffer to file; updates current filename on success
        try:
            # Ensure directory exists for the file
            dirpath = os.path.dirname(filename)
            if dirpath and not os.path.exists(dirpath):
                os.makedirs(dirpath, exist_ok=True)
            with open(filename, "w", encoding="utf-8") as f:
                f.write("\n".join(self.lines))
            self.filename = filename
        except Exception:
            raise

    def open_file(self, filename):
        # Open existing file or create it if it doesn't exist
        self.filename = filename
        if os.path.exists(filename):
            try:
                with open(filename, "r", encoding="utf-8") as f:
                    data = f.read()
                # Keep trailing empty line behavior similar to normal editors
                self.lines = data.splitlines() if data != "" else [""]
                # If file ends with newline, splitlines() will drop the final empty line;
                # for simplicity we won't attempt to preserve exact trailing newline semantics.
            except Exception as e:
                self.lines = [""]
                self.status_message = f"Error opening {filename}: {e}"
        else:
            # Create the file (empty) and keep buffer empty
            try:
                # Ensure directory part exists
                dirpath = os.path.dirname(filename)
                if dirpath and not os.path.exists(dirpath):
                    os.makedirs(dirpath, exist_ok=True)
                open(filename, "w", encoding="utf-8").close()
                self.lines = [""]
                self.status_message = f"Created {filename}"
            except Exception as e:
                self.lines = [""]
                self.status_message = f"Error creating {filename}: {e}"

        # Reset cursor/scroll
        self.cx = 0
        self.cy = 0
        self.scroll_x = 0
        self.scroll_y = 0
        self.clamp_cursor()
        self.ensure_visible()

    def run(self):
        # Initial render
        self.stdscr.clear()
        try:
            curses.curs_set(1)
        except curses.error:
            pass
        self.update_size()
        self.draw()
        while not self.should_quit:
            try:
                ch = self.stdscr.getch()
            except KeyboardInterrupt:
                break
            if ch == -1:
                continue
            self.handle_key(ch)
            self.draw()


def main(stdscr):
    # Curses setup
    curses.raw()
    stdscr.keypad(True)
    curses.noecho()
    curses.cbreak()
    stdscr.timeout(-1)  # Blocking getch

    # Check for file argument
    filename = sys.argv[1] if len(sys.argv) > 1 else None
    editor = SimpleEditor(stdscr, filename=filename)
    editor.run()


if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except Exception as e:
        # If initialization fails, fall back to printing the exception so user can debug.
        print("Error starting editor:", e, file=sys.stderr)
        sys.exit(1)
