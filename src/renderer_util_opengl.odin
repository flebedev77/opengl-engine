package main
import "core:fmt"
import "core:mem"
import gl "vendor:OpenGL"

CloudNoise :: struct {
  base_shape: GpuID
}


bake_cloud_noise :: proc() -> CloudNoise {
  fmt.printfln("Allocating 3d noise")
  cloud_noise := CloudNoise{}
  base_shape_w, base_shape_h, base_shape_d := i32(128),
    i32(50),
    i32(128)
  base_noise := make([]f32, base_shape_w * base_shape_h * base_shape_d, context.temp_allocator)

  fmt.printfln("Generating 3d noise")
  for z : i32 = 0; z < base_shape_d; z += 1 {
    for y : i32 = 0; y < base_shape_h; y += 1 {
      for x : i32 = 0; x < base_shape_w; x += 1 {
        p := Vec3{f32(x), f32(y), f32(z)} * 0.01
        base_noise[z * (base_shape_h * base_shape_d) + y * base_shape_w + x] = 
        cpu_snoise(p)
      }
    }
  }

  fmt.printfln("Uploading 3d noise")
  gl.GenTextures(1, &cloud_noise.base_shape)
  gl.BindTexture(gl.TEXTURE_3D, cloud_noise.base_shape)
  gl.TexImage3D(gl.TEXTURE_3D, 0, gl.R32F, base_shape_w, base_shape_h, base_shape_d, 0, gl.RED, gl.FLOAT, &base_noise[0])

  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_S, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_T, gl.REPEAT)
  gl.TexParameteri(gl.TEXTURE_3D, gl.TEXTURE_WRAP_R, gl.REPEAT)

  return cloud_noise
}
