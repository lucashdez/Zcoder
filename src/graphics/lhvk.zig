const std = @import("std");
const vk = @import("vk_api.zig").vk;
const Window = if (@import("builtin").os.tag == .windows) @import("win32.zig").Window else @import("wayland.zig").Window;
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;
const assert = std.debug.assert;
const u = @import("lhvk_utils.zig");
const la = @import("../lin_alg/la.zig");


pub const LhvkGraphicsCtx = struct {
    window: Window,
    vk_app: VkApp,
    vk_appdata: VkAppData,
};

pub const VkApp = struct {
    arena: Arena,
    instance: vk.VkInstance,
    debug_messenger: vk.VkDebugUtilsMessengerEXT,
    device: vk.VkDevice,
    graphics_queue: vk.VkQueue,
    surface: vk.VkSurfaceKHR,
    swapchain: vk.VkSwapchainKHR,
    swapchain_images: []vk.VkImage,
    format: vk.VkFormat,
    extent: vk.VkExtent2D,
    image_views: []vk.VkImageView,
    render_pass: vk.VkRenderPass,
    pipeline_layout: vk.VkPipelineLayout,
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
        vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT => {
            const len = std.mem.len(pCallbackData.*.pMessage);
            u.trace("{s}", .{pCallbackData.*.pMessage[0..len]});
        },
        else => {
            u.trace("A", .{});
        },
    }
    const len = std.mem.len(pCallbackData.*.pMessage);
    u.trace("{s}", .{pCallbackData.*.pMessage[0..len]});
    _ = message_type;
    if (pUserData == null) {}
    return 0;
}

