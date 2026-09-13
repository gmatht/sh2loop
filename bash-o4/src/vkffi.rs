//! Minimal Vulkan FFI (docs/BASH-O4.md §4.4, M3 scaffolding).
//!
//! `libvulkan.so.1` is opened at RUNTIME (`dlopen` — never a build
//! dependency, so missing Vulkan never breaks the build). Only the
//! instance/device/compute subset is bound, with layouts verified
//! against `vulkan_core.h`. Used by `--check` (device presence) and the
//! lavapipe end-to-end dispatch test; generated-code host-split wiring
//! is M3-remaining.

use std::ffi::{c_char, c_int, c_void, CString};
use std::ptr;

// ---- loader -----------------------------------------------------------

const RTLD_NOW: c_int = 2;

extern "C" {
    fn dlopen(name: *const c_char, flags: c_int) -> *mut c_void;
    fn dlsym(handle: *mut c_void, sym: *const c_char) -> *mut c_void;
    fn dlclose(handle: *mut c_void) -> c_int;
}

fn lib_path() -> String {
    std::env::var("BASH_O4_VULKAN_LIB").unwrap_or_else(|_| "libvulkan.so.1".to_string())
}

// ---- handles ----------------------------------------------------------

type VkInstance = *mut c_void;
type VkPhysicalDevice = *mut c_void;
type VkDevice = *mut c_void;
type VkQueue = *mut c_void;
type VkBuffer = u64;
type VkDeviceMemory = u64;
type VkDescriptorSetLayout = u64;
type VkPipelineLayout = u64;
type VkShaderModule = u64;
type VkPipeline = u64;
type VkDescriptorPool = u64;
type VkDescriptorSet = u64;
type VkCommandPool = u64;
type VkCommandBuffer = *mut c_void;
type VkFence = u64;
type VkResult = i32;
const VK_SUCCESS: VkResult = 0;

// ---- sType values (vulkan_core.h) -------------------------------------

const STYPE_APPLICATION_INFO: u32 = 0;
const STYPE_INSTANCE_CREATE_INFO: u32 = 1;
const STYPE_DEVICE_QUEUE_CREATE_INFO: u32 = 2;
const STYPE_DEVICE_CREATE_INFO: u32 = 3;
const STYPE_SUBMIT_INFO: u32 = 4;
const STYPE_MEMORY_ALLOCATE_INFO: u32 = 5;
const STYPE_FENCE_CREATE_INFO: u32 = 8;
const STYPE_BUFFER_CREATE_INFO: u32 = 12;
const STYPE_SHADER_MODULE_CREATE_INFO: u32 = 16;
const STYPE_COMPUTE_PIPELINE_CREATE_INFO: u32 = 29;
const STYPE_PIPELINE_LAYOUT_CREATE_INFO: u32 = 30;
const STYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO: u32 = 32;
const STYPE_DESCRIPTOR_POOL_CREATE_INFO: u32 = 33;
const STYPE_DESCRIPTOR_SET_ALLOCATE_INFO: u32 = 34;
const STYPE_WRITE_DESCRIPTOR_SET: u32 = 35;
const STYPE_COMMAND_POOL_CREATE_INFO: u32 = 39;
const STYPE_COMMAND_BUFFER_ALLOCATE_INFO: u32 = 40;
const STYPE_COMMAND_BUFFER_BEGIN_INFO: u32 = 42;

const QUEUE_COMPUTE_BIT: u32 = 0x2;
const BUFFER_USAGE_STORAGE: u32 = 0x20;
const MEM_HOST_VISIBLE: u32 = 0x1;
const MEM_HOST_COHERENT: u32 = 0x2;
const DESC_STORAGE_BUFFER: u32 = 7;
const STAGE_COMPUTE: u32 = 0x20;
const BIND_COMPUTE: u32 = 1;
const SHARING_EXCLUSIVE: u32 = 0;
const CMD_LEVEL_PRIMARY: u32 = 0;
const API_VERSION_1_1: u32 = (1 << 22) | (1 << 12);

// ---- structs (C layout, verified against vulkan_core.h) ---------------

#[repr(C)]
struct VkApplicationInfo {
    s_type: u32,
    p_next: *const c_void,
    p_app_name: *const c_char,
    app_version: u32,
    p_engine_name: *const c_char,
    engine_version: u32,
    api_version: u32,
}

#[repr(C)]
struct VkInstanceCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    p_app_info: *const VkApplicationInfo,
    enabled_layer_count: u32,
    pp_enabled_layer_names: *const *const c_char,
    enabled_extension_count: u32,
    pp_enabled_extension_names: *const *const c_char,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct VkQueueFamilyProps {
    flags: u32,
    count: u32,
    _timestamp_bits: u32,
    _granularity: [u32; 3],
}

#[repr(C)]
struct VkDeviceQueueCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    family_index: u32,
    queue_count: u32,
    p_priorities: *const f32,
}

