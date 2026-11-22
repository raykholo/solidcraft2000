Attribute VB_Name = "modCommands"
' modCommands - everything is a command.
'
' The toolbar, the menus and the keyboard all call RunCommand with the same
' key, so there is exactly one copy of each command. (The 1999 way was three
' copies, one per Click handler, all subtly different. See README.)
Option Explicit

Public Sub RunCommand(ByVal sCmd As String)
    Select Case sCmd
    Case "New": CmdNew
    Case "Open": CmdOpen
    Case "Save": CmdSave False
    Case "SaveAs": CmdSave True
    Case "Close": CmdClose
    Case "SaveFloppy": CmdFloppy
    Case "Publish": CmdPublish
    Case "ExportStl": CmdExportStl
    Case "Exit": Unload frmMain

    Case "SketchRect": CmdSketchRect
    Case "SketchCircle": CmdSketchCircle
    Case "Extrude": CmdExtrude
    Case "Revolve": CmdRevolve
    Case "Hole": CmdHole
    Case "Fillet": CmdEdgeFinish FK_FILLET
    Case "Chamfer": CmdEdgeFinish FK_CHAMFER
    Case "SMBase", "SMEdge", "SMFlat", "BendTable": SM_Command sCmd
    Case "Undo": CmdUndo
    Case "Edit": CmdEdit
    Case "Delete": CmdDelete

    Case "Orbit", "ViewIso": WithPart "ViewIso"
    Case "ZoomFit": WithPart "ZoomFit"
    Case "Regen": WithPart "Regen"

    Case "Shaded": CmdShaded
    Case "Turbo": SetTurbo Not Turbo

    Case "Cascade": frmMain.Arrange vbCascade
    Case "TileH": frmMain.Arrange vbTileHorizontal
    Case "TileV": frmMain.Arrange vbTileVertical

    Case "Help": CmdHelp
    Case "About": frmAbout.Show vbModal, frmMain
    Case "Upgrade": frmUpgrade.Show vbModal, frmMain
    Case "StabilityPack": StabilityPackCommand
    Case Else
        MsgBox "Command '" & sCmd & "' is not implemented yet." & vbCrLf & _
            "It is scheduled for SolidCraft XP.", vbInformation, App.Title
    End Select
End Sub

' The part window in front, or Nothing.
Public Function ActivePart() As frmPart
    If frmMain.ActiveForm Is Nothing Then Exit Function
    If TypeOf frmMain.ActiveForm Is frmPart Then Set ActivePart = frmMain.ActiveForm
End Function

Private Function NeedPart(p As frmPart) As Boolean
    Set p = ActivePart()
    If p Is Nothing Then
        MsgBox "There is no part open." & vbCrLf & "Choose File, New Part first.", vbExclamation, App.Title
    Else
        NeedPart = True
    End If
End Function

Private Sub WithPart(ByVal sWhat As String)
    Dim p As frmPart
    If Not NeedPart(p) Then Exit Sub
    Select Case sWhat
    Case "ViewIso": p.ViewIso
    Case "ZoomFit": p.ZoomFit
    Case "Regen": p.Regen
    End Select
End Sub

Private Sub Status(ByVal s As String)
    frmMain.SetStatus s
End Sub

' ---- File ----

Private Sub CmdNew()
    Dim slot As Integer, p As frmPart
    slot = NewDocSlot()
    If slot = 0 Then
        MsgBox "Too many parts open. Sixteen ought to be enough for anybody.", vbExclamation, App.Title
        Exit Sub
    End If
    Set p = New frmPart
    p.Attach slot
    p.Show
    Status "New part created."
End Sub

