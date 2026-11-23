{ uCommands - everything is a command.

  The toolbar, the menus and the keyboard all call RunCommand with the same
  key, so there is exactly one copy of each command. (The 1999 way was three
  copies, one per OnClick, all subtly different.) }
unit uCommands;

{$mode objfpc}{$H+}

interface

uses fPart;

procedure RunCommand(const ACmd: string);
{ Double-click in the tree or the timeline: change a feature's numbers. }
procedure EditFeature(p: TPartWindow; i: Integer);
procedure SetTurbo(AOn: Boolean);

implementation

uses Classes, SysUtils, Forms, Controls, Graphics, IntfGraphics, FPImage,
  uModel, uKernel, uMesh, uStl, uImport, uDocs, uArt, uGif, uSheet, uStability,
  fDialogs, fWizard, fMain;

procedure Status(const s: string);
begin
  SetStatus(s);
end;

function NeedPart(out p: TPartWindow): Boolean;
begin
  p := MainForm.ActivePart;
  Result := p <> nil;
  if not Result then
    MsgBox('There is no part open.' + LineEnding + 'Choose File, New Part first.', MB_EXCLAMATION);
end;

procedure SetTurbo(AOn: Boolean);
begin
  Turbo := AOn;
  if not Turbo then Y2KHappened := False;
  MainForm.TurboChanged;
  MainForm.RefreshAllParts;
  if Turbo then Status('Turbo on: 33 MHz. Authentic 1999 behaviour enabled.')
  else Status('Turbo off: 66 MHz. Everything works again.');
end;

{ ---- File ---- }

procedure CmdNew;
var
  slot: Integer;
begin
  slot := NewDocSlot;
  if slot = 0 then
  begin
    MsgBox('Too many parts open. Sixteen ought to be enough for anybody.', MB_EXCLAMATION);
    Exit;
  end;
  MainForm.AddPart(slot);
  Status('New part created.');
end;

{ Opens a part (or a SolidCraft design, rebuilt here). True if it worked. }
function OpenPath(const APath: string): Boolean;
var
  slot, r: Integer;
  notice, err: string;
  p: TPartWindow;
begin
  Result := False;
  slot := NewDocSlot;
  if slot = 0 then
  begin
    MsgBox('Too many parts open. Close one first.', MB_EXCLAMATION);
    Exit;
  end;
  if IsSolidCraftDesign(APath) then
  begin
    // a design from SolidCraft itself: rebuilt here, saved as a new .sc2
    Screen.Cursor := crHourGlass;
    try
      if not ImportSolidCraft(APath, Docs[slot], notice, err) then
      begin
        Screen.Cursor := crDefault;
        FreeDocSlot(slot);
        MsgBox(err, MB_EXCLAMATION, 'Open');
        Exit;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    DocPath[slot] := '';
  end
  else
  begin
    r := LoadDesign(Docs[slot], APath);
    if (r <> 0) and (r <> 5) then
    begin
      FreeDocSlot(slot);
      MsgBox(LastFileError, MB_EXCLAMATION);
      Exit;
    end;
    if r = 5 then MsgBox(LastFileError, MB_INFO);
    DocPath[slot] := APath;
    Docs[slot].Title := FileTitle(APath);
    notice := '';
    // an upgraded SolidCraft 98 part is saved as a new .sc2, never over the old file
    if Upgraded98 then
    begin
      DocPath[slot] := '';
      MsgBox('This part was made in SolidCraft 98, and has been upgraded to SolidCraft 2000.' + LineEnding + LineEnding +
        'Save it to keep the new format. SolidCraft 98 won''t be able to open it again.' + LineEnding +
        '(That''s progress.)', MB_INFO);
    end;
  end;
  p := MainForm.AddPart(slot);
  p.ZoomFit;
  Status('Opened ' + APath);
  if notice <> '' then MsgBox(notice, MB_INFO, 'Open');
  Result := True;
end;

procedure CmdOpen;
var
  path: string;
begin
  path := MainForm.AskFileName(False, '',
    'All SolidCraft files (*.sc2, *.sc98, *.solidcraft)|*.sc2;*.sc98;*.solidcraft|SolidCraft 2000 Parts (*.sc2)|*.sc2|SolidCraft 98 Parts (*.sc98)|*.sc98|SolidCraft Designs (*.solidcraft)|*.solidcraft',
    PART_EXT);
  if path <> '' then OpenPath(path);
end;

function FileLen(const APath: string): Int64;
var
  sr: TSearchRec;
begin
  Result := 0;
  if FindFirst(APath, faAnyFile, sr) = 0 then Result := sr.Size;
  FindClose(sr);
end;

function SaveTo(p: TPartWindow; const APath: string): Boolean;
var
  slot: Integer;
begin
  slot := p.Slot;
  Result := SaveDesign(Docs[slot], APath);
  if not Result then
  begin
    MsgBox(LastFileError, MB_CRITICAL);
    Exit;
  end;
  DocPath[slot] := APath;
  Docs[slot].Title := FileTitle(APath);
  DocDirty[slot] := False;
  p.RefreshNames;
  MainForm.PartsChanged;
end;

{ My Documents/<name>, with (2), (3)... if that's taken. }
function SafeDocumentsPath(const AName: string): string;
var
  dir, base: string;
  n: Integer;
begin
  dir := IncludeTrailingPathDelimiter(GetUserDir) + 'Documents' + PathDelim;
  if not DirectoryExists(dir) then dir := ExtractFilePath(ParamStr(0));
  base := FileTitle(AName);
  Result := dir + base + '.' + PART_EXT;
  n := 1;
  while FileExists(Result) do
  begin
    Inc(n);
    Result := dir + base + ' (' + IntToStr(n) + ').' + PART_EXT;
  end;
end;

{ Saving to drive A:. There isn't one, so the part goes to the hard disk
  first, and with Turbo on we put on a show of floppies for it. }
procedure FloppySave(p: TPartWindow; const AName: string);
const
  PREVIEW_BYTES = 3686454;   // a 1280 x 960 24-bit BMP, "for faster opening"
var
  slot: Integer;
  real: string;
  bytes: Double;
begin
  slot := p.Slot;
  if DirectoryExists('A:\') then
  begin
    // a real floppy drive, in this day and age: save to it
    real := 'A:\' + FileTitle(AName) + '.' + PART_EXT;
    if not SaveTo(p, real) then Exit;
    Status('Saved ' + real + ' (' + IntToStr(FileLen(real)) + ' bytes). Remember to label the disk.');
    Exit;
  end;
  if not Turbo then
  begin
    MsgBox('There is no drive A: on this PC.' + LineEnding + LineEnding +
      'Use File, Save As to save the part to the hard disk.', MB_EXCLAMATION);
    Exit;
  end;
  real := DocPath[slot];
  if real = '' then real := SafeDocumentsPath(AName);
  if not SaveTo(p, real) then Exit;
  bytes := FileLen(real) + PREVIEW_BYTES;
  if RunFloppy(FileTitle(real) + '.' + PART_EXT, bytes) then
    MsgBox('Copied ' + FormatFloat('#,##0', bytes) + ' bytes to ' + IntToStr(-Trunc(-bytes / FLOPPY_BYTES)) + ' disks.' +
      LineEnding + LineEnding + 'Turbo saves include an uncompressed preview bitmap, for speed.' + LineEnding +
      '(This PC has no drive A:, so the part itself is safe in' + LineEnding + real + ')', MB_INFO)
  else
    MsgBox('Copy cancelled. The part is safe in' + LineEnding + real, MB_INFO);
  Status('Saved ' + real);
end;

procedure CmdSave(AAs: Boolean);
var
  p: TPartWindow;
  path: string;
begin
  if not NeedPart(p) then Exit;
  path := DocPath[p.Slot];
  if AAs or (path = '') then
  begin
    path := MainForm.AskFileName(True, Docs[p.Slot].Title, '', '');
    if path = '' then Exit;
  end;
  // A:\ with no floppy drive is the pretend floppy; a real A: is just a drive
  if (UpperCase(Copy(path, 1, 3)) = 'A:\') and not DirectoryExists('A:\') then
  begin
    FloppySave(p, Copy(path, 4, MaxInt));
    Exit;
  end;
  if SaveTo(p, path) then
    Status('Saved ' + path + ' (' + IntToStr(FileLen(path)) + ' bytes)');
end;

procedure CmdFloppy;
var
  p: TPartWindow;
begin
  if not NeedPart(p) then Exit;
  FloppySave(p, Docs[p.Slot].Title + '.' + PART_EXT);
end;

{ ---- File > Publish to Web ----
  A home page for your part, in the style of the day: a marquee, a hit
  counter, an "under construction" GIF and a picture of the part. Three
  files in the folder you pick; nothing goes near a network. }

function MakeFileName(const s: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(s) do
    if s[i] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-'] then Result := Result + s[i];
  if Result = '' then Result := 'mypart';
end;

function HtmlText(const s: string): string;
begin
  Result := StringReplace(s, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

{ The viewport as it is now, squeezed into the 16 colours. }
procedure WritePartGif(bmp: TBitmap; const APath: string);
var
  img: TLazIntfImage;
  px: TPixels;
  x, y, w, h: Integer;
  c: TFPColor;
begin
  w := bmp.Width; h := bmp.Height;
  SetLength(px, w, h);
  img := bmp.CreateIntfImage;
  try
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
      begin
        c := img.Colors[x, y];
        px[x, y] := NearestQB(c.red shr 8, c.green shr 8, c.blue shr 8);
      end;
  finally
    img.Free;
  end;
  GifBegin(w, h, False);
  GifFrame(px, w, h, 0, -1);
  GifSave(APath);
end;

{ Two frames of the road sign, at 3x, blinking twice a second. }
procedure AddSignFrame(const AKey: string);
var
  px: TPixels;
  x, y: Integer;
  ch: Char;
begin
  SetLength(px, 48, 48);
  for y := 0 to 47 do
    for x := 0 to 47 do
    begin
      ch := IconRow(AKey, y div 3)[x div 3 + 1];
      if ch = '.' then px[x, y] := 13
      else if ch <= '9' then px[x, y] := Ord(ch) - Ord('0')
      else px[x, y] := Ord(ch) - Ord('A') + 10;
    end;
  GifFrame(px, 48, 48, 50, 13);          // magenta is see-through
end;

procedure WriteHtml(slot: Integer; const APath, AGif: string);
var
  sl: TStringList;
  i: Integer;
  t, hits: string;
begin
  t := HtmlText(Docs[slot].Title);
  hits := FormatFloat('000000', 427 + Random(9000));    // nobody wants to be visitor 1
  sl := TStringList.Create;
  try
    sl.Add('<HTML>');
    sl.Add('<HEAD><TITLE>' + t + ' - My SolidCraft 2000 Part!!!</TITLE></HEAD>');
    sl.Add('<BODY BGCOLOR="#000080" TEXT="#FFFF00" LINK="#00FFFF" VLINK="#FF00FF">');
    sl.Add('<CENTER>');
    sl.Add('<MARQUEE BEHAVIOR="alternate"><FONT FACE="Comic Sans MS" SIZE="6"><B>Welcome to ' + t + '!!!</B></FONT></MARQUEE>');
    sl.Add('<P><IMG SRC="construction.gif" WIDTH="48" HEIGHT="48"> <FONT SIZE="5"><B>This page is under construction!</B></FONT> <IMG SRC="construction.gif" WIDTH="48" HEIGHT="48"></P>');
    sl.Add('<HR WIDTH="80%">');
    sl.Add('<P><IMG SRC="' + AGif + '" BORDER="4" ALT="' + t + ' (wireframe)"></P>');
    sl.Add('<TABLE BORDER="3" CELLPADDING="4" BGCOLOR="#C0C0C0">');
    sl.Add('<TR><TH><FONT COLOR="#000000">#</FONT></TH><TH><FONT COLOR="#000000">Feature</FONT></TH><TH><FONT COLOR="#000000">What it is</FONT></TH></TR>');
    for i := 1 to Docs[slot].Count do
      sl.Add('<TR><TD><FONT COLOR="#000000">' + IntToStr(i) + '</FONT></TD><TD><FONT COLOR="#000000">' +
        HtmlText(FeatureName(Docs[slot], i)) + '</FONT></TD><TD><FONT COLOR="#000000">' +
        HtmlText(Describe(Docs[slot], i)) + '</FONT></TD></TR>');
    sl.Add('</TABLE>');
    sl.Add('<P>You are visitor number');
    sl.Add('<TABLE BORDER="1" CELLPADDING="2" CELLSPACING="0" BGCOLOR="#000000"><TR>');
    for i := 1 to Length(hits) do
      sl.Add('<TD><FONT FACE="Courier New" COLOR="#00FF00" SIZE="5"><B>' + hits[i] + '</B></FONT></TD>');
    sl.Add('</TR></TABLE></P>');
    sl.Add('<P><A HREF="#">Sign my guestbook!</A> | <A HREF="#">View my guestbook!</A> | <A HREF="#">Next site in the CAD Web Ring &gt;&gt;</A></P>');
    sl.Add('<HR WIDTH="80%">');
    sl.Add('<FONT SIZE="2">Best viewed in IE5 at 800x600. Made with SolidCraft 2000 ' + HtmlText(APP_EDITION) + ', ' + HtmlText(APP_VERSION) + '.<BR>');
    sl.Add('Last updated ' + FormatDateTime('mmmm d, yyyy', ClockNow) + '.</FONT>');
    sl.Add('</CENTER>');
    sl.Add('</BODY>');
    sl.Add('</HTML>');
    sl.WriteBOM := False;
    sl.SaveToFile(APath);
  finally
    sl.Free;
  end;
end;

procedure CmdPublish;
var
  p: TPartWindow;
  html, dir, base: string;
begin
  if not NeedPart(p) then Exit;
  html := MainForm.AskFileName(True, MakeFileName(Docs[p.Slot].Title) + '.htm', 'Web Pages (*.htm)|*.htm', 'htm');
  if html = '' then Exit;
  dir := ExtractFilePath(html);
  base := FileTitle(html);
  Screen.Cursor := crHourGlass;
  try
    Status('Rendering ' + base + '.gif...');
    Application.ProcessMessages;
    WritePartGif(p.ViewBitmap, dir + base + '.gif');
    GifBegin(48, 48, True);
    AddSignFrame('Construction');
    AddSignFrame('Construction2');
    GifSave(dir + 'construction.gif');
    try
      WriteHtml(p.Slot, html, base + '.gif');
    except
      on e: Exception do
      begin
        Screen.Cursor := crDefault;
        MsgBox('Could not write ' + html + LineEnding + LineEnding + e.Message, MB_CRITICAL);
        Exit;
      end;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  Status('Published ' + html);
  MsgBox('Your part is on the World Wide Web!*' + LineEnding + LineEnding + html + LineEnding + LineEnding +
    '* On your hard disk. Upload it with your FTP program.', MB_INFO, 'Publish to Web');
end;

{ ---- File > Export for Rapid Prototyping ---- }

procedure CmdExportStl;
var
  p: TPartWindow;
  t: TTriArray;
  n: Integer;
  err, path: string;
begin
  if not NeedPart(p) then Exit;
  n := MeshDesign(Docs[p.Slot], t, MESH_SEGS, err);
  if n = 0 then
  begin
    MsgBox('There is nothing solid to export.' + LineEnding + LineEnding +
      'Sketches are flat. Extrude or revolve one first.', MB_EXCLAMATION);
    Exit;
  end;
  path := MainForm.AskFileName(True, Docs[p.Slot].Title + '.stl', 'Stereolithography (*.stl)|*.stl', 'stl');
  if path = '' then Exit;
  Screen.Cursor := crHourGlass;
  Status('Writing ' + IntToStr(n) + ' triangles...');
  try
    if not WriteStl(t, n, path, Docs[p.Slot].Title) then
    begin
      Screen.Cursor := crDefault;
      MsgBox('Could not write ' + path, MB_CRITICAL);
      Exit;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  Status('Exported ' + path + ' (' + IntToStr(n) + ' triangles)');
  if err <> '' then
    MsgBox('Exported ' + IntToStr(n) + ' triangles, but left out: ' + err, MB_EXCLAMATION, 'Export for Rapid Prototyping')
  else
    MsgBox('Exported ' + IntToStr(n) + ' triangles to' + LineEnding + path + LineEnding + LineEnding +
      'Send it to your service bureau. Allow 3 to 5 working days.', MB_INFO, 'Export for Rapid Prototyping');
end;

procedure CmdShaded;
begin
  ViewShaded := not ViewShaded;
  MainForm.ShadedChanged;
  if not ViewShaded then Status('Wireframe.');
  MainForm.RefreshAllParts;
end;

procedure CmdClose;
var
  p: TPartWindow;
begin
  if NeedPart(p) then MainForm.ClosePart(p);
end;

{ ---- Features ---- }

function PlacePrompts: string;
begin
  Result := 'On feature # (0 = ground)|Height above that (mm)|Face (0 top, 1-4 sides)';
end;

{ The "on top of" number must be 0 or an extrude that comes before this
  sketch, and the face 0 (its top) or, Service Pack 1, one of its sides. }
function PlaceOk(const d: TDesign; i: Integer; v, face: Double): Boolean;
var
  n, last: Integer;
begin
  if v = 0 then Exit(True);
  if i = 0 then last := d.Count else last := i - 1;
  n := Trunc(v);
  if (n = v) and (n >= 1) and (n <= last) and (d.F[n].Kind = FK_EXTRUDE) then
  begin
    if (face <> Int(face)) or (face < FACE_TOP) or (face > FACE_LEFT) then
    begin
      MsgBox('Face is 0 for the top, or a side: 1 front, 2 right, 3 back, 4 left.' + LineEnding + LineEnding +
        'On a side, X runs along the face, Y goes up it from the bottom, and' + LineEnding +
        'Height above that is how far out from it.', MB_INFO);
      Exit(False);
    end;
    if (face <> FACE_TOP) and (d.F[d.F[n].Ref].Kind <> FK_SKETCH_RECT) then
    begin
      MsgBox(FeatureName(d, n) + ' is round. It has no flat sides to sketch on.' + LineEnding +
        '(Round sides are planned for SolidCraft XP.)', MB_EXCLAMATION);
      Exit(False);
    end;
    Exit(True);
  end;
  MsgBox('A sketch can sit on the ground (0) or on top of an extrude that comes before it.' + LineEnding +
    'Use the number from the # column of the timeline.', MB_EXCLAMATION);
  Result := False;
end;

function Min2(a, b: Double): Double;
begin
  if a < b then Result := a else Result := b;
end;

procedure SketchCentre(const s: TFeature; out x, y: Double);
begin
  if s.Kind = FK_SKETCH_CIRCLE then
  begin
    x := s.X; y := s.Y;
  end
  else
  begin
    x := s.X + s.P1 / 2; y := s.Y + s.P2 / 2;
  end;
end;

function OneSideOfY(const s: TFeature): Boolean;
begin
  if s.Kind = FK_SKETCH_CIRCLE then
    Result := (s.X - s.P1 >= 0) or (s.X + s.P1 <= 0)
  else
    Result := (s.X >= 0) or (s.X + s.P1 <= 0);
end;

{ Cal knows two more things in 2000, and says them once each. }
procedure CalSays(const ASay, ATopic: string);
begin
  if MainForm <> nil then MainForm.CalPop(ASay, ATopic);
end;

{ The one dialog per kind of feature, for New and for Edit. i is the feature
  being edited (0 for a new one). Fills f and returns True on OK, if the
  numbers make sense. }
function AskFeature(const d: TDesign; i: Integer; var f: TFeature): Boolean;
var
  title, sWord, sWhole, sNow, sSides: string;
  s, b, g, inset: TFeature;
  k, m, q, mt, mb: Integer;
  x1, y1, x2, y2, side, wr: Double;
  v: array[0..MAX_FIELDS - 1] of Double absolute ParamValue;
begin
  Result := False;
  if i = 0 then title := '' else title := 'Edit ' + FeatureName(d, i) + ': ';
  case f.Kind of
    FK_SKETCH_RECT:
      begin
        if not AskParams(title + 'Sketch Rectangle',
          'Width (mm)|Height (mm)|Corner X (mm)|Corner Y (mm)|Corner radius (mm)|' + PlacePrompts,
          Fmt0(f.P1) + '|' + Fmt0(f.P2) + '|' + Fmt0(f.X) + '|' + Fmt0(f.Y) + '|' + Fmt0(f.P3) + '|' +
          Fmt0(f.Ref) + '|' + Fmt0(f.Z) + '|' + IntToStr(SketchFace(f))) then Exit;
        if not PlaceOk(d, i, v[5], v[7]) then Exit;
        if (v[0] <= 0) or (v[1] <= 0) then
        begin
          MsgBox('Width and height must be more than zero.', MB_EXCLAMATION);
          Exit;
        end;
        if (v[4] < 0) or (v[4] * 2 > Min2(v[0], v[1])) then
        begin
          MsgBox('The corner radius must be between 0 and half the shorter side.', MB_EXCLAMATION);
          Exit;
        end;
        if (v[4] > 0) and (f.P3 = 0) then
          CalSays('It looks like you''re trying to round an edge!' + LineEnding +
            '(A corner radius rounds the upright ones. For the top ones, try Features, Fillet.)', 'fillet');
        f.P1 := v[0]; f.P2 := v[1];
        f.X := v[2]; f.Y := v[3];
        f.P3 := v[4];
        f.Ref := Trunc(v[5]); f.Z := v[6];
        if f.Ref > 0 then f.Reserved[1] := v[7] else f.Reserved[1] := FACE_TOP;
      end;

    FK_SKETCH_CIRCLE:
      begin
        if not AskParams(title + 'Sketch Circle', 'Radius (mm)|Centre X (mm)|Centre Y (mm)|' + PlacePrompts,
          Fmt0(f.P1) + '|' + Fmt0(f.X) + '|' + Fmt0(f.Y) + '|' + Fmt0(f.Ref) + '|' + Fmt0(f.Z) + '|' +
          IntToStr(SketchFace(f))) then Exit;
        if not PlaceOk(d, i, v[3], v[5]) then Exit;
        if v[0] <= 0 then
        begin
          MsgBox('The radius must be more than zero.', MB_EXCLAMATION);
          Exit;
        end;
        f.P1 := v[0];
        f.X := v[1]; f.Y := v[2];
        f.Ref := Trunc(v[3]); f.Z := v[4];
        if f.Ref > 0 then f.Reserved[1] := v[5] else f.Reserved[1] := FACE_TOP;
      end;

    FK_EXTRUDE:
      begin
        if not AskParams(title + 'Extrude ' + FeatureName(d, f.Ref), 'Depth (mm)', Fmt0(f.P1)) then Exit;
        if v[0] <= 0 then
        begin
          MsgBox('The depth must be more than zero.', MB_EXCLAMATION);
          Exit;
        end;
        f.P1 := v[0];
      end;

    FK_REVOLVE:
      begin
        if not AskParams(title + 'Revolve ' + FeatureName(d, f.Ref) + ' about Y', 'Angle (degrees)', Fmt0(f.P1)) then Exit;
        if (v[0] = 0) or (Abs(v[0]) > 360) then
        begin
          MsgBox('The angle must be between 1 and 360 degrees.', MB_EXCLAMATION);
          Exit;
        end;
        s := d.F[f.Ref];
        if not OneSideOfY(s) then
        begin
          MsgBox('The sketch crosses the Y axis, so revolving it would turn the part inside out.' + LineEnding +
            'Move the sketch so it''s all on one side of X = 0.', MB_EXCLAMATION);
          Exit;
        end;
        f.P1 := v[0];
      end;

    FK_FILLET, FK_CHAMFER:
      begin
        b := d.F[f.Ref];
        s := d.F[b.Ref];
        // Service Pack 1: which sides of the top and the bottom, added up
        sSides := 'Top sides (15 = all)|Bottom sides (0 = none)';
        sNow := '|' + IntToStr(FinishTop(f)) + '|' + IntToStr(FinishBottom(f));
        if f.Kind = FK_CHAMFER then
        begin
          sWord := 'distance'; sWhole := 'A chamfer that big would cut a whole face away.';
          if not AskParams(title + 'Chamfer the edges of ' + FeatureName(d, f.Ref) + ', at 45' + #194#176,
            'Distance (mm)|' + sSides, Fmt0(f.P1) + sNow) then Exit;
        end
        else
        begin
          sWord := 'radius'; sWhole := 'A fillet that big would round a whole face away.';
          if not AskParams(title + 'Fillet the edges of ' + FeatureName(d, f.Ref),
            'Radius (mm)|' + sSides, Fmt0(f.P1) + sNow) then Exit;
        end;
        if v[0] <= 0 then
        begin
          MsgBox('The ' + sWord + ' must be more than zero.', MB_EXCLAMATION);
          Exit;
        end;
        mt := Round(v[1]); mb := Round(v[2]);
        if (mt <> v[1]) or (mb <> v[2]) or (mt < 0) or (mt > SIDES_ALL) or (mb < 0) or (mb > SIDES_ALL) or (mt + mb = 0) then
        begin
          MsgBox('Add up the sides you want: 1 front, 2 right, 4 back, 8 left.' + LineEnding +
            '15 is all four, 0 is none. Back and left is 12.' + LineEnding + LineEnding +
            '(In 2000 this was considered user-friendly.)', MB_INFO);
          Exit;
        end;
        if not SidesOk(s, mt) or not SidesOk(s, mb) then
        begin
          if s.Kind = FK_SKETCH_CIRCLE then MsgBox('A circle has one edge at the top and one at the bottom.' + LineEnding +
            'Its sides are all or nothing: 15 or 0.', MB_EXCLAMATION)
          else MsgBox('A rectangle with rounded corners goes round in one piece.' + LineEnding +
            'Its sides are all or nothing: 15 or 0.', MB_EXCLAMATION);
          Exit;
        end;
        if (mt > 0) and (mb > 0) and (2 * v[0] > Abs(b.P1) + 0.000001) then
        begin
          MsgBox('Top and bottom both: the ' + sWord + ' can be at most half of ' + FeatureName(d, f.Ref) +
            '''s height (' + Fmt0(Abs(b.P1) / 2) + ' mm).', MB_EXCLAMATION);
          Exit;
        end;
        if v[0] > Abs(b.P1) + 0.000001 then
        begin
          MsgBox('That ' + sWord + ' is bigger than ' + FeatureName(d, f.Ref) + ' is tall (' + Fmt0(Abs(b.P1)) + ' mm).', MB_EXCLAMATION);
          Exit;
        end;
        if not SidesFit(s, mt, v[0]) or not SidesFit(s, mb, v[0]) then
        begin
          MsgBox(sWhole + LineEnding + 'Try a smaller ' + sWord + ', or fewer sides.', MB_EXCLAMATION);
          Exit;
        end;
        // the holes in the top have to stay clear of the rounded edge
        inset := SideInset(s, mt, v[0]);
        for k := 1 to d.Count do
          if (k <> i) and (d.F[k].Kind = FK_HOLE) and (d.F[k].Ref = f.Ref) and (d.F[k].Suppressed = 0) then
            if not HolesInside(inset, d.F[k]) then
            begin
              MsgBox(FeatureName(d, k) + ' is too close to the edge for a ' + Fmt0(v[0]) + ' mm ' + LowerCase(KindName(f.Kind)) + '.' + LineEnding +
                'Try a smaller ' + sWord + ', or move the hole in.', MB_EXCLAMATION);
              Exit;
            end;
        f.P1 := v[0];
        f.Reserved[1] := SIDES_ALL - mt;         // the top sides left sharp: 0 is all of them rounded
        f.Reserved[2] := mb;
      end;

    FK_SM_BASE:
      begin
        if not AskParams(title + 'Base Flange from ' + FeatureName(d, f.Ref),
          'Thickness (mm)|Inside bend radius (mm)|K-factor (0 to 1)',
          SMFmt(f.P1) + '|' + SMFmt(f.P2) + '|' + SMFmt(f.P3)) then Exit;
        if (v[0] <= 0) or (v[1] < 0) or (v[2] < 0) or (v[2] > 1) then
        begin
          MsgBox('The thickness must be more than zero, the bend radius zero or more,' + LineEnding +
            'and the K-factor between 0 and 1. (Ask the shop. They''ll say 0.44.)', MB_EXCLAMATION);
          Exit;
        end;
        f.P1 := v[0]; f.P2 := v[1]; f.P3 := v[2];
      end;

    FK_SM_EDGE:
      begin
        if not AskParams(title + 'Edge Flange on ' + FeatureName(d, f.Ref),
          'Edge (0 front, 1 right, 2 back, 3 left)|Length (mm)|Angle (degrees)|Bend relief (0 none, 1 rect, 2 obround, 3 tear)|Relief width (mm, 0 = thickness)',
          SMFmt(f.X) + '|' + SMFmt(f.P1) + '|' + SMFmt(f.P2) + '|' + SMFmt(f.P3) + '|' + SMFmt(f.Z)) then Exit;
        if (v[0] <> Int(v[0])) or (v[0] < 0) or (v[0] > 3) then
        begin
          MsgBox('The edge is a number: 0 for the front, 1 right, 2 back, 3 left.', MB_EXCLAMATION);
          Exit;
        end;
        if (v[1] <= 0) or (v[2] <= 0) or (v[2] > 180) then
        begin
          MsgBox('The length must be more than zero, and the angle between 1 and 180 degrees.', MB_EXCLAMATION);
          Exit;
        end;
        if (v[3] <> Int(v[3])) or (v[3] < 0) or (v[3] > 3) or (v[4] < 0) then
        begin
          MsgBox('The bend relief is a number: 0 none, 1 rectangular, 2 obround, 3 tear.' + LineEnding +
            'The relief width is zero or more.', MB_EXCLAMATION);
          Exit;
        end;
        for k := 1 to d.Count do
          if (k <> i) and (d.F[k].Kind = FK_SM_EDGE) and (d.F[k].Ref = f.Ref) and (d.F[k].X = v[0]) then
          begin
            MsgBox('The ' + EdgeNameOf(Round(v[0])) + ' edge already has ' + FeatureName(d, k) + ' on it.' + LineEnding +
              'Pick another edge. (Flanges on flanges: SolidCraft XP.)', MB_EXCLAMATION);
            Exit;
          end;
        side := d.F[d.F[f.Ref].Ref].P1;
        if (v[0] = 1) or (v[0] = 3) then side := d.F[d.F[f.Ref].Ref].P2;
        wr := v[4];
        if wr <= 0 then wr := d.F[f.Ref].P1;
        if (v[3] <> SM_RELIEF_NONE) and (side <= 4 * wr) then
        begin
          MsgBox('That edge is too short for its relief: the flange stops ' + SMFmt(2 * wr) + ' mm in from each end.', MB_EXCLAMATION);
          Exit;
        end;
        if v[3] = SM_RELIEF_NONE then
          MsgBox('No bend relief. The corners will tear when it''s bent.' + LineEnding + LineEnding +
            '(SolidCraft 2000 will draw it anyway. So will the shop.)', MB_INFO);
        f.X := v[0]; f.P1 := v[1]; f.P2 := v[2];
        f.P3 := v[3]; f.Z := v[4];
      end;

    FK_SM_FLAT:
      begin
        MsgBox('A flat pattern has no numbers to change.' + LineEnding +
          'Sheet Metal, Flat Pattern folds the part and unfolds it again.', MB_INFO);
        Exit;
      end;

    FK_FOREIGN:
      begin
        if Pos('fillet', LowerCase(f.Info)) > 0 then
          MsgBox(f.Name + ' is a fillet from SolidCraft, which rounds the edges it was given, one by one.' + LineEnding + LineEnding +
            'SolidCraft 2000 rounds whole sides of an extrude''s top and bottom, and these aren''t that.' + LineEnding +
            'The rest requires SolidCraft XP. (Features, Fillet rounds the sides you add up.)', MB_INFO)
        else
          MsgBox(f.Name + ' is a ' + LowerCase(f.Info) + ' from SolidCraft.' + LineEnding + LineEnding +
            'Requires SolidCraft XP.', MB_INFO);
        Exit;
      end;

    FK_HOLE:
      begin
        b := d.F[f.Ref];
        s := d.F[b.Ref];
        // Service Pack 1: Count, and the pattern's shape, in the same dialog
        if not AskParams(title + 'Hole on top face of ' + FeatureName(d, f.Ref),
          'Diameter (mm)|Depth (mm, 0 = through all)|Centre X (mm)|Centre Y (mm)|' +
          'Count (1 = one hole)|Bolt circle dia. (0 = a row)|Row spacing (mm)|Angle (degrees)',
          Fmt0(f.P1) + '|' + Fmt0(f.P2) + '|' + Fmt0(f.X) + '|' + Fmt0(f.Y) + '|' +
          IntToStr(HoleCount(f)) + '|' + Fmt0(f.Reserved[1]) + '|' + Fmt0(f.Reserved[2]) + '|' + Fmt0(f.Reserved[3])) then Exit;
        if (v[0] <= 0) or (v[1] < 0) then
        begin
          MsgBox('The diameter must be more than zero, and the depth zero or more.', MB_EXCLAMATION);
          Exit;
        end;
        if (v[4] <> Int(v[4])) or (v[4] < 1) or (v[4] > MAX_PATTERN) then
        begin
          MsgBox('Count must be a whole number from 1 to ' + IntToStr(MAX_PATTERN) + '.' + LineEnding +
            '(' + IntToStr(MAX_PATTERN) + ' holes ought to be enough for anybody.)', MB_EXCLAMATION);
          Exit;
        end;
        if v[5] < 0 then
        begin
          MsgBox('The bolt circle diameter must be zero (for a row) or more.', MB_EXCLAMATION);
          Exit;
        end;
        g := f;
        g.P1 := v[0]; g.P2 := v[1];
        g.X := v[2]; g.Y := v[3];
        g.P3 := v[4];
        g.Reserved[1] := v[5]; g.Reserved[2] := v[6]; g.Reserved[3] := v[7];
        if HoleCount(g) > 1 then
          // the holes of the pattern mustn't run into each other
          for m := 0 to HoleCount(g) - 2 do
          begin
            HoleAt(g, m, x1, y1);
            for q := m + 1 to HoleCount(g) - 1 do
            begin
              HoleAt(g, q, x2, y2);
              if Sqrt(Sqr(x1 - x2) + Sqr(y1 - y2)) < g.P1 + 0.01 then
              begin
                if g.Reserved[1] > 0 then
                  MsgBox('The holes in the pattern would run into each other.' + LineEnding +
                    'Make the bolt circle bigger, or the holes fewer or smaller.', MB_EXCLAMATION)
                else
                  MsgBox('The holes in the pattern would run into each other.' + LineEnding +
                    'Make the row spacing more than the diameter.', MB_EXCLAMATION);
                Exit;
              end;
            end;
          end;
        s := TopFace(d, f.Ref);          // less the fillet, if it has one
        if not HolesInside(s, g) then
        begin
          if HoleCount(g) > 1 then sWord := 'Not all the holes fit on the face. One would fall off the edge'
          else sWord := 'That hole doesn''t fit on the face. It would fall off the edge';
          if FilletOf(d, f.Ref) > 0 then
            sWord := sWord + ', or into the ' + LowerCase(KindName(d.F[FilletOf(d, f.Ref)].Kind)) + '.'
          else
            sWord := sWord + '.';
          MsgBox(sWord, MB_EXCLAMATION);
          Exit;
        end;
        if g.P2 > b.P1 + 0.000001 then
        begin
          MsgBox('That''s deeper than ' + FeatureName(d, f.Ref) + ' is tall.' + LineEnding +
            'Use depth 0 for a hole all the way through.', MB_EXCLAMATION);
          Exit;
        end;
        for k := 1 to d.Count do
          if (k <> i) and (d.F[k].Kind = FK_HOLE) and (d.F[k].Ref = f.Ref) then
            for m := 0 to HoleCount(g) - 1 do
            begin
              HoleAt(g, m, x1, y1);
              for q := 0 to HoleCount(d.F[k]) - 1 do
              begin
                HoleAt(d.F[k], q, x2, y2);
                if Sqrt(Sqr(x1 - x2) + Sqr(y1 - y2)) < (d.F[k].P1 + g.P1) / 2 + 0.01 then
                begin
                  if HoleCount(g) > 1 then sWord := 'A hole of the pattern' else sWord := 'That hole';
                  MsgBox(sWord + ' would run into ' + FeatureName(d, k) + '.', MB_EXCLAMATION);
                  Exit;
                end;
              end;
            end;
        f := g;
      end;
  end;
  Result := True;
end;

function Commit(p: TPartWindow; const f: TFeature): Boolean;
var
  i: Integer;
  before: TDesign;
begin
  Result := False;
  before := Docs[p.Slot];
  i := AddFeature(Docs[p.Slot], f);
  if i = 0 then
  begin
    MsgBox('Subscript out of range.' + LineEnding + LineEnding + 'A part can have ' + IntToStr(MAX_FEATURES) +
      ' features. Nobody will ever need more.', MB_CRITICAL);
    Exit;
  end;
  HistoryRemember(p.Slot, before, 'Add ' + FeatureName(Docs[p.Slot], i));
  DocDirty[p.Slot] := True;
  p.RefreshAll(True);
  MainForm.PartsChanged;
  Status(FeatureName(Docs[p.Slot], i) + ' created: ' + Describe(Docs[p.Slot], i));
  Result := True;
  if f.Kind = FK_SKETCH_RECT then CalSays('It looks like you''re drawing a box.', 'box');
  if f.Kind = FK_FILLET then CalSays('It looks like you''re trying to round an edge!', 'fillet');
  if f.Kind = FK_CHAMFER then CalSays('It looks like you''re trying to take the corner off!', 'chamfer');
end;

function BlankFeature(AKind: Integer): TFeature;
begin
  Result := Default(TFeature);
  Result.Kind := AKind;
end;

{ The extrude picked in the tree or timeline (a hole, a fillet or a chamfer
  counts as its extrude), or 0. }
function SelectedExtrude(p: TPartWindow): Integer;
var
  b: Integer;
begin
  Result := 0;
  b := p.Selected;
  if (b < 1) or (b > Docs[p.Slot].Count) then Exit;
  if (Docs[p.Slot].F[b].Kind = FK_HOLE) or IsEdgeFinish(Docs[p.Slot].F[b].Kind) then b := Docs[p.Slot].F[b].Ref;
  if (b >= 1) and (Docs[p.Slot].F[b].Kind = FK_EXTRUDE) then Result := b;
end;

procedure CmdSketchRect;
var
  p: TPartWindow;
  f: TFeature;
begin
  if not NeedPart(p) then Exit;
  f := BlankFeature(FK_SKETCH_RECT);
  f.P1 := 40; f.P2 := 30;
  f.Ref := SelectedExtrude(p);
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

procedure CmdSketchCircle;
var
  p: TPartWindow;
  f: TFeature;
begin
  if not NeedPart(p) then Exit;
  f := BlankFeature(FK_SKETCH_CIRCLE);
  f.P1 := 15;
  f.Ref := SelectedExtrude(p);
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

procedure CmdExtrude;
var
  p: TPartWindow;
  f: TFeature;
begin
  if not NeedPart(p) then Exit;
  f := BlankFeature(FK_EXTRUDE);
  f.Ref := LastFreeSketch(Docs[p.Slot]);
  if f.Ref = 0 then
  begin
    MsgBox('Extrude needs a sketch to extrude.' + LineEnding + 'Sketch a rectangle or a circle first.', MB_EXCLAMATION);
    Exit;
  end;
  f.P1 := 20;
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

procedure CmdRevolve;
var
  p: TPartWindow;
  f: TFeature;
begin
  if not NeedPart(p) then Exit;
  f := BlankFeature(FK_REVOLVE);
  f.Ref := LastFreeSketch(Docs[p.Slot]);
  if f.Ref = 0 then
  begin
    MsgBox('Revolve needs a sketch to revolve.' + LineEnding + 'Sketch a rectangle or a circle first.', MB_EXCLAMATION);
    Exit;
  end;
  f.P1 := 360;
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

{ A hole goes on the top face of the selected extrude, or the last one. }
procedure CmdHole;
var
  p: TPartWindow;
  f: TFeature;
  b: Integer;
begin
  if not NeedPart(p) then Exit;
  b := SelectedExtrude(p);
  if b = 0 then b := LastSolid(Docs[p.Slot]);
  if b = 0 then
  begin
    MsgBox('A hole goes on the top face of an extrude.' + LineEnding + 'Sketch something and extrude it first.', MB_EXCLAMATION);
    Exit;
  end;
  f := BlankFeature(FK_HOLE);
  f.Ref := b;
  f.P1 := 8;
  f.P3 := 1;                       // one hole; more makes a pattern
  f.Reserved[2] := 20;             // the spacing, if it becomes a row
  SketchCentre(Docs[p.Slot].F[Docs[p.Slot].F[b].Ref], f.X, f.Y);
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

{ NEW IN 2000. A fillet rounds the top edges of the selected extrude (a hole,
  a fillet or a chamfer counts as its extrude), or of the last one. A chamfer
  (Service Pack 1) bevels them instead. An extrude gets one or the other. }
procedure CmdEdgeFinish(AKind: Integer);
var
  p: TPartWindow;
  f: TFeature;
  b, j: Integer;
  s: TFeature;
  m: Double;
  verb: string;
begin
  if not NeedPart(p) then Exit;
  b := SelectedExtrude(p);
  if b = 0 then b := LastSolid(Docs[p.Slot]);
  if b = 0 then
  begin
    if AKind = FK_CHAMFER then verb := ' bevels' else verb := ' rounds';
    MsgBox('A ' + LowerCase(KindName(AKind)) + verb + ' the edges of an extrude.' + LineEnding +
      'Sketch something and extrude it first.', MB_EXCLAMATION);
    Exit;
  end;
  for j := b + 1 to Docs[p.Slot].Count do
    if IsEdgeFinish(Docs[p.Slot].F[j].Kind) and (Docs[p.Slot].F[j].Ref = b) then
    begin
      MsgBox(FeatureName(Docs[p.Slot], b) + ' already has a ' + LowerCase(KindName(Docs[p.Slot].F[j].Kind)) + ', ' +
        FeatureName(Docs[p.Slot], j) + '.' + LineEnding + LineEnding +
        'SolidCraft 2000 finishes the top edges of an extrude once: a fillet or a chamfer.' + LineEnding +
        'Edit ' + FeatureName(Docs[p.Slot], j) + ' to change it, or delete it first.' + LineEnding +
        '(Fillets on chamfers are planned for SolidCraft XP.)', MB_INFO);
      Exit;
    end;
  s := Docs[p.Slot].F[Docs[p.Slot].F[b].Ref];
  // a sensible first guess: 2 mm, or less on something small
  m := Abs(Docs[p.Slot].F[b].P1);
  if s.Kind = FK_SKETCH_RECT then
  begin
    if s.P1 / 2 < m then m := s.P1 / 2;
    if s.P2 / 2 < m then m := s.P2 / 2;
  end
  else if s.P1 < m then m := s.P1;
  f := BlankFeature(AKind);
  f.Ref := b;
  f.P1 := 2;
  if f.P1 > m / 2 then f.P1 := Int(m / 2 * 10) / 10;
  if f.P1 <= 0 then f.P1 := 0.1;
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

{ ---- Sheet Metal ---- }

procedure CmdBendTable;
begin
  if RunBendTableWizard then
    MsgBox('Bend table "' + SMTableName + '" created.' + LineEnding + LineEnding +
      'New base flanges will use it. Base flanges you''ve already made keep their own numbers.', MB_INFO);
end;

procedure CmdSMBase;
var
  p: TPartWindow;
  f: TFeature;
  s: Integer;
begin
  if not NeedPart(p) then Exit;
  s := LastFreeSketch(Docs[p.Slot]);
  if s = 0 then
  begin
    MsgBox('A base flange is made from a rectangle sketch.' + LineEnding + 'Sketch a rectangle first.', MB_EXCLAMATION);
    Exit;
  end;
  if (Docs[p.Slot].F[s].Kind <> FK_SKETCH_RECT) or (Docs[p.Slot].F[s].P3 > 0) then
  begin
    MsgBox(FeatureName(Docs[p.Slot], s) + ' isn''t a rectangle with square corners.' + LineEnding + LineEnding +
      'Base flanges from other shapes require SolidCraft XP.', MB_EXCLAMATION);
    Exit;
  end;
  if not SMTableSet then
  begin
    MsgBox('Before you can make sheet metal parts, SolidCraft 2000 needs a bend table.' + LineEnding + LineEnding +
      'The Bend Table Wizard will now help you create one.', MB_INFO);
    if not RunBendTableWizard then Exit;
  end;
  f := BlankFeature(FK_SM_BASE);
  f.Ref := s;
  f.P1 := SMTableT; f.P2 := SMTableR; f.P3 := SMTableK;
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

procedure CmdSMEdge;
var
  p: TPartWindow;
  f: TFeature;
  b, e, j: Integer;
  taken: Boolean;
begin
  if not NeedPart(p) then Exit;
  b := SMLastBase(Docs[p.Slot]);
  if b = 0 then
  begin
    MsgBox('An edge flange goes on the edge of a base flange.' + LineEnding +
      'Choose Sheet Metal, Base Flange first.', MB_EXCLAMATION);
    Exit;
  end;
  // the first edge that's free
  e := 0;
  while e <= 3 do
  begin
    taken := False;
    for j := b + 1 to Docs[p.Slot].Count do
      if (Docs[p.Slot].F[j].Kind = FK_SM_EDGE) and (Docs[p.Slot].F[j].Ref = b) and (Docs[p.Slot].F[j].X = e) then taken := True;
    if not taken then Break;
    Inc(e);
  end;
  if e > 3 then
  begin
    MsgBox('All four edges of ' + FeatureName(Docs[p.Slot], b) + ' have flanges.' + LineEnding +
      'That''s a box. Well done.', MB_INFO);
    Exit;
  end;
  f := BlankFeature(FK_SM_EDGE);
  f.Ref := b;
  f.X := e;
  f.P1 := 10 * Docs[p.Slot].F[b].P1;
  if f.P1 < 5 then f.P1 := 5;
  f.P2 := 90;
  f.P3 := SM_RELIEF_RECT;
  if AskFeature(Docs[p.Slot], 0, f) then Commit(p, f);
end;

{ Unfolds the part (adding a Flat Pattern the first time) and writes its DXF;
  or, if it's flat, folds it back up. }
procedure CmdSMFlat;
var
  p: TPartWindow;
  slot, b, j: Integer;
  f: TFeature;
  path, dir: string;
begin
  if not NeedPart(p) then Exit;
  slot := p.Slot;
  b := SMLastBase(Docs[slot]);
  if b = 0 then
  begin
    MsgBox('Only sheet metal can be unfolded.' + LineEnding + 'Choose Sheet Metal, Base Flange first.', MB_EXCLAMATION);
    Exit;
  end;
  j := b + 1;
  while (j <= Docs[slot].Count) and not ((Docs[slot].F[j].Kind = FK_SM_FLAT) and (Docs[slot].F[j].Ref = b)) do Inc(j);
  if j <= Docs[slot].Count then
  begin
    if Docs[slot].F[j].Suppressed = 0 then
    begin
      HistoryRemember(slot, Docs[slot], 'Fold ' + FeatureName(Docs[slot], b));
      Docs[slot].F[j].Suppressed := 1;
      DocDirty[slot] := True;
      p.RefreshAll(False);
      Status('Folded.');
      Exit;
    end;
    HistoryRemember(slot, Docs[slot], 'Unfold ' + FeatureName(Docs[slot], b));
    Docs[slot].F[j].Suppressed := 0;
  end
  else
  begin
    f := BlankFeature(FK_SM_FLAT);
    f.Ref := b;
    if not Commit(p, f) then Exit;
    j := Docs[slot].Count;
  end;
  // MOUNTI~1.DXF, next to the part (or in the Documents folder if it's never been saved)
  if DocPath[slot] <> '' then dir := ExtractFilePath(DocPath[slot])
  else
  begin
    dir := IncludeTrailingPathDelimiter(GetUserDir) + 'Documents' + PathDelim;
    if not DirectoryExists(dir) then dir := ExtractFilePath(ParamStr(0));
  end;
  path := FlatPatternPath(dir, Docs[slot].Title);
  Docs[slot].F[j].Info := ExtractFileName(path);
  DocDirty[slot] := True;
  p.RefreshAll(False);
  if WriteFlatDxf(Docs[slot], b, path) then
  begin
    MsgBox('Flat pattern saved as' + LineEnding + path + LineEnding + LineEnding +
      'The file name is 8.3, for the nesting software in the shop, which runs on DOS.', MB_INFO);
    Status('Unfolded. Flat pattern saved as ' + path);
  end
  else
    MsgBox('Run-time error ''75'':' + LineEnding + LineEnding + 'Path/File access error' + LineEnding + LineEnding +
      '(While writing the flat pattern: ' + path + ')', MB_CRITICAL);
end;

procedure EditFeature(p: TPartWindow; i: Integer);
var
  slot, j: Integer;
  f: TFeature;
  bad: string;
begin
  slot := p.Slot;
  if (i < 1) or (i > Docs[slot].Count) then Exit;
  f := Docs[slot].F[i];
  if not AskFeature(Docs[slot], i, f) then Exit;
  HistoryRemember(slot, Docs[slot], 'Edit ' + FeatureName(Docs[slot], i));
  Docs[slot].F[i] := f;
  DocDirty[slot] := True;
  p.RefreshAll(False);
  MainForm.PartsChanged;
  Status(FeatureName(Docs[slot], i) + ' changed: ' + Describe(Docs[slot], i));
  // anything built on it may not fit any more; say so instead of hiding it
  bad := '';
  for j := i + 1 to Docs[slot].Count do
    if not RefOk(Docs[slot], j) then bad := bad + LineEnding + '    ' + FeatureName(Docs[slot], j);
  if bad <> '' then
    MsgBox('These features no longer fit and have been left out of the part:' + LineEnding + bad + LineEnding + LineEnding +
      'Edit them, or edit ' + FeatureName(Docs[slot], i) + ' back.', MB_EXCLAMATION);
end;

procedure CmdEdit;
var
  p: TPartWindow;
begin
  if not NeedPart(p) then Exit;
  if p.Selected = 0 then
  begin
    MsgBox('Select a feature in the tree or the timeline first.', MB_INFO);
    Exit;
  end;
  EditFeature(p, p.Selected);
end;

{ Delete the selected feature, and whatever is built on it. }
procedure CmdDelete;
var
  p: TPartWindow;
  slot, i, j, n: Integer;
  gone: TBoolArray;
  list: string;
begin
  if not NeedPart(p) then Exit;
  slot := p.Slot;
  i := p.Selected;
  if i = 0 then
  begin
    MsgBox('Select a feature in the tree or the timeline first.', MB_INFO);
    Exit;
  end;
  n := MarkDependents(Docs[slot], i, gone);
  list := '';
  for j := 1 to Docs[slot].Count do
    if gone[j] and (j <> i) then list := list + LineEnding + '    ' + FeatureName(Docs[slot], j);
  if n > 1 then
    if MsgBox('These are built on ' + FeatureName(Docs[slot], i) + ' and will be deleted too:' + LineEnding + list +
      LineEnding + LineEnding + 'Delete all ' + IntToStr(n) + ' features?',
      MB_EXCLAMATION or MB_YESNO or MB_DEFBUTTON2) = IDNO then Exit;
  list := FeatureName(Docs[slot], i);
  HistoryRemember(slot, Docs[slot], 'Delete ' + list);
  DeleteMarked(Docs[slot], gone);
  DocDirty[slot] := True;
  p.Selected := 0;
  p.RefreshAll(False);
  MainForm.PartsChanged;
  if n > 1 then Status('Deleted ' + list + ' and ' + IntToStr(n - 1) + ' more.')
  else Status('Deleted ' + list + '.');
end;

{ Service Pack 1: a real history, twenty levels deep. }
procedure CmdUndo;
var
  p: TPartWindow;
  what: string;
begin
  if not NeedPart(p) then Exit;
  what := HistoryUndo(p.Slot);
  if what = '' then
  begin
    Status('Can''t Undo.');
    Exit;
  end;
  DocDirty[p.Slot] := True;
  p.Selected := 0;
  p.RefreshAll(False);
  MainForm.PartsChanged;
  if CanUndo(p.Slot) then Status('Undone: ' + what + '.')
  else Status('Undone: ' + what + '. That was the last thing to undo.');
end;

procedure CmdRedo;
var
  p: TPartWindow;
  what: string;
begin
  if not NeedPart(p) then Exit;
  what := HistoryRedo(p.Slot);
  if what = '' then
  begin
    Status('Can''t Redo.');
    Exit;
  end;
  DocDirty[p.Slot] := True;
  p.Selected := 0;
  p.RefreshAll(False);
  MainForm.PartsChanged;
  Status('Redone: ' + what + '.');
end;

{ Help, Install Stability Pack (or Uninstall, once it's in). }
procedure CmdStabilityPack;
begin
  if StabilityPackInstalled then
  begin
    if MsgBox('Uninstall the Stability Pack?' + LineEnding + LineEnding +
      'SolidCraft 2000 will go back to crashing every 15 minutes or so, as designed.',
      MB_QUESTION or MB_YESNO, 'Stability Pack') = IDNO then Exit;
    SetStabilityPack(False);
    MsgBox('The Stability Pack has been uninstalled.', MB_INFO, 'Stability Pack');
  end
  else
  begin
    if MsgBox('The Stability Pack stops SolidCraft 2000 crashing every 15 minutes or so.' + LineEnding + LineEnding +
      '(The crashes never hurt your parts. They''re only a blue picture.)' + LineEnding + LineEnding +
      'Install the Stability Pack?', MB_QUESTION or MB_YESNO, 'Stability Pack') = IDNO then Exit;
    SetStabilityPack(True);
    MsgBox('The Stability Pack has been installed.' + LineEnding + LineEnding +
      'SolidCraft 2000 will no longer crash on schedule.', MB_INFO, 'Stability Pack');
  end;
  MainForm.StabilityChanged;
end;

procedure CmdHelp;
begin
  MsgBox('Cannot find the file ''SOLIDCRAFT.HLP'' (or one of its components).' + LineEnding + LineEnding +
    'Make sure the path and filename are correct and that all required libraries are available.',
    MB_EXCLAMATION, 'WinHelp');
end;

procedure RunCommand(const ACmd: string);
var
  p: TPartWindow;
begin
  case ACmd of
    'New': CmdNew;
    'Open': CmdOpen;
    'Save': CmdSave(False);
    'SaveAs': CmdSave(True);
    'Close': CmdClose;
    'SaveFloppy': CmdFloppy;
    'Publish': CmdPublish;
    'ExportStl': CmdExportStl;
    'Exit': MainForm.Close;

    'SketchRect': CmdSketchRect;
    'SketchCircle': CmdSketchCircle;
    'Extrude': CmdExtrude;
    'Revolve': CmdRevolve;
    'Hole': CmdHole;
    'Fillet': CmdEdgeFinish(FK_FILLET);
    'Chamfer': CmdEdgeFinish(FK_CHAMFER);
    'SMBase': CmdSMBase;
    'SMEdge': CmdSMEdge;
    'SMFlat': CmdSMFlat;
    'BendTable': CmdBendTable;
    'Undo': CmdUndo;
    'Redo': CmdRedo;
    'Edit': CmdEdit;
    'Delete': CmdDelete;

    'Orbit', 'ViewIso': if NeedPart(p) then p.ViewIso;
    'ZoomFit': if NeedPart(p) then p.ZoomFit;
    'Regen': if NeedPart(p) then p.Regen;

    'Shaded': CmdShaded;
    'Turbo': SetTurbo(not Turbo);

    'Cascade': MainForm.Arrange(0);
    'TileH': MainForm.Arrange(1);
    'TileV': MainForm.Arrange(2);

    'Help': CmdHelp;
    'About': ShowAbout;
    'Upgrade': ShowUpgradeWizard;
    'StabilityPack': CmdStabilityPack;
  else
    if Copy(ACmd, 1, 5) = 'Open:' then OpenPath(Copy(ACmd, 6, MaxInt))
    else
      MsgBox('Command ''' + ACmd + ''' is not implemented yet.' + LineEnding +
        'It is scheduled for SolidCraft XP.', MB_INFO);
  end;
end;

procedure HelpFromDialog;
begin
  CmdHelp;
end;

initialization
  HelpProc := @HelpFromDialog;
end.
