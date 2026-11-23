package atmo_bake
import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1000
WINDOW_HEIGHT :: 900

Vec4 :: [4]f32
Vec3 :: [3]f32
Vec2 :: [2]f32

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
export_rt: rl.RenderTexture2D
// rt_width :: 300
// rt_height :: 300

// rt_width :: 16
// rt_height :: 16

rt_width :: 64
rt_height :: 64

export_rt_width :: 512
export_rt_height :: 512
// export_rt_width :: 64
// export_rt_height :: 64
export_step_size :: 0.005
// export_step_count :: 128
export_step_count :: 256

atmo_density_mult := f32(1.8)
atmo_axis_mult := f32(1.7)
light_density_mult := f32(100000000.0)

hover_color := Vec3{0,0,0}

exposure_sliderdata := SliderData{value = 1, max_value=1, min_value=0}
steps_sliderdata := SliderData{value = 64, max_value=512, min_value=1}
stepsize_sliderdata := SliderData{value = 0.01, max_value=0.4, min_value=0.00001}
planetsize_sliderdata := SliderData{value = 1, max_value=100, min_value=0.0}

pal: Pallette
Pallette :: struct {
  window_background,
  button,
  button_hover,
  button_down,
  knob_hover,
  knob_down,
  cell_label,
  resize_line,
  board_light,
  board_dark: rl.Color
}

EPS :: 1e-5

export_render_texture :: proc(rt: rl.RenderTexture2D, path: cstring) -> bool {
	img := rl.LoadImageFromTexture(rt.texture) // reads pixels back from the GPU
	defer rl.UnloadImage(img)

	// rl.ImageFlipVertical(&img) // render textures are stored upside down (OpenGL origin)
	return rl.ExportImage(img, path)
}

ray_circle_intersect :: proc(origin, direction, center: Vec2, radius: f32) -> (tenter: f32, texit: f32, ok: bool) {
	f := origin - center
	a := direction.x*direction.x + direction.y*direction.y
	if a == 0 do return 0, 0, false

	b := 2 * (f.x*direction.x + f.y*direction.y)
	c := f.x*f.x + f.y*f.y - radius*radius

	disc := b*b - 4*a*c
	if disc < 0 do return 0, 0, false

	sqrt_disc := math.sqrt(disc)
	t1 := (-b - sqrt_disc) / (2*a)
	t2 := (-b + sqrt_disc) / (2*a)

	// if t1 > EPS do return t1, true
	// if t2 > EPS do return t2, true
	// return 0, 0, false
  t_in, t_out := min(t1, t2), max(t1, t2)
  if t_in < 0 || t_out < 0 do return 0, 0, false
  return t_in, t_out, true
}
sample_atmo_density :: proc (p: Vec3) -> f32 {
  // return 0
  v: f32 = math.exp(-(linalg.length(p)) * atmo_axis_mult)
  v *= atmo_density_mult; // same as e^{-ln(atmo_density_mult)-x}
  // v *= 2.1
  // v *= 1308.1;
  // return v

  return math.clamp(v, 0, 1) * 10000
}

