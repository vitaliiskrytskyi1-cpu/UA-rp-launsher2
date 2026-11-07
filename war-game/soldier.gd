extends CharacterBody3D
## Локальний гравець: вид від третьої особи, рух з урахуванням ваги спорядження,
## стрільба, гранатомет, міномет, приціл, FPV-дрон із ручним керуванням.

const Gear = preload("res://gear.gd")
const Character = preload("res://character.gd")
const Settings = preload("res://settings.gd")
const Sfx = preload("res://sfx.gd")
const World = preload("res://world.gd")

const BASE_SPEED := 5.4
const GRAV := 20.0
const JUMP := 5.8
const LOOK_SENS := 0.16
const SEND_RATE := 1.0 / 15.0
const DRONE_SPEEDS := [6.0, 13.0, 22.0]

var main
var touch
var bot := false

var yaw_pivot: Node3D
var head: Node3D
var arm: SpringArm3D
var cam: Camera3D
var model: Node3D
var yaw := 0.0
var pitch := 0.0

# спорядження і боєкомплект
var eq := {"w": "aks74u", "a": "none", "h": "none", "r": "none", "p": "none", "x": "none"}
var wdata: Dictionary = Gear.WEAPONS["aks74u"]
var in_mag := 30
var mags := 1
var drones := 0
var heavy_ammo := 0
var grenades := 0
var medkits := 0
var prone := false
var lean := 0
var lean_k := 0.0
var sprinting := false
var shoulder := 1.0
var gren_cd := 0.0
var _cam_x := 0.55
var speed_mult := 1.0
var slot := 0
var aiming := false
var crouching := false
var col_shape: CollisionShape3D
var capsule: CapsuleShape3D
var reloading := 0.0
var fire_cd := 0.0
var heavy_cd := 0.0
var send_t := 0.0
var step_t := 0.0
var mortar_target := Vector3.ZERO
var mortar_valid := false

var _mouse_look := Vector2.ZERO
var _keys := {}

# дрон
var drone_active := false
var drone_node: Node3D
var drone_cam: Camera3D
var drone_body: Node3D
var drone_vel := Vector3.ZERO
var drone_yaw := 0.0
var drone_tilt := -15.0
var drone_speed_mode := 1
var drone_sound: AudioStreamPlayer
var drone_recon := false
var in_veh := -1
var veh_seat := -1
var veh_send_t := 0.0

# бот для автотесту
var bot_t := 0.0
var bot_age := 0.0
var bot_move := Vector2.ZERO
var bot_turn := 0.0
var bot_step := 0
var bot_veh := -1


func setup(m, t, is_bot: bool) -> void:
	main = m
	touch = t
	bot = is_bot
	collision_layer = 2
	collision_mask = 1
	col_shape = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	col_shape.shape = capsule
	col_shape.position.y = 0.875
	add_child(col_shape)

	model = Character.new()
	add_child(model)
	model.setup(main.team_color(main.my_team), main.my_team)

	head = Node3D.new()
	head.position.y = 1.55
	add_child(head)
	arm = SpringArm3D.new()
	arm.position = Vector3(0.55, 0.2, 0.0)
	arm.spring_length = 2.7
	arm.collision_mask = 1
	arm.margin = 0.2
	head.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 500.0
	arm.add_child(cam)


func apply_loadout(new_eq: Dictionary, n_in_mag: int, n_mags: int, n_drones: int, n_heavy: int, n_gren: int = 0, n_med: int = 0) -> void:
	grenades = n_gren
	medkits = n_med
	eq = new_eq.duplicate()
	wdata = Gear.WEAPONS.get(eq.w, Gear.WEAPONS["aks74u"])
	in_mag = n_in_mag
	mags = n_mags
	drones = n_drones
	heavy_ammo = n_heavy
	_recalc_weight()
	if slot == 1 and eq.x == "none":
		slot = 0
	model.set_gear(eq, slot)
	_update_labels()


func _recalc_weight() -> void:
	var w := Gear.weight(eq, mags, drones, heavy_ammo, grenades, medkits)
	speed_mult = Gear.speed_mult(w)
	if slot == 2:
		speed_mult = minf(speed_mult + 0.1, 1.15)


