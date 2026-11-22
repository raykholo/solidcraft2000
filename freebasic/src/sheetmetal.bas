' sheetmetal.bas - sheet metal, new in 2000 (some assembly required). A port
' of the Windows version's modSheetMetal, a small reference engine: a base
' flange, edge flanges with one bend each, bend relief, and a flat pattern
' written as a DXF with an 8.3 file name.
'
' The features, and what their fields mean:
'
'   FK_SM_BASE  Base Flange. Ref = a rectangle sketch (square corners).
'               P1 = thickness T, P2 = inside bend radius R, P3 = K-factor.
'               Every bend in the part uses this T, R and K.
'   FK_SM_EDGE  Edge Flange. Ref = the base flange. X = which edge of it
'               (0 front, 1 right, 2 back, 3 left). P1 = length L of the
'               straight leg after the bend. P2 = bend angle in degrees, up
'               from flat (90 = upright). P3 = bend relief (SM_RELIEF_...).
'               Z = relief width (0 = T).
'   FK_SM_FLAT  Flat Pattern. Ref = the base flange. Info = the DXF file it
'               wrote. While it isn't suppressed, the part is shown flat.
'
' The reference engine's limits, all of them on purpose: one bend per edge
' flange, only on the four edges of the base, no flanges on flanges, no
' corner treatment (two flanges meeting at a corner are kept apart by their
' relief), relief cut only in the flat pattern, and every bend the same R.

Const SM_RELIEF_NONE = 0
Const SM_RELIEF_RECT = 1
Const SM_RELIEF_OBROUND = 2
Const SM_RELIEF_TEAR = 3

Const WIRE_STEPS = 4           ' steps round a bend in the wireframe
Const MESH_STEPS = 8           ' and in the solid

' The bend table the wizard last made, for new base flanges.
Dim Shared SMTableSet As Boolean
Dim Shared SMTableName As String
Dim Shared SMTableT As Double
Dim Shared SMTableR As Double
Dim Shared SMTableK As Double

' ---- what kind of thing ----

Function SM_IsSheetMetal(ByVal k As Long) As Boolean
    Return k = FK_SM_BASE Or k = FK_SM_EDGE Or k = FK_SM_FLAT
End Function

Function SM_UsesSketch(ByVal k As Long) As Boolean
    Return k = FK_SM_BASE
End Function

Function SM_KindName(ByVal k As Long) As String
    Select Case k
    Case FK_SM_BASE: Return "Base Flange"
    Case FK_SM_EDGE: Return "Edge Flange"
    Case FK_SM_FLAT: Return "Flat Pattern"
    End Select
    Return ""
End Function

Function SM_KindPrefix(ByVal k As Long) As String
    Select Case k
    Case FK_SM_BASE: Return "BaseFlange"
    Case FK_SM_EDGE: Return "EdgeFlange"
    Case FK_SM_FLAT: Return "FlatPattern"
    End Select
    Return ""
End Function

Function EdgeName(ByVal e As Long) As String
    Select Case e
    Case 0: Return "front"
    Case 1: Return "right"
    Case 2: Return "back"
    Case 3: Return "left"
    End Select
    Return ""
End Function

Function ReliefName(ByVal r As Long) As String
    Select Case r
    Case SM_RELIEF_NONE: Return "no relief"
    Case SM_RELIEF_RECT: Return "rectangular relief"
    Case SM_RELIEF_OBROUND: Return "obround relief"
    Case SM_RELIEF_TEAR: Return "tear relief"
    End Select
    Return ""
End Function

' ---- does it build ----

Declare Function BaseOk(ByRef d As TDesign, ByVal i As Long, ByVal b As Long) As Boolean
Declare Function SideLength(ByRef d As TDesign, ByVal b As Long, ByVal e As Long) As Double
Declare Function Margin(ByRef d As TDesign, ByVal i As Long) As Double

