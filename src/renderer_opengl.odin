package main
import "core:fmt"
import gl "vendor:OpenGL"

GpuID :: u32
UniformLocation :: i32

ShaderType :: enum {
  THREE_DIMENSIONAL, // Signifies that the shader should receive 3D related uniforms
  TWO_DIMENTIONAL    // TODO
}

ShaderFlags :: enum {
  has_vertex_normals
}

ShaderParameters :: struct {
  tint_location,
  light_position_location,
  camera_position_location,
  view_matrix_location,
  projection_matrix_location,
  model_matrix_location: UniformLocation,

  view_matrix,
  projection_matrix: Mat4,
  camera_position,
  tint: Vec3
}

Shader :: struct {
  program: GpuID,
  parameters: ShaderParameters,
  type: ShaderType,
  flags: bit_set[ShaderFlags]
}

Mesh :: struct {
  vao,
  position_bufferobject,
  normal_bufferobject,
  uv_bufferobject,
  indice_bufferobject,
  texture: GpuID,
  shader: Shader,
  triangle_count,
  indice_count: i32,
  model_matrix: Mat4 
}

mesh_init :: proc(
  mesh: ^Mesh,
  vertex_positions: []f32,
  vertex_uvs: []f32,
  vertex_normals: []f32,
  indices: []u32,
  shader: Shader
) {
  gl.GenVertexArrays(1, &mesh.vao)
  gl.BindVertexArray(mesh.vao)

  gl.GenBuffers(1, &mesh.position_bufferobject)
  gl.BindBuffer(gl.ARRAY_BUFFER, mesh.position_bufferobject)
  gl.BufferData(gl.ARRAY_BUFFER, len(vertex_positions) * size_of(f32), &vertex_positions[0], gl.STATIC_DRAW)

  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)

  if len(vertex_normals) == len(vertex_positions) {
    fmt.printfln("NORMALS ENABLED")
    gl.GenBuffers(1, &mesh.normal_bufferobject)
    gl.BindBuffer(gl.ARRAY_BUFFER, mesh.normal_bufferobject)
    gl.BufferData(gl.ARRAY_BUFFER, len(vertex_normals) * size_of(f32), &vertex_normals[0], gl.STATIC_DRAW)

    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), cast(uintptr)0)
  }

  gl.GenBuffers(1, &mesh.uv_bufferobject)
  gl.BindBuffer(gl.ARRAY_BUFFER, mesh.uv_bufferobject)
  gl.BufferData(gl.ARRAY_BUFFER, len(vertex_uvs) * size_of(f32), &vertex_uvs[0], gl.STATIC_DRAW)

  gl.EnableVertexAttribArray(2)
  gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), cast(uintptr)0)
  
  gl.GenBuffers(1, &mesh.indice_bufferobject)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.indice_bufferobject)
  gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(f32), &indices[0], gl.STATIC_DRAW)


  gl.BindVertexArray(0)

  mesh.model_matrix = identity_matrix()
  mesh.shader = shader
  mesh.indice_count = i32(len(indices))
  mesh.triangle_count = mesh.indice_count / 3;
  // fmt.printfln("VAO  %d\nVBO  %d\nEBO  %d\nTRIS %d", mesh.vao, mesh.position_bufferobject, mesh.indice_bufferobject, len(indices))
}

mesh_draw :: proc(mesh: Mesh) {
  mesh := mesh
  shader := mesh.shader

  if shader.program != 0 {
    gl.UseProgram(shader.program)

    light_pos := Vec3{10, 10, 10}
    gl.Uniform3fv(shader.parameters.light_position_location, 1, &light_pos[0])
    gl.Uniform3fv(shader.parameters.camera_position_location, 1, &shader.parameters.camera_position[0])
    gl.Uniform3fv(shader.parameters.tint_location, 1, &shader.parameters.tint[0])

    gl.UniformMatrix4fv(shader.parameters.model_matrix_location, 1, gl.FALSE, &mesh.model_matrix[0,0])
    gl.UniformMatrix4fv(shader.parameters.projection_matrix_location, 1, gl.FALSE, &shader.parameters.projection_matrix[0,0])
    gl.UniformMatrix4fv(shader.parameters.view_matrix_location, 1, gl.FALSE, &shader.parameters.view_matrix[0,0])
  }
  gl.BindVertexArray(mesh.vao)

  gl.DrawElements(gl.TRIANGLES, mesh.triangle_count * 3, gl.UNSIGNED_INT, cast(rawptr)(cast(uintptr)0))
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

  // TODO: logging
  success: i32
  gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
  // assert(success == i32(gl.TRUE))
  if success != i32(gl.TRUE) {
    shader_error_log: [512]u8
    len: i32
    gl.GetShaderInfoLog(shader, 512, &len, &shader_error_log[0])
    fmt.printfln("Shader compilation error: %s", shader_error_log)
  }

  return shader
}

shader_compileprogram :: proc(fragmentSource: cstring, vertexSource: cstring) -> Shader {
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
  
  return shader
}

shader_init :: proc(shader: ^Shader) {
  shader.parameters.tint_location = gl.GetUniformLocation(shader.program, "tint")
  switch shader.type {
    case .THREE_DIMENSIONAL:
      shader.parameters.light_position_location = gl.GetUniformLocation(shader.program, "light_pos")
      shader.parameters.camera_position_location = gl.GetUniformLocation(shader.program, "camera_pos")
      shader.parameters.model_matrix_location = gl.GetUniformLocation(shader.program, "model_matrix")
      shader.parameters.view_matrix_location = gl.GetUniformLocation(shader.program, "view_matrix")
      shader.parameters.projection_matrix_location = gl.GetUniformLocation(shader.program, "projection_matrix")
      break
    case .TWO_DIMENTIONAL:
      break
  }
}

renderer_info :: proc() {
  max_vertex_attributes: i32
  gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &max_vertex_attributes)
  fmt.printfln("MAX VERTEX ATTRIBUTES %d", max_vertex_attributes)

  max_fragment_attributes: i32
  gl.GetIntegerv(gl.MAX_FRAGMENT_INPUT_COMPONENTS, &max_fragment_attributes)
  fmt.printfln("MAX FRAGMENT ATTRIBUTES %d", max_fragment_attributes)
}
