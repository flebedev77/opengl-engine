#version 330 core

in vec2 frag_uv;
layout (location = 0) out float frag_color;
layout (location = 1) out vec2 motion_vector;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;
uniform sampler2D shadowmap_texture;
uniform sampler2D macroshadowmap_texture;
uniform sampler2D blue_noise_texture;

uniform sampler3D base_cloud_noise;
uniform sampler3D detail_cloud_noise;

uniform vec2 resolution;

uniform mat4 prev_projection_matrix;
uniform mat4 prev_view_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

uniform mat4 inv_projection_matrix;
uniform mat4 inv_view_matrix;

uniform mat4 shadowmap_matrix;
uniform mat4 macroshadowmap_matrix;
uniform mat4 inv_macroshadowmap_matrix;

uniform vec3 light_pos;

uniform int frame_number;

uniform float cloud_dome_radius;

const float cloud_layer_thickness = 1600;//(186-10);
const float cloud_height_base = 1000;
float cloud_height_apex = cloud_height_base+cloud_layer_thickness;
// const float cloud_dome_radius = 1000000;
vec3 cloud_dome_position = vec3(0, -(cloud_dome_radius-cloud_height_base), 0);
float actual_cloud_height_base = cloud_dome_radius;
float actual_cloud_height_apex = cloud_dome_radius + cloud_layer_thickness;
const float cloud_minimum_height = -3500;

const float esm_k = 140;

ivec3 base_cloud_noise_size = ivec3(128*6, 16, 128*6);

#define CLOUD_DENSITY 1.5
#define CLOUD_STEP_LENGTH 55.5

const float PI = 3.141592653589793;

vec3 project_position(vec3 p, mat4 proj_view) {
  vec4 v = proj_view * vec4(p, 1);
  return v.xyz / v.w;
}

vec2 snoise(vec3 v){ return texture(base_cloud_noise, v).rg; }
float dnoise(vec3 p) { return texture(detail_cloud_noise, p).r; }

float get_height_mask(float y, float layerMin, float layerMax, float feather) {
    float bottomFade = smoothstep(layerMin, layerMin + feather, y);
    float topFade = 1.0 - smoothstep(layerMax - feather, layerMax, y);
    return bottomFade * topFade;
}

vec2 sample_cloud_density(vec3 p) {
  // float y = length(cloud_dome_position-p) - cloud_height_base;
  float y = p.y - cloud_height_base;// - 100;

  float cloud_drift = float(frame_number) * 0.2 + 1e5;
  p.x += cloud_drift;
  p.z += cloud_drift * 0.32;
  float width_to_height = base_cloud_noise_size.x / base_cloud_noise_size.y;
  float depth_to_height = base_cloud_noise_size.z / base_cloud_noise_size.y;
  vec3 base_p = vec3(
      p.x / (cloud_layer_thickness * width_to_height),
      y / cloud_layer_thickness,
      p.z / (cloud_layer_thickness * depth_to_height)
    );

  vec2 n = snoise(base_p);

  float sdf_step_length = 0;

  if (n.g > 0) {
    float max_dist = abs(n.g) * length(vec3(base_cloud_noise_size));
    float cell_size = cloud_layer_thickness / float(base_cloud_noise_size.y); 

    sdf_step_length = max(max_dist * cell_size, 0);
  }
  if (n.r > 0) {
    vec3 detail_p = vec3(p.x, y, p.z) / cloud_layer_thickness;
    detail_p += vec3(cloud_drift, -cloud_drift * 0.3, cloud_drift) * (1/cloud_layer_thickness);

    float d = pow(dnoise(detail_p * 0.9), 1) * 1.4;
    d += dnoise(detail_p * 1.5) * 1.6;
    // d += (dnoise(detail_p * 1.8)) * 2.4;
    d += dnoise(detail_p * 3.5) * 0.9;

    n.r = clamp(n.r-d*0.14, 0, 1);
    n.r *= get_height_mask(y, 0, cloud_layer_thickness, 100);
    // n.r *= 0.18;
    // n.r *= 0.08;
    // n.r += 1.001;
  }

  return vec2(n.r * CLOUD_DENSITY, sdf_step_length);
}

