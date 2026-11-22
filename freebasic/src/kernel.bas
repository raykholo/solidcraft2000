' kernel.bas - turns the features into edges (the "geometry kernel").
' A line-for-line port of the Windows version's modKernel: frames for
' sketches on side faces, hole patterns, fillets and chamfers on chosen
' edges (all exact: the outline of an extrude is moved in as it goes up).

Const PI = 3.14159265358979
Const CIRCLE_SEGS = 32
Const FILLET_STEPS = 4             ' quarter-circle steps in a fillet's wireframe
Const MAX_PATTERN = 36

Type TEdge
    X1 As Double
    Y1 As Double
    Z1 As Double
    X2 As Double
    Y2 As Double
    Z2 As Double
    Col As ULong
End Type

Const COL_SKETCH = &hFF0000C0          ' blue
Const COL_SKETCH_USED = &hFF80A0C0     ' faded, once a feature consumes it
Const COL_SOLID = &hFF000000           ' black
Const COL_HOLE = &hFF800000            ' dark red
Const COL_AXIS = &hFF808080
Const COL_BEND = &hFF008000            ' sheet metal bend lines: dark green

Declare Function RefOk(ByRef d As TDesign, ByVal i As Long) As Boolean
Declare Sub ExtrudeRange(ByRef d As TDesign, ByVal i As Long, ByRef z0 As Double, ByRef z1 As Double)
Declare Function FilletOf(ByRef d As TDesign, ByVal b As Long) As Long
Declare Function TopFace(ByRef d As TDesign, ByVal b As Long) As TFeature
Declare Sub SM_Edges(ByRef d As TDesign, ByVal i As Long, e() As TEdge, ByRef n As Long)
Declare Function SM_RefOk(ByRef d As TDesign, ByVal i As Long) As Boolean

Sub CopyArr(dst() As Double, src() As Double, ByVal n As Long)
    Dim i As Long
    ReDim dst(0 To IIf(n > 0, n - 1, 0))
    For i = 0 To n - 1: dst(i) = src(i): Next
End Sub

' ---- Frames (Service Pack 1: sketches on side faces) ----
'
' Every sketch has a frame: where its X, Y and Z go in the world. A sketch on
' the ground or on a top face has the world's (and its Z, from SketchZ). A
' sketch on a side face of an extrude has that face's: X runs along the face
' (to the right, looking at it from outside), Y up it from the extrude's
' bottom, Z out of it. A body is built in its sketch's frame, and its edges
' and triangles are turned into the world as they're added.

Type TFrame
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

Dim Shared mXf As TFrame
Dim Shared mXfOn As Boolean

Function WorldFrame() As TFrame
    Dim w As TFrame
    w.UX = 1: w.VY = 1: w.WZ = 1
    Return w
End Function

' (x, y, z) in frame fr, in the world.
Sub ToWorld(ByRef fr As TFrame, ByVal x As Double, ByVal y As Double, ByVal z As Double, ByRef wx As Double, ByRef wy As Double, ByRef wz As Double)
    wx = fr.OX + fr.UX * x + fr.VX * y + fr.WX * z
    wy = fr.OY + fr.UY * x + fr.VY * y + fr.WY * z
    wz = fr.OZ + fr.UZ * x + fr.VZ * y + fr.WZ * z
End Sub

' The world's frame, or one only moved up or down from it?
Function IsLevel(ByRef fr As TFrame) As Boolean
    Const E = 0.000000001
    Return Abs(fr.UX - 1) < E And Abs(fr.VY - 1) < E And Abs(fr.WZ - 1) < E And _
           Abs(fr.OX) < E And Abs(fr.OY) < E And Abs(fr.OZ) < E
End Function

' From now on AddEdge takes points in frame fr (until ClearEdgeFrame).
Sub SetEdgeFrame(ByRef fr As TFrame)
    mXf = fr
    mXfOn = Not IsLevel(fr)
End Sub

Sub ClearEdgeFrame()
    mXfOn = False
End Sub

