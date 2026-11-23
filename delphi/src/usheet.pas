{ uSheet - sheet metal, new in 2000: the flat pattern as a DXF with an 8.3
  file name, and the bend table the wizard last made. The geometry (the
  wireframe and the solid) is in uKernel and uMesh. A port of
  modSheetMetal's reference engine; its limits are the same, on purpose: one
  bend per edge flange, only on the four edges of the base, no flanges on
  flanges, no corner treatment, relief cut only in the flat pattern, and every
  bend the same R. }
unit uSheet;

{$mode objfpc}{$H+}

interface

uses uModel;

var
  { The bend table the wizard last made, for new base flanges. }
  SMTableSet: Boolean;
  SMTableName: string;
  SMTableT, SMTableR, SMTableK: Double;

function EdgeNameOf(e: Integer): string;
{ The unfolded outline and the bend lines, as LINEs in an R12 DXF: the
  outline on layer OUTLINE, the bend lines on layer BEND. }
function WriteFlatDxf(const d: TDesign; b: Integer; const APath: string): Boolean;
{ MOUNTI~1.DXF: up to six letters or digits of the title, then ~1, ~2... if
  that's taken. }
function FlatPatternPath(const ADir, ATitle: string): string;

implementation

uses SysUtils, Classes, uKernel;

function EdgeNameOf(e: Integer): string;
begin
  case e of
    0: Result := 'front';
    1: Result := 'right';
    2: Result := 'back';
  else
    Result := 'left';
  end;
end;

function FlatPatternPath(const ADir, ATitle: string): string;
var
  base: string;
  k, n: Integer;
  c: Char;
begin
  base := '';
  for k := 1 to Length(Trim(ATitle)) do
  begin
    c := UpCase(Trim(ATitle)[k]);
    if c in ['A'..'Z', '0'..'9'] then base := base + c;
    if Length(base) = 6 then Break;
  end;
  if base = '' then base := 'FLAT';
  n := 1;
  repeat
    Result := IncludeTrailingPathDelimiter(ADir) + base + '~' + IntToStr(n) + '.DXF';
    if not FileExists(Result) then Exit;
    Inc(n);
  until n >= 10;
end;

{ A number with a decimal point whatever the PC's region says. }
function DxfNum(v: Double): string;
begin
  v := Int(v * 10000 + 0.5) / 10000;
  Result := FmtN(v, 4);
  if Result = '' then Result := '0';
end;

var
  gOut: TStringList;

procedure DxfLine(const sLayer: string; ox, oy, ux, uy, vx, vy, u1, v1, u2, v2: Double);
begin
  gOut.Add('0'); gOut.Add('LINE'); gOut.Add('8'); gOut.Add(sLayer);
  gOut.Add('10'); gOut.Add(DxfNum(ox + u1 * ux + v1 * vx));
  gOut.Add('20'); gOut.Add(DxfNum(oy + u1 * uy + v1 * vy));
  gOut.Add('30'); gOut.Add('0');
  gOut.Add('11'); gOut.Add(DxfNum(ox + u2 * ux + v2 * vx));
  gOut.Add('21'); gOut.Add(DxfNum(oy + u2 * uy + v2 * vy));
  gOut.Add('31'); gOut.Add('0');
end;

{ A relief cut into the base between u = ua and u = ub, dr deep (v < 0). The
  outline arrives at (ua, 0) and leaves from (ub, 0). A tear has no width:
  it's one cut, at u = slitU, where the flange starts or ends. }
procedure Relief(ox, oy, ux, uy, vx, vy, ua, ub, dr: Double; rel: Integer; slitU: Double);
var
  j: Integer;
  a0, a1, cu, rr, cv: Double;
begin
  case rel of
    SM_RELIEF_RECT:
      begin
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ua, 0, ua, -dr);
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ua, -dr, ub, -dr);
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ub, -dr, ub, 0);
      end;
    SM_RELIEF_OBROUND:
      begin
        rr := (ub - ua) / 2; cu := (ua + ub) / 2; cv := -dr + rr;
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ua, 0, ua, cv);
        for j := 0 to 7 do
        begin
          a0 := Pi + Pi * j / 8; a1 := Pi + Pi * (j + 1) / 8;
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, cu + rr * Cos(a0), cv + rr * Sin(a0), cu + rr * Cos(a1), cv + rr * Sin(a1));
        end;
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ub, cv, ub, 0);
      end;
  else
    DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ua, 0, ub, 0);
    DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, slitU, 0, slitU, -dr);
  end;
end;

function WriteFlatDxf(const d: TDesign; b: Integer; const APath: string): Boolean;
var
  e, j, fl, rel: Integer;
  ox, oy, ux, uy, vx, vy, side, ua, ub, s, ba, wr, dr, t, r, k: Double;
begin
  Result := False;
  t := d.F[b].P1; r := d.F[b].P2; k := d.F[b].P3;
  gOut := TStringList.Create;
  try
    gOut.Add('0'); gOut.Add('SECTION'); gOut.Add('2'); gOut.Add('ENTITIES');
    for e := 0 to 3 do
    begin
      SMEdgeFrame(d, b, e, ox, oy, ux, uy, vx, vy);
      side := SMSideLength(d, b, e);
      fl := 0;
      for j := b + 1 to d.Count do
        if (d.F[j].Kind = FK_SM_EDGE) and (d.F[j].Ref = b) and (d.F[j].X = e) then
          if SM_RefOk(d, j) and (d.F[j].Suppressed = 0) then begin fl := j; Break; end;
      if fl = 0 then
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, 0, 0, side, 0)
      else
      begin
        ua := SMMargin(d, fl); ub := side - ua;
        ba := SMBendAllowance(d.F[fl].P2, r, k, t);
        s := ba + d.F[fl].P1;
        rel := Round(d.F[fl].P3);
        wr := SMReliefWidth(d, fl);
        dr := r + t;                              // relief goes in past the bend
        // along to the flange, round it, and on to the corner
        if rel = SM_RELIEF_NONE then
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, 0, 0, 0, s)
        else
        begin
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, 0, 0, wr, 0);
          Relief(ox, oy, ux, uy, vx, vy, wr, ua, dr, rel, ua);
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ua, 0, ua, s);
        end;
        DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ua, s, ub, s);
        if rel = SM_RELIEF_NONE then
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ub, s, side, 0)
        else
        begin
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, ub, s, ub, 0);
          Relief(ox, oy, ux, uy, vx, vy, ub, side - wr, dr, rel, ub);
          DxfLine('OUTLINE', ox, oy, ux, uy, vx, vy, side - wr, 0, side, 0);
        end;
        DxfLine('BEND', ox, oy, ux, uy, vx, vy, ua, 0, ub, 0);
        DxfLine('BEND', ox, oy, ux, uy, vx, vy, ua, ba, ub, ba);
      end;
    end;
    gOut.Add('0'); gOut.Add('ENDSEC'); gOut.Add('0'); gOut.Add('EOF');
    try
      gOut.LineBreak := #13#10;
      gOut.SaveToFile(APath);
      Result := True;
    except
      Result := False;
    end;
  finally
    gOut.Free;
    gOut := nil;
  end;
end;

end.
