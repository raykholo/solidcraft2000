' history.bas - a real undo and redo history, new in Service Pack 1. A port
' of the Windows version's modHistory.
'
' Before every change the whole part is copied onto the undo stack (a part
' is one Type, so a copy is one line). Undo swaps the part with the top of
' that stack, Redo swaps it back. Twenty levels per part, the way Office
' 2000 did it. Nobody will ever need more.

Const HIST_LEVELS = 20

Dim Shared mUndo(1 To MAX_DOCS, 1 To HIST_LEVELS) As TDesign
Dim Shared mUndoWhat(1 To MAX_DOCS, 1 To HIST_LEVELS) As String
Dim Shared mNUndo(1 To MAX_DOCS) As Long
Dim Shared mRedo(1 To MAX_DOCS, 1 To HIST_LEVELS) As TDesign
Dim Shared mRedoWhat(1 To MAX_DOCS, 1 To HIST_LEVELS) As String
Dim Shared mNRedo(1 To MAX_DOCS) As Long

' A new or newly opened part: nothing to undo.
Sub HistoryClear(ByVal slot As Long)
    If slot < 1 Or slot > MAX_DOCS Then Exit Sub
    mNUndo(slot) = 0
    mNRedo(slot) = 0
End Sub

' Onto a full stack, the oldest level falls off the bottom.
Sub PushUndo(ByVal slot As Long, ByRef d As TDesign, ByRef sWhat As String)
    Dim k As Long
    If mNUndo(slot) >= HIST_LEVELS Then
        For k = 1 To HIST_LEVELS - 1
            mUndo(slot, k) = mUndo(slot, k + 1)
            mUndoWhat(slot, k) = mUndoWhat(slot, k + 1)
        Next k
        mNUndo(slot) = HIST_LEVELS - 1
    End If
    mNUndo(slot) += 1
    mUndo(slot, mNUndo(slot)) = d
    mUndoWhat(slot, mNUndo(slot)) = sWhat
End Sub

Sub PushRedo(ByVal slot As Long, ByRef d As TDesign, ByRef sWhat As String)
    Dim k As Long
    If mNRedo(slot) >= HIST_LEVELS Then
        For k = 1 To HIST_LEVELS - 1
            mRedo(slot, k) = mRedo(slot, k + 1)
            mRedoWhat(slot, k) = mRedoWhat(slot, k + 1)
        Next k
        mNRedo(slot) = HIST_LEVELS - 1
    End If
    mNRedo(slot) += 1
    mRedo(slot, mNRedo(slot)) = d
    mRedoWhat(slot, mNRedo(slot)) = sWhat
End Sub

' Part slot was "before" until a change described by sWhat ("Add Extrude2").
' Any redo history is gone: that's how a history works.
Sub HistoryRemember(ByVal slot As Long, ByRef before As TDesign, ByRef sWhat As String)
    PushUndo slot, before, sWhat
    mNRedo(slot) = 0
End Sub

' The features come back; the part keeps the name it's saved under now.
Sub HistoryRestore(ByVal slot As Long, ByRef t As TDesign)
    Dim sTitle As String = Docs(slot).Title
    Docs(slot) = t
    Docs(slot).Title = sTitle
End Sub

' Puts the part back as it was before its last change. Returns what was undone, or "".
Function HistoryUndo(ByVal slot As Long) As String
    Dim As String sWhat
    If mNUndo(slot) = 0 Then Return ""
    sWhat = mUndoWhat(slot, mNUndo(slot))
    PushRedo slot, Docs(slot), sWhat
    Dim t As TDesign = mUndo(slot, mNUndo(slot) )
    mNUndo(slot) -= 1
    HistoryRestore slot, t
    Return sWhat
End Function

' Does again what Undo undid. Returns what was redone, or "".
Function HistoryRedo(ByVal slot As Long) As String
    Dim As String sWhat
    If mNRedo(slot) = 0 Then Return ""
    sWhat = mRedoWhat(slot, mNRedo(slot))
    PushUndo slot, Docs(slot), sWhat
    Dim t As TDesign = mRedo(slot, mNRedo(slot))
    mNRedo(slot) -= 1
    HistoryRestore slot, t
    Return sWhat
End Function

Function CanUndo(ByVal slot As Long) As Boolean
    If slot >= 1 And slot <= MAX_DOCS Then Return mNUndo(slot) > 0
    Return False
End Function

Function CanRedo(ByVal slot As Long) As Boolean
    If slot >= 1 And slot <= MAX_DOCS Then Return mNRedo(slot) > 0
    Return False
End Function
