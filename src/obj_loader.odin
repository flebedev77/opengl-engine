// TODO:
// Handle different materials (mtl files)
// Handle non triangulated meshes (saves disk space (although if we wanted to save disk space, we wouldn't be using obj))

// Mesh requirements
// - Position vectors in 3 components, normal vectors in 3 components and uv in 2 components
// - Triangulated indices
// - Must include all 3 components (position, uv and normal)

package main
import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import "core:mem"


obj_parse :: proc(filename: string, verbose := false) ->
  (vertex_positions: []f32, 
   vertex_colors: []f32,
   vertex_texture_coordinates: []f32,
   vertex_normals: []f32,
   indices: []u32) {
  data, read_ok := os.read_entire_file(filename)
  if read_ok {
    return obj_parse_from_memory(data, verbose)
  }
  fmt.eprintfln("Failed to read %s obj file", filename)
  return {}, {}, {}, {}, {}
}

@(private) OBJModeType :: enum {
  none,
  vertex_pos,
  vertex_nor,
  vertex_tex,
  face_ind
}

obj_parse_from_memory :: proc(contents: []u8, verbose := false) -> 
  (vertex_positions: []f32, 
   vertex_colors: []f32,
   vertex_texture_coordinates: []f32,
   vertex_normals: []f32, 
   indices: []u32) {

  allocator: mem.Arena
  // mem.arena_init(&allocator, make([]byte, 1000000000)) // This allocation size is not set in stone, if the loader doesn't work for some models, this is probably the reason why
  default_allocator := context.allocator
  // context.allocator = mem.arena_allocator(&allocator)
  // defer mem.arena_free_all(&allocator)
  
  vertex_pos: [dynamic]f32
  vertex_col: [dynamic]f32
  vertex_nor: [dynamic]f32
  vertex_tex: [dynamic]f32
  face_ind: [dynamic]u32

  number_sb := strings.builder_make()

  state := OBJModeType.none
  is_comment := false
  line, col := 0, 0
  numbers_encountered := u32(0) // Per line
  is_beginning_of_line := true
  for char, i in contents {
    next_char: u8 = 0
    if len(contents) > i + 1 {
      next_char = contents[i+1]
    }

    if char == '#' {
      is_comment = true
    }
    col += 1
    if char == '\n' {
      is_comment = false
      is_beginning_of_line = true
      line += 1
      col = 0
      numbers_encountered = 0
      continue
    }
    if is_comment || (is_beginning_of_line && (char == ' ' || char == '\t')) {
      continue
    }

    if is_beginning_of_line {
      state = .none
      is_beginning_of_line = false
      if char == 'v' {
        numbers_encountered = 0
        switch next_char {
        case ' ': state = .vertex_pos
        case 'n': state = .vertex_nor
        case 't': state = .vertex_tex
        case: fmt.eprintfln("Invalid v%c directive at %d:%d in obj", next_char, line, col)
        }
      }

      if char == 'f' {
        state = .face_ind
      }

      // TODO actually handle these instead of ignoring
      if char == 's' || char == 'o' {
        state = .none
      }

      continue
    }

    if state != .none && is_numeric(char) {
      strings.write_byte(&number_sb, char)
      if !is_numeric(next_char) {
        value := strconv.parse_f32(strings.to_string(number_sb)) or_else 0
        strings.builder_reset(&number_sb)
        numbers_encountered += 1
        #partial switch state {
          case .vertex_pos: append((numbers_encountered > 3) ? &vertex_col : &vertex_pos, value)
          case .vertex_tex: append(&vertex_tex, value)
          case .vertex_nor: append(&vertex_nor, value)
          case .face_ind: append(&face_ind, u32(value))
        }
      }
    }

  }

  // Some sort of factor validation
  // assert(is_whole(f32(len(vertex_pos)) / 3),   "Invalid amount of vertex positions in obj")
  // assert(is_whole(f32(len(vertex_col)) / 3),   "Invalid amount of vertex colors in obj")
  // assert(is_whole(f32(len(vertex_nor)) / 3),   "Invalid amount of vertex normals in obj")
  // assert(is_whole(f32(len(vertex_tex)) / 2),   "Invalid amount of vertex texture coordinates in obj")
  // assert(is_whole(f32(len(face_ind) * 9) / 3), "Invalid amount of face indices in obj")

  // assert(len(vertex_pos) > 2, "Not enough vertex positions in obj")
  // assert(len(vertex_nor) > 2, "Not enough vertex normals in obj")
  // assert(len(vertex_tex) > 1, "Not enough vertex texture coordinates in obj")
  // assert(len(face_ind)   > 2, "Not enough indices in obj")

  if verbose {
    fmt.printfln("POSLEN %d NORLEN %d TEXLEN %d FACLEN %d", len(vertex_pos), len(vertex_nor), len(vertex_tex), len(face_ind))
    if len(face_ind) < 50 {
      fmt.printfln("VERTEX NORMALS %f", vertex_nor[:])
      fmt.printfln("VERTEX POSITIONS %f", vertex_pos[:])
      fmt.printfln("VERTEX TEXTURE COORDINATES %f", vertex_tex[:])
      fmt.printfln("FACE INDICES %d %d", len(face_ind), face_ind[:])
    }
  }

  vertex_amount := len(face_ind) / 3
  context.allocator = default_allocator
  out_vertex_positions := make([]f32, vertex_amount * 3)
  out_vertex_colors := make([]f32, vertex_amount * 3)
  out_vertex_normals := make([]f32, vertex_amount * 3)
  out_vertex_texture_coordinates := make([]f32, vertex_amount * 2)
  out_indices := make([]u32, vertex_amount)

  for i in 0..<vertex_amount {
    pos_index := face_ind[i * 3]     - 1
    tex_index := face_ind[i * 3 + 1] - 1
    nor_index := face_ind[i * 3 + 2] - 1

    out_vertex_positions[i * 3]     = vertex_pos[pos_index * 3]
    out_vertex_positions[i * 3 + 1] = vertex_pos[pos_index * 3 + 1]
    out_vertex_positions[i * 3 + 2] = vertex_pos[pos_index * 3 + 2]

    if len(vertex_col) > 0 {
      out_vertex_colors[i * 3]     = vertex_col[pos_index * 3]
      out_vertex_colors[i * 3 + 1] = vertex_col[pos_index * 3 + 1]
      out_vertex_colors[i * 3 + 2] = vertex_col[pos_index * 3 + 2]
    }

    out_vertex_normals[i * 3] = vertex_nor[nor_index * 3]
    out_vertex_normals[i * 3 + 1] = vertex_nor[nor_index * 3 + 1]
    out_vertex_normals[i * 3 + 2] = vertex_nor[nor_index * 3 + 2]

    out_vertex_texture_coordinates[i * 2] = vertex_tex[tex_index * 2]
    out_vertex_texture_coordinates[i * 2 + 1] = 1-vertex_tex[tex_index * 2 + 1]

    out_indices[i] = u32(i)
  }

  return out_vertex_positions,
  out_vertex_colors,
  out_vertex_texture_coordinates,
  out_vertex_normals,
  out_indices
}
