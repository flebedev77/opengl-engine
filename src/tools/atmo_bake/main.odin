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

main :: proc() {
  fmt.printfln("Hello world!")
  rl.InitWindow(0, 0, "Atmosphere baker")
  rl.SetConfigFlags({.VSYNC_HINT, .FULLSCREEN_MODE, .MSAA_4X_HINT})

  window_width: f32 = 0
  window_height: f32 = 0

  for !rl.WindowShouldClose() {
    window_width = f32(rl.GetScreenWidth())
    window_height = f32(rl.GetScreenHeight())
    rl.BeginDrawing()
    rl.ClearBackground({120, 120, 255, 0})
    // rl.DrawPixel()
    mp := rl.GetMousePosition() / {window_width, window_height}
    mp = mp * 2 - {1, 1}

    {
      ray_ang := f32(0)
      ray_ang_step := f32(math.PI/100)
      ray_ang_range := f32(math.PI)
      ray_ang_steps := ray_ang_range / ray_ang_step
      sun_pos := Vec3{mp.x * 70, 10, 0}//mp.y * 20}
      atmo_scatter := Vec3{0.3, 0.3, 0.8} * 1.01
      ray_step := f32(0.1)
      ray_light_step := f32(0.1)
      for ray_ang = 0; ray_ang < ray_ang_range; ray_ang += ray_ang_step {
        index := ray_ang / ray_ang_step
        ray_dir := Vec3{
          math.cos(ray_ang),
          math.sin(ray_ang),
          0
        }
        cos_theta := linalg.dot(ray_dir, linalg.normalize(sun_pos))
        rayleigh := rayleigh_phase(cos_theta)
        // fmt.printfln("%f %f %f %f", index, ray_dir.x, ray_dir.y, ray_dir.z)
        w := f32(window_width / ray_ang_steps)
        inscattering := Vec3{0, 0, 0}
        transmittance := f32(1)
        ray_pos := Vec3{0, 0, 0}
        for i in 0..<50 {
          distance_center := linalg.length(ray_pos)
          if distance_center > 100 do break

          ray_pos += ray_dir * ray_step

          air_density := math.pow(math.E, -distance_center * 1.5)
          transmittance *= math.pow(math.E, -air_density * 0.2 * ray_step)
          light_transmittance := f32(1)
          light_pos := ray_pos
          light_dir := linalg.normalize(sun_pos - light_pos)
          for j in 0..<20 {
            ldist_center := linalg.length(light_pos)
            if ldist_center > 100 do break
            dens := math.pow(math.E, -ldist_center * 1.5)
            light_transmittance *= math.pow(math.E, -dens * 0.2 * ray_step)
            light_pos += light_dir * ray_light_step
          }
          sca := light_transmittance * transmittance
          inscattering += atmo_scatter * sca
          // inscattering.r *= air_density * 3.0
          // inscattering.g *= air_density * 2.0
          // inscattering.b *= air_density
        }
        inscattering *= rayleigh
        if inscattering.x > 1 do inscattering.x = 1
        if inscattering.y > 1 do inscattering.y = 1
        if inscattering.z > 1 do inscattering.z = 1


        rl.DrawRectangle(
          i32(index * w),
          0, i32(w)+1, i32(window_height), rl.Color{u8(inscattering.x*255), u8(inscattering.y*255), u8(inscattering.z*255), 255}
        )
        // rl.DrawRectangle(
        //   i32(index * w),
        //   0, i32(w)+1, i32(window_height), rl.Color{u8(math.abs(ray_dir.x)*255), u8(math.abs(ray_dir.y)*255), 0, 255}
        // )

      }
      // rl.CloseWindow()
    }

    rl.DrawFPS(10, 10)
    rl.EndDrawing()
  }

  rl.CloseWindow()
}
