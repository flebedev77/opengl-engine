package main
import "core:math"

Vec3 :: [3]f32
Vec2 :: [2]f32
Mat4 :: matrix[4,4]f32

GLOBAL_UP : Vec3 : {0, 1, 0}

@(require_results) is_numeric :: proc(c: u8) -> bool {
  return (c == '-' || c == '.' || (c > 0x2F && c < 0x3A))
}

@(require_results) is_whole :: proc(v: f32) -> bool {
  return v == math.round(v)
}

@(require_results) rotation_matrix_x :: proc(angle: f32) -> matrix[4,4]f32 {
  rotation_matrix := matrix[4,4]f32{
    1, 0, 0, 0,
    0, math.cos(angle), -math.sin(angle), 0,
    0, math.sin(angle), math.cos(angle), 0,
    0, 0, 0, 1
  }

  return rotation_matrix
}
@(require_results) rotation_matrix_y :: proc(angle: f32) -> matrix[4,4]f32 {
  rotation_matrix := matrix[4,4]f32{
    math.cos(angle), 0, math.sin(angle), 0,
    0, 1, 0, 0,
    -math.sin(angle), 0, math.cos(angle), 0,
    0, 0, 0, 1
  }

  return rotation_matrix
}
@(require_results) rotation_matrix_z :: proc(angle: f32) -> matrix[4,4]f32 {
  rotation_matrix := matrix[4,4]f32{
    math.cos(angle), -math.sin(angle), 0, 0,
    math.sin(angle), math.cos(angle),  0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  }

  return rotation_matrix
}

@(require_results) translation_matrix :: proc(vector: Vec3) -> matrix[4,4]f32 {
  return matrix[4,4]f32{
    1, 0, 0, vector.x,
    0, 1, 0, vector.y,
    0, 0, 1, vector.z,
    0, 0, 0, 1
  }
}

@(require_results) scale_matrix :: proc(scale: Vec3) -> matrix[4,4]f32 {
  return matrix[4,4]f32{
    scale.x, 0, 0, 0,
    0, scale.y, 0, 0,
    0, 0, scale.z, 0,
    0, 0, 0, 1
  }
}

@(require_results) perspective_projection_matrix :: proc(aspect, fov, near, far: f32) -> matrix[4,4]f32 {
  f: f32 = 1 / math.tan(fov * 0.5 * math.PI/180)
  // return matrix[4,4]f32{
  //   f, 0, 0, 0,
  //   0, f, 0, 0,
  //   0, 0, (far + near) / (near - far), -1.0,
  //   0, 0, (2.0 * far * near) / (near - far), 0.0
  // }
  return matrix[4,4]f32{
    f / aspect, 0, 0, 0,
    0, f, 0, 0,
    0, 0, -(far / (far - near)), -1.0,
    0, 0, -((far * near) / (far - near)), 0.0
  }
  // return matrix[4,4]f32{
  //   f / aspect, 0, 0, 0,
  //   0, f, 0, 0,
  //   0, 0, 0, 0,
  //   0, 0, f, 1
  // }
}

@(require_results) orthographic_projection_matrix :: proc(left, right, top, bottom, near, far: f32) -> Mat4 {
  return Mat4{
    2 / (right - left), 0, 0, -((right + left) / (right - left)),
    0, 2 / (top - bottom), 0, -((top + bottom) / (top - bottom)),
    0, 0, -2 / (far - near), -((far + near) / (far - near)),
    0, 0, 0, 1
  }
}

@(require_results) identity_matrix :: proc() -> matrix[4,4]f32 {
  return matrix[4,4]f32{
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  }
}

@(require_results) lookat_matrix :: proc(from, to, up: Vec3) -> matrix[4,4]f32 {
  up := normalize_vector3(up)
  direction: Vec3 = normalize_vector3(from - to)
  right: Vec3 = normalize_vector3(cross_product_vector3(up, direction))
  up = cross_product_vector3(direction, right)
  // return matrix[4,4]f32 {
  //   right.x, right.y, right.z, -from.x,
  //   up.x, up.y, up.z, -from.y,
  //   direction.x, direction.y, direction.z, -from.z,
  //   0, 0, 0, 1
  // }
  return matrix[4,4]f32 {
    1, 0, 0, from.x,
    0, 1, 0, from.y,
    0, 0, 1, from.z,
    0, 0, 0, 1
  }
}

@(require_results) normalize_vector3 :: proc(v: Vec3) -> Vec3 {
  len: f32 = math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
  return Vec3{
    v.x/len, v.y/len, v.z/len
  }
}

@(require_results) cross_product_vector3 :: proc(a, b: Vec3) -> Vec3 {
  return Vec3{
    a.y*b.z - a.z*b.y,
    a.z*b.x - a.x*b.z,
    a.x*b.y - a.y*b.x
  }
}
