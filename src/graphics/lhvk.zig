const std = @import("std");
const vk = @import("vk_api.zig").vk;
const Window = if (@import("builtin").os.tag == .windows) @import("win32.zig").Window else @import("x.zig").Window;
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;
const assert = std.debug.assert;
const u = @import("lhvk_utils.zig");
const la = @import("../lin_alg/la.zig");
const TARGET_OS = @import("builtin").os.tag;
const Swapchain = @import("vulkan/swapchain.zig").Swapchain;
const Pipeline = @import("vulkan/pipeline.zig").Pipeline;
const v = @import("drawing/vertex.zig");

pub const LhvkGraphicsCtx = struct {
    window: Window,
    vk_app: VkApp,
    vk_appdata: VkAppData,
    current_image: u32,
    current_vertex_group: v.VertexList,
};

pub const InstanceWrapper = struct {
    instance: vk.VkInstance,
    debug_messenger: vk.VkDebugUtilsMessengerEXT,
};

pub const DeviceWrapper = struct {
    device: vk.VkDevice,
    graphics_queue: vk.VkQueue,
    present_queue: vk.VkQueue,
    surface: vk.VkSurfaceKHR,
};

pub const VkApp = struct {
    arena: Arena,
    instance_wrapper: InstanceWrapper,
    device_wrapper: DeviceWrapper,
    device: vk.VkDevice,
    graphics_queue: vk.VkQueue,
    present_queue: vk.VkQueue,
    surface: vk.VkSurfaceKHR,
    lhswapchain: Swapchain,
    swapchain: vk.VkSwapchainKHR,
    swapchain_images: []vk.VkImage,
    format: vk.VkFormat,
    extent: vk.VkExtent2D,
    image_views: []vk.VkImageView,
    render_pass: vk.VkRenderPass,
    lhpipeline: Pipeline,
    pipeline_layout: vk.VkPipelineLayout,
    graphics_pipeline: vk.VkPipeline,
    swapchain_framebuffers: []vk.VkFramebuffer,
    command_pool: vk.VkCommandPool,
    vertex_buffer: vk.VkBuffer,
    vertex_buffer_size: u64,
    vertex_buffer_mem: vk.VkDeviceMemory,
    command_buffer: vk.VkCommandBuffer,
    image_available_sem: vk.VkSemaphore,
    render_finished_sem: vk.VkSemaphore,
    in_flight_fence: vk.VkFence,
    max_frames_in_flight: u32,
};

pub const VkAppData = struct {
    arena: Arena,
    physical_device: vk.VkPhysicalDevice,
    queue_priority: f32,
};

pub const VulkanInitError = error{
    CreateInstance,
};

fn debug_callback(message_severity: c_uint, message_type: u32, pCallbackData: [*c]const vk.VkDebugUtilsMessengerCallbackDataEXT, pUserData: ?*anyopaque) callconv(.C) u32 {
    _ = message_type;
    switch (message_severity) {
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => {
            const len = std.mem.len(pCallbackData.*.pMessage);
            u.err("{s}", .{pCallbackData.*.pMessage[0..len]});
        },
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => {
            const len = std.mem.len(pCallbackData.*.pMessage);
            u.warn("{s}", .{pCallbackData.*.pMessage[0..len]});
        },
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT => {
            const len = std.mem.len(pCallbackData.*.pMessage);
            u.trace("{s}", .{pCallbackData.*.pMessage[0..len]});
        },
        else => {
            const len = std.mem.len(pCallbackData.*.pMessage);
            u.trace("{s}", .{pCallbackData.*.pMessage[0..len]});
        },
    }
    if (pUserData == null) {}
    return 0;
}

fn check_validation_layers() bool {
    std.debug.print("Checking validation layers\n", .{});
    var arena: Arena = lhmem.make_arena((1 << 10) * 16);
    //defer arena.release();

    std.debug.print("Arena done...\n", .{});
    const validationLayers: [2][]const u8 = .{
        "VK_LAYER_KHRONOS_validation",
        "VK_KHR_portability_enumeration",
    };
    var layer_count: u32 = 0;
    _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, null);
    var count: usize = 0;
    count = @as(usize, @intCast(layer_count));
    const available_layers: []vk.VkLayerProperties = arena.push_array(vk.VkLayerProperties, count)[0..count];
    _ = vk.vkEnumerateInstanceLayerProperties(&layer_count, @ptrCast(available_layers));

    for (validationLayers) |layer| {
        var layer_found: bool = false;
        for (available_layers) |av| {
            if (u.strcmp(layer.ptr, &av.layerName) == true) {
                layer_found = true;
            }
        }
        if (!layer_found) {
            return false;
        }
    }
    return true;
}

