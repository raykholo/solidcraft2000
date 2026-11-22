Attribute VB_Name = "modKernel"
' modKernel - the geometry kernel. Not B-rep: a bag of edges.
'
' Regenerate walks the feature list and turns it into 3D line segments,
' which the viewport projects and draws. Z is up, units are mm.
Option Explicit

Public Const PI As Double = 3.14159265358979
Private Const CIRCLE_SEGS As Integer = 32
Public Const FILLET_STEPS As Integer = 4     ' quarter-circle steps in a fillet's wireframe

Public Type TEdge
    X1 As Double
    Y1 As Double
    Z1 As Double
    X2 As Double
    Y2 As Double
    Z2 As Double
    Color As Long
End Type

Public Const COL_SKETCH As Long = &HC00000       ' blue (BGR)
Public Const COL_SKETCH_USED As Long = &HC0A080  ' faded, once a feature consumes it
Public Const COL_SOLID As Long = &H0&            ' black
Public Const COL_HOLE As Long = &H80&            ' dark red
Public Const COL_AXIS As Long = &H808080

' ---- Frames (Service Pack 1: sketches on side faces) ----
'
' Every sketch has a frame: where its X, Y and Z go in the world. A sketch on
' the ground or on a top face has the world's (and its Z, from SketchZ). A
' sketch on a side face of an extrude has that face's: X runs along the face
' (to the right, looking at it from outside), Y up it from the extrude's
' bottom, Z out of it. A body is built in its sketch's frame, and its edges
' and triangles are turned into the world as they're added.

Public Type TFrame
    OX As Double
    OY As Double
    OZ As Double
    UX As Double
    UY As Double
    UZ As Double
    VX As Double
    VY As Double
    VZ As Double
    WX As Double
    WY As Double
    WZ As Double
End Type

Public Const FACE_TOP As Integer = 0          ' a sketch's Reserved(1): which face of its extrude
Public Const FACE_FRONT As Integer = 1        ' -Y
Public Const FACE_RIGHT As Integer = 2        ' +X
Public Const FACE_BACK As Integer = 3         ' +Y
Public Const FACE_LEFT As Integer = 4         ' -X

Private mXf As TFrame
Private mXfOn As Boolean

Public Function WorldFrame() As TFrame
    Dim w As TFrame
    w.UX = 1: w.VY = 1: w.WZ = 1
    WorldFrame = w
End Function

' (x, y, z) in frame fr, in the world.
Public Sub ToWorld(fr As TFrame, ByVal x As Double, ByVal y As Double, ByVal z As Double, wx As Double, wy As Double, wz As Double)
    wx = fr.OX + fr.UX * x + fr.VX * y + fr.WX * z
    wy = fr.OY + fr.UY * x + fr.VY * y + fr.WY * z
    wz = fr.OZ + fr.UZ * x + fr.VZ * y + fr.WZ * z
End Sub

' From now on AddEdge takes points in frame fr (until ClearEdgeFrame).
Public Sub SetEdgeFrame(fr As TFrame)
    mXf = fr
    mXfOn = Not IsLevel(fr)
End Sub

Public Sub ClearEdgeFrame()
    mXfOn = False
End Sub

' The world's frame, or one only moved up or down from it?
Public Function IsLevel(fr As TFrame) As Boolean
    Const E As Double = 0.000000001
    IsLevel = Abs(fr.UX - 1) < E And Abs(fr.VY - 1) < E And Abs(fr.WZ - 1) < E And _
              Abs(fr.OX) < E And Abs(fr.OY) < E And Abs(fr.OZ) < E
End Function

Public Function SameFrame(a As TFrame, b As TFrame) As Boolean
    Const E As Double = 0.000001
    SameFrame = Abs(a.OX - b.OX) < E And Abs(a.OY - b.OY) < E And Abs(a.OZ - b.OZ) < E And _
        Abs(a.UX - b.UX) < E And Abs(a.UY - b.UY) < E And Abs(a.UZ - b.UZ) < E And _
        Abs(a.VX - b.VX) < E And Abs(a.VY - b.VY) < E And Abs(a.VZ - b.VZ) < E And _
        Abs(a.WX - b.WX) < E And Abs(a.WY - b.WY) < E And Abs(a.WZ - b.WZ) < E
End Function

' Which face of its extrude sketch f is on (FACE_TOP for the ground too).
Public Function SketchFace(f As TFeature) As Integer
    If f.Ref <= 0 Then Exit Function
    SketchFace = CInt(f.Reserved(1))
End Function

Public Function FaceName(ByVal face As Integer) As String
    Select Case face
    Case FACE_FRONT: FaceName = "front"
    Case FACE_RIGHT: FaceName = "right"
    Case FACE_BACK: FaceName = "back"
    Case FACE_LEFT: FaceName = "left"
    Case Else: FaceName = "top"
    End Select
End Function