Function SM_RefOk(ByRef d As TDesign, ByVal i As Long) As Boolean
    Dim As TFeature f, s
    Dim As Long j
    f = d.F(i)
    Select Case f.Kind
    Case FK_SM_BASE
        If f.Ref < 1 Or f.Ref >= i Then Return False
        s = d.F(f.Ref)
        If s.Kind <> FK_SKETCH_RECT Or s.P3 > 0 Then Return False
        If Not IsLevel(FrameOf(d, f.Ref)) Then Return False     ' sheet metal lies flat
        If Not RefOk(d, f.Ref) Then Return False
        Return (f.P1 > 0 And f.P2 >= 0 And f.P3 >= 0 And f.P3 <= 1)
    Case FK_SM_EDGE
        If Not BaseOk(d, i, f.Ref) Then Return False
        If f.X <> Int(f.X) Or f.X < 0 Or f.X > 3 Then Return False
        If f.P1 <= 0 Or f.P2 <= 0 Or f.P2 > 180 Then Return False
        If f.P3 <> Int(f.P3) Or f.P3 < 0 Or f.P3 > 3 Or f.Z < 0 Then Return False
        If SideLength(d, f.Ref, f.X) - 2 * Margin(d, i) <= 0 Then Return False
        ' one flange to an edge: the first one gets it
        For j = f.Ref + 1 To i - 1
            If d.F(j).Kind = FK_SM_EDGE And d.F(j).Ref = f.Ref And d.F(j).X = f.X And d.F(j).Suppressed = 0 Then Return False
        Next j
        Return True
    Case FK_SM_FLAT
        Return BaseOk(d, i, f.Ref)
    End Select
    Return False
End Function

Function BaseOk(ByRef d As TDesign, ByVal i As Long, ByVal b As Long) As Boolean
    If b < 1 Or b >= i Then Return False
    If d.F(b).Kind <> FK_SM_BASE Or d.F(b).Suppressed <> 0 Then Return False
    Return SM_RefOk(d, b)
End Function

' ---- the numbers of the geometry ----

' The base's rectangle, and its bottom and top.
Sub BaseBox(ByRef d As TDesign, ByVal b As Long, ByRef x As Double, ByRef y As Double, ByRef w As Double, ByRef h As Double, ByRef z0 As Double, ByRef z1 As Double)
    Dim s As TFeature = d.F(d.F(b).Ref)
    x = s.X: y = s.Y: w = s.P1: h = s.P2
    z0 = SketchZ(d, d.F(b).Ref)
    z1 = z0 + d.F(b).P1
End Sub

Function SideLength(ByRef d As TDesign, ByVal b As Long, ByVal e As Long) As Double
    Dim s As TFeature = d.F(d.F(b).Ref)
    If e = 0 Or e = 2 Then Return s.P1
    Return s.P2
End Function

' Where edge e starts, which way it runs (u), and which way is out (v), going
' anticlockwise round the base seen from above.
Sub EdgeFrame(ByRef d As TDesign, ByVal b As Long, ByVal e As Long, ByRef ox As Double, ByRef oy As Double, _
              ByRef ux As Double, ByRef uy As Double, ByRef vx As Double, ByRef vy As Double)
    Dim As Double x, y, w, h, z0, z1
    BaseBox d, b, x, y, w, h, z0, z1
    Select Case e
    Case 0: ox = x: oy = y: ux = 1: uy = 0: vx = 0: vy = -1
    Case 1: ox = x + w: oy = y: ux = 0: uy = 1: vx = 1: vy = 0
    Case 2: ox = x + w: oy = y + h: ux = -1: uy = 0: vx = 0: vy = 1
    Case Else: ox = x: oy = y + h: ux = 0: uy = -1: vx = -1: vy = 0
    End Select
End Sub

Function ReliefWidth(ByRef d As TDesign, ByVal i As Long) As Double
    Dim w As Double = d.F(i).Z
    If w <= 0 Then w = d.F(d.F(i).Ref).P1
    Return w
End Function

' How far in from each end of its edge a flange stops: nothing without relief,
' otherwise room for the relief and as much again, so flanges on neighbouring
' edges don't meet.
Function Margin(ByRef d As TDesign, ByVal i As Long) As Double
    If d.F(i).P3 = SM_RELIEF_NONE Then Return 0
    Return 2 * ReliefWidth(d, i)
End Function

' The length of the bend, measured along the K-factor line.
Function BendAllowance(ByVal angleDeg As Double, ByVal r As Double, ByVal k As Double, ByVal t As Double) As Double
    Return angleDeg * PI / 180 * (r + k * t)
End Function

' Is the part being shown flat?
Function IsFlat(ByRef d As TDesign, ByVal b As Long) As Boolean
    Dim j As Long
    For j = b + 1 To d.Count
        If d.F(j).Kind = FK_SM_FLAT And d.F(j).Ref = b And d.F(j).Suppressed = 0 Then
            If SM_RefOk(d, j) Then Return True
        End If
    Next j
    Return False
