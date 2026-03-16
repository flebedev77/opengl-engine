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
  back_framebuffer: Framebuffer,
  shadowmap_framebuffer: Framebuffer,
  shadowmap_material: Material,
  post_process_quad: Mesh,

  delta_time: f32
}

scene_init :: proc(scene: ^Scene, renderer: ^Renderer) {
  player_init(&scene.player)
  scene.delta_time = 16.666;

  renderer_init(renderer, scene)

  framebuffer_init(&scene.back_framebuffer, {1920, 1080}, .COLOR_DEPTH_AND_NORMAL)

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

  // TODO: All the rendering code should be moved to the renderer
  scene.renderer.bound_framebuffer = scene.shadowmap_framebuffer
  scene.renderer.bound_framebuffer.size = {4096, 4096}
  scene_render(scene, scene.shadowmap_material)

  scene.renderer.bound_framebuffer = scene.back_framebuffer
  // scene.renderer.bound_framebuffer = scene.default_framebuffer
  // scene.renderer.bound_framebuffer.size = {FrameBuffer.w, FrameBuffer.h}
  scene_render(scene)

  scene.renderer.bound_framebuffer = scene.default_framebuffer
  scene.renderer.bound_framebuffer.size = {FrameBuffer.w, FrameBuffer.h}
  render_begin(scene.renderer)
  gl.ActiveTexture(gl.TEXTURE2)
  gl.BindTexture(gl.TEXTURE_2D, scene.back_framebuffer.color_texture)
  gl.ActiveTexture(gl.TEXTURE3)
  gl.BindTexture(gl.TEXTURE_2D, scene.back_framebuffer.depth_texture)
  gl.ActiveTexture(gl.TEXTURE4)
  gl.BindTexture(gl.TEXTURE_2D, scene.back_framebuffer.normal_texture)
  render_mesh(scene.renderer, &scene.post_process_quad) 

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
