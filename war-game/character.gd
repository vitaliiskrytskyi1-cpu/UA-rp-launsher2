extends Node3D
## Модель солдата: піксельний камуфляж, шолом з навушниками, балаклава,
## плитоноска з підсумками і рацією, рюкзак, наколінники, рукавиці, берці.
## Скелет із шарнірами (плечі, лікті, стегна, коліна) і процедурна анімація:
## дихання, ходьба/біг з рухом рук, присідання, утримання і прицілювання зброєю.

const Gear = preload("res://gear.gd")

static var _camo: ImageTexture
static var _mats := {}

var team_color := Color.WHITE
var hips: Node3D
var spine: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var kn_l: Node3D
var kn_r: Node3D
var gear_root: Node3D
var weapon_root: Node3D

var crouch := false
var aiming := false
var _phase := 0.0
var _breath := 0.0
var _crouch_k := 0.0
var _eq := {}
var _slot := 0


# ---------------------------------------------------------------- матеріали

static func camo_texture() -> ImageTexture:
	if _camo:
		return _camo
	var size := 128
	var block := 4
	var n1 := FastNoiseLite.new()
	n1.seed = 14
	n1.frequency = 0.09
	var n2 := FastNoiseLite.new()
	n2.seed = 77
	n2.frequency = 0.14
	var n3 := FastNoiseLite.new()
	n3.seed = 5
	n3.frequency = 0.2
	var i1 := n1.get_seamless_image(size / block, size / block)
	var i2 := n2.get_seamless_image(size / block, size / block)
	var i3 := n3.get_seamless_image(size / block, size / block)
	var base := Color(0.69, 0.65, 0.51)
	var sand := Color(0.58, 0.54, 0.4)
	var olive := Color(0.42, 0.44, 0.31)
	var dark := Color(0.28, 0.28, 0.21)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for by in size / block:
		for bx in size / block:
			var a := i1.get_pixel(bx, by).r
			var b := i2.get_pixel(bx, by).r
			var c := i3.get_pixel(bx, by).r
			var col := base
			if a > 0.52:
				col = sand
			if b > 0.58:
				col = olive
			if c > 0.66 and b > 0.45:
				col = dark
			img.fill_rect(Rect2i(bx * block, by * block, block, block), col)
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
			m.uv1_scale = Vector3(3.0, 3.0, 3.0)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		"skin":
			m.albedo_color = Color(0.8, 0.62, 0.5)
		"boot":
			m.albedo_color = Color(0.72, 0.58, 0.4)
		"sole":
			m.albedo_color = Color(0.2, 0.17, 0.13)
		"olive":
			m.albedo_color = Color(0.36, 0.38, 0.27)
		"helmet":
			m.albedo_color = Color(0.4, 0.42, 0.3)
			m.roughness = 0.7
		"glove":
			m.albedo_color = Color(0.3, 0.32, 0.22)
		"black":
			m.albedo_color = Color(0.07, 0.07, 0.07)
			m.roughness = 0.55
		"wood":
			m.albedo_color = Color(0.38, 0.24, 0.13)
		"blue":
			m.albedo_color = Color(0.0, 0.34, 0.72)
		"yellow":
			m.albedo_color = Color(1.0, 0.84, 0.0)
		"red":
			m.albedo_color = Color(0.6, 0.08, 0.06)
		"glass":
			m.albedo_color = Color(0.12, 0.1, 0.06)
			m.roughness = 0.15
			m.metallic = 0.5
	_mats[key] = m
	return m


