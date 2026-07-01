package main

Resources :: struct {
  black_texture,
  blue_noise_texture: GpuID
}

resources_load :: proc(r: ^Resources) {
  r.black_texture = texture_load("assets/textures/black.png")
  r.blue_noise_texture = texture_load("assets/textures/blue_noise/128_128/HDR_L_0.png")
}
