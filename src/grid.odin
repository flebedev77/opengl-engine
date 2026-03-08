package main

Grid :: struct {
  width,
  height: int,
  offset: Vec3,
  mesh: Mesh // TODO batch this into a single mesh or use instancing
}

grid_init :: proc(grid: ^Grid, width, height: int, offset: Vec3, shader: Shader) {
  grid.width = width
  grid.height = height
  grid.offset = offset
  grid.mesh = mesh_make_cube(shader)

  // for y in 0..<height {
  //   for x in 0..<width {
  //     i := y * width + x
  //
  //     mesh := mesh_make_cube(shader)
  //     mesh.model_matrix = translation_matrix({f32(x) + offset.x, offset.y, f32(y) + offset.z})
  //     grid.meshes[i] = mesh
  //   }
  // }
}

grid_draw :: proc(grid: ^Grid, camera: Camera, shader_override: Shader = {}) {
  for y in 0..<grid.height {
    for x in 0..<grid.width {
      i := y * grid.width + x
      grid.mesh.model_matrix = translation_matrix({
        f32(x) + grid.offset.x,
        grid.offset.y, 
        f32(y) + grid.offset.z
      }) 
      grid.mesh.shader.parameters.view_matrix = camera.view_matrix
      grid.mesh.shader.parameters.camera_position = camera.position
      grid.mesh.shader.parameters.projection_matrix = camera.projection_matrix
      grid.mesh.shader.parameters.tint = {
        f32(x) / f32(grid.width),
        1,
        f32(y) / f32(grid.height)
      }
      mesh_draw(grid.mesh, shader_override)
    }
  }
}

grid_delete :: proc(grid: Grid) {
  mesh_delete(grid.mesh)
}