Private Sub CmdOpen()
    Dim sPath As String, slot As Integer, p As frmPart
    sPath = frmMain.AskFileName(False, "", _
        "All SolidCraft files (*.sc2, *.sc98, *.solidcraft)|*.sc2;*.sc98;*.solidcraft|SolidCraft 2000 Parts (*.sc2)|*.sc2|SolidCraft 98 Parts (*.sc98)|*.sc98|SolidCraft Designs (*.solidcraft)|*.solidcraft", PART_EXT)
    If Len(sPath) = 0 Then Exit Sub
    slot = NewDocSlot()
    If slot = 0 Then
        MsgBox "Too many parts open. Close one first.", vbExclamation, App.Title
        Exit Sub
    End If
    If IsSolidCraftDesign(sPath) Then
        ' a design from SolidCraft itself: rebuilt here, saved as a new .sc2
        Screen.MousePointer = vbHourglass
        If Not ImportSolidCraft(sPath, Docs(slot)) Then
            Screen.MousePointer = vbDefault
            FreeDocSlot slot
            Exit Sub
        End If
        Screen.MousePointer = vbDefault
        DocPath(slot) = ""
    Else
        If Not LoadDesign(Docs(slot), sPath) Then
            FreeDocSlot slot
            Exit Sub
        End If
        DocPath(slot) = sPath
        Docs(slot).Title = FileTitle(sPath)
        ' an upgraded SolidCraft 98 part is saved as a new .sc2, never over the old file
        If LCase$(Right$(sPath, 5)) = ".sc98" Then DocPath(slot) = ""
    End If
    Set p = New frmPart
    p.Attach slot
    p.Show
    p.ZoomFit
    Status "Opened " & sPath
End Sub

Private Sub CmdSave(ByVal bAs As Boolean)
    Dim p As frmPart, slot As Integer, sPath As String
    If Not NeedPart(p) Then Exit Sub
    slot = p.DocIndex
    sPath = DocPath(slot)
    If bAs Or Len(sPath) = 0 Then
        sPath = frmMain.AskFileName(True, RTrim$(Docs(slot).Title))
        If Len(sPath) = 0 Then Exit Sub
    End If
    ' A:\ with no floppy drive is the pretend floppy; a real A: is just a drive
    If UCase$(Left$(sPath, 3)) = "A:\" And Not FolderExists("A:\") Then
        FloppySave p, Mid$(sPath, 4)
        Exit Sub
    End If
    If SaveDesign(Docs(slot), sPath) Then
        DocPath(slot) = sPath
        Docs(slot).Title = FileTitle(sPath)
        DocDirty(slot) = False
        p.RefreshNames
        Status "Saved " & sPath & " (" & FileLen(sPath) & " bytes)"
    End If
End Sub

Private Sub CmdFloppy()
    Dim p As frmPart
    If Not NeedPart(p) Then Exit Sub
    FloppySave p, RTrim$(Docs(p.DocIndex).Title) & "." & PART_EXT
End Sub

