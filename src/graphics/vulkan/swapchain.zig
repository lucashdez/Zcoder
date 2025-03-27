const std = @import("std");
const lhvk = @import("../lhvk.zig");
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;
const u = @import("../lhvk_utils.zig");
const vk = @import("../vk_api.zig").vk;
const win32 = @import("../win32.zig");
const Window = win32.Window;
const la = @import("../../lin_alg/la.zig");

const SwapChainSupportDetails = struct {
    capabilities: vk.VkSurfaceCapabilitiesKHR,
    formats: []vk.VkSurfaceFormatKHR,
    presentModes: []vk.VkPresentModeKHR,
};

pub const Swapchain = struct {
    // Minimum arena size == 16kb?
    arena: Arena,
    handle: vk.VkSwapchainKHR,
    format: vk.VkSurfaceFormatKHR,
    present_mode: vk.VkPresentModeKHR,
    extent: vk.VkExtent2D,
    images: []vk.VkImage,
    image_views: []vk.VkImageView,
    framebuffers: []vk.VkFramebuffer,
    swapchain_support: ?SwapChainSupportDetails,

    fn find_queue_families(ctx: *lhvk.LhvkGraphicsCtx, device: vk.VkPhysicalDevice) !lhvk.QueueFamilyIndices {
        const app = ctx.vk_app;
        var scratch: Arena = lhmem.scratch_block();
        var indices: lhvk.QueueFamilyIndices = .{ .graphics_family = null, .present_family = null };
        var queue_family_count: u32 = 0;
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, null);
        const queue_families: [*]vk.VkQueueFamilyProperties = scratch.push_array(vk.VkQueueFamilyProperties, queue_family_count);
        vk.vkGetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, @ptrCast(@constCast(queue_families)));
        for (queue_families, 0..queue_family_count) |queue, i| {
            var present_support: u32 = 0;
            _ = vk.vkGetPhysicalDeviceSurfaceSupportKHR(device, @intCast(i), app.device_wrapper.surface, &present_support);
            if (present_support == vk.VK_TRUE) {
                indices.present_family = @intCast(i);
            }
            if ((queue.queueFlags & vk.VK_QUEUE_GRAPHICS_BIT) == 1) {
                indices.graphics_family = @intCast(i);
            }
        }
        return indices;
    }

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

    pub fn choose_surface_format(available_formats: []vk.VkSurfaceFormatKHR) vk.VkSurfaceFormatKHR {
        for (available_formats) |format| {
            if (format.format == vk.VK_FORMAT_R8G8B8A8_SRGB and format.colorSpace == vk.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) return format;
        }
        return available_formats[0];
    }

    pub fn choose_swap_extent(window: Window, capabilities: vk.VkSurfaceCapabilitiesKHR) vk.VkExtent2D {
        var actual_extent: vk.VkExtent2D = .{
            .width = window.width,
            .height = window.height,
        };
        la.clamp(u32, &actual_extent.width, capabilities.minImageExtent.width, capabilities.maxImageExtent.width);
        la.clamp(u32, &actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height);
        u.warn("extent: {any}", .{actual_extent});
        return actual_extent;
    }

    pub fn init(ctx: *lhvk.LhvkGraphicsCtx) !Swapchain {
        const app = &ctx.vk_app;
        const app_data = &ctx.vk_appdata;
        var swapchain_arena = lhmem.scratch_block();

        const device = app.device_wrapper.device;

        const swapchain_support = query_swapchain_support(&swapchain_arena, app_data.physical_device, app.device_wrapper.surface);

        const surface_format = choose_surface_format(swapchain_support.formats);
        const present_mode = vk.VK_PRESENT_MODE_FIFO_KHR;
        const extent = choose_swap_extent(ctx.window, swapchain_support.capabilities);

        var image_count = swapchain_support.capabilities.minImageCount + 1;
        la.clamp(u32, &image_count, swapchain_support.capabilities.minImageCount, swapchain_support.capabilities.maxImageCount);

        var create_info: vk.VkSwapchainCreateInfoKHR = std.mem.zeroes(vk.VkSwapchainCreateInfoKHR);
        create_info.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        create_info.surface = app.device_wrapper.surface;
        create_info.minImageCount = image_count;
        create_info.imageFormat = surface_format.format;
        create_info.imageColorSpace = surface_format.colorSpace;
        create_info.imageExtent = extent;
        create_info.imageArrayLayers = 1;
        create_info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        const indices = try find_queue_families(ctx, app_data.physical_device);
        const real_indices: [2]u32 = .{ indices.graphics_family.?, indices.present_family.? };
        if (indices.graphics_family.? != indices.present_family.?) {
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

        var swapchain: vk.VkSwapchainKHR = null;
        if (vk.vkCreateSwapchainKHR(device, &create_info, null, &swapchain) != vk.VK_SUCCESS) {
            //return error.CannotCreateSwapchain;
        }

        // TEST: Creation of swapchain_images
        _ = vk.vkGetSwapchainImagesKHR(device, swapchain, &image_count, null);
        const images = swapchain_arena.push_array(vk.VkImage, image_count)[0..image_count];
        _ = vk.vkGetSwapchainImagesKHR(device, swapchain, &image_count, images.ptr);

        var image_views = app.arena.push_array(vk.VkImageView, images.len)[0..images.len];
        for (0..images.len) |i| {
            var info: vk.VkImageViewCreateInfo = std.mem.zeroes(vk.VkImageViewCreateInfo);
            info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            info.image = images[i];
            info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
            info.format = surface_format.format;
            info.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
            info.subresourceRange.baseMipLevel = 0;
            info.subresourceRange.levelCount = 1;
            info.subresourceRange.baseArrayLayer = 0;
            info.subresourceRange.layerCount = 1;

            // TEST: Can be copying images instead of modifying array
            if (vk.vkCreateImageView(device, &info, null, &image_views[i]) != vk.VK_SUCCESS) return error.CannotCreateImageView;
        }

        return Swapchain{
            .arena = swapchain_arena,
            .handle = swapchain,
            .format = surface_format,
            .present_mode = present_mode,
            .extent = extent,
            .images = images,
            .image_views = image_views,
            .framebuffers = swapchain_arena.push_array(vk.VkFramebuffer, images.len)[0..images.len],
            .swapchain_support = swapchain_support,
        };
    }

    pub fn recreate(old: *Swapchain, ctx: *lhvk.LhvkGraphicsCtx) !void {
        const app = &ctx.vk_app;
        const app_data = &ctx.vk_appdata;
        old.arena = lhmem.scratch_block();

        const device = app.device_wrapper.device;
        old.extent = choose_swap_extent(ctx.window, old.swapchain_support.?.capabilities);

        var image_count = old.swapchain_support.?.capabilities.minImageCount + 1;
        la.clamp(u32, &image_count, old.swapchain_support.?.capabilities.minImageCount, old.swapchain_support.?.capabilities.maxImageCount);

        var create_info: vk.VkSwapchainCreateInfoKHR = std.mem.zeroes(vk.VkSwapchainCreateInfoKHR);
        create_info.sType = vk.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
        create_info.surface = app.device_wrapper.surface;
        create_info.minImageCount = image_count;
        create_info.imageFormat = old.format.format;
        create_info.imageColorSpace = old.format.colorSpace;
        create_info.imageExtent = old.extent;
        create_info.imageArrayLayers = 1;
        create_info.imageUsage = vk.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

        // TODO: Redo
        const indices = try find_queue_families(ctx, app_data.physical_device);
        const real_indices: [2]u32 = .{ indices.graphics_family.?, indices.present_family.? };
        if (indices.graphics_family.? != indices.present_family.?) {
            create_info.imageSharingMode = vk.VK_SHARING_MODE_CONCURRENT;
            create_info.queueFamilyIndexCount = 2;
            create_info.pQueueFamilyIndices = &real_indices;
        } else {
            create_info.imageSharingMode = vk.VK_SHARING_MODE_EXCLUSIVE;
            create_info.queueFamilyIndexCount = 0;
            create_info.pQueueFamilyIndices = null;
        }

        create_info.preTransform = old.swapchain_support.?.capabilities.currentTransform;
        create_info.compositeAlpha = vk.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
        create_info.presentMode = old.present_mode;
        create_info.clipped = vk.VK_TRUE;
        create_info.oldSwapchain = null;

        if (vk.vkCreateSwapchainKHR(device, &create_info, null, &old.handle) != vk.VK_SUCCESS) {
            //return error.CannotCreateSwapchain;
        }

        // TEST: Creation of swapchain_images
        _ = vk.vkGetSwapchainImagesKHR(device, old.handle, &image_count, null);
        old.images = old.arena.push_array(vk.VkImage, image_count)[0..image_count];
        _ = vk.vkGetSwapchainImagesKHR(device, old.handle, &image_count, old.images.ptr);

        old.image_views = app.arena.push_array(vk.VkImageView, old.images.len)[0..old.images.len];
        for (0..old.images.len) |i| {
            var info: vk.VkImageViewCreateInfo = std.mem.zeroes(vk.VkImageViewCreateInfo);
            info.sType = vk.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
            info.image = old.images[i];
            info.viewType = vk.VK_IMAGE_VIEW_TYPE_2D;
            info.format = old.format.format;
            info.components.r = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.g = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.b = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.a = vk.VK_COMPONENT_SWIZZLE_IDENTITY;
            info.subresourceRange.aspectMask = vk.VK_IMAGE_ASPECT_COLOR_BIT;
            info.subresourceRange.baseMipLevel = 0;
            info.subresourceRange.levelCount = 1;
            info.subresourceRange.baseArrayLayer = 0;
            info.subresourceRange.layerCount = 1;

            // TEST: Can be copying images instead of modifying array
            if (vk.vkCreateImageView(device, &info, null, &old.image_views[i]) != vk.VK_SUCCESS) return error.CannotCreateImageView;
        }
    }
};
