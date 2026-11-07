extends CharacterBody3D
## Локальний гравець: рух, огляд, стрільба, керування FPV-дроном.

const SPEED := 5.5
const GRAV := 20.0
const JUMP := 6.0
const MAG := 30
const RELOAD_TIME := 2.0
const FIRE_DELAY := 0.11
const LOOK_SENS := 0.16
const SEND_RATE := 1.0 / 15.0

var main
var touch
var bot := false

var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var ammo := MAG
var reloading := 0.0
var fire_cd := 0.0
var send_t := 0.0
var _mouse_look := Vector2.ZERO
var _key_jump := false
var _key_reload := false
var _key_drone := false
var _key_boom := false

var drone_active := false
var drone_node: Node3D
var drone_cam: Camera3D
var drone_vel := Vector3.ZERO
var drone_yaw := 0.0
var drone_pitch := -10.0
var drone_throttle := 0.5

# бот для автоматичного тесту
var bot_t := 0.0
var bot_age := 0.0
var bot_move := Vector2.ZERO
var bot_turn := 0.0
var bot_drone_asked := false
var bot_drone_t := 0.0


func setup(m, t, is_bot: bool) -> void:
	main = m
	touch = t
	bot = is_bot
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.05
	cam.far = 500.0
	head.add_child(cam)

	# Автомат у руках (вид від першої особи)
	var gun_m := StandardMaterial3D.new()
	gun_m.albedo_color = Color(0.12, 0.12, 0.12)
	var gun := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.07, 0.09, 0.62)
	gun.mesh = gm
	gun.material_override = gun_m
	gun.position = Vector3(0.2, -0.2, -0.42)
	cam.add_child(gun)
	var mag := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.05, 0.16, 0.08)
	mag.mesh = mm
	mag.material_override = gun_m
	mag.position = Vector3(0.2, -0.3, -0.38)
	mag.rotation.x = 0.25
	cam.add_child(mag)


func respawn(pos: Vector3, yaw_rad: float) -> void:
	end_drone()
	global_position = pos
	velocity = Vector3.ZERO
	yaw = rad_to_deg(yaw_rad)
	pitch = 0.0
	rotation_degrees.y = yaw
	head.rotation_degrees.x = 0.0
	ammo = MAG
	reloading = 0.0
	cam.current = true
	set_physics_process(true)


func die() -> void:
	end_drone()
	set_physics_process(false)
	if touch:
		touch.reset_input()


func _unhandled_input(event: InputEvent) -> void:
	if bot:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_look += event.relative
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				_key_jump = true
			KEY_R:
				_key_reload = true
			KEY_E:
				_key_drone = true
			KEY_F, KEY_Q:
				_key_boom = true


func _physics_process(delta: float) -> void:
	var mv := Vector2.ZERO
	var look := Vector2.ZERO
	var firing := false
	var jump := false
	var reload := false
	var want_drone := false
	var want_boom := false

	if bot:
		bot_age += delta
		bot_t -= delta
		if bot_t <= 0.0:
			bot_t = 1.5
			bot_move = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, -0.2))
			bot_turn = randf_range(-60.0, 60.0)
		mv = bot_move
		look = Vector2(bot_turn * delta * 4.0, 0.0)
		firing = randf() < 0.6
		jump = randf() < 0.01
		if bot_age > 3.0 and not bot_drone_asked:
			bot_drone_asked = true
			want_drone = true
		if drone_active:
			bot_drone_t += delta
			if bot_drone_t > 2.0:
				want_boom = true
	else:
		if touch and touch.visible:
			mv = touch.move
			look = touch.look_delta
			touch.look_delta = Vector2.ZERO
			firing = touch.fire
			jump = touch.jump_pressed
			reload = touch.reload_pressed
			want_drone = touch.drone_pressed
			want_boom = touch.boom_pressed
			touch.jump_pressed = false
			touch.reload_pressed = false
			touch.drone_pressed = false
			touch.boom_pressed = false
		# клавіатура і миша (для перевірки на ПК)
		var kv := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W): kv.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S): kv.y += 1.0
		if Input.is_physical_key_pressed(KEY_A): kv.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D): kv.x += 1.0
		if kv != Vector2.ZERO:
			mv = kv.normalized()
		look += _mouse_look * 0.6
		_mouse_look = Vector2.ZERO
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			firing = true
		jump = jump or _key_jump
		reload = reload or _key_reload
		want_drone = want_drone or _key_drone
		want_boom = want_boom or _key_boom
		_key_jump = false
		_key_reload = false
		_key_drone = false
		_key_boom = false

	if want_drone and not drone_active:
		main.request_drone()

	if drone_active:
		_drone_process(delta, mv, look, want_boom)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAV * delta
		move_and_slide()
	else:
		_soldier_process(delta, mv, look, firing, jump, reload)

	send_t -= delta
	if send_t <= 0.0:
		send_t = SEND_RATE
		var dpos := Vector3.ZERO
		var dyaw := 0.0
		if drone_active and drone_node:
			dpos = drone_node.global_position
			dyaw = deg_to_rad(drone_yaw)
		main.send_state(global_position, rotation.y, head.rotation.x, 1 if drone_active else 0, dpos, dyaw)