#[repr(C)]
struct VkDeviceCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    queue_create_info_count: u32,
    p_queue_create_infos: *const VkDeviceQueueCreateInfo,
    enabled_layer_count: u32,
    pp_enabled_layer_names: *const *const c_char,
    enabled_extension_count: u32,
    pp_enabled_extension_names: *const *const c_char,
    p_enabled_features: *const c_void,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct VkMemoryType {
    property_flags: u32,
    heap_index: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
struct VkMemoryHeap {
    size: u64,
    flags: u32,
    _pad: u32,
}

#[repr(C)]
struct VkMemoryProps {
    type_count: u32,
    types: [VkMemoryType; 32],
    heap_count: u32,
    heaps: [VkMemoryHeap; 16],
}

#[repr(C)]
struct VkBufferCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    size: u64,
    usage: u32,
    sharing_mode: u32,
    queue_family_index_count: u32,
    p_queue_family_indices: *const u32,
}

#[repr(C)]
struct VkMemoryReq {
    size: u64,
    alignment: u64,
    type_bits: u32,
    _pad: u32,
}

#[repr(C)]
struct VkMemoryAllocInfo {
    s_type: u32,
    p_next: *const c_void,
    size: u64,
    type_index: u32,
    _pad: u32,
}

#[repr(C)]
struct VkSetLayoutBinding {
    binding: u32,
    descriptor_type: u32,
    descriptor_count: u32,
    stage_flags: u32,
    p_immutable_samplers: *const c_void,
}

#[repr(C)]
struct VkSetLayoutCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    binding_count: u32,
    p_bindings: *const VkSetLayoutBinding,
}

#[repr(C)]
struct VkPipelineLayoutCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    set_layout_count: u32,
    p_set_layouts: *const VkDescriptorSetLayout,
    push_constant_range_count: u32,
    p_push_constant_ranges: *const c_void,
}

#[repr(C)]
struct VkShaderModuleCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    code_size: usize,
    p_code: *const u32,
}

#[repr(C)]
struct VkShaderStageInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    stage: u32,
    module: VkShaderModule,
    p_name: *const c_char,
    p_specialization_info: *const c_void,
}

#[repr(C)]
struct VkComputePipelineCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    stage: VkShaderStageInfo,
    layout: VkPipelineLayout,
    base_handle: VkPipeline,
    base_index: i32,
}

#[repr(C)]
struct VkPoolSize {
    ty: u32,
    count: u32,
}

#[repr(C)]
struct VkPoolCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    max_sets: u32,
    pool_size_count: u32,
    p_pool_sizes: *const VkPoolSize,
}

#[repr(C)]
struct VkSetAllocInfo {
    s_type: u32,
    p_next: *const c_void,
    pool: VkDescriptorPool,
    set_count: u32,
    p_set_layouts: *const VkDescriptorSetLayout,
}

#[repr(C)]
struct VkDescriptorBufferInfo {
    buffer: VkBuffer,
    offset: u64,
    range: u64,
}

#[repr(C)]
struct VkWriteSet {
    s_type: u32,
    p_next: *const c_void,
    dst_set: VkDescriptorSet,
    dst_binding: u32,
    dst_array_element: u32,
    descriptor_count: u32,
    descriptor_type: u32,
    p_image_info: *const c_void,
    p_buffer_info: *const VkDescriptorBufferInfo,
    p_texel_view: *const c_void,
}

#[repr(C)]
struct VkCmdPoolCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    queue_family_index: u32,
}

#[repr(C)]
struct VkCmdAllocInfo {
    s_type: u32,
    p_next: *const c_void,
    pool: VkCommandPool,
    level: u32,
    count: u32,
}

#[repr(C)]
struct VkCmdBeginInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    p_inheritance_info: *const c_void,
}

#[repr(C)]
struct VkSubmitInfo {
    s_type: u32,
    p_next: *const c_void,
    wait_count: u32,
    p_wait_sems: *const c_void,
    p_wait_masks: *const u32,
    cmd_count: u32,
    p_cmds: *const VkCommandBuffer,
    signal_count: u32,
    p_signal_sems: *const c_void,
}

#[repr(C)]
struct VkFenceCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
}

// ---- function table ---------------------------------------------------

macro_rules! vkfn {
    // GLOBAL commands only (resolvable with a NULL instance — loader
    // trampolines). Instance/device commands MUST go through `ifn`
    // (real instance) / `dproc` (real device): NULL-instance lookup
    // returns null for them and calling it segfaults (lavapipe SEGV).
    ($name:ident ( $( $arg:ident : $ty:ty ),* ) -> $ret:ty) => {
        #[allow(non_snake_case)]
        fn $name(&self, $( $arg : $ty ),*) -> $ret {
            let f: unsafe extern "C" fn( $( $ty ),* ) -> $ret =
                unsafe { std::mem::transmute(self.proc(stringify!($name))) };
            unsafe { f( $( $arg ),* ) }
        }
    };
}

/// Resolve an INSTANCE-level command through a real instance handle.
/// Panics loudly when the loader lacks it (never a null call).
fn ifn<T>(vk: &Vk, inst: VkInstance, name: &str) -> T
where
    T: Copy,
{
    let p = vk.iproc(inst, name);
    assert!(!p.is_null(), "vulkan {name} missing");
    unsafe { std::mem::transmute_copy::<*mut c_void, T>(&p) }
}

pub struct Vk {
    handle: *mut c_void,
    get_proc: unsafe extern "C" fn(VkInstance, *const c_char) -> *mut c_void,
}

