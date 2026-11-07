extends Control
## Рюкзак: зліва 3D-персонаж у поточному спорядженні з підсвіченими червоним зонами
## влучань і статистикою (здоров'я, броня, шолом, вага, швидкість), справа комірки
## з усім, що є при собі: зброя, набої, магазини, гранати, дрони, важка зброя.

const Icons = preload("res://icons.gd")
const Gear = preload("res://gear.gd")
const Character = preload("res://character.gd")
const HitHud = preload("res://hithud.gd")

## Центри зон у просторі персонажа (стоїть, дивиться в -Z).
const ZONE_POS := [
	[Vector3(0.0, 1.67, -0.02), Vector3(0.14, 0.15, 0.14)],
	[Vector3(0.0, 1.36, -0.03), Vector3(0.22, 0.2, 0.16)],
	[Vector3(0.0, 1.08, -0.02), Vector3(0.19, 0.15, 0.14)],
	[Vector3(-0.29, 1.2, 0.02), Vector3(0.08, 0.26, 0.08)],
	[Vector3(0.29, 1.2, 0.02), Vector3(0.08, 0.26, 0.08)],
	[Vector3(-0.11, 0.55, 0.0), Vector3(0.11, 0.42, 0.11)],
	[Vector3(0.11, 0.55, 0.0), Vector3(0.11, 0.42, 0.11)],
]

var main
var view_box: SubViewportContainer
var viewport: SubViewport
var model: Node3D
var pivot: Node3D
var zone_mats: Array = []
var _rot := 0.0
var _drag := false
var _eq_key := ""


func setup(m) -> void:
	main = m
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


const UI = preload("res://uikit.gd")


func open() -> void:
	if visible:
		return
	_ensure_view()
	_refresh_model()
	UI.fade_in(self)


func close() -> void:
	_close()


func _close() -> void:
	if not visible or modulate.a < 0.99:
		return
	UI.fade_out(self)
	main.on_bag_closed()


func _ensure_view() -> void:
	if view_box:
		return
	view_box = SubViewportContainer.new()
	view_box.stretch = true
	view_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view_box)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	view_box.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.05, -2.75)
	cam.fov = 42.0
	root.add_child(cam)
	cam.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	sun.light_energy = 1.3
	root.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.2, 1.6, -1.5)
	fill.omni_range = 5.0
	fill.light_energy = 0.8
	root.add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.52)
	e.ambient_light_energy = 0.9
	env.environment = e
	root.add_child(env)
	# підставка
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.6
	cm.height = 0.04
	disc.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.2, 0.22, 0.17)
	disc.material_override = dm
	disc.position.y = -0.02
	root.add_child(disc)
	pivot = Node3D.new()
	root.add_child(pivot)
	model = Character.new()
	pivot.add_child(model)
	model.setup(main.team_color(main.my_team))
	# зони влучань
	for i in ZONE_POS.size():
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		mi.position = ZONE_POS[i][0]
		mi.scale = ZONE_POS[i][1]
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.albedo_color = Color(1.0, 0.1, 0.05, 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		zone_mats.append(mat)


func _refresh_model() -> void:
	if model == null or main.soldier == null:
		return
	var eq: Dictionary = main.soldier.eq
	var key := str(eq)
	if key != _eq_key:
		_eq_key = key
		model.set_gear(eq, 0)


func _gui_input(event: InputEvent) -> void:
	var vs := size
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		var p: Vector2 = event.position
		if p.distance_to(Vector2(vs.x - 50.0, 50.0)) < 50.0:
			_close()
		elif p.x < vs.x * 0.42:
			_drag = true
		accept_event()
	elif (event is InputEventMouseButton and not event.pressed) or (event is InputEventScreenTouch and not event.pressed):
		_drag = false
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and _drag):
		if _drag:
			_rot += event.relative.x * 0.012


func _layout() -> void:
	if view_box == null:
		return
	var vs := size
	view_box.position = Vector2(vs.x * 0.02, vs.y * 0.08)
	view_box.size = Vector2(vs.x * 0.24, vs.y * 0.9)