fn check_validation_layers() bool {
    std.debug.print("Checking validation layers\n", .{});
    var arena: Arena = lhmem.make_arena((1<<10) * 16);
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
    dci.messageSeverity = vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT;
    dci.messageType = vk.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT | vk.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
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
    if (create_debug_utils_messenger(app.instance, &create_info, null, &app.debug_messenger) != vk.VK_SUCCESS) {
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
        const layers: [2][*c]const u8 = .{validation.ptr, enumeration.ptr};
        create_info.enabledLayerCount = 2;
        create_info.ppEnabledLayerNames = &layers;
        populate_debug_info(&debug_create_info);
        create_info.pNext = &debug_create_info;
    } else {
        create_info.enabledLayerCount = 0;
        create_info.ppEnabledLayerNames = null;
    }
    // Extensions
    var editable: [*][*c]const u8 = app.arena.push_array([*c]const u8, 3);
    editable[0] = vk.VK_EXT_DEBUG_UTILS_EXTENSION_NAME;
    editable[1] = vk.VK_KHR_SURFACE_EXTENSION_NAME;
    // TODO: wayland and xcb extensions
    if (@import("builtin").os.tag == .windows) {
        editable[2] = vk.VK_KHR_WIN32_SURFACE_EXTENSION_NAME;
    } else {
        editable[2] = vk.VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME;
    }
    create_info.enabledExtensionCount = 3;
    create_info.ppEnabledExtensionNames = editable;
    _ = vk.vkCreateInstance(&create_info, null, @constCast(&app.*.instance));
    if (app.instance == null) {
        return VulkanInitError.CreateInstance;
    }
    assert(app.instance != null);
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

fn is_device_suitable(device: vk.VkPhysicalDevice, surface: vk.VkSurfaceKHR, rates: *u8, ctx: *LhvkGraphicsCtx) bool
{
    var device_properties: vk.VkPhysicalDeviceProperties = std.mem.zeroes(vk.VkPhysicalDeviceProperties);
    var device_features: vk.VkPhysicalDeviceFeatures = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);

    vk.vkGetPhysicalDeviceProperties(device, &device_properties);
    vk.vkGetPhysicalDeviceFeatures(device, &device_features);
    const families_found: ?QueueFamilyIndices = find_queue_families(ctx, device) catch return null;
    var scratch = lhmem.scratch_block();
    const swapchain_support = query_swapchain_support(&scratch, device, surface);
    const supports_swapchain: bool = (swapchain_support.presentModes.len != 0) and (swapchain_support.formats.len != 0);

    switch (device_properties.deviceType)
    {
        vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => {rates .* = 10;},
        vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => {rates.* = 5;},
        else => {rates.* = 0;}
    }
    if (rates.* != 0
        and device_features.geometryShader != 0
        and families_found != null)
    {
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

    _ = vk.vkEnumeratePhysicalDevices(app.instance, &device_count, null);
    if (device_count == 0) {
        std.debug.print("No physical devices found", .{});
    }
    rates = tmp.push_array(u8, 2)[0..device_count];
    const physical_devices_bytes = tmp.push_array(vk.VkPhysicalDevice, device_count);
    u.trace("Devices found: {}", .{device_count});
    const physical_devices: [*]vk.VkPhysicalDevice = @ptrCast(@alignCast(physical_devices_bytes));
    _ = vk.vkEnumeratePhysicalDevices(app.instance, &device_count, physical_devices);
    const dview: []vk.VkPhysicalDevice = physical_devices[0..device_count];
    for (dview, 0..device_count) |device, i|
    {
        if (!is_device_suitable(device, app.surface, &rates[i], ctx)) rates[i] = 0;
    }
    var max: i32 = 0;
    var i: usize = 0;
    for(0..rates.len) |idx|
    {
        if (rates[idx] > max)
        {
            max = rates[idx];
            i = idx;
        }
    }
    app_data.physical_device = dview[i];
}

const QueueFamilyIndices = struct {
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
    var queue_create_info: vk.VkDeviceQueueCreateInfo = undefined;
    queue_create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queue_create_info.pNext = null;
    queue_create_info.flags = 0;
    queue_create_info.queueFamilyIndex = indices.graphics_family.?;
    queue_create_info.queueCount = 1;
    app_data.queue_priority = 1.0;
    queue_create_info.pQueuePriorities = &app_data.queue_priority;

    var device_features: vk.VkPhysicalDeviceFeatures = undefined;
    vk.vkGetPhysicalDeviceFeatures(app_data.physical_device, &device_features);
    u.trace("device_features {any}", .{device_features});
    var create_info: vk.VkDeviceCreateInfo = undefined;
    create_info.sType = vk.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    create_info.pNext = null;
    create_info.flags = 0;
    create_info.pQueueCreateInfos = &queue_create_info;
    create_info.queueCreateInfoCount = 1;
    create_info.pEnabledFeatures = &device_features;
    // EXTENSIONS
    {
        var editable: [*][*c]const u8 = app.arena.push_array([*c]const u8, 1);
        editable[0] = vk.VK_KHR_SWAPCHAIN_EXTENSION_NAME;
        create_info.enabledExtensionCount = 1;
        create_info.ppEnabledExtensionNames = editable;
    }
    // LAYERS IGNORED
    {
        create_info.enabledLayerCount = 0;
        create_info.ppEnabledLayerNames = null;
    }

    assert(vk.vkCreateDevice(app_data.physical_device, &create_info, null, &app.device) == vk.VK_SUCCESS);
    vk.vkGetDeviceQueue(app.device, indices.graphics_family.?, 0, &app.graphics_queue);
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
    if (format_count != 0)
    {
        details.formats = arena.push_array(vk.VkSurfaceFormatKHR, format_count)[0..format_count];
        _ = vk.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &format_count, details.formats.ptr);
    }

    var present_mode_count: u32 = 0;
    _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, null);
    if (present_mode_count != 0)
    {
        details.presentModes = arena.push_array(vk.VkPresentModeKHR, present_mode_count)[0..present_mode_count];
        _ = vk.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &present_mode_count, details.presentModes.ptr);
    }

    return details;
}

