package main
import "core:math"
import "core:math/linalg"

import "vendor:glfw"

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
  position,
  velocity: Vec3,
  is_onground: bool,
  is_flying: bool,
  debug_movement: bool,
  mesh: Mesh,
  basis_matrix: Mat4,
  aerodynamics_triangle: [3]Vec4,
  scene: ^Scene
}

player_init :: proc(scene: ^Scene, player: ^Player) {
  // player.position = {0, 0.3, 0}
  player.position = {0, 2, 0}
  player.walk_speed = PLAYER_WALK_SPEED
  player.look_sensitivity = PLAYER_LOOK_SENSITIVITY
  player.is_flying = false
  player.debug_movement = false
  player.camera_pitch = math.PI * 3/2
  player.zoom = 1.2
  player.mass = 11000
  player.wing_area = 38
  player.body_crossectional_area = 10

  // player.aerodynamics_triangle[0] = {-1, 0, 0, 1}
  // player.aerodynamics_triangle[1] = {0, 2, 0, 1}
  // player.aerodynamics_triangle[2] = {1, 0, 0, 1}

  player.aerodynamics_triangle[0] = {-1, 0, 0, 1}
  player.aerodynamics_triangle[1] = {0, 0, 2, 1}
  player.aerodynamics_triangle[2] = {1, 0, 0, 1}
  // player.velocity = {0, 0, 0.3}

  player.basis_matrix = identity_matrix()

  player_material := Material{
    is_valid = true,
    albedo_texture = texture_load("assets/models/mig/textures/BaseColor.png"),
    roughness_texture = texture_load("assets/models/mig/textures/metallic.png"),
    shader = scene.renderer.default_shader,
    metallic_strength = 1,
    roughness_strength = 1,
  }
  player.mesh = asset_loader_obj_mesh("assets/models/mig/mig.obj", player_material)
}

player_update :: proc(scene: ^Scene, player: ^Player) {
  if glfw.GetKey(GlfwWindow, glfw.KEY_TAB) > 0 {
    player.is_flying = true
    player.debug_movement = true
  }
  if glfw.GetKey(GlfwWindow, glfw.KEY_LEFT_CONTROL) > 0 {
    player.is_flying = false
    player.debug_movement = false
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
  player.zoom -= scene.mouse.scroll * 0.1

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

  player.basis_matrix *= linalg.matrix4_rotate_f32(delta_pitch, {1, 0, 0})
  player.basis_matrix *= linalg.matrix4_rotate_f32(delta_yaw, {0, 1, 0})
  player.basis_matrix *= linalg.matrix4_rotate_f32(delta_roll, {0, 0, 1})

  scene.camera.position = player.position + look_direction * player.zoom
  scene.camera.view_matrix = player.viewmatrix

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
  basis_draw_scale := f32(1)

  if player.is_flying { 
    player.position += player.velocity * scene.delta_time * 0.2
    thrust_force := ((local_forward * 2.98) / player.mass) * scene.delta_time
    player.velocity += thrust_force
    player.velocity += -GLOBAL_UP * 0.0001 * scene.delta_time

    debugrenderer_linebatch(
      &scene.renderer.debug_renderer,
      player.position,
      player.position + thrust_force * 6000,
      {0, 1, 0}
    )


    // DRAG
    speed_sq := linalg.length2(player.velocity)
    if (speed_sq < 0.000001) do player.velocity = {0, 0, 0}
    else {
      velocity_dir := linalg.normalize(player.velocity)
      air_density := f32(1.225)
      Cd := f32(7.4)

      aerodynamics_triangle_area := f32(0)
      { // CROSS SECTION CALCULATIONS
        wind_view_matrix := linalg.matrix4_look_at_f32(player.velocity, {0, 0, 0}, GLOBAL_UP + {0.00001,0,0})
        A := wind_view_matrix * player.basis_matrix * player.aerodynamics_triangle[0]
        B := wind_view_matrix * player.basis_matrix * player.aerodynamics_triangle[1]
        C := wind_view_matrix * player.basis_matrix * player.aerodynamics_triangle[2]

        aerodynamics_triangle_area = abs(linalg.cross((B-A).xy, (C-A).xy) / 2)
        // Test wing cross section detection
        // debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + GLOBAL_UP * aerodynamics_triangle_area, {1, 0, 0})
        aerodynamics_triangle_area *= player.wing_area
      }

      cross_sectional_area := max(player.body_crossectional_area, aerodynamics_triangle_area)
      drag := 0.5 * air_density * speed_sq * Cd * cross_sectional_area
      drag_force := ((-velocity_dir * drag) / player.mass) * scene.delta_time
      player.velocity += drag_force

      debugrenderer_linebatch(
        &scene.renderer.debug_renderer,
        player.position,
        player.position + drag_force * 6000,
        {1, 0, 0}
      )

      // LIFT
      flight_angle := linalg.dot(velocity_dir, local_forward) 
      stall_factor := math.max(0.8-math.abs(local_forward.y), 0)
      lift_dir := linalg.normalize(linalg.cross(-local_right, velocity_dir))

      lift_coefficient := 3.7 * max(0.0, flight_angle)
      lift := 0.5 * air_density * speed_sq * player.wing_area * lift_coefficient * stall_factor
      lift_force := lift_dir * lift / player.mass * scene.delta_time
      player.velocity += lift_force


      debugrenderer_linebatch(
        &scene.renderer.debug_renderer,
        player.position,
        player.position + lift_force * 6000,
        {0, 1, 1}
      )
    }

  }

  // debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + local_forward * basis_draw_scale, {0, 0, 1})
  // debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + local_up * basis_draw_scale, {0, 1, 0})
  // debugrenderer_linebatch(&scene.renderer.debug_renderer, player.position, player.position + local_right * basis_draw_scale, {1, 0, 0})
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


  if linalg.length2(moveinput) > 0 &&
    linalg.length(player.velocity.xz) < player.walk_speed {
      moveinput = linalg.normalize(moveinput)
      if player.is_flying && math.abs(player.velocity.y) > player.walk_speed {
        moveinput *= 0
      }

      player.velocity += moveinput * player.walk_speed * 0.5
    }


    if !player.is_flying {
      player.velocity.y -= 0.004
    } else {
      player.velocity.y *= 0.9
    }
    player.velocity.xz *= 0.9
    player.position += player.velocity
    scene.camera.position = player.position
    scene.camera.view_matrix = player.viewmatrix
}

player_render :: proc(scene: ^Scene, player: ^Player, material_override: ^Material = {}) {
  if player.debug_movement {
    return
  }

  forward_rotation := Vec3{
    math.cos(player.yaw) * math.cos(player.pitch),
    math.sin(player.pitch),
    math.sin(player.yaw) * math.cos(player.pitch)
  }


  scale := f32(0.01)
  player.mesh.model_matrix = identity_matrix() 
  player.mesh.model_matrix *= translation_matrix(player.position)
  player.mesh.model_matrix *= scale_matrix({scale, scale, scale})
  player.mesh.model_matrix *= player.basis_matrix
  player.mesh.model_matrix *= linalg.matrix4_from_euler_angle_y_f32(math.PI/2)
  render_mesh(scene.renderer, &player.mesh, material_override)
}
