// STD
const std = @import("std");
const assert = std.debug.assert;

// FONT UTILS
const fu = @import("font.zig").fu;
const FontDirectory = @import("font.zig").FontDirectory;

// MEMORY
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;


pub const hhea = struct {
    version: u32,
    ascent: i16,
    descent: i16,
    lineGap: i16,
    advanceWidthMax: u16,
    minLeftSideBearing: i16,
    minRightSideBearing: i16,
    xMaxExtent: i16,
    caretSlopeRise: i16,
    caretSlopeRun: i16,
    caretOffset: i16,
    r1: i16,
    r2: i16,
    r3: i16,
    r4: i16,
    metricDataFormat: i16,
    numOfLongHorMetrics: u16,

    pub fn init(ft: FontDirectory, buf: []const u8) hhea {
        const offset = ft.find_table("hhea");
        var pos: usize = @intCast(offset);
        var hh: hhea = undefined;
        hh.version = fu.read_u32m(&pos, buf) >> 16;
        hh.ascent = fu.read_i16m(&pos, buf);
        hh.descent = fu.read_i16m(&pos, buf);
        hh.lineGap = fu.read_i16m(&pos, buf);
        hh.advanceWidthMax = fu.read_u16m(&pos, buf);
        hh.minLeftSideBearing = fu.read_i16m(&pos, buf);
        hh.minRightSideBearing = fu.read_i16m(&pos, buf);
        hh.xMaxExtent = fu.read_i16m(&pos, buf);
        hh.caretSlopeRise = fu.read_i16m(&pos, buf);
        hh.caretSlopeRun = fu.read_i16m(&pos, buf);
        hh.caretOffset = fu.read_i16m(&pos, buf);
        hh.r1 = fu.read_i16m(&pos, buf);
        hh.r2 = fu.read_i16m(&pos, buf);
        hh.r3 = fu.read_i16m(&pos, buf);
        hh.r4 = fu.read_i16m(&pos, buf);
        hh.metricDataFormat = fu.read_i16m(&pos, buf);
        hh.numOfLongHorMetrics = fu.read_u16m(&pos, buf);

        return hh;
    }
    pub fn print(self: *const hhea) void {
        const p = std.debug.print;
        p("hhea V.:{}\nx", .{self.version});
    }
};