' The frame of sketch i.
Public Function FrameOf(d As TDesign, ByVal i As Integer) As TFrame
    Dim f As TFeature, r As Integer, p As TFrame, s As TFeature, q As TFrame, z0 As Double
    f = d.Features(i)
    r = f.Ref
    If r < 1 Or r >= i Then FrameOf = WorldFrame: Exit Function
    If d.Features(r).Kind <> FK_EXTRUDE Then FrameOf = WorldFrame: Exit Function
    p = FrameOf(d, d.Features(r).Ref)            ' the extrude's own frame
    If SketchFace(f) = FACE_TOP Then FrameOf = p: Exit Function
    s = d.Features(d.Features(r).Ref)
    z0 = SketchZ(d, d.Features(r).Ref)           ' the extrude's bottom
    q = p
    Select Case SketchFace(f)
    Case FACE_FRONT
        ToWorld p, 0, s.Y, z0, q.OX, q.OY, q.OZ
        SetAxes q, p.UX, p.UY, p.UZ, p.WX, p.WY, p.WZ, -p.VX, -p.VY, -p.VZ
    Case FACE_RIGHT
        ToWorld p, s.X + s.P1, 0, z0, q.OX, q.OY, q.OZ
        SetAxes q, p.VX, p.VY, p.VZ, p.WX, p.WY, p.WZ, p.UX, p.UY, p.UZ
    Case FACE_BACK
        ToWorld p, 0, s.Y + s.P2, z0, q.OX, q.OY, q.OZ
        SetAxes q, -p.UX, -p.UY, -p.UZ, p.WX, p.WY, p.WZ, p.VX, p.VY, p.VZ
    Case FACE_LEFT
        ToWorld p, s.X, 0, z0, q.OX, q.OY, q.OZ
        SetAxes q, -p.VX, -p.VY, -p.VZ, p.WX, p.WY, p.WZ, -p.UX, -p.UY, -p.UZ
    End Select
    FrameOf = q
End Function

' The frame extrude, revolve or hole i is built in.
Public Function BodyFrame(d As TDesign, ByVal i As Integer) As TFrame
    Select Case d.Features(i).Kind
    Case FK_EXTRUDE, FK_REVOLVE
        BodyFrame = FrameOf(d, d.Features(i).Ref)
    Case FK_HOLE, FK_FILLET, FK_CHAMFER
        BodyFrame = FrameOf(d, d.Features(d.Features(i).Ref).Ref)
    Case Else
        BodyFrame = WorldFrame
    End Select
End Function

Private Sub SetAxes(q As TFrame, ByVal ux As Double, ByVal uy As Double, ByVal uz As Double, _
                    ByVal vx As Double, ByVal vy As Double, ByVal vz As Double, _
                    ByVal wx As Double, ByVal wy As Double, ByVal wz As Double)
    q.UX = ux: q.UY = uy: q.UZ = uz
    q.VX = vx: q.VY = vy: q.VZ = vz
    q.WX = wx: q.WY = wy: q.WZ = wz
End Sub

' Adds one segment to the list, growing it as needed. (Public for modSheetMetal.)
Public Sub AddEdge(e() As TEdge, n As Long, ByVal x1 As Double, ByVal y1 As Double, ByVal z1 As Double, _
                    ByVal x2 As Double, ByVal y2 As Double, ByVal z2 As Double, ByVal c As Long)
    If mXfOn Then
        ToWorld mXf, x1, y1, z1, x1, y1, z1
        ToWorld mXf, x2, y2, z2, x2, y2, z2
    End If
    If n > UBound(e) Then ReDim Preserve e(0 To UBound(e) * 2 + 1)
    e(n).X1 = x1: e(n).Y1 = y1: e(n).Z1 = z1
    e(n).X2 = x2: e(n).Y2 = y2: e(n).Z2 = z2
    e(n).Color = c
    n = n + 1
End Sub

Private Sub AddCircle(e() As TEdge, n As Long, ByVal cx As Double, ByVal cy As Double, ByVal z As Double, _
                      ByVal r As Double, ByVal c As Long)
    Dim i As Integer, a0 As Double, a1 As Double
    For i = 0 To CIRCLE_SEGS - 1
        a0 = 2 * PI * i / CIRCLE_SEGS
        a1 = 2 * PI * (i + 1) / CIRCLE_SEGS
        AddEdge e, n, cx + r * Cos(a0), cy + r * Sin(a0), z, cx + r * Cos(a1), cy + r * Sin(a1), z, c
    Next i
End Sub

