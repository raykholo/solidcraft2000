Attribute VB_Name = "modHistory"
' modHistory - a real undo and redo history, new in Service Pack 1.
'
' Before every change the whole part is copied onto the undo stack (a part
' is one Type, so a copy is one line). Undo swaps the part with the top of
' that stack, Redo swaps it back. Twenty levels per part, the way Office
' 2000 did it. Nobody will ever need more.
Option Explicit

Private Const LEVELS As Integer = 20

Private mUndo() As TDesign
Private mUndoWhat() As String
Private mNUndo(1 To MAX_DOCS) As Integer
Private mRedo() As TDesign
Private mRedoWhat() As String
Private mNRedo(1 To MAX_DOCS) As Integer
Private mReady As Boolean

Private Sub Ready()
    If mReady Then Exit Sub
    ReDim mUndo(1 To MAX_DOCS, 1 To LEVELS): ReDim mUndoWhat(1 To MAX_DOCS, 1 To LEVELS)
    ReDim mRedo(1 To MAX_DOCS, 1 To LEVELS): ReDim mRedoWhat(1 To MAX_DOCS, 1 To LEVELS)
    mReady = True
End Sub

' A new or newly opened part: nothing to undo.
Public Sub HistoryClear(ByVal slot As Integer)
    If slot < 1 Or slot > MAX_DOCS Then Exit Sub
    mNUndo(slot) = 0
    mNRedo(slot) = 0
End Sub

' Part slot was "before" until a change described by sWhat ("Add Extrude2").
' Any redo history is gone: that's how a history works.
Public Sub HistoryRemember(ByVal slot As Integer, before As TDesign, ByVal sWhat As String)
    Ready
    Push mUndo, mUndoWhat, mNUndo(slot), slot, before, sWhat
    mNRedo(slot) = 0
End Sub

' Puts the part back as it was before its last change. Returns what was undone, or "".
Public Function HistoryUndo(ByVal slot As Integer) As String
    Dim t As TDesign, sWhat As String
    If mNUndo(slot) = 0 Then Exit Function
    sWhat = mUndoWhat(slot, mNUndo(slot))
    Push mRedo, mRedoWhat, mNRedo(slot), slot, Docs(slot), sWhat
    t = mUndo(slot, mNUndo(slot))
    mNUndo(slot) = mNUndo(slot) - 1
    Restore slot, t
    HistoryUndo = sWhat
End Function

' Does again what Undo undid. Returns what was redone, or "".
Public Function HistoryRedo(ByVal slot As Integer) As String
    Dim t As TDesign, sWhat As String
    If mNRedo(slot) = 0 Then Exit Function
    sWhat = mRedoWhat(slot, mNRedo(slot))
    Push mUndo, mUndoWhat, mNUndo(slot), slot, Docs(slot), sWhat
    t = mRedo(slot, mNRedo(slot))
    mNRedo(slot) = mNRedo(slot) - 1
    Restore slot, t
    HistoryRedo = sWhat
End Function

Public Function CanUndo(ByVal slot As Integer) As Boolean
    If slot >= 1 And slot <= MAX_DOCS Then CanUndo = mNUndo(slot) > 0
End Function

Public Function CanRedo(ByVal slot As Integer) As Boolean
    If slot >= 1 And slot <= MAX_DOCS Then CanRedo = mNRedo(slot) > 0
End Function

' The features come back; the part keeps the name it's saved under now.
Private Sub Restore(ByVal slot As Integer, t As TDesign)
    Dim sTitle As String
    sTitle = Docs(slot).Title
    Docs(slot) = t
    Docs(slot).Title = sTitle
End Sub

' Onto a full stack, the oldest level falls off the bottom.
Private Sub Push(stack() As TDesign, what() As String, n As Integer, ByVal slot As Integer, d As TDesign, ByVal sWhat As String)
    Dim k As Integer
    If n >= LEVELS Then
        For k = 1 To LEVELS - 1
            stack(slot, k) = stack(slot, k + 1)
            what(slot, k) = what(slot, k + 1)
        Next k
        n = LEVELS - 1
    End If
    n = n + 1
    stack(slot, n) = d
    what(slot, n) = sWhat
End Sub
