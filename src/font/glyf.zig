const std = @import("std");
// FONT
const fu = @import("font.zig").fu;

// MEMORY
const lhmem = @import("../memory/memory.zig");
const Arena = lhmem.Arena;

// LINEAR ALGEBRA
const la = @import("../lin_alg/la.zig");
const Vec2f = la.Vec2f;

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

pub const Glyph = struct {
    arena: Arena,
    number_of_contours: u16,
    xMin: i16,
    yMin: i16,
    xMax: i16,
    yMax: i16,
    end_pts_of_contours: []u16,
    instruction_length: u16,
    instructions: []const u8,
    flags: []GlyphFlags,
    x_coords: []i16,
    y_coords: []i16,
    pub fn generate_points(self: *Glyph, subdivision: u32) []Vec2f {
        const count_off_curve: u32 = blk: {
            var count: u32 = 0;
            for (0..self.flags.len) |i| {
                if (!self.flags[i].on_curve) count += 1;
            }
            break :blk count;
        };
        const memrev = self.x_coords.len + count_off_curve * subdivision;
        var res = self.arena.push_array(Vec2f, memrev)[0..memrev];
        // iterate through array
        for (0..self.flags.len) |i| {
            if (self.flags[i].on_curve) {
                res[i].x = @floatFromInt(self.x_coords[i]);
                res[i].y = @floatFromInt(self.y_coords[i]);
            } else {}
        }
        return res;
    }
    fn tesselate_bezier(out: []Vec2f, idx: usize, subdivision: u32, p0: Vec2f, p1: Vec2f, p2: Vec2f) void {
        const step_per_iter: f32 = 1.0 / subdivision;
        for (idx..subdivision + idx) |i| {
            const t = i * step_per_iter;
            const t1 = (1.0 - t);
            const t2 = t * t;
            const x = t1 * t1 * p0.x + 2 * t1 * t * p1.x + t2 * p2.x;
            const y = t1 * t1 * p0.y + 2 * t1 * t * p1.y + t2 * p2.y;
            out[i].x = x;
            out[i].y = y;
        }
    }
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
    glyph.instruction_length = fu.read_u16m(&pos, buf);
    glyph.instructions = fu.read_nu8m(&pos, buf, glyph.instruction_length);

    const last_index = glyph.end_pts_of_contours[glyph.end_pts_of_contours.len - 1];
    glyph.flags = glyph.arena.push_array(GlyphFlags, last_index + 1)[0 .. last_index + 1];

    { // NOTE(lucashdez) we need for loop ?
        var i: usize = 0;
        while (i < glyph.flags.len) {
            glyph.flags[i] = std.mem.bytesToValue(GlyphFlags, &fu.read_u8m(&pos, buf));
            if (glyph.flags[i].repeat) {
                var repeat_count: u8 = fu.read_u8m(&pos, buf);
                while (repeat_count > 0) {
                    i += 1;
                    glyph.flags[i] = glyph.flags[i - 1];
                    repeat_count -= 1;
                }
            }
            i += 1;
        }
    }
    //TODO(lucashdez) read xcoords and ycoords
    glyph.x_coords = glyph.arena.push_array(i16, last_index + 1)[0 .. last_index + 1];
    glyph.y_coords = glyph.arena.push_array(i16, last_index + 1)[0 .. last_index + 1];
    var prev_x_coord: i16 = 0;
    var current_x_coord: i16 = 0;
    for (0..last_index + 1) |i| {
        const x_flag: u8 = @as(u8, @intFromBool(glyph.flags[i].x_short)) << @as(u8, 1) | @intFromBool(glyph.flags[i].x_short_pos);
        switch (x_flag) {
            0 => current_x_coord = fu.read_i16m(&pos, buf),
            1 => current_x_coord = 0,
            2 => current_x_coord = @as(i16, @intCast(fu.read_u8m(&pos, buf))) * -1,
            3 => current_x_coord = @intCast(fu.read_u8m(&pos, buf)),
            else => {
                unreachable;
            },
        }
        glyph.x_coords[i] = current_x_coord + prev_x_coord;
        prev_x_coord = glyph.x_coords[i];
    }

    var prev_y_coord: i16 = 0;
    var current_y_coord: i16 = 0;
    for (0..last_index + 1) |i| {
        const y_flag: u8 = @as(u8, @intFromBool(glyph.flags[i].y_short)) << @as(u8, 1) | @intFromBool(glyph.flags[i].y_short_pos);
        switch (y_flag) {
            0 => current_y_coord = fu.read_i16m(&pos, buf),
            1 => current_y_coord = 0,
            2 => current_y_coord = @as(i16, @intCast(fu.read_u8m(&pos, buf))) * -1,
            3 => current_y_coord = @intCast(fu.read_u8m(&pos, buf)),
            else => unreachable,
        }
        glyph.y_coords[i] = current_y_coord + prev_y_coord;
        prev_y_coord = glyph.y_coords[i];
    }

    std.debug.print("(#{s:3})  {s:5} {s:5}\n", .{ "#", "x", "y" });
    for (0..glyph.x_coords.len) |i| {
        std.debug.print("{d:4}#)  {d:5} {d:5}\n", .{ i, glyph.x_coords[i], glyph.y_coords[i] });
    }

    return glyph;
}

//OEF0QkKuGkqXafiGQ_P0Lg
