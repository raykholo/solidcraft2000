{ fWizard - the two wizards of 2000: the Upgrade Wizard (Help, Upgrade from
  SolidCraft 98) and the Bend Table Wizard (Sheet Metal), with its Advanced
  button, which opens a dialog over the wizard, which opens a message box
  over that. Like every wizard of its day they ask a lot. The Upgrade Wizard
  does nothing at all: the upgrade that matters happens when you open an
  .sc98 part. The Bend Table Wizard sets the numbers for the next base flange. }
unit fWizard;

{$mode objfpc}{$H+}

interface

procedure ShowUpgradeWizard;
{ True if it was finished, and the bend table is set. }
function RunBendTableWizard: Boolean;

implementation

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  uModel, uDocs, uArt, uSheet, fDialogs;

type
  TWizardForm = class(TForm)
  public
    Side: TPaintBox;
    Title, Body: TLabel;
    OptA, OptB: TRadioButton;
    Lst: TListBox;
    Bar: TPaintBox;
    BtnBack, BtnNext, BtnCancel, BtnAdv: TButton;
    Page: Integer;
    SideText1, SideText2: string;
    SideBig: Boolean;
    BarFrac: Double;
    constructor CreateWizard(AOwner: TComponent; const ACaption: string);
    procedure SidePaint(Sender: TObject);
    procedure BarPaint(Sender: TObject);
    procedure ShowPage; virtual; abstract;
    procedure NextClick(Sender: TObject); virtual; abstract;
    procedure BackClick(Sender: TObject);
    procedure CancelClick(Sender: TObject); virtual; abstract;
    procedure OptClick(Sender: TObject); virtual;
    procedure ListClick(Sender: TObject); virtual;
    procedure ListDbl(Sender: TObject);
    { Enter goes to Next (or Finish) on every page, not to whatever button had the focus last. }
    procedure FocusNext;
    { A label drops empty lines (GTK), so a blank line gets a space in it. }
    procedure FixBody;
  end;

constructor TWizardForm.CreateWizard(AOwner: TComponent; const ACaption: string);
begin
  inherited CreateNew(AOwner);
  Caption := ACaption;
  BorderStyle := bsDialog;
  Position := poMainFormCenter;
  ClientWidth := 500; ClientHeight := 340;
  Color := FACE_2000;
  Side := TPaintBox.Create(Self); Side.Parent := Self; Side.SetBounds(0, 0, 150, 292);
  Side.OnPaint := @SidePaint;
  Title := TLabel.Create(Self); Title.Parent := Self; Title.SetBounds(166, 14, 318, 40);
  Title.AutoSize := False; Title.WordWrap := True; Title.Font.Style := [fsBold]; Title.Font.Size := 11;
  Body := TLabel.Create(Self); Body.Parent := Self; Body.SetBounds(166, 62, 318, 160);
  Body.AutoSize := False; Body.WordWrap := True;
  OptA := TRadioButton.Create(Self); OptA.Parent := Self; OptA.SetBounds(180, 226, 290, 22);
  OptB := TRadioButton.Create(Self); OptB.Parent := Self; OptB.SetBounds(180, 252, 290, 22);
  OptA.OnClick := @OptClick; OptB.OnClick := @OptClick;
  Lst := TListBox.Create(Self); Lst.Parent := Self; Lst.SetBounds(166, 120, 318, 140);
  Lst.OnClick := @ListClick; Lst.OnDblClick := @ListDbl;
  Bar := TPaintBox.Create(Self); Bar.Parent := Self; Bar.SetBounds(166, 240, 318, 18);
  Bar.OnPaint := @BarPaint;
  BtnAdv := TButton.Create(Self); BtnAdv.Parent := Self; BtnAdv.SetBounds(166, 302, 90, 26);
  BtnAdv.Caption := '&Advanced...';
  BtnBack := TButton.Create(Self); BtnBack.Parent := Self; BtnBack.SetBounds(258, 302, 74, 26);
  BtnBack.Caption := '< &Back'; BtnBack.OnClick := @BackClick;
  BtnNext := TButton.Create(Self); BtnNext.Parent := Self; BtnNext.SetBounds(336, 302, 74, 26);
  BtnNext.Caption := '&Next >'; BtnNext.Default := True; BtnNext.OnClick := @NextClick;
  BtnCancel := TButton.Create(Self); BtnCancel.Parent := Self; BtnCancel.SetBounds(414, 302, 74, 26);
  BtnCancel.Caption := 'Cancel'; BtnCancel.Cancel := True; BtnCancel.OnClick := @CancelClick;
