Attribute VB_Name = "modMain"
' modMain - startup: splash, main window, an empty part.
Option Explicit

Sub Main()
    InitClock
    StabilityStart
    frmSplash.Show
    frmSplash.Paint
    frmSplash.Refresh
    Load frmMain
    frmSplash.Progress "Loading geometry kernel..."
    frmSplash.Progress "Registering MSCOMCTL.OCX..."
    frmSplash.Progress "Reticulating B-splines..."
    frmSplash.Progress "Rounding edges..."
    frmSplash.Progress "Hiding menu items you don't use..."
    frmSplash.Progress "Checking Year 2000 compliance..."
    frmMain.Show
    RunCommand "New"
    RemoteStart
    frmSplash.Progress "Ready."
    ' /SPLASH leaves the splash up for 15 seconds, for screenshots
    If InStr(UCase$(Command$), "/SPLASH") > 0 Then
        Dim t As Single
        frmSplash.ZOrder 0
        t = Timer
        Do While Timer - t < 15 And Timer >= t
            DoEvents
        Loop
    End If
    Unload frmSplash
    If InStr(UCase$(Command$), "/UPGRADE") > 0 Then RunCommand "Upgrade"
End Sub
