package main
import "core:math"
import "core:math/linalg"
import "core:fmt"

import "vendor:glfw"

PlayerVisual :: struct {
  scene: ^Scene,
  mesh: Mesh,
  canopy_mesh: Mesh
}

Player :: struct {
  viewmatrix: matrix[4,4]f32,
  camera_yaw, camera_pitch: f32,
  roll, pitch, yaw: f32,
  zoom: f32,
  look_sensitivity: Vec2,
  mass,
  wing_area,
  body_crossectional_area,
  walk_speed: f32,
  debug_is_fast: bool,
  position,
  freecam_position,
  freecam_velocity,
  velocity: Vec3,
  is_onground: bool,
  is_flying: bool,
  debug_movement: bool,
  basis_matrix: Mat4,
  aerodynamics_triangle: [3]Vec4,
  visual: PlayerVisual,
  thrust: f32
}

player_init :: proc(scene: ^Scene, player: ^Player) {
  player.position = {-150, -2.96, 0}
  // player.position = {0, -502.12, 0}
  // player.position = {0, 5502.12, 0}
  player.walk_speed = PLAYER_WALK_SPEED
  player.look_sensitivity = PLAYER_LOOK_SENSITIVITY
  player.is_flying = true
  player.debug_movement = false
  player.camera_pitch = math.PI * 3/2
  player.zoom = 37.3
  player.mass = 10
  player.wing_area = 100038
  player.thrust = 0
  player.body_crossectional_area = 2

  // player.aerodynamics_triangle[0] = {-1, 0, 0, 1}
  // player.aerodynamics_triangle[1] = {0, 2, 0, 1}
  // player.aerodynamics_triangle[2] = {1, 0, 0, 1}

  player.aerodynamics_triangle[0] = {-1, 0, 0, 1}
  player.aerodynamics_triangle[1] = {0, 0, 2, 1}
  player.aerodynamics_triangle[2] = {1, 0, 0, 1}
  // player.velocity = {0, 0, 0.3}

  player.basis_matrix = identity_matrix()

  if !LOAD_WORLD do return
  player_material := Material{
    is_valid = true,
    albedo_textures = texture_load("assets/models/mig/textures/BaseColor.png", true),
    roughness_texture = texture_load("assets/models/mig/textures/metallic.png"),
    shader = scene.renderer.default_shader,
    metallic_strength = 1,
    roughness_strength = 1,
  }
  refractive_material := asset_loader_material(0, 0, "refractive", .THREE_DIMENSIONAL)
  refractive_material.is_transparent = true;
  player.visual.mesh = asset_loader_obj_mesh("assets/models/mig/mig.obj", player_material)
  player.visual.canopy_mesh = asset_loader_obj_mesh("assets/models/mig/mig_canopy.obj", refractive_material)
}

