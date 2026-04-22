#version 330 core
layout (location = 0) out vec4 out_frag_color;
layout (location = 1) out vec4 out_frag_normal;

in vec2 frag_uv;
in vec3 frag_pos;
in vec3 frag_normal;
in vec4 frag_pos_lightspace;
in vec3 frag_vert_color;

uniform sampler2D albedo_texture;
uniform sampler2D roughness_texture;
uniform sampler2D shadowmap_texture;
uniform sampler2D macroshadowmap_texture;

uniform vec3 tint;
uniform vec3 camera_pos;
uniform vec3 light_pos;
uniform mat4 view_matrix;
uniform mat4 macroshadowmap_matrix;

uniform vec4 uv;

const float PI = 3.141592653589793;

const float shadow_pcf_border_exponent = 10; // Helps make the transition between nonshadow and shadow more natural and non linear
const float shadow_pcf_noisiness = 1.0;
const int shadow_pcf_samples = 5;
const float ambient_light_intensity = 0.5;

const vec2 poisson_offsets[64] = vec2[](
vec2(0.24772918, 0.42333201), 
vec2(-0.49345073, -0.56058770), 
vec2(0.33773723, -0.33185625), 
vec2(-0.42333335, -0.67931640), 
vec2(-0.56918424, 0.50545412), 
vec2(0.61495525, -0.56252587), 
vec2(-0.67867583, 0.08087199), 
vec2(0.23042901, -0.38165757), 
vec2(0.00572612, -0.63751310), 
vec2(0.24972799, 0.45497194), 
vec2(0.60606140, 0.09318615), 
vec2(0.44612327, 0.19621556), 
vec2(-0.66485894, -0.06752378), 
vec2(-0.94160569, -0.22511423), 
vec2(0.02352239, -0.02492522), 
vec2(0.75924087, 0.46712619), 
vec2(-0.03723203, 0.42882612), 
vec2(-0.20740692, -0.33882591), 
vec2(0.78905636, 0.17830573), 
vec2(-0.12130364, 0.89415163), 
vec2(0.18524505, -0.16827337), 
vec2(0.69696110, -0.71203583), 
vec2(-0.21347535, -0.93752778), 
vec2(0.21920304, -0.28975391), 
vec2(-0.36250681, -0.14360578), 
vec2(-0.52363777, 0.82716507), 
vec2(0.19863699, -0.05758470), 
vec2(0.28176853, 0.82335269), 
vec2(-0.16420561, -0.66520327), 
vec2(-0.22581151, 0.40243334), 
vec2(0.88885278, -0.08475550), 
vec2(0.63730830, -0.28425556), 
vec2(0.17913473, 0.85945350), 
vec2(-0.22355738, 0.12447221), 
vec2(-0.47471470, 0.42998087), 
vec2(-0.87762588, -0.22661512), 
vec2(0.52406353, 0.72567666), 
vec2(-0.36563814, -0.60846978), 
vec2(-0.75840884, -0.44909629), 
vec2(-0.64087528, 0.04041982), 
vec2(0.48745134, 0.83716547), 
vec2(-0.06525695, -0.71009201), 
vec2(-0.96412289, -0.23523238), 
vec2(-0.16232638, 0.55210590), 
vec2(0.28586948, -0.76331109), 
vec2(0.98136264, 0.14953384), 
vec2(0.09105146, -0.78715026), 
vec2(0.06548858, -0.35983145), 
vec2(0.75632578, -0.55447483), 
vec2(0.08975850, -0.53518254), 
vec2(-0.35269159, 0.71880257), 
vec2(-0.68824291, -0.12898995), 
vec2(-0.19524200, 0.60467082), 
vec2(-0.49216211, 0.76259518), 
vec2(-0.16087414, 0.87056315), 
vec2(0.02998847, -0.60004658), 
vec2(-0.51174641, -0.10292845), 
vec2(-0.73968518, 0.30407849), 
vec2(-0.73906046, 0.66284049), 
vec2(-0.10300110, 0.53295016), 
vec2(-0.52906251, -0.54112375), 
vec2(0.63081646, -0.04855106), 
vec2(0.43956539, -0.09492128), 
vec2(-0.22184938, 0.03012371)
);