func _soldier_process(delta: float, mv: Vector2, look: Vector2, firing: bool, jump: bool, reload: bool) -> void:
	yaw -= look.x * LOOK_SENS
	pitch = clampf(pitch - look.y * LOOK_SENS, -85.0, 85.0)
	rotation_degrees.y = yaw
	head.rotation_degrees.x = pitch

	var dir := transform.basis * Vector3(mv.x, 0.0, mv.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	if is_on_floor():
		if jump:
			velocity.y = JUMP
	else:
		velocity.y -= GRAV * delta
	move_and_slide()
	if global_position.y < -10.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)

	fire_cd -= delta
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			ammo = MAG
	if reload and ammo < MAG and reloading <= 0.0:
		reloading = RELOAD_TIME
	if firing and fire_cd <= 0.0 and reloading <= 0.0 and ammo > 0:
		fire_cd = FIRE_DELAY
		ammo -= 1
		var origin := cam.global_position
		var fwd := -cam.global_transform.basis.z
		var spread := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 0.012
		main.local_fire(origin, (fwd + spread).normalized())
		head.rotation_degrees.x += 0.25  # віддача
		pitch = head.rotation_degrees.x
		if ammo == 0:
			reloading = RELOAD_TIME


# ---------------------------------------------------------------- FPV-дрон

func start_drone(pos: Vector3) -> void:
	if drone_active:
		return
	drone_active = true
	drone_node = main.make_drone(main.my_team)
	main.world.add_child(drone_node)
	drone_node.global_position = pos
	drone_yaw = yaw
	drone_pitch = -10.0
	drone_throttle = 0.45
	drone_vel = Vector3.ZERO
	drone_cam = Camera3D.new()
	drone_cam.fov = 95.0
	drone_cam.near = 0.05
	drone_cam.far = 500.0
	drone_cam.position = Vector3(0.0, 0.05, -0.2)
	drone_node.add_child(drone_cam)
	drone_cam.current = true
	if touch:
		touch.drone_mode = true
		touch.reset_input()


func end_drone() -> void:
	if not drone_active:
		return
	drone_active = false
	if drone_node:
		drone_node.queue_free()
		drone_node = null
		drone_cam = null
	if cam:
		cam.current = true
	if touch:
		touch.drone_mode = false
		touch.reset_input()


func _drone_process(delta: float, mv: Vector2, look: Vector2, want_boom: bool) -> void:
	if drone_node == null:
		return
	drone_yaw -= look.x * LOOK_SENS
	drone_pitch = clampf(drone_pitch - look.y * LOOK_SENS, -85.0, 50.0)
	# стік вгору — газ, вниз — гальмо; вліво/вправо — бічний зсув
	drone_throttle = clampf(drone_throttle - mv.y * delta * 0.9, 0.15, 1.0)
	var b := Basis.from_euler(Vector3(deg_to_rad(drone_pitch), deg_to_rad(drone_yaw), 0.0))
	var target := -b.z * (6.0 + 26.0 * drone_throttle) + b.x * mv.x * 7.0
	drone_vel = drone_vel.lerp(target, clampf(delta * 2.5, 0.0, 1.0))
	drone_vel.y -= 1.2 * delta
	var from := drone_node.global_position
	var to := from + drone_vel * delta
	var q := PhysicsRayQueryParameters3D.create(from, to + drone_vel.normalized() * 0.4)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		main.local_drone_boom(hit.position)
		return
	drone_node.global_position = to
	drone_node.global_transform.basis = b
	if want_boom or main.enemy_near(to, 2.2):
		main.local_drone_boom(to)
