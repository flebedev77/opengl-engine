package main
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import json "core:encoding/json"
  
MsdfCharData :: struct {
  char: rune,
  width,
  height,
  xoffset,
  yoffset,
  xadvance,
  x,
  y: f32
}

Resources :: struct {
  font_msdf_resolution: IVec2,
  font_msdf_charset: string,
  font_msdf_data: map[rune]MsdfCharData,
  font_msdf,
  black_texture,
  blue_noise_texture: GpuID
}

resources_load :: proc(r: ^Resources) {
  r.black_texture = texture_load("assets/textures/black.png")
  r.blue_noise_texture = texture_load("assets/textures/blue_noise/128_128/HDR_L_0.png")
  r.font_msdf, r.font_msdf_resolution = texture_load_with_dimensions("assets/textures/msdf_fonts/noto_serif_512.png")
  r.font_msdf_charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?.,;:'\"()[]{}"

  // MSDF generated from https://msdf.zap.works/
  font_json_data, ok := os.read_entire_file("assets/textures/msdf_fonts/noto_data.json")
  defer delete(font_json_data)
  assert(ok, "Failed to load msdf data")

  value, err := json.parse(font_json_data)
  defer json.destroy_value(value)
  assert(err == .None, "Failed to parse msdf json")

  root_obj, ok2 := value.(json.Object)
  assert(ok2, "Failed to get root object of msdf json")

  root_obj, ok2 = root_obj["FONT"].(json.Object)
  assert(ok2, "Failed to find object in msdf json")

  root_obj, ok2 = root_obj["400"].(json.Object)
  assert(ok2, "Failed to find object in msdf json")

  chars, ok3 := root_obj["chars"].(json.Array)
  assert(ok3, "Failed to find chars array")

  common, ok4 := root_obj["common"].(json.Object)
  assert(ok4, "Failed to find common")

  resolutionx, resolutiony := f32(r.font_msdf_resolution.x), f32(r.font_msdf_resolution.y)

  fmt.printfln("RESOLUTION ATLAS %f %f", resolutionx, resolutiony)


  for c in chars {
    object, is_object := c.(json.Object)
    if (!is_object) do continue

    char, found := object["char"].(json.String)

    if !found {
      fmt.printf("Character not found in msdf entry")
      continue
    }

    width, _ := object["width"].(json.Float)
    height, _ := object["height"].(json.Float)
    xoffset, _ := object["xoffset"].(json.Float)
    yoffset, _ := object["yoffset"].(json.Float)
    xadvance, _ := object["xadvance"].(json.Float)
    y, _ := object["y"].(json.Float)
    x, _ := object["x"].(json.Float)

    decoded_rune, _ := utf8.decode_rune_in_string(char)
    // fmt.printfln("FOUND CHARACTER %r\n  Width = %f\n Height = %f\n  x = %f\n  y = %f",
    //   decoded_rune, width, height, x, y)

    r.font_msdf_data[decoded_rune] = MsdfCharData {
      char = decoded_rune,
      width = f32(width) / f32(resolutionx),
      height = f32(height) / f32(resolutiony),
      xoffset = f32(xoffset) / f32(resolutionx),
      yoffset = f32(yoffset) / f32(resolutiony),
      xadvance = f32(xadvance) / f32(resolutionx),
      x = f32(x) / f32(resolutionx),
      y = f32(y) / f32(resolutiony),
    }

  }

}
