package main
import "core:mem"
import "core:strings"
import "core:fmt"
import "core:os"

asset_loader_obj_mesh_new :: proc(filename: string, material: Material, verbose := false) -> Mesh {
  // fmt.printf("Loading OBJ %s ", filename)
  // profile_begin()
  obj := obj_parse_new(filename, verbose)
  mesh: Mesh
  mesh_init(&mesh, 
    obj.positions,
    obj.colors,
    obj.uvs,
    obj.normals,
    obj.indices,
    material
  )

  alloc_err := mem.free_with_size(obj.memory, obj.memory_size, obj.allocator)
  assert(alloc_err == .None)
  // profile_end()
  return mesh
}

asset_loader_obj_mesh :: proc(filename: string, material: Material, verbose := false) -> Mesh {
  // fmt.printf("Loading OBJ %s ", filename)
  // profile_begin()
  cached_filename := fmt.tprintf("%s.mdl", filename)
  s, e := os.stat(filename, context.temp_allocator)
  assert(e == os.General_Error.None)
  mesh: Mesh
  if os.exists(cached_filename) {
    cached_file_stat, e := os.stat(cached_filename, context.temp_allocator)
    if cached_file_stat.size < 8*6 {
      os.remove(cached_filename)
    } else {
        cached_buf, err := os.read_entire_file_from_path(cached_filename, context.temp_allocator)
        assert(e == os.General_Error.None)
        base := cast([^]i64)(raw_data(cached_buf))
        if s.creation_time._nsec == base[0] {
          cscope := profile_begin(false)
          fmt.printf("Loading cached %s version! ", cached_filename)
          pos_amt, col_amt, uv_amt, nor_amt, ind_amt := base[1], base[2], base[3], base[4], base[5]
          p := cast([^]f32)(&base[6])
          pos := p[0:pos_amt]
          p = ([^]f32)(uintptr(p) + uintptr(size_of(f32) * pos_amt))
          col := p[0:col_amt]
          p = ([^]f32)(uintptr(p) + uintptr(size_of(f32) * col_amt))
          uv := p[0:uv_amt]
          p = ([^]f32)(uintptr(p) + uintptr(size_of(f32) * uv_amt))
          nor := p[0:nor_amt]
          pind := ([^]u32)(uintptr(p) + uintptr(size_of(f32) * nor_amt))
          ind := pind[0:ind_amt]
          mesh_init(&mesh, pos, col, uv, nor, ind, material)
          profile_end(cscope)
          return mesh
        } else {
          os.remove(cached_filename)
        }
      }
      // mesh_init(&mesh
    }
    pos, col, uv, nor, ind := obj_parse(filename, verbose)
    mesh_init(&mesh, pos, col, uv, nor, ind, material)

  {
    fmt.printfln("Caching model %s", cached_filename)
    pos_amt := i64(len(pos))
    col_amt := i64(len(col))
    uv_amt := i64(len(uv))
    nor_amt := i64(len(nor))
    ind_amt := i64(len(ind))
    cache_file, err := os.open(cached_filename, {.Read, .Write, .Create})
    assert(err == os.General_Error.None)
    n, e := os.write_ptr(cache_file, &s.creation_time._nsec, 8)
    assert(e == os.General_Error.None && n == 8)
    os.write_ptr(cache_file, &pos_amt, 8)
    os.write_ptr(cache_file, &col_amt, 8)
    os.write_ptr(cache_file, &uv_amt, 8)
    os.write_ptr(cache_file, &nor_amt, 8)
    os.write_ptr(cache_file, &ind_amt, 8)
    os.write_ptr(cache_file, raw_data(pos), int(size_of(f32) * pos_amt))
    os.write_ptr(cache_file, raw_data(col), int(size_of(f32) * col_amt))
    os.write_ptr(cache_file, raw_data(uv), int(size_of(f32) * uv_amt))
    os.write_ptr(cache_file, raw_data(nor), int(size_of(f32) * nor_amt))
    os.write_ptr(cache_file, raw_data(ind), int(size_of(u32) * ind_amt))
    os.close(cache_file)
  }

  // NOTE should use the temporary allocator for this
  delete(pos)
  delete(uv)
  delete(nor)
  delete(ind)
  // profile_end()
  return mesh
}

asset_loader_material :: proc(
  albedo_texture,
  roughness_texture: GpuID,
  shader_name: string,
  shader_type: ShaderType,
  vertex_shader_override := ""
) -> Material {
  frag_path, vert_path :=
  fmt.aprintf("./assets/shaders/%s_frag.glsl", shader_name),
  (shader_type == .TWO_DIMENSIONAL) ? "./assets/shaders/quad_vert.glsl" :
  fmt.aprintf("./assets/shaders/%s_vert.glsl", shader_name)

  if vertex_shader_override != "" do vert_path = 
    fmt.aprintf("./assets/shaders/%s_vert.glsl", vertex_shader_override)


  frag_contents, frag_success := os.read_entire_file_from_path(frag_path, context.temp_allocator)
  assert(frag_success == nil, fmt.tprintf("Failed to load fragment shader from %s", frag_path))
  frag_cstring := strings.clone_to_cstring(string(frag_contents), context.temp_allocator)

  vert_contents, vert_success := os.read_entire_file_from_path(vert_path, context.temp_allocator)
  assert(vert_success == nil, fmt.tprintf("Failed to load vertment shader from %s", vert_path))
  vert_cstring := strings.clone_to_cstring(string(vert_contents), context.temp_allocator)

  shader := shader_compileprogram(
    frag_cstring,
    vert_cstring,
    shader_type,
    frag_path,
    vert_path
  )
  return Material{
    is_valid = true,
    albedo_textures = albedo_texture,
    roughness_textures = roughness_texture,
    shader = shader 
  }
}
