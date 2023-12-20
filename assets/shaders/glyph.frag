#version 330 core

uniform sampler2D font_texture;

in vec2 texture_coords;
out vec4 FragColor;

void main() {
    FragColor = vec4(1.0, 1.0, 1.0, texture(font_texture, texture_coords).r);
}
