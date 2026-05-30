#version 330 core

in vec2 frag_uv;
in vec3 frag_pos;

out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D normal_texture;
uniform sampler2D depth_texture;

uniform sampler2D volumetrics_texture;
uniform sampler2D volumetric_history_texture;
uniform sampler2D volumetric_motion_vectors_texture;

uniform int volumetrics_taa_frames;

uniform mat4 inv_projection_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

vec3 reconstruct_position(vec2 uv, float non_linear_depth) {
  vec2 ndc = uv * 2 - 1;
  vec4 clip = vec4(ndc.x, ndc.y, non_linear_depth, 1);
  vec4 view = inv_projection_matrix * clip;
  return view.xyz / view.w;
}

void main() {
  float weight = 1/float(volumetrics_taa_frames);
  vec2 velocity = texture(volumetric_motion_vectors_texture, frag_uv).xy;
  // if (length(velocity) > 0.05) weight = 1;

  vec2 history_uv = frag_uv - velocity;

  if (history_uv.x <= 0 || history_uv.x >= 1 ||
      history_uv.y <= 0 || history_uv.y >= 1) {
    frag_color = texture(volumetrics_texture, frag_uv);
  } else {
    frag_color = mix(
        texture(volumetric_history_texture, frag_uv - velocity),
        texture(volumetrics_texture, frag_uv),
        weight
    );
  }
  frag_color += vec4(texture(volumetric_motion_vectors_texture, frag_uv).rgb, 0.5);
}
