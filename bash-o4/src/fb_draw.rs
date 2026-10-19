//! fb_draw — offscreen graphics dispatch for the fb0 fragment leg.
//!
//! ## Need
//!
//! `fb_frag` emits static GLSL450 vertex+fragment pairs for the
//! `/dev/fb0/blocks` and `/dev/fb0/overlay` verbs, but nothing
//! dispatched them: `vkffi` binds only the compute subset, and the
//! `_sh_gpu_*` host split in `docs/BASH-O4.md` §4.4 is specified but
//! unbuilt. This module is the host half for the fragment leg: an
//! offscreen render pass (color + depth, no surface, no swapchain)
//! that draws the `blocks` and `overlay` pipelines into images and
//! reads the pixels back to the host.
//!
//! ## What it does per frame
//!
//! ```text
//! blocks   CubeRec SSBO + atlas sampler → color+depth images
//! overlay  OvRec SSBO (+ same atlas)   → color image (src-alpha blend)
//! readback color image → RGBA8 host pixels
//! ```
//!
//! Push constants (`cam0/cam1/cfg`), descriptor bindings (0 = blocks
//! SSBO, 1 = atlas `sampler2DArray`, 2 = overlay SSBO), and the crack-
//! in-atlas-layer-9 rule all follow `fb_frag`'s contract exactly.
//!
//! ## What it does NOT do
//!
//! Presentation (no swapchain — `fb_present` in `fbdev.c` owns the
//! window/mmap/PPM backends), texture upload from game assets (the
//! caller supplies atlas texels), payload parsing (the caller packs
//! `CubeRec`/`OvRec` records), or the C-backend `_sh_gpu_*` call-site
//! emission (still M3-remaining). Host-visible coherent memory
//! throughout (v1 — device-local + staging is P3, same as compute).

use std::ffi::{c_void, CString};
use std::ptr;

use crate::vkffi::{
    self, OpenDevice, VkBuffer, VkCommandBuffer, VkCommandPool, VkDescriptorPool, VkDescriptorSet,
    VkDescriptorSetLayout, VkDevice, VkDeviceMemory, VkFence, VkPipeline, VkPipelineLayout,
    VkQueue, VkResult, VkShaderModule, VkShaderModuleCreateInfo,
};

// ---- local handles ----------------------------------------------------

type VkImage = u64;
type VkImageView = u64;
type VkSampler = u64;
type VkRenderPass = u64;
type VkFramebuffer = u64;

// ---- sType values (vulkan_core.h, verified by /tmp/vk_sizes) ----------

const STYPE_IMAGE_CREATE_INFO: u32 = 14;
const STYPE_IMAGE_VIEW_CREATE_INFO: u32 = 15;
const STYPE_SHADER_STAGE_CREATE_INFO: u32 = 18;
const STYPE_VERTEX_INPUT_CREATE_INFO: u32 = 19;
const STYPE_INPUT_ASSEMBLY_CREATE_INFO: u32 = 20;
const STYPE_VIEWPORT_CREATE_INFO: u32 = 22;
const STYPE_RASTER_CREATE_INFO: u32 = 23;
const STYPE_MULTISAMPLE_CREATE_INFO: u32 = 24;
const STYPE_DEPTH_STENCIL_CREATE_INFO: u32 = 25;
const STYPE_COLOR_BLEND_CREATE_INFO: u32 = 26;
const STYPE_GRAPHICS_PIPELINE_CREATE_INFO: u32 = 28;
const STYPE_SAMPLER_CREATE_INFO: u32 = 31;
const STYPE_FRAMEBUFFER_CREATE_INFO: u32 = 37;
const STYPE_RENDER_PASS_CREATE_INFO: u32 = 38;
const STYPE_RENDER_PASS_BEGIN_INFO: u32 = 43;
const STYPE_IMAGE_BARRIER: u32 = 45;

// ---- enums (vulkan_core.h) --------------------------------------------

use crate::vkffi::QUEUE_GRAPHICS_BIT;
const FORMAT_RGBA8: u32 = 37; // VK_FORMAT_R8G8B8A8_UNORM
const FORMAT_D32: u32 = 126; // VK_FORMAT_D32_SFLOAT
const IMAGE_TYPE_2D: u32 = 1;
const VIEW_TYPE_2D: u32 = 1;
const VIEW_TYPE_2D_ARRAY: u32 = 5;
const TILING_OPTIMAL: u32 = 0;
const SHARING_EXCLUSIVE: u32 = 0;
const LAYOUT_UNDEFINED: u32 = 0;
const LAYOUT_COLOR_OPTIMAL: u32 = 2;
const LAYOUT_DEPTH_OPTIMAL: u32 = 3;
const LAYOUT_TRANSFER_SRC: u32 = 6;
const LAYOUT_READ_ONLY: u32 = 5;
const LAYOUT_TRANSFER_DST: u32 = 7;
const ASPECT_COLOR: u32 = 1;
const ASPECT_DEPTH: u32 = 2;
const USAGE_TRANSFER_SRC: u32 = 1;
const USAGE_TRANSFER_DST: u32 = 2;
const USAGE_SAMPLED: u32 = 4;
const USAGE_COLOR_ATTACH: u32 = 16;
const USAGE_DEPTH_ATTACH: u32 = 32;
const BUFFER_USAGE_TRANSFER_DST: u32 = 2;
const BUFFER_USAGE_STORAGE: u32 = 0x20;
// NOTE: lavapipe reports HOST_VISIBLE=2/COHERENT=4 (vulkan_core.h), NOT
// 1/2. vkffi.rs hardcodes 1/2, which happens to select nothing on
// lavapipe's types... yet compute works because lavapipe's type 0
// carries flags 15 (all bits). Do NOT copy vkffi's constants: use the
// header values below (verified by /tmp/vk_sizes ENUM dump).
const MEM_HOST_VISIBLE_BIT: u32 = 2;
const MEM_HOST_COHERENT_BIT: u32 = 4;
const DESC_STORAGE_BUFFER: u32 = 7;
const DESC_COMBINED_SAMPLER: u32 = 1;
const STAGE_VERTEX: u32 = 0x1;
const STAGE_FRAGMENT: u32 = 0x10;
const BIND_GRAPHICS: u32 = 0;
const TOPO_TRIANGLE_LIST: u32 = 3;
const POLYGON_FILL: u32 = 0;
const CULL_NONE: u32 = 0;
const FRONT_CCW: u32 = 0;
const COMPARE_LESS: u32 = 1;
const LOAD_CLEAR: u32 = 1;
const LOAD_DONT_CARE: u32 = 2;
const STORE_STORE: u32 = 0;
const STORE_DONT_CARE: u32 = 1;
const BLEND_SRC_ALPHA: u32 = 6;
const BLEND_ONE_MINUS_SRC_ALPHA: u32 = 7;
const BLEND_ONE: u32 = 1;
const BLEND_ZERO: u32 = 0;
const BLEND_ADD: u32 = 0;
const COLOR_R_BIT: u32 = 1;
const COLOR_G_BIT: u32 = 2;
const COLOR_B_BIT: u32 = 4;
const COLOR_A_BIT: u32 = 8;
const FILTER_NEAREST: u32 = 0;
const MIPMAP_NEAREST: u32 = 0;
const ADDRESS_CLAMP: u32 = 2;
const ACCESS_COLOR_WRITE: u32 = 256;
const ACCESS_DEPTH_WRITE: u32 = 1024;
const ACCESS_TRANSFER_READ: u32 = 2048;
const ACCESS_TRANSFER_WRITE: u32 = 4096;
const ACCESS_SHADER_READ: u32 = 32;
const STAGE_TOP: u32 = 1;
const STAGE_COLOR_OUTPUT: u32 = 1024;
const STAGE_TRANSFER: u32 = 4096;
const STAGE_FRAG_SHADER: u32 = 128;
const SUBPASS_EXTERNAL: i32 = -1;
const CONTENTS_INLINE: u32 = 0;
const CMD_ONE_TIME: u32 = 1;
const SWIZZLE_IDENTITY: u32 = 0;

// ---- structs (C layout, sizes verified by /tmp/vk_sizes) --------------

#[repr(C)]
struct VkExtent2D {
    width: u32,
    height: u32,
}

#[repr(C)]
struct VkExtent3D {
    width: u32,
    height: u32,
    depth: u32,
}

#[repr(C)]
struct VkOffset3D {
    x: i32,
    y: i32,
    z: i32,
}

#[repr(C)]
struct VkImageSubLayers {
    aspect_mask: u32,
    mip_level: u32,
    base_array_layer: u32,
    layer_count: u32,
} // 16

#[repr(C)]
struct VkImageCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    image_type: u32,
    format: u32,
    extent: VkExtent3D,
    mip_levels: u32,
    array_layers: u32,
    samples: u32,
    tiling: u32,
    usage: u32,
    sharing_mode: u32,
    queue_family_index_count: u32,
    p_queue_family_indices: *const u32,
    initial_layout: u32,
} // 88

#[repr(C)]
struct VkComponentMapping {
    r: u32,
    g: u32,
    b: u32,
    a: u32,
} // 16

#[repr(C)]
#[derive(Clone, Copy)]
struct VkImageSubRange {
    aspect_mask: u32,
    base_mip_level: u32,
    level_count: u32,
    base_array_layer: u32,
    layer_count: u32,
} // 20

#[repr(C)]
struct VkImageViewCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    image: VkImage,
    view_type: u32,
    format: u32,
    components: VkComponentMapping,
    subresource_range: VkImageSubRange,
} // 80

#[repr(C)]
struct VkSamplerCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    mag_filter: u32,
    min_filter: u32,
    mipmap_mode: u32,
    address_u: u32,
    address_v: u32,
    address_w: u32,
    mip_lod_bias: f32,
    anisotropy_enable: u32,
    max_anisotropy: f32,
    compare_enable: u32,
    compare_op: u32,
    min_lod: f32,
    max_lod: f32,
    border_color: u32,
    unnormalized_coordinates: u32,
} // 80

#[repr(C)]
struct VkAttachmentDesc {
    flags: u32,
    format: u32,
    samples: u32,
    load_op: u32,
    store_op: u32,
    stencil_load_op: u32,
    stencil_store_op: u32,
    initial_layout: u32,
    final_layout: u32,
} // 36

#[repr(C)]
struct VkAttachmentRef {
    attachment: u32,
    layout: u32,
} // 8

#[repr(C)]
struct VkSubpassDesc {
    flags: u32,
    pipeline_bind_point: u32,
    input_attachment_count: u32,
    p_input_attachments: *const VkAttachmentRef,
    color_attachment_count: u32,
    p_color_attachments: *const VkAttachmentRef,
    p_resolve_attachments: *const VkAttachmentRef,
    p_depth_stencil_attachment: *const VkAttachmentRef,
    preserve_attachment_count: u32,
    p_preserve_attachments: *const u32,
} // 72

#[repr(C)]
struct VkSubpassDep {
    src_subpass: u32,
    dst_subpass: u32,
    src_stage_mask: u32,
    dst_stage_mask: u32,
    src_access_mask: u32,
    dst_access_mask: u32,
    dependency_flags: u32,
} // 28

#[repr(C)]
struct VkRenderPassCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    attachment_count: u32,
    p_attachments: *const VkAttachmentDesc,
    subpass_count: u32,
    p_subpasses: *const VkSubpassDesc,
    dependency_count: u32,
    p_dependencies: *const VkSubpassDep,
} // 64

#[repr(C)]
struct VkFramebufferCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    render_pass: VkRenderPass,
    attachment_count: u32,
    p_attachments: *const VkImageView,
    width: u32,
    height: u32,
    layers: u32,
} // 64

#[repr(C)]
struct VkVertexInputCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    binding_count: u32,
    p_bindings: *const c_void,
    attribute_count: u32,
    p_attributes: *const c_void,
} // 48

#[repr(C)]
struct VkInputAssemblyCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    topology: u32,
    primitive_restart_enable: u32,
} // 32

#[repr(C)]
struct VkViewport {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
} // 24

#[repr(C)]
struct VkOffset2D {
    x: i32,
    y: i32,
} // 8

#[repr(C)]
struct VkRect2D {
    offset: VkOffset2D,
    extent: VkExtent2D,
} // 16

