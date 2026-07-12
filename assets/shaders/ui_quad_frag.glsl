#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform vec2 quad_position;
uniform vec2 quad_size;
uniform vec4 quad_color;
uniform float quad_char_weight;
uniform vec4 uv;

uniform sampler2D msdf_font_texture;
uniform bool is_char;

float median(vec3 v) {
    return max(min(v.r, v.g), min(max(v.r, v.g), v.b));
}

void main() {
  frag_color = quad_color;
  if (is_char) {
  // frag_color = texture(msdf_font_texture, frag_uv * uv.zw + uv.xy);
    float sig_dist = median(texture(msdf_font_texture, frag_uv * uv.zw + uv.xy).rgb) - quad_char_weight;
    frag_color.a *= clamp(sig_dist / fwidth(sig_dist) + quad_char_weight, 0.0, 1.0);
  }
}
