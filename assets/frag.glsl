#version 330 core
in vec2 frag_uv;
in vec3 frag_pos;
in vec3 frag_normal;

out vec4 frag_color;

uniform sampler2D tex;
uniform vec3 tint;
uniform vec3 camera_pos;

void main() {
  // frag_color = vec4(uv.x, 1.0, uv.y, 1.0);
  frag_color = texture(tex, frag_uv);
  if (frag_color.r < 0.2) {
    frag_color = vec4(tint, 1.0);
  }
  // frag_color = vec4(abs(frag_pos), 1.0);
  vec3 light_dir = normalize(frag_pos - camera_pos); // TODO change this to point from an actual light
  vec3 view_dir = normalize(frag_pos - camera_pos);

  vec3 specular_reflection_direction = reflect(light_dir, frag_normal);
  float specular = clamp(pow(dot(view_dir, specular_reflection_direction), 50.0), 0.0, 1.0);
  float diffuse = clamp(dot(light_dir, frag_normal), 0.0, 1.0);

  frag_color *= (diffuse + specular);
}
