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

pub const Vec4f = struct {
    i: f32, j: f32, k: f32, t: f32
};

pub fn vec4f(i: f32, j: f32, k: f32, t: f32) Vec4f {
    return Vec4f{ .i = i , .j = j, .k = k, .t = t };
}



pub fn clamp(comptime T: type, value: *T, min: T, max: T) void {
    if (value.* < min) value.* = min;
    if (value.* > max) value.* = max;
}

pub fn normalize(comptime T: type, value: T, norm: T) T {
    return (value / norm) - 1 ; // vulkan goes from -1,-1 to 1,1
}