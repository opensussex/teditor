# Side-by-Side Code Comparison

## Example: Insert Character Method

### Python Version (ted.py)

```python
def insert_char(self, ch):
    # If selection active, replace selection with inserted char
    if self.sel_active:
        self.delete_selection()
        self.clear_selection()
    line = self.lines[self.cy]
    self.lines[self.cy] = line[: self.cx] + ch + line[self.cx :]
    self.cx += len(ch)
    self.dirty = True
```

### Pascal Version (ted.pas)

```pascal
procedure TSimpleEditor.InsertChar(const ch: String);
var
  line: String;
begin
  if sel_active then
  begin
    DeleteSelection;
    ClearSelection;
  end;
  
  line := lines[cy];
  lines[cy] := Copy(line, 1, cx) + ch + Copy(line, cx + 1, Length(line));
  cx := cx + Length(ch);
  dirty := True;
end;
```

### Key Differences

1. **Method Declaration**:
   - Python: `def insert_char(self, ch):`
   - Pascal: `procedure TSimpleEditor.InsertChar(const ch: String);`

2. **Variable Declaration**:
   - Python: Implicit typing
   - Pascal: Explicit `var line: String;`

3. **String Slicing**:
   - Python: `line[:self.cx]` (0-based, slice notation)
   - Pascal: `Copy(line, 1, cx)` (1-based, function call)

4. **Member Access**:
   - Python: `self.lines`, `self.cx`
   - Pascal: `lines`, `cx` (implicit self)

5. **Block Structure**:
   - Python: Indentation-based
   - Pascal: `begin`/`end` keywords

---

## Example: Selection Bounds Calculation

### Python Version

```python
def get_selection_bounds(self):
    ax, ay = self.sel_anchor
    bx, by = self.cx, self.cy
    if (ay < by) or (ay == by and ax < bx):
        return (ax, ay), (bx, by)
    else:
        return (bx, by), (ax, ay)
```

### Pascal Version

```pascal
procedure TSimpleEditor.GetSelectionBounds(out sx, sy, ex, ey: Integer);
begin
  if (sel_anchor_y < cy) or ((sel_anchor_y = cy) and (sel_anchor_x < cx)) then
  begin
    sx := sel_anchor_x;
    sy := sel_anchor_y;
    ex := cx;
    ey := cy;
  end
  else
  begin
    sx := cx;
    sy := cy;
    ex := sel_anchor_x;
    ey := sel_anchor_y;
  end;
end;
```

### Key Differences

1. **Return Values**:
   - Python: Returns tuple `((ax, ay), (bx, by))`
   - Pascal: Uses `out` parameters `sx, sy, ex, ey`

2. **Tuple Unpacking**:
   - Python: `ax, ay = self.sel_anchor`
   - Pascal: Separate variables `sel_anchor_x`, `sel_anchor_y`

3. **Comparison Operators**:
   - Python: `and`, `or`
   - Pascal: `and`, `or` (same keywords)

4. **Assignment**:
   - Python: `=`
   - Pascal: `:=`

---

## Example: Main Event Loop

### Python Version

```python
def run(self):
    while not self.should_quit:
        ch = self.stdscr.getch()
        
        if ch != -1:
            self.handle_key(ch)
            self.draw()
        
        now = time.time()
        elapsed = now - self._last_autosave
        if self.dirty and elapsed >= self.autosave_interval:
            self.autosave()
        
        self._clear_expired_status()
```

### Pascal Version

```pascal
procedure TSimpleEditor.Run;
var
  k: TKeyEvent;
  now_time: TDateTime;
  elapsed: Double;
begin
  InitKeyboard;
  
  while not should_quit do
  begin
    Draw;
    
    if PollKeyEvent <> 0 then
    begin
      k := GetKeyEvent;
      k := TranslateKeyEvent(k);
      HandleKey(k);
    end
    else
      Sleep(50);
    
    now_time := Now;
    elapsed := SecondsBetween(now_time, last_autosave);
    if dirty and (elapsed >= AUTOSAVE_INTERVAL) then
      Autosave;
    
    ClearExpiredStatus;
  end;
  
  DoneKeyboard;
end;
```

