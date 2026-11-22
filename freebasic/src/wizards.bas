' wizards.bas - the Upgrade Wizard (Help, Upgrade from SolidCraft 98), the
' Bend Table Wizard (Sheet Metal), and the Stability Pack. Ports of the
' Windows version's frmUpgrade, frmBendTable and modStability.
'
' Like every wizard of its day they ask a lot and do nothing much. The
' Upgrade Wizard does nothing at all: it reads no files, writes no files and
' changes no settings. The upgrade that matters happens when you open an
' .sc98 part.

Const WZ_W = 500, WZ_H = 360

' control numbers in a wizard's dialog
Const WZ_TITLE = 0, WZ_BODY = 1, WZ_A = 2, WZ_B = 3, WZ_LIST = 4, WZ_ADV = 5, WZ_BACK = 6, WZ_NEXT = 7, WZ_CANCEL = 8

Dim Shared WzKind As Long            ' 1 the upgrade wizard, 2 the bend table wizard
Dim Shared WzPage As Long
Dim Shared WzBar As Boolean          ' show the progress bar
Dim Shared WzBarPct As Long

' "word wrap" to a width in pixels, on top of the line breaks already in it
Function WrapText(ByRef t As String, ByVal maxw As Long) As String
    Dim As String r, rest = t & Chr(10), ln, cur, word
    Do While Len(rest)
        Dim As Long p = InStr(rest, Chr(10))
        ln = Left(rest, p - 1): rest = Mid(rest, p + 1)
        cur = ""
        Dim As String w = ln & " "
        Do While Len(w)
            Dim As Long q = InStr(w, " ")
            word = Left(w, q - 1): w = Mid(w, q + 1)
            If Len(cur) = 0 Then
                cur = word
            ElseIf TextW(cur & " " & word) <= maxw Then
                cur &= " " & word
            Else
                r &= cur & Chr(10): cur = word
            End If
        Loop
        r &= cur & Chr(10)
    Loop
    Return Left(r, Len(r) - 1)
End Function

Sub WizardDraw(ByVal dp As Any Ptr)
    Dim As TDlg Ptr d = dp
    Dim As Long ox = ClientX(*d), oy = ClientY(*d)
    GradientV ox, oy, 164, 314, TEAL_LIGHT, TEAL_DARK
    DrawLogo ox + 74, oy + 82, 15, &hFFFFFFFF
    If WzKind = 1 Then
        TextAt ox + 14, oy + 170, "SolidCraft", &hFFFFFFFF, True
        TextAt ox + 14, oy + 190, "2000", &hFFFFEC8C, True, 2
        TextAt ox + 14, oy + 228, "Upgrade Wizard", &hFFFFFFFF
        DrawY2KBadge ox + 128, oy + 278, 22
    Else
        TextAt ox + 14, oy + 170, "Bend Table", &hFFFFFFFF, True
        TextAt ox + 14, oy + 186, "Wizard", &hFFFFFFFF, True
        TextAt ox + 14, oy + 228, "SolidCraft 2000", &hFFFFFFFF
        TextAt ox + 14, oy + 241, "Sheet Metal", &hFFFFFFFF
    End If
    HLine ox, oy + 314, WZ_W, C_SHADOW
    HLine ox, oy + 315, WZ_W, C_HILITE
    If WzBar Then
        Bevel ox + 180, oy + 272, 304, 18, BEV_SUNKEN
        Fill ox + 182, oy + 274, 300, 14, C_WINDOW
        Fill ox + 182, oy + 274, 300 * WzBarPct \ 100, 14, TEAL_DARK
    End If
End Sub

