#version 330 core
layout (location = 2) in vec2 vert_uv;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;

out vec2 frag_uv;

void main() {
  frag_uv = vert_uv;

  vec2 pos = vec2(
      gl_VertexID & 1,
      (gl_VertexID >> 1) & 1
  );
  gl_Position = vec4(pos.xy * 2 - 1, 0, 1);
}