Function SameFrame(ByRef a As TFrame, ByRef b As TFrame) As Boolean
    Const E = 0.000001
    Return Abs(a.OX - b.OX) < E And Abs(a.OY - b.OY) < E And Abs(a.OZ - b.OZ) < E And _
        Abs(a.UX - b.UX) < E And Abs(a.UY - b.UY) < E And Abs(a.UZ - b.UZ) < E And _
        Abs(a.VX - b.VX) < E And Abs(a.VY - b.VY) < E And Abs(a.VZ - b.VZ) < E And _
        Abs(a.WX - b.WX) < E And Abs(a.WY - b.WY) < E And Abs(a.WZ - b.WZ) < E
End Function

Sub SetAxes(ByRef q As TFrame, ByVal ux As Double, ByVal uy As Double, ByVal uz As Double, _
            ByVal vx As Double, ByVal vy As Double, ByVal vz As Double, _
            ByVal wx As Double, ByVal wy As Double, ByVal wz As Double)
    q.UX = ux: q.UY = uy: q.UZ = uz
    q.VX = vx: q.VY = vy: q.VZ = vz
    q.WX = wx: q.WY = wy: q.WZ = wz
End Sub

Declare Function SketchZ(ByRef d As TDesign, ByVal i As Long) As Double

' The frame of sketch i.
Function FrameOf(ByRef d As TDesign, ByVal i As Long) As TFrame
    Dim As Long r
    Dim As TFrame p, q
    Dim As TFeature s
    Dim As Double z0
    r = d.F(i).Ref
    If r < 1 Or r >= i Then Return WorldFrame()
    If d.F(r).Kind <> FK_EXTRUDE Then Return WorldFrame()
    p = FrameOf(d, d.F(r).Ref)            ' the extrude's own frame
    If SketchFace(d.F(i)) = FACE_TOP Then Return p
    s = d.F(d.F(r).Ref)
    z0 = SketchZ(d, d.F(r).Ref)           ' the extrude's bottom
    q = p
    Select Case SketchFace(d.F(i))
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
    Return q
End Function

' The frame extrude, revolve or hole i is built in.
Function BodyFrame(ByRef d As TDesign, ByVal i As Long) As TFrame
    Select Case d.F(i).Kind
    Case FK_EXTRUDE, FK_REVOLVE
        Return FrameOf(d, d.F(i).Ref)
    Case FK_HOLE, FK_FILLET, FK_CHAMFER
        Return FrameOf(d, d.F(d.F(i).Ref).Ref)
    End Select
    Return WorldFrame()
End Function

' Adds one segment to the list, growing it as needed. (Also for sheet metal.)
Sub AddEdge(e() As TEdge, ByRef n As Long, ByVal x1 As Double, ByVal y1 As Double, ByVal z1 As Double, _
            ByVal x2 As Double, ByVal y2 As Double, ByVal z2 As Double, ByVal c As ULong)
    If mXfOn Then
        ToWorld mXf, x1, y1, z1, x1, y1, z1
        ToWorld mXf, x2, y2, z2, x2, y2, z2
    End If
    If n > UBound(e) Then ReDim Preserve e(0 To UBound(e) * 2 + 1)
    e(n).X1 = x1: e(n).Y1 = y1: e(n).Z1 = z1
    e(n).X2 = x2: e(n).Y2 = y2: e(n).Z2 = z2
    e(n).Col = c
    n += 1
End Sub

Sub AddCircle(e() As TEdge, ByRef n As Long, ByVal cx As Double, ByVal cy As Double, ByVal z As Double, _
              ByVal r As Double, ByVal c As ULong)
    Dim i As Long, a0 As Double, a1 As Double
    For i = 0 To CIRCLE_SEGS - 1
        a0 = 2 * PI * i / CIRCLE_SEGS
        a1 = 2 * PI * (i + 1) / CIRCLE_SEGS
        AddEdge e(), n, cx + r * Cos(a0), cy + r * Sin(a0), z, cx + r * Cos(a1), cy + r * Sin(a1), z, c
    Next i
End Sub

