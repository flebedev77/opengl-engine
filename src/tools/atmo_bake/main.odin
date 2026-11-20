package atmo_bake
import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 900

Vec4 :: [4]f32
Vec3 :: [3]f32

AtmosphereConfig :: struct {
  radius: f32,
  scattering: Vec3,
  transmittance: f32
}

BETA_RAYLEIGH := Vec3{5.8e-6, 13.5e-6, 33.1e-6}

rayleigh_phase :: proc(cos_theta: f32) -> f32 {
	return (3.0 / (16.0 * math.PI)) * (1.0 + cos_theta * cos_theta)
}

// main :: proc() {
//   fmt.printfln("Hello world!")
//   rl.InitWindow(0, 0, "Atmosphere baker")
//   rl.SetConfigFlags({.VSYNC_HINT, .FULLSCREEN_MODE, .MSAA_4X_HINT})
//
//   window_width: f32 = 0
//   window_height: f32 = 0
//
//   for !rl.WindowShouldClose() {
//     window_width = f32(rl.GetScreenWidth())
//     window_height = f32(rl.GetScreenHeight())
//     rl.BeginDrawing()
//     rl.ClearBackground({120, 120, 255, 0})
//     // rl.DrawPixel()
//     mp := rl.GetMousePosition() / {window_width, window_height}
//     mp = mp * 2 - {1, 1}
//
//     {
//       ray_ang := f32(0)
//       ray_ang_step := f32(math.PI/100)
//       ray_ang_range := f32(math.PI)
//       ray_ang_steps := ray_ang_range / ray_ang_step
//       sun_pos := Vec3{mp.x * 70, 10, 0}//mp.y * 20}
//       atmo_scatter := Vec3{0.3, 0.3, 0.8} * 1.01
//       ray_step := f32(0.1)
//       ray_light_step := f32(0.1)
//       for ray_ang = 0; ray_ang < ray_ang_range; ray_ang += ray_ang_step {
//         index := ray_ang / ray_ang_step
//         ray_dir := Vec3{
//           math.cos(ray_ang),
//           math.sin(ray_ang),
//           0
//         }
//         cos_theta := linalg.dot(ray_dir, linalg.normalize(sun_pos))
//         rayleigh := rayleigh_phase(cos_theta)
//         // fmt.printfln("%f %f %f %f", index, ray_dir.x, ray_dir.y, ray_dir.z)
//         w := f32(window_width / ray_ang_steps)
//         inscattering := Vec3{0, 0, 0}
//         transmittance := f32(1)
//         ray_pos := Vec3{0, 0, 0}
//         for i in 0..<50 {
//           distance_center := linalg.length(ray_pos)
//           if distance_center > 100 do break
//
//           ray_pos += ray_dir * ray_step
//
//           air_density := math.pow(math.E, -distance_center * 1.5)
//           transmittance *= math.pow(math.E, -air_density * 0.2 * ray_step)
//           light_transmittance := f32(1)
//           light_pos := ray_pos
//           light_dir := linalg.normalize(sun_pos - light_pos)
//           for j in 0..<20 {
//             ldist_center := linalg.length(light_pos)
//             if ldist_center > 100 do break
//             dens := math.pow(math.E, -ldist_center * 1.5)
//             light_transmittance *= math.pow(math.E, -dens * 0.2 * ray_step)
//             light_pos += light_dir * ray_light_step
//           }
//           sca := light_transmittance * transmittance
//           inscattering += atmo_scatter * sca
//           // inscattering.r *= air_density * 3.0
//           // inscattering.g *= air_density * 2.0
//           // inscattering.b *= air_density
//         }
//         inscattering *= rayleigh
//         if inscattering.x > 1 do inscattering.x = 1
//         if inscattering.y > 1 do inscattering.y = 1
//         if inscattering.z > 1 do inscattering.z = 1
//
//
//         rl.DrawRectangle(
//           i32(index * w),
//           0, i32(w)+1, i32(window_height), rl.Color{u8(inscattering.x*255), u8(inscattering.y*255), u8(inscattering.z*255), 255}
//         )
//         // rl.DrawRectangle(
//         //   i32(index * w),
//         //   0, i32(w)+1, i32(window_height), rl.Color{u8(math.abs(ray_dir.x)*255), u8(math.abs(ray_dir.y)*255), 0, 255}
//         // )
//
//       }
//       // rl.CloseWindow()
//     }
//
//     rl.DrawFPS(10, 10)
//     rl.EndDrawing()
//   }
//
//   rl.CloseWindow()
// }

rt: rl.RenderTexture2D
// rt_width :: 300
// rt_height :: 300


rt_width :: 64
rt_height :: 64

