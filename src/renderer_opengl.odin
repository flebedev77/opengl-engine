package main
import "core:os"
import "core:fmt"
import "core:math/linalg"
import "core:strings"
import stbi "vendor:stb/image"
import gl "vendor:OpenGL"

GpuID :: u32
UniformLocation :: i32

ShaderType :: enum {
  THREE_DIMENSIONAL, // Signifies that the shader should receive 3D related uniforms
  TWO_DIMENTIONAL,   // TODO
  SHADOWMAP
}

ShaderFlags :: enum {
  has_vertex_normals
}

ShaderParameters :: struct {
  metallic_strength_location,
  roughness_strength_location,
  screen_texture_location,
  ssao_texture_location,
  blur_texture_location,
  blur_amount_location,
  volumetrics_texture_location,
  depth_texture_location,
  normal_texture_location,
  albedo_texture_location,
  roughness_texture_location,
  shadowmap_texture_location,
  shadowmap_matrix_location,
  macroshadowmap_texture_location,
  macroshadowmap_matrix_location,
  blue_noise_texture_location,
  frame_number_location,
  uv_location,
  tint_location,
  light_position_location,
  camera_position_location,
  view_matrix_location,
  inv_view_matrix_location,
  inv_projection_matrix_location,
  projection_matrix_location,
  model_matrix_location: UniformLocation,

  shadowmap_matrix,
  macroshadowmap_matrix,
  view_matrix,
  inv_view_matrix,
  inv_projection_matrix,
  projection_matrix: Mat4,
  sun_position,
  camera_position: Vec3,
  frame_number: i32,
  blur_amount: int
}

Shader :: struct {
  program: GpuID,
  parameters: ShaderParameters,
  type: ShaderType,
  flags: bit_set[ShaderFlags],
  vertex_source_path,
  fragment_source_path: string
}

Material :: struct {
  is_valid: bool,
  roughness_texture,
  albedo_texture: GpuID,
  albedo_tint: Vec3,
  uv: Vec4,
  shader: Shader,
  roughness_strength,
  metallic_strength: f32
}

Mesh :: struct {
  vao,
  position_bufferobject,
  color_bufferobject,
  normal_bufferobject,
  uv_bufferobject,
  indice_bufferobject: GpuID,
  triangle_count,
  indice_count: i32,
  material: Material,
  model_matrix: Mat4 
}

Renderer :: struct {
  debug_renderer: DebugRenderer,
  scene: ^Scene,

  bound_framebuffer: Framebuffer,
  default_framebuffer: Framebuffer,

  prepass_framebuffer: Framebuffer,
  msaa_back_framebuffer: Framebuffer,
  back_framebuffer: Framebuffer,

  ssao_framebuffer: Framebuffer,
  volumetrics_framebuffer: Framebuffer,
  blur_framebuffer: Framebuffer,
  shadowmap_framebuffer: Framebuffer,
  macroshadowmap_framebuffer: Framebuffer,

  final_pass_material: Material,
  post_process_quad: Mesh,
  shadowmap_matrix: Mat4,
  macroshadowmap_matrix: Mat4,
  default_shader: Shader,
  sun_position: Vec3,

  reload_shaders: bool,
}