func _update_labels() -> void:
	if model:
		model.set_pose(crouching, aiming)
	if touch == null:
		return
	match slot:
		0: touch.slot_icon = "rifle"
		1: touch.slot_icon = "rpg" if eq.x == "rpg" else "mortar"
		2: touch.slot_icon = "hands"
	touch.aiming = aiming
	touch.crouching = crouching
	touch.prone = prone
	touch.lean = lean


func _room_above(h: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.5, 0.0), global_position + Vector3(0.0, h, 0.0))
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _apply_capsule() -> void:
	capsule.height = 0.72 if prone else (1.15 if crouching else 1.75)
	col_shape.position.y = capsule.height * 0.5


func set_crouch(on: bool) -> void:
	if prone:
		if not _room_above(1.25):
			return
		prone = false
		crouching = true
	elif not on and crouching:
		# чи є місце, щоб встати
		if not _room_above(1.85):
			return
		crouching = false
	else:
		crouching = on
	_apply_capsule()
	_update_labels()


func set_prone(on: bool) -> void:
	if not on and prone:
		if not _room_above(1.85):
			return
		prone = false
		crouching = false
	else:
		prone = on
		if prone:
			lean = 0
			sprinting = false
	_apply_capsule()
	_update_labels()


func respawn(pos: Vector3, yaw_rad: float) -> void:
	end_drone()
	if in_veh >= 0:
		var v = main.vnodes.get(in_veh)
		if v and is_instance_valid(v):
			v.local_driver = false
	in_veh = -1
	veh_seat = -1
	col_shape.disabled = false
	arm.spring_length = 2.7
	global_position = pos
	velocity = Vector3.ZERO
	yaw = rad_to_deg(yaw_rad)
	pitch = 0.0
	rotation_degrees.y = yaw
	head.rotation_degrees.x = 0.0
	reloading = 0.0
	slot = 0
	crouching = false
	prone = false
	lean = 0
	lean_k = 0.0
	sprinting = false
	capsule.height = 1.75
	col_shape.position.y = 0.875
	set_aim(false)
	cam.current = true
	model.visible = true
	set_physics_process(true)
	_update_labels()


func die() -> void:
	end_drone()
	if in_veh >= 0:
		var v = main.vnodes.get(in_veh)
		if v and is_instance_valid(v):
			v.local_driver = false
		in_veh = -1
		veh_seat = -1
		col_shape.disabled = false
	set_aim(false)
	set_physics_process(false)
	if touch:
		touch.reset_input()


func set_aim(on: bool) -> void:
	aiming = on and slot != 2
	if aiming:
		sprinting = false
		arm.spring_length = 0.0
		cam.fov = wdata.zoom if slot == 0 else 55.0
		model.visible = false
	else:
		arm.spring_length = 2.7
		cam.fov = 72.0
		model.visible = true
	_update_labels()


## Вибір слота з панелі: повторне натискання на поточну зброю — сховати її.
func select_slot(n: int) -> void:
	if n == slot:
		n = 2
	if n == 1 and eq.x == "none":
		n = 2
	if n == slot:
		return
	slot = n
	reloading = 0.0
	set_aim(false)
	model.set_gear(eq, slot)
	_recalc_weight()
	main.send_slot(slot)
	Sfx.play(main, "reload", null, -8.0, 1.4)


func switch_slot() -> void:
	var next := (slot + 1) % 3
	if next == 1 and eq.x == "none":
		next = 2
	slot = next
	reloading = 0.0
	set_aim(false)
	model.set_gear(eq, slot)
	_recalc_weight()
	main.send_slot(slot)
	Sfx.play(main, "reload", null, -8.0, 1.4)


func _unhandled_input(event: InputEvent) -> void:
	if bot:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_look += event.relative
	elif event is InputEventKey and event.pressed and not event.echo:
		_keys[event.physical_keycode] = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_keys["aim"] = true


func _take_key(k) -> bool:
	if _keys.has(k):
		_keys.erase(k)
		return true
	return false


