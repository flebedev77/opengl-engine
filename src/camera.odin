package main
import "core:math/linalg"
import "core:math"

Camera :: struct {
  view_matrix,
  projection_matrix: Mat4,
  position: Vec3
}

camera_update :: proc(camera: ^Camera) {
    camera.projection_matrix = linalg.matrix4_perspective_f32(90 * math.PI / 180, f32(FrameBuffer.w) / f32(FrameBuffer.h), 0.1, 1000)
}