### Key Differences

1. **Input Handling**:
   - Python: `ch = self.stdscr.getch()` (blocking with timeout)
   - Pascal: `PollKeyEvent()` + `GetKeyEvent()` (explicit polling)

2. **Time Functions**:
   - Python: `time.time()` (Unix timestamp)
   - Pascal: `Now` (TDateTime), `SecondsBetween()`

3. **Initialization/Cleanup**:
   - Python: Handled by curses.wrapper
   - Pascal: Explicit `InitKeyboard` / `DoneKeyboard`

4. **Draw Timing**:
   - Python: Draw after key handling
   - Pascal: Draw at start of loop (before input)

---

## Example: File Save

### Python Version

```python
def save_file(self, filename):
    try:
        dirpath = os.path.dirname(filename)
        if dirpath and not os.path.exists(dirpath):
            os.makedirs(dirpath, exist_ok=True)
        with open(filename, "w", encoding="utf-8") as f:
            f.write("\n".join(self.lines))
        self.filename = filename
        self.dirty = False
        autosave = self._determine_autosave_path()
        try:
            if autosave and os.path.exists(autosave):
                os.remove(autosave)
                self._autosave_path = None
        except Exception:
            pass
    except Exception:
        raise
```

### Pascal Version

```pascal
procedure TSimpleEditor.SaveFile(const fname: String);
var
  dirpath: String;
  autosave_file: String;
begin
  dirpath := ExtractFilePath(fname);
  if (dirpath <> '') and (not DirectoryExists(dirpath)) then
    ForceDirectories(dirpath);
  
  lines.SaveToFile(fname);
  filename := fname;
  dirty := False;
  
  autosave_file := DetermineAutosavePath;
  if FileExists(autosave_file) then
  begin
    DeleteFile(autosave_file);
    autosave_path := '';
  end;
end;
```

### Key Differences

1. **File I/O**:
   - Python: `with open()` context manager, manual `write()`
   - Pascal: `TStringList.SaveToFile()` (built-in method)

2. **Path Operations**:
   - Python: `os.path.dirname()`, `os.makedirs()`
   - Pascal: `ExtractFilePath()`, `ForceDirectories()`

3. **File Checks**:
   - Python: `os.path.exists()`
   - Pascal: `FileExists()`, `DirectoryExists()`

4. **Exception Handling**:
   - Python: Nested try/except blocks
   - Pascal: No explicit exception handling (propagates to caller)

5. **String Joining**:
   - Python: `"\n".join(self.lines)`
   - Pascal: `TStringList.SaveToFile()` handles line endings automatically

---

## Summary of Translation Patterns

| Python Pattern | Pascal Equivalent | Notes |
|----------------|-------------------|-------|
| `self.method()` | `Method` | Implicit self in Pascal |
| `list[index]` | `list[index]` | Same syntax, different base (0 vs 1) |
| `str[start:end]` | `Copy(str, start, length)` | Different slicing approach |
| `len(str)` | `Length(str)` | Similar function names |
| `str.lower()` | `LowerCase(str)` | Function vs method |
| `if condition:` | `if condition then` | Explicit `then` keyword |
| `def method(self):` | `procedure Method;` | Different declaration syntax |
| `return value` | `Result := value` | Function result assignment |
| `try: ... except:` | `try ... except end;` | Similar structure |
| `with open() as f:` | `try ... finally end;` | Resource management |

## Conclusion

The conversion maintains logical equivalence while adapting to Pascal's:
- Explicit type system
- 1-based string indexing
- Procedural syntax
- Manual resource management
- Different standard library

Both versions are equally readable and maintainable, with Pascal offering compile-time safety and Python offering runtime flexibility.