' Profile points of a sketch, counter-clockwise, in its own plane. Returns how
' many. seam(j) is True where a solid built on it should show a vertical edge:
' the corners of a rectangle, the ends of each rounded corner, every 4th
' point of a circle. nCircle is how many points a full circle gets.
' bKeepCount: a sharp rectangle gets as many points as a rounded one (its
' "corners" have radius 0), so the outlines a fillet steps through all line up.
Public Function ProfilePoints(f As TFeature, px() As Double, py() As Double, seam() As Boolean, _
                              Optional ByVal nCircle As Integer = CIRCLE_SEGS, _
                              Optional ByVal bKeepCount As Boolean = False) As Integer
    Dim i As Integer, c As Integer, j As Integer, k As Integer, n As Integer
    Dim r As Double, cx As Double, cy As Double, a As Double
    If f.Kind = FK_SKETCH_RECT Then
        r = f.P3
        If r < 0 Then r = 0
        If r <= 0 And Not bKeepCount Then
            ReDim px(0 To 3): ReDim py(0 To 3): ReDim seam(0 To 3)
            px(0) = f.X: py(0) = f.Y
            px(1) = f.X + f.P1: py(1) = f.Y
            px(2) = f.X + f.P1: py(2) = f.Y + f.P2
            px(3) = f.X: py(3) = f.Y + f.P2
            For i = 0 To 3: seam(i) = True: Next i
            ProfilePoints = 4
            Exit Function
        End If
        k = nCircle \ 4                ' segments per rounded corner
        If k < 2 Then k = 2
        ReDim px(0 To 4 * (k + 1) - 1): ReDim py(0 To 4 * (k + 1) - 1): ReDim seam(0 To 4 * (k + 1) - 1)
        For c = 0 To 3
            Select Case c                ' corner centres, going round anticlockwise
            Case 0: cx = f.X + f.P1 - r: cy = f.Y + r
            Case 1: cx = f.X + f.P1 - r: cy = f.Y + f.P2 - r
            Case 2: cx = f.X + r: cy = f.Y + f.P2 - r
            Case 3: cx = f.X + r: cy = f.Y + r
            End Select
            For j = 0 To k
                a = (c * 90 - 90 + 90 * j / k) * PI / 180
                px(n) = cx + r * Cos(a): py(n) = cy + r * Sin(a)
                seam(n) = (j = 0 Or j = k)
                n = n + 1
            Next j
        Next c
        ProfilePoints = n
    Else
        ReDim px(0 To nCircle - 1): ReDim py(0 To nCircle - 1): ReDim seam(0 To nCircle - 1)
        For i = 0 To nCircle - 1
            px(i) = f.X + f.P1 * Cos(2 * PI * i / nCircle)
            py(i) = f.Y + f.P1 * Sin(2 * PI * i / nCircle)
            seam(i) = (i Mod 4) = 0
        Next i
        ProfilePoints = nCircle
    End If
End Function

' Is the circle (x, y, radius rr) wholly inside the sketch's outline?
Public Function ProfileContains(s As TFeature, ByVal x As Double, ByVal y As Double, ByVal rr As Double) As Boolean
    Dim r As Double, cx As Double, cy As Double
    Const EPS As Double = 0.000001
    If s.Kind = FK_SKETCH_CIRCLE Then
        ProfileContains = Sqr((x - s.X) ^ 2 + (y - s.Y) ^ 2) + rr <= s.P1 + EPS
        Exit Function
    End If
    If x - rr < s.X - EPS Or x + rr > s.X + s.P1 + EPS Or y - rr < s.Y - EPS Or y + rr > s.Y + s.P2 + EPS Then Exit Function
    r = s.P3
    If r > 0 Then
        ' in a corner square, the circle must also be inside the rounded corner
        cx = x: cy = y
        If x < s.X + r Then cx = s.X + r
        If x > s.X + s.P1 - r Then cx = s.X + s.P1 - r
        If y < s.Y + r Then cy = s.Y + r
        If y > s.Y + s.P2 - r Then cy = s.Y + s.P2 - r
        If Sqr((x - cx) ^ 2 + (y - cy) ^ 2) + rr > r + EPS Then
            If (x < s.X + r Or x > s.X + s.P1 - r) And (y < s.Y + r Or y > s.Y + s.P2 - r) Then Exit Function
        End If
    End If
    ProfileContains = True
End Function

' The height of sketch i. A sketch can sit on the top face of an extrude
' (its Ref); then Z is how far above that face it is, and it moves with it.
Public Function SketchZ(d As TDesign, ByVal i As Integer) As Double
    Dim r As Integer, z0 As Double, z1 As Double
    SketchZ = d.Features(i).Z
    r = d.Features(i).Ref
    If SketchFace(d.Features(i)) <> FACE_TOP Then Exit Function   ' on a side: Z is how far out
    If r >= 1 And r < i Then
        If d.Features(r).Kind = FK_EXTRUDE Then
            ExtrudeRange d, r, z0, z1
            SketchZ = SketchZ + z1
        End If
    End If
End Function

' The bottom and top of an extruded body.
Public Sub ExtrudeRange(d As TDesign, ByVal i As Integer, z0 As Double, z1 As Double)
    z0 = SketchZ(d, d.Features(i).Ref)
    z1 = z0 + d.Features(i).P1