End Function

' A flange's cross-section, seen along its edge: the outside (bottom) of the
' sheet in ov/ow and the inside in iv/iw, point for point, v out from the
' edge and w up. Folded: round the bend, then the straight leg. Flat: one
' strip as long as the bend allowance and the leg. Returns how many points;
' nBend is where the bend ends.
Function Section(ByRef d As TDesign, ByVal i As Long, ByVal bFlat As Boolean, ByVal steps As Long, _
                 ov() As Double, ow() As Double, iv() As Double, iw() As Double, ByRef nBend As Long) As Long
    Dim As Long b, j
    Dim As Double t, r, k, a, L, x, y, w, h, z0, z1, th, ba
    b = d.F(i).Ref
    t = d.F(b).P1: r = d.F(b).P2: k = d.F(b).P3
    a = d.F(i).P2 * PI / 180
    L = d.F(i).P1
    BaseBox d, b, x, y, w, h, z0, z1
    If bFlat Then
        ba = BendAllowance(d.F(i).P2, r, k, t)
        ReDim ov(0 To 2): ReDim ow(0 To 2): ReDim iv(0 To 2): ReDim iw(0 To 2)
        ov(0) = 0: ov(1) = ba: ov(2) = ba + L
        For j = 0 To 2
            iv(j) = ov(j): ow(j) = z0: iw(j) = z1
        Next j
        nBend = 1
        Return 3
    End If
    ReDim ov(0 To steps + 1): ReDim ow(0 To steps + 1): ReDim iv(0 To steps + 1): ReDim iw(0 To steps + 1)
    ' the bend turns about a line R above the top face, at the edge
    For j = 0 To steps
        th = a * j / steps
        ov(j) = (r + t) * Sin(th): ow(j) = z1 + r - (r + t) * Cos(th)
        iv(j) = r * Sin(th): iw(j) = z1 + r - r * Cos(th)
    Next j
    ov(steps + 1) = ov(steps) + L * Cos(a): ow(steps + 1) = ow(steps) + L * Sin(a)
    iv(steps + 1) = iv(steps) + L * Cos(a): iw(steps + 1) = iw(steps) + L * Sin(a)
    nBend = steps
    Return steps + 2
End Function

' ---- the wireframe ----

' One line, given in an edge's own u, v, w.
Sub Wire(e() As TEdge, ByRef n As Long, ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
         ByVal vx As Double, ByVal vy As Double, ByVal u1 As Double, ByVal v1 As Double, ByVal w1 As Double, _
         ByVal u2 As Double, ByVal v2 As Double, ByVal w2 As Double, ByVal c As ULong)
    AddEdge e(), n, ox + u1 * ux + v1 * vx, oy + u1 * uy + v1 * vy, w1, ox + u2 * ux + v2 * vx, oy + u2 * uy + v2 * vy, w2, c
End Sub

Sub WireBox(e() As TEdge, ByRef n As Long, ByVal x As Double, ByVal y As Double, ByVal w As Double, ByVal h As Double, _
            ByVal z0 As Double, ByVal z1 As Double)
    Dim As Double px(0 To 3), py(0 To 3)
    Dim As Long j, k
    px(0) = x: py(0) = y: px(1) = x + w: py(1) = y: px(2) = x + w: py(2) = y + h: px(3) = x: py(3) = y + h
    For j = 0 To 3
        k = (j + 1) Mod 4
        AddEdge e(), n, px(j), py(j), z0, px(k), py(k), z0, COL_SOLID
        AddEdge e(), n, px(j), py(j), z1, px(k), py(k), z1, COL_SOLID
        AddEdge e(), n, px(j), py(j), z0, px(j), py(j), z1, COL_SOLID
    Next j
End Sub

