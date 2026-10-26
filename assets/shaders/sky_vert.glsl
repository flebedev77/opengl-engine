#version 330 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec3 vert_normal;
layout (location = 2) in vec2 vert_uv;

uniform mat4 model_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;
uniform int frame_number;

out vec3 frag_pos;
out vec3 frag_normal;

const float PI = 3.141592653589793;

void main() {
  frag_normal = vert_normal;
  frag_pos = vert_pos;//vec3(model_matrix * vec4(vert_pos, 0));

  mat4 view_no_translation = mat4(mat3(view_matrix));
  // float theta = 2*PI * (float(frame_number) / 60) / (60*60);
  // mat4 rot_mat = mat4(
  //   1, 0, 0, 0,
  //   0, cos(theta), -sin(theta), 0,
  //   0, sin(theta), cos(theta), 0,
  //   0, 0, 0, 1
  // );
  gl_Position = projection_matrix * view_no_translation * model_matrix * vec4(vert_pos, 1);
}
