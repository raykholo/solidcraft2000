# SolidCraft 2000 for Linux and the Raspberry Pi

SolidCraft 2000 1.2, ported to FreeBASIC. It runs on 64-bit PC Linux and on
an original Raspberry Pi from 2014 (ARMv6, 512 MB). There's no toolkit:
every window, menu and button is drawn by the program itself in the Windows
2000 style (grey-teal, with a Y2K sticker), in its own pixel font, so it
looks the same on every machine. `.sc2` files are byte for byte the Windows
version's, both ways, and `.sc98` parts from SolidCraft 98 open and are
upgraded.

> **SolidCraft 2000 is a parody.** It is not affiliated with, endorsed by, or
> a replacement for SolidCraft. This is the Linux edition of the
> [SolidCraft 2000](../README.md) in this repository, itself the sequel to
> SolidCraft 98.

Download `SolidCraft2000-Linux-1.2.tar.gz` from the
[Releases page](https://github.com/raykholo/solidcraft2000/releases):
`sc2000-pi` for the Pi, `sc2000-x86_64` for a PC. Its `README.TXT` says what
a Pi without a desktop needs.

## What's in it

Everything the Windows version does, Service Pack 1 included:

- **Fillets** (L) and **chamfers** (M) on the top and bottom edges of an
  extrude, on the sides you add up (1 front, 2 right, 4 back, 8 left). They
  are exact in the wireframe, the shaded view and the STL: going up a fillet
  the outline shrinks by `r(1 - cos a)`.
- **Hole patterns**: Count, Bolt circle dia., Row spacing and Angle in the
  Hole dialog. Up to 36 holes in one feature.
- **Sketches on side faces**: the Face box in the sketch dialogs (1 front,
  2 right, 3 back, 4 left).
- **Undo and Redo**, twenty levels (Ctrl+Z, Ctrl+Y).
- **Sheet metal**: base flange, edge flange (relief: none, rectangular,
  obround, tear), and Flat Pattern, which unfolds the part, shows the bend
  lines in green and writes a DXF named the 8.3 way (`PART2~1.DXF`). The
  **Bend Table Wizard** has its Advanced... dialog and its "Are you sure?".
- **Help, Upgrade from SolidCraft 98**: the Upgrade Wizard. It changes
  nothing. Opening an `.sc98` part is what upgrades it.
- **The blue screen** every 12 to 18 minutes, and **Help, Install Stability
  Pack** to stop it.
- **Personalized Menus**: File, Features and View show only what you've used,
  and "Show all items" opens them again.
- Opening SolidCraft designs (fillets and chamfers included), Export for
  Rapid Prototyping (.stl), part windows, Turbo and every egg, and the remote
  control (`--remote`, see the main README).

Switches: `--stable` (no blue screen this run), `--crashtest` (the first one
in ten seconds), `--upgrade` (start the Upgrade Wizard), `--remote`,
`--headless --script <file>`, `--bench`. The Windows `/STABLE`, `/CRASHTEST`
and `/UPGRADE` work too.

## What it can't do

What the Windows version can't do yet (upright edges, other sketch shapes,
real booleans, a real sheet metal engine) it can't do here either: see
"What it can't do yet" in the main README. On top of that:

- **A Raspberry Pi 1 is slow.** Shading is software, one triangle at a time,
  and a filleted part has several times the triangles of a plain one, so a
  Pi shades it slowly, a band of rows at a time. This is accurate to 2000, when
  a Pentium II did the same. Use the wireframe (S again) to orbit; the
  shaded picture comes back when you let go.
- **No registry.** The Stability Pack is remembered in
  `~/.config/solidcraft2000/stability-pack`, a file with a 1 in it. Nothing
  else is saved, and the Personalized Menus start short on every run, as in
  the Windows version.
- **Drive A: doesn't exist.** Send To 3 1/2 Floppy still puts on its show
  with Turbo on, and keeps your part safe on the hard disk.
- **The flat pattern is 8.3 on a filesystem that doesn't care.** It's named
  `PART2~1.DXF` anyway, for the nesting software in the shop, which runs on
  DOS. It goes next to the part, or in `~/Documents`.