' Saving to drive A:. There isn't one, so the part goes to the hard disk
' first, and with Turbo on we put on a show of floppies for it.
Private Sub FloppySave(p As frmPart, ByVal sName As String)
    Dim slot As Integer, sReal As String, nBytes As Double
    Const PREVIEW_BYTES As Double = 3686454   ' a 1280 x 960 24-bit BMP, "for faster opening"
    slot = p.DocIndex
    If FolderExists("A:\") Then
        ' a real floppy drive, in this day and age: save to it
        sReal = "A:\" & FileTitle(sName) & "." & PART_EXT
        If Not SaveDesign(Docs(slot), sReal) Then Exit Sub
        DocPath(slot) = sReal
        Docs(slot).Title = FileTitle(sReal)
        DocDirty(slot) = False
        p.RefreshNames
        Status "Saved " & sReal & " (" & FileLen(sReal) & " bytes). Remember to label the disk."
        Exit Sub
    End If
    If Not Turbo Then
        MsgBox "There is no drive A: on this PC." & vbCrLf & vbCrLf & _
            "Use File, Save As to save the part to the hard disk.", vbExclamation, App.Title
        Exit Sub
    End If
    sReal = DocPath(slot)
    If Len(sReal) = 0 Then sReal = SafeDocumentsPath(sName)
    If Not SaveDesign(Docs(slot), sReal) Then Exit Sub
    DocPath(slot) = sReal
    Docs(slot).Title = FileTitle(sReal)
    DocDirty(slot) = False
    p.RefreshNames
    nBytes = FileLen(sReal) + PREVIEW_BYTES
    If frmFloppy.Run(FileTitle(sReal) & "." & PART_EXT, nBytes) Then
        MsgBox "Copied " & Format$(nBytes, "#,##0") & " bytes to " & (-Int(-nBytes / FLOPPY_BYTES)) & " disks." & vbCrLf & vbCrLf & _
            "Turbo saves include an uncompressed preview bitmap, for speed." & vbCrLf & _
            "(This PC has no drive A:, so the part itself is safe in" & vbCrLf & sReal & ")", vbInformation, App.Title
    Else
        MsgBox "Copy cancelled. The part is safe in" & vbCrLf & sReal, vbInformation, App.Title
    End If
    Status "Saved " & sReal
End Sub

' My Documents\<name>, with (2), (3)... if that's taken.
Private Function SafeDocumentsPath(ByVal sName As String) As String
    Dim sDir As String, sBase As String, n As Integer
    sDir = Environ$("USERPROFILE") & "\Documents\"
    If Not FolderExists(sDir) Then sDir = App.Path & "\"
    sBase = FileTitle(sName)
    SafeDocumentsPath = sDir & sBase & "." & PART_EXT
    n = 1
    Do While FileExists(SafeDocumentsPath)
        n = n + 1
        SafeDocumentsPath = sDir & sBase & " (" & n & ")." & PART_EXT
    Loop
End Function

Private Sub CmdPublish()
    Dim p As frmPart
    If Not NeedPart(p) Then Exit Sub
    PublishPart p
End Sub

Private Sub CmdExportStl()
    Dim p As frmPart
    If Not NeedPart(p) Then Exit Sub
    ExportStl p
End Sub

Private Sub CmdShaded()
    ViewShaded = Not ViewShaded
    frmMain.ShadedChanged
    If Not ViewShaded Then frmMain.SetStatus "Wireframe."
    RefreshAllParts
End Sub

Private Sub CmdClose()
    Dim p As frmPart
    If Not NeedPart(p) Then Exit Sub
    Unload p
End Sub

' ---- Features ----

' For modSheetMetal: adds f to the part, as the menus do.
Public Function CommitFeature(p As frmPart, f As TFeature) As Boolean
    CommitFeature = Commit(p, f)
End Function

Private Function Commit(p As frmPart, f As TFeature) As Boolean
    Dim i As Integer
    i = AddFeature(Docs(p.DocIndex), f)
    If i = 0 Then
        MsgBox "Subscript out of range." & vbCrLf & vbCrLf & _
            "A part can have " & MAX_FEATURES & " features. Nobody will ever need more.", vbCritical, App.Title
        Exit Function
    End If
    DocDirty(p.DocIndex) = True
    p.RefreshAll True
    Status FeatureName(Docs(p.DocIndex), i) & " created: " & Describe(Docs(p.DocIndex), i)
    Commit = True
    If f.Kind = FK_SKETCH_RECT Then frmCal.Pop "It looks like you're drawing a box."
    If f.Kind = FK_FILLET Then frmCal.Pop "It looks like you're trying to round an edge!", "fillet"
    If f.Kind = FK_CHAMFER Then frmCal.Pop "It looks like you're trying to take the corner off!", "chamfer"
End Function

Private Sub CmdSketchRect()
    Dim p As frmPart, f As TFeature
    If Not NeedPart(p) Then Exit Sub
    f.Kind = FK_SKETCH_RECT
    f.P1 = 40: f.P2 = 30
    f.Ref = SelectedExtrude(p)
    If AskFeature(Docs(p.DocIndex), 0, f) Then Commit p, f
End Sub

Private Sub CmdSketchCircle()
    Dim p As frmPart, f As TFeature
    If Not NeedPart(p) Then Exit Sub
    f.Kind = FK_SKETCH_CIRCLE
    f.P1 = 15
    f.Ref = SelectedExtrude(p)
    If AskFeature(Docs(p.DocIndex), 0, f) Then Commit p, f
End Sub

Private Sub CmdExtrude()
    Dim p As frmPart, f As TFeature
    If Not NeedPart(p) Then Exit Sub
    f.Ref = LastFreeSketch(Docs(p.DocIndex))
    If f.Ref = 0 Then
        MsgBox "Extrude needs a sketch to extrude." & vbCrLf & "Sketch a rectangle or a circle first.", vbExclamation, App.Title
        Exit Sub
    End If
    f.Kind = FK_EXTRUDE
    f.P1 = 20
    If AskFeature(Docs(p.DocIndex), 0, f) Then Commit p, f
End Sub

Private Sub CmdRevolve()
    Dim p As frmPart, f As TFeature
    If Not NeedPart(p) Then Exit Sub
    f.Ref = LastFreeSketch(Docs(p.DocIndex))
    If f.Ref = 0 Then
        MsgBox "Revolve needs a sketch to revolve." & vbCrLf & "Sketch a rectangle or a circle first.", vbExclamation, App.Title
        Exit Sub
    End If
    f.Kind = FK_REVOLVE
    f.P1 = 360
    If AskFeature(Docs(p.DocIndex), 0, f) Then Commit p, f
End Sub

' The extrude picked in the tree or timeline (a hole, a fillet or a chamfer
' counts as its extrude), or 0.
Private Function SelectedExtrude(p As frmPart) As Integer
    Dim b As Integer
    b = p.SelectedFeature()
    If b = 0 Then Exit Function
    If Docs(p.DocIndex).Features(b).Kind = FK_HOLE Or IsEdgeFinish(Docs(p.DocIndex).Features(b).Kind) Then b = Docs(p.DocIndex).Features(b).Ref
    If Docs(p.DocIndex).Features(b).Kind = FK_EXTRUDE Then SelectedExtrude = b
End Function

' A hole goes on the top face of the selected extrude, or the last one.
Private Sub CmdHole()
    Dim p As frmPart, f As TFeature, b As Integer, s As TFeature
    If Not NeedPart(p) Then Exit Sub
    b = SelectedExtrude(p)
    If b = 0 Then b = LastSolid(Docs(p.DocIndex))
    If b = 0 Then
        MsgBox "A hole goes on the top face of an extrude." & vbCrLf & "Sketch something and extrude it first.", vbExclamation, App.Title
        Exit Sub
    End If
    s = Docs(p.DocIndex).Features(Docs(p.DocIndex).Features(b).Ref)
    f.Kind = FK_HOLE
    f.Ref = b
    f.P1 = 8
    f.P3 = 1                       ' one hole; more makes a pattern
    f.Reserved(2) = 20             ' the spacing, if it becomes a row
    SketchCentre s, f.X, f.Y
    If AskFeature(Docs(p.DocIndex), 0, f) Then Commit p, f
End Sub

' NEW IN 2000. A fillet rounds the top edges of the selected extrude (a hole,
' a fillet or a chamfer counts as its extrude), or of the last one. A chamfer
' (Service Pack 1) bevels them instead. An extrude gets one or the other.
Private Sub CmdEdgeFinish(ByVal nKind As Integer)
    Dim p As frmPart, f As TFeature, b As Integer, j As Integer, s As TFeature, m As Double
    If Not NeedPart(p) Then Exit Sub
    b = SelectedExtrude(p)
    If b = 0 Then b = LastSolid(Docs(p.DocIndex))
    If b = 0 Then
        MsgBox "A " & LCase$(KindName(nKind)) & IIf(nKind = FK_CHAMFER, " bevels", " rounds") & " the edges of an extrude." & vbCrLf & _
            "Sketch something and extrude it first.", vbExclamation, App.Title
        Exit Sub
    End If
    For j = b + 1 To Docs(p.DocIndex).Count
        If IsEdgeFinish(Docs(p.DocIndex).Features(j).Kind) And Docs(p.DocIndex).Features(j).Ref = b Then
            MsgBox FeatureName(Docs(p.DocIndex), b) & " already has a " & LCase$(KindName(Docs(p.DocIndex).Features(j).Kind)) & ", " & FeatureName(Docs(p.DocIndex), j) & "." & vbCrLf & vbCrLf & _
                "SolidCraft 2000 finishes the top edges of an extrude once: a fillet or a chamfer." & vbCrLf & _
                "Edit " & FeatureName(Docs(p.DocIndex), j) & " to change it, or delete it first." & vbCrLf & _
                "(Fillets on chamfers are planned for SolidCraft XP.)", vbInformation, App.Title
            Exit Sub
        End If
    Next j
    s = Docs(p.DocIndex).Features(Docs(p.DocIndex).Features(b).Ref)
    ' a sensible first guess: 2 mm, or less on something small
    m = Abs(Docs(p.DocIndex).Features(b).P1)
    If s.Kind = FK_SKETCH_RECT Then
        If s.P1 / 2 < m Then m = s.P1 / 2
        If s.P2 / 2 < m Then m = s.P2 / 2
    Else
        If s.P1 < m Then m = s.P1
    End If
    f.Kind = nKind
    f.Ref = b
    f.P1 = 2
    If f.P1 > m / 2 Then f.P1 = Int(m / 2 * 10) / 10
    If f.P1 <= 0 Then f.P1 = 0.1
    If AskFeature(Docs(p.DocIndex), 0, f) Then Commit p, f
End Sub

' Double-click in the tree or the timeline: change a feature's numbers.
Public Sub EditFeature(p As frmPart, ByVal i As Integer)
    Dim slot As Integer, f As TFeature
    slot = p.DocIndex
    If i < 1 Or i > Docs(slot).Count Then Exit Sub
    f = Docs(slot).Features(i)
    If Not AskFeature(Docs(slot), i, f) Then Exit Sub
    Docs(slot).Features(i) = f
    DocDirty(slot) = True
    p.RefreshAll False
    Status FeatureName(Docs(slot), i) & " changed: " & Describe(Docs(slot), i)
    ' anything built on it may not fit any more; say so instead of hiding it
    Dim j As Integer, sBad As String
    For j = i + 1 To Docs(slot).Count
        If Not RefOk(Docs(slot), j) Then sBad = sBad & vbCrLf & "    " & FeatureName(Docs(slot), j)
    Next j
    If Len(sBad) > 0 Then
        MsgBox "These features no longer fit and have been left out of the part:" & vbCrLf & sBad & vbCrLf & vbCrLf & _
            "Edit them, or edit " & FeatureName(Docs(slot), i) & " back.", vbExclamation, App.Title
    End If
End Sub

Private Sub CmdEdit()
    Dim p As frmPart, i As Integer
    If Not NeedPart(p) Then Exit Sub
    i = p.SelectedFeature()
    If i = 0 Then
        MsgBox "Select a feature in the tree or the timeline first.", vbInformation, App.Title
        Exit Sub
    End If
    EditFeature p, i
End Sub

' Delete the selected feature, and whatever is built on it.
Private Sub CmdDelete()
    Dim p As frmPart, slot As Integer, i As Integer, j As Integer, gone() As Boolean, n As Integer, sList As String
    If Not NeedPart(p) Then Exit Sub
    slot = p.DocIndex
    i = p.SelectedFeature()
    If i = 0 Then
        MsgBox "Select a feature in the tree or the timeline first.", vbInformation, App.Title
        Exit Sub
    End If
    n = MarkDependents(Docs(slot), i, gone)
    For j = 1 To Docs(slot).Count
        If gone(j) And j <> i Then sList = sList & vbCrLf & "    " & FeatureName(Docs(slot), j)
    Next j
    If n > 1 Then
        If MsgBox("These are built on " & FeatureName(Docs(slot), i) & " and will be deleted too:" & vbCrLf & sList & vbCrLf & vbCrLf & _
            "Delete all " & n & " features?", vbExclamation Or vbYesNo Or vbDefaultButton2, App.Title) = vbNo Then Exit Sub
    End If
    sList = FeatureName(Docs(slot), i)
    DeleteMarked Docs(slot), gone
    DocDirty(slot) = True
    p.RefreshAll False
    If n > 1 Then Status "Deleted " & sList & " and " & (n - 1) & " more." Else Status "Deleted " & sList & "."
End Sub

' The one dialog per kind of feature, for New and for Edit. i is the feature
' being edited (0 for a new one). Fills f and returns True on OK, if the
' numbers make sense.
Private Function AskFeature(d As TDesign, ByVal i As Integer, f As TFeature) As Boolean
    Dim sTitle As String, s As TFeature, b As TFeature, k As Integer, inset As TFeature
    Dim sWord As String, sWhole As String
    Dim g As TFeature, m As Integer, q As Integer, x1 As Double, y1 As Double, x2 As Double, y2 As Double
    If i = 0 Then sTitle = "" Else sTitle = "Edit " & FeatureName(d, i) & ": "
    Select Case f.Kind
    Case FK_SKETCH_RECT
        If Not frmParams.Ask(sTitle & "Sketch Rectangle", _
            "Width (mm)|Height (mm)|Corner X (mm)|Corner Y (mm)|Corner radius (mm)|" & PlacePrompts(), _
            Fmt0(f.P1) & "|" & Fmt0(f.P2) & "|" & Fmt0(f.X) & "|" & Fmt0(f.Y) & "|" & Fmt0(f.P3) & "|" & Fmt0(f.Ref) & "|" & Fmt0(f.Z)) Then Exit Function
        If Not PlaceOk(d, i, frmParams.Value(5)) Then Exit Function
        If frmParams.Value(0) <= 0 Or frmParams.Value(1) <= 0 Then
            MsgBox "Width and height must be more than zero.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(4) < 0 Or frmParams.Value(4) * 2 > Min2(frmParams.Value(0), frmParams.Value(1)) Then
            MsgBox "The corner radius must be between 0 and half the shorter side.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(4) > 0 And f.P3 = 0 Then
            frmCal.Pop "It looks like you're trying to round an edge!" & vbCrLf & _
                "(A corner radius rounds the upright ones. For the top ones, try Features, Fillet.)", "fillet"
        End If
        f.P1 = frmParams.Value(0): f.P2 = frmParams.Value(1)
        f.X = frmParams.Value(2): f.Y = frmParams.Value(3)
        f.P3 = frmParams.Value(4)
        f.Ref = frmParams.Value(5): f.Z = frmParams.Value(6)

    Case FK_SKETCH_CIRCLE
        If Not frmParams.Ask(sTitle & "Sketch Circle", "Radius (mm)|Centre X (mm)|Centre Y (mm)|" & PlacePrompts(), _
            Fmt0(f.P1) & "|" & Fmt0(f.X) & "|" & Fmt0(f.Y) & "|" & Fmt0(f.Ref) & "|" & Fmt0(f.Z)) Then Exit Function
        If Not PlaceOk(d, i, frmParams.Value(3)) Then Exit Function
        If frmParams.Value(0) <= 0 Then
            MsgBox "The radius must be more than zero.", vbExclamation, App.Title
            Exit Function
        End If
        f.P1 = frmParams.Value(0)
        f.X = frmParams.Value(1): f.Y = frmParams.Value(2)
        f.Ref = frmParams.Value(3): f.Z = frmParams.Value(4)

    Case FK_EXTRUDE
        If Not frmParams.Ask(sTitle & "Extrude " & FeatureName(d, f.Ref), "Depth (mm)", Fmt0(f.P1)) Then Exit Function
        If frmParams.Value(0) <= 0 Then
            MsgBox "The depth must be more than zero.", vbExclamation, App.Title
            Exit Function
        End If
        f.P1 = frmParams.Value(0)

    Case FK_REVOLVE
        If Not frmParams.Ask(sTitle & "Revolve " & FeatureName(d, f.Ref) & " about Y", "Angle (degrees)", Fmt0(f.P1)) Then Exit Function
        If frmParams.Value(0) = 0 Or Abs(frmParams.Value(0)) > 360 Then
            MsgBox "The angle must be between 1 and 360 degrees.", vbExclamation, App.Title
            Exit Function
        End If
        s = d.Features(f.Ref)
        If Not OneSideOfY(s) Then
            MsgBox "The sketch crosses the Y axis, so revolving it would turn the part inside out." & vbCrLf & _
                "Move the sketch so it's all on one side of X = 0.", vbExclamation, App.Title
            Exit Function
        End If
        f.P1 = frmParams.Value(0)

    Case FK_FILLET, FK_CHAMFER
        b = d.Features(f.Ref)
        s = d.Features(b.Ref)
        If f.Kind = FK_CHAMFER Then
            sWord = "distance": sWhole = "A chamfer that big would cut the whole top away."
            If Not frmParams.Ask(sTitle & "Chamfer the top edges of " & FeatureName(d, f.Ref) & ", at 45" & Chr$(176), "Distance (mm)", Fmt0(f.P1)) Then Exit Function
        Else
            sWord = "radius": sWhole = "A fillet that big would round the whole top away."
            If Not frmParams.Ask(sTitle & "Fillet the top edges of " & FeatureName(d, f.Ref), "Radius (mm)", Fmt0(f.P1)) Then Exit Function
        End If
        If frmParams.Value(0) <= 0 Then
            MsgBox "The " & sWord & " must be more than zero.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(0) > Abs(b.P1) + 0.000001 Then
            MsgBox "That " & sWord & " is bigger than " & FeatureName(d, f.Ref) & " is tall (" & Fmt0(Abs(b.P1)) & " mm).", vbExclamation, App.Title
            Exit Function
        End If
        If s.Kind = FK_SKETCH_RECT Then
            If 2 * frmParams.Value(0) >= Min2(s.P1, s.P2) - 0.000001 Then
                MsgBox sWhole & vbCrLf & _
                    "Keep the " & sWord & " under half the shorter side (" & Fmt0(Min2(s.P1, s.P2) / 2) & " mm).", vbExclamation, App.Title
                Exit Function
            End If
        ElseIf frmParams.Value(0) >= s.P1 - 0.000001 Then
            MsgBox sWhole & vbCrLf & _
                "Keep the " & sWord & " under the circle's radius (" & Fmt0(s.P1) & " mm).", vbExclamation, App.Title
            Exit Function
        End If
        ' the holes in the top have to stay clear of the rounded edge
        inset = InsetSketch(s, frmParams.Value(0))
        For k = 1 To d.Count
            If k <> i And d.Features(k).Kind = FK_HOLE And d.Features(k).Ref = f.Ref And d.Features(k).Suppressed = 0 Then
                If Not HolesInside(inset, d.Features(k)) Then
                    MsgBox FeatureName(d, k) & " is too close to the edge for a " & Fmt0(frmParams.Value(0)) & " mm " & LCase$(KindName(f.Kind)) & "." & vbCrLf & _
                        "Try a smaller " & sWord & ", or move the hole in.", vbExclamation, App.Title
                    Exit Function
                End If
            End If
        Next k
        f.P1 = frmParams.Value(0)

    Case FK_SM_BASE, FK_SM_EDGE, FK_SM_FLAT
        If Not SM_Ask(d, i, f) Then Exit Function

    Case FK_FOREIGN
        If InStr(LCase$(f.Info), "fillet") > 0 Then
            MsgBox RTrim$(f.Name) & " is a fillet from SolidCraft, which rounds the edges it was given, one by one." & vbCrLf & vbCrLf & _
                "SolidCraft 2000 rounds all the top edges of an extrude or none of them." & vbCrLf & _
                "Choosing edges requires SolidCraft XP. (Features, Fillet rounds them all.)", vbInformation, App.Title
        Else
            MsgBox RTrim$(f.Name) & " is a " & LCase$(RTrim$(f.Info)) & " from SolidCraft." & vbCrLf & vbCrLf & _
                "Requires SolidCraft XP.", vbInformation, App.Title
        End If
        Exit Function

    Case FK_HOLE
        b = d.Features(f.Ref)
        s = d.Features(b.Ref)
        ' Service Pack 1: Count, and the pattern's shape, in the same dialog
        If Not frmParams.Ask(sTitle & "Hole on top face of " & FeatureName(d, f.Ref), _
            "Diameter (mm)|Depth (mm, 0 = through all)|Centre X (mm)|Centre Y (mm)|" & _
            "Count (1 = one hole)|Bolt circle dia. (0 = a row)|Row spacing (mm)|Angle (degrees)", _
            Fmt0(f.P1) & "|" & Fmt0(f.P2) & "|" & Fmt0(f.X) & "|" & Fmt0(f.Y) & "|" & _
            HoleCount(f) & "|" & Fmt0(f.Reserved(1)) & "|" & Fmt0(f.Reserved(2)) & "|" & Fmt0(f.Reserved(3))) Then Exit Function
        If frmParams.Value(0) <= 0 Or frmParams.Value(1) < 0 Then
            MsgBox "The diameter must be more than zero, and the depth zero or more.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(4) <> Int(frmParams.Value(4)) Or frmParams.Value(4) < 1 Or frmParams.Value(4) > MAX_PATTERN Then
            MsgBox "Count must be a whole number from 1 to " & MAX_PATTERN & "." & vbCrLf & _
                "(" & MAX_PATTERN & " holes ought to be enough for anybody.)", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(5) < 0 Then
            MsgBox "The bolt circle diameter must be zero (for a row) or more.", vbExclamation, App.Title
            Exit Function
        End If
        g = f
        g.P1 = frmParams.Value(0): g.P2 = frmParams.Value(1)
        g.X = frmParams.Value(2): g.Y = frmParams.Value(3)
        g.P3 = frmParams.Value(4)
        g.Reserved(1) = frmParams.Value(5): g.Reserved(2) = frmParams.Value(6): g.Reserved(3) = frmParams.Value(7)
        If HoleCount(g) > 1 Then
            ' the holes of the pattern mustn't run into each other
            For m = 0 To HoleCount(g) - 2
                HoleAt g, m, x1, y1
                For q = m + 1 To HoleCount(g) - 1
                    HoleAt g, q, x2, y2
                    If Sqr((x1 - x2) ^ 2 + (y1 - y2) ^ 2) < g.P1 + 0.01 Then
                        MsgBox "The holes in the pattern would run into each other." & vbCrLf & _
                            IIf(g.Reserved(1) > 0, "Make the bolt circle bigger, or the holes fewer or smaller.", _
                            "Make the row spacing more than the diameter."), vbExclamation, App.Title
                        Exit Function
                    End If
                Next q
            Next m
        End If
        s = TopFace(d, f.Ref)          ' less the fillet, if it has one
        If Not HolesInside(s, g) Then
            MsgBox IIf(HoleCount(g) > 1, "Not all the holes fit on the face. One would fall off the edge", _
                "That hole doesn't fit on the face. It would fall off the edge") & _
                IIf(FilletOf(d, f.Ref) > 0, ", or into the " & LCase$(KindName(d.Features(FilletOf(d, f.Ref)).Kind)) & ".", "."), vbExclamation, App.Title
            Exit Function
        End If
        If g.P2 > b.P1 + 0.000001 Then
            MsgBox "That's deeper than " & FeatureName(d, f.Ref) & " is tall." & vbCrLf & _
                "Use depth 0 for a hole all the way through.", vbExclamation, App.Title
            Exit Function
        End If
        For k = 1 To d.Count
            If k <> i And d.Features(k).Kind = FK_HOLE And d.Features(k).Ref = f.Ref Then
                For m = 0 To HoleCount(g) - 1
                    HoleAt g, m, x1, y1
                    For q = 0 To HoleCount(d.Features(k)) - 1
                        HoleAt d.Features(k), q, x2, y2
                        If Sqr((x1 - x2) ^ 2 + (y1 - y2) ^ 2) < (d.Features(k).P1 + g.P1) / 2 + 0.01 Then
                            MsgBox IIf(HoleCount(g) > 1, "A hole of the pattern", "That hole") & " would run into " & FeatureName(d, k) & ".", vbExclamation, App.Title
                            Exit Function
                        End If
                    Next q
                Next m
            End If
        Next k
        f = g
    End Select
    AskFeature = True
End Function

Private Function PlacePrompts() As String
    PlacePrompts = "On feature # (0 = ground)|Height above that (mm)"
End Function

' The "on top of" number must be 0 or an extrude that comes before this sketch.
Private Function PlaceOk(d As TDesign, ByVal i As Integer, ByVal v As Double) As Boolean
    Dim n As Integer, last As Integer
    If v = 0 Then
        PlaceOk = True
        Exit Function
    End If
    If i = 0 Then last = d.Count Else last = i - 1
    n = Int(v)
    If n = v And n >= 1 And n <= last Then
        If d.Features(n).Kind = FK_EXTRUDE Then
            PlaceOk = True
            Exit Function
        End If
    End If
    MsgBox "A sketch can sit on the ground (0) or on top of an extrude that comes before it." & vbCrLf & _
        "Use the number from the # column of the timeline.", vbExclamation, App.Title
End Function

Private Function Fmt0(ByVal v As Double) As String
    Fmt0 = Format$(v, "0.###")
    If Right$(Fmt0, 1) = "." Then Fmt0 = Left$(Fmt0, Len(Fmt0) - 1)
End Function

Private Function Min2(ByVal a As Double, ByVal b As Double) As Double
    If a < b Then Min2 = a Else Min2 = b
End Function

Private Sub SketchCentre(s As TFeature, x As Double, y As Double)
    If s.Kind = FK_SKETCH_CIRCLE Then
        x = s.X: y = s.Y
    Else
        x = s.X + s.P1 / 2: y = s.Y + s.P2 / 2
    End If
End Sub

Private Function OneSideOfY(s As TFeature) As Boolean
    If s.Kind = FK_SKETCH_CIRCLE Then
        OneSideOfY = (s.X - s.P1 >= 0) Or (s.X + s.P1 <= 0)
    Else
        OneSideOfY = (s.X >= 0) Or (s.X + s.P1 <= 0)
    End If
End Function

Private Sub CmdUndo()
    Dim p As frmPart, slot As Integer, i As Integer
    If Not NeedPart(p) Then Exit Sub
    slot = p.DocIndex
    i = Docs(slot).Count
    If i = 0 Then
        Status "Nothing to undo."
        Exit Sub
    End If
    ' Features only ever build on earlier ones, so the last one is always safe to drop.
    Status "Removed " & FeatureName(Docs(slot), i) & "."
    Docs(slot).Features(i).Kind = FK_NONE
    Docs(slot).Count = i - 1
    DocDirty(slot) = True
    p.RefreshAll False
End Sub

Private Sub CmdHelp()
    MsgBox "Cannot find the file 'SOLIDCRAFT.HLP' (or one of its components)." & vbCrLf & vbCrLf & _
        "Make sure the path and filename are correct and that all required libraries are available.", _
        vbExclamation, "WinHelp"
End Sub
