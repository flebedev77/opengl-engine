package main
import "base:runtime"
import "core:fmt"
import "core:time"
import "vendor:glfw"
import gl "vendor:OpenGL"

// TODO: Move all constants to a .ini file
WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

MIN_WINDOW_WIDTH :: 600
MIN_WINDOW_HEIGHT :: 480

GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 5

PLAYER_WALK_SPEED :: 2.0001
PLAYER_LOOK_SENSITIVITY :: Vec2{0.0001, 0.0002}

EPSILON : f32 : 0.0001
SIMULATION_AIR_DENSITY : f32 : 1.225

LOAD_WORLD :: true // Gives an ability to not waste time loading the world
 //for faster load times if testing other aspects

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

  glfw.SetWindowRefreshCallback(GlfwWindow, window_refresh)

  for glfw.WindowShouldClose(GlfwWindow) == false {

    // fmt.printfln("DT: %f", delta_time)

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