renderer_init :: proc(renderer: ^Renderer, scene: ^Scene) {
  renderer.sun_position = {10, 10, 10}

  gl.LineWidth(5.0)
  gl.Enable(gl.DEPTH_TEST)
  gl.Enable(gl.FRAMEBUFFER_SRGB)
  gl.Enable(gl.MULTISAMPLE)
  gl.Enable(gl.CULL_FACE)
  gl.CullFace(gl.BACK)
  gl.FrontFace(gl.CCW)

  debugrenderer_init(&renderer.debug_renderer)

  renderer.scene = scene
  scene.renderer = renderer

  // TODO: Make the resize on window change
  window_resolution := IVec2{WINDOW_WIDTH, WINDOW_HEIGHT}
  framebuffer_init(&renderer.prepass_framebuffer, window_resolution, {.NORMAL, .DEPTH}, "prepass", .THREE_DIMENSIONAL)
  framebuffer_init(&renderer.msaa_back_framebuffer, window_resolution, {.COLOR, .DEPTH}, "", .THREE_DIMENSIONAL, true, 8)
  framebuffer_init(&renderer.back_framebuffer, window_resolution, {.COLOR})
  framebuffer_init(&renderer.shadowmap_framebuffer, {4096, 4096}, {.DEPTH}, "shadowmap", .SHADOWMAP)
  framebuffer_init(&renderer.macroshadowmap_framebuffer, {4096, 4096}, {.DEPTH}, "shadowmap", .SHADOWMAP)

  effects_resolution_factor: f32 = 1.0/2.5
  effects_resolution := Vec2{WINDOW_WIDTH, WINDOW_HEIGHT} * effects_resolution_factor
  effects_resolution_int := IVec2{i32(effects_resolution.x), i32(effects_resolution.y)}
  fmt.printfln("Effects resolution %d (1/%d)", effects_resolution_int, i32(1 / effects_resolution_factor))
  framebuffer_init(&renderer.ssao_framebuffer, effects_resolution_int, {.RED}, "ssao", .TWO_DIMENTIONAL)
  framebuffer_init(&renderer.volumetrics_framebuffer, effects_resolution_int, {.COLOR}, "volumetric", .TWO_DIMENTIONAL)
  framebuffer_init(&renderer.blur_framebuffer, effects_resolution_int, {.COLOR}, "blur", .TWO_DIMENTIONAL)

  renderer.final_pass_material = asset_loader_material(0, 0, "post_process", .TWO_DIMENTIONAL)

  renderer.post_process_quad = mesh_make_quad(renderer.final_pass_material)

  renderer.default_shader = shader_compileprogram(
    cstring(#load("../assets/shaders/frag.glsl")),
    cstring(#load("../assets/shaders/vert.glsl")),
    .THREE_DIMENSIONAL,
    "./assets/shaders/frag.glsl",
    "./assets/shaders/vert.glsl"
  )
}

renderer_delete :: proc(renderer: ^Renderer) {
  gl.DeleteProgram(renderer.default_shader.program)
}

renderer_draw_meshes :: proc(renderer: ^Renderer, material_override: ^Material = {}) {
  player_render(renderer.scene, &renderer.scene.player, material_override)
  for &mesh in renderer.scene.meshes {
    render_mesh(renderer, &mesh, material_override)
  }
}

renderer_render :: proc(renderer: ^Renderer) {
  // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)// : GL_FILL); 

  // Shadowmap pass

  light_viewmatrix := linalg.matrix4_look_at_f32(
    renderer.scene.camera.position + linalg.normalize(renderer.sun_position) * 70, 
    renderer.scene.camera.position,
    {0, 1, 0}
  )
  lightmap_proj_size := f32(6)
  light_projmatrix := orthographic_projection_matrix(
    -lightmap_proj_size,
    lightmap_proj_size,
    lightmap_proj_size,
    -lightmap_proj_size,
    3, 2*70)
  macromap_proj_size := f32(500)
  light_macromap_projmatrix := orthographic_projection_matrix(
    -macromap_proj_size,
    macromap_proj_size,
    macromap_proj_size,
    -macromap_proj_size,
    3, 2*70
  )
  renderer.macroshadowmap_matrix = light_macromap_projmatrix * light_viewmatrix
  renderer.shadowmap_matrix = light_projmatrix * light_viewmatrix

  gl.Enable(gl.DEPTH_TEST)
  renderer_bind_and_clear_framebuffer(renderer, renderer.shadowmap_framebuffer)
  renderer_draw_meshes(renderer, &renderer.shadowmap_framebuffer.material)
  gl.ActiveTexture(gl.TEXTURE1)
  gl.BindTexture(gl.TEXTURE_2D, renderer.shadowmap_framebuffer.depth_texture)

  renderer.shadowmap_matrix = renderer.macroshadowmap_matrix
  renderer_bind_and_clear_framebuffer(renderer, renderer.macroshadowmap_framebuffer)
  renderer_draw_meshes(renderer, &renderer.shadowmap_framebuffer.material)
  gl.ActiveTexture(gl.TEXTURE7)
  gl.BindTexture(gl.TEXTURE_2D, renderer.macroshadowmap_framebuffer.depth_texture)

  renderer.shadowmap_matrix = light_projmatrix * light_viewmatrix


  // Prepass
  renderer_bind_and_clear_framebuffer(renderer, renderer.prepass_framebuffer)
  renderer_draw_meshes(renderer, &renderer.prepass_framebuffer.material)


  // MSAA forward pass
  // scene.renderer.back_framebuffer.size = {FrameBuffer.w, FrameBuffer.h}
  renderer_bind_and_clear_framebuffer(renderer, renderer.msaa_back_framebuffer)
  render_mesh(renderer, &renderer.scene.sky_mesh)
  renderer_draw_meshes(renderer)

  renderer.debug_renderer.shader.parameters.view_matrix = renderer.scene.camera.view_matrix
  renderer.debug_renderer.shader.parameters.projection_matrix = renderer.scene.camera.projection_matrix
  // debugrenderer_draw(&renderer.debug_renderer)

  framebuffer_blit(renderer.msaa_back_framebuffer, renderer.back_framebuffer)


  gl.Disable(gl.DEPTH_TEST)
  // Post processing passes
  gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL); 
  gl.ActiveTexture(gl.TEXTURE2)
  gl.BindTexture(gl.TEXTURE_2D, renderer.back_framebuffer.color_texture)
  gl.ActiveTexture(gl.TEXTURE3)
  gl.BindTexture(gl.TEXTURE_2D, renderer.prepass_framebuffer.depth_texture)
  gl.ActiveTexture(gl.TEXTURE4)
  gl.BindTexture(gl.TEXTURE_2D, renderer.prepass_framebuffer.normal_texture)
  gl.ActiveTexture(gl.TEXTURE5)
  gl.BindTexture(gl.TEXTURE_2D, renderer.ssao_framebuffer.red_texture)
  gl.ActiveTexture(gl.TEXTURE6)
  gl.BindTexture(gl.TEXTURE_2D, renderer.volumetrics_framebuffer.color_texture)

  // Volumetrics pass
  renderer_bind_and_clear_framebuffer(renderer, renderer.volumetrics_framebuffer)
  render_mesh(renderer, &renderer.post_process_quad, &renderer.volumetrics_framebuffer.material)

  gl.ActiveTexture(gl.TEXTURE5)
  gl.BindTexture(gl.TEXTURE_2D, renderer.volumetrics_framebuffer.color_texture)
  // Volumetrics blur pass
  renderer.blur_framebuffer.material.shader.parameters.blur_amount = 0
  renderer_bind_and_clear_framebuffer(renderer, renderer.blur_framebuffer)
  render_mesh(renderer, &renderer.post_process_quad, &renderer.blur_framebuffer.material)
  framebuffer_blit(renderer.blur_framebuffer, renderer.volumetrics_framebuffer)

  // SSAO
  renderer_bind_and_clear_framebuffer(renderer, renderer.ssao_framebuffer)
  render_mesh(renderer, &renderer.post_process_quad, &renderer.ssao_framebuffer.material)

  gl.ActiveTexture(gl.TEXTURE5)
  gl.BindTexture(gl.TEXTURE_2D, renderer.ssao_framebuffer.red_texture)
  // SSAO blur pass
  renderer.blur_framebuffer.material.shader.parameters.blur_amount = 4
  renderer_bind_and_clear_framebuffer(renderer, renderer.blur_framebuffer)
  render_mesh(renderer, &renderer.post_process_quad, &renderer.blur_framebuffer.material)
  framebuffer_blit(renderer.blur_framebuffer, renderer.ssao_framebuffer)

  

  // Final combination pass
  renderer.default_framebuffer.size = {FrameBuffer.w, FrameBuffer.h}
  renderer_bind_and_clear_framebuffer(renderer, renderer.default_framebuffer)
  render_mesh(renderer, &renderer.post_process_quad) 

  // renderer.debug_renderer.shader.parameters.view_matrix = renderer.scene.camera.view_matrix
  // renderer.debug_renderer.shader.parameters.projection_matrix = renderer.scene.camera.projection_matrix
  debugrenderer_draw(&renderer.debug_renderer)
  renderer.reload_shaders = false
  free_all(context.temp_allocator)
}

renderer_bind_and_clear_framebuffer :: proc(renderer: ^Renderer, framebuffer: Framebuffer) {
  renderer.bound_framebuffer = framebuffer
  gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer.framebuffer)
  gl.Viewport(0, 0,
    framebuffer.size.x,
    framebuffer.size.y
  )
  gl.Clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT)
}