' The frame every wizard shares: the title, the body, two option buttons, a
' list, Advanced..., and Back, Next and Cancel.
Sub WizardFrame(ByRef d As TDlg, ByRef sCaption As String)
    Dim As Long i
    d.title = sCaption
    d.w = WZ_W + 6: d.h = WZ_H + 3 + DLG_TITLE_H + 1 + 3
    CenterDialog d
    i = AddCtl(d, CT_LABEL, 180, 16, 304, 40, ""): d.c(i).bold = True                    ' WZ_TITLE
    AddCtl d, CT_LABEL, 180, 64, 304, 150, ""                                            ' WZ_BODY
    i = AddCtl(d, CT_RADIO, 180, 216, 304, 16, ""): d.c(i).hidden = True                 ' WZ_A
    i = AddCtl(d, CT_RADIO, 180, 240, 304, 16, ""): d.c(i).hidden = True                 ' WZ_B
    i = AddCtl(d, CT_LIST, 180, 144, 304, 122): d.c(i).hidden = True: d.c(i).plain = True   ' WZ_LIST
    i = AddCtl(d, CT_BUTTON, 180, 280, 100, 25, "&Advanced..."): d.c(i).hidden = True    ' WZ_ADV
    AddCtl d, CT_BUTTON, 232, 328, 73, 25, "< &Back"                                     ' WZ_BACK
    i = AddCtl(d, CT_BUTTON, 305, 328, 73, 25, "&Next >"): d.c(i).isDefault = True       ' WZ_NEXT
    i = AddCtl(d, CT_BUTTON, 403, 328, 73, 25, "Cancel"): d.c(i).isCancel = True         ' WZ_CANCEL
    d.focus = WZ_NEXT
    d.drawFn = @WizardDraw
End Sub

' ---- the Upgrade Wizard ----

Const UP_LAST = 4
Dim Shared UpAccepted As Boolean
Dim Shared UpClean As Boolean
Dim Shared UpChecked As Long            ' how far the Year 2000 check has got
Dim Shared UpNextTick As Double

Sub UpgradeCheckStep(ByVal d As TDlg Ptr)
    Dim As String s
    Select Case UpChecked
    Case 0: s = "Looking for two-digit years..."
    Case 1: s = "Looking for two-digit years... none found."
    Case 2: s = "Looking for two-digit years... none found." & Chr(10) & "Rolling the clock over to 1 January 2000... OK."
    Case 3: s = "Looking for two-digit years... none found." & Chr(10) & "Rolling the clock over to 1 January 2000... OK." & Chr(10) & _
                "Checking 29 February 2000 (it is a leap year)... OK."
    Case Else: s = "Looking for two-digit years... none found." & Chr(10) & "Rolling the clock over to 1 January 2000... OK." & Chr(10) & _
                "Checking 29 February 2000 (it is a leap year)... OK." & Chr(10) & Chr(10) & _
                "SolidCraft 2000 is Year 2000 compliant." & Chr(10) & _
                "* Tested until 19 January 2038. After that, you're on your own."
    End Select
    d->c(WZ_BODY).text = WrapText(s, 300)
    WzBarPct = IIf(UpChecked >= 4, 100, UpChecked * 25)
End Sub

