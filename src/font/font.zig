const std = @import("std");
const lhmem = @import("../memory/memory.zig");
const TARGET_OS = @import("builtin").os.tag;
const Arena = lhmem.Arena;
const assert = std.debug.assert;

// TABLES
const cmap = @import("cmap.zig");
const head = @import("head.zig");
const loca = @import("loca.zig");
const glyf = @import("glyf.zig");

pub const fu = struct {
    pub fn read_nu8m(pos: *usize, stream: []const u8, nu8: usize) []const u8 {
        defer pos.* += nu8;
        return stream[pos.* .. pos.* + nu8];
    }

    pub fn read_u8m(pos: *usize, stream: []const u8) u8 {
        defer pos.* += 1;
        return stream[pos.*];
    }

    pub fn read_u16(pos: usize, stream: []const u8) u16 {
        const ret: u16 = (@as(u16, stream[pos]) << 8) | (stream[pos + 1]);
        return ret;
    }

    pub fn read_u16m(pos: *usize, stream: []const u8) u16 {
        defer pos.* += 2;
        const ret: u16 = (@as(u16, stream[pos.*]) << 8) | (stream[pos.* + 1]);
        return ret;
    }

    pub fn read_i16m(pos: *usize, stream: []const u8) i16 {
        defer pos.* += 2;
        const ret: i16 = (@as(i16, stream[pos.*]) << 8) | (stream[pos.* + 1]);
        return ret;
    }

    pub fn read_u32(pos: usize, stream: []const u8) u32 {
        return std.mem.bytesToValue(u32, stream[pos .. pos + 4]);
    }

    pub fn read_u32m(pos: *usize, stream: []const u8) u32 {
        defer pos.* += 4;
        const ret = (@as(u32, stream[pos.*]) << 24) | (@as(u32, stream[pos.* + 1]) << 16) | (@as(u32, stream[pos.* + 2]) << 8) | (@as(u32, stream[pos.* + 3]));
        return ret;
    }

    pub fn read_u64m(pos: *usize, stream: []const u8) u64 {
        defer pos.* += 2;
        const ret: u64 = (@as(u64, stream[pos.*]) << 56) | (@as(u64, stream[pos.* + 1]) << 48) | (@as(u64, stream[pos.* + 2]) << 40) | (@as(u64, stream[pos.* + 3]) << 32) | (@as(u64, stream[pos.* + 4]) << 24) | (@as(u64, stream[pos.* + 5]) << 16) | (@as(u64, stream[pos.* + 6]) << 8) | (@as(u64, stream[pos.* + 7]));
        return ret;
    }

    pub fn read_i64m(pos: *usize, stream: []const u8) i64 {
        defer pos.* += 2;
        const ret: i64 = (@as(i64, stream[pos.*]) << 56) | (@as(i64, stream[pos.* + 1]) << 48) | (@as(i64, stream[pos.* + 2]) << 40) | (@as(i64, stream[pos.* + 3]) << 32) | (@as(i64, stream[pos.* + 4]) << 24) | (@as(i64, stream[pos.* + 5]) << 16) | (@as(i64, stream[pos.* + 6]) << 8) | (@as(i64, stream[pos.* + 7]));
        return ret;
    }
};

const offset_subtable = struct {
    scaler_type: u32,
    num_tables: u16,
    search_range: u16,
    entry_selector: u16,
    range_shift: u16,
    fn read(pos: *usize, stream: []const u8) offset_subtable {
        return offset_subtable{
            .scaler_type = fu.read_u32m(pos, stream),
            .num_tables = fu.read_u16m(pos, stream),
            .search_range = fu.read_u16m(pos, stream),
            .entry_selector = fu.read_u16m(pos, stream),
            .range_shift = fu.read_u16m(pos, stream),
        };
    }
};

const table_directory = struct {
    tag: []const u8,
    checksum: u32,
    offset: u32,
    length: u32,
    fn read(pos: *usize, stream: []const u8) table_directory {
        return table_directory{
            .tag = fu.read_nu8m(pos, stream, 4),
            .checksum = fu.read_u32m(pos, stream),
            .offset = fu.read_u32m(pos, stream),
            .length = fu.read_u32m(pos, stream),
        };
    }
};

