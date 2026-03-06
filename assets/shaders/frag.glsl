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

float shadow_pcf_border_exponent = 4.0; // Helps make the transition between nonshadow and shadow more natural and non linear
float shadow_pcf_noisiness = 0.1;
int shadow_pcf_samples = 5;

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float calculate_shadow(vec4 light_space_pos, vec3 light_dir) {
  vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
  proj_coords = proj_coords * 0.5 + 0.5;

  if (proj_coords.z >= 1.0) return 0.0;

  float max_bias = 0.0005;
  float min_bias = 0.0001;
  float bias = max(max_bias * (1.0 - dot(frag_normal, light_dir)), min_bias);  


  float closest_depth = texture(shadowmap_texture, proj_coords.xy).r;
  float pixel_depth = proj_coords.z;

  if (closest_depth < pixel_depth - bias) {
    vec2 texel_size = 1.0 / textureSize(shadowmap_texture, 0);
    float shadow = 0.0;

    // NOTE(flebedev99): Could be factored to hardware multisampling for performance
    for (int x = -shadow_pcf_samples; x <= shadow_pcf_samples; x++) {
      for (int y = -shadow_pcf_samples; y <= shadow_pcf_samples; y++) {
        vec2 noise_offset = vec2( // NOTE(flebedev99): This could be stored into a texture to avoid redundant calculations
          rand(vec2(x, y)) * 2.0 - 1.0,
          rand(frag_pos.xy) * 2.0 - 1.0
        ) * shadow_pcf_noisiness;
        vec2 sample_pos = (noise_offset + vec2(x, y)) * texel_size;
        float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
        shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
      }
    }
    shadow /= pow(shadow_pcf_samples * 2.0 + 1.0, 2.0);

    return shadow;
  }
  return 0.0;
}

void main() {
  vec4 textureSample = texture(albedo_texture, frag_uv);
  frag_color = textureSample * vec4(tint, 1.0);
  // frag_color.a = 1.0;
  //if (frag_color.r < 0.5) {
  // if (frag_color.r < 1.0) {
  //   frag_color = vec4(tint, 1.0);
  // }
  // frag_color = vec4(abs(frag_pos), 1.0);
  vec3 light_dir = normalize(frag_pos - light_pos); // TODO change this to point from an actual light
  vec3 view_dir = normalize(frag_pos - camera_pos);

  float specularity = (textureSample.r) * 1.5;//step(0.99, (textureSample.r + textureSample.g + textureSample.b));
  vec3 specular_reflection_direction = reflect(-light_dir, frag_normal);
  float specular = clamp(pow(dot(view_dir, specular_reflection_direction), 50.0), 0.0, 1.0);
  specular *= clamp(specularity, 0.0, 1.0);

  float diffuse = clamp(dot(light_dir, -frag_normal), 0.0, 1.0) * 0.5;

  float ambient = 0.1;
  frag_color += ambient;
  
  float shadow = calculate_shadow(frag_pos_lightspace, light_dir);
  frag_color = mix(frag_color, frag_color * vec4(0.1, 0.1, 0.12, 1.0), clamp(pow(shadow, shadow_pcf_border_exponent), 0.0, 1.0));
  frag_color *= (diffuse + ambient + specular * (1.0 - shadow));
}