Sub UpgradeShowPage(ByVal d As TDlg Ptr)
    Dim As String s
    With *d
        .c(WZ_A).hidden = True: .c(WZ_B).hidden = True
        WzBar = False
        .c(WZ_BACK).disabled = (WzPage = 0)
        .c(WZ_NEXT).text = IIf(WzPage = UP_LAST, "Finish", "&Next >")
        .c(WZ_NEXT).disabled = False
        Select Case WzPage
        Case 0
            .c(WZ_TITLE).text = WrapText("Welcome to the SolidCraft 2000 Upgrade Wizard", 300)
            s = "This wizard upgrades SolidCraft 98 to SolidCraft 2000." & Chr(10) & Chr(10) & _
                "New in SolidCraft 2000:" & Chr(10) & _
                "    - Fillets!" & Chr(10) & _
                "    - Personalized Menus, which hide what you don't use" & Chr(10) & _
                "    - Year 2000 compliance*" & Chr(10) & _
                "    - Sheet metal (some assembly required)" & Chr(10) & Chr(10) & _
                "To continue, click Next."
            .c(WZ_BODY).text = WrapText(s, 300)
        Case 1
            .c(WZ_TITLE).text = "License Agreement"
            s = "Please read the following license agreement." & Chr(10) & Chr(10) & _
                "SolidCraft 2000 is free software under the MIT License: you may use, copy, change and " & _
                "give away copies of it, as long as the copyright notice goes with them. It comes with no " & _
                "warranty of any kind, express, implied, or rounded." & Chr(10) & Chr(10) & _
                "Do you accept all the terms of the license agreement?"
            .c(WZ_BODY).text = WrapText(s, 300)
            .c(WZ_A).text = "I &accept the agreement": .c(WZ_B).text = "I &do not accept the agreement"
            .c(WZ_A).checked = UpAccepted: .c(WZ_B).checked = Not UpAccepted
            .c(WZ_A).hidden = False: .c(WZ_B).hidden = False
            .c(WZ_NEXT).disabled = Not UpAccepted
        Case 2
            .c(WZ_TITLE).text = "Choose Installation Type"
            s = "How do you want to install SolidCraft 2000?" & Chr(10) & Chr(10) & _
                "Upgrade keeps your SolidCraft 98 parts and settings." & Chr(10) & _
                "Clean install starts fresh."
            .c(WZ_BODY).text = WrapText(s, 300)
            .c(WZ_A).text = "&Upgrade (Recommended)": .c(WZ_B).text = "&Clean install"
            .c(WZ_A).checked = Not UpClean: .c(WZ_B).checked = UpClean
            .c(WZ_A).hidden = False: .c(WZ_B).hidden = False
        Case 3
            .c(WZ_TITLE).text = WrapText("Checking for Year 2000 Compliance", 300)
            WzBar = True
            UpChecked = 0
            .c(WZ_NEXT).disabled = True
            .c(WZ_BACK).disabled = True
            UpgradeCheckStep d
            UpNextTick = Timer + 0.12
        Case 4
            .c(WZ_TITLE).text = WrapText("Completing the SolidCraft 2000 Upgrade Wizard", 300)
            s = "You have successfully " & IIf(UpClean, "clean-installed", "upgraded to") & " SolidCraft 2000." & Chr(10) & Chr(10)
            If UpClean Then
                s &= "Your SolidCraft 98 parts were left exactly where they were. So was everything else. " & _
                    "A clean install is the same as an upgrade, only cleaner." & Chr(10) & Chr(10)
            Else
                s &= "Settings copied from SolidCraft 98: 0 (it didn't have any)." & Chr(10) & _
                    "Parts made in SolidCraft 98 are upgraded when you open them." & Chr(10) & Chr(10)
            End If
            s &= "Nothing on this computer was changed. To close this wizard, click Finish."
            .c(WZ_BODY).text = WrapText(s, 300)
            .focus = WZ_NEXT
        End Select
        .c(WZ_ADV).hidden = True
        .c(WZ_LIST).hidden = True
    End With
End Sub

' One line of the Year 2000 check every so often, and the bar.
Sub UpgradeTick(ByVal dp As Any Ptr)
    Dim As TDlg Ptr d = dp
    If WzPage <> 3 Or UpChecked >= 4 Then Exit Sub
    If Timer < UpNextTick Then Exit Sub
    UpChecked += 1
    UpNextTick = Timer + 0.7
    UpgradeCheckStep d
    If UpChecked >= 4 Then
        d->c(WZ_NEXT).disabled = False
        d->c(WZ_BACK).disabled = False
        d->focus = WZ_NEXT
    End If
End Sub

