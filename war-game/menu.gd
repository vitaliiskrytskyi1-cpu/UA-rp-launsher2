extends Control
## Головне меню: 3D-база з бійцем на тлі, баланс RP, кнопки зліва
## (ГРАТИ, ПЕРСОНАЖ, ІНВЕНТАР, НАЛАШТУВАННЯ, МАГАЗИН), вибір карти,
## команди і ролі, екран очікування бою. Позивний питається один раз.

const UI = preload("res://uikit.gd")
const Settings = preload("res://settings.gd")
const World = preload("res://world.gd")
const Gear = preload("res://gear.gd")
const Character = preload("res://character.gd")
var main
var screen := ""
var history: Array = []
var content: Control
var rp_lbl: Label
var status_lbl: Label
var nick_lbl: Label
var left_btns := {}
var nick_box: Control

var sel_map := 0
var sel_team := -1
var sel_role := ""
var lobby := {}
var picked := false
var waiting_pick := false

# 3D-тло
var view_box: SubViewportContainer
var viewport: SubViewport
var cam: Camera3D
var hero: Node3D
var hero_team := -1
var _cam_t := 0.0


func setup(m) -> void:
	main = m
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.0)
	add_child(shade)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.02, 0.92))
	g.set_color(1, Color(0.02, 0.03, 0.02, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grad.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 620
	add_child(grad)

	# ліва колонка
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 34
	left.offset_top = 26
	left.offset_right = 330
	left.offset_bottom = -20
	add_child(left)
	left.add_child(UI.title("UA WAR FRONT", 40))
	nick_lbl = UI.label("", 20, UI.DIM)
	left.add_child(nick_lbl)
	var sp0 := Control.new()
	sp0.custom_minimum_size = Vector2(0, 14)
	left.add_child(sp0)
	for d in [["play", "ГРАТИ"], ["char", "ПЕРСОНАЖ"], ["inv", "ІНВЕНТАР"], ["settings", "НАЛАШТУВАННЯ"], ["shop", "МАГАЗИН"]]:
		var b := UI.button(String(d[1]), 26, 66)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.pressed.connect(_on_left.bind(String(d[0])))
		left.add_child(b)
		left_btns[d[0]] = b
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	status_lbl = UI.label("", 17, UI.DIM)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	left.add_child(status_lbl)

	# баланс RP угорі праворуч
	var rp := UI.panel()
	rp.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rp.offset_left = -260
	rp.offset_right = -24
	rp.offset_top = 20
	rp.offset_bottom = 74
	add_child(rp)
	var rph := HBoxContainer.new()
	rph.alignment = BoxContainer.ALIGNMENT_END
	rp.add_child(rph)
	var rpi := UI.label("RP", 22, Color(0.1, 0.1, 0.08))
	var sb := UI.box(UI.ACCENT, UI.ACCENT, 4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	rpi.add_theme_stylebox_override("normal", sb)
	rph.add_child(rpi)
	rp_lbl = UI.label("—", 26, UI.TEXT)
	rph.add_child(rp_lbl)

	# область праворуч від кнопок
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 360
	content.offset_top = 90
	content.offset_right = -24
	content.offset_bottom = -20
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	sel_map = clampi(int(Settings.value("main", "map", 0)), 0, World.map_count() - 1)
	_refresh_nick()
	go("home")
	if String(Settings.value("main", "nick", "")).strip_edges() == "":
		_ask_nick()


# ---------------------------------------------------------------- 3D-тло

func _build_background() -> void:
	view_box = SubViewportContainer.new()
	view_box.stretch = true
	view_box.stretch_shrink = 2 if OS.has_feature("mobile") else 1
	view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view_box)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	view_box.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.45, 0.55)
	sm.sky_horizon_color = Color(0.7, 0.68, 0.6)
	sm.ground_horizon_color = Color(0.5, 0.47, 0.4)
	sm.ground_bottom_color = Color(0.25, 0.23, 0.2)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.62, 0.56)
	env.fog_density = 0.006
	env.tonemap_exposure = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.shadow_enabled = true
	root.add_child(sun)

	# земля
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.26, 0.25, 0.18)
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)

	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.42, 0.38, 0.27)
	sand.roughness = 1.0
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.27, 0.16)
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color(0.28, 0.31, 0.2)
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	# мішки з піском півколом за бійцем
	for i in 15:
		var a := -0.9 + i * 0.13
		for row in 3:
			var bag := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.62, 0.24, 0.36)
			bag.mesh = bm
			bag.material_override = sand
			var r := 4.2 + (row % 2) * 0.05
			bag.position = Vector3(sin(a) * r - 1.0, 0.12 + row * 0.24, -cos(a) * r - 1.5)
			bag.rotation.y = -a + (row % 2) * 0.12
			root.add_child(bag)
	# ящики з боєприпасами
	for i in 4:
		var box := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(0.9, 0.42, 0.5)
		box.mesh = b2
		box.material_override = wood
		box.position = Vector3(2.0 + (i % 2) * 0.95, 0.21 + (i / 2) * 0.42, -0.8 - (i % 3) * 0.2)
		box.rotation.y = 0.3 + i * 0.1
		root.add_child(box)
	# намети
	for i in 3:
		var tent := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(4.0, 2.4, 5.5)
		tent.mesh = pr
		tent.material_override = canvas
		tent.position = Vector3(-9.0 + i * 6.5, 1.2, -16.0 - i * 2.0)
		tent.rotation.y = 0.15 * i
		root.add_child(tent)
	# прапор
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.05
	cm.height = 7.0
	pole.mesh = cm
	pole.position = Vector3(-4.5, 3.5, -7.0)
	root.add_child(pole)
	for k in 2:
		var fl := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(1.6, 0.5, 0.02)
		fl.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(0.0, 0.35, 0.75) if k == 0 else Color(1.0, 0.82, 0.0)
		fl.material_override = fmat
		fl.position = Vector3(-3.7, 6.75 - k * 0.5, -7.0)
		root.add_child(fl)
	# бронетранспортер М113
	if ResourceLoader.exists("res://models/m113.glb"):
		var ps = load("res://models/m113.glb")
		if ps:
			var apc: Node3D = ps.instantiate()
			apc.position = Vector3(5.2, 0.0, -5.5)
			apc.rotation.y = -0.7
			root.add_child(apc)

	hero = Node3D.new()
	root.add_child(hero)
	cam = Camera3D.new()
	cam.fov = 48.0
	root.add_child(cam)
	cam.current = true
	_update_cam(0.0)


