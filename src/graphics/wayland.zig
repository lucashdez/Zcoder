const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const u = @import("lhvk_utils.zig");
const raw = @import("../os/wayland/wayland.zig");



pub const Window = struct {
    handle: ?*sdl.SDL_Window,
    instance: ?*anyopaque,
    surface: ?*anyopaque,
    display: ?*anyopaque,
    width: u32,
    height: u32,
};


pub fn create_window(name: []const u8) Window {
 _ = name;
    return Window {
    .handle = null,
    .instance = null,
    .surface = null,
    .display = null,
    .width = 800,
    .height = 600,
    };
}

const raw = @import("../os/wayland/wayland.zig");
const std = @import("std");
const assert = std.debug.assert;


pub const Window  = struct {
    display: raw.wl_display,
    surface: raw.wl_surface,
    registry: raw.wl_registry,
    listener: raw.wl_registry_listener,

    fn registryGlobal(data: ?*anyopaque
        , name: u32
        , interface: [*c]const u8
        , version: u32) void {
        _ = data;
        std.debug.print("Global object {} ({s} v{}) announced\n", .{name, interface, version});
    }

    fn registryGlobalRemove(data: ?*anyopaque, name: u32) void {
        _ = data;
        std.debug.print("Global object {} removed\n", .{name});
    }

    fn glb_reg_handler(data: ?*anyopaque,
                   registry: ?*raw.wl_registry,
                   id: u32,
                   interface: [*c]const u8,
                   version: u32
    ) callconv(.C) void {
        _ = data;
        _ = registry;
        _ = id;
        _ = interface;
        _ = version;
    }

    //global: ?*const fn (?*anyopaque, ?*struct_wl_registry, u32, [*c]const u8, u32) callconv(.C) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_registry, u32, [*c]const u8, u32) callconv(.C) void),
    //global_remove: ?*const fn (?*anyopaque, ?*struct_wl_registry, u32) callconv(.C) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_registry, u32) callconv(.C) void),

    fn glb_reg_remover(data: ?*anyopaque,
                   registry: ?*raw.wl_registry,
                   id: u32
    ) callconv(.C) void {
        _ = data;
        _ = registry;
        _ = id;
    }

    pub fn init(name: []const u8) Window {
        _ = name;
        const display: ?raw.wl_display = raw.wl_display_connect(null);
        assert(display != null);
        const registry: ?raw.wl_registry = raw.wl_display_get_registry(display.?);
        assert(registry != null);
        const listener: raw.wl_registry_listener = .{
            .global = registryGlobal,
            .global_remove = registryGlobalRemove
        };
        raw.wl_registry_add_listener(registry.?, &listener, null);
        raw.wl_display_roundtrip(display.?);

        const compositor_interface: raw.wl_compositor_interface = undefined;
        _ = compositor_interface;

        return Window {};
    }

    pub fn default_handle_messages(_: *Window) Event {
        return Event.QUIT;
    }
};
