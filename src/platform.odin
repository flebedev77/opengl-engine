package main;
import "vendor:glfw"

psc: ^Scene

platform_scroll_callback :: proc "c" (window: glfw.WindowHandle, xscroll, yscroll: f64) {
  psc.mouse.scroll += f32(yscroll)
}

platform_init :: proc(scene: ^Scene) {
  psc = scene
  glfw.SetScrollCallback(GlfwWindow, platform_scroll_callback)
}
