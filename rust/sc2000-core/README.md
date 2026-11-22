# SolidCraft 2000 core

The Embedded Edition's parts, feature history, geometry and files, now with the
fillet and the chamfer. The library
is `no_std` with `alloc`, forbids unsafe code, and has no filesystem, display,
window-system or global mutable state. Even the optional `import` feature works
without `std`. An embedded caller supplies an allocator and handles storage.

## Pixel-layer API

```rust
use sc2000_core::{Error, Feature, FeatureKind, Part};

let mut part = Part::new("My first block");
let sketch = part.add_feature(Feature {
    kind: FeatureKind::Rectangle,
    x: -40.0, y: -25.0, p1: 80.0, p2: 50.0, p3: 6.0,
    ..Feature::default()
})?;
part.add_feature(Feature {
    kind: FeatureKind::Extrude, reference: sketch as i16, p1: 6.0,
    ..Feature::default()
})?;
let rebuilt = part.rebuild(32)?;
for triangle in rebuilt.mesh.triangles() {
    let vertices = triangle.vertices; // three [Scalar; 3], model-space mm
    let normal = triangle.normal;     // unit outward face normal
    let colour = triangle.colour;     // opaque 0xAARRGGBB
    let feature = triangle.feature;   // owning feature, for picking
    // Project vertices and pass these values to the pixel layer.
    # let _ = (vertices, normal, colour, feature);
}
let saved = part.to_sc98();
let loaded = Part::from_sc98(&saved)?;
assert_eq!(loaded.part.features().len(), 2);
let stl = part.mesh(64)?.to_stl(&part.title)?;
# let _ = stl;
# Ok::<(), Error>(())
```

`Part::features()` returns the timeline in file order. Feature IDs are **one
based**; zero is the ground plane, and `feature(id)` returns an `Option`.
References always identify earlier features. `ref_ok(id)` implements the
reference edition's validity rules; `Rebuild::invalid_features` identifies
features that could not be built. A suppressed feature remains in the timeline
and file but emits no edges or triangles. As in FreeBASIC, suppression does not
implicitly delete its descendants.

`add_feature` assigns names such as Sketch1 and Extrude2; `add_named_feature`
preserves a supplied name. `edit_feature` replaces one feature. Use a clone of
`feature(id)` to change selected fields. Rebuilding has no cache, so a changed
extrude immediately moves sketches on its top face and recalculates through
holes. `dependents(id)` previews deletion; `delete_with_dependents(id)` returns
the deleted IDs, compacts the timeline and renumbers references. The remaining
features retain their names. A part holds at most 64 features.

| Kind | `x`, `y` | `z` | `p1` | `p2` | `p3` | `reference` |
|---|---|---|---|---|---|---|
| Rectangle | lower-left corner | height/offset | width | height | corner radius | 0 or supporting extrude |
| Circle | centre | height/offset | radius | unused | unused | 0 or supporting extrude |
| Extrude | unused | unused | signed depth | unused | unused | sketch |
| Revolve | unused | unused | signed degrees about Y | unused | unused | sketch |
| Hole | centre | unused | diameter | depth; <=0 through all | unused | extrude |
| Fillet, Chamfer | unused | unused | radius, or distance at 45° | unused | unused | extrude |
| Foreign | unused | unused | unused | unused | unused | 0 |

A fillet or chamfer takes edges of its extrude, and `reserved` (the record's three
spare doubles, kept so a file saves back as it was read) says which: `reserved[0]`
is the sum of the top sides it leaves **sharp** (1 front, 2 right, 4 back, 8 left,
so 0 is all four) and `reserved[1]` the sum of the bottom sides it takes.
`Feature::finish_top()` and `finish_bottom()` give the sides taken. A circle, or a
rectangle with rounded corners, is all or nothing. An extrude gets one fillet or
chamfer, the first that fits (`edge_finish_of`), and holes have to keep clear of it
(`top_face`, `bottom_face`). Not in the preview yet: hole patterns, sketches on
side faces (a sketch with `reserved[0]` set is reported as an invalid feature),
sheet metal, and fillets on chosen edges of a sketch other than a sharp rectangle.