end;

procedure TWizardForm.SidePaint(Sender: TObject);
var
  c: TCanvas;
begin
  c := Side.Canvas;
  GradientV(c, 0, 0, Side.Width, Side.Height, TEAL_LIGHT, TEAL_DARK);
  DrawLogo2000(c, 70, 70, 15, clWhite);
  c.Brush.Style := bsClear;
  c.Font.Name := 'Arial'; c.Font.Style := [fsBold]; c.Font.Size := 13; c.Font.Color := clWhite;
  c.TextOut(14, 170, SideText1);
  if SideBig then
  begin
    c.Font.Name := 'Arial Black'; c.Font.Size := 20; c.Font.Color := RGBToColor(255, 236, 140);
    c.TextOut(14, 190, '2000');
    c.Font.Name := 'Arial'; c.Font.Style := []; c.Font.Size := 8; c.Font.Color := clWhite;
    c.TextOut(14, 228, SideText2);
    DrawY2KBadge(c, 128, 258, 24);
  end
  else
  begin
    c.TextOut(14, 192, 'Wizard');
    c.Font.Style := []; c.Font.Size := 8;
    c.TextOut(14, 228, SideText2);
  end;
  c.Brush.Style := bsSolid;
  c.Pen.Color := clGray;
  c.Line(0, 292, 500, 292);
end;

procedure TWizardForm.BarPaint(Sender: TObject);
var
  c: TCanvas;
begin
  c := Bar.Canvas;
  c.Brush.Color := clWhite;
  c.Pen.Color := clGray;
  c.Rectangle(0, 0, Bar.Width, Bar.Height);
  c.Brush.Color := TEAL_DARK;
  c.FillRect(1, 1, 1 + Round((Bar.Width - 2) * BarFrac), Bar.Height - 1);
end;

procedure TWizardForm.BackClick(Sender: TObject);
begin
  if Page > 0 then Dec(Page);
  ShowPage;
end;

procedure TWizardForm.FixBody;
begin
  Body.Caption := StringReplace(Body.Caption, LineEnding + LineEnding, LineEnding + ' ' + LineEnding, [rfReplaceAll]);
end;

procedure TWizardForm.FocusNext;
begin
  FixBody;
  try
    if Lst.Visible then ActiveControl := Lst else ActiveControl := BtnNext;
  except
    // before the form is on screen there's no focus to give
  end;
end;

procedure TWizardForm.OptClick(Sender: TObject);
begin
end;

procedure TWizardForm.ListClick(Sender: TObject);
begin
end;

procedure TWizardForm.ListDbl(Sender: TObject);
begin
  NextClick(Sender);
end;

{ ---- the Upgrade Wizard ---- }

type
  TUpgradeForm = class(TWizardForm)
  public
    Accepted, Clean: Boolean;
    Checked: Integer;
    Tmr: TTimer;
    constructor CreateUpgrade(AOwner: TComponent);
    procedure ShowPage; override;
    procedure NextClick(Sender: TObject); override;
    procedure CancelClick(Sender: TObject); override;
    procedure OptClick(Sender: TObject); override;
    procedure CheckStep;
    procedure Tick(Sender: TObject);
  end;

const
  LAST_UPGRADE_PAGE = 4;

constructor TUpgradeForm.CreateUpgrade(AOwner: TComponent);
begin
  inherited CreateWizard(AOwner, APP_NAME + ' Upgrade Wizard');
  SideText1 := 'SolidCraft'; SideText2 := 'Upgrade Wizard'; SideBig := True;
  BtnAdv.Visible := False; Lst.Visible := False;
  Tmr := TTimer.Create(Self); Tmr.Enabled := False; Tmr.Interval := 700; Tmr.OnTimer := @Tick;
  Page := 0;
  ShowPage;
end;

procedure TUpgradeForm.ShowPage;
var
  s2: string;
