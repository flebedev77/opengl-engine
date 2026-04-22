#version 330 core

in vec2 frag_uv;
out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;
uniform sampler2D shadowmap_texture;
uniform sampler2D macroshadowmap_texture;

uniform mat4 projection_matrix;
uniform mat4 view_matrix;
uniform mat4 inv_projection_matrix;
uniform mat4 inv_view_matrix;
uniform mat4 shadowmap_matrix;
uniform mat4 macroshadowmap_matrix;

uniform vec3 light_pos;

const float cloud_height_base = 10;
const float cloud_height_apex = 62;

#define STEPS_LIGHT 16
#define STEPS_CLOUDS 100
#define STEPS_CLOUDS_LIGHTING 6
#define CLOUD_DENSITY 2.3
#define CLOUD_LIGHT_DENSITY 0.831
#define CLOUD_STEP_LENGTH 0.7
#define CLOUD_LIGHT_STEP_LENGTH 1.8

//	Simplex 3D Noise 
//	by Ian McEwan, Stefan Gustavson (https://github.com/stegu/webgl-noise)
//
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float snoise(vec3 v){ 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C 
  vec3 x1 = x0 - i1 + 1.0 * C.xxx;
  vec3 x2 = x0 - i2 + 2.0 * C.xxx;
  vec3 x3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = mod(i, 289.0 ); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  float n_ = 1.0/7.0; // N=7
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z *ns.z);  //  mod(p,N*N)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
}

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float sample_cloud_density(vec3 p) {
  return clamp(
      10 - length(
        p - vec3(0, (cloud_height_base + cloud_height_apex)/2, 0)
      ) - snoise(p * 0.9) * 0.3,
  0, 1);


  float density = snoise(p * 0.01);
  density -= max(0, snoise(p * 0.02) * 1.9);
  density -= snoise(p * 0.1) * 0.3;
  density *= 2.1;
  return clamp(pow(density, 1), 0, 1);
}

vec4 calculate_volumetrics() {
    float depth = texture(depth_texture, frag_uv).r;

    vec4 clip_space = vec4(frag_uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view_space = inv_projection_matrix * clip_space;
    view_space /= view_space.w;

    vec3 world_space_pixel = (inv_view_matrix * view_space).xyz;
    vec3 camera_world_pos = inv_view_matrix[3].xyz;

    vec3 ray_dir = world_space_pixel - camera_world_pos;
    float ray_length = length(ray_dir);
    ray_dir = normalize(ray_dir);

    float max_distance = 140.0; 
    ray_length = min(ray_length, max_distance);

    float step_length = ray_length / float(STEPS_LIGHT);
    vec3 step_vector = ray_dir * step_length;

    float jitter = rand(frag_uv) * 0.8;
    vec3 current_pos = camera_world_pos + (step_vector * jitter);

    float volumetric_light = 0.0;
    float scattering_intensity = 0.4; // Tweak this for thicker/thinner fog
    float density = 0.0;
    bool far_away = false;

    float g = 0.8; // Forward scattering coefficient
    float cos_theta = dot(ray_dir, normalize(light_pos));
    // Henyey-Greenstein Phase Function
    float phase = 1;//(1.0 / (4.0 * 3.14159)) * ((1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5));

    // for (int i = 0; i < STEPS_LIGHT; i++) {
    //     vec4 light_space_pos;
    //     vec3 proj_coords;
    //     float shadow_depth;
    //
    //     if (far_away) {
    //       light_space_pos = macroshadowmap_matrix * vec4(current_pos, 1);
    //
    //       proj_coords = light_space_pos.xyz / light_space_pos.w;
    //       proj_coords = proj_coords * 0.5 + 0.5;
    //
    //       shadow_depth = texture(macroshadowmap_texture, proj_coords.xy).r;
    //     } else {
    //       light_space_pos = shadowmap_matrix * vec4(current_pos, 1);
    //
    //       proj_coords = light_space_pos.xyz / light_space_pos.w;
    //       proj_coords = proj_coords * 0.5 + 0.5;
    //
    //       if (proj_coords.x > 1 || proj_coords.x < 0 || proj_coords.y > 1 || proj_coords.y < 0) {
    //         far_away = true;
    //       }
    //
    //       shadow_depth = texture(shadowmap_texture, proj_coords.xy).r;
    //     }
    //
    //     if (proj_coords.z < shadow_depth) {
    //       volumetric_light += scattering_intensity * phase;
    //     }
    //
    //     current_pos += step_vector;
    // }
    // volumetric_light /= STEPS_LIGHT;

    float cloud_transmittance = 1.0;
    float cloud_light = 0;
    float cloud = 0.0;

    if (ray_dir.y != 0) {
      float t_base = (cloud_height_base - camera_world_pos.y) / ray_dir.y;
      float t_apex = (cloud_height_apex - camera_world_pos.y) / ray_dir.y;

      float t_in = min(t_base, t_apex);
      float t_out = max(t_base, t_apex);

      if (t_out > 0.0) {
        t_in = max(t_in, 0.0);

        // if (ray_length < t_out) cloud_transmittance = 0;
        t_out = min(t_out, ray_length);

        if (t_in < t_out) {

          float cloud_march_length = t_out - t_in;

          step_length = jitter + CLOUD_STEP_LENGTH;//min(10, cloud_march_length / float(STEPS_CLOUDS));
          step_vector = ray_dir * step_length;

          vec3 start_pos = camera_world_pos + ray_dir * t_in;
          float distance_travelled = 0;

          for (int i = 0; i < STEPS_CLOUDS; i++) {
            if (cloud_transmittance < 0.001) break;
            if (distance_travelled > cloud_march_length) break;


            current_pos = start_pos + ray_dir * distance_travelled + step_vector;
            distance_travelled += step_length;
            float current_density = sample_cloud_density(current_pos);

            if (current_density > 0) {
              vec3 light_dir = normalize(light_pos);
              vec3 light_step_vector = light_dir * CLOUD_LIGHT_STEP_LENGTH;
              vec3 light_current_pos = current_pos;
              
              float light_distance_travelled = 0;
              float light_transmittance = 1;
              float light_density = 0;
              for (int j = 0; j < STEPS_CLOUDS_LIGHTING; j++) {
                if (light_transmittance < 0.001) break;
                if (light_distance_travelled > cloud_march_length) break;

                float light_current_density = sample_cloud_density(light_current_pos);

                light_transmittance *= exp(-light_current_density * CLOUD_LIGHT_DENSITY * CLOUD_LIGHT_STEP_LENGTH);
                light_density += light_current_density * CLOUD_LIGHT_STEP_LENGTH;

                light_current_pos += light_step_vector;
                light_distance_travelled += CLOUD_LIGHT_STEP_LENGTH;
              }

              cloud_light += current_density * cloud_transmittance * light_transmittance * step_length;
              // cloud_light = light_transmittance;
              cloud += current_density * cloud_transmittance * step_length;
              cloud_transmittance *= exp(-current_density * CLOUD_DENSITY * step_length);
            }

          }
        }
      }
    }

    return vec4(
        // vec3(cloud_light),
        // vec3(1.0),
        mix(vec3(0.094, 0.345, 0.729), vec3(1), cloud_light + 0.1),
        clamp(1-cloud_transmittance, 0, 1)
    );
}

void main() {
    frag_color = calculate_volumetrics();
}
