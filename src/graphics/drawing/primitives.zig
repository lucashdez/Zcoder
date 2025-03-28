// Vulkan
const lhvk = @import("../lhvk.zig");
const LhvkGraphicsCtx = lhvk.LhvkGraphicsCtx;

// Vertices
const vertex = @import("vertex.zig");
const VertexList = vertex.VertexList;
const Vertex = vertex.Vertex;

// Linear algebra
const la = @import("../../lin_alg/la.zig");

// Base
const base = @import("../../base/base_types.zig");
const Rectu32 = base.Rectu32;
const Rectf32 = base.Rectf32;

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn create(hex: u32) Color {
        return Color{
            .r = @as(f32, @floatFromInt((hex >> 24) & 0xff)) / 255,
            .g = @as(f32, @floatFromInt((hex >> 16) & 0xff)) / 255,
            .b = @as(f32, @floatFromInt((hex >> 8) & 0xff)) / 255,
            .a = @as(f32, @floatFromInt((hex >> 0) & 0xff)) / 255,
        };
    }
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

pub fn drawp_triangle(ctx: *LhvkGraphicsCtx, pos: struct { [2]f32, [2]f32, [2]f32 }, color: Color) void {
    const winrect: Rectu32 = ctx.window.get_size();
    const top = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, pos[0][0], @floatFromInt(winrect.size.width)), la.normalize(f32, pos[0][1], @floatFromInt(winrect.size.height))), color);
    const left = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, pos[1][0], @floatFromInt(winrect.size.width)), la.normalize(f32, pos[1][1], @floatFromInt(winrect.size.height))), color);
    const right = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, pos[2][0], @floatFromInt(winrect.size.width)), la.normalize(f32, pos[2][1], @floatFromInt(winrect.size.height))), color);
    ctx.current_vertex_group.sll_push_back(top);
    ctx.current_vertex_group.sll_push_back(left);
    ctx.current_vertex_group.sll_push_back(right);
}

pub fn drawp_rectangle(ctx: *LhvkGraphicsCtx, r: Rectf32, color: Color) void {
    const winrect: Rectu32 = ctx.window.get_size();
    const top_left = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, r.size.pos.pos.x, @floatFromInt(winrect.size.width)), la.normalize(f32, r.size.pos.pos.y, @floatFromInt(winrect.size.height))), color);
    const top_right = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, r.size.pos.pos.x + r.size.width, @floatFromInt(winrect.size.width)), la.normalize(f32, r.size.pos.pos.y, @floatFromInt(winrect.size.height))), color);
    const bottom_left = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, r.size.pos.pos.x, @floatFromInt(winrect.size.width)), la.normalize(f32, r.size.pos.pos.y + r.size.height, @floatFromInt(winrect.size.height))), color);
    const bottom_right = Vertex.init(&ctx.current_vertex_group.arena, la.vec2f(la.normalize(f32, r.size.pos.pos.x + r.size.width, @floatFromInt(winrect.size.width)), la.normalize(f32, r.size.pos.pos.y + r.size.height, @floatFromInt(winrect.size.height))), color);
    ctx.current_vertex_group.sll_push_back(top_left);
    ctx.current_vertex_group.sll_push_back(top_right);
    ctx.current_vertex_group.sll_push_back(bottom_left);
    ctx.current_vertex_group.sll_push_back(bottom_right);
}