End Sub

' ---- Hole patterns (Service Pack 1) ----
'
' One hole feature can be a row of holes or a bolt circle. P3 is how many
' (0 or 1: just the one). Reserved(1) is the bolt circle's diameter, 0 for a
' row; Reserved(2) is the spacing in a row; Reserved(3) is an angle in
' degrees: the row's direction, or where the first hole on the circle sits.
' A row starts at the hole's centre; a bolt circle goes round it.

Public Const MAX_PATTERN As Integer = 36

Public Function HoleCount(f As TFeature) As Integer
    If f.P3 >= 2 Then HoleCount = Int(f.P3) Else HoleCount = 1
End Function

' The centre of hole k (0 to HoleCount - 1) of hole feature f.
Public Sub HoleAt(f As TFeature, ByVal k As Integer, x As Double, y As Double)
    Dim a As Double, n As Integer
    n = HoleCount(f)
    a = f.Reserved(3) * PI / 180
    If n > 1 And f.Reserved(1) > 0 Then
        a = a + 2 * PI * k / n
        x = f.X + f.Reserved(1) / 2 * Cos(a)
        y = f.Y + f.Reserved(1) / 2 * Sin(a)
    Else
        x = f.X + k * f.Reserved(2) * Cos(a)
        y = f.Y + k * f.Reserved(2) * Sin(a)
    End If
End Sub

' Are all the holes of f inside the face s?
Public Function HolesInside(s As TFeature, f As TFeature) As Boolean
    Dim k As Integer, x As Double, y As Double
    For k = 0 To HoleCount(f) - 1
        HoleAt f, k, x, y
        If Not ProfileContains(s, x, y, f.P1 / 2) Then Exit Function
    Next k
    HolesInside = True
End Function

' Where hole i starts and stops. It starts on the top face of the body it was
' put on. A blind hole goes down its depth; "through all" keeps going through
' every extruded body stacked underneath that the hole fits inside. k is
' which hole of a pattern.
Public Sub HoleSpan(d As TDesign, ByVal i As Integer, zTop As Double, zBot As Double, Optional ByVal k As Integer = 0)
    Dim h As TFeature, j As Integer, b0 As Double, b1 As Double, moved As Boolean, tf As TFeature
    Dim hx As Double, hy As Double, hf As TFrame
    Const EPS As Double = 0.000001
    h = d.Features(i)
    HoleAt h, k, hx, hy
    hf = BodyFrame(d, h.Ref)
    ExtrudeRange d, h.Ref, zBot, zTop
    If h.P2 > 0 Then
        zBot = zTop - h.P2
        Exit Sub
    End If
    Do
        moved = False
        For j = 1 To i - 1
            If d.Features(j).Kind = FK_EXTRUDE And d.Features(j).Suppressed = 0 And j <> h.Ref Then
                If RefOk(d, j) And SameFrame(BodyFrame(d, j), hf) Then     ' only bodies facing the same way
                    ExtrudeRange d, j, b0, b1
                    If b0 < zBot - EPS And b1 >= zBot - EPS And b1 <= zTop + EPS Then
                        tf = TopFace(d, j)
                        If ProfileContains(tf, hx, hy, h.P1 / 2) Then
                            zBot = b0
                            moved = True
                        End If
                    End If
                End If
            End If
        Next j
    Loop While moved
End Sub

' ---- Fillets (new in 2000) ----
'
' A fillet rounds the top edges of one extrude with a quarter circle of
' radius P1. Going up the fillet, the body's outline shrinks: at angle a it is
' the sketch moved in by P1 * (1 - Cos(a)), at height top - P1 + P1 * Sin(a).
' Every outline SolidCraft 2000 can sketch is convex, so moving it in is
' exact: a rectangle gets smaller and its corner radius goes down (to a sharp
' corner if need be), a circle's radius goes down.
'
' A chamfer (Service Pack 1) is the same with a straight line for the quarter
' circle: at t of the way up it is moved in by P1 * t, at top - P1 + P1 * t.
' Everything below calls both a fillet: one per extrude, and P1 is how far in
' the top's edge is.

' How far in (inset) and how far up from where it starts (rise) the edge
' finish is, t of the way along it (0 to 1). r is its radius or distance.
Public Sub EdgeAt(ByVal bChamfer As Boolean, ByVal r As Double, ByVal t As Double, inset As Double, rise As Double)
    If bChamfer Then
        inset = r * t
        rise = r * t
    Else
        inset = r * (1 - Cos(t * PI / 2))
        rise = r * Sin(t * PI / 2)
    End If
End Sub

' How many bands it takes: a chamfer is flat, so one.
Public Function EdgeSteps(ByVal bChamfer As Boolean, ByVal nFillet As Integer) As Integer
    If bChamfer Then EdgeSteps = 1 Else EdgeSteps = nFillet
