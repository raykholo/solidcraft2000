Attribute VB_Name = "modArt"
' modArt - the logo and the splash backdrop, drawn with Line and Circle
' so there's no bitmap to ship. Our own art: a wireframe block with a hole,
' its top edges rounded now (new in 2000), a starburst, and a Y2K badge.
Option Explicit

' The 2000 colours: grey-teal where 98 was navy, and the warmer grey of the
' new 3D face. Our own picks.
Public Const TEAL_DARK As Long = &H585000      ' RGB(0, 80, 88)
Public Const TEAL_LIGHT As Long = &HB4AA78     ' RGB(120, 170, 180)
Public Const FACE_2000 As Long = &HC8D0D4      ' RGB(212, 208, 200)

Private Type POINTAPI
    X As Long
    Y As Long
End Type

Private Declare Function Polygon Lib "gdi32" (ByVal hDC As Long, lpPoint As POINTAPI, ByVal nCount As Long) As Long
Private Declare Function CreateSolidBrush Lib "gdi32" (ByVal crColor As Long) As Long
Private Declare Function CreatePen Lib "gdi32" (ByVal nPenStyle As Long, ByVal nWidth As Long, ByVal crColor As Long) As Long
Private Declare Function SelectObject Lib "gdi32" (ByVal hDC As Long, ByVal hObject As Long) As Long
Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long

Public Const APP_NAME As String = "SolidCraft 2000"
Public Const APP_EDITION As String = "Professional Edition"
Public Const APP_BUILD As String = "Build 2000.1123, Service Pack 1"

Public Function AppVersion() As String
    AppVersion = "Version " & App.Major & "." & App.Minor & "." & App.Revision
End Function

' Vertical gradient, the setup-program look. c1 at the top, c2 at the bottom.
Public Sub Gradient(ByVal pic As PictureBox, ByVal c1 As Long, ByVal c2 As Long)
    Dim y As Long, h As Long, t As Double
    Dim r1 As Long, g1 As Long, b1 As Long, r2 As Long, g2 As Long, b2 As Long
    r1 = c1 And &HFF&: g1 = (c1 \ &H100&) And &HFF&: b1 = (c1 \ &H10000) And &HFF&
    r2 = c2 And &HFF&: g2 = (c2 \ &H100&) And &HFF&: b2 = (c2 \ &H10000) And &HFF&
    h = pic.ScaleHeight
    For y = 0 To h Step 2
        t = y / h
        pic.Line (0, y)-(pic.ScaleWidth, y + 2), RGB(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t), BF
    Next y
End Sub

' Left-to-right gradient over a box, c1 on the left: the 2000 title-bar look.
Public Sub GradientH(ByVal pic As PictureBox, ByVal x0 As Long, ByVal y0 As Long, ByVal x1 As Long, ByVal y1 As Long, _
                     ByVal c1 As Long, ByVal c2 As Long)
    Dim x As Long, t As Double
    Dim r1 As Long, g1 As Long, b1 As Long, r2 As Long, g2 As Long, b2 As Long
    r1 = c1 And &HFF&: g1 = (c1 \ &H100&) And &HFF&: b1 = (c1 \ &H10000) And &HFF&
    r2 = c2 And &HFF&: g2 = (c2 \ &H100&) And &HFF&: b2 = (c2 \ &H10000) And &HFF&
    For x = x0 To x1 Step 2
        t = (x - x0) / (x1 - x0 + 1)
        pic.Line (x, y0)-(x + 1, y1), RGB(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t), BF
    Next x
End Sub

