' Headless test of the model and the geometry. Run from freebasic/:
'   fbc tests/core_test.bas -x build/core_test && build/core_test
' It checks, with no screen:
'   - the .sc2 file format byte for byte (open every sample, save it, compare),
'   - that an .sc98 part opens, upgrades, and is saved as SC2K version 6,
'   - that fillets, chamfers, hole patterns and side-face bodies mesh into
'     closed solids (every triangle edge meets exactly one the other way round),
'   - that the STL and the flat pattern's DXF get written.
' Prints "ALL OK" at the end, or what failed and exits 1.
#include "fbgfx.bi"
#include "dir.bi"
#include "datetime.bi"
#include "vbcompat.bi"
#include "../src/font.bi"
#include "../src/icons.bi"
#include "../src/gfx.bas"
#include "../src/model.bas"
#include "../src/kernel.bas"
#include "../src/view.bas"
#include "../src/mesh.bas"
#include "../src/shade.bas"
#include "../src/expr.bas"
#include "../src/stl.bas"
Function Y2KDimension() As String
    Return "19100"
End Function
' what sheetmetal.bas needs from the program around it
Dim Shared ParamValue(0 To 8) As Double
Function AskParams(ByRef sTitle As String, ByRef sPrompts As String, ByRef sDefaults As String) As Boolean
    Return False
End Function
Const MB_EXCLAMATION = 48, MB_INFO = 64, MB_CRITICAL = 16
Function MsgBox(ByRef prompt As String, ByVal flags As Long = 0, ByRef title As String = "") As Long
    Return 1
End Function

#include "../src/sheetmetal.bas"

Dim Shared Fails As Long
Sub Check(ByVal ok As Boolean, ByRef what As String)
    If Not ok Then Print #9, "FAIL: " & what: Fails += 1 Else Print #9, "ok:   " & what
End Sub

' An empty fixed-length string is spaces in the samples (tools/mksample.py) and NULs
' from VB, which leaves one nobody assigned alone. Both are the same field.
Function Blank(ByVal s As String) As String
    Dim i As Long
    For i = 0 To Len(s) - 1
        If s[i] = 0 Then s[i] = 32
    Next
    Return s
End Function

