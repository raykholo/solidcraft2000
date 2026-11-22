use crate::{
    Colour, Dimension as D, Error, Feature, FeatureId, FeatureKind as K, Mesh, Part, Vec3,
};
use alloc::{vec, vec::Vec};
// The reference's decimal PI is deliberately shorter than the mathematical constant.
#[allow(clippy::approx_constant)]
pub(crate) const PI: D = 3.14159265358979;
pub const CIRCLE_SEGS: usize = 32;
pub const COL_SKETCH: Colour = 0xff0000c0;
pub const COL_SKETCH_USED: Colour = 0xff80a0c0;
pub const COL_SOLID: Colour = 0xff000000;
pub const COL_HOLE: Colour = 0xff800000;
pub const COL_AXIS: Colour = 0xff808080;
/// Quarter-circle steps in a fillet's wireframe.
pub const FILLET_STEPS: usize = 4;
/// Every side of an extrude: front (-Y) 1, right (+X) 2, back (+Y) 4, left (-X) 8.
pub const SIDES_ALL: u8 = 15;
pub(crate) type Point = [D; 2];
pub(crate) type Point3 = [D; 3];
#[derive(Clone, Debug, PartialEq)]
pub struct Edge {
    pub vertices: [Vec3; 2],
    pub colour: Colour,
}
#[derive(Clone, Debug)]
pub struct Rebuild {
    pub edges: Vec<Edge>,
    pub mesh: Mesh,
    pub invalid_features: Vec<FeatureId>,
}

