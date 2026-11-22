//! Explicit little-endian encoding; never Rust structure layout.
use crate::{
    model::{Feature, FeatureKind, Part, MAX_FEATURES},
    Error,
};
use alloc::{string::String, vec::Vec};

/// The newest SolidCraft 98 part: `.sc98`, magic `SC98`.
pub const FILE_VERSION: i16 = 5;
/// The newest SolidCraft 2000 part: `.sc2`, magic `SC2K`. Version 7 is Service Pack 1;
/// a part that uses nothing from it is still saved as 6.
pub const SC2_FILE_VERSION: i16 = 7;
const SC2_FILE_VERSION_1_0: i16 = 6;
pub const HEADER_BYTES: usize = 72;
pub const RECORD_BYTES: usize = 134;
pub const FILE_BYTES: usize = HEADER_BYTES + MAX_FEATURES * RECORD_BYTES;
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Conversion {
    None,
    Version3,
    Version4,
}
#[derive(Clone, Debug, PartialEq)]
pub struct LoadedPart {
    pub part: Part,
    pub conversion: Conversion,
}

pub(crate) struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
}
impl<'a> Reader<'a> {
    pub(crate) fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, at: 0 }
    }
    pub(crate) fn take(&mut self, n: usize) -> Result<&'a [u8], Error> {
        let end = self.at.checked_add(n).ok_or(Error::Truncated)?;
        let b = self.bytes.get(self.at..end).ok_or(Error::Truncated)?;
        self.at = end;
        Ok(b)
    }
    pub(crate) fn short(&mut self) -> Result<i16, Error> {
        let b = self.take(2)?;
        Ok(i16::from_le_bytes([b[0], b[1]]))
    }
    pub(crate) fn double(&mut self) -> Result<f64, Error> {
        let mut b = [0; 8];
        b.copy_from_slice(self.take(8)?);
        Ok(f64::from_le_bytes(b))
    }
    fn text(&mut self, n: usize) -> Result<String, Error> {
        let b = self.take(n)?;
        let end = b
            .iter()
            .rposition(|&c| c != 0 && c != b' ')
            .map_or(0, |n| n + 1);
        Ok(b[..end].iter().map(|&b| char::from(b)).collect())
    }
}
fn text(out: &mut Vec<u8>, s: &str, n: usize, empty: u8) {
    let start = out.len();
    out.extend(
        s.chars()
            .take(n)
            .map(|c| u8::try_from(c as u32).unwrap_or(b'?')),
    );
    out.resize(start + n, if s.is_empty() { empty } else { b' ' });
}
impl Part {
    /// Load a SolidCraft 98 part, versions 3–5; trailing Turbo preview bytes are
    /// ignored, as in FreeBASIC.
    pub fn from_sc98(bytes: &[u8]) -> Result<LoadedPart, Error> {
        Self::load(bytes, false)
    }
    /// Load a SolidCraft 2000 part (`SC2K`, versions 3–7) or, as SolidCraft 2000
    /// itself does, a SolidCraft 98 part.
    pub fn from_sc2(bytes: &[u8]) -> Result<LoadedPart, Error> {
        Self::load(bytes, true)
    }
    fn load(bytes: &[u8], allow_sc2: bool) -> Result<LoadedPart, Error> {
        let mut r = Reader::new(bytes);
        let magic = r.take(4)?;
        let is_98 = magic == b"SC98";
        if !is_98 && !(allow_sc2 && magic == b"SC2K") {
            return Err(Error::NotAPart);
        }
        let version = r.short()?;
        if version
            > if is_98 {
                FILE_VERSION
            } else {
                SC2_FILE_VERSION
            }
        {
            return Err(Error::TooNew);
        }
        if version < 3 {
            return Err(Error::TooOld);
        }
        let mut part = Part::new(r.text(64)?);
        let count = r.short()?;
        part.count = if (0..=64).contains(&count) {
            count as usize
        } else {
            0
        };
        for i in 0..MAX_FEATURES {
            let mut f = Feature {
                kind: FeatureKind::from_code(r.short()?),
                name: r.text(24)?,
                x: r.double()?,
                y: r.double()?,
                z: r.double()?,
                p1: r.double()?,
                p2: r.double()?,
                reference: r.short()?,
                suppressed: r.short()?,
                ..Feature::default()
            };
            if version >= 4 {
                f.p3 = r.double()?;
            }
            if version >= 5 {
                f.info = r.text(32)?;
            }
            if version >= 4 {
                for n in &mut f.reserved {
                    *n = r.double()?;
                }
            }
            if !f.finite() {
                return Err(Error::InvalidNumber);
            }
            if i >= part.count {
                f.kind = FeatureKind::None;
            }
            part.records[i] = f;
        }
        Ok(LoadedPart {
            part,
            conversion: match version {
                3 => Conversion::Version3,
                4 => Conversion::Version4,
                _ => Conversion::None,
            },
        })
    }
    /// Save a SolidCraft 98 part in version 5, including all 64 records.
    pub fn to_sc98(&self) -> Vec<u8> {
        self.save(b"SC98", FILE_VERSION)
    }
    /// The oldest SolidCraft 2000 version that can hold this part, so a part with
    /// nothing from Service Pack 1 still opens in SolidCraft 2000 1.0.
    pub fn sc2_version(&self) -> i16 {
        let sp1 = self.features().iter().any(|f| match f.kind {
            FeatureKind::Chamfer => true,
            FeatureKind::Hole => f.p3 >= 2.0,
            FeatureKind::Fillet => f.reserved[0] != 0.0 || f.reserved[1] != 0.0,
            k if k.is_sketch() => f.reserved[0] != 0.0,
            _ => false,
        });
        if sp1 {
            SC2_FILE_VERSION
        } else {
            SC2_FILE_VERSION_1_0
        }
    }
    /// Save a SolidCraft 2000 part: `SC2K`, version 6 or 7, all 64 records.
    pub fn to_sc2(&self) -> Vec<u8> {
        self.save(b"SC2K", self.sc2_version())
    }
    fn save(&self, magic: &[u8; 4], version: i16) -> Vec<u8> {
        let mut out = Vec::with_capacity(FILE_BYTES);
        // Visual Basic's fixed-length strings are space-padded even when empty;
        // the FreeBASIC edition's SolidCraft 98 parts NUL-fill an empty one.
        let empty = if magic == b"SC2K" { b' ' } else { 0 };
        out.extend(magic);
        out.extend(version.to_le_bytes());
        text(&mut out, &self.title, 64, empty);
        out.extend((self.count as i16).to_le_bytes());
        for f in &self.records {
            out.extend(f.kind.code().to_le_bytes());
            text(&mut out, &f.name, 24, empty);
            for n in [f.x, f.y, f.z, f.p1, f.p2] {
                out.extend(n.to_le_bytes());
            }
            out.extend(f.reference.to_le_bytes());
            out.extend(f.suppressed.to_le_bytes());
            out.extend(f.p3.to_le_bytes());
            text(&mut out, &f.info, 32, empty);
            // SolidCraft 98 zeroes them on every save; SolidCraft 2000 keeps them.
            for n in f.reserved {
                out.extend(if magic == b"SC2K" { n } else { 0.0 }.to_le_bytes());
            }
        }
        out
    }
}
