package main
import "core:fmt"
import "core:time"
import "core:math/linalg"
import "vendor:glfw"
import bd "vendor:box3d"

default_material: Material

PhysicsMesh :: struct {
  scene: ^Scene,
  body_id: bd.BodyId,
  mesh_index: int,
  mesh: ^Mesh,
  def: PhysicsMeshDef
}

PhysicsMeshType :: enum {
  DYNAMIC,
  STATIC
}

PhysicsMeshDef :: struct {
  position: Vec3,
  size: Vec3,
  type: PhysicsMeshType
}

scene_append_physics_mesh :: proc(scene: ^Scene, def: PhysicsMeshDef) {
  o: PhysicsMesh
  o.def = def
  m := mesh_make_cube(default_material)
  append(&scene.meshes, m)
  o.mesh_index = len(scene.meshes)-1
  o.mesh = &scene.meshes[o.mesh_index]

  bdef := bd.DefaultBodyDef()
  if def.type == .DYNAMIC {
    bdef.type = .dynamicBody
  }
  bdef.position = def.position

  o.body_id = bd.CreateBody(scene.world_id, bdef)

  hull := bd.MakeBoxHull(def.size.x*0.5, def.size.y*0.5, def.size.z*0.5)
  shape := bd.DefaultShapeDef()
  shape.density = 1
  shape.baseMaterial.friction = 0.3
  _ = bd.CreateHullShape(o.body_id, shape, &hull.base)
  bd.Body_ApplyMassFromShapes(o.body_id)

  bd.Body_SetAwake(o.body_id, true)
  append(&scene.physics_meshes, o)
}

SceneFlags :: enum {
  DEBUG_OVERLAY
}

Scene :: struct {
  camera: Camera,
  player: Player,
  sky_mesh: Mesh,
  mouse: Mouse,
  keys: map[int]bool,
  keys_pressed: map[int]bool,
  meshes: [dynamic]Mesh,
  physics_meshes: [dynamic]PhysicsMesh,
  quads: [dynamic]Quad,
  renderer: ^Renderer,
  resources: Resources,
  delta_time: f32,
  delta_time_ema: f32,
  frame_number: i32,
  flags: bit_set[SceneFlags],

  // Physics
  world_id: bd.WorldId,
  ground_box_id: bd.BodyId,
  physics_timestep: f32,
  substep_count: i32
}

