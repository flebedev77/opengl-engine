package main
import "core:math/linalg"
import "core:math"

Camera :: struct {
  view_matrix,
  inv_view_matrix,
  inv_projection_matrix,
  projection_matrix: Mat4,
  position: Vec3
}

camera_update :: proc(camera: ^Camera) {
    // If near or far planes get changed, change in post process shader
    camera.projection_matrix = linalg.matrix4_perspective_f32(
      80 * math.PI / 180, 
      f32(FrameBuffer.w) / f32(FrameBuffer.h), 
      0.001,
      1000
    )
    camera.inv_projection_matrix = linalg.inverse(camera.projection_matrix)
    camera.inv_view_matrix = linalg.inverse(camera.view_matrix)
    // camera.projection_matrix = orthographic_projection_matrix(-1, 1, 1, -1, 0.1, 1000)
}
