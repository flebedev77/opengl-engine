package main
import "core:fmt"
import "core:os"
import "core:mem"
import "core:math"
import gl "vendor:OpenGL"

CloudNoise :: struct {
  base_shape:    GpuID,
  detail_worley: GpuID,
}

Vec3i :: struct { x, y, z: i32 }

SdfCell :: struct {
  density:         f32,
  closest_surface: Vec3i,
  distance_sq:     f32,
}

bake_cloud_noise :: proc() -> CloudNoise {
  fmt.printf("Allocating 3d noise ")
  profile_begin()
  cloud_noise := CloudNoise{}
  base_shape_w, base_shape_h, base_shape_d := i32(128), i32(16), i32(128)

  base_loaded := false
  base_noise: []f32

  when #exists("../cloud_noise") {
    base_loaded = true
    base_noise = #load("../cloud_noise")
  } else {
    base_noise = make([]f32, base_shape_w * base_shape_h * base_shape_d, context.temp_allocator)
  }
  profile_end()

  coverage_bias := f32(0.0)
  perlin_weight := f32(0.1)

  if !base_loaded {
    fmt.printfln("Generating 3d noise ")
    profile_begin()
    for z : i32 = 0; z < base_shape_d; z += 1 {
      for y : i32 = 0; y < base_shape_h; y += 1 {
        for x : i32 = 0; x < base_shape_w; x += 1 {
          index := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
          fmt.printf("%0.2f%%           \r", (f32(index)/f32(base_shape_w * base_shape_h * base_shape_d)) * 100)

          p := Vec3{f32(x), f32(y), f32(z)} * 0.04
          percentage_to_apex := f32(y) / f32(base_shape_h)

          height_feather := clamp(1.0 - percentage_to_apex, 0, 1)
          perlin := (height_feather > 0) ? cpu_snoise(p) * height_feather : 0
          worley : f32 = (height_feather > 0) ? (1 - cpu_voronoi3d(p * 1.5).r) * height_feather : 0
          worley_perlin_weight : f32 = clamp(1 - worley + perlin_weight, 0, 1)
          perlin_worley := worley_perlin_weight * perlin + (1 - worley_perlin_weight) * worley

          high_freq_worley := 1 - cpu_voronoi3d(p * 6).r * 0.2
          perlin_worley = remap_range_f32(perlin_worley, 1 - high_freq_worley, 1, 0, 1)
          perlin_worley *= 0.1

          base_noise[index] = clamp(perlin_worley - coverage_bias, 0, 1)
        }
      }
    }
    fmt.printfln("")
    profile_end()

    fmt.printfln("Computing Signed Distance Field ")
    profile_begin()
    generate_exact_edt_sdf(base_noise, base_shape_w, base_shape_h, base_shape_d)
//
//     num_texels := base_shape_w * base_shape_h * base_shape_d
//     sdf_grid := make([]SdfCell, num_texels, context.temp_allocator)
//
//     for z in 0..<base_shape_d {
//       for y in 0..<base_shape_h {
//         for x in 0..<base_shape_w {
//           idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
//           density := base_noise[idx]
//
//           sdf_grid[idx].density = density
//           if density > 0.0 {
//             sdf_grid[idx].closest_surface = Vec3i{x, y, z}
//             sdf_grid[idx].distance_sq = 0.0
//           } else {
//             sdf_grid[idx].closest_surface = Vec3i{-1, -1, -1}
//             sdf_grid[idx].distance_sq = 1e9
//           }
//         }
//       }
//     }
//
// jfa_pass := proc(sdf_grid: []SdfCell, step, w, h, d: int) {
//         for z in 0..<d {
//             for y in 0..<h {
//                 for x in 0..<w {
//                     curr_idx := z * (w * h) + y * w + x
//
//                     for nz in -1..=1 {
//                         for ny in -1..=1 {
//                             for nx in -1..=1 {
//                                 sample_x := (x + nx * step) % w
//                                 if sample_x < 0 do sample_x += w
//
//                                 sample_z := (z + nz * step) % d
//                                 if sample_z < 0 do sample_z += d
//
//                                 sample_y := y + ny * step
//                                 if sample_y < 0 || sample_y >= h do continue
//
//                                 s_idx := sample_z * (w * h) + sample_y * w + sample_x
//                                 neighbor_surf := sdf_grid[s_idx].closest_surface
//
//                                 if neighbor_surf.x != -1 {
//                                     dx := f32(x - int(neighbor_surf.x))
//                                     if dx > f32(w / 2)  do dx -= f32(w)
//                                     if dx < f32(-w / 2) do dx += f32(w)
//
//                                     dz := f32(z - int(neighbor_surf.z))
//                                     if dz > f32(d / 2)  do dz -= f32(d)
//                                     if dz < f32(-d / 2) do dz += f32(d)
//
//                                     dy := f32(y - int(neighbor_surf.y))
//
//                                     dist_sq := dx*dx + dy*dy + dz*dz
//                                     if dist_sq < sdf_grid[curr_idx].distance_sq {
//                                         sdf_grid[curr_idx].distance_sq = dist_sq
//                                         sdf_grid[curr_idx].closest_surface = neighbor_surf
//                                     }
//                                 }
//                             }
//                         }
//                     }
//                 }
//             }
//         }
//     }
//
//     // 2. Main Jump Flooding Loop (Logarithmic steps)
//     max_dim := int(max(base_shape_w, max(base_shape_h, base_shape_d)))
//     step := max_dim / 2
//     for step > 0 {
//         jfa_pass(sdf_grid, step, int(base_shape_w), int(base_shape_h), int(base_shape_d))
//         step /= 2
//     }
//
//     // 3. JFA+2 Refinement Passes (Fixes empty space discontinuities)
//     jfa_pass(sdf_grid, 2, int(base_shape_w), int(base_shape_h), int(base_shape_d))
//     jfa_pass(sdf_grid, 1, int(base_shape_w), int(base_shape_h), int(base_shape_d))
//
//     max_possible_dist := math.sqrt(f32(base_shape_w*base_shape_w + base_shape_h*base_shape_h + base_shape_d*base_shape_d))
//     for i in 0..<num_texels {
//       if sdf_grid[i].density > 0.0 {
//         base_noise[i] = sdf_grid[i].density
//       } else {
//         true_dist := math.sqrt(sdf_grid[i].distance_sq)
//         normalized_dist := true_dist / max_possible_dist
//         base_noise[i] = -normalized_dist
//       }
//     }
    profile_end()

    fmt.printf("Saving 3d noise ")
    profile_begin()
    os.write_entire_file("cloud_noise", mem.slice_data_cast([]u8, base_noise))
    profile_end()
  }

  fmt.printf("Uploading 3d noise ")
  profile_begin()
  cloud_noise.base_shape = upload_noise(base_shape_w, base_shape_h, base_shape_d, &base_noise[0])
  profile_end()

  fmt.printf("Allocating 3d detail noise ")
  profile_begin()
  detail_w, detail_h, detail_d := i32(32), i32(32), i32(32)
  detail_noise: []f32
  detail_loaded := false
  when #exists("../cloud_noise_detail") {
    detail_loaded = true
    detail_noise = #load("../cloud_noise_detail")
  } else {
    detail_noise = make([]f32, detail_w * detail_h * detail_d, context.temp_allocator)
  }
  profile_end()


  if !detail_loaded {
    fmt.printf("Generating 3d detail noise ")
    profile_begin()
    for z : i32 = 0; z < detail_d; z += 1 {
      for y : i32 = 0; y < detail_h; y += 1 {
        for x : i32 = 0; x < detail_w; x += 1 {
          p := Vec3{f32(x), f32(y), f32(z)} * 0.1
          worley : f32 = cpu_voronoi3d(p * 1.5).r
          detail_noise[z * (detail_h * detail_d) + y * detail_w + x] =
          clamp(worley, 0, 1)
        }
      }
    }

    profile_end()

    fmt.printf("Saving 3d detail noise ")
    profile_begin()
    os.write_entire_file("cloud_noise_detail", mem.slice_data_cast([]u8, detail_noise))
    profile_end()
  }

  fmt.printf("Uploading 3d detail noise ")
  profile_begin()
  cloud_noise.detail_worley = upload_noise(detail_w, detail_h, detail_d, &detail_noise[0])
  profile_end()

  return cloud_noise
}

