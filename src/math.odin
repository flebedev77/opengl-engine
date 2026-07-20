package main
import "core:math"
import "core:math/linalg"

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32
IVec2 :: [2]i32
Mat4 :: matrix[4,4]f32

Basis :: struct {
  right,
  up,
  forward: Vec3
}

GLOBAL_UP :: Vec3{0, 1, 0}


@(require_results)
mat4_perspective :: proc "contextless" (fovy, aspect, near, far: f32) -> (m: Mat4) #no_bounds_check {


tan_half_fovy := math.tan(0.5 * fovy)
    
    m[0, 0] = 1 / (aspect * tan_half_fovy)
    m[1, 1] = 1 / (tan_half_fovy)
    
    // Mapping Z: -near -> 1, -far -> 0
    m[2, 2] = near / (far - near)
    m[2, 3] = (far * near) / (far - near)
    
    // W = -Z
    m[3, 2] = -1
    m[3, 3] = 0

    return

	// tan_half_fovy := math.tan(0.5 * fovy)
	// m[0, 0] = 1 / (aspect*tan_half_fovy)
	// m[1, 1] = 1 / (tan_half_fovy)
	// m[2, 2] = (far / (far - near))
	// m[3, 2] = 1
	// m[2, 3] = (far*near / (far - near))

	// return
}

@(require_results) is_numeric :: proc(c: u8) -> bool {
  return (c == '-' || c == '.' || (c > 0x2F && c < 0x3A))
}

@(require_results) is_whole :: proc(v: f32) -> bool {
  return v == math.round(v)
}