End Function

' Is extrude b's edge finish a chamfer?
Public Function IsChamfered(d As TDesign, ByVal b As Integer) As Boolean
    Dim j As Integer
    j = FilletOf(d, b)
    If j > 0 Then IsChamfered = (d.Features(j).Kind = FK_CHAMFER)
End Function

' The sketch s, moved in by off on every side.
Public Function InsetSketch(s As TFeature, ByVal off As Double) As TFeature
    Dim t As TFeature
    t = s
    If s.Kind = FK_SKETCH_RECT Then
        t.X = s.X + off: t.Y = s.Y + off
        t.P1 = s.P1 - 2 * off: t.P2 = s.P2 - 2 * off
        t.P3 = s.P3 - off
        If t.P3 < 0 Then t.P3 = 0
    Else
        t.P1 = s.P1 - off
    End If
    InsetSketch = t
End Function

' ---- Chosen edges (Service Pack 1) ----
'
' A fillet or chamfer takes whole sides of an extrude's top and bottom:
' bits 1 front (-Y), 2 right (+X), 4 back (+Y), 8 left (-X), added up.
' Reserved(1) is the top sides it leaves sharp (so 0, in every part from
' before Service Pack 1, is all of them) and Reserved(2) the bottom sides it
' takes. A circle, or a rectangle with rounded corners, is all or nothing:
' 15 or 0. Moving in only some sides of a sharp rectangle leaves a
' rectangle, so every cross-section is still exact.

Public Const SIDES_ALL As Integer = 15

Public Function FinishTop(f As TFeature) As Integer
    FinishTop = SIDES_ALL - (CInt(f.Reserved(1)) And SIDES_ALL)
End Function

Public Function FinishBottom(f As TFeature) As Integer
    FinishBottom = CInt(f.Reserved(2)) And SIDES_ALL
End Function

' The sketch s, moved in by off on the sides in mask.
Public Function SideInset(s As TFeature, ByVal mask As Integer, ByVal off As Double) As TFeature
    Dim t As TFeature
    If mask = 0 Or off = 0 Then
        SideInset = s
    ElseIf mask = SIDES_ALL Or s.Kind <> FK_SKETCH_RECT Or s.P3 > 0 Then
        SideInset = InsetSketch(s, off)
    Else
        t = s
        If mask And 1 Then t.Y = t.Y + off: t.P2 = t.P2 - off
        If mask And 2 Then t.P1 = t.P1 - off
        If mask And 4 Then t.P2 = t.P2 - off
        If mask And 8 Then t.X = t.X + off: t.P1 = t.P1 - off
        SideInset = t
    End If
End Function

' Can sketch s take these sides? A circle or a rounded rectangle, all or none.
Public Function SidesOk(s As TFeature, ByVal mask As Integer) As Boolean
    If mask < 0 Or mask > SIDES_ALL Then Exit Function
    If s.Kind = FK_SKETCH_RECT And s.P3 <= 0 Then
        SidesOk = True
    Else
        SidesOk = (mask = 0 Or mask = SIDES_ALL)
    End If
End Function

' Is r small enough for these sides of s? Something of the face has to stay.
Public Function SidesFit(s As TFeature, ByVal mask As Integer, ByVal r As Double) As Boolean
    Const EPS As Double = 0.000001
    Dim nx As Integer, ny As Integer
    If mask = 0 Then SidesFit = True: Exit Function
    If s.Kind = FK_SKETCH_CIRCLE Then SidesFit = (s.P1 > r + EPS): Exit Function
    If mask And 2 Then nx = nx + 1
    If mask And 8 Then nx = nx + 1
    If mask And 1 Then ny = ny + 1
    If mask And 4 Then ny = ny + 1
    If s.P3 > 0 Then nx = 2: ny = 2
    SidesFit = (s.P1 > nx * r + EPS) And (s.P2 > ny * r + EPS)
End Function

' Does fillet j fit its extrude? Its radius must leave some of each face it
' rounds, and fit in the extrude's height (twice, if it rounds both ends).
Public Function FilletFits(d As TDesign, ByVal j As Integer) As Boolean
    Dim f As TFeature, s As TFeature, b As Integer, mt As Integer, mb As Integer, n As Integer
    Const EPS As Double = 0.000001
    f = d.Features(j)
    b = f.Ref
    If b < 1 Or b >= j Then Exit Function
    If d.Features(b).Kind <> FK_EXTRUDE Then Exit Function
    If d.Features(b).Ref < 1 Or d.Features(b).Ref >= b Then Exit Function
    s = d.Features(d.Features(b).Ref)
    If s.Kind <> FK_SKETCH_RECT And s.Kind <> FK_SKETCH_CIRCLE Then Exit Function
    mt = FinishTop(f): mb = FinishBottom(f)
    If mt = 0 And mb = 0 Then Exit Function
    If Not SidesOk(s, mt) Or Not SidesOk(s, mb) Then Exit Function
    If mt <> 0 Then n = n + 1
    If mb <> 0 Then n = n + 1
    If f.P1 <= 0 Or n * f.P1 > Abs(d.Features(b).P1) + EPS Then Exit Function
    If Not SidesFit(s, mt, f.P1) Or Not SidesFit(s, mb, f.P1) Then Exit Function
    FilletFits = True
