{ uStability - SolidCraft 2000 crashes on schedule. (Requested by brett19, who
  asked that "every 15 minutes or so, it blue screens".)

  Every 12 to 18 minutes of running, a blue screen covers everything. Any key
  or click closes it, and nothing underneath is touched: the design, the undo
  list and the open dialogs are all exactly as they were.

  Help, Install Stability Pack turns it off, and is remembered: one setting in
  SolidCraft2000.ini in the user's config folder (the Windows version keeps
  it in the registry, where VB's SaveSetting puts it). It's off with --stable
  (or /STABLE), so nothing testing the program gets a surprise; --crashtest
  (or /CRASHTEST) brings the first one forward to ten seconds. }
unit uStability;

{$mode objfpc}{$H+}

interface

procedure StabilityStart;
{ Called every second by the main window's clock. True when a blue screen is due. }
function StabilityTick: Boolean;
function StabilityPackInstalled: Boolean;
procedure SetStabilityPack(AOn: Boolean);
{ Seconds until the next one, for the tests. }
function StabilityDue: Integer;

implementation

uses SysUtils, IniFiles;

var
  mSeconds, mDue: Integer;
  mOffThisRun: Boolean;

function HasParam(const a, b: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if (UpperCase(ParamStr(i)) = UpperCase(a)) or (UpperCase(ParamStr(i)) = UpperCase(b)) then Exit(True);
end;

function IniPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'SolidCraft2000.ini';
end;

procedure NextCrash;
begin
  mSeconds := 0;
  mDue := 12 * 60 + Random(6 * 60);
end;

function StabilityPackInstalled: Boolean;
var
  ini: TIniFile;
begin
  Result := False;
  try
    if not FileExists(IniPath) then Exit;
    ini := TIniFile.Create(IniPath);
    try
      Result := ini.ReadString('Options', 'StabilityPack', '0') = '1';
    finally
      ini.Free;
    end;
  except
    Result := False;
  end;
end;

procedure SetStabilityPack(AOn: Boolean);
var
  ini: TIniFile;
begin
  try
    ForceDirectories(ExtractFilePath(IniPath));
    ini := TIniFile.Create(IniPath);
    try
      if AOn then ini.WriteString('Options', 'StabilityPack', '1')
      else ini.WriteString('Options', 'StabilityPack', '0');
    finally
      ini.Free;
    end;
  except
    // a read-only home folder: the pack lasts until you quit, which is the honest version
  end;
  NextCrash;
end;

procedure StabilityStart;
begin
  Randomize;
  mOffThisRun := HasParam('--stable', '/STABLE') or HasParam('--remote', '/REMOTE');
  NextCrash;
  if HasParam('--crashtest', '/CRASHTEST') then
  begin
    mOffThisRun := False;
    mDue := 10;
  end;
end;

function StabilityDue: Integer;
begin
  Result := mDue - mSeconds;
end;

function StabilityTick: Boolean;
begin
  Result := False;
  if mOffThisRun or StabilityPackInstalled then Exit;
  Inc(mSeconds);
  if mSeconds < mDue then Exit;
  NextCrash;
  Result := True;
end;

end.
