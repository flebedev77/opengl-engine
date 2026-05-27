package main

import "core:time"
import "core:fmt"

ProfileScope :: struct {
  begin_time: time.Tick
}

default_profile_scope: ProfileScope

profile_begin :: proc(set_default_profile_scope := true) -> ProfileScope {
  if set_default_profile_scope do default_profile_scope = {begin_time = time.tick_now()}
  return {begin_time = time.tick_now()} 
}

profile_end :: proc(scope: ProfileScope = default_profile_scope) {
  fmt.printfln("%f ms",
    time.duration_milliseconds(time.tick_since(scope.begin_time))
  )
}