Sub SM_Edges(ByRef d As TDesign, ByVal i As Long, e() As TEdge, ByRef n As Long)
    Dim As TFeature f
    Dim As Double x, y, w, h, z0, z1, ox, oy, ux, uy, vx, vy, ua, ub
    Dim As Double ov(Any), ow(Any), iv(Any), iw(Any)
    Dim As Long m, nb, j
    Dim As Boolean bFlat
    f = d.F(i)
    Select Case f.Kind
    Case FK_SM_BASE
        BaseBox d, i, x, y, w, h, z0, z1
        WireBox e(), n, x, y, w, h, z0, z1
    Case FK_SM_EDGE
        bFlat = IsFlat(d, f.Ref)
        m = Section(d, i, bFlat, WIRE_STEPS, ov(), ow(), iv(), iw(), nb)
        EdgeFrame d, f.Ref, f.X, ox, oy, ux, uy, vx, vy
        ua = Margin(d, i): ub = SideLength(d, f.Ref, f.X) - ua
        ' both ends of the flange, and the lines along it
        For j = 0 To m - 2
            Wire e(), n, ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ua, ov(j + 1), ow(j + 1), COL_SOLID
            Wire e(), n, ox, oy, ux, uy, vx, vy, ua, iv(j), iw(j), ua, iv(j + 1), iw(j + 1), COL_SOLID
            Wire e(), n, ox, oy, ux, uy, vx, vy, ub, ov(j), ow(j), ub, ov(j + 1), ow(j + 1), COL_SOLID
            Wire e(), n, ox, oy, ux, uy, vx, vy, ub, iv(j), iw(j), ub, iv(j + 1), iw(j + 1), COL_SOLID
        Next j
        Wire e(), n, ox, oy, ux, uy, vx, vy, ua, ov(m - 1), ow(m - 1), ua, iv(m - 1), iw(m - 1), COL_SOLID
        Wire e(), n, ox, oy, ux, uy, vx, vy, ub, ov(m - 1), ow(m - 1), ub, iv(m - 1), iw(m - 1), COL_SOLID
        For j = 0 To m - 1
            If j = 0 Or j = nb Or j = m - 1 Then
                Wire e(), n, ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ub, ov(j), ow(j), IIf(bFlat And j < m - 1, COL_BEND, COL_SOLID)
                Wire e(), n, ox, oy, ux, uy, vx, vy, ua, iv(j), iw(j), ub, iv(j), iw(j), IIf(bFlat And j < m - 1, COL_BEND, COL_SOLID)
            End If
        Next j
    End Select
End Sub

' ---- the solid ----

' Two triangles, corners given in an edge's own u, v, w, in order round the quad.
Sub Quad(ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
         ByVal vx As Double, ByVal vy As Double, _
         ByVal u1 As Double, ByVal v1 As Double, ByVal w1 As Double, ByVal u2 As Double, ByVal v2 As Double, ByVal w2 As Double, _
         ByVal u3 As Double, ByVal v3 As Double, ByVal w3 As Double, ByVal u4 As Double, ByVal v4 As Double, ByVal w4 As Double, _
         ByVal body As Long)
    Dim As Double x1, y1, x2, y2, x3, y3, x4, y4
    x1 = ox + u1 * ux + v1 * vx: y1 = oy + u1 * uy + v1 * vy
    x2 = ox + u2 * ux + v2 * vx: y2 = oy + u2 * uy + v2 * vy
    x3 = ox + u3 * ux + v3 * vx: y3 = oy + u3 * uy + v3 * vy
    x4 = ox + u4 * ux + v4 * vx: y4 = oy + u4 * uy + v4 * vy
    AddTri x1, y1, w1, x2, y2, w2, x3, y3, w3, body
    AddTri x1, y1, w1, x3, y3, w3, x4, y4, w4, body
End Sub

' A strip of sheet swept along an edge from u = ua to u = ub: its outside
' face, its inside face, its two long edges, and its two ends.
Sub Prism(ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
          ByVal vx As Double, ByVal vy As Double, ByVal ua As Double, ByVal ub As Double, _
          ov() As Double, ow() As Double, iv() As Double, iw() As Double, ByVal m As Long, ByVal body As Long)
    Dim j As Long
    For j = 0 To m - 2
        Quad ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ub, ov(j), ow(j), ub, ov(j + 1), ow(j + 1), ua, ov(j + 1), ow(j + 1), body
        Quad ox, oy, ux, uy, vx, vy, ua, iv(j), iw(j), ua, iv(j + 1), iw(j + 1), ub, iv(j + 1), iw(j + 1), ub, iv(j), iw(j), body
        Quad ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ua, ov(j + 1), ow(j + 1), ua, iv(j + 1), iw(j + 1), ua, iv(j), iw(j), body
        Quad ox, oy, ux, uy, vx, vy, ub, ov(j), ow(j), ub, iv(j), iw(j), ub, iv(j + 1), iw(j + 1), ub, ov(j + 1), ow(j + 1), body
    Next j
    Quad ox, oy, ux, uy, vx, vy, ua, ov(0), ow(0), ua, iv(0), iw(0), ub, iv(0), iw(0), ub, ov(0), ow(0), body
    Quad ox, oy, ux, uy, vx, vy, ua, ov(m - 1), ow(m - 1), ub, ov(m - 1), ow(m - 1), ub, iv(m - 1), iw(m - 1), ua, iv(m - 1), iw(m - 1), body
