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
  y: f32,
  id: i32
}

KerningKey :: struct {
  first: i32,
  second: i32
}

MsdfData :: struct {
  charset: string,
  chardata: map[rune]MsdfCharData,
  kernings: map[KerningKey]f32,
  resolution: IVec2,
  line_height,
  base: f32,
}

Resources :: struct {
  font_msdf_common: MsdfData,
  font_msdf,
  black_texture,
  wtf_tex,
  blue_noise_texture: GpuID
}

resources_load :: proc(r: ^Resources) {
  r.black_texture = texture_load("assets/textures/black.png")
  r.blue_noise_texture = texture_load("assets/textures/blue_noise/128_128/HDR_L_0.png")
  r.font_msdf, r.font_msdf_common.resolution = texture_load_with_dimensions("assets/textures/msdf_fonts/noto_serif_512.png", false, false) 
  r.font_msdf_common.charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!?.,;:'\"()[]{}-+@#$%^&*=_|<>/`~\\"

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

  line_height, ok5 := common["lineHeight"].(json.Float)
  assert(ok5, "Failed to find line height")
  r.font_msdf_common.line_height = f32(line_height)

  base, ok6 := common["base"].(json.Float)
  assert(ok6, "Failed to find line height")
  r.font_msdf_common.base = f32(base)

  resolutionx, resolutiony := 
    f32(r.font_msdf_common.resolution.x),
    f32(r.font_msdf_common.resolution.y)

  fmt.printfln("RESOLUTION ATLAS %f %f", resolutionx, resolutiony)


  for c in chars {
    object, is_object := c.(json.Object)
    if (!is_object) do continue

    char, found := object["char"].(json.String)

    if !found {
      fmt.eprintf("Character not found in msdf entry")
      continue
    }

    width, ok := object["width"].(json.Float)
    height, ok2 := object["height"].(json.Float)
    xoffset, ok3 := object["xoffset"].(json.Float)
    yoffset, ok4 := object["yoffset"].(json.Float)
    xadvance, ok5 := object["xadvance"].(json.Float)
    y, ok6 := object["y"].(json.Float)
    x, ok7 := object["x"].(json.Float)
    id, ok8 := object["id"].(json.Float)

    decoded_rune, _ := utf8.decode_rune_in_string(char)
    if !ok || !ok2 || !ok3 || !ok4 || !ok5 || !ok6 || !ok7 || !ok8 {
      fmt.eprintfln("Failed to aquire sufficient properties from glyph %r", decoded_rune)
      continue
    }

    // fmt.printfln("FOUND CHARACTER %r\n  Width = %f\n Height = %f\n  x = %f\n  y = %f",
    //   decoded_rune, width, height, x, y)

    r.font_msdf_common.chardata[decoded_rune] = MsdfCharData {
      char = decoded_rune,
      width = f32(width),
      height = f32(height),
      xoffset = f32(xoffset),
      yoffset = f32(yoffset),
      xadvance = f32(xadvance),
      x = f32(x),
      y = f32(y),
      id = i32(id)
    }

  }
  fmt.printfln("%d glyphs parsed", len(r.font_msdf_common.chardata))

  kernings, ok7 := root_obj["kernings"].(json.Array)
  if ok7 {
    for k in kernings {
      el, ok := k.(json.Object)
      if !ok {
        fmt.eprintfln("Not an object in kernings array")
        continue
      }
      
      first, ok2 := el["first"].(json.Float)
      second, ok3 := el["second"].(json.Float)
      amount, ok4 := el["amount"].(json.Float)

      if !ok2 || !ok3 || !ok4 {
        fmt.eprintfln("Could not locate necessary kerning properties")
        continue
      }

      r.font_msdf_common.kernings[KerningKey{first = i32(first), second = i32(second)}] =
        f32(amount)
    }

    fmt.printfln("%d kernings parsed", len(kernings))
  } else {
    fmt.eprintfln("Failed to locate kernings table")
  }

}
