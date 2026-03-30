#version 330 core
layout (location = 0) out vec4 out_frag_color;
layout (location = 1) out vec4 out_frag_normal;

uniform mat4 view_matrix;
in vec3 frag_normal;

void main() {
  out_frag_normal = vec4(normalize((view_matrix * vec4(frag_normal, 0)).xyz), 0);
}
