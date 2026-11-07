extends Node
## UA War Front — головний скрипт: меню, мережа, логіка сервера, магазин, HUD.
## Запуск сервера:  godot --headless --path . -- --server --port=7000
## Тестовий бот:    godot --headless --path . -- --bot --host=127.0.0.1 --port=7000

const World = preload("res://world.gd")
const Soldier = preload("res://soldier.gd")
const Avatar = preload("res://avatar.gd")
const TouchUI = preload("res://touch.gd")
const Gear = preload("res://gear.gd")
const Sfx = preload("res://sfx.gd")
const HudMap = preload("res://hudmap.gd")
const Inventory = preload("res://inventory.gd")
static var _fpv_scene: PackedScene

const VERSION := 4
const DEFAULT_ADDR := "147.185.221.217:11983"
const DEFAULT_PORT := 7000
const MAX_PLAYERS := 40
const RESPAWN_TIME := 6.0
const START_TICKETS := 300
const DRONE_LIFETIME := 60.0
const CAPTURE_RADIUS := 14.0
const BASE_Z := 120.0
const BASE_RADIUS := 32.0
const SNAP_RATE := 0.1
const SNAP_FIELDS := 11
const TEAM_NAMES := ["Сині", "Жовті"]
const TEAM_COLORS := [Color(0.25, 0.5, 1.0), Color(1.0, 0.8, 0.15)]
const PROFILES_PATH := "user://profiles.cfg"

var is_server := false
var is_bot := false
var connected := false
var world: Node3D
var players := {}
var avatars := {}
var remote_drones := {}
var drone_targets := {}
var projectiles: Array = []
var soldier = null
var touch = null
var my_id := 0
var my_team := 0
var my_hp := 100
var alive_local := false
var drone_time := 0.0
var tickets := [START_TICKETS, START_TICKETS]
var capture := 0.0
var round_over := false
var cfg_port := DEFAULT_PORT
var profile := {}

# сервер
var snap_t := 0.0
var tick_acc := 0.0
var drain_acc := 0
var round_reset_t := 0.0
var pending_shots: Array = []
var pending_booms: Array = []
var server_projectiles: Array = []
var mortar_impacts: Array = []
var profiles_cfg: ConfigFile
var save_t := 0.0
var save_dirty := false

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
var money_lbl: Label
var center_t := 0.0
var feed: Array = []
var shop: Control
var shop_list: VBoxContainer
var shop_money: Label
var shop_info: Label
var shop_cat := "w"
var minimap: Control
var bigmap: Control
var bag: Control
var tracer_mat: StandardMaterial3D
var boom_mat: StandardMaterial3D
var smoke_mat: StandardMaterial3D
var rocket_mat: StandardMaterial3D
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
#   СЕРВЕР: профілі гравців
# =====================================================================

func _load_profile(nick: String) -> Dictionary:
	var key := nick.to_lower()
	var p = null
	if profiles_cfg.has_section_key("p", key):
		p = profiles_cfg.get_value("p", key)
	if typeof(p) != TYPE_DICTIONARY:
		p = Gear.new_profile()
	return Gear.fix_profile(p)


func _save_profile(id: int) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	profiles_cfg.set_value("p", String(p.nick).to_lower(), p.prof)
	save_dirty = true


func start_server() -> void:
	is_server = true
	profiles_cfg = ConfigFile.new()
	profiles_cfg.load(PROFILES_PATH)
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
		_return_carried(id)
		_save_profile(id)
		players.erase(id)
		rpc("cl_remove_player", id)


func _team_count(t: int) -> int:
	var n := 0
	for p in players.values():
		if p.team == t:
			n += 1
	return n


func _new_pdata(nick: String, team: int, prof: Dictionary) -> Dictionary:
	return {
		"nick": nick, "team": team, "hp": 100, "alive": false, "prof": prof,
		"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "mode": 0, "slot": 0,
		"dpos": Vector3.ZERO, "dyaw": 0.0, "kills": 0, "deaths": 0,
		"respawn": 0.0, "drone_t": 0.0, "last_fire": 0, "last_heavy": 0,
		"in_mag": 0, "mags": 0, "drones": 0, "heavy": 0, "crouch": false,
	}


# Видача спорядження зі складу гравця при відродженні.
func _equip(id: int) -> void:
	var p: Dictionary = players[id]
	var prof: Dictionary = p.prof
	var eq: Dictionary = prof.eq
	var w: Dictionary = Gear.WEAPONS[eq.w]
	var stock := int(prof.mags.get(eq.w, 0))
	var take := mini(stock, Gear.mag_capacity(eq))
	if take <= 0:
		take = 1  # один магазин видають завжди
	else:
		prof.mags[eq.w] = stock - take
	p.in_mag = int(w.mag)
	p.mags = take - 1
	var dt := mini(int(prof.fpv), Gear.drone_slots(eq))
	prof.fpv = int(prof.fpv) - dt
	p.drones = dt
	p.heavy = 0
	if eq.x != "none":
		var hs := int(prof.heavy_ammo.get(eq.x, 0))
		var ht := mini(hs, Gear.heavy_slots(eq))
		prof.heavy_ammo[eq.x] = hs - ht
		p.heavy = ht
	p.slot = 0
	_save_profile(id)
	_send_loadout(id)
	rpc("cl_gear", id, eq, 0)


# Повернення невикористаного на склад (вихід з гри, зміна спорядження на базі).
func _return_carried(id: int) -> void:
	var p: Dictionary = players[id]
	if not p.alive:
		return
	var prof: Dictionary = p.prof
	var eq: Dictionary = prof.eq
	var back := int(p.mags) + (1 if int(p.in_mag) > 0 else 0)
	prof.mags[eq.w] = int(prof.mags.get(eq.w, 0)) + back
	prof.fpv = int(prof.fpv) + int(p.drones)
	if eq.x != "none":
		prof.heavy_ammo[eq.x] = int(prof.heavy_ammo.get(eq.x, 0)) + int(p.heavy)
	p.mags = 0
	p.in_mag = 0
	p.drones = 0
	p.heavy = 0


