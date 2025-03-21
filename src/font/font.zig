const std = @import("std");
const lhmem = @import("../memory/memory.zig");
const TARGET_OS = @import("builtin").os.tag;
const Arena = lhmem.Arena;

pub const FontFace = struct {};

pub const FontAttributes = struct {
    arena: Arena,
    face: FontFace,
    name: [:0]const u8,
};

pub fn load_font(name: []const u8) !FontAttributes {
    const arena = lhmem.make_arena(lhmem.MB(1));
    const scratch = lhmem.make_arena(lhmem.MB(1));
    var path: []const u8 = undefined;
    if (TARGET_OS == .windows) {
        path = "C:/Windows/Fonts/";
    } else {
        path = "/usr/share/fonts/";
    }
    const file = try std.fs.openFileAbsolute(path ++ name, .{});
    const metadata = try file.metadata();
    const size = metadata.size();
    const buff: []u8 = scratch.push_array(u8, size)[0..size];
    file.readAll(buff);

    return FontAttributes{ .arena = arena, .name = name };
}
