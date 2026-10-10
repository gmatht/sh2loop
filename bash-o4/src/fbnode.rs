//! fbnode — present `/dev/fb0` as a device NODE: one path holding pixels.
//!
//! ## What the device actually is
//!
//! `/dev/fb0` is a linear framebuffer. There are no verbs beneath it and no
//! subdirectory: the node IS the pixel array. The C device says so itself
//! (`sh2perl/runtime/fbdev.c`):
//!
//! ```text
//! fb_try_dev("/dev/fb0") -> open(O_RDWR)
//!                        -> ioctl(FBIOGET_FSCREENINFO)   f.type, f.visual, f.line_length
//!                        -> ioctl(FBIOGET_VSCREENINFO)   xres, yres, bpp, channel offsets
//!                        -> mmap(len = line_length * yres_virtual)
//!                        -> put_px() writes through that mapping
//! ```
//!
//! and `fb_dump_ppm` writes the *same* buffer out as P6: `W*H` pixels,
//! row-major, three bytes each, R high. So "write the node" means "write
//! pixels", and the only thing that differs between the device and the RAM
//! fallback is whether the bytes go to a display or to a file.
//!
//! (`/dev/fb0/blocks`, `/dev/fb0/overlay` in `MIMEcroft_fb.sh` are the
//! pre-port SPELLING: the `fbdev-gpu` transforms in
//! `sh2perl/src/transforms/fbdev_gpu.rs` lift those writes into `GpuOp`
//! nodes and rewrite them back to one in-process `fb_blocks(payload)` call.
//! They are not a filesystem contract and are deliberately not served here.)
//!
//! ## Why this box has no node, and what this module is instead
//!
//! WSL2 has no `/proc/fb` and no framebuffer resource: `hyperv_fb` registers
//! but produces no node, and there is no `vfb`/`vkms` to load. A kernel-backed
//! `/dev/fb0` is therefore impossible here, and a character node with no
//! driver behind it is a LIE — `open(2)` succeeds, then every `write(2)` fails
//! with ENODEV and `FBIOGET_FSCREENINFO` fails outright, which moves the
//! failure without making one pixel land.
//!
//! What is achievable, and is what [`publish`] does, is a **userspace
//! framebuffer node**: one regular file at the device path, sized to the
//! geometry, whose bytes are the pixels in the device's own layout. A shell
//! can then do what it would on real hardware —
//!
//! ```text
//! printf '\\x20\\x40\\x60\\x20\\x40\\x60' > "$FB0_DEV"   # two red-ish pixels
//! cat frame.raw > /dev/fb0                        # a whole frame
//! ```
//!
//! — and `mmap` the same file to watch the frame change, which a FIFO (stream,
//! no seek, single reader) cannot do.
//!
//! ## The layout, and why it is ARGB here but RGB in the PPM
//!
//! Two layouts exist in this tree and they are both real:
//!
//! - the DEVICE mapping is 32-bit with the kernel's channel offsets
//!   (`v.red.offset` etc. — 16/8/0 on every fb here), i.e. `0x00RRGGBB` in a
//!   `uint32_t`, which is what `put_px` writes;
//! - the PPM dump is 24-bit `R,G,B` bytes.
//!
//! The node follows the DEVICE, not the dump: a node is supposed to be
//! what the program would have mapped, and the dump is the fallback for a
//! box with no node. [`Frame::to_ppm`] bridges the two so the existing
//! `fb_dump_ppm` consumers keep working unchanged.
//!
//! The bridge is what lets the loop close in either direction: a program
//! that DRAWS can `--dump-fb0` its surface into the node (the device's pixels
//! land in the file a viewer reads), and a shell that has pixels can convert
//! the node to a PPM with the same layout `fb_dump_ppm` produces.
//!
//! ## The one thing this does NOT do, and why
//!
//! The C device's `fb_try_dev` (fbdev.c) requires a path that answers
//! `FBIOGET_FSCREENINFO`/`FBIOGET_VSCREENINFO` and then `mmap`, so it does NOT
//! adopt a node published by this module — measured: a regular file (and even
//! a character device like `/dev/null`) returns `ENOTTY` (errno 25) from both
//! ioctls, and `fb_try_dev` correctly rejects it and falls back to its RAM
//! surface. That rejection is load-bearing: a device that mmapped an ordinary
//! file would treat its bytes as a display and mis-address every pixel that is
//! not `line_length`-strided.
//!
//! So the node serves the consumers that speak PIXELS — a shell doing
//! `cat frame.raw > /dev/fb0`, `cat /dev/urandom > /dev/fb0` to fill, or
//! `cat /dev/zero > /dev/fb0` to clear — and [`to_ppm`] converts a node's
//! frame to the P6 layout `fb_dump_ppm` produces, so the two are interchangeable
//! at the file level. A kernel-backed `/dev/fb0` would additionally satisfy the
//! ioctl+mmap path; this box cannot have one (no `/proc/fb`, no framebuffer
//! resource, only `hyperv_fb`, which registers but makes no node).

