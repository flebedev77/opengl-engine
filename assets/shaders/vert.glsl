#version 330 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec3 vert_normal;
layout (location = 2) in vec2 vert_uv;
layout (location = 3) in vec3 vert_color;

uniform mat4 model_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;
uniform mat4 shadowmap_matrix;

out vec2 frag_uv;
out vec3 frag_pos;
out vec3 frag_normal;
out vec4 frag_pos_lightspace;
out vec3 frag_vert_color;

void main() {
  frag_uv = vert_uv;
  frag_vert_color = vert_color;
  if (vert_color == vec3(0)) frag_vert_color = vec3(1);
  // NOTE calculating the normal matrix on the shader is expensive, should pass it as a uniform?
  frag_normal = normalize(mat3(transpose(inverse(model_matrix))) * vert_normal);
  frag_pos = vec3(model_matrix * vec4(vert_pos, 1.0));
  frag_pos_lightspace = shadowmap_matrix * model_matrix * vec4(vert_pos, 1.0);
  gl_Position = projection_matrix * view_matrix * model_matrix * vec4(vert_pos, 1.0);
  // gl_Position = vec4((gl_VertexID >> 1) & 1, gl_VertexID & 1, 1.0, 1.0);
}