impl Vk {
    /// dlopen the loader. Err on any failure (callers degrade to CPU).
    pub fn load() -> Result<Self, String> {
        let path = CString::new(lib_path()).map_err(|e| format!("vulkan lib path: {e}"))?;
        let handle = unsafe { dlopen(path.as_ptr(), RTLD_NOW) };
        if handle.is_null() {
            return Err(format!("dlopen {} failed (no Vulkan loader)", lib_path()));
        }
        let sym = CString::new("vkGetInstanceProcAddr").unwrap();
        let get_proc = unsafe { dlsym(handle, sym.as_ptr()) };
        if get_proc.is_null() {
            unsafe { dlclose(handle) };
            return Err("vkGetInstanceProcAddr missing".to_string());
        }
        Ok(Vk { handle, get_proc: unsafe { std::mem::transmute(get_proc) } })
    }

    fn proc(&self, name: &str) -> *mut c_void {
        let c = CString::new(name).unwrap();
        unsafe { (self.get_proc)(ptr::null_mut(), c.as_ptr()) }
    }

    fn iproc(&self, inst: VkInstance, name: &str) -> *mut c_void {
        let c = CString::new(name).unwrap();
        unsafe { (self.get_proc)(inst, c.as_ptr()) }
    }

    vkfn!(vkCreateInstance(p_create_info: *const VkInstanceCreateInfo, p_allocator: *const c_void, p_instance: *mut VkInstance) -> VkResult);

    #[allow(clippy::too_many_arguments)]
    fn dproc<T>(&self, inst: VkInstance, dev: VkDevice, name: &str) -> T
    where
        T: Copy,
    {
        // vkGetDeviceProcAddr must be resolved through a REAL instance
        // (NULL-instance lookup returns null — calling it segfaults).
        let gdpa: unsafe extern "C" fn(VkDevice, *const c_char) -> *mut c_void =
            unsafe { std::mem::transmute(self.iproc(inst, "vkGetDeviceProcAddr")) };
        let c = CString::new(name).unwrap();
        let p = unsafe { gdpa(dev, c.as_ptr()) };
        let p = if p.is_null() { self.proc(name) } else { p };
        assert!(!p.is_null(), "vulkan {name} missing");
        unsafe { std::mem::transmute_copy::<*mut c_void, T>(&p) }
    }
}

impl Drop for Vk {
    fn drop(&mut self) {
        unsafe { dlclose(self.handle) };
    }
}

fn vk_ok(what: &str, rc: VkResult) -> Result<(), String> {
    if rc == VK_SUCCESS {
        Ok(())
    } else {
        Err(format!("vulkan {what} failed: rc={rc}"))
    }
}

// ---- device detection -------------------------------------------------

/// True when a loader + ≥1 physical device with a compute queue exists.
/// Any failure ⇒ false (callers take the CPU path — doc §4.4 firewall).
/// The probe instance is destroyed afterwards (no leak per `--check`).
pub fn has_compute_device() -> bool {
    let Ok(vk) = Vk::load() else { return false };
    match pick_compute_device(&vk) {
        Ok((inst, _, _)) => {
            let destroy: unsafe extern "C" fn(VkInstance, *const c_void) -> () =
                ifn(&vk, inst, "vkDestroyInstance");
            unsafe { destroy(inst, ptr::null()) };
            true
        }
        Err(_) => false,
    }
}

/// First physical device with a compute-capable queue family.
fn pick_compute_device(vk: &Vk) -> Result<(VkInstance, VkPhysicalDevice, u32), String> {
    let ai = VkApplicationInfo {
        s_type: STYPE_APPLICATION_INFO,
        p_next: ptr::null(),
        p_app_name: ptr::null(),
        app_version: 0,
        p_engine_name: ptr::null(),
        engine_version: 0,
        api_version: API_VERSION_1_1,
    };
    let ci = VkInstanceCreateInfo {
        s_type: STYPE_INSTANCE_CREATE_INFO,
        p_next: ptr::null(),
        flags: 0,
        p_app_info: &ai,
        enabled_layer_count: 0,
        pp_enabled_layer_names: ptr::null(),
        enabled_extension_count: 0,
        pp_enabled_extension_names: ptr::null(),
    };
    let mut inst: VkInstance = ptr::null_mut();
    vk_ok("create-instance", vk.vkCreateInstance(&ci, ptr::null(), &mut inst))?;
    let enum_devs: unsafe extern "C" fn(VkInstance, *mut u32, *mut VkPhysicalDevice) -> VkResult =
        ifn(&vk, inst, "vkEnumeratePhysicalDevices");
    let qfam_props: unsafe extern "C" fn(VkPhysicalDevice, *mut u32, *mut VkQueueFamilyProps) -> () =
        ifn(&vk, inst, "vkGetPhysicalDeviceQueueFamilyProperties");
    let destroy: unsafe extern "C" fn(VkInstance, *const c_void) -> () =
        ifn(&vk, inst, "vkDestroyInstance");
    let result = (|| {
        let mut n: u32 = 0;
        vk_ok("enum-devices", unsafe { enum_devs(inst, &mut n, ptr::null_mut()) })?;
        if n == 0 {
            return Err("no physical devices".to_string());
        }
        let mut devs = vec![ptr::null_mut(); n as usize];
        vk_ok("enum-devices", unsafe { enum_devs(inst, &mut n, devs.as_mut_ptr()) })?;
        for d in devs {
            let mut m: u32 = 0;
            unsafe { qfam_props(d, &mut m, ptr::null_mut()) };
            let mut fams = vec![
                VkQueueFamilyProps { flags: 0, count: 0, _timestamp_bits: 0, _granularity: [0; 3] };
                m as usize
            ];
            unsafe { qfam_props(d, &mut m, fams.as_mut_ptr()) };
            for (i, f) in fams.iter().enumerate() {
                if f.flags & QUEUE_COMPUTE_BIT != 0 && f.count > 0 {
                    return Ok((inst, d, i as u32));
                }
            }
        }
        Err("no compute queue".to_string())
    })();
    if result.is_err() {
        unsafe { destroy(inst, ptr::null()) };
    }
    result
}