#[repr(C)]
struct VkViewportCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    viewport_count: u32,
    p_viewports: *const VkViewport,
    scissor_count: u32,
    p_scissors: *const VkRect2D,
} // 48

#[repr(C)]
struct VkRasterCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    depth_clamp_enable: u32,
    rasterizer_discard_enable: u32,
    polygon_mode: u32,
    cull_mode: u32,
    front_face: u32,
    depth_bias_enable: u32,
    depth_bias_constant_factor: f32,
    depth_bias_clamp: f32,
    depth_bias_slope_factor: f32,
    line_width: f32,
} // 64

#[repr(C)]
struct VkMultisampleCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    rasterization_samples: u32,
    sample_shading_enable: u32,
    min_sample_shading: f32,
    p_sample_mask: *const u32,
    alpha_to_coverage_enable: u32,
    alpha_to_one_enable: u32,
} // 48

#[repr(C)]
#[derive(Clone, Copy)]
struct VkStencilOpState {
    fail_op: u32,
    pass_op: u32,
    depth_fail_op: u32,
    compare_op: u32,
    compare_mask: u32,
    write_mask: u32,
    reference: u32,
} // 28

#[repr(C)]
struct VkDepthStencilCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    depth_test_enable: u32,
    depth_write_enable: u32,
    depth_compare_op: u32,
    depth_bounds_test_enable: u32,
    stencil_test_enable: u32,
    front: VkStencilOpState,
    back: VkStencilOpState,
    min_depth_bounds: f32,
    max_depth_bounds: f32,
} // 104

#[repr(C)]
struct VkBlendAttachment {
    blend_enable: u32,
    src_color_blend_factor: u32,
    dst_color_blend_factor: u32,
    color_blend_op: u32,
    src_alpha_blend_factor: u32,
    dst_alpha_blend_factor: u32,
    alpha_blend_op: u32,
    color_write_mask: u32,
} // 32

#[repr(C)]
struct VkColorBlendCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    logic_op_enable: u32,
    logic_op: u32,
    attachment_count: u32,
    p_attachments: *const VkBlendAttachment,
    blend_constants: [f32; 4],
} // 56

#[repr(C)]
struct VkPushRange {
    stage_flags: u32,
    offset: u32,
    size: u32,
} // 12

#[repr(C)]
struct VkStageInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    stage: u32,
    module: VkShaderModule,
    p_name: *const std::ffi::c_char,
    p_specialization_info: *const c_void,
} // 48

#[repr(C)]
struct VkGraphicsPipelineCreateInfo {
    s_type: u32,
    p_next: *const c_void,
    flags: u32,
    stage_count: u32,
    p_stages: *const VkStageInfo,
    p_vertex_input_state: *const VkVertexInputCreateInfo,
    p_input_assembly_state: *const VkInputAssemblyCreateInfo,
    p_tessellation_state: *const c_void,
    p_viewport_state: *const VkViewportCreateInfo,
    p_rasterization_state: *const VkRasterCreateInfo,
    p_multisample_state: *const VkMultisampleCreateInfo,
    p_depth_stencil_state: *const VkDepthStencilCreateInfo,
    p_color_blend_state: *const VkColorBlendCreateInfo,
    p_dynamic_state: *const c_void,
    layout: VkPipelineLayout,
    render_pass: VkRenderPass,
    subpass: u32,
    base_handle: VkPipeline,
    base_index: i32,
} // 144

#[repr(C)]
struct VkClearValue {
    color: [f32; 4],
} // 16 (union — color float[4] covers depth/stencil use)

#[repr(C)]
struct VkRenderPassBeginInfo {
    s_type: u32,
    p_next: *const c_void,
    render_pass: VkRenderPass,
    framebuffer: VkFramebuffer,
    render_area: VkRect2D,
    clear_value_count: u32,
    p_clear_values: *const VkClearValue,
} // 64

#[repr(C)]
struct VkImageBarrier {
    s_type: u32,
    p_next: *const c_void,
    src_access_mask: u32,
    dst_access_mask: u32,
    old_layout: u32,
    new_layout: u32,
    src_queue_family_index: u32,
    dst_queue_family_index: u32,
    image: VkImage,
    subresource_range: VkImageSubRange,
} // 72

#[repr(C)]
struct VkBufferImageCopy {
    buffer_offset: u64,
    buffer_row_length: u32,
    buffer_image_height: u32,
    image_subresource: VkImageSubLayers,
    image_offset: VkOffset3D,
    image_extent: VkExtent3D,
} // 56

#[repr(C)]
struct VkDescriptorImageInfo {
    sampler: VkSampler,
    image_view: VkImageView,
    image_layout: u32,
} // 24

fn vk_ok(what: &str, rc: VkResult) -> Result<(), String> {
    if rc == vkffi::VK_SUCCESS {
        Ok(())
    } else {
        Err(format!("vulkan {what} failed: rc={rc}"))
    }
}

// ---- device function table (graphics subset) --------------------------

/// Device function table (graphics subset). `destroy_device` /
/// `destroy_descriptor_pool` are resolved but never called: tearing
/// them down segfaults lavapipe (see Drop) — the `allow` records the
/// decision, not an oversight.
#[derive(Clone, Copy)]
#[allow(dead_code)]
struct GfxFns {
    create_shader_module: unsafe extern "C" fn(
        VkDevice,
        *const VkShaderModuleCreateInfo,
        *const c_void,
        *mut VkShaderModule,
    ) -> VkResult,
    destroy_shader_module: unsafe extern "C" fn(VkDevice, VkShaderModule, *const c_void) -> (),
    create_descriptor_set_layout: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkSetLayoutCreateInfo,
        *const c_void,
        *mut VkDescriptorSetLayout,
    ) -> VkResult,
    destroy_descriptor_set_layout:
        unsafe extern "C" fn(VkDevice, VkDescriptorSetLayout, *const c_void) -> (),
    create_pipeline_layout: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkPipelineLayoutCreateInfo,
        *const c_void,
        *mut VkPipelineLayout,
    ) -> VkResult,
    destroy_pipeline_layout: unsafe extern "C" fn(VkDevice, VkPipelineLayout, *const c_void) -> (),
    create_graphics_pipelines: unsafe extern "C" fn(
        VkDevice,
        VkPipeline,
        u32,
        *const VkGraphicsPipelineCreateInfo,
        *const c_void,
        *mut VkPipeline,
    ) -> VkResult,
    destroy_pipeline: unsafe extern "C" fn(VkDevice, VkPipeline, *const c_void) -> (),
    create_render_pass: unsafe extern "C" fn(
        VkDevice,
        *const VkRenderPassCreateInfo,
        *const c_void,
        *mut VkRenderPass,
    ) -> VkResult,
    destroy_render_pass: unsafe extern "C" fn(VkDevice, VkRenderPass, *const c_void) -> (),
    create_framebuffer: unsafe extern "C" fn(
        VkDevice,
        *const VkFramebufferCreateInfo,
        *const c_void,
        *mut VkFramebuffer,
    ) -> VkResult,
    destroy_framebuffer: unsafe extern "C" fn(VkDevice, VkFramebuffer, *const c_void) -> (),
    create_image: unsafe extern "C" fn(
        VkDevice,
        *const VkImageCreateInfo,
        *const c_void,
        *mut VkImage,
    ) -> VkResult,
    destroy_image: unsafe extern "C" fn(VkDevice, VkImage, *const c_void) -> (),
    get_image_memory_requirements:
        unsafe extern "C" fn(VkDevice, VkImage, *mut vkffi::VkMemoryReq) -> (),
    create_image_view: unsafe extern "C" fn(
        VkDevice,
        *const VkImageViewCreateInfo,
        *const c_void,
        *mut VkImageView,
    ) -> VkResult,
    destroy_image_view: unsafe extern "C" fn(VkDevice, VkImageView, *const c_void) -> (),
    create_sampler: unsafe extern "C" fn(
        VkDevice,
        *const VkSamplerCreateInfo,
        *const c_void,
        *mut VkSampler,
    ) -> VkResult,
    destroy_sampler: unsafe extern "C" fn(VkDevice, VkSampler, *const c_void) -> (),
    create_buffer: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkBufferCreateInfo,
        *const c_void,
        *mut VkBuffer,
    ) -> VkResult,
    get_buffer_memory_requirements:
        unsafe extern "C" fn(VkDevice, VkBuffer, *mut vkffi::VkMemoryReq) -> (),
    allocate_memory: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkMemoryAllocInfo,
        *const c_void,
        *mut VkDeviceMemory,
    ) -> VkResult,
    bind_buffer_memory: unsafe extern "C" fn(VkDevice, VkBuffer, VkDeviceMemory, u64) -> VkResult,
    bind_image_memory: unsafe extern "C" fn(VkDevice, VkImage, VkDeviceMemory, u64) -> VkResult,
    map_memory:
        unsafe extern "C" fn(VkDevice, VkDeviceMemory, u64, u64, u32, *mut *mut c_void) -> VkResult,
    unmap_memory: unsafe extern "C" fn(VkDevice, VkDeviceMemory) -> (),
    free_memory: unsafe extern "C" fn(VkDevice, VkDeviceMemory, *const c_void) -> (),
    destroy_buffer: unsafe extern "C" fn(VkDevice, VkBuffer, *const c_void) -> (),
    create_descriptor_pool: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkPoolCreateInfo,
        *const c_void,
        *mut VkDescriptorPool,
    ) -> VkResult,
    destroy_descriptor_pool: unsafe extern "C" fn(VkDevice, VkDescriptorPool, *const c_void) -> (),
    allocate_descriptor_sets: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkSetAllocInfo,
        *mut VkDescriptorSet,
    ) -> VkResult,
    update_descriptor_sets:
        unsafe extern "C" fn(VkDevice, u32, *const vkffi::VkWriteSet, u32, *const c_void) -> (),
    create_command_pool: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkCmdPoolCreateInfo,
        *const c_void,
        *mut VkCommandPool,
    ) -> VkResult,
    destroy_command_pool: unsafe extern "C" fn(VkDevice, VkCommandPool, *const c_void) -> (),
    allocate_command_buffers: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkCmdAllocInfo,
        *mut VkCommandBuffer,
    ) -> VkResult,
    begin_command_buffer:
        unsafe extern "C" fn(VkCommandBuffer, *const vkffi::VkCmdBeginInfo) -> VkResult,
    cmd_begin_render_pass:
        unsafe extern "C" fn(VkCommandBuffer, *const VkRenderPassBeginInfo, u32) -> (),
    cmd_end_render_pass: unsafe extern "C" fn(VkCommandBuffer) -> (),
    cmd_bind_pipeline: unsafe extern "C" fn(VkCommandBuffer, u32, VkPipeline) -> (),
    cmd_bind_descriptor_sets: unsafe extern "C" fn(
        VkCommandBuffer,
        u32,
        VkPipelineLayout,
        u32,
        u32,
        *const VkDescriptorSet,
        u32,
        *const u32,
    ) -> (),
    cmd_push_constants:
        unsafe extern "C" fn(VkCommandBuffer, VkPipelineLayout, u32, u32, u32, *const c_void) -> (),
    cmd_draw: unsafe extern "C" fn(VkCommandBuffer, u32, u32, u32, u32) -> (),
    cmd_pipeline_barrier: unsafe extern "C" fn(
        VkCommandBuffer,
        u32,
        u32,
        u32,
        u32,
        *const c_void,
        u32,
        *const c_void,
        u32,
        *const VkImageBarrier,
    ) -> (),
    cmd_copy_image_to_buffer: unsafe extern "C" fn(
        VkCommandBuffer,
        VkImage,
        u32,
        VkBuffer,
        u32,
        *const VkBufferImageCopy,
    ) -> (),
    cmd_copy_buffer_to_image: unsafe extern "C" fn(
        VkCommandBuffer,
        VkBuffer,
        VkImage,
        u32,
        u32,
        *const VkBufferImageCopy,
    ) -> (),
    end_command_buffer: unsafe extern "C" fn(VkCommandBuffer) -> VkResult,
    reset_command_buffer: unsafe extern "C" fn(VkCommandBuffer, u32) -> VkResult,
    create_fence: unsafe extern "C" fn(
        VkDevice,
        *const vkffi::VkFenceCreateInfo,
        *const c_void,
        *mut VkFence,
    ) -> VkResult,
    destroy_fence: unsafe extern "C" fn(VkDevice, VkFence, *const c_void) -> (),
    queue_submit:
        unsafe extern "C" fn(VkQueue, u32, *const vkffi::VkSubmitInfo, VkFence) -> VkResult,
    wait_for_fences: unsafe extern "C" fn(VkDevice, u32, *const VkFence, u32, u64) -> VkResult,
    destroy_device: unsafe extern "C" fn(VkDevice, *const c_void) -> (),
}