pub(crate) fn profile(f: &Feature, segments: usize) -> (Vec<Point>, Vec<bool>) {
    profile_keep(f, segments, false)
}
/// `keep_count`: a sharp rectangle gets as many points as a rounded one (its
/// corners have radius 0), so every outline a fillet steps through lines up.
pub(crate) fn profile_keep(
    f: &Feature,
    segments: usize,
    keep_count: bool,
) -> (Vec<Point>, Vec<bool>) {
    let mut points = Vec::new();
    let mut seam = Vec::new();
    if f.kind == K::Rectangle {
        let r = f.p3.max(0.0);
        if r <= 0.0 && !keep_count {
            return (
                vec![
                    [f.x, f.y],
                    [f.x + f.p1, f.y],
                    [f.x + f.p1, f.y + f.p2],
                    [f.x, f.y + f.p2],
                ],
                vec![true; 4],
            );
        }
        let k = (segments / 4).max(2);
        for c in 0..4 {
            let (cx, cy) = match c {
                0 => (f.x + f.p1 - r, f.y + r),
                1 => (f.x + f.p1 - r, f.y + f.p2 - r),
                2 => (f.x + r, f.y + f.p2 - r),
                _ => (f.x + r, f.y + r),
            };
            for j in 0..=k {
                let a = (c as D * 90.0 - 90.0 + 90.0 * j as D / k as D) * PI / 180.0;
                points.push([cx + r * libm::cos(a), cy + r * libm::sin(a)]);
                seam.push(j == 0 || j == k);
            }
        }
    } else {
        for i in 0..segments {
            let a = 2.0 * PI * i as D / segments as D;
            points.push([f.x + f.p1 * libm::cos(a), f.y + f.p1 * libm::sin(a)]);
            seam.push(i % 4 == 0);
        }
    }
    (points, seam)
}
pub fn profile_contains(s: &Feature, x: D, y: D, rr: D) -> bool {
    const EPS: D = 0.000001;
    if s.kind == K::Circle {
        return libm::sqrt((x - s.x) * (x - s.x) + (y - s.y) * (y - s.y)) + rr <= s.p1 + EPS;
    }
    if x - rr < s.x - EPS
        || x + rr > s.x + s.p1 + EPS
        || y - rr < s.y - EPS
        || y + rr > s.y + s.p2 + EPS
    {
        return false;
    }
    let r = s.p3;
    if r > 0.0 {
        let cx = x.max(s.x + r).min(s.x + s.p1 - r);
        let cy = y.max(s.y + r).min(s.y + s.p2 - r);
        if libm::sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) + rr > r + EPS
            && (x < s.x + r || x > s.x + s.p1 - r)
            && (y < s.y + r || y > s.y + s.p2 - r)
        {
            return false;
        }
    }
    true
}
impl Part {
    pub fn ref_ok(&self, id: FeatureId) -> bool {
        let Some(f) = self.feature(id) else {
            return false;
        };
        let parent = f
            .parent()
            .filter(|&r| r < id)
            .and_then(|r| self.feature(r).map(|p| (r, p)));
        match f.kind {
            K::Rectangle | K::Circle => {
                // Sketches on side faces (reserved[0] != 0) are not in the preview yet.
                f.reference == 0
                    || (f.reserved[0] == 0.0
                        && parent.is_some_and(|(r, p)| p.kind == K::Extrude && self.ref_ok(r)))
            }
            K::Extrude | K::Revolve => parent.is_some_and(|(_, p)| p.kind.is_sketch()),
            K::Foreign => true,
            K::Fillet | K::Chamfer => parent.is_some_and(|(r, p)| {
                p.kind == K::Extrude && self.ref_ok(r) && self.edge_finish_of(r) == Some(id)
            }),
            K::Hole => parent.is_some_and(|(r, p)| {
                if p.kind != K::Extrude || !self.ref_ok(r) {
                    return false;
                }
                let inside = |s: &Feature| profile_contains(s, f.x, f.y, f.p1 / 2.0);
                let Some(top) = self.top_face(r) else {
                    return false;
                };
                if !inside(&top) {
                    return false;
                }
                // One that comes out through a filleted bottom has to miss the fillet too.
                match (
                    self.edge_finish_of(r),
                    self.hole_span(id),
                    self.extrude_range(r),
                ) {
                    (Some(j), Some((_, zb)), Some((z0, _)))
                        if self.features()[j - 1].finish_bottom() != 0
                            && zb < z0 + self.features()[j - 1].p1 =>
                    {
                        self.bottom_face(r).is_some_and(|s| inside(&s))
                    }
                    _ => true,
                }
            }),
            _ => false,
        }
    }
    pub fn sketch_z(&self, id: FeatureId) -> Option<D> {
        let f = self.feature(id)?;
        let mut z = f.z;
        if let Some(r) = f.parent().filter(|&r| r < id) {
            if self.feature(r)?.kind == K::Extrude {
                z += self.extrude_range(r)?.1;
            }
        }
        Some(z)
    }
    pub fn extrude_range(&self, id: FeatureId) -> Option<(D, D)> {
        let f = self.feature(id)?;
        let r = f.parent().filter(|&r| r < id)?;
        let z = self.sketch_z(r)?;
        Some((z, z + f.p1))
    }
    pub fn hole_span(&self, id: FeatureId) -> Option<(D, D)> {
        let f = self.feature(id)?;
        let r = f.parent().filter(|&r| r < id)?;
        let (mut bottom, top) = self.extrude_range(r)?;
        if f.p2 > 0.0 {
            return Some((top, top - f.p2));
        }
        loop {
            let mut moved = false;
            for j in 1..id {
                let g = self.feature(j)?;
                if g.kind == K::Extrude && g.suppressed == 0 && j != r && self.ref_ok(j) {
                    let (b0, b1) = self.extrude_range(j)?;
                    if b0 < bottom - 0.000001
                        && b1 >= bottom - 0.000001
                        && b1 <= top + 0.000001
                        && g.parent()
                            .and_then(|r| self.feature(r))
                            .is_some_and(|s| profile_contains(s, f.x, f.y, f.p1 / 2.0))
                    {
                        bottom = b0;
                        moved = true;
                    }
                }
            }
            if !moved {
                break;
            }
        }
        Some((top, bottom))
    }
    pub fn regenerate(&self) -> Result<Vec<Edge>, Error> {
        let mut edges = Vec::new();
        let mut used = vec![false; self.count + 1];
        for f in self.features() {
            if matches!(f.kind, K::Extrude | K::Revolve) {
                if let Some(r) = f.parent().filter(|&r| r <= self.count) {
                    used[r] = true;
                }
            }
        }
        let add = |e: &mut Vec<Edge>, a: Point3, b: Point3, c| {
            e.push(Edge {
                vertices: [a.map(|v| v as _), b.map(|v| v as _)],
                colour: c,
            });
        };
        let circle = |e: &mut Vec<Edge>, x: D, y: D, z: D, r: D, c| {
            for i in 0..CIRCLE_SEGS {
                let a = 2.0 * PI * i as D / CIRCLE_SEGS as D;
                let b = 2.0 * PI * (i + 1) as D / CIRCLE_SEGS as D;
                add(
                    e,
                    [x + r * libm::cos(a), y + r * libm::sin(a), z],
                    [x + r * libm::cos(b), y + r * libm::sin(b), z],
                    c,
                );
            }
        };
        for (i, &is_used) in used.iter().enumerate().skip(1) {
            let f = &self.records[i - 1];
            if f.suppressed != 0 || !self.ref_ok(i) {
                continue;
            }
            let col = if is_used { COL_SKETCH_USED } else { COL_SKETCH };
            match f.kind {
                K::Rectangle => {
                    let z = self.sketch_z(i).ok_or(Error::InvalidFeature)?;
                    let (p, _) = profile(f, CIRCLE_SEGS);
                    for j in 0..p.len() {
                        let k = (j + 1) % p.len();
                        add(
                            &mut edges,
                            [p[j][0], p[j][1], z],
                            [p[k][0], p[k][1], z],
                            col,
                        );
                    }
                }
                K::Circle => circle(
                    &mut edges,
                    f.x,
                    f.y,
                    self.sketch_z(i).ok_or(Error::InvalidFeature)?,
                    f.p1,
                    col,
                ),
                K::Extrude => {
                    let (z0, z1) = self.extrude_range(i).ok_or(Error::InvalidFeature)?;
                    let s = self
                        .feature(f.parent().ok_or(Error::InvalidFeature)?)
                        .ok_or(Error::InvalidFeature)?;
                    if let Some(rings) = self
                        .edge_finish_of(i)
                        .and_then(|_| self.extrude_rings(i, FILLET_STEPS))
                    {
                        // The rings it goes through: a ring where a face starts or ends,
                        // and the quarter circles (or the chamfer's slopes) at each seam.
                        let (base, seam) = profile_keep(s, CIRCLE_SEGS, true);
                        let mut last: Vec<Point> = Vec::new();
                        for (m, ring) in rings.iter().enumerate() {
                            let (q, _) = profile_keep(&ring.outline, CIRCLE_SEGS, true);
                            let mut seg = |a: Point3, b: Point3| {
                                if a != b {
                                    add(&mut edges, a, b, COL_SOLID);
                                }
                            };
                            if ring.key {
                                for j in 0..q.len() {
                                    let k = (j + 1) % q.len();
                                    seg([q[j][0], q[j][1], ring.z], [q[k][0], q[k][1], ring.z]);
                                }
                            }
                            if m > 0 {
                                for j in 0..base.len() {
                                    // (a sharp corner's points are all in one place: one line)
                                    if seam[j] && !(j > 0 && base[j] == base[j - 1]) {
                                        seg(
                                            [last[j][0], last[j][1], rings[m - 1].z],
                                            [q[j][0], q[j][1], ring.z],
                                        );
                                    }
                                }
                            }
                            last = q;
                        }
                        continue;
                    }
                    let (p, seam) = profile(s, CIRCLE_SEGS);
                    for j in 0..p.len() {
                        let k = (j + 1) % p.len();
                        add(
                            &mut edges,
                            [p[j][0], p[j][1], z0],
                            [p[k][0], p[k][1], z0],
                            COL_SOLID,
                        );
                        add(
                            &mut edges,
                            [p[j][0], p[j][1], z1],
                            [p[k][0], p[k][1], z1],
                            COL_SOLID,
                        );
                        if seam[j] {
                            add(
                                &mut edges,
                                [p[j][0], p[j][1], z0],
                                [p[j][0], p[j][1], z1],
                                COL_SOLID,
                            );
                        }
                    }
                }
                K::Revolve => {
                    if f.p1.abs() > 360.0 {
                        return Err(Error::MeshTooLarge);
                    }
                    let sk = f.parent().ok_or(Error::InvalidFeature)?;
                    let s = self.feature(sk).ok_or(Error::InvalidFeature)?;
                    let z = self.sketch_z(sk).ok_or(Error::InvalidFeature)?;
                    let (p, seam) = profile(s, CIRCLE_SEGS);
                    let steps = (libm::floor(f.p1.abs() / 15.0 + 0.5) as usize).max(1);
                    let spin =
                        |p: Point, a: D| [p[0] * libm::cos(a), p[1], z - p[0] * libm::sin(a)];
                    for k in 0..=steps {
                        let a = f.p1 * PI / 180.0 * k as D / steps as D;
                        if k == 0 || k == steps || k % 3 == 0 {
                            for j in 0..p.len() {
                                add(
                                    &mut edges,
                                    spin(p[j], a),
                                    spin(p[(j + 1) % p.len()], a),
                                    COL_SOLID,
                                );
                            }
                        }
                        if k < steps {
                            let b = f.p1 * PI / 180.0 * (k + 1) as D / steps as D;
                            for j in 0..p.len() {
                                if seam[j] && (p.len() <= 4 || s.kind == K::Rectangle || j % 8 == 0)
                                {
                                    add(&mut edges, spin(p[j], a), spin(p[j], b), COL_SOLID);
                                }
                            }
                        }
                    }
                    add(
                        &mut edges,
                        [0.0, -10.0, z],
                        [
                            0.0,
                            10.0 + p.iter().map(|p| p[1].abs()).fold(0.0, D::max),
                            z,
                        ],
                        COL_AXIS,
                    );
                }
                K::Hole => {
                    let (top, bot) = self.hole_span(i).ok_or(Error::InvalidFeature)?;
                    let r = f.p1 / 2.0;
                    circle(&mut edges, f.x, f.y, top, r, COL_HOLE);
                    circle(&mut edges, f.x, f.y, bot, r, COL_HOLE);
                    for j in 0..4 {
                        let a = j as D * PI / 2.0;
                        add(
                            &mut edges,
                            [f.x + r * libm::cos(a), f.y + r * libm::sin(a), top],
                            [f.x + r * libm::cos(a), f.y + r * libm::sin(a), bot],
                            COL_HOLE,
                        );
                    }
                }
                _ => {}
            }
        }
        if edges
            .iter()
            .flat_map(|e| e.vertices.iter().flatten())
            .any(|n| !n.is_finite())
        {
            return Err(Error::InvalidNumber);
        }
        Ok(edges)
    }
    pub fn rebuild(&self, segments: usize) -> Result<Rebuild, Error> {
        Ok(Rebuild {
            edges: self.regenerate()?,
            mesh: self.mesh(segments)?,
            invalid_features: (1..=self.count).filter(|&i| !self.ref_ok(i)).collect(),
        })
    }
}