render_mesh :: proc(renderer: ^Renderer, mesh: ^Mesh, material_override: ^Material = {}) {
  material_override := material_override

  mesh_material := &mesh.material
  if material_override != nil && material_override.is_valid {
    mesh_material = material_override
  }

  // Has the benefit of loading only the shaders required,
  // but may reload the same shader MULTIPLE times fix later
  if renderer.reload_shaders {
    fragment_filename := mesh_material.shader.fragment_source_path
    vertex_filename := mesh_material.shader.vertex_source_path
    new_fragment_source, fragment_load_success := 
    os.read_entire_file_from_filename(fragment_filename, context.temp_allocator)
    if fragment_load_success {
      new_vertex_source, vertex_load_success := 
      os.read_entire_file_from_filename(vertex_filename, context.temp_allocator)
      if vertex_load_success {
        frag_contents_cstring := strings.clone_to_cstring(string(new_fragment_source), context.temp_allocator)
        vert_contents_cstring := strings.clone_to_cstring(string(new_vertex_source), context.temp_allocator)
        mesh_material.shader.program = shader_compileprogram(
          frag_contents_cstring, 
          vert_contents_cstring,
          mesh_material.shader.type,
          vertex_filename,
          fragment_filename
        ).program
      }
    }
  }

  shader_parameters := &mesh_material.shader.parameters
  shader_parameters.macroshadowmap_matrix = renderer.macroshadowmap_matrix
  shader_parameters.shadowmap_matrix = renderer.shadowmap_matrix
  shader_parameters.view_matrix = renderer.scene.camera.view_matrix
  shader_parameters.projection_matrix = renderer.scene.camera.projection_matrix
  shader_parameters.inv_projection_matrix = renderer.scene.camera.inv_projection_matrix
  shader_parameters.inv_view_matrix = renderer.scene.camera.inv_view_matrix
  shader_parameters.camera_position = renderer.scene.camera.position
  shader_parameters.sun_position = renderer.sun_position
  shader_parameters.frame_number = renderer.scene.frame_number

  gl.ActiveTexture(gl.TEXTURE8)
  gl.BindTexture(gl.TEXTURE_2D, renderer.scene.resources.blue_noise_texture)

  mesh_draw(mesh^, material_override)
}