fn choose_surface_format(available_formats: []vk.VkSurfaceFormatKHR) vk.VkSurfaceFormatKHR {
    for (available_formats) |format|
    {
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

fn create_swapchain(ctx: *LhvkGraphicsCtx)
!void
{
    var app: *VkApp = &ctx.vk_app;
    const app_data: *VkAppData = &ctx.vk_appdata;
    var arena = lhmem.scratch_block();
    const swapchain_support = query_swapchain_support(&arena, app_data.physical_device, app.surface);

    const surface_format = choose_surface_format(swapchain_support.formats);
    const present_mode = vk.VK_PRESENT_MODE_FIFO_KHR;
    const extent = choose_swap_extent(ctx.window, swapchain_support.capabilities);

    var image_count = swapchain_support.capabilities.minImageCount + 1;
    la.clamp(u32, &image_count, swapchain_support.capabilities.minImageCount, swapchain_support.capabilities.maxImageCount);

    var create_info: vk.VkSwapchainCreateInfoKHR = std.mem.zeroes(vk.VkSwapchainCreateInfoKHR);
    create_info.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    create_info.surface = app.surface;
    create_info.minImageCount = image_count;
    create_info.imageFormat = surface_format.format;
    create_info.imageColorSpace = surface_format.colorSpace;
    create_info.imageExtent = extent;
    create_info.imageArrayLayers = 1;
    create_info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    const indices = try find_queue_families(ctx, app_data.physical_device);
    const real_indices: [2]u32 = .{indices.graphics_family.?, indices.present_family.?};
    if (indices.graphics_family.? != indices.present_family.?)
    {
        create_info.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
        create_info.queueFamilyIndexCount = 2;
        create_info.pQueueFamilyIndices = &real_indices;
    } else {
        create_info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
        create_info.queueFamilyIndexCount = 0;
        create_info.pQueueFamilyIndices = null;
    }

    create_info.preTransform = swapchain_support.capabilities.currentTransform;
    create_info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    create_info.presentMode = present_mode;
    create_info.clipped = vk.VK_TRUE;
    create_info.oldSwapchain = null;

    if (vk.vkCreateSwapchainKHR(app.device, &create_info, null, &app.swapchain) != vk.VK_SUCCESS) {
        return error.CANNOT_CREATE_SWAPCHAIN;
    }
    _ = vk.vkGetSwapchainImagesKHR(app.device, app.swapchain, &image_count, null);
    app.swapchain_images = app.arena.push_array(vk.VkImage, image_count)[0..image_count];
    _ = vk.vkGetSwapchainImagesKHR(app.device, app.swapchain, &image_count, app.swapchain_images.ptr);
    app.format = surface_format.format;
    app.extent = extent;
}

fn create_image_views(ctx: *LhvkGraphicsCtx)
!void
{
    const app: *VkApp = &ctx.vk_app;
    app.image_views = app.arena.push_array(vk.VkImageView, app.swapchain_images.len)[0..app.swapchain_images.len];
    for (app.image_views, 0..app.swapchain_images.len) |view, i|
    {
        var info: vk.VkImageViewCreateInfo = std.mem.zeroes(vk.VkImageViewCreateInfo);
        info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        info.image = app.swapchain_images[i];
        info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
        info.format = app.format;
        info.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
        info.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
        info.subresourceRange.baseMipLevel = 0;
        info.subresourceRange.levelCount = 1;
        info.subresourceRange.baseArrayLayer = 0;
        info.subresourceRange.layerCount = 1;
        // BUG: Can be copying images instead of modifying array
        if (vk.vkCreateImageView(app.device, &info, null, @constCast(&view)) != vk.VK_SUCCESS) return error.CannotCreateImageView;
    }
}

fn read_file(arena: *lhmem.Arena, file_name: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(file_name, .{});
    const metadata = try file.metadata();
    const size = metadata.size();
    const buff: []u8 = arena.push_array(u8, size)[0..size];
    const reader = file.reader();
    const ret = try reader.readUntilDelimiterOrEof(@constCast(buff), 0);
    return ret.?;
}

fn create_shader_module(device: vk.VkDevice, code: []const u8) ?vk.VkShaderModule {
    var create_info: vk.VkShaderModuleCreateInfo = .{
        .sType = vk.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = code.len,
        .pCode = @alignCast(@ptrCast(code.ptr)),
    };
    var shader_module: vk.VkShaderModule = undefined;
    if (vk.vkCreateShaderModule(device, &create_info, null, &shader_module) != vk.VK_SUCCESS) return null;
    return shader_module;
}

fn create_graphics_pipeline(ctx: *LhvkGraphicsCtx) !void {
    const app: *VkApp = &ctx.vk_app;
    const appdata: *VkAppData = &ctx.vk_appdata;
    const vert_bytes = try read_file(&appdata.arena, "../../src/shaders/vert.spv");
    const frag_bytes = try read_file(&appdata.arena, "../../src/shaders/frag.spv");

    const vert_shader = create_shader_module(app.device, vert_bytes).?;
    const frag_shader = create_shader_module(app.device, frag_bytes).?;

    var vert_shader_stage_create_info: vk.VkPipelineShaderStageCreateInfo  = undefined;
    vert_shader_stage_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    vert_shader_stage_create_info.stage = vk.VK_SHADER_STAGE_VERTEX_BIT;
    vert_shader_stage_create_info.module = vert_shader;
    vert_shader_stage_create_info.pName = "main";

    var frag_shader_stage_create_info: vk.VkPipelineShaderStageCreateInfo  = undefined;
    frag_shader_stage_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    frag_shader_stage_create_info.stage = vk.VK_SHADER_STAGE_FRAGMENT_BIT;
    frag_shader_stage_create_info.module = frag_shader;
    frag_shader_stage_create_info.pName = "main";

    const stage_infos: [2]vk.VkPipelineShaderStageCreateInfo = .{vert_shader_stage_create_info, frag_shader_stage_create_info};

    var vertex_input_info: vk.VkPipelineVertexInputStateCreateInfo = undefined;
    vertex_input_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;
    vertex_input_info.vertexBindingDescriptionCount = 0;
    vertex_input_info.pVertexBindingDescriptions = null;
    vertex_input_info.vertexAttributeDescriptionCount = 0;
    vertex_input_info.pVertexAttributeDescriptions = null;

    var input_assembly_create_info: vk.VkPipelineInputAssemblyStateCreateInfo = undefined;
    input_assembly_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    input_assembly_create_info.topology = vk.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
    input_assembly_create_info.primitiveRestartEnable = vk.VK_FALSE;


    var viewport: vk.VkViewport = undefined;
    viewport.x = 0.0;
    viewport.y = 0.0;
    viewport.width = @as(f32, @floatFromInt(app.extent.width));
    viewport.height = @as(f32, @floatFromInt(app.extent.height));
    viewport.minDepth = 0.0;
    viewport.maxDepth = 1.0;

    var scissor: vk.VkRect2D = undefined;
    var offset: vk.VkOffset2D = undefined;
    offset.x = 0;
    offset.y = 0;
    scissor.offset =  offset;
    scissor.extent = app.extent;

    var viewport_state_create_info: vk.VkPipelineViewportStateCreateInfo = undefined;
    viewport_state_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    viewport_state_create_info.viewportCount = 1;
    viewport_state_create_info.pViewports = &viewport;
    viewport_state_create_info.scissorCount = 1;
    viewport_state_create_info.pScissors = &scissor;

    var rasterizer : vk.VkPipelineRasterizationStateCreateInfo = undefined;
    rasterizer.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rasterizer.depthClampEnable = vk.VK_FALSE;
    rasterizer.rasterizerDiscardEnable = vk.VK_FALSE;
    rasterizer.polygonMode = vk.VK_POLYGON_MODE_FILL;
    rasterizer.lineWidth = 1.0;
    rasterizer.cullMode = vk.VK_CULL_MODE_BACK_BIT;
    rasterizer.frontFace = vk.VK_FRONT_FACE_CLOCKWISE;
    rasterizer.depthBiasEnable = vk.VK_FALSE;
    rasterizer.depthBiasConstantFactor = 0.0;
    rasterizer.depthBiasClamp = 0.0;
    rasterizer.depthBiasSlopeFactor = 0.0;

    var multisampling: vk.VkPipelineMultisampleStateCreateInfo = undefined;
    multisampling.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    multisampling.sampleShadingEnable = vk.VK_FALSE;
    multisampling.rasterizationSamples = vk.VK_SAMPLE_COUNT_1_BIT;
    multisampling.minSampleShading = 1.0; // Optional
    multisampling.pSampleMask = null; // Optional
    multisampling.alphaToCoverageEnable = vk.VK_FALSE; // Optional
    multisampling.alphaToOneEnable = vk.VK_FALSE; // Optional

     var color_blend_attachment: vk.VkPipelineColorBlendAttachmentState = undefined;
    color_blend_attachment.colorWriteMask = vk.VK_COLOR_COMPONENT_R_BIT | vk.VK_COLOR_COMPONENT_G_BIT | vk.VK_COLOR_COMPONENT_B_BIT | vk.VK_COLOR_COMPONENT_A_BIT;
    color_blend_attachment.blendEnable = vk.VK_FALSE;
    color_blend_attachment.srcColorBlendFactor = vk.VK_BLEND_FACTOR_ONE; // Optional
    color_blend_attachment.dstColorBlendFactor = vk.VK_BLEND_FACTOR_ZERO; // Optional
    color_blend_attachment.colorBlendOp = vk.VK_BLEND_OP_ADD; // Optional
    color_blend_attachment.srcAlphaBlendFactor = vk.VK_BLEND_FACTOR_ONE; // Optional
    color_blend_attachment.dstAlphaBlendFactor = vk.VK_BLEND_FACTOR_ZERO; // Optional
    color_blend_attachment.alphaBlendOp = vk.VK_BLEND_OP_ADD; // Optional

    var color_blending: vk.VkPipelineColorBlendStateCreateInfo = undefined;
    color_blending.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    color_blending.logicOpEnable = vk.VK_FALSE;
    color_blending.logicOp = vk.VK_LOGIC_OP_COPY; // Optional
    color_blending.attachmentCount = 1;
    color_blending.pAttachments = &color_blend_attachment;
    color_blending.blendConstants[0] = 0.0; // Optional
    color_blending.blendConstants[1] = 0.0; // Optional
    color_blending.blendConstants[2] = 0.0; // Optional
    color_blending.blendConstants[3] = 0.0; // Optional

    var pipeline_layout_create_info: vk.VkPipelineLayoutCreateInfo = undefined;
    pipeline_layout_create_info.sType = vk.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipeline_layout_create_info.pNext = null;
    pipeline_layout_create_info.flags = 0;
    pipeline_layout_create_info.setLayoutCount = 0;
    pipeline_layout_create_info.pSetLayouts = null;
    pipeline_layout_create_info.pushConstantRangeCount = 0;
    pipeline_layout_create_info.pPushConstantRanges = null;

    if(vk.vkCreatePipelineLayout(app.device, &pipeline_layout_create_info, null, &app.pipeline_layout) != vk.VK_SUCCESS)
    {
        u.err("SOMETHING HERE IN THE CREATING OF LAYOUT", .{});
    }

    var pipeline_info: vk.VkGraphicsPipelineCreateInfo = undefined;
    pipeline_info.sType = vk.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipeline_info.stageCount = 2;
    pipeline_info.pStages = &stage_infos;


    vk.vkDestroyShaderModule(app.device, vert_shader, null);
    vk.vkDestroyShaderModule(app.device, frag_shader, null);

}

fn create_render_pass(ctx: *LhvkGraphicsCtx)
!void
{
    const app: *VkApp = &ctx.vk_app;
    var attachment_description: vk.VkAttachmentDescription = undefined;
    attachment_description.format = app.format;
    attachment_description.samples = vk.VK_SAMPLE_COUNT_1_BIT;
    attachment_description.loadOp = vk.VK_ATTACHMENT_LOAD_OP_CLEAR;
    attachment_description.storeOp = vk.VK_ATTACHMENT_STORE_OP_STORE;
    attachment_description.stencilLoadOp = vk.VK_ATTACHMENT_LOAD_OP_DONT_CARE;
    attachment_description.stencilStoreOp = vk.VK_ATTACHMENT_STORE_OP_DONT_CARE;
    attachment_description.initialLayout = vk.VK_IMAGE_LAYOUT_UNDEFINED;
    attachment_description.finalLayout = vk.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

    var color_attachment_ref: vk.VkAttachmentReference = undefined;
    color_attachment_ref.attachment = 0;
    color_attachment_ref.layout = vk.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

    var subpass: vk.VkSubpassDescription = undefined;
    subpass.pipelineBindPoint = vk.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &color_attachment_ref;

    var renderpass_info: vk.VkRenderPassCreateInfo = undefined;
    renderpass_info.sType = vk.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO;
    renderpass_info.attachmentCount = 1;
    renderpass_info.pAttachments = &attachment_description;
    renderpass_info.subpassCount = 1;
    renderpass_info.pSubpasses = &subpass;

    if (vk.vkCreateRenderPass(app.device, &renderpass_info, null, &app.render_pass) != vk.VK_SUCCESS) return error.CANNOTCREATERENDERPASS;
}

pub fn init_vulkan(ctx: *LhvkGraphicsCtx)
!void
{
    _ = try create_instance(&ctx.vk_app, &ctx.vk_appdata);
    _ = setup_debug_messenger(&ctx.vk_app);
    create_surface(ctx, &ctx.vk_app);
    _ = try pick_physical_device(ctx);
    assert(ctx.vk_appdata.physical_device != null);
    create_logical_device(ctx);
    try create_swapchain(ctx);
    try create_image_views(ctx);
    try create_render_pass(ctx);
    try create_graphics_pipeline(ctx);
}

fn create_surface(ctx: *const LhvkGraphicsCtx, app: *VkApp)
void
{
    if (@import("builtin").os.tag == .windows)
    {
        u.warn("ALIGNMENT: hwnd {}\n\thinstance: {}\n\nhwnd {}|| {d:.10} \nhinstance {} || {d:.10}",
        .{@alignOf(*anyopaque), @alignOf(vk.HINSTANCE), @intFromPtr(ctx.window.instance.?), @as(f32, @floatFromInt(@intFromPtr(ctx.window.instance.?))) / 8, @intFromPtr(ctx.window.surface.?), @as(f32,@floatFromInt(@intFromPtr(ctx.window.surface.?))) / 8});
        var create_info: vk.VkWin32SurfaceCreateInfoKHR = .{
            .sType = vk.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
            .hwnd = @alignCast(@ptrCast(ctx.window.surface.?)),
            .hinstance = @alignCast(@ptrCast(ctx.window.instance.?)),
        };
        const result = vk.vkCreateWin32SurfaceKHR(app.instance, &create_info, null, &app.surface);
        assert(result == vk.VK_SUCCESS);
    }
}