#version 330 core
layout (location = 0) in vec3 vert_pos;

uniform mat4 model_matrix;
uniform mat4 shadowmap_matrix;

void main() {
  gl_Position = shadowmap_matrix * model_matrix * vec4(vert_pos, 1.0);
  // gl_Position = projection_matrix * view_matrix * model_matrix * vec4(vert_pos, 1.0);
}
