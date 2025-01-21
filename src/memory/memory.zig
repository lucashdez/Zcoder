const std = @import("std");
pub const Arena = struct {
    base: *const std.mem.Allocator,
    mem: [*]const u8,
    pos: usize,
    cap: usize,
    pub fn init(allocator: *const std.mem.Allocator, size: usize) Arena {
        return Arena{
            .base = allocator,
            .mem = allocator.rawAlloc(size, @alignOf(u8), 0).?,
            .pos = 0,
            .cap = size,
        };
    }
};