- **The Upgrade Wizard's option buttons aren't Tab stops.** They work with
  the mouse, the arrow keys and Alt+letter. It was 2000: nothing was.

| File | What it does |
|---|---|
| `src/sc2000.bas` | The program: includes the rest, in order |
| `src/gfx.bas`, `font.bi`, `icons.bi` | Drawing straight into pixel memory; the pixel font and the icons |
| `src/gui.bas`, `dialogs.bas` | Events, message boxes, the number dialog and the file dialog |
| `src/app.bas`, `part.bas` | The main window, the menus (Personalized Menus too) and every command; part windows |
| `src/model.bas` | Features and the `.sc2` file (versions 6 and 7, and `.sc98` upgrades) |
| `src/kernel.bas`, `mesh.bas`, `view.bas`, `shade.bas`, `stl.bas` | Geometry (frames, fillets, patterns), triangles, the view, shading, STL |
| `src/history.bas` | Undo and Redo |
| `src/sheetmetal.bas`, `sheetui.bas` | Sheet metal: the reference engine and the Sheet Metal menu |
| `src/wizards.bas` | The Upgrade Wizard, the Bend Table Wizard and the Stability Pack |
| `src/expr.bas` | Arithmetic in number boxes |
| `src/zip.bas`, `json.bas`, `import.bas` | Opening SolidCraft designs |
| `src/eggs.bas` | The splash, Turbo and the rest |
| `src/remote.bas`, `tutor.bas` | Remote control (`--remote`): commands on standard input, and the tutor |
| `tools/mkfont.py`, `mkicons.py` | Make `font.bi` and `icons.bi` from text pixel art (the icons come from `../src/modIcons.bas`) |

## Building

Everything builds in two container images, made from `containers/` with
`containers/build.sh` (podman):

- `sc2000-fb-x86`: FreeBASIC 1.10.1 on Ubuntu 22.04.
- `sc2000-fb-arm`: a Raspberry Pi OS userland with FreeBASIC's runtime built
  from source for ARMv6 (`tools/arm-rtlib.sh`); FreeBASIC's own ARM
  packages are for ARMv7. Building it needs qemu-user-static on a PC.

Then:

- `./build.sh src/sc2000.bas build/sc2000` for x86-64
- `./build-arm.sh` for the Pi: fbc writes C for linux-arm, and gcc for
  ARMv6 compiles and links it. Output: `build/arm/sc2000`
- `./mkdist.sh` builds both and packs `dist/SolidCraft2000-Linux-<v>.tar.gz`

GitHub builds both on every change (`.github/workflows/editions.yml`), and
the release downloads come from there: the artifacts `freebasic-linux`
(`sc2000`) and `freebasic-pi` (`sc2000`).

On a machine with FreeBASIC installed, `fbc -w all src/sc2000.bas -x sc2000`
is all it takes.

## Testing

- `tests/core.sh` builds and runs `tests/core_test.bas`: opens the samples
  and saves them again (the bytes must match), upgrades an `.sc98` part, and
  checks that fillets, chamfers, hole patterns, side-face bodies and the sheet
  metal tray mesh into closed solids, and that the STL and the flat pattern's
  DXF get written.
- `./run.sh tests/<script>.txt` runs a UI script headless (x86-64) and turns
  its screenshots into PNGs in `tests/out/`; `./run-arm.sh` does the same
  with the ARM build. Script commands: click, dblclick, drag, move, key,
  type, wait, shot, log, quit. CI runs `ui1` (first look), `ui13` (a fillet,
  a chamfer, a hole pattern, undo and redo, a side face), `ui14` (opening
  `.sc2` and `.sc98` parts, sheet metal, the flat pattern, both wizards, the
  Stability Pack), `ui15` (the blue screen, with `--crashtest`) and `ui16`
  (a SolidCraft design with a fillet), keeping every screenshot.
- `tests/remote-tutor.sh` checks the remote control's help.
- `tests/x11.sh` runs it in a virtual X display with real mouse and
  keyboard events (xdotool).
- `sc2000 --headless --bench <part>` times drawing.
