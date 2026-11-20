# SolidCraft 2000

[![Build](https://github.com/raykholo/solidcraft2000/actions/workflows/build.yml/badge.svg)](https://github.com/raykholo/solidcraft2000/actions/workflows/build.yml)

> **NEW! SOLIDCRAFT 2000 PROFESSIONAL EDITION.** The sequel to the CAD
> program that brought parametric solid modelling to the desktop PC. Now
> with **FILLETS**: round the edges of any extrude in a single step!
> Personalized Menus that learn how you work. Sheet metal*. A brand-new
> Upgrade Wizard. Certified Year 2000 compliant**. Built on 98 technology.
> Crashes less than once an hour***.
>
> <sub>\* some assembly required: see [Sheet metal](#sheet-metal). \*\* tested until 19 January 2038.
> \*\*\* every 15 minutes or so; the [Stability Pack](#the-stability-pack) is free.</sub>

![The SolidCraft 2000 splash screen](docs/screenshots/splash.png)

SolidCraft 2000 is the sequel to [SolidCraft 98](https://github.com/raykholo/solidcraft98),
written the way it would have been written in 2000: the same Visual Basic,
the same MDI window, `TreeView` and `ListView`, and a wireframe drawn with
`Line`, one edge at a time. Now in grey-teal, with every new idea of the year
2000 in it, good and bad.

It's a joke, but it works. Everything SolidCraft 98 does, it does: sketch,
extrude, revolve, drill holes, change any feature later, open designs from
SolidCraft itself, and export STL for a 3D printer. And it opens SolidCraft 98
parts.

> **SolidCraft 2000 is a parody.** It is not affiliated with, endorsed by, or a
> replacement for SolidCraft, and it shares no code with it.

Requested by the SolidCraft Discord, which has been asking for SolidCraft
2000 since SolidCraft 98 first said a feature "requires SolidCraft 2000",
and by brett19, who asked that it blue-screen every 15 minutes or so. It does.

**Talk about it** on the [Dutchman CAD Discord](https://discord.gg/yTcseBEdeu).

## Getting it

There's no release yet. Every build on the [Actions tab](../../actions) keeps
the EXE (artifact `exe`); download it, unzip it anywhere and run
`SolidCraft2000.exe`. One EXE, nothing to install, like SolidCraft 98. It runs
on Windows 10 and 11. The EXE isn't signed, so Windows may say it "protected
your PC": choose More info, then Run anyway.

Like SolidCraft 98, it still fits on one 1.44 MB floppy disk, packed with UPX.

## New in 2000

### Fillets

**Features > Fillet** (L, or the new button on the toolbar) rounds every top
edge of an extrude: the one picked in the tree or the timeline, or the last
one. Type the radius. That's it.

![The Filleted Plate sample: a plate and a boss, each with its top edges filleted](docs/screenshots/fillet.png)

- It's parametric, like everything else: double-click the fillet in the
  timeline to change its radius, or the extrude under it to change that.
- It's in the wireframe, the shaded view and the STL. The rounded edge is
  exact: going up the fillet, the outline shrinks by `r(1 - cos a)`, so a
  rectangle's corners get sharper and a circle gets smaller, as they should.
- Holes keep clear of it: the Hole dialog won't put one in the rounded edge,
  and a fillet too big for the holes already there says which hole is in the
  way.
- One fillet per extrude, on all its top edges at once. Choosing edges is
  coming in SolidCraft XP. A rectangle's Corner radius still rounds the four
  upright edges.

Cal, the caliper assistant, has learned a second thing: "It looks like you're
trying to round an edge!"

### Sheet metal

The **Sheet Metal** menu: Base Flange, Edge Flange, Flat Pattern and the Bend
Table Wizard. Sketch a rectangle, choose Base Flange, and the Bend Table Wizard
asks for a material and a thickness (with an Advanced... dialog over the
wizard, for the bend radius and K-factor, and an "Are you sure?" over that).
Then add edge flanges, one to an edge, each with its own angle and bend relief.

![The Sheet Metal Tray sample: a base flange and four edge flanges, each with a different relief](docs/screenshots/sheetmetal.png)

![The Bend Table Wizard](docs/screenshots/bendtable.png)

**Flat Pattern** unfolds the part, shows the bend lines in green, and writes a
DXF of the flat blank with its relief cuts, named the 8.3 way
(`PART2~1.DXF`) for the nesting software in the shop. Choose it again to fold
the part back up.

![A part with two edge flanges, unfolded](docs/screenshots/flatpattern.png)

What's there now is a small reference engine. It's a slot: everything sheet
metal is in one module, behind a documented interface, waiting for a real
engine. [CONTRIBUTING-SHEETMETAL.md](CONTRIBUTING-SHEETMETAL.md) says where it
plugs in, how to run it, and what "clunky" means here.

### Personalized Menus

The File, Features and View menus show only what you've used. The rest wait
behind **Show all items** at the bottom, which opens the menu again with
everything in it. Use something and it stays. Keyboard shortcuts of hidden
items don't work, because Windows takes a hidden item's shortcut with it; that
is how it was, and why everybody turned this off. (Nothing is saved: every run
starts short.)

![The File menu, all items shown](docs/screenshots/menu-expanded.png)

### The Upgrade Wizard

**Help > Upgrade from SolidCraft 98** (or start it with `/UPGRADE`): Welcome,
the licence agreement, Upgrade or Clean install, a Year 2000 compliance check,
and Finish. It changes nothing on your computer. The upgrade that matters
happens when you open an `.sc98` part: it comes in whole, and Save writes it as
a new `.sc2`.

![The Upgrade Wizard](docs/screenshots/upgrade.png)

### The Stability Pack

Every 12 to 18 minutes, SolidCraft 2000 blue-screens. It's a picture: any key
closes it, and the part, the timeline and any open dialog are exactly as they
were. Nothing is ever lost.

![A fatal exception in FILLET.VXD](docs/screenshots/bluescreen.png)

**Help > Install Stability Pack** stops it, and is remembered (one setting, in
the registry key VB's `SaveSetting` uses). It's also off under the remote
control and with `/STABLE`. `/CRASHTEST` brings the first one forward to ten
seconds, to see it without waiting.

### And

- Parts are `.sc2` files. File > Open still takes `.sc98` parts and SolidCraft
  designs. Two new samples: `Filleted Plate.sc2` and `Sheet Metal Tray.sc2`.
- The splash, the About box and the wizards are grey-teal, with a Y2K
  sticker. The logo's block has filleted edges.
- The demo-scene credits (type WIN98 in the About box) have new lines.

## Design a part with a fillet

A mounting plate with a rounded top edge: 80 x 50 x 6 mm, a hole in each
corner, and a boss with a bore. About five minutes.

1. **The plate outline.** Press R. Width 80, Height 50, Corner X -40, Corner
   Y -25, Corner radius 6. OK.
2. **The plate.** Press E. Depth 6. OK.
3. **The fillet.** Press L. Radius 2. OK. The top edge of the plate is round,
   and so are its corners.
4. **Corner holes.** Press H. Diameter 5, Depth 0 (all the way through),
   Centre X -32, Centre Y -17. OK. Again at (32, -17), (32, 17) and (-32, 17).
5. **The boss.** Press C: Radius 10, Centre 0, 0, on feature # 2 (the plate).
   OK. Press E: Depth 15. OK. Press L: Radius 3. OK.
6. **The bore.** Press H. Diameter 10, Depth 0, Centre 0, 0. It goes through
   the boss and the plate.
7. **Change your mind.** Double-click Fillet1 and make it 5. SolidCraft 2000
   says Hole1 is too close to the edge for that. Make it 3.
8. **Shade it** with S, and **print it** with File > Export for Rapid
   Prototyping (Show all items first: it's hidden until you've used it).

## What it can't do yet

- Sketches are rectangles and circles, flat, facing up. Holes go straight down
  from a top face. Fillets go on all the top edges of an extrude, or none.
- No booleans to speak of: a body standing wholly on another's top face is
  joined to it in an STL; anything else stays separate (slicers merge them).
- Sheet metal is the reference engine: see its limits in
  [CONTRIBUTING-SHEETMETAL.md](CONTRIBUTING-SHEETMETAL.md).
- Export is STL, and DXF for flat patterns. Parts save as `.sc2`.

## Keys

| Key | Command |
|---|---|
| Ctrl+N / Ctrl+O / Ctrl+S | New, Open, Save |
| Ctrl+Z | Undo last feature |
| R, C | Sketch rectangle, sketch circle |
| E, V, H, L | Extrude, Revolve, Hole, Fillet |
| I, F | Isometric view, Zoom to fit |
| S | Shaded (again for wireframe) |
| Enter, or double-click | Edit the selected feature |
| Del | Delete the selected feature |
| + / - | Zoom in and out |
| F5 | Regenerate |
| F1 | Help (it isn't installed) |

Turbo, Cal's pin, the floppies, Publish to Web, DLL Hell and the Y2K bug are
all still in there. [SolidCraft 98's README](https://github.com/raykholo/solidcraft98#turbo)
has the spoilers.

## Remote control

Start it with `/REMOTE` and SolidCraft 2000 listens on TCP port 9898, as
SolidCraft 98 does, and takes the same commands: `look`, `click`, `menu`,
`key`, `type`, `how`, `yes` and the rest. It reads the new things out too: the
Sheet Metal menu, the wizards and their lists, and the blue screen. Plain
`/REMOTE` takes connections from this PC only; `/REMOTE:ANY` from any
computer, so use that only on a network you trust.

The personalized menus apply to the remote control as well: "menu File > Save
As..." answers that the File menu has no Save As, and lists what it does have,
including Show all items. CI drives the program this way on every push
(`tools/ci/smoke.py`).

## Source

The source is plain VB6 text: `src/SolidCraft2000.vbp` plus `.frm` and `.bas`
files. There are no `.frx` files: the icons, the logo and the splash are
drawn at startup. New in 2000:

| File | What it does |
|---|---|
| `modKernel.bas` | Fillets: `InsetSketch`, `FilletOf`, `TopFace`, and the rounded wireframe |
| `modMesh.bas` | Fillets in the solid: rings of the outline moved in, up the quarter circle |
| `modSheetMetal.bas` | Sheet metal: the slot and its reference engine |
| `frmBendTable.frm` | The Bend Table Wizard |
| `modAdaptive.bas` | Personalized Menus |
| `frmUpgrade.frm` | The Upgrade Wizard |
| `modStability.bas` | The blue screen every 15 minutes or so, and the Stability Pack |
| `modArt.bas` | The 2000 logo, the starburst and the Y2K sticker, in `Line`, `Circle` and GDI |

The rest is SolidCraft 98's, described in
[its README](https://github.com/raykholo/solidcraft98#source).

## Building from source

**With twinBASIC** (free, and what CI builds with), on Windows with Python 3:

```
python tools/vb2tb.py src/SolidCraft2000.vbp build/src
python tools/impexp.py import build/SolidCraft2000.twinproj build/src --overwrite
twinBASIC.exe build\SolidCraft2000.twinproj --buildAndExit32
```

The EXE lands in `build\Build\SolidCraft2000.exe`. If the build hits a compile
error the IDE stays open in the background: open the `.twinproj` in the IDE to
see it.

**On GitHub**, every push builds on a Windows runner (`.github/workflows/build.yml`,
which runs `tools/ci/build.ps1`), fails if the UPX-packed EXE no longer fits
on a floppy, and then runs the smoke test, keeping its screenshots. A `v*` tag
publishes the zip and the floppy image as a release.

## Licence

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE). The EXE is compiled with
twinBASIC, which is not part of this project.

SolidCraft 2000 is a parody, and not affiliated with or a replacement for
SolidCraft.
