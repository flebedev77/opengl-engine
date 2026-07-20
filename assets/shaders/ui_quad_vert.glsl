#version 330 core
out vec2 frag_uv;

uniform vec2 quad_position;
uniform vec2 quad_size;

void main() {
  vec2 pos = vec2(
      gl_VertexID & 1,
      (gl_VertexID >> 1) & 1
  );

  frag_uv = vec2(pos.x, 1-pos.y);
  pos *= quad_size;
  pos += quad_position;
  gl_Position = vec4(pos.xy, 0, 1);
}
