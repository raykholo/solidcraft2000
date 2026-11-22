{ uArt - the 16-colour icons, the logo, gradients: everything drawn from
  code, so the program ships no bitmaps. }
unit uArt;

{$mode objfpc}{$H+}

interface

uses Graphics, Controls, ImgList;

const
  APP_NAME = 'SolidCraft 2000';
  APP_EDITION = 'Delphi Edition';
  APP_BUILD = 'Build 2000.1122';
  APP_VERSION = 'Version 1.2.0';

  TEAL_DARK = $585000;         // RGB(0, 80, 88)
  TEAL_LIGHT = $B4AA78;        // RGB(120, 170, 180)
  FACE_2000 = $C8D0D4;         // RGB(212, 208, 200), the warm grey

var
  QB: array[0..15] of TColor;

function IconIndex(const AKey: string): Integer;
{ A 16 x 16 icon, s times the size; see-through pixels are clFuchsia. }
function IconBitmap(const AKey: string; s: Integer = 1): TBitmap;
procedure PaintIcon(c: TCanvas; const AKey: string; x, y: Integer; s: Integer = 1);
{ Row y of an icon: 16 hex digits (palette indexes), '.' for see-through. }
function IconRow(const AKey: string; y: Integer): string;
procedure AddIcons(il: TImageList; const Keys: array of string);
procedure GradientV(c: TCanvas; x, y, w, h: Integer; c1, c2: TColor);
procedure GradientH(c: TCanvas; x, y, w, h: Integer; c1, c2: TColor);
{ The logo: an isometric block with a hole in the top (our own art). }
procedure DrawLogo(c: TCanvas; ox, oy: Integer; s: Double; col: TColor);
{ The 2000 logo: the same block, with its top edges filleted, and the hole. }
procedure DrawLogo2000(c: TCanvas; ox, oy: Integer; s: Double; col: TColor);
{ The box-art starburst: "NEW! Fillets!". }
procedure DrawStarburst(c: TCanvas; cx, cy, r: Integer; const ALine1, ALine2: string);
{ A gold seal saying the program will still work on 1 January 2000. }
procedure DrawY2KBadge(c: TCanvas; cx, cy, r: Integer);

implementation

uses Types;

{$I icondata.inc}

function IconIndex(const AKey: string): Integer;
var
  i: Integer;
begin
  for i := 0 to ICON_COUNT - 1 do
    if IconNames[i] = AKey then Exit(i);
  Result := -1;
end;

function IconRow(const AKey: string; y: Integer): string;
var
  k: Integer;
begin
  k := IconIndex(AKey);
  if k < 0 then Exit(StringOfChar('.', 16));
  Result := IconArt[k, y];
end;

function HexVal(ch: Char): Integer;
begin
  if ch <= '9' then Result := Ord(ch) - Ord('0') else Result := Ord(ch) - Ord('A') + 10;
end;

procedure PaintIcon(c: TCanvas; const AKey: string; x, y: Integer; s: Integer);
var
  k, r, col: Integer;
begin
  k := IconIndex(AKey);
  if k < 0 then Exit;
  for r := 0 to 15 do
    for col := 0 to 15 do
      if IconArt[k, r][col + 1] <> '.' then
      begin
        c.Brush.Color := QB[HexVal(IconArt[k, r][col + 1])];
        c.FillRect(x + col * s, y + r * s, x + col * s + s, y + r * s + s);
      end;
end;

function IconBitmap(const AKey: string; s: Integer): TBitmap;
begin
  Result := TBitmap.Create;
  Result.SetSize(16 * s, 16 * s);
  Result.Canvas.Brush.Color := clFuchsia;
  Result.Canvas.FillRect(0, 0, 16 * s, 16 * s);
  PaintIcon(Result.Canvas, AKey, 0, 0, s);
  Result.TransparentColor := clFuchsia;
  Result.Transparent := True;
end;

procedure AddIcons(il: TImageList; const Keys: array of string);
var
  i: Integer;
  b: TBitmap;
begin
  for i := 0 to High(Keys) do
  begin
    b := IconBitmap(Keys[i]);
    il.AddMasked(b, clFuchsia);
    b.Free;
  end;
end;

function Mix(c1, c2: TColor; t: Double): TColor;
var
  r1, g1, b1, r2, g2, b2: Integer;
begin
  c1 := ColorToRGB(c1); c2 := ColorToRGB(c2);
  r1 := Red(c1); g1 := Green(c1); b1 := Blue(c1);
  r2 := Red(c2); g2 := Green(c2); b2 := Blue(c2);
  Result := RGBToColor(Round(r1 + (r2 - r1) * t), Round(g1 + (g2 - g1) * t), Round(b1 + (b2 - b1) * t));
