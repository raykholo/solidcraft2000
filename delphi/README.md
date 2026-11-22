# SolidCraft 2000 Delphi Edition

SolidCraft 2000 1.2 in Object Pascal, built with Free Pascal and Lazarus: the
Delphi 5 way, with real widgets, and one source for Windows (and ReactOS),
64-bit PC Linux and the Raspberry Pi 1 and up. The same features as the Visual
Basic version of SolidCraft 2000 (all but the remote control), the same grey-teal
window, and the same `.sc2` files byte for byte.

> **SolidCraft 2000 is a parody.** It is not affiliated with, endorsed by, or a
> replacement for SolidCraft, and it shares no code with it. This edition is the
> Delphi Edition of SolidCraft 98 with everything SolidCraft 2000 added put in.
> The [main README](../README.md) tells it properly.

Download `SolidCraft2000-Delphi-1.2.zip` from the
[Releases page](https://github.com/raykholo/solidcraft2000/releases). It has
`SolidCraft2000.exe` for Windows, `sc2000-x86_64` for Linux and `sc2000-pi` for
the Pi, and the samples. The Linux ones need GTK 2 (`sudo apt install
libgtk2.0-0`). Every build on the
[Actions tab](https://github.com/raykholo/solidcraft2000/actions) keeps them too
(artifacts `delphi-windows`, `delphi-linux`, `delphi-pi`).

Also in this edition: the splash says so, and the About box knows a word that
the Visual Basic version doesn't.

## What's in it

All of SolidCraft 98's (sketches, extrude, revolve, holes, change any feature
later, opening SolidCraft designs, STL, the shaded view, Turbo, Cal, the
floppies, Publish to Web, DLL Hell, the Y2K bug) and everything new in 2000:

- **Fillets** (L) and **chamfers** (M) on the top and bottom edges of an
  extrude, on the sides you add up (1 front, 2 right, 4 back, 8 left): exact in
  the wireframe, the shaded view and the STL.
- **Hole patterns**: Count, Bolt circle dia., Row spacing and Angle in the Hole
  dialog.
- **Sketches on side faces**: the Face box, 0 for the top, 1 to 4 for the sides.
- **Undo and Redo**, twenty levels for each part (Ctrl+Z, Ctrl+Y).
- **Sheet metal**: base flange, edge flange with its relief, Flat Pattern saved
  as a DXF with an 8.3 name (`PART1~1.DXF`), and the Bend Table Wizard, with
  Advanced... and its "Are you sure?".
- **The Upgrade Wizard** (Help), and **Personalized Menus** (File, Features and
  View show what you've used; "Show all items" shows the rest).
- **The blue screen** every 12 to 18 minutes, and **Help, Install Stability
  Pack**, which stops it. `--crashtest` brings the first one to ten seconds,
  `--stable` turns it off for the run.
- **`.sc2` parts**, version 6, or 7 if the part uses something from Service
  Pack 1. SolidCraft 98 parts (`.sc98`) open, are upgraded, and save as a new
  `.sc2`. SolidCraft designs open with their fillets and chamfers, when those
  take whole sides, as SolidCraft 2000's do.

## What it can't do yet

- **The remote control.** `/REMOTE` and its TCP port 9898 are the Windows
  version's. This one is driven by `xdotool` in CI, like a real user.
- **Real MDI.** Lazarus has MDI only on Windows, so part windows are panels with
  their own caption bars inside the main window's grey area. They work the same
  everywhere. (In 2000 the caption bars are teal.)
- **"Show all items" opening the menu again.** Windows can be sent the Alt key
  to do it; Lazarus can't open a menu from code on GTK. Choose it, then open the
  menu again: everything is there. Use anything and the menus go short again.
- **The Stability Pack's registry key.** It's one line in `SolidCraft2000.ini` in
  your config folder (`~/.config/SolidCraft2000/` on Linux), because VB's
  `SaveSetting` is VB's.
- **Fillets and chamfers on upright edges**, or on part of a circle: they wait
  for SolidCraft XP, in the timeline, as in the VB version.
- **A real sheet metal engine.** It is the reference engine: one bend per edge
  flange, only on the four edges of the base, no flanges on flanges, no corner
  treatment, relief cut only in the flat pattern, one bend radius throughout.
- Everything else the main README's "What it can't do yet" says: sketches are
  rectangles and circles, holes go straight in, no booleans to speak of, and
  export is STL (and DXF for flat patterns).

## What's where

| | |
|---|---|
| `SolidCraft2000.lpr`, `.lpi` | the program and the Lazarus project |
| `src/umodel.pas` | features, designs, the `.sc2` and `.sc98` files (packed records) |
| `src/ukernel.pas`, `umesh.pas`, `ushade.pas`, `uview.pas` | geometry (frames, patterns, fillets, sheet metal), triangles, the shaded view, projection |
| `src/usheet.pas` | the flat pattern's DXF, and the bend table |
| `src/uexpr.pas` | arithmetic in number boxes, and VB's `Val` |
| `src/uzip.pas`, `ujson.pas`, `uimport.pas` | opening SolidCraft designs |
| `src/ustl.pas`, `ugif.pas` | STL export; GIFs for Publish to Web |
| `src/udocs.pas` | open parts, message boxes, the 20-level history, Turbo, the clock |
| `src/ustability.pas`, `uadaptive.pas` | the blue screen's schedule and the Stability Pack; Personalized Menus |
| `src/ucommands.pas` | every command, one copy each |
| `src/fmain.pas`, `fpart.pas`, `fdialogs.pas`, `fwizard.pas` | the windows, built in code; the two wizards |
| `src/uart.pas`, `icondata.inc` | icons (from `tools/mkicons.py`), gradients, the 2000 logo, the starburst and the Y2K sticker |
| `tests/` | `coretest.pas` and the screen tests |

## Build

With Lazarus installed, on any of the three:

    lazbuild SolidCraft2000.lpi                      # build/SolidCraft2000
    lazbuild --build-mode=Debug SolidCraft2000.lpi   # with range checks and line numbers

The release downloads are built by GitHub (`.github/workflows/editions.yml`):
Linux and Windows on its runners, the Pi in an emulated Raspberry Pi OS. By hand:

- Linux: `./build.sh`, in the `sc2000-lz-x86` image (Ubuntu 22.04, FPC 3.2.2,
  Lazarus 2.2).
- Raspberry Pi: `./build-arm.sh`, in the emulated `sc2000-lz-arm` image
  (Raspberry Pi OS bullseye, Lazarus 2.0). Output: `build/arm/SolidCraft2000`.
- Windows: Lazarus 3.6, 32-bit, `lazbuild SolidCraft2000.lpi`. The EXE goes in
  `build/win/` for packing.
- `./mkdist.sh` packs all three into `dist/`.

The images are made from `containers/` with `containers/build.sh` (podman; the
ARM one needs qemu-user-static on a PC).

## Tests

Run from `delphi/`; the samples are in `../samples`.

    fpc -O1 -Fusrc -Fu<lazutils units> -FUbuild -obuild/coretest tests/coretest.pas && build/coretest
    podman run --rm -v "$PWD/..":/r:Z -w /r/delphi sc2000-lz-x86 bash tests/x11.sh tests/ui-basic.sh

`coretest` reads every sample, writes it back and compares the bytes, builds a
filleted block, a chamfered one, a bolt circle, a boss on a side face and a
sheet metal tray, and checks that every mesh is closed and faces outward.

The screen tests run the program on a virtual screen and leave screenshots in
`tests/out`: `ui-basic` (a box with a hole, shaded), `ui-2000` (a fillet, a hole
pattern, undo and redo, a boss on a side face, a chamfer), `ui-2000-files`
(`Filleted Plate.sc2`, `Mounting Plate.sc98` upgraded, Save As, a design with a
fillet), `ui-2000-sheet` (the Bend Table Wizard, Advanced and its "Are you
sure?", a base flange, an edge flange, a flat pattern), `ui-2000-misc`
(Personalized Menus, the Upgrade Wizard, the Stability Pack), `ui-crash` (start
with `--crashtest`: the blue screen), and SolidCraft 98's: `ui-turbo`,
`ui-about`, `ui-files`, `ui-misc` (run with `--y2ktest` and wait a minute for Y2K).
