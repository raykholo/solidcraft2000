' app.bas - the main window: menus, toolbar, status bar, the commands and
' the main loop. A port of the Windows version's frmMain and modCommands.

Const APP_NAME = "SolidCraft 2000"
Const APP_EDITION = "Professional Edition"
Const APP_BUILD = "Build 2000.0214"
Const APP_VERSION = "Version 1.2.0"
Const PART_EXT = "sc2"

Dim Shared FullScreenMode As Boolean
Dim Shared TitleH As Long          ' our own title bar, full screen only
Const MENU_H = 19
Const TOOL_H = 29
Const STATUS_H = 22

' ---- menus ----

Type TMenuItem
    caption As String
    shortcut As String
    cmd As String
End Type

Const NMENUS = 8
Const MENU_WINDOW = 6
Dim Shared MenuTitles(0 To NMENUS - 1) As ZString * 14 = {"&File", "&Edit", "&Sketch", "Fea&tures", "Sheet &Metal", "&View", "&Window", "&Help"}
Dim Shared MenuItems(0 To NMENUS - 1, 0 To 15) As TMenuItem
Dim Shared MenuItemCount(0 To NMENUS - 1) As Long
Dim Shared MenuX(0 To NMENUS) As Long
Dim Shared OpenMenu As Long = -1
Dim Shared HotItem As Long = -1
Dim Shared MenuKeyboard As Boolean

Sub AddMenuItem(ByVal m As Long, ByRef caption As String, ByRef cmd As String = "", ByRef shortcut As String = "")
    Dim As Long i = MenuItemCount(m)
    MenuItems(m, i).caption = caption: MenuItems(m, i).cmd = cmd: MenuItems(m, i).shortcut = shortcut
    MenuItemCount(m) += 1
End Sub

Declare Function StabilityPackInstalled() As Boolean

Sub BuildMenus()
    AddMenuItem 0, "&New Part", "New", "Ctrl+N"
    AddMenuItem 0, "&Open...", "Open", "Ctrl+O"
    AddMenuItem 0, "&Save", "Save", "Ctrl+S"
    AddMenuItem 0, "Save &As...", "SaveAs"
    AddMenuItem 0, "Sen&d To 3 1/2 Floppy (A:)...", "SaveFloppy"
    AddMenuItem 0, "Publish to &Web...", "Publish"
    AddMenuItem 0, "Export for &Rapid Prototyping (*.stl)...", "ExportStl"
    AddMenuItem 0, "&Close", "Close"
    AddMenuItem 0, "-"
    AddMenuItem 0, "E&xit", "Exit"
    AddMenuItem 0, "Show &all items", "More", ">>"
    AddMenuItem 1, "&Undo", "Undo", "Ctrl+Z"
    AddMenuItem 1, "&Redo", "Redo", "Ctrl+Y"
    AddMenuItem 1, "-"
    AddMenuItem 1, "&Edit Feature...", "Edit", "Enter"
    AddMenuItem 1, "&Delete Feature", "Delete", "Del"
    AddMenuItem 2, "&Rectangle...", "SketchRect", "R"
    AddMenuItem 2, "&Circle...", "SketchCircle", "C"
    AddMenuItem 3, "&Extrude...", "Extrude", "E"
    AddMenuItem 3, "Re&volve...", "Revolve", "V"
    AddMenuItem 3, "&Hole...", "Hole", "H"
    AddMenuItem 3, "Fi&llet... (New!)", "Fillet", "L"
    AddMenuItem 3, "Cha&mfer... (SP1)", "Chamfer", "M"
    AddMenuItem 3, "Show &all items", "More", ">>"
    AddMenuItem 4, "&Base Flange...", "SMBase"
    AddMenuItem 4, "&Edge Flange...", "SMEdge"
    AddMenuItem 4, "&Flat Pattern", "SMFlat"
    AddMenuItem 4, "-"
    AddMenuItem 4, "Bend &Table Wizard...", "BendTable"
    AddMenuItem 5, "&Isometric", "ViewIso", "I"
    AddMenuItem 5, "Zoom to &Fit", "ZoomFit", "F"
    AddMenuItem 5, "&Regenerate", "Regen", "F5"
    AddMenuItem 5, "&Shaded", "Shaded", "S"
    AddMenuItem 5, "-"
    AddMenuItem 5, "&Turbo", "Turbo"
    AddMenuItem 5, "Show &all items", "More", ">>"
    AddMenuItem MENU_WINDOW, "&Cascade", "Cascade"
    AddMenuItem MENU_WINDOW, "Tile &Horizontally", "TileH"
    AddMenuItem MENU_WINDOW, "Tile &Vertically", "TileV"
    AddMenuItem 7, "&Contents", "Help", "F1"
    AddMenuItem 7, "&Upgrade from SolidCraft 98...", "Upgrade"
    AddMenuItem 7, "Install &Stability Pack...", "StabilityPack"
    AddMenuItem 7, "-"
    AddMenuItem 7, "&About SolidCraft 2000...", "About"
End Sub

Function MenuChecked(ByRef cmd As String) As Boolean
    Select Case cmd
    Case "Shaded": Return ViewShaded
    Case "Turbo": Return Turbo
    End Select
    Return False
End Function

' ---- Personalized Menus (new in 2000) ----
'
' The File, Features and View menus show only the items you use. The rest
' wait behind "Show all items" at the bottom, which opens the menu again with
' everything in it. Use an item and it stays in the short menu from then on
' (for this run: nothing is written anywhere). Keyboard shortcuts of hidden
' items don't work, because Windows takes a hidden item's shortcut with it.
' That is how it was, and it is why people turned this off.

Const SHOWN_AT_FIRST = "|New|Open|Save|Exit|Extrude|Hole|Fillet|Chamfer|ViewIso|ZoomFit|Regen|Shaded|"
Dim Shared AdaptUsed As String          ' "|Cmd|" for each item used this run
Dim Shared AdaptExpanded As Boolean     ' "Show all items" was chosen and nothing since

Function IsAdaptive(ByVal m As Long) As Boolean
    Return m = 0 Or m = 3 Or m = 5
End Function

Function AdaptiveShows(ByRef cmd As String) As Boolean
    If AdaptExpanded Then Return True
    Return InStr(SHOWN_AT_FIRST & AdaptUsed, "|" & cmd & "|") > 0
End Function

Sub AdaptiveUsed(ByRef cmd As String)
    If cmd = "More" Or Len(cmd) = 0 Then Exit Sub
    If InStr(SHOWN_AT_FIRST & AdaptUsed, "|" & cmd & "|") = 0 Then AdaptUsed &= "|" & cmd & "|"
    AdaptExpanded = False
End Sub

' Is item k of menu m in the menu right now? A separator shows only if
' something after it does, and "Show all items" only if something is hidden.
Function ItemVisible(ByVal m As Long, ByVal k As Long) As Boolean
    Dim As Long j
    Dim As Boolean anyHidden, after
    If Not IsAdaptive(m) Then Return True
    Dim As String c = MenuItems(m, k).cmd
    If c = "More" Then
        For j = 0 To MenuItemCount(m) - 1
            If MenuItems(m, j).cmd <> "More" And MenuItems(m, j).caption <> "-" Then
                If Not AdaptiveShows(MenuItems(m, j).cmd) Then anyHidden = True
            End If
        Next j
        Return anyHidden
    End If
    If MenuItems(m, k).caption = "-" Then
        For j = k + 1 To MenuItemCount(m) - 1
            If MenuItems(m, j).caption <> "-" And MenuItems(m, j).cmd <> "More" Then
                If AdaptiveShows(MenuItems(m, j).cmd) Then after = True
            End If
        Next j
        Return after
    End If
    Return AdaptiveShows(c)
End Function

' The k-th item of menu m that's showing.
Function VisibleItem(ByVal m As Long, ByVal n As Long) As Long
    Dim As Long k, c
    For k = 0 To MenuItemCount(m) - 1
        If ItemVisible(m, k) Then
            If c = n Then Return k
            c += 1
        End If
    Next k
    Return -1
End Function

Function VisibleCount(ByVal m As Long) As Long
    Dim As Long k, c
    For k = 0 To MenuItemCount(m) - 1
        If ItemVisible(m, k) Then c += 1
    Next k
    Return c
End Function

' The Window menu ends with the open parts, numbered, as MDI did.
Function WindowMenuCount() As Long
    Return MenuItemCount(MENU_WINDOW) + IIf(ZCount > 0, 1 + ZCount, 0)
End Function

Function MenuItemAt(ByVal m As Long, ByVal i As Long) As TMenuItem
    If m = MENU_WINDOW And i >= MenuItemCount(MENU_WINDOW) Then
        Dim it As TMenuItem
        If i = MenuItemCount(MENU_WINDOW) Then it.caption = "-": Return it
        Dim As Long k = i - MenuItemCount(MENU_WINDOW) - 1
        Dim As Long p = ZOrder(k)
        it.caption = "&" & (k + 1) & " " & Docs(Parts(p).slot).Title
        it.cmd = "Window" & p
        Return it
    End If
    Dim As TMenuItem r = MenuItems(m, VisibleItem(m, i))
    If r.cmd = "StabilityPack" Then
        If StabilityPackInstalled() Then r.caption = "Uninstall &Stability Pack..."
    End If
    Return r
End Function

Function ItemsIn(ByVal m As Long) As Long
    If m = MENU_WINDOW Then Return WindowMenuCount()
    Return VisibleCount(m)
End Function

Sub MenuGeometry()
    Dim As Long i, x = 2
    For i = 0 To NMENUS - 1
        MenuX(i) = x
        x += TextW(AmpStrip(MenuTitles(i))) + 14
    Next
    MenuX(NMENUS) = x
End Sub

Sub DropRect(ByVal m As Long, ByRef x As Long, ByRef y As Long, ByRef w As Long, ByRef h As Long)
    Dim As Long i, wc, ws
    w = 0: h = 0
    For i = 0 To ItemsIn(m) - 1
        Dim it As TMenuItem = MenuItemAt(m, i)
        If TextW(AmpStrip(it.caption)) > wc Then wc = TextW(AmpStrip(it.caption))
        If TextW(it.shortcut) > ws Then ws = TextW(it.shortcut)
        h += IIf(it.caption = "-", 8, 17)
    Next
    w = 20 + wc + 24 + ws + 16
    h += 6
    x = MenuX(m): y = TitleH + MENU_H
    If x + w > ScrW Then x = ScrW - w
End Sub

Sub DrawMenuBar()
    Dim As Long i, y = TitleH
    Fill 0, y, ScrW, MENU_H, C_FACE
    For i = 0 To NMENUS - 1
        Dim As Long w = MenuX(i + 1) - MenuX(i)
        If i = OpenMenu Then Bevel MenuX(i), y + 1, w, MENU_H - 2, BEV_THIN_DOWN
        TextAmp MenuX(i) + 7 + IIf(i = OpenMenu, 1, 0), y + 4 + IIf(i = OpenMenu, 1, 0), MenuTitles(i), C_TEXT
    Next