// ---- push-constant block (fb_frag contract: cam0/cam1/cfg) -------------

/// 12 words = vec4 cam0 + vec4 cam1 + ivec4 cfg, matching
/// `fb_frag::push_constants_glsl` word for word.
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct PushConstants {
    pub cam0: [f32; 4], // xyz, cos(yaw_deg)
    pub cam1: [f32; 4], // sin(yaw), shift, view_w, view_h
    pub cfg: [i32; 4],  // flags bit0 crt, bit1 corrupt; spare, spare
}

/// One `vec4` = 16 bytes; CubeRec = 3 vec4s = 12 f32s
/// (x,y,z,sx)(sy,sz,r,g)(b,tx,dam,pad).
pub const CUBE_REC_WORDS: usize = 12;
/// OvRec = 3 vec4s = 12 f32s (g=cx,cy,wfrac,hfrac)(c=r,g,b,a)(d=rot,0,0,0).
pub const OV_REC_WORDS: usize = 12;

// ---- the runner -------------------------------------------------------

/// Offscreen rasterizer for the fb0 fragment leg.
///
/// Owns a graphics device + a W×H color+depth target. `draw_blocks`
/// and `draw_overlay` compile the `fb_frag` pair for that verb once
/// (cached per (SPIR-V bytes, pipeline kind)), upload records +
/// atlas + push constants, render, and leave the pixels in the color
/// image; `readback` copies them to host RGBA8.
pub struct RasterRunner {
    od: OpenDevice,
    gf: GfxFns,
    width: u32,
    height: u32,
    color_img: VkImage,
    color_mem: VkDeviceMemory,
    color_view: VkImageView,
    depth_img: VkImage,
    depth_mem: VkDeviceMemory,
    depth_view: VkImageView,
    sampler: VkSampler,
    render_pass: VkRenderPass,
    framebuffer: VkFramebuffer,
    cmd_pool: VkCommandPool,
    cmd: VkCommandBuffer,
    blocks_pipe: Option<CompiledPipe>,
    overlay_pipe: Option<CompiledPipe>,
    /// Cached LOAD render pass + framebuffer for the overlay path
    /// (created on first overlay, destroyed in Drop — per-pass
    /// create/destroy segfaults lavapipe; see record_overlay_pass).
    load_rp: Option<VkRenderPass>,
    load_fb: Option<VkFramebuffer>,
    /// Atlas images uploaded via `upload_atlas` (image + memory +
    /// view), freed in Drop. v1: the runner owns every atlas it
    /// uploads — no cross-runner sharing.
    atlases: Vec<(VkImage, VkDeviceMemory, VkImageView)>,
}

/// Everything the driver COMPILES per pipeline (modules + layouts +
/// pipeline + pool + set). Per-frame work stays buffers + descriptor
/// writes + re-record + submit (same split as the compute runner).
struct CompiledPipe {
    hash: u64,
    vert: VkShaderModule,
    frag: VkShaderModule,
    set_layout: VkDescriptorSetLayout,
    pipe_layout: VkPipelineLayout,
    pipeline: VkPipeline,
    pool: VkDescriptorPool,
    set: VkDescriptorSet,
}

impl RasterRunner {
    /// Open a graphics device (lavapipe honors VK_ICD_FILENAMES via
    /// the loader) and build a `width`×`height` offscreen target.
    pub fn new(width: u32, height: u32) -> Result<Self, String> {
        if width == 0 || height == 0 || width > 4096 || height > 4096 {
            return Err(format!("bad raster size {width}x{height}"));
        }
        let od = vkffi::open_queue_device(QUEUE_GRAPHICS_BIT, "graphics")?;
        let gf: GfxFns = {
            macro_rules! d {
                ($n:literal) => {
                    od.vk.dproc(od.inst, od.dev, $n)
                };
            }
            GfxFns {
                create_shader_module: d!("vkCreateShaderModule"),
                destroy_shader_module: d!("vkDestroyShaderModule"),
                create_descriptor_set_layout: d!("vkCreateDescriptorSetLayout"),
                destroy_descriptor_set_layout: d!("vkDestroyDescriptorSetLayout"),
                create_pipeline_layout: d!("vkCreatePipelineLayout"),
                destroy_pipeline_layout: d!("vkDestroyPipelineLayout"),
                create_graphics_pipelines: d!("vkCreateGraphicsPipelines"),
                destroy_pipeline: d!("vkDestroyPipeline"),
                create_render_pass: d!("vkCreateRenderPass"),
                destroy_render_pass: d!("vkDestroyRenderPass"),
                create_framebuffer: d!("vkCreateFramebuffer"),
                destroy_framebuffer: d!("vkDestroyFramebuffer"),
                create_image: d!("vkCreateImage"),
                destroy_image: d!("vkDestroyImage"),
                get_image_memory_requirements: d!("vkGetImageMemoryRequirements"),
                create_image_view: d!("vkCreateImageView"),
                destroy_image_view: d!("vkDestroyImageView"),
                create_sampler: d!("vkCreateSampler"),
                destroy_sampler: d!("vkDestroySampler"),
                create_buffer: d!("vkCreateBuffer"),
                get_buffer_memory_requirements: d!("vkGetBufferMemoryRequirements"),
                allocate_memory: d!("vkAllocateMemory"),
                bind_buffer_memory: d!("vkBindBufferMemory"),
                bind_image_memory: d!("vkBindImageMemory"),
                map_memory: d!("vkMapMemory"),
                unmap_memory: d!("vkUnmapMemory"),
                free_memory: d!("vkFreeMemory"),
                destroy_buffer: d!("vkDestroyBuffer"),
                create_descriptor_pool: d!("vkCreateDescriptorPool"),
                destroy_descriptor_pool: d!("vkDestroyDescriptorPool"),
                allocate_descriptor_sets: d!("vkAllocateDescriptorSets"),
                update_descriptor_sets: d!("vkUpdateDescriptorSets"),
                create_command_pool: d!("vkCreateCommandPool"),
                destroy_command_pool: d!("vkDestroyCommandPool"),
                allocate_command_buffers: d!("vkAllocateCommandBuffers"),
                begin_command_buffer: d!("vkBeginCommandBuffer"),
                cmd_begin_render_pass: d!("vkCmdBeginRenderPass"),
                cmd_end_render_pass: d!("vkCmdEndRenderPass"),
                cmd_bind_pipeline: d!("vkCmdBindPipeline"),
                cmd_bind_descriptor_sets: d!("vkCmdBindDescriptorSets"),
                cmd_push_constants: d!("vkCmdPushConstants"),
                cmd_draw: d!("vkCmdDraw"),
                cmd_pipeline_barrier: d!("vkCmdPipelineBarrier"),
                cmd_copy_image_to_buffer: d!("vkCmdCopyImageToBuffer"),
                cmd_copy_buffer_to_image: d!("vkCmdCopyBufferToImage"),
                end_command_buffer: d!("vkEndCommandBuffer"),
                reset_command_buffer: d!("vkResetCommandBuffer"),
                create_fence: d!("vkCreateFence"),
                destroy_fence: d!("vkDestroyFence"),
                queue_submit: d!("vkQueueSubmit"),
                wait_for_fences: d!("vkWaitForFences"),
                destroy_device: d!("vkDestroyDevice"),
            }
        };
        let mut r = RasterRunner {
            od,
            gf,
            width,
            height,
            color_img: 0,
            color_mem: 0,
            color_view: 0,
            depth_img: 0,
            depth_mem: 0,
            depth_view: 0,
            sampler: 0,
            render_pass: 0,
            framebuffer: 0,
            cmd_pool: 0,
            cmd: ptr::null_mut(),
            blocks_pipe: None,
            overlay_pipe: None,
            load_rp: None,
            load_fb: None,
            atlases: Vec::new(),
        };
        r.build_target()?;
        Ok(r)
    }

    fn dev(&self) -> VkDevice {
        self.od.dev
    }

    fn mem_type(&self, bits: u32) -> Result<u32, String> {
        for i in 0..self.od.mem_props.type_count {
            let t = &self.od.mem_props.types[i as usize];
            if bits & (1 << i) != 0
                && t.property_flags & (MEM_HOST_VISIBLE_BIT | MEM_HOST_COHERENT_BIT)
                    == (MEM_HOST_VISIBLE_BIT | MEM_HOST_COHERENT_BIT)
            {
                return Ok(i);
            }
        }
        Err("no host-visible coherent memory type".to_string())
    }

    /// Color + depth images, views, sampler, render pass, framebuffer,
    /// command pool/buffer. All host-visible (v1 — no staging).
    fn build_target(&mut self) -> Result<(), String> {
        let f = &self.gf;
        let dev = self.dev();
        // Color image: RGBA8, color-attach + sampled + transfer-src.
        let (color_img, color_mem) = self.make_image(
            FORMAT_RGBA8,
            USAGE_COLOR_ATTACH | USAGE_SAMPLED | USAGE_TRANSFER_SRC,
            ASPECT_COLOR,
        )?;
        // Depth image: D32, depth-attach.
        let (depth_img, depth_mem) =
            self.make_image(FORMAT_D32, USAGE_DEPTH_ATTACH, ASPECT_DEPTH)?;
        self.color_img = color_img;
        self.color_mem = color_mem;
        self.depth_img = depth_img;
        self.depth_mem = depth_mem;
        self.color_view = self.make_view(color_img, FORMAT_RGBA8, VIEW_TYPE_2D, ASPECT_COLOR, 1)?;
        self.depth_view = self.make_view(depth_img, FORMAT_D32, VIEW_TYPE_2D, ASPECT_DEPTH, 1)?;
        // NEAREST sampler (fb_frag: "texels are byte-exact under
        // NEAREST filtering"), clamp-to-edge.
        let sci = VkSamplerCreateInfo {
            s_type: STYPE_SAMPLER_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            mag_filter: FILTER_NEAREST,
            min_filter: FILTER_NEAREST,
            mipmap_mode: MIPMAP_NEAREST,
            address_u: ADDRESS_CLAMP,
            address_v: ADDRESS_CLAMP,
            address_w: ADDRESS_CLAMP,
            mip_lod_bias: 0.0,
            anisotropy_enable: 0,
            max_anisotropy: 1.0,
            compare_enable: 0,
            compare_op: 0,
            min_lod: 0.0,
            max_lod: 0.0,
            border_color: 0,
            unnormalized_coordinates: 0,
        };
        let mut sampler: VkSampler = 0;
        vk_ok("create-sampler", unsafe {
            (f.create_sampler)(dev, &sci, ptr::null(), &mut sampler)
        })?;
        self.sampler = sampler;
        // Render pass: color (clear→present-src layout handled by
        // explicit barriers at readback) + depth (clear→dontcare).
        let color_att = VkAttachmentDesc {
            flags: 0,
            format: FORMAT_RGBA8,
            samples: 1,
            load_op: LOAD_CLEAR,
            store_op: STORE_STORE,
            stencil_load_op: LOAD_DONT_CARE,
            stencil_store_op: STORE_DONT_CARE,
            initial_layout: LAYOUT_UNDEFINED,
            final_layout: LAYOUT_COLOR_OPTIMAL,
        };
        let depth_att = VkAttachmentDesc {
            flags: 0,
            format: FORMAT_D32,
            samples: 1,
            load_op: LOAD_CLEAR,
            store_op: STORE_DONT_CARE,
            stencil_load_op: LOAD_DONT_CARE,
            stencil_store_op: STORE_DONT_CARE,
            initial_layout: LAYOUT_UNDEFINED,
            final_layout: LAYOUT_DEPTH_OPTIMAL,
        };
        let atts = [color_att, depth_att];
        let color_ref = VkAttachmentRef {
            attachment: 0,
            layout: LAYOUT_COLOR_OPTIMAL,
        };
        let depth_ref = VkAttachmentRef {
            attachment: 1,
            layout: LAYOUT_DEPTH_OPTIMAL,
        };
        let subpass = VkSubpassDesc {
            flags: 0,
            pipeline_bind_point: BIND_GRAPHICS,
            input_attachment_count: 0,
            p_input_attachments: ptr::null(),
            color_attachment_count: 1,
            p_color_attachments: &color_ref,
            p_resolve_attachments: ptr::null(),
            p_depth_stencil_attachment: &depth_ref,
            preserve_attachment_count: 0,
            p_preserve_attachments: ptr::null(),
        };
        let dep = VkSubpassDep {
            src_subpass: SUBPASS_EXTERNAL as u32,
            dst_subpass: 0,
            src_stage_mask: STAGE_COLOR_OUTPUT,
            dst_stage_mask: STAGE_COLOR_OUTPUT,
            src_access_mask: 0,
            dst_access_mask: ACCESS_COLOR_WRITE | ACCESS_DEPTH_WRITE,
            dependency_flags: 0,
        };
        let rpci = VkRenderPassCreateInfo {
            s_type: STYPE_RENDER_PASS_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            attachment_count: 2,
            p_attachments: atts.as_ptr(),
            subpass_count: 1,
            p_subpasses: &subpass,
            dependency_count: 1,
            p_dependencies: &dep,
        };
        let mut rp: VkRenderPass = 0;
        vk_ok("create-render-pass", unsafe {
            (f.create_render_pass)(dev, &rpci, ptr::null(), &mut rp)
        })?;
        self.render_pass = rp;
        let views = [self.color_view, self.depth_view];
        let fbci = VkFramebufferCreateInfo {
            s_type: STYPE_FRAMEBUFFER_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            render_pass: rp,
            attachment_count: 2,
            p_attachments: views.as_ptr(),
            width: self.width,
            height: self.height,
            layers: 1,
        };
        let mut fb: VkFramebuffer = 0;
        vk_ok("create-framebuffer", unsafe {
            (f.create_framebuffer)(dev, &fbci, ptr::null(), &mut fb)
        })?;
        self.framebuffer = fb;
        // Command pool + buffer (graphics family).
        let cpci = vkffi::VkCmdPoolCreateInfo {
            s_type: 39,
            p_next: ptr::null(),
            flags: 0,
            queue_family_index: self.od.family,
        };
        let mut pool: VkCommandPool = 0;
        vk_ok("cmd-pool", unsafe {
            (f.create_command_pool)(dev, &cpci, ptr::null(), &mut pool)
        })?;
        self.cmd_pool = pool;
        let cai = vkffi::VkCmdAllocInfo {
            s_type: 40,
            p_next: ptr::null(),
            pool,
            level: 0,
            count: 1,
        };
        let mut cmd: VkCommandBuffer = ptr::null_mut();
        vk_ok("alloc-cmd", unsafe {
            (f.allocate_command_buffers)(dev, &cai, &mut cmd)
        })?;
        self.cmd = cmd;
        Ok(())
    }

