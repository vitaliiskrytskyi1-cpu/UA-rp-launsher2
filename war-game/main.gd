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
const HitHud = preload("res://hithud.gd")
const TopHud = preload("res://tophud.gd")
const Menu = preload("res://menu.gd")
const HudEdit = preload("res://hudedit.gd")
const SettingsPanel = preload("res://settings_panel.gd")
const Settings = preload("res://settings.gd")
const UI = preload("res://uikit.gd")
const Vehicle = preload("res://vehicle.gd")
const Front = preload("res://front.gd")
const VEH_HP := 600.0
const VEH_RESPAWN := 30.0
const RECON_LIFETIME := 180.0
const BOT_NAMES := ["Сокіл", "Грім", "Вовк", "Тайфун", "Шершень", "Беркут", "Барс", "Скіф", "Яструб", "Сич", "Рись", "Буревій", "Кремінь", "Лис", "Граніт", "Ворон"]
static var _fpv_scene: PackedScene

const VERSION := 8
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
const TEAM_NAMES := ["Штурм", "Оборона"]
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
## Стан матчу на сервері: "waiting" — збір у лобі з відліком, "running" — бій, "ended" — підсумки раунду.
var match_state := "waiting"
var match_count := 0.0
var cfg_countdown := 20.0
var lobby_t := 0.0
## Клієнт: останні дані лобі і моя роль
var lobby := {}
var my_role := ""
var in_match := false
var map_index := 0
var map_pref := 0
var vehicles := {}          # сервер: машини
var vnodes := {}            # клієнт: моделі машин
var bot_fill := 8           # сервер: ботів до N бійців у кожній команді
var bot_seq := 0
var spotted := {}           # клієнт: id -> час, поки ворога видно на карті
var waypoint := Vector3.ZERO
var waypoint_t := 0.0

# сервер
var snap_t := 0.0
var recon_t := 0.0
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
var status_lbl: Label
var settings_panel: Control
var hud_editor: Control
var auto_pick := false
var retry_t := 0.0
var music: AudioStreamPlayer
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
var hithud: Control
var tophud: Control
var heal_left := 0.0
## Пошкодження по зонах тіла (для рюкзака і HUD): 0 голова … 6 права нога, 7 вибух.
var zone_dmg := [0, 0, 0, 0, 0, 0, 0, 0]
var zone_flash := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var armor_dur := 100
var helm_dur := 100
const ZONE_NAMES := ["голова", "груди", "живіт", "ліва рука", "права рука", "ліва нога", "права нога", "вибух"]
static var _gren_scene: PackedScene
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
		elif a.begins_with("--countdown="):
			cfg_countdown = float(a.substr(12))
		elif a.begins_with("--host="):
			host = a.substr(7)
		elif a.begins_with("--map="):
			map_pref = int(a.substr(6))
		elif a.begins_with("--bots="):
			bot_fill = int(a.substr(7))
	if args.has("--server"):
		start_server()
	elif args.has("--bot"):
		is_bot = true
		auto_pick = true
		_build_client_world()
		connect_to(host, cfg_port, "Bot_%d" % (randi() % 1000))
	elif args.has("--autojoin"):
		# перевірка інтерфейсу: вхід без меню і знімок екрана
		auto_pick = true
		_build_client_world()
		_build_ui()
		connect_to(host, cfg_port, "Tester")
		for a2 in args:
			if a2.begins_with("--shot="):
				var path := a2.substr(7)
				get_tree().create_timer(18.0).timeout.connect(func():
					get_viewport().get_texture().get_image().save_png(path)
					get_tree().quit())
	else:
		for a3 in args:
			if a3.begins_with("--nick="):
				Settings.set_value("main", "nick", a3.substr(7))
			elif a3.begins_with("--addr="):
				Settings.set_value("main", "addr", a3.substr(7))
		_build_client_world()
		_build_ui()
		if menu.has_nick():
			menu_connect(true)
		# перевірка меню: --menu=<екран> --shot=<файл>
		for a2 in args:
			if a2.begins_with("--menu="):
				var scr := a2.substr(7)
				get_tree().create_timer(4.0).timeout.connect(func():
					if scr == "hudedit":
						hud.show()
						open_hud_editor()
					elif scr == "settings":
						open_settings(false)
					else:
						if scr in ["team", "role", "wait"] and connected:
							request_enter(menu.sel_map)
						if scr == "role":
							menu.sel_team = 0
							menu.sel_role = "fpv"
						menu.go(scr))
			elif a2.begins_with("--shot="):
				var path2 := a2.substr(7)
				get_tree().create_timer(14.0).timeout.connect(func():
					get_viewport().get_texture().get_image().save_png(path2)
					get_tree().quit())
	if not is_server:
		get_tree().set_quit_on_go_back(false)
		Settings.apply(get_tree())
		if not is_bot:
			_start_music()


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
	if not players.has(id) or players[id].ai:
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
	_spawn_vehicles()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("[SERVER] UA War Front v%d started on UDP port %d" % [VERSION, cfg_port])


func _on_peer_connected(id: int) -> void:
	print("[SERVER] peer connected: %d" % id)


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		print("[SERVER] player left: %s" % players[id].nick)
		_veh_leave(id)
		_return_carried(id)
		_save_profile(id)
		players.erase(id)
		rpc("cl_remove_player", id)
		_fill_bots()
		_lobby_broadcast()


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
		"in_match": false, "role": "", "confirmed": false, "eq": prof.eq.duplicate(), "free": {},
		"flags": 0, "veh": -1, "seat": -1, "ai": false, "drone_kind": "", "aim": false, "gren": 0, "armor_dur": 100.0, "helm_dur": 100.0, "last_gren": 0, "med": 0, "heal_t": 0.0,
	}


# Видача спорядження зі складу гравця при відродженні.
func _equip(id: int) -> void:
	var p: Dictionary = players[id]
	var prof: Dictionary = p.prof
	# спорядження на це життя: власне + набір ролі
	var eq: Dictionary = prof.eq.duplicate()
	var role: Dictionary = Gear.ROLES.get(String(p.role), Gear.ROLES["rifle"])
	for k in role.kit:
		eq[k] = role.kit[k]
	p.eq = eq
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
	var mt := mini(int(prof.get("med", 0)), Gear.medkit_slots(eq))
	prof.med = int(prof.get("med", 0)) - mt
	p.med = mt
	p.heal_t = 0.0
	var gt := mini(int(prof.get("gren", 0)), Gear.grenade_slots(eq))
	prof.gren = int(prof.get("gren", 0)) - gt
	p.gren = gt
	# безкоштовні речі ролі (не беруться зі складу і не повертаються на склад)
	var fr: Dictionary = role.free
	p.free = fr.duplicate()
	p.mags = int(p.mags) + int(fr.get("mags", 0))
	p.drones = int(p.drones) + int(fr.get("drones", 0))
	p.heavy = int(p.heavy) + int(fr.get("heavy", 0))
	p.gren = int(p.gren) + int(fr.get("gren", 0))
	p.med = int(p.med) + int(fr.get("med", 0))
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
	var eq: Dictionary = p.eq
	var fr: Dictionary = p.get("free", {})
	p.mags = maxi(0, int(p.mags) - int(fr.get("mags", 0)))
	p.drones = maxi(0, int(p.drones) - int(fr.get("drones", 0)))
	p.heavy = maxi(0, int(p.heavy) - int(fr.get("heavy", 0)))
	p.gren = maxi(0, int(p.gren) - int(fr.get("gren", 0)))
	p.med = maxi(0, int(p.med) - int(fr.get("med", 0)))
	p.free = {}
	var back := int(p.mags) + (1 if int(p.in_mag) > 0 else 0)
	prof.mags[eq.w] = int(prof.mags.get(eq.w, 0)) + back
	prof.fpv = int(prof.fpv) + int(p.drones)
	if eq.x != "none":
		prof.heavy_ammo[eq.x] = int(prof.heavy_ammo.get(eq.x, 0)) + int(p.heavy)
	prof.gren = int(prof.get("gren", 0)) + int(p.gren)
	prof.med = int(prof.get("med", 0)) + int(p.med)
	p.med = 0
	p.mags = 0
	p.in_mag = 0
	p.drones = 0
	p.heavy = 0
	p.gren = 0


func _send_loadout(id: int) -> void:
	var p: Dictionary = players[id]
	if id > 0: rpc_id(id, "cl_loadout", p.prof, p.eq, p.in_mag, p.mags, p.drones, p.heavy, p.gren, int(p.armor_dur), int(p.helm_dur), int(p.med))


func _server_spawn(id: int) -> void:
	var p: Dictionary = players[id]
	p.hp = 100
	p.alive = true
	p.mode = 0
	p.flags = 0
	p.armor_dur = 100.0
	p.helm_dur = 100.0
	p.pos = spawn_point(p.team)
	p.yaw = PI if p.team == 0 else 0.0
	p.veh = -1
	p.seat = -1
	if p.ai:
		p.body.global_position = p.pos
		p.body.velocity = Vector3.ZERO
		p.ai_last = p.pos
		p.ai_goal = Vector3.ZERO
	rpc("cl_spawn", id, p.pos, p.yaw)
	_equip(id)


func _in_base(p: Dictionary) -> bool:
	var bp := World.base_pos(p.team)
	return Vector2(p.pos.x - bp.x, p.pos.z - bp.y).length() < float(World.cur.base_r)


