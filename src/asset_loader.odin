package main

asset_loader_obj_mesh :: proc(filename: string, material: Material, verbose := false) -> Mesh {
  pos, uv, nor, ind := obj_parse(filename, verbose)
  mesh: Mesh
  mesh_init(&mesh, pos, uv, nor, ind, material)

  // NOTE should use the temporary allocator for this
  delete(pos)
  delete(uv)
  delete(nor)
  delete(ind)
  return mesh
}