mesh_init :: proc(
  mesh: ^Mesh,
  vertex_positions: []f32,
  vertex_colors: []f32,
  vertex_uvs: []f32,
  vertex_normals: []f32,
  indices: []u32,
  material: Material
) {
  gl.GenVertexArrays(1, &mesh.vao)
  gl.BindVertexArray(mesh.vao)

  if len(vertex_positions) > 0 {
    gl.GenBuffers(1, &mesh.position_bufferobject)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.position_bufferobject)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertex_positions) * size_of(f32), &vertex_positions[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
  }

  if len(vertex_normals) == len(vertex_positions) &&
     len(vertex_normals) > 0 {
    gl.GenBuffers(1, &mesh.normal_bufferobject)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.normal_bufferobject)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertex_normals) * size_of(f32), &vertex_normals[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
  }

  if len(vertex_uvs) == (len(vertex_positions) / 3) * 2 &&
     len(vertex_uvs) > 0 {
    gl.GenBuffers(1, &mesh.uv_bufferobject)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.uv_bufferobject)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertex_uvs) * size_of(f32), &vertex_uvs[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), cast(uintptr)0)
  }

  if len(vertex_colors) == len(vertex_positions) &&
     len(vertex_colors) > 0 {
    gl.GenBuffers(1, &mesh.color_bufferobject)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.color_bufferobject)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertex_colors) * size_of(f32), &vertex_colors[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(3)
    gl.VertexAttribPointer(3, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
  }

  if len(indices) > 0 {
    gl.GenBuffers(1, &mesh.indice_bufferobject)
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.indice_bufferobject)
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(f32), &indices[0], gl.STATIC_DRAW)
  }

  gl.BindVertexArray(0)

  mesh.model_matrix = identity_matrix()
  mesh.material = material
  mesh.indice_count = i32(len(indices))
  mesh.triangle_count = mesh.indice_count / 3;
  // fmt.printfln("VAO  %d\nVBO  %d\nEBO  %d\nTRIS %d", mesh.vao, mesh.position_bufferobject, mesh.indice_bufferobject, len(indices))
}