# ---------------------------------------------------------------- примітиви

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


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
	sm.radial_segments = 14
	sm.rings = 7
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
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Сегмент кінцівки, що звисає вниз від шарніра.
func _limb(parent: Node3D, r: float, h: float, m: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = m
	mi.position = Vector3(0.0, -h * 0.5 + r * 0.6, 0.0)
	mi.scale = sc
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- побудова

func setup(color: Color) -> void:
	team_color = color
	var band := StandardMaterial3D.new()
	band.albedo_color = color
	band.emission_enabled = true
	band.emission = color * 0.4

	hips = _node(self, Vector3(0.0, 0.94, 0.0))
	_box(hips, Vector3(0.34, 0.16, 0.22), Vector3(0.0, 0.0, 0.0), mat("camo"))
	# ремінь з підсумками
	_box(hips, Vector3(0.37, 0.06, 0.25), Vector3(0.0, 0.07, 0.0), mat("olive"))
	_box(hips, Vector3(0.09, 0.12, 0.08), Vector3(-0.19, 0.0, -0.06), mat("camo"))
	_box(hips, Vector3(0.09, 0.12, 0.08), Vector3(0.19, 0.0, -0.06), mat("camo"))

	# ноги
	hip_l = _node(hips, Vector3(-0.1, -0.04, 0.0))
	hip_r = _node(hips, Vector3(0.1, -0.04, 0.0))
	for side in [-1.0, 1.0]:
		var hp: Node3D = hip_l if side < 0.0 else hip_r
		_limb(hp, 0.085, 0.48, mat("camo"))
		_box(hp, Vector3(0.07, 0.14, 0.05), Vector3(side * 0.07, -0.24, -0.02), mat("camo"))  # кишеня
		_box(hp, Vector3(0.18, 0.04, 0.19), Vector3(0.0, -0.12, 0.0), band)  # стрічка
		var kn := _node(hp, Vector3(0.0, -0.44, 0.0))
		_limb(kn, 0.07, 0.44, mat("camo"))
		_sphere(kn, 0.075, Vector3(0.0, -0.02, -0.06), mat("olive"), Vector3(1.0, 1.1, 0.7))  # наколінник
		_box(kn, Vector3(0.12, 0.13, 0.26), Vector3(0.0, -0.41, -0.04), mat("boot"))  # берець
		_box(kn, Vector3(0.13, 0.03, 0.28), Vector3(0.0, -0.48, -0.04), mat("sole"))
		if side < 0.0:
			kn_l = kn
		else:
			kn_r = kn

	# тулуб
	spine = _node(hips, Vector3(0.0, 0.06, 0.0))
	var chest := _sphere(spine, 0.2, Vector3(0.0, 0.3, 0.0), mat("camo"), Vector3(1.15, 1.45, 0.75))
	chest.name = "Chest"
	_cyl(spine, 0.06, 0.08, Vector3(0.0, 0.58, 0.0), mat("camo"))  # шия

	# голова
	head = _node(spine, Vector3(0.0, 0.7, 0.0))
	_sphere(head, 0.115, Vector3(0.0, 0.0, 0.0), mat("skin"), Vector3(0.95, 1.1, 1.0))
	_sphere(head, 0.118, Vector3(0.0, -0.035, -0.005), mat("camo"), Vector3(0.98, 0.75, 1.02))  # балаклава
	_box(head, Vector3(0.17, 0.04, 0.03), Vector3(0.0, 0.025, -0.11), mat("glass"))  # окуляри

	# руки
	sh_l = _node(spine, Vector3(-0.23, 0.5, 0.0))
	sh_r = _node(spine, Vector3(0.23, 0.5, 0.0))
	for side in [-1.0, 1.0]:
		var sh: Node3D = sh_l if side < 0.0 else sh_r
		_sphere(sh, 0.08, Vector3.ZERO, mat("camo"))
		_limb(sh, 0.065, 0.32, mat("camo"))
		_box(sh, Vector3(0.15, 0.035, 0.15), Vector3(0.0, -0.1, 0.0), band)  # стрічка
		if side < 0.0:
			# шеврон з прапором на лівому плечі
			_box(sh, Vector3(0.012, 0.03, 0.08), Vector3(-0.065, -0.05, 0.0), mat("blue"))
			_box(sh, Vector3(0.012, 0.03, 0.08), Vector3(-0.065, -0.08, 0.0), mat("yellow"))
		var el := _node(sh, Vector3(0.0, -0.29, 0.0))
		_limb(el, 0.055, 0.28, mat("camo"))
		_sphere(el, 0.055, Vector3(0.0, -0.27, 0.0), mat("glove"), Vector3(0.9, 1.1, 1.0))  # рукавиця
		if side < 0.0:
			el_l = el
		else:
			el_r = el

	gear_root = _node(spine, Vector3.ZERO)
	weapon_root = _node(spine, Vector3(0.06, 0.32, -0.3))
	set_gear({"w": "aks74u", "a": "a2", "h": "none", "r": "none", "p": "s", "x": "none"}, 0)


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
	band.emission = team_color * 0.4

	# шолом з навушниками або панама
	var hd := _node(gear_root, head.position)
	if eq.get("h", "none") == "h1":
		_sphere(hd, 0.15, Vector3(0.0, 0.05, 0.005), mat("helmet"), Vector3(1.0, 0.78, 1.08))
		_box(hd, Vector3(0.26, 0.02, 0.2), Vector3(0.0, 0.02, 0.0), mat("helmet"))  # край
		for s in [-1.0, 1.0]:
			_box(hd, Vector3(0.015, 0.03, 0.14), Vector3(s * 0.145, 0.04, 0.0), mat("black"))  # рейки
			_cyl(hd, 0.05, 0.04, Vector3(s * 0.13, -0.03, 0.0), mat("olive"), Vector3(0.0, 0.0, PI * 0.5))  # навушники
		_box(hd, Vector3(0.05, 0.05, 0.03), Vector3(0.0, 0.07, -0.16), mat("black"))  # кріплення ПНБ
		_box(hd, Vector3(0.08, 0.03, 0.02), Vector3(0.0, 0.12, 0.14), band)
	else:
		_cyl(hd, 0.125, 0.09, Vector3(0.0, 0.07, 0.0), mat("camo"))
		_cyl(hd, 0.2, 0.012, Vector3(0.0, 0.035, 0.0), mat("camo"))  # поля панами

	# плитоноска
	var a: String = eq.get("a", "none")
	if a != "none":
		var am := mat("camo")
		var depth: float = {"a2": 0.31, "a4": 0.34, "a5": 0.37}.get(a, 0.31)
		_box(gear_root, Vector3(0.42, 0.42, depth), Vector3(0.0, 0.32, 0.0), am)
		_box(gear_root, Vector3(0.06, 0.06, depth + 0.02), Vector3(-0.15, 0.53, 0.0), mat("olive"))  # лямки
		_box(gear_root, Vector3(0.06, 0.06, depth + 0.02), Vector3(0.15, 0.53, 0.0), mat("olive"))
		_box(gear_root, Vector3(0.44, 0.08, depth + 0.03), Vector3(0.0, 0.16, 0.0), mat("olive"))  # камербанд
		# потрійний підсумок під магазини
		for i in 3:
			_box(gear_root, Vector3(0.1, 0.15, 0.06), Vector3(-0.11 + i * 0.11, 0.24, -depth * 0.5 - 0.03), mat("camo"))
		_box(gear_root, Vector3(0.05, 0.08, 0.03), Vector3(0.13, 0.42, -depth * 0.5 - 0.015), mat("red"))  # турнікет
		_box(gear_root, Vector3(0.05, 0.1, 0.04), Vector3(0.17, 0.44, 0.0), mat("black"))  # рація
		_cyl(gear_root, 0.006, 0.28, Vector3(0.18, 0.6, 0.02), mat("black"))  # антена
		if a == "a5":
			_box(gear_root, Vector3(0.32, 0.1, 0.24), Vector3(0.0, 0.6, 0.0), am)  # комір
			_box(gear_root, Vector3(0.22, 0.16, 0.06), Vector3(0.0, -0.02, -0.14), am)  # пах
			for s in [-1.0, 1.0]:
				_box(gear_root, Vector3(0.12, 0.14, 0.16), Vector3(s * 0.27, 0.48, 0.0), am)  # наплічники

	# розгрузка
	var r: String = eq.get("r", "none")
	if r != "none":
		var n: int = {"light": 2, "assault": 4}.get(r, 0)
		for i in n:
			_box(gear_root, Vector3(0.09, 0.12, 0.07), Vector3(-0.2 + i * (0.4 / maxf(1.0, n - 1.0)), 0.08, -0.15), mat("camo"))
		if r == "assault":
			_box(gear_root, Vector3(0.1, 0.14, 0.08), Vector3(-0.21, 0.02, 0.06), mat("camo"))  # аптечка
			_box(gear_root, Vector3(0.04, 0.05, 0.03), Vector3(-0.21, 0.05, 0.11), mat("red"))

	# рюкзак
	var p: String = eq.get("p", "none")
	if p != "none":
		var ps: Vector3 = {"s": Vector3(0.3, 0.34, 0.15), "m": Vector3(0.36, 0.46, 0.2), "l": Vector3(0.42, 0.62, 0.28)}.get(p, Vector3(0.3, 0.34, 0.15))
		var bz := 0.16 + ps.z * 0.5
		var by := 0.42 - (ps.y - 0.34) * 0.35
		_box(gear_root, ps, Vector3(0.0, by, bz), mat("camo"))
		_box(gear_root, Vector3(ps.x * 0.85, ps.y * 0.4, 0.05), Vector3(0.0, by - ps.y * 0.15, bz + ps.z * 0.5 + 0.02), mat("camo"))  # кишеня
		_box(gear_root, Vector3(ps.x * 0.9, 0.04, ps.z * 0.9), Vector3(0.0, by + ps.y * 0.5 + 0.02, bz), mat("olive"))
		for s in [-1.0, 1.0]:
			_box(gear_root, Vector3(0.035, ps.y * 0.9, 0.03), Vector3(s * ps.x * 0.3, by, bz + ps.z * 0.5 + 0.03), mat("olive"))  # стропи

	# важка зброя за спиною
	var hx: String = eq.get("x", "none")
	if hx == "rpg" and slot != 1:
		_cyl(gear_root, 0.045, 0.95, Vector3(0.2, 0.42, 0.24), mat("olive"), Vector3(0.0, 0.0, 0.5))
	elif hx == "mortar" and slot != 1:
		_cyl(gear_root, 0.05, 0.8, Vector3(-0.17, 0.4, 0.26), mat("olive"), Vector3(0.0, 0.0, -0.4))

	# зброя
	if slot == 0:
		_build_rifle(weapon_root, eq.get("w", "aks74u"))
	elif slot == 1 and hx == "rpg":
		_cyl(weapon_root, 0.045, 0.95, Vector3(0.0, 0.0, 0.05), mat("olive"), Vector3(PI * 0.5, 0.0, 0.0))
		var war := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.07
		cone.height = 0.3
		war.mesh = cone
		war.material_override = mat("olive")
		war.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		war.position = Vector3(0.0, 0.0, -0.57)
		weapon_root.add_child(war)
	elif slot == 1 and hx == "mortar":
		_cyl(weapon_root, 0.05, 0.8, Vector3(0.0, 0.0, 0.0), mat("olive"), Vector3(PI * 0.35, 0.0, 0.0))
	else:
		var back := _node(gear_root, Vector3(0.0, 0.38, 0.2))
		back.rotation = Vector3(0.0, PI * 0.5, 0.9)
		_build_rifle(back, eq.get("w", "aks74u"))


func _build_rifle(holder: Node3D, w: String) -> void:
	var data: Dictionary = Gear.WEAPONS.get(w, Gear.WEAPONS["aks74u"])
	var L: float = data.len
	_box(holder, Vector3(0.05, 0.075, L * 0.42), Vector3(0.0, 0.0, -L * 0.08), mat("black"))  # ствольна коробка
	_box(holder, Vector3(0.055, 0.06, L * 0.22), Vector3(0.0, -0.005, -L * 0.38), mat("black") if w != "ak74" else mat("wood"))  # цівка
	_cyl(holder, 0.012, L * 0.4, Vector3(0.0, 0.012, -L * 0.62), mat("black"), Vector3(PI * 0.5, 0.0, 0.0))  # ствол
	_box(holder, Vector3(0.035, 0.1, 0.045), Vector3(0.0, -0.075, 0.04), mat("black"), Vector3(-0.3, 0.0, 0.0))  # руків'я
	var stock_m := mat("wood") if w == "svd" else mat("black")
	_box(holder, Vector3(0.04, 0.085, L * 0.3), Vector3(0.0, -0.015, L * 0.22), stock_m)  # приклад
	match w:
		"pkm":
			_box(holder, Vector3(0.1, 0.12, 0.13), Vector3(-0.07, -0.07, -0.06), mat("olive"))
			_box(holder, Vector3(0.015, 0.14, 0.015), Vector3(-0.03, -0.08, -L * 0.7), mat("black"), Vector3(0.3, 0.0, 0.2))
			_box(holder, Vector3(0.015, 0.14, 0.015), Vector3(0.03, -0.08, -L * 0.7), mat("black"), Vector3(0.3, 0.0, -0.2))
		"svd":
			_cyl(holder, 0.022, 0.26, Vector3(0.0, 0.07, -0.05), mat("black"), Vector3(PI * 0.5, 0.0, 0.0))
			_box(holder, Vector3(0.035, 0.12, 0.05), Vector3(0.0, -0.09, -0.1), mat("black"), Vector3(-0.2, 0.0, 0.0))
		"m4":
			_box(holder, Vector3(0.035, 0.14, 0.05), Vector3(0.0, -0.1, -0.1), mat("black"), Vector3(-0.15, 0.0, 0.0))
			_box(holder, Vector3(0.04, 0.045, 0.1), Vector3(0.0, 0.06, -0.02), mat("black"))
		_:
			_box(holder, Vector3(0.035, 0.15, 0.055), Vector3(0.0, -0.1, -0.12), mat("black"), Vector3(-0.45, 0.0, 0.0))  # ріжок
			_box(holder, Vector3(0.035, 0.03, 0.07), Vector3(0.0, 0.052, -0.02), mat("black"))  # коліматор


# ---------------------------------------------------------------- анімація

func set_pose(is_crouch: bool, is_aiming: bool) -> void:
	crouch = is_crouch
	aiming = is_aiming


func animate(speed: float, delta: float) -> void:
	if hips == null:
		return
	_crouch_k = move_toward(_crouch_k, 1.0 if crouch else 0.0, delta * 6.0)
	var k := clampf(speed / 5.0, 0.0, 1.5)
	if k > 0.05:
		_phase += delta * (4.5 + speed * 1.3)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(delta * 5.0, 0.0, 1.0))
	_breath += delta * 1.6
	var sw := sin(_phase) * 0.6 * k
	var lift_l := maxf(0.0, sin(_phase + PI * 0.5)) * 1.0 * k
	var lift_r := maxf(0.0, sin(_phase - PI * 0.5)) * 1.0 * k
	var c := _crouch_k

	# ноги
	hips.position.y = 0.94 - c * 0.36 + absf(sin(_phase)) * 0.03 * k
	hip_l.rotation.x = sw + c * 1.25
	hip_r.rotation.x = -sw + c * 1.0
	kn_l.rotation.x = -lift_l - c * 2.0
	kn_r.rotation.x = -lift_r - c * 1.7
	hip_r.rotation.z = c * 0.1

	# корпус
	spine.rotation.x = -0.08 * k - c * 0.25
	spine.rotation.y = sin(_phase) * 0.06 * k
	var br := sin(_breath) * 0.012
	spine.scale = Vector3(1.0 + br, 1.0, 1.0 + br)

	# руки: тримання зброї / вільні
	if _slot == 0 or _slot == 1:
		var raise := 0.35 if aiming else 0.0
		if _slot == 1 and _eq.get("x", "") == "rpg":
			raise = 0.6
		weapon_root.position = Vector3(0.06, 0.32 + raise * 0.4, -0.3 + raise * 0.1)
		weapon_root.rotation.x = 0.0
		sh_r.rotation = Vector3(0.55 + raise, 0.0, 0.25)
		el_r.rotation = Vector3(1.25 - raise * 0.5, 0.0, 0.0)
		sh_l.rotation = Vector3(1.05 + raise, 0.0, -0.45)
		el_l.rotation = Vector3(0.5, 0.0, 0.0)
		weapon_root.position.y += sin(_phase * 2.0) * 0.01 * k
	else:
		sh_l.rotation = Vector3(-sw * 0.8, 0.0, -0.08)
		sh_r.rotation = Vector3(sw * 0.8, 0.0, 0.08)
		el_l.rotation = Vector3(0.3 + maxf(0.0, -sw) * 0.5, 0.0, 0.0)
		el_r.rotation = Vector3(0.3 + maxf(0.0, sw) * 0.5, 0.0, 0.0)
	head.rotation.x = c * 0.2