render_atmo :: proc(step_size: f32, step_count: i32, norm_mp := Vec2{0, 0}, rt_wh := Vec2{rt_width, rt_height}) {
  inscattering := Vec3{}
  extinction := Vec3{1, 1, 1}

  light_densities := Vec3{635, 540, 470}
  light_densities = Vec3{
    1/math.pow(light_densities.r, 4),
    1/math.pow(light_densities.g, 4),
    1/math.pow(light_densities.b, 4)
  } * light_density_mult

  for y in 0..<rt_wh.y {
    for x in 0..<rt_wh.x {
      // x = angle to sun
      // y = altitude
      x_norm, y_norm := f32(x)/rt_wh.x, f32(y)/rt_wh.y
      angle_to_sun := math.acos(x_norm*2-1)//(x_norm) * math.PI // Maybe don't need entire revolution
      altitude := y_norm// - 0.1
      pos := Vec3{0, altitude, 0} // Technically, don't need an entire 3d representation
      dens := sample_atmo_density(pos)
      advance_vector := Vec3{math.sin(angle_to_sun), math.cos(angle_to_sun), 0}
      earth_r: f32 = planetsize_sliderdata.value
      t_in, t_out, is_hit := ray_circle_intersect(pos.xy, advance_vector.xy, {0, -earth_r}, earth_r)
      // fmt.printfln("%v", is_hit)
      advance_vector *= step_size
      extinction = Vec3{1, 1, 1}
      // if !is_hit {
      //   for i in 0..< step_count {
      //     dens = sample_atmo_density(pos)
      //     extinction.r *= math.exp(-dens * step_size * light_densities.r)
      //     extinction.g *= math.exp(-dens * step_size * light_densities.g)
      //     extinction.b *= math.exp(-dens * step_size * light_densities.b)
      //
      //     pos += advance_vector
      //   }
      // } else {
      //   extinction = Vec3{0, 0, 0}
      // }


      for i in 0..<step_count {
        dens = sample_atmo_density(pos)
        extinction.r *= math.exp(-dens * step_size * light_densities.r)
        extinction.g *= math.exp(-dens * step_size * light_densities.g)
        extinction.b *= math.exp(-dens * step_size * light_densities.b)

        pos += advance_vector
      }
      if is_hit {
        // extinction = Vec3{0, 0, 0}
        extinction *= clamp(earth_r-max((t_out-t_in), 0), 0, 1)
      }
      // extinction *= 1000.01
      extinction *= exposure_sliderdata.value
      inscattering = extinction
      // inscattering = extinction * 0.4

      // norm_mp := mp - Vec2{rt_pos.x, rt_pos.y}
      // // fmt.printfln("%v", norm_mp)
      // norm_mp = Vec2{
      //   math.floor(norm_mp.x / rt_pos.width),
      //   math.floor(norm_mp.y / rt_pos.height)
      // }
      if (norm_mp.x) == x && (norm_mp.y) == y {
        hover_color = extinction
      }
      // }
      // inscattering = extinction * 1/(linalg.length(extinction))
      // inscattering = Vec3{math.log_f32(extinction.r, 2), math.log_f32(extinction.g, 2), math.log_f32(extinction.b, 2)}
      inscattering = Vec3{clamp(inscattering.r, 0, 1), clamp(inscattering.g, 0, 1), clamp(inscattering.b, 0, 1)}
      rl.DrawPixel(i32(x), i32(y), rl.Color{u8(inscattering.r*255), u8(inscattering.g*255), u8(inscattering.b*255), 255})
      // rl.DrawPixel(i32(x), i32(y), rl.Color{u8(dens*255), 0, 0, 255})
  }
    }
}

