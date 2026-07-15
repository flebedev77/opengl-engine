package main
import "core:unicode/utf8"
import "core:math"
import "core:fmt"
import "core:strings"
import "core:math/linalg"
import "vendor:glfw"

@(deprecated = "Broken UVs and normals")
mesh_make_cube_unlit :: proc(material: Material) -> Mesh {
  mesh: Mesh
  vertices: []f32 = {
    0, 0, 0,
    1, 0, 0,
    1, 0, 1,
    0, 0, 1,

    0, 1, 0,
    1, 1, 0,
    1, 1, 1,
    0, 1, 1
  }
  indices: []u32 = {
    //Bottom face
    0, 1, 2,
    0, 2, 3,
    //Top face
    4, 5, 6,
    4, 7, 6,
    //Front face
    2, 3, 7,
    7, 6, 2,
    //Back face
    0, 1, 5,
    0, 5, 4,
    //Left face
    1, 2, 5,
    2, 5, 6,
    //Right face
    0, 3, 7,
    0, 7, 4
  }
  normals: []f32 = {
  }
  uvs: []f32 = {
    0, 0,
    0, 1,
    1, 1,
  }
  colors: []f32 = {
  }
  mesh_init(&mesh, vertices, colors, uvs, normals, indices, material)
  return mesh
}


mesh_make_cube :: proc(material: Material, origin_offset := Vec3{-0.5, -0.5, -0.5}, insideout_normals := false) -> Mesh {
  mesh: Mesh
  vertices: []f32 = {
    //Front
    1, 0, 0,
    1, 1, 0,
    1, 0, 1,

    1, 1, 0,
    1, 1, 1,
    1, 0, 1,

    //Bottom
    0, 0, 0,
    1, 0, 1,
    1, 0, 0,

    0, 0, 0,
    0, 0, 1,
    1, 0, 1,

    //Left
    0, 0, 0,
    1, 0, 0,
    1, 1, 0,

    0, 0, 0,
    1, 1, 0,
    0, 1, 0,

    //Right
    1, 0, 1,
    0, 1, 1,
    0, 0, 1,

    1, 0, 1,
    1, 1, 1,
    0, 1, 1,

    //Top
    1, 1, 0,
    0, 1, 0,
    1, 1, 1,

    0, 1, 0,
    0, 1, 1,
    1, 1, 1,

    //Back
    0, 0, 0,
    0, 1, 0,
    0, 0, 1,

    0, 1, 0,
    0, 1, 1,
    0, 0, 1
  }
  for i := 0; i < len(vertices); i += 3 {
    vertices[i]   += origin_offset.x
    vertices[i+1] += origin_offset.y
    vertices[i+2] += origin_offset.z
  }
  indices: []u32 = {
    0, 1, 2,
    3, 4, 5,
    8, 7, 6,
    11, 10, 9,
    14, 13, 12,
    17, 16, 15,
    18, 19, 20,
    21, 22, 23,
    24, 25, 26,
    27, 28, 29,
    32, 31, 30,
    35, 34, 33
    // 2, 1, 0,
    // 5, 4, 3,
    // 8, 7, 6,
    // 11, 10, 9,
    // 14, 13, 12,
    // 17, 16, 15,
    // 20, 19, 18,
    // 23, 22, 21,
    // 26, 25, 24,
    // 29, 28, 27,
    // 32, 31, 30,
    // 35, 34, 33
  }
  normals: []f32 = {
    1, 0, 0,
    1, 0, 0,
    1, 0, 0,

    1, 0, 0,
    1, 0, 0,
    1, 0, 0,

    0, -1, 0,
    0, -1, 0,
    0, -1, 0,

    0, -1, 0,
    0, -1, 0,
    0, -1, 0,

    0, 0, -1,
    0, 0, -1,
    0, 0, -1,
    
    0, 0, -1,
    0, 0, -1,
    0, 0, -1,

    0, 0, 1,
    0, 0, 1,
    0, 0, 1,

    0, 0, 1,
    0, 0, 1,
    0, 0, 1,

    0, 1, 0,
    0, 1, 0,
    0, 1, 0,

    0, 1, 0,
    0, 1, 0,
    0, 1, 0,

    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0,

    -1, 0, 0,
    -1, 0, 0,
    -1, 0, 0
  }
  if insideout_normals {
    for &n in normals {
      n *= -1
    }
  }
  uvs: []f32 = {
    0, 0,
    0, 1,
    1, 0,

    0, 1,
    1, 1,
    1, 0,

    0, 0,
    1, 1,
    1, 0,

    0, 0,
    0, 1,
    1, 1,

    0, 0,
    1, 0,
    1, 1,

    0, 0,
    1, 1,
    0, 1,

    1, 0,
    0, 1,
    0, 0,

    1, 0,
    1, 1,
    0, 1,

    0, 0,
    1, 0,
    0, 1,

    1, 0,
    1, 1,
    0, 1,

    0, 0,
    0, 1,
    1, 0,

    0, 1,
    1, 1,
    1, 0
  }
  colors: []f32 = {
  }
  mesh_init(&mesh, vertices, colors, uvs, normals, indices, material)
  return mesh
}

mesh_make_3d_quad :: proc(material: Material) -> Mesh {
  vertex_positions: []f32 = {
    -0.5, -0.5, 0,
    +0.5, -0.5, 0,
    +0.5, +0.5, 0,
    -0.5, +0.5, 0
  }
  vertex_uvs: []f32 = {
    0, 0,
    1, 0,
    1, 1,
    0, 1
  }
  indices: []u32 = {
    0, 1, 2,
    2, 3, 0
  }
  normals: []f32 = {
    0, 0, 1,
    0, 0, 1,
    0, 0, 1,
    0, 0, 1
  }
  colors: []f32
  mesh: Mesh
  mesh_init(&mesh, vertex_positions, colors, vertex_uvs, normals, indices, material)
  return mesh
}