func _physics_process(delta: float) -> void:
	var mv := Vector2.ZERO
	var look := Vector2.ZERO
	var firing := false
	var up := false
	var down := false
	var jump := false
	var reload := false
	var want_drone := false
	var want_boom := false
	var want_aim := false
	var want_slot := false
	var want_speed := false
	var want_crouch := false
	var want_prone := false
	var want_gren := false
	var want_lean := 0
	var want_shoulder := false
	var sprint_in := false
	var want_stand := false
	var want_med := false
	var want_select := -1

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
		if bot_age > 2.0 and bot_step == 0:
			bot_step = 1
			main.bot_shop_test()
		if bot_age > 4.0 and bot_step == 1:
			bot_step = 2
			want_drone = true
		if drone_active:
			mv = Vector2(0.0, -1.0)
			up = bot_age < 6.0
			if bot_age > 7.5:
				want_boom = true
		if bot_age > 9.0 and bot_step == 2:
			bot_step = 3
			want_slot = true
		if bot_age > 10.0 and bot_step == 3:
			bot_step = 4
			reload = true
		if bot_age > 11.0 and bot_step == 4:
			bot_step = 5
			want_gren = true
			want_lean = 1
		if bot_age > 12.0 and bot_step == 5:
			bot_step = 6
			want_prone = true
		if bot_age > 13.5 and bot_step == 6:
			bot_step = 7
			want_prone = true
		if bot_step == 7:
			sprint_in = true
			mv = Vector2(0.0, -1.0)
			if bot_age > 15.0:
				bot_step = 8
				var nv: int = main.nearest_vehicle(global_position)
				print("[BOT] nearest vehicle %d" % nv)
				if nv < 0:
					# підійти до найближчої машини своєї команди
					for vid in main.vnodes:
						if int(main.vnodes[vid].team) == main.my_team:
							global_position = main.vnodes[vid].global_position + Vector3(3.5, 0.5, 0.0)
							nv = vid
							break
				print("[BOT] vehicles %d, try %d" % [main.vnodes.size(), nv])
				bot_veh = nv
		if bot_step == 8:
			mv = Vector2(0.4, -1.0)
			if in_veh < 0:
				mv = Vector2.ZERO
				if bot_age > 16.5 and bot_veh >= 0:
					main.request_veh_enter(bot_veh)
					bot_veh = -1
			if bot_age > 20.0 and in_veh >= 0:
				bot_step = 9
				print("[BOT] drove to %s" % str(global_position))
				main.request_veh_exit()
	else:
		if touch and touch.visible:
			mv = touch.move
			look = touch.look_delta
			touch.look_delta = Vector2.ZERO
			firing = touch.fire
			up = touch.up
			down = touch.down
			jump = touch.jump_pressed
			reload = touch.reload_pressed
			want_drone = touch.drone_pressed
			want_boom = touch.boom_pressed
			want_aim = touch.aim_pressed
			want_slot = touch.slot_pressed
			want_speed = touch.speed_pressed
			want_crouch = touch.crouch_pressed
			touch.crouch_pressed = false
			want_prone = touch.prone_pressed
			want_gren = touch.grenade_pressed
			want_shoulder = touch.shoulder_pressed
			if touch.lean_l_pressed:
				want_lean = -1
			if touch.lean_r_pressed:
				want_lean = 1
			sprint_in = touch.sprint
			want_stand = touch.stand_pressed
			want_med = touch.med_pressed
			want_select = touch.slot_select
			touch.stand_pressed = false
			touch.med_pressed = false
			touch.slot_select = -1
			touch.prone_pressed = false
			touch.grenade_pressed = false
			touch.shoulder_pressed = false
			touch.lean_l_pressed = false
			touch.lean_r_pressed = false
			touch.jump_pressed = false
			touch.reload_pressed = false
			touch.drone_pressed = false
			touch.boom_pressed = false
			touch.aim_pressed = false
			touch.slot_pressed = false
			touch.speed_pressed = false
		# клавіатура і миша (перевірка на ПК)
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
		up = up or Input.is_physical_key_pressed(KEY_SPACE) and drone_active
		down = down or Input.is_physical_key_pressed(KEY_CTRL)
		jump = jump or _take_key(KEY_SPACE)
		reload = reload or _take_key(KEY_R)
		want_drone = want_drone or _take_key(KEY_E)
		want_boom = want_boom or _take_key(KEY_F)
		want_slot = want_slot or _take_key(KEY_Q)
		if drone_active:
			want_speed = want_speed or _take_key(KEY_SHIFT)
		else:
			sprint_in = sprint_in or Input.is_physical_key_pressed(KEY_SHIFT)
		want_prone = want_prone or _take_key(KEY_Z)
		want_gren = want_gren or _take_key(KEY_G)
		want_med = want_med or _take_key(KEY_H)
		want_shoulder = want_shoulder or _take_key(KEY_V)
		if _take_key(KEY_1):
			want_lean = -1
		if _take_key(KEY_3):
			want_lean = 1
		want_aim = want_aim or _take_key("aim")
		want_crouch = want_crouch or _take_key(KEY_C)

	if not bot and _take_key(KEY_T) and touch:
		touch.veh_pressed = true
	if in_veh >= 0:
		_vehicle_process(delta, mv, look)
		return
	if drone_active:
		if want_speed:
			drone_speed_mode = (drone_speed_mode + 1) % DRONE_SPEEDS.size()
			if touch:
				touch.speed_level = drone_speed_mode + 1
		_drone_process(delta, mv, look, up, down, want_boom)
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAV * delta
		move_and_slide()
		model.animate(0.0, delta)
	else:
		if want_drone:
			main.request_drone()
		if want_slot:
			switch_slot()
		if want_aim:
			set_aim(not aiming)
		if want_crouch:
			set_crouch(not crouching)
		if want_prone:
			set_prone(not prone)
		if want_stand:
			if prone:
				set_prone(false)
			elif crouching:
				set_crouch(false)
		if want_med:
			main.use_medkit()
		if want_select >= 0:
			select_slot(want_select)
		if want_shoulder:
			shoulder = -shoulder
		if want_lean != 0:
			lean = 0 if lean == want_lean else want_lean
			if prone:
				lean = 0
			_update_labels()
		if want_gren:
			_throw_grenade()
		sprinting = sprint_in and mv.y < -0.3 and not prone and not aiming and slot != 1
		if sprinting and lean != 0:
			lean = 0
			_update_labels()
		_soldier_process(delta, mv, look, firing and not sprinting, jump, reload)

	send_t -= delta
	if send_t <= 0.0:
		send_t = SEND_RATE
		var dpos := Vector3.ZERO
		var dyaw := 0.0
		if drone_active and drone_node:
			dpos = drone_node.global_position
			dyaw = deg_to_rad(drone_yaw)
		var mode := (1 if drone_active else 0) | (2 if crouching else 0) | (4 if aiming else 0) | (8 if prone else 0) \
			| (16 if lean < 0 else 0) | (32 if lean > 0 else 0) | (64 if sprinting else 0) | (128 if not is_on_floor() else 0)
		main.send_state(global_position, rotation.y, head.rotation.x, mode, dpos, dyaw)


