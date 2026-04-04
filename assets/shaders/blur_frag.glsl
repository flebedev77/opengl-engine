#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D normal_texture;
uniform sampler2D depth_texture;
uniform sampler2D blur_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;

uniform int blur_size;

// const int blur_size = 4;

// Simple box blur
void main() {
  // Transforms from [0 to 1920, 0 to 1080] to [0 to 1, 0 to 1]
  vec2 res_to_unit = 1 / vec2(textureSize(blur_texture, 0));
  float result = 0;
  for (int x = -blur_size; x < blur_size; x++) {
    for (int y = -blur_size; y < blur_size; y++) {
      vec2 sample_pos = vec2(float(x), float(y)) * res_to_unit;
      result += texture(blur_texture, frag_uv + sample_pos).r;
    }
  }
  frag_color = vec4(result / ((blur_size * 2) * (blur_size * 2)));
  // frag_color = texture(blur_texture, frag_uv).r;
}
