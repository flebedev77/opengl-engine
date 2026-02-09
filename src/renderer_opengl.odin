package main
import "core:fmt"
import gl "vendor:OpenGL"

Mesh :: struct {
  vao,
  position_bufferobject,
  indice_bufferobject,
  texture,
  shader: u32,
  triangle_count: i32
}

mesh_init :: proc(mesh: ^Mesh, vertex_positions: []f32, indices: []u32, shader: u32) {

  gl.GenVertexArrays(1, &mesh.vao)
  gl.BindVertexArray(mesh.vao)

  gl.GenBuffers(1, &mesh.position_bufferobject)
  gl.BindBuffer(gl.ARRAY_BUFFER, mesh.position_bufferobject)
  gl.BufferData(gl.ARRAY_BUFFER, len(vertex_positions) * size_of(f32), &vertex_positions[0], gl.STATIC_DRAW)
  
  gl.GenBuffers(1, &mesh.indice_bufferobject)
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh.indice_bufferobject)
  gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(f32), &indices[0], gl.STATIC_DRAW)

  gl.EnableVertexAttribArray(0)
  gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 2 * size_of(f32), cast(uintptr)0)

  gl.BindVertexArray(0)

  mesh.triangle_count = i32(len(indices) / 3);
  fmt.printfln("VAO %d\nVBO %d\nEBO %d\nTRIS %d", mesh.vao, mesh.position_bufferobject, mesh.indice_bufferobject, len(indices))
}

mesh_draw :: proc(mesh: Mesh) {
  gl.BindVertexArray(mesh.vao)
  gl.DrawElements(gl.TRIANGLES, mesh.triangle_count * 3, gl.UNSIGNED_INT, cast(rawptr)(cast(uintptr)0))
}
