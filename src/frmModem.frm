VERSION 5.00
Begin VB.Form frmModem
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "Connect To SolidCraft Online"
   ClientHeight    =   2760
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   5640
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Begin VB.Timer tmrStep
      Enabled         =   0   'False
      Interval        =   100
      Left            =   240
      Top             =   2160
   End
   Begin VB.PictureBox picIcon
      AutoRedraw      =   -1  'True
      BorderStyle     =   0  'None
      Height          =   720
      Left            =   240
      ScaleHeight     =   48
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   72
      TabIndex        =   1
      TabStop         =   0   'False
      Top             =   240
      Width           =   1080
   End
   Begin VB.CommandButton cmdCancel
      Cancel          =   -1  'True
      Caption         =   "Cancel"
      Default         =   -1  'True
      Height          =   375
      Left            =   4320
      TabIndex        =   0
      Top             =   2220
      Width           =   1095
   End
   Begin VB.Label lblStatus
      Caption         =   "Dialing..."
      Height          =   495
      Left            =   1560
      TabIndex        =   2
      Top             =   300
      Width           =   3855
   End
   Begin VB.Label lblDetail
      Height          =   855
      Left            =   1560
      TabIndex        =   3
      Top             =   960
      Width           =   3855
   End
End
Attribute VB_Name = "frmModem"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' frmModem - Help, Check Online for Help. Dial-Up Networking, as it was:
' dial, answer, the screech, "Connected at 56,000 bps", and then the browser
' opens the README. Cancel hangs up at any point.
Option Explicit

Private mStart As Single
Private mStage As Integer
Private mDone As Single

Private Sub Form_Load()
    ClassicLook Me
    DrawIcon
    mStage = 0
    lblStatus.Caption = "Dialing " & MODEM_NUMBER & "..."
    lblDetail.Caption = "Dial-Up Networking" & vbCrLf & "Connection: SolidCraft Online Help" & vbCrLf & "Speaker volume: medium"
    ModemPlay
    mStart = Timer
    tmrStep.Enabled = True
End Sub

' Two computers and the telephone line between them.
Private Sub DrawIcon()
    Dim p As PictureBox
    Set p = picIcon
    p.Cls
    Pc p, 2, 8
    Pc p, 46, 8
    p.DrawStyle = 2
    p.Line (26, 30)-(46, 30), TEAL_DARK
    p.DrawStyle = 0
    p.Refresh
End Sub

Private Sub Pc(p As PictureBox, ByVal x As Long, ByVal y As Long)
    p.Line (x, y)-(x + 22, y + 16), vbBlack, B
    p.Line (x + 2, y + 2)-(x + 20, y + 14), TEAL_LIGHT, BF
    p.Line (x + 8, y + 17)-(x + 14, y + 20), &H808080, BF
    p.Line (x + 3, y + 21)-(x + 19, y + 25), &HC0C0C0, BF
    p.Line (x + 3, y + 21)-(x + 19, y + 25), vbBlack, B
End Sub

Private Function Elapsed() As Single
    Elapsed = Timer - mStart
    If Elapsed < 0 Then Elapsed = Elapsed + 86400
End Function

Private Sub tmrStep_Timer()
    Dim t As Single
    t = Elapsed()
    Select Case mStage
    Case 0
        If t >= ModemAnswerAt Then mStage = 1: lblStatus.Caption = "Verifying user name and password..."
    Case 1
        If t >= ModemTrainAt Then mStage = 2: lblStatus.Caption = "Logging on to network..."
    Case 2
        If t >= ModemLength Then
            mStage = 3
            lblStatus.Caption = "Connected at 56,000 bps."
            lblDetail.Caption = "(Actual speed: 28,800 bps. It was always 28,800 bps.)" & vbCrLf & vbCrLf & _
                "Opening SolidCraft Online Help..."
            mDone = t
        End If
    Case 3
        If t >= mDone + 2 Then
            tmrStep.Enabled = False
            OpenHelpPage
            Unload Me
        End If
    End Select
End Sub

Private Sub cmdCancel_Click()
    Unload Me
End Sub

Private Sub Form_Unload(Cancel As Integer)
    tmrStep.Enabled = False
    ModemStop
End Sub
