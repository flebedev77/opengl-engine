package main
import "core:fmt"
import "vendor:glfw"

Scene :: struct {
  camera: Camera,
  player: Player,
  mouse: Mouse,
  meshes: [dynamic]Mesh,
  renderer: ^Renderer,

  shadowmap_shader: Shader,

  delta_time: f32
}

scene_init :: proc(scene: ^Scene) {
  player_init(&scene.player)
  scene.delta_time = 16.666;
}

scene_update :: proc(scene: ^Scene) {
  {
    mx, my := glfw.GetCursorPos(GlfwWindow)

    scene.mouse.previous_position = scene.mouse.current_position
    scene.mouse.current_position = {f32(mx), f32(my)}
    scene.mouse.delta_position = scene.mouse.current_position - scene.mouse.previous_position
  }

  scene_render(scene)

  camera_update(&scene.camera)
  player_update(scene, &scene.player)
}

scene_render :: proc(scene: ^Scene) {
  for &mesh in scene.meshes {
    render_mesh(scene.renderer, &mesh)
  }
}
