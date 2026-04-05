#version 330 core

in vec2 frag_uv;
out vec4 frag_color;

uniform sampler2D screen_texture;
uniform sampler2D depth_texture;
uniform sampler2D shadowmap_texture;

uniform mat4 inv_projection_matrix;
uniform mat4 inv_view_matrix;
uniform mat4 shadowmap_matrix;

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

    float max_distance = 80.0; 
    ray_length = min(ray_length, max_distance);

    float step_length = ray_length / float(STEPS);
    vec3 step_vector = ray_dir * step_length;

    float jitter = rand(view_space.xy);
    vec3 current_pos = camera_world_pos + (step_vector * jitter);

    float volumetric_light = 0.0;
    float scattering_intensity = 0.4; // Tweak this for thicker/thinner fog
    float density = 0.0;

    for (int i = 0; i < STEPS; i++) {
        vec4 light_space_pos = shadowmap_matrix * vec4(current_pos, 1.0);

        vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
        proj_coords = proj_coords * 0.5 + 0.5;

        float shadow_depth = texture(shadowmap_texture, proj_coords.xy).r;

        if (proj_coords.z + 0.1 < shadow_depth) {
          volumetric_light += scattering_intensity;
          density += 0.03;
        }

        current_pos += step_vector;
    }
    float transmittance = exp(-density);


    return vec4(
        vec3(volumetric_light / float(STEPS)),
        density
        );
}

void main() {
    frag_color = crepuscular_rays();
}