mesh_draw :: proc(mesh: Mesh, material_override: ^Material = {}) {
  mesh := mesh
  material := mesh.material

  if material.is_valid && (material_override == nil || !material_override.is_valid) {
    gl.UseProgram(material.shader.program)
  } else if material_override.is_valid {
    gl.UseProgram(material_override.shader.program)
    material = material_override^
  }
  shader := material.shader

  gl.UniformMatrix4fv(shader.parameters.inv_projection_matrix_location, 1, gl.FALSE, &shader.parameters.inv_projection_matrix[0, 0])
  gl.UniformMatrix4fv(shader.parameters.projection_matrix_location, 1, gl.FALSE, &shader.parameters.projection_matrix[0,0])
  gl.UniformMatrix4fv(shader.parameters.view_matrix_location, 1, gl.FALSE, &shader.parameters.view_matrix[0,0])
  gl.UniformMatrix4fv(shader.parameters.inv_view_matrix_location, 1, gl.FALSE, &shader.parameters.inv_view_matrix[0,0])
  gl.UniformMatrix4fv(shader.parameters.shadowmap_matrix_location, 1, gl.FALSE, &shader.parameters.shadowmap_matrix[0,0])
  gl.UniformMatrix4fv(shader.parameters.macroshadowmap_matrix_location, 1, gl.FALSE, &shader.parameters.macroshadowmap_matrix[0,0])

  gl.Uniform3fv(shader.parameters.light_position_location, 1, &shader.parameters.sun_position[0])

  gl.Uniform1i(shader.parameters.shadowmap_texture_location, 1)
  gl.Uniform1i(shader.parameters.macroshadowmap_texture_location, 7)

  gl.Uniform1i(shader.parameters.frame_number_location, shader.parameters.frame_number)

  if material.shader.type == .TWO_DIMENTIONAL {
    gl.BindVertexArray(mesh.vao)
    gl.Uniform1i(shader.parameters.screen_texture_location, 2)
    gl.Uniform1i(shader.parameters.depth_texture_location, 3)
    gl.Uniform1i(shader.parameters.normal_texture_location, 4)
    gl.Uniform1i(shader.parameters.ssao_texture_location, 5)
    gl.Uniform1i(shader.parameters.blur_texture_location, 5)
    gl.Uniform1i(shader.parameters.volumetrics_texture_location, 6)
    gl.Uniform1i(shader.parameters.blue_noise_texture_location, 8)
    gl.Uniform1i(shader.parameters.blur_amount_location, i32(shader.parameters.blur_amount))
    gl.DrawElements(gl.TRIANGLE_STRIP, 4, gl.UNSIGNED_INT, cast(rawptr)(cast(uintptr)0))
  } else {
    gl.Uniform3fv(shader.parameters.camera_position_location, 1, &shader.parameters.camera_position[0])

    if material.albedo_tint == {0, 0, 0} {
      material.albedo_tint = {1, 1, 1}
    }
    gl.Uniform3fv(shader.parameters.tint_location, 1, &material.albedo_tint[0])

    if material.uv == {0, 0, 0, 0} {
      material.uv = {0, 0, 1, 1}
    }
    gl.Uniform4fv(shader.parameters.uv_location, 1, &material.uv[0]);

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, material.albedo_texture)
    gl.ActiveTexture(gl.TEXTURE2)
    gl.BindTexture(gl.TEXTURE_2D, material.roughness_texture)

    gl.Uniform1i(shader.parameters.albedo_texture_location, 0)
    gl.Uniform1i(shader.parameters.roughness_texture_location, 2)

    gl.Uniform1f(shader.parameters.roughness_strength_location, material.roughness_strength)
    gl.Uniform1f(shader.parameters.metallic_strength_location, material.metallic_strength)

    gl.UniformMatrix4fv(shader.parameters.model_matrix_location, 1, gl.FALSE, &mesh.model_matrix[0,0])
    // gl.UniformMatrix4fv(shader.parameters.projection_matrix_location, 1, gl.FALSE, &shader.parameters.projection_matrix[0,0])
    // gl.UniformMatrix4fv(shader.parameters.view_matrix_location, 1, gl.FALSE, &shader.parameters.view_matrix[0,0])
    // gl.UniformMatrix4fv(shader.parameters.shadowmap_matrix_location, 1, gl.FALSE, &shader.parameters.shadowmap_matrix[0,0])

    gl.BindVertexArray(mesh.vao)

    gl.DrawElements(gl.TRIANGLES, mesh.triangle_count * 3, gl.UNSIGNED_INT, cast(rawptr)(cast(uintptr)0))
  }
}

mesh_delete :: proc(mesh: Mesh) {
  mesh := mesh
  gl.DeleteBuffers(1, &mesh.position_bufferobject)
  gl.DeleteBuffers(1, &mesh.indice_bufferobject)
  gl.DeleteVertexArrays(1, &mesh.vao)
}


shader_compilemodule :: proc(source: cstring, type: u32, filename := "unknown") -> GpuID {
  source := source
  shader := gl.CreateShader(type)
  gl.ShaderSource(shader, 1, &source, nil)
  gl.CompileShader(shader)

  success: i32
  gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
  if success != i32(gl.TRUE) {
    shader_error_log: [512]u8
    len: i32
    gl.GetShaderInfoLog(shader, 512, &len, &shader_error_log[0])
    fmt.eprintfln("Shader %s compilation error in %s: %s",
        (type == gl.FRAGMENT_SHADER) ? "fragment" : "vertex",
        filename,
        shader_error_log[:len]
    )
  } else {
    fmt.printfln("Shader %s %s successfully loaded", 
        (type == gl.FRAGMENT_SHADER) ? "fragment" : "vertex  ",
        filename
    )
  }

  return shader
}

