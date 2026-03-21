package main
import "core:os"
import "core:fmt"
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
  screen_texture_location,
  depth_texture_location,
  normal_texture_location,
  albedo_texture_location,
  shadowmap_texture_location,
  shadowmap_matrix_location,
  tint_location,
  light_position_location,
  camera_position_location,
  view_matrix_location,
  inv_projection_matrix_location,
  projection_matrix_location,
  model_matrix_location: UniformLocation,

  shadowmap_matrix,
  view_matrix,
  inv_projection_matrix,
  projection_matrix: Mat4,
  camera_position: Vec3
}

Shader :: struct {
  program: GpuID,
  parameters: ShaderParameters,
  type: ShaderType,
  flags: bit_set[ShaderFlags]
}

Material :: struct {
  is_valid: bool,
  albedo_texture: GpuID,
  albedo_tint: Vec3,
  shader: Shader,
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
  scene: ^Scene,
  bound_framebuffer: Framebuffer
}

renderer_init :: proc(renderer: ^Renderer, scene: ^Scene) {
  gl.Enable(gl.DEPTH_TEST)
  gl.Enable(gl.FRAMEBUFFER_SRGB)
  gl.Enable(gl.MULTISAMPLE)
  gl.Enable(gl.CULL_FACE)
  gl.CullFace(gl.BACK)
  gl.FrontFace(gl.CCW)

  // gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)// : GL_FILL); 

  renderer.scene = scene
  scene.renderer = renderer
}

render_begin :: proc(renderer: ^Renderer) {
  gl.BindFramebuffer(gl.FRAMEBUFFER, renderer.bound_framebuffer.framebuffer)
  gl.Viewport(0, 0,
    renderer.bound_framebuffer.size.x,
    renderer.bound_framebuffer.size.y
  )
  gl.Clear(gl.DEPTH_BUFFER_BIT | gl.COLOR_BUFFER_BIT)
}