scene_init :: proc(scene: ^Scene, renderer: ^Renderer) {
  {
    scene.substep_count = 4
    scene.physics_timestep = 1.0 / 60.0
    world_def := bd.DefaultWorldDef()
    scene.world_id = bd.CreateWorld(world_def)

    ground_body_def := bd.DefaultBodyDef()
    ground_body_def.position = {0, -250, 0}
    scene.ground_box_id = bd.CreateBody(scene.world_id, ground_body_def)

    ground_hull := bd.MakeBoxHull(800, 5, 800)
    ground_shape := bd.DefaultShapeDef()
    _ = bd.CreateHullShape(scene.ground_box_id, ground_shape, &ground_hull.base)
  }

  platform_init(scene)
  resources_load(&scene.resources)
  renderer_init(renderer, scene)
  player_init(scene, &scene.player)
  scene.delta_time = 16.666;
  scene.delta_time_ema = 1//scene.delta_time

  // scene.post_process_quad = mesh_make_quad()

  {
    sky_shader := shader_compileprogram(
                  cstring(#load("../assets/shaders/sky_frag.glsl")),
                  cstring(#load("../assets/shaders/sky_vert.glsl")),
                  .THREE_DIMENSIONAL,
                  "./assets/shaders/sky_frag.glsl",
                  "./assets/shaders/sky_vert.glsl"
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

  albedo_texture := texture_load("assets/textures/slate-cliff-rock-bl4/slatecliffrock-albedo.png", true)//texture_load("assets/textures/box_placeholder.ppm", true)
  grass_texture := texture_load("assets/textures/whispy-grass-meadow-bl/wispy-grass-meadow_albedo.png", true)
  dirt_texture := texture_load("assets/textures/dirt_albedo.png", true)

  default_material = Material{
    is_valid = true,
    albedo_textures = albedo_texture,
    albedo_tint = {0.8,0.8,0.98},
    roughness_textures = scene.resources.black_texture,
    shader = renderer.default_shader,
    roughness_strength = 0,
    metallic_strength = 0
  }
  uvf := f32(0.18)
  ground_material := Material{
    is_valid = true,
    albedo_textures = {grass_texture, dirt_texture, 0},
    roughness_textures = scene.resources.black_texture,
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


  // ground_mesh := asset_loader_obj_mesh("assets/models/terrain.obj", ground_material)
  scl := f32(850)
  // ground_mesh.material.albedo_tint = {0.3, 0.7, 0.3}
  // ground_mesh.model_matrix *= translation_matrix({0, -3, 0})
  // ground_mesh.model_matrix *= scale_matrix({scl, scl, scl})

  // append(&scene.meshes, ground_mesh)

  macroground_material := asset_loader_material(
    texture_load("assets/models/mountain/textures/albedo.jpg"),
    0,
    "terrain",
    .THREE_DIMENSIONAL
  )
  macroground_material.metallic_strength = 0
  macroground_material.roughness_strength = 0.2
  macroground_material.normal_strength = 1
  macroground_material.uv.zw = {100, 100} * 0.9
  macroground_material.albedo_textures[1] = texture_load("assets/textures/slate-cliff-rock-bl4/slatecliffrock-albedo.png", true)
  macroground_material.albedo_textures[2] = texture_load("assets/textures/iced-over-ground7-bl/iced-over-ground7-albedo.png", true)
  
  macroground_material.roughness_textures[0] = texture_load("assets/textures/slate-cliff-rock-bl4/slatecliffrock_Roughness2.png")
  macroground_material.roughness_textures[1] = texture_load("assets/textures/iced-over-ground7-bl/iced-over-ground7-Roughness.png")

  macroground_material.normal_textures[0] = texture_load("assets/textures/slate-cliff-rock-bl4/slatecliffrock_Normal-ogl.png")
  macroground_material.normal_textures[1] = texture_load("assets/textures/iced-over-ground7-bl/iced-over-ground7-Normal-ogl.png")



  scl = f32(180)
  macroground_mesh := asset_loader_obj_mesh("assets/models/mountain/mountain.obj", macroground_material)
  macroground_mesh.model_matrix *= translation_matrix({0, -3, 0})
  macroground_mesh.model_matrix *= scale_matrix({scl, scl, scl})
  append(&scene.meshes, macroground_mesh)

  scene_append_physics_mesh(scene, {
    position = {0, 1000, 0},
    size = {50, 50, 50},
    type = .DYNAMIC
  })
  scene_append_physics_mesh(scene, {
    position = {28, 1100, 26},
    size = {50, 50, 50},
    type = .DYNAMIC
  })
}

scene_update :: proc(scene: ^Scene) {
  current_time := f64(time.now()._nsec)
  delta_time := f32((current_time - prev_time) / f64(time.Millisecond))
  prev_time = current_time
  time_since_start := f32((current_time - start_time) / f64(time.Millisecond))

  scene.delta_time = delta_time
  dt_ema_fac := f32(0.3)
  scene.delta_time_ema = 
    scene.delta_time * dt_ema_fac + 
    scene.delta_time_ema * (1-dt_ema_fac)

  // copy(
  //   scene.delta_time_history[1:],
  //   scene.delta_time_history[0:len(scene.delta_time_history)-1]
  // )
  // scene.delta_time_history[0] = delta_time

  {
    // TODO: factor out to windowing layer
    mx, my := glfw.GetCursorPos(GlfwWindow)

    scene.mouse.previous_position = scene.mouse.current_position
    scene.mouse.current_position = {f32(mx), f32(my)}
    scene.mouse.delta_position = scene.mouse.current_position - scene.mouse.previous_position
  }

  bd.World_Step(scene.world_id, scene.physics_timestep, scene.substep_count)
  { // Update physics meshes
    for &m in scene.physics_meshes {
      p := bd.Body_GetPosition(m.body_id)
      r := bd.Body_GetRotation(m.body_id)
      m.mesh.model_matrix = translation_matrix(p) 
      m.mesh.model_matrix *= linalg.matrix4_from_quaternion(r)
      m.mesh.model_matrix *= scale_matrix(m.def.size)
      // fmt.printfln("Body pos %f %f %f", p.x, p.y, p.z)
    }
  }

  player_update(scene, &scene.player)
  camera_update(&scene.camera)

  renderer_render(scene.renderer)


  scene.mouse.scroll = 0
  scene.frame_number += 1
  platform_advance()
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

  bd.DestroyWorld(scene.world_id)
}
