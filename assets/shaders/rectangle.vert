#version 330 core

const vec2 positions[4] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0,  1.0)
);

layout(location = 0) in vec2 center;
layout(location = 1) in vec2 radius;
layout(location = 2) in vec4 color;

out vec4 color_vert;

void main() {
    color_vert = color;

    vec2 pos = positions[gl_VertexID];

    pos = center + radius * pos;
    gl_Position = vec4(pos.x, pos.y, 0.0, 1.0);
}