End Sub

Sub SM_Mesh(ByRef d As TDesign, ByVal i As Long)
    Dim As TFeature f
    Dim As Double x, y, w, h, z0, z1, ox, oy, ux, uy, vx, vy, ua, ub
    Dim As Double ov(Any), ow(Any), iv(Any), iw(Any)
    Dim As Long m, nb, first
    f = d.F(i)
    first = MeshCount()
    Select Case f.Kind
    Case FK_SM_BASE
        BaseBox d, i, x, y, w, h, z0, z1
        ' the plate as a flange of no bend: a box along the front edge
        ReDim ov(0 To 1): ReDim ow(0 To 1): ReDim iv(0 To 1): ReDim iw(0 To 1)
        ov(0) = 0: ov(1) = -h: ow(0) = z0: ow(1) = z0
        iv(0) = 0: iv(1) = -h: iw(0) = z1: iw(1) = z1
        Prism x, y, 1, 0, 0, -1, 0, w, ov(), ow(), iv(), iw(), 2, i
    Case FK_SM_EDGE
        m = Section(d, i, IsFlat(d, f.Ref), MESH_STEPS, ov(), ow(), iv(), iw(), nb)
        EdgeFrame d, f.Ref, f.X, ox, oy, ux, uy, vx, vy
        ua = Margin(d, i): ub = SideLength(d, f.Ref, f.X) - ua
        Prism ox, oy, ux, uy, vx, vy, ua, ub, ov(), ow(), iv(), iw(), m, i
    End Select
    If MeshCount() > first Then MeshOrient first
End Sub

' ---- the timeline ----

Function SM_Describe(ByRef d As TDesign, ByVal i As Long) As String
    Dim f As TFeature = d.F(i)
    Select Case f.Kind
    Case FK_SM_BASE
        Return FeatureName(d, f.Ref) & ", T " & Fmt(f.P1) & " mm, R " & Fmt(f.P2) & " mm, K " & Format(f.P3, "0.00")
    Case FK_SM_EDGE
        Return EdgeName(CLng(f.X)) & " edge of " & FeatureName(d, f.Ref) & ", " & Fmt(f.P1) & " mm at " & _
            Fmt(f.P2) & Chr(176) & ", " & ReliefName(CLng(f.P3))
    Case FK_SM_FLAT
        If f.Suppressed <> 0 Then Return "Folded (suppressed)"
        Return "Flat, saved as " & f.Info
    End Select
    Return ""
End Function

' ---- the dialogs ----