begin
  s2 := LineEnding + LineEnding;
  OptA.Visible := False; OptB.Visible := False; Bar.Visible := False;
  BtnBack.Enabled := Page > 0;
  if Page = LAST_UPGRADE_PAGE then BtnNext.Caption := 'Finish' else BtnNext.Caption := '&Next >';
  BtnNext.Enabled := True;
  case Page of
    0: begin
         Title.Caption := 'Welcome to the SolidCraft 2000 Upgrade Wizard';
         Body.Caption := 'This wizard upgrades SolidCraft 98 to SolidCraft 2000.' + s2 +
           'New in SolidCraft 2000:' + LineEnding +
           '    - Fillets!' + LineEnding +
           '    - Personalized Menus, which hide what you don''t use' + LineEnding +
           '    - Year 2000 compliance*' + LineEnding +
           '    - Sheet metal (some assembly required)' + s2 +
           'To continue, click Next.';
       end;
    1: begin
         Title.Caption := 'License Agreement';
         Body.Caption := 'Please read the following license agreement.' + s2 +
           'SolidCraft 2000 is free software under the MIT License: you may use, copy, change and ' +
           'give away copies of it, as long as the copyright notice goes with them. It comes with no ' +
           'warranty of any kind, express, implied, or rounded.' + s2 +
           'Do you accept all the terms of the license agreement?';
         OptA.Caption := 'I &accept the agreement';
         OptB.Caption := 'I &do not accept the agreement';
         OptA.Checked := Accepted; OptB.Checked := not Accepted;
         OptA.Visible := True; OptB.Visible := True;
         BtnNext.Enabled := Accepted;
       end;
    2: begin
         Title.Caption := 'Choose Installation Type';
         Body.Caption := 'How do you want to install SolidCraft 2000?' + s2 +
           'Upgrade keeps your SolidCraft 98 parts and settings.' + LineEnding +
           'Clean install starts fresh.';
         OptA.Caption := '&Upgrade (Recommended)';
         OptB.Caption := '&Clean install';
         OptA.Checked := not Clean; OptB.Checked := Clean;
         OptA.Visible := True; OptB.Visible := True;
       end;
    3: begin
         Title.Caption := 'Checking for Year 2000 Compliance';
         Bar.Visible := True;
         Checked := 0;
         BtnNext.Enabled := False;
         BtnBack.Enabled := False;
         CheckStep;
         Tmr.Enabled := True;
       end;
    4: begin
         Title.Caption := 'Completing the SolidCraft 2000 Upgrade Wizard';
         Body.Caption := 'You have successfully ';
         if Clean then Body.Caption := Body.Caption + 'clean-installed' else Body.Caption := Body.Caption + 'upgraded to';
         Body.Caption := Body.Caption + ' SolidCraft 2000.' + s2;
         if Clean then
           Body.Caption := Body.Caption + 'Your SolidCraft 98 parts were left exactly where they were. So was everything else. ' +
             'A clean install is the same as an upgrade, only cleaner.' + s2
         else
           Body.Caption := Body.Caption + 'Settings copied from SolidCraft 98: 0 (it didn''t have any).' + LineEnding +
             'Parts made in SolidCraft 98 are upgraded when you open them.' + s2;
         Body.Caption := Body.Caption + 'Nothing on this computer was changed. To close this wizard, click Finish.';
       end;
  end;
  if Page <> 3 then FocusNext;
end;

{ One line of the Year 2000 check per tick, and the bar. }
procedure TUpgradeForm.CheckStep;
var
  s: string;
begin
  s := 'Looking for two-digit years...';
  case Checked of
    0: ;
    1: s := s + ' none found.';
  else
    s := 'Looking for two-digit years... none found.' + LineEnding + 'Rolling the clock over to 1 January 2000... OK.';
    if Checked >= 3 then s := s + LineEnding + 'Checking 29 February 2000 (it is a leap year)... OK.';
    if Checked >= 4 then
      s := s + LineEnding + LineEnding + 'SolidCraft 2000 is Year 2000 compliant.' + LineEnding +
        '* Tested until 19 January 2038. After that, you''re on your own.';
  end;
  Body.Caption := s;
  FixBody;
  if Checked >= 4 then BarFrac := 1 else BarFrac := Checked / 4;
  Bar.Invalidate;
end;

procedure TUpgradeForm.Tick(Sender: TObject);
begin
  Inc(Checked);
  CheckStep;
  if Checked >= 4 then
  begin
    Tmr.Enabled := False;
    BtnNext.Enabled := True;
    BtnBack.Enabled := True;
    FocusNext;
  end;
end;

procedure TUpgradeForm.OptClick(Sender: TObject);
begin
  if not TRadioButton(Sender).Checked then Exit;
  if Page = 1 then
  begin
    Accepted := Sender = OptA;
    BtnNext.Enabled := Accepted;
  end;
  if Page = 2 then Clean := Sender = OptB;
end;

procedure TUpgradeForm.NextClick(Sender: TObject);
begin
  if Page = LAST_UPGRADE_PAGE then
  begin
    ModalResult := mrOk;
    Exit;
  end;
  Inc(Page);
  ShowPage;