player_update :: proc(scene: ^Scene, player: ^Player) {
  local_forward := Vec3{
    player.basis_matrix[2][0],
    player.basis_matrix[2][1],
    player.basis_matrix[2][2]
  }
  local_up := Vec3{
    player.basis_matrix[1][0],
    player.basis_matrix[1][1],
    player.basis_matrix[1][2]
  }
  local_right := Vec3{
    player.basis_matrix[0][0],
    player.basis_matrix[0][1],
    player.basis_matrix[0][2]
  }
  basis_draw_scale := f32(0.05)

  if player.is_flying && !player.debug_movement { 
    force: Vec3

    thrust_force := player.mass * local_forward * player.thrust
    drag_force, lift_force := player_calculate_aero_forces(scene, player)
    gravity_force := player.mass * Vec3{0, -9.81, 0}

    force += thrust_force + gravity_force + drag_force + lift_force
    force *= 0.000001

    acceleration := force / player.mass

    player.velocity += acceleration * scene.delta_time
    player.position += player.velocity * scene.delta_time
    GROUND_PLANE_Y: f32 : -2.98
    if player.position.y < GROUND_PLANE_Y {
      player.position.y = GROUND_PLANE_Y
      player.velocity.y = 0
      // acceleration.y = 0
    }

    if .DEBUG_OVERLAY in scene.flags {
      debugrenderer_linebatch(
        &scene.renderer.debug_renderer,
        player.position,
        player.position + thrust_force * 6000,
        {0, 1, 0}
      )
    }

  }


  if glfw.GetKey(GlfwWindow, glfw.KEY_TAB) > 0 {
    player.is_flying = true
    player.debug_movement = true
    player.freecam_position = player.position
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_RIGHT_ALT) > 0 {
    player.is_flying = false
    player.debug_movement = false
  }

  if glfw.GetKey(GlfwWindow, glfw.KEY_LEFT_ALT) > 0 {
    scene.flags ~= {.DEBUG_OVERLAY}
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_APOSTROPHE) > 0 {
    player.debug_is_fast = !player.debug_is_fast
  }
  
  if glfw.GetKey(GlfwWindow, glfw.KEY_F7) > 0 {
    scene.renderer.reload_shaders = true
  }

  if player.debug_movement {
    player_debug_update(scene, player)
    return
  }

  player.camera_yaw += scene.mouse.delta_position.x * player.look_sensitivity.x * scene.delta_time
  player.camera_pitch += scene.mouse.delta_position.y * player.look_sensitivity.y * scene.delta_time

  camera_pitch_limit_padding: f32 = 0.003
  if player.camera_pitch > math.PI/2 - camera_pitch_limit_padding {
    player.camera_pitch = math.PI/2 - camera_pitch_limit_padding 
  }

  if player.camera_pitch < -math.PI/2 + camera_pitch_limit_padding {
    player.camera_pitch = -math.PI/2 + camera_pitch_limit_padding
  }

  look_direction := Vec3{
    math.cos(player.camera_yaw) * math.cos(player.camera_pitch),
    math.sin(player.camera_pitch),
    math.sin(player.camera_yaw) * math.cos(player.camera_pitch)
  }

  player.viewmatrix = linalg.matrix4_look_at_f32(
    player.position + look_direction * player.zoom,
    player.position,
    {0, 1, 0}
  )
  player.zoom -= scene.mouse.scroll * 1.4

  moveinput: Vec3
  rotation_speed := f32(0.03) // TODO: Make this variable depending on drag/lift from elevons
  // rotation_speed := f32(0.1)
  delta_pitch, delta_yaw, delta_roll: f32
  // TODO move this to glfw layer
  if glfw.GetKey(GlfwWindow, glfw.KEY_W) > 0 {
    player.pitch += rotation_speed
    delta_pitch = rotation_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_S) > 0 {
    player.pitch -= rotation_speed
    delta_pitch = -rotation_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_A) > 0 {
    player.yaw -= rotation_speed
    delta_yaw = rotation_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_D) > 0 {
    player.yaw += rotation_speed
    delta_yaw = -rotation_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_Q) > 0 {
    player.roll -= rotation_speed
    delta_roll = -rotation_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_E) > 0 {
    player.roll += rotation_speed
    delta_roll = rotation_speed
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_SPACE) > 0 {
    player.is_flying = !player.is_flying
  }

  if glfw.GetKey(GlfwWindow, glfw.KEY_LEFT_SHIFT) > 0 {
    player.thrust += 0.01 * scene.delta_time
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_LEFT_CONTROL) > 0 {
    player.thrust -= 0.01 * scene.delta_time
  }
  player.thrust = clamp(player.thrust, 0, 10)


  player.basis_matrix *= linalg.matrix4_rotate_f32(delta_pitch, {1, 0, 0})
  player.basis_matrix *= linalg.matrix4_rotate_f32(delta_yaw, {0, 1, 0})
  player.basis_matrix *= linalg.matrix4_rotate_f32(delta_roll, {0, 0, 1})

  scene.camera.position = player.position + look_direction * player.zoom
  scene.camera.view_matrix = player.viewmatrix


  if .DEBUG_OVERLAY in scene.flags {
    debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + local_forward * basis_draw_scale, {0, 0, 1})
    debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + local_up * basis_draw_scale, {0, 1, 0})
    debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + local_right * basis_draw_scale, {1, 0, 0})
  }
}

