Attribute VB_Name = "modSheetMetal"
' modSheetMetal - sheet metal, new in 2000 (some assembly required).
'
' THIS MODULE IS A SLOT. Everything sheet metal lives here, and the rest of
' SolidCraft 2000 calls in through the SM_ functions below and nothing else.
' What's here now is a small reference engine, enough to show the slot
' working end to end: a base flange, edge flanges with one bend each, bend
' relief, and a flat pattern written as a DXF with an 8.3 file name. It is
' meant to be replaced by a real engine. CONTRIBUTING-SHEETMETAL.md says how.
'
' The features, and what their fields mean (TFeature is in modModel; the
' file format IS that record, so a sheet-metal feature must fit in it):
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
' The calls the rest of the program makes (keep these, change the insides):
'
'   SM_IsSheetMetal(kind)        is this kind one of ours?
'   SM_UsesSketch(kind)          does it use up a sketch, as Extrude does?
'   SM_KindName / SM_KindPrefix  "Edge Flange" for the timeline, "EdgeFlange" for names
'   SM_RefOk(d, i)               does feature i build? (False: "Rebuild error")
'   SM_Describe(d, i)            the timeline's Description column
'   SM_Edges(d, i, e(), n)       the wireframe: AddEdge for each line
'   SM_Mesh(d, i)                the solid, for shading and STL: MeshAddTri,
'                                then MeshOrient for each closed body
'   SM_Ask(d, i, f)              the dialog(s) to make or edit feature f
'   SM_Command(sCmd)             the Sheet Metal menu: SMBase, SMEdge, SMFlat, BendTable
'
' The reference engine's limits, all of them on purpose: one bend per edge
' flange, only on the four edges of the base, no flanges on flanges, no
' corner treatment (two flanges meeting at a corner are kept apart by their
' relief), relief cut only in the flat pattern, and every bend the same R.
Option Explicit

Public Const FK_SM_BASE As Integer = 20
Public Const FK_SM_EDGE As Integer = 21
Public Const FK_SM_FLAT As Integer = 22

Public Const SM_RELIEF_NONE As Integer = 0
Public Const SM_RELIEF_RECT As Integer = 1
Public Const SM_RELIEF_OBROUND As Integer = 2
Public Const SM_RELIEF_TEAR As Integer = 3

Public Const COL_BEND As Long = &H8000&          ' bend lines: dark green

Private Const WIRE_STEPS As Integer = 4          ' steps round a bend in the wireframe
Private Const MESH_STEPS As Integer = 8          ' and in the solid

' The bend table the wizard last made, for new base flanges.
Public SMTableSet As Boolean
Public SMTableName As String
Public SMTableT As Double
Public SMTableR As Double
Public SMTableK As Double

' ---- what kind of thing ----

Public Function SM_IsSheetMetal(ByVal k As Integer) As Boolean
    SM_IsSheetMetal = (k = FK_SM_BASE Or k = FK_SM_EDGE Or k = FK_SM_FLAT)
End Function

Public Function SM_UsesSketch(ByVal k As Integer) As Boolean
    SM_UsesSketch = (k = FK_SM_BASE)
End Function

Public Function SM_KindName(ByVal k As Integer) As String
    Select Case k
    Case FK_SM_BASE: SM_KindName = "Base Flange"
    Case FK_SM_EDGE: SM_KindName = "Edge Flange"
    Case FK_SM_FLAT: SM_KindName = "Flat Pattern"
    End Select
End Function

Public Function SM_KindPrefix(ByVal k As Integer) As String
    Select Case k
    Case FK_SM_BASE: SM_KindPrefix = "BaseFlange"
    Case FK_SM_EDGE: SM_KindPrefix = "EdgeFlange"
    Case FK_SM_FLAT: SM_KindPrefix = "FlatPattern"
    End Select
End Function

Private Function EdgeName(ByVal e As Integer) As String
    Select Case e
    Case 0: EdgeName = "front"
    Case 1: EdgeName = "right"
    Case 2: EdgeName = "back"
    Case 3: EdgeName = "left"
    End Select
End Function

Private Function ReliefName(ByVal r As Integer) As String
    Select Case r
    Case SM_RELIEF_NONE: ReliefName = "no relief"
    Case SM_RELIEF_RECT: ReliefName = "rectangular relief"
    Case SM_RELIEF_OBROUND: ReliefName = "obround relief"
    Case SM_RELIEF_TEAR: ReliefName = "tear relief"
    End Select
End Function

' ---- does it build ----

