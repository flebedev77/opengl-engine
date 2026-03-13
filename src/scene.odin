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
  default_framebuffer: Framebuffer,
  back_buffer: Framebuffer,
  shadowmap_framebuffer: Framebuffer,
  shadowmap_material: Material,

  delta_time: f32
}

scene_init :: proc(scene: ^Scene, renderer: ^Renderer) {
  player_init(&scene.player)
  scene.delta_time = 16.666;

  renderer_init(renderer, scene)
}

scene_update :: proc(scene: ^Scene) {
  {
    // NOTE: factor out to windowing layer
    mx, my := glfw.GetCursorPos(GlfwWindow)

    scene.mouse.previous_position = scene.mouse.current_position
    scene.mouse.current_position = {f32(mx), f32(my)}
    scene.mouse.delta_position = scene.mouse.current_position - scene.mouse.previous_position
  }

  scene.renderer.bound_framebuffer = scene.shadowmap_framebuffer
  scene.renderer.bound_framebuffer.size = {4096, 4096}
  scene_render(scene, scene.shadowmap_material)

  scene.renderer.bound_framebuffer = scene.back_buffer
  scene.renderer.bound_framebuffer.size = {FrameBuffer.w, FrameBuffer.h}
  scene_render(scene)

  camera_update(&scene.camera)
  player_update(scene, &scene.player)
}

scene_render :: proc(scene: ^Scene, material_override: Material = {}) {
  render_begin(scene.renderer)
  for &mesh in scene.meshes {
    render_mesh(scene.renderer, &mesh, material_override)
  }
}

scene_delete :: proc(scene: ^Scene, verbose := false) {
  if verbose {
    fmt.printfln("Unloading meshes")
  }

  for mesh in scene.meshes {
    mesh_delete(mesh)
  }
  delete(scene.meshes)
}