end;

procedure GradientV(c: TCanvas; x, y, w, h: Integer; c1, c2: TColor);
var
  i: Integer;
begin
  for i := 0 to h - 1 do
  begin
    if h > 1 then c.Pen.Color := Mix(c1, c2, i / (h - 1)) else c.Pen.Color := c1;
    c.Line(x, y + i, x + w, y + i);
  end;
end;

procedure GradientH(c: TCanvas; x, y, w, h: Integer; c1, c2: TColor);
var
  i: Integer;
begin
  for i := 0 to w - 1 do
  begin
    if w > 1 then c.Pen.Color := Mix(c1, c2, i / (w - 1)) else c.Pen.Color := c1;
    c.Line(x + i, y, x + i, y + h);
  end;
end;

procedure IsoPt(x, y, z, s: Double; ox, oy: Integer; out sx, sy: Integer);
begin
  sx := ox + Round((x - y) * 0.866 * s);
  sy := oy + Round((x + y) * 0.5 * s - z * s);
end;

procedure DrawLogo(c: TCanvas; ox, oy: Integer; s: Double; col: TColor);
var
  px, py: array[0..7] of Integer;
  i, hx, hy, rx, ry: Integer;
begin
  IsoPt(0, 0, 0, s, ox, oy, px[0], py[0]); IsoPt(4, 0, 0, s, ox, oy, px[1], py[1]);
  IsoPt(4, 3, 0, s, ox, oy, px[2], py[2]); IsoPt(0, 3, 0, s, ox, oy, px[3], py[3]);
  IsoPt(0, 0, 1.5, s, ox, oy, px[4], py[4]); IsoPt(4, 0, 1.5, s, ox, oy, px[5], py[5]);
  IsoPt(4, 3, 1.5, s, ox, oy, px[6], py[6]); IsoPt(0, 3, 1.5, s, ox, oy, px[7], py[7]);
  c.Pen.Color := col;
  c.Pen.Width := 2;
  for i := 0 to 3 do
  begin
    c.Line(px[i], py[i], px[(i + 1) mod 4], py[(i + 1) mod 4]);
    c.Line(px[i + 4], py[i + 4], px[(i + 1) mod 4 + 4], py[(i + 1) mod 4 + 4]);
    c.Line(px[i], py[i], px[i + 4], py[i + 4]);
  end;
  IsoPt(2, 1.5, 1.5, s, ox, oy, hx, hy);
  rx := Round(s * 0.75); ry := Round(s * 0.75 * 0.55);
  c.Brush.Style := bsClear;
  c.Ellipse(hx - rx, hy - ry, hx + rx, hy + ry);
  c.Brush.Style := bsSolid;
  c.Pen.Width := 1;
end;

procedure DrawLogo2000(c: TCanvas; ox, oy: Integer; s: Double; col: TColor);
const
  R = 0.45; W = 4; D = 3; H = 1.5;
  CX: array[0..3] of Double = (0, W, W, 0);
  CY: array[0..3] of Double = (0, 0, D, D);
  SX: array[0..3] of Double = (1, -1, -1, 1);
  SY: array[0..3] of Double = (1, 1, -1, -1);
var
  i, k, j, x1, y1, x2, y2, hx, hy, rx, ry: Integer;
  zf, a0, a1: Double;
