Attribute VB_Name = "modModel"
' modModel - the design, as one Type you can Put straight to disk.
'
' The file format IS this Type. Change a field and every older file breaks,
' which is why FILE_VERSION exists and why the "migration system" is a MsgBox.
Option Explicit

Public Const FILE_MAGIC As String = "SC2K"
Public Const FILE_VERSION As Integer = 7     ' 7: Service Pack 1 (chamfers, hole patterns). Parts without them are still saved as 6
Private Const FILE_VERSION_1_0 As Integer = 6
Public Const FILE_MAGIC_98 As String = "SC98"   ' SolidCraft 98 parts: read, upgraded, never written
Public Const MAX_FEATURES As Integer = 64    ' someone once had 41 features

Private mFrom98 As Boolean                   ' the file being opened is a SolidCraft 98 part

Public Const FK_NONE As Integer = 0
Public Const FK_SKETCH_RECT As Integer = 1
Public Const FK_SKETCH_CIRCLE As Integer = 2
Public Const FK_EXTRUDE As Integer = 3
Public Const FK_REVOLVE As Integer = 4
Public Const FK_HOLE As Integer = 5
Public Const FK_FILLET As Integer = 6      ' NEW IN 2000: rounds the top edges of an extrude
Public Const FK_CHAMFER As Integer = 7     ' Service Pack 1: bevels them, at 45 degrees
Public Const FK_FOREIGN As Integer = 9     ' from a SolidCraft design, and not something SolidCraft 2000 can build

Public Type TFeature
    Kind As Integer
    Name As String * 24
    X As Double            ' sketch origin / hole centre, mm
    Y As Double
    Z As Double            ' sketch plane height, mm
    P1 As Double           ' width | radius | depth | angle | diameter | fillet radius | chamfer distance
    P2 As Double           ' height | - | - | - | hole depth (0 = through all) | -
    Ref As Integer         ' the feature this one is built on
    Suppressed As Integer
    P3 As Double           ' rectangle corner radius | hole: how many in the pattern (0 or 1 = one)
    Info As String * 32    ' FK_FOREIGN: what the feature was in SolidCraft ("fillet")
    Reserved(1 To 3) As Double   ' so the next version won't break every file (it will anyway).
                                 ' Hole patterns: bolt circle diameter (0 = a row), row spacing, angle
End Type

' Version 3 files, from before corner radii. Read and converted on Open.
Private Type TFeatureV3
    Kind As Integer
    Name As String * 24
    X As Double
    Y As Double
    Z As Double
    P1 As Double
    P2 As Double
    Ref As Integer
    Suppressed As Integer
End Type

Private Type TDesignV3
    Magic As String * 4
    Version As Integer
    Title As String * 64
    Count As Integer
    Features(1 To MAX_FEATURES) As TFeatureV3
End Type

' Version 4: corner radii, but no room to say what a SolidCraft feature was.
Private Type TFeatureV4
    Kind As Integer
    Name As String * 24
    X As Double
    Y As Double
    Z As Double
    P1 As Double
    P2 As Double
    Ref As Integer
    Suppressed As Integer
    P3 As Double
    Reserved(1 To 3) As Double
End Type

Private Type TDesignV4
    Magic As String * 4
    Version As Integer
    Title As String * 64
    Count As Integer
    Features(1 To MAX_FEATURES) As TFeatureV4
End Type

Public Type TFileHeader
    Magic As String * 4
    Version As Integer
End Type

Public Type TDesign
    Magic As String * 4
    Version As Integer
    Title As String * 64
    Count As Integer
    Features(1 To MAX_FEATURES) As TFeature
End Type

Public Sub NewDesign(d As TDesign, ByVal sTitle As String)
    Dim i As Integer
    d.Magic = FILE_MAGIC
    d.Version = FILE_VERSION
    d.Title = sTitle
    d.Count = 0
    For i = 1 To MAX_FEATURES
        d.Features(i).Kind = FK_NONE
    Next i
End Sub

Public Function KindName(ByVal k As Integer) As String
    Select Case k
    Case FK_SKETCH_RECT: KindName = "Sketch (Rectangle)"
    Case FK_SKETCH_CIRCLE: KindName = "Sketch (Circle)"
    Case FK_EXTRUDE: KindName = "Extrude"
    Case FK_REVOLVE: KindName = "Revolve"
    Case FK_HOLE: KindName = "Hole"
    Case FK_FILLET: KindName = "Fillet"
    Case FK_CHAMFER: KindName = "Chamfer"
    Case FK_FOREIGN: KindName = "SolidCraft"
    Case Else
        KindName = SM_KindName(k)
        If Len(KindName) = 0 Then KindName = "?"
    End Select
End Function

