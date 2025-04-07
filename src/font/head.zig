const std = @import("std");

const fu = @import("font.zig").fu;

pub const head = struct {
    version: u32,
    fontRevision: u32,

    checkSumAdjustment: u32,
    magicNumber: u32,

    flags: u16,
    unitsPerEm: u16,

    created: u64,
    modified: u64,

    xMin: u16,
    yMin: u16,
    xMax: u16,
    yMax: u16,

    macStyle: u16,
    lowestRecPPEM: u16,
    fontDirectionHint: u16,
    indexToLocFormat: u16,
    glyphDataFormat: u16,
};
pub fn loca_type(offset: u32, buf: []const u8) u16 {
    return fu.read_u16(offset + 50, buf);
}
