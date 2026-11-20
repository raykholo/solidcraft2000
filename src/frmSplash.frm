VERSION 5.00
Begin VB.Form frmSplash
   BorderStyle     =   0  'None
   ClientHeight    =   4200
   ClientLeft      =   0
   ClientTop       =   0
   ClientWidth     =   6600
   ControlBox      =   0   'False
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ShowInTaskbar   =   0   'False
   StartUpPosition =   2  'CenterScreen
   Begin VB.PictureBox picSplash
      AutoRedraw      =   -1  'True
      BorderStyle     =   0  'None
      Height          =   4200
      Left            =   0
      ScaleHeight     =   280
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   440
      TabIndex        =   0
      Top             =   0
      Width           =   6600
   End
End
Attribute VB_Name = "frmSplash"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' frmSplash - the startup splash, all of it drawn in code once it's on screen.
' The 2000 look: a grey-teal band across the top, the warm grey below, the
' box art's starburst, a Y2K sticker, and a little bar that slides along
' while it loads.
Option Explicit

Private Const BAND_H As Long = 116      ' the teal band
Private Const BAR_Y As Long = 116       ' the sliding bar, just under it
Private mBarPos As Long

Public Sub Paint()
    Dim p As PictureBox
    Set p = picSplash
    p.Line (0, 0)-(p.ScaleWidth, p.ScaleHeight), FACE_2000, BF
    GradientH p, 0, 0, p.ScaleWidth, BAND_H - 1, TEAL_DARK, TEAL_LIGHT
    DrawLogo2000 p, 62, 34, 15, vbWhite
    p.FontName = "Arial"
    p.FontBold = True
    p.FontItalic = False
    p.FontSize = 24
    SayAt p, 138, 14, "SolidCraft", vbWhite
    p.FontName = "Arial Black"
    p.FontSize = 34
    SayAt p, 136, 44, "2000", RGB(255, 236, 140)
    DrawStarburst p, 382, 50, 44, "NEW!", "Fillets!"
    DrawBar
    p.FontName = "Arial"
    p.FontBold = True
    p.FontSize = 10
    SayAt p, 18, 130, APP_EDITION, RGB(0, 56, 64)
    p.FontBold = False
    p.FontSize = 8
    SayAt p, 18, 148, "Built on 98 technology", RGB(64, 64, 64)
    SayAt p, 18, 236, AppVersion() & "  " & APP_BUILD, RGB(64, 64, 64)
    SayAt p, 18, 252, "Copyright (C) 1998-2000 SolidCraft Software. Made with Line and Circle.", RGB(64, 64, 64)
    DrawY2KBadge p, 392, 196, 32
    p.FontSize = 7
    SayAt p, 300, 266, "* tested until 19 January 2038", RGB(96, 96, 96)
    p.Line (0, 0)-(p.ScaleWidth - 1, p.ScaleHeight - 1), RGB(64, 64, 64), B
End Sub

' The thin bar under the band, with a lighter stretch that moves a step each
' time something loads. It means nothing; neither did the real ones.
Private Sub DrawBar()
    Dim p As PictureBox, x As Long, w As Long
    Set p = picSplash
    w = p.ScaleWidth
    GradientH p, 1, BAR_Y, w - 2, BAR_Y + 4, TEAL_LIGHT, TEAL_DARK
    x = (mBarPos * 37) Mod w
    GradientH p, x, BAR_Y, x + 60, BAR_Y + 4, RGB(255, 255, 255), TEAL_LIGHT
    mBarPos = mBarPos + 1
End Sub

Private Sub SayAt(ByVal p As PictureBox, ByVal x As Single, ByVal y As Single, ByVal s As String, ByVal c As Long)
    TextAt p, x, y, s, c
    p.Refresh
End Sub

' Shows a loading message and pauses just long enough to read it.
Public Sub Progress(ByVal s As String)
    Dim t As Single
    picSplash.FontName = "Arial"
    picSplash.FontBold = False
    picSplash.FontSize = 8
    picSplash.Line (14, 196)-(340, 212), FACE_2000, BF
    SayAt picSplash, 18, 197, s, RGB(0, 0, 0)
    DrawBar
    picSplash.Refresh
    t = Timer
    Do While Timer - t < 0.35 And Timer >= t
        DoEvents
    Loop
End Sub