Public Function SM_RefOk(d As TDesign, ByVal i As Integer) As Boolean
    Dim f As TFeature, s As TFeature, j As Integer
    f = d.Features(i)
    Select Case f.Kind
    Case FK_SM_BASE
        If f.Ref < 1 Or f.Ref >= i Then Exit Function
        s = d.Features(f.Ref)
        If s.Kind <> FK_SKETCH_RECT Or s.P3 > 0 Then Exit Function
        If Not RefOk(d, f.Ref) Then Exit Function
        SM_RefOk = (f.P1 > 0 And f.P2 >= 0 And f.P3 >= 0 And f.P3 <= 1)
    Case FK_SM_EDGE
        If Not BaseOk(d, i, f.Ref) Then Exit Function
        If f.X <> Int(f.X) Or f.X < 0 Or f.X > 3 Then Exit Function
        If f.P1 <= 0 Or f.P2 <= 0 Or f.P2 > 180 Then Exit Function
        If f.P3 <> Int(f.P3) Or f.P3 < 0 Or f.P3 > 3 Or f.Z < 0 Then Exit Function
        If SideLength(d, f.Ref, f.X) - 2 * Margin(d, i) <= 0 Then Exit Function
        ' one flange to an edge: the first one gets it
        For j = f.Ref + 1 To i - 1
            If d.Features(j).Kind = FK_SM_EDGE And d.Features(j).Ref = f.Ref And d.Features(j).X = f.X And d.Features(j).Suppressed = 0 Then Exit Function
        Next j
        SM_RefOk = True
    Case FK_SM_FLAT
        SM_RefOk = BaseOk(d, i, f.Ref)
    End Select
End Function

Private Function BaseOk(d As TDesign, ByVal i As Integer, ByVal b As Integer) As Boolean
    If b < 1 Or b >= i Then Exit Function
    If d.Features(b).Kind <> FK_SM_BASE Or d.Features(b).Suppressed <> 0 Then Exit Function
    BaseOk = SM_RefOk(d, b)
End Function

' ---- the numbers of the geometry ----

' The base's rectangle, and its bottom and top.
Private Sub BaseBox(d As TDesign, ByVal b As Integer, x As Double, y As Double, w As Double, h As Double, z0 As Double, z1 As Double)
    Dim s As TFeature
    s = d.Features(d.Features(b).Ref)
    x = s.X: y = s.Y: w = s.P1: h = s.P2
    z0 = SketchZ(d, d.Features(b).Ref)
    z1 = z0 + d.Features(b).P1
End Sub

Private Function SideLength(d As TDesign, ByVal b As Integer, ByVal e As Integer) As Double
    Dim s As TFeature
    s = d.Features(d.Features(b).Ref)
    If e = 0 Or e = 2 Then SideLength = s.P1 Else SideLength = s.P2
End Function

' Where edge e starts, which way it runs (u), and which way is out (v), going
' anticlockwise round the base seen from above.
Private Sub EdgeFrame(d As TDesign, ByVal b As Integer, ByVal e As Integer, ox As Double, oy As Double, _
                      ux As Double, uy As Double, vx As Double, vy As Double)
    Dim x As Double, y As Double, w As Double, h As Double, z0 As Double, z1 As Double
    BaseBox d, b, x, y, w, h, z0, z1
    Select Case e
    Case 0: ox = x: oy = y: ux = 1: uy = 0: vx = 0: vy = -1
    Case 1: ox = x + w: oy = y: ux = 0: uy = 1: vx = 1: vy = 0
    Case 2: ox = x + w: oy = y + h: ux = -1: uy = 0: vx = 0: vy = 1
    Case Else: ox = x: oy = y + h: ux = 0: uy = -1: vx = -1: vy = 0
    End Select
End Sub

Private Function ReliefWidth(d As TDesign, ByVal i As Integer) As Double
    ReliefWidth = d.Features(i).Z
    If ReliefWidth <= 0 Then ReliefWidth = d.Features(d.Features(i).Ref).P1
End Function

' How far in from each end of its edge a flange stops: nothing without relief,
' otherwise room for the relief and as much again, so flanges on neighbouring
' edges don't meet.
Private Function Margin(d As TDesign, ByVal i As Integer) As Double
    If d.Features(i).P3 = SM_RELIEF_NONE Then Exit Function
    Margin = 2 * ReliefWidth(d, i)
End Function

' The length of the bend, measured along the K-factor line.
Public Function BendAllowance(ByVal angleDeg As Double, ByVal r As Double, ByVal k As Double, ByVal t As Double) As Double
    BendAllowance = angleDeg * PI / 180 * (r + k * t)
End Function

' Is the part being shown flat?
Private Function IsFlat(d As TDesign, ByVal b As Integer) As Boolean
    Dim j As Integer
    For j = b + 1 To d.Count
        If d.Features(j).Kind = FK_SM_FLAT And d.Features(j).Ref = b And d.Features(j).Suppressed = 0 Then
            If SM_RefOk(d, j) Then IsFlat = True: Exit Function
        End If
    Next j
