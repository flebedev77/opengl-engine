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
    fmt.printf("Generating 3d noise ")
    profile_begin()
    for z : i32 = 0; z < base_shape_d; z += 1 {
      for y : i32 = 0; y < base_shape_h; y += 1 {
        for x : i32 = 0; x < base_shape_w; x += 1 {
          index := z * (base_shape_w * base_shape_h) + y * base_shape_w + x

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
    profile_end()

    fmt.printf("Computing Signed Distance Field ")
    profile_begin()

    num_texels := base_shape_w * base_shape_h * base_shape_d
    sdf_grid := make([]SdfCell, num_texels, context.temp_allocator)

    for z in 0..<base_shape_d {
      for y in 0..<base_shape_h {
        for x in 0..<base_shape_w {
          idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x
          density := base_noise[idx]

          sdf_grid[idx].density = density
          if density > 0.0 {
            sdf_grid[idx].closest_surface = Vec3i{x, y, z}
            sdf_grid[idx].distance_sq = 0.0
          } else {
            sdf_grid[idx].closest_surface = Vec3i{-1, -1, -1}
            sdf_grid[idx].distance_sq = 1e9
          }
        }
      }
    }

    max_dim := max(base_shape_w, max(base_shape_h, base_shape_d))
    step := max_dim / 2
    for step > 0 {
      for z in 0..<base_shape_d {
        for y in 0..<base_shape_h {
          for x in 0..<base_shape_w {
            curr_idx := z * (base_shape_w * base_shape_h) + y * base_shape_w + x

            for nz in -1..=1 {
              for ny in -1..=1 {
                for nx in -1..=1 {
                  sample_x := (x + i32(nx) * step) % base_shape_w
                  if sample_x < 0 do sample_x += base_shape_w

                    sample_z := (z + i32(nz) * step) % base_shape_d
                    if sample_z < 0 do sample_z += base_shape_d

                      sample_y := y + i32(ny) * step
                      if sample_y < 0 || sample_y >= base_shape_h do continue

                        s_idx := sample_z * (base_shape_w * base_shape_h) + sample_y * base_shape_w + sample_x
                        neighbor_surf := sdf_grid[s_idx].closest_surface

                        if neighbor_surf.x != -1 {
                          dx := f32(x - neighbor_surf.x)
                          if dx > f32(base_shape_w / 2)  do dx -= f32(base_shape_w)
                            if dx < f32(-base_shape_w / 2) do dx += f32(base_shape_w)

                              dz := f32(z - neighbor_surf.z)
                              if dz > f32(base_shape_d / 2)  do dz -= f32(base_shape_d)
                                if dz < f32(-base_shape_d / 2) do dz += f32(base_shape_d)

                                  dy := f32(y - neighbor_surf.y)

                                  dist_sq := dx*dx + dy*dy + dz*dz
                                  if dist_sq < sdf_grid[curr_idx].distance_sq {
                                    sdf_grid[curr_idx].distance_sq = dist_sq
                                    sdf_grid[curr_idx].closest_surface = neighbor_surf
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                    step /= 2
    }

    max_possible_dist := math.sqrt(f32(base_shape_w*base_shape_w + base_shape_h*base_shape_h + base_shape_d*base_shape_d))
    for i in 0..<num_texels {
      if sdf_grid[i].density > 0.0 {
        base_noise[i] = sdf_grid[i].density
      } else {
        true_dist := math.sqrt(sdf_grid[i].distance_sq)
        normalized_dist := true_dist / max_possible_dist
        base_noise[i] = -normalized_dist
      }
    }
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
  gl.TexImage3D(gl.TEXTURE_3D, 0, gl.R16F, w, h, d, 0, gl.RED, gl.FLOAT, data)

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
