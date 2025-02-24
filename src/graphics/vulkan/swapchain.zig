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
    
    
    pub fn init(ctx: ?*lhvk.LhvkGraphicsCtx)
        SwapchainError!Swapchain
    {
        if (ctx == null)
        {
            u.err("Context in creation of swapchain == null", .{});
            return error.NoContextProvided;
        }
        const arena = lhmem.make_arena((1 << 10) * 16);
        //var app = ctx.vk_app;
        //var app_data = ctx.vk_appdata;
        
        
        return Swapchain {
            .arena = arena,
            .handle = std.mem.zeroes(vk.VkSwapchainKHR),
            .images = std.mem.zeroes([]vk.VkImage),
            .image_views = std.mem.zeroes([]vk.VkImageView),
            .framebuffers = std.mem.zeroes([]vk.VkFramebuffer),
        };
    }
};