fn populate_debug_info(dci: *vk.VkDebugUtilsMessengerCreateInfoEXT) void {
    dci.sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
    dci.pNext = null;
    dci.messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_FLAG_BITS_MAX_ENUM_EXT;
    dci.messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_DEVICE_ADDRESS_BINDING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_FLAG_BITS_MAX_ENUM_EXT;
    dci.pfnUserCallback = &debug_callback;
    dci.pUserData = null;
}

fn create_debug_utils_messenger(instance: vk.VkInstance, pCreateInfo: ?*const vk.VkDebugUtilsMessengerCreateInfoEXT, pAllocator: ?*const vk.VkAllocationCallbacks, pDebugMessenger: ?*vk.VkDebugUtilsMessengerEXT) vk.VkResult {
    const func: vk.PFN_vkCreateDebugUtilsMessengerEXT = @ptrCast(vk.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT"));
    if (func != null) {
        return func.?(instance, pCreateInfo, pAllocator, pDebugMessenger);
    } else {
        u.err("NOOOOO", .{});
        return vk.VK_FALSE;
    }
}

fn setup_debug_messenger(app: *VkApp) bool {
    const create_info: vk.VkDebugUtilsMessengerCreateInfoEXT = .{
        .sType = vk.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .pNext = null,
        .messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
        .messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = &debug_callback,
        .pUserData = null,
    };
    if (create_debug_utils_messenger(app.instance_wrapper.instance, &create_info, null, &app.instance_wrapper.debug_messenger) != vk.VK_SUCCESS) {
        return false;
    }
    return true;
}

fn create_instance(app: *VkApp, app_data: ?*VkAppData) VulkanInitError!void {
    if (app_data == null) {}
    var app_info: vk.VkApplicationInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "Hello",
        .applicationVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
        .pEngineName = "Noname",
        .engineVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
        .apiVersion = vk.VK_MAKE_API_VERSION(0, 1, 0, 0),
    };

    var debug_create_info: vk.VkDebugUtilsMessengerCreateInfoEXT = undefined;

    var create_info: vk.VkInstanceCreateInfo = std.mem.zeroes(vk.VkInstanceCreateInfo);
    create_info.sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &app_info;
    create_info.pNext = null;
    create_info.flags = vk.VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
    // Layers -> enable validation layer for debug only
    if (check_validation_layers()) {
        const validation = app.arena.push_string("VK_LAYER_KHRONOS_validation");
        const enumeration = app.arena.push_string("VK_KHR_portability_enumeration");
        const profiles = app.arena.push_string("VK_LAYER_KHRONOS_profiles");
        const layers: [3][*c]const u8 = .{ validation.ptr, enumeration.ptr, profiles.ptr };
        create_info.enabledLayerCount = 3;
        create_info.ppEnabledLayerNames = &layers;
        populate_debug_info(&debug_create_info);
        create_info.pNext = &debug_create_info;
    } else {
        create_info.enabledLayerCount = 0;
        create_info.ppEnabledLayerNames = null;
    }
    // Extensions
    var editable: [*][*c]const u8 = app.arena.push_array([*c]const u8, 5);
    editable[0] = vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    editable[1] = vk.VK_KHR_SURFACE_EXTENSION_NAME;
    // TODO: xcb extensions
    if (TARGET_OS == .windows) {
        editable[2] = vk.VK_KHR_WIN32_SURFACE_EXTENSION_NAME;
    } else {
        editable[2] = vk.VK_KHR_XLIB_SURFACE_EXTENSION_NAME;
    }
    editable[3] = "VK_KHR_get_physical_device_properties2";
    editable[4] = vk.VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME;
    create_info.enabledExtensionCount = 5;
    create_info.ppEnabledExtensionNames = editable;
    _ = vk.vkCreateInstance(&create_info, null, @constCast(&app.*.instance_wrapper.instance));
    if (app.instance_wrapper.instance == null) {
        return VulkanInitError.CreateInstance;
    }
    // TODO: No more assert, this cannot panic!
    assert(app.instance_wrapper.instance != null);
}