    fn make_image(
        &self,
        format: u32,
        usage: u32,
        aspect: u32,
    ) -> Result<(VkImage, VkDeviceMemory), String> {
        let _ = aspect;
        let f = &self.gf;
        let dev = self.dev();
        let ici = VkImageCreateInfo {
            s_type: STYPE_IMAGE_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            image_type: IMAGE_TYPE_2D,
            format,
            extent: VkExtent3D {
                width: self.width,
                height: self.height,
                depth: 1,
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            tiling: TILING_OPTIMAL,
            usage,
            sharing_mode: SHARING_EXCLUSIVE,
            queue_family_index_count: 0,
            p_queue_family_indices: ptr::null(),
            initial_layout: LAYOUT_UNDEFINED,
        };
        let mut img: VkImage = 0;
        vk_ok("create-image", unsafe {
            (f.create_image)(dev, &ici, ptr::null(), &mut img)
        })?;
        let mut req = vkffi::VkMemoryReq::zero();
        // VkMemoryReq fields are pub(crate) — construct via helper.
        unsafe { (f.get_image_memory_requirements)(dev, img, &mut req) };
        let ai = vkffi::VkMemoryAllocInfo::for_type(5, req.size, self.mem_type(req.type_bits)?);
        let mut mem: VkDeviceMemory = 0;
        let r = unsafe { (f.allocate_memory)(dev, &ai, ptr::null(), &mut mem) };
        if r != vkffi::VK_SUCCESS {
            unsafe { (f.destroy_image)(dev, img, ptr::null()) };
            return Err(format!("vulkan allocate-image-memory failed: rc={r}"));
        }
        vk_ok("bind-image-memory", unsafe {
            (f.bind_image_memory)(dev, img, mem, 0)
        })?;
        Ok((img, mem))
    }

    fn make_view(
        &self,
        img: VkImage,
        format: u32,
        view_type: u32,
        aspect: u32,
        layers: u32,
    ) -> Result<VkImageView, String> {
        let f = &self.gf;
        let ici = VkImageViewCreateInfo {
            s_type: STYPE_IMAGE_VIEW_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            image: img,
            view_type,
            format,
            components: VkComponentMapping {
                r: SWIZZLE_IDENTITY,
                g: SWIZZLE_IDENTITY,
                b: SWIZZLE_IDENTITY,
                a: SWIZZLE_IDENTITY,
            },
            subresource_range: VkImageSubRange {
                aspect_mask: aspect,
                base_mip_level: 0,
                level_count: 1,
                base_array_layer: 0,
                layer_count: layers,
            },
        };
        let mut view: VkImageView = 0;
        vk_ok("create-image-view", unsafe {
            (f.create_image_view)(self.dev(), &ici, ptr::null(), &mut view)
        })?;
        Ok(view)
    }
}

impl RasterRunner {
    // ---- host-visible buffers -------------------------------------

    fn make_ssbo(&self, bytes: u64) -> Result<(VkBuffer, VkDeviceMemory), String> {
        let f = &self.gf;
        let dev = self.dev();
        let bci = vkffi::VkBufferCreateInfo {
            s_type: 12,
            p_next: ptr::null(),
            flags: 0,
            size: bytes.max(16),
            usage: BUFFER_USAGE_STORAGE,
            sharing_mode: SHARING_EXCLUSIVE,
            queue_family_index_count: 0,
            p_queue_family_indices: ptr::null(),
        };
        let mut buf: VkBuffer = 0;
        vk_ok("create-ssbo", unsafe {
            (f.create_buffer)(dev, &bci, ptr::null(), &mut buf)
        })?;
        let mut req = vkffi::VkMemoryReq::zero();
        unsafe { (f.get_buffer_memory_requirements)(dev, buf, &mut req) };
        let ai = vkffi::VkMemoryAllocInfo::for_type(5, req.size, self.mem_type(req.type_bits)?);
        let mut mem: VkDeviceMemory = 0;
        let r = unsafe { (f.allocate_memory)(dev, &ai, ptr::null(), &mut mem) };
        if r != vkffi::VK_SUCCESS {
            unsafe { (f.destroy_buffer)(dev, buf, ptr::null()) };
            return Err(format!("vulkan allocate-ssbo failed: rc={r}"));
        }
        vk_ok("bind-ssbo", unsafe {
            (f.bind_buffer_memory)(dev, buf, mem, 0)
        })?;
        Ok((buf, mem))
    }