// ---- minimal compute runner (M3 proof vehicle) -------------------------

/// One-shot compute dispatch over the emitter's buffer contract:
/// binding 0 = read-only `in_data[]`, binding 1 = `out[]` (int64).
/// Returns the full out buffer. Host-visible coherent memory throughout
/// (v1 — device-local + staging is P3).
pub struct ComputeRunner {
    vk: Vk,
    inst: VkInstance,
    dev: VkDevice,
    queue: VkQueue,
    family: u32,
    mem_props: VkMemoryProps,
    dev_fns: DevFns,
}

#[derive(Clone, Copy)]
struct DevFns {
    create_buffer: unsafe extern "C" fn(VkDevice, *const VkBufferCreateInfo, *const c_void, *mut VkBuffer) -> VkResult,
    get_buffer_memory_requirements:
        unsafe extern "C" fn(VkDevice, VkBuffer, *mut VkMemoryReq) -> (),
    allocate_memory: unsafe extern "C" fn(VkDevice, *const VkMemoryAllocInfo, *const c_void, *mut VkDeviceMemory) -> VkResult,
    bind_buffer_memory: unsafe extern "C" fn(VkDevice, VkBuffer, VkDeviceMemory, u64) -> VkResult,
    map_memory: unsafe extern "C" fn(VkDevice, VkDeviceMemory, u64, u64, u32, *mut *mut c_void) -> VkResult,
    unmap_memory: unsafe extern "C" fn(VkDevice, VkDeviceMemory) -> (),
    free_memory: unsafe extern "C" fn(VkDevice, VkDeviceMemory, *const c_void) -> (),
    destroy_buffer: unsafe extern "C" fn(VkDevice, VkBuffer, *const c_void) -> (),
    create_descriptor_set_layout:
        unsafe extern "C" fn(VkDevice, *const VkSetLayoutCreateInfo, *const c_void, *mut VkDescriptorSetLayout) -> VkResult,
    destroy_descriptor_set_layout: unsafe extern "C" fn(VkDevice, VkDescriptorSetLayout, *const c_void) -> (),
    create_pipeline_layout:
        unsafe extern "C" fn(VkDevice, *const VkPipelineLayoutCreateInfo, *const c_void, *mut VkPipelineLayout) -> VkResult,
    destroy_pipeline_layout: unsafe extern "C" fn(VkDevice, VkPipelineLayout, *const c_void) -> (),
    create_shader_module:
        unsafe extern "C" fn(VkDevice, *const VkShaderModuleCreateInfo, *const c_void, *mut VkShaderModule) -> VkResult,
    destroy_shader_module: unsafe extern "C" fn(VkDevice, VkShaderModule, *const c_void) -> (),
    create_compute_pipelines:
        unsafe extern "C" fn(VkDevice, VkPipeline, u32, *const VkComputePipelineCreateInfo, *const c_void, *mut VkPipeline) -> VkResult,
    destroy_pipeline: unsafe extern "C" fn(VkDevice, VkPipeline, *const c_void) -> (),
    create_descriptor_pool:
        unsafe extern "C" fn(VkDevice, *const VkPoolCreateInfo, *const c_void, *mut VkDescriptorPool) -> VkResult,
    destroy_descriptor_pool: unsafe extern "C" fn(VkDevice, VkDescriptorPool, *const c_void) -> (),
    allocate_descriptor_sets:
        unsafe extern "C" fn(VkDevice, *const VkSetAllocInfo, *mut VkDescriptorSet) -> VkResult,
    update_descriptor_sets:
        unsafe extern "C" fn(VkDevice, u32, *const VkWriteSet, u32, *const c_void) -> (),
    create_command_pool:
        unsafe extern "C" fn(VkDevice, *const VkCmdPoolCreateInfo, *const c_void, *mut VkCommandPool) -> VkResult,
    destroy_command_pool: unsafe extern "C" fn(VkDevice, VkCommandPool, *const c_void) -> (),
    allocate_command_buffers:
        unsafe extern "C" fn(VkDevice, *const VkCmdAllocInfo, *mut VkCommandBuffer) -> VkResult,
    begin_command_buffer: unsafe extern "C" fn(VkCommandBuffer, *const VkCmdBeginInfo) -> VkResult,
    cmd_bind_pipeline: unsafe extern "C" fn(VkCommandBuffer, u32, VkPipeline) -> (),
    cmd_bind_descriptor_sets:
        unsafe extern "C" fn(VkCommandBuffer, u32, VkPipelineLayout, u32, u32, *const VkDescriptorSet, u32, *const u32) -> (),
    cmd_dispatch: unsafe extern "C" fn(VkCommandBuffer, u32, u32, u32) -> (),
    end_command_buffer: unsafe extern "C" fn(VkCommandBuffer) -> VkResult,
    create_fence: unsafe extern "C" fn(VkDevice, *const VkFenceCreateInfo, *const c_void, *mut VkFence) -> VkResult,
    destroy_fence: unsafe extern "C" fn(VkDevice, VkFence, *const c_void) -> (),
    queue_submit: unsafe extern "C" fn(VkQueue, u32, *const VkSubmitInfo, VkFence) -> VkResult,
    wait_for_fences: unsafe extern "C" fn(VkDevice, u32, *const VkFence, u32, u64) -> VkResult,
    get_device_queue: unsafe extern "C" fn(VkDevice, u32, u32, *mut VkQueue) -> (),
    destroy_device: unsafe extern "C" fn(VkDevice, *const c_void) -> (),
}

