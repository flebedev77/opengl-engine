// Netbpm ppm image file format


package main
import "core:os"
import "core:mem"
import "core:fmt"
import "core:strconv"
import "core:strings"

ppm_parse :: proc(filename: string, verbose := false) ->
(image_w, image_h, image_channels: i32, data: [^]byte) {
  if data, ok := os.read_entire_file(filename); ok {
    return ppm_parse_from_memory(data)
  }
  return
}

@(private) PPMModeType :: enum {
  WIDTH,
  HEIGHT,
  COLOR_RANGE,
  PIXEL_COMPONENT
}

ppm_parse_from_memory :: proc(contents: []u8, verbose := false) ->
(image_w, image_h, image_channels: i32, data: [^]byte) {
  color_range: int

  state := PPMModeType.WIDTH
  sb, err := strings.builder_make(context.temp_allocator)
  if err != nil {
    fmt.eprintfln("Failed to allocate memory for string builder") 
  }

  if contents[0] != 'P' {
    fmt.eprintfln("Incorrect magic number")
  }

  pixel_buffer: []u8
  pixel_begin_index: int

  switch contents[1] {
    case '6':
      for i in 2..<len(contents) {
        c := contents[i]
        nc: u8
        if i+1 < len(contents) {
          nc = contents[i+1]
        }

        if is_numeric(c) && state != .PIXEL_COMPONENT {
          strings.write_byte(&sb, c)
          if !is_numeric(nc) {
            value := strconv.parse_int(strings.to_string(sb)) or_else 0
            strings.builder_reset(&sb)
            if value == 0 {
              fmt.eprintfln("P6 PPM image has an invalid width/height/color range")
            }
            #partial switch state {
            case .WIDTH:
              image_w = i32(value)
              state = .HEIGHT
            case .HEIGHT:
              image_h = i32(value)
              state = .COLOR_RANGE
            case .COLOR_RANGE:
              color_range = value              
              state = .PIXEL_COMPONENT
              pixel_begin_index = i

              alloc_size := int(image_w * image_h * 3 * 10)
              pixel_buffer, err = mem.alloc_bytes_non_zeroed(
                alloc_size, 
                mem.DEFAULT_ALIGNMENT
              )

              if err != nil {
                fmt.eprintfln("Failed to allocate %d bytes for ppm image", alloc_size)
              }
            }

          }
        }

        if state == .PIXEL_COMPONENT {
          pixel_index := i - pixel_begin_index
          pixel_buffer[pixel_index] = c
        }
      }
    case:
      fmt.eprintfln("P%c not supported yet", contents[1])
  }
  fmt.printfln("WIDTH %d HEIGHT %d CHANNELS %d COLOR RANGE %d", image_w, image_h, 3, color_range)

  data = &pixel_buffer[0]
  image_channels = 3
  return
}