End Function

' A flange's cross-section, seen along its edge: the outside (bottom) of the
' sheet in ov/ow and the inside in iv/iw, point for point, v out from the
' edge and w up. Folded: round the bend, then the straight leg. Flat: one
' strip as long as the bend allowance and the leg. Returns how many points;
' nBend is where the bend ends.
Private Function Section(d As TDesign, ByVal i As Integer, ByVal bFlat As Boolean, ByVal steps As Integer, _
                         ov() As Double, ow() As Double, iv() As Double, iw() As Double, nBend As Integer) As Integer
    Dim b As Integer, t As Double, r As Double, k As Double, a As Double, L As Double
    Dim x As Double, y As Double, w As Double, h As Double, z0 As Double, z1 As Double
    Dim j As Integer, th As Double, ba As Double
    b = d.Features(i).Ref
    t = d.Features(b).P1: r = d.Features(b).P2: k = d.Features(b).P3
    a = d.Features(i).P2 * PI / 180
    L = d.Features(i).P1
    BaseBox d, b, x, y, w, h, z0, z1
    If bFlat Then
        ba = BendAllowance(d.Features(i).P2, r, k, t)
        ReDim ov(0 To 2): ReDim ow(0 To 2): ReDim iv(0 To 2): ReDim iw(0 To 2)
        ov(0) = 0: ov(1) = ba: ov(2) = ba + L
        For j = 0 To 2
            iv(j) = ov(j): ow(j) = z0: iw(j) = z1
        Next j
        nBend = 1
        Section = 3
        Exit Function
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
    Section = steps + 2
End Function

' ---- the wireframe ----

Public Sub SM_Edges(d As TDesign, ByVal i As Integer, e() As TEdge, n As Long)
    Dim f As TFeature, x As Double, y As Double, w As Double, h As Double, z0 As Double, z1 As Double
    Dim ov() As Double, ow() As Double, iv() As Double, iw() As Double, m As Integer, nb As Integer, j As Integer
    Dim ox As Double, oy As Double, ux As Double, uy As Double, vx As Double, vy As Double
    Dim ua As Double, ub As Double, bFlat As Boolean
    f = d.Features(i)
    Select Case f.Kind
    Case FK_SM_BASE
        BaseBox d, i, x, y, w, h, z0, z1
        WireBox e, n, x, y, w, h, z0, z1
    Case FK_SM_EDGE
        bFlat = IsFlat(d, f.Ref)
        m = Section(d, i, bFlat, WIRE_STEPS, ov, ow, iv, iw, nb)
        EdgeFrame d, f.Ref, f.X, ox, oy, ux, uy, vx, vy
        ua = Margin(d, i): ub = SideLength(d, f.Ref, f.X) - ua
        ' both ends of the flange, and the lines along it
        For j = 0 To m - 2
            Wire e, n, ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ua, ov(j + 1), ow(j + 1), COL_SOLID
            Wire e, n, ox, oy, ux, uy, vx, vy, ua, iv(j), iw(j), ua, iv(j + 1), iw(j + 1), COL_SOLID
            Wire e, n, ox, oy, ux, uy, vx, vy, ub, ov(j), ow(j), ub, ov(j + 1), ow(j + 1), COL_SOLID
            Wire e, n, ox, oy, ux, uy, vx, vy, ub, iv(j), iw(j), ub, iv(j + 1), iw(j + 1), COL_SOLID
        Next j
        Wire e, n, ox, oy, ux, uy, vx, vy, ua, ov(m - 1), ow(m - 1), ua, iv(m - 1), iw(m - 1), COL_SOLID
        Wire e, n, ox, oy, ux, uy, vx, vy, ub, ov(m - 1), ow(m - 1), ub, iv(m - 1), iw(m - 1), COL_SOLID
        For j = 0 To m - 1
            If j = 0 Or j = nb Or j = m - 1 Then
                Wire e, n, ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ub, ov(j), ow(j), IIf(bFlat And j < m - 1, COL_BEND, COL_SOLID)
                Wire e, n, ox, oy, ux, uy, vx, vy, ua, iv(j), iw(j), ub, iv(j), iw(j), IIf(bFlat And j < m - 1, COL_BEND, COL_SOLID)
            End If
        Next j
    End Select
End Sub

