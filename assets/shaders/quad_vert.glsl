#version 330 core
out vec2 frag_uv;

void main() {
  vec2 pos = vec2(
      gl_VertexID & 1,
      (gl_VertexID >> 1) & 1
  );
  frag_uv = pos;
  gl_Position = vec4(pos.xy * 2 - 1, 0, 1);
}