Function ReadAll(ByRef p As String) As String
    Dim As Long fh = FreeFile
    Dim As String s
    If Open(p For Binary Access Read As #fh) <> 0 Then Return ""
    s = Space(LOF(fh))
    Get #fh, , s
    Close #fh
    Return s
End Function

Const SZ = 1 Shl 20
Dim Shared keys() As ULongInt, cnt() As Long

' Is every edge of every triangle shared with exactly one triangle going the other way?
Function IsClosed(t() As TTri, ByVal n As Long) As Boolean
    Dim As Long i, k, s
    Erase keys, cnt
    ReDim keys(0 To SZ - 1): ReDim cnt(0 To SZ - 1)
    Dim ok As Boolean = True
    Dim As Double ax, ay, az, bx, by, bz
    For pass As Long = 0 To 1
        For i = 0 To n - 1
            For k = 0 To 2
                TriCorner t(i), k, ax, ay, az
                TriCorner t(i), (k + 1) Mod 3, bx, by, bz
                Dim As ULongInt h = EdgeHash(ax, ay, az, bx, by, bz)
                Dim As ULongInt hr = EdgeHash(bx, by, bz, ax, ay, az)
                If pass = 0 Then
                    s = h And (SZ - 1)
                    Do While cnt(s) <> 0 AndAlso keys(s) <> h
                        s = (s + 1) And (SZ - 1)
                    Loop
                    keys(s) = h: cnt(s) += 1
                Else
                    s = h And (SZ - 1)
                    Do While cnt(s) <> 0 AndAlso keys(s) <> h
                        s = (s + 1) And (SZ - 1)
                    Loop
                    If cnt(s) <> 1 Then ok = False
                    s = hr And (SZ - 1)
                    Do While cnt(s) <> 0 AndAlso keys(s) <> hr
                        s = (s + 1) And (SZ - 1)
                    Loop
                    If cnt(s) <> 1 Then ok = False
                End If
            Next k
        Next i
    Next pass
    Return ok
End Function

Sub MeshCheck(ByRef d As TDesign, ByRef what As String, ByVal expectClosed As Boolean)
    Dim t() As TTri, sErr As String
    Dim n As Long = MeshDesign(d, t(), 32, sErr)
    Check n > 0, what & ": " & n & " triangles"
    Check Len(sErr) = 0, what & ": no body left out"
    If expectClosed Then Check IsClosed(t(), n), what & ": closed solid"
End Sub

Sub Feat(ByRef d As TDesign, ByVal kind As Long, ByVal ref As Long, ByVal p1 As Double, ByVal p2 As Double, _
         ByVal x As Double, ByVal y As Double, ByVal z As Double, ByVal p3 As Double)
    Dim f As TFeature
    f.Kind = kind: f.Ref = ref: f.P1 = p1: f.P2 = p2: f.X = x: f.Y = y: f.Z = z: f.P3 = p3
    AddFeature d, f
End Sub

Open Cons For Output As #9
ScreenControl FB.SET_DRIVER_NAME, "null"
ScreenRes 640, 480, 32
MkDir "tests/out"
Dim d As TDesign, r As Long, i As Long

' ---- the file format, byte for byte ----
Dim names(0 To 1) As String = {"Filleted Plate.sc2", "Sheet Metal Tray.sc2"}
For i = 0 To 1
    r = LoadDesign(d, "../samples/" & names(i))
    Check r = 0, "open " & names(i) & " (" & d.Count & " features)"
    Check SaveDesign(d, "tests/out/resave.sc2"), "save it again"
    Check Blank(ReadAll("tests/out/resave.sc2")) = Blank(ReadAll("../samples/" & names(i))), "saved bytes equal the sample's: " & names(i)
    Check Len(ReadAll("../samples/" & names(i))) = 72 + 64 * 134, "72-byte header and 64 records of 134 bytes"
Next
r = LoadDesign(d, "../samples/Mounting Plate.sc98")
Check r = 6, "open Mounting Plate.sc98: upgraded (" & r & ")"
Check SaveDesign(d, "tests/out/upgraded.sc2"), "save the upgraded part"
Dim up As String = ReadAll("tests/out/upgraded.sc2")
Check Left(up, 4) = "SC2K" And up[4] = 6 And up[5] = 0, "it is SC2K version 6"
Check LoadDesign(d, "tests/out/upgraded.sc2") = 0, "and it opens as a SolidCraft 2000 part"

' ---- a design with everything from Service Pack 1 ----
NewDesign d, "Everything"
Feat d, FK_SKETCH_RECT, 0, 80, 50, -40, -25, 0, 0
Feat d, FK_EXTRUDE, 1, 12, 0, 0, 0, 0, 0
Feat d, FK_CHAMFER, 2, 2, 0, 0, 0, 0, 0
d.F(3).Rsv(1) = SIDES_ALL - 5: d.F(3).Rsv(2) = 15
Feat d, FK_HOLE, 2, 5, 0, 0, 0, 0, 6
d.F(4).Rsv(1) = 30: d.F(4).Rsv(2) = 20
Check SaveVersion(d) = 7, "a chamfer and a pattern make a version 7 part"
For i = 1 To d.Count: Check RefOk(d, i), d.F(i).Name & " builds: " & Describe(d, i): Next
MeshCheck d, "chamfered, with a bolt circle", True
Check SaveDesign(d, "tests/out/sp1.sc2"), "save it"
Dim d2 As TDesign
Check LoadDesign(d2, "tests/out/sp1.sc2") = 0, "open it"
Check d2.F(4).Rsv(1) = 30 And d2.F(3).Rsv(2) = 15 And d2.F(4).P3 = 6, "hole pattern and chosen edges kept"

NewDesign d, "Rounded"
Feat d, FK_SKETCH_RECT, 0, 60, 40, 0, 0, 0, 6
Feat d, FK_EXTRUDE, 1, 10, 0, 0, 0, 0, 0
Feat d, FK_FILLET, 2, 3, 0, 0, 0, 0, 0
d.F(3).Rsv(2) = 15
Feat d, FK_SKETCH_CIRCLE, 2, 8, 0, 30, 20, 0, 0
Feat d, FK_EXTRUDE, 4, 15, 0, 0, 0, 0, 0
Feat d, FK_FILLET, 5, 2, 0, 0, 0, 0, 0
Feat d, FK_HOLE, 5, 6, 0, 30, 20, 0, 1
For i = 1 To d.Count: Check RefOk(d, i), d.F(i).Name & " builds": Next
MeshCheck d, "filleted top and bottom, with a filleted boss and a bore", True

NewDesign d, "Front and back"
Feat d, FK_SKETCH_RECT, 0, 60, 40, 0, 0, 0, 0
Feat d, FK_EXTRUDE, 1, 10, 0, 0, 0, 0, 0
Feat d, FK_FILLET, 2, 3, 0, 0, 0, 0, 0
d.F(3).Rsv(1) = SIDES_ALL - 5
MeshCheck d, "fillet on the front and back of the top only", True

NewDesign d, "Side face"
Feat d, FK_SKETCH_RECT, 0, 60, 40, 0, 0, 0, 0
Feat d, FK_EXTRUDE, 1, 10, 0, 0, 0, 0, 0
Feat d, FK_SKETCH_RECT, 2, 20, 6, 10, 2, 0, 0
d.F(3).Rsv(1) = FACE_RIGHT
Feat d, FK_EXTRUDE, 3, 8, 0, 0, 0, 0, 0
Check RefOk(d, 3) And RefOk(d, 4), "a sketch on the right face and its extrude build"
Dim e() As TEdge
Dim ne As Long = Regenerate(d, e())
Dim As Double maxx = -1E+30
For i = 0 To ne - 1
    If e(i).X1 > maxx Then maxx = e(i).X1
Next
Check Abs(maxx - 68) < 0.0001, "the boss grows out of the right face, to x = 68 (" & maxx & ")"
MeshCheck d, "a boss on a side face", True

' ---- sheet metal and the flat pattern ----
r = LoadDesign(d, "../samples/Sheet Metal Tray.sc2")
For i = 1 To d.Count: Check RefOk(d, i), d.F(i).Name & " builds: " & Describe(d, i): Next
MeshCheck d, "sheet metal tray", True
Dim b As Long
For i = 1 To d.Count
    If d.F(i).Kind = FK_SM_BASE Then b = i
Next
Check WriteFlatDxf(d, b, "tests/out/TRAY~1.DXF"), "the flat pattern's DXF is written"
Check InStr(ReadAll("tests/out/TRAY~1.DXF"), "OUTLINE") > 0 And InStr(ReadAll("tests/out/TRAY~1.DXF"), "BEND") > 0, "with an OUTLINE layer and a BEND layer"

Dim t() As TTri, sErr As String
Dim nt As Long = MeshDesign(d, t(), MESH_SEGS, sErr)
Check WriteStl(t(), nt, "tests/out/tray.stl", d.Title), "the STL is written"

If Fails Then Print #9, Fails; " checks failed": End 1
Print #9, "ALL OK"