player_debug_update :: proc(scene: ^Scene, player: ^Player) {
  player.camera_yaw += scene.mouse.delta_position.x * player.look_sensitivity.x * scene.delta_time
  player.camera_pitch -= scene.mouse.delta_position.y * player.look_sensitivity.y * scene.delta_time

  camera_pitch_limit_padding: f32 = 0.003
  if player.camera_pitch > math.PI/2 - camera_pitch_limit_padding {
    player.camera_pitch = math.PI/2 - camera_pitch_limit_padding 
  }

  if player.camera_pitch < -math.PI/2 + camera_pitch_limit_padding {
    player.camera_pitch = -math.PI/2 + camera_pitch_limit_padding
  }

  look_direction := Vec3{
    math.cos(player.camera_yaw) * math.cos(player.camera_pitch),
    math.sin(player.camera_pitch),
    math.sin(player.camera_yaw) * math.cos(player.camera_pitch)
  }


  player.viewmatrix = linalg.matrix4_look_at_f32(player.freecam_position, player.freecam_position + look_direction, {0, 1, 0})

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

  if !player.is_flying && player.freecam_position.y + player.freecam_velocity.y <= 0.6 {
    player.freecam_position.y = 0.6
    player.freecam_velocity.y = 0.0
    player.is_onground = true
  }

  if !player.is_flying && glfw.GetKey(GlfwWindow, glfw.KEY_SPACE) > 0 && player.is_onground {
    player.is_onground = false 
    player.freecam_velocity.y = 0.14
  }


  if player.debug_is_fast do player.walk_speed = PLAYER_WALK_SPEED + 6
  else do player.walk_speed = PLAYER_WALK_SPEED

  if linalg.length2(moveinput) > 0 &&
    linalg.length(player.freecam_velocity.xz) < player.walk_speed {
      moveinput = linalg.normalize(moveinput)
      if player.is_flying && math.abs(player.freecam_velocity.y) > player.walk_speed {
        moveinput *= 0
      }

      player.freecam_velocity += moveinput * player.walk_speed * 0.5
    }


    if !player.is_flying {
      player.freecam_velocity.y -= 0.004
    } else {
      player.freecam_velocity.y *= 0.9
    }
    player.freecam_velocity.xz *= 0.9
    player.freecam_position += player.freecam_velocity
    scene.camera.position = player.freecam_position
    scene.camera.view_matrix = player.viewmatrix
}

player_render :: proc(scene: ^Scene, player: ^Player, material_override: ^Material = {}) {
  // if player.debug_movement {
  //   return
  // }

  if !LOAD_WORLD do return

  scale := f32(0.25)//0.001)
  player.visual.mesh.model_matrix = identity_matrix() 
  player.visual.mesh.model_matrix *= translation_matrix(player.position)
  player.visual.mesh.model_matrix *= scale_matrix({scale, scale, scale})
  player.visual.mesh.model_matrix *= player.basis_matrix
  player.visual.mesh.model_matrix *= linalg.matrix4_from_euler_angle_y_f32(math.PI/2)
  render_mesh(scene.renderer, &player.visual.mesh, material_override)
  player.visual.canopy_mesh.model_matrix = player.visual.mesh.model_matrix

  if material_override == {} {
    renderer_add_to_transparent_queue(
      scene.renderer,
      &player.visual.canopy_mesh
    )
  }

}

player_calculate_drag_coefficient :: proc(player: ^Player) -> f32 {
  return 2
}