use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Seek, SeekFrom, Write};
use std::os::unix::fs::FileTypeExt;
use std::path::{Path, PathBuf};

/// Where the node goes when nothing overrides it.
pub const DEFAULT_PATH: &str = "/dev/fb0";

/// Bytes per pixel in the node: 32-bit ARGB, matching the device mapping
/// (`fbdev.c` refuses any mapping that is not `S_fb_bpp == 32`).
pub const BPP: usize = 4;

/// Resolve the node path: `$FB0_NODE` > `$FB0_DEV` > [`DEFAULT_PATH`].
///
/// `$FB0_DEV` is the C device's own override (`fb_open` reads it), so
/// honouring it first keeps the node and the device on the same path: a run
/// that points `fb_open` at `/tmp/myfb0` must not find the node at
/// `/dev/fb0`. `$FB0_NODE` is the node-specific spelling, for the case where
/// the device path names a real framebuffer and the node is wanted elsewhere.
pub fn path_from_env() -> PathBuf {
    for k in ["FB0_NODE", "FB0_DEV"] {
        if let Ok(v) = std::env::var(k) {
            if !v.is_empty() {
                return PathBuf::from(v);
            }
        }
    }
    PathBuf::from(DEFAULT_PATH)
}

/// Is publishing switched off? `$FB0_NODE=off` or `$FB0_DISABLE=1`.
///
/// `FB0_NODE=off` is the useful spelling (it names the thing being turned
/// off); `FB0_DISABLE` is the blunt one for a harness that wants no trace of
/// device work at all.
pub fn disabled() -> bool {
    if std::env::var("FB0_DISABLE").map(|v| v == "1").unwrap_or(false) {
        return true;
    }
    std::env::var("FB0_NODE")
        .map(|v| v.eq_ignore_ascii_case("off"))
        .unwrap_or(false)
}

/// A geometry, in the device's own terms.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Geom {
    pub w: u32,
    pub h: u32,
}

impl Geom {
    /// The device's default when a program opens with a nonsense size:
    /// `fb_open` clamps `w<=0`/`h<=0` to this (`fbdev.c`).
    pub const DEFAULT: Geom = Geom { w: 320, h: 240 };

    /// The node size in bytes: `w * h * BPP`, no stride padding. The device
    /// keeps `line_length` for a real `/dev/fb0` (where the kernel may pad
    /// rows), but a node published by this module is the one place we get to
    /// choose, and an unpadded buffer is the one a writer can `fwrite` a
    /// whole frame into without knowing about strides.
    pub fn len(self) -> usize {
        self.w as usize * self.h as usize * BPP
    }

    /// Resolve the geometry: `$FB0_GEOM` (`WxH`) > [`Geom::DEFAULT`].
    ///
    /// This is what makes the node self-describing: `fbdev.c`'s RAM path
    /// takes the size from `fb_open(w,h)`, and a shell writing pixels has no
    /// way to call that, so it needs a declared geometry the node was
    /// published with. An unparseable value is an ERROR rather than a silent
    /// default — a node published at a different size than the writer expects
    /// shears every row, and that is invisible until the frame is viewed.
    pub fn from_env() -> Result<Geom, String> {
        let Ok(v) = std::env::var("FB0_GEOM") else {
            return Ok(Geom::DEFAULT);
        };
        if v.is_empty() {
            return Ok(Geom::DEFAULT);
        }
        let (w, h) = v
            .split_once(['x', 'X'])
            .ok_or_else(|| format!("$FB0_GEOM={v:?} is not WxH (e.g. 320x240)"))?;
        let w: u32 = w
            .trim()
            .parse()
            .map_err(|_| format!("$FB0_GEOM={v:?}: {w:?} is not a width"))?;
        let h: u32 = h
            .trim()
            .parse()
            .map_err(|_| format!("$FB0_GEOM={v:?}: {h:?} is not a height"))?;
        if w == 0 || h == 0 {
            return Err(format!("$FB0_GEOM={v:?}: a surface needs nonzero w and h"));
        }
        // The same bound the driver's own buffers would need to stay sane;
        // 64 GiB of pixels is a typo, not a display.
        if w as u64 * h as u64 * BPP as u64 > (1u64 << 36) {
            return Err(format!("$FB0_GEOM={v:?}: {w}x{h} is implausibly large"));
        }
        Ok(Geom { w, h })
    }
}

