#version 330

out vec4 frag_color;

in vec3 fragPosition;
in vec2 fragTexCoord;
in vec4 fragColor;
in vec3 fragNormal;
in vec3 fragPos;

uniform vec3 camera_pos;

void main() {
  vec3 color = vec3(1, 0, 0);
  vec3 light_dir = normalize(fragPos-vec3(10, 10, 60));
  vec3 view_dir = normalize(fragPos - camera_pos);
  vec3 middle_vec = normalize((-light_dir) + (-view_dir));
  float diffuse = clamp(dot(light_dir, -fragNormal), 0, 1) * 0.7;
  float specular = clamp(pow(dot(fragNormal, middle_vec), 30), 0, 1);

  vec3 out_color = color * (diffuse + 0.5) + vec3(1) * specular;
  frag_color = vec4(out_color, 1);
}
