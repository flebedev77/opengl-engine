#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec3 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D ssao_texture;
uniform sampler2D depth_texture;
uniform sampler2DArray volumetrics_texture;
uniform int volumetrics_taa_frames;
uniform int frame_number;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;


uniform vec3 light_pos;

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

void main() {
  float depth = texture(depth_texture, frag_uv).r;
  frag_color = texture(screen_texture, frag_uv).rgb;
  vec4 volumetrics = vec4(0);
  int current_volumetric_frame = frame_number % volumetrics_taa_frames;
  float weight = 1 / float(volumetrics_taa_frames);
  for (int i = 0; i < volumetrics_taa_frames; i++) {
    volumetrics += texture(volumetrics_texture, vec3(frag_uv, float(i))) * weight;
  }
  // volumetrics.a = texture(volumetrics_texture, vec3(frag_uv, current_volumetric_frame)).a;

  // frag_color *= 1-volumetrics.a;
  // frag_color += vec4(volumetrics.rgb, 0);
  frag_color *= 1-texture(ssao_texture, frag_uv).r;
  // frag_color = mix(frag_color, vec4(volumetrics.rgb, 0), volumetrics.a);
  frag_color = volumetrics.rgb + frag_color * volumetrics.a;

  // frag_color += volumetrics;
  // frag_color = ACES_ToneMap(frag_color.xyz);
}