fn find_queue_families(ctx: *LhvkGraphicsCtx, device: vk.VkPhysicalDevice) !QueueFamilyIndices {
    const app = ctx.vk_app;
    var scratch: Arena = lhmem.scratch_block();
    var indices: QueueFamilyIndices = .{ .graphics_family = null, .present_family = null };
    var queue_family_count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);
    const queue_families: [*]vk.VkQueueFamilyProperties = scratch.push_array(vk.VkQueueFamilyProperties, queue_family_count);
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, @ptrCast(@constCast(queue_families)));
    for (queue_families, 0..queue_family_count) |queue, i| {
        var present_support: u32 = 0;
        _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), app.surface, &present_support);
        if (present_support == vk.VK_TRUE) {
            indices.present_family = @intCast(i);
        }
        if ((queue.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT) == 1) {
            indices.graphics_family = @intCast(i);
        }
    }
    return indices;
}

fn is_device_suitable(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR, rates: *u8, ctx: *LhvkGraphicsCtx) bool {
    var device_properties: vk.VkPhysicalDeviceProperties = std.mem.zeroes(vk.VkPhysicalDeviceProperties);
    var device_features: vk.VkPhysicalDeviceFeatures = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);

    vk.vkGetPhysicalDeviceProperties(device, &device_properties);
    vk.vkGetPhysicalDeviceFeatures(device, &device_features);
    const families_found: ?QueueFamilyIndices = find_queue_families(ctx, device) catch return null;
    var scratch = lhmem.scratch_block();
    const swapchain_support = query_swapchain_support(&scratch, device, surface);
    const supports_swapchain: bool = (swapchain_support.presentModes.len != 0) and (swapchain_support.formats.len != 0);

    switch (device_properties.deviceType) {
        vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => {
            rates.* = 10;
        },
        vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => {
            rates.* = 5;
        },
        else => {
            rates.* = 0;
        },
    }
    if (rates.* != 0 and device_features.geometryShader != 0 and families_found != null) {
        u.trace("{s} found.", .{device_properties.deviceName});
        return supports_swapchain;
    }
    return false;
}

fn pick_physical_device(ctx: *LhvkGraphicsCtx) !void {
    const app: *VkApp = &ctx.vk_app;
    const app_data: *VkAppData = &ctx.vk_appdata;
    var tmp: Arena = lhmem.scratch_block();
    var device_count: u32 = 0;
    var rates: []u8 = undefined;

    _ = vk.vkEnumeratePhysicalDevices(app.instance_wrapper.instance, &device_count, null);
    if (device_count == 0) {
        std.debug.print("No physical devices found", .{});
    }
    rates = tmp.push_array(u8, 2)[0..device_count];
    const physical_devices_bytes = tmp.push_array(vk.VkPhysicalDevice, device_count);
    u.trace("Devices found: {}", .{device_count});
    const physical_devices: [*]vk.VkPhysicalDevice = @ptrCast(@alignCast(physical_devices_bytes));
    _ = vk.vkEnumeratePhysicalDevices(app.instance_wrapper.instance, &device_count, physical_devices);
    const dview: []vk.VkPhysicalDevice = physical_devices[0..device_count];
    for (dview, 0..device_count) |device, i| {
        if (!is_device_suitable(device, app.surface, &rates[i], ctx)) rates[i] = 0;
    }
    var max: i32 = 0;
    var i: usize = 0;
    for (0..rates.len) |idx| {
        if (rates[idx] > max) {
            max = rates[idx];
            i = idx;
        }
    }
    app_data.physical_device = dview[i];
}

pub const QueueFamilyIndices = struct {
    graphics_family: ?u32,
    present_family: ?u32,
};

