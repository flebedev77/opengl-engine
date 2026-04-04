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
    // 1. Get the non-linear depth
    float depth = texture(depth_texture, frag_uv).r;

    // 2. Correctly reconstruct View Space (Fixing the NDC Z-mapping!)
    vec4 clip_space = vec4(frag_uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view_space = inv_projection_matrix * clip_space;
    view_space /= view_space.w;

    // 3. Convert pixel to World Space
    vec3 world_space_pixel = (inv_view_matrix * view_space).xyz;

    // 4. Extract Camera World Position directly from the inverse view matrix
    vec3 camera_world_pos = inv_view_matrix[3].xyz;

    // 5. Setup the Ray in World Space (The Optimization!)
    vec3 ray_dir = world_space_pixel - camera_world_pos;
    float ray_length = length(ray_dir);
    ray_dir = normalize(ray_dir);

    // Cap the ray distance so we don't raymarch into the void of the skybox
    float max_distance = 30.0; 
    ray_length = min(ray_length, max_distance);

    float step_length = ray_length / float(STEPS);
    vec3 step_vector = ray_dir * step_length;

    // Jitter to turn banding into noise
    float jitter = rand(frag_uv);
    vec3 current_pos = camera_world_pos + (step_vector * jitter);

    float volumetric_light = 0.0;
    float scattering_intensity = 0.9; // Tweak this for thicker/thinner fog
    float density = 0.0;

    // 6. The Optimized Loop
    for (int i = 0; i < STEPS; i++) {
        // Because we are already in World Space, we skip the inv_view_matrix multiplication here!
        vec4 light_space_pos = shadowmap_matrix * vec4(current_pos, 1.0);

        // Perspective divide & NDC to UV [0, 1]
        vec3 proj_coords = light_space_pos.xyz / light_space_pos.w;
        proj_coords = proj_coords * 0.5 + 0.5;

        // Ensure we only sample inside the shadow map bounds
        if (proj_coords.x >= 0.0 && proj_coords.x <= 1.0 &&
            proj_coords.y >= 0.0 && proj_coords.y <= 1.0 &&
            proj_coords.z <= 1.0) {

            float shadow_depth = texture(shadowmap_texture, proj_coords.xy).r;

            // If the air pocket is closer to the light than the nearest occluder, it's lit!
            // (Using a 0.005 bias to prevent acne/self-shadowing inside the volume)
            if (proj_coords.z < shadow_depth) {
                volumetric_light += scattering_intensity;
            }
        }
        density += 0.1;

        current_pos += step_vector;
    }

    float transmittance = exp(-density);

    return vec4(
        vec3(volumetric_light / float(STEPS)),
        transmittance
        );
}

void main() {
    frag_color = vec4(crepuscular_rays());
}
