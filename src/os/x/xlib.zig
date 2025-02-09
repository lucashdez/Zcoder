pub const Display = opaque {}; 

pub extern fn XOpenDisplay(name: [:0]u8) callconv(.c) ?*Display;