' Fills f and returns True on OK, if the numbers make sense. i is the feature
' being edited, 0 for a new one.
Function SM_Ask(ByRef d As TDesign, ByVal i As Long, ByRef f As TFeature) As Boolean
    Dim As String sTitle
    Dim As Long j
    Dim As Double side, wr
    If i = 0 Then sTitle = "" Else sTitle = "Edit " & FeatureName(d, i) & ": "
    Select Case f.Kind
    Case FK_SM_BASE
        If Not AskParams(sTitle & "Base Flange from " & FeatureName(d, f.Ref), _
            "Thickness (mm)|Inside bend radius (mm)|K-factor (0 to 1)", _
            Fmt0(f.P1) & "|" & Fmt0(f.P2) & "|" & Fmt0(f.P3)) Then Return False
        If ParamValue(0) <= 0 Or ParamValue(1) < 0 Or ParamValue(2) < 0 Or ParamValue(2) > 1 Then
            MsgBox "The thickness must be more than zero, the bend radius zero or more," & Chr(10) & _
                "and the K-factor between 0 and 1. (Ask the shop. They'll say 0.44.)", MB_EXCLAMATION
            Return False
        End If
        f.P1 = ParamValue(0): f.P2 = ParamValue(1): f.P3 = ParamValue(2)

    Case FK_SM_EDGE
        If Not AskParams(sTitle & "Edge Flange on " & FeatureName(d, f.Ref), _
            "Edge (0 front, 1 right, 2 back, 3 left)|Length (mm)|Angle (degrees)|Bend relief (0 none, 1 rect, 2 obround, 3 tear)|Relief width (mm, 0 = thickness)", _
            Fmt0(f.X) & "|" & Fmt0(f.P1) & "|" & Fmt0(f.P2) & "|" & Fmt0(f.P3) & "|" & Fmt0(f.Z)) Then Return False
        If ParamValue(0) <> Int(ParamValue(0)) Or ParamValue(0) < 0 Or ParamValue(0) > 3 Then
            MsgBox "The edge is a number: 0 for the front, 1 right, 2 back, 3 left.", MB_EXCLAMATION
            Return False
        End If
        If ParamValue(1) <= 0 Or ParamValue(2) <= 0 Or ParamValue(2) > 180 Then
            MsgBox "The length must be more than zero, and the angle between 1 and 180 degrees.", MB_EXCLAMATION
            Return False
        End If
        If ParamValue(3) <> Int(ParamValue(3)) Or ParamValue(3) < 0 Or ParamValue(3) > 3 Or ParamValue(4) < 0 Then
            MsgBox "The bend relief is a number: 0 none, 1 rectangular, 2 obround, 3 tear." & Chr(10) & _
                "The relief width is zero or more.", MB_EXCLAMATION
            Return False
        End If
        For j = 1 To d.Count
            If j <> i And d.F(j).Kind = FK_SM_EDGE And d.F(j).Ref = f.Ref And d.F(j).X = ParamValue(0) Then
                MsgBox "The " & EdgeName(CLng(ParamValue(0))) & " edge already has " & FeatureName(d, j) & " on it." & Chr(10) & _
                    "Pick another edge. (Flanges on flanges: SolidCraft XP.)", MB_EXCLAMATION
                Return False
            End If
        Next j
        side = d.F(d.F(f.Ref).Ref).P1
        If ParamValue(0) = 1 Or ParamValue(0) = 3 Then side = d.F(d.F(f.Ref).Ref).P2
        wr = ParamValue(4)
        If wr <= 0 Then wr = d.F(f.Ref).P1
        If ParamValue(3) <> SM_RELIEF_NONE And side <= 4 * wr Then
            MsgBox "That edge is too short for its relief: the flange stops " & Fmt0(2 * wr) & " mm in from each end.", MB_EXCLAMATION
            Return False
        End If
        If ParamValue(3) = SM_RELIEF_NONE Then
            MsgBox "No bend relief. The corners will tear when it's bent." & Chr(10) & Chr(10) & _
                "(SolidCraft 2000 will draw it anyway. So will the shop.)", MB_INFO
        End If
        f.X = ParamValue(0): f.P1 = ParamValue(1): f.P2 = ParamValue(2)
        f.P3 = ParamValue(3): f.Z = ParamValue(4)

    Case FK_SM_FLAT
        MsgBox "A flat pattern has no numbers to change." & Chr(10) & _
            "Sheet Metal, Flat Pattern folds the part and unfolds it again.", MB_INFO
        Return False
    End Select
    Return True
End Function

' ---- the flat pattern, as a DXF ----

' A number with a decimal point whatever the PC's region says.
Function DxfNum(ByVal v As Double) As String
    Return FmtN(v, 4)
End Function

Sub DxfPut(ByVal fh As Long, ByRef s As String)
    Print #fh, s & Chr(13, 10);
End Sub

Sub DxfLine(ByVal fh As Long, ByRef sLayer As String, ByVal ox As Double, ByVal oy As Double, _
            ByVal ux As Double, ByVal uy As Double, ByVal vx As Double, ByVal vy As Double, _
            ByVal u1 As Double, ByVal v1 As Double, ByVal u2 As Double, ByVal v2 As Double)
    DxfPut fh, "0" & Chr(13, 10) & "LINE" & Chr(13, 10) & "8" & Chr(13, 10) & sLayer
    DxfPut fh, "10" & Chr(13, 10) & DxfNum(ox + u1 * ux + v1 * vx) & Chr(13, 10) & "20" & Chr(13, 10) & DxfNum(oy + u1 * uy + v1 * vy) & Chr(13, 10) & "30" & Chr(13, 10) & "0"
    DxfPut fh, "11" & Chr(13, 10) & DxfNum(ox + u2 * ux + v2 * vx) & Chr(13, 10) & "21" & Chr(13, 10) & DxfNum(oy + u2 * uy + v2 * vy) & Chr(13, 10) & "31" & Chr(13, 10) & "0"