## Точка відродження на базі команди (висота — по землі карти).
func spawn_point(team: int) -> Vector3:
	var bpos := World.base_pos(team)
	var bz := bpos.y
	var spread := minf(25.0, float(World.cur.base_r) * 0.8)
	var x := bpos.x + randf_range(-spread, spread)
	var z := bz + randf_range(-spread * 0.25, spread * 0.25)
	if World.cur.has("file"):
		var bx := bpos.x
		for attempt in 40:
			var r := spread * (1.0 + attempt * 0.08)
			var tx := bx + randf_range(-r, r)
			var tz := bz + randf_range(-r * 0.4, r * 0.4)
			var y := World.ground_y(world, tx, tz, -9999.0)
			if y > -9000.0:
				return Vector3(tx, y + 0.6, tz)
		return Vector3(0.0, World.ground_y(world, 0.0, 0.0, 30.0) + 1.0, 0.0)
	return Vector3(x, 1.2, z)


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
	if id > 0: rpc_id(id, "cl_money", int(p.prof.money), amount, reason)


@rpc("any_peer", "call_remote", "reliable")
func srv_hello(nick: String, ver: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if ver != VERSION:
		if id > 0: rpc_id(id, "cl_msg", "Версія гри застаріла. Скачайте нову версію.")
		return
	if players.has(id):
		return
	nick = nick.strip_edges().substr(0, 16)
	if nick == "":
		nick = "Боєць_%d" % (id % 1000)
	for pid in players:
		if String(players[pid].nick).to_lower() == nick.to_lower():
			if id > 0: rpc_id(id, "cl_msg", "Позивний «%s» вже в грі. Оберіть інший." % nick)
			return
	for pid in players:
		var e: Dictionary = players[pid]
		if id > 0: rpc_id(id, "cl_add_player", pid, e.nick, e.team, e.kills, e.deaths)
		if e.alive:
			if id > 0: rpc_id(id, "cl_gear", pid, e.eq, int(e.slot))
	players[id] = _new_pdata(nick, -1, _load_profile(nick))
	rpc("cl_add_player", id, nick, -1, 0, 0)
	if id > 0: rpc_id(id, "cl_map", map_index)
	for vid in vehicles:
		var vv: Dictionary = vehicles[vid]
		for si in vv.seats.size():
			if int(vv.seats[si]) != 0:
				rpc_id(id, "cl_veh_seat", vid, int(vv.seats[si]), si)
	if id > 0: rpc_id(id, "cl_profile", players[id].prof)
	print("[SERVER] %s connected (players: %d)" % [nick, players.size()])
	_lobby_broadcast()


## Гравець натиснув «ПОЧАТИ»: голос за карту; якщо ніхто не грає — карта змінюється.
@rpc("any_peer", "call_remote", "reliable")
func srv_enter(pref: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	pref = clampi(pref, 0, World.map_count() - 1)
	players[id].map_pref = pref
	var busy := false
	for pid in players:
		if pid != id and (players[pid].confirmed or players[pid].alive):
			busy = true
	if not busy and pref != map_index:
		_switch_map(pref)
	_lobby_broadcast()


func _role_count(team: int, role: String, except_id: int = -1) -> int:
	var n := 0
	for pid in players:
		var e: Dictionary = players[pid]
		if pid != except_id and e.confirmed and int(e.team) == team and String(e.role) == role:
			n += 1
	return n


func _team_size(team: int, except_id: int = -1) -> int:
	var n := 0
	for pid in players:
		var e: Dictionary = players[pid]
		if pid != except_id and e.confirmed and int(e.team) == team and not e.ai:
			n += 1
	return n


## Вибір команди і ролі. Сервер перевіряє вільні місця, щоб двоє не зайняли одне.
@rpc("any_peer", "call_remote", "reliable")
func srv_pick(team: int, role: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if team < 0 or team > 1 or not Gear.ROLES.has(role):
		return
	if p.alive and (int(p.team) != team or String(p.role) != role):
		if id > 0: rpc_id(id, "cl_msg", "Роль можна змінити лише до початку бою або після загибелі.")
		return
	if _team_size(team, id) >= Gear.TEAM_SIZE:
		if id > 0: rpc_id(id, "cl_pick_result", false, "Команда заповнена (%d з %d). Оберіть іншу." % [Gear.TEAM_SIZE, Gear.TEAM_SIZE])
		return
	if _role_count(team, role, id) >= int(Gear.ROLES[role].slots):
		if id > 0: rpc_id(id, "cl_pick_result", false, "Усі місця «%s» зайняті. Оберіть іншу роль." % Gear.ROLES[role].name)
		return
	var team_changed := int(p.team) != team
	p.team = team
	p.role = role
	p.confirmed = true
	p.in_match = true
	rpc("cl_player_team", id, team, role)
	if id > 0: rpc_id(id, "cl_pick_result", true, "")
	print("[SERVER] %s: команда %d, роль %s" % [p.nick, team, role])
	if match_state == "running" and not p.alive:
		if id > 0: rpc_id(id, "cl_match_start", tickets[0], tickets[1], capture)
		p.respawn = 0.5
		_fill_bots()
	elif match_state == "waiting" and match_count <= 0.0:
		match_count = cfg_countdown
	if team_changed and p.alive:
		_server_spawn(id)
	_lobby_broadcast()


## Вихід з бою в головне меню (з'єднання лишається).
@rpc("any_peer", "call_remote", "reliable")
func srv_leave_match() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.mode == 1:
		_end_drone(id, false)
	_veh_leave(id)
	_return_carried(id)
	p.alive = false
	p.in_match = false
	p.confirmed = false
	p.respawn = 0.0
	_save_profile(id)
	rpc("cl_player_left_match", id)
	_lobby_broadcast()


func _lobby_data() -> Dictionary:
	var teams := [[], []]
	for pid in players:
		var e: Dictionary = players[pid]
		if e.confirmed and int(e.team) >= 0:
			teams[int(e.team)].append([String(e.nick), String(e.role)])
	return {"state": match_state, "count": match_count, "map": map_index, "teams": teams, "t": tickets}


func _lobby_broadcast() -> void:
	rpc("cl_lobby", _lobby_data())


func _start_match() -> void:
	match_state = "running"
	round_over = false
	tickets = [START_TICKETS, START_TICKETS]
	capture = 0.0
	server_projectiles.clear()
	mortar_impacts.clear()
	print("[SERVER] match started on %s" % World.cur.name)
	for pid in players:
		var p: Dictionary = players[pid]
		p.kills = 0
		p.deaths = 0
		if p.confirmed:
			if pid > 0: rpc_id(pid, "cl_match_start", tickets[0], tickets[1], capture)
			_server_spawn(pid)
	rpc("cl_status", tickets[0], tickets[1], capture)
	_reset_vehicles()
	_fill_bots()
	_lobby_broadcast()


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
	p.flags = mode & ~1
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
	if slot < 0 or slot > 2 or (slot == 1 and p.eq.x == "none"):
		slot = 0
	p.slot = slot
	rpc("cl_gear", id, p.eq, slot)


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
	var w: Dictionary = Gear.WEAPONS[p.eq.w]
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
	p.in_mag = int(Gear.WEAPONS[p.eq.w].mag)


@rpc("any_peer", "call_remote", "reliable")
func srv_rpg(origin: Vector3, dir: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or p.eq.x != "rpg" or int(p.slot) != 1 or int(p.heavy) <= 0:
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
	if not p.alive or p.eq.x != "mortar" or int(p.slot) != 1 or int(p.heavy) <= 0:
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
func srv_heal() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or int(p.med) <= 0 or int(p.hp) >= 100 or float(p.heal_t) > 0.0:
		return
	p.heal_t = Gear.MEDKIT_TIME
	if id > 0: rpc_id(id, "cl_heal_start", Gear.MEDKIT_TIME)


func _update_heals(delta: float) -> void:
	for pid in players:
		var p: Dictionary = players[pid]
		if float(p.get("heal_t", 0.0)) <= 0.0:
			continue
		p.heal_t = float(p.heal_t) - delta
		if not p.alive:
			p.heal_t = 0.0
		elif float(p.heal_t) <= 0.0:
			p.heal_t = 0.0
			p.med = int(p.med) - 1
			p.hp = mini(100, int(p.hp) + Gear.MEDKIT_HEAL)
			if pid > 0: rpc_id(pid, "cl_healed", int(p.hp), int(p.med))


@rpc("any_peer", "call_remote", "reliable")
func srv_grenade(target: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or p.mode != 0 or int(p.gren) <= 0:
		return
	var now := Time.get_ticks_msec()
	if now - int(p.last_gren) < 1200:
		return
	p.last_gren = now
	p.gren = int(p.gren) - 1
	var flat := Vector2(target.x - p.pos.x, target.z - p.pos.z)
	if flat.length() > Gear.GRENADE_RANGE:
		flat = flat.normalized() * Gear.GRENADE_RANGE
		target = Vector3(p.pos.x + flat.x, target.y, p.pos.z + flat.y)
	var flight := 0.5 + flat.length() / 20.0
	var fuse := maxf(Gear.GRENADE_FUSE, flight + 0.6)
	var from: Vector3 = p.pos + Vector3(0.0, 1.6, 0.0)
	mortar_impacts.append({"owner": id, "team": p.team, "pos": target, "t": fuse, "kind": "gren"})
	rpc("cl_grenade", id, from, target, flight, fuse)


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
		if id > 0: rpc_id(id, "cl_msg", "Немає дронів. Купіть FPV-дрони і рюкзак у магазині.")
		return
	p.drones = int(p.drones) - 1
	p.mode = 1
	var fwd := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	p.dpos = p.pos + fwd * 1.5 + Vector3(0.0, 1.8, 0.0)
	p.dyaw = p.yaw
	p.drone_t = DRONE_LIFETIME
	if id > 0: rpc_id(id, "cl_drone_ok", p.dpos)


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
					if id > 0: rpc_id(id, "cl_msg", "Недостатньо грошей.")
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
				if id > 0: rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.fpv = int(prof.fpv) + qty
			msg = "Куплено FPV-дронів: %d" % qty
		"mag":
			if not Gear.WEAPONS.has(key):
				return
			var cost := int(Gear.WEAPONS[key].mag_price) * qty
			if int(prof.money) < cost:
				if id > 0: rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.mags[key] = int(prof.mags.get(key, 0)) + qty
			msg = "Куплено магазинів: %d" % qty
		"med":
			var cost := Gear.MEDKIT_PRICE * qty
			if int(prof.money) < cost:
				if id > 0: rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.med = int(prof.get("med", 0)) + qty
			msg = "Куплено аптечок: %d" % qty
		"gren":
			var cost := Gear.GRENADE_PRICE * qty
			if int(prof.money) < cost:
				if id > 0: rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.gren = int(prof.get("gren", 0)) + qty
			msg = "Куплено гранат: %d" % qty
		"hammo":
			if not Gear.HEAVY.has(key) or key == "none":
				return
			var cost := int(Gear.HEAVY[key].ammo_price) * qty
			if int(prof.money) < cost:
				if id > 0: rpc_id(id, "cl_msg", "Недостатньо грошей.")
				return
			_spend(prof, cost)
			prof.heavy_ammo[key] = int(prof.heavy_ammo.get(key, 0)) + qty
			msg = "Куплено: %s × %d" % [Gear.HEAVY[key].ammo_name, qty]
		_:
			return
	# поповнення на базі
	if p.alive and _in_base(p) and cat in ["fpv", "mag", "hammo", "gren", "med"]:
		_return_carried(id)
		_equip(id)
	_save_profile(id)
	_send_loadout(id)
	if id > 0: rpc_id(id, "cl_msg", msg)
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
		if not p.alive and not round_over and match_state == "running" and p.confirmed:
			p.respawn -= delta
			if p.respawn <= 0.0:
				_server_spawn(pid)

	# лобі: відлік до старту бою
	if match_state == "waiting":
		var any := false
		for pid in players:
			if players[pid].confirmed:
				any = true
		if not any:
			match_count = 0.0
		elif match_count > 0.0:
			match_count -= delta
			lobby_t -= delta
			if lobby_t <= 0.0:
				lobby_t = 1.0
				_lobby_broadcast()
			if match_count <= 0.0:
				_start_match()
	elif match_state == "running":
		var anyone := false
		for pid in players:
			if players[pid].in_match and not players[pid].ai:
				anyone = true
		if not anyone:
			match_state = "waiting"
			match_count = 0.0
			_remove_bots(true)
			_reset_vehicles()
			_lobby_broadcast()

	_update_vehicles(delta)
	_update_bots(delta)
	recon_t -= delta
	if recon_t <= 0.0:
		recon_t = 1.0
		_recon_tick()

	snap_t -= delta
	if snap_t <= 0.0:
		snap_t = SNAP_RATE
		_send_snapshot()

	tick_acc += delta
	if tick_acc >= 1.0:
		tick_acc -= 1.0
		if match_state == "running":
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
	if not p.alive or p.mode != 0 or int(p.veh) >= 0:
		return
	var w: Dictionary = Gear.WEAPONS[p.eq.w]
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
		if not e.alive or e.team == p.team or int(e.veh) >= 0:
			continue
		for part in hit_parts(e):
			var d := _ray_sphere(origin, dir, part[0], part[1])
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
	rpc("cl_tracer", id, origin, end, p.eq.w)
	if target == -1:
		return
	if target_drone:
		_end_drone(target, true)
		_give_money(id, Gear.REWARD_DRONE_SHOTDOWN, "дрон збито")
		return
	var e: Dictionary = players[target]
	var raw := float(w.dmg)
	var dmg := raw
	var head := part_hit == 0
	var a_eff := 0.35 + 0.65 * float(e.armor_dur) / 100.0
	var h_eff := 0.35 + 0.65 * float(e.helm_dur) / 100.0
	match part_hit:
		0:
			dmg *= 2.2 * (1.0 - float(Gear.HELMET[e.eq.h].reduce) * h_eff)
			if e.eq.h != "none":
				e.helm_dur = maxf(0.0, float(e.helm_dur) - raw * 0.8)
		1, 2:
			var k := 1.0 if part_hit == 1 else 0.7
			dmg *= 1.0 - float(Gear.ARMOR[e.eq.a].reduce) * a_eff * k
			if e.eq.a != "none":
				e.armor_dur = maxf(0.0, float(e.armor_dur) - raw * 0.6 * k)
		3, 4:
			dmg *= 0.7
		_:
			dmg *= 0.75
	_damage(target, id, int(round(dmg)), head, part_hit, origin)


## Сфери влучання з урахуванням розвороту, присіду, лежання і нахилу.
## Зони: 0 голова, 1 груди, 2 живіт, 3 ліва рука, 4 права рука, 5 ліва нога, 6 права нога.
const HIT_PARTS := [
	[Vector3(0.0, 1.66, 0.0), 0.14, 0], [Vector3(0.0, 1.38, 0.0), 0.21, 1], [Vector3(0.0, 1.08, 0.0), 0.19, 2],
	[Vector3(-0.27, 1.28, -0.08), 0.09, 3], [Vector3(0.27, 1.28, -0.08), 0.09, 4],
	[Vector3(-0.11, 0.75, 0.0), 0.13, 5], [Vector3(0.11, 0.75, 0.0), 0.13, 6],
	[Vector3(-0.11, 0.35, 0.0), 0.11, 5], [Vector3(0.11, 0.35, 0.0), 0.11, 6],
]


func hit_parts(e: Dictionary) -> Array:
	var out: Array = []
	var f := int(e.get("flags", 0))
	var prone := (f & 8) != 0
	var crouch := (f & 2) != 0
	var lean := (-1.0 if (f & 16) != 0 else 0.0) + (1.0 if (f & 32) != 0 else 0.0)
	var b := Basis(Vector3.UP, float(e.yaw))
	for part in HIT_PARTS:
		var lp: Vector3 = part[0]
		if prone:
			lp = Vector3(lp.x, 0.22, -(lp.y - 0.9))
		else:
			if lean != 0.0 and lp.y > 0.95:
				lp.x += lean * 0.38 * (lp.y - 0.95) / 0.7
				lp.y -= absf(lean) * 0.06
			if crouch:
				lp.y *= 0.66
		out.append([e.pos + b * lp, part[1], part[2]])
	return out


func _damage(vid: int, kid: int, dmg: int, head: bool = false, zone: int = 7, from: Vector3 = Vector3.ZERO) -> void:
	if not players.has(vid):
		return
	var v: Dictionary = players[vid]
	if not v.alive:
		return
	v.hp -= maxi(1, dmg)
	if v.hp <= 0:
		_kill(vid, kid, head)
	else:
		if vid > 0: rpc_id(vid, "cl_hp", v.hp, zone, maxi(1, dmg), from, int(v.armor_dur), int(v.helm_dur))
		if players.has(kid) and kid != vid:
			if kid > 0: rpc_id(kid, "cl_hitmark", zone)


func _kill(vid: int, kid: int, head: bool = false) -> void:
	var v: Dictionary = players[vid]
	if v.mode == 1:
		_end_drone(vid, true)
	_veh_leave(vid)
	v.alive = false
	v.hp = 0
	v.deaths += 1
	v.respawn = RESPAWN_TIME
	# все, що було з собою, втрачено
	v.mags = 0
	v.in_mag = 0
	v.drones = 0
	v.heavy = 0
	v.gren = 0
	v.med = 0
	v.heal_t = 0.0
	_save_profile(vid)
	var kname := ""
	if players.has(kid) and kid != vid:
		players[kid].kills += 1
		kname = players[kid].nick
		var reward := Gear.REWARD_KILL + (Gear.REWARD_HEADSHOT if head else 0)
		_give_money(kid, reward, "ліквідація" + (" в голову" if head else ""))
	tickets[v.team] = maxi(0, tickets[v.team] - 1)
	if is_server and (OS.get_cmdline_user_args().has("--verbose") or v.ai == false):
		print("[SERVER] %s ліквідовано (%s)" % [v.nick, kname])
	rpc("cl_killed", vid, kid, kname)
	_check_round_end()


func _process_boom(id: int, pos: Vector3) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.mode != 1 or String(p.drone_kind) == "recon":
		return
	if pos.distance_to(p.dpos) > 12.0:
		pos = p.dpos
	_end_drone(id, false)
	_explode(pos, id, p.team, 7.0, 170.0, Gear.REWARD_DRONE_KILL)


func _explode(pos: Vector3, kid: int, team: int, radius: float, maxdmg: float, reward: int = 0) -> void:
	rpc("cl_boom", pos, radius)
	for vid in vehicles.keys():
		var vv: Dictionary = vehicles[vid]
		if not vv.alive or int(vv.team) == team:
			continue
		var vd: float = (vv.pos + Vector3(0.0, 1.2, 0.0)).distance_to(pos)
		var r2 := radius + 2.6
		if vd < r2:
			_veh_damage(vid, maxdmg * (1.0 - vd / r2) * 1.15, kid)
	for pid in players.keys():
		if not players.has(pid):
			continue
		var e: Dictionary = players[pid]
		if not e.alive or e.team == team or int(e.veh) >= 0:
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
			var armor := 1.0 - float(Gear.ARMOR[e.eq.a].reduce) * 0.5 * (0.35 + 0.65 * float(e.armor_dur) / 100.0)
			var dmg := int(maxdmg * (1.0 - d / radius) * cover * armor) + 5
			if e.eq.a != "none":
				e.armor_dur = maxf(0.0, float(e.armor_dur) - dmg * 0.4)
			var was_alive: bool = e.alive
			_damage(pid, kid, dmg, false, 7, pos)
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
	_update_heals(delta)
	if mortar_impacts.is_empty():
		return
	var keep: Array = []
	for m in mortar_impacts:
		m.t -= delta
		if m.t <= 0.0:
			if m.get("kind", "") == "gren":
				_explode(m.pos + Vector3(0.0, 0.3, 0.0), m.owner, m.team, Gear.GRENADE_RADIUS, Gear.GRENADE_DMG)
			else:
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
	p.drone_kind = ""
	rpc("cl_drone_end", id, destroyed, p.dpos)


func _send_snapshot() -> void:
	var ids := PackedInt32Array()
	var data := PackedFloat32Array()
	for pid in players:
		var p: Dictionary = players[pid]
		if not p.alive:
			continue
		ids.append(pid)
		var m := int(p.mode) | (int(p.flags) & ~1) | (256 if int(p.veh) >= 0 else 0) | (512 if String(p.drone_kind) == "recon" else 0)
		var vals := [p.pos.x, p.pos.y, p.pos.z, p.yaw, p.pitch, float(m), p.dpos.x, p.dpos.y, p.dpos.z, p.dyaw, float(p.slot)]
		for v in vals:
			data.append(v)
	if ids.size() > 0:
		rpc("cl_snapshot", ids, data)
	if not vehicles.is_empty():
		var vd := PackedFloat32Array()
		for vid in vehicles:
			var v: Dictionary = vehicles[vid]
			vd.append_array([float(vid), v.pos.x, v.pos.y, v.pos.z, float(v.yaw), float(v.hp), 1.0 if v.alive else 0.0, float(v.team)])
		rpc("cl_vehicles", vd)


func _capture_tick() -> void:
	var n := [0, 0]
	var on_point: Array = []
	for pid in players:
		var p: Dictionary = players[pid]
		if p.alive and p.mode == 0 and Vector2(p.pos.x, p.pos.z).length() < float(World.cur.cap):
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
				if pid > 0: rpc_id(pid, "cl_money", int(players[pid].prof.money), 0, "")
		_check_round_end()
	rpc("cl_status", tickets[0], tickets[1], capture)


func _check_round_end() -> void:
	if round_over:
		return
	for t in 2:
		if tickets[t] <= 0:
			round_over = true
			match_state = "ended"
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


func _switch_map(idx: int) -> void:
	idx = clampi(idx, 0, World.map_count() - 1)
	map_index = idx
	if world:
		world.free()
	world = World.build(self, false, idx)
	_spawn_vehicles()
	print("[SERVER] map: %s" % World.cur.name)
	rpc("cl_map", idx)


## Наступна карта: за голосами гравців (вибір у меню), при нічиїй — випадково серед лідерів.
func _vote_map() -> int:
	var votes := {}
	for pid in players:
		var v := int(players[pid].get("map_pref", map_index))
		votes[v] = int(votes.get(v, 0)) + 1
	if votes.is_empty():
		return map_index
	var best := 0
	for v in votes.values():
		best = maxi(best, int(v))
	var top: Array = []
	for k in votes:
		if int(votes[k]) == best:
			top.append(k)
	return int(top[randi() % top.size()])


## Кінець раунду: усі повертаються в лобі і обирають команду й роль заново.
func _round_restart() -> void:
	var next := _vote_map()
	if next != map_index:
		_switch_map(next)
	round_over = false
	match_state = "waiting"
	match_count = 0.0
	tickets = [START_TICKETS, START_TICKETS]
	capture = 0.0
	server_projectiles.clear()
	mortar_impacts.clear()
	_remove_bots(true)
	for pid in players:
		var p: Dictionary = players[pid]
		if p.mode == 1:
			_end_drone(pid, false)
		_veh_leave(pid)
		_return_carried(pid)
		p.alive = false
		p.confirmed = false
		_save_profile(pid)
	_reset_vehicles()
	rpc("cl_round_lobby")
	rpc("cl_status", tickets[0], tickets[1], capture)
	_lobby_broadcast()


# =====================================================================
#   СЕРВЕР: техніка (БТР М113)
# =====================================================================

func _veh_body(pos: Vector3, yaw: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 2.3, 5.3)
	cs.shape = bs
	cs.position.y = 1.25
	b.add_child(cs)
	world.add_child(b)
	b.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return b


func _spawn_vehicles() -> void:
	vehicles.clear()
	if String(World.cur.id) != "front":
		return
	var k := 0
	for v in Front.layout.vehicles:
		var x := float(v.x)
		var z := float(v.z)
		var pos := Vector3(x, World.ground_y(world, x, z), z)
		var yaw := float(v.yaw)
		vehicles[k] = {"pos": pos, "yaw": yaw, "team": int(v.team), "seats": [0, 0, 0, 0, 0, 0], "hp": VEH_HP,
			"alive": true, "respawn": 0.0, "home": pos, "home_yaw": yaw, "body": _veh_body(pos, yaw)}
		k += 1


func _reset_vehicles() -> void:
	for vid in vehicles:
		var v: Dictionary = vehicles[vid]
		for si in v.seats.size():
			if int(v.seats[si]) != 0:
				_veh_leave(int(v.seats[si]))
		v.pos = v.home
		v.yaw = v.home_yaw
		v.hp = VEH_HP
		v.alive = true
		v.body.global_transform = Transform3D(Basis(Vector3.UP, v.yaw), v.pos)


@rpc("any_peer", "call_remote", "reliable")
func srv_veh_enter(vid: int) -> void:
	if not is_server:
		return
	_veh_enter(multiplayer.get_remote_sender_id(), vid)


func _veh_enter(id: int, vid: int) -> void:
	if not players.has(id) or not vehicles.has(vid):
		return
	var p: Dictionary = players[id]
	var v: Dictionary = vehicles[vid]
	if not p.alive or int(p.veh) >= 0 or p.mode != 0 or not v.alive:
		return
	if int(v.team) != int(p.team):
		if id > 0: rpc_id(id, "cl_msg", "Це техніка противника.")
		return
	if p.pos.distance_to(v.pos) > 7.5:
		return
	var seat := -1
	for si in v.seats.size():
		if int(v.seats[si]) == 0:
			seat = si
			break
	if seat < 0:
		if id > 0: rpc_id(id, "cl_msg", "У машині немає вільних місць.")
		return
	v.seats[seat] = id
	p.veh = vid
	p.seat = seat
	rpc("cl_veh_seat", vid, id, seat)


@rpc("any_peer", "call_remote", "reliable")
func srv_veh_exit() -> void:
	if not is_server:
		return
	_veh_leave(multiplayer.get_remote_sender_id())


func _veh_leave(id: int) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	var vid := int(p.veh)
	if vid < 0:
		return
	if vehicles.has(vid):
		var v: Dictionary = vehicles[vid]
		var si := int(p.seat)
		if si >= 0 and si < v.seats.size() and int(v.seats[si]) == id:
			v.seats[si] = 0
		# вихід збоку від машини
		var side := Basis(Vector3.UP, float(v.yaw)) * Vector3(2.9, 0.0, 0.0)
		var ep: Vector3 = v.pos + side
		ep.y = World.ground_y(world, ep.x, ep.z, v.pos.y) + 0.3
		p.pos = ep
	p.veh = -1
	p.seat = -1
	rpc("cl_veh_seat", vid, id, -1)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_veh_state(vid: int, pos: Vector3, yaw: float) -> void:
	if not is_server or not vehicles.has(vid):
		return
	var id := multiplayer.get_remote_sender_id()
	var v: Dictionary = vehicles[vid]
	if int(v.seats[0]) != id or not v.alive:
		return
	if v.pos.distance_to(pos) < 25.0:
		v.pos = pos
		v.yaw = yaw
		v.body.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)


func _veh_damage(vid: int, dmg: float, kid: int) -> void:
	var v: Dictionary = vehicles[vid]
	if not v.alive:
		return
	v.hp = float(v.hp) - dmg
	if players.has(kid) and kid > 0:
		rpc_id(kid, "cl_hitmark", 7)
	if v.hp > 0.0:
		return
	v.hp = 0.0
	v.alive = false
	v.respawn = VEH_RESPAWN
	rpc("cl_boom", v.pos + Vector3(0.0, 1.0, 0.0), 6.0)
	for si in v.seats.size():
		var pid := int(v.seats[si])
		if pid != 0 and players.has(pid):
			_veh_leave(pid)
			_kill(pid, kid)
	if players.has(kid):
		_give_money(kid, 1500, "знищено БТР")


func _update_vehicles(delta: float) -> void:
	for vid in vehicles:
		var v: Dictionary = vehicles[vid]
		if not v.alive:
			v.respawn = float(v.respawn) - delta
			if v.respawn <= 0.0:
				v.alive = true
				v.hp = VEH_HP
				v.pos = v.home
				v.yaw = v.home_yaw
				v.body.global_transform = Transform3D(Basis(Vector3.UP, v.yaw), v.pos)
		else:
			# пасажири їдуть разом з машиною
			for si in v.seats.size():
				var pid := int(v.seats[si])
				if pid != 0 and players.has(pid):
					players[pid].pos = v.pos + Vector3(0.0, 0.6, 0.0)


# =====================================================================
#   СЕРВЕР: розвідка дроном
# =====================================================================

@rpc("any_peer", "call_remote", "reliable")
func srv_recon_start() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if not p.alive or p.mode != 0 or int(p.veh) >= 0 or round_over:
		return
	if String(p.role) != "recon":
		if id > 0: rpc_id(id, "cl_msg", "Дрон-розвідник є лише в ролі «Розвідник».")
		return
	p.mode = 1
	p.drone_kind = "recon"
	var fwd := Vector3(-sin(p.yaw), 0.0, -cos(p.yaw))
	p.dpos = p.pos + fwd * 1.5 + Vector3(0.0, 1.8, 0.0)
	p.dyaw = p.yaw
	p.drone_t = RECON_LIFETIME
	if id > 0: rpc_id(id, "cl_recon_ok", p.dpos)


## Позначка розвідника: точка для штурму + вороги поряд з нею підсвічуються команді.
@rpc("any_peer", "call_remote", "reliable")
func srv_recon_mark(pos: Vector3) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.mode != 1 or String(p.drone_kind) != "recon":
		return
	var ids := PackedInt32Array()
	for pid in players:
		var e: Dictionary = players[pid]
		if e.alive and int(e.team) != int(p.team) and (e.pos as Vector3).distance_to(pos) < 30.0:
			ids.append(pid)
	for pid in players:
		if pid > 0 and int(players[pid].team) == int(p.team):
			rpc_id(pid, "cl_waypoint", pos, String(p.nick))
			if ids.size() > 0:
				rpc_id(pid, "cl_spot", ids, 20.0)


## Щосекунди: вороги в полі зору дрона-розвідника (до 55 м) видно всій команді.
func _recon_tick() -> void:
	for rid in players:
		var r: Dictionary = players[rid]
		if r.mode != 1 or String(r.drone_kind) != "recon":
			continue
		var ids := PackedInt32Array()
		for pid in players:
			var e: Dictionary = players[pid]
			if not e.alive or int(e.team) == int(r.team):
				continue
			var tp: Vector3 = e.pos + Vector3(0.0, 1.0, 0.0)
			if (r.dpos as Vector3).distance_to(tp) > 55.0:
				continue
			var q := PhysicsRayQueryParameters3D.create(r.dpos, tp)
			q.collision_mask = 1
			if world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				ids.append(pid)
		if ids.is_empty():
			continue
		for pid in players:
			if pid > 0 and int(players[pid].team) == int(r.team):
				rpc_id(pid, "cl_spot", ids, 4.0)


# =====================================================================
#   СЕРВЕР: боти (заповнюють команди до bot_fill бійців)
# =====================================================================

func _fill_bots() -> void:
	if bot_fill <= 0 or match_state != "running":
		return
	for t in 2:
		var humans := 0
		var bots: Array = []
		for pid in players:
			var e: Dictionary = players[pid]
			if int(e.team) == t and e.confirmed:
				if e.ai:
					bots.append(pid)
				else:
					humans += 1
		var want := maxi(0, bot_fill - humans)
		while bots.size() > want:
			_remove_bot(int(bots.pop_back()))
		while bots.size() < want:
			bots.append(_add_bot(t))


func _add_bot(team: int) -> int:
	bot_seq += 1
	var id := -bot_seq
	var nick := "Бот %s" % BOT_NAMES[bot_seq % BOT_NAMES.size()]
	var prof := Gear.new_profile()
	prof.eq.w = "ak74" if randf() < 0.6 else ("m4" if randf() < 0.5 else "aks74u")
	prof.mags[prof.eq.w] = 999
	var p := _new_pdata(nick, team, prof)
	p.ai = true
	p.role = "rifle"
	p.confirmed = true
	p.in_match = true
	var body := CharacterBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	body.add_child(cs)
	world.add_child(body)
	body.floor_snap_length = 0.6
	p.body = body
	p.ai_t = 0.0
	p.ai_goal = Vector3.ZERO
	p.ai_target = 0
	p.ai_stuck = 0.0
	p.ai_side = Vector3.ZERO
	p.ai_side_t = 0.0
	p.ai_last = Vector3.ZERO
	p.ai_fire = 0.0
	p.ai_burst = 0
	players[id] = p
	rpc("cl_add_player", id, nick, team, 0, 0)
	rpc("cl_player_team", id, team, "rifle")
	p.respawn = randf_range(0.2, 2.0)
	print("[SERVER] бот %s у команді %d" % [nick, team])
	return id


func _remove_bot(id: int) -> void:
	if not players.has(id):
		return
	var p: Dictionary = players[id]
	if p.has("body") and is_instance_valid(p.body):
		p.body.queue_free()
	players.erase(id)
	rpc("cl_remove_player", id)


func _remove_bots(all: bool) -> void:
	for pid in players.keys():
		if players[pid].ai and all:
			_remove_bot(pid)


func _bot_can_see(eye: Vector3, tp: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(eye, tp)
	q.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _update_bots(delta: float) -> void:
	for pid in players.keys():
		if not players.has(pid):
			continue
		var p: Dictionary = players[pid]
		if not p.ai:
			continue
		var body: CharacterBody3D = p.body
		if not p.alive:
			body.global_position = Vector3(0.0, -500.0, 0.0)
			continue
		if body.global_position.y < -400.0 or (p.ai_last as Vector3) == Vector3.ZERO:
			body.global_position = p.pos
			body.velocity = Vector3.ZERO
			p.ai_last = p.pos
		var pos := body.global_position
		var eye := pos + Vector3(0.0, 1.55, 0.0)
		p.ai_t = float(p.ai_t) - delta
		if p.ai_t <= 0.0:
			p.ai_t = 0.4
			# ціль: найближчий видимий ворог
			var best := 0
			var bd := 120.0
			for eid in players:
				var e: Dictionary = players[eid]
				if not e.alive or int(e.team) == int(p.team) or int(e.veh) >= 0:
					continue
				var d: float = pos.distance_to(e.pos)
				if d < bd and _bot_can_see(eye, e.pos + Vector3(0.0, 1.3, 0.0)):
					bd = d
					best = eid
			p.ai_target = best
			# точка руху: центр (захоплення), потім тримати позицію поряд
			if (p.ai_goal as Vector3) == Vector3.ZERO or pos.distance_to(p.ai_goal) < 4.0:
				var cap_r := float(World.cur.cap)
				var a := randf() * TAU
				var rr := randf_range(2.0, cap_r + 18.0)
				p.ai_goal = Vector3(cos(a) * rr, 0.0, sin(a) * rr)
			# застряг?
			var moved := Vector2(pos.x - p.ai_last.x, pos.z - p.ai_last.z).length()
			p.ai_last = pos
			if moved < 0.35 and int(p.ai_target) == 0:
				p.ai_stuck = float(p.ai_stuck) + 0.4
			else:
				p.ai_stuck = 0.0
			if float(p.ai_stuck) > 1.2:
				var a2 := randf() * TAU
				p.ai_side = Vector3(cos(a2), 0.0, sin(a2))
				p.ai_side_t = 1.6
				if body.is_on_floor():
					body.velocity.y = 8.5
				p.ai_stuck = 0.0
		var dirv := Vector3.ZERO
		var speed := 4.6
		var tgt := int(p.ai_target)
		var aiming := false
		if tgt != 0 and players.has(tgt) and players[tgt].alive:
			var e: Dictionary = players[tgt]
			var to: Vector3 = (e.pos as Vector3) - pos
			p.yaw = atan2(-to.x, -to.z)
			aiming = true
			var d := to.length()
			if d > 45.0:
				dirv = Vector3(to.x, 0.0, to.z).normalized()
				speed = 3.0
			else:
				var side := Vector3(-to.z, 0.0, to.x).normalized()
				dirv = side * (1.0 if int(Time.get_ticks_msec() / 1700) % 2 == 0 else -1.0)
				speed = 1.6
			# стрільба чергами з розкидом
			p.ai_fire = float(p.ai_fire) - delta
			if p.ai_fire <= 0.0:
				var w: Dictionary = Gear.WEAPONS[p.eq.w]
				p.ai_fire = float(w.rof)
				p.ai_burst = int(p.ai_burst) + 1
				if p.ai_burst > 4:
					p.ai_burst = 0
					p.ai_fire = randf_range(0.6, 1.4)
				var aimp: Vector3 = e.pos + Vector3(0.0, randf_range(0.9, 1.6), 0.0)
				var err := 0.03 + d * 0.0012
				var dir := (aimp - eye).normalized() + Vector3(randf_range(-err, err), randf_range(-err, err), randf_range(-err, err))
				p.pitch = rad_to_deg(asin(clampf(dir.normalized().y, -1.0, 1.0)))
				_process_shot(pid, eye, dir)
		else:
			var g: Vector3 = p.ai_goal
			dirv = Vector3(g.x - pos.x, 0.0, g.z - pos.z).normalized()
			if (p.ai_side_t as float) > 0.0:
				p.ai_side_t = float(p.ai_side_t) - delta
				dirv = p.ai_side
			if dirv.length() > 0.1:
				p.yaw = lerp_angle(float(p.yaw), atan2(-dirv.x, -dirv.z), clampf(delta * 6.0, 0.0, 1.0))
			p.pitch = 0.0
		body.velocity.x = dirv.x * speed
		body.velocity.z = dirv.z * speed
		if not body.is_on_floor():
			body.velocity.y -= 20.0 * delta
		body.move_and_slide()
		if body.global_position.y < float(World.cur.get("hmin", -20.0)) - 10.0:
			body.global_position = spawn_point(int(p.team))
		p.pos = body.global_position
		p.flags = (4 if aiming else 0) | (64 if speed > 4.0 and dirv.length() > 0.1 else 0)



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
	my_id = multiplayer.get_unique_id()
	_set_status("Сервер: підключено")
	rpc_id(1, "srv_hello", str(get_meta("nick", "Боєць")), VERSION)
	if auto_pick:
		rpc_id(1, "srv_enter", map_pref)
	if is_bot:
		print("[BOT] connected as %d" % multiplayer.get_unique_id())


func _on_conn_failed() -> void:
	connected = false
	multiplayer.multiplayer_peer = null
	_set_status("Сервер не відповідає. Повторна спроба за 5 с...")
	retry_t = 5.0
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
	in_match = false
	if menu:
		_close_overlays()
		hud.hide()
		touch.hide()
		menu.picked = false
		menu.show_menu("home")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_status("З'єднання з сервером втрачено. Повторна спроба за 5 с...")
	retry_t = 5.0


func _clear_match() -> void:
	for id in avatars:
		avatars[id].queue_free()
	avatars.clear()
	for id in remote_drones:
		remote_drones[id].queue_free()
	remote_drones.clear()
	for vid in vnodes:
		vnodes[vid].queue_free()
	vnodes.clear()
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
	if my_role == "recon":
		rpc_id(1, "srv_recon_start")
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
	buy("gren", "", 2)
	buy("med", "", 1)
	print("[BOT] shop test sent")


func show_hint(t: String) -> void:
	_show_center(t, 2.5)
	if is_bot:
		print("[BOT] hint: " + t)


# ---------------------------------------------------------------- RPC від сервера

@rpc("authority", "call_remote", "reliable")
func cl_map(idx: int) -> void:
	if idx == map_index and world != null:
		return
	map_index = idx
	_rebuild_client_world()
	if is_bot:
		print("[BOT] map: %s" % World.cur.name)
	else:
		_show_center("Карта: %s" % World.cur.name, 3.0)


func _rebuild_client_world() -> void:
	# солдат і аватари переносяться в новий світ, решта (ефекти, дрони) видаляється
	var keep: Array = []
	if world:
		if soldier and soldier.get_parent() == world:
			world.remove_child(soldier)
			keep.append(soldier)
		for id in avatars:
			var a = avatars[id]
			if a.get_parent() == world:
				world.remove_child(a)
				keep.append(a)
		for id in remote_drones:
			remote_drones[id].queue_free()
		remote_drones.clear()
		vnodes.clear()
		projectiles.clear()
		world.free()
	world = null
	_build_client_world()
	for n in keep:
		world.add_child(n)


@rpc("authority", "call_remote", "reliable")
func cl_profile(prof: Dictionary) -> void:
	profile = prof
	if menu:
		menu.refresh_rp()
		menu.refresh_hero_gear()
		menu.refresh()


@rpc("authority", "call_remote", "reliable")
func cl_lobby(data: Dictionary) -> void:
	lobby = data
	if menu:
		menu.on_lobby(data)
	if auto_pick and my_role == "" and not get_meta("pick_sent", false):
		_auto_pick(data)


## Бот / автотест: обирає команду з меншою кількістю гравців і вільну роль.
func _auto_pick(data: Dictionary) -> void:
	var teams: Array = data.get("teams", [[], []])
	var t := 0 if teams[0].size() <= teams[1].size() else 1
	var roles: Array = ["rifle", "fpv", "medic", "mg", "mortar", "eng", "radio", "recon"]
	if is_bot:
		roles.shuffle()
	for r in roles:
		var used := 0
		for e in teams[t]:
			if String(e[1]) == r:
				used += 1
		if used < int(Gear.ROLES[r].slots):
			set_meta("pick_sent", true)
			rpc_id(1, "srv_pick", t, r)
			if is_bot:
				print("[BOT] pick team %d role %s" % [t, r])
			return


@rpc("authority", "call_remote", "reliable")
func cl_pick_result(ok: bool, msg: String) -> void:
	if not ok:
		set_meta("pick_sent", false)
		my_role = ""
	if menu:
		menu.on_pick_result(ok, msg)
	if is_bot:
		print("[BOT] pick %s %s" % [str(ok), msg])


@rpc("authority", "call_remote", "reliable")
func cl_player_team(id: int, team: int, role: String) -> void:
	if not players.has(id):
		return
	var old := int(players[id].team)
	players[id].team = team
	players[id]["role"] = role
	if id == my_id:
		my_team = team
		my_role = role
		if menu:
			menu.sel_team = team
			menu.sel_role = role
		if old != team and soldier:
			soldier.queue_free()
			soldier = null
			alive_local = false
	elif old != team or not avatars.has(id):
		if avatars.has(id):
			avatars[id].queue_free()
		var a = Avatar.new()
		a.setup(String(players[id].nick), TEAM_COLORS[team], team)
		a.visible = false
		world.add_child(a)
		avatars[id] = a


@rpc("authority", "call_remote", "reliable")
func cl_match_start(t0: int, t1: int, cap: float) -> void:
	tickets = [t0, t1]
	capture = cap
	in_match = true
	if tophud:
		tophud.round_t = 0.0
	if menu:
		_close_overlays()
		menu.hide_menu()
		hud.show()
		touch.show()
		touch.reset_input()
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_show_center("В бій! Команда: %s, роль: %s" % [TEAM_NAMES[my_team], String(Gear.ROLES.get(my_role, {}).get("name", ""))], 3.5)
	if is_bot:
		print("[BOT] match start, team %d" % my_team)


@rpc("authority", "call_remote", "reliable")
func cl_round_lobby() -> void:
	in_match = false
	my_role = ""
	set_meta("pick_sent", false)
	alive_local = false
	if soldier:
		soldier.queue_free()
		soldier = null
	for id in avatars:
		avatars[id].visible = false
	for id in remote_drones.keys():
		_remove_remote_drone(id)
	if menu:
		_close_overlays()
		hud.hide()
		touch.hide()
		touch.reset_input()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		menu.new_round()
	if is_bot:
		print("[BOT] back to lobby")


@rpc("authority", "call_remote", "reliable")
func cl_player_left_match(id: int) -> void:
	if avatars.has(id):
		avatars[id].visible = false
	_remove_remote_drone(id)


@rpc("authority", "call_remote", "reliable")
func cl_add_player(id: int, nick: String, team: int, kills: int, deaths: int) -> void:
	players[id] = {"nick": nick, "team": team, "kills": kills, "deaths": deaths}
	if id != multiplayer.get_unique_id() and not avatars.has(id):
		var a = Avatar.new()
		a.setup(nick, TEAM_COLORS[maxi(team, 0)], maxi(team, 0))
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
func cl_loadout(prof: Dictionary, eq: Dictionary, in_mag: int, mags: int, drones: int, heavy: int, gren: int, adur: int, hdur: int, med: int) -> void:
	profile = prof
	armor_dur = adur
	helm_dur = hdur
	if soldier:
		soldier.apply_loadout(eq, in_mag, mags, drones, heavy, gren, med)
	if shop and shop.visible:
		_refresh_shop()
	if menu and menu.visible:
		menu.refresh_rp()
		menu.refresh_hero_gear()
		menu.refresh()
	if is_bot:
		print("[BOT] loadout: %s, mags %d, drones %d, money %d" % [str(eq), mags, drones, int(prof.money)])


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
		zone_dmg = [0, 0, 0, 0, 0, 0, 0, 0]
		zone_flash = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		armor_dur = 100
		helm_dur = 100
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
		if avatars.has(id) and (mode & 256) != 0:
			avatars[id].visible = false
		if avatars.has(id):
			var am = avatars[id].model
			am.set_pose((mode & 2) != 0, (mode & 4) != 0)
			am.look_pitch = data[b + 4]
			var lv := -1.0 if (mode & 16) != 0 else (1.0 if (mode & 32) != 0 else 0.0)
			am.set_move_state((mode & 8) != 0, lv, (mode & 64) != 0, (mode & 128) != 0)
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
func cl_hp(hp: int, zone: int, dmg: int, from: Vector3, adur: int, hdur: int) -> void:
	my_hp = hp
	armor_dur = adur
	helm_dur = hdur
	zone = clampi(zone, 0, 7)
	zone_dmg[zone] = int(zone_dmg[zone]) + dmg
	zone_flash[zone] = 1.0
	if zone == 7:
		for z in [1, 2, 5, 6]:
			zone_flash[z] = maxf(float(zone_flash[z]), 0.7)
	if hithud and soldier:
		hithud.add_hit(from, zone, dmg)
	_add_feed("Поранено: %s  −%d" % [ZONE_NAMES[zone], dmg])
	Sfx.play(self, "hit", null, -4.0, 0.7)


@rpc("authority", "call_remote", "reliable")
func cl_heal_start(t: float) -> void:
	heal_left = t
	Sfx.play(self, "reload", null, -6.0, 0.7)


@rpc("authority", "call_remote", "reliable")
func cl_healed(hp: int, med: int) -> void:
	my_hp = hp
	heal_left = 0.0
	if soldier:
		soldier.medkits = med
		soldier._recalc_weight()
	# перев'язані рани
	for zi in 8:
		zone_dmg[zi] = int(int(zone_dmg[zi]) * 0.4)
	_show_center("Здоров'я відновлено: %d" % hp, 1.2)
	if is_bot:
		print("[BOT] healed to %d" % hp)


func use_medkit() -> void:
	if soldier == null or not alive_local:
		return
	if soldier.medkits <= 0:
		show_hint("Немає аптечок. Купіть у магазині.")
		return
	if my_hp >= 100:
		show_hint("Здоров'я повне.")
		return
	if heal_left > 0.0:
		return
	rpc_id(1, "srv_heal")


@rpc("authority", "call_remote", "reliable")
func cl_grenade(id: int, from: Vector3, target: Vector3, flight: float, fuse: float) -> void:
	if world == null:
		return
	if _gren_scene == null:
		_gren_scene = load("res://models/grenade.glb")
	var g: Node3D = _gren_scene.instantiate()
	g.scale = Vector3.ONE * 1.4
	world.add_child(g)
	g.global_position = from
	Sfx.play(world, "reload", from, -4.0, 1.6)
	var tw := g.create_tween()
	var peak := maxf(from.y, target.y) + 1.5 + from.distance_to(target) * 0.12
	tw.tween_method(_gren_fly.bind(g, from, target, peak), 0.0, 1.0, flight)
	tw.tween_interval(maxf(0.05, fuse - flight))
	tw.tween_callback(g.queue_free)
	if id == my_id:
		_show_center("Граната!", 0.8)


func _gren_fly(t: float, g: Node3D, from: Vector3, target: Vector3, peak: float) -> void:
	if not is_instance_valid(g):
		return
	var p := from.lerp(target + Vector3(0.0, 0.06, 0.0), t)
	p.y += sin(t * PI) * (peak - lerpf(from.y, target.y, t))
	g.global_position = p
	g.rotation = Vector3(t * 14.0, t * 5.0, 0.0)


func local_grenade(target: Vector3) -> void:
	if is_server:
		return
	rpc_id(1, "srv_grenade", target)


@rpc("authority", "call_remote", "reliable")
func cl_hitmark(zone: int) -> void:
	_show_center("✕ влучання: %s" % ZONE_NAMES[clampi(zone, 0, 7)], 0.5)
	if hithud:
		hithud.hitmark(zone)
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
	if tophud:
		tophud.round_t = 0.0


# ---------------------------------------------------------------- техніка (клієнт)

@rpc("authority", "call_remote", "unreliable_ordered")
func cl_vehicles(vd: PackedFloat32Array) -> void:
	if world == null:
		return
	var k := 0
	while k + 7 < vd.size():
		var vid := int(vd[k])
		var pos := Vector3(vd[k + 1], vd[k + 2], vd[k + 3])
		var yaw := vd[k + 4]
		if not vnodes.has(vid):
			var v = Vehicle.new()
			world.add_child(v)
			v.setup(vid, int(vd[k + 7]), pos, yaw)
			vnodes[vid] = v
		vnodes[vid].net_update(pos, yaw, vd[k + 5], vd[k + 6] > 0.5)
		k += 8


@rpc("authority", "call_remote", "reliable")
func cl_veh_seat(vid: int, pid: int, seat: int) -> void:
	if vnodes.has(vid):
		var v = vnodes[vid]
		for si in v.seats.size():
			if int(v.seats[si]) == pid:
				v.seats[si] = 0
		if seat >= 0:
			v.seats[seat] = pid
	if pid == my_id and soldier:
		if seat >= 0:
			soldier.enter_vehicle(vid, seat)
			_show_center("Водій: джойстик — газ і поворот" if seat == 0 else "Ви пасажир. Вихід — кнопка праворуч", 2.5)
		else:
			soldier.exit_vehicle()
	if is_bot:
		print("[BOT] seat %d %d %d" % [vid, pid, seat])


func nearest_vehicle(pos: Vector3) -> int:
	var best := -1
	var bd := 6.0
	for vid in vnodes:
		var v = vnodes[vid]
		if not v.alive or int(v.team) != my_team:
			continue
		var d: float = (v.global_position as Vector3).distance_to(pos)
		if d < bd:
			bd = d
			best = vid
	return best


func request_veh_enter(vid: int) -> void:
	if connected and vid >= 0:
		rpc_id(1, "srv_veh_enter", vid)


func request_veh_exit() -> void:
	if connected:
		rpc_id(1, "srv_veh_exit")


func send_veh_state(vid: int, pos: Vector3, yaw: float) -> void:
	if connected:
		rpc_id(1, "srv_veh_state", vid, pos, yaw)


# ---------------------------------------------------------------- розвідка (клієнт)

@rpc("authority", "call_remote", "reliable")
func cl_recon_ok(pos: Vector3) -> void:
	if soldier and alive_local:
		soldier.start_drone(pos, true)
		drone_time = RECON_LIFETIME
		_show_center("Дрон-розвідник у повітрі. Кнопка «Позначити» — ціль для штурму", 3.0)
		if is_bot:
			print("[BOT] recon drone launched")


func recon_mark(pos: Vector3) -> void:
	if connected:
		rpc_id(1, "srv_recon_mark", pos)


@rpc("authority", "call_remote", "reliable")
func cl_spot(ids: PackedInt32Array, secs: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for id in ids:
		spotted[id] = maxf(float(spotted.get(id, 0.0)), now + secs)


@rpc("authority", "call_remote", "reliable")
func cl_waypoint(pos: Vector3, who: String) -> void:
	waypoint = pos
	waypoint_t = 45.0
	_show_center("Розвідник %s позначив ціль" % who, 2.0)
	Sfx.play(self, "buy", null, -6.0)
	_update_wp_marker()


var wp_marker: Node3D


func _update_wp_marker() -> void:
	if world == null:
		return
	if wp_marker == null or not is_instance_valid(wp_marker):
		wp_marker = Node3D.new()
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.25
		cm.height = 60.0
		beam.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.25, 0.15, 0.45)
		m.no_depth_test = true
		beam.material_override = m
		beam.position.y = 30.0
		wp_marker.add_child(beam)
		world.add_child(wp_marker)
	wp_marker.global_position = waypoint
	wp_marker.visible = waypoint_t > 0.0


func is_spotted(id: int) -> bool:
	return float(spotted.get(id, 0.0)) > Time.get_ticks_msec() / 1000.0



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
	world = World.build(self, true, map_index)
	World.decorate_scan(world, World.cur.has("file"))
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
	for zi in 8:
		zone_flash[zi] = maxf(0.0, float(zone_flash[zi]) - delta * 0.45)
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
	_fill_music()
	if retry_t > 0.0 and not connected and not is_bot:
		retry_t -= delta
		if retry_t <= 0.0:
			menu_connect(true)
	if touch and touch.shop_pressed:
		touch.shop_pressed = false
		_open_shop()
	if touch and touch.bag_pressed:
		touch.bag_pressed = false
		if bag:
			open_bag()
	if touch and touch.map_pressed:
		touch.map_pressed = false
		if bigmap:
			open_bigmap()
	if waypoint_t > 0.0:
		waypoint_t -= delta
		if waypoint_t <= 0.0 and wp_marker and is_instance_valid(wp_marker):
			wp_marker.visible = false
	if touch and soldier and alive_local:
		touch.in_vehicle = soldier.in_veh >= 0
		touch.veh_near = not touch.in_vehicle and not soldier.drone_active and nearest_vehicle(soldier.global_position) >= 0
		touch.recon = my_role == "recon"
		if touch.veh_pressed:
			touch.veh_pressed = false
			if soldier.in_veh >= 0:
				request_veh_exit()
			else:
				request_veh_enter(nearest_vehicle(soldier.global_position))
	elif touch:
		touch.in_vehicle = false
		touch.veh_near = false
	if touch and touch.settings_pressed:
		touch.settings_pressed = false
		if settings_panel:
			open_settings(true)
	if minimap and hud and hud.visible:
		var mr: Rect2 = touch.minimap_rect()
		minimap.position = mr.position
		minimap.size = mr.size
		minimap.modulate.a = touch.el_alpha("minimap")
		minimap.visible = not touch.el_hidden("minimap")
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
		elif heal_left > 0.0:
			ammo_lbl.text = "Перев'язка... %.1f с" % heal_left
		elif soldier.slot == 0:
			ammo_lbl.text = "ПЕРЕЗАРЯДКА..." if soldier.reloading > 0.0 else ""
		elif soldier.slot == 1:
			var h: Dictionary = Gear.HEAVY[soldier.eq.x]
			var t := "%s • боєприпаси: %d" % [h.name, soldier.heavy_ammo]
			if soldier.eq.x == "mortar":
				var dist := Vector2(soldier.mortar_target.x - soldier.global_position.x, soldier.mortar_target.z - soldier.global_position.z).length()
				t += " • дистанція %d м%s" % [int(dist), "" if soldier.mortar_valid else " (поза межами)"]
			ammo_lbl.text = t
		else:
			ammo_lbl.text = ""
		if touch:
			var wi: String = {"ak74": "ak47", "aks74u": "ak", "m4": "m4", "svd": "svd"}.get(soldier.eq.w, "ak47")
			touch.info = {
				"slot": soldier.slot, "w_icon": wi, "in_mag": soldier.in_mag,
				"reserve": soldier.mags * int(soldier.wdata.mag), "heavy": soldier.eq.x,
				"heavy_ammo": soldier.heavy_ammo, "gren": soldier.grenades, "med": soldier.medkits,
				"hp": my_hp, "armor": float(armor_dur) if soldier.eq.a != "none" else 0.0,
				"heal": 1.0 - heal_left / Gear.MEDKIT_TIME if heal_left > 0.0 else 0.0,
			}
			var bd := {"drone": soldier.drones, "grenade": soldier.grenades}
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
	if heal_left > 0.0:
		heal_left = maxf(0.0, heal_left - delta)
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

	score_lbl = _label(hud, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_place(score_lbl, Vector4(0, 0, 1, 0), Vector4(0, 62, 0, 86))
	cap_lbl = _label(hud, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_place(cap_lbl, Vector4(0, 0, 1, 0), Vector4(0, 86, 0, 106))
	hp_lbl = _label(hud, 34, HORIZONTAL_ALIGNMENT_LEFT)
	hp_lbl.visible = false
	money_lbl = _label(hud, 18, HORIZONTAL_ALIGNMENT_LEFT)
	money_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55))
	_place(money_lbl, Vector4(0, 0, 0, 0), Vector4(240, 80, 480, 104))
	money_lbl.visible = not Gear.UNLIMITED_MONEY
	feed_lbl = _label(hud, 16, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(feed_lbl, Vector4(1, 0, 1, 0), Vector4(-430, 240, -20, 380))
	ammo_lbl = _label(hud, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_place(ammo_lbl, Vector4(0.5, 1, 0.5, 1), Vector4(-360, -178, 360, -150))
	center_lbl = _label(hud, 28, HORIZONTAL_ALIGNMENT_CENTER)
	center_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(center_lbl, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-460, -190, 460, -110))
	tophud = TopHud.new()
	hud.add_child(tophud)
	tophud.setup(self)
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
	hithud = HitHud.new()
	hud.add_child(hithud)
	hithud.setup(self)
	bag = Inventory.new()
	ui.add_child(bag)
	bag.setup(self)
	bag.hide()

	_build_shop()

	# ---------------- головне меню, налаштування, редактор HUD
	menu = Menu.new()
	ui.add_child(menu)
	menu.setup(self)
	status_lbl = menu.status_lbl
	ui.move_child(shop, -1)
	settings_panel = SettingsPanel.new()
	ui.add_child(settings_panel)
	settings_panel.setup(self)
	hud_editor = HudEdit.new()
	ui.add_child(hud_editor)
	hud_editor.setup(self, touch)
	touch.load_layout(int(Settings.value("controls", "hud_profile", 1)))
	touch.auto_sprint = int(Settings.value("controls", "auto_sprint", 1)) == 1
	minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	map_pref = clampi(int(Settings.value("main", "map", 0)), 0, World.map_count() - 1)


# ---------------------------------------------------------------- меню і панелі

## Підключення до сервера з меню (адреса — з налаштувань).
func menu_connect(force: bool = false) -> void:
	if connected and not force:
		return
	var nick := String(Settings.value("main", "nick", "")).strip_edges()
	if nick == "":
		return
	var addr := String(Settings.value("main", "addr", DEFAULT_ADDR)).strip_edges()
	if addr == "" or addr == "127.0.0.1:7000":
		addr = DEFAULT_ADDR
	var host := addr
	var port := DEFAULT_PORT
	var colon := addr.rfind(":")
	if colon > 0:
		host = addr.substr(0, colon)
		port = int(addr.substr(colon + 1))
	if connected:
		multiplayer.multiplayer_peer.close()
		connected = false
		_clear_match()
	retry_t = 0.0
	connect_to(host, port, nick)


func request_enter(map_idx: int) -> void:
	map_pref = map_idx
	if connected:
		rpc_id(1, "srv_enter", map_idx)


func request_pick(team: int, role: String) -> void:
	if connected:
		rpc_id(1, "srv_pick", team, role)
	else:
		menu.on_pick_result(false, "Немає з'єднання з сервером.")


## Вихід з лобі до головного меню.
func leave_lobby() -> void:
	my_role = ""
	if connected:
		rpc_id(1, "srv_leave_match")


## Вихід з бою в головне меню (з налаштувань під час бою).
func leave_match() -> void:
	in_match = false
	my_role = ""
	if connected:
		rpc_id(1, "srv_leave_match")
	if soldier:
		soldier.queue_free()
		soldier = null
	alive_local = false
	_close_overlays()
	hud.hide()
	touch.hide()
	touch.reset_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.picked = false
	menu.show_menu("home")


func open_settings(game: bool) -> void:
	if settings_panel.visible:
		return
	touch.reset_input()
	if game:
		touch.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	settings_panel.open(game)


func on_settings_closed() -> void:
	touch.auto_sprint = int(Settings.value("controls", "auto_sprint", 1)) == 1
	touch.load_layout(int(Settings.value("controls", "hud_profile", 1)))
	if hud.visible:
		touch.show()


var _touch_idx := -1
var _menu_was_visible := false


func open_hud_editor() -> void:
	_touch_idx = touch.get_index()
	ui.move_child(touch, -1)
	ui.move_child(hud_editor, -1)
	_menu_was_visible = menu.visible
	if menu.visible:
		menu.visible = false
		menu.set_active(false)
	hud_editor.open()


func on_hud_editor_closed() -> void:
	if _touch_idx >= 0:
		ui.move_child(touch, _touch_idx)
	if _menu_was_visible:
		menu.visible = true
		menu.set_active(true)
	if not hud.visible:
		touch.hide()
	settings_panel.open(hud.visible)


func open_shop_from_menu() -> void:
	_open_shop()


## Закриває всі накладки (карта, рюкзак, магазин, налаштування).
func _close_overlays() -> void:
	if bigmap and bigmap.visible:
		bigmap.hide()
	if bag and bag.visible:
		bag.hide()
	if shop and shop.visible:
		shop.hide()
	if settings_panel and settings_panel.visible:
		settings_panel.hide()
	if hud_editor and hud_editor.visible:
		hud_editor.back()


## Системна кнопка «Назад» на Android: закриває верхню панель, а не гру.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or is_server or menu == null:
		return
	if hud_editor.visible:
		hud_editor.back()
	elif settings_panel.visible:
		settings_panel.close_panel()
	elif shop.visible:
		_close_shop()
	elif bag.visible:
		bag.close()
	elif bigmap.visible:
		close_bigmap()
	elif menu.visible:
		menu.back()


func open_bigmap() -> void:
	if bigmap.visible or bag.visible:
		return
	touch.hide()
	touch.reset_input()
	UI.fade_in(bigmap)


func close_bigmap() -> void:
	if not bigmap.visible:
		return
	UI.fade_out(bigmap)
	on_map_closed()


func open_bag() -> void:
	if bag.visible or bigmap.visible:
		return
	touch.hide()
	touch.reset_input()
	bag.open()


## Фонова музика меню (синтезована, шина Music).
func _start_music() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.5
	music = AudioStreamPlayer.new()
	music.stream = gen
	music.volume_db = -14.0
	if AudioServer.get_bus_index("Music") >= 0:
		music.bus = "Music"
	add_child(music)
	music.play()
	set_meta("mus_t", 0.0)


const _MUS_NOTES := [55.0, 55.0, 65.41, 55.0, 49.0, 49.0, 58.27, 49.0]


func _fill_music() -> void:
	if music == null or not music.playing:
		return
	var pb := music.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := pb.get_frames_available()
	if n <= 0:
		return
	var t: float = get_meta("mus_t", 0.0)
	var on: bool = menu != null and menu.visible
	var dt := 1.0 / 22050.0
	for k in n:
		var beat := int(t / 2.0) % _MUS_NOTES.size()
		var f: float = _MUS_NOTES[beat]
		var ph := fmod(t, 2.0)
		var env := minf(1.0, ph * 4.0) * (1.0 - ph * 0.35)
		var v := sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.18 + sin(TAU * f * 3.01 * t) * 0.07
		v += sin(TAU * f * 1.5 * t + sin(t * 0.5) * 2.0) * 0.12
		v *= env * (0.32 if on else 0.0)
		pb.push_frame(Vector2(v, v))
		t += dt
	set_meta("mus_t", fmod(t, 16.0))


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
		_shop_row("Військова аптечка: +%d здоров'я за %d с. На складі: %d. Береш з собою до %d. Вага 0,5 кг." % [Gear.MEDKIT_HEAL, int(Gear.MEDKIT_TIME), int(profile.get("med", 0)), Gear.medkit_slots(eq)],
			[["+1  $%d" % Gear.MEDKIT_PRICE, func(): buy("med", "", 1)], ["+5  $%d" % (Gear.MEDKIT_PRICE * 5), func(): buy("med", "", 5)]])
		_shop_row("Ручна граната. На складі: %d. Береш з собою до %d (розгрузка і рюкзак). Вага 0,6 кг, радіус 7 м." % [int(profile.get("gren", 0)), Gear.grenade_slots(eq)],
			[["+1  $%d" % Gear.GRENADE_PRICE, func(): buy("gren", "", 1)], ["+5  $%d" % (Gear.GRENADE_PRICE * 5), func(): buy("gren", "", 5)]])
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