float rand(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec2 randtwo(vec2 co) {
  return vec2(rand(co), rand(co + frag_uv)) * 2 - 1;
}

float calculate_shadow(vec3 proj_coords, vec3 light_dir, sampler2D shadowmap) {
  if (proj_coords.z >= 1.0) return 0.0;

  float max_bias = 0.0002;
  float min_bias = 0.0001;
  // float max_bias = 0.05;
  // float min_bias = 0.01;
  float bias = 0.0000001;//max(max_bias * (1.0 - dot(frag_normal, light_dir)), min_bias);  

  float closest_depth = texture(shadowmap, proj_coords.xy).r;
  float pixel_depth = proj_coords.z;

  if (closest_depth < pixel_depth - bias) {
    vec2 texel_size = 1.0 / vec2(4096, 4096);//textureSize(shadowmap, 0);
    texel_size *= 1;
    float shadow = 0.0;

    // float test_sample = 0;
    // float test_sample_amount = 10;
    // float test_sample_radius = 0.02;
    // for (int i = 0; i < test_sample_amount; i++) {
    //   vec2 jitter = poisson_offsets[i];
    //
    //   float sample_depth = texture(shadowmap, proj_coords.xy + jitter * texel_size * test_sample_radius).r;
    //   test_sample += (pixel_depth - bias > sample_depth) ? 1.0 : 0.0;
    // }
    // test_sample /= test_sample_amount;
    //
    // if (test_sample == 0 || test_sample == 1) {
    //   return test_sample;
    // }

    // Box sampling
    for (int x = -shadow_pcf_samples; x <= shadow_pcf_samples; x++) {
      for (int y = -shadow_pcf_samples; y <= shadow_pcf_samples; y++) {
        vec2 noise_offset = vec2( // NOTE: This could be stored into a texture to avoid redundant calculations
          rand(vec2(x, y)) * 2.0 - 1.0,
          rand(gl_FragCoord.xy) * 2.0 - 1.0
        ) * shadow_pcf_noisiness;
        vec2 sample_pos = (noise_offset + vec2(x, y)) * texel_size;
        sample_pos += proj_coords.xy;
        float depth = closest_depth;
        // if (sample_pos.x <= 1 && sample_pos.y <= 1 &&
        //     sample_pos.x >= 0 && sample_pos.y >= 0) {
          depth = texture(shadowmap, sample_pos).r;
        // }
        shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
      }
    }
    shadow /= (shadow_pcf_samples * 2 + 1) * (shadow_pcf_samples * 2 + 1);

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
    // float circle_sample_step = 0.4;
    // float samples = 0;
    // for (int radius = 0; radius < 2; radius++) {
    //   for (float theta = 0; theta < 2 * PI; theta += circle_sample_step) {
    //     samples++;
    //     vec2 noise_offset = vec2(
    //         rand(vec2(radius, theta)) * 2.0 - 1.0,
    //         rand(frag_pos.xy) * 2.0 - 1.0
    //     ) * shadow_pcf_noisiness;
    //
    //     vec2 sample_pos = vec2(
    //         cos(theta + noise_offset.x),
    //         sin(theta + noise_offset.y)
    //       ) * (noise_offset.x + radius) * texel_size;
    //     float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
    //     shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
    //   }
    // }
    //
    // shadow /= samples;

    // Poisson sampling
    // for (int j = 0; j < 2; j++) {
    //   for (int i = 0; i < 64; i++) {
    //     vec2 noise_offset = vec2(0);
    //     //     rand(poisson_offsets[i]) * 2.0 - 1.0,
    //     //     rand(poisson_offsets[i] + i) * 2.0 - 1.0
    //     // ) * shadow_pcf_noisiness;
    //     vec2 sample_pos = vec2(
    //         cos(poisson_offsets[i].x + j) * poisson_offsets[i].y,
    //         sin(poisson_offsets[i].x + j) * poisson_offsets[i].y
    //       );
    //     sample_pos = (sample_pos + noise_offset) * texel_size;
    //     float depth = texture(shadowmap_texture, proj_coords.xy + sample_pos).r;
    //     shadow += (pixel_depth - bias > depth) ? 1.0 : 0.0;
    //   }
    // }
    // shadow /= 64.0;

    // shadow = 1;

    return shadow;
  }
  return 0.0;
}

void main() {
  out_frag_normal = vec4(frag_normal, 0);

  vec4 textureSample = texture(albedo_texture, (frag_uv + uv.xy) * uv.zw);
  out_frag_color = textureSample * vec4(tint, 1) * vec4(frag_vert_color, 1);

  vec3 light_dir = normalize(-light_pos); // TODO change this to point from an actual light
  vec3 view_dir = normalize(frag_pos - camera_pos);

  float specularity = 1-texture(roughness_texture, frag_uv).r;//step(0.99, (textureSample.r + textureSample.g + textureSample.b));
  vec3 light_view_midway = normalize((-light_dir) + (-view_dir));
  float specular = clamp(
      pow(
        dot(light_view_midway, frag_normal),
        specularity * 30
      ),
      0,
      1
  ) * specularity * 2;
  // specular *= clamp(specularity, 0, 1.0);

  float diffuse = clamp(dot(light_dir, -frag_normal), 0, 1) * 0.5;

  vec4 ambient = vec4(ambient_light_intensity * vec3(0.094, 0.345, 0.729), 1.0); // NOTE multiplying by the color of the sky, make sure it always corresponds
  float shadow_darkness = 0.9;
  out_frag_color += 0.1;
  
  float shadow = 1.0;
  
  if (diffuse != 0) {
    vec3 proj_coords = frag_pos_lightspace.xyz / frag_pos_lightspace.w;
    proj_coords = proj_coords * 0.5 + 0.5;

    float p = 0.01;
    // TODO: OPTIMISATION: Move this comparison to the vertex shader and pass the properly selected shadowmap sampler from there
    if (proj_coords.x <= 1-p && proj_coords.y <= 1-p && proj_coords.x >= p && proj_coords.y >= p) {
      shadow = calculate_shadow(proj_coords, light_dir, shadowmap_texture);
    } else {
      vec4 macromap_space = macroshadowmap_matrix * vec4(frag_pos, 1);
      proj_coords = macromap_space.xyz / macromap_space.w;
      proj_coords = proj_coords * 0.5 + 0.5;
      shadow = calculate_shadow(proj_coords, light_dir, macroshadowmap_texture);
    }

    shadow = clamp(pow(shadow, shadow_pcf_border_exponent), 0, 1);
  }

  float inv_shadow = 1 - shadow;
  // out_frag_color = mix(out_frag_color, out_frag_color * shadow_ambient, clamp(pow(shadow, shadow_pcf_border_exponent), 0.0, 1.0));
  out_frag_color *= (diffuse * inv_shadow + specular * inv_shadow + ambient);// * ((1 + shadow_darkness) - shadow);

  // out_frag_color = vec4(frag_uv, 1, 1);
  // out_frag_color = vec4(1, 1, 1, 1);
  // out_frag_color = vec4(frag_normal, 1);
}