    fn write_bytes(&self, mem: VkDeviceMemory, bytes: &[u8]) -> Result<(), String> {
        let f = &self.gf;
        let mut p: *mut c_void = ptr::null_mut();
        vk_ok("map-ssbo", unsafe {
            (f.map_memory)(self.dev(), mem, 0, bytes.len() as u64, 0, &mut p)
        })?;
        unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), p as *mut u8, bytes.len()) };
        unsafe { (f.unmap_memory)(self.dev(), mem) };
        Ok(())
    }

    fn make_readback_buffer(&self, bytes: u64) -> Result<(VkBuffer, VkDeviceMemory), String> {
        let f = &self.gf;
        let dev = self.dev();
        let bci = vkffi::VkBufferCreateInfo {
            s_type: 12,
            p_next: ptr::null(),
            flags: 0,
            size: bytes,
            usage: BUFFER_USAGE_TRANSFER_DST,
            sharing_mode: SHARING_EXCLUSIVE,
            queue_family_index_count: 0,
            p_queue_family_indices: ptr::null(),
        };
        let mut buf: VkBuffer = 0;
        vk_ok("create-readback", unsafe {
            (f.create_buffer)(dev, &bci, ptr::null(), &mut buf)
        })?;
        let mut req = vkffi::VkMemoryReq::zero();
        unsafe { (f.get_buffer_memory_requirements)(dev, buf, &mut req) };
        let ai = vkffi::VkMemoryAllocInfo::for_type(5, req.size, self.mem_type(req.type_bits)?);
        let mut mem: VkDeviceMemory = 0;
        let r = unsafe { (f.allocate_memory)(dev, &ai, ptr::null(), &mut mem) };
        if r != vkffi::VK_SUCCESS {
            unsafe { (f.destroy_buffer)(dev, buf, ptr::null()) };
            return Err(format!("vulkan allocate-readback failed: rc={r}"));
        }
        vk_ok("bind-readback", unsafe {
            (f.bind_buffer_memory)(dev, buf, mem, 0)
        })?;
        Ok((buf, mem))
    }

    // ---- atlas upload ---------------------------------------------

    /// Upload `layers` RGBA8 layers of `size`×`size` into a
    /// `sampler2DArray` image + view. Layer 9 is the crack texture
    /// (callers pad unused layers with zeros).
    pub fn upload_atlas(
        &mut self,
        layers_rgba: &[u8],
        nlayers: u32,
        size: u32,
    ) -> Result<(VkImage, VkImageView), String> {
        let f = &self.gf;
        let dev = self.dev();
        let want = (nlayers as usize) * (size as usize) * (size as usize) * 4;
        if layers_rgba.len() != want {
            return Err(format!(
                "atlas bytes {} != {nlayers}x{size}x{size}x4={want}",
                layers_rgba.len()
            ));
        }
        // Device image (optimal tiling, transfer-dst + sampled).
        let ici = VkImageCreateInfo {
            s_type: STYPE_IMAGE_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            image_type: IMAGE_TYPE_2D,
            format: FORMAT_RGBA8,
            extent: VkExtent3D {
                width: size,
                height: size,
                depth: 1,
            },
            mip_levels: 1,
            array_layers: nlayers,
            samples: 1,
            tiling: TILING_OPTIMAL,
            usage: USAGE_TRANSFER_DST | USAGE_SAMPLED,
            sharing_mode: SHARING_EXCLUSIVE,
            queue_family_index_count: 0,
            p_queue_family_indices: ptr::null(),
            initial_layout: LAYOUT_UNDEFINED,
        };
        let mut img: VkImage = 0;
        vk_ok("create-atlas", unsafe {
            (f.create_image)(dev, &ici, ptr::null(), &mut img)
        })?;
        let mut req = vkffi::VkMemoryReq::zero();
        unsafe { (f.get_image_memory_requirements)(dev, img, &mut req) };
        // Atlas needs DEVICE-local ideally, but v1 is host-visible
        // throughout (same as compute) — lavapipe has no discrete
        // memory anyway.
        let ai = vkffi::VkMemoryAllocInfo::for_type(5, req.size, self.mem_type(req.type_bits)?);
        let mut mem: VkDeviceMemory = 0;
        let r = unsafe { (f.allocate_memory)(dev, &ai, ptr::null(), &mut mem) };
        if r != vkffi::VK_SUCCESS {
            unsafe { (f.destroy_image)(dev, img, ptr::null()) };
            return Err(format!("vulkan allocate-atlas failed: rc={r}"));
        }
        vk_ok("bind-atlas", unsafe {
            (f.bind_image_memory)(dev, img, mem, 0)
        })?;
        // Staging buffer with the texels.
        let (stg_buf, stg_mem) = self.make_readback_buffer_staged(want as u64)?;
        self.write_bytes(stg_mem, layers_rgba)?;
        // Record: UNDEFINED→DST → copy → DST→READ_ONLY.
        let (pool, cmd) = self.transient_cmd()?;
        let range = VkImageSubRange {
            aspect_mask: ASPECT_COLOR,
            base_mip_level: 0,
            level_count: 1,
            base_array_layer: 0,
            layer_count: nlayers,
        };
        let to_dst = VkImageBarrier {
            s_type: STYPE_IMAGE_BARRIER,
            p_next: ptr::null(),
            src_access_mask: 0,
            dst_access_mask: ACCESS_TRANSFER_WRITE,
            old_layout: LAYOUT_UNDEFINED,
            new_layout: LAYOUT_TRANSFER_DST,
            src_queue_family_index: u32::MAX,
            dst_queue_family_index: u32::MAX,
            image: img,
            subresource_range: range,
        };
        unsafe {
            (f.cmd_pipeline_barrier)(
                cmd,
                STAGE_TOP,
                STAGE_TRANSFER,
                0,
                0,
                ptr::null(),
                0,
                ptr::null(),
                1,
                &to_dst,
            );
        }
        let copy = VkBufferImageCopy {
            buffer_offset: 0,
            buffer_row_length: 0,
            buffer_image_height: 0,
            image_subresource: VkImageSubLayers {
                aspect_mask: ASPECT_COLOR,
                mip_level: 0,
                base_array_layer: 0,
                layer_count: nlayers,
            },
            image_offset: VkOffset3D { x: 0, y: 0, z: 0 },
            image_extent: VkExtent3D {
                width: size,
                height: size,
                depth: 1,
            },
        };
        unsafe {
            (f.cmd_copy_buffer_to_image)(cmd, stg_buf, img, LAYOUT_TRANSFER_DST, 1, &copy);
        }
        let to_read = VkImageBarrier {
            s_type: STYPE_IMAGE_BARRIER,
            p_next: ptr::null(),
            src_access_mask: ACCESS_TRANSFER_WRITE,
            dst_access_mask: ACCESS_SHADER_READ,
            old_layout: LAYOUT_TRANSFER_DST,
            new_layout: LAYOUT_READ_ONLY,
            src_queue_family_index: u32::MAX,
            dst_queue_family_index: u32::MAX,
            image: img,
            subresource_range: range,
        };
        unsafe {
            (f.cmd_pipeline_barrier)(
                cmd,
                STAGE_TRANSFER,
                STAGE_FRAG_SHADER,
                0,
                0,
                ptr::null(),
                0,
                ptr::null(),
                1,
                &to_read,
            );
        }
        self.submit_transient(pool, cmd)?;
        unsafe { (f.destroy_buffer)(dev, stg_buf, ptr::null()) };
        unsafe { (f.free_memory)(dev, stg_mem, ptr::null()) };
        let view = self.make_view(img, FORMAT_RGBA8, VIEW_TYPE_2D_ARRAY, ASPECT_COLOR, nlayers)?;
        self.atlases.push((img, mem, view));
        Ok((img, view))
    }

    /// A staging buffer is TRANSFER_SRC + host-visible; the readback
    /// helper makes TRANSFER_DST. Same memory, different usage bit.
    fn make_readback_buffer_staged(
        &self,
        bytes: u64,
    ) -> Result<(VkBuffer, VkDeviceMemory), String> {
        let f = &self.gf;
        let dev = self.dev();
        let bci = vkffi::VkBufferCreateInfo {
            s_type: 12,
            p_next: ptr::null(),
            flags: 0,
            size: bytes,
            usage: USAGE_TRANSFER_SRC,
            sharing_mode: SHARING_EXCLUSIVE,
            queue_family_index_count: 0,
            p_queue_family_indices: ptr::null(),
        };
        let mut buf: VkBuffer = 0;
        vk_ok("create-staging", unsafe {
            (f.create_buffer)(dev, &bci, ptr::null(), &mut buf)
        })?;
        let mut req = vkffi::VkMemoryReq::zero();
        unsafe { (f.get_buffer_memory_requirements)(dev, buf, &mut req) };
        let ai = vkffi::VkMemoryAllocInfo::for_type(5, req.size, self.mem_type(req.type_bits)?);
        let mut mem: VkDeviceMemory = 0;
        let r = unsafe { (f.allocate_memory)(dev, &ai, ptr::null(), &mut mem) };
        if r != vkffi::VK_SUCCESS {
            unsafe { (f.destroy_buffer)(dev, buf, ptr::null()) };
            return Err(format!("vulkan allocate-staging failed: rc={r}"));
        }
        vk_ok("bind-staging", unsafe {
            (f.bind_buffer_memory)(dev, buf, mem, 0)
        })?;
        Ok((buf, mem))
    }

    /// One transient command buffer, begun. Caller fills, then
    /// `submit_transient`.
    fn transient_cmd(&self) -> Result<(VkCommandPool, VkCommandBuffer), String> {
        let f = &self.gf;
        let dev = self.dev();
        let cpci = vkffi::VkCmdPoolCreateInfo {
            s_type: 39,
            p_next: ptr::null(),
            flags: 0,
            queue_family_index: self.od.family,
        };
        let mut pool: VkCommandPool = 0;
        vk_ok("transient-pool", unsafe {
            (f.create_command_pool)(dev, &cpci, ptr::null(), &mut pool)
        })?;
        let cai = vkffi::VkCmdAllocInfo {
            s_type: 40,
            p_next: ptr::null(),
            pool,
            level: 0,
            count: 1,
        };
        let mut cmd: VkCommandBuffer = ptr::null_mut();
        vk_ok("transient-cmd", unsafe {
            (f.allocate_command_buffers)(dev, &cai, &mut cmd)
        })?;
        let bi = vkffi::VkCmdBeginInfo {
            s_type: 42,
            p_next: ptr::null(),
            flags: CMD_ONE_TIME,
            p_inheritance_info: ptr::null(),
        };
        vk_ok("transient-begin", unsafe {
            (f.begin_command_buffer)(cmd, &bi)
        })?;
        Ok((pool, cmd))
    }

    fn submit_transient(&self, pool: VkCommandPool, cmd: VkCommandBuffer) -> Result<(), String> {
        let f = &self.gf;
        let dev = self.dev();
        vk_ok("transient-end", unsafe { (f.end_command_buffer)(cmd) })?;
        let fci = vkffi::VkFenceCreateInfo {
            s_type: 8,
            p_next: ptr::null(),
            flags: 0,
        };
        let mut fence: VkFence = 0;
        vk_ok("transient-fence", unsafe {
            (f.create_fence)(dev, &fci, ptr::null(), &mut fence)
        })?;
        let si = vkffi::VkSubmitInfo {
            s_type: 4,
            p_next: ptr::null(),
            wait_count: 0,
            p_wait_sems: ptr::null(),
            p_wait_masks: ptr::null(),
            cmd_count: 1,
            p_cmds: &cmd,
            signal_count: 0,
            p_signal_sems: ptr::null(),
        };
        vk_ok("transient-submit", unsafe {
            (f.queue_submit)(self.od.queue, 1, &si, fence)
        })?;
        vk_ok("transient-wait", unsafe {
            (f.wait_for_fences)(dev, 1, &fence, 1, 30_000_000_000)
        })?;
        unsafe { (f.destroy_fence)(dev, fence, ptr::null()) };
        unsafe { (f.destroy_command_pool)(dev, pool, ptr::null()) };
        Ok(())
    }
}

impl RasterRunner {
    // ---- pipeline compile -----------------------------------------

    fn spv_hash(spv: &[u8]) -> u64 {
        let mut h: u64 = 0xcbf29ce484222325;
        for b in spv {
            h ^= *b as u64;
            h = h.wrapping_mul(0x100000001b3);
        }
        h
    }

    fn make_module(&self, spv: &[u8]) -> Result<VkShaderModule, String> {
        if !spv.len().is_multiple_of(4) {
            return Err("SPIR-V length not a multiple of 4".to_string());
        }
        let smci = VkShaderModuleCreateInfo {
            s_type: 16,
            p_next: ptr::null(),
            flags: 0,
            code_size: spv.len(),
            p_code: spv.as_ptr() as *const u32,
        };
        let mut m: VkShaderModule = 0;
        vk_ok("shader-module", unsafe {
            (self.gf.create_shader_module)(self.dev(), &smci, ptr::null(), &mut m)
        })?;
        Ok(m)
    }

