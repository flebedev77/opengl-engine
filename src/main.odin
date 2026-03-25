package main
import "base:runtime"
import "core:fmt"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

import "core:math/linalg"
import "core:math"

// TODO: Move all constants to a .ini file
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

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

  GlfwWindow = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Hello world", nil, nil)
  defer glfw.DestroyWindow(GlfwWindow)
  assert(GlfwWindow != nil)

  glfw.SetWindowSizeLimits(GlfwWindow, MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT, glfw.DONT_CARE, glfw.DONT_CARE)
  glfw.SetInputMode(GlfwWindow, glfw.CURSOR, glfw.CURSOR_DISABLED)
  glfw.MakeContextCurrent(GlfwWindow)
  glfw.SwapInterval(1)

  gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, glfw.gl_set_proc_address)
  renderer_info()
  update_framebuffer()

  shader = shader_compileprogram(
    cstring(#load("../assets/shaders/frag.glsl")),
    cstring(#load("../assets/shaders/vert.glsl")),
    .THREE_DIMENSIONAL
  )
  defer gl.DeleteProgram(shader.program)

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

  scene: Scene
  renderer: Renderer
  scene_init(&scene, &renderer)
  defer scene_delete(&scene)

  // shadowmap_width, shadowmap_height: i32 = 4096, 4096
  // shadowmap_material: Material
  // shadowmap_framebuffer, shadowmap_texture: u32
  // gl.GenTextures(1, &shadowmap_texture)
  // gl.BindTexture(gl.TEXTURE_2D, shadowmap_texture)
  // gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, shadowmap_width, shadowmap_height, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)
  // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  //
  // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
  // gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
  // border_col: []f32 = {1, 1, 1}
  // gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &border_col[0])
  //
  // gl.GenFramebuffers(1, &shadowmap_framebuffer)
  // gl.BindFramebuffer(gl.FRAMEBUFFER, shadowmap_framebuffer)
  // gl.DrawBuffer(gl.NONE)
  // gl.ReadBuffer(gl.NONE)
  // gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, shadowmap_texture, 0)
  // if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
  //   fmt.printfln("Shadow framebuffer not complete!")
  //   fmt.printfln("%d", gl.CheckFramebufferStatus(gl.FRAMEBUFFER))
  // }
  // gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
  //
  // renderer.shadowmap_framebuffer = {
  //   framebuffer = shadowmap_framebuffer,
  //   size = {shadowmap_width, shadowmap_height}
  // }


  albedo_texture := texture_load("assets/textures/box_placeholder.ppm")
  airplane_texture := texture_load("assets/textures/su_body.ppm")
  angel_texture := texture_load("assets/models/pavlov/albedo.ppm")

  default_material := Material{
    is_valid = true,
    albedo_texture = albedo_texture,
    albedo_tint = {0.8,0.8,0.98},
    shader = shader
  }
  airplane_material := Material{
    is_valid = true,
    albedo_texture = airplane_texture,
    albedo_tint = {0,0,0},
    shader = shader
  }
  angel_material := Material{
    is_valid = true,
    albedo_texture = angel_texture,
    roughness_texture = texture_load("assets/models/pavlov/roughness.ppm"),
    shader = shader
  }
  sky_material := Material{
    is_valid = true,
    shader = sky_shader
  }

  // shadowmap_material = Material{
  //   is_valid = true,
  //   shader = shadowmap_shader
  // }
  // renderer.shadowmap_material = shadowmap_material

  glfw.SetWindowRefreshCallback(GlfwWindow, window_refresh)

  light_mesh := mesh_make_cube(default_material, {10, 10, 10})  

  cube_mesh := mesh_make_cube(default_material, {0, 0, 0})
  cube_mesh.model_matrix = translation_matrix({1, 0, 1})
  cube_mesh.model_matrix *= scale_matrix({1, 0.8, 1})

  obj_mesh := asset_loader_obj_mesh("assets/models/pavlov.obj", angel_material, true)
  scl := f32(0.02)
  obj_mesh.model_matrix *= translation_matrix({0, 0, 0})
  obj_mesh.model_matrix *= scale_matrix({scl, scl, scl})

  
  sky_mesh := asset_loader_obj_mesh("assets/models/skydome.obj", sky_material)
  sky_mesh.model_matrix *= scale_matrix({500, 500, 500})

  ground_mesh := asset_loader_obj_mesh("assets/models/ground_colors.obj", default_material)
  scl = 0.2
  ground_mesh.model_matrix *= scale_matrix({scl, scl, scl})
  ground_mesh.model_matrix *= translation_matrix({0, 0, 0})
  
  append(&scene.meshes, cube_mesh)
  append(&scene.meshes, sky_mesh)
  append(&scene.meshes, obj_mesh)
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
