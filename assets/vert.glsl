#version 330 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec3 vert_normal;
layout (location = 2) in vec2 vert_uv;

uniform mat4 model_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

out vec2 frag_uv;
out vec3 frag_pos;
out vec3 frag_normal;

void main() {
  frag_uv = vert_uv;
  // NOTE calculating the normal matrix on the shader is expensive, should pass it as a uniform?
  frag_normal = mat3(transpose(inverse(model_matrix))) * vert_normal;
  frag_pos = vec3(model_matrix * vec4(vert_pos, 1.0));
  gl_Position = projection_matrix * view_matrix * model_matrix * vec4(vert_pos, 1.0);
  // gl_Position = vec4((gl_VertexID >> 1) & 1, gl_VertexID & 1, 1.0, 1.0);
}
