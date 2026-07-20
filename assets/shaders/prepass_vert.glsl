#version 330 core
layout (location = 0) in vec3 vert_pos;
layout (location = 1) in vec3 vert_normal;

uniform mat4 model_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;
uniform mat4 shadowmap_matrix;

out vec3 frag_normal;

void main() {
  // NOTE calculating the normal matrix on the shader is expensive, should pass it as a uniform?
  frag_normal = normalize(mat3(transpose(inverse(model_matrix))) * vert_normal);
  gl_Position = projection_matrix * view_matrix * model_matrix * vec4(vert_pos, 1.0);
  // gl_Position = vec4((gl_VertexID >> 1) & 1, gl_VertexID & 1, 1.0, 1.0);
}
