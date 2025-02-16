pub const Display = opaque {};
pub const Window = opaque {};
pub const Visual = opaque {};

pub const XSetWindowAttributes = struct {
    bit_gravity: i32,
};

pub extern fn XOpenDisplay(name: [:0]u8) callconv(.c) ?*Display;

pub extern fn XCreateWindow(display: ?*Display, parent: ?*Window, x: i32, y: i32, width: u32, height: u32, border_width: u32, depth: i32, class: u32, visual: ?*Visual, valuemask: u64, attributes: ?*XSetWindowAttributes) ?*Window;
