package main
import "core:math/linalg"
import "core:math"

Camera :: struct {
  view_matrix,
  inv_view_matrix,
  inv_projection_matrix,
  projection_matrix,
  prev_view_matrix,
  prev_projection_matrix: Mat4,
  position: Vec3
}

camera_update :: proc(camera: ^Camera) {
    // If near or far planes get changed, change in post process shader
    camera.prev_view_matrix = camera.view_matrix
    camera.prev_projection_matrix = camera.projection_matrix

    camera.projection_matrix = mat4_perspective(
      80 * math.PI / 180, 
      f32(FrameBuffer.w) / f32(FrameBuffer.h), 
      0.001,
      1000000000
    )
    camera.inv_projection_matrix = linalg.inverse(camera.projection_matrix)
    camera.inv_view_matrix = linalg.inverse(camera.view_matrix)
    // camera.projection_matrix = orthographic_projection_matrix(-1, 1, 1, -1, 0.1, 1000)
}