Public Function KindPrefix(ByVal k As Integer) As String
    Select Case k
    Case FK_SKETCH_RECT, FK_SKETCH_CIRCLE: KindPrefix = "Sketch"
    Case FK_EXTRUDE: KindPrefix = "Extrude"
    Case FK_REVOLVE: KindPrefix = "Revolve"
    Case FK_HOLE: KindPrefix = "Hole"
    Case FK_FILLET: KindPrefix = "Fillet"
    Case FK_CHAMFER: KindPrefix = "Chamfer"
    Case Else: KindPrefix = SM_KindPrefix(k)
    End Select
End Function

Public Function IsSketch(ByVal k As Integer) As Boolean
    IsSketch = (k = FK_SKETCH_RECT Or k = FK_SKETCH_CIRCLE)
End Function

' A fillet or a chamfer: something that finishes the top edges of an extrude.
' An extrude gets one of them, not both.
Public Function IsEdgeFinish(ByVal k As Integer) As Boolean
    IsEdgeFinish = (k = FK_FILLET Or k = FK_CHAMFER)
End Function

' Adds a feature and gives it a name like "Extrude2". Returns its index, 0 if full.
Public Function AddFeature(d As TDesign, f As TFeature) As Integer
    Dim i As Integer, n As Integer
    If d.Count >= MAX_FEATURES Then
        AddFeature = 0
        Exit Function
    End If
    For i = 1 To d.Count
        If KindPrefix(d.Features(i).Kind) = KindPrefix(f.Kind) Then n = n + 1
    Next i
    d.Count = d.Count + 1
    f.Name = KindPrefix(f.Kind) & CStr(n + 1)
    d.Features(d.Count) = f
    AddFeature = d.Count
End Function

Public Function FeatureName(d As TDesign, ByVal i As Integer) As String
    If i < 1 Or i > d.Count Then Exit Function
    FeatureName = RTrim$(d.Features(i).Name)
End Function

' The last sketch nobody has used yet, for Extrude and Revolve.
Public Function LastFreeSketch(d As TDesign) As Integer
    Dim i As Integer, j As Integer, used As Boolean
    For i = d.Count To 1 Step -1
        If IsSketch(d.Features(i).Kind) Then
            used = False
            For j = i + 1 To d.Count
                If d.Features(j).Ref = i And (d.Features(j).Kind = FK_EXTRUDE Or d.Features(j).Kind = FK_REVOLVE Or SM_UsesSketch(d.Features(j).Kind)) Then used = True
            Next j
            If Not used Then
                LastFreeSketch = i
                Exit Function
            End If
        End If
    Next i
End Function

' The last extrude, the default place for a hole.
Public Function LastSolid(d As TDesign) As Integer
    Dim i As Integer
    For i = d.Count To 1 Step -1
        If d.Features(i).Kind = FK_EXTRUDE Then
            LastSolid = i
            Exit Function
        End If
    Next i
End Function

' Marks feature i and everything built on it, directly or not. Returns how many.
Public Function MarkDependents(d As TDesign, ByVal i As Integer, gone() As Boolean) As Integer
    Dim j As Integer
    ReDim gone(0 To d.Count)
    gone(i) = True
    MarkDependents = 1
    For j = i + 1 To d.Count
        If d.Features(j).Ref >= 1 And d.Features(j).Ref <= d.Count Then
            If gone(d.Features(j).Ref) Then
                gone(j) = True
                MarkDependents = MarkDependents + 1
            End If
        End If
    Next j
End Function

' Removes the marked features and renumbers what the rest refer to.
Public Sub DeleteMarked(d As TDesign, gone() As Boolean)
    Dim i As Integer, n As Integer, newIndex() As Integer, blank As TFeature
    ReDim newIndex(0 To d.Count)
    For i = 1 To d.Count
        If Not gone(i) Then
            n = n + 1
            newIndex(i) = n
            d.Features(n) = d.Features(i)
            If d.Features(n).Ref >= 1 Then d.Features(n).Ref = newIndex(d.Features(n).Ref)
        End If
    Next i
    For i = n + 1 To d.Count
        d.Features(i) = blank
    Next i
    d.Count = n
End Sub

