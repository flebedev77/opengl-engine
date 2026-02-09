package main
import "core:math"
import "core:math/linalg"

import "vendor:glfw"

Player :: struct {
  viewmatrix: matrix[4,4]f32,
  yaw, pitch: f32,
  look_sensitivity: Vec2,
  walk_speed: f32,
  position: Vec3
}

player_init :: proc(player: ^Player) {
  player.position = {0, 0.3, 0}
  player.walk_speed = PLAYER_WALK_SPEED
  player.look_sensitivity = PLAYER_LOOK_SENSITIVITY
}

player_update :: proc(player: ^Player, delta_time: f32) {
  player.yaw += mouse.delta_position.x * player.look_sensitivity.x * delta_time
  player.pitch -= mouse.delta_position.y * player.look_sensitivity.y * delta_time

  pitch_limit_padding: f32 = 0.003
  if player.pitch > math.PI/2 - pitch_limit_padding {
    player.pitch = math.PI/2 - pitch_limit_padding 
  }

  if player.pitch < -math.PI/2 + pitch_limit_padding {
    player.pitch = -math.PI/2 + pitch_limit_padding
  }

  look_direction := Vec3{
    math.cos(player.yaw) * math.cos(player.pitch),
    math.sin(player.pitch),
    math.sin(player.yaw) * math.cos(player.pitch)
  }


  player.viewmatrix = linalg.matrix4_look_at_f32(player.position, player.position + look_direction, {0, 1, 0})

  forward := linalg.normalize(Vec3{look_direction.x, 0, look_direction.z}) 
  

  right := linalg.cross(forward, GLOBAL_UP)


  if glfw.GetKey(GlfwWindow, glfw.KEY_W) > 0 {
    player.position += forward * player.walk_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_S) > 0 {
    player.position -= forward * player.walk_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_A) > 0 {
    player.position -= right * player.walk_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_D) > 0 {
    player.position += right * player.walk_speed
  }
}
