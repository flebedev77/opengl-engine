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

float calculate_shadow(vec4 light_space_pos, vec3 light_dir) {
  vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
  proj_coords = proj_coords * 0.5 + 0.5;

  float visible_depth = texture(shadowmap_texture, proj_coords.xy).r;
  float current_depth = proj_coords.z;

  float max_bias = 0.005;
  float min_bias = 0.001;
  float bias = max(max_bias * (1.0 - dot(frag_normal, light_dir)), min_bias);  

  return (visible_depth < current_depth - bias) ? 1.0 : 0.0;
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

  float specularity = (1.0 - textureSample.r) * 1.5;//step(0.99, (textureSample.r + textureSample.g + textureSample.b));
  vec3 specular_reflection_direction = reflect(-light_dir, frag_normal);
  float specular = clamp(pow(dot(view_dir, specular_reflection_direction), 50.0), 0.0, 1.0);
  specular *= clamp(specularity, 0.0, 1.0);

  float diffuse = clamp(dot(light_dir, -frag_normal), 0.0, 1.0) * 0.5;

  float ambient = 0.1;
  frag_color += ambient;
  
  float shadow = calculate_shadow(frag_pos_lightspace, light_dir);
  frag_color = mix(frag_color, frag_color * vec4(0.1, 0.1, 0.12, 1.0), shadow);
  frag_color *= (diffuse + ambient + specular * (1.0 - shadow));
}
