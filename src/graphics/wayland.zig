const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const u = @import("lhvk_utils.zig");
const raw = @import("../os/wayland/wayland.zig");
const assert = std.debug.assert;
const e = @import("windowing/events.zig");
const lhmem = @import("../memory/memory.zig");

fn glb_reg_handler(data: ?*anyopaque, registry: ?*raw.wl_registry, name: u32, interface: [*c]const u8, version: u32)
callconv(.C) void
{
    if (data) |ptr|
    {
        var reg_data: *WaylandProps = @ptrCast(@alignCast(ptr));
        const len = std.mem.len(interface);
        if (std.mem.eql(u8, interface[0..len], "wl_compositor"))
        {
            const proxy = raw.wl_registry_bind(registry, name, &raw.wl_compositor_interface, version);
            assert(proxy != null);
            _ = raw.wl_proxy_set_queue(@as(*raw.wl_proxy, @ptrCast(proxy)), reg_data.queue);
            reg_data.compositor = @ptrCast(@alignCast(proxy));
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

// TODO: Add queue and regglobalhanddler handle queue things.
pub const WaylandProps = struct {
    display: ?*raw.wl_display,
    surface: ?*raw.wl_surface,
    compositor: ?*raw.wl_compositor,
    compositor_proxy: ?*raw.wl_proxy,
    registry: ?*raw.wl_registry,
    listener: ?raw.wl_registry_listener,
    queue: ?*raw.wl_event_queue,
    //global: ?*const fn (?*anyopaque, ?*struct_wl_registry, u32, [*c]const u8, u32) callconv(.C) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_registry, u32, [*c]const u8, u32) callconv(.C) void),
    //global_remove: ?*const fn (?*anyopaque, ?*struct_wl_registry, u32) callconv(.C) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, ?*struct_wl_registry, u32) callconv(.C) void),
};

pub const Window = struct {
    handle: ?*sdl.SDL_Window,
    raw: WaylandProps,
    width: u32,
    height: u32,
    events: e.EventList,
    pub fn get_events(window: *Window) void {
        _ = window;
    }
};


pub fn create_window(name: []const u8) Window {
    _ = name;
    var props: WaylandProps = std.mem.zeroes(WaylandProps);

    props.display = raw.wl_display_connect(null);
    assert(props.display != null);

    props.queue = raw.wl_display_create_queue(props.display.?);
    assert(props.queue != null);

    props.registry = raw.wl_display_get_registry(props.display.?);
    assert(props.registry != null);

    _ = raw.wl_proxy_set_queue(@as(*raw.wl_proxy, @ptrCast(props.registry)), props.queue);

    props.listener =  raw.wl_registry_listener {
        .global = glb_reg_handler,
        .global_remove = glb_reg_remover,
    };
    _ = raw.wl_registry_add_listener(props.registry.?, &props.listener.?, &props);
    assert(props.compositor != null);
    props.surface = raw.wl_compositor_create_surface(props.compositor.?);
    assert(props.surface != null);

    raw.wl_proxy_set_queue(@ptrCast(props.registry.?), props.queue);
    raw.wl_proxy_set_queue(@ptrCast(props.compositor.?), props.queue);
    raw.wl_proxy_set_queue(@ptrCast(props.surface.?), props.queue);

    _ = raw.wl_display_roundtrip_queue(props.display.?, props.queue);



    return Window {
    .handle = null,
    .raw = props,
    .events = e.EventList{.first = null, .last = null, .arena = lhmem.make_arena(1 << 10)},
    .width = 800,
    .height = 600,
    };
}
