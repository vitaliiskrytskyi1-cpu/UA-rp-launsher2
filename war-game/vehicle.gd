extends Node3D
## БТР М113 на клієнті: модель, колізія, рух водія (місцево) і плавне
## відтворення руху для інших гравців (з даних сервера).

const World = preload("res://world.gd")
const Sfx = preload("res://sfx.gd")

## Типи техніки: БТР М113 і квадроцикл.
const KINDS := {
	"m113": {"max_fwd": 13.0, "max_rev": 4.5, "accel": 5.0, "turn": 0.9, "hw": 1.35, "hl": 2.5, "box": Vector3(3.0, 2.3, 5.3),
		"seats": 6, "hp": 600.0, "model": "res://models/m113.glb", "cam": 9.5, "eye": 0.6, "armored": true, "pitch": 0.32},
	"atv": {"max_fwd": 19.0, "max_rev": 5.0, "accel": 9.0, "turn": 1.7, "hw": 0.6, "hl": 1.05, "box": Vector3(1.2, 1.1, 2.1),
		"seats": 2, "hp": 160.0, "model": "res://models/atv.glb", "cam": 5.0, "eye": 0.55, "armored": false, "pitch": 0.6},
}
const KIND_IDS := ["m113", "atv"]
const BRAKE := 9.0
var kind := "m113"
var MAX_FWD := 13.0
var MAX_REV := 4.5
var ACCEL := 5.0
var TURN := 0.9
var HALF_W := 1.35
var HALF_L := 2.5

var vid := 0
var team := 0
var hp := 600.0
var alive := true
var speed := 0.0
var target_pos := Vector3.ZERO
var target_yaw := 0.0
var local_driver := false
var body: StaticBody3D
var model: Node3D
var engine: AudioStreamPlayer3D
var seats := [0, 0, 0, 0, 0, 0]
var _first := true


func setup(id: int, t: int, pos: Vector3, yaw: float, k: String = "m113") -> void:
	vid = id
	team = t
	kind = k if KINDS.has(k) else "m113"
	var kd: Dictionary = KINDS[kind]
	MAX_FWD = kd.max_fwd
	MAX_REV = kd.max_rev
	ACCEL = kd.accel
	TURN = kd.turn
	HALF_W = kd.hw
	HALF_L = kd.hl
	hp = kd.hp
	seats = []
	for i in int(kd.seats):
		seats.append(0)
	global_position = pos
	rotation.y = yaw
	target_pos = pos
	target_yaw = yaw
	body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = kd.box
	cs.shape = bs
	cs.position.y = bs.size.y * 0.5 + 0.1
	body.add_child(cs)
	add_child(body)
	var ps = load(String(kd.model)) if ResourceLoader.exists(String(kd.model)) else null
	if ps:
		model = ps.instantiate()
		add_child(model)
	elif kind == "atv":
		model = _atv_fallback()
		add_child(model)
	# позначка команди: смуга на борту
	var strip := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.08, 0.18, 1.2) if kind == "m113" else Vector3(0.5, 0.06, 0.5)
	strip.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.25, 0.5, 1.0) if team == 0 else Color(1.0, 0.8, 0.15)
	strip.material_override = sm
	strip.position = Vector3(0.0, 1.75, 0.0) if kind == "m113" else Vector3(0.0, 0.95, 0.75)
	add_child(strip)
	if DisplayServer.get_name() != "headless":
		engine = AudioStreamPlayer3D.new()
		engine.stream = Sfx.get_sound("drone")
		engine.pitch_scale = float(kd.pitch)
		engine.unit_size = 8.0
		engine.max_distance = 140.0
		engine.volume_db = -8.0
		if AudioServer.get_bus_index("SFX") >= 0:
			engine.bus = "SFX"
		add_child(engine)


func forward() -> Vector3:
	return -global_transform.basis.z


## Рух водія: mv.y < 0 — газ, > 0 — назад; mv.x — поворот.
func drive(mv: Vector2, delta: float) -> void:
	if not alive:
		speed = 0.0
		return
	var throttle := -mv.y
	var steer := mv.x
	if absf(throttle) < 0.15:
		speed = move_toward(speed, 0.0, BRAKE * 0.5 * delta)
	elif signf(throttle) != signf(speed) and absf(speed) > 0.3:
		speed = move_toward(speed, 0.0, BRAKE * delta)
	else:
		speed += throttle * ACCEL * delta
	speed = clampf(speed, -MAX_REV, MAX_FWD)
	var turn_k := clampf(absf(speed) / 3.0, 0.35, 1.0)
	var yaw := rotation.y - steer * TURN * turn_k * delta * (1.0 if speed >= -0.1 else -1.0)
	var dir := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var step := dir * speed * delta
	# перешкоди: промені з передніх (або задніх) кутів
	if absf(speed) > 0.05:
		var space := get_world_3d().direct_space_state
		var sgn := signf(speed)
		var side := Vector3(dir.z, 0.0, -dir.x)
		for k in [-1.0, 0.0, 1.0]:
			var from: Vector3 = global_position + Vector3(0.0, 0.6 if kind == "atv" else 1.3, 0.0) + side * HALF_W * float(k) * 0.9
			var to: Vector3 = from + dir * sgn * (HALF_L + 0.4 + absf(speed) * delta)
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.collision_mask = 1
			q.exclude = [body.get_rid()]
			if not space.intersect_ray(q).is_empty():
				speed = 0.0
				step = Vector3.ZERO
				break
	var p := global_position + step
	var half := float(World.cur.half) - 6.0
	p.x = clampf(p.x, -half, half)
	p.z = clampf(p.z, -half, half)
	rotation.y = yaw
	_settle(p, yaw)


