// Vulkan
const lhvk = @import("../lhvk.zig");
const LhvkGraphicsCtx = lhvk.LhvkGraphicsCtx;

// Vertices
const vertex = @import("vertex.zig");
const VertexList = vertex.VertexList;
const Vertex = vertex.Vertex;

// Linear algebra
const la = @import("../../lin_alg/la.zig");

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn create(hex: u32) Color {
        return Color {
            .r = @intCast((hex >> 24) & 0xff),
            .g = @intCast((hex >> 16) & 0xff),
            .b = @intCast((hex >> 8) & 0xff),
            .a = @intCast((hex >> 0) & 0xff),
        };
    }
};

pub const Rect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

};


pub fn drawp_triangle(ctx: *LhvkGraphicsCtx, pos: .{usize, usize, usize}) void {
     _ = ctx;
     _ = pos;
}

pub fn drawp_rectangle(ctx: *LhvkGraphicsCtx, r: Rect, color: Color) void {
    var top_left = Vertex.init(la.vec2f(la.normalize(f32 ,r.x, @floatFromInt(ctx.window.width)), la.normalize(f32 ,r.y, @floatFromInt(ctx.window.height))), color);
    var top_right = Vertex.init(la.vec2f(la.normalize(f32 ,r.x + r.w, @floatFromInt(ctx.window.width)), la.normalize(f32 ,r.y, @floatFromInt(ctx.window.height))), color);
    var bottom_left = Vertex.init(la.vec2f(la.normalize(f32 ,r.x, @floatFromInt(ctx.window.width)), la.normalize(f32 ,r.y + r.h, @floatFromInt(ctx.window.height))), color);
    var bottom_right = Vertex.init(la.vec2f(la.normalize(f32 ,r.x + r.h, @floatFromInt(ctx.window.width)), la.normalize(f32 ,r.y + r.h, @floatFromInt(ctx.window.height))), color);
    ctx.current_vertex_group.sll_push_back(&top_left);
    ctx.current_vertex_group.sll_push_back(&top_right);
    ctx.current_vertex_group.sll_push_back(&bottom_left);
    ctx.current_vertex_group.sll_push_back(&bottom_right);
}