func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	if model:
		_rot += delta * 0.25 if not _drag else 0.0
		pivot.rotation.y = _rot
		model.animate(0.0, delta)
		for i in zone_mats.size():
			var d := float(main.zone_dmg[i])
			var f := float(main.zone_flash[i])
			var a := clampf(d / 60.0, 0.0, 1.0) * 0.45 + (0.25 if d > 0.0 else 0.0) + f * 0.3
			a *= 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
			zone_mats[i].albedo_color = Color(1.0, 0.1, 0.05, clampf(a, 0.0, 0.85))
	queue_redraw()


# ---------------------------------------------------------------- вміст

func _cells() -> Array:
	var cells: Array = []
	var s = main.soldier
	if s == null:
		return cells
	var eq: Dictionary = s.eq
	var wd: Dictionary = s.wdata
	cells.append(["rifle", "%d/%d" % [s.in_mag, int(wd.mag)], wd.name, "%d кг" % int(round(float(wd.weight)))])
	cells.append(["mag", "×%d" % s.mags, "Магазини", "%d набоїв" % (s.mags * int(wd.mag) + s.in_mag)])
	cells.append(["grenade", "×%d" % s.grenades, "Гранати", "до %d" % Gear.grenade_slots(eq)])
	cells.append(["drone", "×%d" % s.drones, "FPV-дрони", "до %d" % Gear.drone_slots(eq)])
	if eq.x != "none":
		var h: Dictionary = Gear.HEAVY[eq.x]
		cells.append([eq.x, "×%d" % s.heavy_ammo, h.name.split(" (")[0], String(h.ammo_name)])
	cells.append(["armor", Gear.ARMOR[eq.a].name.replace("Бронежилет, ", "") if eq.a != "none" else "—", "Броня", "%d кг" % int(Gear.ARMOR[eq.a].weight)])
	cells.append(["helmet", "1" if eq.h != "none" else "—", "Шолом", "%.1f кг" % float(Gear.HELMET[eq.h].weight)])
	cells.append(["rig", "%d" % Gear.mag_capacity(eq), Gear.RIG[eq.r].name, "магазинів"])
	cells.append(["bag", eq.p.to_upper() if eq.p != "none" else "—", Gear.PACK[eq.p].name, "дронів %d" % Gear.drone_slots(eq)])
	return cells