Function UpgradeClick(ByVal dp As Any Ptr, ByVal ci As Long) As Boolean
    Dim As TDlg Ptr d = dp
    Select Case ci
    Case WZ_A
        If WzPage = 1 Then UpAccepted = True
        If WzPage = 2 Then UpClean = False
        UpgradeShowPage d
    Case WZ_B
        If WzPage = 1 Then UpAccepted = False
        If WzPage = 2 Then UpClean = True
        UpgradeShowPage d
    Case WZ_BACK
        If WzPage > 0 Then WzPage -= 1
        If WzPage = 3 Then WzPage = 2          ' the check isn't worth doing twice
        UpgradeShowPage d
    Case WZ_NEXT
        If WzPage = UP_LAST Then d->result = IDOK: Return True
        WzPage += 1
        UpgradeShowPage d
    Case WZ_CANCEL
        If MsgBox("Are you sure you want to cancel the upgrade?" & Chr(10) & Chr(10) & _
            "SolidCraft 2000 will keep working anyway.", MB_QUESTION Or MB_YESNO, d->title) = IDYES Then d->result = IDCANCEL: Return True
    End Select
    Return False
End Function

Function UpgradeKey(ByVal dp As Any Ptr, ByRef ev As UIEvent) As Boolean
    Dim As TDlg Ptr d = dp
    If d->c(WZ_A).hidden Then Return False
    If ev.key = K_UP Or ev.key = K_DOWN Then
        UpgradeClick d, IIf(d->c(WZ_A).checked, WZ_B, WZ_A)
        Return True
    End If
    If ev.alt And Len(ev.ch) Then
        Dim As Long k
        For k = WZ_A To WZ_B
            Dim As Long p = InStr(d->c(k).text, "&")
            If p AndAlso UCase(Mid(d->c(k).text, p + 1, 1)) = UCase(ev.ch) Then UpgradeClick d, k: Return True
        Next
    End If
    Return False
End Function

Function WizardReadOut(ByVal dp As Any Ptr) As String
    Dim As TDlg Ptr d = dp
    Return "A wizard: a teal picture down the left, with the SolidCraft 2000 logo, and the page on the right. " & _
        "Back, Next and Cancel along the bottom."
End Function

Sub ShowUpgrade()
    Dim d As TDlg
    WizardFrame d, "SolidCraft 2000 Upgrade Wizard"
    WzKind = 1: WzPage = 0: UpAccepted = False: UpClean = False
    d.clickFn = @UpgradeClick
    d.tickFn = @UpgradeTick
    d.keyFn = @UpgradeKey
    d.readOutFn = @WizardReadOut
    UpgradeShowPage @d
    LogLine "upgrade wizard"
    RunDialog d
    WzBar = False
End Sub

' ---- the Bend Table Wizard ----
'
' Material, then thickness, then the bend radius and K-factor it suggests,
' with an Advanced... button that opens a dialog over the wizard, which opens
' a message box over that. Sheet metal in 2000 was like this. The numbers
' are rules of thumb (bend radius about the thickness, K-factor a little
' under a half), not a shop's real table.

Const BT_LAST = 2
Dim Shared BtMaterial As Long
Dim Shared BtGauge As Long
Dim Shared BtR As Double
Dim Shared BtK As Double
Dim Shared BtOk As Boolean

Function MaterialName(ByVal m As Long) As String
    Select Case m
    Case 0: Return "Mild steel"
    Case 1: Return "Aluminium 5052"
    Case 2: Return "Stainless steel 304"
    Case 3: Return "Copper"
    End Select
    Return "Cereal box (for prototypes)"
End Function

' The thicknesses each material comes in, as the list shows them.
Function Gauges(ByVal m As Long) As String
    Select Case m
    Case 0, 2: Return "20 gauge (0.91 mm)|18 gauge (1.21 mm)|16 gauge (1.52 mm)|14 gauge (1.90 mm)|12 gauge (2.66 mm)"
    Case 1: Return "0.8 mm|1.0 mm|1.6 mm|2.0 mm|3.0 mm"
    Case 3: Return "0.5 mm|1.0 mm|1.5 mm|2.0 mm"
    End Select
    Return "0.4 mm (one layer)|0.8 mm (two layers, glued)"
End Function

