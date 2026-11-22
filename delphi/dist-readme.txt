SolidCraft 2000 Delphi Edition  1.2
===================================

SolidCraft2000.exe   Windows (and ReactOS)
sc2000-x86_64        64-bit PC Linux
sc2000-pi            Raspberry Pi 1 and up (ARMv6, 32-bit Raspberry Pi OS)

The Linux versions need a desktop and GTK 2:
    sudo apt install libgtk2.0-0
Then:
    chmod +x sc2000-pi
    ./sc2000-pi
    ./sc2000-pi "Samples/Filleted Plate.sc2"

Parts are .sc2 files, byte for byte the same as in the Visual Basic version of
SolidCraft 2000. SolidCraft 98 parts (.sc98) and SolidCraft designs
(.solidcraft) open too: a 98 part is upgraded, and saved as a new .sc2.

New in 2000: fillets and chamfers, hole patterns, sketches on side faces,
twenty levels of Undo and Redo, sheet metal (with a flat pattern saved as a DXF
with an 8.3 name), the Upgrade Wizard, Personalized Menus, and a blue screen
every 15 minutes or so. Help, Install Stability Pack stops that.

To see the blue screen without waiting:
    ./sc2000-pi --crashtest   (Windows: SolidCraft2000.exe /CRASHTEST)
To see the Y2K bug without touching the clock:
    ./sc2000-pi --y2ktest     (Windows: SolidCraft2000.exe /Y2KTEST)
then show all the View menu's items, switch Turbo on and wait a minute.

SolidCraft 2000 is a parody. It is not affiliated with SolidCraft.
