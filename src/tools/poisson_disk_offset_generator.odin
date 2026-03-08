package possion
import "core:fmt"
import "core:time"
import "core:math"
import "core:math/rand"
import "core:math/linalg"

import "core:strings"
import "core:os"

import rl "vendor:raylib"

v2 :: [2]f32

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

main :: proc() {
  rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Poisson distribution generator")
  rl.SetWindowState({.VSYNC_HINT})

  disks := generate_distribution()
  fmt.printfln("DISKS amount %d", len(disks))

  is_running := true

  for !rl.WindowShouldClose() && is_running {
    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)

    for disk in disks {
      draw_disk(disk)
    }

    if rl.IsKeyPressed(.SPACE) {
      free_all(context.temp_allocator)
      disks = generate_distribution()
    }

    if rl.IsKeyPressed(.ENTER) {
      export_poisson_offsets(disks)
      is_running = false
    }

    rl.EndDrawing()
  }

  free_all(context.temp_allocator)

  rl.CloseWindow()
}