' One line, given in an edge's own u, v, w.
Private Sub Wire(e() As TEdge, n As Long, ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
                 ByVal vx As Double, ByVal vy As Double, ByVal u1 As Double, ByVal v1 As Double, ByVal w1 As Double, _
                 ByVal u2 As Double, ByVal v2 As Double, ByVal w2 As Double, ByVal c As Long)
    AddEdge e, n, ox + u1 * ux + v1 * vx, oy + u1 * uy + v1 * vy, w1, ox + u2 * ux + v2 * vx, oy + u2 * uy + v2 * vy, w2, c
End Sub

Private Sub WireBox(e() As TEdge, n As Long, ByVal x As Double, ByVal y As Double, ByVal w As Double, ByVal h As Double, _
                    ByVal z0 As Double, ByVal z1 As Double)
    Dim px(0 To 3) As Double, py(0 To 3) As Double, j As Integer, k As Integer
    px(0) = x: py(0) = y: px(1) = x + w: py(1) = y: px(2) = x + w: py(2) = y + h: px(3) = x: py(3) = y + h
    For j = 0 To 3
        k = (j + 1) Mod 4
        AddEdge e, n, px(j), py(j), z0, px(k), py(k), z0, COL_SOLID
        AddEdge e, n, px(j), py(j), z1, px(k), py(k), z1, COL_SOLID
        AddEdge e, n, px(j), py(j), z0, px(j), py(j), z1, COL_SOLID
    Next j
End Sub

' ---- the solid ----

Public Sub SM_Mesh(d As TDesign, ByVal i As Integer)
    Dim f As TFeature, x As Double, y As Double, w As Double, h As Double, z0 As Double, z1 As Double
    Dim ov() As Double, ow() As Double, iv() As Double, iw() As Double, m As Integer, nb As Integer, j As Integer
    Dim ox As Double, oy As Double, ux As Double, uy As Double, vx As Double, vy As Double
    Dim ua As Double, ub As Double, first As Long
    f = d.Features(i)
    first = MeshCount()
    Select Case f.Kind
    Case FK_SM_BASE
        BaseBox d, i, x, y, w, h, z0, z1
        ' the plate as a flange of no bend: a box along the front edge
        ReDim ov(0 To 1): ReDim ow(0 To 1): ReDim iv(0 To 1): ReDim iw(0 To 1)
        ov(0) = 0: ov(1) = -h: ow(0) = z0: ow(1) = z0
        iv(0) = 0: iv(1) = -h: iw(0) = z1: iw(1) = z1
        Prism x, y, 1, 0, 0, -1, 0, w, ov, ow, iv, iw, 2, i
    Case FK_SM_EDGE
        m = Section(d, i, IsFlat(d, f.Ref), MESH_STEPS, ov, ow, iv, iw, nb)
        EdgeFrame d, f.Ref, f.X, ox, oy, ux, uy, vx, vy
        ua = Margin(d, i): ub = SideLength(d, f.Ref, f.X) - ua
        Prism ox, oy, ux, uy, vx, vy, ua, ub, ov, ow, iv, iw, m, i
    End Select
    If MeshCount() > first Then MeshOrient first
End Sub

' A strip of sheet swept along an edge from u = ua to u = ub: its outside
' face, its inside face, its two long edges, and its two ends.
Private Sub Prism(ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
                  ByVal vx As Double, ByVal vy As Double, ByVal ua As Double, ByVal ub As Double, _
                  ov() As Double, ow() As Double, iv() As Double, iw() As Double, ByVal m As Integer, ByVal body As Integer)
    Dim j As Integer
    For j = 0 To m - 2
        Quad ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ub, ov(j), ow(j), ub, ov(j + 1), ow(j + 1), ua, ov(j + 1), ow(j + 1), body
        Quad ox, oy, ux, uy, vx, vy, ua, iv(j), iw(j), ua, iv(j + 1), iw(j + 1), ub, iv(j + 1), iw(j + 1), ub, iv(j), iw(j), body
        Quad ox, oy, ux, uy, vx, vy, ua, ov(j), ow(j), ua, ov(j + 1), ow(j + 1), ua, iv(j + 1), iw(j + 1), ua, iv(j), iw(j), body
        Quad ox, oy, ux, uy, vx, vy, ub, ov(j), ow(j), ub, iv(j), iw(j), ub, iv(j + 1), iw(j + 1), ub, ov(j + 1), ow(j + 1), body
    Next j
    Quad ox, oy, ux, uy, vx, vy, ua, ov(0), ow(0), ua, iv(0), iw(0), ub, iv(0), iw(0), ub, ov(0), ow(0), body
    Quad ox, oy, ux, uy, vx, vy, ua, ov(m - 1), ow(m - 1), ub, ov(m - 1), ow(m - 1), ub, iv(m - 1), iw(m - 1), ua, iv(m - 1), iw(m - 1), body
End Sub

