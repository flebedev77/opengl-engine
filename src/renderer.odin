package main
import "core:unicode/utf8"
import "core:fmt"
import "core:strings"

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
  clear(&renderer.scene.quads) 

  append(&renderer.scene.quads, Quad{
    position = {-1, -1},
    color = {0.057, 0.057, 0.057, 1},
    width = 0.25,
    height = 0.25
  })
  
  // append(&renderer.scene.quads, Quad{
  //   position = {-1 + 0.025, -1 + 0.025},
  //   color = {0, 1, 1, 1},
  //   width = 0.2,
  //   height = 0.2
  // })

  draw_text(renderer, Vec2{0, 0}, "The Lorem Ipsum Dolor sit amet", 66)
}

draw_text :: proc(renderer: ^Renderer, position: Vec2, text: string, font_size: f32, color: Vec4 = {0.9, 0.9, 0.9, 1}) {
  position := position
  remaining := text
  for len(remaining) > 0 {
    r, width := utf8.decode_rune_in_string(remaining)
    remaining = remaining[width:]
    if r == ' ' {
      position.x += font_size / WINDOW_WIDTH
      continue;
    }
    if strings.contains_rune(renderer.scene.resources.font_msdf_charset, r) {
      d : MsdfCharData = renderer.scene.resources.font_msdf_data[r]
      msdf_resx, msdf_resy :=
        f32(renderer.scene.resources.font_msdf_resolution.x),
        f32(renderer.scene.resources.font_msdf_resolution.y)
      // fmt.printfln("W = %f, H = %f", msdf_resx, msdf_resy)

      k: f32 = font_size / (msdf_resy * d.height)

      append(&renderer.scene.quads, Quad{
        position = {
          position.x + d.xoffset * msdf_resx * k / WINDOW_WIDTH, 
          position.y - (d.yoffset) * msdf_resy * k / WINDOW_HEIGHT
        },
        color = color,
        width = d.width * msdf_resx * k / WINDOW_WIDTH,//font_size / WINDOW_WIDTH,
        height = font_size / WINDOW_HEIGHT,//font_size / WINDOW_HEIGHT,
        is_char = true,
        char_weight = 0.5,
        uv = {
          d.x,
          d.y,
          d.width,
          d.height
        }
      })

      position.x += (d.xadvance * msdf_resx * k) / WINDOW_WIDTH
    } else {
      fmt.printfln("Tried printing invalid character %r", r)
    }

  }
}
