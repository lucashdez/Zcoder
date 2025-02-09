const std = @import("std");
const u = @import("lhvk_utils.zig");
const wl = @import("../os/wayland/xdg.zig");
const assert = std.debug.assert;
const e = @import("windowing/events.zig");
const lhmem = @import("../memory/memory.zig");

fn handle_xdg_wm_base_ping(data: ?*anyopaque, base: ?*wl.xdg_wm_base, serial: u32) callconv(.C) void {
    _ = data;
    u.info("Recieved ping, sent pong", .{});
    wl.xdg_wm_base_pong(base, serial);
    u.info("Recieved ping, sent pong", .{});
}
fn handle_xdg_surface_configure(data: ?*anyopaque, surface: ?*wl.xdg_surface, serial: u32) callconv(.C) void {
    _ = data;
    wl.xdg_surface_ack_configure(surface, serial);
    u.warn("CONFIGURE, RECEIVED", .{});
}

fn handle_xdg_toplevel_configure(data: ?*anyopaque, toplevel: ?*wl.xdg_toplevel, width: i32, height: i32, states: [*c]wl.wl_array) callconv(.c) void {
    _ = data;
    _ = toplevel;
    _ = states;
    if (width != 0 and height != 0) {}
}

fn handle_xdg_toplevel_close(data: ?*anyopaque, toplevel: ?*wl.xdg_toplevel) callconv(.c) void {
    _ = data;
    _ = toplevel;
    u.warn("QUIT RECEIVED", .{});
}

fn glb_reg_handler(data: ?*anyopaque, registry: ?*wl.wl_registry, name: u32, interface: [*c]const u8, version: u32) callconv(.C) void {
    _ = version;
    if (data) |ptr| {
        var reg_data: *WaylandProps = @ptrCast(@alignCast(ptr));
        const len = std.mem.len(interface);
        if (std.mem.eql(u8, interface[0..len], "wl_compositor")) {
            const proxy = wl.wl_registry_bind(registry, name, &wl.wl_compositor_interface, 1);
            assert(proxy != null);

            _ = wl.wl_proxy_set_queue(@as(*wl.wl_proxy, @ptrCast(proxy)), reg_data.queue);
            _ = wl.wl_proxy_set_queue(@as(*wl.wl_proxy, @ptrCast(registry)), reg_data.queue);
            reg_data.compositor = @ptrCast(@alignCast(proxy));
        } else if (std.mem.eql(u8, interface[0..len], "xdg_wm_base")) {
            u.info("Received xdg_wm_base event through registry", .{});
            reg_data.wm_base = @ptrCast(wl.wl_registry_bind(registry, name, &wl.xdg_wm_base_interface, 1));
            _ = wl.xdg_wm_base_add_listener(reg_data.wm_base, &reg_data.wm_base_listener.?, data);
        }
    }
    std.debug.print("Global: {s} ({} version {})\n", .{ interface, name, 1 });
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
    wm_base_listener: ?wl.xdg_wm_base_listener,
    wm_surface_listener: ?wl.xdg_surface_listener,
    wm_toplevel_listener: ?wl.xdg_toplevel_listener,
};

pub const Window = struct {
    handle: ?*i32,
    raw: WaylandProps,
    width: u32,
    height: u32,
    event: ?e.Event,
    pub fn get_events(window: *Window) void {
        u.trace("BEFORE DISPATCH", .{});
        _ = wl.wl_display_dispatch(window.raw.display);
        u.trace("AFTER DISPATCH", .{});

        wl.wl_surface_commit(window.raw.surface);
        _ = wl.wl_display_roundtrip(window.raw.display);
    }
};

pub fn create_window(name: [:0]const u8) Window {
    //TODO: Create xdg surface for vulkan presenting;
    //TODO: buffer too??
    const width = 800;
    const height = 600;
    var props: WaylandProps = .{
        .display = null,
        .surface = null,
        .compositor = null,
        .compositor_proxy = null,
        .registry = null,
        .listener = .{ .global = glb_reg_handler, .global_remove = glb_reg_remover },
        .queue = null, //wl.wl_event_queue_create(),
        .wm_base = null,
        .wm_surface = null,
        .wm_toplevel = null,
        .wm_base_listener = .{ .ping = handle_xdg_wm_base_ping },
        .wm_surface_listener = .{ .configure = handle_xdg_surface_configure },
        .wm_toplevel_listener = .{ .configure = handle_xdg_toplevel_configure, .close = handle_xdg_toplevel_close },
    };

    props.display = wl.wl_display_connect(null);
    props.registry = wl.wl_display_get_registry(props.display);
    props.queue = wl.wl_display_create_queue(props.display);
    _ = wl.wl_registry_add_listener(props.registry, &props.listener.?, &props);
    _ = wl.wl_display_roundtrip(props.display);
    assert(props.compositor != null and props.wm_base != null);
    u.trace("Created compositor and xdg base:\ndisplay: {any}\nregistry: {any}\ncompositor: {any}\nxdg_base: {any}", .{ props.display, props.registry, props.compositor, props.wm_base });

    //created _surface
    props.surface = wl.wl_compositor_create_surface(props.compositor);
    assert(props.surface != null);

    props.wm_surface = wl.xdg_wm_base_get_xdg_surface(props.wm_base, props.surface);
    _ = wl.xdg_surface_add_listener(props.wm_surface, &props.wm_surface_listener.?, &props);

    props.wm_toplevel = wl.xdg_surface_get_toplevel(props.wm_surface);
    _ = wl.xdg_toplevel_add_listener(props.wm_toplevel, &props.wm_toplevel_listener.?, &props);

    wl.xdg_toplevel_set_title(props.wm_toplevel, name.ptr);
    wl.xdg_toplevel_set_app_id(props.wm_toplevel, name.ptr);

    wl.wl_surface_commit(props.surface);
    _ = wl.wl_display_roundtrip(props.display);
    wl.wl_surface_commit(props.surface);

    u.trace("BEFORE DISPATCH", .{});
    _ = wl.wl_display_dispatch_queue(props.display, props.queue);
    u.trace("AFTER DISPATCH", .{});

    return Window{
        .handle = null,
        .raw = props,
        .event = null,
        .width = width,
        .height = height,
    };
}