' Profile points of a sketch, counter-clockwise, in its own plane. Returns how
' many. seam(j) is True where a solid built on it should show a vertical edge.
' bKeepCount: a sharp rectangle gets as many points as a rounded one (its
' "corners" have radius 0), so the outlines a fillet steps through all line up.
Function ProfilePoints(ByRef f As TFeature, px() As Double, py() As Double, seam() As Boolean, _
                       ByVal nCircle As Long = CIRCLE_SEGS, ByVal bKeepCount As Boolean = False) As Long
    Dim As Long i, c, j, k, n
    Dim As Double r, cx, cy, a
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
            Return 4
        End If
        k = nCircle \ 4
        If k < 2 Then k = 2
        ReDim px(0 To 4 * (k + 1) - 1): ReDim py(0 To 4 * (k + 1) - 1): ReDim seam(0 To 4 * (k + 1) - 1)
        For c = 0 To 3
            Select Case c
            Case 0: cx = f.X + f.P1 - r: cy = f.Y + r
            Case 1: cx = f.X + f.P1 - r: cy = f.Y + f.P2 - r
            Case 2: cx = f.X + r: cy = f.Y + f.P2 - r
            Case 3: cx = f.X + r: cy = f.Y + r
            End Select
            For j = 0 To k
                a = (c * 90 - 90 + 90 * j / k) * PI / 180
                px(n) = cx + r * Cos(a): py(n) = cy + r * Sin(a)
                seam(n) = (j = 0 Or j = k)
                n += 1
            Next j
        Next c
        Return n
    Else
        ReDim px(0 To nCircle - 1): ReDim py(0 To nCircle - 1): ReDim seam(0 To nCircle - 1)
        For i = 0 To nCircle - 1
            px(i) = f.X + f.P1 * Cos(2 * PI * i / nCircle)
            py(i) = f.Y + f.P1 * Sin(2 * PI * i / nCircle)
            seam(i) = (i Mod 4) = 0
        Next i
        Return nCircle
    End If
End Function

' Is the circle (x, y, radius rr) wholly inside the sketch's outline?
Function ProfileContains(ByRef s As TFeature, ByVal x As Double, ByVal y As Double, ByVal rr As Double) As Boolean
    Dim As Double r, cx, cy
    Const EPS = 0.000001
    If s.Kind = FK_SKETCH_CIRCLE Then
        Return Sqr((x - s.X) ^ 2 + (y - s.Y) ^ 2) + rr <= s.P1 + EPS
    End If
    If x - rr < s.X - EPS Or x + rr > s.X + s.P1 + EPS Or y - rr < s.Y - EPS Or y + rr > s.Y + s.P2 + EPS Then Return False
    r = s.P3
    If r > 0 Then
        cx = x: cy = y
        If x < s.X + r Then cx = s.X + r
        If x > s.X + s.P1 - r Then cx = s.X + s.P1 - r
        If y < s.Y + r Then cy = s.Y + r
        If y > s.Y + s.P2 - r Then cy = s.Y + s.P2 - r
        If Sqr((x - cx) ^ 2 + (y - cy) ^ 2) + rr > r + EPS Then
            If (x < s.X + r Or x > s.X + s.P1 - r) And (y < s.Y + r Or y > s.Y + s.P2 - r) Then Return False
        End If
    End If
    Return True
End Function

' The height of sketch i. A sketch can sit on the top face of an extrude
' (its Ref); then Z is how far above that face it is, and it moves with it.
Function SketchZ(ByRef d As TDesign, ByVal i As Long) As Double
    Dim As Long r
    Dim As Double z0, z1, z = d.F(i).Z
    r = d.F(i).Ref
    If SketchFace(d.F(i)) <> FACE_TOP Then Return z       ' on a side: Z is how far out
    If r >= 1 And r < i Then
        If d.F(r).Kind = FK_EXTRUDE Then
            ExtrudeRange d, r, z0, z1
            z += z1
        End If
    End If
    Return z
End Function

' The bottom and top of an extruded body.
Sub ExtrudeRange(ByRef d As TDesign, ByVal i As Long, ByRef z0 As Double, ByRef z1 As Double)
    z0 = SketchZ(d, d.F(i).Ref)
    z1 = z0 + d.F(i).P1
End Sub

' ---- Hole patterns (Service Pack 1) ----
'
' One hole feature can be a row of holes or a bolt circle. P3 is how many
' (0 or 1: just the one). Rsv(1) is the bolt circle's diameter, 0 for a
' row; Rsv(2) is the spacing in a row; Rsv(3) is an angle in degrees: the
' row's direction, or where the first hole on the circle sits. A row starts
' at the hole's centre; a bolt circle goes round it.

