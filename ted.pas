program ted;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, Keyboard, Video;

const
  CTRL_W = $17;
  CTRL_X = $18;
  CTRL_V = $16;
  AUTOSAVE_INTERVAL = 5.0;
  STATUS_DURATION = 3.0;
  
  kbLeft = $4B00;
  kbRight = $4D00;
  kbUp = $4800;
  kbDown = $5000;
  kbHome = $4700;
  kbEnd = $4F00;
  kbF2 = $3C00;

type
  TSimpleEditor = class
  private
    lines: TStringList;
    cx, cy: Integer;
    scroll_x, scroll_y: Integer;
    max_x, max_y: Integer;
    view_height, view_width: Integer;
    should_quit: Boolean;
    
    sel_active: Boolean;
    sel_anchor_x, sel_anchor_y: Integer;
    sel_mode: Boolean;
    clipboard: String;
    
    filename: String;
    status_message: String;
    status_time: TDateTime;
    has_status_time: Boolean;
    
    autosave_path: String;
    last_autosave: TDateTime;
    dirty: Boolean;
    
    show_help: Boolean;
    
    procedure UpdateSize;
    procedure ClampCursor;
    procedure EnsureVisible;
    procedure SetStatus(const text: String);
    procedure ClearExpiredStatus;
    function DetermineAutosavePath: String;
    procedure Autosave;
    procedure CleanupAutosave;
    procedure InsertChar(const ch: String);
    procedure Backspace;
    procedure Newline;
    procedure Draw;
    procedure GetSelectionBounds(out sx, sy, ex, ey: Integer);
    function GetSelectedText: String;
    procedure DeleteSelection;
    procedure ClearSelection;
    procedure CopySelection;
    procedure CutSelection;
    procedure PasteClipboard;
    procedure HandleLeader;
    procedure OpenCommandPalette;
    procedure SavePrompt(const prefill: String);
    procedure SaveFile(const fname: String);
    procedure OpenFile(const fname: String);
    procedure HandleKey(const k: TKeyEvent);
    procedure Run;
  public
    constructor Create(const fname: String);
    destructor Destroy; override;
  end;

constructor TSimpleEditor.Create(const fname: String);
begin
  inherited Create;
  lines := TStringList.Create;
  lines.Add('');
  cx := 0;
  cy := 0;
  scroll_x := 0;
  scroll_y := 0;
  should_quit := False;
  
  sel_active := False;
  sel_anchor_x := 0;
  sel_anchor_y := 0;
  sel_mode := False;
  clipboard := '';
  
  filename := '';
  status_message := '';
  has_status_time := False;
  
  autosave_path := '';
  last_autosave := Now;
  dirty := False;
  
  show_help := False;
  
  UpdateSize;
  
  if fname <> '' then
    OpenFile(fname);
end;

destructor TSimpleEditor.Destroy;
begin
  CleanupAutosave;
  lines.Free;
  inherited Destroy;
end;

procedure TSimpleEditor.UpdateSize;
begin
  max_x := ScreenWidth;
  max_y := ScreenHeight;
  view_height := max_y - 1;
  if view_height < 1 then view_height := 1;
  view_width := max_x;
  if view_width < 1 then view_width := 1;
end;

procedure TSimpleEditor.ClampCursor;
var
  line_len: Integer;
begin
  if cy < 0 then cy := 0;
  if cy >= lines.Count then cy := lines.Count - 1;
  
  line_len := Length(lines[cy]);
  if cx < 0 then cx := 0;
  if cx > line_len then cx := line_len;
end;

procedure TSimpleEditor.EnsureVisible;
begin
  if cy < scroll_y then
    scroll_y := cy
  else if cy >= scroll_y + view_height then
    scroll_y := cy - view_height + 1;
    
  if cx < scroll_x then
    scroll_x := cx
  else if cx >= scroll_x + view_width then
    scroll_x := cx - view_width + 1;
end;

procedure TSimpleEditor.SetStatus(const text: String);
begin
  status_message := text;
  status_time := Now;
  has_status_time := True;
end;

procedure TSimpleEditor.ClearExpiredStatus;
begin
  if not has_status_time then Exit;
  if SecondsBetween(Now, status_time) >= STATUS_DURATION then
  begin
    status_message := '';
    has_status_time := False;
  end;
end;

function TSimpleEditor.DetermineAutosavePath: String;
var
  base, dirpath: String;
begin
  if filename <> '' then
  begin
    base := ExtractFileName(filename);
    dirpath := ExtractFilePath(filename);
    if dirpath = '' then dirpath := '.';
    Result := dirpath + PathDelim + '.' + base + '.autosave';
  end
  else
    Result := GetCurrentDir + PathDelim + '.ted_autosave';
