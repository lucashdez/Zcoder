// STD
const std = @import("std");
const assert = std.debug.assert;

// FONT UTILS
const fu = @import("font.zig").fu;
const FontDirectory = @import("font.zig").FontDirectory;

// MEMORY
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;

pub const hmtx = struct {
    advance: []u16,
    bearing: []i16,
    pub fn init(arena: *Arena, ft: FontDirectory, buf: []const u8, numOfLongHorMetrics: u16, numGlyphs: u16) hmtx {
        const offset = ft.find_table("hmtx");
        var pos: usize = @intCast(offset);
        var hm: hmtx = undefined;
        const numBearings = numGlyphs + 1 - numOfLongHorMetrics;
        hm.advance = arena.push_array(u16, numGlyphs + 1)[0..numGlyphs + 1];
        hm.bearing = arena.push_array(i16, numGlyphs + 1)[0..numGlyphs + 1];

        for (0..numOfLongHorMetrics) |i| {
            hm.advance[i] = fu.read_u16m(&pos, buf);
            hm.bearing[i] = fu.read_i16m(&pos, buf);
        }
        for (0..numBearings) |i| {
            hm.bearing[i] = fu.read_i16m(&pos, buf);
            hm.advance[i] = hm.advance[numOfLongHorMetrics - 1];
        }
        return hm;
    }
};