SolidCraft 2000 for Linux and the Raspberry Pi  1.2
===================================================

Parametric CAD, the way it would have been written in 2000. Now with
fillets, chamfers, hole patterns, sheet metal and a blue screen every
15 minutes or so. SolidCraft 2000 is a parody, not affiliated with
SolidCraft.

sc2000-pi       Raspberry Pi 1 and up (ARMv6, 32-bit Raspberry Pi OS)
sc2000-x86_64   64-bit PC Linux

On a Raspberry Pi with the desktop:
    ./sc2000-pi
    ./sc2000-pi "Samples/Filleted Plate.sc2"

Raspberry Pi OS Lite (no desktop) needs a few small X libraries first,
even to run on the console:
    sudo apt install libx11-6 libxext6 libxpm4 libxrandr2
Then run it from the console (not over ssh); it takes the whole screen.
The mouse needs read access to /dev/input/mice (sudo, or the input group).

Try it:
    File, Open: Samples/Mounting Plate.sc98 (a SolidCraft 98 part, upgraded
    as it opens), Samples/Filleted Plate.sc2, Samples/Sheet Metal Tray.sc2.
    R sketches a rectangle, C a circle, E extrudes, V revolves, H drills
    holes (Count, Bolt circle dia. and Angle make a pattern), L fillets,
    M chamfers. Ctrl+Z and Ctrl+Y are Undo and Redo, twenty levels.
    Sheet Metal, Base Flange, then Edge Flange; Flat Pattern unfolds it
    and saves a DXF with an 8.3 name (PART2~1.DXF).
    S shades the view. On a Pi it takes a few seconds.
    The File, Features and View menus hide what you haven't used:
    "Show all items" opens them again.

It blue-screens every 12 to 18 minutes. Press any key: nothing is lost.
Help, Install Stability Pack stops it (remembered in
~/.config/solidcraft2000). --stable turns it off for one run, --crashtest
brings the first one forward to ten seconds.

Other switches: --upgrade starts the Upgrade Wizard, --remote the remote
control (see the main README), --bench times drawing on this machine:
    ./sc2000-pi --headless --bench "Samples/Filleted Plate.sc2"

Parts (.sc2) open in the Windows version and back, byte for byte, and
SolidCraft 98 parts (.sc98) open and are upgraded.

MIT License. See LICENSE and NOTICE.
SolidCraft 2000 is a parody, not affiliated with or a replacement for SolidCraft.