main :: proc() {
  rl.InitWindow(0, 0, "Atmosphere baker")
  rl.SetConfigFlags({.VSYNC_HINT, .FULLSCREEN_MODE, .MSAA_4X_HINT})

  pal.resize_line = rl.Color{74, 74, 74, 255}
  pal.cell_label = rl.Color{200, 200, 200, 155}
  pal.window_background = rl.Color{30, 30, 30, 255}
  pal.board_light = rl.Color{56, 56, 56, 255}
  pal.board_dark = rl.Color{40, 40, 40, 255}
  pal.button = rl.Color{35, 35, 35, 255}
  pal.button_hover = rl.Color{33, 33, 33, 255}
  pal.button_down = rl.Color{30, 30, 30, 255}
  pal.knob_hover = rl.Color{180, 180, 180, 255}
  pal.knob_down = rl.Color{130, 130, 130, 255}

  window_width: f32 = 0
  window_height: f32 = 0

  rt = rl.LoadRenderTexture(rt_width, rt_height)
  export_rt = rl.LoadRenderTexture(export_rt_width, export_rt_height)

  for !rl.WindowShouldClose() {
    window_width = f32(rl.GetScreenWidth())
    window_height = f32(rl.GetScreenHeight())
    rl.BeginDrawing()
    rl.ClearBackground({120, 120, 255, 255})

    smallest_dim := min(rt_width, rt_height)
    smallest_dim_window := min(f32(rl.GetRenderHeight()), f32(rl.GetRenderWidth()))
    window_size := Vec2{f32(rl.GetRenderWidth()), f32(rl.GetRenderHeight())}
    rt_pos := rl.Rectangle{f32(rl.GetRenderWidth())*0.5-smallest_dim_window*0.5, 0, smallest_dim_window, -smallest_dim_window}
    mp := rl.GetMousePosition()

    is_exporting := button({window_size.x-200, 20, 180, 70}, "Export", 20)
    if is_exporting {
      rl.BeginTextureMode(export_rt)
      render_atmo(export_step_size, export_step_count,
        {0, 0}, {export_rt_width, export_rt_height})
      rl.EndTextureMode()
      if ok := export_render_texture(export_rt, "./exported.png"); ok {
        fmt.printfln("Successfully exported lightmarch to ./exported.png")
      }
      rl.CloseWindow() 
    }


    norm_mp := mp - Vec2{rt_pos.x, rt_pos.y}
    norm_mp = Vec2{
      math.floor((norm_mp.x / rt_pos.width) * rt_width),
      math.floor(((window_size.y - norm_mp.y) / -rt_pos.height) * rt_height)
    }
    rl.BeginTextureMode(rt)
    rl.ClearBackground({255, 0, 0, 255})

    step_size := f32(stepsize_sliderdata.value)//f32(0.01)

    // fmt.printfln("%v %v", norm_mp, rt_pos)

    render_atmo(step_size, i32(steps_sliderdata.value), norm_mp)

    rl.EndTextureMode()

    // smallest_dim = min(rt_width, rt_height)
    // smallest_dim_window = min(f32(rl.GetRenderHeight()), f32(rl.GetRenderWidth()))
    // rt_pos = rl.Rectangle{f32(rl.GetRenderWidth())*0.5-smallest_dim_window*0.5, 0, smallest_dim_window, -smallest_dim_window}
    rl.DrawTexturePro(rt.texture, {0, 0, rt_width, rt_height},
      rt_pos, {0,0}, 0, rl.WHITE)


    if mp.x < rt_pos.x + rt_pos.width &&
      mp.x > rt_pos.x &&
      mp.y < rt_pos.y - rt_pos.height &&
      mp.y > rt_pos.y {
        norm_hover_col := (hover_color / linalg.length(hover_color))*255
        color_rect_pos := mp
        if color_rect_pos.y + 22 > window_size.y do color_rect_pos.y = window_size.y - 22
          if color_rect_pos.x + 22 > window_size.x do color_rect_pos.x = window_size.x - 22
            rl.DrawRectangleV(color_rect_pos - {1, 1}, {22, 22}, 
              rl.RAYWHITE
            )
            rl.DrawRectangleV(color_rect_pos, {20, 20}, 
              rl.Color{u8(norm_hover_col.r), u8(norm_hover_col.g), u8(norm_hover_col.b), 255}
            )
      }

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
      light_density_mult_rate := f32(10000000) * 0.1
      if rl.IsKeyDown(.LEFT_SHIFT) {
        light_density_mult += atmo_mult_rate * light_density_mult_rate
      }
      if rl.IsKeyDown(.LEFT_CONTROL) {
        light_density_mult -= atmo_mult_rate * light_density_mult_rate
      }
      atmo_density_mult = clamp(atmo_density_mult, 0, 100)
      atmo_axis_mult = clamp(atmo_axis_mult, 0, 10)

      slider({50, window_size.y-50, 400, 15}, &exposure_sliderdata)
      slider({50, window_size.y-150, 200, 15}, &steps_sliderdata)
      slider({50, window_size.y-200, 200, 15}, &stepsize_sliderdata)
      rl.DrawText(rl.TextFormat("exposure: %0.2f", exposure_sliderdata.value), 50, i32(window_size.y-70), 15, rl.BLACK)
      rl.DrawText(rl.TextFormat("step amount: %0.2f", steps_sliderdata.value), 50, i32(window_size.y-70-50), 15, rl.BLACK)
      rl.DrawText(rl.TextFormat("step size: %0.2f", stepsize_sliderdata.value), 50, i32(window_size.y-70-100), 15, rl.BLACK)


      rl.DrawText(rl.TextFormat("planet size: %0.2f", planetsize_sliderdata.value), i32(window_size.x-250), i32(window_size.y-70-100), 15, rl.BLACK)
      slider({window_size.x - 250, window_size.y-50, 200, 15}, &planetsize_sliderdata)

      rl.DrawFPS(10, 10)
      rl.EndDrawing()
  }

  rl.CloseWindow()
}