' The centre of hole k (0 to HoleCount - 1) of hole feature f.
Sub HoleAt(ByRef f As TFeature, ByVal k As Long, ByRef x As Double, ByRef y As Double)
    Dim As Double a
    Dim As Long n = HoleCount(f)
    a = f.Rsv(3) * PI / 180
    If n > 1 And f.Rsv(1) > 0 Then
        a += 2 * PI * k / n
        x = f.X + f.Rsv(1) / 2 * Cos(a)
        y = f.Y + f.Rsv(1) / 2 * Sin(a)
    Else
        x = f.X + k * f.Rsv(2) * Cos(a)
        y = f.Y + k * f.Rsv(2) * Sin(a)
    End If
End Sub

' Are all the holes of f inside the face s?
Function HolesInside(ByRef s As TFeature, ByRef f As TFeature) As Boolean
    Dim As Long k
    Dim As Double x, y
    For k = 0 To HoleCount(f) - 1
        HoleAt f, k, x, y
        If Not ProfileContains(s, x, y, f.P1 / 2) Then Return False
    Next k
    Return True
End Function

' Where hole i starts and stops. It starts on the top face of the body it was
' put on. A blind hole goes down its depth; "through all" keeps going through
' every extruded body stacked underneath that the hole fits inside. k is
' which hole of a pattern.
Sub HoleSpan(ByRef d As TDesign, ByVal i As Long, ByRef zTop As Double, ByRef zBot As Double, ByVal k As Long = 0)
    Dim As Long j
    Dim As Double b0, b1, hx, hy
    Dim As Boolean moved
    Dim As TFeature h, tf
    Dim As TFrame hf
    Const EPS = 0.000001
    h = d.F(i)
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
            If d.F(j).Kind = FK_EXTRUDE And d.F(j).Suppressed = 0 And j <> h.Ref Then
                If RefOk(d, j) AndAlso SameFrame(BodyFrame(d, j), hf) Then     ' only bodies facing the same way
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

' ---- Fillets (new in 2000) and chamfers (Service Pack 1) ----
'
' A fillet rounds the top edges of one extrude with a quarter circle of
' radius P1. Going up the fillet, the body's outline shrinks: at angle a it is
' the sketch moved in by P1 * (1 - Cos(a)), at height top - P1 + P1 * Sin(a).
' Every outline SolidCraft 2000 can sketch is convex, so moving it in is
' exact: a rectangle gets smaller and its corner radius goes down (to a sharp
' corner if need be), a circle's radius goes down.
'
' A chamfer is the same with a straight line for the quarter circle: at t of
' the way up it is moved in by P1 * t, at top - P1 + P1 * t.

' How far in (inset) and how far up from where it starts (rise) the edge
' finish is, t of the way along it (0 to 1). r is its radius or distance.
Sub EdgeAt(ByVal bChamfer As Boolean, ByVal r As Double, ByVal t As Double, ByRef inset As Double, ByRef rise As Double)
    If bChamfer Then
        inset = r * t
        rise = r * t
    Else
        inset = r * (1 - Cos(t * PI / 2))
        rise = r * Sin(t * PI / 2)
    End If
End Sub

' How many bands it takes: a chamfer is flat, so one.
Function EdgeSteps(ByVal bChamfer As Boolean, ByVal nFillet As Long) As Long
    Return IIf(bChamfer, 1, nFillet)
End Function

' Is extrude b's edge finish a chamfer?
Function IsChamfered(ByRef d As TDesign, ByVal b As Long) As Boolean
    Dim j As Long = FilletOf(d, b)
    If j > 0 Then Return d.F(j).Kind = FK_CHAMFER
    Return False
End Function

' The sketch s, moved in by off on every side.
Function InsetSketch(ByRef s As TFeature, ByVal off As Double) As TFeature
    Dim t As TFeature = s
    If s.Kind = FK_SKETCH_RECT Then
        t.X = s.X + off: t.Y = s.Y + off
        t.P1 = s.P1 - 2 * off: t.P2 = s.P2 - 2 * off
        t.P3 = s.P3 - off
        If t.P3 < 0 Then t.P3 = 0
    Else
        t.P1 = s.P1 - off
    End If
    Return t
