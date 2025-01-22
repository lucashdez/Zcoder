const std = @import("std");
const vk = if (@import("builtin").os.tag == .windows) @import("vk_api.zig").vk else @import("vk_api.zig");
const Window = @import("win32.zig").Window;
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;
const assert = std.debug.assert;
const u = @import("lhvk_utils.zig");


pub const LhvkGraphicsCtx = struct {
    window: Window,
};

pub const VkApp = struct {
    arena: Arena,
    instance: vk.VkInstance,
    debug_messenger: vk.VkDebugUtilsMessengerEXT,
    device: vk.VkDevice,
    graphics_queue: vk.VkQueue,
    surface: vk.VkSurfaceKHR,
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

fn find_queue_families(device: vk.VkPhysicalDevice) !QueueFamilyIndices {
    var scratch: Arena = lhmem.scratch_block();
    var indices: QueueFamilyIndices = .{ .graphics_family = null };
    var queue_family_count: u32 = 0;
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);
    const queue_families: [*]vk.VkQueueFamilyProperties = scratch.push_array(vk.VkQueueFamilyProperties, queue_family_count);
    vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, @ptrCast(@constCast(queue_families)));
    for (queue_families, 0..queue_family_count) |queue, i| {
        if ((queue.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT) == 1) {
            indices.graphics_family = @intCast(i);
            break;
        }
    }
    return indices;
}

fn is_device_suitable(device: vk.VkPhysicalDevice) bool {
    var device_properties: vk.VkPhysicalDeviceProperties = std.mem.zeroes(vk.VkPhysicalDeviceProperties);
    var device_features: vk.VkPhysicalDeviceFeatures = std.mem.zeroes(vk.VkPhysicalDeviceFeatures);

    vk.vkGetPhysicalDeviceProperties(device, &device_properties);
    vk.vkGetPhysicalDeviceFeatures(device, &device_features);
    const families_found: QueueFamilyIndices = find_queue_families(device) catch return undefined;

    if ((device_properties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU or device_properties.deviceType == vk.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) and device_features.geometryShader != 0 and families_found.graphics_family != undefined) {
        u.trace("{s} selected.", .{device_properties.deviceName});
        return true;
    }
    return false;
}

// TODO: Rate devices
fn pick_physical_device(app: *VkApp, app_data: *VkAppData) !void {
    var tmp: Arena = lhmem.scratch_block();

    var device_count: u32 = 0;
    _ = vk.vkEnumeratePhysicalDevices(app.instance, &device_count, null);
    if (device_count == 0) {
        std.debug.print("No physical devices found", .{});
    }
    const physical_devices_bytes = tmp.push_array(vk.VkPhysicalDevice, device_count);
    const physical_devices: [*]vk.VkPhysicalDevice = @ptrCast(@alignCast(physical_devices_bytes));
    _ = vk.vkEnumeratePhysicalDevices(app.instance, &device_count, physical_devices);
    const dview: []vk.VkPhysicalDevice = physical_devices[0..device_count];
    for (dview) |device| {
        if (is_device_suitable(device)) {
            app_data.physical_device = device;
            return;
        }
    }
}

const QueueFamilyIndices = struct {
    graphics_family: ?u32,
};

fn create_logical_device(app: *VkApp, app_data: *VkAppData) void {
    const indices: QueueFamilyIndices = find_queue_families(app_data.physical_device) catch {
        return .{ .graphics_family = null };
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
    { // EXTENSIONS
        create_info.enabledExtensionCount = 0;
        create_info.ppEnabledExtensionNames = null;
    }
    { // LAYERS IGNORED
        create_info.enabledLayerCount = 0;
        create_info.ppEnabledLayerNames = null;
    }

    assert(vk.vkCreateDevice(app_data.physical_device, &create_info, null, &app.device) == vk.VK_SUCCESS);
    vk.vkGetDeviceQueue(app.device, indices.graphics_family.?, 0, &app.graphics_queue);
}

pub fn init_vulkan(ctx: *LhvkGraphicsCtx, app: *VkApp, app_data: *VkAppData) !void {
    _ = try create_instance(app, app_data);
    _ = setup_debug_messenger(app);
    create_surface(ctx, app);
    _ = try pick_physical_device(app, app_data);
    assert(app_data.physical_device != null);
    create_logical_device(app, app_data);
}

fn create_surface(ctx: *const LhvkGraphicsCtx, app: *VkApp) void {
    _ = ctx;
    _ = app;
    if (@import("builtin").os.tag == .windows) {
        // const instance = std.os.windows.kernel32.GetModuleHandleW(null);
        // var info: sdl.SDL_SysWMinfo = undefined;
        // sdl.SDL_VERSION(&info.version);
        // sdl.SDL_GetWindowWMinfo(ctx.window.handle,&info);
        // const hwnd = info.info.win.window;

        //      var create_info: vk.VkWin32SurfaceCreateInfoKHR = .{
        //         .sType = vk.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
        //         .hwnd = hwnd,
        //         .hinstance = instance,
        //      };
        //      const result = vk.vkCreateWin32SurfaceKHR(app.instance, &create_info, null, &app.surface);
        //      assert(result == vk.VK_SUCCESS);
    }
    // sdl.SDL_Vulkan_CreateSurface(ctx.window.handle, app.instance, &app.surface);

}
