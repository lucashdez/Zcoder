// STD
const std = @import("std");
const assert = std.debug.assert;

// FONT UTILS
const fu = @import("font.zig").fu;
const FontDirectory = @import("font.zig").FontDirectory;

// MEMORY
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;

pub const maxp = struct {
    version: u32,
    numGlyphs: u16,
    maxPoints: u16,
    maxContours: u16,
    maxComponentPoints: u16,
    maxComponentContours: u16,
    maxZones: u16,
    maxTwilightPoints: u16,
    maxStorage: u16,
    maxFunctionDefs: u16,
    maxInstructionDefs: u16,
    maxStackElements: u16,
    maxSizeOfInstructions: u16,
    maxComponentElements: u16,
    maxComponentDepth: u16,

    pub fn init(ft: FontDirectory, buf: []const u8) maxp {
        const offset = ft.find_table("maxp");
        var pos: usize = @intCast(offset);
        var mp: maxp = undefined;
        mp.version = fu.read_u32m(&pos, buf) >> 16;
        mp.numGlyphs = fu.read_u16m(&pos, buf);
        mp.maxPoints = fu.read_u16m(&pos, buf);
        mp.maxContours = fu.read_u16m(&pos, buf);
        mp.maxComponentPoints = fu.read_u16m(&pos, buf);
        mp.maxComponentContours = fu.read_u16m(&pos, buf);
        mp.maxZones = fu.read_u16m(&pos, buf);
        mp.maxTwilightPoints = fu.read_u16m(&pos, buf);
        mp.maxStorage = fu.read_u16m(&pos, buf);
        mp.maxFunctionDefs = fu.read_u16m(&pos, buf);
        mp.maxInstructionDefs = fu.read_u16m(&pos, buf);
        mp.maxStackElements = fu.read_u16m(&pos, buf);
        mp.maxSizeOfInstructions = fu.read_u16m(&pos, buf);
        mp.maxComponentElements = fu.read_u16m(&pos, buf);
        mp.maxComponentDepth = fu.read_u16m(&pos, buf);
        return mp;
    }
    pub fn print(self: *const maxp) void {
        // TODO(lucashdez) pretty print
        const p = std.debug.print;
        p("| {d:5}|{d:5}|\n", .{self.version,self.numGlyphs});
    }

};