mesh_make_quad :: proc(material: Material) -> Mesh {
  assert(material.is_valid)
  mesh: Mesh
  if material.shader.type == .TWO_DIMENSIONAL {
    mesh_init(&mesh, {}, {}, {}, {}, {0, 1, 2, 3}, material)
  } else {
    mesh = mesh_make_3d_quad(material)
  }
  return mesh
}

generate_ui :: proc(renderer: ^Renderer) {
  // profile_begin() // 0.09 ms! Pretty slow...
  clear(&renderer.scene.quads) 

  append(&renderer.scene.quads, Quad{
    position = {-1, -1},
    color = {0.057, 0.057, 0.057, 1},
    width = 0.25,
    height = 0.25
  })

  w, h := f32(690), f32(90)
  append(&renderer.scene.quads, Quad{
    position = ({-1, 1} - pixels_to_ndc({0, h})),
    color = {0.057, 0.057, 0.057, 1},
    width = pixels_to_ndc({w, h}).x,
    height = pixels_to_ndc({w, h}).y
  })
  
  // append(&renderer.scene.quads, Quad{
  //   position = {-1 + 0.025, -1 + 0.025},
  //   color = {0, 1, 1, 1},
  //   width = 0.2,
  //   height = 0.2
  // })

  // xp, _ := glfw.GetCursorPos(GlfwWindow)
  // fmt.printfln("PIXELS %f %f", pixels_to_ndc({0, 20}).xy)
  // draw_text(renderer, Vec2{0, 0}, "AC AVThe Lorem Ipsum Dolor sit amet", f32(xp) / f32(WINDOW_WIDTH))
  draw_text(renderer, {-1, -1} + pixels_to_ndc({0, 60}),
    fmt.tprintf("Speed: %fkm/h", 
      linalg.length(renderer.scene.player.velocity) * 
      renderer.scene.delta_time * 1000 * 3.6 /* meters per second to kmh */),
    0.1)

  draw_text(renderer, pixels_to_ndc({-20, WINDOW_HEIGHT - 60}), 
    fmt.tprintf("Altitude: %06f", renderer.scene.player.position.y),
    pixels_to_ndc({0, 30}).y
  )

  // dt_average := math.sum(renderer.scene.delta_time_history[:]) / len(renderer.scene.delta_time_history)
  draw_text(renderer, {-1, 1} + pixels_to_ndc({10, -80}), 
    fmt.tprintf("FPS: %0.1f %0.1f", math.ceil((1000 / renderer.scene.delta_time_ema)*10)/10, renderer.scene.delta_time_ema), pixels_to_ndc({0, 60}).y)
  // draw_text(renderer, {0, 0}, "Hello, World!", 0.2)
  // profile_end()
}

draw_text :: proc(renderer: ^Renderer, position: Vec2, text: string, font_size: f32, color: Vec4 = {0.9, 0.9, 0.9, 1}) {
  position := position
  // font_size := font_size / WINDOW_HEIGHT
  remaining := text

  line_height, base :=
    f32(renderer.scene.resources.font_msdf_common.line_height),
    f32(renderer.scene.resources.font_msdf_common.base)

  scale: f32 = (font_size * 2.0) / (line_height)

  aspect_ratio := f32(WINDOW_HEIGHT) / f32(WINDOW_WIDTH)

  prev_id: i32 = -1

  for len(remaining) > 0 {
    r, width := utf8.decode_rune_in_string(remaining)
    remaining = remaining[width:]
    if r == ' ' {
      position.x += scale * 
        renderer.scene.resources.font_msdf_common.chardata['A'].width *
        aspect_ratio
      prev_id = -1
      continue;
    }
    if strings.contains_rune(renderer.scene.resources.font_msdf_common.charset, r) {
      d : MsdfCharData = renderer.scene.resources.font_msdf_common.chardata[r]
      msdf_resx, msdf_resy :=
        f32(renderer.scene.resources.font_msdf_common.resolution.x),
        f32(renderer.scene.resources.font_msdf_common.resolution.y)
      // fmt.printfln("Id = %d W = %f, H = %f, Line height %f, Base %f", d.id, msdf_resx, msdf_resy, line_height, base)

      kerning := renderer.scene.resources.font_msdf_common.kernings[KerningKey{first = prev_id, second = d.id}]

      append(&renderer.scene.quads, Quad{
          position = {
            position.x + (kerning + d.xoffset) * scale * aspect_ratio, 
            position.y + (line_height - base - (d.height + d.yoffset) + line_height - base * 0.5) * scale
          },
          color = color,
          width = d.width * scale * aspect_ratio,
          height = d.height * scale,
          is_char = true,
          char_weight = 0.5,
          uv = {
            d.x / msdf_resx,
            d.y / msdf_resy,
            d.width / msdf_resx,
            d.height / msdf_resy
          }
      })

      position.x += (d.xadvance - kerning) * scale * aspect_ratio
      prev_id = d.id
    } else {
      fmt.printfln("Tried printing invalid character %r", r)
      prev_id = -1
    }

  }
}

// Pixel coordinates have 0 as the center
ndc_to_pixels :: proc(v: Vec2) -> Vec2 {
  vec := (v) // 2
  vec.x *= WINDOW_WIDTH
  vec.y *= WINDOW_HEIGHT
  return vec
}

pixels_to_ndc :: proc(v: Vec2) -> Vec2 {
  vec := Vec2{
    v.x / WINDOW_WIDTH,
    v.y / WINDOW_HEIGHT
  }
  // vec *= 2
  return vec
}