atmo_density_mult := f32(1.8)
atmo_axis_mult := f32(1.7)
light_density_mult := f32(100000000.0)

sample_atmo_density :: proc (p: Vec3) -> f32 {
  // return 0
  v: f32 = math.exp(-(linalg.length(p)) * atmo_axis_mult)
  v *= atmo_density_mult;
  // v *= 2.1
  // v *= 1308.1;
  // return v

  return math.clamp(v, 0, 1)
}

main :: proc() {
  rl.InitWindow(0, 0, "Atmosphere baker")
  rl.SetConfigFlags({.VSYNC_HINT, .FULLSCREEN_MODE, .MSAA_4X_HINT})

  window_width: f32 = 0
  window_height: f32 = 0

  rt = rl.LoadRenderTexture(rt_width, rt_height)

  for !rl.WindowShouldClose() {
    window_width = f32(rl.GetScreenWidth())
    window_height = f32(rl.GetScreenHeight())
    rl.BeginDrawing()
    rl.ClearBackground({120, 120, 255, 255})

    rl.BeginTextureMode(rt)
    rl.ClearBackground({255, 0, 0, 255})

    inscattering := Vec3{}
    extinction := Vec3{1, 1, 1}
    step_size := f32(0.01)

    light_densities := Vec3{635, 540, 470}
    light_densities = Vec3{
      1/math.pow(light_densities.r, 4),
      1/math.pow(light_densities.g, 4),
      1/math.pow(light_densities.b, 4)
    } * light_density_mult

    for y in 0..<rt_height {
      for x in 0..<rt_width {
        // x = angle to sun
        // y = altitude
        x_norm, y_norm := f32(x)/rt_width, f32(y)/rt_height
        angle_to_sun := (x_norm-0.5)*2 * math.PI // Maybe don't need entire revolution
        altitude := y_norm
        pos := Vec3{0, altitude, 0} // Technically, don't need an entire 3d representation
        dens := sample_atmo_density(pos)
        for i in 0..<64 {
          advance_vector := Vec3{math.cos(angle_to_sun), math.sin(angle_to_sun), 0}
          dens = sample_atmo_density(pos)
          extinction.r *= math.exp(-dens * step_size * light_densities.r)
          extinction.g *= math.exp(-dens * step_size * light_densities.g)
          extinction.b *= math.exp(-dens * step_size * light_densities.b)

          pos += advance_vector
        }
        // extinction *= 1000.01
        inscattering = extinction
        // inscattering = Vec3{math.log_f32(extinction.r, 2), math.log_f32(extinction.g, 2), math.log_f32(extinction.b, 2)}
        inscattering = Vec3{clamp(inscattering.r, 0, 1), clamp(inscattering.g, 0, 1), clamp(inscattering.b, 0, 1)}
        rl.DrawPixel(i32(x), i32(y), rl.Color{u8(inscattering.r*255), u8(inscattering.g*255), u8(inscattering.b*255), 255})
        // rl.DrawPixel(i32(x), i32(y), rl.Color{u8(dens*255), 0, 0, 255})
      }
    }

    rl.EndTextureMode()

    smallest_dim := min(rt_width, rt_height)
    smallest_dim_window := min(f32(rl.GetRenderHeight()), f32(rl.GetRenderWidth()))
    rl.DrawTexturePro(rt.texture, {0, 0, rt_width, rt_height},
      {f32(rl.GetRenderWidth())*0.5-smallest_dim_window*0.5, 0, smallest_dim_window, -smallest_dim_window}, {0,0}, 0, rl.WHITE)

    atmo_mult_rate := f32(10.1) * rl.GetFrameTime()
    if rl.IsKeyDown(.UP) {
      atmo_density_mult += atmo_mult_rate
    }
    if rl.IsKeyDown(.DOWN) {
      atmo_density_mult -= atmo_mult_rate
    }
    if rl.IsKeyDown(.RIGHT) {
      atmo_axis_mult += atmo_mult_rate
    }
    if rl.IsKeyDown(.LEFT) {
      atmo_axis_mult -= atmo_mult_rate
    }
    light_density_mult_rate := f32(10000000)
    if rl.IsKeyDown(.LEFT_SHIFT) {
      light_density_mult += atmo_mult_rate * light_density_mult_rate
    }
    if rl.IsKeyDown(.LEFT_CONTROL) {
      light_density_mult -= atmo_mult_rate * light_density_mult_rate
    }
    atmo_density_mult = clamp(atmo_density_mult, 0, 100)
    atmo_axis_mult = clamp(atmo_axis_mult, 0, 10)

    rl.DrawFPS(10, 10)
    rl.EndDrawing()
  }

  rl.CloseWindow()
}
