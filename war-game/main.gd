extends Node
## UA War Front — головний скрипт: меню, мережа, логіка сервера, HUD.
## Запуск сервера:  godot --headless --path . -- --server --port=7000
## Тестовий бот:    godot --headless --path . -- --bot --host=127.0.0.1 --port=7000

const World = preload("res://world.gd")
const Soldier = preload("res://soldier.gd")
const Avatar = preload("res://avatar.gd")
const TouchUI = preload("res://touch.gd")

const VERSION := 1
const DEFAULT_ADDR := "147.185.221.217:11983"
const DEFAULT_PORT := 7000
const MAX_PLAYERS := 40
const RESPAWN_TIME := 5.0
const START_TICKETS := 300
const DRONE_COOLDOWN := 25.0
const DRONE_LIFETIME := 45.0
const CAPTURE_RADIUS := 14.0
const BASE_Z := 120.0
const SNAP_RATE := 0.1
const TEAM_NAMES := ["Сині", "Жовті"]
const TEAM_COLORS := [Color(0.25, 0.5, 1.0), Color(1.0, 0.8, 0.15)]

var is_server := false
var is_bot := false
var connected := false
var world: Node3D
var players := {}
var avatars := {}
var remote_drones := {}
var drone_targets := {}
var soldier = null
var touch = null
var my_id := 0
var my_team := 0
var my_hp := 100
var alive_local := false
var local_drone_cd := 0.0
var tickets := [START_TICKETS, START_TICKETS]
var capture := 0.0
var round_over := false
var cfg_port := DEFAULT_PORT

# сервер
var snap_t := 0.0
var tick_acc := 0.0
var drain_acc := 0
var round_reset_t := 0.0
var pending_shots: Array = []
var pending_booms: Array = []

# інтерфейс
var ui: CanvasLayer
var menu: Control
var nick_edit: LineEdit
var addr_edit: LineEdit
var status_lbl: Label
var hud: Control
var hp_lbl: Label
var ammo_lbl: Label
var score_lbl: Label
var cap_lbl: Label
var feed_lbl: Label
var center_lbl: Label
var center_t := 0.0
var feed: Array = []
var tracer_mat: StandardMaterial3D
var boom_mat: StandardMaterial3D
var cap_ring_mat: StandardMaterial3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "127.0.0.1"
	for a in args:
		if a.begins_with("--port="):
			cfg_port = int(a.substr(7))
		elif a.begins_with("--host="):
			host = a.substr(7)
	if args.has("--server"):
		start_server()
	elif args.has("--bot"):
		is_bot = true
		_build_client_world()
		connect_to(host, cfg_port, "Bot_%d" % (randi() % 1000))
	else:
		_build_client_world()
		_build_ui()


# =====================================================================
#   СЕРВЕР
# =====================================================================

