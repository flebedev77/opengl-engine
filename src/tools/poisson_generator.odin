package poisson
import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"

import "core:strings"
import "core:os"

import rl "vendor:raylib"

v2 :: [2]f32
v3 :: [3]f32

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
SCALE :: WINDOW_HEIGHT / 2 - 20

desired_amount := 16

PoissonDisk :: struct {
  position: v2,
  radius: f32
}

draw_disk :: proc(d: PoissonDisk) {
  origin := v2{WINDOW_WIDTH/2, WINDOW_HEIGHT/2}
  rl.DrawCircle(
    i32(origin.x + d.position.x * SCALE), 
    i32(origin.y + d.position.y * SCALE),
    math.sqrt(f32(SCALE)), 
    rl.WHITE
  )
}

generate_distribution :: proc() -> [dynamic]PoissonDisk {
  arr := make([dynamic]PoissonDisk, context.temp_allocator)

  rand.reset(u64(time.now()._nsec))


  for i in 0..<(desired_amount * 2) {
    angle  := rand.float32() * 2 * math.PI
    radius := math.sqrt(rand.float32())

    pos := v2{math.cos(angle), math.sin(angle)} * radius
    for disk in arr {
      dist := linalg.length(disk.position - pos)
      if dist < disk.radius {
        continue
      }
    }

    append(&arr, PoissonDisk{
      position = pos,
      radius = 1
    })

    if len(arr) >= desired_amount {
      break
    }
  }

  return arr
}

export_poisson_offsets :: proc(disks: [dynamic]PoissonDisk) -> os.Error {
  sb := strings.builder_make(context.temp_allocator)
  for disk in disks {
    strings.write_string(&sb, "vec2(")
    strings.write_f32(&sb, disk.position.x, 'f')
    strings.write_string(&sb, ", ")

    strings.write_f32(&sb, disk.position.y, 'f')
    strings.write_string(&sb, "), \n")
  }

  os.write_entire_file("poisson_offsets.txt", sb.buf[:])

  return nil
}

HemiPoint :: struct {
  position: v3,
  radius: f32
}

generate_hemi_distribution :: proc() -> [dynamic]HemiPoint {
  arr := make([dynamic]HemiPoint, context.temp_allocator)

  rand.reset(u64(time.now()._nsec))

  for i in 0..<(desired_amount * 2) {
    pos := v3{rand.float32_range(-1, 1), rand.float32_range(-1, 1), rand.float32_range(0, 1)}
    leng := linalg.length(pos)
    for point in arr {
      dist := linalg.length(point.position - pos)
      if dist < point.radius {
        continue
      }
    }

    append(&arr, HemiPoint{
      position = pos,
      radius = 1
    })

    if len(arr) >= desired_amount {
      break
    }
  }

  return arr
}

LaunchMode :: enum {
  None,
  Disk,
  Hemisphere
}

launch_mode: LaunchMode = .None

