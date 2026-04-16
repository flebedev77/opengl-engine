#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D ssao_texture;
uniform sampler2D depth_texture;
uniform sampler2D volumetrics_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

uniform vec3 light_pos;

#define near 0.001
#define far  1000
#define fov 80
#define num_samples 200

vec3 RRTAndODTFit(vec3 v) {
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 ACES_ToneMap(vec3 color) {
    vec3 x = RRTAndODTFit(color);
    x = clamp(x, 0.0, 1.0);

    vec3 srgb = mix(12.92 * x, 1.055 * pow(x, vec3(1.0/2.4)) - 0.055, step(0.0031308, x));
    return x;
}

float linearize_depth(float depth) {
  return (near * far) / (far - depth * (far - near));
}

void main() {
  float depth = texture(depth_texture, frag_uv).r;
  frag_color = texture(screen_texture, frag_uv);
  vec4 volumetrics = texture(volumetrics_texture, frag_uv);
  // frag_color *= 1-volumetrics.a;
  // frag_color += vec4(volumetrics.rgb, 0);
  frag_color *= 1-texture(ssao_texture, frag_uv).r;
  frag_color = mix(frag_color, vec4(volumetrics.rgb, 0), volumetrics.a);
  // frag_color += volumetrics;
  frag_color = vec4(ACES_ToneMap(frag_color.xyz * 1), 1);
}