upload_noise :: proc(w, h, d: i32, data: rawptr) -> GpuID {
  shape: GpuID
  gl.GenTextures(1, &shape)
  gl.BindTexture(gl.TEXTURE_3D, shape)
  gl.TexImage3D(gl.TEXTURE_3D, 0, gl.R32F, w, h, d, 0, gl.RED, gl.FLOAT, data)

  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

  // gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
  // gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)

  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_BORDER)

  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_R, gl.REPEAT)
  return shape
}

generate_exact_edt_sdf :: proc(base_noise: []f32, base_shape_w, base_shape_h, base_shape_d: i32) {
    num_texels := base_shape_w * base_shape_h * base_shape_d
    
    // Allocate intermediate 3D grids for the dimensional passes
    grid_a := make([]f32, num_texels, context.temp_allocator)
    grid_b := make([]f32, num_texels, context.temp_allocator)

    // 1. Initialization: Inside features are 0, outside is infinity (1e9)
    for i in 0..<num_texels {
        grid_a[i] = base_noise[i] > 0 ? 0.0 : 1e9
    }

    // Allocate 1D scratchpads (X and Z require 3x space to calculate wrapping seamlessly)
    max_len := max(3 * base_shape_w, max(base_shape_h, 3 * base_shape_d))
    scratch_f := make([]f32, max_len, context.temp_allocator)
    scratch_d := make([]f32, max_len, context.temp_allocator)
    scratch_v := make([]i32, max_len, context.temp_allocator)
    scratch_z := make([]f32, max_len + 1, context.temp_allocator)

    // Core 1D Felzenszwalb-Huttenlocher Distance Transform
    edt_1d := proc(f: []f32, d: []f32, v: []i32, z: []f32) {
        n := i32(len(f))
        k := 0
        v[0] = 0
        z[0] = -1e30
        z[1] = 1e30

        for q in 1..<n {
            var_s := f32(0.0)
            for k >= 0 {
                q_f := f32(q)
                vk_f := f32(v[k])
                var_s = ((f[q] + q_f*q_f) - (f[v[k]] + vk_f*vk_f)) / (2.0 * (q_f - vk_f))
                if var_s <= z[k] {
                    k -= 1
                } else {
                    break
                }
            }
            k += 1
            v[k] = i32(q)
            z[k] = var_s
            z[k+1] = 1e30
        }

        k = 0
        for q in 0..<n {
            q_f := f32(q)
            for z[k+1] < q_f {
                k += 1
            }
            vk_f := f32(v[k])
            d[q] = (q_f - vk_f)*(q_f - vk_f) + f[v[k]]
        }
    }

    // PASS 1: X-Axis (Periodic / Wrapping)
    for z in 0..<base_shape_d {
        for y in 0..<base_shape_h {
            for x in 0..<3*base_shape_w {
                orig_x := x % base_shape_w
                idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + orig_x
                scratch_f[x] = grid_a[idx]
            }
            
            edt_1d(scratch_f[:3*base_shape_w], scratch_d[:3*base_shape_w], scratch_v[:3*base_shape_w], scratch_z[:3*base_shape_w + 1])
            
            for x in 0..<base_shape_w {
                idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
                grid_b[idx] = scratch_d[base_shape_w + x] // Extract the middle wrapped section
            }
        }
    }

    // PASS 2: Y-Axis (Non-periodic / Clamped)
    for z in 0..<base_shape_d {
        for x in 0..<base_shape_w {
            for y in 0..<base_shape_h {
                idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
                scratch_f[y] = grid_b[idx]
            }
            
            edt_1d(scratch_f[:base_shape_h], scratch_d[:base_shape_h], scratch_v[:base_shape_h], scratch_z[:base_shape_h + 1])
            
            for y in 0..<base_shape_h {
                idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
                grid_a[idx] = scratch_d[y]
            }
        }
    }

    // PASS 3: Z-Axis (Periodic / Wrapping)
    for y in 0..<base_shape_h {
        for x in 0..<base_shape_w {
            for z in 0..<3*base_shape_d {
                orig_z := z % base_shape_d
                idx := orig_z * (base_shape_w * base_shape_h) + y * base_shape_w + x
                scratch_f[z] = grid_a[idx]
            }
            
            edt_1d(scratch_f[:3*base_shape_d], scratch_d[:3*base_shape_d], scratch_v[:3*base_shape_d], scratch_z[:3*base_shape_d + 1])
            
            for z in 0..<base_shape_d {
                idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
                grid_b[idx] = scratch_d[base_shape_d + z] // Extract the middle wrapped section
            }
        }
    }

    max_possible_dist := math.sqrt(f32(base_shape_w*base_shape_w + base_shape_h*base_shape_h + base_shape_d*base_shape_d))
    for i in 0..<num_texels {
        if base_noise[i] <= 0.0 {
            true_dist := math.sqrt(grid_b[i]) // grid_b stores squared distances
            normalized_dist := true_dist / max_possible_dist
            base_noise[i] = -normalized_dist
        }
    }

}