Public Function Describe(d As TDesign, ByVal i As Integer) As String
    Dim f As TFeature
    f = d.Features(i)
    Select Case f.Kind
    Case FK_SKETCH_RECT
        Describe = Fmt(f.P1) & " x " & Fmt(f.P2) & " mm at (" & Fmt(f.X) & ", " & Fmt(f.Y) & ")"
        If f.P3 > 0 Then Describe = Describe & ", R" & Fmt(f.P3) & " corners"
        Describe = Describe & SketchPlace(d, f)
    Case FK_SKETCH_CIRCLE
        Describe = "R " & Fmt(f.P1) & " mm at (" & Fmt(f.X) & ", " & Fmt(f.Y) & ")"
        Describe = Describe & SketchPlace(d, f)
    Case FK_EXTRUDE
        Describe = FeatureName(d, f.Ref) & ", " & Fmt(f.P1) & " mm"
    Case FK_REVOLVE
        Describe = FeatureName(d, f.Ref) & ", " & Fmt(f.P1) & Chr$(176) & " about Y"
    Case FK_FILLET, FK_CHAMFER
        If f.Kind = FK_FILLET Then Describe = "R " & Fmt(f.P1) & " mm, " Else Describe = Fmt(f.P1) & " mm x 45" & Chr$(176) & ", "
        Describe = Describe & EdgesText(f) & " of " & FeatureName(d, f.Ref)
    Case FK_FOREIGN
        Describe = "From SolidCraft. Not in SolidCraft 2000."
    Case FK_HOLE
        If f.P3 >= 2 Then Describe = Int(f.P3) & " x "
        Describe = Describe & "D " & Fmt(f.P1) & " mm on " & FeatureName(d, f.Ref) & " top face, "
        If f.P2 <= 0 Then
            Describe = Describe & "through all"
        Else
            Describe = Describe & Fmt(f.P2) & " mm deep"
        End If
        If f.P3 >= 2 Then
            If f.Reserved(1) > 0 Then
                Describe = Describe & ", on a " & Fmt(f.Reserved(1)) & " mm bolt circle"
            Else
                Describe = Describe & ", in a row " & Fmt(f.Reserved(2)) & " mm apart"
                If f.Reserved(3) <> 0 Then Describe = Describe & " at " & Fmt(f.Reserved(3)) & Chr$(176)
            End If
        End If
    Case Else
        If SM_IsSheetMetal(f.Kind) Then Describe = SM_Describe(d, i)
    End Select
End Function

' "top edges", "top front and back edges, bottom edges": what a fillet takes.
Private Function EdgesText(f As TFeature) As String
    Dim mt As Integer, mb As Integer
    mt = FinishTop(f): mb = FinishBottom(f)
    If mt > 0 Then EdgesText = "top" & SidesText(mt) & " edges"
    If mt > 0 And mb > 0 Then EdgesText = EdgesText & ", "
    If mb > 0 Then EdgesText = EdgesText & "bottom" & SidesText(mb) & " edges"
End Function

'  ", on Extrude1" / ", on Extrude1 +2" / ", Z 5" / "" for where a sketch sits.
Private Function SketchPlace(d As TDesign, f As TFeature) As String
    If f.Ref > 0 Then
        SketchPlace = ", on " & FeatureName(d, f.Ref)
        If f.Z <> 0 Then SketchPlace = SketchPlace & IIf(f.Z > 0, " +", " ") & Fmt(f.Z)
    ElseIf f.Z <> 0 Then
        SketchPlace = ", Z " & Fmt(f.Z)
    End If
End Function

Public Function Fmt(ByVal v As Double) As String
    If Y2KHappened Then
        Fmt = Y2KDimension()        ' two-digit years were a mistake
        Exit Function
    End If
    Fmt = Format$(v, "0.##")
    If Right$(Fmt, 1) = "." Then Fmt = Left$(Fmt, Len(Fmt) - 1)
End Function

' ---- Save and Open: Put and Get, straight from the Type ----

Public Function SaveDesign(d As TDesign, ByVal sPath As String) As Boolean
    Dim fh As Integer, sStep As String, bOpen As Boolean
    On Error GoTo Failed
    d.Magic = FILE_MAGIC
    d.Version = SaveVersion(d)
    sStep = "replacing the old file"
    If FileExists(sPath) Then Kill sPath
    sStep = "creating the file"
    fh = FreeFile
    Open sPath For Binary Access Write As #fh
    bOpen = True
    sStep = "writing the part"
    Put #fh, 1, d
    sStep = "closing the file"
    Close #fh
    bOpen = False
    SaveDesign = True
    Exit Function
Failed:
    MsgBox "Run-time error '" & Err.Number & "':" & vbCrLf & vbCrLf & Err.Description & vbCrLf & vbCrLf & _
        "(While " & sStep & ": " & sPath & ")", vbCritical, App.Title
    If bOpen Then
        On Error Resume Next
        Close #fh
    End If
End Function

