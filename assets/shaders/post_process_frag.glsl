#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

void main() {
  frag_color = vec4(frag_uv.xy, 1, 1);
}