shader_compileprogram :: proc(
  fragmentSource: cstring,
  vertexSource: cstring,
  type: ShaderType,
  fragment_filename := "unknown",
  vertex_filename := "unknown"
) -> Shader {
  shader_program := gl.CreateProgram()
  fragment_shader := shader_compilemodule(fragmentSource, gl.FRAGMENT_SHADER, fragment_filename)
  vertex_shader := shader_compilemodule(vertexSource, gl.VERTEX_SHADER, vertex_filename)

  gl.AttachShader(shader_program, fragment_shader)
  gl.AttachShader(shader_program, vertex_shader)
  gl.LinkProgram(shader_program)
  gl.DeleteShader(fragment_shader)
  gl.DeleteShader(vertex_shader)

  shader: Shader
  shader.program = shader_program
  shader.type = type
  shader.vertex_source_path = vertex_filename
  shader.fragment_source_path = fragment_filename
  shader_init(&shader)
  
  return shader
}

shader_init :: proc(shader: ^Shader) {
  shader.parameters.shadowmap_matrix_location = gl.GetUniformLocation(shader.program, "shadowmap_matrix")
  shader.parameters.macroshadowmap_texture_location = gl.GetUniformLocation(shader.program, "macroshadowmap_texture")
  shader.parameters.macroshadowmap_matrix_location = gl.GetUniformLocation(shader.program, "macroshadowmap_matrix")
  shader.parameters.inv_view_matrix_location = gl.GetUniformLocation(shader.program, "inv_view_matrix")
  shader.parameters.inv_projection_matrix_location = gl.GetUniformLocation(shader.program, "inv_projection_matrix")
  shader.parameters.projection_matrix_location = gl.GetUniformLocation(shader.program, "projection_matrix")
  shader.parameters.frame_number_location = gl.GetUniformLocation(shader.program, "frame_number")
  // switch shader.type {
  //   case .THREE_DIMENSIONAL:
      shader.parameters.uv_location = gl.GetUniformLocation(shader.program, "uv");
      shader.parameters.tint_location = gl.GetUniformLocation(shader.program, "tint")
      shader.parameters.albedo_texture_location = gl.GetUniformLocation(shader.program, "albedo_texture")
      shader.parameters.shadowmap_texture_location = gl.GetUniformLocation(shader.program, "shadowmap_texture")
      shader.parameters.light_position_location = gl.GetUniformLocation(shader.program, "light_pos")
      shader.parameters.camera_position_location = gl.GetUniformLocation(shader.program, "camera_pos")
      shader.parameters.model_matrix_location = gl.GetUniformLocation(shader.program, "model_matrix")
      shader.parameters.view_matrix_location = gl.GetUniformLocation(shader.program, "view_matrix")
      shader.parameters.roughness_texture_location = gl.GetUniformLocation(shader.program, "roughness_texture")
      shader.parameters.roughness_strength_location = gl.GetUniformLocation(shader.program, "roughness_strength")
      shader.parameters.metallic_strength_location = gl.GetUniformLocation(shader.program, "metallic_strength")
    // case .TWO_DIMENTIONAL:
      shader.parameters.blue_noise_texture_location = gl.GetUniformLocation(shader.program, "blue_noise_texture")
      shader.parameters.volumetrics_texture_location = gl.GetUniformLocation(shader.program, "volumetrics_texture")
      shader.parameters.screen_texture_location = gl.GetUniformLocation(shader.program, "screen_texture")
      shader.parameters.ssao_texture_location = gl.GetUniformLocation(shader.program, "ssao_texture")
      shader.parameters.depth_texture_location = gl.GetUniformLocation(shader.program, "depth_texture")
      shader.parameters.normal_texture_location = gl.GetUniformLocation(shader.program, "normal_texture")
      shader.parameters.blur_texture_location = gl.GetUniformLocation(shader.program, "blur_texture");
      shader.parameters.blur_amount_location = gl.GetUniformLocation(shader.program, "blur_size")
    // case .SHADOWMAP:
      shader.parameters.model_matrix_location = gl.GetUniformLocation(shader.program, "model_matrix")
      shader.parameters.view_matrix_location = gl.GetUniformLocation(shader.program, "view_matrix")
      shader.parameters.projection_matrix_location = gl.GetUniformLocation(shader.program, "projection_matrix")
  // }
}

shader_delete :: proc(shader: Shader) {
  gl.DeleteProgram(shader.program)
}

