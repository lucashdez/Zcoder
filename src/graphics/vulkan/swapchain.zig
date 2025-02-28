const std = @import("std");
const lhvk = @import("../lhvk.zig");
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;
const u = @import("../lhvk_utils.zig");
const vk = @import("../vk_api.zig").vk;


const SwapChainSupportDetails = struct {
    capabilities: vk.VkSurfaceCapabilitiesKHR,
    formats: []vk.VkSurfaceFormatKHR,
    presentModes: []vk.VkPresentModeKHR,
};

pub const Swapchain = struct
{
    // Minimum arena size == 16kb?
    arena: Arena,
    handle: vk.VkSwapchainKHR,
    images: []vk.VkImage,
    image_views: []vk.VkImageView,
    framebuffers: []vk.VkFramebuffer,
    swapchain_support: ?SwapChainSupportDetails,
    
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
    
    pub fn init(ctx: *lhvk.LhvkGraphicsCtx)
        !Swapchain
    {
        const app = &ctx.vk_app;
        const app_data = &ctx.vk_appdata;
        var scratch = lhmem.scratch_block();
        const swapchain_support = query_swapchain_support(&scratch, app_data.physical_device, app.surface);
        
        return Swapchain {
            .arena = lhmem.make_arena((1 << 10) * 16),
            .handle = std.mem.zeroes(vk.VkSwapchainKHR),
            .images = std.mem.zeroes([]vk.VkImage),
            .image_views = std.mem.zeroes([]vk.VkImageView),
            .framebuffers = std.mem.zeroes([]vk.VkFramebuffer),
            .swapchain_support = swapchain_support,
        };
    }
};