    /// Compile one pipeline. `kind`: 0 = blocks (36-vert triangle
    /// list, depth test on, no blending), 1 = overlay (4-vert strip,
    /// no depth test/write, src-alpha blending).
    ///
    /// Descriptor layout (both): binding 0 = records SSBO (vertex
    /// stage), binding 1 = atlas combined sampler (fragment stage).
    /// Push range: 48 bytes (cam0/cam1/cfg) for vertex+fragment.
    fn compile_pipe(
        &self,
        vert_spv: &[u8],
        frag_spv: &[u8],
        kind: u32,
    ) -> Result<CompiledPipe, String> {
        let f = &self.gf;
        let dev = self.dev();
        let hash = Self::spv_hash(vert_spv)
            .wrapping_mul(31)
            .wrapping_add(Self::spv_hash(frag_spv));
        let vert = self.make_module(vert_spv)?;
        let frag = self.make_module(frag_spv)?;
        // Set layout: 0 = SSBO (vertex), 1 = combined sampler (fragment).
        // The OVERLAY vertex stage reads OvRecs from
        // set 0 binding 2 (fb_frag contract — binding 0 is the blocks
        // SSBO, unused by this pipeline). The layout MUST declare all
        // three bindings (0 = blocks SSBO, 1 = atlas, 2 = overlay
        // SSBO); the blocks pipeline leaves 2 unbound, the overlay
        // pipeline leaves 0 unbound. A 2-binding layout makes the
        // overlay vertex's `rec[gl_InstanceIndex]` read set 0 binding
        // 2 through a MISSING descriptor — segfault inside lavapipe's
        // draw (found: overlay-only dispatch crashed, blocks was
        // fine because ITS vertex reads binding 0 which existed).
        let bindings = [
            vkffi::VkSetLayoutBinding {
                binding: 0,
                descriptor_type: DESC_STORAGE_BUFFER,
                descriptor_count: 1,
                stage_flags: STAGE_VERTEX,
                p_immutable_samplers: ptr::null(),
            },
            vkffi::VkSetLayoutBinding {
                binding: 1,
                descriptor_type: DESC_COMBINED_SAMPLER,
                descriptor_count: 1,
                stage_flags: STAGE_FRAGMENT,
                p_immutable_samplers: ptr::null(),
            },
            vkffi::VkSetLayoutBinding {
                binding: 2,
                descriptor_type: DESC_STORAGE_BUFFER,
                descriptor_count: 1,
                stage_flags: STAGE_VERTEX,
                p_immutable_samplers: ptr::null(),
            },
        ];
        let slci = vkffi::VkSetLayoutCreateInfo {
            s_type: 32,
            p_next: ptr::null(),
            flags: 0,
            binding_count: 3,
            p_bindings: bindings.as_ptr(),
        };
        let mut set_layout: VkDescriptorSetLayout = 0;
        vk_ok("gfx-set-layout", unsafe {
            (f.create_descriptor_set_layout)(dev, &slci, ptr::null(), &mut set_layout)
        })?;
        let push = VkPushRange {
            stage_flags: STAGE_VERTEX | STAGE_FRAGMENT,
            offset: 0,
            size: 48,
        };
        let plci = vkffi::VkPipelineLayoutCreateInfo {
            s_type: 30,
            p_next: ptr::null(),
            flags: 0,
            set_layout_count: 1,
            p_set_layouts: &set_layout,
            push_constant_range_count: 1,
            p_push_constant_ranges: &push as *const VkPushRange as *const c_void,
        };
        let mut pipe_layout: VkPipelineLayout = 0;
        vk_ok("gfx-pipe-layout", unsafe {
            (f.create_pipeline_layout)(dev, &plci, ptr::null(), &mut pipe_layout)
        })?;
        let main = CString::new("main").unwrap();
        let stages = [
            VkStageInfo {
                s_type: STYPE_SHADER_STAGE_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                stage: STAGE_VERTEX,
                module: vert,
                p_name: main.as_ptr(),
                p_specialization_info: ptr::null(),
            },
            VkStageInfo {
                s_type: STYPE_SHADER_STAGE_CREATE_INFO,
                p_next: ptr::null(),
                flags: 0,
                stage: STAGE_FRAGMENT,
                module: frag,
                p_name: main.as_ptr(),
                p_specialization_info: ptr::null(),
            },
        ];
        let vi = VkVertexInputCreateInfo {
            s_type: STYPE_VERTEX_INPUT_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            binding_count: 0,
            p_bindings: ptr::null(),
            attribute_count: 0,
            p_attributes: ptr::null(),
        };
        // Both pipelines are triangle lists (the overlay stage
        // emits 6 verts = 2 explicit triangles; see above).
        let topo = TOPO_TRIANGLE_LIST;
        let ia = VkInputAssemblyCreateInfo {
            s_type: STYPE_INPUT_ASSEMBLY_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            topology: topo,
            primitive_restart_enable: 0,
        };
        let vp = VkViewport {
            x: 0.0,
            y: 0.0,
            width: self.width as f32,
            height: self.height as f32,
            min_depth: 0.0,
            max_depth: 1.0,
        };
        let sc = VkRect2D {
            offset: VkOffset2D { x: 0, y: 0 },
            extent: VkExtent2D {
                width: self.width,
                height: self.height,
            },
        };
        let vps = VkViewportCreateInfo {
            s_type: STYPE_VIEWPORT_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            viewport_count: 1,
            p_viewports: &vp,
            scissor_count: 1,
            p_scissors: &sc,
        };
        let rast = VkRasterCreateInfo {
            s_type: STYPE_RASTER_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            depth_clamp_enable: 0,
            rasterizer_discard_enable: 0,
            polygon_mode: POLYGON_FILL,
            cull_mode: CULL_NONE,
            front_face: FRONT_CCW,
            depth_bias_enable: 0,
            depth_bias_constant_factor: 0.0,
            depth_bias_clamp: 0.0,
            depth_bias_slope_factor: 0.0,
            line_width: 1.0,
        };
        let ms = VkMultisampleCreateInfo {
            s_type: STYPE_MULTISAMPLE_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            rasterization_samples: 1,
            sample_shading_enable: 0,
            min_sample_shading: 0.0,
            p_sample_mask: ptr::null(),
            alpha_to_coverage_enable: 0,
            alpha_to_one_enable: 0,
        };
        let no_stencil = VkStencilOpState {
            fail_op: 0,
            pass_op: 0,
            depth_fail_op: 0,
            compare_op: 0,
            compare_mask: 0,
            write_mask: 0,
            reference: 0,
        };
        let ds = VkDepthStencilCreateInfo {
            s_type: STYPE_DEPTH_STENCIL_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            depth_test_enable: if kind == 0 { 1 } else { 0 },
            depth_write_enable: if kind == 0 { 1 } else { 0 },
            depth_compare_op: COMPARE_LESS,
            depth_bounds_test_enable: 0,
            stencil_test_enable: 0,
            front: no_stencil,
            back: no_stencil,
            min_depth_bounds: 0.0,
            max_depth_bounds: 1.0,
        };
        // Blocks: opaque (blending off, full write mask). Overlay:
        // src-alpha blending (the layer composite at present).
        let blend_att = if kind == 0 {
            VkBlendAttachment {
                blend_enable: 0,
                src_color_blend_factor: BLEND_ONE,
                dst_color_blend_factor: BLEND_ZERO,
                color_blend_op: BLEND_ADD,
                src_alpha_blend_factor: BLEND_ONE,
                dst_alpha_blend_factor: BLEND_ZERO,
                alpha_blend_op: BLEND_ADD,
                color_write_mask: COLOR_R_BIT | COLOR_G_BIT | COLOR_B_BIT | COLOR_A_BIT,
            }
        } else {
            VkBlendAttachment {
                blend_enable: 1,
                src_color_blend_factor: BLEND_SRC_ALPHA,
                dst_color_blend_factor: BLEND_ONE_MINUS_SRC_ALPHA,
                color_blend_op: BLEND_ADD,
                src_alpha_blend_factor: BLEND_ONE,
                dst_alpha_blend_factor: BLEND_ONE_MINUS_SRC_ALPHA,
                alpha_blend_op: BLEND_ADD,
                color_write_mask: COLOR_R_BIT | COLOR_G_BIT | COLOR_B_BIT | COLOR_A_BIT,
            }
        };
        let cb = VkColorBlendCreateInfo {
            s_type: STYPE_COLOR_BLEND_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            logic_op_enable: 0,
            logic_op: 0,
            attachment_count: 1,
            p_attachments: &blend_att,
            blend_constants: [0.0; 4],
        };
        let gpci = VkGraphicsPipelineCreateInfo {
            s_type: STYPE_GRAPHICS_PIPELINE_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            stage_count: 2,
            p_stages: stages.as_ptr(),
            p_vertex_input_state: &vi,
            p_input_assembly_state: &ia,
            p_tessellation_state: ptr::null(),
            p_viewport_state: &vps,
            p_rasterization_state: &rast,
            p_multisample_state: &ms,
            p_depth_stencil_state: &ds,
            p_color_blend_state: &cb,
            p_dynamic_state: ptr::null(),
            layout: pipe_layout,
            render_pass: self.render_pass,
            subpass: 0,
            base_handle: 0,
            base_index: -1,
        };
        let mut pipeline: VkPipeline = 0;
        vk_ok("create-graphics-pipeline", unsafe {
            (f.create_graphics_pipelines)(dev, 0, 1, &gpci, ptr::null(), &mut pipeline)
        })?;
        // Pool: 1 SSBO + 1 sampler.
        let sizes = [
            vkffi::VkPoolSize {
                ty: DESC_STORAGE_BUFFER,
                count: 2,
            },
            vkffi::VkPoolSize {
                ty: DESC_COMBINED_SAMPLER,
                count: 1,
            },
        ];
        let poolci = vkffi::VkPoolCreateInfo {
            s_type: 33,
            p_next: ptr::null(),
            flags: 0,
            max_sets: 1,
            pool_size_count: 2,
            p_pool_sizes: sizes.as_ptr(),
        };
        let mut pool: VkDescriptorPool = 0;
        vk_ok("gfx-desc-pool", unsafe {
            (f.create_descriptor_pool)(dev, &poolci, ptr::null(), &mut pool)
        })?;
        let alloc = vkffi::VkSetAllocInfo {
            s_type: 34,
            p_next: ptr::null(),
            pool,
            set_count: 1,
            p_set_layouts: &set_layout,
        };
        let mut set: VkDescriptorSet = 0;
        vk_ok("gfx-alloc-set", unsafe {
            (f.allocate_descriptor_sets)(dev, &alloc, &mut set)
        })?;
        Ok(CompiledPipe {
            hash,
            vert,
            frag,
            set_layout,
            pipe_layout,
            pipeline,
            pool,
            set,
        })
    }
}

impl RasterRunner {
    // ---- draw -------------------------------------------------------

    /// Bind one pipeline's descriptors: the records SSBO goes to
    /// binding 0 (blocks) or 2 (overlay) — `ssbo_binding` selects —
    /// and the atlas sampler always to binding 1. The layout always
    /// declares all three (see compile_pipe); the unbound SSBO slot
    /// is simply never written.
    fn bind_pipe_descriptors(
        &self,
        set: VkDescriptorSet,
        ssbo_binding: u32,
        ssbo: VkBuffer,
        ssbo_bytes: u64,
        atlas_view: VkImageView,
    ) -> Result<(), String> {
        let f = &self.gf;
        let buf_info = vkffi::VkDescriptorBufferInfo {
            buffer: ssbo,
            offset: 0,
            range: ssbo_bytes,
        };
        let img_info = VkDescriptorImageInfo {
            sampler: self.sampler,
            image_view: atlas_view,
            image_layout: LAYOUT_READ_ONLY,
        };
        // VkWriteSet.p_image_info is *const c_void in vkffi — the
        // image info struct is layout-compatible (sampler/view/layout).
        let writes = [
            vkffi::VkWriteSet {
                s_type: 35,
                p_next: ptr::null(),
                dst_set: set,
                dst_binding: ssbo_binding,
                dst_array_element: 0,
                descriptor_count: 1,
                descriptor_type: DESC_STORAGE_BUFFER,
                p_image_info: ptr::null(),
                p_buffer_info: &buf_info as *const vkffi::VkDescriptorBufferInfo,
                p_texel_view: ptr::null(),
            },
            vkffi::VkWriteSet {
                s_type: 35,
                p_next: ptr::null(),
                dst_set: set,
                dst_binding: 1,
                dst_array_element: 0,
                descriptor_count: 1,
                descriptor_type: DESC_COMBINED_SAMPLER,
                p_image_info: &img_info as *const VkDescriptorImageInfo as *const c_void,
                p_buffer_info: ptr::null(),
                p_texel_view: ptr::null(),
            },
        ];
        unsafe {
            (f.update_descriptor_sets)(
                self.dev(),
                writes.len() as u32,
                writes.as_ptr(),
                0,
                ptr::null(),
            );
        }
        Ok(())
    }

    /// Draw the blocks pipeline: `records` = packed CubeRecs (12 f32
    /// each), `push` = camera + flags, `atlas_view` from
    /// `upload_atlas`. One instance per record, 36 verts each.
    /// Clears color+depth first (the frame start).
    pub fn draw_blocks(
        &mut self,
        vert_spv: &[u8],
        frag_spv: &[u8],
        records: &[f32],
        push: &PushConstants,
        atlas_view: VkImageView,
    ) -> Result<(), String> {
        if !records.len().is_multiple_of(CUBE_REC_WORDS) {
            return Err(format!(
                "blocks records {} not a multiple of {CUBE_REC_WORDS}",
                records.len()
            ));
        }
        let n = (records.len() / CUBE_REC_WORDS) as u32;
        if n == 0 {
            return Err("blocks: no records".to_string());
        }
        let hash = Self::spv_hash(vert_spv)
            .wrapping_mul(31)
            .wrapping_add(Self::spv_hash(frag_spv));
        let replace = match &self.blocks_pipe {
            Some(p) => p.hash != hash,
            None => true,
        };
        if replace {
            let pipe = self.compile_pipe(vert_spv, frag_spv, 0)?;
            if let Some(old) = self.blocks_pipe.take() {
                self.destroy_pipe(old);
            }
            self.blocks_pipe = Some(pipe);
        }
        let bytes = records.len() * 4;
        let (ssbo, mem) = self.make_ssbo(bytes as u64)?;
        self.write_bytes(mem, unsafe {
            std::slice::from_raw_parts(records.as_ptr() as *const u8, bytes)
        })?;
        let pipe = self.blocks_pipe.as_ref().ok_or("blocks pipe missing")?;
        self.bind_pipe_descriptors(pipe.set, 0, ssbo, bytes as u64, atlas_view)?;
        self.record_blocks_pass(pipe, push, n)?;
        let f = &self.gf;
        unsafe { (f.destroy_buffer)(self.dev(), ssbo, ptr::null()) };
        unsafe { (f.free_memory)(self.dev(), mem, ptr::null()) };
        Ok(())
    }

    /// Draw the overlay pipeline: `records` = packed OvRecs (12 f32
    /// each). Loads (does NOT clear) color — blends over blocks.
    /// One instance per record, 6 verts each (2 triangles).
    pub fn draw_overlay(
        &mut self,
        vert_spv: &[u8],
        frag_spv: &[u8],
        records: &[f32],
        push: &PushConstants,
        atlas_view: VkImageView,
    ) -> Result<(), String> {
        if !records.len().is_multiple_of(OV_REC_WORDS) {
            return Err(format!(
                "overlay records {} not a multiple of {OV_REC_WORDS}",
                records.len()
            ));
        }
        let n = (records.len() / OV_REC_WORDS) as u32;
        if n == 0 {
            return Err("overlay: no records".to_string());
        }
        let hash = Self::spv_hash(vert_spv)
            .wrapping_mul(31)
            .wrapping_add(Self::spv_hash(frag_spv));
        let replace = match &self.overlay_pipe {
            Some(p) => p.hash != hash,
            None => true,
        };
        if replace {
            let pipe = self.compile_pipe(vert_spv, frag_spv, 1)?;
            if let Some(old) = self.overlay_pipe.take() {
                self.destroy_pipe(old);
            }
            self.overlay_pipe = Some(pipe);
        }
        let bytes = records.len() * 4;
        let (ssbo, mem) = self.make_ssbo(bytes as u64)?;
        self.write_bytes(mem, unsafe {
            std::slice::from_raw_parts(records.as_ptr() as *const u8, bytes)
        })?;
        let pipe_layout = self
            .overlay_pipe
            .as_ref()
            .ok_or("overlay pipe missing")?
            .pipe_layout;
        let pipe_set = self
            .overlay_pipe
            .as_ref()
            .ok_or("overlay pipe missing")?
            .set;
        let pipe_handle = self
            .overlay_pipe
            .as_ref()
            .ok_or("overlay pipe missing")?
            .pipeline;
        self.bind_pipe_descriptors(pipe_set, 2, ssbo, bytes as u64, atlas_view)?;
        self.record_overlay_pass(pipe_handle, pipe_layout, pipe_set, push, n)?;
        let f = &self.gf;
        unsafe { (f.destroy_buffer)(self.dev(), ssbo, ptr::null()) };
        unsafe { (f.free_memory)(self.dev(), mem, ptr::null()) };
        Ok(())
    }

