package main
import "core:fmt"
import "core:os"
import "core:mem"
import gl "vendor:OpenGL"

CloudNoise :: struct {
  base_shape: GpuID,
  detail_worley: GpuID
}


bake_cloud_noise :: proc(load_from_file := true) -> CloudNoise {
  load_from_file := load_from_file
  fmt.printf("Allocating 3d noise ")
  profile_begin()
  cloud_noise := CloudNoise{}
  base_shape_w, base_shape_h, base_shape_d := i32(128),
    i32(32),
    i32(128)

  base_noise: []f32
  when #exists("../cloud_noise") {
    base_noise = #load("../cloud_noise")
    // TODO: Handle case where we don't want to load from the file even though it exists
  } else {
    base_noise = make([]f32, base_shape_w * base_shape_h * base_shape_d, context.temp_allocator)
  }
  profile_end()


  coverage_bias := f32(-0.0)
  worley_perlin_weight := f32(0.6)
  if !load_from_file || len(base_noise) == 0 {
    fmt.printf("Generating 3d noise ")
    profile_begin()
    for z : i32 = 0; z < base_shape_d; z += 1 {
      for y : i32 = 0; y < base_shape_h; y += 1 {
        for x : i32 = 0; x < base_shape_w; x += 1 {
          p := Vec3{f32(x), f32(y), f32(z)} * 0.1
          p.y *= f32(base_shape_d) / f32(base_shape_h)
          perlin := cpu_snoise(p)
          worley : f32 = 1-cpu_voronoi3d(p * 2).r
          perlin_worley := worley_perlin_weight * perlin + (1-worley_perlin_weight) * worley//remap_range(perlin, 1-worley, 1, 0, 1)
          base_noise[z * (base_shape_h * base_shape_d) + y * base_shape_w + x] = 
            perlin_worley
          // worley_perlin_weight * clamp(1-cpu_voronoi3d(p * 2).r + coverage_bias, 0, 1) +
          // (1-worley_perlin_weight) * clamp(cpu_snoise(p) + coverage_bias, 0, 1)
        }
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

  fmt.printf("Allocating 3d noise ")
  profile_begin()
  detail_w, detail_h, detail_d := i32(32), i32(32), i32(32)
  detail_noise: []f32
  when #exists("../cloud_noise_detail") {
    detail_noise = #load("../cloud_noise_detail")
  } else {
    detail_noise = make([]f32, detail_w * detail_h * detail_d, context.temp_allocator)
  }
  profile_end()


  if !load_from_file || len(detail_noise) == 0 {
    fmt.printf("Generating detail 3d noise ")
    profile_begin()
    for z : i32 = 0; z < detail_d; z += 1 {
      for y : i32 = 0; y < detail_h; y += 1 {
        for x : i32 = 0; x < detail_w; x += 1 {
          p := Vec3{f32(x), f32(y), f32(z)} * 0.1
          worley : f32 = cpu_voronoi3d(p * 1.5).r
          detail_noise[z * (detail_h * detail_d) + y * detail_w + x] =
          (worley);//, 0, 1)
        }
      }
    }

    profile_end()

    fmt.printf("Saving detail 3d noise ")
    profile_begin()
    os.write_entire_file("cloud_noise_detail", mem.slice_data_cast([]u8, detail_noise))
    profile_end()
  }

  fmt.printf("Uploading 3d noise ")
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

  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_R, gl.REPEAT)
  return shape
}
