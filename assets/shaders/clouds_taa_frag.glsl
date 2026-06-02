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
    vec2 texel_size = 1.0 / vec2(textureSize(volumetrics_texture, 0));
    vec4 min_color = vec4(9999.0);
    vec4 max_color = vec4(-9999.0);

    // Sample a 3x3 neighborhood around the current pixel
    for (int x = -1; x <= 1; ++x) {
      for (int y = -1; y <= 1; ++y) {
        vec2 offset = vec2(x, y) * texel_size;
        vec4 neighbor = texture(volumetrics_texture, frag_uv + offset);
        min_color = min(min_color, neighbor);
        max_color = max(max_color, neighbor);
      }
    }

    // Sample history and clamp it to the local neighborhood bounds
    vec4 history_color = texture(volumetric_history_texture, history_uv);
    history_color = clamp(history_color, min_color, max_color);

    frag_color = mix(
        history_color,
        texture(volumetrics_texture, frag_uv),
        weight
    );
  }
  // frag_color += vec4(texture(volumetric_motion_vectors_texture, frag_uv).rgb, 0.5);
}

// void main() {
//   // frag_color = texture(volumetrics_texture,frag_uv);
//   // return;
//   float weight = 1.0 / float(volumetrics_taa_frames);
//   vec2 velocity = texture(volumetric_motion_vectors_texture, frag_uv).xy;
//   vec2 history_uv = frag_uv - velocity;
//
//   // Frustum/behind-camera validation check
//   if (history_uv.x <= 0.0 || history_uv.x >= 1.0 ||
//       history_uv.y <= 0.0 || history_uv.y >= 1.0 || 
//       velocity.x > 0.4) {
//     frag_color = texture(volumetrics_texture, frag_uv);
//   } else {
//     vec2 texel_size = 1.0 / vec2(textureSize(volumetrics_texture, 0));
//
//     vec4 m1 = vec4(0.0); // First moment (Sum)
//     vec4 m2 = vec4(0.0); // Second moment (Sum of Squares)
//
//     // Gather statistics from the 3x3 neighborhood
//     for (int x = -1; x <= 1; ++x) {
//       for (int y = -1; y <= 1; ++y) {
//         vec2 offset = vec2(x, y) * texel_size;
//         vec4 sample_color = texture(volumetrics_texture, frag_uv + offset);
//
//         m1 += sample_color;
//         m2 += sample_color * sample_color;
//       }
//     }
//
//     // Calculate Mean and Standard Deviation
//     vec4 mean = m1 / 9.0;
//     vec4 stddev = sqrt(max(vec4(0.0), (m2 / 9.0) - (mean * mean)));
//
//     // Gamma controls the width of the bounding box. 
//     // 1.5 to 2.0 is ideal. Lower = less ghosting, Higher = less flicker.
//     float gamma = 2.0; 
//     vec4 min_color = mean - gamma * stddev;
//     vec4 max_color = mean + gamma * stddev;
//
//     // Sample and clamp history color to our soft statistical envelope
//     vec4 history_color = texture(volumetric_history_texture, history_uv);
//     history_color = clamp(history_color, min_color, max_color);
//
//     // Fetch current frame color
//     vec4 current_color = texture(volumetrics_texture, frag_uv);
//
//     // HDR Anti-Flicker: Weight the blend based on relative sample luminance.
//     // This compresses bright noise spikes during the blend pass.
//     float l_current = dot(current_color.rgb, vec3(0.2126, 0.7152, 0.0722));
//     float l_history = dot(history_color.rgb, vec3(0.2126, 0.7152, 0.0722));
//
//     float w_current = weight / (1.0 + l_current);
//     float w_history = (1.0 - weight) / (1.0 + l_history);
//
//     // Final resolve
//     frag_color = (current_color * w_current + history_color * w_history) / (w_current + w_history);
//   }
// }
