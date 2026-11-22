//! Fillets and chamfers (SolidCraft 2000 1.0, Service Pack 1) and `.sc2` files.
use sc2000_core::{
    file::{Conversion, FILE_BYTES},
    mesh::MESH_SEGS,
    Error, Feature, FeatureKind as K, Mesh, Part,
};
use std::{collections::BTreeMap, f64::consts::PI, fs, path::PathBuf};

fn root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}
fn volume(m: &Mesh) -> f64 {
    m.triangles()
        .iter()
        .map(|t| {
            let [a, b, c] = t.vertices.map(|v| v.map(f64::from));
            (a[0] * (b[1] * c[2] - b[2] * c[1]) - b[0] * (a[1] * c[2] - a[2] * c[1])
                + c[0] * (a[1] * b[2] - a[2] * b[1]))
                / 6.0
        })
        .sum()
}
fn assert_closed(m: &Mesh) {
    let key = |p: [f32; 3]| p.map(|v| if v == 0.0 { 0 } else { v.to_bits() });
    let mut edges = BTreeMap::new();
    for t in m.triangles() {
        for k in 0..3 {
            let a = key(t.vertices[k]);
            let b = key(t.vertices[(k + 1) % 3]);
            if a != b {
                let (pair, dir) = if a < b { ((a, b), 1) } else { ((b, a), -1) };
                let e = edges.entry(pair).or_insert((0, 0));
                e.0 += 1;
                e.1 += dir;
            }
        }
    }
    for (edge, (count, dir)) in edges {
        assert_eq!((count, dir), (2, 0), "edge {edge:?}");
    }
}
/// A 20 x 10 block, 5 mm tall, with sketch 1 and extrude 2.
fn block(sketch: Feature) -> Part {
    let mut p = Part::new("Block");
    p.add_feature(sketch).unwrap();
    p.add_feature(Feature {
        kind: K::Extrude,
        reference: 1,
        p1: 5.0,
        ..Feature::default()
    })
    .unwrap();
    p
}
fn rect() -> Feature {
    Feature {
        kind: K::Rectangle,
        p1: 20.0,
        p2: 10.0,
        ..Feature::default()
    }
}
fn finish(kind: K, size: f64, sharp_top: f64, bottom: f64) -> Feature {
    Feature {
        kind,
        reference: 2,
        p1: size,
        reserved: [sharp_top, bottom, 0.0],
        ..Feature::default()
    }
}
fn built(p: &Part) -> Mesh {
    let r = p.rebuild(MESH_SEGS).unwrap();
    assert!(r.invalid_features.is_empty(), "{:?}", r.invalid_features);
    assert!(r.mesh.warnings.is_empty());
    r.mesh
}