impl ComputeRunner {
    pub fn new() -> Result<Self, String> {
        let vk = Vk::load()?;
        let (inst, phys, family) = pick_compute_device(&vk)?;
        let prio = [1.0f32];
        let qci = VkDeviceQueueCreateInfo {
            s_type: STYPE_DEVICE_QUEUE_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            family_index: family,
            queue_count: 1,
            p_priorities: prio.as_ptr(),
        };
        let dci = VkDeviceCreateInfo {
            s_type: STYPE_DEVICE_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            queue_create_info_count: 1,
            p_queue_create_infos: &qci,
            enabled_layer_count: 0,
            pp_enabled_layer_names: ptr::null(),
            enabled_extension_count: 0,
            pp_enabled_extension_names: ptr::null(),
            p_enabled_features: ptr::null(),
        };
        let mut dev: VkDevice = ptr::null_mut();
        let create_dev: unsafe extern "C" fn(VkPhysicalDevice, *const VkDeviceCreateInfo, *const c_void, *mut VkDevice) -> VkResult =
            ifn(&vk, inst, "vkCreateDevice");
        let destroy_inst: unsafe extern "C" fn(VkInstance, *const c_void) -> () =
            ifn(&vk, inst, "vkDestroyInstance");
        let r = unsafe { create_dev(phys, &dci, ptr::null(), &mut dev) };
        if r != VK_SUCCESS {
            unsafe { destroy_inst(inst, ptr::null()) };
            return Err(format!("vulkan create-device failed: rc={r}"));
        }
        let mut queue: VkQueue = ptr::null_mut();
        let f: unsafe extern "C" fn(VkDevice, u32, u32, *mut VkQueue) -> () =
            vk.dproc(inst, dev, "vkGetDeviceQueue");
        unsafe { f(dev, family, 0, &mut queue) };
        let mut mem_props = VkMemoryProps {
            type_count: 0,
            types: [VkMemoryType { property_flags: 0, heap_index: 0 }; 32],
            heap_count: 0,
            heaps: [VkMemoryHeap { size: 0, flags: 0, _pad: 0 }; 16],
        };
        let get_mem_props: unsafe extern "C" fn(VkPhysicalDevice, *mut VkMemoryProps) -> () =
            ifn(&vk, inst, "vkGetPhysicalDeviceMemoryProperties");
        unsafe { get_mem_props(phys, &mut mem_props) };
        macro_rules! d {
            ($n:literal) => {
                vk.dproc(inst, dev, $n)
            };
        }
        let dev_fns = DevFns {
            create_buffer: d!("vkCreateBuffer"),
            get_buffer_memory_requirements: d!("vkGetBufferMemoryRequirements"),
            allocate_memory: d!("vkAllocateMemory"),
            bind_buffer_memory: d!("vkBindBufferMemory"),
            map_memory: d!("vkMapMemory"),
            unmap_memory: d!("vkUnmapMemory"),
            free_memory: d!("vkFreeMemory"),
            destroy_buffer: d!("vkDestroyBuffer"),
            create_descriptor_set_layout: d!("vkCreateDescriptorSetLayout"),
            destroy_descriptor_set_layout: d!("vkDestroyDescriptorSetLayout"),
            create_pipeline_layout: d!("vkCreatePipelineLayout"),
            destroy_pipeline_layout: d!("vkDestroyPipelineLayout"),
            create_shader_module: d!("vkCreateShaderModule"),
            destroy_shader_module: d!("vkDestroyShaderModule"),
            create_compute_pipelines: d!("vkCreateComputePipelines"),
            destroy_pipeline: d!("vkDestroyPipeline"),
            create_descriptor_pool: d!("vkCreateDescriptorPool"),
            destroy_descriptor_pool: d!("vkDestroyDescriptorPool"),
            allocate_descriptor_sets: d!("vkAllocateDescriptorSets"),
            update_descriptor_sets: d!("vkUpdateDescriptorSets"),
            create_command_pool: d!("vkCreateCommandPool"),
            destroy_command_pool: d!("vkDestroyCommandPool"),
            allocate_command_buffers: d!("vkAllocateCommandBuffers"),
            begin_command_buffer: d!("vkBeginCommandBuffer"),
            cmd_bind_pipeline: d!("vkCmdBindPipeline"),
            cmd_bind_descriptor_sets: d!("vkCmdBindDescriptorSets"),
            cmd_dispatch: d!("vkCmdDispatch"),
            end_command_buffer: d!("vkEndCommandBuffer"),
            create_fence: d!("vkCreateFence"),
            destroy_fence: d!("vkDestroyFence"),
            queue_submit: d!("vkQueueSubmit"),
            wait_for_fences: d!("vkWaitForFences"),
            get_device_queue: d!("vkGetDeviceQueue"),
            destroy_device: d!("vkDestroyDevice"),
        };
        Ok(ComputeRunner { vk, inst, dev, queue, family, mem_props, dev_fns })
    }