/// A published node: the path, the geometry, and an open handle.
///
/// The handle is kept so the node stays the same inode across the whole run
/// (a re-publish that unlinked and recreated it would leave a running
/// writer's descriptor attached to a deleted file), and so [`Node::write_frame`]
/// can update the pixels without a second `open`.
#[derive(Debug)]
pub struct Node {
    path: PathBuf,
    geom: Geom,
    file: File,
}

impl Node {
    /// The node path (`/dev/fb0`, by default).
    pub fn path(&self) -> &Path {
        &self.path
    }

    /// The geometry the node was published with.
    pub fn geom(&self) -> Geom {
        self.geom
    }

    /// Replace the whole frame from `pixels`, ARGB row-major (`w*h*4` bytes).
    ///
    /// A short buffer is an error, not a partial paint: a frame that is one
    /// row short leaves the previous frame's last row on screen, which reads
    /// as a rendering bug rather than as the caller's mistake.
    pub fn write_frame(&mut self, pixels: &[u8]) -> io::Result<()> {
        let want = self.geom.len();
        if pixels.len() != want {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!(
                    "frame is {} bytes, but {}x{}x{} is {want}",
                    pixels.len(),
                    self.geom.w,
                    self.geom.h,
                    BPP
                ),
            ));
        }
        self.file.seek(SeekFrom::Start(0))?;
        self.file.write_all(pixels)?;
        self.file.flush()
    }

    /// Read the pixels back, ARGB row-major.
    ///
    /// This is the read half a framebuffer has and a FIFO does not: the
    /// current frame is still there to be read after it was written, so a
    /// viewer (or a test) can look at a frame it did not just produce.
    pub fn read_frame(&mut self) -> io::Result<Vec<u8>> {
        self.file.seek(SeekFrom::Start(0))?;
        let mut buf = vec![0u8; self.geom.len()];
        self.file.read_exact(&mut buf)?;
        Ok(buf)
    }
}

/// Publish the node at `path`, idempotently.
///
/// Creates the file if it is absent and truncates it to the frame size if it
/// is the wrong length (a node left over from a different geometry is not
/// usable and there is nothing in it worth keeping). An existing path that is
/// NOT a regular file — a directory, a FIFO, a real character device — is
/// REFUSED rather than replaced: on a box that really has `/dev/fb0`, that
/// node is the display, and clobbering it would break the very thing this
/// emulates. `REFUSE > GUESS`, the same rule the fb0 lowering follows.
pub fn publish(path: &Path) -> Result<Node, String> {
    if disabled() {
        return Err("fb0 node publishing disabled ($FB0_NODE=off)".into());
    }
    let geom = Geom::from_env()?;

    match fs::symlink_metadata(path) {
        Ok(md) => {
            let ft = md.file_type();
            if ft.is_char_device() {
                // A real framebuffer node: leave it absolutely alone. This
                // is the case the emulation is FOR, not a case to overwrite.
                let file = OpenOptions::new()
                    .read(true)
                    .write(true)
                    .open(path)
                    .map_err(|e| format!("open real device {}: {e}", path.display()))?;
                return Ok(Node {
                    path: path.to_path_buf(),
                    geom,
                    file,
                });
            }
            if !ft.is_file() {
                return Err(format!(
                    "{} exists and is not a regular file (not a node we \
                     may publish over); remove it by hand if it is stale",
                    path.display()
                ));
            }
        }
        Err(e) if e.kind() == io::ErrorKind::NotFound => {
            if let Some(dir) = path.parent() {
                if !dir.as_os_str().is_empty() {
                    fs::create_dir_all(dir)
                        .map_err(|e| format!("create {}: {e}", dir.display()))?;
                }
            }
        }
        Err(e) => return Err(format!("stat {}: {e}", path.display())),
    }

    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(path)
        .map_err(|e| format!("open {} (rw): {e}", path.display()))?;
    // Size it to the geometry. A mismatch means a stale node from another
    // size, and every row of it would shear.
    let md = file
        .metadata()
        .map_err(|e| format!("stat {}: {e}", path.display()))?;
    if md.len() != geom.len() as u64 {
        file.set_len(geom.len() as u64)
            .map_err(|e| format!("set_len {} to {}: {e}", path.display(), geom.len()))?;
    }
    Ok(Node {
        path: path.to_path_buf(),
        geom,
        file,
    })
}