#[test]
fn edge_at_matches_the_visual_basic_kernel() {
    use sc2000_core::kernel::edge_at;
    let (i, r) = edge_at(false, 2.0, 0.5);
    assert!((i - 2.0 * (1.0 - (PI / 4.0).cos())).abs() < 1e-12);
    assert!((r - 2.0 * (PI / 4.0).sin()).abs() < 1e-12);
    assert_eq!(edge_at(true, 2.0, 0.25), (0.5, 0.5));
    assert_eq!(edge_at(false, 3.0, 1.0).1, 3.0);
}
#[test]
fn a_top_fillet_rounds_a_block_and_stays_closed() {
    let mut p = block(rect());
    let sharp = built(&p);
    assert_eq!(sharp.triangles().len(), 12);
    let f = p.add_feature(finish(K::Fillet, 1.0, 0.0, 0.0)).unwrap();
    assert_eq!(p.feature(f).unwrap().name, "Fillet1");
    assert_eq!(p.edge_finish_of(2), Some(3));
    assert_eq!(p.feature(3).unwrap().finish_top(), 15);
    assert_eq!(p.feature(3).unwrap().finish_bottom(), 0);
    let m = built(&p);
    assert_closed(&m);
    assert!(m.triangles().len() > sharp.triangles().len());
    // The block loses (1 - pi/4) r^2 of material along 60 mm of edge, and a little
    // less at the corners.
    let lost = 1000.0 - volume(&m);
    let exact = (1.0 - PI / 4.0) * 60.0;
    assert!(
        lost > exact * 0.9 && lost < exact * 1.1,
        "{lost} vs {exact}"
    );
    // The top is 18 x 8 now.
    let top = m
        .triangles()
        .iter()
        .filter(|t| t.vertices.iter().all(|v| v[2] == 5.0))
        .flat_map(|t| t.vertices)
        .fold([f32::MAX, f32::MIN], |a, v| {
            [a[0].min(v[0]), a[1].max(v[0])]
        });
    assert_eq!(top, [1.0, 19.0]);
    assert_eq!(p.describe(3).unwrap(), "R 1 mm, top edges of Extrude1");
}
#[test]
fn a_chamfer_is_one_flat_band() {
    let mut p = block(rect());
    p.add_feature(finish(K::Chamfer, 1.0, 0.0, 0.0)).unwrap();
    let m = built(&p);
    assert_closed(&m);
    let lost = 1000.0 - volume(&m);
    assert!((lost - 30.0).abs() < 2.0, "{lost}");
    assert_eq!(p.describe(3).unwrap(), "1 mm x 45°, top edges of Extrude1");
}
#[test]
fn chosen_sides_top_and_bottom() {
    let mut p = block(rect());
    // Leave the front (1) and right (2) top edges sharp; take the bottom's back (4) and left (8).
    p.add_feature(finish(K::Fillet, 1.0, 3.0, 12.0)).unwrap();
    let f = p.feature(3).unwrap();
    assert_eq!((f.finish_top(), f.finish_bottom()), (12, 12));
    let m = built(&p);
    assert_closed(&m);
    assert_eq!(
        p.describe(3).unwrap(),
        "R 1 mm, top back and left edges, bottom back and left edges of Extrude1"
    );
    let lost = 1000.0 - volume(&m);
    let exact = (1.0 - PI / 4.0) * (20.0 + 10.0) * 2.0;
    assert!(
        lost > exact * 0.9 && lost < exact * 1.1,
        "{lost} vs {exact}"
    );
    // The bottom only.
    let mut q = block(rect());
    q.add_feature(finish(K::Fillet, 1.0, 15.0, 15.0)).unwrap();
    assert_eq!(q.feature(3).unwrap().finish_top(), 0);
    assert_closed(&built(&q));
}
#[test]
fn circles_and_rounded_rectangles_take_all_their_edges() {
    let circle = Feature {
        kind: K::Circle,
        p1: 8.0,
        ..Feature::default()
    };
    let mut p = block(circle);
    p.add_feature(finish(K::Fillet, 2.0, 0.0, 15.0)).unwrap();
    let m = built(&p);
    assert_closed(&m);
    assert!(volume(&m) < PI * 64.0 * 5.0);
    let rounded = Feature { p3: 3.0, ..rect() };
    let mut p = block(rounded);
    p.add_feature(finish(K::Fillet, 2.0, 0.0, 0.0)).unwrap();
    assert_closed(&built(&p));
    // A rounded rectangle cannot take only some sides.
    let rounded = Feature { p3: 3.0, ..rect() };
    let mut p = block(rounded);
    p.add_feature(finish(K::Fillet, 1.0, 3.0, 0.0)).unwrap();
    assert_eq!(p.edge_finish_of(2), None);
    assert_eq!(p.rebuild(32).unwrap().invalid_features, vec![3]);
}
#[test]
fn a_fillet_that_does_not_fit_is_not_built() {
    let mut p = block(rect());
    // 6 mm is more than the 5 mm height; both ends of a 3 mm one need 6 mm.
    p.add_feature(finish(K::Fillet, 6.0, 0.0, 0.0)).unwrap();
    assert_eq!(p.rebuild(32).unwrap().invalid_features, vec![3]);
    let mut p = block(rect());
    p.add_feature(finish(K::Fillet, 3.0, 0.0, 15.0)).unwrap();
    assert_eq!(p.edge_finish_of(2), None);
    // Nothing of the 10 mm side would be left.
    let mut p = block(rect());
    p.add_feature(finish(K::Fillet, 5.0, 0.0, 0.0)).unwrap();
    assert_eq!(p.edge_finish_of(2), None);
    // A suppressed one does nothing, and the second one counts.
    let mut p = block(rect());
    p.add_feature(Feature {
        suppressed: 1,
        ..finish(K::Fillet, 1.0, 0.0, 0.0)
    })
    .unwrap();
    p.add_feature(finish(K::Chamfer, 1.0, 0.0, 0.0)).unwrap();
    assert_eq!(p.edge_finish_of(2), Some(4));
    // An extrude gets one of them, not both.
    p.add_feature(finish(K::Fillet, 1.0, 0.0, 0.0)).unwrap();
    let invalid = p.rebuild(32).unwrap().invalid_features;
    assert!(invalid.contains(&5), "{invalid:?}");
}
#[test]
fn holes_have_to_miss_the_fillet() {
    let hole = |x: f64| Feature {
        kind: K::Hole,
        reference: 2,
        x,
        y: 5.0,
        p1: 2.0,
        ..Feature::default()
    };
    let mut p = block(rect());
    p.add_feature(finish(K::Fillet, 2.0, 0.0, 0.0)).unwrap();
    // Centre 3 clears the 2 mm fillet by 1 mm (its edge is at 2); centre 2.5 does not.
    p.add_feature(hole(3.5)).unwrap();
    p.add_feature(hole(2.5)).unwrap();
    let r = p.rebuild(32).unwrap();
    assert_eq!(r.invalid_features, vec![5]);
    let m = p.mesh(MESH_SEGS).unwrap();
    assert_closed(&m);
    assert!(m.triangles().iter().any(|t| t.feature == 4));
    assert!(m.triangles().iter().all(|t| t.feature != 5));
}
#[test]
fn the_wireframe_draws_the_rings() {
    let mut p = block(rect());
    let plain = p.regenerate().unwrap().len();
    assert_eq!(plain, 4 + 12);
    p.add_feature(finish(K::Fillet, 1.0, 0.0, 0.0)).unwrap();
    let edges = p.regenerate().unwrap();
    assert!(edges.len() > plain + 12, "{}", edges.len());
    // No edge has no length.
    assert!(edges.iter().all(|e| e.vertices[0] != e.vertices[1]));
    p.add_feature(finish(K::Chamfer, 1.0, 0.0, 0.0)).unwrap();
    assert_eq!(p.regenerate().unwrap().len(), edges.len());
}