End Function

' ---- Chosen edges (Service Pack 1) ----
'
' A fillet or chamfer takes whole sides of an extrude's top and bottom:
' bits 1 front (-Y), 2 right (+X), 4 back (+Y), 8 left (-X), added up.
' Rsv(1) is the top sides it leaves sharp (so 0, in every part from before
' Service Pack 1, is all of them) and Rsv(2) the bottom sides it takes. A
' circle, or a rectangle with rounded corners, is all or nothing: 15 or 0.
' Moving in only some sides of a sharp rectangle leaves a rectangle, so
' every cross-section is still exact.

' The sketch s, moved in by off on the sides in mask.
Function SideInset(ByRef s As TFeature, ByVal mask As Long, ByVal off As Double) As TFeature
    Dim t As TFeature
    If mask = 0 Or off = 0 Then
        Return s
    ElseIf mask = SIDES_ALL Or s.Kind <> FK_SKETCH_RECT Or s.P3 > 0 Then
        Return InsetSketch(s, off)
    Else
        t = s
        If mask And 1 Then t.Y = t.Y + off: t.P2 = t.P2 - off
        If mask And 2 Then t.P1 = t.P1 - off
        If mask And 4 Then t.P2 = t.P2 - off
        If mask And 8 Then t.X = t.X + off: t.P1 = t.P1 - off
        Return t
    End If
End Function

' Can sketch s take these sides? A circle or a rounded rectangle, all or none.
Function SidesOk(ByRef s As TFeature, ByVal mask As Long) As Boolean
    If mask < 0 Or mask > SIDES_ALL Then Return False
    If s.Kind = FK_SKETCH_RECT And s.P3 <= 0 Then Return True
    Return (mask = 0 Or mask = SIDES_ALL)
End Function

' Is r small enough for these sides of s? Something of the face has to stay.
Function SidesFit(ByRef s As TFeature, ByVal mask As Long, ByVal r As Double) As Boolean
    Const EPS = 0.000001
    Dim As Long nx, ny
    If mask = 0 Then Return True
    If s.Kind = FK_SKETCH_CIRCLE Then Return s.P1 > r + EPS
    If mask And 2 Then nx += 1
    If mask And 8 Then nx += 1
    If mask And 1 Then ny += 1
    If mask And 4 Then ny += 1
    If s.P3 > 0 Then nx = 2: ny = 2
    Return (s.P1 > nx * r + EPS) And (s.P2 > ny * r + EPS)
End Function

' Does fillet j fit its extrude? Its radius must leave some of each face it
' rounds, and fit in the extrude's height (twice, if it rounds both ends).
Function FilletFits(ByRef d As TDesign, ByVal j As Long) As Boolean
    Dim As TFeature f, s
    Dim As Long b, mt, mb, n
    Const EPS = 0.000001
    f = d.F(j)
    b = f.Ref
    If b < 1 Or b >= j Then Return False
    If d.F(b).Kind <> FK_EXTRUDE Then Return False
    If d.F(b).Ref < 1 Or d.F(b).Ref >= b Then Return False
    s = d.F(d.F(b).Ref)
    If s.Kind <> FK_SKETCH_RECT And s.Kind <> FK_SKETCH_CIRCLE Then Return False
    mt = FinishTop(f): mb = FinishBottom(f)
    If mt = 0 And mb = 0 Then Return False
    If Not SidesOk(s, mt) Or Not SidesOk(s, mb) Then Return False
    If mt <> 0 Then n += 1
    If mb <> 0 Then n += 1
    If f.P1 <= 0 Or n * f.P1 > Abs(d.F(b).P1) + EPS Then Return False
    If Not SidesFit(s, mt, f.P1) Or Not SidesFit(s, mb, f.P1) Then Return False
    Return True
End Function