end;

procedure TSimpleEditor.Autosave;
var
  path: String;
begin
  if not dirty then Exit;
  
  path := DetermineAutosavePath;
  try
    lines.SaveToFile(path);
    last_autosave := Now;
    autosave_path := path;
    dirty := False;
    SetStatus('Autosaved to ' + path);
  except
    on E: Exception do
      SetStatus('Autosave error: ' + E.Message);
  end;
end;

procedure TSimpleEditor.CleanupAutosave;
var
  path: String;
begin
  try
    path := DetermineAutosavePath;
    if FileExists(path) then
      DeleteFile(path);
    autosave_path := '';
  except
  end;
end;

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

procedure TSimpleEditor.Backspace;
var
  line: String;
  prev_len: Integer;
begin
  if sel_active then
  begin
    DeleteSelection;
    ClearSelection;
    dirty := True;
    Exit;
  end;
  
  if cx > 0 then
  begin
    line := lines[cy];
    lines[cy] := Copy(line, 1, cx - 1) + Copy(line, cx + 1, Length(line));
    cx := cx - 1;
    dirty := True;
  end
  else if cy > 0 then
  begin
    prev_len := Length(lines[cy - 1]);
    lines[cy - 1] := lines[cy - 1] + lines[cy];
    lines.Delete(cy);
    cy := cy - 1;
    cx := prev_len;
    dirty := True;
  end;
end;

procedure TSimpleEditor.Newline;
var
  line, new_line: String;
begin
  if sel_active then
  begin
    DeleteSelection;
    ClearSelection;
  end;
  
  line := lines[cy];
  new_line := Copy(line, cx + 1, Length(line));
  lines[cy] := Copy(line, 1, cx);
  cy := cy + 1;
  lines.Insert(cy, new_line);
  cx := 0;
  dirty := True;
end;

procedure TSimpleEditor.Draw;
var
  i, lineno: Integer;
  text, visible, status_line: String;
  sx, sy, ex, ey: Integer;
  s, e: Integer;
  pre_text, mid_text, post_text: String;
  vis_x, vis_y: Integer;
  x, y: Integer;