const font_directory = struct {
    off_sub: offset_subtable,
    tbl_dir: []table_directory,
    fn print(self: *const font_directory) void {
        std.debug.print("{s}\t{s:10}{s:10}{s:10}\n", .{ "#)", "name", "len", "offset" });
        for (0..self.off_sub.num_tables) |i| {
            std.debug.print("{d})\t{s:10}{d:10}{d:10}\n", .{ i, self.tbl_dir[i].tag, self.tbl_dir[i].length, self.tbl_dir[i].offset });
        }
    }
    // Returns offset
    fn find_table(self: *const font_directory, name: []const u8) u32 {
        for (self.tbl_dir) |table| {
            if (std.mem.eql(u8, table.tag, name)) {
                return table.offset;
            }
        }
        return 0;
    }
};

pub const FontFace = struct {
    arena: Arena,
    glyphs: [256]?glyf.GeneratedGlyph,
    glyph: glyf.Glyph,
};

pub const FontAttributes = struct {
    arena: Arena,
    face: FontFace,
    name: []const u8,
    tables: font_directory,
};

pub fn load_font(name: []const u8) !FontAttributes {
    var arena = lhmem.make_arena(lhmem.MB(1));
    var scratch = lhmem.make_arena(lhmem.MB(30));
    const allocator = std.heap.page_allocator;
    var path: []const u8 = undefined;
    if (TARGET_OS == .windows) {
        //path = "C:/Windows/Fonts/";
        path = "C:/projects/zcoder/font/";
    } else {
        path = "/usr/share/fonts/";
    }
    const total_name_len = path.len + name.len;
    const name_buff = try allocator.alloc(u8, total_name_len);
    std.mem.copyForwards(u8, name_buff[0..path.len], path);
    std.mem.copyForwards(u8, name_buff[path.len..], name);
    const file = try std.fs.openFileAbsolute(name_buff, .{});
    defer file.close();
    const metadata = try file.metadata();
    const size = metadata.size();
    const buff: []u8 = scratch.push_array(u8, scratch.cap - 1)[0..scratch.cap - 1];
    const size_read = try file.readAll(buff);
    assert(size_read == size);
    var pos: usize = 0;
    var font_dir: font_directory = undefined;
    font_dir.off_sub = offset_subtable.read(&pos, buff);
    var tables = arena.push_array(table_directory, font_dir.off_sub.num_tables);

    for (0..font_dir.off_sub.num_tables) |i| {
        tables[i] = table_directory.read(&pos, buff);
    }
    font_dir.tbl_dir = tables[0..font_dir.off_sub.num_tables];
    font_dir.print();
    std.debug.print("\n\n", .{});

    var off = font_dir.find_table("cmap");
    const cmap_table = cmap.read(off, buff);
    off = font_dir.find_table("head");
    const loca_type = head.loca_type(off, buff);
    const loca_off = font_dir.find_table("loca");
    const a_index = cmap_table.format.get_glyph_index('E', buff);
    const a_offset = loca.get_glyph_offset(loca_off, a_index, loca_type, buff);
    const glyf_off = font_dir.find_table("glyf");
    const glyph_table = glyf.read(glyf_off + a_offset, buff);

    var face: FontFace = undefined;
    face.arena = lhmem.make_arena(lhmem.MB(80));
    face.glyph = glyph_table;
    for (0..256) |i| {
        const codepoint_index = cmap_table.format.get_glyph_index(@intCast(i), buff);
        if (codepoint_index == 0) {
            continue;
        }
        const codepoint_offset = loca.get_glyph_offset(loca_off, codepoint_index, loca_type, buff);
        std.log.debug("i: {c}\n", .{@as(u8, @intCast(i))});
        face.glyphs[i] = glyf.read(glyf_off + codepoint_offset, buff).generate_glyph(&face.arena, 3);
    }

    return FontAttributes{ .arena = arena, .name = name, .face = face, .tables = font_dir };
}