End Sub

' A relief cut into the base between u = ua and u = ub, dr deep (v < 0).
' The outline arrives at (ua, 0) and leaves from (ub, 0). A tear has no
' width: it's one cut, at u = slitU, where the flange starts or ends.
Sub Relief(ByVal fh As Long, ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
           ByVal vx As Double, ByVal vy As Double, ByVal ua As Double, ByVal ub As Double, ByVal dr As Double, _
           ByVal rel As Long, ByVal slitU As Double)
    Dim As Long j
    Dim As Double a0, a1, cu, rr, cv
    Select Case rel
    Case SM_RELIEF_RECT
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ua, 0, ua, -dr
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ua, -dr, ub, -dr
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ub, -dr, ub, 0
    Case SM_RELIEF_OBROUND
        rr = (ub - ua) / 2: cu = (ua + ub) / 2: cv = -dr + rr
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ua, 0, ua, cv
        For j = 0 To 7
            a0 = PI + PI * j / 8: a1 = PI + PI * (j + 1) / 8
            DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, cu + rr * Cos(a0), cv + rr * Sin(a0), cu + rr * Cos(a1), cv + rr * Sin(a1)
        Next j
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ub, cv, ub, 0
    Case Else
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ua, 0, ub, 0
        DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, slitU, 0, slitU, -dr
    End Select
End Sub

' The unfolded outline and the bend lines, as LINEs in an R12 DXF: the
' outline on layer OUTLINE, the bend lines on layer BEND. Going round the
' base anticlockwise, each edge with a flange on it goes out round the
' flange, with its relief cut in at both ends.
Function WriteFlatDxf(ByRef d As TDesign, ByVal b As Long, ByRef sPath As String) As Boolean
    Dim As Long fh, e, j, fl, rel
    Dim As Double ox, oy, ux, uy, vx, vy, side, ua, ub, s, ba, wr, dr, t, r, k
    t = d.F(b).P1: r = d.F(b).P2: k = d.F(b).P3
    fh = FreeFile
    If Open(sPath For Output As #fh) <> 0 Then
        MsgBox "Run-time error '75':" & Chr(10) & Chr(10) & "Path/File access error" & Chr(10) & Chr(10) & _
            "(While writing the flat pattern: " & sPath & ")", MB_CRITICAL
        Return False
    End If
    DxfPut fh, "0" & Chr(13, 10) & "SECTION" & Chr(13, 10) & "2" & Chr(13, 10) & "ENTITIES"
    For e = 0 To 3
        EdgeFrame d, b, e, ox, oy, ux, uy, vx, vy
        side = SideLength(d, b, e)
        fl = 0
        For j = b + 1 To d.Count
            If d.F(j).Kind = FK_SM_EDGE And d.F(j).Ref = b And d.F(j).X = e Then
                If SM_RefOk(d, j) And d.F(j).Suppressed = 0 Then fl = j: Exit For
            End If
        Next j
        If fl = 0 Then
            DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, 0, 0, side, 0
        Else
            ua = Margin(d, fl): ub = side - ua
            ba = BendAllowance(d.F(fl).P2, r, k, t)
            s = ba + d.F(fl).P1
            rel = d.F(fl).P3
            wr = ReliefWidth(d, fl)
            dr = r + t                              ' relief goes in past the bend
            ' along to the flange, round it, and on to the corner
            If rel = SM_RELIEF_NONE Then
                DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, 0, 0, 0, s
            Else
                DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, 0, 0, wr, 0
                Relief fh, ox, oy, ux, uy, vx, vy, wr, ua, dr, rel, ua
                DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ua, 0, ua, s
            End If
            DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ua, s, ub, s
            If rel = SM_RELIEF_NONE Then
                DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ub, s, side, 0
            Else
                DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, ub, s, ub, 0
                Relief fh, ox, oy, ux, uy, vx, vy, ub, side - wr, dr, rel, ub
                DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, side - wr, 0, side, 0
            End If
            DxfLine fh, "BEND", ox, oy, ux, uy, vx, vy, ua, 0, ub, 0
            DxfLine fh, "BEND", ox, oy, ux, uy, vx, vy, ua, ba, ub, ba
        End If
    Next e
    DxfPut fh, "0" & Chr(13, 10) & "ENDSEC" & Chr(13, 10) & "0" & Chr(13, 10) & "EOF"
    Close #fh
    Return True
End Function