' Item k (from 0) of a "|" list.
Function ListItem(ByRef s As String, ByVal k As Long) As String
    Dim As String rest = s & "|"
    Dim As Long n
    Do While Len(rest)
        Dim As Long p = InStr(rest, "|")
        If n = k Then Return Left(rest, p - 1)
        rest = Mid(rest, p + 1): n += 1
    Loop
    Return ""
End Function

Function ListItems(ByRef s As String) As Long
    Dim As Long n = 1, i
    For i = 0 To Len(s) - 1
        If s[i] = Asc("|") Then n += 1
    Next
    Return n
End Function

' The thickness in a gauge's description: the number before " mm".
Function Thickness() As Double
    Dim As String s = ListItem(Gauges(BtMaterial), BtGauge)
    Dim As Long q = InStr(s, " mm"), p = q - 1
    Do While p > 1 AndAlso InStr("0123456789.", Mid(s, p - 1, 1)) > 0
        p -= 1
    Loop
    Return Val(Mid(s, p, q - p))
End Function

' The suggestion: bend radius and K-factor for the material and thickness.
Sub Suggest()
    Dim As Double t = Thickness()
    Select Case BtMaterial
    Case 0: BtR = t: BtK = 0.44
    Case 1: BtR = t: BtK = 0.43
    Case 2: BtR = 1.5 * t: BtK = 0.45
    Case 3: BtR = t: BtK = 0.42
    Case Else: BtR = 0: BtK = 0.5
    End Select
    BtR = Int(BtR * 100 + 0.5) / 100
End Sub

' "STEEL16.BTL": the table's 8.3 name, which nothing ever saves.
Function TableName() As String
    Dim As String p
    Select Case BtMaterial
    Case 0: p = "STEEL"
    Case 1: p = "ALUM"
    Case 2: p = "SS304"
    Case 3: p = "COPPER"
    Case Else: p = "CEREAL"
    End Select
    Return p & Format(BtGauge + 1, "00") & ".BTL"
End Function

Sub BendSummary(ByVal d As TDlg Ptr)
    d->c(WZ_TITLE).text = WrapText("Step 3 of 3: Bend Radius and K-Factor", 300)
    d->c(WZ_BODY).text = "Bend table: " & TableName() & Chr(10) & Chr(10) & _
        "    Material:  " & MaterialName(BtMaterial) & Chr(10) & _
        "    Thickness:  " & Fmt0(Thickness()) & " mm" & Chr(10) & _
        "    Inside bend radius:  " & Fmt0(BtR) & " mm" & Chr(10) & _
        "    K-factor:  " & Format(BtK, "0.00") & Chr(10) & Chr(10) & _
        "To change these, click Advanced." & Chr(10) & "To create the table, click Finish."
End Sub

Sub BendShowPage(ByVal d As TDlg Ptr)
    Dim As Long i, n
    With *d
        .c(WZ_BACK).disabled = (WzPage = 0)
        .c(WZ_NEXT).text = IIf(WzPage = BT_LAST, "Finish", "&Next >")
        .c(WZ_ADV).hidden = (WzPage <> BT_LAST)
        .c(WZ_LIST).hidden = (WzPage = BT_LAST)
        .c(WZ_A).hidden = True: .c(WZ_B).hidden = True
        Select Case WzPage
        Case 0
            .c(WZ_TITLE).text = "Step 1 of 3: Material"
            .c(WZ_BODY).text = WrapText("This wizard creates a bend table for your sheet metal parts." & Chr(10) & Chr(10) & "What material are your parts made of?", 300)
            ListCount = 5
            ReDim ListRows(0 To 7)
            For i = 0 To 4: ListRows(i) = "F" & MaterialName(i): Next
            .c(WZ_LIST).sel = BtMaterial: .c(WZ_LIST).top = 0
        Case 1
            .c(WZ_TITLE).text = "Step 2 of 3: Thickness"
            .c(WZ_BODY).text = WrapText("What thickness of " & LCase(MaterialName(BtMaterial)) & " will you use?" & Chr(10) & Chr(10) & _
                "(Every part made with this table is this thick. To change it, run the wizard again.)", 300)
            n = ListItems(Gauges(BtMaterial))
            ListCount = n
            ReDim ListRows(0 To n)
            For i = 0 To n - 1: ListRows(i) = "F" & ListItem(Gauges(BtMaterial), i): Next
            If BtGauge > n - 1 Then BtGauge = n - 1
            .c(WZ_LIST).sel = BtGauge: .c(WZ_LIST).top = 0
        Case 2
            Suggest
            BendSummary d
        End Select
        .focus = IIf(WzPage < BT_LAST, WZ_LIST, WZ_NEXT)
    End With
