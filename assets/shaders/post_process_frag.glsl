#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D ssao_texture;
uniform sampler2D depth_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;

vec3 RRTAndODTFit(vec3 v) {
    // Narkowicz fit for RRT+ODT (common approximation)
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return a / b;
}

vec3 ACES_ToneMap(vec3 color) {
    // Input: linear HDR color (scene linear)
    // 1) Input color primaries -> ACES AP1 (skip if already scene linear close to ACES)
    //    For most uses you can skip chromatic transform and apply fit directly.

    // 2) Apply RRT+ODT fit
    vec3 x = RRTAndODTFit(color);

    // 3) Clamp to [0,1]
    x = clamp(x, 0.0, 1.0);

    // 4) Optional gamma (sRGB) conversion
    // return pow(x, vec3(1.0/2.2)); // simple gamma
    // Better: convert to sRGB
    // vec3 srgb = mix(12.92 * x, 1.055 * pow(x, vec3(1.0/2.4)) - 0.055, step(0.0031308, x));
    return x;
}

void main() {
  frag_color = texture(screen_texture, frag_uv);
  frag_color *= 1-texture(ssao_texture, frag_uv).r;
  frag_color = vec4(ACES_ToneMap(frag_color.xyz * 1.5), 1);
  // frag_color = vec4(1-texture(ssao_texture, frag_uv).r);
}