End Sub

Sub DrawDropdown()
    If OpenMenu < 0 Then Exit Sub
    Dim As Long x, y, w, h, i, iy
    DropRect OpenMenu, x, y, w, h
    Fill x, y, w, h, C_FACE
    Bevel x, y, w, h, BEV_RAISED
    iy = y + 3
    For i = 0 To ItemsIn(OpenMenu) - 1
        Dim it As TMenuItem = MenuItemAt(OpenMenu, i)
        If it.caption = "-" Then
            HLine x + 3, iy + 3, w - 6, C_SHADOW: HLine x + 3, iy + 4, w - 6, C_HILITE
            iy += 8
            Continue For
        End If
        Dim As Boolean hot = (i = HotItem)
        Dim As ULong tc = IIf(hot, C_SELTEXT, C_TEXT)
        If hot Then Fill x + 3, iy, w - 6, 17, C_SEL
        If MenuChecked(it.cmd) Then
            ' a tick
            Dim As Long k
            For k = 0 To 2: Fill x + 7 + k, iy + 7 + k, 1, 3, tc: Next
            For k = 0 To 3: Fill x + 10 + k, iy + 8 - k, 1, 3, tc: Next
        End If
        TextAmp x + 20, iy + 3, it.caption, tc
        If Len(it.shortcut) Then Text x + w - 16 - TextW(it.shortcut), iy + 3, it.shortcut, tc
        iy += 17
    Next
End Sub

Function DropItemAt(ByVal mx As Long, ByVal my As Long) As Long
    Dim As Long x, y, w, h, i, iy
    If OpenMenu < 0 Then Return -2
    DropRect OpenMenu, x, y, w, h
    If mx < x Or mx >= x + w Or my < y Or my >= y + h Then Return -2
    iy = y + 3
    For i = 0 To ItemsIn(OpenMenu) - 1
        Dim As Long ih = IIf(MenuItemAt(OpenMenu, i).caption = "-", 8, 17)
        If my >= iy And my < iy + ih Then Return IIf(ih = 8, -1, i)
        iy += ih
    Next
    Return -1
End Function

Function MenuTitleAt(ByVal mx As Long, ByVal my As Long) As Long
    Dim i As Long
    If my < TitleH Or my >= TitleH + MENU_H Then Return -1
    For i = 0 To NMENUS - 1
        If mx >= MenuX(i) And mx < MenuX(i + 1) Then Return i
    Next
    Return -1
End Function

' ---- toolbar ----

Type TButton
    key As String
    tip As String
    x As Long
    w As Long
End Type

Dim Shared Buttons(0 To 20) As TButton
Dim Shared ButtonCount As Long
Dim Shared HotButton As Long = -1, DownButton As Long = -1
Dim Shared HoverStart As Double
Dim Shared TooltipText As String

Sub AddButton(ByRef key As String, ByRef tip As String)
    Dim As Long x = IIf(ButtonCount > 0, Buttons(ButtonCount - 1).x + Buttons(ButtonCount - 1).w, 4)
    Buttons(ButtonCount).key = key: Buttons(ButtonCount).tip = tip
    Buttons(ButtonCount).x = x: Buttons(ButtonCount).w = IIf(Len(key), 24, 8)
    ButtonCount += 1
End Sub

Sub BuildToolbar()
    AddButton "New", "New Part (Ctrl+N)"
    AddButton "Open", "Open Part (Ctrl+O)"
    AddButton "Save", "Save Part (Ctrl+S)"
    AddButton "", ""
    AddButton "SketchRect", "Sketch Rectangle (R)"
    AddButton "SketchCircle", "Sketch Circle (C)"
    AddButton "", ""
    AddButton "Extrude", "Extrude (E)"
    AddButton "Revolve", "Revolve (V)"
    AddButton "Hole", "Hole (H)"
    AddButton "Fillet", "Fillet (L). New in SolidCraft 2000!"
    AddButton "Chamfer", "Chamfer (M). New in Service Pack 1!"
    AddButton "", ""
    AddButton "Orbit", "Isometric View (I). Drag in the viewport to orbit."
    AddButton "Shaded", "Shaded (S). Rendered in software, properly."
    AddButton "ZoomFit", "Zoom to Fit (F)"
    AddButton "Regen", "Regenerate (F5)"
    AddButton "", ""
    AddButton "Turbo", "Turbo. Makes everything faster. (It doesn't.)"
End Sub

Function ToolTop() As Long
    Return TitleH + MENU_H
End Function

Function ButtonAt(ByVal mx As Long, ByVal my As Long) As Long
    Dim i As Long
    If my < ToolTop() + 3 Or my >= ToolTop() + 3 + 23 Then Return -1
    For i = 0 To ButtonCount - 1
        If Len(Buttons(i).key) And mx >= Buttons(i).x And mx < Buttons(i).x + Buttons(i).w Then Return i
    Next
    Return -1
End Function

' One seven-segment digit, 10 x 15. Unlit segments glow a little.
Sub SevenSeg(ByVal x As Long, ByVal y As Long, ByRef dg As String)
    Dim As String lit
    Select Case dg
    Case "0": lit = "1111110"
    Case "1": lit = "0110000"
    Case "2": lit = "1101101"
    Case "3": lit = "1111001"
    Case "4": lit = "0110011"
    Case "5": lit = "1011011"
    Case "6": lit = "1011111"
    Case "7": lit = "1110000"
    Case "8": lit = "1111111"
    Case "9": lit = "1111011"
    Case Else: lit = "0000001"
    End Select
    Dim As Long k
    For k = 1 To 7
        Dim As ULong c = IIf(Mid(lit, k, 1) = "1", &hFFFF2000, &hFF400000)
        Select Case k
        Case 1: Fill x + 2, y, 7, 3, c
        Case 2: Fill x + 8, y + 1, 3, 7, c
        Case 3: Fill x + 8, y + 8, 3, 7, c
        Case 4: Fill x + 2, y + 13, 7, 3, c
        Case 5: Fill x, y + 8, 3, 7, c
        Case 6: Fill x, y + 1, 3, 7, c
        Case 7: Fill x + 2, y + 7, 7, 2, c
        End Select
    Next
End Sub

Sub DrawToolbar()
    Dim As Long i, y = ToolTop()
    Fill 0, y, ScrW, TOOL_H, C_FACE
    HLine 0, y, ScrW, C_HILITE
    HLine 0, y + TOOL_H - 1, ScrW, C_SHADOW
    For i = 0 To ButtonCount - 1
        Dim As Long bx = Buttons(i).x, by = y + 3, bw = Buttons(i).w, off = 0
        If Len(Buttons(i).key) = 0 Then
            VLine bx + 3, by + 1, 22, C_SHADOW: VLine bx + 4, by + 1, 22, C_HILITE
            Continue For
        End If
        Dim As Boolean latched = MenuChecked(Buttons(i).key)
        If (i = DownButton And i = HotButton) Or latched Then
            Bevel bx, by, bw, 23, BEV_THIN_DOWN: off = 1
        ElseIf i = HotButton And DownButton < 0 Then
            Bevel bx, by, bw, 23, BEV_THIN_UP
        End If
        DrawIcon bx + (bw - 16) \ 2 + off, by + 3 + off, Buttons(i).key
    Next
    ' the LED: two red digits and MHz
    Dim As Long lx = Buttons(ButtonCount - 1).x + Buttons(ButtonCount - 1).w + 6, ly = y + 4
    Bevel lx, ly, 32, 21, BEV_THIN_DOWN
    Fill lx + 1, ly + 1, 30, 19, &hFF180000
    Dim As String dg = IIf(Turbo, "33", "66")
    SevenSeg lx + 4, ly + 3, Mid(dg, 1, 1)
    SevenSeg lx + 17, ly + 3, Mid(dg, 2, 1)
    Text lx + 35, ly + 5, "MHz", C_TEXT
End Sub

' ---- status bar ----

Dim Shared StatusMsg As String
Dim Shared StatusFps As String
Dim Shared ClockText As String

Sub SetStatus(ByRef t As String)
    StatusMsg = t
    LogLine "status: " & t
    NeedRedraw = True
End Sub

Sub SetFps(ByRef t As String)
    StatusFps = t: NeedRedraw = True
End Sub

Sub DrawStatusBar()
    Dim As Long y = ScrH - STATUS_H, i
    Fill 0, y, ScrW, STATUS_H, C_FACE
    Dim As Long wClock = 74, wFps = 110, wUnits = 40
    Dim As Long wMsg = ScrW - (wClock + wFps + wUnits + 2 * 4) - 4 - 14
    Dim As Long x = 2
    Bevel x, y + 2, wMsg, STATUS_H - 3, BEV_THIN_DOWN
    ClipTo x + 1, y + 2, wMsg - 2, STATUS_H - 3
    Text x + 3, y + 6, StatusMsg, C_TEXT
    NoClip
    x += wMsg + 2
    Bevel x, y + 2, wUnits, STATUS_H - 3, BEV_THIN_DOWN: Text x + 3, y + 6, "mm", C_TEXT: x += wUnits + 2
    Bevel x, y + 2, wFps, STATUS_H - 3, BEV_THIN_DOWN: Text x + 3, y + 6, StatusFps, C_TEXT: x += wFps + 2
    Bevel x, y + 2, wClock, STATUS_H - 3, BEV_THIN_DOWN: Text x + 3, y + 6, ClockText, C_TEXT
    For i = 0 To 2
        DrawLine ScrW - 3 - i * 4, ScrH - 2, ScrW - 1, ScrH - 4 - i * 4, C_HILITE
        DrawLine ScrW - 2 - i * 4, ScrH - 2, ScrW - 1, ScrH - 3 - i * 4, C_SHADOW
    Next
End Sub

' ---- the frame ----

Sub DrawTitleBar()
    If TitleH = 0 Then Exit Sub
    Fill 0, 0, ScrW, TitleH, C_FACE
    GradientH 2, 2, ScrW - 4, TitleH - 3, C_TITLE1, C_TITLE2
    DrawIcon 4, 3, "App"
    Text 24, 6, APP_NAME, C_HILITE, True
    DrawCaptionButton ScrW - 20, 4, 2, False
    DrawCaptionButton ScrW - 38, 4, 3, True
    DrawCaptionButton ScrW - 54, 4, 0, True
End Sub

Sub DrawTooltip()
    If Len(TooltipText) = 0 Then Exit Sub
    Dim As Long w = TextW(TooltipText) + 8, x = MouseX + 2, y = MouseY + 22
    If x + w > ScrW Then x = ScrW - w
    Fill x, y, w, 17, C_INFO
    Frame x, y, w, 17, C_DARK
    Text x + 4, y + 3, TooltipText, C_TEXT
End Sub

