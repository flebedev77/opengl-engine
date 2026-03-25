#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D ssao_texture;
uniform sampler2D depth_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;

#define near 0.001
#define far  1000
#define fov 80

void main() {
  frag_color = texture(screen_texture, frag_uv);
  frag_color *= 1-texture(ssao_texture, frag_uv).r;
  // frag_color = vec4(1-texture(ssao_texture, frag_uv).r);
}
