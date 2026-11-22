"""Runs the built SolidCraft 2000 on the CI runner and takes screenshots.

    python tools/ci/smoke.py out/SolidCraft2000.exe shots

1. The splash (/SPLASH holds it for 15 seconds).
3. The scheduled blue screen (/CRASHTEST), and the part still there after.
2. Through the remote control (/REMOTE, port 9898, this PC only): a filleted
   block with a hole, a chamfered one with a bolt circle of holes, a sheet-metal part folded and flat, the personalized
   File menu, and the Upgrade Wizard. Every answer goes in shots/remote.log.

Fails if the program won't start, or an action answers "error:" where it
shouldn't.
"""
import re
import socket
import subprocess
import sys
import time
from pathlib import Path

from PIL import ImageGrab

EXE, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
log = open(OUT / "remote.log", "w", encoding="utf-8")
problems = []


def shot(name):
    ImageGrab.grab().save(OUT / f"{name}.png")
    print(f"screenshot {name}.png", flush=True)


# 1. the splash
p = subprocess.Popen([str(EXE), "/SPLASH"])
time.sleep(6)
shot("splash")
p.kill()
p.wait()
time.sleep(1)

# 2. driven by the remote control
p = subprocess.Popen([str(EXE), "/REMOTE"])
s = None
for _ in range(60):
    try:
        s = socket.create_connection(("127.0.0.1", 9898), timeout=60)
        break
    except OSError:
        time.sleep(1)
if s is None:
    sys.exit("SolidCraft 2000 never answered on port 9898")
buf = b""


def say(cmd, ok=True):
    """Sends one command and returns its answer (the lines before ".")."""
    global buf
    s.sendall(cmd.encode("latin-1") + b"\r\n")
    lines = []
    while True:
        while b"\n" not in buf:
            try:
                chunk = s.recv(4096)
            except socket.timeout:
                shot("timeout")
                log.write(f"> {cmd}\n(no answer in 60 s; got so far: {buf!r})\n")
                log.close()
                raise SystemExit(f"no answer to {cmd!r}")
            if not chunk:
                raise SystemExit("the connection closed")
            buf += chunk
        raw, buf = buf.split(b"\n", 1)
        line = raw.decode("latin-1").rstrip("\r")
        if line == ".":
            break
        lines.append(line)
    text = "\n".join(lines)
    log.write(f"> {cmd}\n{text}\n\n")
    log.flush()
    if ok and text.lstrip().lower().startswith("error"):
        problems.append(f"{cmd}: {text.splitlines()[0]}")
    return text


say("look")
# a block, its top edges filleted, a hole in the top
say("key r"); say("key enter")
say("key e"); say("key enter")
say("menu Features > Fillet..."); say("key enter")
say("key h"); say("key enter")
say("key s")
say("wait 1500")
shot("fillet")
say("look")

# a block, its top edges chamfered, a hole in the top, in a new part
say("key ctrl+n")
say("key r"); say("key enter")
say("key e"); say("key enter")
say("menu Features > Chamfer..."); say("key enter")
say("key h"); say("key enter")
say("wait 1500")
shot("chamfer")
t = say("look")
if "Chamfer1" not in t or "Rebuild error" in t:
    problems.append("the chamfered block didn't build: " + t.splitlines()[0])
# six 3 mm holes on a 20 mm bolt circle round the middle one
say("key h")
say("type 3"); say("key tab"); say("key tab"); say("key tab"); say("key tab")
say("type 6"); say("key tab"); say("type 20"); say("key enter")
say("wait 1500")
shot("holepattern")
t = say("look")
if "6 x D 3" not in t or "Rebuild error" in t:
    problems.append("the bolt circle didn't build: " + t.splitlines()[0])

# sheet metal, in a new part
say("key ctrl+n")
say("key r"); say("key enter")
say("menu Sheet Metal > Base Flange...")
say("key enter")                       # "needs a bend table"
shot("bendtable")
say("key enter"); say("key enter")     # material, thickness
say("key enter")                       # Finish
say("key enter")                       # the base flange's numbers
say("menu Sheet Metal > Edge Flange..."); say("key enter")
say("menu Sheet Metal > Edge Flange..."); say("key enter")
say("wait 3000")
shot("sheetmetal")
say("menu Sheet Metal > Flat Pattern")
say("wait 4000")                       # shaded first, then "saved as"
shot("flatpattern")
if not re.search(r"PART\d~1\.DXF", say("look")):
    problems.append("the flat pattern wasn't saved with an 8.3 name like PART3~1.DXF")
say("key enter")

# the personalized File menu: Save As is hidden until "Show all items"
t = say("menu File > Save As...", ok=False)
if "has no" not in t:
    problems.append("menu File > Save As... didn't say it was hidden: " + t.splitlines()[0])
say("key escape"); say("key escape")
say("menu File > Show all items")
say("wait 800")
shot("menu-expanded")
say("key escape"); say("key escape")
say("menu File > Save As...")          # shown now
say("wait 800")
shot("save-as")
say("key escape")

# the samples, through File > Open: they must build without a rebuild error
SAMPLES = Path(__file__).resolve().parents[2] / "samples"
for name, shotname in (("Filleted Plate.sc2", "sample-plate"), ("Sheet Metal Tray.sc2", "sample-tray")):
    say("key ctrl+o")
    say("wait 800")
    say("type " + str(SAMPLES / name))
    say("key enter")
    say("wait 4000")                   # the view is still shaded from before
    shot(shotname)
    t = say("look")
    if "Rebuild error" in t or name.split(".")[0] not in t:
        problems.append(f"{name} didn't open cleanly")

# the Upgrade Wizard
say("menu Help > Upgrade from SolidCraft 98...")
say("wait 800")
shot("upgrade")
say("look")
say("key escape")
say("key enter")

try:
    say("quit")
except SystemExit:
    pass
p.wait(timeout=30)

# the scheduled crash, brought forward to 10 seconds by /CRASHTEST
p = subprocess.Popen([str(EXE), "/REMOTE", "/CRASHTEST"])
time.sleep(4)
s = socket.create_connection(("127.0.0.1", 9898), timeout=60)
buf = b""
say("key r"); say("key enter")
say("key e"); say("key enter")
say("wait 9000")
shot("bluescreen")
if "fatal exception" not in say("look").lower():
    problems.append("no blue screen after /CRASHTEST")
say("key space")
say("wait 800")
t = say("look")
if "Extrude1" not in t:
    problems.append("the part was not there after the blue screen")
shot("after-bluescreen")
try:
    say("quit")
except SystemExit:
    pass
p.wait(timeout=30)
log.close()
if problems:
    print("PROBLEMS:\n  " + "\n  ".join(problems))
    sys.exit(1)
print("smoke test OK")
