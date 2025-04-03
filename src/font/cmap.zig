const std = @import("std");
const fu = @import("font.zig").fu;
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;

const cmap = struct {};

const CmapIndex = struct {
    version: u16,
    numberSubtables: u16,
};

const CmapSubtables = struct {
    platformId: u16,
    platformSpecificId: u16,
    offset: u32,
};

pub fn read(offset: u32, buf: []const u8) cmap {
    var scratch = lhmem.scratch_block();
    var pos: usize = @intCast(offset);
    const cmap_index = CmapIndex{ .version = fu.read_u16m(&pos, buf), .numberSubtables = fu.read_u16m(&pos, buf) };

    const cmap_subtables_arr = scratch.push_array(CmapSubtables, cmap_index.numberSubtables)[0..cmap_index.numberSubtables];

    for (0..cmap_index.numberSubtables) |i| {
        cmap_subtables_arr[i] = .{
            .platformId = fu.read_u16m(&pos, buf),
            .platformSpecificId = fu.read_u16m(&pos, buf),
            .offset = fu.read_u32m(&pos, buf),
        };
    }

    std.log.info("{any}\n{any}\n", .{ cmap_index, cmap_subtables_arr });

    return cmap{};
}
