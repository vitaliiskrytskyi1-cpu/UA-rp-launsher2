extends Node3D
## Модель солдата в камуфляжі зі спорядженням і простою анімацією ходьби.
## Спорядження (шолом, броня, розгрузка, рюкзак, зброя) видно на моделі.

const Gear = preload("res://gear.gd")

static var _camo: ImageTexture
static var _mats := {}

var team_color := Color.WHITE
var leg_l: Node3D
var leg_r: Node3D
var torso: Node3D
var gear_root: Node3D
var weapon_root: Node3D
var _phase := 0.0
var _eq := {}
var _slot := 0


static func camo_texture() -> ImageTexture:
	if _camo:
		return _camo
	var size := 128
	var n1 := FastNoiseLite.new()
	n1.seed = 11
	n1.frequency = 0.045
	var n2 := FastNoiseLite.new()
	n2.seed = 29
	n2.frequency = 0.07
	var n3 := FastNoiseLite.new()
	n3.seed = 47
	n3.frequency = 0.11
	var i1 := n1.get_seamless_image(size, size)
	var i2 := n2.get_seamless_image(size, size)
	var i3 := n3.get_seamless_image(size, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := Color(0.56, 0.51, 0.39)
	var green := Color(0.38, 0.41, 0.28)
	var brown := Color(0.44, 0.35, 0.25)
	var dark := Color(0.22, 0.21, 0.16)
	var light := Color(0.68, 0.64, 0.52)
	for y in size:
		for x in size:
			var a := i1.get_pixel(x, y).r
			var b := i2.get_pixel(x, y).r
			var c := i3.get_pixel(x, y).r
			var col := base
			if a > 0.58:
				col = green
			if b > 0.62:
				col = brown
			if c > 0.7:
				col = dark
			if a < 0.3 and b < 0.4:
				col = light
			img.set_pixel(x, y, col)
	_camo = ImageTexture.create_from_image(img)
	return _camo


static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	match key:
		"camo":
			m.albedo_texture = camo_texture()
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(2.5, 2.5, 2.5)
		"skin": m.albedo_color = Color(0.82, 0.65, 0.52)
		"boot": m.albedo_color = Color(0.16, 0.14, 0.11)
		"coyote": m.albedo_color = Color(0.6, 0.53, 0.4)
		"olive": m.albedo_color = Color(0.33, 0.35, 0.24)
		"black":
			m.albedo_color = Color(0.08, 0.08, 0.08)
			m.roughness = 0.6
		"wood": m.albedo_color = Color(0.4, 0.25, 0.14)
		"rpg": m.albedo_color = Color(0.25, 0.3, 0.2)
		"mortar": m.albedo_color = Color(0.28, 0.31, 0.24)
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, m: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func setup(color: Color) -> void:
	team_color = color
	var band := StandardMaterial3D.new()
	band.albedo_color = color
	band.emission_enabled = true
	band.emission = color * 0.35

	# ноги з тазостегновими шарнірами
	leg_l = Node3D.new()
	leg_l.position = Vector3(-0.11, 0.9, 0.0)
	add_child(leg_l)
	leg_r = Node3D.new()
	leg_r.position = Vector3(0.11, 0.9, 0.0)
	add_child(leg_r)
	for leg in [leg_l, leg_r]:
		_box(leg, Vector3(0.17, 0.48, 0.2), Vector3(0.0, -0.24, 0.0), mat("camo"))
		_box(leg, Vector3(0.15, 0.42, 0.17), Vector3(0.0, -0.66, 0.0), mat("camo"))
		_box(leg, Vector3(0.16, 0.1, 0.28), Vector3(0.0, -0.86, -0.04), mat("boot"))
		_box(leg, Vector3(0.18, 0.12, 0.08), Vector3(0.0, -0.45, -0.11), mat("black"))  # наколінник

	torso = Node3D.new()
	torso.position = Vector3(0.0, 0.9, 0.0)
	add_child(torso)
	_box(torso, Vector3(0.36, 0.14, 0.22), Vector3(0.0, 0.05, 0.0), mat("camo"))  # таз
	_box(torso, Vector3(0.42, 0.52, 0.24), Vector3(0.0, 0.38, 0.0), mat("camo"))  # тулуб
	_sphere(torso, 0.14, Vector3(0.0, 0.8, -0.01), mat("skin"))  # голова
	_box(torso, Vector3(0.2, 0.08, 0.2), Vector3(0.0, 0.66, 0.0), mat("olive"))  # шия / баф
	# руки тримають зброю
	_box(torso, Vector3(0.11, 0.3, 0.12), Vector3(-0.25, 0.48, -0.05), mat("camo"), Vector3(0.6, 0.0, 0.25))
	_box(torso, Vector3(0.11, 0.3, 0.12), Vector3(0.25, 0.48, -0.05), mat("camo"), Vector3(0.6, 0.0, -0.25))
	_box(torso, Vector3(0.1, 0.1, 0.32), Vector3(-0.16, 0.34, -0.3), mat("camo"), Vector3(0.0, -0.35, 0.0))
	_box(torso, Vector3(0.1, 0.1, 0.32), Vector3(0.17, 0.32, -0.28), mat("camo"), Vector3(0.0, 0.3, 0.0))
	# стрічки розпізнавання своїх
	_box(torso, Vector3(0.13, 0.05, 0.14), Vector3(-0.25, 0.58, -0.02), band, Vector3(0.6, 0.0, 0.25))
	_box(torso, Vector3(0.13, 0.05, 0.14), Vector3(0.25, 0.58, -0.02), band, Vector3(0.6, 0.0, -0.25))
	for leg in [leg_l, leg_r]:
		_box(leg, Vector3(0.19, 0.05, 0.22), Vector3(0.0, -0.3, 0.0), band)

	gear_root = Node3D.new()
	torso.add_child(gear_root)
	weapon_root = Node3D.new()
	weapon_root.position = Vector3(0.12, 0.36, -0.42)
	torso.add_child(weapon_root)
	set_gear({"w": "aks74u", "a": "none", "h": "none", "r": "none", "p": "none", "x": "none"}, 0)


func set_gear(eq: Dictionary, slot: int) -> void:
	if eq == _eq and slot == _slot and gear_root.get_child_count() > 0:
		return
	_eq = eq.duplicate()
	_slot = slot
	for c in gear_root.get_children():
		c.queue_free()
	for c in weapon_root.get_children():
		c.queue_free()
	var band := StandardMaterial3D.new()
	band.albedo_color = team_color
	band.emission_enabled = true
	band.emission = team_color * 0.35

	# шолом або кепка
	if eq.get("h", "none") == "h1":
		_sphere(gear_root, 0.19, Vector3(0.0, 0.86, 0.0), mat("camo"), Vector3(1.0, 0.72, 1.08))
		_box(gear_root, Vector3(0.1, 0.03, 0.04), Vector3(0.0, 0.93, -0.18), band)
		_box(gear_root, Vector3(0.06, 0.05, 0.05), Vector3(0.0, 0.92, -0.2), mat("black"))  # кріплення ПНБ
	else:
		_box(gear_root, Vector3(0.3, 0.09, 0.3), Vector3(0.0, 0.9, -0.01), mat("camo"))
		_box(gear_root, Vector3(0.24, 0.02, 0.12), Vector3(0.0, 0.86, -0.18), mat("camo"))

	# бронежилет (плитоноска)
	var a: String = eq.get("a", "none")
	if a != "none":
		var thick: float = {"a2": 0.3, "a4": 0.34, "a5": 0.38}.get(a, 0.3)
		var am := mat("coyote") if a != "a5" else mat("olive")
		_box(gear_root, Vector3(0.46, 0.44, thick), Vector3(0.0, 0.4, 0.0), am)
		if a == "a5":
			_box(gear_root, Vector3(0.3, 0.1, 0.2), Vector3(0.0, 0.66, 0.0), am)  # комір
			_box(gear_root, Vector3(0.26, 0.16, 0.08), Vector3(0.0, 0.05, -0.13), am)  # пах
			_box(gear_root, Vector3(0.14, 0.14, 0.16), Vector3(-0.27, 0.56, 0.0), am)  # плечі
			_box(gear_root, Vector3(0.14, 0.14, 0.16), Vector3(0.27, 0.56, 0.0), am)

	# розгрузка — підсумки на грудях
	var r: String = eq.get("r", "none")
	var pouches: int = {"light": 3, "assault": 5}.get(r, 0)
	for i in pouches:
		var x := -0.16 + i * (0.32 / maxf(1.0, pouches - 1.0))
		_box(gear_root, Vector3(0.08, 0.15, 0.07), Vector3(x, 0.32, -0.2), mat("olive"))
	if r == "assault":
		_box(gear_root, Vector3(0.1, 0.12, 0.1), Vector3(-0.24, 0.12, -0.08), mat("olive"))
		_box(gear_root, Vector3(0.08, 0.1, 0.06), Vector3(0.0, 0.5, -0.2), mat("black"))  # рація

	# рюкзак
	var p: String = eq.get("p", "none")
	if p != "none":
		var ps: Vector3 = {"s": Vector3(0.3, 0.3, 0.14), "m": Vector3(0.36, 0.42, 0.2), "l": Vector3(0.42, 0.6, 0.28)}.get(p, Vector3(0.3, 0.3, 0.14))
		_box(gear_root, ps, Vector3(0.0, 0.45 - (ps.y - 0.3) * 0.3, 0.13 + ps.z * 0.5), mat("olive"))
		_box(gear_root, Vector3(ps.x * 0.8, 0.08, 0.06), Vector3(0.0, 0.45 + ps.y * 0.42, 0.13 + ps.z), mat("coyote"))

	# важка зброя за спиною
	var hx: String = eq.get("x", "none")
	if hx == "rpg" and slot != 1:
		_cyl(gear_root, 0.045, 0.95, Vector3(0.18, 0.5, 0.2), mat("rpg"), Vector3(0.0, 0.0, 0.5))
	elif hx == "mortar" and slot != 1:
		_cyl(gear_root, 0.05, 0.8, Vector3(-0.15, 0.45, 0.24), mat("mortar"), Vector3(0.0, 0.0, -0.4))

	# зброя в руках
	if slot == 0:
		_build_rifle(weapon_root, eq.get("w", "aks74u"))
	elif slot == 1 and hx == "rpg":
		_cyl(weapon_root, 0.045, 0.95, Vector3(0.0, 0.08, 0.0), mat("rpg"), Vector3(PI * 0.5, 0.0, 0.0))
		var war := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07
		cone.height = 0.3
		war.mesh = cone
		war.material_override = mat("olive")
		war.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		war.position = Vector3(0.0, 0.08, -0.62)
		weapon_root.add_child(war)
	elif slot == 1 and hx == "mortar":
		_cyl(weapon_root, 0.05, 0.8, Vector3(0.0, 0.0, 0.0), mat("mortar"), Vector3(PI * 0.35, 0.0, 0.0))
	else:
		_build_rifle(gear_root, eq.get("w", "aks74u"), true)


func _build_rifle(parent: Node3D, w: String, on_back: bool = false) -> void:
	var holder := Node3D.new()
	parent.add_child(holder)
	if on_back:
		holder.position = Vector3(0.0, 0.42, 0.2)
		holder.rotation = Vector3(0.0, PI * 0.5, 0.9)
	var data: Dictionary = Gear.WEAPONS.get(w, Gear.WEAPONS["aks74u"])
	var L: float = data.len
	_box(holder, Vector3(0.055, 0.08, L * 0.55), Vector3(0.0, 0.0, -L * 0.15), mat("black"))  # ствольна коробка
	_cyl(holder, 0.013, L * 0.45, Vector3(0.0, 0.015, -L * 0.62), mat("black"), Vector3(PI * 0.5, 0.0, 0.0))  # ствол
	var stock_m := mat("wood") if w == "ak74" or w == "svd" else mat("black")
	_box(holder, Vector3(0.045, 0.09, L * 0.3), Vector3(0.0, -0.01, L * 0.25), stock_m)  # приклад
	match w:
		"pkm":
			_box(holder, Vector3(0.1, 0.12, 0.12), Vector3(-0.07, -0.06, -0.1), mat("olive"))  # короб
			_box(holder, Vector3(0.02, 0.1, 0.02), Vector3(0.0, -0.08, -L * 0.75), mat("black"))  # сошки
		"svd":
			_cyl(holder, 0.022, 0.26, Vector3(0.0, 0.07, -0.08), mat("black"), Vector3(PI * 0.5, 0.0, 0.0))  # приціл
			_box(holder, Vector3(0.04, 0.12, 0.06), Vector3(0.0, -0.09, -0.12), mat("black"), Vector3(-0.2, 0.0, 0.0))
		"m4":
			_box(holder, Vector3(0.04, 0.14, 0.05), Vector3(0.0, -0.1, -0.12), mat("black"), Vector3(-0.15, 0.0, 0.0))
			_box(holder, Vector3(0.04, 0.04, 0.1), Vector3(0.0, 0.065, -0.05), mat("black"))  # коліматор
		_:
			_box(holder, Vector3(0.04, 0.16, 0.06), Vector3(0.0, -0.11, -0.14), mat("black"), Vector3(-0.45, 0.0, 0.0))  # ріжок


func animate(speed: float, delta: float) -> void:
	if leg_l == null:
		return
	var k := clampf(speed / 5.0, 0.0, 1.4)
	if k > 0.05:
		_phase += delta * (5.0 + speed * 1.2)
	else:
		_phase = lerpf(_phase, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	var sw := sin(_phase) * 0.55 * k
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	torso.position.y = 0.9 + absf(sin(_phase)) * 0.03 * k