## Висота і нахил по рельєфу (кути корпусу; окопи перекриваються корпусом).
func _settle(p: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var fr := b * Vector3(0, 0, -HALF_L)
	var rt := b * Vector3(HALF_W, 0, 0)
	var hf := maxf(World.ground_y(null, p.x + fr.x + rt.x, p.z + fr.z + rt.z), World.ground_y(null, p.x + fr.x - rt.x, p.z + fr.z - rt.z))
	var hb := maxf(World.ground_y(null, p.x - fr.x + rt.x, p.z - fr.z + rt.z), World.ground_y(null, p.x - fr.x - rt.x, p.z - fr.z - rt.z))
	var hr := maxf(World.ground_y(null, p.x + rt.x + fr.x, p.z + rt.z + fr.z), World.ground_y(null, p.x + rt.x - fr.x, p.z + rt.z - fr.z))
	var hl := maxf(World.ground_y(null, p.x - rt.x + fr.x, p.z - rt.z + fr.z), World.ground_y(null, p.x - rt.x - fr.x, p.z - rt.z - fr.z))
	var hc := World.ground_y(null, p.x, p.z)
	p.y = maxf((hf + hb) * 0.5, hc) - 0.05
	var pitch := atan2(hf - hb, HALF_L * 2.0)
	var roll := atan2(hr - hl, HALF_W * 2.0)
	global_position = p
	rotation = Vector3(pitch, yaw, -roll)


## Позиція від сервера (для машин, якими керує інший гравець).
func net_update(pos: Vector3, yaw: float, nhp: float, is_alive: bool) -> void:
	hp = nhp
	if alive and not is_alive:
		visible_dead(true)
	elif not alive and is_alive:
		visible_dead(false)
		_first = true
	alive = is_alive
	if local_driver:
		return
	target_pos = pos
	target_yaw = yaw
	if _first:
		_first = false
		global_position = pos
		rotation.y = yaw


func visible_dead(dead: bool) -> void:
	if model:
		model.visible = true
		_tint(model, Color(0.25, 0.22, 0.2) if dead else Color(1, 1, 1))


func _tint(n: Node, c: Color) -> void:
	if n is GeometryInstance3D:
		if c == Color(1, 1, 1):
			(n as GeometryInstance3D).material_override = null
		else:
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			(n as GeometryInstance3D).material_override = m
	for ch in n.get_children():
		_tint(ch, c)


func _process(delta: float) -> void:
	if not local_driver:
		var p := global_position.lerp(target_pos, clampf(delta * 8.0, 0.0, 1.0))
		var moved := global_position.distance_to(target_pos)
		speed = moved / maxf(delta, 0.001) * 0.1
		var y := lerp_angle(rotation.y, target_yaw, clampf(delta * 8.0, 0.0, 1.0))
		_settle(p, y)
	if engine:
		var busy: bool = int(seats[0]) != 0 and alive
		if busy and not engine.playing:
			engine.play()
		elif not busy and engine.playing:
			engine.stop()
		engine.pitch_scale = float(KINDS[kind].pitch) * (0.95 + absf(speed) / MAX_FWD * 1.1)


## Простий квадроцикл, поки немає моделі (рама, 4 колеса, кермо, сидіння).
func _atv_fallback() -> Node3D:
	var root := Node3D.new()
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color(0.25, 0.3, 0.18)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.06)
	var parts := [[Vector3(1.0, 0.35, 1.7), Vector3(0, 0.65, 0), body_m], [Vector3(0.5, 0.18, 0.7), Vector3(0, 0.92, 0.25), dark],
		[Vector3(1.1, 0.12, 0.55), Vector3(0, 0.88, -0.75), body_m], [Vector3(1.1, 0.12, 0.5), Vector3(0, 0.88, 0.8), body_m],
		[Vector3(0.75, 0.05, 0.05), Vector3(0, 1.12, -0.45), dark]]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.material_override = p[2]
		mi.position = p[1]
		root.add_child(mi)
	for wx in [-0.55, 0.55]:
		for wz in [-0.7, 0.72]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.3
			cm.bottom_radius = 0.3
			cm.height = 0.28
			w.mesh = cm
			w.material_override = dark
			w.rotation.z = PI * 0.5
			w.position = Vector3(wx, 0.3, wz)
			root.add_child(w)
	return root
