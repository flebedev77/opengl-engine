package main
import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"

SceneFlags :: enum {
  DEBUG_OVERLAY
}

Scene :: struct {
  camera: Camera,
  player: Player,
  sky_mesh: Mesh,
  mouse: Mouse,
  meshes: [dynamic]Mesh,
  quads: [dynamic]Quad,
  renderer: ^Renderer,
  resources: Resources,
  delta_time: f32,
  frame_number: i32,
  flags: bit_set[SceneFlags]
}

scene_init :: proc(scene: ^Scene, renderer: ^Renderer) {
  platform_init(scene)
  resources_load(&scene.resources)
  renderer_init(renderer, scene)
  player_init(scene, &scene.player)
  scene.delta_time = 16.666;

  // scene.post_process_quad = mesh_make_quad()

  {
    sky_shader := shader_compileprogram(
                  cstring(#load("../assets/shaders/sky_frag.glsl")),
                  cstring(#load("../assets/shaders/sky_vert.glsl")),
                  .THREE_DIMENSIONAL
                )
    sky_material := Material{
      is_valid = true,
      shader = sky_shader
    }
    sky_mesh := asset_loader_obj_mesh("assets/models/skydome.obj", sky_material)
    sky_size := f32(100000000)
    sky_mesh.model_matrix *= scale_matrix({sky_size, sky_size, sky_size})
    scene.sky_mesh = sky_mesh
    // defer gl.DeleteProgram(sky_shader.program)
  }

  if !LOAD_WORLD do return

  albedo_texture := texture_load("assets/textures/box_placeholder.ppm", true)
  grass_texture := texture_load("assets/textures/whispy-grass-meadow-bl/wispy-grass-meadow_albedo.png", true)
  dirt_texture := texture_load("assets/textures/dirt_albedo.png", true)

  default_material := Material{
    is_valid = true,
    albedo_textures = albedo_texture,
    albedo_tint = {0.8,0.8,0.98},
    roughness_texture = scene.resources.black_texture,
    shader = renderer.default_shader,
    roughness_strength = 0,
    metallic_strength = 0
  }
  uvf := f32(0.18)
  ground_material := Material{
    is_valid = true,
    albedo_textures = {grass_texture, dirt_texture, 0},
    roughness_texture = scene.resources.black_texture,
    uv = {0, 0, uvf*2600, uvf*2600},
    shader = shader_compileprogram(
        cstring(#load("../assets/shaders/terrain_frag.glsl")),
        cstring(#load("../assets/shaders/terrain_vert.glsl")),
        .THREE_DIMENSIONAL,
        "./assets/shaders/terrain_frag.glsl",
        "./assets/shaders/terrain_vert.glsl"
    ),
    roughness_strength = 0,
    metallic_strength = 0
  }

  light_mesh := mesh_make_cube(default_material, {10, 10, 10})  

  cube_mesh := mesh_make_cube(default_material, {0, 0, 0})
  cube_mesh.model_matrix = translation_matrix({1, 0, 1})
  cube_mesh.model_matrix *= scale_matrix({1, 0.8, 1})
  // textures_delete(albedo_texture, grass_texture)

  append(&scene.meshes, cube_mesh)
  append(&scene.meshes, light_mesh)


  ground_mesh := asset_loader_obj_mesh("assets/models/terrain.obj", ground_material)
  scl := f32(850)
  ground_mesh.material.albedo_tint = {0.3, 0.7, 0.3}
  ground_mesh.model_matrix *= translation_matrix({0, -3, 0})
  ground_mesh.model_matrix *= scale_matrix({scl, scl, scl})

  append(&scene.meshes, ground_mesh)

  macroground_mesh := asset_loader_obj_mesh("assets/models/macroterrain.obj", ground_material)
  macroground_mesh.model_matrix *= translation_matrix({0, -3, 0})
  macroground_mesh.model_matrix *= scale_matrix({scl, scl, scl})
  append(&scene.meshes, macroground_mesh)
}

scene_update :: proc(scene: ^Scene) {
  {
    // TODO: factor out to windowing layer
    mx, my := glfw.GetCursorPos(GlfwWindow)

    scene.mouse.previous_position = scene.mouse.current_position
    scene.mouse.current_position = {f32(mx), f32(my)}
    scene.mouse.delta_position = scene.mouse.current_position - scene.mouse.previous_position
  }


  player_update(scene, &scene.player)
  camera_update(&scene.camera)

  renderer_render(scene.renderer)

  scene.mouse.scroll = 0
  scene.frame_number += 1
}

scene_delete :: proc(scene: ^Scene, verbose := false) {
  if verbose {
    fmt.printfln("Unloading meshes")
  }

  for mesh in scene.meshes {
    shader_delete(mesh.material.shader)
    mesh_delete(mesh)
  }
  shader_delete(scene.sky_mesh.material.shader)
  delete(scene.meshes)
  renderer_delete(scene.renderer)
}