## У машині: водій керує, пасажир їде; камера — позаду машини.
func _vehicle_process(delta: float, mv: Vector2, look: Vector2) -> void:
	var v = main.vnodes.get(in_veh)
	if v == null or not is_instance_valid(v):
		exit_vehicle()
		return
	var sens := LOOK_SENS * float(Settings.value("controls", "sens", 1.0))
	if int(Settings.value("controls", "invert_y", 0)) == 1:
		look.y = -look.y
	yaw -= look.x * sens
	pitch = clampf(pitch - look.y * sens, -55.0, 15.0)
	rotation_degrees.y = yaw
	head.rotation_degrees.x = pitch
	if veh_seat == 0:
		v.local_driver = true
		v.drive(mv, delta)
		veh_send_t -= delta
		if veh_send_t <= 0.0:
			veh_send_t = 0.05
			main.send_veh_state(in_veh, v.global_position, v.rotation.y)
	global_position = v.global_position + Vector3(0.0, 0.6, 0.0)
	velocity = Vector3.ZERO
	model.animate(0.0, delta)
	send_t -= delta
	if send_t <= 0.0:
		send_t = SEND_RATE
		main.send_state(global_position, rotation.y, head.rotation.x, 256, Vector3.ZERO, 0.0)


func enter_vehicle(vid: int, seat: int) -> void:
	end_drone()
	set_aim(false)
	in_veh = vid
	veh_seat = seat
	col_shape.disabled = true
	model.visible = false
	arm.spring_length = 9.5
	arm.position = Vector3(0.0, 1.6, 0.0)
	pitch = -12.0
	var v = main.vnodes.get(vid)
	if v:
		yaw = rad_to_deg(v.rotation.y)
	if touch:
		touch.reset_input()