    fn mem_type(&self, bits: u32) -> Result<u32, String> {
        for i in 0..self.mem_props.type_count {
            let t = &self.mem_props.types[i as usize];
            if bits & (1 << i) != 0
                && t.property_flags & (MEM_HOST_VISIBLE | MEM_HOST_COHERENT)
                    == (MEM_HOST_VISIBLE | MEM_HOST_COHERENT)
            {
                return Ok(i);
            }
        }
        Err("no host-visible coherent memory type".to_string())
    }

    fn make_buffer(&self, bytes: u64) -> Result<(VkBuffer, VkDeviceMemory), String> {
        let f = &self.dev_fns;
        let bci = VkBufferCreateInfo {
            s_type: STYPE_BUFFER_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            size: bytes,
            usage: BUFFER_USAGE_STORAGE,
            sharing_mode: SHARING_EXCLUSIVE,
            queue_family_index_count: 0,
            p_queue_family_indices: ptr::null(),
        };
        let mut buf: VkBuffer = 0;
        vk_ok("create-buffer", unsafe { (f.create_buffer)(self.dev, &bci, ptr::null(), &mut buf) })?;
        let mut req = VkMemoryReq { size: 0, alignment: 0, type_bits: 0, _pad: 0 };
        unsafe { (f.get_buffer_memory_requirements)(self.dev, buf, &mut req) };
        let ai = VkMemoryAllocInfo {
            s_type: STYPE_MEMORY_ALLOCATE_INFO,
            p_next: ptr::null(),
            size: req.size,
            type_index: self.mem_type(req.type_bits)?,
            _pad: 0,
        };
        let mut mem: VkDeviceMemory = 0;
        let r = unsafe { (f.allocate_memory)(self.dev, &ai, ptr::null(), &mut mem) };
        if r != VK_SUCCESS {
            unsafe { (f.destroy_buffer)(self.dev, buf, ptr::null()) };
            return Err(format!("vulkan allocate-memory failed: rc={r}"));
        }
        vk_ok("bind-memory", unsafe {
            (f.bind_buffer_memory)(self.dev, buf, mem, 0)
        })?;
        Ok((buf, mem))
    }

    fn write_mem(&self, mem: VkDeviceMemory, data: &[i64]) -> Result<(), String> {
        let f = &self.dev_fns;
        let mut ptr: *mut c_void = ptr::null_mut();
        vk_ok("map-memory", unsafe {
            (f.map_memory)(self.dev, mem, 0, (data.len() * 8) as u64, 0, &mut ptr)
        })?;
        unsafe { std::ptr::copy_nonoverlapping(data.as_ptr(), ptr as *mut i64, data.len()) };
        unsafe { (f.unmap_memory)(self.dev, mem) };
        Ok(())
    }

    fn read_mem(&self, mem: VkDeviceMemory, n: usize) -> Result<Vec<i64>, String> {
        let f = &self.dev_fns;
        let mut ptr: *mut c_void = ptr::null_mut();
        vk_ok("map-memory", unsafe {
            (f.map_memory)(self.dev, mem, 0, (n * 8) as u64, 0, &mut ptr)
        })?;
        let mut out = vec![0i64; n];
        unsafe { std::ptr::copy_nonoverlapping(ptr as *const i64, out.as_mut_ptr(), n) };
        unsafe { (f.unmap_memory)(self.dev, mem) };
        Ok(out)
    }