    /// Record + submit the blocks pass (CLEAR color+depth, triangle list).
    fn record_blocks_pass(
        &self,
        pipe: &CompiledPipe,
        push: &PushConstants,
        n_instances: u32,
    ) -> Result<(), String> {
        let f = &self.gf;
        vk_ok("reset-cmd", unsafe {
            (f.reset_command_buffer)(self.cmd, 0)
        })?;
        let bi = vkffi::VkCmdBeginInfo {
            s_type: 42,
            p_next: ptr::null(),
            flags: CMD_ONE_TIME,
            p_inheritance_info: ptr::null(),
        };
        vk_ok("begin-cmd", unsafe {
            (f.begin_command_buffer)(self.cmd, &bi)
        })?;
        let clears = [
            VkClearValue {
                color: [0.0, 0.0, 0.0, 1.0],
            },
            VkClearValue {
                color: [1.0, 0.0, 0.0, 0.0],
            }, // depth=1.0 (first float)
        ];
        let rpbi = VkRenderPassBeginInfo {
            s_type: STYPE_RENDER_PASS_BEGIN_INFO,
            p_next: ptr::null(),
            render_pass: self.render_pass,
            framebuffer: self.framebuffer,
            render_area: VkRect2D {
                offset: VkOffset2D { x: 0, y: 0 },
                extent: VkExtent2D {
                    width: self.width,
                    height: self.height,
                },
            },
            clear_value_count: 2,
            p_clear_values: clears.as_ptr(),
        };
        unsafe { (f.cmd_begin_render_pass)(self.cmd, &rpbi, CONTENTS_INLINE) };
        unsafe { (f.cmd_bind_pipeline)(self.cmd, BIND_GRAPHICS, pipe.pipeline) };
        unsafe {
            (f.cmd_bind_descriptor_sets)(
                self.cmd,
                BIND_GRAPHICS,
                pipe.pipe_layout,
                0,
                1,
                &pipe.set,
                0,
                ptr::null(),
            );
        }
        unsafe {
            (f.cmd_push_constants)(
                self.cmd,
                pipe.pipe_layout,
                STAGE_VERTEX | STAGE_FRAGMENT,
                0,
                48,
                push as *const PushConstants as *const c_void,
            );
        }
        unsafe { (f.cmd_draw)(self.cmd, 36, n_instances, 0, 0) };
        unsafe { (f.cmd_end_render_pass)(self.cmd) };
        vk_ok("end-cmd", unsafe { (f.end_command_buffer)(self.cmd) })?;
        self.submit_cmd()?;
        Ok(())
    }

    /// Create the LOAD render pass + framebuffer (no self — all
    /// inputs are hoisted copies, so the caller can store the
    /// result without aliasing).
    #[allow(clippy::too_many_arguments)]
    fn make_load_pass(
        gf: GfxFns,
        dev: VkDevice,
        rpci: &VkRenderPassCreateInfo,
        cv: VkImageView,
        dv: VkImageView,
        w: u32,
        h: u32,
    ) -> Result<(VkRenderPass, VkFramebuffer), String> {
        let mut load_rp: VkRenderPass = 0;
        vk_ok("create-load-pass", unsafe {
            (gf.create_render_pass)(dev, rpci, ptr::null(), &mut load_rp)
        })?;
        let views = [cv, dv];
        let fbci = VkFramebufferCreateInfo {
            s_type: STYPE_FRAMEBUFFER_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            render_pass: load_rp,
            attachment_count: 2,
            p_attachments: views.as_ptr(),
            width: w,
            height: h,
            layers: 1,
        };
        let mut load_fb: VkFramebuffer = 0;
        vk_ok("create-load-fb", unsafe {
            (gf.create_framebuffer)(dev, &fbci, ptr::null(), &mut load_fb)
        })?;
        Ok((load_rp, load_fb))
    }

    /// Record + submit the overlay pass (LOAD color, no depth write,
    /// triangle strip, src-alpha blend).
    fn record_overlay_pass(
        &mut self,
        pipe: VkPipeline,
        pipe_layout: VkPipelineLayout,
        pipe_set: VkDescriptorSet,
        push: &PushConstants,
        n_instances: u32,
    ) -> Result<(), String> {
        // A LOAD render pass sharing the same attachments: color
        // keeps the blocks pixels, depth keeps testing off (the
        // overlay pipeline has depth test disabled anyway).
        // (`gf` is the whole function table by value — GfxFns is
        // Copy — so the cache stores below alias nothing.)
        let color_att = VkAttachmentDesc {
            flags: 0,
            format: FORMAT_RGBA8,
            samples: 1,
            load_op: 0, // LOAD = 0
            store_op: STORE_STORE,
            stencil_load_op: LOAD_DONT_CARE,
            stencil_store_op: STORE_DONT_CARE,
            initial_layout: LAYOUT_COLOR_OPTIMAL,
            final_layout: LAYOUT_COLOR_OPTIMAL,
        };
        let depth_att = VkAttachmentDesc {
            flags: 0,
            format: FORMAT_D32,
            samples: 1,
            load_op: 0, // LOAD
            store_op: STORE_DONT_CARE,
            stencil_load_op: LOAD_DONT_CARE,
            stencil_store_op: STORE_DONT_CARE,
            initial_layout: LAYOUT_DEPTH_OPTIMAL,
            final_layout: LAYOUT_DEPTH_OPTIMAL,
        };
        let atts = [color_att, depth_att];
        let color_ref = VkAttachmentRef {
            attachment: 0,
            layout: LAYOUT_COLOR_OPTIMAL,
        };
        let depth_ref = VkAttachmentRef {
            attachment: 1,
            layout: LAYOUT_DEPTH_OPTIMAL,
        };
        let subpass = VkSubpassDesc {
            flags: 0,
            pipeline_bind_point: BIND_GRAPHICS,
            input_attachment_count: 0,
            p_input_attachments: ptr::null(),
            color_attachment_count: 1,
            p_color_attachments: &color_ref,
            p_resolve_attachments: ptr::null(),
            p_depth_stencil_attachment: &depth_ref,
            preserve_attachment_count: 0,
            p_preserve_attachments: ptr::null(),
        };
        let rpci = VkRenderPassCreateInfo {
            s_type: STYPE_RENDER_PASS_CREATE_INFO,
            p_next: ptr::null(),
            flags: 0,
            attachment_count: 2,
            p_attachments: atts.as_ptr(),
            subpass_count: 1,
            p_subpasses: &subpass,
            dependency_count: 0,
            p_dependencies: ptr::null(),
        };
        // Hoist every self-read ABOVE the &mut cache stores
        // below (NLL keeps the shared borrows alive otherwise):
        // device + queue family values, command buffer, geometry,
        // views, and the function table (GfxFns is Copy).
        let dev = self.dev();
        let gf = self.gf;
        let cmd = self.cmd;
        let (w, h) = (self.width, self.height);
        let queue = self.od.queue;
        let (cv, dv) = (self.color_view, self.depth_view);
        // The LOAD pass is created once per runner and cached: a
        // per-overlay create/destroy cycle segfaults lavapipe on the
        // second runner teardown in the process (same lazy-free class
        // as the descriptor-pool fault — render-pass objects carry
        // attachment references the driver frees late).
        // Cache fill via a self-free helper: `rpci` borrows the
        // local atts/subpass (not self), so only hoisted copies
        // (gf/dev/cv/dv/w/h) cross into it — then two plain stores.
        // The cache check + fill MUST NOT hold a shared self
        // borrow across the stores (NLL keeps `zip`'s borrow alive
        // through the match). Raw-pointer reads: the fields are
        // Option<u64> (Copy), and this is the only writer.
        let cached: Option<(VkRenderPass, VkFramebuffer)> = unsafe {
            let rp = *std::ptr::addr_of!(self.load_rp);
            let fb = *std::ptr::addr_of!(self.load_fb);
            rp.zip(fb)
        };
        let (load_rp, load_fb) = match cached {
            Some(pair) => pair,
            None => {
                let (nrp, nfb) = Self::make_load_pass(gf, dev, &rpci, cv, dv, w, h)?;
                self.load_rp = Some(nrp);
                self.load_fb = Some(nfb);
                (nrp, nfb)
            }
        };
        vk_ok("reset-cmd", unsafe { (gf.reset_command_buffer)(cmd, 0) })?;
        let bi = vkffi::VkCmdBeginInfo {
            s_type: 42,
            p_next: ptr::null(),
            flags: CMD_ONE_TIME,
            p_inheritance_info: ptr::null(),
        };
        vk_ok("begin-cmd", unsafe { (gf.begin_command_buffer)(cmd, &bi) })?;
        let rpbi = VkRenderPassBeginInfo {
            s_type: STYPE_RENDER_PASS_BEGIN_INFO,
            p_next: ptr::null(),
            render_pass: load_rp,
            framebuffer: load_fb,
            render_area: VkRect2D {
                offset: VkOffset2D { x: 0, y: 0 },
                extent: VkExtent2D {
                    width: w,
                    height: h,
                },
            },
            clear_value_count: 0,
            p_clear_values: ptr::null(),
        };
        unsafe { (gf.cmd_begin_render_pass)(cmd, &rpbi, CONTENTS_INLINE) };
        unsafe { (gf.cmd_bind_pipeline)(cmd, BIND_GRAPHICS, pipe) };
        unsafe {
            (gf.cmd_bind_descriptor_sets)(
                cmd,
                BIND_GRAPHICS,
                pipe_layout,
                0,
                1,
                &pipe_set,
                0,
                ptr::null(),
            );
        }
        unsafe {
            (gf.cmd_push_constants)(
                cmd,
                pipe_layout,
                STAGE_VERTEX | STAGE_FRAGMENT,
                0,
                48,
                push as *const PushConstants as *const c_void,
            );
        }
        // 6 verts: two explicit triangles (TL,TR,BR)+(TL,BR,BL) —
        // the vertex stage folds k=4,5 back to corners 2,3 (see
        // fb_frag::overlay_vertex; a 4-vert strip misinterpolates
        // on lavapipe).
        unsafe { (gf.cmd_draw)(cmd, 6, n_instances, 0, 0) };
        unsafe { (gf.cmd_end_render_pass)(cmd) };
        vk_ok("end-cmd", unsafe { (gf.end_command_buffer)(cmd) })?;
        // Submit inline (not via submit_cmd): that helper takes
        // &self, whose shared borrow would span the cache stores.
        let fci = vkffi::VkFenceCreateInfo {
            s_type: 8,
            p_next: ptr::null(),
            flags: 0,
        };
        let mut fence: VkFence = 0;
        vk_ok("fence", unsafe {
            (gf.create_fence)(dev, &fci, ptr::null(), &mut fence)
        })?;
        let si = vkffi::VkSubmitInfo {
            s_type: 4,
            p_next: ptr::null(),
            wait_count: 0,
            p_wait_sems: ptr::null(),
            p_wait_masks: ptr::null(),
            cmd_count: 1,
            p_cmds: &cmd,
            signal_count: 0,
            p_signal_sems: ptr::null(),
        };
        vk_ok("submit", unsafe { (gf.queue_submit)(queue, 1, &si, fence) })?;
        vk_ok("wait-fence", unsafe {
            (gf.wait_for_fences)(dev, 1, &fence, 1, 30_000_000_000)
        })?;
        unsafe { (gf.destroy_fence)(dev, fence, ptr::null()) };
        Ok(())
    }