end;

procedure TUpgradeForm.CancelClick(Sender: TObject);
begin
  if MsgBox('Are you sure you want to cancel the upgrade?' + LineEnding + LineEnding +
    'SolidCraft 2000 will keep working anyway.', MB_QUESTION or MB_YESNO, Caption) = IDYES then ModalResult := mrCancel;
end;

procedure ShowUpgradeWizard;
var
  f: TUpgradeForm;
begin
  f := TUpgradeForm.CreateUpgrade(Application);
  try
    f.ShowModal;
  finally
    f.Free;
  end;
end;

{ ---- the Bend Table Wizard ---- }

type
  TBendForm = class(TWizardForm)
  public
    Material, Gauge: Integer;
    R, K: Double;
    Ok: Boolean;
    constructor CreateBend(AOwner: TComponent);
    function MaterialName(m: Integer): string;
    function Gauges(m: Integer): string;
    function Thickness: Double;
    procedure Suggest;
    function TableName: string;
    procedure ShowSummary;
    procedure ShowPage; override;
    procedure NextClick(Sender: TObject); override;
    procedure CancelClick(Sender: TObject); override;
    procedure ListClick(Sender: TObject); override;
    procedure AdvClick(Sender: TObject);
  end;

const
  LAST_BEND_PAGE = 2;

constructor TBendForm.CreateBend(AOwner: TComponent);
begin
  inherited CreateWizard(AOwner, 'Bend Table Wizard');
  SideText1 := 'Bend Table'; SideText2 := 'SolidCraft 2000 Sheet Metal'; SideBig := False;
  OptA.Visible := False; OptB.Visible := False; Bar.Visible := False;
  BtnAdv.OnClick := @AdvClick;
  Material := 0; Gauge := 2;
  Page := 0;
  ShowPage;
end;

function TBendForm.MaterialName(m: Integer): string;
begin
  case m of
    0: Result := 'Mild steel';
    1: Result := 'Aluminium 5052';
    2: Result := 'Stainless steel 304';
    3: Result := 'Copper';
  else
    Result := 'Cereal box (for prototypes)';
  end;
end;

{ The thicknesses each material comes in, as the list shows them. }
function TBendForm.Gauges(m: Integer): string;
begin
  case m of
    0, 2: Result := '20 gauge (0.91 mm)|18 gauge (1.21 mm)|16 gauge (1.52 mm)|14 gauge (1.90 mm)|12 gauge (2.66 mm)';
    1: Result := '0.8 mm|1.0 mm|1.6 mm|2.0 mm|3.0 mm';
    3: Result := '0.5 mm|1.0 mm|1.5 mm|2.0 mm';
  else
    Result := '0.4 mm (one layer)|0.8 mm (two layers, glued)';
  end;
end;

