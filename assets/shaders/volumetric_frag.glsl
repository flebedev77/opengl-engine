#version 330 core

in vec2 frag_uv;
layout (location = 0) out vec4 frag_color;
layout (location = 1) out vec2 motion_vector;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;
uniform sampler2D shadowmap_texture;
uniform sampler2D macroshadowmap_texture;
uniform sampler2D blue_noise_texture;

uniform sampler3D base_cloud_noise;
uniform sampler3D detail_cloud_noise;

uniform mat4 prev_projection_matrix;
uniform mat4 prev_view_matrix;
uniform mat4 projection_matrix;
uniform mat4 view_matrix;

uniform mat4 inv_projection_matrix;
uniform mat4 inv_view_matrix;

uniform mat4 shadowmap_matrix;
uniform mat4 macroshadowmap_matrix;

uniform vec3 light_pos;

uniform int frame_number;

uniform float cloud_dome_radius;

const float cloud_layer_thickness = 2000;//(186-10);
const float cloud_height_base = 1000;
float cloud_height_apex = cloud_height_base+cloud_layer_thickness;
// const float cloud_dome_radius = 1000000;
vec3 cloud_dome_position = vec3(0, -(cloud_dome_radius-cloud_height_base), 0);
float actual_cloud_height_base = cloud_dome_radius;
float actual_cloud_height_apex = cloud_dome_radius + cloud_layer_thickness;
const float cloud_minimum_height = -3500;

#define STEPS_CLOUDS 100
#define STEPS_CLOUDS_LIGHTING 5
#define CLOUD_DENSITY 1.0//0.5
#define CLOUD_LIGHT_DENSITY 0.8
#define CLOUD_STEP_LENGTH 265.5
#define CLOUD_LIGHT_STEP_LENGTH 30.6
#define MIN_DENSITY 0.01
#define SUN_INTENSITY 7//0

#define BACKSCATTER_MIN 0.52
#define BACKSCATTER_MAX 0.55

#define EXTINCTION_FACTOR 0.9
#define SCATTERING_FACTOR (EXTINCTION_FACTOR-0.001)

#define POWDER_FACTOR 152.2
#define POWDER_STRENGTH 3.0

#define TEMPORAL_ACCUMULATION_ENABLED true

const float PI = 3.141592653589793;

//	Simplex 3D Noise 
//	by Ian McEwan, Stefan Gustavson (https://github.com/stegu/webgl-noise)
//
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}

