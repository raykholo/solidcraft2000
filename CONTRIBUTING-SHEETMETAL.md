# Contributing a sheet-metal engine

SolidCraft 2000 has a slot for sheet metal: one module, `src/modSheetMetal.bas`,
that the rest of the program calls through a handful of functions. What's in it
now is a small reference engine. It's there to show the slot works end to end
and to be thrown away. This page is for whoever wants to put a real engine in
it, as advanced as they like, behind the clunkiest interface we can manage.

## Where it plugs in

Everything sheet metal is in `src/modSheetMetal.bas` (the engine) and
`src/frmBendTable.frm` (the Bend Table Wizard). Nothing else in the program
knows how sheet metal works. It only calls these:

| Call | Called by | What it must do |
|---|---|---|
| `SM_IsSheetMetal(kind)` | the model, the kernel | True for your feature kinds |
| `SM_UsesSketch(kind)` | the model, the tree | True if the kind uses up a sketch, as Extrude does |
| `SM_KindName(kind)`, `SM_KindPrefix(kind)` | the timeline, naming | "Edge Flange", and "EdgeFlange" for EdgeFlange1, EdgeFlange2... |
| `SM_RefOk(d, i)` | the kernel | Whether feature `i` builds. False shows "Rebuild error" and leaves it out |
| `SM_Describe(d, i)` | the timeline | The Description column |
| `SM_Edges(d, i, e(), n)` | the wireframe | One `AddEdge e, n, x1, y1, z1, x2, y2, z2, colour` per line |
| `SM_Mesh(d, i)` | shading, STL export | `MeshAddTri` for each triangle, then `MeshOrient first` for each closed body |
| `SM_Ask(d, i, f)` | New and Edit | The dialog(s) for feature `f`; True on OK with `f` filled in |
| `SM_Command(sCmd)` | the Sheet Metal menu | `SMBase`, `SMEdge`, `SMFlat`, `BendTable` |

Keep those signatures and change whatever is behind them. To add a menu item,
add it to the Sheet Metal menu in `src/frmMain.frm` with a `Tag`, and handle the
tag in `SM_Command` (and in the one `Case` line in `RunCommand`, in
`src/modCommands.bas`, that sends the sheet-metal tags your way).

### Features are one fixed-size record

A part is a `TDesign` (in `src/modModel.bas`): up to 64 `TFeature` records,
written to disk with `Put` exactly as they are. That record is the file format,
so a feature has to fit in it:

| Field | Type | The reference engine uses it for |
|---|---|---|
| `Kind` | Integer | `FK_SM_BASE` 20, `FK_SM_EDGE` 21, `FK_SM_FLAT` 22. Take 23 to 39 for new kinds |
| `Ref` | Integer | What it's built on: the sketch, or the base flange |
| `X`, `Y`, `Z` | Double | Edge flange: `X` is the edge (0 front, 1 right, 2 back, 3 left), `Z` the relief width |
| `P1`, `P2`, `P3` | Double | Base: thickness, inside bend radius, K-factor. Edge: length, angle, relief type |
| `Info` | String * 32 | Flat pattern: the DXF file name |
| `Reserved(1 To 3)` | Double | Free |
| `Suppressed` | Integer | Flat pattern: 0 shows the part flat, 1 folded |

Features can only build on features before them (`Ref < i`), and deleting one
deletes everything that refers to it. If you need more numbers than a record
holds, use two features (a hidden helper kind is fine), or add fields to
`TFeature` and bump `FILE_VERSION`, with a converter for the old record in
`LoadDesign`, the way versions 3 and 4 are done.

### Geometry

- Z is up, units are millimetres, and the base flange sits on its sketch, which
  is flat on the ground or on top of an extrude.
- The wireframe is just lines. Colour them with `COL_SOLID`, or `COL_BEND` for
  bend lines.
- The mesh must be closed and face outward for STL export to be any good.
  Build each closed body, then call `MeshOrient` with the `MeshCount()` from
  before it; it turns the body inside out if its volume came out negative.
  Bodies may touch or overlap (the reference engine's flanges overlap the base
  at the bend); slicers merge them.
