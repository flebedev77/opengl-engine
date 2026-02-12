package main
import "core:fmt"
import "core:mem"

Grid :: struct {
  width,
  height: int,
  meshes: []Mesh, // TODO batch this into a single mesh or use instancing
  allocator: mem.Arena // Might be overkill since we might need to allocate only the meshes
}

grid_init :: proc(grid: ^Grid, width, height: int, offset: Vec3, shader: Shader) {
  allocator_size: int = width * height * (size_of(Mesh) + 1)
  backing_buffer, err := mem.alloc_bytes(allocator_size)
  assert(err == nil)
  mem.arena_init(&grid.allocator, backing_buffer)

  grid.width = width
  grid.height = height
  grid.meshes = make([]Mesh, width * height, mem.arena_allocator(&grid.allocator))

  for y in 0..<height {
    for x in 0..<width {
      i := y * width + x

      mesh := mesh_make_cube(shader)
      mesh.model_matrix = translation_matrix({f32(x) + offset.x, offset.y, f32(y) + offset.z})
      grid.meshes[i] = mesh
    }
  }
}

grid_draw :: proc(grid: ^Grid, camera: Camera) {
  for y in 0..<grid.height {
    for x in 0..<grid.width {
      i := y * grid.width + x
      mesh := grid.meshes[i]
      mesh.shader.parameters.view_matrix = camera.view_matrix
      mesh.shader.parameters.camera_position = camera.position
      mesh.shader.parameters.projection_matrix = camera.projection_matrix
      mesh.shader.parameters.tint = {
        f32(x) / f32(grid.width),
        1,
        f32(y) / f32(grid.height)
      }
      mesh_draw(mesh)
    }
  }
}

grid_delete :: proc() {

}
