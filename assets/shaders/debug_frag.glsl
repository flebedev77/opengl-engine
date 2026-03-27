#version 330 core
out vec4 out_frag_color;

in vec3 frag_vert_color;

void main() {
  out_frag_color = vec4(frag_vert_color, 1);
}