renderer_info :: proc() {
  max_vertex_attributes: i32
  gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &max_vertex_attributes)
  fmt.printfln("MAX VERTEX ATTRIBUTES %d", max_vertex_attributes)

  max_fragment_attributes: i32
  gl.GetIntegerv(gl.MAX_FRAGMENT_INPUT_COMPONENTS, &max_fragment_attributes)
  fmt.printfln("MAX FRAGMENT ATTRIBUTES %d", max_fragment_attributes)

  max_texture_units: i32
  gl.GetIntegerv(gl.MAX_TEXTURE_UNITS, &max_texture_units)
  fmt.printfln("MAX TEXTURE UNITS %d", max_texture_units)

  fmt.printfln("OpenGL version  : %s", gl.GetString(gl.VERSION))
  fmt.printfln("OpenGL renderer : %s", gl.GetString(gl.RENDERER))
  fmt.printfln("OpenGL vendor   : %s", gl.GetString(gl.VENDOR))
}

texture_load :: proc(filepath: string) -> u32 {
  contents := os.read_entire_file(filepath) or_else nil
  if contents == nil {
    fmt.eprintfln("Failed to read %s image", filepath)
  }

  img_w, img_h, img_channels: i32
  img_data := stbi.load_from_memory(&contents[0], i32(len(contents)), 
    &img_w, &img_h, &img_channels, 0)
  defer stbi.image_free(img_data)

  // img_w, img_h, img_channels, img_data := ppm_parse(filepath)
  // defer free(img_data)

  if img_data == nil {
    fmt.eprintfln("Failed to parse %s image", filepath)
  }

  texture: u32

  gl.GenTextures(1, &texture)
  gl.BindTexture(gl.TEXTURE_2D, texture)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  if img_channels == 1 {
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, img_w, img_h,
      0, gl.RED, gl.UNSIGNED_BYTE, &img_data[0])
  } else {
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, img_w, img_h,
      0, (img_channels == 3) ? gl.RGB : gl.RGBA, gl.UNSIGNED_BYTE, &img_data[0])
  }
  gl.GenerateMipmap(gl.TEXTURE_2D)


  return texture
}

Framebuffer :: struct {
  color_texture,
  depth_texture,
  normal_texture,
  red_texture,
  framebuffer: GpuID,
  material: Material,
  size: IVec2,
  type: bit_set[FramebufferType]
}

FramebufferType :: enum {
  COLOR,
  NORMAL,
  DEPTH,
  RED,
}

framebuffer_init :: proc(
  framebuffer: ^Framebuffer,
  size: IVec2,
  type: bit_set[FramebufferType],
  shader_name: string = "",
  shader_type: ShaderType = .THREE_DIMENSIONAL,
  msaa: bool = false,
  msaa_samples: i32 = 8,
) {
  if len(shader_name) != 0 {
    framebuffer.material = asset_loader_material(0, 0, shader_name, shader_type)
  }

  texture_attachment: u32 = (msaa) ? gl.TEXTURE_2D_MULTISAMPLE : gl.TEXTURE_2D
  framebuffer.size = size
  framebuffer.type = type

  gl.GenFramebuffers(1, &framebuffer.framebuffer)
  gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer.framebuffer)

  if type == {.RED} {
    gl.GenTextures(1, &framebuffer.red_texture)
    gl.BindTexture(gl.TEXTURE_2D, framebuffer.red_texture)

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RED, size.x, size.y, 0, gl.RED, gl.FLOAT, nil)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

    gl.FramebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT0,
      gl.TEXTURE_2D,
      framebuffer.red_texture,
      0
    )
  } else if .DEPTH in type {
    gl.GenTextures(1, &framebuffer.depth_texture)
    gl.BindTexture(texture_attachment, framebuffer.depth_texture)

    if msaa {
      gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, msaa_samples, gl.DEPTH_COMPONENT, size.x, size.y, gl.TRUE)
    } else {
      gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, size.x, size.y, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)

      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

      // Setting a white border helps with shadows outside the shadowmap
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
      border_col: []f32 = {1, 1, 1}
      gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &border_col[0])
    }

    gl.FramebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.DEPTH_ATTACHMENT,
      texture_attachment,
      framebuffer.depth_texture,
      0
    )
  }

  if .COLOR in type {
    gl.GenTextures(1, &framebuffer.color_texture)
    gl.BindTexture(texture_attachment, framebuffer.color_texture)

    if msaa {
      gl.TexImage2DMultisample(
        gl.TEXTURE_2D_MULTISAMPLE,
        msaa_samples,
        gl.RGBA,
        size.x,
        size.y,
        gl.TRUE
      )

    } else {
      gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, size.x, size.y, 0, gl.RGBA, gl.FLOAT, nil)

      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
    }

    gl.FramebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT0,
      texture_attachment,
      framebuffer.color_texture,
      0
    )

  }

  if .NORMAL in type {
    gl.GenTextures(1, &framebuffer.normal_texture)
    gl.BindTexture(texture_attachment, framebuffer.normal_texture)

    if msaa {
      gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, msaa_samples, gl.RGBA16F, size.x, size.y, gl.TRUE)
    } else {
      gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, size.x, size.y, 0, gl.RGBA, gl.FLOAT, nil)

      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    }

    gl.FramebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT1,
      texture_attachment,
      framebuffer.normal_texture,
      0
    )

    draw_attachments := []u32 {
      gl.COLOR_ATTACHMENT0,
      gl.COLOR_ATTACHMENT1,
    }
    gl.DrawBuffers(2, &draw_attachments[0])
  }

  if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
    fmt.printfln("Failed to init framebuffer")
    fmt.printfln("%d", gl.CheckFramebufferStatus(gl.FRAMEBUFFER))
  }
}

