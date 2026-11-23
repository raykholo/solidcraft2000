{ Checks the core against the Windows version's results, no UI: the .sc2 and
  .sc98 files (read, upgraded, written back byte for byte), fillets and
  chamfers on chosen sides, hole patterns, side faces and sheet metal, as
  meshes that are closed and face outward. Run from delphi/ with ../samples
  next to it. }
program coretest;
{$mode objfpc}{$H+}
uses SysUtils, Classes, StrUtils, uModel, uKernel, uMesh, uStl, uExpr, uImport, uSheet;
var
  fails: Integer;

procedure Check(ok: Boolean; const what: string);
begin
  if ok then WriteLn('  ok   ', what)
  else begin WriteLn('  FAIL ', what); Inc(fails); end;
end;

function Slurp(const p: string): string;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(p, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, fs.Size);
    if fs.Size > 0 then fs.ReadBuffer(Result[1], fs.Size);
  finally
    fs.Free;
  end;
end;

{ Closed: every directed edge is matched by its reverse exactly once.
  Volume (signed, from the triangles) comes back in vol. }
function Closed(const t: TTriArray; n: Integer; out vol: Double): Boolean;
type
  TKey = record a, b: string; end;
var
  l: TStringList;
  i, k: Integer;
  p: array[0..2] of string;
  function Pt(x, y, z: Double): string;
  begin
    Result := Format('%.4f,%.4f,%.4f', [x + 0.00001, y + 0.00001, z + 0.00001]);
  end;
begin
  l := TStringList.Create;
  vol := 0;
  try
    l.Sorted := False;
    for i := 0 to n - 1 do
    begin
      p[0] := Pt(t[i].X1, t[i].Y1, t[i].Z1);
      p[1] := Pt(t[i].X2, t[i].Y2, t[i].Z2);
      p[2] := Pt(t[i].X3, t[i].Y3, t[i].Z3);
      for k := 0 to 2 do l.Add(p[k] + '>' + p[(k + 1) mod 3]);
      vol := vol + (t[i].X1 * (t[i].Y2 * t[i].Z3 - t[i].Y3 * t[i].Z2) - t[i].X2 * (t[i].Y1 * t[i].Z3 - t[i].Y3 * t[i].Z1) +
        t[i].X3 * (t[i].Y1 * t[i].Z2 - t[i].Y2 * t[i].Z1)) / 6;
    end;
    l.Sort;
    l.Sorted := True;
    Result := True;
    for i := 0 to l.Count - 1 do
    begin
      k := Pos('>', l[i]);
      if l.IndexOf(Copy(l[i], k + 1, MaxInt) + '>' + Copy(l[i], 1, k - 1)) < 0 then
      begin
        Result := False;
        Break;
      end;
    end;
  finally
    l.Free;
  end;
end;

procedure Show(const d: TDesign; const name: string);
var
  e: TEdgeArray;
  t: TTriArray;
  i, n: Integer;
  serr: string;
  vol: Double;
  cl: Boolean;
begin
  WriteLn(name, ': "', d.Title, '", ', d.Count, ' features');
  for i := 1 to d.Count do
    WriteLn('  ', i, ' ', d.F[i].Name, ' | ', KindName(d.F[i].Kind), ' | ', Describe(d, i), IfThen(RefOk(d, i), '', '   <- DOES NOT BUILD'));
  Check(Regenerate(d, e) > 0, 'wireframe has edges');
  n := MeshDesign(d, t, MESH_SEGS, serr);
  cl := Closed(t, n, vol);
  WriteLn('  triangles ', n, ', volume ', FmtN(vol, 2), ', err "', serr, '"');
  Check(n > 0, 'mesh has triangles');
  Check(serr = '', 'every body meshed');
  Check(cl, 'mesh is closed');
  Check(vol > 0, 'mesh faces outward (volume > 0)');
  WriteStl(t, n, 'tests/out/' + ExtractFileName(name) + '.stl', d.Title);
end;

procedure RoundTrip(const path: string);
var
  d: TDesign;
  a, b: string;
