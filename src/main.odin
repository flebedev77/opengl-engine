package main
import "base:runtime"
import "core:fmt"
import "core:time"
import "core:math/linalg"
import "core:math"
import "vendor:glfw"
import gl "vendor:OpenGL"
import stb "vendor:stb/image"

// TODO: Move all constants to a .ini file
WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

MIN_WINDOW_WIDTH :: 600
MIN_WINDOW_HEIGHT :: 480

GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

PLAYER_WALK_SPEED :: 0.02
PLAYER_LOOK_SENSITIVITY :: Vec2{0.0001, 0.0002}

VAO :: distinct u32
VBO :: distinct u32
Shader :: distinct u32

IRect :: struct {
  x, y, w, h: i32
}

FrameBuffer: IRect
GlfwWindow: glfw.WindowHandle


start_time := f64(time.now()._nsec)
prev_time := f64(start_time)

Mouse :: struct {
  previous_position,
  current_position,
  delta_position: Vec2
}
mouse: Mouse

player: Player

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
  update_framebuffer()

  gl.Viewport(0, 0, FrameBuffer.w, FrameBuffer.h)

  // vertices: []f32 = {
  //   -0.5, -0.5,
  //   0.0, 0.5,
  //   0.5, -0.5
  // }
  //
  // indices: []u32 = {
  //   0, 1, 2
  // }

  vertices: []f32 = {
    0, 0,
    0, 1,
    1, 0,
    1, 1
  }
  // uvs: []f32 = {
  //   0, 0  
  // }
  indices: []u32 = {
    0, 1, 2,
    1, 2, 3
  }

  model_matrix := matrix[4, 4]f32{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, -0.2,
    0, 0, 0, 1
  }

  view_matrix := translation_matrix({0, 0, -1})//identity_matrix()

  player_position := Vec3{0, 0, 0}

  // projection_matrix := perspective_projection_matrix(WINDOW_WIDTH / WINDOW_HEIGHT, 30, 1, 10)
  projection_matrix := linalg.matrix4_perspective_f32(40 * math.PI / 180, WINDOW_WIDTH / WINDOW_HEIGHT, 0.01, 1000)

  shader_program := compile_shaderprogram(
                    cstring(#load("../assets/frag.glsl")),
                    cstring(#load("../assets/vert.glsl"))
                   )
  gl.UseProgram(cast(u32)shader_program)
  defer gl.DeleteProgram(cast(u32)shader_program)

  shader_transform_matrix_location := gl.GetUniformLocation(cast(u32)shader_program, "model_matrix")
  gl.UniformMatrix4fv(shader_transform_matrix_location, 1, gl.FALSE, &model_matrix[0,0])

  shader_projection_matrix_location := gl.GetUniformLocation(cast(u32)shader_program, "projection_matrix")
  gl.UniformMatrix4fv(shader_projection_matrix_location, 1, gl.FALSE, &projection_matrix[0,0])

  shader_view_matrix_location := gl.GetUniformLocation(cast(u32)shader_program, "view_matrix")
  gl.UniformMatrix4fv(shader_view_matrix_location, 1, gl.FALSE, &view_matrix[0,0])

  triangle_vao: VAO
  gl.GenVertexArrays(1, cast(^u32)&triangle_vao)
  gl.BindVertexArray(cast(u32)triangle_vao)

  position_buffer: VBO
  gl.GenBuffers(1, cast(^u32)&position_buffer)
  gl.BindBuffer(gl.ARRAY_BUFFER, cast(u32)position_buffer)
  gl.BufferData(gl.ARRAY_BUFFER, len(vertices) * size_of(f32), &vertices[0], gl.STATIC_DRAW)

  index_buffer: VBO
  gl.GenBuffers(1, cast(^u32)&index_buffer)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, cast(u32)index_buffer)
  gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), &indices[0], gl.STATIC_DRAW)

  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), cast(uintptr)0)

  stone_image_mem := #load("../assets/stone.png")
  img_w, img_h, channels: i32
  image_data := stb.load_from_memory(&stone_image_mem[0], i32(len(stone_image_mem)), &img_w, &img_h, &channels, 0)
  fmt.printfln("%d %d %d", img_w, img_h, channels)

  texture: u32
  gl.GenTextures(1, &texture)
  gl.BindTexture(gl.TEXTURE_2D, texture)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, img_w, img_h, 0, gl.RGBA, gl.UNSIGNED_BYTE, &image_data[0])
  gl.GenerateMipmap(gl.TEXTURE_2D)

  stb.image_free(image_data)



  glfw.SetWindowRefreshCallback(GlfwWindow, window_refresh)

  gl.Enable(gl.DEPTH_TEST)

  mx, my := glfw.GetCursorPos(GlfwWindow)
  mouse.current_position = {f32(mx), f32(my)}

  wall_mesh := Mesh{}
  mesh_init(&wall_mesh, vertices, indices, 0)

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

    // model_matrix *= rotation_matrix_y(delta_time * 0.001)
    // model_matrix *= translation_matrix({0, 0, f32(math.sin(time_since_start*0.00001))*0.1})
    gl.UniformMatrix4fv(shader_transform_matrix_location, 1, gl.FALSE, &model_matrix[0,0])

    // view_matrix = lookat_matrix({-f32(mouse_x/300), f32(mouse_y/300), 0}, {0, 0, -3}, {0, 1, 0})
    // view_matrix = lin.matrix4_look_at_f32({0, 1, 0}, {0, 0, -3}, {0, 1, 0}, false)
    //translation_matrix({0, f32(mouse_y/400) - 0.5, f32(mouse_x/700) + 1})
    // view_matrix = lookat_matrix({0, 0, 0}, {0, 0, -1}, {0, 1, 0})


    projection_matrix := linalg.matrix4_perspective_f32(90 * math.PI / 180, f32(FrameBuffer.w) / f32(FrameBuffer.h), 0.1, 1000)
    gl.UniformMatrix4fv(shader_projection_matrix_location, 1, gl.FALSE, &projection_matrix[0,0])

    gl.BindVertexArray(cast(u32)triangle_vao)
    window_render()
    mesh_draw(wall_mesh)


    gl.UniformMatrix4fv(shader_view_matrix_location, 1, gl.FALSE, &player.viewmatrix[0,0])


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

compile_shadermodule :: proc(source: cstring, type: u32) -> u32 {
  source := source
  shader := gl.CreateShader(type)
  gl.ShaderSource(shader, 1, &source, nil)
  gl.CompileShader(shader)

  // TODO: logging
  success: i32
  gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
  assert(success == i32(gl.TRUE))

  return shader
}

compile_shaderprogram :: proc(fragmentSource: cstring, vertexSource: cstring) -> Shader {
  shader_program := gl.CreateProgram()
  fragment_shader := compile_shadermodule(fragmentSource, gl.FRAGMENT_SHADER)
  vertex_shader := compile_shadermodule(vertexSource, gl.VERTEX_SHADER)

  gl.AttachShader(shader_program, fragment_shader)
  gl.AttachShader(shader_program, vertex_shader)
  gl.LinkProgram(shader_program)
  gl.DeleteShader(fragment_shader)
  gl.DeleteShader(vertex_shader)

  return cast(Shader)shader_program
}
