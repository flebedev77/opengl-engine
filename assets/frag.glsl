#version 330 core
in vec2 uv;
out vec4 frag_color;

uniform sampler2D tex;
uniform vec3 tint;

void main() {
  // frag_color = vec4(uv.x, 1.0, uv.y, 1.0);
  frag_color = texture(tex, uv);
  if (frag_color.r < 0.9) {
    frag_color = vec4(tint, 1.0);
  }
}
