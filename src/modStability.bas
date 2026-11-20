Attribute VB_Name = "modStability"
' modStability - SolidCraft 2000 crashes on schedule. (Requested by brett19,
' who asked that "every 15 minutes or so, it blue screens".)
'
' Every 12 to 18 minutes of running, a blue screen covers everything. It's
' frmFatal, a borderless window: any key or click closes it, and nothing
' underneath is touched. The design, the undo list and the open dialogs are
' all exactly as they were.
'
' Help, Install Stability Pack turns it off, and is remembered (one setting
' under HKEY_CURRENT_USER\Software\VB and VBA Program Settings\SolidCraft 2000,
' where VB's SaveSetting puts it). It's off under the remote control and with
' /STABLE, so nothing driving the program or testing it gets a surprise.
Option Explicit

Private Const APP_KEY As String = "SolidCraft 2000"

Private mSeconds As Long         ' seconds since the last crash (or since starting)
Private mDue As Long             ' when the next one is due
Private mOffThisRun As Boolean   ' /STABLE or /REMOTE

Public Sub StabilityStart()
    Randomize
    mOffThisRun = InStr(UCase$(Command$), "/STABLE") > 0 Or InStr(UCase$(Command$), "/REMOTE") > 0
    NextCrash
    ' /CRASHTEST: the first one in 10 seconds, even under the remote control
    ' (but not if the Stability Pack is in), to see it without waiting
    If InStr(UCase$(Command$), "/CRASHTEST") > 0 Then
        mOffThisRun = False
        mDue = 10
    End If
End Sub

Private Sub NextCrash()
    mSeconds = 0
    mDue = 12 * 60 + Int(Rnd * 6 * 60)
End Sub

Public Function StabilityPackInstalled() As Boolean
    StabilityPackInstalled = (GetSetting(APP_KEY, "Options", "StabilityPack", "0") = "1")
End Function

' Called every second by the main window's clock.
Public Sub StabilityTick()
    If mOffThisRun Or StabilityPackInstalled() Then Exit Sub
    mSeconds = mSeconds + 1
    If mSeconds < mDue Then Exit Sub
    NextCrash
    If frmFatal.Visible Then Exit Sub
    frmFatal.Scheduled = True
    frmFatal.Show vbModal          ' modal: it has to be able to come up over a dialog
End Sub

' Help, Install Stability Pack (or Uninstall, once it's in).
Public Sub StabilityPackCommand()
    If StabilityPackInstalled() Then
        If MsgBox("Uninstall the Stability Pack?" & vbCrLf & vbCrLf & _
            "SolidCraft 2000 will go back to crashing every 15 minutes or so, as designed.", _
            vbQuestion Or vbYesNo, "Stability Pack") = vbNo Then Exit Sub
        SaveSetting APP_KEY, "Options", "StabilityPack", "0"
        NextCrash
        MsgBox "The Stability Pack has been uninstalled.", vbInformation, "Stability Pack"
    Else
        If MsgBox("The Stability Pack stops SolidCraft 2000 crashing every 15 minutes or so." & vbCrLf & vbCrLf & _
            "(The crashes never hurt your parts. They're only a blue picture.)" & vbCrLf & vbCrLf & _
            "Install the Stability Pack?", vbQuestion Or vbYesNo, "Stability Pack") = vbNo Then Exit Sub
        SaveSetting APP_KEY, "Options", "StabilityPack", "1"
        MsgBox "The Stability Pack has been installed." & vbCrLf & vbCrLf & _
            "SolidCraft 2000 will no longer crash on schedule.", vbInformation, "Stability Pack"
    End If
    frmMain.StabilityChanged
End Sub
