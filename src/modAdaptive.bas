Attribute VB_Name = "modAdaptive"
' modAdaptive - Personalized Menus, new in 2000.
'
' The File, Features and View menus show only the items you use. The rest
' wait behind "Show all items" at the bottom, which opens the menu again with
' everything in it. Use an item and it stays in the short menu from then on
' (for this run: nothing is written anywhere). Keyboard shortcuts of hidden
' items don't work, because Windows takes a hidden item's shortcut with it.
' That is how it was, and it is why people turned this off.
Option Explicit

' what the short menus show before you've used anything
Private Const SHOWN_AT_FIRST As String = "|New|Open|Save|Exit|Extrude|Hole|Fillet|ViewIso|ZoomFit|Regen|Shaded|"

Public Const MORE_TAG As String = "More"

Private mUsed As String          ' "|Tag|" for each item used this run
Private mExpanded As Boolean     ' "Show all items" was chosen and nothing since

' Should the item with this command key be in the menu right now?
Public Function AdaptiveShows(ByVal sTag As String) As Boolean
    If mExpanded Then AdaptiveShows = True: Exit Function
    AdaptiveShows = InStr(SHOWN_AT_FIRST & mUsed, "|" & sTag & "|") > 0
End Function

' A menu item was used: it joins the short menu, and the menus go short again.
Public Sub AdaptiveUsed(ByVal sTag As String)
    If sTag = MORE_TAG Or Len(sTag) = 0 Then Exit Sub
    If InStr(SHOWN_AT_FIRST & mUsed, "|" & sTag & "|") = 0 Then mUsed = mUsed & "|" & sTag & "|"
    mExpanded = False
End Sub

Public Sub AdaptiveExpand()
    mExpanded = True
End Sub

Public Function AdaptiveExpanded() As Boolean
    AdaptiveExpanded = mExpanded
End Function
