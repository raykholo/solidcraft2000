VERSION 5.00
Begin VB.Form frmUpgrade
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "SolidCraft 2000 Upgrade Wizard"
   ClientHeight    =   5400
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   7500
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Begin VB.Timer tmrCheck
      Enabled         =   0   'False
      Interval        =   120
      Left            =   120
      Top             =   4920
   End
   Begin VB.PictureBox picSide
      AutoRedraw      =   -1  'True
      BorderStyle     =   0  'None
      Height          =   4710
      Left            =   0
      ScaleHeight     =   314
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   164
      TabIndex        =   7
      TabStop         =   0   'False
      Top             =   0
      Width           =   2460
   End
   Begin VB.PictureBox picBar
      AutoRedraw      =   -1  'True
      BackColor       =   &H00FFFFFF&
      Height          =   300
      Left            =   2700
      ScaleHeight     =   16
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   300
      TabIndex        =   8
      TabStop         =   0   'False
      Top             =   4080
      Visible         =   0   'False
      Width           =   4560
   End
   Begin VB.OptionButton optA
      Caption         =   "A"
      Height          =   300
      Left            =   2820
      TabIndex        =   0
      Top             =   3240
      Visible         =   0   'False
      Width           =   4440
   End
   Begin VB.OptionButton optB
      Caption         =   "B"
      Height          =   300
      Left            =   2820
      TabIndex        =   1
      Top             =   3600
      Visible         =   0   'False
      Width           =   4440
   End
   Begin VB.CommandButton cmdBack
      Caption         =   "< &Back"
      Height          =   375
      Left            =   3480
      TabIndex        =   2
      Top             =   4920
      Width           =   1095
   End
   Begin VB.CommandButton cmdNext
      Caption         =   "&Next >"
      Default         =   -1  'True
      Height          =   375
      Left            =   4575
      TabIndex        =   3
      Top             =   4920
      Width           =   1095
   End
   Begin VB.CommandButton cmdCancel
      Cancel          =   -1  'True
      Caption         =   "Cancel"
      Height          =   375
      Left            =   6045
      TabIndex        =   4
      Top             =   4920
      Width           =   1095
   End
   Begin VB.Label lblTitle
      BackStyle       =   0  'Transparent
      BeginProperty Font
         Name            =   "Arial"
         Size            =   12
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   660
      Left            =   2700
      TabIndex        =   5
      Top             =   240
      Width           =   4560
   End
   Begin VB.Label lblBody
      BackStyle       =   0  'Transparent
      Height          =   2280
      Left            =   2700
      TabIndex        =   6
      Top             =   960
      Width           =   4560
   End
   Begin VB.Line linSep
      BorderColor     =   &H00808080&
      X1              =   0
      X2              =   7500
      Y1              =   4740
      Y2              =   4740
   End
End
Attribute VB_Name = "frmUpgrade"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' frmUpgrade - the Upgrade Wizard: Welcome, the licence, Upgrade or Clean
' install, a Year 2000 check, and Finish. Help, Upgrade from SolidCraft 98,
' or start SolidCraft2000.exe with /UPGRADE.
'
' Like every wizard of its day it asks a lot and does nothing much. This one
' does nothing at all: it reads no files, writes no files and changes no
' settings. SolidCraft 98 was one EXE and so is SolidCraft 2000; the upgrade
' that matters happens when you open an .sc98 part.
Option Explicit

Private Const LAST_PAGE As Integer = 4
Private mPage As Integer
Private mAccepted As Boolean
Private mClean As Boolean
Private mChecked As Integer      ' how far the Year 2000 check has got

Private Sub Form_Load()
    ClassicLook Me
    PaintSide
    mPage = 0
    ShowPage
End Sub

' The wizard picture down the left: teal, the logo, and the name.
Private Sub PaintSide()
    Dim p As PictureBox
    Set p = picSide
    Gradient p, TEAL_LIGHT, TEAL_DARK
    DrawLogo2000 p, 70, 70, 15, vbWhite
    p.FontName = "Arial"
    p.FontBold = True
    p.FontSize = 13
    TextAt p, 14, 170, "SolidCraft", vbWhite
    p.FontName = "Arial Black"
    p.FontSize = 20
    TextAt p, 14, 190, "2000", RGB(255, 236, 140)
    p.FontName = "Arial"
    p.FontBold = False
    p.FontSize = 8
    TextAt p, 14, 228, "Upgrade Wizard", vbWhite
    DrawY2KBadge p, 128, 278, 24
    p.Refresh
End Sub