func _send_loadout(id: int) -> void:
	var p: Dictionary = players[id]
	rpc_id(id, "cl_loadout", p.prof, p.in_mag, p.mags, p.drones, p.heavy)


func _server_spawn(id: int) -> void:
	var p: Dictionary = players[id]
	p.hp = 100
	p.alive = true
	p.mode = 0
	var z := -BASE_Z if p.team == 0 else BASE_Z
	p.pos = Vector3(randf_range(-25.0, 25.0), 1.2, z + randf_range(-6.0, 6.0))
	p.yaw = PI if p.team == 0 else 0.0
	rpc("cl_spawn", id, p.pos, p.yaw)
	_equip(id)


func _in_base(p: Dictionary) -> bool:
	var bz := -BASE_Z if p.team == 0 else BASE_Z
	return Vector2(p.pos.x, p.pos.z - bz).length() < BASE_RADIUS


func _spend(prof: Dictionary, amount: int) -> void:
	if Gear.UNLIMITED_MONEY:
		prof.money = Gear.UNLIMITED_AMOUNT
	else:
		prof.money = int(prof.money) - amount


func _give_money(id: int, amount: int, reason: String) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	p.prof.money = int(p.prof.money) + amount
	_save_profile(id)
	rpc_id(id, "cl_money", int(p.prof.money), amount, reason)


