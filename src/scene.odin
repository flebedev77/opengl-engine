package main
import "core:fmt"
import "vendor:glfw"
import gl "vendor:OpenGL"

Scene :: struct {
  camera: Camera,
  player: Player,
  mouse: Mouse,
  meshes: [dynamic]Mesh,
  renderer: ^Renderer,
  delta_time: f32
}

scene_init :: proc(scene: ^Scene, renderer: ^Renderer) {
  platform_init(scene)
  renderer_init(renderer, scene)
  player_init(scene, &scene.player)
  scene.delta_time = 16.666;

  // scene.post_process_quad = mesh_make_quad()
}

scene_update :: proc(scene: ^Scene) {
  {
    // TODO: factor out to windowing layer
    mx, my := glfw.GetCursorPos(GlfwWindow)

    scene.mouse.previous_position = scene.mouse.current_position
    scene.mouse.current_position = {f32(mx), f32(my)}
    scene.mouse.delta_position = scene.mouse.current_position - scene.mouse.previous_position
  }

  renderer_render(scene.renderer)

  camera_update(&scene.camera)
  player_update(scene, &scene.player)

  scene.mouse.scroll = 0
}

scene_delete :: proc(scene: ^Scene, verbose := false) {
  if verbose {
    fmt.printfln("Unloading meshes")
  }

  for mesh in scene.meshes {
    shader_delete(mesh.material.shader)
    mesh_delete(mesh)
  }
  delete(scene.meshes)
}