{ The thickness in a gauge's description: the number before " mm". }
function TBendForm.Thickness: Double;
var
  sl: TStringList;
  s: string;
  p, q: Integer;
begin
  sl := TStringList.Create;
  try
    sl.StrictDelimiter := True; sl.Delimiter := '|'; sl.DelimitedText := Gauges(Material);
    s := sl[Gauge];
  finally
    sl.Free;
  end;
  q := Pos(' mm', s);
  p := q - 1;
  while (p > 1) and (s[p - 1] in ['0'..'9', '.']) do Dec(p);
  Result := StrToFloatDef(Copy(s, p, q - p), 0, DefaultFormatSettings);
end;

{ The suggestion: bend radius and K-factor for the material and thickness. }
procedure TBendForm.Suggest;
var
  t: Double;
begin
  t := Thickness;
  case Material of
    0: begin R := t; K := 0.44; end;
    1: begin R := t; K := 0.43; end;
    2: begin R := 1.5 * t; K := 0.45; end;
    3: begin R := t; K := 0.42; end;
  else
    R := 0; K := 0.5;
  end;
  R := Int(R * 100 + 0.5) / 100;
end;

{ "STEEL16.BTL": the table's 8.3 name, which nothing ever saves. }
function TBendForm.TableName: string;
var
  p: string;
begin
  case Material of
    0: p := 'STEEL';
    1: p := 'ALUM';
    2: p := 'SS304';
    3: p := 'COPPER';
  else
    p := 'CEREAL';
  end;
  Result := p + Format('%.2d', [Gauge + 1]) + '.BTL';
end;

procedure TBendForm.ShowSummary;
begin
  Title.Caption := 'Step 3 of 3: Bend Radius and K-Factor';
  Body.Caption := 'Bend table: ' + TableName + LineEnding + LineEnding +
    '    Material:  ' + MaterialName(Material) + LineEnding +
    '    Thickness:  ' + FmtN(Thickness, 4) + ' mm' + LineEnding +
    '    Inside bend radius:  ' + FmtN(R, 4) + ' mm' + LineEnding +
    '    K-factor:  ' + FmtN(K, 2) + LineEnding + LineEnding +
    'To change these, click Advanced. To create the table, click Finish.';
end;

procedure TBendForm.ShowPage;
var
  sl: TStringList;
  i: Integer;
begin
  BtnBack.Enabled := Page > 0;
  if Page = LAST_BEND_PAGE then BtnNext.Caption := 'Finish' else BtnNext.Caption := '&Next >';
  BtnAdv.Visible := Page = LAST_BEND_PAGE;
  Lst.Visible := Page < LAST_BEND_PAGE;
  Lst.Items.Clear;
  case Page of
    0: begin
         Title.Caption := 'Step 1 of 3: Material';
         Body.Caption := 'This wizard creates a bend table for your sheet metal parts.' + LineEnding + LineEnding +
           'What material are your parts made of?';
         for i := 0 to 4 do Lst.Items.Add(MaterialName(i));
         Lst.ItemIndex := Material;
       end;
    1: begin
         Title.Caption := 'Step 2 of 3: Thickness';
         Body.Caption := 'What thickness of ' + LowerCase(MaterialName(Material)) + ' will you use?' + LineEnding + LineEnding +
           '(Every part made with this table is this thick. To change it, run the wizard again.)';
         sl := TStringList.Create;
         try
           sl.StrictDelimiter := True; sl.Delimiter := '|'; sl.DelimitedText := Gauges(Material);
           Lst.Items.AddStrings(sl);
           if Gauge > sl.Count - 1 then Gauge := sl.Count - 1;
         finally
           sl.Free;
         end;
         Lst.ItemIndex := Gauge;
       end;
    2: begin
         Suggest;
         ShowSummary;
       end;
  end;
  if Page < LAST_BEND_PAGE then Body.Height := 56 else Body.Height := 200;
  Lst.Top := 126; Lst.Height := 160;
  FocusNext;
end;

procedure TBendForm.ListClick(Sender: TObject);
begin
  if Lst.ItemIndex < 0 then Exit;
  if Page = 0 then Material := Lst.ItemIndex;
  if Page = 1 then Gauge := Lst.ItemIndex;
end;

{ A dialog over the wizard, for the two numbers nobody should change. }
procedure TBendForm.AdvClick(Sender: TObject);
begin
  if not AskParams('Advanced Bend Table Options', 'Inside bend radius (mm)|K-factor (0 to 1)',
    FmtN(R, 4) + '|' + FmtN(K, 4)) then Exit;
  if (ParamValue[0] < 0) or (ParamValue[1] < 0) or (ParamValue[1] > 1) then
  begin
    MsgBox('The bend radius must be zero or more, and the K-factor between 0 and 1.', MB_EXCLAMATION, Caption);
    Exit;
  end;
  if ParamValue[1] <> K then
    if MsgBox('Changing the K-factor changes the size of every flat pattern made with this table.' + LineEnding + LineEnding +
      'Are you sure you want to change the K-factor?', MB_EXCLAMATION or MB_YESNO or MB_DEFBUTTON2, Caption) = IDNO then Exit;
  R := ParamValue[0];
  K := ParamValue[1];
  ShowSummary;
  FocusNext;
end;

procedure TBendForm.NextClick(Sender: TObject);
begin
  if Page = 0 then Gauge := 2;
  if Page = LAST_BEND_PAGE then
  begin
    SMTableSet := True;
    SMTableName := TableName;
    SMTableT := Thickness;
    SMTableR := R;
    SMTableK := K;
    Ok := True;
    ModalResult := mrOk;
    Exit;
  end;
  Inc(Page);
  ShowPage;
end;

procedure TBendForm.CancelClick(Sender: TObject);
begin
  if MsgBox('Are you sure you want to cancel the Bend Table Wizard?' + LineEnding + LineEnding +
    'Sheet metal parts need a bend table.', MB_QUESTION or MB_YESNO, Caption) = IDYES then ModalResult := mrCancel;
end;

function RunBendTableWizard: Boolean;
var
  f: TBendForm;
begin
  f := TBendForm.CreateBend(Application);
  try
    f.ShowModal;
    Result := f.Ok;
  finally
    f.Free;
  end;
end;

end.