Private Sub ShowPage()
    Dim sCRLF2 As String
    sCRLF2 = vbCrLf & vbCrLf
    optA.Visible = False: optB.Visible = False
    picBar.Visible = False
    cmdBack.Enabled = (mPage > 0)
    cmdNext.Caption = IIf(mPage = LAST_PAGE, "Finish", "&Next >")
    cmdNext.Enabled = True
    Select Case mPage
    Case 0
        lblTitle.Caption = "Welcome to the SolidCraft 2000 Upgrade Wizard"
        lblBody.Caption = "This wizard upgrades SolidCraft 98 to SolidCraft 2000." & sCRLF2 & _
            "New in SolidCraft 2000:" & vbCrLf & _
            "    - Fillets!" & vbCrLf & _
            "    - Personalized Menus, which hide what you don't use" & vbCrLf & _
            "    - Year 2000 compliance*" & vbCrLf & _
            "    - Sheet metal (some assembly required)" & sCRLF2 & _
            "To continue, click Next."
    Case 1
        lblTitle.Caption = "License Agreement"
        lblBody.Caption = "Please read the following license agreement." & sCRLF2 & _
            "SolidCraft 2000 is free software under the MIT License: you may use, copy, change and " & _
            "give away copies of it, as long as the copyright notice goes with them. It comes with no " & _
            "warranty of any kind, express, implied, or rounded." & sCRLF2 & _
            "Do you accept all the terms of the license agreement?"
        optA.Caption = "I &accept the agreement"
        optB.Caption = "I &do not accept the agreement"
        optA.Value = mAccepted
        optB.Value = Not mAccepted
        optA.Visible = True: optB.Visible = True
        cmdNext.Enabled = mAccepted
    Case 2
        lblTitle.Caption = "Choose Installation Type"
        lblBody.Caption = "How do you want to install SolidCraft 2000?" & sCRLF2 & _
            "Upgrade keeps your SolidCraft 98 parts and settings." & vbCrLf & _
            "Clean install starts fresh."
        optA.Caption = "&Upgrade (Recommended)"
        optB.Caption = "&Clean install"
        optA.Value = Not mClean
        optB.Value = mClean
        optA.Visible = True: optB.Visible = True
    Case 3
        lblTitle.Caption = "Checking for Year 2000 Compliance"
        picBar.Visible = True
        mChecked = 0
        cmdNext.Enabled = False
        cmdBack.Enabled = False
        CheckStep
        tmrCheck.Enabled = True
    Case 4
        lblTitle.Caption = "Completing the SolidCraft 2000 Upgrade Wizard"
        On Error Resume Next
        cmdNext.SetFocus
        On Error GoTo 0
        lblBody.Caption = "You have successfully " & IIf(mClean, "clean-installed", "upgraded to") & " SolidCraft 2000." & sCRLF2 & _
            IIf(mClean, "Your SolidCraft 98 parts were left exactly where they were. So was everything else. " & _
                "A clean install is the same as an upgrade, only cleaner." & sCRLF2, _
                "Settings copied from SolidCraft 98: 0 (it didn't have any)." & vbCrLf & _
                "Parts made in SolidCraft 98 are upgraded when you open them." & sCRLF2) & _
            "Nothing on this computer was changed. To close this wizard, click Finish."
    End Select
End Sub

' One line of the Year 2000 check per tick, and the bar.
Private Sub CheckStep()
    Dim s As String, w As Long
    Select Case mChecked
    Case 0: s = "Looking for two-digit years..."
    Case 1: s = "Looking for two-digit years... none found."
    Case 2: s = "Looking for two-digit years... none found." & vbCrLf & "Rolling the clock over to 1 January 2000... OK."
    Case 3: s = "Looking for two-digit years... none found." & vbCrLf & "Rolling the clock over to 1 January 2000... OK." & vbCrLf & _
                "Checking 29 February 2000 (it is a leap year)... OK."
    Case Else: s = "Looking for two-digit years... none found." & vbCrLf & "Rolling the clock over to 1 January 2000... OK." & vbCrLf & _
                "Checking 29 February 2000 (it is a leap year)... OK." & vbCrLf & vbCrLf & _
                "SolidCraft 2000 is Year 2000 compliant." & vbCrLf & _
                "* Tested until 19 January 2038. After that, you're on your own."
    End Select
    lblBody.Caption = s
    w = picBar.ScaleWidth * IIf(mChecked >= 4, 1, mChecked / 4)
    picBar.Cls
    picBar.Line (0, 0)-(w, picBar.ScaleHeight), TEAL_DARK, BF
    picBar.Refresh
End Sub

Private Sub tmrCheck_Timer()
    tmrCheck.Interval = 700
    mChecked = mChecked + 1
    CheckStep
    If mChecked >= 4 Then
        tmrCheck.Enabled = False
        cmdNext.Enabled = True
        cmdBack.Enabled = True
    End If
End Sub

Private Sub optA_Click()
    If mPage = 1 Then mAccepted = True: cmdNext.Enabled = True
    If mPage = 2 Then mClean = False
End Sub

Private Sub optB_Click()
    If mPage = 1 Then mAccepted = False: cmdNext.Enabled = False
    If mPage = 2 Then mClean = True
End Sub

Private Sub cmdBack_Click()
    If mPage > 0 Then mPage = mPage - 1
    If mPage = 3 Then mPage = 2          ' the check isn't worth doing twice
    ShowPage
End Sub

Private Sub cmdNext_Click()
    If mPage = LAST_PAGE Then
        Unload Me
        Exit Sub
    End If
    mPage = mPage + 1
    ShowPage
End Sub

Private Sub cmdCancel_Click()
    If MsgBox("Are you sure you want to cancel the upgrade?" & vbCrLf & vbCrLf & _
        "SolidCraft 2000 will keep working anyway.", vbQuestion Or vbYesNo, Caption) = vbYes Then Unload Me
End Sub

Private Sub Form_Unload(Cancel As Integer)
    tmrCheck.Enabled = False
End Sub