begin
  ClearExpiredStatus;
  ClearScreen;
  
  if sel_active then
    GetSelectionBounds(sx, sy, ex, ey);
  
  for i := 0 to view_height - 1 do
  begin
    lineno := scroll_y + i;
    if lineno >= lines.Count then Break;
    
    text := lines[lineno];
    
    if not sel_active then
    begin
      visible := Copy(text, scroll_x + 1, view_width);
      for x := 0 to Length(visible) - 1 do
        VideoBuf^[i * max_x + x] := Ord(visible[x + 1]) or ($07 shl 8);
    end
    else
    begin
      if (sy = ey) and (lineno = sy) then
      begin
        s := sx;
        if s < scroll_x then s := scroll_x;
        e := ex;
        if e > scroll_x + view_width then e := scroll_x + view_width;
        
        pre_text := Copy(text, scroll_x + 1, s - scroll_x);
        mid_text := Copy(text, s + 1, e - s);
        post_text := Copy(text, e + 1, scroll_x + view_width - e);
        
        x := 0;
        for y := 1 to Length(pre_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(pre_text[y]) or ($07 shl 8);
          Inc(x);
        end;
        
        for y := 1 to Length(mid_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(mid_text[y]) or ($70 shl 8);
          Inc(x);
        end;
        
        for y := 1 to Length(post_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(post_text[y]) or ($07 shl 8);
          Inc(x);
        end;
      end
      else if lineno = sy then
      begin
        s := sx;
        if s < scroll_x then s := scroll_x;
        e := Length(text);
        if e > scroll_x + view_width then e := scroll_x + view_width;
        
        pre_text := Copy(text, scroll_x + 1, s - scroll_x);
        mid_text := Copy(text, s + 1, e - s);
        
        x := 0;
        for y := 1 to Length(pre_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(pre_text[y]) or ($07 shl 8);
          Inc(x);
        end;
        
        for y := 1 to Length(mid_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(mid_text[y]) or ($70 shl 8);
          Inc(x);
        end;
      end
      else if lineno = ey then
      begin
        s := scroll_x;
        e := ex;
        if e > scroll_x + view_width then e := scroll_x + view_width;
        
        mid_text := Copy(text, s + 1, e - s);
        post_text := Copy(text, e + 1, scroll_x + view_width - e);
        
        x := 0;
        for y := 1 to Length(mid_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(mid_text[y]) or ($70 shl 8);
          Inc(x);
        end;
        
        for y := 1 to Length(post_text) do
        begin
          VideoBuf^[i * max_x + x] := Ord(post_text[y]) or ($07 shl 8);
          Inc(x);
        end;
      end
      else if (lineno > sy) and (lineno < ey) then
      begin
        visible := Copy(text, scroll_x + 1, view_width);
        for x := 0 to Length(visible) - 1 do
          VideoBuf^[i * max_x + x] := Ord(visible[x + 1]) or ($70 shl 8);
      end
      else
      begin
        visible := Copy(text, scroll_x + 1, view_width);
        for x := 0 to Length(visible) - 1 do
          VideoBuf^[i * max_x + x] := Ord(visible[x + 1]) or ($07 shl 8);
      end;
    end;
  end;
  
  status_line := Format('Line %d Col %d', [cy + 1, cx + 1]);
  if sel_mode then
    status_line := status_line + ' [SELECT]';
  if filename <> '' then
    status_line := status_line + ' | ' + filename
  else
    status_line := status_line + ' | (unnamed)';
  if status_message <> '' then
    status_line := status_line + ' | ' + status_message;
  
  if Length(status_line) > max_x then
    status_line := Copy(status_line, 1, max_x);
  
  for x := 0 to max_x - 1 do
  begin
    if x < Length(status_line) then
      VideoBuf^[(max_y - 1) * max_x + x] := Ord(status_line[x + 1]) or ($70 shl 8)
    else
      VideoBuf^[(max_y - 1) * max_x + x] := Ord(' ') or ($70 shl 8);
  end;
  
  vis_x := cx - scroll_x;
  vis_y := cy - scroll_y;
  SetCursorPos(vis_x, vis_y);
  
  UpdateScreen(False);
end;

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

function TSimpleEditor.GetSelectedText: String;
var
  sx, sy, ex, ey: Integer;
  i: Integer;
  line, first_part, last_part: String;
begin
  GetSelectionBounds(sx, sy, ex, ey);
  
  if sy = ey then
  begin
    line := lines[sy];
    Result := Copy(line, sx + 1, ex - sx);
  end
  else
  begin
    Result := '';
    line := lines[sy];
    first_part := Copy(line, sx + 1, Length(line));
    Result := first_part;
    
    for i := sy + 1 to ey - 1 do
      Result := Result + LineEnding + lines[i];
    
    line := lines[ey];
    last_part := Copy(line, 1, ex);
    Result := Result + LineEnding + last_part;
  end;
end;

procedure TSimpleEditor.DeleteSelection;
var
  sx, sy, ex, ey: Integer;
  first_part, last_part: String;
begin
  if not sel_active then Exit;
  
  GetSelectionBounds(sx, sy, ex, ey);
  
  if sy = ey then
  begin
    lines[sy] := Copy(lines[sy], 1, sx) + Copy(lines[sy], ex + 1, Length(lines[sy]));
    cx := sx;
    cy := sy;
  end
  else
  begin
    first_part := Copy(lines[sy], 1, sx);
    last_part := Copy(lines[ey], ex + 1, Length(lines[ey]));
    
    while ey >= sy do
    begin
      lines.Delete(sy);
      Dec(ey);
    end;
    
    lines.Insert(sy, first_part + last_part);
    cx := sx;
    cy := sy;
  end;
  
  dirty := True;
end;

procedure TSimpleEditor.ClearSelection;
begin
  sel_active := False;
end;

procedure TSimpleEditor.CopySelection;
begin
  if not sel_active then
  begin
    SetStatus('No selection to copy');
    Exit;
  end;
  
  clipboard := GetSelectedText;
  SetStatus('Copied selection');
end;

procedure TSimpleEditor.CutSelection;
begin
  if not sel_active then
  begin
    SetStatus('No selection to cut');
    Exit;
  end;
  
  CopySelection;
  DeleteSelection;
  ClearSelection;
  ClampCursor;
  EnsureVisible;
  SetStatus('Cut selection');
end;

procedure TSimpleEditor.PasteClipboard;
var
  pieces: TStringList;
  line, before_text, after_text: String;
  i, insert_at: Integer;
begin
  if clipboard = '' then
  begin
    SetStatus('Clipboard empty');
    Exit;
  end;
  
  if sel_active then
  begin
    DeleteSelection;
    ClearSelection;
  end;
  
  pieces := TStringList.Create;
  try
    pieces.Text := clipboard;
    
    if pieces.Count = 1 then
    begin
      line := lines[cy];
      lines[cy] := Copy(line, 1, cx) + pieces[0] + Copy(line, cx + 1, Length(line));
      cx := cx + Length(pieces[0]);
    end
    else if pieces.Count > 1 then
    begin
      line := lines[cy];
      before_text := Copy(line, 1, cx);
      after_text := Copy(line, cx + 1, Length(line));
      
      lines[cy] := before_text + pieces[0];
      insert_at := cy + 1;
      
      for i := 1 to pieces.Count - 2 do
      begin
        lines.Insert(insert_at, pieces[i]);
        Inc(insert_at);
      end;
      
      lines.Insert(insert_at, pieces[pieces.Count - 1] + after_text);
      cy := insert_at;
      cx := Length(pieces[pieces.Count - 1]);
    end;
  finally
    pieces.Free;
  end;
  
  ClampCursor;
  EnsureVisible;
  dirty := True;
  SetStatus('Pasted');
end;

procedure TSimpleEditor.HandleLeader;
var
  k: TKeyEvent;
  ch: Char;
  lch: String;
begin
  k := GetKeyEvent;
  k := TranslateKeyEvent(k);
  
  if GetKeyEventFlags(k) = 0 then
  begin
    ch := GetKeyEventChar(k);
    lch := LowerCase(ch);
    
    if Length(lch) > 0 then
    case lch[1] of
      'e': OpenCommandPalette;
      'c': CopySelection;
      'x': CutSelection;
      'v': PasteClipboard;
      's': SavePrompt(filename);
      'h': show_help := not show_help;
    end;
  end;
end;

procedure TSimpleEditor.OpenCommandPalette;
var
  prompt: String;
  cmd_chars: String;
  k: TKeyEvent;
  ch: Char;
  display: String;
  x: Integer;
begin
  prompt := ':';
  cmd_chars := '';
  
  while True do
  begin
    display := prompt + cmd_chars;
    if Length(display) > max_x then
      display := Copy(display, 1, max_x);
    
    for x := 0 to max_x - 1 do
    begin
      if x < Length(display) then
        VideoBuf^[(max_y - 1) * max_x + x] := Ord(display[x + 1]) or ($70 shl 8)
      else
        VideoBuf^[(max_y - 1) * max_x + x] := Ord(' ') or ($70 shl 8);
    end;
    
    SetCursorPos(Length(display), max_y - 1);
    UpdateScreen(False);
    
    k := GetKeyEvent;
    k := TranslateKeyEvent(k);
    
    if GetKeyEventFlags(k) = kbASCII then
    begin
      ch := GetKeyEventChar(k);
      if ch = #13 then
      begin
        if Trim(cmd_chars) = 'exit' then
          should_quit := True;
        Break;
      end
      else if ch = #27 then
        Break
      else if ch = #8 then
      begin
        if Length(cmd_chars) > 0 then
          Delete(cmd_chars, Length(cmd_chars), 1);
      end
      else if (Ord(ch) >= 32) and (Ord(ch) <= 126) then
      begin
        if Length(prompt) + Length(cmd_chars) < max_x - 1 then
          cmd_chars := cmd_chars + ch;
      end;
    end;
  end;
end;

procedure TSimpleEditor.SavePrompt(const prefill: String);
var
  prompt: String;
  cmd_chars: String;
  k: TKeyEvent;
  ch: Char;
  display: String;
  fname: String;
  x: Integer;
begin
  prompt := 'Save as: ';
  cmd_chars := prefill;
  
  while True do
  begin
    display := prompt + cmd_chars;
    if Length(display) > max_x then
      display := Copy(display, 1, max_x);
    
    for x := 0 to max_x - 1 do
    begin
      if x < Length(display) then
        VideoBuf^[(max_y - 1) * max_x + x] := Ord(display[x + 1]) or ($70 shl 8)
      else
        VideoBuf^[(max_y - 1) * max_x + x] := Ord(' ') or ($70 shl 8);
    end;
    
    SetCursorPos(Length(display), max_y - 1);
    UpdateScreen(False);
    
    k := GetKeyEvent;
    k := TranslateKeyEvent(k);
    
    if GetKeyEventFlags(k) = kbASCII then
    begin
      ch := GetKeyEventChar(k);
      if ch = #13 then
      begin
        fname := Trim(cmd_chars);
        if fname <> '' then
        begin
          try
            SaveFile(fname);
            SetStatus('Saved to ' + fname);
          except
            on E: Exception do
              SetStatus('Error saving: ' + E.Message);
          end;
        end
        else
          SetStatus('Save cancelled (empty filename)');
        Break;
      end
      else if ch = #27 then
      begin
        SetStatus('Save cancelled');
        Break;
      end
      else if ch = #8 then
      begin
        if Length(cmd_chars) > 0 then
          Delete(cmd_chars, Length(cmd_chars), 1);
      end
      else if (Ord(ch) >= 32) and (Ord(ch) <= 126) then
      begin
        if Length(prompt) + Length(cmd_chars) < max_x - 1 then
          cmd_chars := cmd_chars + ch;
      end;
    end;
  end;
end;

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

procedure TSimpleEditor.OpenFile(const fname: String);
begin
  filename := fname;
  if FileExists(fname) then
  begin
    try
      lines.LoadFromFile(fname);
      if lines.Count = 0 then
        lines.Add('');
      dirty := False;
    except
      on E: Exception do
      begin
        lines.Clear;
        lines.Add('');
        SetStatus('Error opening ' + fname + ': ' + E.Message);
      end;
    end;
  end
  else
  begin
    lines.Clear;
    lines.Add('');
    dirty := False;
  end;
end;

procedure TSimpleEditor.HandleKey(const k: TKeyEvent);
var
  kc: Word;
  ch: Char;
  flags: Byte;
begin
  kc := GetKeyEventCode(k);
  flags := GetKeyEventFlags(k);
  
  if kc = kbF2 then
  begin
    sel_mode := not sel_mode;
    if sel_mode and not sel_active then
    begin
      sel_anchor_x := cx;
      sel_anchor_y := cy;
      sel_active := True;
    end
    else if not sel_mode then
      ClearSelection;
  end
  else if sel_mode and ((kc = kbLeft) or (kc = kbRight) or (kc = kbUp) or (kc = kbDown)) then
  begin
    if not sel_active then
    begin
      sel_anchor_x := cx;
      sel_anchor_y := cy;
      sel_active := True;
    end;
    
    case kc of
      kbLeft:
        if cx > 0 then
          Dec(cx)
        else if cy > 0 then
        begin
          Dec(cy);
          cx := Length(lines[cy]);
        end;
      kbRight:
        if cx < Length(lines[cy]) then
          Inc(cx)
        else if cy + 1 < lines.Count then
        begin
          Inc(cy);
          cx := 0;
        end;
      kbUp:
        if cy > 0 then
        begin
          Dec(cy);
          if cx > Length(lines[cy]) then
            cx := Length(lines[cy]);
        end;
      kbDown:
        if cy + 1 < lines.Count then
        begin
          Inc(cy);
          if cx > Length(lines[cy]) then
            cx := Length(lines[cy]);
        end;
    end;
    
    ClampCursor;
    EnsureVisible;
  end
  else if (kc = kbLeft) or (kc = kbRight) or (kc = kbUp) or (kc = kbDown) then
  begin
    ClearSelection;
    
    case kc of
      kbLeft:
        if cx > 0 then
          Dec(cx)
        else if cy > 0 then
        begin
          Dec(cy);
          cx := Length(lines[cy]);
        end;
      kbRight:
        if cx < Length(lines[cy]) then
          Inc(cx)
        else if cy + 1 < lines.Count then
        begin
          Inc(cy);
          cx := 0;
        end;
      kbUp:
        if cy > 0 then
        begin
          Dec(cy);
          if cx > Length(lines[cy]) then
            cx := Length(lines[cy]);
        end;
      kbDown:
        if cy + 1 < lines.Count then
        begin
          Inc(cy);
          if cx > Length(lines[cy]) then
            cx := Length(lines[cy]);
        end;
    end;
    
    ClampCursor;
    EnsureVisible;
  end
  else if kc = kbHome then
  begin
    cx := 0;
    EnsureVisible;
  end
  else if kc = kbEnd then
  begin
    cx := Length(lines[cy]);
    EnsureVisible;
  end
  else if flags = kbASCII then
  begin
    ch := GetKeyEventChar(k);
    
    if ch = #13 then
      Newline
    else if ch = #8 then
      Backspace
    else if ch = Chr(CTRL_W) then
      HandleLeader
    else if ch = Chr(CTRL_X) then
      CutSelection
    else if ch = Chr(CTRL_V) then
      PasteClipboard
    else if (Ord(ch) >= 32) and (Ord(ch) <= 126) then
      InsertChar(ch);
  end;
end;

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

var
  editor: TSimpleEditor;
  fname: String;

begin
  InitVideo;
  
  if ParamCount > 0 then
    fname := ParamStr(1)
  else
    fname := '';
  
  editor := TSimpleEditor.Create(fname);
  try
    editor.Run;
  finally
    editor.Free;
  end;
  
  DoneVideo;
end.