func set_hero(team: int) -> void:
	if team < 0:
		team = 0
	if team == hero_team:
		return
	hero_team = team
	for c in hero.get_children():
		c.queue_free()
	var ch = Character.new()
	hero.add_child(ch)
	ch.setup(main.team_color(team), team)
	if main.profile.has("eq"):
		ch.set_gear(main.profile.eq, 0)
	hero.rotation.y = PI - 0.45


func refresh_hero_gear() -> void:
	if hero.get_child_count() > 0 and main.profile.has("eq"):
		var ch = hero.get_child(0)
		ch.set_gear(main.profile.eq, 0)


func _update_cam(delta: float) -> void:
	_cam_t += delta * 0.12
	var a := sin(_cam_t) * 0.22
	cam.position = Vector3(sin(a) * 4.6 + 1.1, 1.55, cos(a) * 4.6)
	cam.look_at(Vector3(1.4, 1.05, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if not visible:
		return
	_update_cam(delta)
	if hero.get_child_count() > 0:
		var ch = hero.get_child(0)
		ch.animate(0.0, delta)


## Вимикає рендер тла, поки меню сховане (економія FPS у бою).
func set_active(on: bool) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


# ---------------------------------------------------------------- навігація

func show_menu(scr: String = "home") -> void:
	set_active(true)
	if not visible:
		UI.fade_in(self, 0.25)
	history.clear()
	go(scr)


func hide_menu() -> void:
	set_active(false)
	UI.fade_out(self, 0.2)


func _on_left(id: String) -> void:
	match id:
		"settings":
			left_btns[id].button_pressed = false
			main.open_settings(false)
		"shop":
			left_btns[id].button_pressed = false
			main.open_shop_from_menu()
		_:
			history.clear()
			go(id)


## Кнопка «Назад» (і системна кнопка «Назад» на Android). Повертає false, якщо нікуди.
func back() -> bool:
	if nick_box and nick_box.visible:
		return true
	if history.is_empty():
		if screen != "home":
			go("home", false)
			return true
		return false
	go(String(history.pop_back()), false)
	return true


func go(scr: String, remember: bool = true) -> void:
	if remember and screen != "" and screen != scr and screen != "wait":
		history.append(screen)
	screen = scr
	for k in left_btns:
		left_btns[k].button_pressed = k == scr or (k == "play" and scr in ["team", "role", "wait"])
	for c in content.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)
	match scr:
		"home": _scr_home(box)
		"play": _scr_play(box)
		"team": _scr_team(box)
		"role": _scr_role(box)
		"wait": _scr_wait(box)
		"char": _scr_char(box)
		"inv": _scr_inv(box)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	set_hero(sel_team if sel_team >= 0 else main.my_team)
	refresh_rp()


func refresh() -> void:
	if visible and screen in ["team", "role", "wait", "inv", "char"]:
		var keep := history.duplicate()
		go(screen, false)
		history = keep


func refresh_rp() -> void:
	if main.profile.has("money"):
		var m := int(main.profile.money)
		rp_lbl.text = "∞" if Gear.UNLIMITED_MONEY else _fmt(m)
	else:
		rp_lbl.text = "—"


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return out


func set_status(t: String) -> void:
	status_lbl.text = t


func _refresh_nick() -> void:
	var n := String(Settings.value("main", "nick", ""))
	nick_lbl.text = ("Позивний: " + n) if n != "" else ""


# ---------------------------------------------------------------- позивний

func _ask_nick() -> void:
	nick_box = Control.new()
	nick_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nick_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(nick_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nick_box.add_child(dim)
	var p := UI.panel()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -330
	p.offset_right = 330
	p.offset_top = -170
	p.offset_bottom = 170
	nick_box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UI.title("ВАШ ПОЗИВНИЙ", 30))
	var l := UI.label("Позивний задається один раз і назавжди. Його бачитимуть інші бійці.", 18, UI.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(l)
	var ed := LineEdit.new()
	ed.max_length = 16
	ed.placeholder_text = "Позивний (3–16 символів)"
	ed.add_theme_font_size_override("font_size", 28)
	ed.custom_minimum_size = Vector2(0, 62)
	v.add_child(ed)
	var err := UI.label("", 17, Color(1, 0.45, 0.35))
	v.add_child(err)
	var ok := UI.action_button("ПІДТВЕРДИТИ", 26)
	v.add_child(ok)
	var submit := func(_t = ""):
		var n := ed.text.strip_edges()
		if n.length() < 3:
			err.text = "Мінімум 3 символи."
			return
		Settings.set_value("main", "nick", n)
		_refresh_nick()
		UI.fade_out(nick_box)
		nick_box.queue_free()
		nick_box = null
		main.menu_connect(true)
	ok.pressed.connect(submit)
	ed.text_submitted.connect(submit)
	UI.fade_in(nick_box)


func has_nick() -> bool:
	return String(Settings.value("main", "nick", "")).strip_edges() != ""


# ---------------------------------------------------------------- екрани

func _card(sel: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var col := Color(0.05, 0.07, 0.06, 0.86)
	p.add_theme_stylebox_override("panel", UI.box(col, UI.ACCENT if sel else Color(1, 1, 1, 0.1), 6, 3 if sel else 1))
	return p


func _scr_home(box: VBoxContainer) -> void:
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(sp)
	var p := _card()
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UI.title("Бій 20 на 20", 26))
	var l := UI.label("Окопи, FPV-дрони, РПГ і міномети. Карти зі сканів Фарерських островів.\nНатисніть ГРАТИ, оберіть карту, команду і роль.", 18, UI.TEXT)
	v.add_child(l)
	var play := UI.action_button("ГРАТИ", 32)
	play.custom_minimum_size = Vector2(380, 80)
	play.size_flags_horizontal = Control.SIZE_SHRINK_END
	play.pressed.connect(func(): go("play"))
	box.add_child(play)


func _scr_play(box: VBoxContainer) -> void:
	box.add_child(UI.title("ОБЕРІТЬ КАРТУ", 30))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	scroll.add_child(row)
	for mi in World.map_count():
		var md: Dictionary = World.MAPS[mi]
		var card := _card(mi == sel_map)
		card.custom_minimum_size = Vector2(250, 0)
		row.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var img := TextureRect.new()
		img.custom_minimum_size = Vector2(220, 200)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var ip := "res://maps/%s_top.png" % String(md.get("file", "field"))
		if ResourceLoader.exists(ip):
			img.texture = load(ip)
		v.add_child(img)
		v.add_child(UI.label(String(md.name), 22, UI.ACCENT if mi == sel_map else UI.TEXT))
		var sx := float(md.get("half", 150.0)) * 2.0
		var sz := float(md.get("hz", md.get("half", 150.0))) * 2.0
		v.add_child(UI.label("%d × %d м" % [int(sx), int(sz)], 16, UI.DIM))
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.pressed.connect(func():
			sel_map = mi
			Settings.set_value("main", "map", mi)
			go("play", false))
		card.add_child(b)
		# кнопка поверх картки: PanelContainer розтягує її на весь розмір
	var start := UI.action_button("ПОЧАТИ", 32)
	start.custom_minimum_size = Vector2(380, 80)
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	start.pressed.connect(_on_start)
	box.add_child(start)


func _on_start() -> void:
	if not has_nick():
		_ask_nick()
		return
	if not main.connected:
		set_status("Немає з'єднання з сервером. Підключаємося...")
		main.menu_connect(true)
		return
	main.request_enter(sel_map)
	go("team")


func _team_list(t: int) -> Array:
	var teams: Array = lobby.get("teams", [[], []])
	return teams[t] if t < teams.size() else []


func _scr_team(box: VBoxContainer) -> void:
	box.add_child(UI.title("ОБЕРІТЬ КОМАНДУ", 30))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(row)
	for t in 2:
		var list := _team_list(t)
		var free := Gear.TEAM_SIZE - list.size()
		var card := _card(sel_team == t)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		var hb := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.color = main.team_color(t)
		sw.custom_minimum_size = Vector2(10, 40)
		hb.add_child(sw)
		hb.add_child(UI.label("  " + String(main.TEAM_NAMES[t]).to_upper(), 30, UI.TEXT))
		v.add_child(hb)
		v.add_child(UI.label("Гравців: %d / %d   •   вільно: %d" % [list.size(), Gear.TEAM_SIZE, free], 19, UI.ACCENT if free > 0 else Color(1, 0.4, 0.3)))
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.custom_minimum_size = Vector2(0, 160)
		v.add_child(sc)
		var lv := VBoxContainer.new()
		sc.add_child(lv)
		if list.is_empty():
			lv.add_child(UI.label("Поки нікого", 17, UI.DIM))
		for e in list:
			var rn := String(Gear.ROLES.get(String(e[1]), {}).get("name", ""))
			lv.add_child(UI.label("%s — %s" % [String(e[0]), rn], 17, UI.TEXT))
		var b := UI.button("ОБРАТИ «%s»" % String(main.TEAM_NAMES[t]).to_upper(), 22, 60)
		b.disabled = free <= 0 and not (picked and int(main.my_team) == t)
		b.pressed.connect(func():
			sel_team = t
			go("role"))
		v.add_child(b)


func _role_used(t: int, role: String) -> int:
	var n := 0
	for e in _team_list(t):
		if String(e[1]) == role:
			n += 1
	return n


func _scr_role(box: VBoxContainer) -> void:
	if sel_team < 0:
		sel_team = 0
	var hb := HBoxContainer.new()
	box.add_child(hb)
	var back_b := UI.button("‹ Назад", 20, 50)
	back_b.custom_minimum_size = Vector2(140, 50)
	back_b.pressed.connect(func(): go("team", false))
	hb.add_child(back_b)
	hb.add_child(UI.title("   РОЛЬ У КОМАНДІ «%s»" % String(main.TEAM_NAMES[sel_team]).to_upper(), 28))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(grid)
	for rk in Gear.ROLE_ORDER:
		var rd: Dictionary = Gear.ROLES[rk]
		var mine: bool = picked and String(main.my_role) == rk and int(main.my_team) == sel_team
		var used := _role_used(sel_team, rk) - (1 if mine else 0)
		var free := int(rd.slots) - used
		var card := _card(sel_role == rk)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if free <= 0:
			card.modulate = Color(1, 1, 1, 0.45)
		grid.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var ic := _RoleIcon.new()
		ic.icon = String(rd.icon)
		ic.custom_minimum_size = Vector2(0, 52)
		v.add_child(ic)
		v.add_child(UI.label(String(rd.name), 20, UI.ACCENT if sel_role == rk else UI.TEXT))
		v.add_child(UI.label("вільно %d з %d" % [maxi(free, 0), int(rd.slots)], 16, UI.DIM if free > 0 else Color(1, 0.4, 0.3)))
		var d := UI.label(String(rd.desc), 14, UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		d.custom_minimum_size = Vector2(160, 0)
		v.add_child(d)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = free <= 0
		b.pressed.connect(func():
			sel_role = rk
			go("role", false))
		card.add_child(b)
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(bot)
	var info := UI.label("", 18, Color(1, 0.5, 0.4))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(info)
	var ok := UI.action_button("ПІДТВЕРДИТИ", 30)
	ok.custom_minimum_size = Vector2(360, 74)
	ok.disabled = sel_role == "" or waiting_pick
	if sel_role == "":
		info.text = "Оберіть роль."
		info.add_theme_color_override("font_color", UI.DIM)
	ok.pressed.connect(func():
		waiting_pick = true
		ok.disabled = true
		main.request_pick(sel_team, sel_role))
	bot.add_child(ok)


func on_pick_result(ok: bool, msg: String) -> void:
	waiting_pick = false
	if ok:
		picked = true
		go("wait", false)
	else:
		picked = false
		set_status(msg)
		if screen == "role":
			go("role", false)


func _scr_wait(box: VBoxContainer) -> void:
	var card := _card(true)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.custom_minimum_size = Vector2(560, 0)
	box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var st := String(lobby.get("state", "waiting"))
	var cnt := float(lobby.get("count", 0.0))
	v.add_child(UI.title("ОЧІКУВАННЯ БОЮ", 30))
	var t := "Бій почнеться через %d с" % ceili(cnt) if cnt > 0.0 else "Очікуємо гравців..."
	if st == "running":
		t = "Бій уже йде — заходимо..."
	v.add_child(UI.label(t, 26, UI.TEXT))
	var mi := int(lobby.get("map", 0))
	if mi < World.map_count():
		v.add_child(UI.label("Карта: %s" % String(World.MAPS[mi].name), 20, UI.DIM))
	v.add_child(UI.label("Команда: %s   •   Роль: %s" % [String(main.TEAM_NAMES[maxi(sel_team, 0)]), String(Gear.ROLES.get(sel_role, {}).get("name", "—"))], 20, UI.ACCENT))
	for tt in 2:
		v.add_child(UI.label("%s: %d / %d" % [String(main.TEAM_NAMES[tt]), _team_list(tt).size(), Gear.TEAM_SIZE], 18, UI.DIM))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	var cr := UI.button("Змінити роль", 20, 56)
	cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.pressed.connect(func(): go("role", false))
	hb.add_child(cr)
	var ct := UI.button("Змінити команду", 20, 56)
	ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ct.pressed.connect(func(): go("team", false))
	hb.add_child(ct)
	var lv := UI.button("Вийти в меню", 20, 56)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.pressed.connect(func():
		picked = false
		main.leave_lobby()
		history.clear()
		go("home", false))
	hb.add_child(lv)


func on_lobby(data: Dictionary) -> void:
	lobby = data
	if not visible:
		return
	if screen in ["team", "role", "wait"]:
		refresh()


## Новий раунд: вибір команди і ролі заново.
func new_round() -> void:
	picked = false
	sel_role = ""
	show_menu("team")


func _scr_char(box: VBoxContainer) -> void:
	box.add_child(UI.title("ПЕРСОНАЖ", 30))
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.custom_minimum_size = Vector2(520, 0)
	box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(UI.label(String(Settings.value("main", "nick", "—")), 28, UI.ACCENT))
	if not main.profile.has("eq"):
		v.add_child(UI.label("Підключіться до сервера, щоб побачити спорядження.", 18, UI.DIM))
		return
	var eq: Dictionary = main.profile.eq
	var names := {"w": "Зброя", "a": "Бронежилет", "h": "Шолом", "r": "Розгрузка", "p": "Рюкзак", "x": "Важка зброя"}
	for c in ["w", "a", "h", "r", "p", "x"]:
		var cd := Gear.catalog(c)
		var k := String(eq.get(c, "none"))
		v.add_child(_kv(String(names[c]), String(cd[k].name) if cd.has(k) else "—"))
	var w := Gear.weight(eq, Gear.mag_capacity(eq), Gear.drone_slots(eq))
	v.add_child(_kv("Вага спорядження", "%.1f кг" % w))
	v.add_child(_kv("Швидкість", "%d%%" % int(Gear.speed_mult(w) * 100.0)))
	var a := String(eq.get("a", "none"))
	var h := String(eq.get("h", "none"))
	v.add_child(_kv("Захист корпусу", "%d%%" % int(float(Gear.ARMOR[a].get("reduce", 0.0)) * 100.0)))
	v.add_child(_kv("Захист голови", "%d%%" % int(float(Gear.HELMET[h].get("reduce", 0.0)) * 100.0)))
	v.add_child(_kv("Склад", "магазинів %d • дронів %d • гранат %d • аптечок %d" % [_mags_total(), int(main.profile.get("fpv", 0)), int(main.profile.get("gren", 0)), int(main.profile.get("med", 0))]))


func _mags_total() -> int:
	var n := 0
	var m = main.profile.get("mags", {})
	if typeof(m) == TYPE_DICTIONARY:
		for k in m:
			n += int(m[k])
	return n


func _kv(k: String, v: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var a := UI.label(k, 19, UI.DIM)
	a.custom_minimum_size = Vector2(210, 0)
	hb.add_child(a)
	hb.add_child(UI.label(v, 19, UI.TEXT))
	return hb


var inv_cat := "w"


func _scr_inv(box: VBoxContainer) -> void:
	box.add_child(UI.title("ІНВЕНТАР", 30))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	box.add_child(tabs)
	for d in [["w", "Зброя"], ["x", "Важка"], ["a", "Броня"], ["h", "Шоломи"], ["r", "Розгрузки"], ["p", "Рюкзаки"], ["c", "Запаси"]]:
		var b := UI.button(String(d[1]), 18, 48)
		b.toggle_mode = true
		b.button_pressed = inv_cat == d[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			inv_cat = String(d[0])
			go("inv", false))
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	if not main.profile.has("eq"):
		list.add_child(UI.label("Підключіться до сервера, щоб побачити склад.", 18, UI.DIM))
		return
	var prof: Dictionary = main.profile
	if inv_cat == "c":
		list.add_child(_inv_row("FPV-дрони", "на складі: %d" % int(prof.get("fpv", 0)), "", ""))
		list.add_child(_inv_row("Гранати", "на складі: %d" % int(prof.get("gren", 0)), "", ""))
		list.add_child(_inv_row("Аптечки", "на складі: %d" % int(prof.get("med", 0)), "", ""))
		for wk in prof.get("mags", {}):
			if Gear.WEAPONS.has(wk):
				list.add_child(_inv_row("Магазини: %s" % Gear.WEAPONS[wk].name, "на складі: %d" % int(prof.mags[wk]), "", ""))
		for hk in prof.get("heavy_ammo", {}):
			if Gear.HEAVY.has(hk):
				list.add_child(_inv_row(String(Gear.HEAVY[hk].ammo_name), "на складі: %d" % int(prof.heavy_ammo[hk]), "", ""))
		return
	var cd := Gear.catalog(inv_cat)
	var any := false
	for k in cd:
		if not prof.owned.has("%s:%s" % [inv_cat, k]):
			continue
		any = true
		var on: bool = String(prof.eq.get(inv_cat, "")) == k
		list.add_child(_inv_row(String(cd[k].name), "вага %.1f кг" % float(cd[k].get("weight", 0.0)), "✓ Одягнено" if on else "Одягнути", "" if on else k))
	if not any:
		list.add_child(UI.label("Нічого немає. Купіть у МАГАЗИНІ.", 18, UI.DIM))


func _inv_row(name: String, sub: String, btn: String, key: String) -> PanelContainer:
	var p := _card(btn.begins_with("✓"))
	var hb := HBoxContainer.new()
	p.add_child(hb)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(v)
	v.add_child(UI.label(name, 20, UI.TEXT))
	v.add_child(UI.label(sub, 15, UI.DIM))
	if btn != "":
		var b := UI.button(btn, 18, 48)
		b.custom_minimum_size = Vector2(190, 48)
		b.disabled = key == ""
		var cat := inv_cat
		b.pressed.connect(func(): main.buy(cat, key, 1))
		hb.add_child(b)
	return p


## Значок ролі (векторний).
class _RoleIcon extends Control:
	const Icons = preload("res://icons.gd")
	var icon := ""

	func _draw() -> void:
		var nm := icon
		if nm == "pkm":
			nm = "rifle"
		Icons.draw(self, nm, Vector2(size.y * 0.6, size.y * 0.5), size.y * 0.9, Color(0.86, 0.74, 0.32))
