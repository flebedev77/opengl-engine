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
out vec3 frag_normal;
out vec3 frag_vert_color;
out vec4 frag_pos_viewspace;
out vec3 frag_pos_ndc;

void main() {
  frag_uv = vert_uv;
  frag_vert_color = vert_color;

  // NOTE calculating the normal matrix on the shader is expensive, should pass it as a uniform?
  frag_normal = normalize(mat3(transpose(inverse(model_matrix))) * vert_normal);
  frag_pos_viewspace = view_matrix * model_matrix * vec4(vert_pos, 1); 
  gl_Position = projection_matrix * frag_pos_viewspace;
  frag_pos_ndc = gl_Position.xyz / gl_Position.w;
}