@rpc("any_peer", "call_remote", "reliable")
func srv_join(nick: String, ver: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if ver != VERSION:
		rpc_id(id, "cl_msg", "Версія гри застаріла. Скачайте нову версію.")
		return
	if players.has(id):
		return
	nick = nick.strip_edges().substr(0, 16)
	if nick == "":
		nick = "Боєць_%d" % (id % 1000)
	for pid in players:
		if String(players[pid].nick).to_lower() == nick.to_lower():
			rpc_id(id, "cl_msg", "Позивний «%s» вже в грі. Оберіть інший." % nick)
			return
	var team := 0 if _team_count(0) <= _team_count(1) else 1
	for pid in players:
		var e: Dictionary = players[pid]
		rpc_id(id, "cl_add_player", pid, e.nick, e.team, e.kills, e.deaths)
		rpc_id(id, "cl_gear", pid, e.prof.eq, int(e.slot))
	players[id] = _new_pdata(nick, team, _load_profile(nick))
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
	p.crouch = (mode & 2) != 0
	p.aim = (mode & 4) != 0
	if p.mode == 1 and (mode & 1) == 1:
		if p.dpos.distance_to(dpos) < 40.0:
			p.dpos = dpos
		p.dyaw = dyaw


@rpc("any_peer", "call_remote", "reliable")
func srv_slot(slot: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if slot < 0 or slot > 2 or (slot == 1 and p.prof.eq.x == "none"):
		slot = 0
	p.slot = slot
	rpc("cl_gear", id, p.prof.eq, slot)


@rpc("any_peer", "call_remote", "reliable")
func srv_fire(origin: Vector3, dir: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if int(p.slot) != 0 or int(p.in_mag) <= 0:
		return
	var w: Dictionary = Gear.WEAPONS[p.prof.eq.w]
	var now := Time.get_ticks_msec()
	if now - int(p.last_fire) < int(float(w.rof) * 800.0):
		return
	p.last_fire = now
	p.in_mag = int(p.in_mag) - 1
	pending_shots.append([id, origin, dir])


@rpc("any_peer", "call_remote", "reliable")
func srv_reload() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if int(p.mags) <= 0:
		return
	p.mags = int(p.mags) - 1
	p.in_mag = int(Gear.WEAPONS[p.prof.eq.w].mag)


@rpc("any_peer", "call_remote", "reliable")
func srv_rpg(origin: Vector3, dir: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or p.prof.eq.x != "rpg" or int(p.slot) != 1 or int(p.heavy) <= 0:
		return
	var now := Time.get_ticks_msec()
	if now - int(p.last_heavy) < 2000:
		return
	p.last_heavy = now
	p.heavy = int(p.heavy) - 1
	var eye: Vector3 = p.pos + Vector3(0.0, 1.55, 0.0)
	if origin.distance_to(eye) > 3.0:
		origin = eye
	dir = dir.normalized()
	var vel: Vector3 = dir * float(Gear.HEAVY["rpg"].speed)
	server_projectiles.append({"owner": id, "team": p.team, "pos": origin + dir * 0.8, "vel": vel, "t": 0.0})
	rpc("cl_rocket", id, origin + dir * 0.8, vel)


@rpc("any_peer", "call_remote", "reliable")
func srv_mortar(target: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	var h: Dictionary = Gear.HEAVY["mortar"]
	if not p.alive or p.prof.eq.x != "mortar" or int(p.slot) != 1 or int(p.heavy) <= 0:
		return
	var dist := Vector2(target.x - p.pos.x, target.z - p.pos.z).length()
	if dist < float(h.min_range) or dist > float(h.max_range):
		return
	var now := Time.get_ticks_msec()
	if now - int(p.last_heavy) < 2500:
		return
	p.last_heavy = now
	p.heavy = int(p.heavy) - 1
	# розсіювання росте з дистанцією
	var spread := 2.0 + dist * 0.02
	var impact := Vector3(target.x + randf_range(-spread, spread), 0.0, target.z + randf_range(-spread, spread))
	var flight := 3.0 + dist / 110.0
	mortar_impacts.append({"owner": id, "team": p.team, "pos": impact, "t": flight})
	rpc("cl_mortar_fire", id, p.pos, impact, flight)


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
	if int(p.drones) <= 0:
		rpc_id(id, "cl_msg", "Немає дронів. Купіть FPV-дрони і рюкзак у магазині.")
		return
	p.drones = int(p.drones) - 1
	p.mode = 1
	var fwd := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	p.dpos = p.pos + fwd * 1.5 + Vector3(0.0, 1.8, 0.0)
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


@rpc("any_peer", "call_remote", "reliable")
func srv_buy(cat: String, key: String, qty: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	var prof: Dictionary = p.prof
	qty = clampi(qty, 1, 20)
	var msg := ""
	match cat:
		"w", "a", "h", "r", "p", "x":
			var c := Gear.catalog(cat)
			if not c.has(key):
				return
			var tag := "%s:%s" % [cat, key]
			if not prof.owned.has(tag):
				var price := int(c[key].price)
				if int(prof.money) < price:
					rpc_id(id, "cl_msg", "Недостатньо грошей.")
					return
				_spend(prof, price)
				prof.owned.append(tag)
				msg = "Куплено: %s" % c[key].name
			else:
				msg = "Обрано: %s" % c[key].name
			if p.alive and _in_base(p):
				_return_carried(id)
				prof.eq[cat] = key
				_equip(id)
			else:
				prof.eq[cat] = key
				msg += " (видадуть після відродження)"
		"fpv":
			var cost := Gear.FPV_PRICE * qty
			if int(prof.money) < cost:
				rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.fpv = int(prof.fpv) + qty
			msg = "Куплено FPV-дронів: %d" % qty
		"mag":
			if not Gear.WEAPONS.has(key):
				return
			var cost := int(Gear.WEAPONS[key].mag_price) * qty
			if int(prof.money) < cost:
				rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.mags[key] = int(prof.mags.get(key, 0)) + qty
			msg = "Куплено магазинів: %d" % qty
		"hammo":
			if not Gear.HEAVY.has(key) or key == "none":
				return
			var cost := int(Gear.HEAVY[key].ammo_price) * qty
			if int(prof.money) < cost:
				rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.heavy_ammo[key] = int(prof.heavy_ammo.get(key, 0)) + qty
			msg = "Куплено: %s × %d" % [Gear.HEAVY[key].ammo_name, qty]
		_:
			return
	# поповнення на базі
	if p.alive and _in_base(p) and cat in ["fpv", "mag", "hammo"]:
		_return_carried(id)
		_equip(id)
	_save_profile(id)
	_send_loadout(id)
	rpc_id(id, "cl_msg", msg)
	print("[SERVER] %s: %s" % [p.nick, msg])


func _physics_process(delta: float) -> void:
	if not is_server:
		return
	for s in pending_shots:
		_process_shot(s[0], s[1], s[2])
	pending_shots.clear()
	for b in pending_booms:
		_process_boom(b[0], b[1])
	pending_booms.clear()
	_update_projectiles(delta)
	_update_mortars(delta)

	for pid in players.keys():
		if not players.has(pid):
			continue
		var p: Dictionary = players[pid]
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

	save_t -= delta
	if save_t <= 0.0:
		save_t = 10.0
		if save_dirty:
			save_dirty = false
			profiles_cfg.save(PROFILES_PATH)

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
	var w: Dictionary = Gear.WEAPONS[p.prof.eq.w]
	var eye: Vector3 = p.pos + Vector3(0.0, 1.55, 0.0)
	if origin.distance_to(eye) > 3.0:
		origin = eye
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var maxd := 400.0
	var best_d := maxd
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * maxd)
	q.collision_mask = 1
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		best_d = origin.distance_to(hit.position)
	var target := -1
	var target_drone := false
	var part_hit := 1
	for pid in players:
		if pid == id:
			continue
		var e: Dictionary = players[pid]
		if not e.alive or e.team == p.team:
			continue
		var parts := [[Vector3(0.0, 1.7, 0.0), 0.2, 0], [Vector3(0.0, 1.3, 0.0), 0.32, 1], [Vector3(0.0, 0.95, 0.0), 0.3, 1], [Vector3(0.0, 0.45, 0.0), 0.3, 2]]
		var hk := 0.66 if e.crouch else 1.0
		for part in parts:
			var d := _ray_sphere(origin, dir, e.pos + part[0] * hk, part[1])
			if d >= 0.0 and d < best_d:
				best_d = d
				target = pid
				target_drone = false
				part_hit = part[2]
		if e.mode == 1:
			var dd := _ray_sphere(origin, dir, e.dpos, 0.6)
			if dd >= 0.0 and dd < best_d:
				best_d = dd
				target = pid
				target_drone = true
	var end := origin + dir * best_d
	rpc("cl_tracer", id, origin, end, p.prof.eq.w)
	if target == -1:
		return
	if target_drone:
		_end_drone(target, true)
		_give_money(id, Gear.REWARD_DRONE_SHOTDOWN, "дрон збито")
		return
	var e: Dictionary = players[target]
	var dmg := float(w.dmg)
	var head := part_hit == 0
	if head:
		dmg *= 2.2 * (1.0 - float(Gear.HELMET[e.prof.eq.h].reduce))
	elif part_hit == 1:
		dmg *= 1.0 - float(Gear.ARMOR[e.prof.eq.a].reduce)
	else:
		dmg *= 0.8
	_damage(target, id, int(round(dmg)), head)


func _damage(vid: int, kid: int, dmg: int, head: bool = false) -> void:
	if not players.has(vid):
		return
	var v: Dictionary = players[vid]
	if not v.alive:
		return
	v.hp -= maxi(1, dmg)
	if v.hp <= 0:
		_kill(vid, kid, head)
	else:
		rpc_id(vid, "cl_hp", v.hp)
		if players.has(kid) and kid != vid:
			rpc_id(kid, "cl_hitmark")


func _kill(vid: int, kid: int, head: bool = false) -> void:
	var v: Dictionary = players[vid]
	if v.mode == 1:
		_end_drone(vid, true)
	v.alive = false
	v.hp = 0
	v.deaths += 1
	v.respawn = RESPAWN_TIME
	# все, що було з собою, втрачено
	v.mags = 0
	v.in_mag = 0
	v.drones = 0
	v.heavy = 0
	_save_profile(vid)
	var kname := ""
	if players.has(kid) and kid != vid:
		players[kid].kills += 1
		kname = players[kid].nick
		var reward := Gear.REWARD_KILL + (Gear.REWARD_HEADSHOT if head else 0)
		_give_money(kid, reward, "ліквідація" + (" в голову" if head else ""))
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
	_explode(pos, id, p.team, 7.0, 170.0, Gear.REWARD_DRONE_KILL)


func _explode(pos: Vector3, kid: int, team: int, radius: float, maxdmg: float, reward: int = 0) -> void:
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
			# укриття: якщо між вибухом і ціллю стіна — шкода значно менша
			var cover := 1.0
			var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.3, 0.0), e.pos + Vector3(0.0, 1.0, 0.0))
			q.collision_mask = 1
			if not world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				cover = 0.3
			var armor := 1.0 - float(Gear.ARMOR[e.prof.eq.a].reduce) * 0.5
			var dmg := int(maxdmg * (1.0 - d / radius) * cover * armor) + 5
			var was_alive: bool = e.alive
			_damage(pid, kid, dmg)
			if was_alive and not e.alive and reward > 0 and players.has(kid):
				_give_money(kid, reward - Gear.REWARD_KILL, "бонус за вибух")


func _update_projectiles(delta: float) -> void:
	if server_projectiles.is_empty():
		return
	var space := world.get_world_3d().direct_space_state
	var keep: Array = []
	for pr in server_projectiles:
		pr.t += delta
		var vel: Vector3 = pr.vel
		vel.y -= 2.0 * delta
		pr.vel = vel
		var from: Vector3 = pr.pos
		var to: Vector3 = from + vel * delta
		var hit_pos := Vector3.INF
		var q := PhysicsRayQueryParameters3D.create(from, to)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			hit_pos = hit.position
		var seg := to - from
		var seg_len := seg.length()
		if seg_len > 0.0:
			var dir := seg / seg_len
			for pid in players:
				var e: Dictionary = players[pid]
				if not e.alive or e.team == pr.team:
					continue
				var d := _ray_sphere(from, dir, e.pos + Vector3(0.0, 1.0, 0.0), 0.7)
				if d >= 0.0 and d <= seg_len:
					hit_pos = from + dir * d
				if e.mode == 1:
					var dd := _ray_sphere(from, dir, e.dpos, 0.8)
					if dd >= 0.0 and dd <= seg_len:
						hit_pos = from + dir * dd
		if hit_pos != Vector3.INF:
			var h: Dictionary = Gear.HEAVY["rpg"]
			_explode(hit_pos, pr.owner, pr.team, float(h.radius), float(h.dmg))
		elif pr.t > 5.0:
			_explode(to, pr.owner, pr.team, float(Gear.HEAVY["rpg"].radius), float(Gear.HEAVY["rpg"].dmg))
		else:
			pr.pos = to
			keep.append(pr)
	server_projectiles = keep


func _update_mortars(delta: float) -> void:
	if mortar_impacts.is_empty():
		return
	var keep: Array = []
	for m in mortar_impacts:
		m.t -= delta
		if m.t <= 0.0:
			var h: Dictionary = Gear.HEAVY["mortar"]
			_explode(m.pos + Vector3(0.0, 0.3, 0.0), m.owner, m.team, float(h.radius), float(h.dmg))
		else:
			keep.append(m)
	mortar_impacts = keep


func _end_drone(id: int, destroyed: bool) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.mode != 1:
		return
	p.mode = 0
	rpc("cl_drone_end", id, destroyed, p.dpos)


func _send_snapshot() -> void:
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	for pid in players:
		var p: Dictionary = players[pid]
		if not p.alive:
			continue
		ids.append(pid)
		var m := int(p.mode) | (2 if p.crouch else 0) | (4 if p.get("aim", false) else 0)
		var vals := [p.pos.x, p.pos.y, p.pos.z, p.yaw, p.pitch, float(m), p.dpos.x, p.dpos.y, p.dpos.z, p.dyaw, float(p.slot)]
		for v in vals:
			data.append(v)
	if ids.size() > 0:
		rpc("cl_snapshot", ids, data)


func _capture_tick() -> void:
	var n := [0, 0]
	var on_point: Array = []
	for pid in players:
		var p: Dictionary = players[pid]
		if p.alive and p.mode == 0 and Vector2(p.pos.x, p.pos.z).length() < CAPTURE_RADIUS:
			n[p.team] += 1
			on_point.append(pid)
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
		for pid in on_point:
			if players[pid].team == owner:
				players[pid].prof.money = int(players[pid].prof.money) + Gear.REWARD_CAPTURE_TICK * 3
				rpc_id(pid, "cl_money", int(players[pid].prof.money), 0, "")
		_check_round_end()
	rpc("cl_status", tickets[0], tickets[1], capture)


func _check_round_end() -> void:
	if round_over:
		return
	for t in 2:
		if tickets[t] <= 0:
			round_over = true
			round_reset_t = 12.0
			var winner := 1 - t
			print("[SERVER] round over, winner team %d" % winner)
			for pid in players:
				if players[pid].team == winner:
					_give_money(pid, Gear.REWARD_WIN, "перемога")
				else:
					_give_money(pid, Gear.REWARD_LOSS, "участь у бою")
			rpc("cl_round_end", winner)
			return


func _round_restart() -> void:
	round_over = false
	tickets = [START_TICKETS, START_TICKETS]
	capture = 0.0
	server_projectiles.clear()
	mortar_impacts.clear()
	for pid in players:
		var p: Dictionary = players[pid]
		p.kills = 0
		p.deaths = 0
		if p.mode == 1:
			_end_drone(pid, false)
		_return_carried(pid)
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
		shop.hide()
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
	for pr in projectiles:
		if is_instance_valid(pr.node):
			pr.node.queue_free()
	projectiles.clear()
	players.clear()
	if soldier:
		soldier.die()
		soldier.queue_free()
		soldier = null
	alive_local = false


func send_state(pos: Vector3, yaw: float, pitch: float, mode: int, dpos: Vector3, dyaw: float) -> void:
	if connected:
		rpc_id(1, "srv_state", pos, yaw, pitch, mode, dpos, dyaw)


func send_slot(slot: int) -> void:
	if connected:
		rpc_id(1, "srv_slot", slot)


func local_fire(origin: Vector3, dir: Vector3, muzzle: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_fire", origin, dir)
	_tracer(muzzle, origin + dir * 150.0)
	var heavy: bool = soldier != null and (soldier.eq.w == "pkm" or soldier.eq.w == "svd")
	Sfx.play(self, "shot_heavy" if heavy else "shot", null, -4.0, randf_range(0.95, 1.05))


func local_rpg(origin: Vector3, dir: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_rpg", origin, dir)
	Sfx.play(self, "shot_heavy", null, 0.0, 0.6)


func local_mortar(target: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_mortar", target)
	Sfx.play(self, "shot_heavy", null, 0.0, 0.45)


func request_reload() -> void:
	if connected:
		rpc_id(1, "srv_reload")


func request_drone() -> void:
	if not connected or not alive_local:
		return
	if soldier and soldier.drones <= 0:
		show_hint("Немає дронів з собою. Купіть FPV-дрони і рюкзак у магазині.")
		return
	rpc_id(1, "srv_drone_start")


func local_drone_boom(pos: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_drone_boom", pos)
	if soldier:
		soldier.end_drone()


func drone_seconds_left() -> float:
	return drone_time


func enemy_near(pos: Vector3, r: float) -> bool:
	for id in avatars:
		if not players.has(id) or players[id].team == my_team:
			continue
		var a: Node3D = avatars[id]
		if a.visible and (a.position + Vector3(0.0, 1.0, 0.0)).distance_to(pos) < r:
			return true
	return false


func buy(cat: String, key: String, qty: int = 1) -> void:
	if connected:
		rpc_id(1, "srv_buy", cat, key, qty)


func bot_shop_test() -> void:
	# автотест магазину: купити АК-74, рюкзак, дрони, броню
	buy("p", "s")
	buy("fpv", "", 1)
	buy("mag", "aks74u", 2)
	buy("h", "h1")
	print("[BOT] shop test sent")


func show_hint(t: String) -> void:
	_show_center(t, 2.5)
	if is_bot:
		print("[BOT] hint: " + t)


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
	_show_center("Ваша команда: %s. Спорядження — кнопка МАГАЗИН" % TEAM_NAMES[team], 4.0)
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
func cl_gear(id: int, eq: Dictionary, slot: int) -> void:
	if avatars.has(id):
		avatars[id].set_gear(eq, slot)


@rpc("authority", "call_remote", "reliable")
func cl_loadout(prof: Dictionary, in_mag: int, mags: int, drones: int, heavy: int) -> void:
	profile = prof
	if soldier:
		soldier.apply_loadout(prof.eq, in_mag, mags, drones, heavy)
	if shop and shop.visible:
		_refresh_shop()
	if is_bot:
		print("[BOT] loadout: %s, mags %d, drones %d, money %d" % [str(prof.eq), mags, drones, int(prof.money)])


@rpc("authority", "call_remote", "reliable")
func cl_money(money: int, delta_money: int, reason: String) -> void:
	if profile.has("money"):
		profile.money = money
	if delta_money > 0:
		_add_feed("+$%d  %s" % [delta_money, reason])
	if shop and shop.visible:
		_refresh_shop()


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
		var b := i * SNAP_FIELDS
		if b + SNAP_FIELDS - 1 >= data.size():
			break
		if avatars.has(id):
			var a = avatars[id]
			a.target_pos = Vector3(data[b], data[b + 1], data[b + 2])
			a.target_yaw = data[b + 3]
			a.visible = true
		var mode := int(data[b + 5])
		if avatars.has(id):
			avatars[id].model.set_pose((mode & 2) != 0, (mode & 4) != 0)
			avatars[id].model.look_pitch = data[b + 4]
		if (mode & 1) == 1:
			var dpos := Vector3(data[b + 6], data[b + 7], data[b + 8])
			if not remote_drones.has(id) and players.has(id):
				var d := make_drone(players[id].team)
				world.add_child(d)
				d.global_position = dpos
				remote_drones[id] = d
				if DisplayServer.get_name() != "headless":
					var snd := AudioStreamPlayer3D.new()
					snd.stream = Sfx.get_sound("drone")
					snd.unit_size = 6.0
					snd.max_distance = 120.0
					snd.volume_db = -4.0
					d.add_child(snd)
					snd.play()
			drone_targets[id] = [dpos, data[b + 9]]
		elif remote_drones.has(id):
			_remove_remote_drone(id)


@rpc("authority", "call_remote", "unreliable")
func cl_tracer(id: int, a: Vector3, b: Vector3, weapon: String) -> void:
	if id != my_id:
		_tracer(a + (b - a).normalized() * 0.8, b)
		var heavy := weapon == "pkm" or weapon == "svd"
		Sfx.play(world, "shot_heavy" if heavy else "shot", a, 0.0, randf_range(0.95, 1.05))


@rpc("authority", "call_remote", "reliable")
func cl_rocket(id: int, pos: Vector3, vel: Vector3) -> void:
	if world == null:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.06
	cm.height = 0.45
	mi.mesh = cm
	mi.material_override = rocket_mat
	world.add_child(mi)
	mi.global_position = pos
	projectiles.append({"node": mi, "vel": vel, "t": 0.0})
	if id != my_id:
		Sfx.play(world, "shot_heavy", pos, 2.0, 0.6)


@rpc("authority", "call_remote", "reliable")
func cl_mortar_fire(id: int, from: Vector3, impact: Vector3, flight: float) -> void:
	if id != my_id:
		Sfx.play(world, "shot_heavy", from, 4.0, 0.45)
	if id == my_id:
		_show_center("Міна в польоті: %.1f с" % flight, flight)


@rpc("authority", "call_remote", "reliable")
func cl_hp(hp: int) -> void:
	my_hp = hp
	_show_center("Вас поранено!", 0.6)


@rpc("authority", "call_remote", "reliable")
func cl_hitmark() -> void:
	_show_center("✕ влучання", 0.4)
	Sfx.play(self, "hit", null, -6.0)


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
		_show_center("Вас знищено. Спорядження втрачено. Відродження через %d с" % int(RESPAWN_TIME), RESPAWN_TIME)
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
		drone_time = DRONE_LIFETIME
		_show_center("Дрон у повітрі. Джойстик — рух, ВГОРУ/ВНИЗ — висота", 3.0)
		if is_bot:
			print("[BOT] drone launched")


@rpc("authority", "call_remote", "reliable")
func cl_drone_end(id: int, destroyed: bool, pos: Vector3) -> void:
	if id == my_id:
		drone_time = 0.0
		if soldier:
			soldier.end_drone()
		if destroyed:
			_show_center("Дрон втрачено", 1.5)
	else:
		_remove_remote_drone(id)


@rpc("authority", "call_remote", "reliable")
func cl_boom(pos: Vector3, radius: float) -> void:
	_boom_fx(pos, radius)
	Sfx.play(world, "boom", pos, 6.0 if radius > 8.0 else 3.0, randf_range(0.9, 1.1))
	# прибрати ракету, що вибухнула
	var keep: Array = []
	for pr in projectiles:
		if is_instance_valid(pr.node) and pr.node.global_position.distance_to(pos) < 12.0:
			pr.node.queue_free()
		else:
			keep.append(pr)
	projectiles = keep
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
	_show_center("Новий раунд! В бій!", 2.0)


@rpc("authority", "call_remote", "reliable")
func cl_msg(text: String) -> void:
	_show_center(text, 2.5)
	if text.begins_with("Куплено") or text.begins_with("Обрано"):
		Sfx.play(self, "buy", null, -4.0)
	if is_bot:
		print("[BOT] msg: %s" % text)


func _remove_remote_drone(id: int) -> void:
	if remote_drones.has(id):
		remote_drones[id].queue_free()
		remote_drones.erase(id)
	drone_targets.erase(id)


# =====================================================================
#   КЛІЄНТ: світ, ефекти
# =====================================================================

func _build_client_world() -> void:
	world = World.build(self, true)
	tracer_mat = StandardMaterial3D.new()
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_mat.albedo_color = Color(1.0, 0.85, 0.45)
	boom_mat = StandardMaterial3D.new()
	boom_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boom_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	boom_mat.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
	smoke_mat = StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = Color(0.25, 0.23, 0.2, 0.55)
	rocket_mat = StandardMaterial3D.new()
	rocket_mat.albedo_color = Color(0.3, 0.33, 0.24)
	var ring := world.get_node_or_null("CapRing")
	if ring:
		cap_ring_mat = ring.material_override


func make_drone(team: int) -> Node3D:
	var d := Node3D.new()
	var body_root := Node3D.new()
	d.add_child(body_root)
	var light_m := StandardMaterial3D.new()
	light_m.albedo_color = TEAM_COLORS[team]
	light_m.emission_enabled = true
	light_m.emission = TEAM_COLORS[team]
	# 3D-модель FPV-дрона з бойовою частиною
	if _fpv_scene == null:
		_fpv_scene = load("res://models/fpv.glb")
	var fpv: Node3D = _fpv_scene.instantiate()
	body_root.add_child(fpv)
	# розмиті диски пропелерів, що обертаються
	for x in [-0.147, 0.147]:
		for z in [-0.187, 0.187]:
			var prop := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.075
			cm.bottom_radius = 0.075
			cm.height = 0.004
			cm.radial_segments = 14
			prop.mesh = cm
			prop.material_override = smoke_mat
			prop.position = Vector3(x, 0.02, z)
			prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			body_root.add_child(prop)
	var led := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.018
	lm.height = 0.036
	led.mesh = lm
	led.material_override = light_m
	led.position = Vector3(0.0, 0.045, 0.06)
	body_root.add_child(led)
	return d


func _tracer(a: Vector3, b: Vector3) -> void:
	if world == null or tracer_mat == null:
		return
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, minf(length, 60.0))
	mi.mesh = bm
	mi.material_override = tracer_mat
	world.add_child(mi)
	var dir := (b - a).normalized()
	mi.global_position = a + dir * minf(length, 60.0) * 0.5
	if absf(dir.dot(Vector3.UP)) < 0.98:
		mi.look_at(mi.global_position + dir, Vector3.UP)
	get_tree().create_timer(0.05).timeout.connect(mi.queue_free)


func _boom_fx(pos: Vector3, radius: float) -> void:
	if world == null or boom_mat == null:
		return
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var fire := MeshInstance3D.new()
	fire.mesh = sm
	fire.material_override = boom_mat
	world.add_child(fire)
	fire.global_position = pos
	fire.scale = Vector3.ONE * 0.3
	var tw := fire.create_tween()
	tw.tween_property(fire, "scale", Vector3.ONE * radius * 0.5, 0.25)
	tw.tween_callback(fire.queue_free)
	var smoke := MeshInstance3D.new()
	smoke.mesh = sm
	smoke.material_override = smoke_mat
	world.add_child(smoke)
	smoke.global_position = pos + Vector3(0.0, 0.5, 0.0)
	smoke.scale = Vector3.ONE * radius * 0.3
	var tw2 := smoke.create_tween()
	tw2.tween_property(smoke, "scale", Vector3.ONE * radius * 0.7, 2.5)
	tw2.parallel().tween_property(smoke, "position", smoke.position + Vector3(0.0, 4.0, 0.0), 2.5)
	tw2.tween_callback(smoke.queue_free)


func _process(delta: float) -> void:
	if is_server:
		return
	if drone_time > 0.0:
		drone_time = maxf(0.0, drone_time - delta)
	for id in drone_targets:
		if remote_drones.has(id):
			var d: Node3D = remote_drones[id]
			var t: Array = drone_targets[id]
			d.global_position = d.global_position.lerp(t[0], clampf(delta * 10.0, 0.0, 1.0))
			d.rotation.y = t[1]
	if not projectiles.is_empty():
		var keep: Array = []
		for pr in projectiles:
			if not is_instance_valid(pr.node):
				continue
			pr.t += delta
			var vel: Vector3 = pr.vel
			vel.y -= 2.0 * delta
			pr.vel = vel
			pr.node.global_position += vel * delta
			if vel.length() > 0.1 and absf(vel.normalized().dot(Vector3.UP)) < 0.98:
				pr.node.look_at(pr.node.global_position + vel, Vector3.UP)
				pr.node.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
			if pr.t > 5.5:
				pr.node.queue_free()
			else:
				keep.append(pr)
		projectiles = keep
	if cap_ring_mat:
		var c := Color(1, 1, 1, 0.25)
		if capture <= -100.0:
			c = Color(TEAM_COLORS[0].r, TEAM_COLORS[0].g, TEAM_COLORS[0].b, 0.35)
		elif capture >= 100.0:
			c = Color(TEAM_COLORS[1].r, TEAM_COLORS[1].g, TEAM_COLORS[1].b, 0.35)
		cap_ring_mat.albedo_color = c
	if touch and touch.shop_pressed:
		touch.shop_pressed = false
		_open_shop()
	if touch and touch.bag_pressed:
		touch.bag_pressed = false
		if bag:
			bag.show()
			touch.hide()
			touch.reset_input()
	if touch and touch.map_pressed:
		touch.map_pressed = false
		if bigmap:
			bigmap.show()
			touch.hide()
			touch.reset_input()
	if hud == null or not hud.visible:
		return
	_update_hud(delta)


# =====================================================================
#   ІНТЕРФЕЙС
# =====================================================================

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
	if profile.has("money"):
		money_lbl.text = "$ %d" % int(profile.money)
	if soldier and alive_local:
		if soldier.drone_active:
			ammo_lbl.text = "FPV • швидкість %d • висота %d м • батарея %d с" % [soldier.drone_speed_mode + 1, int(soldier.drone_node.global_position.y) if soldier.drone_node else 0, int(drone_time)]
		elif soldier.slot == 0:
			if soldier.reloading > 0.0:
				ammo_lbl.text = "ПЕРЕЗАРЯДКА..."
			else:
				ammo_lbl.text = "%s  %d / %d×%d" % [soldier.wdata.name, soldier.in_mag, soldier.mags, int(soldier.wdata.mag)]
		elif soldier.slot == 1:
			var h: Dictionary = Gear.HEAVY[soldier.eq.x]
			var t := "%s • боєприпаси: %d" % [h.name, soldier.heavy_ammo]
			if soldier.eq.x == "mortar":
				var dist := Vector2(soldier.mortar_target.x - soldier.global_position.x, soldier.mortar_target.z - soldier.global_position.z).length()
				t += " • дистанція %d м%s" % [int(dist), "" if soldier.mortar_valid else " (поза межами)"]
			ammo_lbl.text = t
		else:
			ammo_lbl.text = "Зброю сховано"
		if touch:
			var bd := {"drone": soldier.drones, "reload": soldier.mags}
			if soldier.slot == 1:
				bd["slot"] = soldier.heavy_ammo
			touch.badges = bd
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
	money_lbl = _label(hud, 26, HORIZONTAL_ALIGNMENT_LEFT)
	money_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	_place(money_lbl, Vector4(0, 0, 0, 0), Vector4(24, 60, 300, 96))
	feed_lbl = _label(hud, 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(feed_lbl, Vector4(1, 0, 1, 0), Vector4(-430, 240, -20, 400))
	ammo_lbl = _label(hud, 26, HORIZONTAL_ALIGNMENT_CENTER)
	_place(ammo_lbl, Vector4(0.5, 1, 0.5, 1), Vector4(-360, -64, 360, -20))
	center_lbl = _label(hud, 28, HORIZONTAL_ALIGNMENT_CENTER)
	center_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(center_lbl, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-460, -190, 460, -110))
	var cross := _label(hud, 34, HORIZONTAL_ALIGNMENT_CENTER)
	cross.text = "+"
	_place(cross, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-20, -26, 20, 22))
	hud.hide()

	minimap = HudMap.new()
	hud.add_child(minimap)
	minimap.setup(self, false)

	# ---------------- сенсорне керування
	touch = TouchUI.new()
	ui.add_child(touch)
	touch.hide()

	bigmap = HudMap.new()
	ui.add_child(bigmap)
	bigmap.setup(self, true)
	bigmap.hide()
	bag = Inventory.new()
	ui.add_child(bag)
	bag.setup(self)
	bag.hide()

	_build_shop()

	# ---------------- меню
	menu = ColorRect.new()
	menu.color = Color(0.05, 0.06, 0.08, 0.94)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	menu.add_child(box)
	_place(box, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-300, -280, 300, 280))

	var title := Label.new()
	title.text = "UA WAR FRONT"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Бій 20 на 20 • окопи • FPV-дрони • РПГ і міномети"
	sub.add_theme_font_size_override("font_size", 21)
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
	help.text = "Ліва частина екрана — рух, права — огляд. ЗБРОЯ — автомат / РПГ або міномет / сховати.\nГроші — за ліквідації, збиті дрони, утримання точки і перемогу. Витрачайте їх у МАГАЗИНІ.\nВсе, що береш у бій, важить: що важче спорядження, то повільніше рухаєшся."
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.76))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
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
		_set_status("Неправильна адреса. Приклад: 147.185.221.217:11983")
		return
	var cfg := ConfigFile.new()
	cfg.set_value("main", "nick", nick)
	cfg.set_value("main", "addr", addr)
	cfg.save("user://settings.cfg")
	connect_to(host, port, nick)


# ---------------------------------------------------------------- магазин

func _build_shop() -> void:
	shop = ColorRect.new()
	shop.color = Color(0.06, 0.07, 0.06, 0.96)
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(shop)
	shop.hide()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	shop.add_child(root)
	_place(root, Vector4(0, 0, 1, 1), Vector4(24, 16, -24, -16))

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "СКЛАД І МАГАЗИН СПОРЯДЖЕННЯ"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.15))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	shop_money = Label.new()
	shop_money.add_theme_font_size_override("font_size", 28)
	shop_money.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	top.add_child(shop_money)
	var close := Button.new()
	close.text = "  ✕ ЗАКРИТИ  "
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(_close_shop)
	top.add_child(close)

	var cats := HBoxContainer.new()
	cats.add_theme_constant_override("separation", 6)
	root.add_child(cats)
	for c in [["w", "Зброя"], ["x", "Важка зброя"], ["a", "Броня"], ["h", "Шоломи"], ["r", "Розгрузки"], ["p", "Рюкзаки"], ["c", "Дрони і набої"]]:
		var b := Button.new()
		b.text = c[1]
		b.add_theme_font_size_override("font_size", 20)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = c[0]
		b.pressed.connect(_set_cat.bind(key))
		cats.add_child(b)

	shop_info = Label.new()
	shop_info.add_theme_font_size_override("font_size", 18)
	shop_info.add_theme_color_override("font_color", Color(0.75, 0.78, 0.8))
	shop_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(shop_info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	shop_list = VBoxContainer.new()
	shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_list.add_theme_constant_override("separation", 6)
	scroll.add_child(shop_list)


func on_map_closed() -> void:
	if hud.visible:
		touch.show()


func on_bag_closed() -> void:
	if hud.visible:
		touch.show()


func _set_cat(key: String) -> void:
	shop_cat = key
	_refresh_shop()


func team_color(t: int) -> Color:
	return TEAM_COLORS[t]


func _open_shop() -> void:
	if shop == null:
		return
	shop.show()
	touch.hide()
	touch.reset_input()
	_refresh_shop()


func _close_shop() -> void:
	shop.hide()
	if hud.visible:
		touch.show()


func _shop_row(text: String, btns: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var bg := PanelContainer.new()
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	bg.add_child(l)
	row.add_child(bg)
	for b in btns:
		var btn := Button.new()
		btn.text = "  %s  " % b[0]
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(150, 56)
		var has_cb := typeof(b[1]) == TYPE_CALLABLE
		btn.disabled = not has_cb
		if has_cb:
			btn.pressed.connect(b[1])
		row.add_child(btn)
	shop_list.add_child(row)


func _refresh_shop() -> void:
	if shop_list == null:
		return
	for c in shop_list.get_children():
		c.queue_free()
	if not profile.has("money"):
		shop_info.text = "Зайдіть у бій, щоб відкрити склад."
		return
	shop_money.text = "$ %d   " % int(profile.money)
	var eq: Dictionary = profile.eq
	var w := Gear.weight(eq, Gear.mag_capacity(eq), Gear.drone_slots(eq), Gear.heavy_slots(eq) if eq.x != "none" else 0)
	shop_info.text = "Вага повного спорядження: %.1f кг • швидкість %d%% • з собою: магазинів %d, дронів %d, важких боєприпасів %d.\nКупівлі зберігаються. На базі зміни діють одразу, в бою — після відродження." % [w, int(Gear.speed_mult(w) * 100.0), Gear.mag_capacity(eq), Gear.drone_slots(eq), Gear.heavy_slots(eq) if eq.x != "none" else 0]
	if shop_cat == "c":
		_shop_row("FPV-дрон-камікадзе. На складі: %d. Береш з собою до %d (залежить від рюкзака). Вага 1,5 кг." % [int(profile.fpv), Gear.drone_slots(eq)],
			[["+1  $%d" % Gear.FPV_PRICE, func(): buy("fpv", "", 1)], ["+5  $%d" % (Gear.FPV_PRICE * 5), func(): buy("fpv", "", 5)]])
		for wk in Gear.WEAPON_ORDER:
			if not profile.owned.has("w:" + wk):
				continue
			var wd: Dictionary = Gear.WEAPONS[wk]
			var mp := int(wd.mag_price)
			_shop_row("Магазини для %s (%d набоїв). На складі: %d." % [wd.name, int(wd.mag), int(profile.mags.get(wk, 0))],
				[["+1  $%d" % mp, func(): buy("mag", wk, 1)], ["+5  $%d" % (mp * 5), func(): buy("mag", wk, 5)]])
		for hk in ["rpg", "mortar"]:
			if not profile.owned.has("x:" + hk):
				continue
			var hd: Dictionary = Gear.HEAVY[hk]
			var ap := int(hd.ammo_price)
			_shop_row("%s для %s. На складі: %d. Вага %.1f кг." % [hd.ammo_name, hd.name, int(profile.heavy_ammo.get(hk, 0)), float(hd.ammo_weight)],
				[["+1  $%d" % ap, func(): buy("hammo", hk, 1)], ["+3  $%d" % (ap * 3), func(): buy("hammo", hk, 3)]])
		return
	var order: Array = []
	match shop_cat:
		"w": order = Gear.WEAPON_ORDER
		"a": order = Gear.ARMOR_ORDER
		"h": order = Gear.HELMET_ORDER
		"r": order = Gear.RIG_ORDER
		"p": order = Gear.PACK_ORDER
		"x": order = Gear.HEAVY_ORDER
	var cat_data := Gear.catalog(shop_cat)
	for k in order:
		var d: Dictionary = cat_data[k]
		var desc := String(d.name)
		match shop_cat:
			"w": desc += " — шкода %d, темп %d/хв, магазин %d, перезарядка %.1f с, вага %.1f кг" % [int(d.dmg), int(60.0 / float(d.rof)), int(d.mag), float(d.reload), float(d.weight)]
			"a": desc += " — зменшує шкоду в корпус на %d%%, вага %.0f кг" % [int(float(d.reduce) * 100.0), float(d.weight)]
			"h": desc += " — зменшує шкоду в голову на %d%%, вага %.1f кг" % [int(float(d.reduce) * 100.0), float(d.weight)]
			"r": desc += " — магазинів з собою: %d" % int(d.mags)
			"p": desc += " — дронів: %d, +%d магазини, важких боєприпасів: %d" % [int(d.drones), int(d.mags), int(d.heavy)]
			"x":
				if k == "rpg":
					desc += " — протитанковий гранатомет, вибух %d м, вага %.1f кг" % [int(d.radius), float(d.weight)]
				elif k == "mortar":
					desc += " — вогонь з закритих позицій на %d–%d м, вибух %d м, вага %.0f кг" % [int(d.min_range), int(d.max_range), int(d.radius), float(d.weight)]
		var tag := "%s:%s" % [shop_cat, k]
		var cat := shop_cat
		if eq.get(shop_cat, "") == k:
			_shop_row(desc, [["✓ Обрано", null]])
		elif profile.owned.has(tag):
			_shop_row(desc, [["Взяти", func(): buy(cat, k, 1)]])
		else:
			_shop_row(desc, [["Купити $%d" % int(d.price), func(): buy(cat, k, 1)]])


func _unhandled_input(event: InputEvent) -> void:
	if is_server or OS.has_feature("mobile"):
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_B and hud and hud.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_open_shop()
	elif event is InputEventMouseButton and event.pressed and hud and hud.visible and not shop.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
