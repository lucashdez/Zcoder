const std = @import("std");
const Arena = @import("../memory/memory.zig");

pub const FontAttributes = struct {
    arena: Arena,
    face: u8,
    name: [:0]const u8,
};

pub fn load_font(allocator: *const std.mem.Allocator, name: []const u8) FontAttributes {
    _ = allocator;
    return FontAttributes{ .name = name };
}