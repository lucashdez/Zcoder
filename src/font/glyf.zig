const fu = @import("font.zig").fu;
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;

const GlyphFlags = packed struct {
    on_curve: bool,

    x_short: bool,
    y_short: bool,

    repeat: bool,

    x_short_pos: bool,
    y_short_pos: bool,

    reserved1: bool,
    reserved2: bool,
};

const Glyph = struct {
    arena: Arena,
    number_of_contours: u16,
    xMin: i16,
    yMin: i16,
    xMax: i16,
    yMax: i16,
    end_pts_of_contours: []u16,
    instruction_length: u16,
    instructions: []u8,
    flags: []GlyphFlags,
    x_coords: []i16,
    y_coords: []i16,
};

pub fn read(offset: usize, buf: []const u8) Glyph {
    var pos: usize = offset;
    var glyph: Glyph = undefined;
    glyph.arena = lhmem.make_arena(lhmem.KB(26));
    glyph.number_of_contours = fu.read_u16m(&pos, buf);
    glyph.xMin = fu.read_i16m(&pos, buf);
    glyph.yMin = fu.read_i16m(&pos, buf);
    glyph.xMax = fu.read_i16m(&pos, buf);
    glyph.yMax = fu.read_i16m(&pos, buf);
    glyph.end_pts_of_contours = glyph.arena.push_array(u16, glyph.number_of_contours * 2)[0..glyph.number_of_contours];
    for (0..glyph.end_pts_of_contours.len) |i| {
        glyph.end_pts_of_contours[i] = fu.read_u16m(&pos, buf);
    }

    return glyph;
}
