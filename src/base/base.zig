const std = @import("std");


const RED = "\x1b[0;31m";
const YELLOW = "\x1b[0;33m";
const CYAN = "\x1b[0;36m";
const GRAY = "\x1b[240;240;240m";
const RESET = "\x1b[0m";


pub fn WARN(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print( YELLOW ++ "[WARN] {s}:{d} -> " ++ fmt ++ RESET ++ "\n", .{file, line} ++ args);
}


pub fn ERROR(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print(RED ++ "[ERROR] {s}:{d} -> " ++ fmt ++ RESET ++ "\n", .{file, line} ++ args);
}

pub fn INFO(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print(CYAN ++ "[INFO] {s}:{d} -> " ++ fmt ++ RESET ++ "\n", .{file, line} ++ args);
}

pub fn DEBUG(src: std.builtin.SourceLocation, comptime fmt: []const u8, args: anytype) void {
    const file = src.file;
    const line = src.line;
    std.debug.print(GRAY ++ "[DEBUG] {s}:{d} -> " ++ fmt ++ RESET ++ "\n", .{file, line} ++ args);
}