fn create_logical_device(ctx: *LhvkGraphicsCtx) void {
    var app: *VkApp = &ctx.vk_app;
    var app_data: *VkAppData = &ctx.vk_appdata;
    const indices: QueueFamilyIndices = find_queue_families(ctx, app_data.physical_device) catch {
        return .{ .graphics_family = null, .present_family = null };
    };

    assert(indices.graphics_family != null);
    assert(indices.present_family != null);
    app_data.queue_priority = 1.0;
    var queue_create_infos: [2]vk.VkDeviceQueueCreateInfo = undefined;
    { // graphics queue
        queue_create_infos[0].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queue_create_infos[0].pNext = null;
        queue_create_infos[0].flags = 0;
        queue_create_infos[0].queueFamilyIndex = indices.graphics_family.?;
        queue_create_infos[0].queueCount = 1;
        queue_create_infos[0].pQueuePriorities = &app_data.queue_priority;
    }

    { // present family
        queue_create_infos[1].sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
        queue_create_infos[1].pNext = null;
        queue_create_infos[1].flags = 0;
        queue_create_infos[1].queueFamilyIndex = indices.present_family.?;
        queue_create_infos[1].queueCount = 1;
        queue_create_infos[1].pQueuePriorities = &app_data.queue_priority;
    }

    var device_features: vk.VkPhysicalDeviceFeatures = undefined;
    vk.vkGetPhysicalDeviceFeatures(app_data.physical_device, &device_features);
    u.trace("device_features {any}", .{device_features});
    var create_info: vk.VkDeviceCreateInfo = undefined;
    create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = 0;
    create_info.pQueueCreateInfos = &queue_create_infos;
    create_info.queueCreateInfoCount = 1;
    create_info.pEnabledFeatures = &device_features;
    // EXTENSIONS
    {
        var count: u32 = 1;
        if (TARGET_OS == .windows) {
            count = 2;
        }
        var editable: [*][*c]const u8 = app.arena.push_array([*c]const u8, count);
        editable[0] = vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME;
        // WINDOWS thing
        if (TARGET_OS == .windows) {
            editable[1] = "VK_KHR_portability_subset";
        }

        create_info.enabledExtensionCount = count;
        create_info.ppEnabledExtensionNames = editable;
    }
    // LAYERS IGNORED
    {
        create_info.enabledLayerCount = 0;
        create_info.ppEnabledLayerNames = null;
    }

    assert(vk.vkCreateDevice(app_data.physical_device, &create_info, null, &app.device) == vk.VK_SUCCESS);
    vk.vkGetDeviceQueue(app.device, indices.graphics_family.?, 0, &app.graphics_queue);
    vk.vkGetDeviceQueue(app.device, indices.present_family.?, 0, &app.present_queue);
}

const SwapChainSupportDetails = struct {
    capabilities: vk.VkSurfaceCapabilitiesKHR,
    formats: []vk.VkSurfaceFormatKHR,
    presentModes: []vk.VkPresentModeKHR,
};

fn query_swapchain_support(arena: *Arena, device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR) SwapChainSupportDetails {
    var details: SwapChainSupportDetails = undefined;
    _ = vk.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &details.capabilities);

    var format_count: u32 = 0;
    _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, null);
    if (format_count != 0) {
        details.formats = arena.push_array(vk.VkSurfaceFormatKHR, format_count)[0..format_count];
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, details.formats.ptr);
    }

    var present_mode_count: u32 = 0;
    _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null);
    if (present_mode_count != 0) {
        details.presentModes = arena.push_array(vk.VkPresentModeKHR, present_mode_count)[0..present_mode_count];
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, details.presentModes.ptr);
    }

    return details;
}

fn choose_surface_format(available_formats: []vk.VkSurfaceFormatKHR) vk.VkSurfaceFormatKHR {
    for (available_formats) |format| {
        if (format.format == vk.VK_FORMAT_R8G8B8A8_SRGB and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) return format;
    }
    return available_formats[0];
}

