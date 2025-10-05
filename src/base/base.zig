const std = @import("std");

const Color = struct {
    const RED = "\x1b[0;31m";
    const YELLOW = "\x1b[0;33m";
    const CYAN = "\x1b[0;36m";
    const GRAY = "\x1b[38;2;150;150;150m";
    const RESET = "\x1b[0m";
};


pub fn WARN(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print( Color.YELLOW ++ "[WARN] {s}:{d} -> " ++ fmt ++ Color.RESET ++ "\n", .{file, line} ++ args);
}


pub fn ERROR(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print(Color.RED ++ "[ERROR] {s}:{d} -> " ++ fmt ++ Color.RESET ++ "\n", .{file, line} ++ args);
}

pub fn INFO(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print(Color.CYAN ++ "[INFO] {s}:{d} -> " ++ fmt ++ Color.RESET ++ "\n", .{file, line} ++ args);
}

pub fn DEBUG(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print(Color.GRAY ++ "[DEBUG] {s}:{d} -> " ++ fmt ++ Color.RESET ++ "\n", .{file, line} ++ args);
}
