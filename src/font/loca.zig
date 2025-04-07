const fu = @import("font.zig").fu;

pub fn get_glyph_offset(loca_offset: usize, glyph_index: usize, loca_type: u16, buf: []const u8) u32 {
    if (loca_type == 0) {
        return @as(u32, @intCast(fu.read_u16(loca_offset + glyph_index * 2, buf))) * 2;
    } else {
        return fu.read_u32(loca_offset + glyph_index, buf);
    }
}
