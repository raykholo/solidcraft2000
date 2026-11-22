' sheetui.bas - the Sheet Metal menu: Base Flange, Edge Flange, Flat Pattern
' and the Bend Table Wizard. The commands half of the Windows version's
' modSheetMetal (the geometry is in sheetmetal.bas).

Declare Function RunBendTable() As Boolean

' The last base flange, the default home for an edge flange.
Function LastBase(ByRef d As TDesign) As Long
    Dim i As Long
    For i = d.Count To 1 Step -1
        If d.F(i).Kind = FK_SM_BASE Then Return i
    Next i
    Return 0
End Function

Sub NewBase(ByVal p As Long)
    Dim As TFeature f
    Dim As Long slot = Parts(p).slot, s
    s = LastFreeSketch(Docs(slot))
    If s = 0 Then
        MsgBox "A base flange is made from a rectangle sketch." & Chr(10) & "Sketch a rectangle first.", MB_EXCLAMATION
        Exit Sub
    End If
    If Docs(slot).F(s).Kind <> FK_SKETCH_RECT Or Docs(slot).F(s).P3 > 0 Then
        MsgBox FeatureName(Docs(slot), s) & " isn't a rectangle with square corners." & Chr(10) & Chr(10) & _
            "Base flanges from other shapes require SolidCraft XP.", MB_EXCLAMATION
        Exit Sub
    End If
    If Not SMTableSet Then
        MsgBox "Before you can make sheet metal parts, SolidCraft 2000 needs a bend table." & Chr(10) & Chr(10) & _
            "The Bend Table Wizard will now help you create one.", MB_INFO
        If Not RunBendTable() Then Exit Sub
    End If
    f.Kind = FK_SM_BASE
    f.Ref = s
    f.P1 = SMTableT: f.P2 = SMTableR: f.P3 = SMTableK
    If SM_Ask(Docs(slot), 0, f) Then Commit p, f
End Sub

Sub NewEdge(ByVal p As Long)
    Dim As TFeature f
    Dim As Long slot = Parts(p).slot, b, e, j
    Dim As Boolean taken
    b = LastBase(Docs(slot))
    If b = 0 Then
        MsgBox "An edge flange goes on the edge of a base flange." & Chr(10) & _
            "Choose Sheet Metal, Base Flange first.", MB_EXCLAMATION
        Exit Sub
    End If
    ' the first edge that's free
    For e = 0 To 4
        taken = False
        For j = b + 1 To Docs(slot).Count
            If Docs(slot).F(j).Kind = FK_SM_EDGE And Docs(slot).F(j).Ref = b And Docs(slot).F(j).X = e Then taken = True
        Next j
        If Not taken Then Exit For
    Next e
    If e > 3 Then
        MsgBox "All four edges of " & FeatureName(Docs(slot), b) & " have flanges." & Chr(10) & _
            "That's a box. Well done.", MB_INFO
        Exit Sub
    End If
    f.Kind = FK_SM_EDGE
    f.Ref = b
    f.X = e
    f.P1 = 10 * Docs(slot).F(b).P1
    If f.P1 < 5 Then f.P1 = 5
    f.P2 = 90
    f.P3 = SM_RELIEF_RECT
    If SM_Ask(Docs(slot), 0, f) Then Commit p, f
End Sub

' MOUNTI~1.DXF, next to the part (or in Documents if it's never been
' saved), with ~2, ~3... if that's taken.
Function FlatPatternPath(ByVal slot As Long) As String
    Dim As String sDir, sBase, c, sPath
    Dim As Long k, n
    If Len(DocPath(slot)) Then
        sDir = Left(DocPath(slot), InStrRev(DocPath(slot), "/"))
    Else
        sDir = JoinPath(HomeDir(), "Documents") & "/"
        If Not IsDir(sDir) Then sDir = HomeDir() & "/"
    End If
    For k = 1 To Len(RTrim(Docs(slot).Title))
        c = UCase(Mid(Docs(slot).Title, k, 1))
        If (c >= "A" And c <= "Z") Or (c >= "0" And c <= "9") Then sBase &= c
        If Len(sBase) = 6 Then Exit For
    Next k
    If Len(sBase) = 0 Then sBase = "FLAT"
    n = 1
    Do
        sPath = sDir & sBase & "~" & n & ".DXF"
        If Not IsFile(sPath) Then Return sPath
        n += 1
    Loop While n < 10
    Return sPath
End Function

' Unfolds the part (adding a Flat Pattern the first time) and writes its
' DXF; or, if it's flat, folds it back up.
Sub FoldUnfold(ByVal p As Long)
    Dim As Long slot = Parts(p).slot, b, j
    Dim As TFeature f
    Dim As String sPath
    b = LastBase(Docs(slot))
    If b = 0 Then
        MsgBox "Only sheet metal can be unfolded." & Chr(10) & "Choose Sheet Metal, Base Flange first.", MB_EXCLAMATION
        Exit Sub
    End If
    For j = b + 1 To Docs(slot).Count
        If Docs(slot).F(j).Kind = FK_SM_FLAT And Docs(slot).F(j).Ref = b Then Exit For
    Next j
    If j <= Docs(slot).Count Then
        If Docs(slot).F(j).Suppressed = 0 Then
            HistoryRemember slot, Docs(slot), "Fold " & FeatureName(Docs(slot), b)
            Docs(slot).F(j).Suppressed = 1
            DocDirty(slot) = True
            PartRefreshAll p, False
            SetStatus "Folded."
            Exit Sub
        End If
        HistoryRemember slot, Docs(slot), "Unfold " & FeatureName(Docs(slot), b)
        Docs(slot).F(j).Suppressed = 0
    Else
        f.Kind = FK_SM_FLAT
        f.Ref = b
        If Not Commit(p, f) Then Exit Sub
        j = Docs(slot).Count
    End If
    sPath = FlatPatternPath(slot)
    Docs(slot).F(j).Info = Mid(sPath, InStrRev(sPath, "/") + 1)
    DocDirty(slot) = True
    PartRefreshAll p, False
    If WriteFlatDxf(Docs(slot), b, sPath) Then
        MsgBox "Flat pattern saved as" & Chr(10) & sPath & Chr(10) & Chr(10) & _
            "The file name is 8.3, for the nesting software in the shop, which runs on DOS.", MB_INFO
        SetStatus "Unfolded. Flat pattern saved as " & sPath
    End If
End Sub

' The Sheet Metal menu: SMBase, SMEdge, SMFlat, BendTable.
Sub SM_Command(ByRef sCmd As String)
    Dim As Long p
    If sCmd = "BendTable" Then
        If RunBendTable() Then
            MsgBox "Bend table """ & SMTableName & """ created." & Chr(10) & Chr(10) & _
                "New base flanges will use it. Base flanges you've already made keep their own numbers.", MB_INFO
        End If
        Exit Sub
    End If
    p = ActivePart()
    If p = 0 Then
        MsgBox "There is no part open." & Chr(10) & "Choose File, New Part first.", MB_EXCLAMATION
        Exit Sub
    End If
    Select Case sCmd
    Case "SMBase": NewBase p
    Case "SMEdge": NewEdge p
    Case "SMFlat": FoldUnfold p
    End Select
End Sub
