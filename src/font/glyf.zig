const std = @import("std");
// BASE
const base = @import("../base/base_types.zig");
const Rectf32 = base.Rectf32;
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

pub const GeneratedGlyph = struct {
    vertex: []Vec2f,
    end_indexes_for_strokes: []usize,
    bounding_box: Rectf32,
    advance: f32,
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

    pub fn generate_glyph(self: *const Glyph, arena: *Arena, subdivision: u32) GeneratedGlyph {
        // NOTE(lucashdez) SEE THE DIFFS WITH PREVIOUS THING BECAUSE WE DONT SUPPORT COMPOUND YETT
        const count_off_curve: u32 = blk: {
            var count: u32 = 0;
            for (0..self.flags.len) |i| {
                if (!self.flags[i].on_curve) count += 1;
            }
            break :blk count;
        };
        const memrev = self.x_coords.len + count_off_curve * (subdivision) * self.number_of_contours;
        var res: []Vec2f = arena.push_array(Vec2f, memrev + 1)[0 .. memrev + 1];
        var end_indexes: []usize = arena.push_array(usize, self.number_of_contours)[0..self.number_of_contours];
        var j: usize = 0;
        var res_index: usize = 0;
        // iterate through array
        for (0..self.number_of_contours) |i| {
            const contour_start_index: usize = j;
            const generated_points_start_index: usize = res_index;
            var contour_start: bool = true;
            var contour_started: bool = false;
            while (j <= self.end_pts_of_contours[i] and j < self.x_coords.len) {
                defer j += 1;
                var x: f32 = @floatFromInt(self.x_coords[j]);
                var y: f32 = @floatFromInt(self.y_coords[j]);

                const contour_len: usize = self.end_pts_of_contours[i] - contour_start_index + 1;
                //const cur_index = j;
                const next_index = (j + 1 - contour_start_index) % contour_len + contour_start_index;

                if (res_index < res.len and self.flags[j].on_curve) {
                    res[res_index].x = x;
                    res[res_index].y = y;
                    res_index += 1;
                    continue;
                } else if (res_index < res.len and next_index < self.flags.len) {
                    if (contour_start) {
                        contour_started = true;
                        if (self.flags[next_index].on_curve) {
                            res[res_index].x = @floatFromInt(self.x_coords[next_index]);
                            res[res_index].y = @floatFromInt(self.y_coords[next_index]);
                            res_index += 1;
                            continue;
                        }
                        x = x + (@as(f32, @floatFromInt(self.x_coords[next_index])) - x) / 2.0;
                        y = y + (@as(f32, @floatFromInt(self.y_coords[next_index])) - y) / 2.0;
                        res[res_index].x = x;
                        res[res_index].y = y;
                        res_index += 1;
                    }

                    const p0: Vec2f = res[res_index - 1];
                    const p1: Vec2f = .{ .x = x, .y = y };
                    var p2: Vec2f = .{ .x = @floatFromInt(self.x_coords[next_index]), .y = @floatFromInt(self.y_coords[next_index]) };
                    if (!self.flags[next_index].on_curve) {
                        p2.x = p1.x + (p2.x - p1.x) / 2.0;
                        p2.y = p1.y + (p2.y - p1.y) / 2.0;
                    } else {
                        // TODO?
                    }
                    tesselate_bezier(&res, res_index, subdivision, p0, p1, p2);
                    res_index += subdivision;
                    contour_start = false;
                } else {
                    std.log.warn("[WARN] something happens with the next_index", .{});
                }
            }
            if (res_index < res.len) {
                if (self.flags[j - 1].on_curve) {
                    res[res_index] = res[generated_points_start_index];
                    res_index += 1;
                } else {
                    res[res_index] = res[generated_points_start_index];
                    res_index += 1;
                }
            }
            if (res_index < res.len and contour_started) {
                const p0: Vec2f = res[res_index - 1];
                const p1: Vec2f = .{ .x = @floatFromInt(self.x_coords[contour_start_index]), .y = @floatFromInt(self.y_coords[contour_start_index]) };
                const p2: Vec2f = res[generated_points_start_index];
                tesselate_bezier(&res, res_index, subdivision, p0, p1, p2);
                res_index += 1;
            }
            end_indexes[i] = res_index;
        }
        while (res_index < res.len) {
            res[res_index] = res[res_index - 1];
            res_index += 1;
        }
        return GeneratedGlyph
        {
            .vertex = res,
            .end_indexes_for_strokes = end_indexes,
            .bounding_box = Rectf32 {
                .size = .{
                    .pos = .{
                        .xy = .{
                            .x = @floatFromInt(self.xMin), .y = @floatFromInt(self.yMax)
                        }
                    },
                    .width = @floatFromInt(@abs(self.xMax - self.xMin)),
                    .height = @floatFromInt(@abs(self.yMax - self.yMin))
                }
            },
            .advance = 0.0
        };
    }
};

fn tesselate_bezier(out: *[]Vec2f, idx: usize, subdivision: u32, p0: Vec2f, p1: Vec2f, p2: Vec2f) void {
    const step_per_iter: f64 = 1.0 / @as(f64, @floatFromInt(subdivision));
    for (0..subdivision) |i| {
        const t = @as(f64, @floatFromInt(i)) * step_per_iter;
        const t1 = (1.0 - t);
        const t2 = t * t;
        const x = t1 * t1 * p0.x + 2 * t1 * t * p1.x + t2 * p2.x;
        const y = t1 * t1 * p0.y + 2 * t1 * t * p1.y + t2 * p2.y;
        out.*[idx + i].x = @as(f32, @floatCast(x));
        out.*[idx + i].y = @as(f32, @floatCast(y));
        //std.log.debug("({}) x: {}, y: {}, t: {}, step: {}", .{ idx, @as(i32, @intFromFloat(x)), @as(i32, @intFromFloat(y)), t, step_per_iter });
    }
}

pub fn read(offset: usize, buf: []const u8) Glyph {
    var pos: usize = offset;
    var glyph: Glyph = undefined;
    glyph.arena = lhmem.make_arena(lhmem.MB(2));
    // TODO(lucashdez) read compound glyfs
    glyph.number_of_contours = fu.read_u16m(&pos, buf);
    glyph.xMin = fu.read_i16m(&pos, buf);
    glyph.yMin = fu.read_i16m(&pos, buf);
    glyph.xMax = fu.read_i16m(&pos, buf);
    glyph.yMax = fu.read_i16m(&pos, buf);
    glyph.end_pts_of_contours = glyph.arena.push_array(u16, @as(u32, @intCast(glyph.number_of_contours)) * 2)[0..glyph.number_of_contours];
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

    // std.debug.print("(#{s:3})  {s:5} {s:5}\n", .{ "#", "x", "y" });
    // for (0..glyph.x_coords.len) |i| {
    //    std.debug.print("{d:4}#)  {d:5} {d:5}\n", .{ i, glyph.x_coords[i], glyph.y_coords[i] });
    // }

    return glyph;
}
