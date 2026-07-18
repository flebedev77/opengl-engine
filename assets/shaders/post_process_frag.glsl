#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec3 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D ssao_texture;
uniform sampler2D depth_texture;
uniform sampler2D volumetrics_texture;
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

// Corrected B-Spline cubic weight calculation
vec4 cubic(float v) {
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0 / 6.0);
}

// Drop-in bicubic texture sampler replacement
vec4 textureBicubic(sampler2D tex, vec2 uv) {
    vec2 texSize = vec2(textureSize(tex, 0));
    vec2 texelSize = 1.0 / texSize;
    
    // Shift coordinate system to texel centers
    uv = uv * texSize - 0.5;
    vec2 fxy = fract(uv);
    uv -= fxy;
    
    // Calculate custom X and Y cubic interpolation weights
    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);
    
    vec4 c = uv.xxyy + vec4(-0.5, 1.5, -0.5, 1.5);
    
    // Smooth out components into quadrant scales
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;
    
    // FIX: Correctly scale X coordinates by Width, Y coordinates by Height
    offset *= texelSize.xxyy;
    
    // Use the GPU's native bilinear filtering hardware to gather the quadrants
    vec4 sample0 = texture(tex, offset.xz);
    vec4 sample1 = texture(tex, offset.yz);
    vec4 sample2 = texture(tex, offset.xw);
    vec4 sample3 = texture(tex, offset.yw);
    
    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);
    
    // Final smooth blending pass
    return mix(
        mix(sample3, sample2, sx),
        mix(sample1, sample0, sx), 
        sy
    );
}

void main() {
  float depth = texture(depth_texture, frag_uv).r;
  frag_color = texture(screen_texture, frag_uv).rgb;
  
  frag_color *= 1-texture(ssao_texture, frag_uv).r;

  vec4 volumetrics = textureBicubic(volumetrics_texture, frag_uv);
  // Could do a lanczos or bicubic filter here
  frag_color = volumetrics.rgb + frag_color * (volumetrics.a);

  // frag_color += volumetrics;
  // frag_color = ACES_ToneMap(frag_color.xyz);
}