End Function

' "", " front and back", " front, right and left": which sides, for Describe.
Public Function SidesText(ByVal mask As Integer) As String
    Dim w(0 To 3) As String, n As Integer, k As Integer, nm As Variant
    If mask = SIDES_ALL Or mask = 0 Then Exit Function
    nm = Array("front", "right", "back", "left")
    For k = 0 To 3
        If mask And (2 ^ k) Then w(n) = nm(k): n = n + 1
    Next k
    For k = 0 To n - 1
        If k = 0 Then
            SidesText = " " & w(k)
        ElseIf k = n - 1 Then
            SidesText = SidesText & " and " & w(k)
        Else
            SidesText = SidesText & ", " & w(k)
        End If
    Next k
End Function

' The cross-sections an extrude's walls go through, bottom to top: up the
' bottom fillet, the straight part, up the top fillet. rz() the heights,
' rs() the outlines (each a sketch), key() where the wireframe draws a ring.
' Every outline gives ProfilePoints the same number of points.
Public Function ExtrudeRings(d As TDesign, ByVal b As Integer, ByVal steps As Integer, _
                             rz() As Double, rs() As TFeature, key() As Boolean) As Integer
    Dim s As TFeature, j As Integer, z0 As Double, z1 As Double, r As Double, m As Integer, n As Integer
    Dim mt As Integer, mb As Integer, bCh As Boolean, inset As Double, rise As Double, st As Integer
    s = d.Features(d.Features(b).Ref)
    ExtrudeRange d, b, z0, z1
    j = FilletOf(d, b)
    If j > 0 Then
        r = d.Features(j).P1: mt = FinishTop(d.Features(j)): mb = FinishBottom(d.Features(j))
        bCh = (d.Features(j).Kind = FK_CHAMFER)
    End If
    st = EdgeSteps(bCh, steps)
    ReDim rz(0 To 2 * st + 2): ReDim rs(0 To 2 * st + 2): ReDim key(0 To 2 * st + 2)
    If mb <> 0 Then
        For m = st To 1 Step -1                 ' from the bottom face up to the straight sides
            EdgeAt bCh, r, m / st, inset, rise
            If m = st Then inset = r: rise = r
            rz(n) = z0 + r - rise: rs(n) = SideInset(s, mb, inset): key(n) = (m = st)
            n = n + 1
        Next m
        rz(n) = z0 + r
    Else
        rz(n) = z0
    End If
    rs(n) = s: key(n) = True: n = n + 1
    If mt <> 0 Then
        rz(n) = z1 - r: rs(n) = s: key(n) = True: n = n + 1
        For m = 1 To st
            EdgeAt bCh, r, m / st, inset, rise
            If m = st Then inset = r: rise = r   ' exactly the top's edge
            rz(n) = z1 - r + rise: rs(n) = SideInset(s, mt, inset): key(n) = (m = st)
            n = n + 1
        Next m
    Else
        rz(n) = z1: rs(n) = s: key(n) = True: n = n + 1
    End If
    ExtrudeRings = n
End Function

' The fillet or chamfer on extrude b, or 0. Only the first one that fits counts.
Public Function FilletOf(d As TDesign, ByVal b As Integer) As Integer
    Dim j As Integer
    For j = b + 1 To d.Count
        If IsEdgeFinish(d.Features(j).Kind) And d.Features(j).Ref = b And d.Features(j).Suppressed = 0 Then
            If FilletFits(d, j) Then
                FilletOf = j
                Exit Function
            End If
        End If
    Next j
End Function

Public Function FilletRadius(d As TDesign, ByVal b As Integer) As Double
    Dim j As Integer
    j = FilletOf(d, b)
    If j > 0 Then FilletRadius = d.Features(j).P1
End Function

' The flat part of extrude b's top face, as a sketch: its own sketch, moved
' in by its fillet. Holes and anything standing on it have to fit in here.
Public Function TopFace(d As TDesign, ByVal b As Integer) As TFeature
    Dim s As TFeature, j As Integer
    s = d.Features(d.Features(b).Ref)
    j = FilletOf(d, b)
    If j = 0 Then TopFace = s Else TopFace = SideInset(s, FinishTop(d.Features(j)), d.Features(j).P1)
End Function