' Two triangles, corners given in an edge's own u, v, w, in order round the quad.
Private Sub Quad(ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
                 ByVal vx As Double, ByVal vy As Double, _
                 ByVal u1 As Double, ByVal v1 As Double, ByVal w1 As Double, ByVal u2 As Double, ByVal v2 As Double, ByVal w2 As Double, _
                 ByVal u3 As Double, ByVal v3 As Double, ByVal w3 As Double, ByVal u4 As Double, ByVal v4 As Double, ByVal w4 As Double, _
                 ByVal body As Integer)
    Dim x1 As Double, y1 As Double, x2 As Double, y2 As Double, x3 As Double, y3 As Double, x4 As Double, y4 As Double
    x1 = ox + u1 * ux + v1 * vx: y1 = oy + u1 * uy + v1 * vy
    x2 = ox + u2 * ux + v2 * vx: y2 = oy + u2 * uy + v2 * vy
    x3 = ox + u3 * ux + v3 * vx: y3 = oy + u3 * uy + v3 * vy
    x4 = ox + u4 * ux + v4 * vx: y4 = oy + u4 * uy + v4 * vy
    MeshAddTri x1, y1, w1, x2, y2, w2, x3, y3, w3, body
    MeshAddTri x1, y1, w1, x3, y3, w3, x4, y4, w4, body
End Sub

' ---- the timeline ----

Public Function SM_Describe(d As TDesign, ByVal i As Integer) As String
    Dim f As TFeature
    f = d.Features(i)
    Select Case f.Kind
    Case FK_SM_BASE
        SM_Describe = FeatureName(d, f.Ref) & ", T " & Fmt(f.P1) & " mm, R " & Fmt(f.P2) & " mm, K " & Format$(f.P3, "0.00")
    Case FK_SM_EDGE
        SM_Describe = EdgeName(CInt(f.X)) & " edge of " & FeatureName(d, f.Ref) & ", " & Fmt(f.P1) & " mm at " & _
            Fmt(f.P2) & Chr$(176) & ", " & ReliefName(CInt(f.P3))
    Case FK_SM_FLAT
        If f.Suppressed <> 0 Then
            SM_Describe = "Folded (suppressed)"
        Else
            SM_Describe = "Flat, saved as " & RTrim$(f.Info)
        End If
    End Select
End Function

' ---- the dialogs ----

' Fills f and returns True on OK, if the numbers make sense. i is the feature
' being edited, 0 for a new one.
Public Function SM_Ask(d As TDesign, ByVal i As Integer, f As TFeature) As Boolean
    Dim sTitle As String, j As Integer, side As Double, wr As Double
    If i = 0 Then sTitle = "" Else sTitle = "Edit " & FeatureName(d, i) & ": "
    Select Case f.Kind
    Case FK_SM_BASE
        If Not frmParams.Ask(sTitle & "Base Flange from " & FeatureName(d, f.Ref), _
            "Thickness (mm)|Inside bend radius (mm)|K-factor (0 to 1)", _
            Num(f.P1) & "|" & Num(f.P2) & "|" & Num(f.P3)) Then Exit Function
        If frmParams.Value(0) <= 0 Or frmParams.Value(1) < 0 Or frmParams.Value(2) < 0 Or frmParams.Value(2) > 1 Then
            MsgBox "The thickness must be more than zero, the bend radius zero or more," & vbCrLf & _
                "and the K-factor between 0 and 1. (Ask the shop. They'll say 0.44.)", vbExclamation, App.Title
            Exit Function
        End If
        f.P1 = frmParams.Value(0): f.P2 = frmParams.Value(1): f.P3 = frmParams.Value(2)

    Case FK_SM_EDGE
        If Not frmParams.Ask(sTitle & "Edge Flange on " & FeatureName(d, f.Ref), _
            "Edge (0 front, 1 right, 2 back, 3 left)|Length (mm)|Angle (degrees)|Bend relief (0 none, 1 rect, 2 obround, 3 tear)|Relief width (mm, 0 = thickness)", _
            Num(f.X) & "|" & Num(f.P1) & "|" & Num(f.P2) & "|" & Num(f.P3) & "|" & Num(f.Z)) Then Exit Function
        If frmParams.Value(0) <> Int(frmParams.Value(0)) Or frmParams.Value(0) < 0 Or frmParams.Value(0) > 3 Then
            MsgBox "The edge is a number: 0 for the front, 1 right, 2 back, 3 left.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(1) <= 0 Or frmParams.Value(2) <= 0 Or frmParams.Value(2) > 180 Then
            MsgBox "The length must be more than zero, and the angle between 1 and 180 degrees.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(3) <> Int(frmParams.Value(3)) Or frmParams.Value(3) < 0 Or frmParams.Value(3) > 3 Or frmParams.Value(4) < 0 Then
            MsgBox "The bend relief is a number: 0 none, 1 rectangular, 2 obround, 3 tear." & vbCrLf & _
                "The relief width is zero or more.", vbExclamation, App.Title
            Exit Function
        End If
        For j = 1 To d.Count
            If j <> i And d.Features(j).Kind = FK_SM_EDGE And d.Features(j).Ref = f.Ref And d.Features(j).X = frmParams.Value(0) Then
                MsgBox "The " & EdgeName(CInt(frmParams.Value(0))) & " edge already has " & FeatureName(d, j) & " on it." & vbCrLf & _
                    "Pick another edge. (Flanges on flanges: SolidCraft XP.)", vbExclamation, App.Title
                Exit Function
            End If
        Next j
        side = d.Features(d.Features(f.Ref).Ref).P1
        If frmParams.Value(0) = 1 Or frmParams.Value(0) = 3 Then side = d.Features(d.Features(f.Ref).Ref).P2
        wr = frmParams.Value(4)
        If wr <= 0 Then wr = d.Features(f.Ref).P1
        If frmParams.Value(3) <> SM_RELIEF_NONE And side <= 4 * wr Then
            MsgBox "That edge is too short for its relief: the flange stops " & Num(2 * wr) & " mm in from each end.", vbExclamation, App.Title
            Exit Function
        End If
        If frmParams.Value(3) = SM_RELIEF_NONE Then
            MsgBox "No bend relief. The corners will tear when it's bent." & vbCrLf & vbCrLf & _
                "(SolidCraft 2000 will draw it anyway. So will the shop.)", vbInformation, App.Title
        End If
        f.X = frmParams.Value(0): f.P1 = frmParams.Value(1): f.P2 = frmParams.Value(2)
        f.P3 = frmParams.Value(3): f.Z = frmParams.Value(4)

    Case FK_SM_FLAT
        MsgBox "A flat pattern has no numbers to change." & vbCrLf & _
            "Sheet Metal, Flat Pattern folds the part and unfolds it again.", vbInformation, App.Title
        Exit Function
    End Select
    SM_Ask = True
