#version 450

layout(location = 0) in vec2 uv;
layout(location = 1) in vec4 color;

layout(location = 0) out vec4 outColor;

void main() {
    float f = uv.x * uv.x - uv.y;
    if (f > 0.0) discard;
    outColor = color;
}
