const Platform = @This();


const std = @import("std");
const u = @import("lhvk_utils.zig");
const x = @import("../os/x/xlib.zig");
const assert = std.debug.assert;
const e = @import("windowing/events.zig");
const lhmem = @import("../memory/memory.zig");
const base = @import("../base/base_types.zig");
const Rectu32 = base.Rectu32;

// TODO: Add queue and regglobalhanddler handle queue things.
pub const XlibProps = struct {
    display: ?*x.Display,
};

pub const Window = struct {
    handle: ?*i32,
    raw: XlibProps,
    width: u32,
    height: u32,
    event: ?e.Event,
    pub fn get_events(window: *Window) void {
        _ = window;
    }

    pub fn get_size(window: *Window) Rectu32 {
        return undefined;
    } 
};

pub fn create_window(name: [:0]const u8) Window {
    _ = name;
    const props = std.mem.zeroes(XlibProps);
    const width = 800;
    const height = 600;
    return Window{
        .handle = null,
        .raw = props,
        .event = null,
        .width = width,
        .height = height,
    };
}