End Function

Private Function Num(ByVal v As Double) As String
    Num = Format$(v, "0.###")
    If Right$(Num, 1) = "." Or Right$(Num, 1) = "," Then Num = Left$(Num, Len(Num) - 1)
End Function

' ---- the Sheet Metal menu ----

Public Sub SM_Command(ByVal sCmd As String)
    Dim p As frmPart
    If sCmd = "BendTable" Then
        If frmBendTable.Run() Then
            MsgBox "Bend table """ & SMTableName & """ created." & vbCrLf & vbCrLf & _
                "New base flanges will use it. Base flanges you've already made keep their own numbers.", vbInformation, App.Title
        End If
        Exit Sub
    End If
    Set p = ActivePart()
    If p Is Nothing Then
        MsgBox "There is no part open." & vbCrLf & "Choose File, New Part first.", vbExclamation, App.Title
        Exit Sub
    End If
    Select Case sCmd
    Case "SMBase": NewBase p
    Case "SMEdge": NewEdge p
    Case "SMFlat": FoldUnfold p
    End Select
End Sub

Private Sub NewBase(p As frmPart)
    Dim f As TFeature, s As Integer
    s = LastFreeSketch(Docs(p.DocIndex))
    If s = 0 Then
        MsgBox "A base flange is made from a rectangle sketch." & vbCrLf & "Sketch a rectangle first.", vbExclamation, App.Title
        Exit Sub
    End If
    If Docs(p.DocIndex).Features(s).Kind <> FK_SKETCH_RECT Or Docs(p.DocIndex).Features(s).P3 > 0 Then
        MsgBox FeatureName(Docs(p.DocIndex), s) & " isn't a rectangle with square corners." & vbCrLf & vbCrLf & _
            "Base flanges from other shapes require SolidCraft XP.", vbExclamation, App.Title
        Exit Sub
    End If
    If Not SMTableSet Then
        MsgBox "Before you can make sheet metal parts, SolidCraft 2000 needs a bend table." & vbCrLf & vbCrLf & _
            "The Bend Table Wizard will now help you create one.", vbInformation, App.Title
        If Not frmBendTable.Run() Then Exit Sub
    End If
    f.Kind = FK_SM_BASE
    f.Ref = s
    f.P1 = SMTableT: f.P2 = SMTableR: f.P3 = SMTableK
    If SM_Ask(Docs(p.DocIndex), 0, f) Then CommitFeature p, f
End Sub

' The last base flange, the default home for an edge flange.
Private Function LastBase(d As TDesign) As Integer
    Dim i As Integer
    For i = d.Count To 1 Step -1
        If d.Features(i).Kind = FK_SM_BASE Then LastBase = i: Exit Function
    Next i
End Function

Private Sub NewEdge(p As frmPart)
    Dim f As TFeature, b As Integer, e As Integer, j As Integer, taken As Boolean
    b = LastBase(Docs(p.DocIndex))
    If b = 0 Then
        MsgBox "An edge flange goes on the edge of a base flange." & vbCrLf & _
            "Choose Sheet Metal, Base Flange first.", vbExclamation, App.Title
        Exit Sub
    End If
    ' the first edge that's free
    For e = 0 To 4
        taken = False
        For j = b + 1 To Docs(p.DocIndex).Count
            If Docs(p.DocIndex).Features(j).Kind = FK_SM_EDGE And Docs(p.DocIndex).Features(j).Ref = b And Docs(p.DocIndex).Features(j).X = e Then taken = True
        Next j
        If Not taken Then Exit For
    Next e
    If e > 3 Then
        MsgBox "All four edges of " & FeatureName(Docs(p.DocIndex), b) & " have flanges." & vbCrLf & _
            "That's a box. Well done.", vbInformation, App.Title
        Exit Sub
    End If
    f.Kind = FK_SM_EDGE
    f.Ref = b
    f.X = e
    f.P1 = 10 * Docs(p.DocIndex).Features(b).P1
    If f.P1 < 5 Then f.P1 = 5
    f.P2 = 90
    f.P3 = SM_RELIEF_RECT
    If SM_Ask(Docs(p.DocIndex), 0, f) Then CommitFeature p, f
End Sub

' Unfolds the part (adding a Flat Pattern the first time) and writes its
' DXF; or, if it's flat, folds it back up.
Private Sub FoldUnfold(p As frmPart)
    Dim d As Integer, b As Integer, j As Integer, f As TFeature, sPath As String
    d = p.DocIndex
    b = LastBase(Docs(d))
    If b = 0 Then
        MsgBox "Only sheet metal can be unfolded." & vbCrLf & "Choose Sheet Metal, Base Flange first.", vbExclamation, App.Title
        Exit Sub
    End If
    For j = b + 1 To Docs(d).Count
        If Docs(d).Features(j).Kind = FK_SM_FLAT And Docs(d).Features(j).Ref = b Then Exit For
    Next j
    If j <= Docs(d).Count Then
        If Docs(d).Features(j).Suppressed = 0 Then
            HistoryRemember d, Docs(d), "Fold " & FeatureName(Docs(d), b)
            Docs(d).Features(j).Suppressed = 1
            DocDirty(d) = True
            p.RefreshAll False
            frmMain.SetStatus "Folded."
            Exit Sub
        End If
        HistoryRemember d, Docs(d), "Unfold " & FeatureName(Docs(d), b)
        Docs(d).Features(j).Suppressed = 0
    Else
        f.Kind = FK_SM_FLAT
        f.Ref = b
        If Not CommitFeature(p, f) Then Exit Sub
        j = Docs(d).Count
    End If
    sPath = FlatPatternPath(d)
    Docs(d).Features(j).Info = FileTitle(sPath) & ".DXF"
    DocDirty(d) = True
    p.RefreshAll False
    If WriteFlatDxf(Docs(d), b, sPath) Then
        MsgBox "Flat pattern saved as" & vbCrLf & sPath & vbCrLf & vbCrLf & _
            "The file name is 8.3, for the nesting software in the shop, which runs on DOS.", vbInformation, App.Title
        frmMain.SetStatus "Unfolded. Flat pattern saved as " & sPath
    End If
End Sub

' MOUNTI~1.DXF, next to the part (or in My Documents if it's never been
' saved), with ~2, ~3... if that's taken.
Private Function FlatPatternPath(ByVal d As Integer) As String
    Dim sDir As String, sBase As String, c As String, k As Long, n As Integer
    If Len(DocPath(d)) Then
        sDir = Left$(DocPath(d), InStrRev(DocPath(d), "\"))
    Else
        sDir = Environ$("USERPROFILE") & "\Documents\"
        If Not FolderExists(sDir) Then sDir = App.Path & "\"
    End If
    For k = 1 To Len(RTrim$(Docs(d).Title))
        c = UCase$(Mid$(Docs(d).Title, k, 1))
        If (c >= "A" And c <= "Z") Or (c >= "0" And c <= "9") Then sBase = sBase & c
        If Len(sBase) = 6 Then Exit For
    Next k
    If Len(sBase) = 0 Then sBase = "FLAT"
    n = 1
    Do
        FlatPatternPath = sDir & sBase & "~" & n & ".DXF"
        If Not FileExists(FlatPatternPath) Then Exit Function
        n = n + 1
    Loop While n < 10
End Function

' ---- the flat pattern, as a DXF ----

' The unfolded outline and the bend lines, as LINEs in an R12 DXF: the
' outline on layer OUTLINE, the bend lines on layer BEND. Going round the
' base anticlockwise, each edge with a flange on it goes out round the
' flange, with its relief cut in at both ends.
Private Function WriteFlatDxf(d As TDesign, ByVal b As Integer, ByVal sPath As String) As Boolean
    Dim fh As Integer, e As Integer, j As Integer, fl As Integer
    Dim ox As Double, oy As Double, ux As Double, uy As Double, vx As Double, vy As Double
    Dim side As Double, ua As Double, ub As Double, s As Double, ba As Double, wr As Double, dr As Double
    Dim t As Double, r As Double, k As Double, rel As Integer
    On Error GoTo Failed
    t = d.Features(b).P1: r = d.Features(b).P2: k = d.Features(b).P3
    fh = FreeFile
    Open sPath For Output As #fh
    Print #fh, "0" & vbCrLf & "SECTION" & vbCrLf & "2" & vbCrLf & "ENTITIES"
    For e = 0 To 3
        EdgeFrame d, b, e, ox, oy, ux, uy, vx, vy
        side = SideLength(d, b, e)
        fl = 0
        For j = b + 1 To d.Count
            If d.Features(j).Kind = FK_SM_EDGE And d.Features(j).Ref = b And d.Features(j).X = e Then
                If SM_RefOk(d, j) And d.Features(j).Suppressed = 0 Then fl = j: Exit For
            End If
        Next j
        If fl = 0 Then
            DxfLine fh, "OUTLINE", ox, oy, ux, uy, vx, vy, 0, 0, side, 0
        Else
            ua = Margin(d, fl): ub = side - ua
            ba = BendAllowance(d.Features(fl).P2, r, k, t)
            s = ba + d.Features(fl).P1
            rel = d.Features(fl).P3
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
    Print #fh, "0" & vbCrLf & "ENDSEC" & vbCrLf & "0" & vbCrLf & "EOF"
    Close #fh
    WriteFlatDxf = True
    Exit Function
Failed:
    If fh <> 0 Then Close #fh
    MsgBox "Run-time error '" & Err.Number & "':" & vbCrLf & vbCrLf & Err.Description & vbCrLf & vbCrLf & _
        "(While writing the flat pattern: " & sPath & ")", vbCritical, App.Title
End Function

' A relief cut into the base between u = ua and u = ub, dr deep (v < 0).
' The outline arrives at (ua, 0) and leaves from (ub, 0). A tear has no
' width: it's one cut, at u = slitU, where the flange starts or ends.
Private Sub Relief(ByVal fh As Integer, ByVal ox As Double, ByVal oy As Double, ByVal ux As Double, ByVal uy As Double, _
                   ByVal vx As Double, ByVal vy As Double, ByVal ua As Double, ByVal ub As Double, ByVal dr As Double, _
                   ByVal rel As Integer, ByVal slitU As Double)
    Dim j As Integer, a0 As Double, a1 As Double, cu As Double, rr As Double, cv As Double
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

Private Sub DxfLine(ByVal fh As Integer, ByVal sLayer As String, ByVal ox As Double, ByVal oy As Double, _
                    ByVal ux As Double, ByVal uy As Double, ByVal vx As Double, ByVal vy As Double, _
                    ByVal u1 As Double, ByVal v1 As Double, ByVal u2 As Double, ByVal v2 As Double)
    Print #fh, "0" & vbCrLf & "LINE" & vbCrLf & "8" & vbCrLf & sLayer
    Print #fh, "10" & vbCrLf & DxfNum(ox + u1 * ux + v1 * vx) & vbCrLf & "20" & vbCrLf & DxfNum(oy + u1 * uy + v1 * vy) & vbCrLf & "30" & vbCrLf & "0"
    Print #fh, "11" & vbCrLf & DxfNum(ox + u2 * ux + v2 * vx) & vbCrLf & "21" & vbCrLf & DxfNum(oy + u2 * uy + v2 * vy) & vbCrLf & "31" & vbCrLf & "0"
End Sub

' A number with a decimal point whatever the PC's region says: Str$, not Format$.
Private Function DxfNum(ByVal v As Double) As String
    v = Int(v * 10000 + 0.5) / 10000
    DxfNum = Trim$(Str$(v))
    If Left$(DxfNum, 1) = "." Then DxfNum = "0" & DxfNum
    If Left$(DxfNum, 2) = "-." Then DxfNum = "-0" & Mid$(DxfNum, 2)
End Function
