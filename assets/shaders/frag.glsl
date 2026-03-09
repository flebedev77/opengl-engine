#version 330 core
in vec2 frag_uv;
in vec3 frag_pos;
in vec3 frag_normal;
in vec4 frag_pos_lightspace;

out vec4 frag_color;

uniform sampler2D albedo_texture;
uniform sampler2D shadowmap_texture;
uniform vec3 tint;
uniform vec3 camera_pos;
uniform vec3 light_pos;

const float PI = 3.141592653589793;
const float shadow_pcf_border_exponent = 6; // Helps make the transition between nonshadow and shadow more natural and non linear
const float shadow_pcf_noisiness = 0.2;
const int shadow_pcf_samples = 2;

const vec2 poisson_offsets[16] = vec2[](
    vec2(0.00087641, -0.63862264), 
    vec2(-0.13883482, 0.45381424), 
    vec2(0.06422021, -0.18769506), 
    vec2(-0.57479477, -0.25208041), 
    vec2(-0.14291742, -0.86147839), 
    vec2(-0.36587161, -0.47558826), 
    vec2(0.34885627, 0.82500464), 
    vec2(0.69631511, -0.55897927), 
    vec2(-0.58133727, 0.72104436), 
    vec2(0.64826161, 0.28402969), 
    vec2(-0.86492872, 0.07038971), 
    vec2(0.42102033, 0.30327117), 
    vec2(0.11165676, 0.87970036), 
    vec2(-0.77341479, -0.35967383), 
    vec2(-0.36183363, -0.56892765), 
    vec2(0.17042206, -0.71032268) 
);

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float calculate_shadow(vec4 light_space_pos, vec3 light_dir) {
  vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
  proj_coords = proj_coords * 0.5 + 0.5;

  if (proj_coords.z >= 1.0) return 0.0;

  float max_bias = 0.0002;
  float min_bias = 0.0001;
  // float max_bias = 0.05;
  // float min_bias = 0.01;
  float bias = max(max_bias * (1.0 - dot(frag_normal, light_dir)), min_bias);  


  float closest_depth = texture(shadowmap_texture, proj_coords.xy).r;
  float pixel_depth = proj_coords.z;

  if (closest_depth < pixel_depth - bias) {
    vec2 texel_size = 1.0 / textureSize(shadowmap_texture, 0);// + 0.0001;
    float shadow = 0.0;

    // Box sampling
    // for (int x = -shadow_pcf_samples; x <= shadow_pcf_samples; x++) {
    //   for (int y = -shadow_pcf_samples; y <= shadow_pcf_samples; y++) {
    //     vec2 noise_offset = vec2( // NOTE: This could be stored into a texture to avoid redundant calculations
    //       rand(vec2(x, y)) * 2.0 - 1.0,
    //       rand(frag_pos.xy) * 2.0 - 1.0
    //     ) * shadow_pcf_noisiness;
    //     vec2 sample_pos = (noise_offset + vec2(x, y)) * texel_size;
    //     float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
    //     shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
    //   }
    // }
    // shadow /= pow(shadow_pcf_samples * 2.0 + 1.0, 2.0);

    // Nvidia hardware accelerated sampling https://developer.nvidia.com/gpugems/gpugems/part-ii-lighting-and-shadows/chapter-11-shadow-map-antialiasing
    // for (float x = -1.5; x <= 1.5; x++) {
    //   for (float y = -1.5; y <= 1.5; y++) {
    //     vec2 sample_pos = vec2(x, y) * texel_size;
    //     float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
    //     shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
    //   }
    // }
    // shadow /= 16;

    // Circular sampling
    // float circle_sample_step = 0.1;
    // float samples = 0;
    // for (int radius = 0; radius < 1; radius++) {
    //   for (float theta = 0; theta < 2 * PI; theta += circle_sample_step) {
    //     samples++;
    //     vec2 noise_offset = vec2(
    //         rand(vec2(radius, theta)) * 2.0 - 1.0,
    //         rand(frag_pos.xy) * 2.0 - 1.0
    //     ) * shadow_pcf_noisiness;
    //
    //     vec2 sample_pos = vec2(cos(theta + noise_offset.x), sin(theta + noise_offset.y)) * (noise_offset.x + radius) * texel_size;
    //     float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
    //     shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
    //   }
    // }
    //
    // shadow /= samples;

    // Poisson sampling
    for (int i = 0; i < 16; i++) {
        vec2 noise_offset = vec2(
            rand(vec2(i, frag_pos.z)) * 2.0 - 1.0,
            rand(frag_pos.xy) * 2.0 - 1.0
        ) * shadow_pcf_noisiness;
        vec2 sample_pos = (poisson_offsets[i] + noise_offset) * texel_size;
        float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
        shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
    }
    shadow /= 16;

    // shadow = 1;

    return shadow;
  }
  return 0.0;
}

void main() {
  vec4 textureSample = texture(albedo_texture, frag_uv);
  frag_color = textureSample * vec4(tint, 1.0);

  vec3 light_dir = normalize(- light_pos); // TODO change this to point from an actual light
  vec3 view_dir = normalize(frag_pos - camera_pos);

  float specularity = (textureSample.r) * 1.5;//step(0.99, (textureSample.r + textureSample.g + textureSample.b));
  vec3 specular_reflection_direction = reflect(-light_dir, frag_normal);
  float specular = clamp(pow(dot(view_dir, specular_reflection_direction), 50), 0.0, 1.0);
  specular *= clamp(specularity, 0, 1.0);

  float diffuse = clamp(dot(light_dir, -frag_normal), 0, 1) * 0.5;

  vec4 ambient = vec4(0.2 * vec3(0.094, 0.345, 0.729), 1.0); // NOTE multiplying by the color of the sky, make sure it always corresponds
  float shadow_darkness = 0.9;
  // frag_color += ambient;
  
  float shadow = calculate_shadow(frag_pos_lightspace, light_dir);
  shadow = clamp(pow(shadow, shadow_pcf_border_exponent), 0, 1);
  float inv_shadow = 1 - shadow;
  // frag_color = mix(frag_color, frag_color * shadow_ambient, clamp(pow(shadow, shadow_pcf_border_exponent), 0.0, 1.0));
  frag_color *= (diffuse * inv_shadow + ambient + specular * inv_shadow) * ((1 + shadow_darkness) - shadow);
}
