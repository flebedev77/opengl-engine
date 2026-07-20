#version 330 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec3 vert_color;

uniform mat4 projection_matrix;
uniform mat4 view_matrix;

out vec3 frag_vert_color;

void main() {
  frag_vert_color = vert_color;
  gl_Position = projection_matrix * view_matrix * vec4(vert_pos, 1);
}
