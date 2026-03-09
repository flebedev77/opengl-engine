package main
import "core:math"
import "core:math/linalg"

import "vendor:glfw"

Player :: struct {
  viewmatrix: matrix[4,4]f32,
  yaw, pitch: f32,
  look_sensitivity: Vec2,
  walk_speed: f32,
  position,
  velocity: Vec3,
  is_onground: bool,
  is_flying: bool
}

player_init :: proc(player: ^Player) {
  player.position = {0, 0.3, 0}
  player.walk_speed = PLAYER_WALK_SPEED
  player.look_sensitivity = PLAYER_LOOK_SENSITIVITY
}

player_update :: proc(scene: ^Scene, player: ^Player) {
  player.yaw += scene.mouse.delta_position.x * player.look_sensitivity.x * scene.delta_time
  player.pitch -= scene.mouse.delta_position.y * player.look_sensitivity.y * scene.delta_time

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

  moveinput: Vec3
  // TODO move this to glfw layer
  if glfw.GetKey(GlfwWindow, glfw.KEY_W) > 0 {
    moveinput += forward
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_S) > 0 {
    moveinput -= forward
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_A) > 0 {
    moveinput -= right
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_D) > 0 {
    moveinput += right
  }
  if player.is_flying && glfw.GetKey(GlfwWindow, glfw.KEY_SPACE) > 0 {
    moveinput += {0, 1, 0}
  }
  if player.is_flying && glfw.GetKey(GlfwWindow, glfw.KEY_LEFT_SHIFT) > 0 {
    moveinput += {0, -1, 0}
  }

  if !player.is_flying && player.position.y + player.velocity.y <= 0.6 {
    player.position.y = 0.6
    player.velocity.y = 0.0
    player.is_onground = true
  }

  if !player.is_flying && glfw.GetKey(GlfwWindow, glfw.KEY_SPACE) > 0 && player.is_onground {
    player.is_onground = false 
    player.velocity.y = 0.14
  }

  
  if linalg.length2(moveinput) > 0 && linalg.length(player.velocity.xz) < player.walk_speed {
    moveinput = linalg.normalize(moveinput)
    moveinput.y *= 0.5
    player.velocity += moveinput * player.walk_speed * 0.5
  }

  if glfw.GetKey(GlfwWindow, glfw.KEY_TAB) > 0 {
    player.is_flying = true
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_LEFT_CONTROL) > 0 {
    player.is_flying = false
  }

  if !player.is_flying {
    player.velocity.y -= 0.004
  }
  player.velocity *= 0.9
  player.position += player.velocity
  scene.camera.position = player.position
  scene.camera.view_matrix = player.viewmatrix
}
