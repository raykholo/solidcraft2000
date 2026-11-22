{ SolidCraft 2000, the Delphi Edition. Startup: splash, main window, an empty
  part (or the parts named on the command line). }
program SolidCraft2000;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, SysUtils,
  uModel, uDocs, uStability, fDialogs, fMain, uCommands;

{$R *.res}

type
  TCrash = class
    { Anything unexpected: where it happened goes to the console, then the
      usual message box. }
    procedure Report(Sender: TObject; E: Exception);
  end;

procedure TCrash.Report(Sender: TObject; E: Exception);
begin
  WriteLn(StdErr, 'Unhandled ', E.ClassName, ': ', E.Message);
  DumpExceptionBackTrace(StdErr);
  Application.ShowException(E);
end;

var
  splash: TForm;
  i, opened: Integer;
  a: string;

begin
  RequireDerivedFormResource := False;
  Application.Title := 'SolidCraft 2000';
  Application.Scaled := False;
  Application.Initialize;
  Application.OnException := @TCrash(nil).Report;
  InitClock;
  StabilityStart;
  splash := ShowSplash;
  Application.CreateForm(TMainForm, MainForm);
  SplashProgress(splash, 'Loading geometry kernel...');
  SplashProgress(splash, 'Registering MSCOMCTL.OCX...');
  SplashProgress(splash, 'Reticulating B-splines...');
  MainForm.Show;
  opened := 0;
  for i := 1 to ParamCount do
  begin
    a := ParamStr(i);
    if (a <> '') and (a[1] <> '-') and FileExists(a) then
    begin
      RunCommand('Open:' + a);
      Inc(opened);
    end;
  end;
  if opened = 0 then RunCommand('New');
  SplashProgress(splash, 'Ready.');
  splash.Free;
  Application.Run;
end.