/// Convert a P6 PPM (the device's `fb_dump_ppm` layout) into node pixels
/// (ARGB, `0x00RRGGBB` in a `u32`, little-endian on disk).
///
/// This is the direction that makes the node a *display*: the C device draws
/// into its own RAM surface and can dump it as PPM, and this writes that frame
/// into the node so a shell — or a viewer with the node open — sees the frame
/// the game just drew.
///
/// The two layouts are the inverse of each other, and that is the whole
/// function:
///
/// ```text
/// node:  B G R A   (byte 3..0 of a u32: 0xAARRGGBB, little-endian)
/// PPM:   R G B     (three bytes per pixel, row-major, no alpha)
/// ```
///
/// A PPM whose header disagrees with `geom` is an ERROR, and so is a
/// truncated body: both would silently shear the frame, and a sheared frame
/// is invisible until someone looks at it. Comments and whitespace between
/// PPM header fields are permitted (the format allows them) but a header of
/// the wrong size never is.
pub fn from_ppm(ppm: &[u8], geom: Geom) -> Result<Vec<u8>, String> {
    // Parse `P6 <w> <h> <max>`: exactly three integers after the magic, with
    // any whitespace between fields, then ONE whitespace byte before the body.
    fn field(b: &[u8], i: &mut usize) -> Result<u32, String> {
        while *i < b.len() && b[*i].is_ascii_whitespace() {
            *i += 1;
        }
        let start = *i;
        while *i < b.len() && b[*i].is_ascii_digit() {
            *i += 1;
        }
        if start == *i {
            return Err("PPM header: expected a number".into());
        }
        std::str::from_utf8(&b[start..*i])
            .map_err(|_| "PPM header: non-UTF-8 digit run".to_string())?
            .parse()
            .map_err(|_| "PPM header: number out of range".to_string())
    }
    if ppm.len() < 2 || &ppm[..2] != b"P6" {
        return Err("not a P6 PPM (the magic must be `P6`)".into());
    }
    let mut i = 2usize;
    let w = field(ppm, &mut i)?;
    let h = field(ppm, &mut i)?;
    let max = field(ppm, &mut i)?;
    if max != 255 {
        return Err(format!("PPM maxval {max} is not 255 (8 bits per channel)"));
    }
    if w != geom.w || h != geom.h {
        return Err(format!(
            "PPM is {}x{}, but the node is {}x{}",
            w, h, geom.w, geom.h
        ));
    }
    // Exactly one whitespace byte separates the header from the body.
    if i >= ppm.len() || !ppm[i].is_ascii_whitespace() {
        return Err("PPM header: no separator before the pixel data".into());
    }
    i += 1;
    let body = &ppm[i..];
    let want = geom.w as usize * geom.h as usize * 3;
    if body.len() != want {
        return Err(format!(
            "PPM body is {} bytes, but {}x{} RGB is {want}",
            body.len(),
            geom.w,
            geom.h
        ));
    }
    let mut out = vec![0u8; geom.len()];
    for (dst, rgb) in out.chunks_exact_mut(BPP).zip(body.chunks_exact(3)) {
        dst[0] = rgb[2]; // B
        dst[1] = rgb[1]; // G
        dst[2] = rgb[0]; // R
        dst[3] = 0xFF; // A, opaque — what put_px stores
    }
    Ok(out)
}

