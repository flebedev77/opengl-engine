package main

@(deprecated = "Broken UVs and normals")
mesh_make_cube_unlit :: proc(shader: Shader) -> Mesh {
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
  mesh_init(&mesh, vertices, uvs, normals, indices, shader)
  return mesh
}


mesh_make_cube :: proc(shader: Shader, origin_offset := Vec3{-0.5, -0.5, -0.5}, insideout_normals := false) -> Mesh {
  shader := shader
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
    // 0, 1, 2,
    // 3, 4, 5,
    // 6, 7, 8,
    // 9, 10, 11,
    // 12, 13, 14,
    // 15, 16, 17,
    // 18, 19, 20,
    // 21, 22, 23,
    // 24, 25, 26,
    // 27, 28, 29,
    // 30, 31, 32,
    // 33, 34, 35
    2, 1, 0,
    5, 4, 3,
    8, 7, 6,
    11, 10, 9,
    14, 13, 12,
    17, 16, 15,
    20, 19, 18,
    23, 22, 21,
    26, 25, 24,
    29, 28, 27,
    32, 31, 30,
    35, 34, 33
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
  mesh_init(&mesh, vertices, uvs, normals, indices, shader)
  return mesh
}
