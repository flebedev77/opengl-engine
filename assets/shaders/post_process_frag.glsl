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

    // vec3 srgb = mix(12.92 * x, 1.055 * pow(x, vec3(1.0/2.4)) - 0.055, step(0.0031308, x));
    return x;
}

float linearize_depth(float depth) {
  return (near * far) / (far - depth * (far - near));
}

void main() {
  frag_color = texture(screen_texture, frag_uv);
  frag_color *= 1-texture(ssao_texture, frag_uv).r;
  frag_color = texture(volumetrics_texture, frag_uv);
  // frag_color = vec4(ACES_ToneMap(frag_color.xyz * 1), 1);
  // frag_color = vec4(1-texture(ssao_texture, frag_uv).r);
  // frag_color = vec4(linearize_depth(texture(depth_texture, frag_uv).r));
  // return;

// vec4 screen_space_sun_pos = projection_matrix * view_matrix * vec4(light_pos, 1.0);
//
// // // 1. Prevent reverse god-rays when the sun is behind the camera
// // if (screen_space_sun_pos.w <= 0.0) {
// //     // Sun is behind us, no rays should be visible
// //     return; // Or just ensure sun_ray remains 0 depending on your shader structure
// // }
//
// // 2. Perspective divide and NDC to UV space [0, 1]
// vec2 sun_uv = screen_space_sun_pos.xy / screen_space_sun_pos.w;
// sun_uv = sun_uv * 0.5 + 0.5;
//
// // Density controls how far the rays stretch across the screen. 
// // Without it, the rays always stretch exactly to the sun coordinate.
// float density = 1.0; 
// vec2 delta_texcoord = (frag_uv - sun_uv) * (density / float(num_samples));
//
// vec2 current_coord = frag_uv;
// float illumination_decay = 1.0;
//
// // 0.1 is extremely aggressive and will kill the ray instantly. 0.95 gives a smooth fade.
// float decay_rate = 0.7; 
// float sun_ray = 0.0;
//
// for (int i = 0; i < num_samples; i++) {
//     current_coord -= delta_texcoord;
//
//     float samp = linearize_depth(texture(depth_texture, current_coord).r);
//
//     if (samp < 100) {
//       break;
//     }
//     sun_ray += (1.0 / float(num_samples)) * illumination_decay;
//
//     // illumination_decay *= decay_rate / f;
// }
//
// // Add the scattered light to your fragment color
// frag_color -= (1 - vec4(sun_ray, sun_ray, sun_ray, 0.0)) * 0.1;
}
