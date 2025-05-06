const std = @import("std");
const Application = @import("../../main.zig").Application;
const GeneratedGlyph = @import("../../font/glyf.zig").GeneratedGlyph;

// Vulkan
const lhvk = @import("../lhvk.zig");
const LhvkGraphicsCtx = lhvk.LhvkGraphicsCtx;

// Vertices
const vertex = @import("vertex.zig");
const VertexList = vertex.VertexList;
const Vertex = vertex.Vertex;

// Primitives
const primitives = @import("primitives.zig");
const Color = primitives.Color;
const drawp_vertex = primitives.drawp_vertex;

// Linear algebra
const la = @import("../../lin_alg/la.zig");

// Base
const base = @import("../../base/base_types.zig");
const lhmem = @import("../../memory/memory.zig");
const Arena = lhmem.Arena;
const Rectu32 = base.Rectu32;
const Rectf32 = base.Rectf32;
const TARGET_OS = @import("builtin").target.os.tag;

pub fn draw_string(app: *Application, arena: *Arena, text: []u8, color: Color) void {
    // TODO(lucashdez): face metrics
    // TODO(lucashdez): word wrap
    var cursor: [2]f32 = .{ 0, 0 };
    const face = app.font.face;
    var last_width: f32 = 0;
    for (0..text.len) |i| {
        if (face.glyphs[text[i]]) |glyph| {
            draw_glyph(app, arena, glyph, cursor, color);
            cursor[0] += glyph.bounding_box.size.width / 10;
            //Temporal patch
            last_width = glyph.bounding_box.size.width / 10;
        } else if (text[i] == ' ') {
            cursor[0] += last_width;
        }
    }
}

pub fn draw_glyph(app: *Application, arena: *Arena, glyph: GeneratedGlyph, cursor: [2]f32, color: Color) void {
    var j: usize = 0;
    var vl: *VertexList = arena.push_item(VertexList);
    vl.arena = lhmem.scratch_block();
    app.graphics_ctx.current_vertex_group.sll_push_back(vl);
    const x = (glyph.bounding_box.size.pos.xy.x / 10) + cursor[0];
    const y = (glyph.bounding_box.size.pos.xy.y / 10) + cursor[1];
    const width = glyph.bounding_box.size.width / 10;
    const height = glyph.bounding_box.size.height / 10;
    const red = Color.create(0xFF0000FF);
    drawp_vertex(&app.graphics_ctx, vl, .{ .xy = .{ .x = x, .y = y } }, red);
    drawp_vertex(&app.graphics_ctx, vl, .{ .xy = .{ .x = x + width, .y = y } }, red);
    drawp_vertex(&app.graphics_ctx, vl, .{ .xy = .{ .x = x + width, .y = y - height } }, red);
    drawp_vertex(&app.graphics_ctx, vl, .{ .xy = .{ .x = x, .y = y - height } }, red);
    drawp_vertex(&app.graphics_ctx, vl, .{ .xy = .{ .x = x, .y = y } }, red);
    for (0..glyph.end_indexes_for_strokes.len) |i| {
        var list_ptr: *VertexList = arena.push_item(VertexList);
        list_ptr.arena = lhmem.scratch_block();
        app.graphics_ctx.current_vertex_group.sll_push_back(list_ptr);

        while (j < (glyph.end_indexes_for_strokes[i])) {
            const p: la.Vec2f = glyph.vertex[j];
            drawp_vertex(&app.graphics_ctx, list_ptr, .{ .xy = .{ .x = (p.x / 10) + cursor[0], .y = (p.y / 10) + cursor[1] } }, color);
            j += 1;
        }
    }
}
