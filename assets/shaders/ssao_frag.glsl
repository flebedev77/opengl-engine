#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D normal_texture;
uniform sampler2D depth_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;

#define near 0.001
#define far  1000
#define fov 80

const int ssao_samples = 16;
const float ssao_radius = 0.09;
const vec3 ssao_kernel[16] = vec3[](
vec3(-0.04233161, -0.05540308, 0.02089313), 
vec3(-0.12190412, -0.03275195, 0.06935520), 
vec3(0.10153740, 0.16059195, 0.08045760), 
vec3(-0.08224130, 0.13116065, 0.08399715), 
vec3(-0.05324854, -0.16949840, 0.07517876), 
vec3(0.09087562, 0.08719978, 0.29224500), 
vec3(0.05954992, -0.06371912, 0.39193946), 
vec3(-0.07470153, -0.24163184, 0.52468365), 
vec3(-0.18377243, 0.13911666, 0.36702201), 
vec3(-0.60713315, -0.07308862, 0.55732340), 
vec3(0.44214863, 0.22550254, 0.30008397), 
vec3(0.16069496, 0.79795063, 0.66617256), 
vec3(0.38086373, -0.52546883, 0.35289249), 
vec3(-0.77908462, 0.09631390, 0.91710919), 
vec3(-1.05362737, -1.39647508, 1.30597067), 
vec3(1.32803941, 1.29210591, 1.43839204)
);

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float linearize_depth(float depth) {
  return (near * far) / (far - depth * (far - near));
}

vec3 reconstruct_position(vec2 uv, float depth) {
  vec2 ndc = uv * 2 - 1;
  // float depth = texture(depth_texture, frag_uv).r;
  vec4 clip = vec4(ndc.x, ndc.y, depth * 2 - 1, 1);
  vec4 view = inv_projection_matrix * clip;
  return view.xyz / view.w;
}

float ssao() {
  float occlusion = 0.0;

  vec3 normal = normalize(texture(normal_texture, frag_uv).xyz);
  vec3 position = reconstruct_position(frag_uv, texture(depth_texture, frag_uv).r);

  vec3 random_vec = vec3(
    rand(frag_uv + position.xy + normal.yx) * 2 - 1,
    rand(frag_uv*2 + position.zx + normal.xz) * 2 - 1,
    rand(frag_uv*3 + position.yz + normal.zy) * 2 - 1
  );
  vec3 tangent = normalize(random_vec - normal * dot(random_vec, normal));
  vec3 bitangent = cross(normal, tangent);
  mat3 tbn = mat3(tangent, bitangent, normal);

  for (int i = 0; i < ssao_samples; i++) {
    vec3 sample_pos = tbn * ssao_kernel[i];
    sample_pos = position + sample_pos * ssao_radius;

    vec4 screen_space_sample_pos = projection_matrix * vec4(sample_pos, 1);
    screen_space_sample_pos.xyz /= screen_space_sample_pos.w;
    vec3 uv_sample_pos = (screen_space_sample_pos.xyz + 1) / 2;

    vec3 occuluder_pos = reconstruct_position(uv_sample_pos.xy, texture(depth_texture, uv_sample_pos.xy).r);

    if (occuluder_pos.z > sample_pos.z) {
      occlusion += smoothstep(0, 1, ssao_radius / abs(occuluder_pos.z - sample_pos.z));
    }
  }

  occlusion /= ssao_samples;
  
  return occlusion * 1.1;
}

void main() {
  frag_color = vec4(ssao());
}