    /// Dispatch `spv` (a compute shader over binding0=in, binding1=out)
    /// in `groups` workgroups; returns `out_len` int64s.
    pub fn run(&self, spv: &[u8], in_data: &[i64], out_len: usize, groups: u32) -> Result<Vec<i64>, String> {
        if spv.len() % 4 != 0 {
            return Err("SPIR-V length not a multiple of 4".to_string());
        }
        let f = &self.dev_fns;
        let in_bytes = ((in_data.len().max(1)) * 8) as u64;
        let out_bytes = (out_len.max(1) * 8) as u64;
        let (in_buf, in_mem) = self.make_buffer(in_bytes)?;
        let (out_buf, out_mem) = self.make_buffer(out_bytes)?;
        let result = (|| {
            self.write_mem(in_mem, &{
                let mut v = in_data.to_vec();
                if v.is_empty() {
                    v.push(0);
                }
                v
            })?;
            self.write_mem(out_mem, &vec![0i64; out_len.max(1)])?;
            // Descriptor set layout: two storage buffers, compute stage.
            let bindings = [
                VkSetLayoutBinding { binding: 0, descriptor_type: DESC_STORAGE_BUFFER, descriptor_count: 1, stage_flags: STAGE_COMPUTE, p_immutable_samplers: ptr::null() },
                VkSetLayoutBinding { binding: 1, descriptor_type: DESC_STORAGE_BUFFER, descriptor_count: 1, stage_flags: STAGE_COMPUTE, p_immutable_samplers: ptr::null() },
            ];
            let slci = VkSetLayoutCreateInfo {
                s_type: STYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                binding_count: 2,
                p_bindings: bindings.as_ptr(),
            };
            let mut set_layout: VkDescriptorSetLayout = 0;
            vk_ok("set-layout", unsafe {
                (f.create_descriptor_set_layout)(self.dev, &slci, ptr::null(), &mut set_layout)
            })?;
            let plci = VkPipelineLayoutCreateInfo {
                s_type: STYPE_PIPELINE_LAYOUT_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                set_layout_count: 1,
                p_set_layouts: &set_layout,
                push_constant_range_count: 0,
                p_push_constant_ranges: ptr::null(),
            };
            let mut pipe_layout: VkPipelineLayout = 0;
            vk_ok("pipe-layout", unsafe {
                (f.create_pipeline_layout)(self.dev, &plci, ptr::null(), &mut pipe_layout)
            })?;
            let main = CString::new("main").unwrap();
            let smci = VkShaderModuleCreateInfo {
                s_type: STYPE_SHADER_MODULE_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                code_size: spv.len(),
                p_code: spv.as_ptr() as *const u32,
            };
            let mut module: VkShaderModule = 0;
            vk_ok("shader-module", unsafe {
                (f.create_shader_module)(self.dev, &smci, ptr::null(), &mut module)
            })?;
            let stage = VkShaderStageInfo {
                s_type: 18, // VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO (vulkan_core.h)
                p_next: ptr::null(),
                flags: 0,
                stage: STAGE_COMPUTE,
                module,
                p_name: main.as_ptr(),
                p_specialization_info: ptr::null(),
            };
            let pci = VkComputePipelineCreateInfo {
                s_type: STYPE_COMPUTE_PIPELINE_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                stage,
                layout: pipe_layout,
                base_handle: 0,
                base_index: -1,
            };
            let mut pipeline: VkPipeline = 0;
            vk_ok("compute-pipeline", unsafe {
                (f.create_compute_pipelines)(self.dev, 0, 1, &pci, ptr::null(), &mut pipeline)
            })?;
            let pool_size = VkPoolSize { ty: DESC_STORAGE_BUFFER, count: 2 };
            let poolci = VkPoolCreateInfo {
                s_type: STYPE_DESCRIPTOR_POOL_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                max_sets: 1,
                pool_size_count: 1,
                p_pool_sizes: &pool_size,
            };
            let mut pool: VkDescriptorPool = 0;
            vk_ok("desc-pool", unsafe {
                (f.create_descriptor_pool)(self.dev, &poolci, ptr::null(), &mut pool)
            })?;
            let alloc = VkSetAllocInfo {
                s_type: STYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
                p_next: ptr::null(),
                pool,
                set_count: 1,
                p_set_layouts: &set_layout,
            };
            let mut set: VkDescriptorSet = 0;
            vk_ok("alloc-set", unsafe {
                (f.allocate_descriptor_sets)(self.dev, &alloc, &mut set)
            })?;
            let infos = [
                VkDescriptorBufferInfo { buffer: in_buf, offset: 0, range: in_bytes },
                VkDescriptorBufferInfo { buffer: out_buf, offset: 0, range: out_bytes },
            ];
            let writes = [
                VkWriteSet { s_type: STYPE_WRITE_DESCRIPTOR_SET, p_next: ptr::null(), dst_set: set, dst_binding: 0, dst_array_element: 0, descriptor_count: 1, descriptor_type: DESC_STORAGE_BUFFER, p_image_info: ptr::null(), p_buffer_info: &infos[0], p_texel_view: ptr::null() },
                VkWriteSet { s_type: STYPE_WRITE_DESCRIPTOR_SET, p_next: ptr::null(), dst_set: set, dst_binding: 1, dst_array_element: 0, descriptor_count: 1, descriptor_type: DESC_STORAGE_BUFFER, p_image_info: ptr::null(), p_buffer_info: &infos[1], p_texel_view: ptr::null() },
            ];
            unsafe { (f.update_descriptor_sets)(self.dev, 2, writes.as_ptr(), 0, ptr::null()) };
            // Command buffer: bind + dispatch.
            let cpci = VkCmdPoolCreateInfo {
                s_type: STYPE_COMMAND_POOL_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                queue_family_index: self.queue_family(),
            };
            let mut cmd_pool: VkCommandPool = 0;
            vk_ok("cmd-pool", unsafe {
                (f.create_command_pool)(self.dev, &cpci, ptr::null(), &mut cmd_pool)
            })?;
            let cai = VkCmdAllocInfo {
                s_type: STYPE_COMMAND_BUFFER_ALLOCATE_INFO,
                p_next: ptr::null(),
                pool: cmd_pool,
                level: CMD_LEVEL_PRIMARY,
                count: 1,
            };
            let mut cmd: VkCommandBuffer = ptr::null_mut();
            vk_ok("alloc-cmd", unsafe {
                (f.allocate_command_buffers)(self.dev, &cai, &mut cmd)
            })?;
            let bi = VkCmdBeginInfo {
                s_type: STYPE_COMMAND_BUFFER_BEGIN_INFO,
                p_next: ptr::null(),
                flags: 1, // ONE_TIME_SUBMIT
                p_inheritance_info: ptr::null(),
            };
            vk_ok("begin-cmd", unsafe { (f.begin_command_buffer)(cmd, &bi) })?;
            unsafe { (f.cmd_bind_pipeline)(cmd, BIND_COMPUTE, pipeline) };
            unsafe {
                (f.cmd_bind_descriptor_sets)(cmd, BIND_COMPUTE, pipe_layout, 0, 1, &set, 0, ptr::null())
            };
            unsafe { (f.cmd_dispatch)(cmd, groups, 1, 1) };
            vk_ok("end-cmd", unsafe { (f.end_command_buffer)(cmd) })?;
            let fci = VkFenceCreateInfo { s_type: STYPE_FENCE_CREATE_INFO, p_next: ptr::null(), flags: 0 };
            let mut fence: VkFence = 0;
            vk_ok("fence", unsafe { (f.create_fence)(self.dev, &fci, ptr::null(), &mut fence) })?;
            let si = VkSubmitInfo {
                s_type: STYPE_SUBMIT_INFO,
                p_next: ptr::null(),
                wait_count: 0,
                p_wait_sems: ptr::null(),
                p_wait_masks: ptr::null(),
                cmd_count: 1,
                p_cmds: &cmd,
                signal_count: 0,
                p_signal_sems: ptr::null(),
            };
            vk_ok("submit", unsafe { (f.queue_submit)(self.queue, 1, &si, fence) })?;
            // 30 s fence (lavapipe software rendering can be slow).
            vk_ok("wait-fence", unsafe {
                (f.wait_for_fences)(self.dev, 1, &fence, 1, 30_000_000_000)
            })?;
            let out = self.read_mem(out_mem, out_len.max(1))?;
            unsafe { (f.destroy_fence)(self.dev, fence, ptr::null()) };
            unsafe { (f.destroy_command_pool)(self.dev, cmd_pool, ptr::null()) };
            unsafe { (f.destroy_descriptor_pool)(self.dev, pool, ptr::null()) };
            unsafe { (f.destroy_pipeline)(self.dev, pipeline, ptr::null()) };
            unsafe { (f.destroy_shader_module)(self.dev, module, ptr::null()) };
            unsafe { (f.destroy_pipeline_layout)(self.dev, pipe_layout, ptr::null()) };
            unsafe { (f.destroy_descriptor_set_layout)(self.dev, set_layout, ptr::null()) };
            Ok(out)
        })();
        unsafe { (f.destroy_buffer)(self.dev, in_buf, ptr::null()) };
        unsafe { (f.free_memory)(self.dev, in_mem, ptr::null()) };
        unsafe { (f.destroy_buffer)(self.dev, out_buf, ptr::null()) };
        unsafe { (f.free_memory)(self.dev, out_mem, ptr::null()) };
        result
    }