render_mesh :: proc(renderer: ^Renderer, mesh: ^Mesh, material_override: Material = {}) {
  // Wtf is going on?
  if material_override.is_valid {
    shader_override := material_override.shader
    shader_override.parameters.view_matrix = renderer.scene.camera.view_matrix
    shader_override.parameters.projection_matrix = renderer.scene.camera.projection_matrix
    shader_override.parameters.camera_position = renderer.scene.camera.position
  } else {
    mesh.material.shader.parameters.view_matrix = renderer.scene.camera.view_matrix
    mesh.material.shader.parameters.projection_matrix = renderer.scene.camera.projection_matrix
    mesh.material.shader.parameters.camera_position = renderer.scene.camera.position
    mesh.material.shader.parameters.inv_projection_matrix = renderer.scene.camera.inv_projection_matrix
  }
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

mesh_draw :: proc(mesh: Mesh, material_override: Material = {}) {
  mesh := mesh
  material := mesh.material

  if material.is_valid && !material_override.is_valid {
    gl.UseProgram(material.shader.program)
  } else if material_override.is_valid {
    gl.UseProgram(material_override.shader.program)
    material = material_override
  }
  shader := material.shader

  gl.UniformMatrix4fv(shader.parameters.inv_projection_matrix_location, 1, gl.FALSE, &shader.parameters.inv_projection_matrix[0, 0])
  gl.UniformMatrix4fv(shader.parameters.projection_matrix_location, 1, gl.FALSE, &shader.parameters.projection_matrix[0,0])
  if mesh.material.shader.type == .TWO_DIMENTIONAL {
    gl.BindVertexArray(mesh.vao)
    gl.Uniform1i(shader.parameters.screen_texture_location, 2)
    gl.Uniform1i(shader.parameters.depth_texture_location, 3)
    gl.Uniform1i(shader.parameters.normal_texture_location, 4)
    gl.DrawElements(gl.TRIANGLE_STRIP, 4, gl.UNSIGNED_INT, cast(rawptr)(cast(uintptr)0))
  } else {
    light_pos := Vec3{10, 50, 10} // TODO move this
    gl.Uniform3fv(shader.parameters.light_position_location, 1, &light_pos[0])
    gl.Uniform3fv(shader.parameters.camera_position_location, 1, &shader.parameters.camera_position[0])

    if material.albedo_tint == {0, 0, 0} {
      material.albedo_tint = {1, 1, 1}
    }
    gl.Uniform3fv(shader.parameters.tint_location, 1, &material.albedo_tint[0])

    gl.ActiveTexture(gl.TEXTURE0)
    gl.BindTexture(gl.TEXTURE_2D, material.albedo_texture)

    gl.Uniform1i(shader.parameters.albedo_texture_location, 0)
    gl.Uniform1i(shader.parameters.shadowmap_texture_location, 1)

    gl.UniformMatrix4fv(shader.parameters.model_matrix_location, 1, gl.FALSE, &mesh.model_matrix[0,0])
    gl.UniformMatrix4fv(shader.parameters.projection_matrix_location, 1, gl.FALSE, &shader.parameters.projection_matrix[0,0])
    gl.UniformMatrix4fv(shader.parameters.view_matrix_location, 1, gl.FALSE, &shader.parameters.view_matrix[0,0])
    gl.UniformMatrix4fv(shader.parameters.shadowmap_matrix_location, 1, gl.FALSE, &shader.parameters.shadowmap_matrix[0,0])

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


shader_compilemodule :: proc(source: cstring, type: u32) -> GpuID {
  source := source
  shader := gl.CreateShader(type)
  gl.ShaderSource(shader, 1, &source, nil)
  gl.CompileShader(shader)

  success: i32
  gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
  // assert(success == i32(gl.TRUE))
  if success != i32(gl.TRUE) {
    shader_error_log: [512]u8
    len: i32
    gl.GetShaderInfoLog(shader, 512, &len, &shader_error_log[0])
    panic(fmt.tprintfln("Shader compilation error: %s", shader_error_log[:len]))
  }

  return shader
}

shader_compileprogram :: proc(fragmentSource: cstring, vertexSource: cstring, type: ShaderType) -> Shader {
  shader_program := gl.CreateProgram()
  fragment_shader := shader_compilemodule(fragmentSource, gl.FRAGMENT_SHADER)
  vertex_shader := shader_compilemodule(vertexSource, gl.VERTEX_SHADER)

  gl.AttachShader(shader_program, fragment_shader)
  gl.AttachShader(shader_program, vertex_shader)
  gl.LinkProgram(shader_program)
  gl.DeleteShader(fragment_shader)
  gl.DeleteShader(vertex_shader)

  shader: Shader
  shader.program = shader_program
  shader.type = type
  shader_init(&shader)
  
  return shader
}

shader_init :: proc(shader: ^Shader) {
  shader.parameters.tint_location = gl.GetUniformLocation(shader.program, "tint")
  shader.parameters.shadowmap_matrix_location = gl.GetUniformLocation(shader.program, "shadowmap_matrix")
  shader.parameters.inv_projection_matrix_location = gl.GetUniformLocation(shader.program, "inv_projection_matrix")
  shader.parameters.projection_matrix_location = gl.GetUniformLocation(shader.program, "projection_matrix")
  switch shader.type {
    case .THREE_DIMENSIONAL:
      shader.parameters.albedo_texture_location = gl.GetUniformLocation(shader.program, "albedo_texture")
      shader.parameters.shadowmap_texture_location = gl.GetUniformLocation(shader.program, "shadowmap_texture")
      shader.parameters.light_position_location = gl.GetUniformLocation(shader.program, "light_pos")
      shader.parameters.camera_position_location = gl.GetUniformLocation(shader.program, "camera_pos")
      shader.parameters.model_matrix_location = gl.GetUniformLocation(shader.program, "model_matrix")
      shader.parameters.view_matrix_location = gl.GetUniformLocation(shader.program, "view_matrix")
    case .TWO_DIMENTIONAL:
      shader.parameters.screen_texture_location = gl.GetUniformLocation(shader.program, "screen_texture")
      shader.parameters.depth_texture_location = gl.GetUniformLocation(shader.program, "depth_texture")
      shader.parameters.normal_texture_location = gl.GetUniformLocation(shader.program, "normal_texture")
    case .SHADOWMAP:
      shader.parameters.model_matrix_location = gl.GetUniformLocation(shader.program, "model_matrix")
      shader.parameters.view_matrix_location = gl.GetUniformLocation(shader.program, "view_matrix")
      shader.parameters.projection_matrix_location = gl.GetUniformLocation(shader.program, "projection_matrix")
  }
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
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, img_w, img_h,
    0, (img_channels == 3) ? gl.RGB : gl.RGBA, gl.UNSIGNED_BYTE, &img_data[0])
  gl.GenerateMipmap(gl.TEXTURE_2D)


  return texture
}

Framebuffer :: struct {
  color_texture,
  depth_texture,
  normal_texture,
  framebuffer: GpuID,
  size: IVec2,
  type: FramebufferType
}

FramebufferType :: enum {
  COLOR_DEPTH_AND_NORMAL,
  COLOR_AND_DEPTH,
  DEPTH,
  NONE
}

framebuffer_init :: proc(
  framebuffer: ^Framebuffer,
  size: IVec2,
  type: FramebufferType
) {
  assert(type != .NONE)
  framebuffer.size = size
  framebuffer.type = type

  gl.GenTextures(1, &framebuffer.depth_texture)
  gl.BindTexture(gl.TEXTURE_2D, framebuffer.depth_texture)
  
  gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, size.x, size.y, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)

  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

  // Setting a white border helps with shadows outside the shadowmap
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
  border_col: []f32 = {1, 1, 1}
  gl.TexParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &border_col[0])

  gl.GenFramebuffers(1, &framebuffer.framebuffer)
  gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer.framebuffer)

  gl.FramebufferTexture2D(
    gl.FRAMEBUFFER,
    gl.DEPTH_ATTACHMENT,
    gl.TEXTURE_2D,
    framebuffer.depth_texture,
    0
  )

  if type == .COLOR_AND_DEPTH || type == .COLOR_DEPTH_AND_NORMAL{
    gl.GenTextures(1, &framebuffer.color_texture)
    gl.BindTexture(gl.TEXTURE_2D, framebuffer.color_texture)

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, size.x, size.y, 0, gl.RGB, gl.FLOAT, nil)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)

    gl.FramebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT0,
      gl.TEXTURE_2D,
      framebuffer.color_texture,
      0
    )
  }

  if type == .COLOR_DEPTH_AND_NORMAL {
    gl.GenTextures(1, &framebuffer.normal_texture)
    gl.BindTexture(gl.TEXTURE_2D, framebuffer.normal_texture)

    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA16F, size.x, size.y, 0, gl.RGBA, gl.FLOAT, nil)

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.FramebufferTexture2D(
      gl.FRAMEBUFFER,
      gl.COLOR_ATTACHMENT1,
      gl.TEXTURE_2D,
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

// TODO: add framebuffer_resize

framebuffer_delete :: proc(framebuffer: Framebuffer) {
  framebuffer := framebuffer
  gl.DeleteTextures(1, &framebuffer.color_texture)
  gl.DeleteTextures(1, &framebuffer.depth_texture)
  gl.DeleteFramebuffers(1, &framebuffer.framebuffer)
}