' The cross-sections an extrude's walls go through, bottom to top: up the
' bottom fillet, the straight part, up the top fillet. rz() the heights,
' rs() the outlines (each a sketch), key() where the wireframe draws a ring.
' Every outline gives ProfilePoints the same number of points.
Function ExtrudeRings(ByRef d As TDesign, ByVal b As Long, ByVal steps As Long, _
                      rz() As Double, rs() As TFeature, key() As Boolean) As Long
    Dim As TFeature s
    Dim As Long j, m, n, mt, mb, st
    Dim As Double z0, z1, r, inset, rise
    Dim As Boolean bCh
    s = d.F(d.F(b).Ref)
    ExtrudeRange d, b, z0, z1
    j = FilletOf(d, b)
    If j > 0 Then
        r = d.F(j).P1: mt = FinishTop(d.F(j)): mb = FinishBottom(d.F(j))
        bCh = (d.F(j).Kind = FK_CHAMFER)
    End If
    st = EdgeSteps(bCh, steps)
    ReDim rz(0 To 2 * st + 2): ReDim rs(0 To 2 * st + 2): ReDim key(0 To 2 * st + 2)
    If mb <> 0 Then
        For m = st To 1 Step -1                 ' from the bottom face up to the straight sides
            EdgeAt bCh, r, m / st, inset, rise
            If m = st Then inset = r: rise = r
            rz(n) = z0 + r - rise: rs(n) = SideInset(s, mb, inset): key(n) = (m = st)
            n += 1
        Next m
        rz(n) = z0 + r
    Else
        rz(n) = z0
    End If
    rs(n) = s: key(n) = True: n += 1
    If mt <> 0 Then
        rz(n) = z1 - r: rs(n) = s: key(n) = True: n += 1
        For m = 1 To st
            EdgeAt bCh, r, m / st, inset, rise
            If m = st Then inset = r: rise = r   ' exactly the top's edge
            rz(n) = z1 - r + rise: rs(n) = SideInset(s, mt, inset): key(n) = (m = st)
            n += 1
        Next m
    Else
        rz(n) = z1: rs(n) = s: key(n) = True: n += 1
    End If
    Return n
End Function

' The fillet or chamfer on extrude b, or 0. Only the first one that fits counts.
Function FilletOf(ByRef d As TDesign, ByVal b As Long) As Long
    Dim j As Long
    For j = b + 1 To d.Count
        If IsEdgeFinish(d.F(j).Kind) And d.F(j).Ref = b And d.F(j).Suppressed = 0 Then
            If FilletFits(d, j) Then Return j
        End If
    Next j
    Return 0
End Function

Function FilletRadius(ByRef d As TDesign, ByVal b As Long) As Double
    Dim j As Long = FilletOf(d, b)
    If j > 0 Then Return d.F(j).P1
    Return 0
End Function

' The flat part of extrude b's top face, as a sketch: its own sketch, moved
' in by its fillet. Holes and anything standing on it have to fit in here.
Function TopFace(ByRef d As TDesign, ByVal b As Long) As TFeature
    Dim s As TFeature = d.F(d.F(b).Ref)
    Dim j As Long = FilletOf(d, b)
    If j = 0 Then Return s
    Return SideInset(s, FinishTop(d.F(j)), d.F(j).P1)
End Function

' The flat part of its bottom face, the same way.
Function BottomFace(ByRef d As TDesign, ByVal b As Long) As TFeature
    Dim s As TFeature = d.F(d.F(b).Ref)
    Dim j As Long = FilletOf(d, b)
    If j = 0 Then Return s
    Return SideInset(s, FinishBottom(d.F(j)), d.F(j).P1)
End Function

Function MaxAbs(v() As Double, ByVal n As Long) As Double
    Dim As Long i
    Dim As Double m
    For i = 0 To n - 1
        If Abs(v(i)) > m Then m = Abs(v(i))
    Next i
    Return m
End Function

