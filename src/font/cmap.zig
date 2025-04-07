// STD
const std = @import("std");
const assert = std.debug.assert;

// FONT UTILS
const fu = @import("font.zig").fu;

// MEMORY
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;

// BEGIN
const cmap = struct {
    format: CmapFormat4,
};

const CmapIndex = struct {
    version: u16,
    numberSubtables: u16,
};

const CmapSubtable = struct {
    platformId: u16,
    platformSpecificId: u16,
    offset: u32,

    fn print(self: *const CmapSubtable) void {
        var platform_name: []const u8 = undefined;
        switch (self.platformId) {
            0 => {
                platform_name = "Unicode";
            },
            1 => {
                platform_name = "Macintosh";
            },
            3 => {
                platform_name = "Windows";
            },
            else => {
                platform_name = "Not Supported";
            },
        }
        std.debug.print("{d:3}{s:15}{d:10}{d:10}\n", .{ self.platformId, platform_name, self.platformSpecificId, self.offset });
    }
};

const CmapFormat4 = struct {
    arena: Arena,
    offset: u32,
    format: u16,
    length: u16,
    language: u16,
    segCountX2: u16,
    searchRange: u16,
    entrySelector: u16,
    rangeShift: u16,
    reservedPad: u16,
    endCode: []u16,
    startCode: []u16,
    idDelta: []u16,
    idRangeOffset: []u16,
    glyphIdArray: []u16,

    fn print(self: *const CmapFormat4) void {
        std.log.info("Format {d}, Length {d}, Language {d}, SegmentCount {d}\n", .{ self.format, self.length, self.language, self.segCountX2 / 2 });
        std.log.info("search params (range: {d}, entry {d}, range {d}) reserved pad: {d}\n", .{ self.searchRange, self.entrySelector, self.rangeShift, self.reservedPad });
        std.log.info("{s:15}{s:10}{s:10}{s:10}{s:10}\n", .{ "segmentranges", "startCode", "endcode", "idDelta", "idRange" });
        for (0..self.segCountX2 / 2) |i| {
            std.log.info("{s:15}{d:10}{d:10}{d:10}{d:10}\n", .{ "-", self.startCode[i], self.endCode[i], self.idDelta[i], self.idRangeOffset[i] });
        }
    }

    pub fn get_glyph_index(self: *const CmapFormat4, code_point: u16, buf: []const u8) usize {
        var i_index: isize = -1;
        var index: usize = 0;
        for (0..self.segCountX2 / 2) |i| {
            if (self.endCode[i] > code_point) {
                i_index = @intCast(i);
                index = i;
                break;
            }
        }

        if (i_index == -1) return 0;

        if (self.startCode[index] < code_point) {
            //3. check the corresponding idRangeOffset if its not 0 then go to step 4 otherwise go to step 7
            if (self.idRangeOffset[index] != 0) {
                var pos = self.offset + 12 + self.segCountX2 * 3 + 2;
                pos += self.idRangeOffset[index];
                // +2 because BIG ENDIAN correction
                pos += 2 * (code_point - self.startCode[index]) + 2;

                return fu.read_u16(pos, buf);
            } else {
                return code_point + self.idDelta[index];
            }
        }

        return 0;
    }
};

fn read_format_table_f4(offset: u32, buf: []const u8) CmapFormat4 {
    var table: CmapFormat4 = undefined;
    table.arena = lhmem.scratch_block();
    table.offset = offset;
    var pos: usize = @intCast(offset);
    table.format = fu.read_u16m(&pos, buf);
    table.length = fu.read_u16m(&pos, buf);
    table.language = fu.read_u16m(&pos, buf);
    table.segCountX2 = fu.read_u16m(&pos, buf);
    table.searchRange = fu.read_u16m(&pos, buf);
    table.entrySelector = fu.read_u16m(&pos, buf);
    table.rangeShift = fu.read_u16m(&pos, buf);
    const mem_reserve = table.segCountX2 / 2;
    table.endCode = table.arena.push_array(u16, mem_reserve)[0..mem_reserve];
    table.startCode = table.arena.push_array(u16, mem_reserve)[0..mem_reserve];
    table.idDelta = table.arena.push_array(u16, mem_reserve)[0..mem_reserve];
    table.idRangeOffset = table.arena.push_array(u16, mem_reserve)[0..mem_reserve];

    const end_pos_start: usize = pos;
    const start_code_start: usize = pos + table.segCountX2 + 2;
    const id_delta_start: usize = pos + table.segCountX2 * 2 + 2;
    const id_range_offset_start: usize = pos + table.segCountX2 * 3 + 2;

    for (0..mem_reserve) |i| {
        table.endCode[i] = fu.read_u16(end_pos_start + i * 2, buf);
        table.startCode[i] = fu.read_u16(start_code_start + i * 2, buf);
        table.idDelta[i] = fu.read_u16(id_delta_start + i * 2, buf);
        table.idRangeOffset[i] = fu.read_u16(id_range_offset_start + i * 2, buf);
    }

    var glyph_id_array_start: usize = pos + table.segCountX2 * 4 + 2;
    const remaining_bytes = table.length - (glyph_id_array_start - offset);
    const glyph_id_count = remaining_bytes / 2;
    table.glyphIdArray = table.arena.push_array(u16, glyph_id_count)[0..glyph_id_count];
    for (0..remaining_bytes / 2) |i| {
        table.glyphIdArray[i] = fu.read_u16m(&glyph_id_array_start, buf);
    }

    return table;
}

pub fn read(offset: u32, buf: []const u8) cmap {
    var scratch = lhmem.scratch_block();
    var pos: usize = @intCast(offset);
    const cmap_index = CmapIndex{ .version = fu.read_u16m(&pos, buf), .numberSubtables = fu.read_u16m(&pos, buf) };

    const cmap_subtables_arr = scratch.push_array(CmapSubtable, cmap_index.numberSubtables)[0..cmap_index.numberSubtables];

    var unicode_table_offset: u32 = undefined;
    std.debug.print("{s:3}{s:15}{s:10}{s:10}\n", .{ "id", "platform", "specific", "offset" });
    for (0..cmap_index.numberSubtables) |i| {
        cmap_subtables_arr[i] = .{
            .platformId = fu.read_u16m(&pos, buf),
            .platformSpecificId = fu.read_u16m(&pos, buf),
            .offset = fu.read_u32m(&pos, buf),
        };
        cmap_subtables_arr[i].print();
        if (cmap_subtables_arr[i].platformId == 0) {
            unicode_table_offset = cmap_subtables_arr[i].offset + offset;
        }
    }

    const format_id = fu.read_u16(unicode_table_offset, buf);
    // TODO(lucashdez): right now we only support format 4
    assert(format_id == 4);
    const format = read_format_table_f4(unicode_table_offset, buf);
    format.print();
    std.log.info("A: {d} B: {d}, C: {}, D: {}, E: {}", .{ format.get_glyph_index('A', buf), format.get_glyph_index('B', buf), format.get_glyph_index('C', buf), format.get_glyph_index('D', buf), format.get_glyph_index('E', buf) });

    return cmap{ .format = format };
}
