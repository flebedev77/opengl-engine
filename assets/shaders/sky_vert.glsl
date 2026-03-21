#version 330 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec3 vert_normal;
layout (location = 2) in vec2 vert_uv;

uniform mat4 model_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

out vec3 frag_pos;
out vec3 frag_normal;

void main() {
  frag_normal = vert_normal;
  frag_pos = vec3(model_matrix * vec4(vert_pos, 1));

  mat4 view_no_translation = mat4(mat3(view_matrix));
  gl_Position = projection_matrix * view_no_translation * model_matrix * vec4(vert_pos, 1);
}
