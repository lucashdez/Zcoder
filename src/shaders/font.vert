#version 450

layout (location=0) in vec2 position;
layout (location=1) in vec4 incolor;
layout (location=2) in vec2 inuv;

layout (location=0) out vec2 outuv;
layout (location=1) out vec4 fragColor;

void main() {
    gl_Position = vec4(position, 0.0, 1.0);
    fragColor = incolor;
    outuv = inuv;
}