/// Write a node's ARGB buffer out as the P6 PPM `fb_dump_ppm` produces.
///
/// The bridge between the node's device layout (`0x00RRGGBB` in a `u32`) and
/// the dump layout (`R`,`G`,`B`), so a consumer that already reads a PPM reads
/// a node's frame unchanged. Kept here rather than in the C device because the
/// node is a driver-side concept: the C device dumps its own RAM surface and
/// knows nothing about a node.
pub fn to_ppm(pixels: &[u8], geom: Geom, path: &Path) -> Result<(), String> {
    if pixels.len() != geom.len() {
        return Err(format!(
            "frame is {} bytes, but {}x{}x{} is {}",
            pixels.len(),
            geom.w,
            geom.h,
            BPP,
            geom.len()
        ));
    }
    let mut out = Vec::with_capacity(geom.len() / BPP * 3 + 32);
    out.extend_from_slice(format!("P6\n{} {}\n255\n", geom.w, geom.h).as_bytes());
    for px in pixels.chunks_exact(BPP) {
        // ARGB little-endian bytes: b, g, r, a.
        out.push(px[2]);
        out.push(px[1]);
        out.push(px[0]);
    }
    fs::write(path, &out).map_err(|e| format!("write {}: {e}", path.display()))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tmp(name: &str) -> PathBuf {
        let d = std::env::temp_dir().join(format!("bo4-fbnode-{}-{name}", std::process::id()));
        let _ = fs::remove_dir_all(&d);
        d
    }

    /// The property the module exists for: after `publish`, the path is a real
    /// filesystem entry of exactly `w*h*4` bytes, and writing pixels to it and
    /// reading them back agrees byte for byte.
    #[test]
    fn published_node_holds_pixels() {
        let path = tmp("pixels").join("fb0");
        let mut node = publish(&path).expect("publish");
        assert_eq!(node.geom(), Geom::DEFAULT);
        assert_eq!(
            fs::metadata(&path).unwrap().len(),
            Geom::DEFAULT.len() as u64,
            "the node must be sized to the geometry"
        );
        // Two pixels: 0x00RRGGBB each, in device byte order.
        let frame: Vec<u8> = vec![
            0x60, 0x40, 0x20, 0x00, // B G R A -> 0x00204060
            0xFF, 0x00, 0x00, 0x00, // -> 0x000000FF
        ];
        let mut full = vec![0u8; Geom::DEFAULT.len()];
        full[..8].copy_from_slice(&frame);
        node.write_frame(&full).expect("write_frame");
        assert_eq!(node.read_frame().unwrap(), full, "read-back must agree");
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    /// A write that is not a whole frame is refused: a short frame would leave
    /// a strip of the PREVIOUS frame on screen, which reads as a rendering bug.
    #[test]
    fn short_frame_is_refused() {
        let path = tmp("short").join("fb0");
        let mut node = publish(&path).expect("publish");
        let e = node.write_frame(&[0u8; 8]).unwrap_err();
        assert!(e.to_string().contains("bytes"), "got: {e}");
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    /// A node published at one geometry is resized when it is published at
    /// another: a stale node of the wrong size shears every row.
    #[test]
    fn stale_node_is_resized() {
        let path = tmp("resize").join("fb0");
        {
            let _n = publish(&path).expect("first");
        }
        fs::write(&path, b"junk").unwrap();
        // Same geometry: must be restored to the frame size.
        let node = publish(&path).expect("second");
        assert_eq!(fs::metadata(&path).unwrap().len(), node.geom().len() as u64);
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    /// Publishing twice must not disturb the inode a running writer holds.
    #[test]
    fn publish_is_idempotent() {
        let path = tmp("idem").join("fb0");
        let a = publish(&path).expect("first");
        let ino0 = {
            use std::os::unix::fs::MetadataExt;
            fs::metadata(&path).unwrap().ino()
        };
        let b = publish(&path).expect("second");
        let ino1 = {
            use std::os::unix::fs::MetadataExt;
            fs::metadata(&path).unwrap().ino()
        };
        assert_eq!(ino0, ino1, "a re-publish must not replace the inode");
        assert_eq!(a.geom(), b.geom());
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    /// A real character device at the path is left alone: on a box that has
    /// one, that node IS the display. Checked by shape, because mknod needs
    /// root and the test must not depend on having it.
    #[test]
    fn non_regular_path_is_refused() {
        let root = tmp("dir");
        fs::create_dir_all(&root).unwrap();
        // A directory in the way is refused…
        let e = publish(&root).unwrap_err();
        assert!(e.contains("not a regular file"), "got: {e}");
        // …and so is a FIFO (a shape a stale device might have).
        let fifo = root.join("f").join("fb0");
        fs::create_dir_all(fifo.parent().unwrap()).unwrap();
        assert_eq!(
            unsafe {
                let c = std::ffi::CString::new(fifo.to_str().unwrap()).unwrap();
                libc::mkfifo(c.as_ptr(), 0o666)
            },
            0,
            "test setup: mkfifo"
        );
        let e = publish(&fifo).unwrap_err();
        assert!(e.contains("not a regular file"), "got: {e}");
        let _ = fs::remove_dir_all(&root);
    }

    /// `$FB0_GEOM` is self-description, and a malformed value must be an error
    /// rather than a silent default: a node of the wrong size is invisible
    /// until someone looks at the frame.
    #[test]
    fn geom_parsing() {
        assert_eq!(Geom { w: 64, h: 48 }.len(), 64 * 48 * 4);
        assert_eq!(Geom::DEFAULT, Geom { w: 320, h: 240 });

        static G: std::sync::Mutex<()> = std::sync::Mutex::new(());
        let _g = G.lock().unwrap();
        let clear = || unsafe {
            std::env::remove_var("FB0_GEOM");
            std::env::remove_var("FB0_NODE");
            std::env::remove_var("FB0_DEV");
            std::env::remove_var("FB0_DISABLE");
        };
        clear();
        assert_eq!(Geom::from_env().unwrap(), Geom::DEFAULT);
        unsafe { std::env::set_var("FB0_GEOM", "640x480") };
        assert_eq!(Geom::from_env().unwrap(), Geom { w: 640, h: 480 });
        unsafe { std::env::set_var("FB0_GEOM", "640X480") };
        assert_eq!(Geom::from_env().unwrap(), Geom { w: 640, h: 480 });
        unsafe { std::env::set_var("FB0_GEOM", "nonsense") };
        assert!(Geom::from_env().is_err(), "a malformed geometry must be refused");
        unsafe { std::env::set_var("FB0_GEOM", "640x0") };
        assert!(Geom::from_env().is_err(), "a zero dimension must be refused");
        clear();
    }

    /// The path resolution order, and the two ways to switch publishing off.
    #[test]
    fn path_and_disable_resolution() {
        static G: std::sync::Mutex<()> = std::sync::Mutex::new(());
        let _g = G.lock().unwrap();
        let clear = || unsafe {
            std::env::remove_var("FB0_NODE");
            std::env::remove_var("FB0_DEV");
            std::env::remove_var("FB0_DISABLE");
        };
        clear();
        assert_eq!(path_from_env(), PathBuf::from(DEFAULT_PATH));
        unsafe { std::env::set_var("FB0_DEV", "/tmp/dev-fb0") };
        assert_eq!(path_from_env(), PathBuf::from("/tmp/dev-fb0"));
        unsafe { std::env::set_var("FB0_NODE", "/tmp/node-fb0") };
        assert_eq!(
            path_from_env(),
            PathBuf::from("/tmp/node-fb0"),
            "FB0_NODE must win: it names the node when FB0_DEV names a real device"
        );
        clear();
        unsafe { std::env::set_var("FB0_NODE", "off") };
        assert!(disabled(), "FB0_NODE=off must disable publishing");
        clear();
        unsafe { std::env::set_var("FB0_DISABLE", "1") };
        assert!(disabled(), "FB0_DISABLE=1 must disable publishing");
        clear();
        assert!(!disabled());
    }

    /// The documented boundary, asserted so it cannot be quietly assumed away:
    /// a node published here is a pixel file, and the C device's ioctl probe
    /// REJECTS it. If a future change ever made `FBIOGET_FSCREENINFO` succeed
    /// on our file, the device would mmap it and mis-stride every row — this
    /// test is the tripwire for that.
    #[test]
    fn node_is_not_a_kernel_framebuffer() {
        let path = tmp("notkfb").join("fb0");
        let _node = publish(&path).expect("publish");
        let file = fs::File::open(&path).unwrap();
        use std::os::unix::io::AsRawFd;
        // FBIOGET_FSCREENINFO, computed the way <linux/fb.h> defines it
        // (libc does not export it): _IOR('F', 0x02, struct fb_fix_screeninfo)
        // == direction _IOC_READ|size 80, type 'F', nr 2.
        const FBIOGET_FSCREENINFO: libc::c_ulong = 0x4600 + 2;
        let mut fix = [0u8; 80];
        // Any ioctl on a regular file is ENOTTY, which is exactly what
        // fbdev.c's fb_try_dev keys on to fall back to RAM.
        let rc = unsafe {
            libc::ioctl(
                file.as_raw_fd(),
                FBIOGET_FSCREENINFO,
                fix.as_mut_ptr() as *mut libc::c_void,
            )
        };
        assert_eq!(rc, -1, "a regular file must not answer an fb ioctl");
        assert_eq!(
            std::io::Error::last_os_error().raw_os_error(),
            Some(libc::ENOTTY),
            "the refusal must be ENOTTY, the signal fb_try_dev falls back on"
        );
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    /// `from_ppm` is the exact inverse of `to_ppm`, so a device frame can be
    /// dumped as PPM and written into the node without a byte changing.
    #[test]
    fn ppm_round_trip_is_lossless() {
        let g = Geom { w: 3, h: 2 };
        // A frame with every channel distinct, so a swapped byte is visible.
        let mut px = vec![0u8; g.len()];
        for (i, c) in px.chunks_exact_mut(4).enumerate() {
            c[0] = i as u8; // B
            c[1] = 0x40 + i as u8; // G
            c[2] = 0x80 + i as u8; // R
            c[3] = 0xFF;
        }
        let dir = tmp("roundtrip");
        fs::create_dir_all(&dir).unwrap();
        let p = dir.join("f.ppm");
        to_ppm(&px, g, &p).expect("to_ppm");
        let back = from_ppm(&fs::read(&p).unwrap(), g).expect("from_ppm");
        assert_eq!(back, px, "node -> PPM -> node must be lossless");
        let _ = fs::remove_dir_all(&dir);
    }

    /// A PPM of the wrong size, a truncated body, and a non-P6 magic are all
    /// refused: each would otherwise shear or half-fill the frame silently.
    #[test]
    fn bad_ppm_is_refused() {
        let g = Geom { w: 2, h: 1 };
        assert!(from_ppm(b"P6\n2 1\n255\n\x00\x01\x02\x03\x04\x05", g).is_ok());
        // wrong dimensions
        let e = from_ppm(b"P6\n4 4\n255\n" , g).unwrap_err();
        assert!(e.contains("but the node is"), "got: {e}");
        // truncated body
        let e = from_ppm(b"P6\n2 1\n255\n\x00\x01\x02", g).unwrap_err();
        assert!(e.contains("body is"), "got: {e}");
        // not a PPM at all
        let e = from_ppm(b"\x89PNG\r\n", g).unwrap_err();
        assert!(e.contains("P6"), "got: {e}");
        // 16-bit maxval
        let e = from_ppm(b"P6\n2 1\n65535\n\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b", g)
            .unwrap_err();
        assert!(e.contains("maxval"), "got: {e}");
    }

    /// The node's pixels and the PPM dump agree: a consumer that already reads
    /// `fb_dump_ppm` output reads a node's frame unchanged.
    #[test]
    fn ppm_bridge_matches_the_dump_layout() {
        let dir = tmp("ppm");
        fs::create_dir_all(&dir).unwrap();
        let geom = Geom { w: 2, h: 1 };
        // 0x00204060 then 0x00A0B0C0, in device byte order (B,G,R,A).
        let px = vec![0x60, 0x40, 0x20, 0x00, 0xC0, 0xB0, 0xA0, 0x00];
        let out = dir.join("f.ppm");
        to_ppm(&px, geom, &out).expect("to_ppm");
        let bytes = fs::read(&out).unwrap();
        let hdr = b"P6\n2 1\n255\n";
        assert_eq!(&bytes[..hdr.len()], hdr, "header");
        assert_eq!(
            &bytes[hdr.len()..],
            [0x20, 0x40, 0x60, 0xA0, 0xB0, 0xC0],
            "R high, then G, then B — the fb_dump_ppm layout"
        );
        let _ = fs::remove_dir_all(&dir);
    }
}