func _bar(pos: Vector2, w: float, k: float, col: Color) -> void:
	draw_rect(Rect2(pos, Vector2(w, 12.0)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(pos, Vector2(w * clampf(k, 0.0, 1.0), 12.0)), col)


func _draw() -> void:
	if main == null:
		return
	var font := ThemeDB.fallback_font
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.04, 0.03, 0.9))
	var s = main.soldier
	if s == null:
		return
	var eq: Dictionary = s.eq

	# ---- статистика (між 3D-персонажем і комірками)
	var sx := vs.x * 0.27
	var y := vs.y * 0.09
	var col_t := Color(1.0, 0.85, 0.3)
	var col := Color(0.9, 0.9, 0.85)
	var fs := int(clampf(vs.y * 0.028, 15.0, 24.0))
	var sw := vs.x * 0.2
	draw_string(font, Vector2(sx, y), "БОЄЦЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 4, col_t)
	y += fs * 1.6
	draw_string(font, Vector2(sx, y), "Здоров'я  %d" % main.my_hp, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	_bar(Vector2(sx, y + 6.0), sw, main.my_hp / 100.0, Color(0.85, 0.2, 0.15))
	y += fs * 2.0
	var ad: Dictionary = Gear.ARMOR[eq.a]
	var at := "Броня: немає" if eq.a == "none" else "Броня: %s, захист %d%%" % [ad.name.replace("Бронежилет, ", ""), int(float(ad.reduce) * 100.0)]
	draw_string(font, Vector2(sx, y), at, HORIZONTAL_ALIGNMENT_LEFT, sw + 40.0, fs, col)
	if eq.a != "none":
		_bar(Vector2(sx, y + 6.0), sw, main.armor_dur / 100.0, Color(0.35, 0.6, 0.95))
		draw_string(font, Vector2(sx + sw + 6.0, y + 17.0), "%d%%" % main.armor_dur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, col)
	y += fs * 2.0
	var ht := "Шолом: немає" if eq.h == "none" else "Шолом: захист голови %d%%" % int(float(Gear.HELMET[eq.h].reduce) * 100.0)
	draw_string(font, Vector2(sx, y), ht, HORIZONTAL_ALIGNMENT_LEFT, sw + 40.0, fs, col)
	if eq.h != "none":
		_bar(Vector2(sx, y + 6.0), sw, main.helm_dur / 100.0, Color(0.35, 0.6, 0.95))
		draw_string(font, Vector2(sx + sw + 6.0, y + 17.0), "%d%%" % main.helm_dur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 4, col)
	y += fs * 2.0
	var w: float = Gear.weight(eq, s.mags, s.drones, s.heavy_ammo, s.grenades)
	draw_string(font, Vector2(sx, y), "Вага  %.1f кг" % w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	y += fs * 1.3
	draw_string(font, Vector2(sx, y), "Швидкість  %d%%" % int(Gear.speed_mult(w) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	_bar(Vector2(sx, y + 6.0), sw, Gear.speed_mult(w) / 1.1, Color(0.4, 0.85, 0.4))
	y += fs * 2.2
	draw_string(font, Vector2(sx, y), "ВЛУЧАННЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, col_t)
	y += fs * 0.6
	HitHud.draw_body(self, Vector2(sx + 34.0, y), fs * 7.5, main.zone_dmg, main.zone_flash, 1.0)
	var ly := y + fs * 0.9
	var any := false
	for i in 8:
		var d := int(main.zone_dmg[i])
		if d <= 0:
			continue
		any = true
		draw_string(font, Vector2(sx + 80.0, ly), "%s  −%d" % [main.ZONE_NAMES[i], d], HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, Color(1.0, 0.45, 0.4))
		ly += fs * 1.05
	if not any:
		draw_string(font, Vector2(sx + 80.0, ly), "без поранень", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 3, Color(0.6, 0.85, 0.6))

	# ---- комірки рюкзака
	var cells := _cells()
	var cols := 3
	var area_x := vs.x * 0.5
	var area_w := vs.x * 0.47
	var gap := 10.0
	var cell := minf((area_w - gap * (cols - 1)) / cols, (vs.y * 0.86 - gap * 2.0) / 3.0)
	var origin := Vector2(area_x, vs.y * 0.1)
	Icons.draw(self, "bag", Vector2(area_x + 20.0, vs.y * 0.05), 34.0, col_t)
	draw_string(font, Vector2(area_x + 46.0, vs.y * 0.05 + 9.0), "СПОРЯДЖЕННЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, col_t)
	for i in cells.size():
		var cx := i % cols
		var cy := i / cols
		var p := origin + Vector2(cx * (cell + gap), cy * (cell * 0.78 + gap))
		var rect := Rect2(p, Vector2(cell, cell * 0.78))
		draw_rect(rect, Color(0.13, 0.15, 0.11, 0.95))
		draw_rect(rect, Color(0.55, 0.57, 0.42, 0.9), false, 2.0)
		var c: Array = cells[i]
		Icons.draw(self, c[0], p + Vector2(cell * 0.5, cell * 0.33), cell * 0.36, Color(0.93, 0.9, 0.8))
		draw_string(font, p + Vector2(0, cell * 0.12), String(c[1]), HORIZONTAL_ALIGNMENT_RIGHT, cell - 8.0, int(cell * 0.12), Color(1, 0.85, 0.3))
		draw_string(font, p + Vector2(4.0, cell * 0.6), String(c[2]), HORIZONTAL_ALIGNMENT_CENTER, cell - 8.0, int(cell * 0.085), Color(0.92, 0.92, 0.88))
		draw_string(font, p + Vector2(4.0, cell * 0.71), String(c[3]), HORIZONTAL_ALIGNMENT_CENTER, cell - 8.0, int(cell * 0.075), Color(0.65, 0.68, 0.6))
	Icons.draw(self, "close", Vector2(vs.x - 50.0, 50.0), 40.0, Color(1, 1, 1, 0.9))