begin
  zf := H - R;
  c.Pen.Color := col;
  c.Pen.Width := 2;
  for i := 0 to 3 do
  begin
    k := (i + 1) mod 4;
    // bottom, the line where the fillet starts, and the smaller top
    IsoPt(CX[i], CY[i], 0, s, ox, oy, x1, y1);
    IsoPt(CX[k], CY[k], 0, s, ox, oy, x2, y2);
    c.Line(x1, y1, x2, y2);
    IsoPt(CX[i], CY[i], zf, s, ox, oy, x1, y1);
    IsoPt(CX[k], CY[k], zf, s, ox, oy, x2, y2);
    c.Line(x1, y1, x2, y2);
    IsoPt(CX[i] + SX[i] * R, CY[i] + SY[i] * R, H, s, ox, oy, x1, y1);
    IsoPt(CX[k] + SX[k] * R, CY[k] + SY[k] * R, H, s, ox, oy, x2, y2);
    c.Line(x1, y1, x2, y2);
    // the upright edge, and the quarter circle over the corner
    IsoPt(CX[i], CY[i], 0, s, ox, oy, x1, y1);
    IsoPt(CX[i], CY[i], zf, s, ox, oy, x2, y2);
    c.Line(x1, y1, x2, y2);
    for j := 1 to 6 do
    begin
      a0 := (Pi / 2) * (j - 1) / 6;
      a1 := (Pi / 2) * j / 6;
      IsoPt(CX[i] + SX[i] * R * (1 - Cos(a0)), CY[i] + SY[i] * R * (1 - Cos(a0)), zf + R * Sin(a0), s, ox, oy, x1, y1);
      IsoPt(CX[i] + SX[i] * R * (1 - Cos(a1)), CY[i] + SY[i] * R * (1 - Cos(a1)), zf + R * Sin(a1), s, ox, oy, x2, y2);
      c.Line(x1, y1, x2, y2);
    end;
  end;
  IsoPt(W / 2, D / 2, H, s, ox, oy, hx, hy);
  rx := Round(s * 0.7); ry := Round(s * 0.7 * 0.55);
  c.Brush.Style := bsClear;
  c.Ellipse(hx - rx, hy - ry, hx + rx, hy + ry);
  c.Brush.Style := bsSolid;
  c.Pen.Width := 1;
end;

procedure DrawStarburst(c: TCanvas; cx, cy, r: Integer; const ALine1, ALine2: string);
const
  SPIKES = 16;
var
  pts: array[0..2 * SPIKES - 1] of TPoint;
  i: Integer;
  a, rr: Double;
begin
  for i := 0 to 2 * SPIKES - 1 do
  begin
    a := Pi * i / SPIKES - Pi / 2 + 0.12;
    if i mod 2 = 0 then rr := r else rr := r * 0.74;
    pts[i].X := cx + Round(rr * Cos(a));
    pts[i].Y := cy + Round(rr * Sin(a));
  end;
  c.Brush.Color := RGBToColor(255, 214, 0);
  c.Pen.Color := RGBToColor(200, 40, 0);
  c.Pen.Width := 1;
  c.Polygon(pts);
  c.Brush.Style := bsClear;
  c.Font.Name := 'Arial';
  c.Font.Style := [fsBold];
  c.Font.Color := RGBToColor(200, 0, 0);
  c.Font.Size := 11;
  c.TextOut(cx - c.TextWidth(ALine1) div 2, cy - c.TextHeight(ALine1) + 1, ALine1);
  c.Font.Size := 9;
  c.TextOut(cx - c.TextWidth(ALine2) div 2, cy + 1, ALine2);
  c.Font.Style := [];
  c.Brush.Style := bsSolid;
end;

procedure DrawY2KBadge(c: TCanvas; cx, cy, r: Integer);
var
  pts: array[0..39] of TPoint;
  i: Integer;
  a, rr: Double;
  s: string;
begin
  for i := 0 to 39 do
  begin
    a := 2 * Pi * i / 40;
    if i mod 2 = 0 then rr := r else rr := r * 0.9;
    pts[i].X := cx + Round(rr * Cos(a));
    pts[i].Y := cy + Round(rr * Sin(a));
  end;
  c.Brush.Color := RGBToColor(230, 180, 48);
  c.Pen.Color := RGBToColor(156, 108, 24);
  c.Pen.Width := 1;
  c.Polygon(pts);
  c.Brush.Style := bsClear;
  c.Ellipse(cx - Round(r * 0.72), cy - Round(r * 0.72), cx + Round(r * 0.72), cy + Round(r * 0.72));
  c.Font.Name := 'Arial';
  c.Font.Style := [fsBold];
  c.Font.Color := RGBToColor(64, 32, 0);
  c.Font.Size := 12;
  s := 'Y2K';
  c.TextOut(cx - c.TextWidth(s) div 2, cy - c.TextHeight(s) + 3, s);
  c.Font.Size := 6;
  s := 'COMPLIANT*';
  c.TextOut(cx - c.TextWidth(s) div 2, cy + 2, s);
  c.Font.Style := [];
  c.Brush.Style := bsSolid;
end;

initialization
  QB[0] := $000000; QB[1] := $800000; QB[2] := $008000; QB[3] := $808000;
  QB[4] := $000080; QB[5] := $800080; QB[6] := $008080; QB[7] := $C0C0C0;
  QB[8] := $808080; QB[9] := $FF0000; QB[10] := $00FF00; QB[11] := $FFFF00;
  QB[12] := $0000FF; QB[13] := $FF00FF; QB[14] := $00FFFF; QB[15] := $FFFFFF;
end.