begin
  Check(LoadDesign(d, path) = 0, 'load ' + ExtractFileName(path));
  SaveDesign(d, 'tests/out/resaved.sc2');
  a := Slurp(path); b := Slurp('tests/out/resaved.sc2');
  Check(Length(a) = Length(b), 'saved size matches (' + IntToStr(Length(a)) + ' bytes)');
  // the samples written by tools/mksample.py pad unused names with spaces; VB leaves NULs
  a := StringReplace(a, ' ', #0, [rfReplaceAll]); b := StringReplace(b, ' ', #0, [rfReplaceAll]);
  Check(a = b, 'saved bytes match (spaces and NULs in unused text aside)');
end;

var
  d: TDesign;
  f: TFeature;
  g: TDesign;
  r, i, j: Integer;
  names: array[0..3] of string = ('Plate with holes', 'Revolved parts', 'Flange', 'Rounded Block');
  ex: array[0..5] of string = ('40/2+5', '(10+2)*3', '-8', '20mm', '40/0', '1.2.3');
  v: Double;
  e: TEdgeArray;
  t: TTriArray;
  serr, notice, err: string;
  n: Integer;
  vol, v0: Double;
  sr: TSearchRec;
begin
  ForceDirectories('tests/out');
  WriteLn('== files');
  if FindFirst('../samples/*.sc2', faAnyFile, sr) = 0 then
  repeat
    RoundTrip('../samples/' + sr.Name);
    r := LoadDesign(d, '../samples/' + sr.Name);
    Show(d, ChangeFileExt(sr.Name, ''));
  until FindNext(sr) <> 0;
  FindClose(sr);

  r := LoadDesign(d, '../samples/Mounting Plate.sc98');
  Check(r = 0, 'Mounting Plate.sc98 opens');
  Check(Upgraded98, 'and says it was upgraded');
  Show(d, 'Mounting Plate');
  Check(SaveDesign(d, 'tests/out/upgraded.sc2'), 'saves as .sc2');
  r := LoadDesign(d, 'tests/out/upgraded.sc2');
  Check((r = 0) and not Upgraded98, 'the .sc2 opens as a SolidCraft 2000 part');
  Check(Copy(Slurp('tests/out/upgraded.sc2'), 1, 4) = 'SC2K', 'with the SC2K magic');
  Check(Copy(Slurp('tests/out/upgraded.sc2'), 6, MaxInt) = Copy(Slurp('../samples/Mounting Plate.sc98'), 6, MaxInt),
    'and everything after the version byte for byte what VB wrote for SolidCraft 98');

  WriteLn('== a part built by hand');
  NewDesign(d, 'Block');
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_SKETCH_RECT; f.P1 := 40; f.P2 := 30; f.X := -20; f.Y := -15;
  AddFeature(d, f);
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_EXTRUDE; f.Ref := 1; f.P1 := 10;
  AddFeature(d, f);
  Show(d, 'block');
  Check(SaveDesign(d, 'tests/out/block.sc2'), 'save');
  Check(Slurp('tests/out/block.sc2')[5] = #6, 'a plain part is version 6');
  v0 := 40 * 30 * 10;

  // fillet, all top edges
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_FILLET; f.Ref := 2; f.P1 := 3;
  AddFeature(d, f);
  Show(d, 'block + fillet');
  n := MeshDesign(d, t, MESH_SEGS, serr); Closed(t, n, vol);
  // a round of radius r along a 2(a+b) perimeter loses (1 - pi/4) r^2 per length, plus the corners
  Check((vol < v0) and (vol > v0 - 0.2146 * 9 * 140 - 40), 'fillet takes about (1 - pi/4) r^2 per mm of edge');
  Check(Slurp('tests/out/block.sc2')[5] = #6, 'still version 6 on disk before saving again');
  SaveDesign(d, 'tests/out/filleted.sc2');
  Check(Slurp('tests/out/filleted.sc2')[5] = #6, 'an all-edges fillet is still version 6');

  // chosen sides: front and back of the top (mask 5) and all the bottom (15)
  d.F[3].Reserved[1] := SIDES_ALL - 5;
  d.F[3].Reserved[2] := SIDES_ALL;
  d.F[3].P1 := 2;
  Show(d, 'block + fillet on chosen edges');
  Check(FinishTop(d.F[3]) = 5, 'top sides 5');
  SaveDesign(d, 'tests/out/filleted2.sc2');
  Check(Slurp('tests/out/filleted2.sc2')[5] = #7, 'chosen edges make version 7');
  Check(LoadDesign(g, 'tests/out/filleted2.sc2') = 0, 'and read back');

  // chamfer instead
  d.F[3].Kind := FK_CHAMFER; d.F[3].Name := 'Chamfer1';
  Show(d, 'block + chamfer on chosen edges');

  // a hole pattern: six on a bolt circle, and a row of three
  d.F[3].Kind := FK_FILLET; d.F[3].Reserved[1] := 0; d.F[3].Reserved[2] := 0; d.F[3].P1 := 1;
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_HOLE; f.Ref := 2; f.P1 := 4; f.P2 := 0; f.X := 0; f.Y := 0; f.P3 := 6; f.Reserved[1] := 20; f.Reserved[3] := 30;
  AddFeature(d, f);
  Show(d, 'block + fillet + bolt circle');
  n := MeshDesign(d, t, MESH_SEGS, serr); Closed(t, n, vol);
  Check(Abs(HoleCount(d.F[4]) - 6) = 0, 'six holes');
  d.F[4].Reserved[1] := 0; d.F[4].Reserved[2] := 8; d.F[4].Reserved[3] := 0; d.F[4].P3 := 3; d.F[4].X := -8;
  Show(d, 'block + fillet + row of three');
  Check(RefOk(d, 4), 'row of three fits');
  SaveDesign(d, 'tests/out/pattern.sc2');
  Check(Slurp('tests/out/pattern.sc2')[5] = #7, 'a hole pattern makes version 7');

  // a sketch on the front face, extruded: a boss
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_SKETCH_CIRCLE; f.Ref := 2; f.P1 := 5; f.X := 20; f.Y := 5; f.Reserved[1] := FACE_FRONT;
  AddFeature(d, f);
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_EXTRUDE; f.Ref := 5; f.P1 := 6;
  AddFeature(d, f);
  Show(d, 'block + boss on the front face');
  Check(Regenerate(d, e) > 0, 'edges');
  Check(RefOk(d, 5) and RefOk(d, 6), 'the side face sketch and its boss build');
  SaveDesign(d, 'tests/out/sideface.sc2');
  Check(Slurp('tests/out/sideface.sc2')[5] = #7, 'a side face makes version 7');

  WriteLn('== sheet metal');
  NewDesign(d, 'Tray');
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_SKETCH_RECT; f.P1 := 60; f.P2 := 40; f.X := 0; f.Y := 0;
  AddFeature(d, f);
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_SM_BASE; f.Ref := 1; f.P1 := 1.5; f.P2 := 1.5; f.P3 := 0.44;
  AddFeature(d, f);
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_SM_EDGE; f.Ref := 2; f.X := 0; f.P1 := 15; f.P2 := 90; f.P3 := SM_RELIEF_RECT;
  AddFeature(d, f);
  f.X := 2; f.P3 := SM_RELIEF_OBROUND;
  AddFeature(d, f);
  Show(d, 'tray');
  FillChar(f, SizeOf(f), 0);
  f.Kind := FK_SM_FLAT; f.Ref := 2; f.Info := 'TRAY~1.DXF';
  AddFeature(d, f);
  Show(d, 'tray flat');
  Check(WriteFlatDxf(d, 2, 'tests/out/TRAY~1.DXF'), 'flat pattern DXF written');
  Check(Pos('BEND', Slurp('tests/out/TRAY~1.DXF')) > 0, 'with bend lines');

  WriteLn('== SolidCraft designs');
  for i := 0 to 3 do
  begin
    if ImportSolidCraft('../samples/' + names[i] + '.solidcraft', d, notice, err) then
    begin
      WriteLn('import ', names[i], ': ', d.Count, ' features; notice: ', StringReplace(notice, LineEnding, ' / ', [rfReplaceAll]));
      for j := 1 to d.Count do WriteLn('  ', j, ' ', d.F[j].Name, ' | ', Describe(d, j));
      n := 0;
      for j := 1 to d.Count do if d.F[j].Kind = FK_FOREIGN then Inc(n);
      Check(n = 0, names[i] + ': nothing left waiting for a later SolidCraft (fillets and chamfers come over)');
      n := MeshDesign(d, t, MESH_SEGS, serr);
      Check(Closed(t, n, vol) and (vol > 0), names[i] + ': the import meshes closed');
      WriteStl(t, n, 'tests/out/import' + IntToStr(i) + '.stl', d.Title);
    end
    else begin WriteLn('import ', names[i], ' FAILED: ', err); Inc(fails); end;
  end;
  WriteLn('== arithmetic');
  for i := 0 to 5 do
  begin
    v := Evaluate(ex[i]);
    WriteLn('eval "', ex[i], '" = ', FmtN(v, 3), ' err ', ExprError);
  end;
  WriteLn;
  if fails = 0 then WriteLn('core: all ok') else WriteLn('core: ', fails, ' FAILED');
  if fails > 0 then Halt(1);
end.
