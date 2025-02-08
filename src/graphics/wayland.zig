const std = @import("std");
const u = @import("lhvk_utils.zig");
//const wl = @import("../os/wayland/wayland.zig");
const wl = @import("../os/wayland/xdg.zig");
const assert = std.debug.assert;
const e = @import("windowing/events.zig");
const lhmem = @import("../memory/memory.zig");

fn glb_reg_handler(data: ?*anyopaque, registry: ?*wl.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
    if (data) |ptr| {
        var reg_data: *WaylandProps = @ptrCast(@alignCast(ptr));
        const len = std.mem.len(interface);
        if (std.mem.eql(u8, interface[0..len], "wl_compositor")) {
            const proxy = wl.wl_registry_bind(registry, name, &wl.wl_compositor_interface, version);
            assert(proxy != null);

            _ = wl.wl_proxy_set_queue(@as(*wl.wl_proxy, @ptrCast(proxy)), reg_data.queue);
            _ = wl.wl_proxy_set_queue(@as(*wl.wl_proxy, @ptrCast(registry)), reg_data.queue);
            reg_data.compositor = @ptrCast(@alignCast(proxy));
        } else if (std.mem.eql(u8, interface[0..len], "xdg_wm_base")) {
            u.info("Received xdg_wm_base event through registry", .{});
            reg_data.wm_base = @ptrCast(wl.wl_registry_bind(registry, name, &wl.xdg_wm_base_interface, version));
        }
    }

    std.debug.print("Global: {s} ({} version {})\n", .{ interface, name, version });
}

fn glb_reg_remover(data: ?*anyopaque, registry: ?*wl.wl_registry, name: u32) callconv(.C) void {
    _ = data;
    _ = registry;
    _ = name;
}

// TODO: Add queue and regglobalhanddler handle queue things.
pub const WaylandProps = struct {
    display: ?*wl.wl_display,
    surface: ?*wl.wl_surface,
    compositor: ?*wl.wl_compositor,
    compositor_proxy: ?*wl.wl_proxy,
    registry: ?*wl.wl_registry,
    listener: ?wl.wl_registry_listener,
    queue: ?*wl.wl_event_queue,
    wm_base: ?*wl.xdg_wm_base,
    wm_surface: ?*wl.xdg_surface,
    wm_toplevel: ?*wl.xdg_toplevel,
};

pub const Window = struct {
    handle: ?*i32,
    raw: WaylandProps,
    width: u32,
    height: u32,
    event: ?e.Event,
    pub fn get_events(window: *Window) void {
        _ = window;
    }
};

pub fn create_window(name: []const u8) Window {
    //TODO: Create xdg surface for vulkan presenting;
    //TODO: buffer too??
    _ = name;
    var props: WaylandProps = std.mem.zeroes(WaylandProps);

    props.display = wl.wl_display_connect(null);
    assert(props.display != null);

    props.queue = wl.wl_display_create_queue(props.display.?);
    assert(props.queue != null);

    props.registry = wl.wl_display_get_registry(props.display.?);
    assert(props.registry != null);

    _ = wl.wl_proxy_set_queue(@as(*wl.wl_proxy, @ptrCast(props.registry.?)), props.queue);

    props.listener = wl.wl_registry_listener{
        .global = glb_reg_handler,
        .global_remove = glb_reg_remover,
    };
    _ = wl.wl_registry_add_listener(props.registry.?, &props.listener.?, &props);
    _ = wl.wl_display_roundtrip_queue(props.display.?, props.queue);
    assert(props.compositor != null);
    props.surface = wl.wl_compositor_create_surface(props.compositor.?);
    assert(props.surface != null);

    _ = wl.wl_display_dispatch(props.display.?);
    _ = wl.wl_surface_commit(props.surface);

    return Window{
        .handle = null,
        .raw = props,
        .event = null,
        .width = 800,
        .height = 600,
    };
}