' The flat part of its bottom face, the same way.
Public Function BottomFace(d As TDesign, ByVal b As Integer) As TFeature
    Dim s As TFeature, j As Integer
    s = d.Features(d.Features(b).Ref)
    j = FilletOf(d, b)
    If j = 0 Then BottomFace = s Else BottomFace = SideInset(s, FinishBottom(d.Features(j)), d.Features(j).P1)
End Function

' Turns the design into edges. Returns the edge count.
Public Function Regenerate(d As TDesign, e() As TEdge) As Long
    Dim n As Long, i As Integer, j As Integer, k As Integer
    Dim f As TFeature, s As TFeature, b As TFeature
    Dim px() As Double, py() As Double, np As Integer, seam() As Boolean
    Dim z0 As Double, z1 As Double, zt As Double, r As Double
    Dim steps As Integer, a0 As Double, a1 As Double, sz As Double
    Dim used() As Boolean, fr As Double, zf As Double, m As Integer
    Dim qx() As Double, qy() As Double, qseam() As Boolean, ox() As Double, oy() As Double
    Dim bCh As Boolean, nst As Integer, in0 As Double, up0 As Double, in1 As Double, up1 As Double
    Dim hx As Double, hy As Double, rz() As Double, rs() As TFeature, rkey() As Boolean

    ReDim e(0 To 255)
    If d.Count > 0 Then ReDim used(1 To d.Count) Else ReDim used(0 To 0)
    For i = 1 To d.Count
        Select Case d.Features(i).Kind
        Case FK_EXTRUDE, FK_REVOLVE, FK_SM_BASE
            If d.Features(i).Ref >= 1 And d.Features(i).Ref <= d.Count Then used(d.Features(i).Ref) = True
        End Select
    Next i

    For i = 1 To d.Count
        f = d.Features(i)
        If f.Suppressed = 0 And RefOk(d, i) Then
            Select Case f.Kind                  ' each in its own frame
            Case FK_SKETCH_RECT, FK_SKETCH_CIRCLE: SetEdgeFrame FrameOf(d, i)
            Case FK_EXTRUDE, FK_REVOLVE, FK_HOLE: SetEdgeFrame BodyFrame(d, i)
            Case Else: ClearEdgeFrame
            End Select
            Select Case f.Kind
            Case FK_SKETCH_RECT
                sz = SketchZ(d, i)
                np = ProfilePoints(f, px, py, seam)
                For j = 0 To np - 1
                    k = (j + 1) Mod np
                    AddEdge e, n, px(j), py(j), sz, px(k), py(k), sz, IIf(used(i), COL_SKETCH_USED, COL_SKETCH)
                Next j
            Case FK_SKETCH_CIRCLE
                AddCircle e, n, f.X, f.Y, SketchZ(d, i), f.P1, IIf(used(i), COL_SKETCH_USED, COL_SKETCH)

            Case FK_EXTRUDE
                s = d.Features(f.Ref)
                ExtrudeRange d, i, z0, z1
                fr = FilletRadius(d, i)
                If fr <= 0 Then
                    np = ProfilePoints(s, px, py, seam)
                    For j = 0 To np - 1
                        k = (j + 1) Mod np
                        AddEdge e, n, px(j), py(j), z0, px(k), py(k), z0, COL_SOLID
                        AddEdge e, n, px(j), py(j), z1, px(k), py(k), z1, COL_SOLID
                        If seam(j) Then AddEdge e, n, px(j), py(j), z0, px(j), py(j), z1, COL_SOLID
                    Next j
                Else
                    ' the rings it goes through (bottom fillet, straight sides,
                    ' top fillet): a ring where a face starts or ends, and the
                    ' quarter circles (or the chamfer's slopes) at each seam
                    nst = ExtrudeRings(d, i, FILLET_STEPS, rz, rs, rkey)
                    np = ProfilePoints(s, px, py, seam, CIRCLE_SEGS, True)
                    For m = 0 To nst - 1
                        ProfilePoints rs(m), qx, qy, qseam, CIRCLE_SEGS, True
                        If rkey(m) Then
                            For j = 0 To np - 1
                                k = (j + 1) Mod np
                                AddEdge e, n, qx(j), qy(j), rz(m), qx(k), qy(k), rz(m), COL_SOLID
                            Next j
                        End If
                        If m > 0 Then
                            For j = 0 To np - 1
                                If seam(j) Then AddEdge e, n, ox(j), oy(j), rz(m - 1), qx(j), qy(j), rz(m), COL_SOLID
                            Next j
                        End If
                        ox = qx: oy = qy
                    Next m
                End If

            Case FK_REVOLVE
                ' Spin the profile about the Y axis of its plane.
                s = d.Features(f.Ref)
                sz = SketchZ(d, f.Ref)
                np = ProfilePoints(s, px, py, seam)
                steps = Int(Abs(f.P1) / 15 + 0.5)
                If steps < 1 Then steps = 1
                For k = 0 To steps
                    a0 = (f.P1 * PI / 180) * k / steps
                    ' a copy of the profile every 45 degrees and at both ends
                    If k = 0 Or k = steps Or (k Mod 3) = 0 Then
                        For j = 0 To np - 1
                            AddEdge e, n, px(j) * Cos(a0), py(j), sz - px(j) * Sin(a0), _
                                px((j + 1) Mod np) * Cos(a0), py((j + 1) Mod np), sz - px((j + 1) Mod np) * Sin(a0), COL_SOLID
                        Next j
                    End If
                    ' the path each profile corner traces
                    If k < steps Then
                        a1 = (f.P1 * PI / 180) * (k + 1) / steps
                        For j = 0 To np - 1
                            If seam(j) And (np <= 4 Or s.Kind = FK_SKETCH_RECT Or (j Mod 8) = 0) Then
                                AddEdge e, n, px(j) * Cos(a0), py(j), sz - px(j) * Sin(a0), _
                                    px(j) * Cos(a1), py(j), sz - px(j) * Sin(a1), COL_SOLID
                            End If
                        Next j
                    End If
                Next k
                AddEdge e, n, 0, -10, sz, 0, 10 + MaxAbs(py, np), sz, COL_AXIS

            Case FK_HOLE
                r = f.P1 / 2
                For m = 0 To HoleCount(f) - 1
                    HoleSpan d, i, zt, z0, m
                    HoleAt f, m, hx, hy
                    AddCircle e, n, hx, hy, zt, r, COL_HOLE
                    AddCircle e, n, hx, hy, z0, r, COL_HOLE
                    For j = 0 To 3
                        a0 = j * PI / 2
                        AddEdge e, n, hx + r * Cos(a0), hy + r * Sin(a0), zt, hx + r * Cos(a0), hy + r * Sin(a0), z0, COL_HOLE
                    Next j
                Next m
            Case Else
                If SM_IsSheetMetal(f.Kind) Then SM_Edges d, i, e, n
            End Select
        End If
    Next i
    ClearEdgeFrame
    Regenerate = n