framebuffer_attach_depth_texture :: proc(framebuffer: ^Framebuffer, texture: GpuID) {
  framebuffer.depth_texture = texture
  gl.BindTexture(gl.TEXTURE_2D, texture)
  gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer.framebuffer)
  gl.FramebufferTexture2D(gl.FRAMEBUFFER,
    gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, texture, 0)
}

// TODO: add framebuffer_resize

framebuffer_delete :: proc(framebuffer: Framebuffer) {
  framebuffer := framebuffer
  gl.DeleteTextures(1, &framebuffer.color_texture)
  gl.DeleteTextures(1, &framebuffer.depth_texture)
  gl.DeleteFramebuffers(1, &framebuffer.framebuffer)
}

framebuffer_blit :: proc(framebuffer_from: Framebuffer, framebuffer_to: Framebuffer, depth: bool = false) {
  gl.BindFramebuffer(gl.READ_FRAMEBUFFER, framebuffer_from.framebuffer)
  gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, framebuffer_to.framebuffer)
  gl.BlitFramebuffer(0, 0, framebuffer_from.size.x, framebuffer_from.size.y,
    0, 0, framebuffer_to.size.x, framebuffer_to.size.y, (depth) ? gl.DEPTH_BUFFER_BIT : gl.COLOR_BUFFER_BIT, gl.LINEAR)
}

DebugVertex :: struct {
  position, color: Vec3
}

DebugRenderer :: struct {
  shader: Shader,
  line_vertices: [dynamic]DebugVertex,
  vao,
  vbo: GpuID
}

debugrenderer_init :: proc(debug_renderer: ^DebugRenderer) {
  #assert(size_of(Vec3) == 12)
  gl.GenVertexArrays(1, &debug_renderer.vao)
  gl.BindVertexArray(debug_renderer.vao)

  gl.GenBuffers(1, &debug_renderer.vbo)
  gl.BindBuffer(gl.ARRAY_BUFFER, debug_renderer.vbo)
  gl.BufferData(gl.ARRAY_BUFFER, 0, nil, gl.DYNAMIC_DRAW)

  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, size_of(DebugVertex), offset_of(DebugVertex, position))
  gl.EnableVertexAttribArray(1)
  gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, size_of(DebugVertex), offset_of(DebugVertex, color))

  debug_renderer.shader = asset_loader_material(0, 0, "debug", .THREE_DIMENSIONAL).shader
}

debugrenderer_draw :: proc(debug_renderer: ^DebugRenderer) {
  if len(debug_renderer.line_vertices) == 0 do return

  gl.BindVertexArray(debug_renderer.vao)
  gl.BindBuffer(gl.ARRAY_BUFFER, debug_renderer.vbo)
  gl.BufferData(gl.ARRAY_BUFFER, len(debug_renderer.line_vertices) * size_of(DebugVertex), &debug_renderer.line_vertices[0], gl.DYNAMIC_DRAW)

  gl.UseProgram(debug_renderer.shader.program)
  gl.UniformMatrix4fv(debug_renderer.shader.parameters.view_matrix_location, 1, gl.FALSE, &debug_renderer.shader.parameters.view_matrix[0,0])
  gl.UniformMatrix4fv(debug_renderer.shader.parameters.projection_matrix_location, 1, gl.FALSE, &debug_renderer.shader.parameters.projection_matrix[0,0])
  gl.DrawArrays(gl.LINES, 0, i32(len(debug_renderer.line_vertices)))

  clear(&debug_renderer.line_vertices)
}

debugrenderer_linebatch :: proc(debug_renderer: ^DebugRenderer, start, end, color: Vec3) {
  append(&debug_renderer.line_vertices, DebugVertex{start, color})
  append(&debug_renderer.line_vertices, DebugVertex{end, color})
}