func exit_vehicle() -> void:
	if in_veh < 0:
		return
	var v = main.vnodes.get(in_veh)
	if v and is_instance_valid(v):
		v.local_driver = false
		var side: Vector3 = v.global_transform.basis.x.normalized() * 2.9
		var ep: Vector3 = v.global_position + side
		ep.y = World.ground_y(null, ep.x, ep.z, v.global_position.y) + 0.3
		global_position = ep
	in_veh = -1
	veh_seat = -1
	col_shape.disabled = false
	model.visible = true
	arm.spring_length = 2.7
	arm.position = Vector3(_cam_x, 0.2, 0.0)
	if touch:
		touch.reset_input()


func eye_pos() -> Vector3:
	return global_position + transform.basis * Vector3(lean_k * 0.38, head.position.y, 0.0)


func _throw_grenade() -> void:
	if grenades <= 0:
		main.show_hint("Немає гранат. Купіть у магазині (вкладка «Боєприпаси»).")
		return
	if gren_cd > 0.0 or drone_active:
		return
	gren_cd = 1.3
	grenades -= 1
	_recalc_weight()
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var maxd := float(Gear.GRENADE_RANGE)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * maxd)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var target: Vector3
	if not hit.is_empty():
		target = hit.position
	else:
		# точка падіння на висоті гравця
		target = from + dir * maxd
		target.y = global_position.y
	main.local_grenade(target)
	model.throw_grenade()


func _aim_point(maxd: float = 500.0) -> Vector3:
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * maxd)
	q.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	return from + dir * maxd