' Turns the design into edges. Returns the edge count.
Function Regenerate(ByRef d As TDesign, e() As TEdge) As Long
    Dim As Long n, i, j, k, np, steps, m, nst
    Dim As Double z0, z1, zt, r, a0, a1, sz, fil, hx, hy
    Dim As Double px(Any), py(Any), qx(Any), qy(Any), ox(Any), oy(Any), rz(Any)
    Dim As Boolean seam(Any), qseam(Any), rkey(Any)
    Dim As TFeature f, s, rs(Any)
    ReDim e(0 To 255)
    Dim used(0 To MAX_FEATURES) As Boolean
    For i = 1 To d.Count
        Select Case d.F(i).Kind
        Case FK_EXTRUDE, FK_REVOLVE, FK_SM_BASE
            If d.F(i).Ref >= 1 And d.F(i).Ref <= d.Count Then used(d.F(i).Ref) = True
        End Select
    Next i

    For i = 1 To d.Count
        f = d.F(i)
        If f.Suppressed = 0 AndAlso RefOk(d, i) Then
            Select Case f.Kind                  ' each in its own frame
            Case FK_SKETCH_RECT, FK_SKETCH_CIRCLE: SetEdgeFrame FrameOf(d, i)
            Case FK_EXTRUDE, FK_REVOLVE, FK_HOLE: SetEdgeFrame BodyFrame(d, i)
            Case Else: ClearEdgeFrame
            End Select
            Select Case f.Kind
            Case FK_SKETCH_RECT
                sz = SketchZ(d, i)
                np = ProfilePoints(f, px(), py(), seam())
                For j = 0 To np - 1
                    k = (j + 1) Mod np
                    AddEdge e(), n, px(j), py(j), sz, px(k), py(k), sz, IIf(used(i), COL_SKETCH_USED, COL_SKETCH)
                Next j
            Case FK_SKETCH_CIRCLE
                AddCircle e(), n, f.X, f.Y, SketchZ(d, i), f.P1, IIf(used(i), COL_SKETCH_USED, COL_SKETCH)

            Case FK_EXTRUDE
                s = d.F(f.Ref)
                ExtrudeRange d, i, z0, z1
                fil = FilletRadius(d, i)
                If fil <= 0 Then
                    np = ProfilePoints(s, px(), py(), seam())
                    For j = 0 To np - 1
                        k = (j + 1) Mod np
                        AddEdge e(), n, px(j), py(j), z0, px(k), py(k), z0, COL_SOLID
                        AddEdge e(), n, px(j), py(j), z1, px(k), py(k), z1, COL_SOLID
                        If seam(j) Then AddEdge e(), n, px(j), py(j), z0, px(j), py(j), z1, COL_SOLID
                    Next j
                Else
                    ' the rings it goes through (bottom fillet, straight sides,
                    ' top fillet): a ring where a face starts or ends, and the
                    ' quarter circles (or the chamfer's slopes) at each seam
                    nst = ExtrudeRings(d, i, FILLET_STEPS, rz(), rs(), rkey())
                    np = ProfilePoints(s, px(), py(), seam(), CIRCLE_SEGS, True)
                    For m = 0 To nst - 1
                        ProfilePoints rs(m), qx(), qy(), qseam(), CIRCLE_SEGS, True
                        If rkey(m) Then
                            For j = 0 To np - 1
                                k = (j + 1) Mod np
                                AddEdge e(), n, qx(j), qy(j), rz(m), qx(k), qy(k), rz(m), COL_SOLID
                            Next j
                        End If
                        If m > 0 Then
                            For j = 0 To np - 1
                                If seam(j) Then AddEdge e(), n, ox(j), oy(j), rz(m - 1), qx(j), qy(j), rz(m), COL_SOLID
                            Next j
                        End If
                        CopyArr ox(), qx(), UBound(qx) + 1: CopyArr oy(), qy(), UBound(qy) + 1
                    Next m
                End If

            Case FK_REVOLVE
                ' Spin the profile about the Y axis of its plane.
                s = d.F(f.Ref)
                sz = SketchZ(d, f.Ref)
                np = ProfilePoints(s, px(), py(), seam())
                steps = Int(Abs(f.P1) / 15 + 0.5)
                If steps < 1 Then steps = 1
                For k = 0 To steps
                    a0 = (f.P1 * PI / 180) * k / steps
                    ' a copy of the profile every 45 degrees and at both ends
                    If k = 0 Or k = steps Or (k Mod 3) = 0 Then
                        For j = 0 To np - 1
                            AddEdge e(), n, px(j) * Cos(a0), py(j), sz - px(j) * Sin(a0), _
                                px((j + 1) Mod np) * Cos(a0), py((j + 1) Mod np), sz - px((j + 1) Mod np) * Sin(a0), COL_SOLID
                        Next j
                    End If
                    ' the path each profile corner traces
                    If k < steps Then
                        a1 = (f.P1 * PI / 180) * (k + 1) / steps
                        For j = 0 To np - 1
                            If seam(j) AndAlso (np <= 4 Or s.Kind = FK_SKETCH_RECT Or (j Mod 8) = 0) Then
                                AddEdge e(), n, px(j) * Cos(a0), py(j), sz - px(j) * Sin(a0), _
                                    px(j) * Cos(a1), py(j), sz - px(j) * Sin(a1), COL_SOLID
                            End If
                        Next j
                    End If
                Next k
                AddEdge e(), n, 0, -10, sz, 0, 10 + MaxAbs(py(), np), sz, COL_AXIS

            Case FK_HOLE
                r = f.P1 / 2
                For m = 0 To HoleCount(f) - 1
                    HoleSpan d, i, zt, z0, m
                    HoleAt f, m, hx, hy
                    AddCircle e(), n, hx, hy, zt, r, COL_HOLE
                    AddCircle e(), n, hx, hy, z0, r, COL_HOLE
                    For j = 0 To 3
                        a0 = j * PI / 2
                        AddEdge e(), n, hx + r * Cos(a0), hy + r * Sin(a0), zt, hx + r * Cos(a0), hy + r * Sin(a0), z0, COL_HOLE
                    Next j
                Next m
            Case Else
                If SM_IsSheetMetal(f.Kind) Then SM_Edges d, i, e(), n
            End Select
        End If
    Next i
    ClearEdgeFrame
    Return n
