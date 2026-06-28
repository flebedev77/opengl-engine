#version 330 core
layout (location = 0) out vec4 out_frag_color;
layout (location = 1) out vec4 out_frag_normal;

in vec2 frag_uv;
in vec3 frag_normal;
in vec3 frag_vert_color;
in vec4 frag_pos_viewspace;
in vec3 frag_pos_ndc;


uniform sampler2D albedo_texture;
uniform sampler2D roughness_texture;
uniform sampler2D shadowmap_texture;
uniform sampler2D macroshadowmap_texture;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;
uniform sampler2D volumetrics_texture;

uniform vec3 tint;
uniform vec3 camera_pos;
uniform vec3 light_pos;
uniform mat4 view_matrix;
uniform mat4 projection_matrix;
uniform mat4 macroshadowmap_matrix;

uniform float roughness_strength;
uniform float metallic_strength;

uniform vec4 uv;

const float PI = 3.141592653589793;


float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 randtwo(vec2 co) {
  return vec2(rand(co), rand(co + frag_uv)) * 2 - 1;
}

float distribution_ggx(vec3 n, vec3 h, float roughness) {
    float a = roughness*roughness;
    float a2 = a*a;
    float ndoth = max(dot(n, h), 0.0);
    float ndoth2 = ndoth*ndoth;

    float nom   = a2;
    float denom = (ndoth2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / denom;
}
float geometryschlick_ggx(float ndotv, float roughness) {
    float r = (roughness + 1.0);
    float k = (r*r) / 8.0;

    float nom   = ndotv;
    float denom = ndotv * (1.0 - k) + k;

    return nom / denom;
}
float geometrysmith(vec3 n, vec3 v, vec3 l, float roughness) {
    float ndotv = max(dot(n, v), 0.0);
    float ndotl = max(dot(n, l), 0.0);
    float ggx2 = geometryschlick_ggx(ndotv, roughness);
    float ggx1 = geometryschlick_ggx(ndotl, roughness);

    return ggx1 * ggx2;
}
vec3 fresnelschlick(float costheta, vec3 f0) {
    return f0 + (1.0 - f0) * pow(clamp(1.0 - costheta, 0.0, 1.0), 5.0);
}

vec3 project_vec(vec3 v) {
  vec4 o = projection_matrix * vec4(v, 1);
  o.xyz /= o.w;
  return o.xyz;
}

vec2 ndc_to_uv(vec3 n) {
  return n.xy * 0.5 + vec2(0.5);
}

const float IOR_air = 1;
const float IOR_glass = 1.013; // Not real IOR of glass, it is small because of lacking exit refraction

void main() {
  vec3 view_normal = normalize((view_matrix * vec4(frag_normal, 0)).xyz);
  vec3 view_vec = normalize(frag_pos_viewspace.xyz);
  vec3 refracted_vec = refract(view_vec, view_normal, IOR_air/IOR_glass); 
  refracted_vec = (
      project_vec(frag_pos_viewspace.xyz + refracted_vec) - frag_pos_ndc.xyz
      ); 
  vec3 step_location = frag_pos_ndc;
  // for (int i = 0; i < 1; i++) {
    step_location += refracted_vec;
  //   break;
  //   if (abs(step_location.x) > 1 || abs(step_location.y) > 1 || abs(step_location.z) > 1) break;
  //   float depth = texture(depth_texture, ndc_to_uv(step_location)).r;
  //   if (depth < step_location.z) break;
  // }

  vec2 uv = ndc_to_uv(step_location);
  out_frag_color = texture(screen_texture, uv);
  vec4 volumetrics = texture(volumetrics_texture, uv);
  out_frag_color = vec4(volumetrics.rgb, 0) + out_frag_color * volumetrics.a;
  return;
}
