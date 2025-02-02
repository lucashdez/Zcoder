const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const u = @import("lhvk_utils.zig");
const raw = @import("../os/wayland/wayland.zig");
const assert = std.debug.assert;

fn glb_reg_handler(data: ?*anyopaque, registry: ?*raw.wl_registry, name: u32, interface: [*c]const u8, version: u32)
callconv(.C) void
{
    if (data) |ptr|
    {
        var reg_data: *WaylandProps = @ptrCast(@alignCast(ptr));
        const len = std.mem.len(interface);
        if (std.mem.eql(u8, interface[0..len], "wl_compositor"))
        {
            reg_data.compositor = @ptrCast(@alignCast(raw.wl_registry_bind(registry, name, &raw.wl_compositor_interface, version)));
        }
    }

    std.debug.print("Global: {s} ({} version {})\n", .{ interface, name, version });
}

fn glb_reg_remover(data: ?*anyopaque, registry: ?*raw.wl_registry, name: u32)
callconv(.C) void {
    _ = data;
    _ = registry;
    _ = name;
}


pub const WaylandProps = struct {
    display: ?*raw.wl_display,
    surface: ?*raw.wl_surface,
    compositor: ?*raw.wl_compositor,
    registry: ?*raw.wl_registry,
    listener: ?raw.wl_registry_listener,
    //global: ?*const fn (?*anyopaque, ?*struct_wl_registry, u32, [*c]const u8, u32) callconv(.C) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_registry, u32, [*c]const u8, u32) callconv(.C) void),
    //global_remove: ?*const fn (?*anyopaque, ?*struct_wl_registry, u32) callconv(.C) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_registry, u32) callconv(.C) void),
};

pub const Window = struct {
    handle: ?*sdl.SDL_Window,
    raw: WaylandProps,
    width: u32,
    height: u32,
};


pub fn create_window(name: []const u8) Window {
    _ = name;
    var props: WaylandProps = std.mem.zeroes(WaylandProps);

    props.display = raw.wl_display_connect(null);
    assert(props.display != null);
    props.registry = raw.wl_display_get_registry(props.display.?);
    assert(props.registry != null);
    props.listener =  raw.wl_registry_listener {
        .global = glb_reg_handler,
        .global_remove = glb_reg_remover,
    };
    _ = raw.wl_registry_add_listener(props.registry.?, &props.listener.?, &props);
    _ = raw.wl_display_roundtrip(props.display.?);





    return Window {
    .handle = null,
    .raw = props,
    .width = 800,
    .height = 600,
    };
}