    fn queue_family(&self) -> u32 {
        self.family
    }
}

impl Drop for ComputeRunner {
    fn drop(&mut self) {
        unsafe { (self.dev_fns.destroy_device)(self.dev, ptr::null()) };
        let destroy: unsafe extern "C" fn(VkInstance, *const c_void) -> () =
            ifn(&self.vk, self.inst, "vkDestroyInstance");
        unsafe { destroy(self.inst, ptr::null()) };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// FFI layout contract: struct sizes must equal the C ABI
    /// (`vulkan_core.h`, verified with gcc `sizeof`). A wrong size here
    /// smashes the stack across the call boundary (the lavapipe SEGV
    /// during development was a doubled manual pad).
    #[test]
    fn struct_layouts_match_c_abi() {
        assert_eq!(std::mem::size_of::<VkMemoryProps>(), 520);
        assert_eq!(std::mem::size_of::<VkQueueFamilyProps>(), 24);
        assert_eq!(std::mem::size_of::<VkBufferCreateInfo>(), 56);
        assert_eq!(std::mem::size_of::<VkMemoryReq>(), 24);
        assert_eq!(std::mem::size_of::<VkMemoryAllocInfo>(), 32);
        assert_eq!(std::mem::size_of::<VkSetLayoutCreateInfo>(), 32);
        assert_eq!(std::mem::size_of::<VkPipelineLayoutCreateInfo>(), 48);
        assert_eq!(std::mem::size_of::<VkShaderStageInfo>(), 48);
        assert_eq!(std::mem::size_of::<VkComputePipelineCreateInfo>(), 96);
        assert_eq!(std::mem::size_of::<VkPoolCreateInfo>(), 40);
        assert_eq!(std::mem::size_of::<VkSetAllocInfo>(), 40);
        assert_eq!(std::mem::size_of::<VkWriteSet>(), 64);
        assert_eq!(std::mem::size_of::<VkCmdPoolCreateInfo>(), 24);
        assert_eq!(std::mem::size_of::<VkCmdAllocInfo>(), 32);
        assert_eq!(std::mem::size_of::<VkCmdBeginInfo>(), 32);
        assert_eq!(std::mem::size_of::<VkSubmitInfo>(), 72);
        assert_eq!(std::mem::size_of::<VkFenceCreateInfo>(), 24);
    }

    #[test]
    fn loader_detects_lavapipe() {
        if Vk::load().is_err() {
            eprintln!("SKIP: no Vulkan loader");
            return;
        }
        // Lavapipe is software: detection must succeed on any box with
        // an ICD, without touching a real GPU.
        assert!(has_compute_device(), "loader present but no compute device");
    }
}