' The 2000 logo: the same block, with its top edges filleted (radius 0.45),
' and the hole. s pixels per unit.
Public Sub DrawLogo2000(ByVal pic As PictureBox, ByVal ox As Single, ByVal oy As Single, ByVal s As Single, ByVal c As Long)
    Const R As Double = 0.45, W As Double = 4, D As Double = 3, H As Double = 1.5
    Dim i As Integer, k As Integer, zf As Double, a0 As Double, a1 As Double
    Dim cx(0 To 3) As Double, cy(0 To 3) As Double, sx(0 To 3) As Double, sy(0 To 3) As Double
    Dim x1 As Single, y1 As Single, x2 As Single, y2 As Single
    zf = H - R
    cx(0) = 0: cy(0) = 0: sx(0) = 1: sy(0) = 1        ' each corner, and which way is in
    cx(1) = W: cy(1) = 0: sx(1) = -1: sy(1) = 1
    cx(2) = W: cy(2) = D: sx(2) = -1: sy(2) = -1
    cx(3) = 0: cy(3) = D: sx(3) = 1: sy(3) = -1
    pic.DrawWidth = 2
    For i = 0 To 3
        k = (i + 1) Mod 4
        ' bottom, the line where the fillet starts, and the smaller top
        IsoPt cx(i), cy(i), 0, s, ox, oy, x1, y1
        IsoPt cx(k), cy(k), 0, s, ox, oy, x2, y2
        pic.Line (x1, y1)-(x2, y2), c
        IsoPt cx(i), cy(i), zf, s, ox, oy, x1, y1
        IsoPt cx(k), cy(k), zf, s, ox, oy, x2, y2
        pic.Line (x1, y1)-(x2, y2), c
        IsoPt cx(i) + sx(i) * R, cy(i) + sy(i) * R, H, s, ox, oy, x1, y1
        IsoPt cx(k) + sx(k) * R, cy(k) + sy(k) * R, H, s, ox, oy, x2, y2
        pic.Line (x1, y1)-(x2, y2), c
        ' the upright edge, and the quarter circle over the corner
        IsoPt cx(i), cy(i), 0, s, ox, oy, x1, y1
        IsoPt cx(i), cy(i), zf, s, ox, oy, x2, y2
        pic.Line (x1, y1)-(x2, y2), c
        For k = 1 To 6
            a0 = (PI / 2) * (k - 1) / 6
            a1 = (PI / 2) * k / 6
            IsoPt cx(i) + sx(i) * R * (1 - Cos(a0)), cy(i) + sy(i) * R * (1 - Cos(a0)), zf + R * Sin(a0), s, ox, oy, x1, y1
            IsoPt cx(i) + sx(i) * R * (1 - Cos(a1)), cy(i) + sy(i) * R * (1 - Cos(a1)), zf + R * Sin(a1), s, ox, oy, x2, y2
            pic.Line (x1, y1)-(x2, y2), c
        Next k
    Next i
    Dim hx As Single, hy As Single
    IsoPt W / 2, D / 2, H, s, ox, oy, hx, hy
    pic.Circle (hx, hy), s * 0.7, c, , , 0.55
    pic.DrawWidth = 1
End Sub

' A filled polygon, through GDI: VB's Line and Circle can't fill a star.
Private Sub FillPoly(ByVal pic As PictureBox, pts() As POINTAPI, ByVal n As Long, ByVal cFill As Long, ByVal cEdge As Long)
    Dim hBr As Long, hPen As Long, oldBr As Long, oldPen As Long
    hBr = CreateSolidBrush(cFill)
    hPen = CreatePen(0, 1, cEdge)
    oldBr = SelectObject(pic.hDC, hBr)
    oldPen = SelectObject(pic.hDC, hPen)
    Polygon pic.hDC, pts(0), n
    SelectObject pic.hDC, oldBr
    SelectObject pic.hDC, oldPen
    DeleteObject hBr
    DeleteObject hPen
End Sub

' The box-art starburst: "NEW! Fillets!", as printed on the side of the box.
Public Sub DrawStarburst(ByVal pic As PictureBox, ByVal cx As Single, ByVal cy As Single, ByVal r As Single, _
                         ByVal sLine1 As String, ByVal sLine2 As String)
    Const SPIKES As Long = 16
    Dim pts(0 To 2 * SPIKES - 1) As POINTAPI, i As Long, a As Double, rr As Double
    For i = 0 To 2 * SPIKES - 1
        a = PI * i / SPIKES - PI / 2 + 0.12
        If i Mod 2 = 0 Then rr = r Else rr = r * 0.74
        pts(i).X = cx + rr * Cos(a)
        pts(i).Y = cy + rr * Sin(a)
    Next i
    FillPoly pic, pts, 2 * SPIKES, RGB(255, 214, 0), RGB(200, 40, 0)
    pic.FontName = "Arial"
    pic.FontBold = True
    pic.FontItalic = False
    pic.FontSize = 11
    TextAt pic, cx - pic.TextWidth(sLine1) / 2, cy - pic.TextHeight(sLine1) + 1, sLine1, RGB(200, 0, 0)
    pic.FontSize = 9
    TextAt pic, cx - pic.TextWidth(sLine2) / 2, cy + 1, sLine2, RGB(200, 0, 0)
    pic.FontBold = False