/// Where an edge finish is, `t` of the way along it (0 to 1): how far in and
/// how far up from where it starts. `r` is its radius or distance.
pub fn edge_at(chamfer: bool, r: D, t: D) -> (D, D) {
    if chamfer {
        (r * t, r * t)
    } else {
        (
            r * (1.0 - libm::cos(t * PI / 2.0)),
            r * libm::sin(t * PI / 2.0),
        )
    }
}
const EPS: D = 0.000001;
/// The sketch moved in by `off` on every side.
fn inset_sketch(s: &Feature, off: D) -> Feature {
    let mut t = s.clone();
    if s.kind == K::Rectangle {
        t.x = s.x + off;
        t.y = s.y + off;
        t.p1 = s.p1 - 2.0 * off;
        t.p2 = s.p2 - 2.0 * off;
        t.p3 = (s.p3 - off).max(0.0);
    } else {
        t.p1 = s.p1 - off;
    }
    t
}
/// The sketch moved in by `off` on the sides in `mask`. Moving in only some
/// sides of a sharp rectangle leaves a rectangle, so every cross-section is exact.
fn side_inset(s: &Feature, mask: u8, off: D) -> Feature {
    if mask == 0 || off == 0.0 {
        return s.clone();
    }
    if mask == SIDES_ALL || s.kind != K::Rectangle || s.p3 > 0.0 {
        return inset_sketch(s, off);
    }
    let mut t = s.clone();
    if mask & 1 != 0 {
        t.y += off;
        t.p2 -= off;
    }
    if mask & 2 != 0 {
        t.p1 -= off;
    }
    if mask & 4 != 0 {
        t.p2 -= off;
    }
    if mask & 8 != 0 {
        t.x += off;
        t.p1 -= off;
    }
    t
}
/// A circle or a rounded rectangle takes all its sides or none.
fn sides_ok(s: &Feature, mask: u8) -> bool {
    mask <= SIDES_ALL && ((s.kind == K::Rectangle && s.p3 <= 0.0) || mask == 0 || mask == SIDES_ALL)
}
/// Is `r` small enough for these sides? Something of the face has to stay.
fn sides_fit(s: &Feature, mask: u8, r: D) -> bool {
    if mask == 0 {
        return true;
    }
    if s.kind == K::Circle {
        return s.p1 > r + EPS;
    }
    let n = |a: u8, b: u8| u8::from(mask & a != 0) + u8::from(mask & b != 0);
    let (mut nx, mut ny) = (n(2, 8), n(1, 4));
    if s.p3 > 0.0 {
        (nx, ny) = (2, 2);
    }
    s.p1 > D::from(nx) * r + EPS && s.p2 > D::from(ny) * r + EPS
}
/// One cross-section of an extrude's walls.
#[derive(Clone, Debug)]
pub(crate) struct Ring {
    pub z: D,
    pub outline: Feature,
    /// The wireframe draws a ring here.
    pub key: bool,
}
impl Feature {
    /// The top sides a fillet or chamfer takes (it stores the ones it leaves sharp).
    pub fn finish_top(&self) -> u8 {
        SIDES_ALL - ((libm::round(self.reserved[0]) as i64 & i64::from(SIDES_ALL)) as u8)
    }
    /// The bottom sides a fillet or chamfer takes.
    pub fn finish_bottom(&self) -> u8 {
        (libm::round(self.reserved[1]) as i64 & i64::from(SIDES_ALL)) as u8
    }
}
impl Part {
    /// Does edge finish `j` fit its extrude? Its size must leave some of each face
    /// it takes, and fit in the extrude's height (twice, if it takes both ends).
    pub fn edge_finish_fits(&self, j: FeatureId) -> bool {
        let Some(f) = self.feature(j).filter(|f| f.kind.is_edge_finish()) else {
            return false;
        };
        let Some(e) = f
            .parent()
            .filter(|&b| b < j)
            .and_then(|b| self.feature(b))
            .filter(|e| e.kind == K::Extrude)
        else {
            return false;
        };
        let Some(s) = e
            .parent()
            .and_then(|r| self.feature(r))
            .filter(|s| s.kind.is_sketch())
        else {
            return false;
        };
        let (mt, mb) = (f.finish_top(), f.finish_bottom());
        if (mt == 0 && mb == 0) || !sides_ok(s, mt) || !sides_ok(s, mb) {
            return false;
        }
        let n = u8::from(mt != 0) + u8::from(mb != 0);
        f.p1 > 0.0
            && D::from(n) * f.p1 <= e.p1.abs() + EPS
            && sides_fit(s, mt, f.p1)
            && sides_fit(s, mb, f.p1)
    }
    /// The fillet or chamfer on extrude `b`. Only the first one that fits counts.
    pub fn edge_finish_of(&self, b: FeatureId) -> Option<FeatureId> {
        (b + 1..=self.count).find(|&j| {
            let f = &self.records[j - 1];
            f.kind.is_edge_finish()
                && f.parent() == Some(b)
                && f.suppressed == 0
                && self.edge_finish_fits(j)
        })
    }
    /// The flat part of extrude `b`'s top face, as a sketch: its own sketch moved in
    /// by its fillet. Holes and anything standing on it have to fit in here.
    pub fn top_face(&self, b: FeatureId) -> Option<Feature> {
        let s = self.feature(self.feature(b)?.parent()?)?;
        Some(match self.edge_finish_of(b) {
            Some(j) => {
                let f = &self.records[j - 1];
                side_inset(s, f.finish_top(), f.p1)
            }
            None => s.clone(),
        })
    }
    /// The flat part of its bottom face, the same way.
    pub fn bottom_face(&self, b: FeatureId) -> Option<Feature> {
        let s = self.feature(self.feature(b)?.parent()?)?;
        Some(match self.edge_finish_of(b) {
            Some(j) => {
                let f = &self.records[j - 1];
                side_inset(s, f.finish_bottom(), f.p1)
            }
            None => s.clone(),
        })
    }
    /// The cross-sections extrude `b`'s walls go through, bottom to top: up the
    /// bottom fillet, the straight part, up the top fillet. Every outline gives
    /// `profile_keep` the same number of points. A chamfer is one band.
    pub(crate) fn extrude_rings(&self, b: FeatureId, steps: usize) -> Option<Vec<Ring>> {
        let s = self.feature(self.feature(b)?.parent()?)?;
        let (z0, z1) = self.extrude_range(b)?;
        let (z0, z1) = (z0.min(z1), z0.max(z1));
        let (mut r, mut mt, mut mb, mut chamfer) = (0.0, 0, 0, false);
        if let Some(j) = self.edge_finish_of(b) {
            let f = &self.records[j - 1];
            (r, mt, mb, chamfer) = (
                f.p1,
                f.finish_top(),
                f.finish_bottom(),
                f.kind == K::Chamfer,
            );
        }
        let st = if chamfer { 1 } else { steps.max(1) };
        let ring = |z, outline, key| Ring { z, outline, key };
        let mut out = Vec::with_capacity(2 * st + 3);
        if mb != 0 {
            for m in (1..=st).rev() {
                let (inset, rise) = if m == st {
                    (r, r)
                } else {
                    edge_at(chamfer, r, m as D / st as D)
                };
                out.push(ring(z0 + r - rise, side_inset(s, mb, inset), m == st));
            }
            out.push(ring(z0 + r, s.clone(), true));
        } else {
            out.push(ring(z0, s.clone(), true));
        }
        if mt != 0 {
            out.push(ring(z1 - r, s.clone(), true));
            for m in 1..=st {
                let (inset, rise) = if m == st {
                    (r, r)
                } else {
                    edge_at(chamfer, r, m as D / st as D)
                };
                out.push(ring(z1 - r + rise, side_inset(s, mt, inset), m == st));
            }
        } else {
            out.push(ring(z1, s.clone(), true));
        }
        Some(out)
    }
}