End Sub

' A dialog over the wizard, for the two numbers nobody should change.
Sub BendAdvanced(ByVal d As TDlg Ptr)
    If Not AskParams("Advanced Bend Table Options", "Inside bend radius (mm)|K-factor (0 to 1)", Fmt0(BtR) & "|" & Fmt0(BtK)) Then Exit Sub
    If ParamValue(0) < 0 Or ParamValue(1) < 0 Or ParamValue(1) > 1 Then
        MsgBox "The bend radius must be zero or more, and the K-factor between 0 and 1.", MB_EXCLAMATION, d->title
        Exit Sub
    End If
    If ParamValue(1) <> BtK Then
        If MsgBox("Changing the K-factor changes the size of every flat pattern made with this table." & Chr(10) & Chr(10) & _
            "Are you sure you want to change the K-factor?", MB_EXCLAMATION Or MB_YESNO Or MB_DEFBUTTON2, d->title) = IDNO Then Exit Sub
    End If
    BtR = ParamValue(0)
    BtK = ParamValue(1)
    BendSummary d
End Sub

Function BendClick(ByVal dp As Any Ptr, ByVal ci As Long) As Boolean
    Dim As TDlg Ptr d = dp
    Select Case ci
    Case WZ_LIST
        If WzPage = 0 Then BtMaterial = d->c(WZ_LIST).sel
        If WzPage = 1 Then BtGauge = d->c(WZ_LIST).sel
        If d->c(WZ_LIST).tag = 2 Then Return BendClick(dp, WZ_NEXT)      ' a double-click is Next
    Case WZ_ADV
        BendAdvanced d
    Case WZ_BACK
        If WzPage > 0 Then WzPage -= 1
        BendShowPage d
    Case WZ_NEXT
        If WzPage = 0 Then BtGauge = 2
        If WzPage = BT_LAST Then
            SMTableSet = True
            SMTableName = TableName()
            SMTableT = Thickness()
            SMTableR = BtR
            SMTableK = BtK
            BtOk = True
            d->result = IDOK
            Return True
        End If
        WzPage += 1
        BendShowPage d
    Case WZ_CANCEL
        If MsgBox("Are you sure you want to cancel the Bend Table Wizard?" & Chr(10) & Chr(10) & _
            "Sheet metal parts need a bend table.", MB_QUESTION Or MB_YESNO, d->title) = IDYES Then d->result = IDCANCEL: Return True
    End Select
    Return False
End Function

' Runs the wizard. True if it was finished, and the table is set.
Function RunBendTable() As Boolean
    Dim d As TDlg
    WizardFrame d, "Bend Table Wizard"
    WzKind = 2: WzPage = 0: BtMaterial = 0: BtGauge = 2: BtOk = False
    d.clickFn = @BendClick
    d.readOutFn = @WizardReadOut
    BendShowPage @d
    LogLine "bend table wizard"
    RunDialog d
    Return BtOk
End Function

' ---- the Stability Pack (modStability) ----
'
' SolidCraft 2000 crashes on schedule. (Requested by brett19, who asked that
' "every 15 minutes or so, it blue screens".) Every 12 to 18 minutes of
' running, a blue screen covers everything. It's a borderless window: any
' key or click closes it, and nothing underneath is touched. The design, the
' undo list and the open dialogs are all exactly as they were.
'
' Help, Install Stability Pack turns it off, and is remembered (one setting,
' in ~/.config/solidcraft2000, where the Windows version uses the registry).
' It's off under the remote control and with --stable, so nothing driving the
' program or testing it gets a surprise.

