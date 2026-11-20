VERSION 5.00
Begin VB.Form frmFatal
   BackColor       =   &H00AA0000&
   BorderStyle     =   0  'None
   ClientHeight    =   7200
   ClientLeft      =   0
   ClientTop       =   0
   ClientWidth     =   9600
   ControlBox      =   0   'False
   KeyPreview      =   -1  'True
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ShowInTaskbar   =   0   'False
   WindowState     =   2  'Maximized
   Begin VB.PictureBox picScreen
      AutoRedraw      =   -1  'True
      BackColor       =   &H00AA0000&
      BorderStyle     =   0  'None
      Height          =   7200
      Left            =   0
      ScaleHeight     =   480
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   640
      TabIndex        =   0
      Top             =   0
      Width           =   9600
   End
End
Attribute VB_Name = "frmFatal"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' frmFatal - what dividing by zero looks like with Turbo on, and (new in
' 2000) what SolidCraft 2000 does every 15 minutes or so (modStability).
' It's a borderless blue window. Any key or click closes it; the part
' underneath was never touched.
Option Explicit

Public Scheduled As Boolean      ' the every-15-minutes crash, not a divide by zero

' The text on the screen, a line at a time ("|" between lines).
Private Function Message() As String
    If Scheduled Then
        Message = "A fatal exception 0E has occurred at 0028:C0FFEE00 in VXD FILLET(01) +|" & _
            "00002000. This was called from 0028:C0012000 in VXD SHEETMTL(03) +|" & _
            "00000D1V. It has been about fifteen minutes, so this was expected.|" & _
            "|" & _
            "Your part has not been terminated. Nothing was lost. It never is.|" & _
            "|" & _
            "*  Press any key to return to SolidCraft 2000.|" & _
            "*  To stop this happening, install the Stability Pack (Help menu)."
    Else
        Message = "A fatal exception 0E has occurred at 0028:SOLIDCRAFT+00000D1V0.|" & _
            "Something somewhere was divided by zero, which even a VB program|" & _
            "knows better than to do.|" & _
            "|" & _
            "The current part will not be terminated. It is fine. It was|" & _
            "never in any danger.|" & _
            "|" & _
            "*  Press any key to return to SolidCraft 2000.|" & _
            "*  Then type a number that isn't zero."
    End If
End Function

' What a screen reader says about it.
Public Function ReadOut() As String
    ReadOut = "The whole screen is blue: " & Replace(Replace(Message(), "|*  ", " "), "|", " ")
End Function

Private Sub Form_Load()
    picScreen.Move 0, 0, Screen.Width, Screen.Height
End Sub

Private Sub Form_Activate()
    Dim x As Single, y As Single, lh As Single, i As Integer, lines() As String
    Const WHITE As Long = &HFFFFFF
    Const GREY As Long = &HAAAAAA
    With picScreen
        .Cls
        .FontName = "Lucida Console"
        .FontSize = 14
        lh = .TextHeight("Xy") * 1.4
        lines = Split(Message(), "|")
        x = (.ScaleWidth - .TextWidth(lines(0))) / 2
        If x < 8 Then x = 8
        y = .ScaleHeight / 2 - lh * 7
        ' the title, grey on blue reversed, centred
        Dim t As String, tw As Single
        t = " SolidCraft "
        tw = .TextWidth(t)
        .Line ((.ScaleWidth - tw) / 2, y)-((.ScaleWidth + tw) / 2, y + lh * 0.8), GREY, BF
        TextAt picScreen, (.ScaleWidth - tw) / 2, y, t, &HAA0000
        y = y + lh * 2
        For i = 0 To UBound(lines)
            TextAt picScreen, x, y, lines(i), WHITE
            y = y + lh
        Next i
        y = y + lh
        t = "Press any key to continue _"
        TextAt picScreen, (.ScaleWidth - .TextWidth(t)) / 2, y, t, WHITE
        .Refresh
    End With
End Sub

Private Sub Form_KeyDown(KeyCode As Integer, Shift As Integer)
    Unload Me
End Sub

Private Sub Form_Unload(Cancel As Integer)
    Scheduled = False
End Sub

Private Sub picScreen_MouseDown(Button As Integer, Shift As Integer, X As Single, Y As Single)
    Unload Me
End Sub