End Sub

' The sticker every box had in 1999: a gold seal saying the program will
' still work on 1 January 2000. Ours, with its asterisk.
Public Sub DrawY2KBadge(ByVal pic As PictureBox, ByVal cx As Single, ByVal cy As Single, ByVal r As Single)
    Const GOLD As Long = &H30B4E6        ' RGB(230, 180, 48)
    Const GOLD_DARK As Long = &H186C9C   ' RGB(156, 108, 24)
    Dim i As Long, pts(0 To 39) As POINTAPI, a As Double, rr As Double, s As String
    ' a scalloped edge, then the seal and its inner ring
    For i = 0 To 39
        a = 2 * PI * i / 40
        If i Mod 2 = 0 Then rr = r Else rr = r * 0.9
        pts(i).X = cx + rr * Cos(a)
        pts(i).Y = cy + rr * Sin(a)
    Next i
    FillPoly pic, pts, 40, GOLD, GOLD_DARK
    pic.Circle (cx, cy), r * 0.72, GOLD_DARK
    pic.FontName = "Arial"
    pic.FontBold = True
    pic.FontItalic = False
    pic.FontSize = 12
    s = "Y2K"
    TextAt pic, cx - pic.TextWidth(s) / 2, cy - pic.TextHeight(s) + 3, s, RGB(64, 32, 0)
    pic.FontSize = 6
    s = "COMPLIANT*"
    TextAt pic, cx - pic.TextWidth(s) / 2, cy + 2, s, RGB(64, 32, 0)
    pic.FontBold = False
End Sub

' The logo: an isometric block with a hole in the top, s pixels per unit.
Public Sub DrawLogo(ByVal pic As PictureBox, ByVal ox As Single, ByVal oy As Single, ByVal s As Single, ByVal c As Long)
    Dim i As Integer
    Dim px(0 To 7) As Single, py(0 To 7) As Single
    ' block corners, 4 x 3 x 1.5 units, in screen space
    IsoPt 0, 0, 0, s, ox, oy, px(0), py(0)
    IsoPt 4, 0, 0, s, ox, oy, px(1), py(1)
    IsoPt 4, 3, 0, s, ox, oy, px(2), py(2)
    IsoPt 0, 3, 0, s, ox, oy, px(3), py(3)
    IsoPt 0, 0, 1.5, s, ox, oy, px(4), py(4)
    IsoPt 4, 0, 1.5, s, ox, oy, px(5), py(5)
    IsoPt 4, 3, 1.5, s, ox, oy, px(6), py(6)
    IsoPt 0, 3, 1.5, s, ox, oy, px(7), py(7)
    pic.DrawWidth = 2
    For i = 0 To 3
        pic.Line (px(i), py(i))-(px((i + 1) Mod 4), py((i + 1) Mod 4)), c
        pic.Line (px(i + 4), py(i + 4))-(px((i + 1) Mod 4 + 4), py((i + 1) Mod 4 + 4)), c
        pic.Line (px(i), py(i))-(px(i + 4), py(i + 4)), c
    Next i
    ' the hole: an ellipse on the top face
    Dim hx As Single, hy As Single
    IsoPt 2, 1.5, 1.5, s, ox, oy, hx, hy
    pic.Circle (hx, hy), s * 0.75, c, , , 0.55
    pic.DrawWidth = 1
End Sub

Private Sub IsoPt(ByVal x As Double, ByVal y As Double, ByVal z As Double, ByVal s As Single, _
                  ByVal ox As Single, ByVal oy As Single, sx As Single, sy As Single)
    sx = ox + (x - y) * 0.866 * s
    sy = oy + (x + y) * 0.5 * s - z * s
End Sub
