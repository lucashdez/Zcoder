pub const Vec2u32 = union { pos: struct { x: u32, y: u32 }, v: [2]u32 };

pub const Rectu32 = union {
    pos: struct {
        p0: u32,
        p1: u32,
        p2: u32,
        p3: u32,
    },
    size: struct {
        pos: Vec2u32,
        width: u32,
        height: u32,
    },
    v_pos: struct {
        p0: Vec2u32,
        p1: Vec2u32,
    },
};

pub const Vec2f32 = union { xy: struct { x: f32, y: f32 }, v: [2]f32 };
pub const Rectf32 = union {
    pos: struct {
        x0: f32,
        y0: f32,
        x1: f32,
        y1: f32,
    },
    size: struct {
        pos: Vec2f32,
        width: f32,
        height: f32,
    },
    v_pos: struct {
        p0: Vec2f32,
        p1: Vec2f32,
    },
};