@(require_results) vector3_rotate_around_axis :: proc(vector, axis: Vec3, angle: f32) -> Vec3 {
  rotation_axis := linalg.normalize(axis)
  rotation := linalg.quaternion_angle_axis_f32(angle, rotation_axis)
  return linalg.mul(rotation, vector)
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

@(require_results) orthographic_projection_matrix :: proc(l, r, t, b, n, f: f32) -> Mat4 {
right, left, top, bottom, near, far := r, l, t, b, n, f
return Mat4{
    2 / (right - left), 0, 0, -((right + left) / (right - left)),
    0, 2 / (top - bottom), 0, -((top + bottom) / (top - bottom)),
    0, 0, -1 / (far - near), -near / (far - near), 
    0, 0, 0, 1,
}
  // return Mat4{
  //   2/(right-left),          0,                 0,                 0,
  //   0,                2/(top-bottom),           0,                 0,
  //   0,                0,               -2/(far-near),           0,
  //   -((right+left)/(right-left)), -((top+bottom)/(top-bottom)), -((far+near)/(far-near)),        1
  // }
  // return Mat4{
  //   2 / (right - left), 0, 0, -((right + left) / (right - left)),
  //   0, 2 / (top - bottom), 0, -((top + bottom) / (top - bottom)),
  //   0, 0, -2 / (far - near), -((far + near) / (far - near)),
  //   0, 0, 0, 1
  // }
// return Mat4{
//   2 / (right - left), 0, 0, -((right + left) / (right - left)),
//   0, 2 / (top - bottom), 0, -((top + bottom) / (top - bottom)),
//   0, 0, 1 / (far - near), far / (far - near),
//   0, 0, 0, 1,
// }

// return Mat4{
//   2/(r-l), 0, 0, -(r+l)/(r-l),
//   0, 2/(t-b), 0, -(t+b)/(t-b),
//   0, 0, -1/(f-n), -n/(f-n),
//   0, 0, 0, 1
// }

// return Mat4{
//     2 / (right - left), 0, 0, -((right + left) / (right - left)),
//     0, 2 / (top - bottom), 0, -((top + bottom) / (top - bottom)),
//     0, 0, 1 / (far - near), far / (far - near), // Reversed Z mapping
//     0, 0, 0, 1,
// }
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


// math.mod
// mod_vec4_f32 :: proc(x: Vec4, y: f32) -> Vec4 {return x - y * math.floor_(x/y)}
// mod :: proc {mod_vec4_f32}
permute :: proc(x: Vec4) -> Vec4 {return linalg.mod(((x*34.0)+1.0)*x, 289.0)}
taylorInvSqrt :: proc(r: Vec4) -> Vec4 {return 1.79284291400159 - 0.85373472095314 * r}

hash :: proc(p: Vec3) -> Vec3 {
  return linalg.fract(
      linalg.sin(
        Vec3{
          linalg.dot(p, Vec3{1.0, 57.0, 113.0}),
          linalg.dot(p, Vec3{57.0, 113.0, 1.0}),
          linalg.dot(p, Vec3{113.0, 1.0, 57.0})
        }) *
      43758.5453);
}


@(require_results) cpu_snoise :: proc(v: Vec3) -> f32 {
C := Vec2{1.0/6.0, 1.0/3.0}
D := Vec4{0.0, 0.5, 1.0, 2.0}

// First corner
i: Vec3 = linalg.floor(v + linalg.dot(v, C.yyy) );
x0: Vec3 =   v - i + linalg.dot(i, C.xxx) ;

// Other corners
g: Vec3 = linalg.step(x0.yzx, x0.xyz);
l: Vec3 = 1.0 - g;
i1: Vec3 = linalg.min( g.xyz, l.zxy );
i2: Vec3 = linalg.max( g.xyz, l.zxy );

  //  x0 = x0 - 0. + 0.0 * C 
x1: Vec3 = x0 - i1 + 1.0 * C.xxx;
x2: Vec3 = x0 - i2 + 2.0 * C.xxx;
x3: Vec3 = x0 - 1. + 3.0 * C.xxx;

// Permutations
  i = linalg.mod(i, 289.0 ); 
  p: Vec4 = permute( permute( permute(i.z + Vec4{0.0, i1.z, i2.z, 1.0 }) + i.y + Vec4{0.0, i1.y, i2.y, 1.0 }) + i.x + Vec4{0.0, i1.x, i2.x, 1.0 })

// Gradients
// ( N*N points uniformly over a square, mapped onto an octahedron.)
  n_: f32 = 1.0/7.0 // N=7
  ns: Vec3 = n_ * D.wyz - D.xzx

  j: Vec4 = p - 49.0 * linalg.floor(p * ns.z *ns.z)  //  mod(p,N*N)

  x_: Vec4 = linalg.floor(j * ns.z)
  y_: Vec4 = linalg.floor(j - 7.0 * x_ )    // mod(j,N)

  x: Vec4 = x_ *ns.x + ns.yyyy
  y: Vec4 = y_ *ns.x + ns.yyyy
  h: Vec4 = 1.0 - linalg.abs(x) - linalg.abs(y)

  b0: Vec4 = Vec4{ x.x, x.y, y.x, y.y }
  b1: Vec4 = Vec4{ x.z, x.w, y.z, y.w }

  s0: Vec4 = linalg.floor(b0)*2.0 + 1.0
  s1: Vec4 = linalg.floor(b1)*2.0 + 1.0
  sh: Vec4 = -linalg.step(h, Vec4{0, 0, 0, 0})

  a0: Vec4 = b0.xzyw + s0.xzyw*sh.xxyy 
  a1: Vec4 = b1.xzyw + s1.xzyw*sh.zzww 

  p0: Vec3 = {a0.x, a0.y, h.x}
  p1: Vec3 = {a0.z, a0.w, h.y}
  p2: Vec3 = {a1.x, a1.y, h.z}
  p3: Vec3 = {a1.z, a1.w, h.w}

//Normalise gradients
  norm: Vec4 = taylorInvSqrt(
Vec4{linalg.dot(p0,p0), linalg.dot(p1,p1), linalg.dot(p2, p2), linalg.dot(p3,p3)}
)
  p0 *= norm.x
  p1 *= norm.y
  p2 *= norm.z
  p3 *= norm.w

// Mix final noise value
  m: Vec4 = linalg.max(0.6 - Vec4{linalg.dot(x0,x0), linalg.dot(x1,x1), linalg.dot(x2,x2), linalg.dot(x3,x3)}, 0.0);
  m = m * m;
  return clamp(42.0 * linalg.dot( m*m, Vec4{ linalg.dot(p0,x0), linalg.dot(p1,x1), 
                                linalg.dot(p2,x2), linalg.dot(p3,x3) } ), -1, 1)
}

@(require_results) cpu_voronoi3d :: proc(x: Vec3) -> Vec3 {
  p := linalg.floor(x)
  f := linalg.fract(x)

  id : f32 = 0
  res := Vec2{100, 100}
  for k := -1; k <= 1; k += 1 {
    for j := -1; j <= 1; j += 1 {
      for i := -1; i <= 1; i += 1 {
        b := Vec3{f32(i), f32(j), f32(k)}
        r := Vec3(b) - f + hash(p + b)
        d := linalg.dot(r, r)

        cond := max(linalg.sign(res.x - d), 0.0)
        nCond := 1.0 - cond

        cond2 := nCond * max(linalg.sign(res.y - d), 0.0)
        nCond2 := 1.0 - cond2

        id = (linalg.dot(p + b, Vec3{1.0, 57.0, 113.0}) * cond) + (id * nCond)
        res = Vec2{d, res.x} * cond + res * nCond

        res.y = cond2 * d + nCond2 * res.y
      }
    }
  }

  res = linalg.sqrt(res)
  return Vec3{res.x, res.y, abs(id)}
}

remap_range_f32 :: proc(x, from_min, from_max, to_min, to_max: f32) -> f32 {
  return to_min + (x - from_min) / (from_max - from_min) * (to_max - to_min)
}
remap_range :: proc{remap_range_f32}
