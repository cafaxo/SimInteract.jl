#version 330 core

uniform samplerBuffer plot_data;

in vec2 pos_frag;
flat in int data_offset_frag;
flat in int data_size_frag;

out vec4 FragColor;

void main() {
    int idx = int(floor(data_size_frag * pos_frag.x));
    int idx_clamped = clamp(idx, 0, data_size_frag - 1);
    float value = texelFetch(plot_data, data_offset_frag + idx_clamped).r;

    float t = step(pos_frag.y, value);
    //float t = clamp(68*value + 1/2 - 68*pos_frag.y, 0.0, 1.0);

    FragColor = mix(vec4(1.0, 1.0, 1.0, 0.4), vec4(1.0, 1.0, 1.0, 1.0), t);
}