Dim Shared StabSeconds As Double       ' seconds since the last crash (or since starting)
Dim Shared StabDue As Double           ' when the next one is due
Dim Shared StabOff As Boolean          ' --stable or --remote
Dim Shared StabLast As Double

Function StabilityFile() As String
    Return JoinPath(JoinPath(JoinPath(HomeDir(), ".config"), "solidcraft2000"), "stability-pack")
End Function

Function StabilityPackInstalled() As Boolean
    Dim As Long fh = FreeFile
    Dim As String l
    If Open(StabilityFile() For Input As #fh) <> 0 Then Return False
    Line Input #fh, l
    Close #fh
    Return Trim(l) = "1"
End Function

Sub SetStabilityPack(ByVal bOn As Boolean)
    Dim As Long fh = FreeFile
    MkDir JoinPath(HomeDir(), ".config")
    MkDir JoinPath(JoinPath(HomeDir(), ".config"), "solidcraft2000")
    If Open(StabilityFile() For Output As #fh) = 0 Then
        Print #fh, IIf(bOn, "1", "0")
        Close #fh
    End If
End Sub

Sub NextCrash()
    StabSeconds = 0
    StabDue = 12 * 60 + Int(Rnd * 6 * 60)
End Sub

Sub StabilityStart()
    Dim As Long i = 1
    Dim As String a
    Randomize
    NextCrash
    StabLast = Timer
    StabOff = RemoteMode
    Do While Len(Command(i))
        a = UCase(Command(i))
        If a = "--STABLE" Or a = "/STABLE" Then StabOff = True
        i += 1
    Loop
    ' --crashtest: the first one in 10 seconds, even under the remote control
    ' (but not if the Stability Pack is in), to see it without waiting
    i = 1
    Do While Len(Command(i))
        a = UCase(Command(i))
        If a = "--CRASHTEST" Or a = "/CRASHTEST" Then StabOff = False: StabDue = 10
        i += 1
    Loop
End Sub

' Called all the time by the main loop; counts real seconds.
Sub StabilityTick()
    Dim As Double t = Timer
    Dim As Double dt = t - StabLast
    StabLast = t
    If dt < 0 Or dt > 5 Then dt = 0
    If StabOff Then Exit Sub
    StabSeconds += dt
    If StabSeconds < StabDue Then Exit Sub
    If StabilityPackInstalled() Then Exit Sub
    NextCrash
    If FatalOpen Then Exit Sub
    FatalScheduled = True
    ShowFatal
End Sub

' Help, Install Stability Pack (or Uninstall, once it's in).
Sub StabilityPackCommand()
    If StabilityPackInstalled() Then
        If MsgBox("Uninstall the Stability Pack?" & Chr(10) & Chr(10) & _
            "SolidCraft 2000 will go back to crashing every 15 minutes or so, as designed.", _
            MB_QUESTION Or MB_YESNO, "Stability Pack") = IDNO Then Exit Sub
        SetStabilityPack False
        NextCrash
        MsgBox "The Stability Pack has been uninstalled.", MB_INFO, "Stability Pack"
    Else
        If MsgBox("The Stability Pack stops SolidCraft 2000 crashing every 15 minutes or so." & Chr(10) & Chr(10) & _
            "(The crashes never hurt your parts. They're only a blue picture.)" & Chr(10) & Chr(10) & _
            "Install the Stability Pack?", MB_QUESTION Or MB_YESNO, "Stability Pack") = IDNO Then Exit Sub
        SetStabilityPack True
        MsgBox "The Stability Pack has been installed." & Chr(10) & Chr(10) & _
            "SolidCraft 2000 will no longer crash on schedule.", MB_INFO, "Stability Pack"
    End If
End Sub
