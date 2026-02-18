package main
import "base:runtime"
import "core:fmt"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

import "core:math/linalg"
import "core:math"

// TODO: Move all constants to a .ini file
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

MIN_WINDOW_WIDTH :: 600
MIN_WINDOW_HEIGHT :: 480

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

PLAYER_WALK_SPEED :: 0.03
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
  previous_position,
  current_position,
  delta_position: Vec2
}
mouse: Mouse

player: Player

camera: Camera

main :: proc() {
  player_init(&player)
  defer glfw.Terminate()

  assert(glfw.Init() == true)

  glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_VERSION_MAJOR)
  glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_VERSION_MINOR)

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

  gl.Viewport(0, 0, FrameBuffer.w, FrameBuffer.h)



  shader := shader_compileprogram(
                    cstring(#load("../assets/shaders/frag.glsl")),
                    cstring(#load("../assets/shaders/vert.glsl")),
                    .THREE_DIMENSIONAL
                   )
  defer gl.DeleteProgram(shader.program)

  shadowmap_shader := shader_compileprogram(
                    cstring(#load("../assets/shaders/shadowmap_frag.glsl")),
                    cstring(#load("../assets/shaders/shadowmap_vert.glsl")),
                    .SHADOWMAP
                   )
  defer gl.DeleteProgram(shadowmap_shader.program)

  shadowmap_width, shadowmap_height: i32 = 1024, 1024
  shadowmap_framebuffer, shadowmap_texture: u32
  gl.GenTextures(1, &shadowmap_texture)
  gl.BindTexture(gl.TEXTURE_2D, shadowmap_texture)
  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, shadowmap_width, shadowmap_height, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

  gl.GenFramebuffers(1, &shadowmap_framebuffer)
  gl.BindFramebuffer(gl.FRAMEBUFFER, shadowmap_framebuffer)
  gl.DrawBuffer(gl.NONE)
  gl.ReadBuffer(gl.NONE)
  gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, shadowmap_texture, 0)
  if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
    fmt.printfln("Shadow framebuffer not complete!")
    fmt.printfln("%d", gl.CheckFramebufferStatus(gl.FRAMEBUFFER))
  }
  gl.BindFramebuffer(gl.FRAMEBUFFER, 0)


  assets_texture := texture_load("assets/textures/box_placeholder.ppm")

  glfw.SetWindowRefreshCallback(GlfwWindow, window_refresh)

  gl.Enable(gl.DEPTH_TEST)
  gl.Enable(gl.FRAMEBUFFER_SRGB); 

  mx, my := glfw.GetCursorPos(GlfwWindow)
  mouse.current_position = {f32(mx), f32(my)}

  cube_mesh := mesh_make_cube(shader, {0, -(0.8 - 0.5), 0})
  defer mesh_delete(cube_mesh)

  grid: Grid
  grid_init(&grid, 5, 5, {-2.5, -0.8, -2.5}, shader)
  defer grid_delete(grid)

  light_mesh := mesh_make_cube(shader, {10, 10, 10})  
  defer mesh_delete(light_mesh)

  obj_pos, obj_uv, obj_nor, obj_ind := obj_parse("assets/monkey.obj")
  obj_mesh: Mesh
  mesh_init(&obj_mesh, obj_pos, obj_uv, obj_nor, obj_ind, shader)
  scl := f32(0.3)
  obj_mesh.model_matrix *= scale_matrix({scl, scl, scl})
  obj_mesh.model_matrix *= translation_matrix({0, 0.3, 0})

  delete(obj_pos)
  delete(obj_uv)
  delete(obj_nor)
  delete(obj_ind)

  for glfw.WindowShouldClose(GlfwWindow) == false {
    current_time := f64(time.now()._nsec)
    delta_time := f32((current_time - prev_time) / f64(time.Millisecond))
    prev_time = current_time
    time_since_start := f32((current_time - start_time) / f64(time.Millisecond))


    mouse.previous_position = mouse.current_position
    mx, my = glfw.GetCursorPos(GlfwWindow)
    mouse.current_position = {f32(mx), f32(my)}
    mouse.delta_position = mouse.current_position - mouse.previous_position
    // fmt.printfln("%f", mouse.delta_position.y)

    // cube_mesh.model_matrix *= rotation_matrix_y(delta_time * 0.001)
    // model_matrix *= translation_matrix({0, 0, f32(math.sin(time_since_start*0.00001))*0.1})
    gl.Viewport(0, 0, shadowmap_width, shadowmap_height)
    gl.BindFramebuffer(gl.FRAMEBUFFER, shadowmap_framebuffer)
    gl.Clear(gl.DEPTH_BUFFER_BIT)
    // gl.BindTexture(gl.TEXTURE_2D, shadowmap_texture)
    light_viewmatrix: Mat4 = linalg.matrix4_look_at_f32({5, 5, 5}, {4, 4, 4}, {0, 1, 0})
    light_projmatrix: Mat4 = linalg.matrix4_perspective_f32(
      90 * math.PI / 180,
      f32(FrameBuffer.w) / f32(FrameBuffer.h), 
      2, 5)
    light_projmatrix = orthographic_projection_matrix(-1, 1, 1, -1, 0.1, 10)

    // fmt.printfln("%d", shadowmap_shader.parameters)
    gl.UseProgram(shadowmap_shader.program)
    gl.UniformMatrix4fv(shadowmap_shader.parameters.view_matrix_location, 1, gl.FALSE, &light_viewmatrix[0][0])
    gl.UniformMatrix4fv(shadowmap_shader.parameters.projection_matrix_location, 1, gl.FALSE, &light_projmatrix[0][0])
    // gl.UniformMatrix4fv(shadowmap_shader.parameters.view_matrix_location, 1, gl.FALSE, &player.viewmatrix[0][0])
    // gl.UniformMatrix4fv(shadowmap_shader.parameters.projection_matrix_location, 1, gl.FALSE, &camera.projection_matrix[0][0])
    grid_draw(grid, camera, shadowmap_shader)
    mesh_draw(obj_mesh, shadowmap_shader)


    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)


    // gl.CullFace(gl.BACK)
    gl.Viewport(0, 0, FrameBuffer.w, FrameBuffer.h)
    {
      cube_mesh.shader.parameters.view_matrix = camera.view_matrix
      cube_mesh.shader.parameters.camera_position = player.position
      cube_mesh.shader.parameters.projection_matrix = camera.projection_matrix
      cube_mesh.shader.parameters.tint = {0, 0.4, 0.6}

      light_mesh.shader.parameters.view_matrix = camera.view_matrix
      light_mesh.shader.parameters.camera_position = player.position
      light_mesh.shader.parameters.projection_matrix = camera.projection_matrix
      light_mesh.shader.parameters.tint = {0, 0.4, 0.6}

      obj_mesh.shader.parameters.view_matrix = camera.view_matrix
      obj_mesh.shader.parameters.camera_position = player.position
      obj_mesh.shader.parameters.projection_matrix = camera.projection_matrix
      obj_mesh.shader.parameters.tint = {0.9, 0.1, 0.1}
      obj_mesh.model_matrix *= rotation_matrix_y(delta_time * 0.001)
      obj_mesh.model_matrix *= translation_matrix({0, math.sin(time_since_start * 0.001) * 0.007, 0})

      camera_update(&camera)
      window_render()
      grid_draw(grid, camera)
      // mesh_draw(cube_mesh)
      mesh_draw(light_mesh)
      mesh_draw(obj_mesh)
      // fmt.printfln("%d", shader.parameters.model_matrix)
    }


    if glfw.GetKey(GlfwWindow, glfw.KEY_ESCAPE) > 0 {
      break
    }


    player_update(&player, delta_time)

    glfw.SwapBuffers(GlfwWindow)
    glfw.PollEvents()
  }

}

window_render :: proc() {
  gl.ClearColor(0.0, 0.0, 0.0, 1.0)
  gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

  // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, cast(rawptr)(cast(uintptr)0))
}

window_refresh :: proc "c" (window: glfw.WindowHandle) {
  context = runtime.default_context()
  update_framebuffer()  
}

update_framebuffer :: proc() {
  FrameBuffer.w, FrameBuffer.h = glfw.GetFramebufferSize(GlfwWindow)
  gl.Viewport(0, 0, FrameBuffer.w, FrameBuffer.h)
  fmt.printfln("Working with framebuffer %d %d", FrameBuffer.w, FrameBuffer.h)
}
