package main
import "core:strings"
import "core:fmt"
import "core:os"

asset_loader_obj_mesh :: proc(filename: string, material: Material, verbose := false) -> Mesh {
  fmt.printf("Loading OBJ %s ", filename)
  profile_begin()
  pos, col, uv, nor, ind := obj_parse(filename, verbose)
  mesh: Mesh
  mesh_init(&mesh, pos, col, uv, nor, ind, material)

  // NOTE should use the temporary allocator for this
  delete(pos)
  delete(uv)
  delete(nor)
  delete(ind)
  profile_end()
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


  frag_contents, frag_success := os.read_entire_file_from_filename(frag_path, context.temp_allocator)
  assert(frag_success, fmt.tprintf("Failed to load fragment shader from %s", frag_path))
  frag_cstring := strings.clone_to_cstring(string(frag_contents), context.temp_allocator)

  vert_contents, vert_success := os.read_entire_file_from_filename(vert_path, context.temp_allocator)
  assert(vert_success, fmt.tprintf("Failed to load vertment shader from %s", vert_path))
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
    roughness_texture = roughness_texture,
    shader = shader 
  }
}
