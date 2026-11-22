{ uKernel - turns the features into edges (the "geometry kernel").
  A line-for-line port of the Windows version's modKernel: frames for
  sketches on side faces, hole patterns, fillets and chamfers on chosen
  sides, and the wireframe of sheet metal. Z is up, units are mm. }
unit uKernel;

{$mode objfpc}{$H+}

interface

uses uModel;

const
  CIRCLE_SEGS = 32;
  FILLET_STEPS = 4;            // quarter-circle steps in a fillet's wireframe
  MAX_PATTERN_HOLES = MAX_PATTERN;

  // colours as $RRGGBB
  COL_SKETCH = $0000C0;        // blue
  COL_SKETCH_USED = $80A0C0;   // faded, once a feature consumes it
  COL_SOLID = $000000;
  COL_HOLE = $800000;          // dark red
  COL_AXIS = $808080;
  COL_BEND = $008000;          // sheet metal bend lines: dark green

type
  TEdge = record
    X1, Y1, Z1, X2, Y2, Z2: Double;
    Col: LongWord;
  end;
  TEdgeArray = array of TEdge;
  TDoubleArray = array of Double;
  TFeatureArray = array of TFeature;

  { Where a sketch's X, Y and Z go in the world (Service Pack 1: a sketch on
    a side face has the face's). }
  TFrame = record
    OX, OY, OZ: Double;
    UX, UY, UZ: Double;
    VX, VY, VZ: Double;
    WX, WY, WZ: Double;
  end;

function WorldFrame: TFrame;
procedure ToWorld(const fr: TFrame; x, y, z: Double; out wx, wy, wz: Double);
function IsLevel(const fr: TFrame): Boolean;
function SameFrame(const a, b: TFrame): Boolean;
function FrameOf(const d: TDesign; i: Integer): TFrame;
function BodyFrame(const d: TDesign; i: Integer): TFrame;

function ProfilePoints(const f: TFeature; out px, py: TDoubleArray; out seam: TBoolArray;
  nCircle: Integer = CIRCLE_SEGS; bKeepCount: Boolean = False): Integer;
function ProfileContains(const s: TFeature; x, y, rr: Double): Boolean;
function SketchZ(const d: TDesign; i: Integer): Double;
procedure ExtrudeRange(const d: TDesign; i: Integer; out z0, z1: Double);

function HoleCount(const f: TFeature): Integer;
procedure HoleAt(const f: TFeature; k: Integer; out x, y: Double);
function HolesInside(const s, f: TFeature): Boolean;
procedure HoleSpan(const d: TDesign; i: Integer; out zTop, zBot: Double; k: Integer = 0);

procedure EdgeAt(bChamfer: Boolean; r, t: Double; out inset, rise: Double);
function EdgeSteps(bChamfer: Boolean; nFillet: Integer): Integer;
function InsetSketch(const s: TFeature; off: Double): TFeature;
function SideInset(const s: TFeature; mask: Integer; off: Double): TFeature;
function SidesOk(const s: TFeature; mask: Integer): Boolean;
function SidesFit(const s: TFeature; mask: Integer; r: Double): Boolean;
function FilletFits(const d: TDesign; j: Integer): Boolean;
function ExtrudeRings(const d: TDesign; b, steps: Integer; out rz: TDoubleArray;
  out rs: TFeatureArray; out key: TBoolArray): Integer;
function FilletOf(const d: TDesign; b: Integer): Integer;
function FilletRadius(const d: TDesign; b: Integer): Double;
function TopFace(const d: TDesign; b: Integer): TFeature;
function BottomFace(const d: TDesign; b: Integer): TFeature;

function Regenerate(const d: TDesign; out e: TEdgeArray): Integer;
function RefOk(const d: TDesign; i: Integer): Boolean;

{ ---- sheet metal (the reference engine; the DXF is in usheet) ---- }
function SM_RefOk(const d: TDesign; i: Integer): Boolean;
procedure SMBaseBox(const d: TDesign; b: Integer; out x, y, w, h, z0, z1: Double);
function SMSideLength(const d: TDesign; b, e: Integer): Double;
procedure SMEdgeFrame(const d: TDesign; b, e: Integer; out ox, oy, ux, uy, vx, vy: Double);
function SMReliefWidth(const d: TDesign; i: Integer): Double;
function SMMargin(const d: TDesign; i: Integer): Double;
function SMBendAllowance(angleDeg, r, k, t: Double): Double;
function SMIsFlat(const d: TDesign; b: Integer): Boolean;
function SMSection(const d: TDesign; i: Integer; bFlat: Boolean; steps: Integer;
  out ov, ow, iv, iw: TDoubleArray; out nBend: Integer): Integer;
function SMLastBase(const d: TDesign): Integer;

implementation

uses Math;

var
  mXf: TFrame;
  mXfOn: Boolean;

{ ---- frames ---- }

function WorldFrame: TFrame;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.UX := 1; Result.VY := 1; Result.WZ := 1;
end;

procedure ToWorld(const fr: TFrame; x, y, z: Double; out wx, wy, wz: Double);
begin
  wx := fr.OX + fr.UX * x + fr.VX * y + fr.WX * z;
  wy := fr.OY + fr.UY * x + fr.VY * y + fr.WY * z;
  wz := fr.OZ + fr.UZ * x + fr.VZ * y + fr.WZ * z;
end;

{ The world's frame, or one only moved up or down from it? }
function IsLevel(const fr: TFrame): Boolean;
const
  E = 0.000000001;
begin
  Result := (Abs(fr.UX - 1) < E) and (Abs(fr.VY - 1) < E) and (Abs(fr.WZ - 1) < E) and
    (Abs(fr.OX) < E) and (Abs(fr.OY) < E) and (Abs(fr.OZ) < E);
end;

function SameFrame(const a, b: TFrame): Boolean;
const
  E = 0.000001;
begin
  Result := (Abs(a.OX - b.OX) < E) and (Abs(a.OY - b.OY) < E) and (Abs(a.OZ - b.OZ) < E) and
    (Abs(a.UX - b.UX) < E) and (Abs(a.UY - b.UY) < E) and (Abs(a.UZ - b.UZ) < E) and
    (Abs(a.VX - b.VX) < E) and (Abs(a.VY - b.VY) < E) and (Abs(a.VZ - b.VZ) < E) and
    (Abs(a.WX - b.WX) < E) and (Abs(a.WY - b.WY) < E) and (Abs(a.WZ - b.WZ) < E);
end;

procedure SetAxes(var q: TFrame; ux, uy, uz, vx, vy, vz, wx, wy, wz: Double);
begin
  q.UX := ux; q.UY := uy; q.UZ := uz;
  q.VX := vx; q.VY := vy; q.VZ := vz;
  q.WX := wx; q.WY := wy; q.WZ := wz;
end;

{ The frame of sketch i. }
function FrameOf(const d: TDesign; i: Integer): TFrame;
var
  f, s: TFeature;
  r: Integer;
  p, q: TFrame;
  z0: Double;
begin
  f := d.F[i];
  r := f.Ref;
  if (r < 1) or (r >= i) then Exit(WorldFrame);
  if d.F[r].Kind <> FK_EXTRUDE then Exit(WorldFrame);
  p := FrameOf(d, d.F[r].Ref);              // the extrude's own frame
  if SketchFace(f) = FACE_TOP then Exit(p);
  s := d.F[d.F[r].Ref];
  z0 := SketchZ(d, d.F[r].Ref);             // the extrude's bottom
  q := p;
  case SketchFace(f) of
    FACE_FRONT:
      begin
        ToWorld(p, 0, s.Y, z0, q.OX, q.OY, q.OZ);
        SetAxes(q, p.UX, p.UY, p.UZ, p.WX, p.WY, p.WZ, -p.VX, -p.VY, -p.VZ);
      end;
    FACE_RIGHT:
      begin
        ToWorld(p, s.X + s.P1, 0, z0, q.OX, q.OY, q.OZ);
        SetAxes(q, p.VX, p.VY, p.VZ, p.WX, p.WY, p.WZ, p.UX, p.UY, p.UZ);
      end;
    FACE_BACK:
      begin
        ToWorld(p, 0, s.Y + s.P2, z0, q.OX, q.OY, q.OZ);
        SetAxes(q, -p.UX, -p.UY, -p.UZ, p.WX, p.WY, p.WZ, p.VX, p.VY, p.VZ);
      end;
    FACE_LEFT:
      begin
        ToWorld(p, s.X, 0, z0, q.OX, q.OY, q.OZ);
        SetAxes(q, -p.VX, -p.VY, -p.VZ, p.WX, p.WY, p.WZ, -p.UX, -p.UY, -p.UZ);
      end;
  end;
  Result := q;
end;

{ The frame extrude, revolve or hole i is built in. }
function BodyFrame(const d: TDesign; i: Integer): TFrame;
begin
  case d.F[i].Kind of
    FK_EXTRUDE, FK_REVOLVE: Result := FrameOf(d, d.F[i].Ref);
    FK_HOLE, FK_FILLET, FK_CHAMFER: Result := FrameOf(d, d.F[d.F[i].Ref].Ref);
  else
    Result := WorldFrame;
  end;
end;

{ ---- edges ---- }

procedure AddEdge(var e: TEdgeArray; var n: Integer; x1, y1, z1, x2, y2, z2: Double; c: LongWord);
begin
  if mXfOn then
  begin
    ToWorld(mXf, x1, y1, z1, x1, y1, z1);
    ToWorld(mXf, x2, y2, z2, x2, y2, z2);
  end;
  if n >= Length(e) then SetLength(e, Length(e) * 2 + 16);
  e[n].X1 := x1; e[n].Y1 := y1; e[n].Z1 := z1;
  e[n].X2 := x2; e[n].Y2 := y2; e[n].Z2 := z2;
  e[n].Col := c;
  Inc(n);
end;

procedure AddCircle(var e: TEdgeArray; var n: Integer; cx, cy, z, r: Double; c: LongWord);
var
  i: Integer;
  a0, a1: Double;
begin
  for i := 0 to CIRCLE_SEGS - 1 do
  begin
    a0 := 2 * Pi * i / CIRCLE_SEGS;
    a1 := 2 * Pi * (i + 1) / CIRCLE_SEGS;
    AddEdge(e, n, cx + r * Cos(a0), cy + r * Sin(a0), z, cx + r * Cos(a1), cy + r * Sin(a1), z, c);
  end;
end;

{ Profile points of a sketch, counter-clockwise, in its own plane. seam[j] is
  True where a solid built on it should show a vertical edge. bKeepCount: a
  sharp rectangle gets as many points as a rounded one (its "corners" have
  radius 0), so the outlines a fillet steps through all line up. }
function ProfilePoints(const f: TFeature; out px, py: TDoubleArray; out seam: TBoolArray;
  nCircle: Integer; bKeepCount: Boolean): Integer;
var
  i, c, j, k, n: Integer;
  r, cx, cy, a: Double;
begin
  n := 0;
  cx := 0; cy := 0;
  if f.Kind = FK_SKETCH_RECT then
  begin
    r := f.P3;
    if r < 0 then r := 0;
    if (r <= 0) and not bKeepCount then
    begin
      SetLength(px, 4); SetLength(py, 4); SetLength(seam, 4);
      px[0] := f.X; py[0] := f.Y;
      px[1] := f.X + f.P1; py[1] := f.Y;
      px[2] := f.X + f.P1; py[2] := f.Y + f.P2;
      px[3] := f.X; py[3] := f.Y + f.P2;
      for i := 0 to 3 do seam[i] := True;
      Exit(4);
    end;
    k := nCircle div 4;
    if k < 2 then k := 2;
    SetLength(px, 4 * (k + 1)); SetLength(py, 4 * (k + 1)); SetLength(seam, 4 * (k + 1));
    for c := 0 to 3 do
    begin
      case c of
        0: begin cx := f.X + f.P1 - r; cy := f.Y + r; end;
        1: begin cx := f.X + f.P1 - r; cy := f.Y + f.P2 - r; end;
        2: begin cx := f.X + r; cy := f.Y + f.P2 - r; end;
        3: begin cx := f.X + r; cy := f.Y + r; end;
      end;
      for j := 0 to k do
      begin
        a := (c * 90 - 90 + 90 * j / k) * Pi / 180;
        px[n] := cx + r * Cos(a); py[n] := cy + r * Sin(a);
        seam[n] := (j = 0) or (j = k);
        Inc(n);
      end;
    end;
    Result := n;
  end
  else
  begin
    SetLength(px, nCircle); SetLength(py, nCircle); SetLength(seam, nCircle);
    for i := 0 to nCircle - 1 do
    begin
      px[i] := f.X + f.P1 * Cos(2 * Pi * i / nCircle);
      py[i] := f.Y + f.P1 * Sin(2 * Pi * i / nCircle);
      seam[i] := (i mod 4) = 0;
    end;
    Result := nCircle;
  end;
end;

{ Is the circle (x, y, radius rr) wholly inside the sketch's outline? }
function ProfileContains(const s: TFeature; x, y, rr: Double): Boolean;
const
  EPS = 0.000001;
var
  r, cx, cy: Double;
begin
  if s.Kind = FK_SKETCH_CIRCLE then
    Exit(Sqrt(Sqr(x - s.X) + Sqr(y - s.Y)) + rr <= s.P1 + EPS);
  if (x - rr < s.X - EPS) or (x + rr > s.X + s.P1 + EPS) or (y - rr < s.Y - EPS) or (y + rr > s.Y + s.P2 + EPS) then
    Exit(False);
  r := s.P3;
  if r > 0 then
  begin
    cx := x; cy := y;
    if x < s.X + r then cx := s.X + r;
    if x > s.X + s.P1 - r then cx := s.X + s.P1 - r;
    if y < s.Y + r then cy := s.Y + r;
    if y > s.Y + s.P2 - r then cy := s.Y + s.P2 - r;
    if Sqrt(Sqr(x - cx) + Sqr(y - cy)) + rr > r + EPS then
      if ((x < s.X + r) or (x > s.X + s.P1 - r)) and ((y < s.Y + r) or (y > s.Y + s.P2 - r)) then
        Exit(False);
  end;
  Result := True;
end;

{ The height of sketch i. A sketch can sit on the top face of an extrude
  (its Ref); then Z is how far above that face it is, and it moves with it. }
function SketchZ(const d: TDesign; i: Integer): Double;
var
  r: Integer;
  z0, z1: Double;
begin
  Result := d.F[i].Z;
  r := d.F[i].Ref;
  if SketchFace(d.F[i]) <> FACE_TOP then Exit;      // on a side: Z is how far out
  if (r >= 1) and (r < i) then
    if d.F[r].Kind = FK_EXTRUDE then
    begin
      ExtrudeRange(d, r, z0, z1);
      Result := Result + z1;
    end;
end;

procedure ExtrudeRange(const d: TDesign; i: Integer; out z0, z1: Double);
begin
  z0 := SketchZ(d, d.F[i].Ref);
  z1 := z0 + d.F[i].P1;
end;

{ ---- hole patterns (Service Pack 1) ----
  One hole feature can be a row of holes or a bolt circle. P3 is how many
  (0 or 1: just the one). Reserved[1] is the bolt circle's diameter, 0 for a
  row; Reserved[2] is the spacing in a row; Reserved[3] is an angle in
  degrees: the row's direction, or where the first hole on the circle sits. }

function HoleCount(const f: TFeature): Integer;
begin
  if f.P3 >= 2 then Result := Trunc(f.P3) else Result := 1;
end;

{ The centre of hole k (0 to HoleCount - 1) of hole feature f. }
procedure HoleAt(const f: TFeature; k: Integer; out x, y: Double);
var
  a: Double;
  n: Integer;
begin
  n := HoleCount(f);
  a := f.Reserved[3] * Pi / 180;
  if (n > 1) and (f.Reserved[1] > 0) then
  begin
    a := a + 2 * Pi * k / n;
    x := f.X + f.Reserved[1] / 2 * Cos(a);
    y := f.Y + f.Reserved[1] / 2 * Sin(a);
  end
  else
  begin
    x := f.X + k * f.Reserved[2] * Cos(a);
    y := f.Y + k * f.Reserved[2] * Sin(a);
  end;
end;

{ Are all the holes of f inside the face s? }
function HolesInside(const s, f: TFeature): Boolean;
var
  k: Integer;
  x, y: Double;
begin
  Result := False;
  for k := 0 to HoleCount(f) - 1 do
  begin
    HoleAt(f, k, x, y);
    if not ProfileContains(s, x, y, f.P1 / 2) then Exit;
  end;
  Result := True;
end;

{ Where hole i starts and stops. It starts on the top face of the body it was
  put on. A blind hole goes down its depth; "through all" keeps going through
  every extruded body stacked underneath that the hole fits inside. k is
  which hole of a pattern. }
procedure HoleSpan(const d: TDesign; i: Integer; out zTop, zBot: Double; k: Integer);
const
  EPS = 0.000001;
var
  h, tf: TFeature;
  j: Integer;
  b0, b1, hx, hy: Double;
  moved: Boolean;
  hf: TFrame;
begin
  h := d.F[i];
  HoleAt(h, k, hx, hy);
  hf := BodyFrame(d, h.Ref);
  ExtrudeRange(d, h.Ref, zBot, zTop);
  if h.P2 > 0 then
  begin
    zBot := zTop - h.P2;
    Exit;
  end;
  repeat
    moved := False;
    for j := 1 to i - 1 do
      if (d.F[j].Kind = FK_EXTRUDE) and (d.F[j].Suppressed = 0) and (j <> h.Ref) then
        if RefOk(d, j) and SameFrame(BodyFrame(d, j), hf) then      // only bodies facing the same way
        begin
          ExtrudeRange(d, j, b0, b1);
          if (b0 < zBot - EPS) and (b1 >= zBot - EPS) and (b1 <= zTop + EPS) then
          begin
            tf := TopFace(d, j);
            if ProfileContains(tf, hx, hy, h.P1 / 2) then
            begin
              zBot := b0;
              moved := True;
            end;
          end;
        end;
  until not moved;
end;

{ ---- fillets and chamfers ----
  A fillet rounds the top edges of one extrude with a quarter circle of
  radius P1: going up it, the body's outline shrinks, at angle a moved in by
  P1 * (1 - Cos(a)), at height top - P1 + P1 * Sin(a). Every outline
  SolidCraft 2000 can sketch is convex, so moving it in is exact. A chamfer
  is the same with a straight line for the quarter circle. }

procedure EdgeAt(bChamfer: Boolean; r, t: Double; out inset, rise: Double);
begin
  if bChamfer then
  begin
    inset := r * t;
    rise := r * t;
  end
  else
  begin
    inset := r * (1 - Cos(t * Pi / 2));
    rise := r * Sin(t * Pi / 2);
  end;
end;

function EdgeSteps(bChamfer: Boolean; nFillet: Integer): Integer;
begin
  if bChamfer then Result := 1 else Result := nFillet;
end;

{ The sketch s, moved in by off on every side. }
function InsetSketch(const s: TFeature; off: Double): TFeature;
begin
  Result := s;
  if s.Kind = FK_SKETCH_RECT then
  begin
    Result.X := s.X + off; Result.Y := s.Y + off;
    Result.P1 := s.P1 - 2 * off; Result.P2 := s.P2 - 2 * off;
    Result.P3 := s.P3 - off;
    if Result.P3 < 0 then Result.P3 := 0;
  end
  else
    Result.P1 := s.P1 - off;
end;

{ The sketch s, moved in by off on the sides in mask (1 front -Y, 2 right +X,
  4 back +Y, 8 left -X). }
function SideInset(const s: TFeature; mask: Integer; off: Double): TFeature;
begin
  if (mask = 0) or (off = 0) then Exit(s);
  if (mask = SIDES_ALL) or (s.Kind <> FK_SKETCH_RECT) or (s.P3 > 0) then Exit(InsetSketch(s, off));
  Result := s;
  if mask and 1 <> 0 then begin Result.Y := Result.Y + off; Result.P2 := Result.P2 - off; end;
  if mask and 2 <> 0 then Result.P1 := Result.P1 - off;
  if mask and 4 <> 0 then Result.P2 := Result.P2 - off;
  if mask and 8 <> 0 then begin Result.X := Result.X + off; Result.P1 := Result.P1 - off; end;
end;

{ Can sketch s take these sides? A circle or a rounded rectangle, all or none. }
function SidesOk(const s: TFeature; mask: Integer): Boolean;
begin
  if (mask < 0) or (mask > SIDES_ALL) then Exit(False);
  if (s.Kind = FK_SKETCH_RECT) and (s.P3 <= 0) then Result := True
  else Result := (mask = 0) or (mask = SIDES_ALL);
end;

{ Is r small enough for these sides of s? Something of the face has to stay. }
function SidesFit(const s: TFeature; mask: Integer; r: Double): Boolean;
const
  EPS = 0.000001;
var
  nx, ny: Integer;
begin
  if mask = 0 then Exit(True);
  if s.Kind = FK_SKETCH_CIRCLE then Exit(s.P1 > r + EPS);
  nx := 0; ny := 0;
  if mask and 2 <> 0 then Inc(nx);
  if mask and 8 <> 0 then Inc(nx);
  if mask and 1 <> 0 then Inc(ny);
  if mask and 4 <> 0 then Inc(ny);
  if s.P3 > 0 then begin nx := 2; ny := 2; end;
  Result := (s.P1 > nx * r + EPS) and (s.P2 > ny * r + EPS);
end;

{ Does fillet j fit its extrude? Its radius must leave some of each face it
  rounds, and fit in the extrude's height (twice, if it rounds both ends). }
function FilletFits(const d: TDesign; j: Integer): Boolean;
const
  EPS = 0.000001;
var
  f, s: TFeature;
  b, mt, mb, n: Integer;
begin
  Result := False;
  f := d.F[j];
  b := f.Ref;
  if (b < 1) or (b >= j) then Exit;
  if d.F[b].Kind <> FK_EXTRUDE then Exit;
  if (d.F[b].Ref < 1) or (d.F[b].Ref >= b) then Exit;
  s := d.F[d.F[b].Ref];
  if (s.Kind <> FK_SKETCH_RECT) and (s.Kind <> FK_SKETCH_CIRCLE) then Exit;
  mt := FinishTop(f); mb := FinishBottom(f);
  if (mt = 0) and (mb = 0) then Exit;
  if not SidesOk(s, mt) or not SidesOk(s, mb) then Exit;
  n := 0;
  if mt <> 0 then Inc(n);
  if mb <> 0 then Inc(n);
  if (f.P1 <= 0) or (n * f.P1 > Abs(d.F[b].P1) + EPS) then Exit;
  if not SidesFit(s, mt, f.P1) or not SidesFit(s, mb, f.P1) then Exit;
  Result := True;
end;

{ The cross-sections an extrude's walls go through, bottom to top: up the
  bottom fillet, the straight part, up the top fillet. rz the heights, rs the
  outlines (each a sketch), key where the wireframe draws a ring. Every
  outline gives ProfilePoints the same number of points. }
function ExtrudeRings(const d: TDesign; b, steps: Integer; out rz: TDoubleArray;
  out rs: TFeatureArray; out key: TBoolArray): Integer;
var
  s: TFeature;
  j, m, n, mt, mb, st: Integer;
  z0, z1, r, inset, rise: Double;
  bCh: Boolean;
begin
  s := d.F[d.F[b].Ref];
  ExtrudeRange(d, b, z0, z1);
  j := FilletOf(d, b);
  r := 0; mt := 0; mb := 0; bCh := False;
  if j > 0 then
  begin
    r := d.F[j].P1; mt := FinishTop(d.F[j]); mb := FinishBottom(d.F[j]);
    bCh := d.F[j].Kind = FK_CHAMFER;
  end;
  st := EdgeSteps(bCh, steps);
  SetLength(rz, 2 * st + 3); SetLength(rs, 2 * st + 3); SetLength(key, 2 * st + 3);
  n := 0;
  if mb <> 0 then
  begin
    for m := st downto 1 do               // from the bottom face up to the straight sides
    begin
      EdgeAt(bCh, r, m / st, inset, rise);
      if m = st then begin inset := r; rise := r; end;
      rz[n] := z0 + r - rise; rs[n] := SideInset(s, mb, inset); key[n] := (m = st);
      Inc(n);
    end;
    rz[n] := z0 + r;
  end
  else
    rz[n] := z0;
  rs[n] := s; key[n] := True; Inc(n);
  if mt <> 0 then
  begin
    rz[n] := z1 - r; rs[n] := s; key[n] := True; Inc(n);
    for m := 1 to st do
    begin
      EdgeAt(bCh, r, m / st, inset, rise);
      if m = st then begin inset := r; rise := r; end;     // exactly the top's edge
      rz[n] := z1 - r + rise; rs[n] := SideInset(s, mt, inset); key[n] := (m = st);
      Inc(n);
    end;
  end
  else
  begin
    rz[n] := z1; rs[n] := s; key[n] := True; Inc(n);
  end;
  Result := n;
end;

{ The fillet or chamfer on extrude b, or 0. Only the first one that fits counts. }
function FilletOf(const d: TDesign; b: Integer): Integer;
var
  j: Integer;
begin
  for j := b + 1 to d.Count do
    if IsEdgeFinish(d.F[j].Kind) and (d.F[j].Ref = b) and (d.F[j].Suppressed = 0) then
      if FilletFits(d, j) then Exit(j);
  Result := 0;
end;

function FilletRadius(const d: TDesign; b: Integer): Double;
var
  j: Integer;
begin
  Result := 0;
  j := FilletOf(d, b);
  if j > 0 then Result := d.F[j].P1;
end;

{ The flat part of extrude b's top face, as a sketch: its own sketch, moved
  in by its fillet. Holes and anything standing on it have to fit in here. }
function TopFace(const d: TDesign; b: Integer): TFeature;
var
  s: TFeature;
  j: Integer;
begin
  s := d.F[d.F[b].Ref];
  j := FilletOf(d, b);
  if j = 0 then Result := s else Result := SideInset(s, FinishTop(d.F[j]), d.F[j].P1);
end;

function BottomFace(const d: TDesign; b: Integer): TFeature;
var
  s: TFeature;
  j: Integer;
begin
  s := d.F[d.F[b].Ref];
  j := FilletOf(d, b);
  if j = 0 then Result := s else Result := SideInset(s, FinishBottom(d.F[j]), d.F[j].P1);
end;

function MaxAbs(const v: TDoubleArray; n: Integer): Double;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to n - 1 do
    if Abs(v[i]) > Result then Result := Abs(v[i]);
end;

{ ---- sheet metal: the numbers ---- }

function SM_Base_Ok(const d: TDesign; i, b: Integer): Boolean;
begin
  Result := False;
  if (b < 1) or (b >= i) then Exit;
  if (d.F[b].Kind <> FK_SM_BASE) or (d.F[b].Suppressed <> 0) then Exit;
  Result := SM_RefOk(d, b);
end;

{ The base's rectangle, and its bottom and top. }
procedure SMBaseBox(const d: TDesign; b: Integer; out x, y, w, h, z0, z1: Double);
var
  s: TFeature;
begin
  s := d.F[d.F[b].Ref];
  x := s.X; y := s.Y; w := s.P1; h := s.P2;
  z0 := SketchZ(d, d.F[b].Ref);
  z1 := z0 + d.F[b].P1;
end;

function SMSideLength(const d: TDesign; b, e: Integer): Double;
var
  s: TFeature;
begin
  s := d.F[d.F[b].Ref];
  if (e = 0) or (e = 2) then Result := s.P1 else Result := s.P2;
end;

{ Where edge e starts, which way it runs (u), and which way is out (v), going
  anticlockwise round the base seen from above. }
procedure SMEdgeFrame(const d: TDesign; b, e: Integer; out ox, oy, ux, uy, vx, vy: Double);
var
  x, y, w, h, z0, z1: Double;
begin
  SMBaseBox(d, b, x, y, w, h, z0, z1);
  case e of
    0: begin ox := x; oy := y; ux := 1; uy := 0; vx := 0; vy := -1; end;
    1: begin ox := x + w; oy := y; ux := 0; uy := 1; vx := 1; vy := 0; end;
    2: begin ox := x + w; oy := y + h; ux := -1; uy := 0; vx := 0; vy := 1; end;
  else
    ox := x; oy := y + h; ux := 0; uy := -1; vx := -1; vy := 0;
  end;
end;

function SMReliefWidth(const d: TDesign; i: Integer): Double;
begin
  Result := d.F[i].Z;
  if Result <= 0 then Result := d.F[d.F[i].Ref].P1;
end;

{ How far in from each end of its edge a flange stops: nothing without relief,
  otherwise room for the relief and as much again. }
function SMMargin(const d: TDesign; i: Integer): Double;
begin
  if Round(d.F[i].P3) = SM_RELIEF_NONE then Exit(0);
  Result := 2 * SMReliefWidth(d, i);
end;

{ The length of the bend, measured along the K-factor line. }
function SMBendAllowance(angleDeg, r, k, t: Double): Double;
begin
  Result := angleDeg * Pi / 180 * (r + k * t);
end;

{ Is the part being shown flat? }
function SMIsFlat(const d: TDesign; b: Integer): Boolean;
var
  j: Integer;
begin
  Result := False;
  for j := b + 1 to d.Count do
    if (d.F[j].Kind = FK_SM_FLAT) and (d.F[j].Ref = b) and (d.F[j].Suppressed = 0) then
      if SM_RefOk(d, j) then Exit(True);
end;

function SMLastBase(const d: TDesign): Integer;
var
  i: Integer;
begin
  for i := d.Count downto 1 do
    if d.F[i].Kind = FK_SM_BASE then Exit(i);
  Result := 0;
end;

{ A flange's cross-section, seen along its edge: the outside (bottom) of the
  sheet in ov/ow and the inside in iv/iw, point for point, v out from the
  edge and w up. Folded: round the bend, then the straight leg. Flat: one
  strip as long as the bend allowance and the leg. nBend is where the bend ends. }
function SMSection(const d: TDesign; i: Integer; bFlat: Boolean; steps: Integer;
  out ov, ow, iv, iw: TDoubleArray; out nBend: Integer): Integer;
var
  b, j: Integer;
  t, r, k, a, L, x, y, w, h, z0, z1, th, ba: Double;
begin
  b := d.F[i].Ref;
  t := d.F[b].P1; r := d.F[b].P2; k := d.F[b].P3;
  a := d.F[i].P2 * Pi / 180;
  L := d.F[i].P1;
  SMBaseBox(d, b, x, y, w, h, z0, z1);
  if bFlat then
  begin
    ba := SMBendAllowance(d.F[i].P2, r, k, t);
    SetLength(ov, 3); SetLength(ow, 3); SetLength(iv, 3); SetLength(iw, 3);
    ov[0] := 0; ov[1] := ba; ov[2] := ba + L;
    for j := 0 to 2 do
    begin
      iv[j] := ov[j]; ow[j] := z0; iw[j] := z1;
    end;
    nBend := 1;
    Exit(3);
  end;
  SetLength(ov, steps + 2); SetLength(ow, steps + 2); SetLength(iv, steps + 2); SetLength(iw, steps + 2);
  // the bend turns about a line R above the top face, at the edge
  for j := 0 to steps do
  begin
    th := a * j / steps;
    ov[j] := (r + t) * Sin(th); ow[j] := z1 + r - (r + t) * Cos(th);
    iv[j] := r * Sin(th); iw[j] := z1 + r - r * Cos(th);
  end;
  ov[steps + 1] := ov[steps] + L * Cos(a); ow[steps + 1] := ow[steps] + L * Sin(a);
  iv[steps + 1] := iv[steps] + L * Cos(a); iw[steps + 1] := iw[steps] + L * Sin(a);
  nBend := steps;
  Result := steps + 2;
end;

function SM_RefOk(const d: TDesign; i: Integer): Boolean;
var
  f, s: TFeature;
  j: Integer;
begin
  Result := False;
  f := d.F[i];
  case f.Kind of
    FK_SM_BASE:
      begin
        if (f.Ref < 1) or (f.Ref >= i) then Exit;
        s := d.F[f.Ref];
        if (s.Kind <> FK_SKETCH_RECT) or (s.P3 > 0) then Exit;
        if not IsLevel(FrameOf(d, f.Ref)) then Exit;       // sheet metal lies flat
        if not RefOk(d, f.Ref) then Exit;
        Result := (f.P1 > 0) and (f.P2 >= 0) and (f.P3 >= 0) and (f.P3 <= 1);
      end;
    FK_SM_EDGE:
      begin
        if not SM_Base_Ok(d, i, f.Ref) then Exit;
        if (f.X <> Int(f.X)) or (f.X < 0) or (f.X > 3) then Exit;
        if (f.P1 <= 0) or (f.P2 <= 0) or (f.P2 > 180) then Exit;
        if (f.P3 <> Int(f.P3)) or (f.P3 < 0) or (f.P3 > 3) or (f.Z < 0) then Exit;
        if SMSideLength(d, f.Ref, Round(f.X)) - 2 * SMMargin(d, i) <= 0 then Exit;
        // one flange to an edge: the first one gets it
        for j := f.Ref + 1 to i - 1 do
          if (d.F[j].Kind = FK_SM_EDGE) and (d.F[j].Ref = f.Ref) and (d.F[j].X = f.X) and (d.F[j].Suppressed = 0) then Exit;
        Result := True;
      end;
    FK_SM_FLAT:
      Result := SM_Base_Ok(d, i, f.Ref);
  end;
end;

{ One line, given in an edge's own u, v, w. }
procedure Wire(var e: TEdgeArray; var n: Integer; ox, oy, ux, uy, vx, vy, u1, v1, w1, u2, v2, w2: Double; c: LongWord);
begin
  AddEdge(e, n, ox + u1 * ux + v1 * vx, oy + u1 * uy + v1 * vy, w1, ox + u2 * ux + v2 * vx, oy + u2 * uy + v2 * vy, w2, c);
end;

procedure WireBox(var e: TEdgeArray; var n: Integer; x, y, w, h, z0, z1: Double);
var
  px, py: array[0..3] of Double;
  j, k: Integer;
begin
  px[0] := x; py[0] := y; px[1] := x + w; py[1] := y; px[2] := x + w; py[2] := y + h; px[3] := x; py[3] := y + h;
  for j := 0 to 3 do
  begin
    k := (j + 1) mod 4;
    AddEdge(e, n, px[j], py[j], z0, px[k], py[k], z0, COL_SOLID);
    AddEdge(e, n, px[j], py[j], z1, px[k], py[k], z1, COL_SOLID);
    AddEdge(e, n, px[j], py[j], z0, px[j], py[j], z1, COL_SOLID);
  end;
end;

procedure SM_Edges(const d: TDesign; i: Integer; var e: TEdgeArray; var n: Integer);
const
  WIRE_STEPS = 4;
var
  f: TFeature;
  x, y, w, h, z0, z1, ox, oy, ux, uy, vx, vy, ua, ub: Double;
  ov, ow, iv, iw: TDoubleArray;
  m, nb, j: Integer;
  bFlat: Boolean;
  cl: LongWord;
begin
  f := d.F[i];
  case f.Kind of
    FK_SM_BASE:
      begin
        SMBaseBox(d, i, x, y, w, h, z0, z1);
        WireBox(e, n, x, y, w, h, z0, z1);
      end;
    FK_SM_EDGE:
      begin
        bFlat := SMIsFlat(d, f.Ref);
        m := SMSection(d, i, bFlat, WIRE_STEPS, ov, ow, iv, iw, nb);
        SMEdgeFrame(d, f.Ref, Round(f.X), ox, oy, ux, uy, vx, vy);
        ua := SMMargin(d, i); ub := SMSideLength(d, f.Ref, Round(f.X)) - ua;
        // both ends of the flange, and the lines along it
        for j := 0 to m - 2 do
        begin
          Wire(e, n, ox, oy, ux, uy, vx, vy, ua, ov[j], ow[j], ua, ov[j + 1], ow[j + 1], COL_SOLID);
          Wire(e, n, ox, oy, ux, uy, vx, vy, ua, iv[j], iw[j], ua, iv[j + 1], iw[j + 1], COL_SOLID);
          Wire(e, n, ox, oy, ux, uy, vx, vy, ub, ov[j], ow[j], ub, ov[j + 1], ow[j + 1], COL_SOLID);
          Wire(e, n, ox, oy, ux, uy, vx, vy, ub, iv[j], iw[j], ub, iv[j + 1], iw[j + 1], COL_SOLID);
        end;
        Wire(e, n, ox, oy, ux, uy, vx, vy, ua, ov[m - 1], ow[m - 1], ua, iv[m - 1], iw[m - 1], COL_SOLID);
        Wire(e, n, ox, oy, ux, uy, vx, vy, ub, ov[m - 1], ow[m - 1], ub, iv[m - 1], iw[m - 1], COL_SOLID);
        for j := 0 to m - 1 do
          if (j = 0) or (j = nb) or (j = m - 1) then
          begin
            if bFlat and (j < m - 1) then cl := COL_BEND else cl := COL_SOLID;
            Wire(e, n, ox, oy, ux, uy, vx, vy, ua, ov[j], ow[j], ub, ov[j], ow[j], cl);
            Wire(e, n, ox, oy, ux, uy, vx, vy, ua, iv[j], iw[j], ub, iv[j], iw[j], cl);
          end;
      end;
  end;
end;

{ ---- the wireframe ---- }

{ Turns the design into edges. Returns the edge count. }
function Regenerate(const d: TDesign; out e: TEdgeArray): Integer;
var
  n, i, j, k, m, np, steps, nst: Integer;
  f, s: TFeature;
  z0, z1, zt, r, a0, a1, sz, fr, hx, hy: Double;
  px, py, qx, qy, ox, oy: TDoubleArray;
  seam, qseam: TBoolArray;
  used: array[0..MAX_FEATURES] of Boolean;
  rz: TDoubleArray;
  rs: TFeatureArray;
  rkey: TBoolArray;
  c: LongWord;
begin
  SetLength(e, 256);
  n := 0;
  FillChar(used, SizeOf(used), 0);
  for i := 1 to d.Count do
    if (d.F[i].Kind = FK_EXTRUDE) or (d.F[i].Kind = FK_REVOLVE) or (d.F[i].Kind = FK_SM_BASE) then
      if (d.F[i].Ref >= 1) and (d.F[i].Ref <= d.Count) then used[d.F[i].Ref] := True;

  for i := 1 to d.Count do
  begin
    f := d.F[i];
    if (f.Suppressed <> 0) or not RefOk(d, i) then Continue;
    case f.Kind of                      // each in its own frame
      FK_SKETCH_RECT, FK_SKETCH_CIRCLE: begin mXf := FrameOf(d, i); mXfOn := not IsLevel(mXf); end;
      FK_EXTRUDE, FK_REVOLVE, FK_HOLE: begin mXf := BodyFrame(d, i); mXfOn := not IsLevel(mXf); end;
    else
      mXfOn := False;
    end;
    case f.Kind of
      FK_SKETCH_RECT:
        begin
          sz := SketchZ(d, i);
          np := ProfilePoints(f, px, py, seam);
          if used[i] then c := COL_SKETCH_USED else c := COL_SKETCH;
          for j := 0 to np - 1 do
          begin
            k := (j + 1) mod np;
            AddEdge(e, n, px[j], py[j], sz, px[k], py[k], sz, c);
          end;
        end;
      FK_SKETCH_CIRCLE:
        begin
          if used[i] then c := COL_SKETCH_USED else c := COL_SKETCH;
          AddCircle(e, n, f.X, f.Y, SketchZ(d, i), f.P1, c);
        end;
      FK_EXTRUDE:
        begin
          s := d.F[f.Ref];
          ExtrudeRange(d, i, z0, z1);
          fr := FilletRadius(d, i);
          if fr <= 0 then
          begin
            np := ProfilePoints(s, px, py, seam);
            for j := 0 to np - 1 do
            begin
              k := (j + 1) mod np;
              AddEdge(e, n, px[j], py[j], z0, px[k], py[k], z0, COL_SOLID);
              AddEdge(e, n, px[j], py[j], z1, px[k], py[k], z1, COL_SOLID);
              if seam[j] then AddEdge(e, n, px[j], py[j], z0, px[j], py[j], z1, COL_SOLID);
            end;
          end
          else
          begin
            // the rings it goes through (bottom fillet, straight sides, top
            // fillet): a ring where a face starts or ends, and the quarter
            // circles (or the chamfer's slopes) at each seam
            nst := ExtrudeRings(d, i, FILLET_STEPS, rz, rs, rkey);
            np := ProfilePoints(s, px, py, seam, CIRCLE_SEGS, True);
            for m := 0 to nst - 1 do
            begin
              ProfilePoints(rs[m], qx, qy, qseam, CIRCLE_SEGS, True);
              if rkey[m] then
                for j := 0 to np - 1 do
                begin
                  k := (j + 1) mod np;
                  AddEdge(e, n, qx[j], qy[j], rz[m], qx[k], qy[k], rz[m], COL_SOLID);
                end;
              if m > 0 then
                for j := 0 to np - 1 do
                  if seam[j] then AddEdge(e, n, ox[j], oy[j], rz[m - 1], qx[j], qy[j], rz[m], COL_SOLID);
              ox := Copy(qx, 0, Length(qx)); oy := Copy(qy, 0, Length(qy));
            end;
          end;
        end;
      FK_REVOLVE:
        begin
          // spin the profile about the Y axis of its plane
          s := d.F[f.Ref];
          sz := SketchZ(d, f.Ref);
          np := ProfilePoints(s, px, py, seam);
          steps := Trunc(Abs(f.P1) / 15 + 0.5);
          if steps < 1 then steps := 1;
          for k := 0 to steps do
          begin
            a0 := (f.P1 * Pi / 180) * k / steps;
            // a copy of the profile every 45 degrees and at both ends
            if (k = 0) or (k = steps) or ((k mod 3) = 0) then
              for j := 0 to np - 1 do
                AddEdge(e, n, px[j] * Cos(a0), py[j], sz - px[j] * Sin(a0),
                  px[(j + 1) mod np] * Cos(a0), py[(j + 1) mod np], sz - px[(j + 1) mod np] * Sin(a0), COL_SOLID);
            // the path each profile corner traces
            if k < steps then
            begin
              a1 := (f.P1 * Pi / 180) * (k + 1) / steps;
              for j := 0 to np - 1 do
                if seam[j] and ((np <= 4) or (s.Kind = FK_SKETCH_RECT) or ((j mod 8) = 0)) then
                  AddEdge(e, n, px[j] * Cos(a0), py[j], sz - px[j] * Sin(a0),
                    px[j] * Cos(a1), py[j], sz - px[j] * Sin(a1), COL_SOLID);
            end;
          end;
          AddEdge(e, n, 0, -10, sz, 0, 10 + MaxAbs(py, np), sz, COL_AXIS);
        end;
      FK_HOLE:
        begin
          r := f.P1 / 2;
          for m := 0 to HoleCount(f) - 1 do
          begin
            HoleSpan(d, i, zt, z0, m);
            HoleAt(f, m, hx, hy);
            AddCircle(e, n, hx, hy, zt, r, COL_HOLE);
            AddCircle(e, n, hx, hy, z0, r, COL_HOLE);
            for j := 0 to 3 do
            begin
              a0 := j * Pi / 2;
              AddEdge(e, n, hx + r * Cos(a0), hy + r * Sin(a0), zt, hx + r * Cos(a0), hy + r * Sin(a0), z0, COL_HOLE);
            end;
          end;
        end;
    else
      if SM_IsSheetMetal(f.Kind) then SM_Edges(d, i, e, n);
    end;
  end;
  mXfOn := False;
  SetLength(e, n);
  Result := n;
end;

{ A feature is only drawn if what it is built on exists and comes before it. }
function RefOk(const d: TDesign; i: Integer): Boolean;
var
  f, tf: TFeature;
  zt, zb, z0, z1: Double;
  fj: Integer;
begin
  Result := False;
  f := d.F[i];
  case f.Kind of
    FK_SKETCH_RECT, FK_SKETCH_CIRCLE:
      if f.Ref = 0 then Result := True
      else if (f.Ref >= 1) and (f.Ref < i) then
      begin
        if d.F[f.Ref].Kind = FK_EXTRUDE then
        begin
          if SketchFace(f) = FACE_TOP then Result := RefOk(d, f.Ref)
          else if (SketchFace(f) >= FACE_FRONT) and (SketchFace(f) <= FACE_LEFT) then
            // a side face: the extrude has to have flat sides
            if d.F[d.F[f.Ref].Ref].Kind = FK_SKETCH_RECT then Result := RefOk(d, f.Ref);
        end;
      end;
    FK_EXTRUDE, FK_REVOLVE:
      if (f.Ref >= 1) and (f.Ref < i) then Result := IsSketch(d.F[f.Ref].Kind);
    FK_FOREIGN:
      Result := True;             // nothing to build, nothing to break
    FK_SM_BASE, FK_SM_EDGE, FK_SM_FLAT:
      Result := SM_RefOk(d, i);
    FK_FILLET, FK_CHAMFER:
      if (f.Ref >= 1) and (f.Ref < i) then
        if d.F[f.Ref].Kind = FK_EXTRUDE then
          if RefOk(d, f.Ref) then Result := FilletOf(d, f.Ref) = i;
    FK_HOLE:
      if (f.Ref >= 1) and (f.Ref < i) then
        if d.F[f.Ref].Kind = FK_EXTRUDE then
          if RefOk(d, f.Ref) then
          begin
            tf := TopFace(d, f.Ref);
            Result := HolesInside(tf, f);
            // one that comes out through a filleted bottom has to miss the fillet too
            fj := FilletOf(d, f.Ref);
            if Result and (fj > 0) then
              if FinishBottom(d.F[fj]) <> 0 then
              begin
                HoleSpan(d, i, zt, zb);
                ExtrudeRange(d, f.Ref, z0, z1);
                if zb < z0 + d.F[fj].P1 then Result := HolesInside(BottomFace(d, f.Ref), f);
              end;
          end;
  end;
end;

end.
