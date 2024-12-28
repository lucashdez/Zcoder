pub const Vec2f = struct {
    x: f32,
    y: f32,
};

pub fn vec2f(x: f32, y: f32) Vec2f {
    return Vec2f{ .x = x, .y = y };
}

pub fn vec2fs(x: f32) Vec2f {
    return Vec2f{
        .x = x,
        .y = x,
    };
}

pub fn vec2f_add(a: Vec2f, b: Vec2f) Vec2f {
    return Vec2f{ .x = a.x + b.x, .y = a.y + b.y };
}

pub fn vec2f_sub(a: Vec2f, b: Vec2f) Vec2f {
    return Vec2f{ .x = a.x - b.x, .y = a.y - b.y };
}

pub fn vec2f_mul(a: Vec2f, b: Vec2f) Vec2f {
    return Vec2f{ .x = a.x * b.x, .y = a.y * b.y };
}

pub fn vec2f_div(a: Vec2f, b: Vec2f) Vec2f {
    return Vec2f{ .x = a.x / b.x, .y = a.y / b.y };
}
