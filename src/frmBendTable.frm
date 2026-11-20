VERSION 5.00
Begin VB.Form frmBendTable
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "Bend Table Wizard"
   ClientHeight    =   5400
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   7500
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
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
   Begin VB.ListBox lstChoice
      Height          =   1815
      Left            =   2700
      TabIndex        =   0
      Top             =   2160
      Width           =   4560
   End
   Begin VB.CommandButton cmdAdvanced
      Caption         =   "&Advanced..."
      Height          =   375
      Left            =   2700
      TabIndex        =   1
      Top             =   4200
      Visible         =   0   'False
      Width           =   1335
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
      Height          =   1200
      Left            =   2700
      TabIndex        =   6
      Top             =   900
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
Attribute VB_Name = "frmBendTable"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
' frmBendTable - the Bend Table Wizard. Material, then thickness, then the
' bend radius and K-factor it suggests, with an Advanced... button that opens
' a dialog over the wizard, which opens a message box over that. Sheet metal
' in 2000 was like this.
'
' The numbers are rules of thumb (bend radius about the thickness, K-factor
' a little under a half), not a shop's real table. The result goes in
' SMTable... in modSheetMetal, for the next base flange.
Option Explicit

Private Const LAST_PAGE As Integer = 2
Private mPage As Integer
Private mMaterial As Integer
Private mGauge As Integer
Private mR As Double
Private mK As Double
Private mOk As Boolean

' Runs the wizard. True if it was finished, and the table is set.
Public Function Run() As Boolean
    mOk = False
    Show vbModal, frmMain
    Run = mOk
End Function

Private Sub Form_Load()
    ClassicLook Me
    Gradient picSide, TEAL_LIGHT, TEAL_DARK
    DrawLogo2000 picSide, 70, 70, 15, vbWhite
    picSide.FontName = "Arial"
    picSide.FontBold = True
    picSide.FontSize = 13
    TextAt picSide, 14, 170, "Bend Table", vbWhite
    TextAt picSide, 14, 192, "Wizard", vbWhite
    picSide.FontBold = False
    picSide.FontSize = 8
    TextAt picSide, 14, 228, "SolidCraft 2000 Sheet Metal", vbWhite
    picSide.Refresh
    mPage = 0
    mMaterial = 0
    mGauge = 2
    ShowPage
End Sub

Private Function MaterialName(ByVal m As Integer) As String
    Select Case m
    Case 0: MaterialName = "Mild steel"
    Case 1: MaterialName = "Aluminium 5052"
    Case 2: MaterialName = "Stainless steel 304"
    Case 3: MaterialName = "Copper"
    Case Else: MaterialName = "Cereal box (for prototypes)"
    End Select
End Function

' The thicknesses each material comes in, as the list shows them.
Private Function Gauges(ByVal m As Integer) As String
    Select Case m
    Case 0, 2: Gauges = "20 gauge (0.91 mm)|18 gauge (1.21 mm)|16 gauge (1.52 mm)|14 gauge (1.90 mm)|12 gauge (2.66 mm)"
    Case 1: Gauges = "0.8 mm|1.0 mm|1.6 mm|2.0 mm|3.0 mm"
    Case 3: Gauges = "0.5 mm|1.0 mm|1.5 mm|2.0 mm"
    Case Else: Gauges = "0.4 mm (one layer)|0.8 mm (two layers, glued)"
    End Select
End Function

' The thickness in a gauge's description: the number before " mm".
Private Function Thickness() As Double
    Dim s As String, p As Long, q As Long
    s = Split(Gauges(mMaterial), "|")(mGauge)
    q = InStr(s, " mm")
    p = q - 1
    Do While p > 1 And InStr("0123456789.", Mid$(s, p - 1, 1)) > 0
        p = p - 1
    Loop
    Thickness = Val(Mid$(s, p, q - p))
End Function

' The suggestion: bend radius and K-factor for the material and thickness.
Private Sub Suggest()
    Dim t As Double
    t = Thickness()
    Select Case mMaterial
    Case 0: mR = t: mK = 0.44
    Case 1: mR = t: mK = 0.43
    Case 2: mR = 1.5 * t: mK = 0.45
    Case 3: mR = t: mK = 0.42
    Case Else: mR = 0: mK = 0.5
    End Select
    mR = Int(mR * 100 + 0.5) / 100
End Sub

