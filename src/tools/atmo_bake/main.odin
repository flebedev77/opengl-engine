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

rt: rl.RenderTexture2D
export_rt: rl.RenderTexture2D
// rt_width :: 300
// rt_height :: 300

rt_width :: 128
rt_height :: 16

// rt_width :: 64
// rt_height :: 64

// export_rt_width :: 512
// export_rt_height :: 512
// export_rt_width :: 64
// export_rt_height :: 64
export_rt_width :: 256
export_rt_height :: 64
export_step_size :: 0.005
// export_step_count :: 128
export_step_count :: 512

atmo_density_mult := f32(1.8)
atmo_axis_mult := f32(1.7)
light_density_mult := f32(60000000000)//100000000.0) * 10000

hover_color := Vec3{0,0,0}
hover_xyz := Vec3{0, 0, 0}

exposure_sliderdata := SliderData{value = 1, max_value=2, min_value=0}
steps_sliderdata := SliderData{value = 128, max_value=512, min_value=1}
stepsize_sliderdata := SliderData{value = 0.01, max_value=0.4, min_value=0.00001}
planetsize_sliderdata := SliderData{value = 1000/55, max_value=1000, min_value=0.0}
horizon_bleed_mult_sliderdata := SliderData{value = 1, max_value=1, min_value=0.0}

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

time_mult_pressed := f64(0)
time_light_dens_pressed := f64(0)

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
sample_atmo_density :: proc (p: Vec3, planet_center: Vec3, earth_r: f32) -> f32 {
  // return 0
  value_at_edge_of_atmosphere := f32(0.01)
  h := f32(1 / -math.ln(value_at_edge_of_atmosphere / 1))//atmo_density_mult))
  // h = 0.145
  v: f32 = math.exp(-(linalg.length(p-planet_center) - earth_r) / h)
  // v *= atmo_density_mult; // same as e^{-ln(atmo_density_mult)-x}
  // v *= 2.1
  // v *= 1308.1;
  // return v

  return math.clamp(v, 0, 1)
}

render_atmo :: proc(step_size: f32, step_count: i32, norm_mp := Vec2{0, 0}, rt_wh := Vec2{rt_width, rt_height}) {
  inscattering := Vec3{}
  extinction := Vec3{1, 1, 1}

  light_densities := Vec3{680, 550, 440}
  light_densities = Vec3{
    1/math.pow(light_densities.r, 4),
    1/math.pow(light_densities.g, 4),
    1/math.pow(light_densities.b, 4)
  } * light_density_mult

  earth_r: f32 = planetsize_sliderdata.value
  planet_center := Vec3{0, -earth_r, 0}

  for y in 0..<rt_wh.y {
    for x in 0..<rt_wh.x {
      // x = angle to sun
      // y = altitude
      x_norm, y_norm := f32(x)/(rt_wh.x-1), f32(y)/(rt_wh.y-1)
      angle_to_sun := math.acos(x_norm*2-1)
      altitude := y_norm// - 0.1
      pos := Vec3{0, altitude, 0}
      dens := sample_atmo_density(pos, planet_center, earth_r)
      advance_vector := Vec3{math.sin(angle_to_sun), math.cos(angle_to_sun), 0}
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
        light_dens := sample_atmo_density(pos, planet_center, earth_r)
        extinction.r *= math.exp(-light_dens * step_size * light_densities.r)
        extinction.g *= math.exp(-light_dens * step_size * light_densities.g)
        extinction.b *= math.exp(-light_dens * step_size * light_densities.b)

        pos += advance_vector
      }
      if is_hit {
        // extinction = Vec3{0, 0, 0}
        extinction *= clamp(1-max(t_out-t_in, 0) * horizon_bleed_mult_sliderdata.value, 0, 1)
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
        hover_xyz = Vec3{angle_to_sun, altitude, dens}
      }
      // }
      // inscattering = extinction * 1/(linalg.length(extinction))
      // inscattering = Vec3{math.log_f32(extinction.r, 2), math.log_f32(extinction.g, 2), math.log_f32(extinction.b, 2)}
      inscattering = Vec3{clamp(inscattering.r, 0, 1), clamp(inscattering.g, 0, 1), clamp(inscattering.b, 0, 1)}
      if rl.IsKeyDown(.SPACE) do inscattering = Vec3{dens, dens, dens}
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
        fmt.printfln("Light mult %0.2f", light_density_mult)
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
            rl.DrawText(rl.TextFormat("(%0.2f, %0.2f, %0.2f)", hover_xyz.x, hover_xyz.y, hover_xyz.z),
              i32(color_rect_pos.x) + 50, i32(color_rect_pos.y), 15, rl.GREEN)
            rl.DrawText(rl.TextFormat("(%0.2f, %0.2f, %0.2f)", hover_color.x, hover_color.y, hover_color.z),
              i32(color_rect_pos.x) + 50, i32(color_rect_pos.y)+30, 15, rl.GREEN)
      }

      if rl.IsKeyUp(.DOWN) && rl.IsKeyUp(.UP) {
        time_mult_pressed = rl.GetTime()
      }
      if rl.IsKeyUp(.LEFT_SHIFT) && rl.IsKeyUp(.LEFT_CONTROL) {
        time_light_dens_pressed = rl.GetTime()
      }
      atmo_axis_rate := f32(10.1) * rl.GetFrameTime()
      atmo_mult_rate := f32(10.1) * rl.GetFrameTime() * math.pow(f32(rl.GetTime() - time_mult_pressed), 2)
      if rl.IsKeyDown(.UP) {
        atmo_density_mult += atmo_mult_rate
      }
      if rl.IsKeyDown(.DOWN) {
        atmo_density_mult -= atmo_mult_rate
      }
      if rl.IsKeyDown(.RIGHT) {
        atmo_axis_mult += atmo_axis_rate
      }
      if rl.IsKeyDown(.LEFT) {
        atmo_axis_mult -= atmo_axis_rate
      }
      light_density_mult_rate := f32(10000000000) *
        rl.GetFrameTime() *
        math.pow(f32(rl.GetTime() - time_light_dens_pressed), 2)
      if rl.IsKeyDown(.LEFT_SHIFT) {
        light_density_mult += light_density_mult_rate
      }
      if rl.IsKeyDown(.LEFT_CONTROL) {
        light_density_mult -= light_density_mult_rate
      }
      light_density_mult = max(light_density_mult, 0)
      atmo_density_mult = clamp(atmo_density_mult, 0, 106000)
      atmo_axis_mult = clamp(atmo_axis_mult, 0, 600)

      slider({50, window_size.y-50, 400, 15}, &exposure_sliderdata)
      slider({50, window_size.y-150, 200, 15}, &steps_sliderdata)
      slider({50, window_size.y-200, 200, 15}, &stepsize_sliderdata)
      rl.DrawText(rl.TextFormat("exposure: %0.2f", exposure_sliderdata.value), 50, i32(window_size.y-70), 15, rl.BLACK)
      rl.DrawText(rl.TextFormat("step amount: %0.2f", steps_sliderdata.value), 50, i32(window_size.y-70-50), 15, rl.BLACK)
      rl.DrawText(rl.TextFormat("step size: %0.2f", stepsize_sliderdata.value), 50, i32(window_size.y-70-100), 15, rl.BLACK)

      slider({50, window_size.y-250, 300, 15}, &horizon_bleed_mult_sliderdata)
      rl.DrawText(rl.TextFormat("horizon bleed mutliplier: %0.2f", horizon_bleed_mult_sliderdata.value), 50, i32(window_size.y-70-150), 15, rl.BLACK)


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