vec2 ray_sphere(vec3 ro, vec3 rd, float sr, vec3 sp) {
    vec3 L = ro - sp;
    float a = dot(rd, rd); 
    float b = 2.0 * dot(rd, L);
    float c = dot(L, L) - (sr * sr);
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) return vec2(-1);
    float sqrtD = sqrt(discriminant);
    float t0 = (-b - sqrtD) / (2.0 * a);
    float t1 = (-b + sqrtD) / (2.0 * a);

    return vec2(t0, t1);
}


float calculate_esm() {
  base_cloud_noise_size = textureSize(base_cloud_noise, 0);

    float depth = texture(macroshadowmap_texture, frag_uv).r;

    vec4 clip_space = vec4(frag_uv * 2.0 - 1.0, depth, 1.0);
    vec4 world_space_pixel = inv_macroshadowmap_matrix * clip_space;
    world_space_pixel /= world_space_pixel.w;

    vec3 ray_origin = project_position(
        vec3(frag_uv * 2 - 1, 0),
        inv_macroshadowmap_matrix
    );

    vec3 ray_dir = world_space_pixel.xyz - ray_origin;
    float ray_length = length(ray_dir);
    ray_dir = normalize(ray_dir);

    vec2 A = ray_sphere(ray_origin, ray_dir, cloud_dome_radius + cloud_layer_thickness, cloud_dome_position);
    vec2 B = ray_sphere(ray_origin, ray_dir, cloud_dome_radius, cloud_dome_position);

    float t_in = -1.0;
    float t_out = -1.0;

    if (A.y >= 0.0) { 
      if (B.x < 0.0 && B.y < 0.0) {
        t_in = max(0.0, A.x);
        t_out = A.y;
      } else {
        if (B.x > 0.0) {
          t_in = max(0.0, A.x);
          t_out = B.x;
        } else if (A.y > 0.0) {
          t_in = max(0.0, B.y);
          t_out = A.y;
        }
      }
    }

    if (t_in >= 0 && t_out > 0.0) {
      t_in = max(t_in, 0.0);
      t_out = min(t_out, ray_length);

      if (t_in < t_out) {

        float cloud_march_length = t_out - t_in;

        vec3 start_pos = ray_origin + ray_dir * t_in;

        vec3 current_pos = start_pos;

        float distance_travelled = 0;
        float step_length = CLOUD_STEP_LENGTH;

        for (int i = 0; i < 16; i++) {
          if (distance_travelled >= cloud_march_length) break;

          current_pos = start_pos + ray_dir * distance_travelled;
          vec2 current_cloud_data = sample_cloud_density(current_pos);
          float current_density = current_cloud_data.x;
          float current_sdf = current_cloud_data.y;

          float cell_size = cloud_layer_thickness / float(base_cloud_noise_size.y);

          float k = 50.1;
          if (current_density <= 0.0 && current_sdf >= 0) {
            distance_travelled += current_sdf;
            if (current_sdf < k) {
              distance_travelled += cell_size;//CLOUD_STEP_LENGTH;
            }
            continue;
          } 

          if (current_density > 0) {
            vec3 proj_p = project_position(current_pos, macroshadowmap_matrix);
            // return proj_p.z;
            return exp(esm_k * proj_p.z);
            // float dist = distance_travelled + t_in;
            // vec3 proj_dist = project_position(vec3(0, 0, dist), macroshadowmap_matrix);
            // return proj_dist.z;
            // return exp(esm_k * proj_dist.z);
          }


          distance_travelled += step_length;
        }



      }}

    vec4 light_clip = macroshadowmap_matrix * vec4(world_space_pixel.xyz, 1.0);
    float normalized_depth = light_clip.z / light_clip.w;

    // return normalized_depth;
    return exp(esm_k * normalized_depth);


    return ray_length;
    float dist = ray_length;
    vec3 proj_dist = project_position(vec3(0, 0, dist), macroshadowmap_matrix);
    return proj_dist.z;
    return exp(esm_k * proj_dist.z);

    // return exp(k * z);
}

void main() {
  frag_color = calculate_esm();
}