float rand_hash(vec2 p) {
  return fract(sin(dot(p.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float remap(float v, float fmin, float fmax, float tmin, float tmax) {
  return tmin + (tmax - tmin) * (v - fmin) / (fmax - fmin);
}

float lerp(float a, float b, float t) {
  return a + (b-a) * t;
}

vec2 rand_vec(vec2 p) {
	return (vec2(
		rand_hash(p) * 2.0 - 1.0, 
		rand_hash(p + vec2(1, 2343)) * 2.0 - 1.0
	));
}

float noisetwod(vec2 p) {
	vec2 f = fract(p);
	vec2 br = ceil(p);
	vec2 bl = br - vec2(1, 0);
	vec2 tl = bl + vec2(0, 1);
	vec2 tr = tl + vec2(1, 0);
	
	vec2 brn = rand_vec(br);
	vec2 bln = rand_vec(bl);
	vec2 tln = rand_vec(tl);
	vec2 trn = rand_vec(tr);
	
	float brv = dot(brn, (p - br));
	float blv = dot(bln, (p - bl));
	float trv = dot(trn, (p - tr));
	float tlv = dot(tln, (p - tl));
	
	float bn = lerp(blv, brv, f.x);
	float tn = lerp(tlv, trv, f.x);
	
	float v = lerp(bn, tn, f.y);
	return v * 0.5 + 0.5;
}

float snoise(vec3 v){ 
  return texture(base_cloud_noise, v).r;
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

float dnoise(vec3 p) { return texture(detail_cloud_noise, p).r; }

const float golden_ratio = 1.61803398875;

float rand(vec2 co){
  vec2 res = textureSize(screen_texture, 0);
  float aspect = res.x / res.y;
  float frame_offset = 0;
// #if (TEMPORAL_ACCUMULATION_ENABLED == true)
  frame_offset = fract(float(frame_number) * golden_ratio); 
// #endif
  co.x *= aspect;
  return fract(texture(blue_noise_texture, co * 5).r * 4 + frame_offset);
}

float Ei( float z )
{
  return 0.5772156649015328606065 + log( 1e-4 + abs(z) ) + z * (1.0 + z * (0.25 + z * ( (1.0/18.0) + z * ( (1.0/96.0) + z *
            (1.0/600.0) ) ) ) ); // For x!=0
}

// #define AMPLITUDE_FACTOR 0.3
// #define FREQUENCY_FACTOR 4.5
// #define DENSITY_FACTOR 0.6
// #define DENSITY_BIAS -0.2
#define CLOUD_SCALE 100
#define BASE_FREQUENCY_FACTOR 0.06
#define AMPLITUDE_FACTOR 0.2
#define FREQUENCY_FACTOR 1.2
#define DENSITY_FACTOR 0.9
#define DENSITY_BIAS -0.5
#define COVERAGE_BIAS -1//0.54
#define CLOUD_DRIFT_SPEED 0.6

float sample_cloud_density_cheap(vec3 p) {
  // p.x += float(frame_number) * CLOUD_DRIFT_SPEED;
  return snoise(p * 0.00015 * 0.06) * 0.1;
}

float sample_cloud_density(vec3 p) {
  // return clamp(
  //     20 - length(
  //       p - vec3(0, (cloud_height_base + cloud_height_apex)/2, 0)
  //       ) - snoise(p * 0.9) * 0.3,
  //     0, 1) * 2 + clamp(
  //       10 - length(
  //         p - vec3(150, (cloud_height_base + cloud_height_apex)/2, 150)
  //         ) - snoise(p * 0.9) * 0.3,
  //       0, 1);
  // float fade_start = cloud_height_apex - 60;
  // float fade_factor = clamp((p.y - fade_start) / (cloud_height_apex - fade_start), 0, 1);


  float coverage = max(noisetwod(p.xz * 0.0004), 0);
  // return coverage;
  // if (coverage < 0.0) return 0.0;


  float dc = length(p-cloud_dome_position);
  float percentage_to_apex = (dc - actual_cloud_height_base) / (actual_cloud_height_apex - actual_cloud_height_base);
  percentage_to_apex = pow(percentage_to_apex, 
      coverage * 3);
  float height_factor = 1.5-percentage_to_apex;
  float bottom_fade_height = 150;
  float bottom_fade = clamp((dc - actual_cloud_height_base) / bottom_fade_height, 0, 1);
  
  // p.x += float(frame_number) * CLOUD_DRIFT_SPEED;
  float m = 
      snoise(p * 0.00015 * 0.06) * 0.1 * (1-percentage_to_apex);
  m -= dnoise(p * 0.00015) * 0.018;//clamp((1-m) * 0.1, 0, 1);
  m -= dnoise(p * 0.00029) * 0.008;//clamp((1-m) * 0.1, 0, 1);

  // p.x += float(frame_number) * CLOUD_DRIFT_SPEED;
  m -= dnoise(p * 0.00069) * 0.006;//clamp((1-m) * 0.1, 0, 1);
  m -= dnoise(p * 0.0019) * 0.002;//clamp((1-m) * 0.1, 0, 1);
  m -= dnoise(p * 0.0029) * 0.001;//clamp((1-m) * 0.1, 0, 1);

  m *= bottom_fade;
  // m -= (1-dnoise(p * 0.002)) * 0.001 * height_factor; // Whispy shapes

  return CLOUD_DENSITY * clamp(m, 0, 1);

  vec3 uv = p * 0.00015;
  uv.zx *= 0.7;
  uv.x += float(frame_number) * 0.00001;
  float mg = 1.3;
  float v = snoise(uv*BASE_FREQUENCY_FACTOR) * mg * max(1.5 - percentage_to_apex, 0); mg *= AMPLITUDE_FACTOR*1.5; uv *= FREQUENCY_FACTOR * 0.3;
  uv.x += float(frame_number) * 0.00001 * 2;
  v += (snoise(uv * 0.7)) * mg * 2.5 * height_factor;
  mg *= AMPLITUDE_FACTOR; uv *= FREQUENCY_FACTOR;

  uv.x += float(frame_number) * 0.00001 * 0.8;
  v += (snoise(uv * 1.8 + vec3(0.2))) * mg * 1.9 * height_factor;// * mg * 0.8; 
  v += (snoise(uv * 0.5 - vec3(0.2))) * mg * 2.7 * height_factor;// * mg * 0.8; 
  mg *= AMPLITUDE_FACTOR; uv *= FREQUENCY_FACTOR;
  v += (snoise(uv * 0.8 + vec3(1))) * mg * 2.0 * height_factor;// * mg * 0.8; 
  v += (snoise(uv * 1.0 + vec3(-0.1))) * mg * 8.0;// * mg * 0.8; 

  v += (snoise(uv * 3)) * mg * 8.8; 
  v += (snoise(uv * 7)) * mg * 4.8; 
  v += (snoise(uv * 10)) * mg * 4.2 * max(0.8+0.5*snoise(uv*0.0001), 0); 
  v *= clamp(coverage, 0, 1);
  v *= bottom_fade;

  return CLOUD_DENSITY * clamp(
      (DENSITY_FACTOR * v + DENSITY_BIAS)// * max(snoise(p*0.001) - 0.1, 0)
      , 0, 1);




  vec3 off = vec3(float(frame_number) * 0.004);
  float density = clamp(snoise(
        p * 0.003
  ), 0, 1);
    //1;//max(0.99 - p.y, 0);
  density *= 0.1;
  density *= max(0.98 - (p.y / (cloud_height_apex - cloud_height_base)), 0); // Taper off clouds on the tops
  density -= snoise(p * 0.06 + off) * density * 0.9;
  // if (density > 0.2) density = 1;
  // density -= snoise(p * 0.1) * 0.3;
  // density *= 2.1;
  return clamp(density, 0, 1);
}

#define AMBIENT_COEFFICIENT 4//5//12.0
#define AMBIENT_TOP_COEFFICIENT 0//0.87
#define AMBIENT_TOP_COLOR vec3(0.9)
#define AMBIENT_BOTTOM_COEFFICIENT 7.2
#define AMBIENT_BOTTOM_COLOR vec3(0.35, 0.35, 0.4)
#define AMBIENT_CONSTANT_COEFFICIENT 3.2
#define AMBIENT_CONSTANT_COLOR vec3(0.260, 0.325, 0.489)
#define AMBIENT_OCCLUSION_DISTANCE 2
#define AMBIENT_OCCLUSION_STRENGTH 2.5

vec3 calculate_ambient_color(vec3 p, float extinction_coefficient) {
  // return AMBIENT_CONSTANT_COLOR * AMBIENT_CONSTANT_COEFFICIENT;
  float dc = length(p-cloud_dome_position);
  float distance_top = (cloud_height_apex - dc);
  float a = -extinction_coefficient * distance_top;
  vec3 isotropic_scattering_top = AMBIENT_TOP_COLOR *
    max(0, exp(a) - a * Ei(a)) * AMBIENT_TOP_COEFFICIENT;


  float distance_bottom = (dc - cloud_height_base);
  a = -extinction_coefficient * distance_bottom;
  vec3 isotropic_scattering_bottom = AMBIENT_BOTTOM_COLOR *
    max(0, exp(a) - a * Ei(a)) * AMBIENT_BOTTOM_COEFFICIENT;
  return AMBIENT_COEFFICIENT * (isotropic_scattering_top +
    isotropic_scattering_bottom + 
    AMBIENT_CONSTANT_COLOR * AMBIENT_CONSTANT_COEFFICIENT);
}

float HG(float g, float cos_theta) {
  return 1 / (4.0 * 3.14159) * 
    (1.0 - g * g) / (pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5));
}

// https://youtu.be/9-HTvoBi0Iw?t=7923
float calculate_phase(float g, float cos_theta, float extinction) {
  float wzero = 0.86;
  float wone = 1-wzero;
  int M = 2;
  float octave_sum = 0;
  for (int j = 1; j <= M; j++) {
    octave_sum += HG(pow(2/3, j) * g, cos_theta);
  }
  float phase = HG(g, cos_theta) * wzero + (wone + extinction) / M * octave_sum;
  float backscatter = 1/PI * remap(extinction, 0, 1, BACKSCATTER_MIN, BACKSCATTER_MAX);
  return max(phase, backscatter);
}

vec2 ray_sphere(vec3 ro, vec3 rd, float sr, vec3 sp) {
    vec3 L = ro - sp;
    float a = dot(rd, rd); 
    float b = 2.0 * dot(rd, L);
    float c = dot(L, L) - (sr * sr);
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) return vec2(-1);
    float sqrtD = sqrt(discriminant);
    float t0 = (-b - sqrtD) / (2.0 * a);
    float t1 = (-b + sqrtD) / (2.0 * a);

    return vec2(t0, t1);
}

vec4 calculate_volumetrics() {
  // return vec4(vec3(1), rand(frag_uv));
    float depth = texture(depth_texture, frag_uv).r;

    vec4 clip_space = vec4(frag_uv * 2.0 - 1.0, depth, 1.0);
    vec4 view_space = inv_projection_matrix * clip_space;
    view_space /= view_space.w;

    vec3 world_space_pixel = (inv_view_matrix * view_space).xyz;
    vec3 camera_world_pos = inv_view_matrix[3].xyz;

    // return vec4(world_space_pixel, 0.5);

    vec3 ray_dir = world_space_pixel - camera_world_pos;
    float ray_length = length(ray_dir);
    ray_dir = normalize(ray_dir);
    // ray_length = min(ray_length, 100);

    float jitter = rand(frag_uv);// * 0.8;
    float density = 0.0;
    bool far_away = false;

    float g = 0.85; // Forward scattering (0.0 to 0.99)
    float cos_theta = dot(ray_dir, normalize(light_pos));
    float hg_phase = HG(g, cos_theta);//calculate_phase();

    //SUN RAYS
    
    // vec4 light_space_pos = shadowmap_matrix * vec4(world_space_pixel, 1);
    //
    // vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
    // proj_coords = proj_coords * 0.5 + 0.5;
    //
    // float shadow_depth = 0;
    // if (proj_coords.x > 1 || proj_coords.x < 0 || proj_coords.y > 1 || proj_coords.y < 0) {
    //       light_space_pos = macroshadowmap_matrix * vec4(world_space_pixel, 1);
    //
    //       proj_coords = light_space_pos.xyz / light_space_pos.w;
    //       proj_coords = proj_coords * 0.5 + 0.5;
    //
    //       shadow_depth = texture(macroshadowmap_texture, proj_coords.xy).r;
    // } else {
    //   shadow_depth = texture(shadowmap_texture, proj_coords.xy).r;
    // }
    // float volumetric_light = 0;
    // if (proj_coords.z < shadow_depth) {
    //   volumetric_light += proj_coords.z;// * hg_phase;
    // }
    //
    // return vec4(vec3(volumetric_light), 0.2);//clamp(volumetric_light, 0, 1));


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
    bool hit_cloud_surface = false;
    vec3 world_space_surface = world_space_pixel;

    float extinction = 1.0;
    vec3 scattering = vec3(0);

    vec2 A = ray_sphere(camera_world_pos, ray_dir, cloud_dome_radius + cloud_layer_thickness, cloud_dome_position);
    vec2 B = ray_sphere(camera_world_pos, ray_dir, cloud_dome_radius, cloud_dome_position);

    float t_in = -1.0;
    float t_out = -1.0;

    if (A.y >= 0.0) { 

      if (B.x < 0.0 && B.y < 0.0) {
        t_in = max(0.0, A.x);
        t_out = A.y;
      } else {
        if (B.x > 0.0) {
          t_in = max(0.0, A.x);
          t_out = B.x;
        } else if (A.y > 0.0) {
          t_in = max(0.0, B.y);
          t_out = A.y;
        }
      }
    }

    if (t_in >= 0 && t_out > 0.0) {
      t_in = max(t_in, 0.0);

      // if (ray_length > 1000) ray_length = 1e6;
      t_out = min(t_out, ray_length);

      if (t_in < t_out) {

        float cloud_march_length = t_out - t_in;

        vec3 start_pos = camera_world_pos + ray_dir * t_in;

        vec3 current_pos = start_pos;

        float jitter = rand(frag_uv) * CLOUD_STEP_LENGTH;
        float distance_travelled = jitter;
        float step_length = CLOUD_STEP_LENGTH;
        float current_step_length = step_length;

        bool fine_step = true;
        int steps_taken_with_zero_density = 0;

        for (int i = 0; i < STEPS_CLOUDS; i++) {
          if (extinction < 0.01) { extinction = 0; break; }
          if (distance_travelled >= cloud_march_length || current_pos.y < cloud_minimum_height) break;

          current_pos = start_pos + ray_dir * distance_travelled;
          float current_density = (fine_step) ? sample_cloud_density(current_pos) :
            sample_cloud_density_cheap(current_pos);


          if (current_density >= MIN_DENSITY) {
            steps_taken_with_zero_density = 0;
            if (fine_step == false) {
              distance_travelled -= current_step_length;
              current_step_length = CLOUD_STEP_LENGTH;
              fine_step = true;
            } else {
              if (!hit_cloud_surface) {
                world_space_surface = start_pos + ray_dir * (distance_travelled);
                hit_cloud_surface = true;
              }
              float scattering_coefficient = SCATTERING_FACTOR * current_density;
              float extinction_coefficient = EXTINCTION_FACTOR * current_density;

              vec3 light_dir = normalize(light_pos);
              vec3 light_step_vector = light_dir * CLOUD_LIGHT_STEP_LENGTH;
              vec3 light_current_pos = current_pos + light_step_vector;

              float light_distance_travelled = 0.0;
              float light_transmittance = 1.0;

              for (int j = 0; j < STEPS_CLOUDS_LIGHTING; j++) {
                if (light_transmittance < 0.01) break;
                // if (
                //     light_current_pos.y < cloud_height_base ||
                //     light_current_pos.y > cloud_height_apex
                //     ) break;

                float light_current_density = sample_cloud_density(light_current_pos);
                if (light_current_density > MIN_DENSITY)
                  light_transmittance *= exp(-EXTINCTION_FACTOR * light_current_density * CLOUD_LIGHT_DENSITY * CLOUD_LIGHT_STEP_LENGTH);

                light_current_pos += light_step_vector;
                // light_distance_travelled += CLOUD_LIGHT_STEP_LENGTH;
              }
              // light_transmittance = max(light_transmittance, 0.7);

              float transmittance = exp(-extinction_coefficient * current_step_length);

              float powder = 1.0 - exp(-extinction_coefficient * POWDER_FACTOR);

              float occ = exp(-sample_cloud_density(current_pos + vec3(0, AMBIENT_OCCLUSION_DISTANCE, 0)) * AMBIENT_OCCLUSION_STRENGTH);

              vec3 sun_light = vec3(SUN_INTENSITY);
              sun_light *= vec3(1, 1, 1.1);
              vec3 sun_color = mix(1, powder, POWDER_STRENGTH) * light_transmittance * sun_light;
              vec3 ambient_color = occ * calculate_ambient_color(current_pos, extinction_coefficient);
              float ambient_phase = 1 / (4 * PI);
              float sun_phase = calculate_phase(0.86, cos_theta, extinction_coefficient);
              vec3 scattered = scattering_coefficient * (sun_color * sun_phase + ambient_color * ambient_phase);
              vec3 integrated_light = (scattered - scattered * transmittance) / max(extinction_coefficient, 0.0001);
              scattering += extinction * integrated_light;// * (scattering_coefficient / max(extinction_coefficient, 0.0001));

              extinction *= transmittance;

            }
          } else {
            steps_taken_with_zero_density++;
            if (steps_taken_with_zero_density > 10 && fine_step) {
              // fine_step = false;
              current_step_length = CLOUD_STEP_LENGTH * 1;
            }
          }

          distance_travelled += current_step_length;
        }
        // scattering = vec3(1);
        // extinction = exp(-0.05 * cloud_march_length);


      }
    }

    // vec4 projected = prev_projection_matrix * prev_view_matrix * vec4(world_space_surface, 1);
    // projected.xyz /= projected.w;
    // vec2 prev_uv = projected.xy * 0.5 + 0.5;
    // motion_vector = (frag_uv - prev_uv) * 100;

    // Calculate current NDC position
    vec4 current_clip = projection_matrix * view_matrix * vec4(world_space_surface, 1.0);
    vec2 current_ndc = current_clip.xy / current_clip.w;
    vec2 current_uv = current_ndc * 0.5 + 0.5;

    // Calculate previous NDC position
    vec4 prev_clip = prev_projection_matrix * prev_view_matrix * vec4(world_space_surface, 1.0);
    vec2 prev_ndc = prev_clip.xy / prev_clip.w;
    vec2 prev_uv = prev_ndc * 0.5 + 0.5;

    // Output velocity
    motion_vector = current_uv - prev_uv;

    return vec4(
        scattering, extinction
    );
}

void main() {
    frag_color = calculate_volumetrics();
}
