package main
import "base:runtime"
import "core:fmt"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

import "core:math/linalg"
import "core:math"

// TODO: Move all constants to a .ini file
WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

MIN_WINDOW_WIDTH :: 600
MIN_WINDOW_HEIGHT :: 480

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

PLAYER_WALK_SPEED :: 0.006
PLAYER_LOOK_SENSITIVITY :: Vec2{0.0001, 0.0002}

VAO :: distinct u32
VBO :: distinct u32

IRect :: struct {
  x, y, w, h: i32
}

FrameBuffer: IRect
GlfwWindow: glfw.WindowHandle


start_time := f64(time.now()._nsec)
prev_time := start_time

Mouse :: struct {
  scroll: f32,
  previous_position,
  current_position,
  delta_position: Vec2
}

shadowmap_material: Material
shader: Shader

main :: proc() {
  defer glfw.Terminate()

  assert(glfw.Init() == true)

  glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_VERSION_MAJOR)
  glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_VERSION_MINOR)
  glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
  glfw.WindowHint(glfw.SAMPLES, 4)

  monitor := glfw.GetPrimaryMonitor()
  monitor_mode := glfw.GetVideoMode(monitor)

  GlfwWindow = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello world", monitor, nil)
  defer glfw.DestroyWindow(GlfwWindow)
  assert(GlfwWindow != nil)

  glfw.SetWindowSizeLimits(GlfwWindow, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, glfw.DONT_CARE, glfw.DONT_CARE)
  glfw.SetInputMode(GlfwWindow, glfw.CURSOR, glfw.CURSOR_DISABLED)
  glfw.MakeContextCurrent(GlfwWindow)
  glfw.SwapInterval(1)

  gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, glfw.gl_set_proc_address)
  renderer_info()
  update_framebuffer()

  scene: Scene
  renderer: Renderer
  scene_init(&scene, &renderer)
  defer scene_delete(&scene)

  light_viewmatrix := linalg.matrix4_look_at_f32(
    linalg.normalize(Vec3{10, 50, 10}) * 5, 
    {0, 0, 0},
    {0, 1, 0}
  )
  lightmap_proj_size := f32(3)
  light_projmatrix := orthographic_projection_matrix(
    -lightmap_proj_size,
    lightmap_proj_size,
    lightmap_proj_size,
    -lightmap_proj_size,
    0.1, 26)
  shadowmap_matrix := light_projmatrix * light_viewmatrix
  shader.parameters.shadowmap_matrix = shadowmap_matrix

  sky_shader := shader_compileprogram(
    cstring(#load("../assets/shaders/sky_frag.glsl")),
    cstring(#load("../assets/shaders/sky_vert.glsl")),
    .THREE_DIMENSIONAL
  )
  defer gl.DeleteProgram(sky_shader.program)


  albedo_texture := texture_load("assets/textures/box_placeholder.ppm")
  grass_texture := texture_load("assets/textures/whispy-grass-meadow-bl/wispy-grass-meadow_albedo.png")
  black_texture := texture_load("assets/textures/black.png")

  default_material := Material{
    is_valid = true,
    albedo_texture = albedo_texture,
    albedo_tint = {0.8,0.8,0.98},
    roughness_texture = black_texture,
    shader = renderer.default_shader,
    roughness_strength = 0,
    metallic_strength = 0
  }
  sky_material := Material{
    is_valid = true,
    shader = sky_shader
  }
  ground_material := Material{
    is_valid = true,
    albedo_texture = grass_texture,
    roughness_texture = black_texture,
    uv = {0, 0, 40, 40},
    shader = renderer.default_shader,
    roughness_strength = 0,
    metallic_strength = 0
  }

  glfw.SetWindowRefreshCallback(GlfwWindow, window_refresh)

  light_mesh := mesh_make_cube(default_material, {10, 10, 10})  

  cube_mesh := mesh_make_cube(default_material, {0, 0, 0})
  cube_mesh.model_matrix = translation_matrix({1, 0, 1})
  cube_mesh.model_matrix *= scale_matrix({1, 0.8, 1})

  sky_mesh := asset_loader_obj_mesh("assets/models/skydome.obj", sky_material)
  sky_mesh.model_matrix *= scale_matrix({500, 500, 500})
  scene.sky_mesh = sky_mesh

  ground_mesh := asset_loader_obj_mesh("assets/models/terrain.obj", ground_material)
  scl := f32(5.2)
  ground_mesh.material.albedo_tint = {0.3, 0.7, 0.3}
  ground_mesh.model_matrix *= scale_matrix({scl, scl, scl})
  ground_mesh.model_matrix *= translation_matrix({0, -3, 0})
  
  append(&scene.meshes, cube_mesh)
  append(&scene.meshes, light_mesh)
  append(&scene.meshes, ground_mesh)


  for glfw.WindowShouldClose(GlfwWindow) == false {
    current_time := f64(time.now()._nsec)
    delta_time := f32((current_time - prev_time) / f64(time.Millisecond))
    prev_time = current_time
    time_since_start := f32((current_time - start_time) / f64(time.Millisecond))

    scene_update(&scene)

    if glfw.GetKey(GlfwWindow, glfw.KEY_ESCAPE) > 0 {
      break
    }

    glfw.SwapBuffers(GlfwWindow)
    glfw.PollEvents()
  }

}

window_refresh :: proc "c" (window: glfw.WindowHandle) {
  context = runtime.default_context()
  update_framebuffer()  
}

update_framebuffer :: proc() {
  FrameBuffer.w, FrameBuffer.h = glfw.GetFramebufferSize(GlfwWindow)
  gl.Viewport(0, 0, FrameBuffer.w, FrameBuffer.h)
  fmt.printfln("Resized framebuffer [%d, %d]", FrameBuffer.w, FrameBuffer.h)
}