SliderData :: struct {
  value: f32,
  max_value: f32,
  min_value: f32,
  is_down: bool
}
slider :: proc(rec: rl.Rectangle, d: ^SliderData) {
  rl.DrawRectangleRounded(rec, 1, 10, pal.board_light)
  p := f32(2)
  rl.DrawRectangleRounded({
    x = rec.x + p,
    y = rec.y + p,
    width = rec.width - p*2,
    height = rec.height - p*2
  }, 1, 10, rl.WHITE)
  percentage := (d.value - d.min_value) / (d.max_value - d.min_value)
  knob_pos := rl.Vector2{
    rec.x + percentage * rec.width,
    rec.y + rec.height/2// - rec.height/2
  }
  rl.DrawCircleV(knob_pos, rec.height, pal.button)
  rl.DrawCircleV(knob_pos, rec.height-p, rl.WHITE)
  d.value = clamp(d.value, d.min_value, d.max_value)

  mp := rl.GetMousePosition()
  if linalg.length(mp-knob_pos) < rec.height {
    rl.DrawCircleV(knob_pos, rec.height-p, pal.knob_hover)
    if rl.IsMouseButtonDown(.LEFT) {
      // rl.DrawCircleV(knob_pos, rec.height-p, pal.knob_down)
      d.is_down = true
    }
  }

  mmar := f32(10)
  if rl.IsMouseButtonPressed(.LEFT) && mp.y - mmar < rec.y + rec.height &&
  mp.y + mmar > rec.y && mp.x + mmar > rec.x && mp.x - mmar < rec.x + rec.width {
    d.is_down = true
  }

  if rl.IsMouseButtonReleased(.LEFT) {
    d.is_down = false
  }
  if d.is_down {
    newp := clamp((mp.x - rec.x) / rec.width, -0.1, 1.1)
    d.value = newp * (d.max_value - d.min_value) + d.min_value
    rl.DrawCircleV(knob_pos, rec.height-p, pal.knob_down)
  }
}

button :: proc(rec: rl.Rectangle, text: cstring, text_size: f32, rounding: f32 = 0.15) -> bool {
  mp := rl.GetMousePosition()
  rl.DrawRectangleRounded(rec, rounding, 10, pal.button)
  if mp.x < rec.x + rec.width &&
    mp.x > rec.x &&
    mp.y < rec.y + rec.height &&
    mp.y > rec.y {
      rl.DrawRectangleRounded(rec, rounding, 10, pal.button_hover)
      if rl.IsMouseButtonDown(.LEFT) {
        rl.DrawRectangleRounded(rec, rounding, 10, pal.button_down)
      }
      if rl.IsMouseButtonReleased(.LEFT) {
        return true
      }
  }
  ts := f32(rl.MeasureText(text, i32(text_size)))
  rl.DrawText(text,
    i32(rec.x+rec.width/2-ts/2),
    i32(rec.y+rec.height/2-text_size/2),
   i32(text_size), rl.WHITE)
  return false
}