func _soldier_process(delta: float, mv: Vector2, look: Vector2, firing: bool, jump: bool, reload: bool) -> void:
	var sens := LOOK_SENS * (0.45 * float(Settings.value("controls", "aim_sens", 1.0)) if aiming else float(Settings.value("controls", "sens", 1.0)))
	if aiming and slot == 0 and wdata.zoom < 30.0:
		sens *= 0.5
	if int(Settings.value("controls", "invert_y", 0)) == 1:
		look.y = -look.y
	yaw -= look.x * sens
	pitch = clampf(pitch - look.y * sens, -80.0, 75.0)
	rotation_degrees.y = yaw
	head.rotation_degrees.x = pitch

	var head_h := 0.45 if prone else (1.05 if crouching else 1.55)
	head.position.y = move_toward(head.position.y, head_h, delta * (2.2 if prone else 3.0))
	# нахил з перевіркою стіни збоку
	var lean_t := float(lean)
	if lean != 0:
		var hp0 := global_position + Vector3(0.0, head.position.y, 0.0)
		var side := transform.basis.x * float(lean)
		var hq := PhysicsRayQueryParameters3D.create(hp0, hp0 + side * 0.65)
		hq.collision_mask = 1
		var hh := get_world_3d().direct_space_state.intersect_ray(hq)
		if not hh.is_empty():
			lean_t *= clampf(hp0.distance_to(hh.position) / 0.65 - 0.2, 0.0, 1.0)
	lean_k = move_toward(lean_k, lean_t, delta * 4.0)
	head.rotation.z = -lean_k * 0.16
	var side_x := (0.55 * shoulder if not aiming else 0.0) + lean_k * (0.42 if not aiming else 0.36)
	_cam_x = lerpf(_cam_x, side_x, clampf(delta * 8.0, 0.0, 1.0))
	arm.position = Vector3(_cam_x, 0.2 if not aiming else 0.05, 0.0)
	var spd := BASE_SPEED * speed_mult * (0.55 if aiming else 1.0) * (0.5 if crouching else 1.0) * (0.22 if prone else 1.0) * (1.42 if sprinting else 1.0)
	if mv.y > 0.2:
		spd *= 0.8   # назад повільніше
	var dir := transform.basis * Vector3(mv.x, 0.0, mv.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	# плавний розгін і гальмування
	var target_v := Vector2(dir.x, dir.z) * spd
	var cur_v := Vector2(velocity.x, velocity.z)
	var acc := (14.0 if target_v.length() > cur_v.length() else 20.0) * (1.0 if is_on_floor() else 0.25)
	cur_v = cur_v.move_toward(target_v, acc * delta)
	velocity.x = cur_v.x
	velocity.z = cur_v.y
	if is_on_floor():
		if jump and prone:
			set_prone(false)
		elif jump and crouching:
			set_crouch(false)
		elif jump:
			velocity.y = JUMP * clampf(speed_mult, 0.75, 1.0)
	else:
		velocity.y -= GRAV * delta
	move_and_slide()
	if global_position.y < float(World.cur.get("hmin", 0.0)) - 14.0:
		# впав за край карти — повернення на базу
		global_position = main.spawn_point(main.my_team)
		velocity = Vector3.ZERO
	var hs := Vector2(velocity.x, velocity.z).length()
	model.look_pitch = head.rotation.x
	var lv := transform.basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	model.move_local = Vector2(lv.x, -lv.z)
	model.set_move_state(prone, lean_k, sprinting, not is_on_floor())
	model.animate(hs, delta)
	gren_cd -= delta
	if hs > 0.5 and is_on_floor():
		step_t -= delta * hs / 4.0
		if step_t <= 0.0:
			step_t = 0.5
			Sfx.play(main, "step", null, -14.0, randf_range(0.85, 1.15))

	fire_cd -= delta
	heavy_cd -= delta
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0 and mags > 0:
			mags -= 1
			in_mag = int(wdata.mag)
			main.request_reload()
			_recalc_weight()
	if reload and slot == 0 and in_mag < int(wdata.mag) and reloading <= 0.0 and mags > 0:
		reloading = float(wdata.reload)
		Sfx.play(main, "reload", null, -6.0)

	mortar_valid = false
	if slot == 1 and eq.x == "mortar":
		var tp := _aim_point(500.0)
		var dist := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
		var h: Dictionary = Gear.HEAVY["mortar"]
		mortar_target = tp
		mortar_valid = dist >= float(h.min_range) and dist <= float(h.max_range)

	if not firing:
		return
	if slot == 0:
		if fire_cd <= 0.0 and reloading <= 0.0:
			if in_mag > 0:
				fire_cd = float(wdata.rof)
				in_mag -= 1
				var eye := eye_pos()
				var target := _aim_point()
				var spread_k := float(wdata.spread) * (0.4 if aiming else 1.0) * (1.6 if hs > 1.0 else 1.0) * (0.6 if crouching else 1.0)
				var spread := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * spread_k
				var d := ((target - eye).normalized() + spread).normalized()
				main.local_fire(eye, d, global_position + transform.basis * Vector3(0.12 + lean_k * 0.38, head.position.y - 0.3, -0.9))
				pitch = clampf(pitch + (0.5 if eq.w == "svd" else 0.22), -80.0, 75.0)
				if in_mag == 0 and mags > 0:
					reloading = float(wdata.reload)
					Sfx.play(main, "reload", null, -6.0)
			elif fire_cd <= 0.0:
				fire_cd = 0.4
				Sfx.play(main, "hit", null, -10.0, 0.6)
	elif slot == 1 and heavy_cd <= 0.0:
		if heavy_ammo <= 0:
			heavy_cd = 0.6
			main.show_hint("Немає боєприпасів для %s. Купіть у магазині." % Gear.HEAVY[eq.x].name)
			return
		if eq.x == "rpg":
			heavy_cd = 2.5
			heavy_ammo -= 1
			var eye := eye_pos()
			var d := (_aim_point() - eye).normalized()
			main.local_rpg(eye, d)
			pitch = clampf(pitch + 2.0, -80.0, 75.0)
		elif eq.x == "mortar":
			if not mortar_valid:
				heavy_cd = 0.5
				main.show_hint("Міномет: дистанція від 60 до 450 м. Наведіть приціл на ціль на землі.")
				return
			heavy_cd = 3.0
			heavy_ammo -= 1
			main.local_mortar(mortar_target)
		_recalc_weight()


# ---------------------------------------------------------------- FPV-дрон

func start_drone(pos: Vector3, recon: bool = false) -> void:
	if drone_active:
		return
	drone_active = true
	drone_recon = recon
	if not recon:
		drones = maxi(0, drones - 1)
	_recalc_weight()
	set_aim(false)
	drone_node = main.make_drone(main.my_team)
	main.world.add_child(drone_node)
	drone_node.global_position = pos
	drone_body = drone_node.get_child(0) if drone_node.get_child_count() > 0 else drone_node
	drone_yaw = yaw
	drone_tilt = -15.0
	drone_vel = Vector3.ZERO
	drone_cam = Camera3D.new()
	drone_cam.fov = 95.0
	drone_cam.near = 0.05
	drone_cam.far = 500.0
	drone_cam.position = Vector3(0.0, 0.05, -0.18)
	drone_node.add_child(drone_cam)
	drone_cam.current = true
	if DisplayServer.get_name() != "headless":
		drone_sound = AudioStreamPlayer.new()
		drone_sound.stream = Sfx.get_sound("drone")
		drone_sound.volume_db = -10.0
		add_child(drone_sound)
		drone_sound.play()
	if touch:
		touch.drone_mode = true
		touch.speed_level = drone_speed_mode + 1
		touch.reset_input()


func end_drone() -> void:
	if not drone_active:
		return
	drone_active = false
	if drone_node:
		drone_node.queue_free()
		drone_node = null
		drone_cam = null
		drone_body = null
	if drone_sound:
		drone_sound.queue_free()
		drone_sound = null
	if cam:
		cam.current = true
	if touch:
		touch.drone_mode = false
		touch.reset_input()


func _drone_process(delta: float, mv: Vector2, look: Vector2, up: bool, down: bool, want_boom: bool) -> void:
	if drone_node == null:
		return
	# огляд: вліво-вправо — розворот дрона, вгору-вниз — нахил камери
	var dsens := LOOK_SENS * float(Settings.value("controls", "drone_sens", 1.0))
	if int(Settings.value("controls", "invert_y", 0)) == 1:
		look.y = -look.y
	drone_yaw -= look.x * dsens
	drone_tilt = clampf(drone_tilt - look.y * dsens, -80.0, 25.0)
	var yb := Basis(Vector3.UP, deg_to_rad(drone_yaw))
	var fwd := -yb.z
	var right := yb.x
	var maxs: float = DRONE_SPEEDS[drone_speed_mode]
	var vert := (1.0 if up else 0.0) - (1.0 if down else 0.0)
	# джойстик: вперед/назад і вліво/вправо; кнопки — висота; без керування дрон зависає
	var target := (fwd * (-mv.y) + right * mv.x) * maxs + Vector3.UP * vert * 4.5
	drone_vel = drone_vel.move_toward(target, delta * (10.0 + maxs))
	var from := drone_node.global_position
	var step := drone_vel * delta
	if step.length() > 0.0001:
		var q := PhysicsRayQueryParameters3D.create(from, from + step + step.normalized() * 0.35)
		q.collision_mask = 1
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			if drone_vel.length() > 5.0 and not drone_recon:
				main.local_drone_boom(hit.position)
				return
			drone_vel = Vector3.ZERO
			step = Vector3.ZERO
	var to := from + step
	to.y = minf(to.y, 120.0)
	drone_node.global_position = to
	# нахил корпусу за рухом, як у справжнього квадрокоптера
	var tilt_f := -mv.y * 0.35 * (maxs / 22.0 + 0.4)
	var tilt_s := -mv.x * 0.35 * (maxs / 22.0 + 0.4)
	drone_node.global_transform.basis = yb * Basis.from_euler(Vector3(tilt_f, 0.0, tilt_s))
	if drone_cam:
		drone_cam.rotation_degrees.x = drone_tilt - rad_to_deg(tilt_f)
	if drone_sound:
		drone_sound.pitch_scale = 0.85 + drone_vel.length() / 30.0 + absf(vert) * 0.1
	if main.drone_seconds_left() <= 0.0:
		return
	if drone_recon:
		if want_boom and drone_cam:
			# позначка: точка на землі в центрі камери
			var cf := drone_cam.global_position
			var cd := -drone_cam.global_transform.basis.z
			var q2 := PhysicsRayQueryParameters3D.create(cf, cf + cd * 400.0)
			q2.collision_mask = 1
			var h2 := get_world_3d().direct_space_state.intersect_ray(q2)
			if not h2.is_empty():
				main.recon_mark(h2.position)
			else:
				main.show_hint("Наведіть камеру на землю")
		return
	if want_boom or main.enemy_near(to, 2.2):
		main.local_drone_boom(to)