' The oldest version that can hold this part, so a part without anything
' from Service Pack 1 still opens in SolidCraft 2000 1.0. One with a chamfer,
' a hole pattern or a fillet on chosen edges tells 1.0 to get Service Pack 1,
' which is the truth.
Private Function SaveVersion(d As TDesign) As Integer
    Dim i As Integer
    SaveVersion = FILE_VERSION_1_0
    For i = 1 To d.Count
        If d.Features(i).Kind = FK_CHAMFER Then SaveVersion = FILE_VERSION
        If d.Features(i).Kind = FK_HOLE And d.Features(i).P3 >= 2 Then SaveVersion = FILE_VERSION
        If IsEdgeFinish(d.Features(i).Kind) And (d.Features(i).Reserved(1) <> 0 Or d.Features(i).Reserved(2) <> 0) Then SaveVersion = FILE_VERSION
    Next i
End Function

' A SolidCraft 98 part has the same features in the same record, so upgrading
' it is changing four letters and a number. It gets a dialog anyway.
Private Sub Upgraded98(d As TDesign)
    If Not mFrom98 Then Exit Sub
    d.Magic = FILE_MAGIC
    d.Version = FILE_VERSION
    MsgBox "This part was made in SolidCraft 98, and has been upgraded to SolidCraft 2000." & vbCrLf & vbCrLf & _
        "Save it to keep the new format. SolidCraft 98 won't be able to open it again." & vbCrLf & _
        "(That's progress.)", vbInformation, App.Title
End Sub

Public Function LoadDesign(d As TDesign, ByVal sPath As String) As Boolean
    Dim fh As Integer, h As TFileHeader
    On Error GoTo Failed
    mFrom98 = False
    fh = FreeFile
    Open sPath For Binary Access Read As #fh
    Get #fh, 1, h
    If h.Magic = FILE_MAGIC_98 Then
        If h.Version > 5 Then h.Version = 99      ' there's no newer SolidCraft 98 part
        mFrom98 = True
    ElseIf h.Magic <> FILE_MAGIC Then
        Close #fh
        MsgBox "'" & sPath & "' is not a SolidCraft 2000 part.", vbExclamation, App.Title
        Exit Function
    End If
    If h.Version > FILE_VERSION Then
        Close #fh
        MsgBox "This file was saved by a newer version of SolidCraft." & vbCrLf & vbCrLf & _
            "Please upgrade to SolidCraft 2000 Service Pack 1.", vbExclamation, App.Title
        Exit Function
    End If
    If h.Version < 3 Then
        Close #fh
        MsgBox "This file was saved by an older version of SolidCraft." & vbCrLf & vbCrLf & _
            "Versions before 3 are not supported. They never were.", vbExclamation, App.Title
        Exit Function
    End If
    If h.Version = 4 Then
        Dim v4 As TDesignV4, j As Integer
        Get #fh, 1, v4
        Close #fh
        NewDesign d, RTrim$(v4.Title)
        d.Count = v4.Count
        For j = 1 To v4.Count
            d.Features(j).Kind = v4.Features(j).Kind
            d.Features(j).Name = v4.Features(j).Name
            d.Features(j).X = v4.Features(j).X
            d.Features(j).Y = v4.Features(j).Y
            d.Features(j).Z = v4.Features(j).Z
            d.Features(j).P1 = v4.Features(j).P1
            d.Features(j).P2 = v4.Features(j).P2
            d.Features(j).Ref = v4.Features(j).Ref
            d.Features(j).Suppressed = v4.Features(j).Suppressed
            d.Features(j).P3 = v4.Features(j).P3
        Next j
        LoadDesign = True        ' same features, a bigger record: nothing to tell anyone
        Upgraded98 d
        Exit Function
    End If
    If h.Version = 3 Then
        Dim old As TDesignV3, i As Integer
        Get #fh, 1, old
        Close #fh
        NewDesign d, RTrim$(old.Title)
        d.Count = old.Count
        For i = 1 To old.Count
            d.Features(i).Kind = old.Features(i).Kind
            d.Features(i).Name = old.Features(i).Name
            d.Features(i).X = old.Features(i).X
            d.Features(i).Y = old.Features(i).Y
            d.Features(i).Z = old.Features(i).Z
            d.Features(i).P1 = old.Features(i).P1
            d.Features(i).P2 = old.Features(i).P2
            d.Features(i).Ref = old.Features(i).Ref
            d.Features(i).Suppressed = old.Features(i).Suppressed
        Next i
        MsgBox "This file was saved by an older version of SolidCraft." & vbCrLf & vbCrLf & _
            "It has been converted. Save it to keep the new format." & vbCrLf & _
            "(This has never happened before.)", vbInformation, App.Title
        LoadDesign = True
        Upgraded98 d
        Exit Function
    End If
    Get #fh, 1, d
    Close #fh
    LoadDesign = True
    Upgraded98 d
    Exit Function
Failed:
    If fh <> 0 Then Close #fh
    MsgBox "Run-time error '" & Err.Number & "':" & vbCrLf & vbCrLf & Err.Description, vbCritical, App.Title
End Function
