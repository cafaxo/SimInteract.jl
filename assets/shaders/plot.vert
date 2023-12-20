#version 330 core

const vec2 positions[4] = vec2[](
    vec2(-1.0, -1.0),
    vec2( 1.0, -1.0),
    vec2( 1.0,  1.0),
    vec2(-1.0,  1.0)
);

layout(location = 0) in vec2 center;
layout(location = 1) in vec2 radius;
layout(location = 2) in int data_offset;
layout(location = 3) in int data_size;

out vec2 pos_frag;
flat out int data_offset_frag;
flat out int data_size_frag;

void main() {
    data_offset_frag = data_offset;
    data_size_frag = data_size;

    vec2 pos = positions[gl_VertexID];

    pos_frag = vec2(0.5*(pos.x + 1.0), pos.y);

    pos = center + radius * pos;
    gl_Position = vec4(pos.x, pos.y, 0.0, 1.0);
}