End Function

' A feature is only drawn if what it is built on exists and comes before it.
Public Function RefOk(d As TDesign, ByVal i As Integer) As Boolean
    Dim f As TFeature, tf As TFeature, zt As Double, zb As Double, z0 As Double, z1 As Double
    f = d.Features(i)
    Select Case f.Kind
    Case FK_SKETCH_RECT, FK_SKETCH_CIRCLE
        If f.Ref = 0 Then
            RefOk = True
        ElseIf f.Ref >= 1 And f.Ref < i Then
            If d.Features(f.Ref).Kind = FK_EXTRUDE Then
                If SketchFace(f) = FACE_TOP Then
                    RefOk = RefOk(d, f.Ref)
                ElseIf SketchFace(f) >= FACE_FRONT And SketchFace(f) <= FACE_LEFT Then
                    ' a side face: the extrude has to have flat sides
                    If d.Features(d.Features(f.Ref).Ref).Kind = FK_SKETCH_RECT Then RefOk = RefOk(d, f.Ref)
                End If
            End If
        End If
    Case FK_EXTRUDE, FK_REVOLVE
        If f.Ref >= 1 And f.Ref < i Then RefOk = IsSketch(d.Features(f.Ref).Kind)
    Case FK_FOREIGN
        RefOk = True          ' nothing to build, nothing to break
    Case FK_SM_BASE, FK_SM_EDGE, FK_SM_FLAT
        RefOk = SM_RefOk(d, i)
    Case FK_FILLET, FK_CHAMFER
        If f.Ref >= 1 And f.Ref < i Then
            If d.Features(f.Ref).Kind = FK_EXTRUDE Then
                If RefOk(d, f.Ref) Then RefOk = (FilletOf(d, f.Ref) = i)
            End If
        End If
    Case FK_HOLE
        If f.Ref >= 1 And f.Ref < i Then
            If d.Features(f.Ref).Kind = FK_EXTRUDE Then
                If RefOk(d, f.Ref) Then
                    tf = TopFace(d, f.Ref)
                    RefOk = HolesInside(tf, f)
                    ' one that comes out through a filleted bottom has to miss the fillet too
                    If RefOk And FilletOf(d, f.Ref) > 0 Then
                        If FinishBottom(d.Features(FilletOf(d, f.Ref))) <> 0 Then
                            HoleSpan d, i, zt, zb
                            ExtrudeRange d, f.Ref, z0, z1
                            If zb < z0 + d.Features(FilletOf(d, f.Ref)).P1 Then RefOk = HolesInside(BottomFace(d, f.Ref), f)
                        End If
                    End If
                End If
            End If
        End If
    End Select
End Function

Private Function MaxAbs(v() As Double, ByVal n As Integer) As Double
    Dim i As Integer
    For i = 0 To n - 1
        If Abs(v(i)) > MaxAbs Then MaxAbs = Abs(v(i))
    Next i
End Function