Sub AppRender()
    Dim As Long i
    DrawTitleBar
    DrawMenuBar
    DrawToolbar
    ' the MDI area: dark grey, with the parts on it
    Fill 0, MdiY, ScrW, MdiH, C_APPWORK
    ClipTo 0, MdiY, ScrW, MdiH
    For i = 0 To ZCount - 1
        DrawPartWindow ZOrder(i), i = ZCount - 1
    Next
    NoClip
    DrawCal
    DrawStatusBar
    DrawDropdown
    DrawTooltip
End Sub

' ---- Turbo ----

Function OrbitFrameInterval() As Double
    Return IIf(Turbo, 0.25, 0)
End Function

Function Y2KDimension() As String
    Return "19" & (Year(ClockNow()) - 1900)
End Function

' Variant everything; converges on the third try.
Function SolverConverges(ByRef nTries As Long) As Boolean
    If Not Turbo Then Return True
    nTries += 1
    If nTries < 3 Then
        MsgBox "Did not converge. Try again." & Chr(10) & Chr(10) & "Residual: 0." & String(3 - nTries, "9") & "1", MB_EXCLAMATION, "Constraint Solver"
        Return False
    End If
    nTries = 0
    MsgBox "Converged. See? Variant works.", MB_INFO, "Constraint Solver"
    Return True
End Function

Sub RefreshAllParts()
    Dim i As Long
    For i = 0 To ZCount - 1
        PartRefreshAll ZOrder(i), False
    Next
End Sub

Sub SetTurbo(ByVal bOn As Boolean)
    Turbo = bOn
    If Not Turbo Then Y2KHappened = False
    RefreshAllParts
    If Turbo Then SetStatus "Turbo on: 33 MHz. Authentic 1999 behaviour enabled." Else SetStatus "Turbo off: 66 MHz. Everything works again."
End Sub

' ---- the fatal exception (Turbo, divide by zero; and, every 15 minutes or so, on schedule) ----

Dim Shared FatalScheduled As Boolean      ' the every-15-minutes crash, not a divide by zero

Function FatalLines(sOut() As String) As Long
    If FatalScheduled Then
        ReDim sOut(0 To 7)
        sOut(0) = "A fatal exception 0E has occurred at 0028:C0FFEE00 in VXD FILLET(01) +"
        sOut(1) = "00002000. This was called from 0028:C0012000 in VXD SHEETMTL(03) +"
        sOut(2) = "00000D1V. It has been about fifteen minutes, so this was expected."
        sOut(3) = ""
        sOut(4) = "Your part has not been terminated. Nothing was lost. It never is."
        sOut(5) = ""
        sOut(6) = "*  Press any key to return to SolidCraft 2000."
        sOut(7) = "*  To stop this happening, install the Stability Pack (Help menu)."
        Return 8
    End If
    ReDim sOut(0 To 8)
    sOut(0) = "A fatal exception 0E has occurred at 0028:SOLIDCRAFT+00000D1V0."
    sOut(1) = "Something somewhere was divided by zero, which even a VB program"
    sOut(2) = "knows better than to do."
    sOut(3) = ""
    sOut(4) = "The current part will not be terminated. It is fine. It was"
    sOut(5) = "never in any danger."
    sOut(6) = ""
    sOut(7) = "*  Press any key to return to SolidCraft 2000."
    sOut(8) = "*  Then type a number that isn't zero."
    Return 9
End Function

Sub FatalDraw(ByVal dp As Any Ptr)
    Dim As Long y = ScrH \ 2 - 140, x = ScrW \ 2 - 300
    Fill 0, 0, ScrW, ScrH, &hFF0000AA
    Dim As String t = " SolidCraft "
    Dim As Long tw = TextW(t, True, 2)
    Fill ScrW \ 2 - tw \ 2 - 4, y, tw + 8, 26, &hFFAAAAAA
    TextAt ScrW \ 2 - tw \ 2, y + 2, t, &hFF0000AA, False, 2
    Dim lines() As String
    Dim As Long i, n = FatalLines(lines()), mw
    For i = 0 To n - 1
        If TextW(lines(i), False, 2) > mw Then mw = TextW(lines(i), False, 2)
    Next
    x = (ScrW - mw) \ 2
    If x < 4 Then x = 4
    For i = 0 To n - 1
        TextAt x, y + 50 + i * 26, lines(i), C_HILITE, False, 2
    Next
    TextAt ScrW \ 2 - 110, y + 50 + (n + 1) * 26, "Press any key to continue " & IIf(CLng(Timer * 2) Mod 2, "_", " "), C_HILITE, False, 2
End Sub

Function FatalReadOut(ByVal dp As Any Ptr) As String
    If FatalScheduled Then
        Return "The whole screen is blue: A fatal exception 0E has occurred at 0028:C0FFEE00 in VXD FILLET(01) +00002000. " & _
            "It has been about fifteen minutes, so this was expected. Your part has not been terminated. Nothing was lost. " & _
            "Press any key to return to SolidCraft 2000. To stop this happening, install the Stability Pack (Help menu)."
    End If
    Return "The whole screen is blue: A fatal exception 0E has occurred at 0028:SOLIDCRAFT+00000D1V0. " & _
        "Something somewhere was divided by zero. The current part will not be terminated. It is fine. " & _
        "Press any key to return to SolidCraft 2000. Then type a number that isn't zero."
End Function

Function FatalKey(ByVal dp As Any Ptr, ByRef ev As UIEvent) As Boolean
    Dim As TDlg Ptr d = dp
    d->done = True
    Return True
End Function

Function FatalMouse(ByVal dp As Any Ptr, ByRef ev As UIEvent) As Boolean
    Dim As TDlg Ptr d = dp
    If ev.kind = EV_DOWN Then d->done = True       ' a click closes it, as a key does
    Return True
End Function

Dim Shared FatalOpen As Boolean

Sub ShowFatal()
    Dim d As TDlg
    If FatalOpen Then Exit Sub
    FatalOpen = True
    d.noFrame = True
    d.x = 0: d.y = 0: d.w = ScrW: d.h = ScrH
    d.drawFn = @FatalDraw
    d.readOutFn = @FatalReadOut
    d.keyFn = @FatalKey
    d.mouseFn = @FatalMouse
    d.focus = -1
    RunDialog d
    FatalOpen = False
    FatalScheduled = False
End Sub

' ---- About ----

Sub IsoPt(ByVal x As Double, ByVal y As Double, ByVal z As Double, ByVal s As Double, ByVal ox As Long, ByVal oy As Long, ByRef sx As Long, ByRef sy As Long)
    sx = ox + (x - y) * 0.866 * s
    sy = oy + (x + y) * 0.5 * s - z * s
End Sub

' The 2000 logo: an isometric block with a hole in the top, and its top
' edges filleted (new in 2000): a ring a little way down the sides, another
' a little way in at the top, and a short line at each corner between them.
Sub DrawLogo(ByVal ox As Long, ByVal oy As Long, ByVal s As Double, ByVal c As ULong)
    Dim As Long px(0 To 3), py(0 To 3), qx(0 To 3), qy(0 To 3), tx(0 To 3), ty(0 To 3), i, k
    Const FIL = 0.4
    IsoPt 0, 0, 0, s, ox, oy, px(0), py(0): IsoPt 4, 0, 0, s, ox, oy, px(1), py(1)
    IsoPt 4, 3, 0, s, ox, oy, px(2), py(2): IsoPt 0, 3, 0, s, ox, oy, px(3), py(3)
    IsoPt 0, 0, 1.5 - FIL, s, ox, oy, qx(0), qy(0): IsoPt 4, 0, 1.5 - FIL, s, ox, oy, qx(1), qy(1)
    IsoPt 4, 3, 1.5 - FIL, s, ox, oy, qx(2), qy(2): IsoPt 0, 3, 1.5 - FIL, s, ox, oy, qx(3), qy(3)
    IsoPt FIL, FIL, 1.5, s, ox, oy, tx(0), ty(0): IsoPt 4 - FIL, FIL, 1.5, s, ox, oy, tx(1), ty(1)
    IsoPt 4 - FIL, 3 - FIL, 1.5, s, ox, oy, tx(2), ty(2): IsoPt FIL, 3 - FIL, 1.5, s, ox, oy, tx(3), ty(3)
    For i = 0 To 3
        For k = 0 To 1
            DrawLine px(i) + k, py(i), px((i + 1) Mod 4) + k, py((i + 1) Mod 4), c
            DrawLine qx(i) + k, qy(i), qx((i + 1) Mod 4) + k, qy((i + 1) Mod 4), c
            DrawLine tx(i) + k, ty(i), tx((i + 1) Mod 4) + k, ty((i + 1) Mod 4), c
            DrawLine px(i) + k, py(i), qx(i) + k, qy(i), c
            DrawLine qx(i) + k, qy(i), tx(i) + k, ty(i), c
        Next
    Next
    Dim As Long hx, hy
    IsoPt 2, 1.5, 1.5, s, ox, oy, hx, hy
    Dim As Double a
    For a = 0 To 2 * PI Step 0.02
        PSetC hx + Cos(a) * s * 0.75, hy + Sin(a) * s * 0.75 * 0.55, c
        PSetC hx + Cos(a) * s * 0.75 + 1, hy + Sin(a) * s * 0.75 * 0.55, c
    Next
End Sub

' A filled polygon, even-odd, with an outline.
Sub FillPoly(px() As Long, py() As Long, ByVal n As Long, ByVal fc As ULong, ByVal bc As ULong)
    Dim As Long i, j, y, y0 = py(0), y1 = py(0), nx, t
    Dim xs(0 To 63) As Long
    For i = 1 To n - 1
        If py(i) < y0 Then y0 = py(i)
        If py(i) > y1 Then y1 = py(i)
    Next
    For y = y0 To y1
        nx = 0
        j = n - 1
        For i = 0 To n - 1
            If (py(i) <= y And py(j) > y) Or (py(j) <= y And py(i) > y) Then
                If nx < 63 Then xs(nx) = px(i) + (y - py(i)) * (px(j) - px(i)) \ (py(j) - py(i)): nx += 1
            End If
            j = i
        Next
        For i = 1 To nx - 1
            For j = i To 1 Step -1
                If xs(j) < xs(j - 1) Then Swap xs(j), xs(j - 1)
            Next
        Next
        For i = 0 To nx - 2 Step 2
            HLine xs(i), y, xs(i + 1) - xs(i) + 1, fc
        Next
    Next
    For i = 0 To n - 1
        DrawLine px(i), py(i), px((i + 1) Mod n), py((i + 1) Mod n), bc
    Next
End Sub

' The box art's starburst, with two lines in it.
Sub DrawStarburst(ByVal cx As Long, ByVal cy As Long, ByVal r As Long, ByRef s1 As String, ByRef s2 As String)
    Const SPIKES = 14
    Dim As Long px(0 To 2 * SPIKES - 1), py(0 To 2 * SPIKES - 1), i
    Dim As Double a, rr
    For i = 0 To 2 * SPIKES - 1
        a = PI * i / SPIKES - PI / 2
        rr = IIf(i Mod 2 = 0, r, r * 0.74)
        px(i) = cx + Cos(a) * rr: py(i) = cy + Sin(a) * rr * 0.9
    Next
    FillPoly px(), py(), 2 * SPIKES, &hFFFFD600, &hFFC82800
    TextAt cx - TextW(s1, True) \ 2, cy - 12, s1, &hFFC80000, True
    TextAt cx - TextW(s2, True) \ 2, cy + 2, s2, &hFFC80000, True