    fn submit_cmd(&self) -> Result<(), String> {
        let f = &self.gf;
        let dev = self.dev();
        let fci = vkffi::VkFenceCreateInfo {
            s_type: 8,
            p_next: ptr::null(),
            flags: 0,
        };
        let mut fence: VkFence = 0;
        vk_ok("fence", unsafe {
            (f.create_fence)(dev, &fci, ptr::null(), &mut fence)
        })?;
        let si = vkffi::VkSubmitInfo {
            s_type: 4,
            p_next: ptr::null(),
            wait_count: 0,
            p_wait_sems: ptr::null(),
            p_wait_masks: ptr::null(),
            cmd_count: 1,
            p_cmds: &self.cmd,
            signal_count: 0,
            p_signal_sems: ptr::null(),
        };
        vk_ok("submit", unsafe {
            (f.queue_submit)(self.od.queue, 1, &si, fence)
        })?;
        vk_ok("wait-fence", unsafe {
            (f.wait_for_fences)(dev, 1, &fence, 1, 30_000_000_000)
        })?;
        unsafe { (f.destroy_fence)(dev, fence, ptr::null()) };
        Ok(())
    }

    // ---- readback ---------------------------------------------------

    /// Copy the color image to host memory as RGBA8 (row-major,
    /// top row first — Vulkan images are top-down here since the
    /// viewport is not flipped and no present transform applies).
    pub fn readback(&self) -> Result<Vec<u8>, String> {
        let f = &self.gf;
        let dev = self.dev();
        let nbytes = (self.width as u64) * (self.height as u64) * 4;
        let (buf, mem) = self.make_readback_buffer(nbytes)?;
        let (pool, cmd) = self.transient_cmd()?;
        // COLOR_OPTIMAL → TRANSFER_SRC.
        let range = VkImageSubRange {
            aspect_mask: ASPECT_COLOR,
            base_mip_level: 0,
            level_count: 1,
            base_array_layer: 0,
            layer_count: 1,
        };
        let to_src = VkImageBarrier {
            s_type: STYPE_IMAGE_BARRIER,
            p_next: ptr::null(),
            src_access_mask: ACCESS_COLOR_WRITE,
            dst_access_mask: ACCESS_TRANSFER_READ,
            old_layout: LAYOUT_COLOR_OPTIMAL,
            new_layout: LAYOUT_TRANSFER_SRC,
            src_queue_family_index: u32::MAX,
            dst_queue_family_index: u32::MAX,
            image: self.color_img,
            subresource_range: range,
        };
        unsafe {
            (f.cmd_pipeline_barrier)(
                cmd,
                STAGE_COLOR_OUTPUT,
                STAGE_TRANSFER,
                0,
                0,
                ptr::null(),
                0,
                ptr::null(),
                1,
                &to_src,
            );
        }
        let copy = VkBufferImageCopy {
            buffer_offset: 0,
            buffer_row_length: 0,
            buffer_image_height: 0,
            image_subresource: VkImageSubLayers {
                aspect_mask: ASPECT_COLOR,
                mip_level: 0,
                base_array_layer: 0,
                layer_count: 1,
            },
            image_offset: VkOffset3D { x: 0, y: 0, z: 0 },
            image_extent: VkExtent3D {
                width: self.width,
                height: self.height,
                depth: 1,
            },
        };
        unsafe {
            (f.cmd_copy_image_to_buffer)(cmd, self.color_img, LAYOUT_TRANSFER_SRC, buf, 1, &copy);
        }
        // TRANSFER_SRC → COLOR_OPTIMAL (so a subsequent overlay pass
        // can LOAD it back).
        let back = VkImageBarrier {
            s_type: STYPE_IMAGE_BARRIER,
            p_next: ptr::null(),
            src_access_mask: ACCESS_TRANSFER_READ,
            dst_access_mask: ACCESS_COLOR_WRITE,
            old_layout: LAYOUT_TRANSFER_SRC,
            new_layout: LAYOUT_COLOR_OPTIMAL,
            src_queue_family_index: u32::MAX,
            dst_queue_family_index: u32::MAX,
            image: self.color_img,
            subresource_range: range,
        };
        unsafe {
            (f.cmd_pipeline_barrier)(
                cmd,
                STAGE_TRANSFER,
                STAGE_COLOR_OUTPUT,
                0,
                0,
                ptr::null(),
                0,
                ptr::null(),
                1,
                &back,
            );
        }
        self.submit_transient(pool, cmd)?;
        // Map + copy out.
        let mut p: *mut c_void = ptr::null_mut();
        vk_ok("map-readback", unsafe {
            (f.map_memory)(dev, mem, 0, nbytes, 0, &mut p)
        })?;
        let mut out = vec![0u8; nbytes as usize];
        unsafe { std::ptr::copy_nonoverlapping(p as *const u8, out.as_mut_ptr(), nbytes as usize) };
        unsafe { (f.unmap_memory)(dev, mem) };
        unsafe { (f.destroy_buffer)(dev, buf, ptr::null()) };
        unsafe { (f.free_memory)(dev, mem, ptr::null()) };
        Ok(out)
    }

    fn destroy_pipe(&self, p: CompiledPipe) {
        // Destroy in dependency order: the command pool owns the
        // descriptor set, the pipeline references layout + modules.
        // Pipeline first, pool last — destroying the pool while the
        // pipeline still references the layout faulted lavapipe on the
        // second runner teardown in the process (found by the
        // 4-iteration probe). Same order as the compute runner's
        // `evict_pipe`, which destroys its pool without faulting.
        let f = &self.gf;
        let dev = self.dev();
        unsafe { (f.destroy_pipeline)(dev, p.pipeline, ptr::null()) };
        unsafe { (f.destroy_shader_module)(dev, p.vert, ptr::null()) };
        unsafe { (f.destroy_shader_module)(dev, p.frag, ptr::null()) };
        unsafe { (f.destroy_pipeline_layout)(dev, p.pipe_layout, ptr::null()) };
        unsafe { (f.destroy_descriptor_set_layout)(dev, p.set_layout, ptr::null()) };
        unsafe { (f.destroy_descriptor_pool)(dev, p.pool, ptr::null()) };
        let _ = p.set;
    }
}

impl Drop for RasterRunner {
    fn drop(&mut self) {
        // Tear down in dependency order. Handles are zero until their
        // create succeeds (`build_target` runs after the struct
        // exists), and destroying a zero/VK_NULL handle segfaults the
        // loader — so every destroy is guarded. A runner that failed
        // halfway through `new` drops zeros for everything not yet
        // created; the device/instance are destroyed only when the
        // device was actually created.
        let f = &self.gf;
        let dev = self.od.dev;
        if dev.is_null() {
            return;
        }
        if let Some(p) = self.blocks_pipe.take() {
            self.destroy_pipe(p);
        }
        if let Some(p) = self.overlay_pipe.take() {
            self.destroy_pipe(p);
        }
        if self.cmd_pool != 0 {
            unsafe { (f.destroy_command_pool)(dev, self.cmd_pool, ptr::null()) };
        }
        if self.framebuffer != 0 {
            unsafe { (f.destroy_framebuffer)(dev, self.framebuffer, ptr::null()) };
        }
        if let Some(fb) = self.load_fb.take() {
            if fb != 0 {
                unsafe { (f.destroy_framebuffer)(dev, fb, ptr::null()) };
            }
        }
        if let Some(rp) = self.load_rp.take() {
            if rp != 0 {
                unsafe { (f.destroy_render_pass)(dev, rp, ptr::null()) };
            }
        }
        if self.render_pass != 0 {
            unsafe { (f.destroy_render_pass)(dev, self.render_pass, ptr::null()) };
        }
        if self.sampler != 0 {
            unsafe { (f.destroy_sampler)(dev, self.sampler, ptr::null()) };
        }
        if self.color_view != 0 {
            unsafe { (f.destroy_image_view)(dev, self.color_view, ptr::null()) };
        }
        if self.depth_view != 0 {
            unsafe { (f.destroy_image_view)(dev, self.depth_view, ptr::null()) };
        }
        if self.color_img != 0 {
            unsafe { (f.destroy_image)(dev, self.color_img, ptr::null()) };
        }
        if self.depth_img != 0 {
            unsafe { (f.destroy_image)(dev, self.depth_img, ptr::null()) };
        }
        if self.color_mem != 0 {
            unsafe { (f.free_memory)(dev, self.color_mem, ptr::null()) };
        }
        if self.depth_mem != 0 {
            unsafe { (f.free_memory)(dev, self.depth_mem, ptr::null()) };
        }
        for (img, mem, view) in self.atlases.drain(..) {
            if view != 0 {
                unsafe { (f.destroy_image_view)(dev, view, ptr::null()) };
            }
            if img != 0 {
                unsafe { (f.destroy_image)(dev, img, ptr::null()) };
            }
            if mem != 0 {
                unsafe { (f.free_memory)(dev, mem, ptr::null()) };
            }
        }
        // Destroy the device + instance like the compute runner does
        // (`ComputeRunner::drop`): the loader (`od.vk`) dlcloses on its
        // own `Drop` after this, so device-then-instance-then-dlclose is
        // the correct order. An earlier revision skipped both to dodge
        // a lavapipe teardown fault and leaked the whole device per
        // runner; the fault was the pool/layout ordering above, now
        // fixed. If lavapipe ever regresses, it fails loud (segfault),
        // not as a silent per-runner device leak.
        unsafe { (f.destroy_device)(dev, ptr::null()) };
        let destroy: unsafe extern "C" fn(vkffi::VkInstance, *const c_void) -> () =
            vkffi::ifn(&self.od.vk, self.od.inst, "vkDestroyInstance");
        unsafe { destroy(self.od.inst, ptr::null()) };
    }
}

// ---- layout tests -----------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    /// FFI layout contract for the graphics subset: struct sizes must
    /// equal the C ABI (`vulkan_core.h`, `/tmp/vk_abi.txt` from gcc
    /// `sizeof`). Same rule as the compute runner: a wrong size
    /// smashes the stack across the call boundary.
    #[test]
    fn gfx_struct_layouts_match_c_abi() {
        assert_eq!(std::mem::size_of::<VkImageCreateInfo>(), 88);
        assert_eq!(std::mem::size_of::<VkImageViewCreateInfo>(), 80);
        assert_eq!(std::mem::size_of::<VkSamplerCreateInfo>(), 80);
        assert_eq!(std::mem::size_of::<VkAttachmentDesc>(), 36);
        assert_eq!(std::mem::size_of::<VkRenderPassCreateInfo>(), 64);
        assert_eq!(std::mem::size_of::<VkFramebufferCreateInfo>(), 64);
        assert_eq!(std::mem::size_of::<VkVertexInputCreateInfo>(), 48);
        assert_eq!(std::mem::size_of::<VkInputAssemblyCreateInfo>(), 32);
        assert_eq!(std::mem::size_of::<VkViewportCreateInfo>(), 48);
        assert_eq!(std::mem::size_of::<VkRasterCreateInfo>(), 64);
        assert_eq!(std::mem::size_of::<VkMultisampleCreateInfo>(), 48);
        assert_eq!(std::mem::size_of::<VkDepthStencilCreateInfo>(), 104);
        assert_eq!(std::mem::size_of::<VkBlendAttachment>(), 32);
        assert_eq!(std::mem::size_of::<VkColorBlendCreateInfo>(), 56);
        assert_eq!(std::mem::size_of::<VkPushRange>(), 12);
        assert_eq!(std::mem::size_of::<VkStageInfo>(), 48);
        assert_eq!(std::mem::size_of::<VkGraphicsPipelineCreateInfo>(), 144);
        assert_eq!(std::mem::size_of::<VkRenderPassBeginInfo>(), 64);
        assert_eq!(std::mem::size_of::<VkClearValue>(), 16);
        assert_eq!(std::mem::size_of::<VkImageBarrier>(), 72);
        assert_eq!(std::mem::size_of::<VkBufferImageCopy>(), 56);
        assert_eq!(std::mem::size_of::<VkDescriptorImageInfo>(), 24);
        assert_eq!(std::mem::size_of::<PushConstants>(), 48);
    }
}