#[test]
fn sc2_files_round_trip_and_pick_their_version() {
    let mut p = block(rect());
    let plain = p.to_sc2();
    assert_eq!(plain.len(), FILE_BYTES);
    assert_eq!(&plain[..4], b"SC2K");
    assert_eq!(i16::from_le_bytes([plain[4], plain[5]]), 6);
    p.add_feature(finish(K::Fillet, 1.0, 0.0, 0.0)).unwrap();
    // A fillet on every top edge is a SolidCraft 2000 1.0 part.
    assert_eq!(p.sc2_version(), 6);
    p.add_feature(finish(K::Chamfer, 1.0, 0.0, 0.0)).unwrap();
    assert_eq!(p.sc2_version(), 7);
    let bytes = p.to_sc2();
    assert_eq!(i16::from_le_bytes([bytes[4], bytes[5]]), 7);
    let loaded = Part::from_sc2(&bytes).unwrap();
    assert_eq!(loaded.conversion, Conversion::None);
    assert_eq!(loaded.part, p);
    assert_eq!(loaded.part.to_sc2(), bytes);
    // A fillet on chosen edges needs Service Pack 1.
    let mut q = block(rect());
    q.add_feature(finish(K::Fillet, 1.0, 3.0, 0.0)).unwrap();
    assert_eq!(q.sc2_version(), 7);
    // SolidCraft 98 does not know SC2K, and SolidCraft 2000 knows both.
    assert_eq!(Part::from_sc98(&bytes).unwrap_err(), Error::NotAPart);
    let old = block(rect()).to_sc98();
    assert_eq!(Part::from_sc2(&old).unwrap().part.to_sc98(), old);
    // A newer file asks for the Service Pack.
    let mut newer = bytes.clone();
    newer[4..6].copy_from_slice(&8i16.to_le_bytes());
    assert_eq!(Part::from_sc2(&newer).unwrap_err(), Error::TooNew);
    assert_eq!(
        Error::TooNew.to_string(),
        "Please upgrade to SolidCraft 2000 Service Pack 1."
    );
}
#[test]
fn filleted_plate_from_the_samples() {
    let bytes = fs::read(root().join("samples/Filleted Plate.sc2")).unwrap();
    let loaded = Part::from_sc2(&bytes).unwrap();
    let p = loaded.part;
    assert_eq!(p.title, "Filleted Plate");
    assert_eq!(p.features().len(), 11);
    assert_eq!(p.feature(3).unwrap().kind, K::Fillet);
    assert_eq!(p.feature(10).unwrap().kind, K::Fillet);
    assert_eq!(p.feature_name(3), "Fillet1");
    assert_eq!(p.describe(3).unwrap(), "R 3 mm, top edges of Extrude1");
    // Saved back it is the file it was read from.
    assert_eq!(p.to_sc2(), bytes);
    let r = p.rebuild(MESH_SEGS).unwrap();
    assert!(r.invalid_features.is_empty(), "{:?}", r.invalid_features);
    assert!(r.mesh.warnings.is_empty());
    assert_closed(&r.mesh);
    // 80 x 50 x 6 plate and a 20 mm boss 15 high, less four holes and the boss's
    // bore (through the plate as well), less the fillets.
    let sharp = 80.0 * 50.0 * 6.0 + PI * 100.0 * 15.0;
    let holes = 4.0 * PI * 6.25 * 6.0 + PI * 25.0 * 21.0;
    let v = volume(&r.mesh);
    assert!(v < sharp - holes && v > sharp - holes - 1000.0, "{v}");
    // Both rounded.
    let tops = r
        .mesh
        .triangles()
        .iter()
        .filter(|t| t.vertices.iter().all(|v| v[2] == 21.0))
        .count();
    assert!(tops > 0);
}