End Sub

' The Y2K sticker: a gold seal.
Sub DrawY2KBadge(ByVal cx As Long, ByVal cy As Long, ByVal r As Long)
    Dim As Long x, y
    For y = -r To r
        For x = -r To r
            Dim As Long d2 = x * x + y * y
            If d2 <= r * r Then PSetC cx + x, cy + y, IIf(d2 > (r - 2) * (r - 2), &hFF9C6C18, IIf(d2 > (r - 5) * (r - 5), &hFFE6B430, &hFFF4D060))
        Next
    Next
    TextAt cx - TextW("Y2K", True) \ 2, cy - 5, "Y2K", &hFF402000, True
End Sub

Function MemoryKB() As String
    Dim As Long fh = FreeFile
    Dim As String l
    If Open("/proc/meminfo" For Input As #fh) = 0 Then
        Do Until EOF(fh)
            Line Input #fh, l
            If Left(l, 9) = "MemTotal:" Then
                Close #fh
                Dim As LongInt kb = ValLng(Trim(Mid(l, 10)))
                ' with thousands separators, so it still looks impressive
                Dim As String s = Str(kb), r
                Dim As Long i
                For i = 1 To Len(s)
                    r &= Mid(s, i, 1)
                    If (Len(s) - i) Mod 3 = 0 And i < Len(s) Then r &= ","
                Next
                Return r
            End If
        Loop
        Close #fh
    End If
    Return "65,536"
End Function

Sub AboutDraw(ByVal dp As Any Ptr)
    Dim As TDlg Ptr d = dp
    Dim As Long ox = ClientX(*d), oy = ClientY(*d)
    ' the logo panel: a blue gradient and the wireframe block
    GradientV ox + 12, oy + 12, 96, 96, &hFF78AAB4, &hFF005058
    Bevel ox + 11, oy + 11, 98, 98, BEV_THIN_DOWN
    DrawLogo ox + 58, oy + 54, 11, &hFFFFFFFF
    DrawY2KBadge ox + 92, oy + 94, 12
    TextAt ox + 124, oy + 12, APP_NAME, C_TEXT, True, 2
    HLine ox + 12, oy + 168, d->w - 30, C_SHADOW
    HLine ox + 12, oy + 169, d->w - 30, C_HILITE
End Sub

Function AboutReadOut(ByVal dp As Any Ptr) As String
    Return "A picture: the SolidCraft 2000 logo, a block with filleted edges and a hole in it, a Y2K sticker, and the name in big letters."
End Function

Dim Shared AboutTyped As String

Function AboutKey(ByVal dp As Any Ptr, ByRef ev As UIEvent) As Boolean
    If Len(ev.ch) Then
        AboutTyped = Right(AboutTyped & UCase(ev.ch), 5)
        If AboutTyped = "WIN98" Then AboutTyped = "": ShowCredits: Return True
    End If
    Return False
End Function

' Turbo on, Shift-click the logo: a setup program "updates" MSCOMCTL.OCX.
Function AboutMouse(ByVal dp As Any Ptr, ByRef ev As UIEvent) As Boolean
    Dim As TDlg Ptr d = dp
    Dim As Long ox = ClientX(*d), oy = ClientY(*d)
    If ev.kind = EV_DOWN And ev.shift And Turbo And ev.x >= ox + 12 And ev.x < ox + 108 And ev.y >= oy + 12 And ev.y < oy + 108 Then
        ShowSetup
        Return True
    End If
    Return False
End Function

Sub ShowAbout()
    Dim d As TDlg
    Dim i As Long
    d.title = "About " & APP_NAME
    d.w = 390: d.h = 244
    CenterDialog d
    AddCtl d, CT_LABEL, 124, 42, 250, 13, APP_VERSION & "  (" & APP_BUILD & ")"
    AddCtl d, CT_LABEL, 124, 64, 250, 70, APP_EDITION & Chr(10) & Chr(10) & "This product is licensed to:" & Chr(10) & _
        "    Machine Shop, Back Office PC" & Chr(10) & Chr(10)
    AddCtl d, CT_LABEL, 124, 128, 250, 40, "Physical memory available to Linux:" & Chr(10) & MemoryKB() & " KB" & Chr(10) & Chr(10) & "System stability:  Uptime: excellent"
    AddCtl d, CT_LABEL, 12, 176, 270, 26, "Warning: this computer program is protected by a sense" & Chr(10) & "of humour."
    i = AddCtl(d, CT_BUTTON, 290, 180, 75, 23, "OK", IDOK): d.c(i).isDefault = True: d.c(i).isCancel = True
    d.focus = i
    d.drawFn = @AboutDraw
    d.readOutFn = @AboutReadOut
    d.keyFn = @AboutKey
    d.mouseFn = @AboutMouse
    AboutTyped = ""
    RunDialog d
End Sub

' ---- the commands: everything is a command ----

Declare Sub CmdSave(ByVal bAs As Boolean)
Declare Sub SM_Command(ByRef sCmd As String)
Declare Sub ShowUpgrade()
Declare Sub StabilityPackCommand()
Declare Function Commit(ByVal p As Long, ByRef f As TFeature) As Boolean

Function NeedPart() As Long
    Dim As Long p = ActivePart()
    If p = 0 Then MsgBox "There is no part open." & Chr(10) & "Choose File, New Part first.", MB_EXCLAMATION
    Return p
End Function

Sub CmdNew()
    Dim As Long slot = NewDocSlot()
    If slot = 0 Then MsgBox "Too many parts open. Sixteen ought to be enough for anybody.", MB_EXCLAMATION: Exit Sub
    OpenPart slot
    SetStatus "New part created."
End Sub

Sub OpenFile(ByRef sPath As String)
    Dim As Long slot = NewDocSlot()
    If slot = 0 Then MsgBox "Too many parts open. Close one first.", MB_EXCLAMATION: Exit Sub
    If IsSolidCraftDesign(sPath) Then
        ' a design from SolidCraft itself: rebuilt here, saved as a new .sc2
        Busy = True: RenderFrame
        Dim As Boolean ok = ImportSolidCraft(sPath, Docs(slot))
        Busy = False
        If Not ok Then FreeDocSlot slot: Exit Sub
        DocPath(slot) = ""
    Else
        Dim As Long r = LoadDesign(Docs(slot), sPath)
        If r <> 0 And r <> 5 And r <> 6 Then
            FreeDocSlot slot
            MsgBox LastFileError, IIf(r = 4, MB_CRITICAL, MB_EXCLAMATION)
            Exit Sub
        End If
        If r = 5 Or r = 6 Then MsgBox LastFileError, MB_INFO
        DocPath(slot) = sPath
        Docs(slot).Title = FileTitle(sPath)
        ' an upgraded SolidCraft 98 part is saved as a new .sc2, never over the old file
        If LCase(Right(sPath, 5)) = ".sc98" Then DocPath(slot) = ""
    End If
    Dim As Long p = OpenPart(slot)
    PartZoomFit p
    SetStatus "Opened " & sPath
End Sub

Sub CmdOpen()
    Dim As String sPath = FileDialog(False, "", _
        "All SolidCraft files (*.sc2, *.sc98, *.solidcraft)|*.sc2;*.sc98;*.solidcraft|SolidCraft 2000 Parts (*.sc2)|*.sc2|SolidCraft 98 Parts (*.sc98)|*.sc98|SolidCraft Designs (*.solidcraft)|*.solidcraft", PART_EXT)
    If Len(sPath) = 0 Then Exit Sub
    OpenFile sPath
End Sub

Sub CmdSave(ByVal bAs As Boolean)
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As Long slot = Parts(p).slot
    Dim As String sPath = DocPath(slot)
    If bAs Or Len(sPath) = 0 Then
        sPath = FileDialog(True, Docs(slot).Title, "SolidCraft 2000 Parts (*.sc2)|*.sc2", PART_EXT)
        If Len(sPath) = 0 Then Exit Sub
    End If
    If SaveDesign(Docs(slot), sPath) Then
        DocPath(slot) = sPath
        Docs(slot).Title = FileTitle(sPath)
        DocDirty(slot) = False
        SetStatus "Saved " & sPath & " (" & FileLen(sPath) & " bytes)"
    Else
        MsgBox "Run-time error '75':" & Chr(10) & Chr(10) & LastFileError, MB_CRITICAL
    End If
End Sub

' Saving to drive A:. There isn't one, so the part goes to the hard disk
' first, and with Turbo on we put on a show of floppies for it.
Sub CmdFloppy()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Const PREVIEW_BYTES = 3686454   ' a 1280 x 960 24-bit BMP, "for faster opening"
    Dim As Long slot = Parts(p).slot
    If Not Turbo Then
        MsgBox "There is no drive A: on this PC." & Chr(10) & Chr(10) & "Use File, Save As to save the part to the hard disk.", MB_EXCLAMATION
        Exit Sub
    End If
    Dim As String sReal = DocPath(slot)
    If Len(sReal) = 0 Then
        Dim As String sDir = JoinPath(HomeDir(), "Documents")
        If Not IsDir(sDir) Then sDir = HomeDir()
        sReal = JoinPath(sDir, Docs(slot).Title & "." & PART_EXT)
        Dim As Long n = 1
        Do While IsFile(sReal)
            n += 1
            sReal = JoinPath(sDir, Docs(slot).Title & " (" & n & ")." & PART_EXT)
        Loop
    End If
    If Not SaveDesign(Docs(slot), sReal) Then MsgBox "Run-time error '75':" & Chr(10) & Chr(10) & LastFileError, MB_CRITICAL: Exit Sub
    DocPath(slot) = sReal: Docs(slot).Title = FileTitle(sReal): DocDirty(slot) = False
    Dim As Double nBytes = FileLen(sReal) + PREVIEW_BYTES
    If RunFloppy(FileTitle(sReal) & "." & PART_EXT, nBytes) Then
        MsgBox "Copied " & Format(nBytes, "#,##0") & " bytes to " & (-Int(-nBytes / FLOPPY_BYTES)) & " disks." & Chr(10) & Chr(10) & _
            "Turbo saves include an uncompressed preview bitmap, for speed." & Chr(10) & _
            "(This PC has no drive A:, so the part itself is safe in" & Chr(10) & sReal & ")", MB_INFO
    Else
        MsgBox "Copy cancelled. The part is safe in" & Chr(10) & sReal, MB_INFO
    End If
    SetStatus "Saved " & sReal
End Sub

Sub CmdExportStl()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As Long slot = Parts(p).slot
    Dim t() As TTri, sErr As String
    Dim As Long n = MeshDesign(Docs(slot), t(), MESH_SEGS, sErr)
    If n = 0 Then
        MsgBox "There is nothing solid to export." & Chr(10) & Chr(10) & "Sketches are flat. Extrude or revolve one first.", MB_EXCLAMATION
        Exit Sub
    End If
    Dim As String sPath = FileDialog(True, Docs(slot).Title & ".stl", "Stereolithography (*.stl)|*.stl", "stl")
    If Len(sPath) = 0 Then Exit Sub
    Busy = True: SetStatus "Writing " & n & " triangles..."
    RenderFrame
    Dim As Boolean ok = WriteStl(t(), n, sPath, Docs(slot).Title)
    Busy = False
    If Not ok Then MsgBox "Could not write " & sPath, MB_CRITICAL: Exit Sub
    SetStatus "Exported " & sPath & " (" & n & " triangles)"
    If Len(sErr) Then
        MsgBox "Exported " & n & " triangles, but left out: " & sErr, MB_EXCLAMATION, "Export for Rapid Prototyping"
    Else
        MsgBox "Exported " & n & " triangles to" & Chr(10) & sPath & Chr(10) & Chr(10) & _
            "Send it to your service bureau. Allow 3 to 5 working days.", MB_INFO, "Export for Rapid Prototyping"
    End If
End Sub

Sub CmdShaded()
    ViewShaded = Not ViewShaded
    If Not ViewShaded Then SetStatus "Wireframe."
    RefreshAllParts
End Sub

Sub CmdClose()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    If PartQueryClose(p) Then ClosePartWindow p
End Sub

Sub CmdExit()
    ' each unsaved part asks for itself; Cancel on any stops the exit
    Do While ZCount > 0
        Dim As Long p = ZOrder(ZCount - 1)
        If Not PartQueryClose(p) Then Exit Sub
        ClosePartWindow p
    Loop
    QuitRequested = True
End Sub

' ---- features ----

Function Commit(ByVal p As Long, ByRef f As TFeature) As Boolean
    Dim As Long slot = Parts(p).slot
    Dim before As TDesign = Docs(slot)
    Dim As Long i = AddFeature(Docs(slot), f)
    If i > 0 Then HistoryRemember slot, before, "Add " & FeatureName(Docs(slot), i)
    If i = 0 Then
        MsgBox "Subscript out of range." & Chr(10) & Chr(10) & "A part can have " & MAX_FEATURES & " features. Nobody will ever need more.", MB_CRITICAL
        Return False
    End If
    DocDirty(slot) = True
    PartRefreshAll p, True
    SetStatus FeatureName(Docs(slot), i) & " created: " & Describe(Docs(slot), i)
    If f.Kind = FK_SKETCH_RECT Then CalPop "It looks like you're drawing a box."
    If f.Kind = FK_FILLET Then CalPop "It looks like you're trying to round an edge!"
    If f.Kind = FK_CHAMFER Then CalPop "It looks like you're trying to take the corner off!"
    Return True
End Function

Function PlacePrompts() As String
    Return "On feature # (0 = ground)|Height above that (mm)|Face (0 top, 1-4 sides)"
End Function

' The "on top of" number must be 0 or an extrude that comes before this
' sketch, and the face 0 (its top) or, Service Pack 1, one of its sides.
Function PlaceOk(ByRef d As TDesign, ByVal i As Long, ByVal v As Double, ByVal face As Double) As Boolean
    If v = 0 Then Return True
    Dim As Long last = IIf(i = 0, d.Count, i - 1), n = Int(v)
    If n = v And n >= 1 And n <= last Then
        If d.F(n).Kind = FK_EXTRUDE Then
            If face <> Int(face) Or face < FACE_TOP Or face > FACE_LEFT Then
                MsgBox "Face is 0 for the top, or a side: 1 front, 2 right, 3 back, 4 left." & Chr(10) & Chr(10) & _
                    "On a side, X runs along the face, Y goes up it from the bottom, and" & Chr(10) & _
                    "Height above that is how far out from it.", MB_INFO
                Return False
            End If
            If face <> FACE_TOP And d.F(d.F(n).Ref).Kind <> FK_SKETCH_RECT Then
                MsgBox FeatureName(d, n) & " is round. It has no flat sides to sketch on." & Chr(10) & _
                    "(Round sides are planned for SolidCraft XP.)", MB_EXCLAMATION
                Return False
            End If
            Return True
        End If
    End If
    MsgBox "A sketch can sit on the ground (0) or on top of an extrude that comes before it." & Chr(10) & _
        "Use the number from the # column of the timeline.", MB_EXCLAMATION
    Return False
End Function

Function OneSideOfY(ByRef s As TFeature) As Boolean
    If s.Kind = FK_SKETCH_CIRCLE Then Return (s.X - s.P1 >= 0) Or (s.X + s.P1 <= 0)
    Return (s.X >= 0) Or (s.X + s.P1 <= 0)
End Function

Function Min2(ByVal a As Double, ByVal b As Double) As Double
    Return IIf(a < b, a, b)
End Function

' The one dialog per kind of feature, for New and for Edit. i is the feature
' being edited (0 for a new one). Fills f and returns True on OK, if the
' numbers make sense.
Function AskFeature(ByRef d As TDesign, ByVal i As Long, ByRef f As TFeature) As Boolean
    Dim As String sTitle = IIf(i = 0, "", "Edit " & FeatureName(d, i) & ": ")
    Dim As Long k, m, q, mt, mb
    Dim As TFeature s, b, g, inset
    Dim As String sWord, sWhole, sSides, sNow
    Dim As Double x1, y1, x2, y2
    Select Case f.Kind
    Case FK_SKETCH_RECT
        If Not AskParams(sTitle & "Sketch Rectangle", "Width (mm)|Height (mm)|Corner X (mm)|Corner Y (mm)|Corner radius (mm)|" & PlacePrompts(), _
            Fmt0(f.P1) & "|" & Fmt0(f.P2) & "|" & Fmt0(f.X) & "|" & Fmt0(f.Y) & "|" & Fmt0(f.P3) & "|" & Fmt0(f.Ref) & "|" & Fmt0(f.Z) & "|" & SketchFace(f)) Then Return False
        If Not PlaceOk(d, i, ParamValue(5), ParamValue(7)) Then Return False
        If ParamValue(0) <= 0 Or ParamValue(1) <= 0 Then MsgBox "Width and height must be more than zero.", MB_EXCLAMATION: Return False
        If ParamValue(4) < 0 Or ParamValue(4) * 2 > Min2(ParamValue(0), ParamValue(1)) Then MsgBox "The corner radius must be between 0 and half the shorter side.", MB_EXCLAMATION: Return False
        If ParamValue(4) > 0 And f.P3 = 0 Then
            CalPop "It looks like you're trying to round an edge!" & Chr(10) & _
                "(A corner radius rounds the upright ones. For the top ones, try Features, Fillet.)"
        End If
        f.P1 = ParamValue(0): f.P2 = ParamValue(1): f.X = ParamValue(2): f.Y = ParamValue(3)
        f.P3 = ParamValue(4): f.Ref = ParamValue(5): f.Z = ParamValue(6)
        f.Rsv(1) = IIf(f.Ref > 0, ParamValue(7), FACE_TOP)
    Case FK_SKETCH_CIRCLE
        If Not AskParams(sTitle & "Sketch Circle", "Radius (mm)|Centre X (mm)|Centre Y (mm)|" & PlacePrompts(), _
            Fmt0(f.P1) & "|" & Fmt0(f.X) & "|" & Fmt0(f.Y) & "|" & Fmt0(f.Ref) & "|" & Fmt0(f.Z) & "|" & SketchFace(f)) Then Return False
        If Not PlaceOk(d, i, ParamValue(3), ParamValue(5)) Then Return False
        If ParamValue(0) <= 0 Then MsgBox "The radius must be more than zero.", MB_EXCLAMATION: Return False
        f.P1 = ParamValue(0): f.X = ParamValue(1): f.Y = ParamValue(2): f.Ref = ParamValue(3): f.Z = ParamValue(4)
        f.Rsv(1) = IIf(f.Ref > 0, ParamValue(5), FACE_TOP)
    Case FK_EXTRUDE
        If Not AskParams(sTitle & "Extrude " & FeatureName(d, f.Ref), "Depth (mm)", Fmt0(f.P1)) Then Return False
        If ParamValue(0) <= 0 Then MsgBox "The depth must be more than zero.", MB_EXCLAMATION: Return False
        f.P1 = ParamValue(0)
    Case FK_REVOLVE
        If Not AskParams(sTitle & "Revolve " & FeatureName(d, f.Ref) & " about Y", "Angle (degrees)", Fmt0(f.P1)) Then Return False
        If ParamValue(0) = 0 Or Abs(ParamValue(0)) > 360 Then MsgBox "The angle must be between 1 and 360 degrees.", MB_EXCLAMATION: Return False
        If Not OneSideOfY(d.F(f.Ref)) Then
            MsgBox "The sketch crosses the Y axis, so revolving it would turn the part inside out." & Chr(10) & _
                "Move the sketch so it's all on one side of X = 0.", MB_EXCLAMATION
            Return False
        End If
        f.P1 = ParamValue(0)

    Case FK_FILLET, FK_CHAMFER
        b = d.F(f.Ref)
        s = d.F(b.Ref)
        ' Service Pack 1: which sides of the top and the bottom, added up
        sSides = "Top sides (15 = all)|Bottom sides (0 = none)"
        sNow = "|" & FinishTop(f) & "|" & FinishBottom(f)
        If f.Kind = FK_CHAMFER Then
            sWord = "distance": sWhole = "A chamfer that big would cut a whole face away."
            If Not AskParams(sTitle & "Chamfer the edges of " & FeatureName(d, f.Ref) & ", at 45" & Chr(176), "Distance (mm)|" & sSides, Fmt0(f.P1) & sNow) Then Return False
        Else
            sWord = "radius": sWhole = "A fillet that big would round a whole face away."
            If Not AskParams(sTitle & "Fillet the edges of " & FeatureName(d, f.Ref), "Radius (mm)|" & sSides, Fmt0(f.P1) & sNow) Then Return False
        End If
        If ParamValue(0) <= 0 Then
            MsgBox "The " & sWord & " must be more than zero.", MB_EXCLAMATION
            Return False
        End If
        mt = CLng(ParamValue(1)): mb = CLng(ParamValue(2))
        If mt <> ParamValue(1) Or mb <> ParamValue(2) Or mt < 0 Or mt > SIDES_ALL Or mb < 0 Or mb > SIDES_ALL Or mt + mb = 0 Then
            MsgBox "Add up the sides you want: 1 front, 2 right, 4 back, 8 left." & Chr(10) & _
                "15 is all four, 0 is none. Back and left is 12." & Chr(10) & Chr(10) & _
                "(In 2000 this was considered user-friendly.)", MB_INFO
            Return False
        End If
        If Not SidesOk(s, mt) Or Not SidesOk(s, mb) Then
            MsgBox IIf(s.Kind = FK_SKETCH_CIRCLE, "A circle has one edge at the top and one at the bottom.", _
                "A rectangle with rounded corners goes round in one piece.") & Chr(10) & _
                "Its sides are all or nothing: 15 or 0.", MB_EXCLAMATION
            Return False
        End If
        If IIf(mt > 0, 1, 0) + IIf(mb > 0, 1, 0) > 1 And 2 * ParamValue(0) > Abs(b.P1) + 0.000001 Then
            MsgBox "Top and bottom both: the " & sWord & " can be at most half of " & FeatureName(d, f.Ref) & "'s height (" & Fmt0(Abs(b.P1) / 2) & " mm).", MB_EXCLAMATION
            Return False
        End If
        If ParamValue(0) > Abs(b.P1) + 0.000001 Then
            MsgBox "That " & sWord & " is bigger than " & FeatureName(d, f.Ref) & " is tall (" & Fmt0(Abs(b.P1)) & " mm).", MB_EXCLAMATION
            Return False
        End If
        If Not SidesFit(s, mt, ParamValue(0)) Or Not SidesFit(s, mb, ParamValue(0)) Then
            MsgBox sWhole & Chr(10) & "Try a smaller " & sWord & ", or fewer sides.", MB_EXCLAMATION
            Return False
        End If
        ' the holes in the top have to stay clear of the rounded edge
        inset = SideInset(s, mt, ParamValue(0))
        For k = 1 To d.Count
            If k <> i And d.F(k).Kind = FK_HOLE And d.F(k).Ref = f.Ref And d.F(k).Suppressed = 0 Then
                If Not HolesInside(inset, d.F(k)) Then
                    MsgBox FeatureName(d, k) & " is too close to the edge for a " & Fmt0(ParamValue(0)) & " mm " & LCase(KindName(f.Kind)) & "." & Chr(10) & _
                        "Try a smaller " & sWord & ", or move the hole in.", MB_EXCLAMATION
                    Return False
                End If
            End If
        Next
        f.P1 = ParamValue(0)
        f.Rsv(1) = SIDES_ALL - mt         ' the top sides left sharp: 0 is all of them rounded
        f.Rsv(2) = mb

    Case FK_SM_BASE, FK_SM_EDGE, FK_SM_FLAT
        If Not SM_Ask(d, i, f) Then Return False

    Case FK_FOREIGN
        If InStr(LCase(f.Info), "fillet") > 0 Then
            MsgBox f.Name & " is a fillet from SolidCraft, which rounds the edges it was given, one by one." & Chr(10) & Chr(10) & _
                "SolidCraft 2000 rounds whole sides of an extrude's top and bottom, and these aren't that." & Chr(10) & _
                "The rest requires SolidCraft XP. (Features, Fillet rounds the sides you add up.)", MB_INFO
        Else
            MsgBox f.Name & " is a " & LCase(f.Info) & " from SolidCraft." & Chr(10) & Chr(10) & "Requires SolidCraft XP.", MB_INFO
        End If
        Return False

    Case FK_HOLE
        b = d.F(f.Ref)
        s = d.F(b.Ref)
        ' Service Pack 1: Count, and the pattern's shape, in the same dialog
        If Not AskParams(sTitle & "Hole on top face of " & FeatureName(d, f.Ref), _
            "Diameter (mm)|Depth (mm, 0 = through all)|Centre X (mm)|Centre Y (mm)|" & _
            "Count (1 = one hole)|Bolt circle dia. (0 = a row)|Row spacing (mm)|Angle (degrees)", _
            Fmt0(f.P1) & "|" & Fmt0(f.P2) & "|" & Fmt0(f.X) & "|" & Fmt0(f.Y) & "|" & _
            HoleCount(f) & "|" & Fmt0(f.Rsv(1)) & "|" & Fmt0(f.Rsv(2)) & "|" & Fmt0(f.Rsv(3))) Then Return False
        If ParamValue(0) <= 0 Or ParamValue(1) < 0 Then MsgBox "The diameter must be more than zero, and the depth zero or more.", MB_EXCLAMATION: Return False
        If ParamValue(4) <> Int(ParamValue(4)) Or ParamValue(4) < 1 Or ParamValue(4) > MAX_PATTERN Then
            MsgBox "Count must be a whole number from 1 to " & MAX_PATTERN & "." & Chr(10) & _
                "(" & MAX_PATTERN & " holes ought to be enough for anybody.)", MB_EXCLAMATION
            Return False
        End If
        If ParamValue(5) < 0 Then
            MsgBox "The bolt circle diameter must be zero (for a row) or more.", MB_EXCLAMATION
            Return False
        End If
        g = f
        g.P1 = ParamValue(0): g.P2 = ParamValue(1)
        g.X = ParamValue(2): g.Y = ParamValue(3)
        g.P3 = ParamValue(4)
        g.Rsv(1) = ParamValue(5): g.Rsv(2) = ParamValue(6): g.Rsv(3) = ParamValue(7)
        If HoleCount(g) > 1 Then
            ' the holes of the pattern mustn't run into each other
            For m = 0 To HoleCount(g) - 2
                HoleAt g, m, x1, y1
                For q = m + 1 To HoleCount(g) - 1
                    HoleAt g, q, x2, y2
                    If Sqr((x1 - x2) ^ 2 + (y1 - y2) ^ 2) < g.P1 + 0.01 Then
                        MsgBox "The holes in the pattern would run into each other." & Chr(10) & _
                            IIf(g.Rsv(1) > 0, "Make the bolt circle bigger, or the holes fewer or smaller.", _
                            "Make the row spacing more than the diameter."), MB_EXCLAMATION
                        Return False
                    End If
                Next q
            Next m
        End If
        s = TopFace(d, f.Ref)          ' less the fillet, if it has one
        If Not HolesInside(s, g) Then
            MsgBox IIf(HoleCount(g) > 1, "Not all the holes fit on the face. One would fall off the edge", _
                "That hole doesn't fit on the face. It would fall off the edge") & _
                IIf(FilletOf(d, f.Ref) > 0, ", or into the " & LCase(KindName(d.F(FilletOf(d, f.Ref)).Kind)) & ".", "."), MB_EXCLAMATION
            Return False
        End If
        If g.P2 > b.P1 + 0.000001 Then
            MsgBox "That's deeper than " & FeatureName(d, f.Ref) & " is tall." & Chr(10) & _
                "Use depth 0 for a hole all the way through.", MB_EXCLAMATION
            Return False
        End If
        For k = 1 To d.Count
            If k <> i And d.F(k).Kind = FK_HOLE And d.F(k).Ref = f.Ref Then
                For m = 0 To HoleCount(g) - 1
                    HoleAt g, m, x1, y1
                    For q = 0 To HoleCount(d.F(k)) - 1
                        HoleAt d.F(k), q, x2, y2
                        If Sqr((x1 - x2) ^ 2 + (y1 - y2) ^ 2) < (d.F(k).P1 + g.P1) / 2 + 0.01 Then
                            MsgBox IIf(HoleCount(g) > 1, "A hole of the pattern", "That hole") & " would run into " & FeatureName(d, k) & ".", MB_EXCLAMATION
                            Return False
                        End If
                    Next q
                Next m
            End If
        Next
        f = g
    End Select
    Return True
End Function

' The extrude picked in the tree or timeline (a hole, a fillet or a chamfer
' counts as its extrude), or 0.
Function SelectedExtrude(ByVal p As Long) As Long
    Dim As Long b = Parts(p).selected
    If b = 0 Then Return 0
    Dim As TDesign Ptr d = @Docs(Parts(p).slot)
    If d->F(b).Kind = FK_HOLE Or IsEdgeFinish(d->F(b).Kind) Then b = d->F(b).Ref
    If b >= 1 AndAlso d->F(b).Kind = FK_EXTRUDE Then Return b
    Return 0
End Function

Sub CmdSketch(ByVal kind As Long)
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim f As TFeature
    f.Kind = kind
    If kind = FK_SKETCH_RECT Then f.P1 = 40: f.P2 = 30 Else f.P1 = 15
    f.Ref = SelectedExtrude(p)
    If AskFeature(Docs(Parts(p).slot), 0, f) Then Commit p, f
End Sub

Sub CmdBuild(ByVal kind As Long)
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim f As TFeature
    f.Ref = LastFreeSketch(Docs(Parts(p).slot))
    If f.Ref = 0 Then
        MsgBox IIf(kind = FK_EXTRUDE, "Extrude needs a sketch to extrude.", "Revolve needs a sketch to revolve.") & Chr(10) & _
            "Sketch a rectangle or a circle first.", MB_EXCLAMATION
        Exit Sub
    End If
    f.Kind = kind
    f.P1 = IIf(kind = FK_EXTRUDE, 20, 360)
    If AskFeature(Docs(Parts(p).slot), 0, f) Then Commit p, f
End Sub

' A hole goes on the top face of the selected extrude, or the last one.
Sub CmdHole()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As TDesign Ptr d = @Docs(Parts(p).slot)
    Dim As Long b = SelectedExtrude(p)
    If b = 0 Then b = LastSolid(*d)
    If b = 0 Then
        MsgBox "A hole goes on the top face of an extrude." & Chr(10) & "Sketch something and extrude it first.", MB_EXCLAMATION
        Exit Sub
    End If
    Dim f As TFeature
    Dim As TFeature s = d->F(d->F(b).Ref)
    f.Kind = FK_HOLE: f.Ref = b: f.P1 = 8
    f.P3 = 1                       ' one hole; more makes a pattern
    f.Rsv(2) = 20                  ' the spacing, if it becomes a row
    If s.Kind = FK_SKETCH_CIRCLE Then f.X = s.X: f.Y = s.Y Else f.X = s.X + s.P1 / 2: f.Y = s.Y + s.P2 / 2
    If AskFeature(*d, 0, f) Then Commit p, f
End Sub

' NEW IN 2000. A fillet rounds the top edges of the selected extrude (a hole,
' a fillet or a chamfer counts as its extrude), or of the last one. A chamfer
' (Service Pack 1) bevels them instead. An extrude gets one or the other.
Sub CmdEdgeFinish(ByVal nKind As Long)
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As TDesign Ptr d = @Docs(Parts(p).slot)
    Dim As Long b = SelectedExtrude(p), j
    Dim As Double m
    Dim f As TFeature, s As TFeature
    If b = 0 Then b = LastSolid(*d)
    If b = 0 Then
        MsgBox "A " & LCase(KindName(nKind)) & IIf(nKind = FK_CHAMFER, " bevels", " rounds") & " the edges of an extrude." & Chr(10) & _
            "Sketch something and extrude it first.", MB_EXCLAMATION
        Exit Sub
    End If
    For j = b + 1 To d->Count
        If IsEdgeFinish(d->F(j).Kind) And d->F(j).Ref = b Then
            MsgBox FeatureName(*d, b) & " already has a " & LCase(KindName(d->F(j).Kind)) & ", " & FeatureName(*d, j) & "." & Chr(10) & Chr(10) & _
                "SolidCraft 2000 finishes the top edges of an extrude once: a fillet or a chamfer." & Chr(10) & _
                "Edit " & FeatureName(*d, j) & " to change it, or delete it first." & Chr(10) & _
                "(Fillets on chamfers are planned for SolidCraft XP.)", MB_INFO
            Exit Sub
        End If
    Next j
    s = d->F(d->F(b).Ref)
    ' a sensible first guess: 2 mm, or less on something small
    m = Abs(d->F(b).P1)
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
    If AskFeature(*d, 0, f) Then Commit p, f
End Sub

' Double-click in the tree or the timeline: change a feature's numbers.
Sub EditFeature(ByVal p As Long, ByVal i As Long)
    Dim As Long slot = Parts(p).slot, j
    If i < 1 Or i > Docs(slot).Count Then Exit Sub
    Dim f As TFeature = Docs(slot).F(i)
    If Not AskFeature(Docs(slot), i, f) Then Exit Sub
    HistoryRemember slot, Docs(slot), "Edit " & FeatureName(Docs(slot), i)
    Docs(slot).F(i) = f
    DocDirty(slot) = True
    PartRefreshAll p, False
    SetStatus FeatureName(Docs(slot), i) & " changed: " & Describe(Docs(slot), i)
    Dim As String sBad
    For j = i + 1 To Docs(slot).Count
        If Not RefOk(Docs(slot), j) Then sBad &= Chr(10) & "    " & FeatureName(Docs(slot), j)
    Next
    If Len(sBad) Then
        MsgBox "These features no longer fit and have been left out of the part:" & Chr(10) & sBad & Chr(10) & Chr(10) & _
            "Edit them, or edit " & FeatureName(Docs(slot), i) & " back.", MB_EXCLAMATION
    End If
End Sub

Sub CmdEdit()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    If Parts(p).selected = 0 Then MsgBox "Select a feature in the tree or the timeline first.", MB_INFO: Exit Sub
    EditFeature p, Parts(p).selected
End Sub

Sub CmdDelete()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As Long slot = Parts(p).slot, i = Parts(p).selected, j, n
    If i = 0 Then MsgBox "Select a feature in the tree or the timeline first.", MB_INFO: Exit Sub
    Dim gone() As Boolean
    n = MarkDependents(Docs(slot), i, gone())
    Dim As String sList
    For j = 1 To Docs(slot).Count
        If gone(j) And j <> i Then sList &= Chr(10) & "    " & FeatureName(Docs(slot), j)
    Next
    If n > 1 Then
        If MsgBox("These are built on " & FeatureName(Docs(slot), i) & " and will be deleted too:" & Chr(10) & sList & Chr(10) & Chr(10) & _
            "Delete all " & n & " features?", MB_EXCLAMATION Or MB_YESNO Or MB_DEFBUTTON2) <> IDYES Then Exit Sub
    End If
    sList = FeatureName(Docs(slot), i)
    HistoryRemember slot, Docs(slot), "Delete " & sList
    DeleteMarked Docs(slot), gone()
    DocDirty(slot) = True
    Parts(p).selected = 0
    PartRefreshAll p, False
    If n > 1 Then SetStatus "Deleted " & sList & " and " & (n - 1) & " more." Else SetStatus "Deleted " & sList & "."
End Sub

' Service Pack 1: a real history, twenty levels deep (history.bas).
Sub CmdUndo()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As Long slot = Parts(p).slot
    Dim As String sWhat = HistoryUndo(slot)
    If Len(sWhat) = 0 Then SetStatus "Can't Undo.": Exit Sub
    DocDirty(slot) = True
    PartRefreshAll p, False
    SetStatus "Undone: " & sWhat & "." & IIf(CanUndo(slot), "", " That was the last thing to undo.")
End Sub

Sub CmdRedo()
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Dim As Long slot = Parts(p).slot
    Dim As String sWhat = HistoryRedo(slot)
    If Len(sWhat) = 0 Then SetStatus "Can't Redo.": Exit Sub
    DocDirty(slot) = True
    PartRefreshAll p, False
    SetStatus "Redone: " & sWhat & "."
End Sub

Sub Arrange(ByRef how As String)
    Dim As Long i, n = ZCount, p
    If n = 0 Then Exit Sub
    For i = 0 To n - 1
        p = ZOrder(i)
        Parts(p).minimized = False
        Select Case how
        Case "Cascade"
            Parts(p).x = MdiX + i * 24: Parts(p).y = MdiY + i * 24
            Parts(p).w = MdiW * 85 \ 100: Parts(p).h = MdiH * 85 \ 100
        Case "TileH"
            Parts(p).x = MdiX: Parts(p).w = MdiW
            Parts(p).y = MdiY + i * MdiH \ n: Parts(p).h = MdiH \ n
        Case "TileV"
            Parts(p).y = MdiY: Parts(p).h = MdiH
            Parts(p).x = MdiX + i * MdiW \ n: Parts(p).w = MdiW \ n
        End Select
        If Parts(p).w < 240 Then Parts(p).w = 240         ' small, but each still works
        If Parts(p).h < 200 Then Parts(p).h = 200
        EnsureImages p
        FitView Parts(p).v, Parts(p).imgW, Parts(p).imgH, Parts(p).edges, Parts(p).edgeN
        PartRedraw p
    Next
End Sub

Sub WithPart(ByRef what As String)
    Dim As Long p = NeedPart()
    If p = 0 Then Exit Sub
    Select Case what
    Case "ViewIso": PartViewIso p
    Case "ZoomFit": PartZoomFit p
    Case "Regen": PartRegen p
    End Select
End Sub

Sub RunCommand(ByRef sCmd As String)
    LogLine "command: " & sCmd
    TooltipText = ""
    Select Case sCmd
    Case "New": CmdNew
    Case "Open": CmdOpen
    Case "Save": CmdSave False
    Case "SaveAs": CmdSave True
    Case "Close": CmdClose
    Case "SaveFloppy": CmdFloppy
    Case "ExportStl": CmdExportStl
    Case "Publish"
        Dim As Long pp = NeedPart()
        If pp Then PublishPart pp
    Case "Exit": CmdExit
    Case "SketchRect": CmdSketch FK_SKETCH_RECT
    Case "SketchCircle": CmdSketch FK_SKETCH_CIRCLE
    Case "Extrude": CmdBuild FK_EXTRUDE
    Case "Revolve": CmdBuild FK_REVOLVE
    Case "Hole": CmdHole
    Case "Fillet": CmdEdgeFinish FK_FILLET
    Case "Chamfer": CmdEdgeFinish FK_CHAMFER
    Case "SMBase", "SMEdge", "SMFlat", "BendTable": SM_Command sCmd
    Case "Undo": CmdUndo
    Case "Redo": CmdRedo
    Case "Edit": CmdEdit
    Case "Delete": CmdDelete
    Case "Orbit", "ViewIso": WithPart "ViewIso"
    Case "ZoomFit": WithPart "ZoomFit"
    Case "Regen": WithPart "Regen"
    Case "Shaded": CmdShaded
    Case "Turbo": SetTurbo Not Turbo
    Case "Cascade", "TileH", "TileV": Arrange sCmd
    Case "Help"
        MsgBox "Cannot find the file 'SOLIDCRAFT.HLP' (or one of its components)." & Chr(10) & Chr(10) & _
            "Make sure the path and filename are correct and that all required libraries are available.", MB_EXCLAMATION, "WinHelp"
    Case "About": ShowAbout
    Case "Upgrade": ShowUpgrade
    Case "StabilityPack": StabilityPackCommand
    Case Else
        If Left(sCmd, 6) = "Window" Then
            Dim As Long p = Val(Mid(sCmd, 7))
            If p >= 1 And p <= MAX_DOCS AndAlso Parts(p).inUse Then
                If Parts(p).minimized Then PartMinimize p
                BringToFront p
            End If
        Else
            MsgBox "Command '" & sCmd & "' is not implemented yet." & Chr(10) & "It is scheduled for SolidCraft XP.", MB_INFO
        End If
    End Select
    NeedRedraw = True
End Sub

' ---- input for the main window ----

Dim Shared CapturePart As Long

Sub MenuRun(ByVal m As Long, ByVal i As Long)
    Dim it As TMenuItem = MenuItemAt(m, i)
    OpenMenu = -1: HotItem = -1
    If it.cmd = "More" Then
        ' "Show all items": everything back, and the same menu open again
        AdaptExpanded = True
        OpenMenu = m: HotItem = -1
        NeedRedraw = True
        Exit Sub
    End If
    If IsAdaptive(m) Then AdaptiveUsed it.cmd
    If Len(it.cmd) Then RunCommand it.cmd
End Sub

Function NextMenuItem(ByVal m As Long, ByVal i As Long, ByVal dirn As Long) As Long
    Dim As Long n = ItemsIn(m), k
    For k = 1 To n
        i = (i + dirn + n) Mod n
        If MenuItemAt(m, i).caption <> "-" Then Return i
    Next
    Return -1
End Function

Sub MenuKey(ByRef ev As UIEvent)
    Select Case ev.key
    Case K_ESC: OpenMenu = -1: HotItem = -1
    Case K_LEFT: OpenMenu = (OpenMenu + NMENUS - 1) Mod NMENUS: HotItem = NextMenuItem(OpenMenu, -1, 1)
    Case K_RIGHT: OpenMenu = (OpenMenu + 1) Mod NMENUS: HotItem = NextMenuItem(OpenMenu, -1, 1)
    Case K_DOWN: HotItem = NextMenuItem(OpenMenu, HotItem, 1)
    Case K_UP: HotItem = NextMenuItem(OpenMenu, HotItem, -1)
    Case K_ENTER: If HotItem >= 0 Then MenuRun OpenMenu, HotItem
    Case Else
        ' the underlined letter
        Dim As Long i
        For i = 0 To ItemsIn(OpenMenu) - 1
            Dim As String c = MenuItemAt(OpenMenu, i).caption
            Dim As Long p = InStr(c, "&")
            If p AndAlso UCase(Mid(c, p + 1, 1)) = Chr(ev.key) Then MenuRun OpenMenu, i: Exit Sub
        Next
    End Select
End Sub

' Konami: up up down down left right left right B A.
Dim Shared KonamiAt As Long
Function KonamiKey(ByVal k As Long) As Boolean
    Static seq(0 To 9) As Long = {K_UP, K_UP, K_DOWN, K_DOWN, K_LEFT, K_RIGHT, K_LEFT, K_RIGHT, Asc("B"), Asc("A")}
    If k = seq(KonamiAt) Then
        KonamiAt += 1
        If KonamiAt > 9 Then KonamiAt = 0: Return True
    ElseIf k = seq(0) Then
        KonamiAt = 1
    Else
        KonamiAt = 0
    End If
    Return False
End Function

Sub KonamiSpin(ByVal p As Long)
    Dim As Double t = Timer, y0 = Parts(p).v.Yaw
    SetFps "60 fps (lying)"
    SetStatus "Cheat activated. Full speed for three seconds."
    Parts(p).spinning = True
    Do While Timer - t < 3 And Timer >= t
        Parts(p).v.Yaw = y0 + (Timer - t) * 240
        PartRedraw p
        UIStep
    Loop
    Parts(p).v.Yaw = y0
    Parts(p).spinning = False
    PartRedraw p
End Sub

Sub AppKey(ByRef ev As UIEvent)
    Dim As String cmd
    If OpenMenu >= 0 Then MenuKey ev: Exit Sub
    Dim As Long p = ActivePart()
    If p AndAlso KonamiKey(ev.key) Then KonamiSpin p: Exit Sub
    If ev.alt Then
        Dim i As Long
        For i = 0 To NMENUS - 1
            Dim As Long k = InStr(MenuTitles(i), "&")
            If UCase(Mid(MenuTitles(i), k + 1, 1)) = Chr(ev.key) Then OpenMenu = i: HotItem = NextMenuItem(i, -1, 1): Exit Sub
        Next
        Exit Sub
    End If
    If ev.ctrl Then
        Select Case ev.key
        Case Asc("N"): cmd = "New"
        Case Asc("O"): cmd = "Open"
        Case Asc("S"): cmd = "Save"
        Case Asc("Z"): cmd = "Undo"
        Case Asc("Y"): cmd = "Redo"
        End Select
    ElseIf Not ev.shift Then
        Select Case ev.key
        Case K_F1: cmd = "Help"
        Case K_F1 + 4: cmd = "Regen"
        Case K_DEL: cmd = "Delete"
        Case K_ENTER: cmd = "Edit"
        Case Asc("R"): cmd = "SketchRect"
        Case Asc("C"): cmd = "SketchCircle"
        Case Asc("E"): cmd = "Extrude"
        Case Asc("V"): cmd = "Revolve"
        Case Asc("H"): cmd = "Hole"
        Case Asc("L"): cmd = "Fillet"
        Case Asc("M"): cmd = "Chamfer"
        Case Asc("I"): cmd = "ViewIso"
        Case Asc("F"): cmd = "ZoomFit"
        Case Asc("S"): cmd = "Shaded"
        End Select
        If p AndAlso (ev.ch = "+" Or ev.ch = "=") Then PartZoomBy p, 1.25: Exit Sub
        If p AndAlso ev.ch = "-" Then PartZoomBy p, 0.8: Exit Sub
    Else
        If p AndAlso ev.ch = "+" Then PartZoomBy p, 1.25: Exit Sub
    End If
    If Len(cmd) Then RunCommand cmd
End Sub

Sub AppEvent(ByRef ev As UIEvent)
    Dim As Long i
    Select Case ev.kind
    Case EV_CLOSE
        CmdExit
    Case EV_KEY
        AppKey ev
    Case EV_DOWN
        TooltipText = ""
        If OpenMenu >= 0 Then
            i = DropItemAt(ev.x, ev.y)
            If i >= 0 Then MenuRun OpenMenu, i: Exit Sub
            If i = -1 Then Exit Sub               ' a separator
            Dim As Long t = MenuTitleAt(ev.x, ev.y)
            OpenMenu = -1: HotItem = -1
            If t >= 0 Then Exit Sub               ' clicking the open title closes it
        End If
        If CalClick(ev.x, ev.y) Then Exit Sub
        ' our title bar's close box (full screen)
        If TitleH > 0 And ev.y < TitleH Then
            If ev.x >= ScrW - 20 Then RunCommand "Exit"
            Exit Sub
        End If
        i = MenuTitleAt(ev.x, ev.y)
        If i >= 0 Then OpenMenu = i: HotItem = -1: Exit Sub
        i = ButtonAt(ev.x, ev.y)
        If i >= 0 Then DownButton = i: HotButton = i: Exit Sub
        If ev.y >= MdiY And ev.y < MdiY + MdiH Then
            Dim As Long p = PartHit(ev.x, ev.y)
            If p Then
                CapturePart = p
                PartMouseDown p, ev
                If Not Parts(p).inUse Then CapturePart = 0
            End If
        End If
    Case EV_MOVE
        If OpenMenu >= 0 Then NeedRedraw = True
        If OpenMenu >= 0 Then
            Dim As Long t = MenuTitleAt(ev.x, ev.y)
            If t >= 0 And t <> OpenMenu Then OpenMenu = t: HotItem = -1
            i = DropItemAt(ev.x, ev.y)
            If i >= 0 Then HotItem = i
            Exit Sub
        End If
        If CapturePart Then PartMouseMove CapturePart, ev: Exit Sub
        i = ButtonAt(ev.x, ev.y)
        If i <> HotButton Then
            NeedRedraw = True
            HotButton = i: HoverStart = Timer: TooltipText = ""
            If i >= 0 Then SetStatus Buttons(i).tip
        End If
    Case EV_UP
        If CapturePart Then
            Dim As Long p = CapturePart
            CapturePart = 0
            If Parts(p).inUse Then PartMouseUp p, ev
            Exit Sub
        End If
        If DownButton >= 0 Then
            i = DownButton
            DownButton = -1
            If ButtonAt(ev.x, ev.y) = i Then
                Dim As String k = Buttons(i).key
                If k = "Orbit" Then k = "ViewIso"
                RunCommand k
            End If
        End If
    Case EV_WHEEL
        Dim As Long p = PartHit(ev.x, ev.y)
        If p Then PartWheel p, ev
    End Select
End Sub

Declare Sub StabilityTick()
Declare Sub StabilityStart()

Sub AppTick()
    Dim As Long i
    StabilityTick
    For i = 0 To ZCount - 1
        PartRevealTick ZOrder(i)
    Next
    ' toolbar tooltips appear after a moment's hover
    If HotButton >= 0 And DownButton < 0 And Len(TooltipText) = 0 And Timer - HoverStart > 0.6 Then
        TooltipText = Buttons(HotButton).tip: NeedRedraw = True
    End If
    ' On 31 Dec 1999 at midnight, with Turbo on, the year rolls over the way a
    ' two-digit year does: 19 & 100.
    If Turbo And Not Y2KHappened Then
        Dim As Double t = ClockNow()
        If Year(t) = 1999 And Month(t) = 12 And Day(t) = 31 Then SawNewYearsEve = True
        If SawNewYearsEve And Year(t) = 2000 Then
            Y2KHappened = True
            RefreshAllParts
            SetStatus "Happy New Year 19100! All dimensions have been updated."
        End If
    End If
    ' the clock
    Dim As Long h = Hour(ClockNow()), m = Minute(ClockNow())
    Dim As String c = ((h + 11) Mod 12 + 1) & ":" & Right("0" & m, 2) & IIf(h < 12, " AM", " PM")
    If c <> ClockText Then ClockText = c: NeedRedraw = True
End Sub

' ---- start ----

Sub Layout()
    TitleH = IIf(FullScreenMode, 22, 0)
    MenuGeometry
    MdiX = 0: MdiY = TitleH + MENU_H + TOOL_H
    MdiW = ScrW: MdiH = ScrH - MdiY - STATUS_H
End Sub

' --bench: how fast this machine draws, for a Pi 1. Prints to the terminal.
Dim Shared BenchMode As Boolean
Sub RunBench()
    Dim As Double t
    Dim As Long i, p = ActivePart()
    Dim As String rep
    t = Timer
    For i = 1 To 20: RenderFrame: Next
    rep &= "full redraw: " & FmtN((Timer - t) / 20 * 1000, 1) & " ms" & Chr(10)
    t = Timer
    For i = 1 To 20: Parts(p).v.Yaw += 3: PartRedraw p: Next
    rep &= "wireframe view: " & FmtN((Timer - t) / 20 * 1000, 1) & " ms" & Chr(10)
    ViewShaded = True
    t = Timer
    PartRedraw p
    rep &= "shaded render (before the slow reveal): " & FmtN((Timer - t) * 1000, 0) & " ms, " & Parts(p).triN & " triangles" & Chr(10)
    ScreenControl FB.SET_DRIVER_NAME, "null"
    Open Cons For Output As #9
    Print #9, rep;
    Close #9
    LogLine rep
End Sub

Sub Main()
    Dim As String sScript, sOpen, a
    Dim As Boolean StartUpgrade
    Dim As Long i, w = 800, h = 600
    i = 1
    Do While Len(Command(i))
        a = Command(i)
        Select Case a
        Case "--script": i += 1: sScript = Command(i)
        Case "--headless": HeadlessMode = True
        Case "--remote": RemoteMode = True
        Case "--fullscreen": FullScreenMode = True
        Case "--size"
            i += 1
            w = Val(Command(i)): h = Val(Mid(Command(i), InStr(Command(i), "x") + 1))
        Case "--log"
            i += 1
            LogFile = FreeFile
            Open Command(i) For Output As #LogFile
        Case "--bench"
            BenchMode = True
        Case "--y2ktest", "/Y2KTEST", "/y2ktest"
            ' read by InitClock
        Case "--stable", "/STABLE", "/stable"
            ' read by StabilityStart
        Case "--crashtest", "/CRASHTEST", "/crashtest"
            ' read by StabilityStart
        Case "--upgrade", "/UPGRADE", "/upgrade"
            StartUpgrade = True
        Case Else
            sOpen = a
        End Select
        i += 1
    Loop
    If Len(sScript) Then LoadScript sScript
    If HeadlessMode Then
        ScreenControl FB.SET_DRIVER_NAME, "null"
    ElseIf Len(Environ("DISPLAY")) = 0 And Len(Environ("WAYLAND_DISPLAY")) = 0 Then
        ' the Linux console (a Pi with no desktop): the whole screen is ours
        FullScreenMode = True
        Dim As Long dw, dh
        ScreenInfo dw, dh
        If dw >= 640 Then w = dw: h = dh
    End If
    If ScreenRes(w, h, 32, 1, IIf(FullScreenMode And Not HeadlessMode, FB.GFX_FULLSCREEN, 0)) <> 0 Then
        If ScreenRes(800, 600, 32) <> 0 Then Print "SolidCraft 2000: can't open an 800 x 600 screen.": End 1
        w = 800: h = 600
    End If
    ScrW = w: ScrH = h
    WindowTitle APP_NAME
    SetMouse , , 0                    ' we draw our own pointer
    InitClock
    SplashProgress "Loading geometry kernel..."
    SplashProgress "Registering MSCOMCTL.OCX..."
    SplashProgress "Reticulating B-splines..."
    BuildMenus
    BuildToolbar
    Layout
    CmdNew
    If Len(sOpen) Then OpenFile sOpen
    SetStatus "Ready"
    StabilityStart
    If StartUpgrade Then ShowUpgrade
    If BenchMode Then RunBench: Exit Sub
    Do
        UIStep
        If QuitRequested Then Exit Do
        If HeadlessMode And Not RemoteMode And ScriptPos >= ScriptCount And EvHead = EvTail And Timer >= ScriptWaitUntil Then Exit Do
    Loop
    If LogFile Then Close #LogFile
End Sub
