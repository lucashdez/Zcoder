const std = @import("std");
const allocator = std.heap.page_allocator;

pub const Arena = struct {
    base: std.mem.Allocator,
    mem: [*]const u8,
    pos: usize,
    cap: usize,

    pub fn push_array(arena: *Arena, comptime T: type, count: usize) [*]T {
        const size = @sizeOf(T) * count;
        const alignment = @alignOf(T);
        var ptr: *const u8 = &arena.mem[arena.pos];
        if (@intFromPtr(ptr) % alignment == 0) {
            // Aligned
            arena.pos += size;
            return @alignCast(@ptrCast(@constCast(ptr)));
        } else {
            while (!(@intFromPtr(ptr) % alignment == 0)) {
                arena.pos += 1;
                ptr = &arena.mem[arena.pos];
            }
            arena.pos += size;
            return @alignCast(@ptrCast(@constCast(ptr)));
        }
    }

    pub fn push_string(arena: *Arena, str: []const u8) []const u8 {
        const size = str.len;
        std.mem.copyForwards(u8, @constCast(arena.mem[arena.pos..size]), str);
        return arena.mem[arena.pos..size];
    }
};

pub fn make_arena(size: usize) Arena {
    return Arena{
        .base = allocator,
        .mem = allocator.rawAlloc(size, std.mem.Alignment.fromByteUnits(@alignOf(u8)), 0).?,
        .pos = 0,
        .cap = size,
    };
}

pub fn scratch_block() Arena {
    const size = (1 << 10) * 16;
    return Arena{
        .base = allocator,
        .mem = allocator.rawAlloc(size, std.mem.Alignment.fromByteUnits(@alignOf(u8)), 0).?,
        .pos = 0,
        .cap = size,
    };
}

pub fn get_bytes(comptime T: type, count: usize, data: [*]T) []u8 {
    const size = count * @sizeOf(T);
    return @as([*]u8, @ptrCast(data))[0..size];
}

pub fn KB(comptime size: usize) usize {
    return (1 << 10) * size;
}

pub fn MB(comptime size: usize) usize {
    return (1 << 20) * size;
}
