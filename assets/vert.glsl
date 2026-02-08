#version 330 core
layout (location = 0) in vec2 vert_pos;

uniform mat4 model_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

out vec2 uv;

void main() {
  uv = vert_pos;
  gl_Position = projection_matrix * view_matrix * model_matrix * vec4(vert_pos, 0.0, 1.0);
  // gl_Position = vec4((gl_VertexID >> 1) & 1, gl_VertexID & 1, 1.0, 1.0);
}