player_calculate_aero_forces :: proc(scene: ^Scene, player: ^Player) -> (Vec3, Vec3) {
  speed_sq := linalg.length2(player.velocity)
  if speed_sq < EPSILON do return {0, 0, 0}, {0, 0, 0}

  velocity_direction := player.velocity / math.sqrt(speed_sq)

  drag_coefficient := #force_inline player_calculate_drag_coefficient(player)

  local_forward := Vec3{
    player.basis_matrix[2][0],
    player.basis_matrix[2][1],
    player.basis_matrix[2][2]
  }
  local_up := Vec3{
    player.basis_matrix[1][0],
    player.basis_matrix[1][1],
    player.basis_matrix[1][2]
  }
  local_right := Vec3{
    player.basis_matrix[0][0],
    player.basis_matrix[0][1],
    player.basis_matrix[0][2]
  }
  wind_view_matrix: Mat4
  if abs(linalg.dot(velocity_direction, local_forward)) > 1-EPSILON {
    wind_view_matrix = linalg.matrix4_look_at_f32({0, EPSILON, 0}, player.velocity, local_forward)
  } else {
    wind_view_matrix = linalg.matrix4_look_at_f32({0, 0, 0}, player.velocity, local_forward)
  }
  A := wind_view_matrix * player.basis_matrix * player.aerodynamics_triangle[0]
  B := wind_view_matrix * player.basis_matrix * player.aerodynamics_triangle[1]
  C := wind_view_matrix * player.basis_matrix * player.aerodynamics_triangle[2]
  area := abs(linalg.cross((B-A).xy, (C-A).xy))/2
  area *= player.wing_area

  drag_force := -velocity_direction * (0.5 * drag_coefficient * SIMULATION_AIR_DENSITY * speed_sq * area)

  forward_speed := linalg.dot(player.velocity, local_forward)
  upward_speed  := linalg.dot(player.velocity, local_up)

  angle_of_attack := math.atan2(-upward_speed, forward_speed)

  MAX_LIFT_ANGLE :: 0.26 // ~15 degrees
  STALL_ANGLE    :: 0.35 // ~20 degrees
  MAX_CL         :: 1.2  // Typical max lift coefficient for a small plane

  abs_aoa := math.abs(angle_of_attack)
  lift_coefficient : f32 = 0.0

  if abs_aoa < MAX_LIFT_ANGLE {
    // Linear lift generation phase
    lift_coefficient = (abs_aoa / MAX_LIFT_ANGLE) * MAX_CL
  } else if abs_aoa < STALL_ANGLE {
    // Post-peak stall drop-off phase
    t := (abs_aoa - MAX_LIFT_ANGLE) / (STALL_ANGLE - MAX_LIFT_ANGLE)
    lift_coefficient = math.max(0.2, (1.0 - t) * MAX_CL) // Drops to 0.2 at full stall
  } else {
    // Completely stalled wing (flat plate behavior)
    lift_coefficient = 0.2 
  }

  if angle_of_attack < 0.0 {
    lift_coefficient = -lift_coefficient
  }

  lift_dir := linalg.cross(velocity_direction, local_right)
  if linalg.length2(lift_dir) > EPSILON {
    lift_dir = linalg.normalize(lift_dir)
    if linalg.dot(lift_dir, local_up) < 0.0 {
      lift_dir = -lift_dir
    }
  }

  lift_force := lift_dir * (0.5 * SIMULATION_AIR_DENSITY * speed_sq * player.wing_area * lift_coefficient)

  if .DEBUG_OVERLAY in scene.flags {
    // TODO: Draw this in screen space
  debugrenderer_linebatch(
    &scene.renderer.debug_renderer,
    player.position + local_right * 2,
    player.position + GLOBAL_UP * area + local_right * 2, {0, 0, 1})


  debugrenderer_linebatch(
    &scene.renderer.debug_renderer,
    player.position,
    player.position + drag_force, {1, 0, 0})


  debugrenderer_linebatch(
    &scene.renderer.debug_renderer,
    player.position,
    player.position + lift_force, {0, 1, 1})
  }



  return drag_force, lift_force
}