End Function

' A feature is only drawn if what it is built on exists and comes before it.
Function RefOk(ByRef d As TDesign, ByVal i As Long) As Boolean
    Dim As TFeature f, tf
    Dim As Double zt, zb, z0, z1
    Dim As Boolean ok
    f = d.F(i)
    Select Case f.Kind
    Case FK_SKETCH_RECT, FK_SKETCH_CIRCLE
        If f.Ref = 0 Then Return True
        If f.Ref >= 1 And f.Ref < i Then
            If d.F(f.Ref).Kind = FK_EXTRUDE Then
                If SketchFace(f) = FACE_TOP Then
                    Return RefOk(d, f.Ref)
                ElseIf SketchFace(f) >= FACE_FRONT And SketchFace(f) <= FACE_LEFT Then
                    ' a side face: the extrude has to have flat sides
                    If d.F(d.F(f.Ref).Ref).Kind = FK_SKETCH_RECT Then Return RefOk(d, f.Ref)
                End If
            End If
        End If
    Case FK_EXTRUDE, FK_REVOLVE
        If f.Ref >= 1 And f.Ref < i Then Return IsSketch(d.F(f.Ref).Kind)
    Case FK_FOREIGN
        Return True          ' nothing to build, nothing to break
    Case FK_SM_BASE, FK_SM_EDGE, FK_SM_FLAT
        Return SM_RefOk(d, i)
    Case FK_FILLET, FK_CHAMFER
        If f.Ref >= 1 And f.Ref < i Then
            If d.F(f.Ref).Kind = FK_EXTRUDE Then
                If RefOk(d, f.Ref) Then Return (FilletOf(d, f.Ref) = i)
            End If
        End If
    Case FK_HOLE
        If f.Ref >= 1 And f.Ref < i Then
            If d.F(f.Ref).Kind = FK_EXTRUDE Then
                If RefOk(d, f.Ref) Then
                    tf = TopFace(d, f.Ref)
                    ok = HolesInside(tf, f)
                    ' one that comes out through a filleted bottom has to miss the fillet too
                    If ok And FilletOf(d, f.Ref) > 0 Then
                        If FinishBottom(d.F(FilletOf(d, f.Ref))) <> 0 Then
                            HoleSpan d, i, zt, zb
                            ExtrudeRange d, f.Ref, z0, z1
                            If zb < z0 + d.F(FilletOf(d, f.Ref)).P1 Then ok = HolesInside(BottomFace(d, f.Ref), f)
                        End If
                    End If
                    Return ok
                End If
            End If
        End If
    End Select
    Return False
End Function
