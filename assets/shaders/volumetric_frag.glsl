#version 330 core

in vec2 frag_uv;
out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;
uniform sampler2D shadowmap_texture;
uniform sampler2D macroshadowmap_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 inv_view_matrix;
uniform mat4 shadowmap_matrix;
uniform mat4 macroshadowmap_matrix;


uniform vec3 light_pos;

#define STEPS 32

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec4 crepuscular_rays() {
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

    float step_length = ray_length / float(STEPS);
    vec3 step_vector = ray_dir * step_length;

    float jitter = rand(frag_uv);
    vec3 current_pos = camera_world_pos + (step_vector * jitter);

    float volumetric_light = 0.0;
    float scattering_intensity = 0.4; // Tweak this for thicker/thinner fog
    float density = 0.0;
    bool far_away = false;

    float g = 0.8; // Forward scattering coefficient
    float cos_theta = dot(ray_dir, normalize(light_pos));
    // Henyey-Greenstein Phase Function
    float phase = 1;//(1.0 / (4.0 * 3.14159)) * ((1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cos_theta, 1.5));

    for (int i = 0; i < STEPS; i++) {
        vec4 light_space_pos;
        vec3 proj_coords;
        float shadow_depth;

        if (far_away) {
          light_space_pos = macroshadowmap_matrix * vec4(current_pos, 1);

          proj_coords = light_space_pos.xyz / light_space_pos.w;
          proj_coords = proj_coords * 0.5 + 0.5;

          shadow_depth = texture(macroshadowmap_texture, proj_coords.xy).r;
        } else {
          light_space_pos = shadowmap_matrix * vec4(current_pos, 1);

          proj_coords = light_space_pos.xyz / light_space_pos.w;
          proj_coords = proj_coords * 0.5 + 0.5;

          if (proj_coords.x > 1 || proj_coords.x < 0 || proj_coords.y > 1 || proj_coords.y < 0) {
            far_away = true;
          }

          shadow_depth = texture(shadowmap_texture, proj_coords.xy).r;
        }
        if (proj_coords.z < shadow_depth) {
          volumetric_light += scattering_intensity * phase;
        }
        density += 0.1;

        current_pos += step_vector;
    }

    float transmittance = exp(-density * 0.5);


    return vec4(
        vec3(volumetric_light / float(STEPS)),
        transmittance
        );
}

void main() {
    frag_color = crepuscular_rays();
}