- The kernel's helpers are yours to use: `SketchZ`, `ProfilePoints`,
  `RefOk`, `FeatureName`, `Fmt`.

## What the reference engine does

- **Base Flange** from a rectangle sketch with square corners: a plate as thick
  as the bend table says. Its thickness, inside bend radius and K-factor are
  used by every bend in the part.
- **Edge Flange** on one of the four edges of the base: a bend of any angle up
  to 180 degrees, then a straight leg. Bend relief is none, rectangular,
  obround or tear; with relief, the flange stops twice the relief width short of
  each corner, so flanges on neighbouring edges don't meet.
- **Flat Pattern** unfolds the part (bend allowance = angle x (R + K x T)),
  shows it flat with the bend lines in green, and writes an R12 DXF: the outline
  with its relief cuts on layer `OUTLINE`, and the bend lines on layer `BEND`.
  Choose it again to fold the part back up.
- **Bend Table Wizard**: material, then thickness, then a suggested bend
  radius and K-factor, with an Advanced... dialog over the wizard to change
  them.

What it doesn't do, on purpose, so there's something left for you: flanges on
flanges, more than one bend per flange, miter flanges, hems, jogs, corner
treatment, relief in the folded model, cuts across bends, forming tools,
per-bend radii, a real bend table file, and K-factors that depend on the
radius.

## How to run it

There's no build on Linux or a Mac; the program is VB6, built with twinBASIC on
Windows. Three ways to see your changes:

1. **Push a branch.** Every push builds on a Windows runner and runs
   `tools/ci/smoke.py`, which drives the program through its remote control: a
   base flange, two edge flanges, the flat pattern. The run keeps the built EXE
   (artifact `exe`) and screenshots of each step (artifact `screenshots`),
   with everything the program said in `remote.log`. Add your own steps to
   `smoke.py`.
2. **Build it on Windows** with [twinBASIC](https://twinbasic.com), as the
   README's "Building from source" says. Start the EXE with `/STABLE` to keep
   the scheduled blue screens away while you work.
3. **Drive it from a script.** Start it with `/REMOTE`, connect to port 9898,
   and send lines like `menu Sheet Metal > Edge Flange...`, `key enter` and
   `look`. `look` reads the screen back as text, including the timeline, so a
   test can check what was built.

The DXF lands next to the saved part, or in Documents if the part has never
been saved. Any DXF viewer will open it.

## What "clunky" means here

The engine underneath can be as good as you can make it. The interface on top
of it has to be as it would have been in 2000, and that means:

- **Wizards for everything.** Anything with more than three numbers gets a
  wizard: Back, Next, Finish, a picture down the left, and a step that asks
  something you've already answered. The Bend Table Wizard is the house style.
- **Dialogs in dialogs.** An Advanced... button opens a dialog over the
  dialog, and changing anything in it gets an "Are you sure?" over that.
- **Numbers for choices.** Which edge? Type 0, 1, 2 or 3. Which relief? 0 to 3,
  explained in the prompt. Every number goes through `frmParams`, the one
  dialog with the one column of text boxes.
- **8.3 file names.** Anything the engine writes is called `MOUNTI~1.DXF`,
  because the nesting software in the shop runs on DOS.
- **Modal everything.** Nothing can be done while a dialog is open, and every
  dialog is a dialog.
- **Message boxes that explain.** If something can't be done, say so in a
  message box, and say which version it's coming in. (SolidCraft XP. It's
  always SolidCraft XP.)

And the rules that apply to all of SolidCraft 2000:

- **It's a parody, not a copy.** Original code, original wording and original
  art only. No other CAD program's names, icons, dialogs or wording, and
  nothing that looks like a real company's product.
- **Nothing is ever lost.** The jokes are on screen only. Don't touch files
  the user didn't ask to write, and never break a part.
- **It works.** Under the clunk, the geometry should be right: a flat pattern
  from SolidCraft 2000 should be one you could cut.

Pull requests welcome. The licence is MIT.
