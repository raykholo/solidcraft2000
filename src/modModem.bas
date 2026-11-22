Attribute VB_Name = "modModem"
' modModem - Help, Check Online for Help: the sound of 2000 connecting.
'
' The handshake is made here, sample by sample, not recorded: a dial tone,
' the number in touch tones, a ring, the answer tone with its phase flips,
' the modems trading tones, and the screech while they train. 8 kHz, 8-bit,
' mono, at about a third of full volume, played from memory with PlaySound.
' Then the browser opens the README, which is all the online help there is.
Option Explicit

Public Const HELP_URL As String = "https://github.com/raykholo/solidcraft2000#readme"
Public Const MODEM_NUMBER As String = "1-555-0198"

Private Const RATE As Long = 8000
Private Const AMP As Double = 42           ' of 127: loud enough to be heard, not enough to wake anyone
Private Const PI2 As Double = 6.28318530717959

Private Const SND_ASYNC As Long = &H1
Private Const SND_NODEFAULT As Long = &H2
Private Const SND_MEMORY As Long = &H4

Private Declare Function PlaySoundMem Lib "winmm.dll" Alias "PlaySoundA" (ByRef pszSound As Any, ByVal hmod As Long, ByVal fdwSound As Long) As Long
Private Declare Function PlaySoundOff Lib "winmm.dll" Alias "PlaySoundA" (ByVal pszSound As Long, ByVal hmod As Long, ByVal fdwSound As Long) As Long
Private Declare Function ShellExecuteA Lib "shell32.dll" (ByVal hwnd As Long, ByVal lpOperation As String, ByVal lpFile As String, _
    ByVal lpParameters As String, ByVal lpDirectory As String, ByVal nShowCmd As Long) As Long

Private mWav() As Byte          ' kept alive while it plays
Private mN As Long              ' samples written so far
Private mSeed As Double         ' the noise generator (Lehmer, in Doubles so nothing overflows)

' When each stage starts, in seconds, for the dialog's status line.
Public ModemAnswerAt As Double
Public ModemTrainAt As Double
Public ModemLength As Double

' Builds the handshake (once) and starts it playing. Returns at once.
Public Sub ModemPlay()
    If mN = 0 Then BuildHandshake
    PlaySoundMem mWav(0), 0, SND_MEMORY Or SND_ASYNC Or SND_NODEFAULT
End Sub

Public Sub ModemStop()
    PlaySoundOff 0, 0, 0
End Sub

Public Sub OpenHelpPage()
    ShellExecuteA frmMain.hwnd, "open", HELP_URL, vbNullString, vbNullString, 1
End Sub

Private Sub BuildHandshake()
    Dim i As Long, d As String
    ReDim mWav(0 To 44 + RATE * 12)
    mN = 0
    mSeed = 1998
    Tones 0.9, 350, 440                                 ' off the hook: the dial tone
    d = Replace(MODEM_NUMBER, "-", "")
    For i = 1 To Len(d)                                 ' the number, in touch tones
        Touch Mid$(d, i, 1)
        Quiet 0.07
    Next i
    Quiet 0.35
    Tones 0.9, 440, 480                                 ' ringing...
    Quiet 0.45
    ModemAnswerAt = mN / RATE
    AnswerTone 1.35                                     ' 2100 Hz, flipping phase every 450 ms
    Fsk 0.45, 1650, 1850                                ' the modems introduce themselves
    Quiet 0.08
    Probe 0.22
    Quiet 0.08
    Probe 0.22
    ModemTrainAt = mN / RATE
    Screech 1.9                                         ' training: the part everybody remembers
    Fsk 0.3, 1200, 2400
    Quiet 0.15
    ModemLength = mN / RATE
    WriteHeader
End Sub