func start_server() -> void:
	is_server = true
	world = World.build(self, false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(cfg_port, MAX_PLAYERS)
	if err != OK:
		print("[SERVER] Cannot open UDP port %d (error %d)" % [cfg_port, err])
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[SERVER] UA War Front v%d started on UDP port %d" % [VERSION, cfg_port])


func _on_peer_connected(id: int) -> void:
	print("[SERVER] peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		print("[SERVER] player left: %s" % players[id].nick)
		players.erase(id)
		rpc("cl_remove_player", id)


func _team_count(t: int) -> int:
	var n := 0
	for p in players.values():
		if p.team == t:
			n += 1
	return n


func _new_pdata(nick: String, team: int) -> Dictionary:
	return {
		"nick": nick, "team": team, "hp": 100, "alive": false,
		"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "mode": 0,
		"dpos": Vector3.ZERO, "dyaw": 0.0, "kills": 0, "deaths": 0,
		"respawn": 0.0, "drone_cd": 0.0, "drone_t": 0.0, "last_fire": 0,
	}


func _server_spawn(id: int) -> void:
	var p: Dictionary = players[id]
	p.hp = 100
	p.alive = true
	p.mode = 0
	var z := -BASE_Z if p.team == 0 else BASE_Z
	p.pos = Vector3(randf_range(-25.0, 25.0), 1.2, z + randf_range(-6.0, 6.0))
	p.yaw = PI if p.team == 0 else 0.0
	rpc("cl_spawn", id, p.pos, p.yaw)


@rpc("any_peer", "call_remote", "reliable")
func srv_join(nick: String, ver: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if ver != VERSION:
		rpc_id(id, "cl_msg", "Версія гри застаріла. Оновіть застосунок.")
		return
	if players.has(id):
		return
	nick = nick.strip_edges().substr(0, 16)
	if nick == "":
		nick = "Боєць_%d" % (id % 1000)
	var team := 0 if _team_count(0) <= _team_count(1) else 1
	for pid in players:
		var e: Dictionary = players[pid]
		rpc_id(id, "cl_add_player", pid, e.nick, e.team, e.kills, e.deaths)
	players[id] = _new_pdata(nick, team)
	rpc("cl_add_player", id, nick, team, 0, 0)
	rpc_id(id, "cl_welcome", id, team, tickets[0], tickets[1], capture)
	print("[SERVER] %s joined team %d (players: %d)" % [nick, team, players.size()])
	_server_spawn(id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_state(pos: Vector3, yaw: float, pitch: float, mode: int, dpos: Vector3, dyaw: float) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive:
		return
	if p.pos.distance_to(pos) < 30.0:
		p.pos = pos
	p.yaw = yaw
	p.pitch = pitch
	if p.mode == 1 and mode == 1:
		if p.dpos.distance_to(dpos) < 40.0:
			p.dpos = dpos
		p.dyaw = dyaw


@rpc("any_peer", "call_remote", "reliable")
func srv_fire(origin: Vector3, dir: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	var now := Time.get_ticks_msec()
	if now - int(p.last_fire) < 85:
		return
	p.last_fire = now
	pending_shots.append([id, origin, dir])


@rpc("any_peer", "call_remote", "reliable")
func srv_drone_start() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or p.mode != 0 or round_over:
		return
	if p.drone_cd > 0.0:
		rpc_id(id, "cl_msg", "Дрон ще не готовий: %d с" % int(ceil(p.drone_cd)))
		return
	p.mode = 1
	p.dpos = p.pos + Vector3(0.0, 2.5, 0.0)
	p.dyaw = p.yaw
	p.drone_t = DRONE_LIFETIME
	rpc_id(id, "cl_drone_ok", p.dpos)


@rpc("any_peer", "call_remote", "reliable")
func srv_drone_boom(pos: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	pending_booms.append([id, pos])


func _physics_process(delta: float) -> void:
	if not is_server:
		return
	for s in pending_shots:
		_process_shot(s[0], s[1], s[2])
	pending_shots.clear()
	for b in pending_booms:
		_process_boom(b[0], b[1])
	pending_booms.clear()

	for pid in players.keys():
		if not players.has(pid):
			continue
		var p: Dictionary = players[pid]
		if p.drone_cd > 0.0:
			p.drone_cd = maxf(0.0, p.drone_cd - delta)
		if p.mode == 1:
			p.drone_t -= delta
			if p.drone_t <= 0.0:
				_end_drone(pid, true)
		if not p.alive and not round_over:
			p.respawn -= delta
			if p.respawn <= 0.0:
				_server_spawn(pid)

	snap_t -= delta
	if snap_t <= 0.0:
		snap_t = SNAP_RATE
		_send_snapshot()

	tick_acc += delta
	if tick_acc >= 1.0:
		tick_acc -= 1.0
		_capture_tick()

	if round_over:
		round_reset_t -= delta
		if round_reset_t <= 0.0:
			_round_restart()


func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var oc := c - o
	var t := oc.dot(d)
	if t < 0.0:
		return -1.0
	var dist2 := oc.length_squared() - t * t
	if dist2 > r * r:
		return -1.0
	return t - sqrt(r * r - dist2)


func _process_shot(id: int, origin: Vector3, dir: Vector3) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or p.mode != 0:
		return
	var eye: Vector3 = p.pos + Vector3(0.0, 1.6, 0.0)
	if origin.distance_to(eye) > 3.0:
		origin = eye
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var maxd := 350.0
	var best_d := maxd
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * maxd)
	q.collision_mask = 1
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		best_d = origin.distance_to(hit.position)
	var target := -1
	var target_drone := false
	var dmg := 0
	for pid in players:
		if pid == id:
			continue
		var e: Dictionary = players[pid]
		if not e.alive or e.team == p.team:
			continue
		var parts := [[Vector3(0.0, 1.6, 0.0), 0.24, 60], [Vector3(0.0, 1.1, 0.0), 0.42, 25], [Vector3(0.0, 0.45, 0.0), 0.33, 20]]
		for part in parts:
			var d := _ray_sphere(origin, dir, e.pos + part[0], part[1])
			if d >= 0.0 and d < best_d:
				best_d = d
				target = pid
				target_drone = false
				dmg = part[2]
		if e.mode == 1:
			var dd := _ray_sphere(origin, dir, e.dpos, 0.7)
			if dd >= 0.0 and dd < best_d:
				best_d = dd
				target = pid
				target_drone = true
	var end := origin + dir * best_d
	rpc("cl_tracer", id, origin, end)
	if target != -1:
		if target_drone:
			_end_drone(target, true)
			rpc_id(id, "cl_msg", "Дрон противника збито!")
		else:
			_damage(target, id, dmg)


func _damage(vid: int, kid: int, dmg: int) -> void:
	if not players.has(vid):
		return
	var v: Dictionary = players[vid]
	if not v.alive:
		return
	v.hp -= dmg
	if v.hp <= 0:
		_kill(vid, kid)
	else:
		rpc_id(vid, "cl_hp", v.hp)
		if players.has(kid):
			rpc_id(kid, "cl_hitmark")


func _kill(vid: int, kid: int) -> void:
	var v: Dictionary = players[vid]
	if v.mode == 1:
		_end_drone(vid, true)
	v.alive = false
	v.hp = 0
	v.deaths += 1
	v.respawn = RESPAWN_TIME
	var kname := ""
	if players.has(kid) and kid != vid:
		players[kid].kills += 1
		kname = players[kid].nick
	tickets[v.team] = maxi(0, tickets[v.team] - 1)
	rpc("cl_killed", vid, kid, kname)
	_check_round_end()


func _process_boom(id: int, pos: Vector3) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.mode != 1:
		return
	if pos.distance_to(p.dpos) > 12.0:
		pos = p.dpos
	_end_drone(id, false)
	_explode(pos, id, p.team, 7.0, 160.0)


func _explode(pos: Vector3, kid: int, team: int, radius: float, maxdmg: float) -> void:
	rpc("cl_boom", pos, radius)
	for pid in players.keys():
		if not players.has(pid):
			continue
		var e: Dictionary = players[pid]
		if not e.alive or e.team == team:
			continue
		if e.mode == 1 and e.dpos.distance_to(pos) < 4.0:
			_end_drone(pid, true)
		var d: float = (e.pos + Vector3(0.0, 0.9, 0.0)).distance_to(pos)
		if d < radius:
			_damage(pid, kid, int(maxdmg * (1.0 - d / radius)) + 10)


func _end_drone(id: int, destroyed: bool) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.mode != 1:
		return
	p.mode = 0
	p.drone_cd = DRONE_COOLDOWN
	rpc("cl_drone_end", id, destroyed, p.dpos)


func _send_snapshot() -> void:
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	for pid in players:
		var p: Dictionary = players[pid]
		if not p.alive:
			continue
		ids.append(pid)
		var vals := [p.pos.x, p.pos.y, p.pos.z, p.yaw, p.pitch, float(p.mode), p.dpos.x, p.dpos.y, p.dpos.z, p.dyaw]
		for v in vals:
			data.append(v)
	if ids.size() > 0:
		rpc("cl_snapshot", ids, data)


func _capture_tick() -> void:
	var n := [0, 0]
	for p in players.values():
		if p.alive and p.mode == 0 and Vector2(p.pos.x, p.pos.z).length() < CAPTURE_RADIUS:
			n[p.team] += 1
	var diff: int = n[1] - n[0]
	capture = clampf(capture + clampi(diff, -3, 3) * 8.0, -100.0, 100.0)
	var owner := -1
	if capture <= -100.0:
		owner = 0
	elif capture >= 100.0:
		owner = 1
	drain_acc += 1
	if owner != -1 and drain_acc >= 3 and not round_over:
		drain_acc = 0
		tickets[1 - owner] = maxi(0, tickets[1 - owner] - 1)
		_check_round_end()
	rpc("cl_status", tickets[0], tickets[1], capture)


func _check_round_end() -> void:
	if round_over:
		return
	for t in 2:
		if tickets[t] <= 0:
			round_over = true
			round_reset_t = 12.0
			print("[SERVER] round over, winner team %d" % (1 - t))
			rpc("cl_round_end", 1 - t)
			return


func _round_restart() -> void:
	round_over = false
	tickets = [START_TICKETS, START_TICKETS]
	capture = 0.0
	for pid in players:
		var p: Dictionary = players[pid]
		p.kills = 0
		p.deaths = 0
		p.drone_cd = 0.0
		if p.mode == 1:
			_end_drone(pid, false)
		_server_spawn(pid)
	rpc("cl_round_start")
	rpc("cl_status", tickets[0], tickets[1], capture)


# =====================================================================
#   КЛІЄНТ: мережа
# =====================================================================

func connect_to(host: String, port: int, nick: String) -> void:
	_set_status("Підключення до %s:%d..." % [host, port])
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		_set_status("Помилка підключення (%d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_conn_failed)
		multiplayer.server_disconnected.connect(_on_server_gone)
	set_meta("nick", nick)


func _on_connected() -> void:
	connected = true
	_set_status("Підключено. Заходимо в бій...")
	rpc_id(1, "srv_join", str(get_meta("nick", "Боєць")), VERSION)
	if is_bot:
		print("[BOT] connected as %d" % multiplayer.get_unique_id())


func _on_conn_failed() -> void:
	connected = false
	multiplayer.multiplayer_peer = null
	_set_status("Сервер не відповідає. Перевірте адресу і чи запущено сервер.")
	if is_bot:
		print("[BOT] connection failed")


func _on_server_gone() -> void:
	connected = false
	multiplayer.multiplayer_peer = null
	_clear_match()
	if is_bot:
		print("[BOT] server disconnected")
		get_tree().quit()
		return
	if menu:
		menu.show()
		hud.hide()
		touch.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_status("З'єднання з сервером втрачено.")


func _clear_match() -> void:
	for id in avatars:
		avatars[id].queue_free()
	avatars.clear()
	for id in remote_drones:
		remote_drones[id].queue_free()
	remote_drones.clear()
	drone_targets.clear()
	players.clear()
	if soldier:
		soldier.die()
		soldier.queue_free()
		soldier = null
	alive_local = false


func send_state(pos: Vector3, yaw: float, pitch: float, mode: int, dpos: Vector3, dyaw: float) -> void:
	if connected:
		rpc_id(1, "srv_state", pos, yaw, pitch, mode, dpos, dyaw)


func local_fire(origin: Vector3, dir: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_fire", origin, dir)
	_tracer(origin + dir * 0.6, origin + dir * 120.0)


func request_drone() -> void:
	if not connected or not alive_local:
		return
	if local_drone_cd > 0.0:
		_show_center("Дрон ще не готовий: %d с" % int(ceil(local_drone_cd)), 1.5)
		return
	rpc_id(1, "srv_drone_start")


func local_drone_boom(pos: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_drone_boom", pos)
	if soldier:
		soldier.end_drone()


func enemy_near(pos: Vector3, r: float) -> bool:
	for id in avatars:
		if not players.has(id) or players[id].team == my_team:
			continue
		var a: Node3D = avatars[id]
		if a.visible and (a.position + Vector3(0.0, 1.0, 0.0)).distance_to(pos) < r:
			return true
	return false


# ---------------------------------------------------------------- RPC від сервера

@rpc("authority", "call_remote", "reliable")
func cl_welcome(id: int, team: int, t0: int, t1: int, cap: float) -> void:
	my_id = id
	my_team = team
	tickets = [t0, t1]
	capture = cap
	if menu:
		menu.hide()
		hud.show()
		touch.show()
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_center("Ваша команда: %s" % TEAM_NAMES[team], 3.0)
	if is_bot:
		print("[BOT] welcome, team %d" % team)


@rpc("authority", "call_remote", "reliable")
func cl_add_player(id: int, nick: String, team: int, kills: int, deaths: int) -> void:
	players[id] = {"nick": nick, "team": team, "kills": kills, "deaths": deaths}
	if id != multiplayer.get_unique_id() and not avatars.has(id):
		var a = Avatar.new()
		a.setup(nick, TEAM_COLORS[team])
		a.visible = false
		world.add_child(a)
		avatars[id] = a


@rpc("authority", "call_remote", "reliable")
func cl_remove_player(id: int) -> void:
	players.erase(id)
	if avatars.has(id):
		avatars[id].queue_free()
		avatars.erase(id)
	_remove_remote_drone(id)


@rpc("authority", "call_remote", "reliable")
func cl_spawn(id: int, pos: Vector3, yaw: float) -> void:
	if id == my_id:
		if soldier == null:
			soldier = Soldier.new()
			soldier.setup(self, touch, is_bot)
			world.add_child(soldier)
		soldier.respawn(pos, yaw)
		alive_local = true
		my_hp = 100
		if is_bot:
			print("[BOT] spawned at %s" % str(pos))
	elif avatars.has(id):
		avatars[id].snap_to(pos, yaw)
		avatars[id].visible = true


@rpc("authority", "call_remote", "unreliable_ordered")
func cl_snapshot(ids: PackedInt32Array, data: PackedFloat32Array) -> void:
	for i in ids.size():
		var id := ids[i]
		if id == my_id:
			continue
		var b := i * 10
		if b + 9 >= data.size():
			break
		if avatars.has(id):
			var a = avatars[id]
			a.target_pos = Vector3(data[b], data[b + 1], data[b + 2])
			a.target_yaw = data[b + 3]
			a.visible = true
		var mode := int(data[b + 5])
		if mode == 1:
			var dpos := Vector3(data[b + 6], data[b + 7], data[b + 8])
			if not remote_drones.has(id) and players.has(id):
				var d := make_drone(players[id].team)
				world.add_child(d)
				d.global_position = dpos
				remote_drones[id] = d
			drone_targets[id] = [dpos, data[b + 9]]
		elif remote_drones.has(id):
			_remove_remote_drone(id)


@rpc("authority", "call_remote", "unreliable")
func cl_tracer(id: int, a: Vector3, b: Vector3) -> void:
	if id != my_id:
		_tracer(a, b)


@rpc("authority", "call_remote", "reliable")
func cl_hp(hp: int) -> void:
	my_hp = hp
	_show_center("Вас поранено!", 0.6)


@rpc("authority", "call_remote", "reliable")
func cl_hitmark() -> void:
	_show_center("✕ влучання", 0.4)


@rpc("authority", "call_remote", "reliable")
func cl_killed(vid: int, kid: int, kname: String) -> void:
	var vname: String = players[vid].nick if players.has(vid) else "?"
	if players.has(vid):
		players[vid].deaths += 1
	if players.has(kid) and kid != vid:
		players[kid].kills += 1
	if kname != "":
		_add_feed("%s  ✖  %s" % [kname, vname])
	else:
		_add_feed("%s загинув" % vname)
	if vid == my_id:
		alive_local = false
		my_hp = 0
		if soldier:
			soldier.die()
		_show_center("Вас знищено. Відродження через %d с" % int(RESPAWN_TIME), RESPAWN_TIME)
		if is_bot:
			print("[BOT] killed")
	elif avatars.has(vid):
		avatars[vid].visible = false
	if kid == my_id and vid != my_id:
		_show_center("Ворога знищено: %s" % vname, 1.5)


@rpc("authority", "call_remote", "reliable")
func cl_drone_ok(pos: Vector3) -> void:
	if soldier and alive_local:
		soldier.start_drone(pos)
		_show_center("FPV-дрон у повітрі! Влетіть у ворога або натисніть ВИБУХ", 2.5)
		if is_bot:
			print("[BOT] drone launched")


@rpc("authority", "call_remote", "reliable")
func cl_drone_end(id: int, destroyed: bool, pos: Vector3) -> void:
	if id == my_id:
		local_drone_cd = DRONE_COOLDOWN
		if soldier:
			soldier.end_drone()
		if destroyed:
			_show_center("Ваш дрон втрачено", 1.5)
	else:
		_remove_remote_drone(id)


@rpc("authority", "call_remote", "reliable")
func cl_boom(pos: Vector3, radius: float) -> void:
	_boom_fx(pos, radius)
	if is_bot:
		print("[BOT] explosion at %s" % str(pos))


@rpc("authority", "call_remote", "unreliable_ordered")
func cl_status(t0: int, t1: int, cap: float) -> void:
	tickets = [t0, t1]
	capture = cap


@rpc("authority", "call_remote", "reliable")
func cl_round_end(winner: int) -> void:
	_show_center("Перемога: %s! Новий раунд за 12 с" % TEAM_NAMES[winner], 12.0)


@rpc("authority", "call_remote", "reliable")
func cl_round_start() -> void:
	for id in players:
		players[id].kills = 0
		players[id].deaths = 0
	local_drone_cd = 0.0
	_show_center("Новий раунд! В бій!", 2.0)


@rpc("authority", "call_remote", "reliable")
func cl_msg(text: String) -> void:
	_show_center(text, 2.5)
	if is_bot:
		print("[BOT] msg: %s" % text)


func _remove_remote_drone(id: int) -> void:
	if remote_drones.has(id):
		remote_drones[id].queue_free()
		remote_drones.erase(id)
	drone_targets.erase(id)


# =====================================================================
#   КЛІЄНТ: світ, ефекти, інтерфейс
# =====================================================================

func _build_client_world() -> void:
	world = World.build(self, true)
	tracer_mat = StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.4)
	boom_mat = StandardMaterial3D.new()
	boom_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boom_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	boom_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.75)
	var ring := world.get_node_or_null("CapRing")
	if ring:
		cap_ring_mat = ring.material_override


func make_drone(team: int) -> Node3D:
	var d := Node3D.new()
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color(0.15, 0.15, 0.15)
	var light_m := StandardMaterial3D.new()
	light_m.albedo_color = TEAM_COLORS[team]
	light_m.emission_enabled = true
	light_m.emission = TEAM_COLORS[team]
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.08, 0.3)
	body.mesh = bm
	body.material_override = body_m
	d.add_child(body)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			var arm := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.11
			cm.bottom_radius = 0.11
			cm.height = 0.02
			cm.radial_segments = 10
			arm.mesh = cm
			arm.material_override = body_m
			arm.position = Vector3(x, 0.05, z)
			d.add_child(arm)
	var led := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.05
	lm.height = 0.1
	led.mesh = lm
	led.material_override = light_m
	led.position = Vector3(0.0, 0.07, 0.12)
	d.add_child(led)
	# вибухівка під дроном
	var charge := MeshInstance3D.new()
	var chm := CylinderMesh.new()
	chm.top_radius = 0.05
	chm.bottom_radius = 0.05
	chm.height = 0.25
	charge.mesh = chm
	charge.material_override = light_m
	charge.rotation.x = PI * 0.5
	charge.position = Vector3(0.0, -0.07, -0.05)
	d.add_child(charge)
	return d


func _tracer(a: Vector3, b: Vector3) -> void:
	if world == null or tracer_mat == null:
		return
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, length)
	mi.mesh = bm
	mi.material_override = tracer_mat
	world.add_child(mi)
	mi.global_position = (a + b) * 0.5
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.98:
		mi.look_at(b, Vector3.UP)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


func _boom_fx(pos: Vector3, radius: float) -> void:
	if world == null or boom_mat == null:
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = boom_mat
	world.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 0.6, 0.3)
	tw.tween_callback(mi.queue_free)


func _process(delta: float) -> void:
	if is_server:
		return
	if local_drone_cd > 0.0:
		local_drone_cd = maxf(0.0, local_drone_cd - delta)
	for id in drone_targets:
		if remote_drones.has(id):
			var d: Node3D = remote_drones[id]
			var t: Array = drone_targets[id]
			d.global_position = d.global_position.lerp(t[0], clampf(delta * 10.0, 0.0, 1.0))
			d.rotation.y = t[1]
	if cap_ring_mat:
		var c := Color(1, 1, 1, 0.25)
		if capture <= -100.0:
			c = Color(TEAM_COLORS[0].r, TEAM_COLORS[0].g, TEAM_COLORS[0].b, 0.35)
		elif capture >= 100.0:
			c = Color(TEAM_COLORS[1].r, TEAM_COLORS[1].g, TEAM_COLORS[1].b, 0.35)
		cap_ring_mat.albedo_color = c
	if hud == null or not hud.visible:
		return
	_update_hud(delta)


func _set_status(t: String) -> void:
	if status_lbl:
		status_lbl.text = t
	if is_bot:
		print("[BOT] " + t)


func _show_center(t: String, secs: float) -> void:
	if center_lbl:
		center_lbl.text = t
		center_t = secs


func _add_feed(t: String) -> void:
	feed.append(t)
	while feed.size() > 5:
		feed.pop_front()
	if feed_lbl:
		feed_lbl.text = "\n".join(PackedStringArray(feed))


func _update_hud(delta: float) -> void:
	hp_lbl.text = "♥ %d" % my_hp
	if soldier and alive_local:
		if soldier.drone_active:
			ammo_lbl.text = "FPV  газ %d%%" % int(soldier.drone_throttle * 100.0)
		elif soldier.reloading > 0.0:
			ammo_lbl.text = "ПЕРЕЗАРЯДКА..."
		else:
			ammo_lbl.text = "%d / 30" % soldier.ammo
	else:
		ammo_lbl.text = ""
	score_lbl.text = "%s  %d   :   %d  %s" % [TEAM_NAMES[0], tickets[0], tickets[1], TEAM_NAMES[1]]
	var cap_txt := "Точка: нейтральна"
	if capture <= -100.0:
		cap_txt = "Точка: %s" % TEAM_NAMES[0]
	elif capture >= 100.0:
		cap_txt = "Точка: %s" % TEAM_NAMES[1]
	elif absf(capture) > 1.0:
		cap_txt = "Захоплення: %d%%" % int(absf(capture))
	cap_lbl.text = cap_txt
	if touch:
		if local_drone_cd > 0.0:
			touch.drone_label = "%d" % int(ceil(local_drone_cd))
		else:
			touch.drone_label = "ДРОН"
	if center_t > 0.0:
		center_t -= delta
		if center_t <= 0.0:
			center_lbl.text = ""


func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.anchor_left = anchors.x
	c.anchor_top = anchors.y
	c.anchor_right = anchors.z
	c.anchor_bottom = anchors.w
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w


func _label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# ---------------- HUD
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	score_lbl = _label(hud, 30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(score_lbl, Vector4(0, 0, 1, 0), Vector4(0, 10, 0, 50))
	cap_lbl = _label(hud, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_place(cap_lbl, Vector4(0, 0, 1, 0), Vector4(0, 50, 0, 82))

	hp_lbl = _label(hud, 34, HORIZONTAL_ALIGNMENT_LEFT)
	_place(hp_lbl, Vector4(0, 0, 0, 0), Vector4(24, 16, 300, 60))

	feed_lbl = _label(hud, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(feed_lbl, Vector4(1, 0, 1, 0), Vector4(-430, 16, -20, 180))

	ammo_lbl = _label(hud, 30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(ammo_lbl, Vector4(0.5, 1, 0.5, 1), Vector4(-160, -70, 160, -22))

	center_lbl = _label(hud, 30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(center_lbl, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-450, -170, 450, -120))

	var cross := _label(hud, 34, HORIZONTAL_ALIGNMENT_CENTER)
	cross.text = "+"
	_place(cross, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-20, -26, 20, 22))
	hud.hide()

	# ---------------- сенсорне керування
	touch = TouchUI.new()
	ui.add_child(touch)
	touch.hide()

	# ---------------- меню
	menu = ColorRect.new()
	menu.color = Color(0.05, 0.06, 0.08, 0.92)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	menu.add_child(box)
	_place(box, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-290, -270, 290, 270))

	var title := Label.new()
	title.text = "UA WAR FRONT"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Бій 20 на 20 • FPV-дрони • штурм позицій"
	sub.add_theme_font_size_override("font_size", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")

	nick_edit = LineEdit.new()
	nick_edit.placeholder_text = "Позивний"
	nick_edit.max_length = 16
	nick_edit.text = str(cfg.get_value("main", "nick", ""))
	nick_edit.add_theme_font_size_override("font_size", 28)
	nick_edit.custom_minimum_size = Vector2(0, 60)
	box.add_child(nick_edit)

	addr_edit = LineEdit.new()
	addr_edit.placeholder_text = "Адреса сервера"
	var saved_addr := str(cfg.get_value("main", "addr", DEFAULT_ADDR))
	if saved_addr == "" or saved_addr.begins_with("127.0.0.1"):
		saved_addr = DEFAULT_ADDR
	addr_edit.text = saved_addr
	addr_edit.add_theme_font_size_override("font_size", 24)
	addr_edit.custom_minimum_size = Vector2(0, 56)
	box.add_child(addr_edit)

	var play := Button.new()
	play.text = "В БІЙ"
	play.add_theme_font_size_override("font_size", 36)
	play.custom_minimum_size = Vector2(0, 80)
	play.pressed.connect(_on_play_pressed)
	box.add_child(play)

	status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 20)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(status_lbl)

	var help := Label.new()
	help.text = "Ліва частина екрана — рух, права — огляд.\nДРОН — запустити FPV-дрон, далі газ стіком, ВИБУХ — підрив.\nТримайте точку в центрі, щоб ворог втрачав очки."
	help.add_theme_font_size_override("font_size", 17)
	help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)


func _on_play_pressed() -> void:
	var nick := nick_edit.text.strip_edges()
	if nick == "":
		_set_status("Введіть позивний.")
		return
	var addr := addr_edit.text.strip_edges()
	var host := addr
	var port := DEFAULT_PORT
	var colon := addr.rfind(":")
	if colon > 0:
		host = addr.substr(0, colon)
		port = int(addr.substr(colon + 1))
	if host == "" or port <= 0:
		_set_status("Неправильна адреса. Приклад: 147.185.221.218:12345")
		return
	var cfg := ConfigFile.new()
	cfg.set_value("main", "nick", nick)
	cfg.set_value("main", "addr", addr)
	cfg.save("user://settings.cfg")
	connect_to(host, port, nick)


func _unhandled_input(event: InputEvent) -> void:
	if is_server or OS.has_feature("mobile"):
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and hud and hud.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
