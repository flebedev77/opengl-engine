#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D normal_texture;
uniform sampler2D depth_texture;
uniform sampler2D shadowmap_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;
uniform mat4 shadowmap_matrix;

uniform vec3 light_pos;

#define near 0.001
#define far  1000
#define fov 80
#define step_size 0.5

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float linearize_depth(float depth) {
  return (near * far) / (far - depth * (far - near));
}

vec3 reconstruct_position(vec2 uv, float depth) {
  vec2 ndc = uv * 2 - 1;
  // float depth = texture(depth_texture, frag_uv).r;
  vec4 clip = vec4(ndc.x, ndc.y, depth, 1);
  vec4 view = inv_projection_matrix * clip;
  return view.xyz / view.w;
}

// TODO: Optimise out to the cpu
vec3 world_space_to_view_space(vec3 world) {
  return (view_matrix * vec4(world, 1)).xyz;
}

float crepuscular_rays() {
  float sun_ray = 0.0;
  float non_linear_depth = texture(depth_texture, frag_uv).r;
  vec3 view_space_sun = world_space_to_view_space(light_pos); 
  vec3 view_space_pixel = reconstruct_position(frag_uv, non_linear_depth);

  vec4 light_space_pos = shadowmap_matrix * vec4(view_space_pixel, 1.0);
  light_space_pos.xyz /= light_space_pos.w;
  light_space_pos = light_space_pos * 0.5 + 0.5;

  return sun_ray;
}

void main() {
  // frag_color = vec4(light_pos, 1);
  // frag_color = texture(shadowmap_texture, frag_uv);
  frag_color = vec4(crepuscular_rays());
}
