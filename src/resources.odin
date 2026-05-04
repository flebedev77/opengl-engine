package main

Resources :: struct {
  blue_noise_texture: GpuID
}

resources_load :: proc(r: ^Resources) {
  r.blue_noise_texture = texture_load("assets/textures/blue_noise/128_128/LDR_RGB1_0.png")
}