main :: proc() {
  for arg in os.args {
    if arg == "-disk" {
      if launch_mode == .Hemisphere {
        fmt.panicf("Cannot launch in both hemisphere and disk generation mode at once")
      }
      launch_mode = .Disk
    }
    if arg == "-hemi" {
      if launch_mode == .Disk {
        fmt.panicf("Cannot launch in both hemisphere and disk generation mode at once")
      }
      launch_mode = .Hemisphere
    }
  }
  if launch_mode == .None {
    launch_mode = .Disk
    fmt.printfln("No launch mode specified, defaulting to disk generation.\nTo change generation mode pass in either: -disk or -hemi\n")
  }
  rl.SetConfigFlags({.MSAA_4X_HINT})
  rl.SetWindowState(({.VSYNC_HINT} | {.MSAA_4X_HINT}))
  rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Poisson distribution generator")
  rl.SetTargetFPS(60)

  disks := generate_distribution()
  fmt.printfln("DISKS amount %d", len(disks))

  is_running := true

  points := generate_hemi_distribution()
  fmt.printfln("POINTS amount %d", len(points))

  hemi_cam: rl.Camera3D
  if launch_mode == .Hemisphere {
    hemi_cam.position = {0, 5, 10}
    hemi_cam.target = {0, 0, 0}
    hemi_cam.projection = .PERSPECTIVE
    hemi_cam.up = {0, 0, 1}
    hemi_cam.fovy = 50
  }

  point_shader := rl.LoadShaderFromMemory(
    #load("../../assets/shaders/tools/point_vert.glsl"),
    #load("../../assets/shaders/tools/point_frag.glsl")
  )
  defer rl.UnloadShader(point_shader)

  point_mesh := rl.GenMeshSphere(1, 20, 20)
  fmt.printfln("%d", point_mesh.normals)
  point_model := rl.LoadModelFromMesh(point_mesh)
  point_model.materials[0].shader = point_shader
  point_material: rl.Material = {shader = point_shader}
  shader_camera_pos_loc := rl.GetShaderLocation(point_model.materials[0].shader, "camera_pos")

  for !rl.WindowShouldClose() && is_running {
    rl.BeginDrawing()
    background_grayness := u8(150)
    rl.ClearBackground({background_grayness, background_grayness, background_grayness, 255})

    if rl.IsKeyPressed(.SPACE) {
      free_all(context.temp_allocator)
      if launch_mode == .Disk {
        disks = generate_distribution()
      } else if launch_mode == .Hemisphere {
        points = generate_hemi_distribution()
      }
    }

    if rl.IsKeyPressed(.ENTER) {
      if launch_mode == .Disk {
        export_poisson_offsets(disks)
      } else if launch_mode == .Hemisphere {
        // export_hemi_offsets(points)
      }
      is_running = false
    }
    if launch_mode == .Disk {
      for disk in disks {
        draw_disk(disk)
      }

    } else if launch_mode == .Hemisphere {
      rl.BeginMode3D(hemi_cam)
      rl.UpdateCamera(&hemi_cam, .THIRD_PERSON)

      // rl.DrawCube({0,0,0}, 1, 1, 1, rl.RAYWHITE)
      // rl.DrawCubeWires({0,0,0}, 1.1, 1.1, 1., rl.BLUE)
      rl.SetShaderValue(point_model.materials[0].shader, shader_camera_pos_loc, &hemi_cam.position, .VEC3)

      basis_display_scale := f32(2)
      rl.BeginShaderMode(point_shader)
      for point in points {
        // rl.DrawSphere(point.position * basis_display_scale, 0.1, rl.RED)
        rl.DrawModel(point_model, point.position * basis_display_scale, 0.1, rl.RED)
        // rl.DrawMesh(point_mesh, point_material, rl.Matrix(1))
      }
      rl.EndShaderMode()

      xa := rl.Vector3{basis_display_scale, 0, 0}
      ya := rl.Vector3{0, basis_display_scale, 0}
      za := rl.Vector3{0, 0, basis_display_scale}

      rl.DrawLine3D({0, 0, 0}, xa, rl.RED)
      rl.DrawLine3D({0, 0, 0}, ya, rl.GREEN)
      rl.DrawLine3D({0, 0, 0}, za, rl.BLUE)

      rl.EndMode3D()


      text_padd := f32(0.1)
      x_pos := rl.GetWorldToScreen(xa + xa * text_padd, hemi_cam)
      rl.DrawText(
        "X",
        i32(x_pos.x - 5),
        i32(x_pos.y - 7),
        15,
        rl.RED
      )

      y_pos := rl.GetWorldToScreen(ya + ya * text_padd, hemi_cam)
      rl.DrawText(
        "Y",
        i32(y_pos.x - 5),
        i32(y_pos.y - 7),
        15,
        rl.GREEN
      )

      z_pos := rl.GetWorldToScreen(za + za * text_padd, hemi_cam)
      rl.DrawText(
        "Z",
        i32(z_pos.x - 5),
        i32(z_pos.y - 7),
        15,
        rl.BLUE
      )

      if rl.IsMouseButtonPressed(.LEFT) {
        rl.DisableCursor()
      }
    }

    rl.EndDrawing()
  }

  free_all(context.temp_allocator)

  rl.CloseWindow()
}
