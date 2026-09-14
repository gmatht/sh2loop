//! Minimal CUDA driver-API FFI (docs/BASH_VULKAN.md §9).
//!
//! `libcuda` is opened at RUNTIME (`dlopen` — never a build dependency,
//! so missing CUDA never breaks the build). Only the context / memory /
//! module / launch subset is bound. Used by the `cudabench` example (GPU
//! leg for bench-opt.sh) and any future PTX backend. Versioned `_v2`
//! symbols are loaded explicitly (unversioned `cuMemAlloc` resolves to a
//! dead stub on WSL — diagnosed by bisection, do not "simplify").
//! PTX must keep entry headers single-line and avoid user regs shadowing
//! specials (`%tid` vs `%tid.x`) — same bisection source.

use std::ffi::{c_char, c_int, c_void, CString};
use std::ptr;

const RTLD_NOW: c_int = 2;

extern "C" {
    fn dlopen(name: *const c_char, flags: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, sym: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> c_int;
}

type CUresult = i32;
type CUdevice = c_int;
type CUcontext = *mut c_void;
type CUmodule = *mut c_void;
type CUfunction = *mut c_void;
pub type CUdeviceptr = u64;
const CUDA_SUCCESS: CUresult = 0;

/// Candidate libcuda paths: env override, WSL passthrough, standard names.
fn lib_candidates() -> Vec<String> {
    let mut v = Vec::new();
    if let Ok(p) = std::env::var("BASH_O4_CUDA_LIB") {
        v.push(p);
    }
    v.push("/usr/lib/wsl/lib/libcuda.so.1.1".to_string());
    v.push("/usr/lib/wsl/lib/libcuda.so.1".to_string());
    v.push("libcuda.so.1".to_string());
    v.push("libcuda.so".to_string());
    v
}

// Function pointer types (LP64: pointers/u64/size_t are 8 bytes).
type FnInit = unsafe extern "C" fn(c_int) -> CUresult;
type FnDevGet = unsafe extern "C" fn(*mut CUdevice, c_int) -> CUresult;
type FnDevName = unsafe extern "C" fn(*mut c_char, c_int, CUdevice) -> CUresult;
type FnCtxCreate = unsafe extern "C" fn(*mut CUcontext, u32, CUdevice) -> CUresult;
type FnCtxSet = unsafe extern "C" fn(CUcontext) -> CUresult;
type FnCtxDestroy = unsafe extern "C" fn(CUcontext) -> CUresult;
type FnAlloc = unsafe extern "C" fn(*mut CUdeviceptr, usize) -> CUresult;
type FnFree = unsafe extern "C" fn(CUdeviceptr) -> CUresult;
type FnHtoD = unsafe extern "C" fn(CUdeviceptr, *const c_void, usize) -> CUresult;
type FnDtoH = unsafe extern "C" fn(*mut c_void, CUdeviceptr, usize) -> CUresult;
type FnModLoad = unsafe extern "C" fn(*mut CUmodule, *const c_char) -> CUresult;
type FnModGetFn = unsafe extern "C" fn(*mut CUfunction, CUmodule, *const c_char) -> CUresult;
type FnModUnload = unsafe extern "C" fn(CUmodule) -> CUresult;
type FnLaunch = unsafe extern "C" fn(
    CUfunction,
    u32,
    u32,
    u32,
    u32,
    u32,
    u32,
    u32,
    *mut c_void,
    *mut *mut c_void,
    *mut *mut c_void,
) -> CUresult;
type FnSync = unsafe extern "C" fn() -> CUresult;
type FnErrStr = unsafe extern "C" fn(CUresult, *mut *const c_char) -> CUresult;

struct CuFns {
    init: FnInit,
    dev_get: FnDevGet,
    #[allow(dead_code)]
    dev_name: FnDevName,
    ctx_create: FnCtxCreate,
    ctx_set: FnCtxSet,
    ctx_destroy: FnCtxDestroy,
    alloc: FnAlloc,
    free: FnFree,
    htod: FnHtoD,
    dtoh: FnDtoH,
    mod_load: FnModLoad,
    mod_getfn: FnModGetFn,
    mod_unload: FnModUnload,
    launch: FnLaunch,
    sync: FnSync,
    err_str: FnErrStr,
}

/// True when a CUDA driver loads with ≥1 device. Any failure ⇒ false
/// (callers take the CPU path — same firewall as vkffi).
pub fn has_cuda_device() -> bool {
    match Cuda::load() {
        Err(_) => false,
        Ok(cu) => cu.device_count().map(|n| n > 0).unwrap_or(false),
    }
}

struct Cuda {
    handle: *mut c_void,
    f: CuFns,
}

impl Drop for Cuda {
    fn drop(&mut self) {
        unsafe {
            dlclose(self.handle);
        }
    }
}

impl Cuda {
    /// dlopen the driver. Err on any failure (callers degrade to CPU).
    fn load() -> Result<Self, String> {
        let mut last_err = String::from("no libcuda candidate");
        for path in lib_candidates() {
            let cs = CString::new(path.clone()).unwrap();
            let h = unsafe { dlopen(cs.as_ptr(), RTLD_NOW) };
            if h.is_null() {
                last_err = format!("dlopen {path} failed");
                continue;
            }
            macro_rules! get {
                ($t:ty, $n:literal) => {{
                    let cs = CString::new($n).unwrap();
                    let p = unsafe { dlsym(h, cs.as_ptr()) };
                    if p.is_null() {
                        unsafe { dlclose(h) };
                        last_err = format!("{path} lacks {}", $n);
                        continue;
                    }
                    unsafe { std::mem::transmute::<*mut c_void, $t>(p) }
                }};
            }
            // Explicit _v2 where versioned (see module docs).
            let f = CuFns {
                init: get!(FnInit, "cuInit"),
                dev_get: get!(FnDevGet, "cuDeviceGet"),
                dev_name: get!(FnDevName, "cuDeviceGetName"),
                ctx_create: get!(FnCtxCreate, "cuCtxCreate_v2"),
                ctx_set: get!(FnCtxSet, "cuCtxSetCurrent"),
                ctx_destroy: get!(FnCtxDestroy, "cuCtxDestroy"),
                alloc: get!(FnAlloc, "cuMemAlloc_v2"),
                free: get!(FnFree, "cuMemFree"),
                htod: get!(FnHtoD, "cuMemcpyHtoD_v2"),
                dtoh: get!(FnDtoH, "cuMemcpyDtoH_v2"),
                mod_load: get!(FnModLoad, "cuModuleLoadData"),
                mod_getfn: get!(FnModGetFn, "cuModuleGetFunction"),
                mod_unload: get!(FnModUnload, "cuModuleUnload"),
                launch: get!(FnLaunch, "cuLaunchKernel"),
                sync: get!(FnSync, "cuCtxSynchronize"),
                err_str: get!(FnErrStr, "cuGetErrorString"),
            };
            let cu = Cuda { handle: h, f };
            if unsafe { (cu.f.init)(0) } != CUDA_SUCCESS {
                unsafe { dlclose(h) };
                last_err = format!("{path}: cuInit failed");
                continue;
            }
            return Ok(cu);
        }
        Err(last_err)
    }

    fn err(&self, rc: CUresult) -> String {
        let mut s: *const c_char = ptr::null();
        unsafe {
            (self.f.err_str)(rc, &mut s);
            if s.is_null() {
                return format!("cuda rc={rc}");
            }
            std::ffi::CStr::from_ptr(s).to_string_lossy().into_owned()
        }
    }

    /// 1 when device 0 enumerates, else Err (only device 0 is used;
    /// multi-GPU selection is future work).
    fn device_count(&self) -> Result<i32, String> {
        let mut dev: CUdevice = 0;
        let rc = unsafe { (self.f.dev_get)(&mut dev, 0) };
        if rc != CUDA_SUCCESS {
            return Err(self.err(rc));
        }
        Ok(1)
    }
}

/// One-shot CUDA dispatch: PTX source (JIT per call — callers hoist
/// compilation outside timers, like gcc compile), output i64 arrays.
/// Grids/blocks caller-sized. Buffers are device memory; outputs copied
/// back after sync. v1 — no streams, no persistent buffers.
pub struct CudaRunner {
    cu: Cuda,
    ctx: CUcontext,
}

impl Drop for CudaRunner {
    fn drop(&mut self) {
        unsafe {
            (self.cu.f.ctx_destroy)(self.ctx);
        }
    }
}

impl CudaRunner {
    pub fn new() -> Result<Self, String> {
        let cu = Cuda::load()?;
        let mut dev: CUdevice = 0;
        let rc = unsafe { (cu.f.dev_get)(&mut dev, 0) };
        if rc != CUDA_SUCCESS {
            return Err(cu.err(rc));
        }
        let mut ctx: CUcontext = ptr::null_mut();
        let rc = unsafe { (cu.f.ctx_create)(&mut ctx, 0, dev) };
        if rc != CUDA_SUCCESS {
            return Err(cu.err(rc));
        }
        let rc = unsafe { (cu.f.ctx_set)(ctx) };
        if rc != CUDA_SUCCESS {
            return Err(cu.err(rc));
        }
        Ok(CudaRunner { cu, ctx })
    }

    /// Allocate a device i64 array (persistent across dispatches for
    /// multi-kernel pipelines like map+reduce sharing). Zero-filled on
    /// host-staged upload (mirrors run's semantics). Free with `free()`.
    pub fn alloc_array(&self, len: usize) -> Result<CUdeviceptr, String> {
        let len = len.max(1);
        let bytes = len * 8;
        let mut p: CUdeviceptr = 0;
        let rc = unsafe { (self.cu.f.alloc)(&mut p, bytes) };
        if rc != CUDA_SUCCESS {
            return Err(format!("alloc_array: {}", self.cu.err(rc)));
        }
        let zeros = vec![0i64; len];
        let rc = unsafe { (self.cu.f.htod)(p, zeros.as_ptr() as *const c_void, bytes) };
        if rc != CUDA_SUCCESS {
            unsafe { (self.cu.f.free)(p) };
            return Err(format!("alloc_array zero: {}", self.cu.err(rc)));
        }
        Ok(p)
    }

    /// Free a device array from `alloc_array`.
    pub fn free_array(&self, p: CUdeviceptr) {
        unsafe {
            (self.cu.f.free)(p);
        }
    }

    /// Read back a device i64 array into host memory.
    pub fn read_array(&self, p: CUdeviceptr, len: usize) -> Result<Vec<i64>, String> {
        let len = len.max(1);
        let mut host = vec![0i64; len];
        let rc = unsafe {
            (self.cu.f.dtoh)(host.as_mut_ptr() as *mut c_void, p, len * 8)
        };
        if rc != CUDA_SUCCESS {
            return Err(format!("read_array: {}", self.cu.err(rc)));
        }
        Ok(host)
    }

    /// Dispatch `ptx` using PRE-ALLOCATED device buffers (no alloc/free;
    /// for pipelines sharing arrays across kernels). `bufs` are device
    /// pointers in param order, followed by `scalars`. Reads back nothing
    /// (callers read what they need via `read_array`).
    pub fn run_buffers(
        &self,
        ptx: &str,
        kernel: &str,
        bufs: &[CUdeviceptr],
        scalars: &[i64],
        grid: u32,
        block: u32,
    ) -> Result<(), String> {
        let f = &self.cu.f;
        let err = |rc| self.cu.err(rc);
        if grid == 0 || block == 0 {
            return Err("empty grid/block".to_string());
        }
        let cptx = CString::new(ptx).map_err(|e| e.to_string())?;
        let mut module: CUmodule = ptr::null_mut();
        let rc = unsafe { (f.mod_load)(&mut module, cptx.as_ptr()) };
        if rc != CUDA_SUCCESS {
            return Err(format!("ptx jit: {}", err(rc)));
        }
        let cname = CString::new(kernel).map_err(|e| e.to_string())?;
        let mut func: CUfunction = ptr::null_mut();
        let rc = unsafe { (f.mod_getfn)(&mut func, module, cname.as_ptr()) };
        if rc != CUDA_SUCCESS {
            unsafe { (f.mod_unload)(module) };
            return Err(format!("getfunc: {}", err(rc)));
        }
        let mut slots: Vec<u64> = bufs.to_vec();
        let mut svals: Vec<u64> = scalars.iter().map(|v| *v as u64).collect();
        let mut params: Vec<*mut c_void> = Vec::new();
        for p in slots.iter_mut() {
            params.push(p as *mut u64 as *mut c_void);
        }
        for v in svals.iter_mut() {
            params.push(v as *mut u64 as *mut c_void);
        }
        let rc = unsafe {
            (f.launch)(
                func, grid, 1, 1, block, 1, 1, 0, ptr::null_mut(),
                params.as_mut_ptr(), ptr::null_mut(),
            )
        };
        if rc != CUDA_SUCCESS {
            unsafe { (f.mod_unload)(module) };
            return Err(format!("launch: {}", err(rc)));
        }
        let rc = unsafe { (f.sync)() };
        unsafe { (f.mod_unload)(module) };
        if rc != CUDA_SUCCESS {
            return Err(format!("sync: {}", err(rc)));
        }
        Ok(())
    }

    /// Dispatch `ptx` (entry `kernel`) over `grid`×`block`, returning the
    /// output i64 arrays (lengths `out_lens`). Scalar `.param` values    /// Dispatch `ptx` (entry `kernel`) over `grid`×`block`, returning the
    /// output i64 arrays (lengths `out_lens`). Scalar `.param` values
    /// (`scalars`, in declaration order after the buffer pointers) feed
    /// extern slots and trip counts. Module JIT + buffers are per-call
    /// (callers hoist what matters outside timers).
    pub fn run(
        &self,
        ptx: &str,
        kernel: &str,
        out_lens: &[usize],
        scalars: &[i64],
        grid: u32,
        block: u32,
    ) -> Result<Vec<Vec<i64>>, String> {
        let f = &self.cu.f;
        let err = |rc| self.cu.err(rc);
        if out_lens.is_empty() {
            return Err("no output arrays".to_string());
        }
        if grid == 0 || block == 0 {
            return Err("empty grid/block".to_string());
        }
        // JIT
        let cptx = CString::new(ptx).map_err(|e| e.to_string())?;
        let mut module: CUmodule = ptr::null_mut();
        let rc = unsafe { (f.mod_load)(&mut module, cptx.as_ptr()) };
        if rc != CUDA_SUCCESS {
            if std::env::var("BASH_O4_CUDA_DUMPPTX").is_ok() {
                let _ = std::fs::write("/tmp/cudabench-last.ptx", ptx);
            }
            return Err(format!("ptx jit: {} (set BASH_O4_CUDA_DUMPPTX=1 to dump)", err(rc)));
        }
        let cname = CString::new(kernel).map_err(|e| e.to_string())?;
        let mut func: CUfunction = ptr::null_mut();
        let rc = unsafe { (f.mod_getfn)(&mut func, module, cname.as_ptr()) };
        if rc != CUDA_SUCCESS {
            unsafe { (f.mod_unload)(module) };
            return Err(format!("getfunc: {}", err(rc)));
        }
        // Output buffers (host-zeroed staging, like vkffi write_mem).
        let mut devptrs: Vec<CUdeviceptr> = Vec::new();
        let mut host: Vec<Vec<i64>> = Vec::new();
        for &len in out_lens {
            let len = len.max(1);
            let bytes = len * 8;
            let mut p: CUdeviceptr = 0;
            let rc = unsafe { (f.alloc)(&mut p, bytes) };
            if rc != CUDA_SUCCESS {
                for q in &devptrs {
                    unsafe { (f.free)(*q) };
                }
                unsafe { (f.mod_unload)(module) };
                return Err(format!("alloc: {}", err(rc)));
            }
            devptrs.push(p);
            let zeros = vec![0i64; len];
            let rc = unsafe { (f.htod)(p, zeros.as_ptr() as *const c_void, bytes) };
            if rc != CUDA_SUCCESS {
                for q in &devptrs {
                    unsafe { (f.free)(*q) };
                }
                unsafe { (f.mod_unload)(module) };
                return Err(format!("h2d zero: {}", err(rc)));
            }
            host.push(vec![0i64; len]);
        }
        // Launch: one pointer param per output buffer, then scalar
        // values (slots must outlive the launch — held in `svals`).
        let mut svals: Vec<u64> = scalars.iter().map(|v| *v as u64).collect();
        let mut params: Vec<*mut c_void> = devptrs
            .iter_mut()
            .map(|p| p as *mut CUdeviceptr as *mut c_void)
            .collect();
        for v in svals.iter_mut() {
            params.push(v as *mut u64 as *mut c_void);
        }
        let rc = unsafe {
            (f.launch)(
                func, grid, 1, 1, block, 1, 1, 0, ptr::null_mut(),
                params.as_mut_ptr(), ptr::null_mut(),
            )
        };
        if rc != CUDA_SUCCESS {
            for q in &devptrs {
                unsafe { (f.free)(*q) };
            }
            unsafe { (f.mod_unload)(module) };
            return Err(format!("launch: {}", err(rc)));
        }
        let rc = unsafe { (f.sync)() };
        if rc != CUDA_SUCCESS {
            for q in &devptrs {
                unsafe { (f.free)(*q) };
            }
            unsafe { (f.mod_unload)(module) };
            return Err(format!("sync: {}", err(rc)));
        }
        for (i, &p) in devptrs.iter().enumerate() {
            let bytes = host[i].len() * 8;
            let rc = unsafe { (f.dtoh)(host[i].as_mut_ptr() as *mut c_void, p, bytes) };
            if rc != CUDA_SUCCESS {
                for q in &devptrs {
                    unsafe { (f.free)(*q) };
                }
                unsafe { (f.mod_unload)(module) };
                return Err(format!("d2h: {}", err(rc)));
            }
        }
        for q in &devptrs {
            unsafe { (f.free)(*q) };
        }
        unsafe { (f.mod_unload)(module) };
        Ok(host)
    }
}