fn choose_swap_extent(window: Window, capabilities: vk.VkSurfaceCapabilitiesKHR) vk.VkExtent2D {
    var actual_extent: vk.VkExtent2D = .{
        .width = window.width,
        .height = window.height,
    };
    la.clamp(u32, &actual_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
    la.clamp(u32, &actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
    return actual_extent;
}

fn create_render_pass(device: vk.VkDevice, format: u32) !vk.VkRenderPass {
    var attachment_description: vk.VkAttachmentDescription = std.mem.zeroes(vk.VkAttachmentDescription);
    attachment_description.format = format;
    attachment_description.samples = vk.VK_SAMPLE_COUNT_1_BIT;
    attachment_description.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachment_description.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
    attachment_description.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment_description.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment_description.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    attachment_description.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    var color_attachment_ref: vk.VkAttachmentReference = std.mem.zeroes(vk.VkAttachmentReference);
    color_attachment_ref.attachment = 0;
    color_attachment_ref.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var subpass: vk.VkSubpassDescription = std.mem.zeroes(vk.VkSubpassDescription);
    subpass.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &color_attachment_ref;

    var dependency = std.mem.zeroes(vk.VkSubpassDependency);
    dependency.srcSubpass = vk.VK_SUBPASS_EXTERNAL;
    dependency.dstSubpass = 0;
    dependency.srcStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.srcAccessMask = 0;
    dependency.dstStageMask = vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    dependency.dstAccessMask = vk.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;

    var renderpass_info: vk.VkRenderPassCreateInfo = std.mem.zeroes(vk.VkRenderPassCreateInfo);
    renderpass_info.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderpass_info.attachmentCount = 1;
    renderpass_info.pAttachments = &attachment_description;
    renderpass_info.subpassCount = 1;
    renderpass_info.pSubpasses = &subpass;
    renderpass_info.dependencyCount = 1;
    renderpass_info.pDependencies = &dependency;
    var render_pass: vk.VkRenderPass = undefined;

    if (vk.vkCreateRenderPass(device, &renderpass_info, null, &render_pass) != vk.VK_SUCCESS) return error.CANNOTCREATERENDERPASS;
    return render_pass;
}

fn create_framebuffers(device: vk.VkDevice, swapchain: *Swapchain, render_pass: vk.VkRenderPass) void {
    for (0..swapchain.images.len) |i| {
        var framebuffer_create_info: vk.VkFramebufferCreateInfo = std.mem.zeroes(vk.VkFramebufferCreateInfo);
        framebuffer_create_info.sType = vk.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO;
        framebuffer_create_info.renderPass = render_pass;
        framebuffer_create_info.attachmentCount = 1;
        framebuffer_create_info.pAttachments = &swapchain.image_views[i];
        framebuffer_create_info.width = swapchain.extent.width;
        framebuffer_create_info.height = swapchain.extent.height;
        framebuffer_create_info.layers = 1;
        if (vk.vkCreateFramebuffer(device, &framebuffer_create_info, null, &swapchain.framebuffers[i]) != vk.VK_SUCCESS) {
            u.err("Couldnt create framebuffer {}", .{i});
        }
    }
}

fn create_command_pool(ctx: *LhvkGraphicsCtx) void {
    var app = &ctx.vk_app;
    const appdata = &ctx.vk_appdata;
    const queue_family_indices = try find_queue_families(ctx, appdata.physical_device);
    var pool_info: vk.VkCommandPoolCreateInfo = std.mem.zeroes(vk.VkCommandPoolCreateInfo);
    pool_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pool_info.flags = vk.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pool_info.queueFamilyIndex = queue_family_indices.graphics_family.?;
    if (vk.vkCreateCommandPool(app.device, &pool_info, null, &app.command_pool) != vk.VK_SUCCESS) {
        u.err("Couldnt create command pool", .{});
    }
}

fn create_command_buffer(ctx: *LhvkGraphicsCtx) void {
    var app: *VkApp = &ctx.vk_app;
    var alloc_info: vk.VkCommandBufferAllocateInfo = std.mem.zeroes(vk.VkCommandBufferAllocateInfo);
    alloc_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc_info.commandPool = app.command_pool;
    alloc_info.level = vk.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc_info.commandBufferCount = 1;
    if (vk.vkAllocateCommandBuffers(app.device, &alloc_info, &app.command_buffer) != vk.VK_SUCCESS) {
        u.err("Cannot create command buffer", .{});
    }
}

pub fn begin_command_buffer_rendering(ctx: *LhvkGraphicsCtx) void {
    const app: *VkApp = &ctx.vk_app;
    var begin_info = std.mem.zeroes(vk.VkCommandBufferBeginInfo);
    begin_info.sType = vk.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    begin_info.flags = 0;
    begin_info.pInheritanceInfo = null;
    if (vk.vkBeginCommandBuffer(app.command_buffer, &begin_info) != vk.VK_SUCCESS) u.err("Cannot record command buffer", .{});

    var rp_begin_info = std.mem.zeroes(vk.VkRenderPassBeginInfo);
    rp_begin_info.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO;
    rp_begin_info.renderPass = app.render_pass;
    rp_begin_info.framebuffer = app.swapchain_framebuffers[ctx.current_image];
    var offset: vk.VkOffset2D = undefined;
    offset.x = 0;
    offset.y = 0;
    rp_begin_info.renderArea.offset = offset;
    rp_begin_info.renderArea.extent = app.extent;
    var clear_value = std.mem.zeroes(vk.VkClearValue);
    clear_value.color.float32[0] = 0.0;
    clear_value.color.float32[1] = 0.0;
    clear_value.color.float32[2] = 0.0;
    clear_value.color.float32[3] = 0.0;
    rp_begin_info.clearValueCount = 1;
    rp_begin_info.pClearValues = &clear_value;

    vk.vkCmdBeginRenderPass(app.command_buffer, &rp_begin_info, vk.VK_SUBPASS_CONTENTS_INLINE);
    vk.vkCmdBindPipeline(app.command_buffer, vk.VK_PIPELINE_BIND_POINT_GRAPHICS, app.graphics_pipeline);

    var data: ?*anyopaque = undefined;
    //var scratch = lhmem.make_arena(app.vertex_buffer_size);
    _ = vk.vkMapMemory(app.device, app.vertex_buffer_mem, 0, app.vertex_buffer_size, 0, &data);

    const data_view: []u8 = @as([*]u8, @ptrCast(data))[0..app.vertex_buffer_size];
    // 1: graphics.drawing.vertex.RawVertex{ .pos = { 1.25e-1, 1.6666667e-1 }, .color = { 1e0, 0e0, 0e0, 1e0 } },
    // 2: graphics.drawing.vertex.RawVertex{ .pos = { 2.5e-1, 3.3333334e-1 }, .color = { 1e0, 0e0, 0e0, 1e0 } },
    // 3: graphics.drawing.vertex.RawVertex{ .pos = { 3.75e-1, 5e-1 }, .color = { 1e0, 0e0, 0e0, 1e0 } }
    // const v1 : v.RawVertex = .{
    //     .pos = .{0.125, 0.166},
    //     .color = .{1.0,1.0,1.0,1.0}
    // };
    // const v2 : v.RawVertex = .{
    //     .pos = .{0.25, 0.33},
    //     .color = .{1.0,1.0,1.0,1.0}
    // };
    // const v3 : v.RawVertex = .{
    //     .pos = .{0.375, 0.5},
    //     .color = .{1.0,1.0,1.0,1.0}
    // };

    // const verticesx = [_]v.RawVertex{v1, v2, v3};

    // TODO: LOOK AT WHY I cant print the current vertex group but the group above works fine
    const vertices = ctx.current_vertex_group.compress(&ctx.current_vertex_group.arena);
    const vertices_bytes = lhmem.get_bytes(v.RawVertex, vertices.len, vertices.ptr);
    std.mem.copyForwards(u8, data_view, vertices_bytes);

    _ = vk.vkUnmapMemory(app.device, app.vertex_buffer_mem);

    const offsets: u64 = 0;
    vk.vkCmdBindVertexBuffers(app.command_buffer, 0, 1, &app.vertex_buffer, &offsets);
    vk.vkCmdDraw(app.command_buffer, @intCast(vertices.len), 1, 0, 0);
}

pub fn end_command_buffer_rendering(ctx: *LhvkGraphicsCtx) void {
    const app: *VkApp = &ctx.vk_app;
    vk.vkCmdEndRenderPass(app.command_buffer);
    if (vk.vkEndCommandBuffer(app.command_buffer) != vk.VK_SUCCESS) {
        u.err("Ending command buffer not posible", .{});
    }

    // TODO(lucashdez): PROBABLY SEPARATE In ANOTHER FUNCTION
    var submit_info = std.mem.zeroes(vk.VkSubmitInfo);
    submit_info.sType = vk.VK_STRUCTURE_TYPE_SUBMIT_INFO;

    submit_info.waitSemaphoreCount = 1;
    submit_info.pWaitSemaphores = &app.image_available_sem;
    const wait_stages: [1]vk.VkPipelineStageFlags = .{vk.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    submit_info.pWaitDstStageMask = &wait_stages;
    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &app.command_buffer;
    submit_info.signalSemaphoreCount = 1;
    submit_info.pSignalSemaphores = &app.render_finished_sem;
    if (vk.vkQueueSubmit(app.graphics_queue, 1, &submit_info, app.in_flight_fence) != vk.VK_SUCCESS) {
        u.err("Cannot submit commands", .{});
    }

    var present_info = std.mem.zeroes(vk.VkPresentInfoKHR);
    present_info.sType = vk.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    present_info.waitSemaphoreCount = 1;
    present_info.pWaitSemaphores = &app.render_finished_sem;
    present_info.swapchainCount = 1;
    present_info.pSwapchains = &app.swapchain;
    present_info.pImageIndices = &ctx.current_image;
    present_info.pResults = null;

    const presenting_result = vk.vkQueuePresentKHR(app.present_queue, &present_info);
    if (presenting_result == vk.VK_ERROR_OUT_OF_DATE_KHR or
        presenting_result == vk.VK_SUBOPTIMAL_KHR)
    {
        recreate_swapchain(ctx);
        u.info("Recreating swapchain", .{});
    }
    ctx.current_image = (ctx.current_image + 1) % app.max_frames_in_flight;
}

fn create_sync_objects(ctx: *LhvkGraphicsCtx) void {
    var app: *VkApp = &ctx.vk_app;
    var semaphore_create_info = std.mem.zeroes(vk.VkSemaphoreCreateInfo);
    semaphore_create_info.sType = vk.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO;

    var fence_create_info = std.mem.zeroes(vk.VkFenceCreateInfo);
    fence_create_info.sType = vk.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    fence_create_info.flags = vk.VK_FENCE_CREATE_SIGNALED_BIT;

    if (vk.vkCreateSemaphore(app.device, &semaphore_create_info, null, &app.image_available_sem) != vk.VK_SUCCESS) u.err("Cannot create semaphore", .{});
    if (vk.vkCreateSemaphore(app.device, &semaphore_create_info, null, &app.render_finished_sem) != vk.VK_SUCCESS) u.err("Cannot create semaphore", .{});
    if (vk.vkCreateFence(app.device, &fence_create_info, null, &app.in_flight_fence) != vk.VK_SUCCESS) u.err("Cannot create fence", .{});
}

fn cleanup_swapchain(ctx: *LhvkGraphicsCtx) void {
    for (0..ctx.vk_app.swapchain_framebuffers.len) |i| {
        vk.vkDestroyFramebuffer(ctx.vk_app.device, ctx.vk_app.swapchain_framebuffers[i], null);
    }
    for (0..ctx.vk_app.image_views.len) |i| {
        vk.vkDestroyImageView(ctx.vk_app.device, ctx.vk_app.image_views[i], null);
    }
    vk.vkDestroySwapchainKHR(ctx.vk_app.device, ctx.vk_app.swapchain, null);
}

fn recreate_swapchain(ctx: *LhvkGraphicsCtx) void {
    _ = vk.vkDeviceWaitIdle(ctx.vk_app.device);
    //cleanup_swapchain(ctx);
    //create_swapchain(ctx) catch {
    //   u.err("Something happened recreating the swapchain", .{});
    //};
    //create_image_views(ctx) catch {
    //    u.err("Something happened recreating the image views", .{});
    //};
    //create_framebuffers(ctx);
}

fn find_memory_type(ctx: *LhvkGraphicsCtx, filter: u32, props: vk.VkMemoryPropertyFlags) u32 {
    _ = filter;
    var mem_props: vk.VkPhysicalDeviceMemoryProperties = undefined;
    vk.vkGetPhysicalDeviceMemoryProperties(ctx.vk_appdata.physical_device, &mem_props);
    for (0..mem_props.memoryTypeCount) |i| {
        if ((mem_props.memoryTypes[i].propertyFlags & props) == props)
            return @intCast(i);
    }
    return 0;
}

fn create_vertex_buffer(ctx: *LhvkGraphicsCtx) void {
    var app: *VkApp = &ctx.vk_app;
    var buffer_info = std.mem.zeroes(vk.VkBufferCreateInfo);
    buffer_info.sType = vk.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    buffer_info.size = (1 << 10) * 20;
    app.vertex_buffer_size = buffer_info.size;
    buffer_info.usage = vk.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
    buffer_info.sharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;

    if (vk.vkCreateBuffer(app.device, &buffer_info, null, &app.vertex_buffer) != vk.VK_SUCCESS) u.err("CANNOT CREATE VERTEX BUFFER", .{});

    var mem_reqs = std.mem.zeroes(vk.VkMemoryRequirements);
    _ = vk.vkGetBufferMemoryRequirements(app.device, app.vertex_buffer, &mem_reqs);

    var alloc_info: vk.VkMemoryAllocateInfo = std.mem.zeroes(vk.VkMemoryAllocateInfo);
    alloc_info.sType = vk.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    alloc_info.allocationSize = mem_reqs.size;
    alloc_info.memoryTypeIndex = find_memory_type(ctx, mem_reqs.memoryTypeBits, vk.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);

    if (vk.vkAllocateMemory(app.device, &alloc_info, null, &app.vertex_buffer_mem) != vk.VK_SUCCESS) u.err("CANNOT ALLOCATE MEMORY", .{});

    _ = vk.vkBindBufferMemory(app.device, app.vertex_buffer, app.vertex_buffer_mem, 0);
}

pub fn init_vulkan(ctx: *LhvkGraphicsCtx) !void {
    ctx.vk_app.max_frames_in_flight = 2;
    _ = try create_instance(&ctx.vk_app, &ctx.vk_appdata);
    _ = setup_debug_messenger(&ctx.vk_app);
    create_surface(ctx, &ctx.vk_app);
    _ = try pick_physical_device(ctx);
    assert(ctx.vk_appdata.physical_device != null);
    create_logical_device(ctx);
    ctx.vk_app.lhswapchain = try Swapchain.init(ctx);
    //try create_swapchain(ctx);
    ctx.vk_app.render_pass = try create_render_pass(ctx.vk_app.device, ctx.vk_app.lhswapchain.format.format);
    ctx.vk_app.lhpipeline = try Pipeline.init(ctx.vk_app.device, ctx.vk_app.render_pass, ctx.vk_app.lhswapchain);
    create_framebuffers(ctx.vk_app.device, &ctx.vk_app.lhswapchain, ctx.vk_app.render_pass);
    // TODO: Continue refactor
    create_command_pool(ctx);
    create_vertex_buffer(ctx);
    create_command_buffer(ctx);
    create_sync_objects(ctx);
}

fn create_surface(ctx: *const LhvkGraphicsCtx, app: *VkApp) void {
    if (TARGET_OS == .windows) {
        u.warn("ALIGNMENT: hwnd {}\n\thinstance: {}\n\nhwnd {}|| {d:.10} \nhinstance {} || {d:.10}", .{ @alignOf(*anyopaque), @alignOf(vk.HINSTANCE), @intFromPtr(ctx.window.instance.?), @as(f32, @floatFromInt(@intFromPtr(ctx.window.instance.?))) / 8, @intFromPtr(ctx.window.surface.?), @as(f32, @floatFromInt(@intFromPtr(ctx.window.surface.?))) / 8 });
        var create_info: vk.VkWin32SurfaceCreateInfoKHR = .{
            .sType = vk.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hwnd = @alignCast(@ptrCast(ctx.window.surface.?)),
            .hinstance = @alignCast(@ptrCast(ctx.window.instance.?)),
        };
        const result = vk.vkCreateWin32SurfaceKHR(app.instance_wrapper.instance, &create_info, null, &app.surface);
        assert(result == vk.VK_SUCCESS);
    } else {
        var create_info: vk.VkXlibSurfaceCreateInfoKHR = .{
            .sType = vk.VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
            .dpy = @alignCast(@ptrCast(ctx.window.raw.display.?)),
            .window = 0,
        };
        //const result = vk.vkCreateXlibSurfaceKHR();
        const result = vk.vkCreateXlibSurfaceKHR(app.instance_wrapper.instance, &create_info, null, &app.surface);
        assert(result == vk.VK_SUCCESS);
    }
}

pub fn prepare_frame(ctx: *LhvkGraphicsCtx) bool {
    var app: *VkApp = &ctx.vk_app;
    _ = vk.vkWaitForFences(app.device, 1, &app.in_flight_fence, vk.VK_TRUE, std.math.maxInt(u64));
    _ = vk.vkResetFences(app.device, 1, &app.in_flight_fence);
    const next_image_result = vk.vkAcquireNextImageKHR(app.device, app.lhswapchain.handle, std.math.maxInt(u64), app.image_available_sem, null, &ctx.current_image);
    if (next_image_result == vk.VK_ERROR_OUT_OF_DATE_KHR) {
        recreate_swapchain(ctx);
        return true;
    }

    _ = vk.vkResetCommandBuffer(app.command_buffer, 0);
    return false;
}
