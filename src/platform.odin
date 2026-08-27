package main;
import "core:fmt"
import "vendor:glfw"
import "base:runtime"

@(private="file")
psc: ^Scene


platform_scroll_callback :: proc "c" (window: glfw.WindowHandle, xscroll, yscroll: f64) {
  psc.mouse.scroll += f32(yscroll)
}

platform_key_callback :: proc "c" (
  window: glfw.WindowHandle,
  key,
  scancode,
  action,
  mods: i32
) {
  context = runtime.default_context()
  // fmt.printfln("key %d scancode %d action %d mods %d", key, scancode, action, mods)
  psc.keys[int(key)] = (action == glfw.PRESS) ? true : (action == glfw.RELEASE) ? false : true
  psc.keys_pressed[int(key)] = (action == glfw.PRESS) ? true : (action == glfw.RELEASE) ? false : false
}

platform_key_down :: #force_inline proc(key: i32) -> bool { return psc.keys[int(key)] }
platform_key_up :: #force_inline proc(key: i32) -> bool { return !platform_key_down(key) }
platform_key_pressed :: #force_inline proc(key: i32) -> bool { return psc.keys_pressed[int(key)] }

platform_advance :: proc() {
  for key, &val in psc.keys_pressed {
    val = false
  }
}

platform_init :: proc(scene: ^Scene) {
  psc = scene
  glfw.SetScrollCallback(GlfwWindow, platform_scroll_callback)
  glfw.SetKeyCallback(GlfwWindow, platform_key_callback)
}