A sketch's `z` is relative to a supporting extrude's top. Hole depth is measured
down from the target top face; through holes continue through stacked bodies
that contain them. `Feature::info` describes an unsupported imported operation;
`kind.name()`, `describe(id)` and `model::fmt_number` supply timeline text.

A fillet is built as the VB edition builds it: the extrude's walls go through rings, each
the outline moved in a little more up a quarter circle (`kernel::edge_at`), and a chamfer
is one straight band. `regenerate()` draws the rings; `mesh()` bands them, and caps the
top and bottom with the flat part of each face.

`regenerate()` produces the reference's 32-segment wireframe, including sketch
and hole colours and revolve axes. `mesh(segments)` produces only solid faces;
32 segments is suitable for shading, and `mesh::MESH_SEGS` (64) is the STL
resolution. `rebuild(segments)` returns both. Normals and colours are per
triangle. Hole walls/floors use `0xffcd877d`; other faces use `0xffa5b2c8`.
Triangles retain their owning feature even when two stacked bodies are joined.
`Mesh::warnings` carries the reference's cap failure messages; inspect it before
exporting because unmeshable bodies are omitted. The library matches the
reference's limited joining rules rather than implementing general booleans.

`Scalar = f32` is the pixel interface's coordinate type. **Compatibility
exception:** dimensions and the reference geometry use the `Dimension = f64`
alias, with `libm` for trigonometry, square roots and rounding. Rounding inputs or
intermediate geometry to f32 changes triangulation and STL bytes. Each triangle
therefore retains private double coordinates until STL translation is complete;
its exposed vertices and normal are f32. This adds RAM cost: on a 64-bit host a
triangle occupies 136 bytes, or 265,472 bytes for the 1,952-triangle plate. Use a
lower segment count for the display and release its mesh before exporting.
Changing `Scalar` alone changes the pixel boundary, not compatibility arithmetic.

## Files and import

`Part::from_sc2(&[u8])` opens a SolidCraft 2000 `.sc2` part (magic `SC2K`, versions 3 to
7; 6 is SolidCraft 2000 1.0 and 7 is Service Pack 1) and, as SolidCraft 2000 does, a
SolidCraft 98 part. `to_sc2()` writes the oldest version that can hold the part (6, unless
it has a chamfer, a hole pattern, a fillet on chosen edges or a sketch on a side face).
The record is the same 134 bytes as SolidCraft 98's, with the three reserved doubles now
kept. `Part::from_sc98` still reads only SolidCraft 98 parts.

`Part::from_sc98(&[u8])` returns `LoadedPart { part, conversion }`. Versions 3 and
4 convert to version 5; version 3 lacks corner radii, and both older versions
lack foreign-feature information. `Conversion::Version3` lets the application
show the historical conversion notice. `to_sc98()` always writes the 8,648-byte
version-5 format: 72-byte header, 64 little-endian 134-byte feature records, with
fixed strings and reserved fields matching FreeBASIC. Inactive record fields
are preserved, with their kinds reset on load as in the reference. Empty strings
are NUL-filled; assigned strings are space-padded. Strings represent Latin-1
characters; characters beyond byte 255 save as `?`. Padding, reserved doubles
and trailing Turbo preview data are normalized exactly as the reference resave
does, so such noncanonical inputs are not promised an unchanged byte stream.
Truncated files, unsupported versions and nonfinite dimensions return errors.

`expr::evaluate` handles number-box arithmetic, with error codes 11 (division by
zero) and 13 (type mismatch). It also preserves FreeBASIC `Val`'s numeric-prefix
behaviour for `1.2.3`. Expressions and parameter substitution have recursion
limits so malformed inputs cannot exhaust the stack.

