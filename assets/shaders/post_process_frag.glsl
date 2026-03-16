#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D normal_texture;
uniform sampler2D depth_texture;

uniform mat4 inv_projection_matrix;

float radius = 67.2;
int samples = 16;
vec2 screen_size = vec2(1920, 1080);

#define near 0.001
#define far  1000
#define fov 80

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

float ssao() {
  float center_depth = linearize_depth(texture(depth_texture, frag_uv).r);
  vec3 center_normal = normalize(texture(normal_texture, frag_uv).rgb * 2.0 - 1.0);
  vec3 center_pos = reconstruct_position(frag_uv, texture(depth_texture, frag_uv).r);
  
  float occlusion = 0.0;
  float sample_count = float(samples);
  float bias = 0.025; // Prevent self-occlusion
  float falloff = 0.00002; // Controls occlusion falloff with distance
  
  for(int i = 0; i < samples; i++)
  {
    // Generate circular sample pattern with noise
    float angle = (2.0 * 3.14159 * float(i)) / sample_count;
    float dist = (float(i) / sample_count); // Distribute samples radially
    
    vec2 offset = vec2(cos(angle), sin(angle)) * dist * radius;
    vec2 sample_uv = frag_uv + offset / screen_size;
    
    // Clamp to texture bounds
    sample_uv = clamp(sample_uv, 0.0, 1.0);
    
    // Sample depth and normal at offset
    float sample_depth = linearize_depth(texture(depth_texture, sample_uv).r);
    vec3 sample_normal = normalize(texture(normal_texture, sample_uv).rgb * 2.0 - 1.0);
    vec3 sample_pos = reconstruct_position(sample_uv, texture(depth_texture, sample_uv).r);
    
    // Vector from center to sample
    vec3 diff = sample_pos - center_pos;
    float dist_sq = dot(diff, diff);
    float dist_len = sqrt(dist_sq);
    
    // Only consider samples within reasonable distance
    if(dist_len > bias && dist_len < radius)
    {
      // Angle-based occlusion: check if sample normal faces away from center
      float normal_angle = dot(sample_normal, -normalize(diff));
      
      // Depth-based occlusion: sample is occluding if it's in front
      float depth_diff = center_depth - sample_depth;
      
      // Crysis-style: combine normal angle and depth for better results
      if(depth_diff > bias)
      {
        // Weight by angle and distance falloff
        float angle_weight = max(0.0, normal_angle);
        float distance_weight = 1.0 - (dist_len / radius);
        float occlusion_amount = angle_weight * distance_weight * distance_weight;
        
        occlusion += occlusion_amount;
      }
    }
  }
  
  // Normalize and apply contrast
  occlusion = occlusion / sample_count;
  occlusion = pow(occlusion, 1.5); // Increase contrast
  
  float ao = 1.0 - occlusion;
  
  return ao;
}

void main() {
  frag_color = texture(screen_texture, frag_uv);
  // frag_color *= ssao();
  frag_color = vec4(ssao());
  // frag_color = texture(normal_texture, frag_uv);

  // vec2 ndc = frag_uv * 2 - 1;
  // float depth = texture(depth_texture, frag_uv).r;
  // vec4 clip = vec4(ndc.x, ndc.y, depth, 1);
  // vec4 view = inv_projection_matrix * clip;
  // view = vec4(view.xyz / view.w, 1);
  // frag_color = vec4(view.xyz, 1);
}
