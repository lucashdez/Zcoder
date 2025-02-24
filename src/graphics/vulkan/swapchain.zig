const std = @import("std");
const lhvk = @import("../lhvk.zig");
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;
const u = @import("../lhvk_utils.zig");
const vk = @import("../vk_api.zig").vk;

pub const Swapchain = struct
{
    // Minimum arena size == 16kb?
    arena: Arena,
    handle: vk.VkSwapchainKHR,
    images: []vk.VkImage,
    image_views: []vk.VkImageView,
    framebuffers: []vk.VkFramebuffer,
    
    
    pub fn init(arena: *Arena, ctx: *lhvk.LhvkGraphicsCtx)
        !Swapchain
    {
        const app: *VkApp = &ctx.vk_app;
        const app_data: *VkAppData = &ctx.vk_appdata;
        var scratch = lhmem.scratch_block();
        const swapchain_support = query_swapchain_support(&scratch, app_data.physical_device, app.surface);
        
        return Swapchain {
            .arena = arena,
            .handle = std.mem.zeroes(vk.VkSwapchainKHR),
            .images = std.mem.zeroes([]vk.VkImage),
            .image_views = std.mem.zeroes([]vk.VkImageView),
            .framebuffers = std.mem.zeroes([]vk.VkFramebuffer),
        };
    }
};