#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D input_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;


float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}


vec3 reconstruct_position(vec2 uv, float non_linear_depth) {
  vec2 ndc = uv * 2 - 1;
  vec4 clip = vec4(ndc.x, ndc.y, non_linear_depth, 1);
  vec4 view = inv_projection_matrix * clip;
  return view.xyz / view.w;
}

void main() {
  vec2 res_to_unit = vec2(1) / textureSize(input_texture, 0);
  float depth = texture(input_texture, frag_uv).r;
  for (int x = -1; x <= 1; x++) {
    for (int y = -1; y <= 1; y++) {
      depth = min(depth,
          texture(input_texture, frag_uv + 
            vec2(float(x), float(y)) * res_to_unit).r);
    }
  }
  frag_color = vec4(depth);
}
