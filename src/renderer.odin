package main

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
  }
  mesh_init(&mesh, vertices, uvs, normals, indices, shader)
  return mesh
}


mesh_make_cube :: proc(shader: Shader) -> Mesh {
  shader := shader
  shader.parameters.model_matrix = identity_matrix()
  mesh: Mesh
  vertices: []f32 = {
    1, 0, 0,
    1, 1, 0,
    1, 0, 1,

    1, 1, 0,
    1, 1, 1,
    1, 0, 1,

    0, 0, 0,
    1, 0, 1,
    1, 0, 0,

    0, 0, 0,
    0, 0, 1,
    1, 0, 1
  }
  indices: []u32 = {
    0, 1, 2,
    3, 4, 5,
    6, 7, 8,
    9, 10, 11
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
    0, -1, 0
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
    1, 1
  }
  mesh_init(&mesh, vertices, uvs, normals, indices, shader)
  return mesh
}
