#version 450


layout (location=0) in vec2 inposition;
layout (location=1) in vec4 incolor;
layout (location=0) out vec4 fragColor;

void main() {
    gl_Position = vec4(inposition, 0.0, 1.0);
    fragColor = incolor;
}