const std = @import("std");

const BLACK  = "\x1b[30;2m";
const RED    = "\x1b[31;2m";
const GREEN  = "\x1b[32;2m";
const YELLOW = "\x1b[33;2m";
const BLUE   = "\x1b[34;2m";
const PURPLE = "\x1b[35;2m";
const CYAN   = "\x1b[36;2m";
const WHITE  = "\x1b[37;2m";
const BOLD  = "\x1b[1m";
const DIM   = "\x1b[2m";
const RESET = "\x1b[0m";

pub fn trace(comptime s: []const u8, args: anytype) void {
    std.debug.print(BLUE++"[TRACE] "++RESET++s++"\n", args);
}

pub fn warn(comptime s: []const u8, args: anytype) void {
    std.debug.print(YELLOW++"[WARNING] "++RESET++s++"\n", args);
}
pub fn err(comptime s: []const u8, args: anytype) void {
    std.debug.print(RED++"[ERROR] "++RESET++s++"\n", args);
}

pub const String8 = struct {
    str: *u8,
    size: usize,
};

pub fn S8Lit(s: []const u8) String8 {
    return String8 {
        .str = @ptrCast(@constCast(s.ptr)),
        .size = s.len
    };
}


pub fn strcmp(a: [*c]const u8, b: [*c]const u8) bool {
    const a_slice = std.mem.span(a);
    const b_slice = std.mem.span(b);
    return std.mem.eql(u8, a_slice, b_slice);
}