' "STEEL16.BTL": the table's 8.3 name, which nothing ever saves.
Private Function TableName() As String
    Dim p As String
    Select Case mMaterial
    Case 0: p = "STEEL"
    Case 1: p = "ALUM"
    Case 2: p = "SS304"
    Case 3: p = "COPPER"
    Case Else: p = "CEREAL"
    End Select
    TableName = p & Format$(mGauge + 1, "00") & ".BTL"
End Function

Private Sub ShowPage()
    Dim g() As String, i As Integer
    cmdBack.Enabled = (mPage > 0)
    cmdNext.Caption = IIf(mPage = LAST_PAGE, "Finish", "&Next >")
    cmdAdvanced.Visible = (mPage = LAST_PAGE)
    lstChoice.Visible = (mPage < LAST_PAGE)
    lstChoice.Clear
    Select Case mPage
    Case 0
        lblTitle.Caption = "Step 1 of 3: Material"
        lblBody.Caption = "This wizard creates a bend table for your sheet metal parts." & vbCrLf & vbCrLf & _
            "What material are your parts made of?"
        For i = 0 To 4
            lstChoice.AddItem MaterialName(i)
        Next i
        lstChoice.ListIndex = mMaterial
    Case 1
        lblTitle.Caption = "Step 2 of 3: Thickness"
        lblBody.Caption = "What thickness of " & LCase$(MaterialName(mMaterial)) & " will you use?" & vbCrLf & vbCrLf & _
            "(Every part made with this table is this thick. To change it, run the wizard again.)"
        g = Split(Gauges(mMaterial), "|")
        For i = 0 To UBound(g)
            lstChoice.AddItem g(i)
        Next i
        If mGauge > UBound(g) Then mGauge = UBound(g)
        lstChoice.ListIndex = mGauge
    Case 2
        Suggest
        ShowSummary
    End Select
End Sub

Private Sub ShowSummary()
    lblTitle.Caption = "Step 3 of 3: Bend Radius and K-Factor"
    lblBody.Caption = "Bend table: " & TableName() & vbCrLf & vbCrLf & _
        "    Material:  " & MaterialName(mMaterial) & vbCrLf & _
        "    Thickness:  " & Thickness() & " mm" & vbCrLf & _
        "    Inside bend radius:  " & mR & " mm" & vbCrLf & _
        "    K-factor:  " & Format$(mK, "0.00") & vbCrLf & vbCrLf & _
        "To change these, click Advanced. To create the table, click Finish."
End Sub

' A dialog over the wizard, for the two numbers nobody should change.
Private Sub cmdAdvanced_Click()
    If Not frmParams.Ask("Advanced Bend Table Options", "Inside bend radius (mm)|K-factor (0 to 1)", _
        CStr(mR) & "|" & CStr(mK)) Then Exit Sub
    If frmParams.Value(0) < 0 Or frmParams.Value(1) < 0 Or frmParams.Value(1) > 1 Then
        MsgBox "The bend radius must be zero or more, and the K-factor between 0 and 1.", vbExclamation, Caption
        Exit Sub
    End If
    If frmParams.Value(1) <> mK Then
        If MsgBox("Changing the K-factor changes the size of every flat pattern made with this table." & vbCrLf & vbCrLf & _
            "Are you sure you want to change the K-factor?", vbExclamation Or vbYesNo Or vbDefaultButton2, Caption) = vbNo Then Exit Sub
    End If
    mR = frmParams.Value(0)
    mK = frmParams.Value(1)
    ShowSummary
End Sub

Private Sub lstChoice_Click()
    If mPage = 0 Then mMaterial = lstChoice.ListIndex
    If mPage = 1 Then mGauge = lstChoice.ListIndex
End Sub

Private Sub lstChoice_DblClick()
    cmdNext_Click
End Sub

Private Sub cmdBack_Click()
    If mPage > 0 Then mPage = mPage - 1
    ShowPage
End Sub

Private Sub cmdNext_Click()
    If mPage = 0 Then mGauge = 2
    If mPage = LAST_PAGE Then
        SMTableSet = True
        SMTableName = TableName()
        SMTableT = Thickness()
        SMTableR = mR
        SMTableK = mK
        mOk = True
        Unload Me
        Exit Sub
    End If
    mPage = mPage + 1
    ShowPage
End Sub

Private Sub cmdCancel_Click()
    If MsgBox("Are you sure you want to cancel the Bend Table Wizard?" & vbCrLf & vbCrLf & _
        "Sheet metal parts need a bend table.", vbQuestion Or vbYesNo, Caption) = vbYes Then Unload Me
End Sub