Enable `import` for `sc2000_core::import::open(bytes, fallback_title)`. It accepts
plain JSON, stored ZIP entries and Deflate-compressed `document.json` entries.
It supports the reference's sketches, face placement, parameter expressions and
units, additive/cut extrudes, revolves and drilled holes. Unsupported operations
become Foreign features and return `ImportNotice`s; history overflow sets
`ImportedPart::full`. ZIP lengths and CRCs are checked and document inflation is
limited to 16 MiB. UI notices and file I/O belong to the caller.

`Mesh::to_stl(title)` returns binary STL bytes: the reference's 80-byte header,
triangle order, normals, positive-coordinate translation, millimetres and zero
attribute words. Empty meshes return an error.

## Reference checks

The fixtures in `tests/fixtures/` were generated by **FreeBASIC 1.10.1**, using
`tests/reference.bas` to include the unchanged model, kernel, mesh, expression,
import, JSON, ZIP and STL sources. Only UI messages, bounding-box helpers and the
normal helper are provided by the harness. The normal helper is copied from
`freebasic/src/shade.bas`; no reference geometry is reimplemented.

| Design | Features | Wireframe edges | STL triangles |
|---|---:|---:|---:|
| Mounting Plate.sc98 | 9 | 560 | 1,952 |
| Plate with holes.solidcraft | 10 | 560 | 1,952 |
| Revolved parts.solidcraft | 4 | 466 | 6,780 |
| Flange.solidcraft | 8 | 444 | 1,552 |

The tests visit **every SolidCraft 98 design file** in `samples/`. Native saves and imported `.sc98` saves match the reference
byte for byte. All four binary STLs also match byte for byte. Independent
reference hashes cover the unshifted public vertices, order and feature IDs.

The fillet and chamfer have no reference fixtures: SolidCraft 98 has none. They are checked
(`tests/fillet.rs`) by closed meshes, volumes against the formula for the material a fillet
removes, the sides and sizes that fit, holes keeping clear, the wireframe, `.sc2` round trips
and `samples/Filleted Plate.sc2`.
`reference.tsv` records STL SHA-256 hashes and reference counts. The tests also
port the non-rendering checks in `freebasic/tests/core_test.bas`, including its
32-segment shading mesh and expression checks. Framebuffer rendering belongs to
the pixel crate. Additional tests cover conversion, mutation, closed edges,
orientation, blind/stacked holes, malformed input and unsupported imports.

From `rust/`, run each command separately:

```sh
nice -n 10 cargo test --offline -p sc2000-core --test core -j 4
nice -n 10 cargo test --offline -p sc2000-core --test import --features import -j 4
nice -n 10 cargo test --offline -p sc2000-core --doc --all-features -j 4
nice -n 10 cargo clippy --offline -p sc2000-core --all-targets --all-features -j 4 -- -D warnings
cargo fmt --all --check
```

To verify or regenerate goldens with FreeBASIC installed, run
`python3 sc2000-core/tests/reference.py` (verify) or add `--write` (regenerate).
`FBC` selects the compiler and `FBC_FLAGS` supplies any installation-specific
include/library paths. This is a headless build of the reference geometry and
import code; the full FreeBASIC GUI was not built.

## RISC-V release size

The workspace release profile uses `opt-level = "z"`, LTO, one codegen unit,
abort-on-panic and stripping. Build the no_std library with:

```sh
nice -n 10 cargo build -p sc2000-core --release --no-default-features \
  --target riscv32imc-unknown-none-elf -j 4
```

Measured on 2026-11-12 with rustc 1.90.0: the default-feature
`riscv32imc-unknown-none-elf` release `libsc2000_core.rlib` is **495,630 bytes
(484.0 KiB)**. This is an archive size, including Rust metadata and LTO bitcode;
it is not a flash-usage figure. The optional `import` build also passed on
the same target and its core archive is **766,256 bytes (748.3 KiB)**; dependency
archives are separate. Linked firmware size additionally depends on
the allocator, entry point and which APIs its linker retains. CI repeats the
cross-build and records archive sizes with and without import.
