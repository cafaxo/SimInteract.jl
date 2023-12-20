#version 330 core

const vec2 positions[4] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0,  1.0)
);

layout(location = 0) in vec2 center;
layout(location = 1) in vec2 radius;
layout(location = 2) in int char_index;

out vec2 texture_coords;

void main() {
    vec2 pos = positions[gl_VertexID];

    texture_coords = vec2(((char_index * 8) + ((pos[0] + 1) / 2) * 8) / 760, (pos[1] + 1) / 2);

    pos = center + radius * pos;
    gl_Position = vec4(pos.x, pos.y, 0.0, 1.0);
}