Private Function Noise() As Double
    mSeed = mSeed * 16807#
    mSeed = mSeed - Int(mSeed / 2147483647#) * 2147483647#
    Noise = (mSeed / 2147483647#) * 2 - 1
End Function

Private Sub Put1(ByVal v As Double)
    Dim s As Long
    s = 128 + CLng(v * AMP)
    If s < 0 Then s = 0
    If s > 255 Then s = 255
    mWav(44 + mN) = s
    mN = mN + 1
End Sub

Private Sub Quiet(ByVal secs As Double)
    Dim i As Long
    For i = 1 To CLng(secs * RATE)
        Put1 0
    Next i
End Sub

Private Sub Tones(ByVal secs As Double, ByVal f1 As Double, ByVal f2 As Double)
    Dim i As Long, t As Double
    For i = 0 To CLng(secs * RATE) - 1
        t = i / RATE
        Put1 0.5 * (Sin(PI2 * f1 * t) + Sin(PI2 * f2 * t))
    Next i
End Sub

Private Sub Touch(ByVal ch As String)
    Dim lo As Double, hi As Double
    Select Case ch
    Case "1": lo = 697: hi = 1209
    Case "2": lo = 697: hi = 1336
    Case "3": lo = 697: hi = 1477
    Case "4": lo = 770: hi = 1209
    Case "5": lo = 770: hi = 1336
    Case "6": lo = 770: hi = 1477
    Case "7": lo = 852: hi = 1209
    Case "8": lo = 852: hi = 1336
    Case "9": lo = 852: hi = 1477
    Case Else: lo = 941: hi = 1336
    End Select
    Tones 0.09, lo, hi
End Sub

Private Sub AnswerTone(ByVal secs As Double)
    Dim i As Long, t As Double, ph As Double
    For i = 0 To CLng(secs * RATE) - 1
        t = i / RATE
        ph = IIf((Int(t / 0.45) Mod 2) = 1, 3.14159265358979, 0)
        Put1 0.8 * Sin(PI2 * 2100 * t + ph)
    Next i
End Sub

' Two tones keyed by random bits at 300 baud.
Private Sub Fsk(ByVal secs As Double, ByVal f0 As Double, ByVal f1 As Double)
    Dim i As Long, ph As Double, f As Double
    For i = 0 To CLng(secs * RATE) - 1
        If i Mod (RATE \ 300) = 0 Then f = IIf(Noise() > 0, f1, f0)
        ph = ph + PI2 * f / RATE
        Put1 0.7 * Sin(ph)
    Next i
End Sub

' Line probing: a chord of tones across the voice band, the "bong".
Private Sub Probe(ByVal secs As Double)
    Dim i As Long, k As Long, t As Double, v As Double
    For i = 0 To CLng(secs * RATE) - 1
        t = i / RATE
        v = 0
        For k = 1 To 11
            v = v + Sin(PI2 * (150 + 300 * k) * t + k)
        Next k
        Put1 v / 5.5
    Next i
End Sub

' Scrambled data: noise, a little smoothed, wobbling in level.
Private Sub Screech(ByVal secs As Double)
    Dim i As Long, y As Double, t As Double
    For i = 0 To CLng(secs * RATE) - 1
        t = i / RATE
        y = 0.55 * y + 0.45 * Noise()
        Put1 (0.75 + 0.25 * Sin(PI2 * 3 * t)) * (y * 1.4 + 0.25 * Sin(PI2 * 1800 * t))
    Next i
End Sub

Private Sub PutLong(ByVal at As Long, ByVal v As Long)
    mWav(at) = v And &HFF
    mWav(at + 1) = (v \ &H100) And &HFF
    mWav(at + 2) = (v \ &H10000) And &HFF
    mWav(at + 3) = (v \ &H1000000) And &HFF
End Sub

Private Sub PutText(ByVal at As Long, ByVal s As String)
    Dim i As Long
    For i = 1 To Len(s)
        mWav(at + i - 1) = Asc(Mid$(s, i, 1))
    Next i
End Sub

Private Sub WriteHeader()
    ReDim Preserve mWav(0 To 44 + mN - 1)
    PutText 0, "RIFF": PutLong 4, 36 + mN: PutText 8, "WAVE"
    PutText 12, "fmt ": PutLong 16, 16
    mWav(20) = 1: mWav(21) = 0          ' PCM
    mWav(22) = 1: mWav(23) = 0          ' mono
    PutLong 24, RATE: PutLong 28, RATE  ' bytes per second, at one byte a sample
    mWav(32) = 1: mWav(33) = 0          ' block align
    mWav(34) = 8: mWav(35) = 0          ' bits
    PutText 36, "data": PutLong 40, mN
End Sub
