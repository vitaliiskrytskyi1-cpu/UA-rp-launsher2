extends Node3D
## Солдат: 3D-модель зі скелетом і процедурною анімацією кісток.
## Дихання, ходьба/біг, присід (на коліно / гусячий крок), нахил корпусу за поглядом,
## утримання і прицілювання зброєю (руки ставляться на зброю через IK), вільні руки.
## Уся математика в просторі персонажа: вперед -Z, праворуч +X, вгору +Y, ноги в нулі.

const Gear = preload("res://gear.gd")
## Моделі завантажуються лише на клієнті (сервер їх не використовує).
static var _soldier_scene: PackedScene
static var _ak_scene: PackedScene
static var _wscenes := {}
## Моделі зброї з текстурами: файл, точка лівої руки (нуль — руків'я).
const WEAPON_MODELS := {
	"ak74": ["res://models/ak47.glb", Vector3(-0.035, 0.035, -0.31)],
	"m4": ["res://models/m4.glb", Vector3(-0.035, 0.045, -0.28)],
	"svd": ["res://models/svd.glb", Vector3(-0.035, 0.02, -0.33)],
}


static func wscene(path: String) -> PackedScene:
	if not _wscenes.has(path):
		_wscenes[path] = load(path)
	return _wscenes[path]

const RIGHT := Vector3(1, 0, 0)
const UP := Vector3(0, 1, 0)
const FWD := Vector3(0, 0, -1)
const DOWN := Vector3(0, -1, 0)
const BACK_Z := Vector3(0, 0, 1)

static var _mats := {}

var team_color := Color.WHITE
var rig: Node3D
var skel: Skeleton3D
var hats: Node3D
var weapon_root: Node3D
var gear_root: Node3D    # рухається разом з грудьми
var hips_gear: Node3D    # рухається разом з тазом
var head_gear: Node3D    # рухається разом з головою
var band_l: Node3D
var band_r: Node3D

var crouch := false
var aiming := false
var look_pitch := 0.0
var _phase := 0.0
var _breath := 0.0
var _crouch_k := 0.0
var _aim_k := 0.0
var _move_k := 0.0
var _eq := {}
var _slot := 0
var _hand_l := Vector3.ZERO   # точки хвату у просторі зброї
var _hand_r := Vector3.ZERO
var _grip_l := 0.0
var _grip_r := 0.0
var _two_hand := true
var _built := false

# дані скелета в спокої (простір персонажа)
var B := {}            # назва -> індекс кістки
var RP: Array = []     # позиції
var RG: Array = []     # обертання
var PAR: Array = []    # батьківська кістка
var _mq_inv := Quaternion.IDENTITY
var _to_skel := Transform3D.IDENTITY
var _fingers_l: Array = []
var _fingers_r: Array = []
var _len_up := 0.25
var _len_lo := 0.3


# ---------------------------------------------------------------- матеріали

static func mat(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	match key:
		"camo":
			m.albedo_color = Color(0.62, 0.58, 0.46)
		"coyote":
			m.albedo_color = Color(0.55, 0.47, 0.34)
		"olive":
			m.albedo_color = Color(0.36, 0.38, 0.27)
		"black":
			m.albedo_color = Color(0.07, 0.07, 0.07)
			m.roughness = 0.55
		"steel":
			m.albedo_color = Color(0.05, 0.05, 0.055)
			m.metallic = 0.8
			m.roughness = 0.4
		"wood":
			m.albedo_color = Color(0.3, 0.15, 0.07)
		"blue":
			m.albedo_color = Color(0.0, 0.34, 0.72)
		"yellow":
			m.albedo_color = Color(1.0, 0.84, 0.0)
		"red":
			m.albedo_color = Color(0.6, 0.08, 0.06)
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _node(parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


# ---------------------------------------------------------------- побудова

func setup(color: Color) -> void:
	team_color = color
	if _soldier_scene == null:
		_soldier_scene = load("res://models/soldier.glb")
		_ak_scene = load("res://models/ak.glb")
	rig = _soldier_scene.instantiate()
	rig.rotation.y = PI   # модель дивиться в +Z, розвертаємо вперед
	add_child(rig)
	var found := rig.find_children("*", "Skeleton3D", true, false)
	skel = found[0] if found.size() > 0 else null
	hats = rig.find_child("Hats", true, false) as Node3D
	_read_rest()

	weapon_root = _node(self)
	gear_root = _node(self)
	hips_gear = _node(self)
	head_gear = _node(self)

	# пов'язки кольору команди на плечах
	var band := StandardMaterial3D.new()
	band.albedo_color = color
	band.emission_enabled = true
	band.emission = color * 0.5
	band_l = _node(self)
	band_r = _node(self)
	for i in 2:
		var holder: Node3D = band_l if i == 0 else band_r
		var side := -1.0 if i == 0 else 1.0
		var c := _cyl(holder, 0.062, 0.05, Vector3.ZERO, band, Vector3(0, 0, PI * 0.5))
		c.set_meta("side", side)
	# шеврон з прапором на лівому плечі
	_box(band_l, Vector3(0.025, 0.01, 0.06), Vector3(0.015, 0.058, 0.0), mat("blue"))
	_box(band_l, Vector3(0.025, 0.01, 0.06), Vector3(-0.01, 0.058, 0.0), mat("yellow"))
	set_gear({"w": "aks74u", "a": "a2", "h": "none", "r": "none", "p": "s", "x": "none"}, 0)
	animate(0.0, 0.0)


func _read_rest() -> void:
	if skel == null:
		return
	# перетворення зі скелета у простір персонажа
	var t := skel.transform
	var n: Node = skel.get_parent()
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	_to_skel = t.affine_inverse()
	var mq := Quaternion(t.basis.orthonormalized())
	_mq_inv = mq.inverse()
	var cnt := skel.get_bone_count()
	RP.resize(cnt)
	RG.resize(cnt)
	PAR.resize(cnt)
	for i in cnt:
		var nm := skel.get_bone_name(i)
		B[nm] = i
		var g := skel.get_bone_global_rest(i)
		RP[i] = t * g.origin
		RG[i] = mq * Quaternion(g.basis.orthonormalized())
		PAR[i] = skel.get_bone_parent(i)
	if B.has("LeftArm") and B.has("LeftForeArm") and B.has("LeftHand"):
		_len_up = (RP[B.LeftForeArm] - RP[B.LeftArm]).length()
		_len_lo = (RP[B.LeftHand] - RP[B.LeftForeArm]).length()
	for f in ["Index", "Middle", "Ring", "Pinky"]:
		for s in [1, 2, 3]:
			var ln := "LeftHand%s%d" % [f, s]
			var rn := "RightHand%s%d" % [f, s]
			if B.has(ln):
				_fingers_l.append([B[ln], s])
			if B.has(rn):
				_fingers_r.append([B[rn], s])


func _bi(nm: String) -> int:
	return B.get(nm, -1)


# ---------------------------------------------------------------- спорядження

func set_gear(eq: Dictionary, slot: int) -> void:
	if eq == _eq and slot == _slot and _built:
		return
	_built = true
	_eq = eq.duplicate()
	_slot = slot
	for root in [gear_root, hips_gear, head_gear, weapon_root]:
		for c in root.get_children():
			c.queue_free()

	# шолом
	var helmet: bool = eq.get("h", "none") == "h1"
	if hats:
		hats.visible = helmet
	if helmet:
		_box(head_gear, Vector3(0.04, 0.03, 0.02), Vector3(0.0, 1.77, -0.125), mat("black"))  # кріплення ПНБ
		for s in [-1.0, 1.0]:
			_cyl(head_gear, 0.045, 0.035, Vector3(s * 0.105, 1.68, 0.02), mat("olive"), Vector3(0, 0, PI * 0.5))  # навушники

	# броня: базова плитоноска вже на моделі, вищі класи додають елементи
	var a: String = eq.get("a", "none")
	if a != "none":
		_box(gear_root, Vector3(0.035, 0.065, 0.03), Vector3(0.13, 1.37, -0.19), mat("red"))  # турнікет
		_box(gear_root, Vector3(0.05, 0.11, 0.04), Vector3(-0.17, 1.35, 0.02), mat("black"))  # рація
		_cyl(gear_root, 0.005, 0.3, Vector3(-0.18, 1.55, 0.06), mat("black"))  # антена
	if a == "a4" or a == "a5":
		for i in 3:
			_box(gear_root, Vector3(0.085, 0.14, 0.055), Vector3(-0.1 + i * 0.1, 1.17, -0.2), mat("coyote"))  # підсумки
	if a == "a5":
		_box(gear_root, Vector3(0.3, 0.08, 0.26), Vector3(0.0, 1.5, 0.02), mat("coyote"))  # комір
		_box(gear_root, Vector3(0.2, 0.15, 0.05), Vector3(0.0, 0.93, -0.15), mat("coyote"))  # пах
		for s in [-1.0, 1.0]:
			_box(gear_root, Vector3(0.11, 0.12, 0.17), Vector3(s * 0.25, 1.43, 0.02), mat("coyote"))  # наплічники

	# розгрузка на поясі
	var r: String = eq.get("r", "none")
	if r != "none":
		var n: int = {"light": 2, "assault": 4}.get(r, 0)
		for i in n:
			var x := -0.16 + i * (0.32 / maxf(1.0, n - 1.0))
			_box(hips_gear, Vector3(0.08, 0.11, 0.06), Vector3(x, 1.0, -0.15), mat("coyote"))
		_box(hips_gear, Vector3(0.36, 0.05, 0.27), Vector3(0.0, 1.06, 0.0), mat("olive"))  # пояс
		if r == "assault":
			_box(hips_gear, Vector3(0.09, 0.13, 0.08), Vector3(-0.19, 0.98, 0.07), mat("coyote"))  # аптечка
			_box(hips_gear, Vector3(0.04, 0.05, 0.02), Vector3(-0.19, 1.0, 0.115), mat("red"))

	# рюкзак
	var p: String = eq.get("p", "none")
	var back_z := 0.22
	if p != "none":
		var ps: Vector3 = {"s": Vector3(0.3, 0.34, 0.14), "m": Vector3(0.35, 0.46, 0.19), "l": Vector3(0.4, 0.62, 0.27)}.get(p, Vector3(0.3, 0.34, 0.14))
		var bz := 0.19 + ps.z * 0.5
		var by := 1.3 - (ps.y - 0.34) * 0.35
		back_z = 0.21 + ps.z + 0.05
		_box(gear_root, ps, Vector3(0.0, by, bz), mat("camo"))
		_box(gear_root, Vector3(ps.x * 0.85, ps.y * 0.4, 0.05), Vector3(0.0, by - ps.y * 0.15, bz + ps.z * 0.5 + 0.02), mat("coyote"))
		_box(gear_root, Vector3(ps.x * 0.9, 0.04, ps.z * 0.9), Vector3(0.0, by + ps.y * 0.5 + 0.02, bz), mat("olive"))
		for s in [-1.0, 1.0]:
			_box(gear_root, Vector3(0.035, ps.y * 0.9, 0.03), Vector3(s * ps.x * 0.3, by, bz + ps.z * 0.5 + 0.03), mat("olive"))

	# важка зброя за спиною
	var hx: String = eq.get("x", "none")
	if hx == "rpg" and slot != 1:
		var hb := _node(gear_root)
		hb.transform = _back_xform(Vector3(-0.45, 0.89, 0.0), Vector3(0.0, 1.28, back_z + 0.02), 0.0)
		_build_rpg_model(hb)
	elif hx == "mortar" and slot != 1:
		var mb := _node(gear_root)
		mb.transform = _back_xform(Vector3(-0.45, 0.89, 0.0), Vector3(0.0, 1.25, back_z + 0.02), 0.0)
		_cyl(mb, 0.045, 0.8, Vector3.ZERO, mat("olive"), Vector3(PI * 0.5, 0.0, 0.0))

	# зброя в руках
	_two_hand = true
	_grip_l = 1.0
	_grip_r = 1.0
	if slot == 0:
		_build_rifle(weapon_root, eq.get("w", "aks74u"))
	elif slot == 1 and hx == "rpg":
		_build_rpg_model(weapon_root)
		_hand_r = Vector3(0.025, 0.0, 0.07)
		_hand_l = Vector3(-0.04, 0.02, -0.16)
	elif slot == 1 and hx == "mortar":
		_cyl(weapon_root, 0.045, 0.8, Vector3(0.0, 0.0, -0.2), mat("olive"), Vector3(PI * 0.5, 0.0, 0.0))
		_cyl(weapon_root, 0.11, 0.02, Vector3(0.0, 0.0, 0.2), mat("olive"), Vector3(PI * 0.5, 0.0, 0.0))  # опорна плита
		_hand_r = Vector3(0.05, -0.06, 0.05)
		_hand_l = Vector3(-0.05, -0.06, -0.3)
	else:
		_two_hand = false
		_grip_l = 0.35
		_grip_r = 0.35
		var back := _node(gear_root)
		back.transform = _back_xform(Vector3(0.5, 0.86, 0.0), Vector3(0.0, 1.22, back_z + (0.07 if hx != "none" else 0.0)), 0.15)
		_build_rifle(back, eq.get("w", "aks74u"))
	_set_fingers()


## Предмет за спиною: ствол дивиться в напрямку dir, лежить пласко на спині.
func _back_xform(dir: Vector3, center: Vector3, shift: float) -> Transform3D:
	var z := -dir.normalized()
	var y := Vector3(0.0, 0.0, 1.0)
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), center - dir.normalized() * shift)


func _build_rpg_model(holder: Node3D) -> void:
	var r: Node3D = wscene("res://models/rpg.glb").instantiate()
	holder.add_child(r)
	# постріл ПГ-7 спереду
	var war := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 0.2
	cone.radial_segments = 12
	war.mesh = cone
	war.material_override = mat("olive")
	war.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	war.position = Vector3(0.0, 0.06, -0.33)
	holder.add_child(war)
	var neck := _cyl(holder, 0.03, 0.08, Vector3(0.0, 0.06, -0.22), mat("olive"), Vector3(PI * 0.5, 0.0, 0.0))
	neck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_rpg(holder: Node3D, rot: Vector3) -> void:
	var tube := _cyl(holder, 0.04, 0.95, Vector3.ZERO, mat("olive"), rot)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var war := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.3
	cone.radial_segments = 10
	war.mesh = cone
	war.material_override = mat("olive")
	if rot.x != 0.0:
		war.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		war.position = Vector3(0.0, 0.0, -0.6)
	else:
		war.position = Vector3(0.0, 0.0, 0.0)
		war.rotation = rot
		war.position = Basis.from_euler(rot) * Vector3(0.0, 0.6, 0.0)
	holder.add_child(war)


func _build_rifle(holder: Node3D, w: String) -> void:
	if WEAPON_MODELS.has(w):
		var wm: Node3D = wscene(WEAPON_MODELS[w][0]).instantiate()
		holder.add_child(wm)
		if holder == weapon_root:
			_hand_r = Vector3(0.025, 0.0, 0.075)
			_hand_l = WEAPON_MODELS[w][1]
		return
	if w == "aks74u":
		var ak: Node3D = _ak_scene.instantiate()
		if w == "aks74u":
			ak.scale = Vector3(1.0, 1.0, 0.86)
		holder.add_child(ak)
		if holder == weapon_root:
			var zf := 0.86 if w == "aks74u" else 1.0
			_hand_r = Vector3(0.025, 0.0, 0.075)
			_hand_l = Vector3(-0.035, -0.035, -0.27 * zf)
		return
	var data: Dictionary = Gear.WEAPONS.get(w, Gear.WEAPONS["aks74u"])
	var L: float = data.len
	var o := Vector3(0.0, 0.07, -0.03)  # точка хвату в нулі, як у моделі АК
	_box(holder, Vector3(0.05, 0.075, L * 0.42), o + Vector3(0.0, 0.0, -L * 0.08), mat("steel"))
	_box(holder, Vector3(0.055, 0.06, L * 0.22), o + Vector3(0.0, -0.005, -L * 0.38), mat("black"))
	_cyl(holder, 0.012, L * 0.4, o + Vector3(0.0, 0.012, -L * 0.62), mat("steel"), Vector3(PI * 0.5, 0.0, 0.0))
	_box(holder, Vector3(0.035, 0.1, 0.045), o + Vector3(0.0, -0.075, 0.04), mat("black"), Vector3(-0.3, 0.0, 0.0))
	var stock_m := mat("wood") if w == "svd" else mat("black")
	_box(holder, Vector3(0.04, 0.085, L * 0.3), o + Vector3(0.0, -0.015, L * 0.22), stock_m)
	match w:
		"pkm":
			_box(holder, Vector3(0.1, 0.12, 0.13), o + Vector3(-0.07, -0.07, -0.06), mat("olive"))
			_box(holder, Vector3(0.015, 0.14, 0.015), o + Vector3(-0.03, -0.08, -L * 0.7), mat("black"), Vector3(0.3, 0.0, 0.2))
			_box(holder, Vector3(0.015, 0.14, 0.015), o + Vector3(0.03, -0.08, -L * 0.7), mat("black"), Vector3(0.3, 0.0, -0.2))
		"svd":
			_cyl(holder, 0.022, 0.26, o + Vector3(0.0, 0.07, -0.05), mat("black"), Vector3(PI * 0.5, 0.0, 0.0))
			_box(holder, Vector3(0.035, 0.12, 0.05), o + Vector3(0.0, -0.09, -0.1), mat("black"), Vector3(-0.2, 0.0, 0.0))
		"m4":
			_box(holder, Vector3(0.035, 0.14, 0.05), o + Vector3(0.0, -0.1, -0.1), mat("black"), Vector3(-0.15, 0.0, 0.0))
			_box(holder, Vector3(0.04, 0.045, 0.1), o + Vector3(0.0, 0.06, -0.02), mat("black"))
		_:
			_box(holder, Vector3(0.035, 0.15, 0.055), o + Vector3(0.0, -0.1, -0.12), mat("black"), Vector3(-0.45, 0.0, 0.0))
	if holder == weapon_root:
		_hand_r = Vector3(0.025, 0.0, 0.075)
		_hand_l = Vector3(-0.035, -0.03, -L * 0.4)


func _set_fingers() -> void:
	if skel == null:
		return
	var curl := {1: 0.75, 2: 1.0, 3: 0.65}
	for i in 2:
		var list: Array = _fingers_l if i == 0 else _fingers_r
		var k := _grip_l if i == 0 else _grip_r
		var sgn := 1.0 if i == 0 else -1.0
		for f in list:
			var e := Quaternion(BACK_Z, sgn * curl[f[1]] * k)
			_set_rel(f[0], e)


# ---------------------------------------------------------------- кістки

## Кістка повернута відносно батька на E (в осях спокою).
func _set_rel(b: int, e: Quaternion) -> void:
	if b < 0:
		return
	var p: int = PAR[b]
	var g: Quaternion = RG[b]
	var l: Quaternion
	if p < 0:
		l = _mq_inv * e * g
	else:
		l = (RG[p] as Quaternion).inverse() * e * g
	skel.set_bone_pose_rotation(b, l)


## Кістка має абсолютний поворот Q відносно спокою; батько має QP.
func _set_abs(b: int, q: Quaternion, qp: Quaternion) -> void:
	if b < 0:
		return
	var p: int = PAR[b]
	var l: Quaternion
	if p < 0:
		l = _mq_inv * q * RG[b]
	else:
		l = (qp * RG[p]).inverse() * (q * RG[b])
	skel.set_bone_pose_rotation(b, l.normalized())


func _child_pos(b: int, pb: int, p_pos: Vector3, p_q: Quaternion) -> Vector3:
	return p_pos + p_q * (RP[b] - RP[pb])


func _frame(b: int, pos: Vector3, q: Quaternion) -> Transform3D:
	return Transform3D(Basis(q), pos - q * RP[b])


## Поворот, що переводить напрям руки зі спокою в цільовий, з площиною згину ліктя.
func _arm_q(d0: Vector3, d1: Vector3, n1: Vector3) -> Quaternion:
	var n0 := d0.cross(FWD).normalized()
	var b0 := Basis(d0, n0, d0.cross(n0))
	var b1 := Basis(d1, n1, d1.cross(n1))
	return Quaternion((b1 * b0.inverse()).orthonormalized())


func _solve_arm(side: String, q_parent: Quaternion, s_pos: Vector3, target: Vector3, pole: Vector3, q_body: Quaternion) -> Quaternion:
	var ia := _bi(side + "Arm")
	var ib := _bi(side + "ForeArm")
	var ic := _bi(side + "Hand")
	if ia < 0 or ib < 0 or ic < 0:
		return q_parent
	var l1 := _len_up
	var l2 := _len_lo
	var to := target - s_pos
	var dist := clampf(to.length(), 0.08, (l1 + l2) * 0.985)
	var dir := to.normalized() if to.length() > 0.001 else DOWN
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var perp := pole - dir * pole.dot(dir)
	if perp.length() < 0.001:
		perp = q_body * DOWN
	perp = perp.normalized()
	var elbow := s_pos + dir * a + perp * h
	var hand := s_pos + dir * dist
	var d1 := (elbow - s_pos).normalized()
	var f1 := (hand - elbow).normalized()
	return _pose_arm(side, q_parent, d1, f1, q_body)


func _pose_arm(side: String, q_parent: Quaternion, d1: Vector3, f1: Vector3, q_body: Quaternion) -> Quaternion:
	var ia := _bi(side + "Arm")
	var ib := _bi(side + "ForeArm")
	var ic := _bi(side + "Hand")
	var d0: Vector3 = (RP[ib] - RP[ia]).normalized()
	var f0: Vector3 = (RP[ic] - RP[ib]).normalized()
	var n1 := d1.cross(f1)
	if n1.length() < 0.02:
		n1 = q_body * d0.cross(FWD)
	n1 = n1.normalized()
	var qa := _arm_q(d0, d1, n1)
	var qf := _arm_q(f0, f1, n1)
	_set_abs(ia, qa, q_parent)
	_set_abs(ib, qf, qa)
	return qa


# ---------------------------------------------------------------- анімація

var prone := false
var lean := 0.0            # -1 вліво, +1 вправо
var sprint := false
var airborne := false
var move_local := Vector2.ZERO   # напрям руху відносно персонажа: x праворуч, y вперед
var _prone_k := 0.0
var _lean_k := 0.0
var _sprint_k := 0.0
var _air_k := 0.0
var _land_t := 0.0
var _speed_s := 0.0
var _dir_s := Vector2(0.0, 1.0)
var _last_yaw := 0.0
var _turn_s := 0.0
var _throw_t := 0.0


func set_pose(is_crouch: bool, is_aiming: bool) -> void:
	crouch = is_crouch
	aiming = is_aiming


func set_move_state(is_prone: bool, lean_v: float, is_sprint: bool, is_air: bool) -> void:
	if airborne and not is_air:
		_land_t = 0.35
	prone = is_prone
	lean = lean_v
	sprint = is_sprint
	airborne = is_air


func throw_grenade() -> void:
	_throw_t = 0.7


func animate(speed: float, delta: float) -> void:
	if skel == null or not is_visible_in_tree():
		return
	var dt := clampf(delta, 0.0, 0.1)
	_crouch_k = move_toward(_crouch_k, 1.0 if (crouch and not prone) else 0.0, dt * 4.5)
	_prone_k = move_toward(_prone_k, 1.0 if prone else 0.0, dt * 2.6)
	_aim_k = move_toward(_aim_k, 1.0 if (aiming and _slot == 0 and not sprint) else 0.0, dt * 7.0)
	_sprint_k = move_toward(_sprint_k, 1.0 if (sprint and not prone) else 0.0, dt * 4.0)
	_lean_k = lerpf(_lean_k, clampf(lean, -1.0, 1.0), clampf(dt * 8.0, 0.0, 1.0))
	_air_k = move_toward(_air_k, 1.0 if airborne else 0.0, dt * 6.0)
	_land_t = maxf(0.0, _land_t - dt)
	_throw_t = maxf(0.0, _throw_t - dt)
	# плавна швидкість і напрям — без ривків між станами
	_speed_s = lerpf(_speed_s, speed, clampf(dt * 7.0, 0.0, 1.0))
	if move_local.length() > 0.1:
		_dir_s = _dir_s.lerp(move_local.normalized(), clampf(dt * 8.0, 0.0, 1.0))
	# поворот на місці — переступання ногами
	var gy := global_rotation.y
	var turn := wrapf(gy - _last_yaw, -PI, PI) / maxf(dt, 0.001)
	_last_yaw = gy
	_turn_s = lerpf(_turn_s, clampf(turn, -6.0, 6.0), clampf(dt * 6.0, 0.0, 1.0))
	var turn_k := clampf((absf(_turn_s) - 0.8) / 3.0, 0.0, 0.35) * clampf(1.0 - _speed_s, 0.0, 1.0)

	var k := clampf(_speed_s / 5.0, 0.0, 1.6)
	var kk := maxf(k, turn_k)
	if kk > 0.03:
		_phase += dt * (4.0 + _speed_s * 1.2 + turn_k * 6.0) * (0.55 if _prone_k > 0.5 else 1.0)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, clampf(dt * 4.0, 0.0, 1.0))
	_breath += dt * (1.6 + _sprint_k * 1.4)
	_move_k = lerpf(_move_k, clampf(k * 3.0, 0.0, 1.0), clampf(dt * 6.0, 0.0, 1.0))
	var c := _crouch_k * (1.0 - _prone_k)
	var pk := _prone_k
	var stand := 1.0 - pk
	var mk := _move_k
	var hold := _slot != 2
	var sk := _sprint_k
	var lk := _lean_k * stand
	var ak := _air_k * stand

	# напрям кроку: вісь махання ноги перпендикулярна руху
	var mdir := Vector3(_dir_s.x, 0.0, -_dir_s.y)
	if mdir.length() < 0.2:
		mdir = FWD
	mdir = mdir.normalized()
	var swing_ax := mdir.cross(UP).normalized()
	var stride := 0.5 + sk * 0.25
	var sw := sin(_phase) * stride * kk
	var lift_l := maxf(0.0, sin(_phase + PI * 0.5)) * (1.0 + sk * 0.5) * kk
	var lift_r := maxf(0.0, sin(_phase - PI * 0.5)) * (1.0 + sk * 0.5) * kk

	# --- таз
	var kneel := c * (1.0 - mk)
	var duck := c * mk
	var bounce := absf(sin(_phase)) * (0.03 + sk * 0.03) * k * (1.0 - c) * stand
	var land := sin(clampf(_land_t / 0.35, 0.0, 1.0) * PI) * 0.12
	var drop := (kneel * 0.44 + duck * 0.3 - bounce + land) * stand
	var hips_off := Vector3(lk * -0.03, -drop + ak * 0.02, kneel * 0.04)
	hips_off = hips_off.lerp(Vector3(0.0, 0.2 - 1.014, 0.25), pk)
	hips_off.x += sin(_phase) * 0.03 * k * stand  # перенесення ваги з ноги на ногу
	var blade := (0.12 if hold else 0.0) * (1.0 - mk * 0.7) * stand
	var hip_roll := sin(_phase) * 0.05 * k * stand
	var q_h := Quaternion(UP, -blade - sin(_phase) * (0.08 + sk * 0.04) * k + pk * sin(_phase) * 0.12 * k) \
		* Quaternion(RIGHT, (-0.06 * k - duck * 0.2 - sk * 0.12) * stand - PI * 0.5 * pk) * Quaternion(BACK_Z, hip_roll)
	var ih := _bi("Hips")
	var p_h: Vector3 = RP[ih] + hips_off
	skel.set_bone_pose_position(ih, _to_skel * p_h)
	_set_abs(ih, q_h, Quaternion.IDENTITY)

	# --- ноги
	var leg_yaw := Quaternion(UP, blade)
	var air_h := ak * 0.55
	var air_kn := ak * 1.0
	var hl := sw * (1.0 - c) * stand + kneel * 1.45 + duck * (0.8 + sw * 0.5) + air_h
	var hr := -sw * (1.0 - c) * stand + kneel * 0.2 + duck * (0.8 - sw * 0.5) + air_h * 0.6
	var kl := lift_l * (1.0 - c) * stand + kneel * 1.45 + duck * (1.3 + lift_l * 0.4) + air_kn + land * 2.0
	var kr := lift_r * (1.0 - c) * stand + kneel * 1.77 + duck * (1.3 + lift_r * 0.4) + air_kn * 0.7 + land * 2.0
	# повзання: ноги по черзі згинаються в сторону
	var crawl_l := maxf(0.0, sin(_phase)) * 0.9 * k * pk
	var crawl_r := maxf(0.0, -sin(_phase)) * 0.9 * k * pk
	var swing_l := Quaternion(swing_ax, hl - (kneel * 1.45 + duck * 0.8 + air_h)) * Quaternion(RIGHT, kneel * 1.45 + duck * 0.8 + air_h)
	var swing_r := Quaternion(swing_ax, hr - (kneel * 0.2 + duck * 0.8 + air_h * 0.6)) * Quaternion(RIGHT, kneel * 0.2 + duck * 0.8 + air_h * 0.6)
	_set_rel(_bi("LeftUpLeg"), leg_yaw * swing_l * Quaternion(BACK_Z, -0.04 - pk * 0.12 - crawl_l * 0.6))
	_set_rel(_bi("RightUpLeg"), leg_yaw * swing_r * Quaternion(BACK_Z, 0.04 + kneel * 0.08 + pk * 0.12 + crawl_r * 0.6))
	_set_rel(_bi("LeftLeg"), Quaternion(RIGHT, -kl - crawl_l * 1.3))
	_set_rel(_bi("RightLeg"), Quaternion(RIGHT, -kr - crawl_r * 1.3))
	_set_rel(_bi("LeftFoot"), Quaternion(RIGHT, clampf(kl - hl, -0.6, 0.9) * (1.0 - kneel) * stand + pk * -0.4))
	_set_rel(_bi("RightFoot"), Quaternion(RIGHT, clampf(kr - hr, -0.6, 0.9) * (1.0 - kneel) * stand + kneel * 0.75 + pk * -0.4))

	# --- корпус
	var lean_f := (0.07 * k + kneel * 0.12 + duck * 0.2 + _aim_k * 0.05 + sk * 0.3) * stand
	var pitch := clampf(look_pitch, -1.2, 1.2) * (1.0 if hold else 0.4)
	var pitch_p := pitch * stand + clampf(look_pitch, -0.3, 0.6) * pk * 0.6
	var br := sin(_breath) * (0.015 + sk * 0.01)
	var twist := blade / 3.0
	var roll := -lk * 0.2 + sin(_phase) * 0.03 * k * stand
	var e_sp := Quaternion(UP, twist) * Quaternion(RIGHT, -lean_f * 0.4 + pitch_p * 0.22 + br + pk * 0.08) * Quaternion(BACK_Z, roll)
	var e_sp1 := Quaternion(UP, twist) * Quaternion(RIGHT, -lean_f * 0.3 + pitch_p * 0.22 - br * 0.5 + pk * 0.06) * Quaternion(BACK_Z, roll)
	var e_sp2 := Quaternion(UP, twist + sin(_phase) * 0.06 * k * stand - _turn_s * 0.02) * Quaternion(RIGHT, -lean_f * 0.3 + pitch_p * 0.22) * Quaternion(BACK_Z, roll)
	var isp := _bi("Spine")
	var isp1 := _bi("Spine1")
	var isp2 := _bi("Spine2")
	_set_rel(isp, e_sp)
	_set_rel(isp1, e_sp1)
	_set_rel(isp2, e_sp2)
	var q_sp := q_h * e_sp
	var q_sp1 := q_sp * e_sp1
	var q_sp2 := q_sp1 * e_sp2
	var p_sp := _child_pos(isp, ih, p_h, q_h)
	var p_sp1 := _child_pos(isp1, isp, p_sp, q_sp)
	var p_sp2 := _child_pos(isp2, isp1, p_sp1, q_sp1)

	# голова: стабілізується, дивиться вперед навіть лежачи
	var ine := _bi("Neck")
	var ihd := _bi("Head")
	var e_ne := Quaternion(RIGHT, pitch * 0.17 * stand - lean_f * 0.2 + pk * 0.75) * Quaternion(BACK_Z, -roll * 1.2)
	var e_hd := Quaternion(RIGHT, pitch * 0.17 * stand - _aim_k * 0.12 + kneel * 0.1 + pk * 0.55) * Quaternion(BACK_Z, -_aim_k * 0.1 + lk * 0.1) \
		* Quaternion(UP, -sin(_phase) * 0.05 * k * stand)
	_set_rel(ine, e_ne)
	_set_rel(ihd, e_hd)
	var q_ne := q_sp2 * e_ne
	var q_hd := q_ne * e_hd
	var p_ne := _child_pos(ine, isp2, p_sp2, q_sp2)
	var p_hd := _child_pos(ihd, ine, p_ne, q_ne)

	gear_root.transform = _frame(isp2, p_sp2, q_sp2)
	hips_gear.transform = _frame(ih, p_h, q_h)
	head_gear.transform = _frame(ihd, p_hd, q_hd)

	# --- зброя
	var wt := Transform3D.IDENTITY
	var bob := sin(_phase * 2.0) * (0.012 + sk * 0.02) * k
	var wpiv: Vector3 = RP[isp2]
	if _slot == 0:
		var ready := Transform3D(Basis(UP, 0.28) * Basis(RIGHT, -0.45), Vector3(0.13, 1.12 + bob, -0.29))
		var aim := Transform3D(Basis(UP, 0.03), Vector3(0.085, 1.45 + bob * 0.3, -0.24))
		var run := Transform3D(Basis(UP, 0.75) * Basis(RIGHT, 0.45) * Basis(BACK_Z, 0.6), Vector3(0.1, 1.18 + bob, -0.24))
		wt = ready.interpolate_with(run, sk).interpolate_with(aim, _aim_k)
	elif _slot == 1 and _eq.get("x", "") == "rpg":
		wt = Transform3D(Basis(RIGHT, 0.04), Vector3(0.15, 1.5 + bob * 0.5, -0.2))
	elif _slot == 1:
		wt = Transform3D(Basis(UP, 0.3) * Basis(RIGHT, 0.7), Vector3(0.08, 1.1 + bob, -0.3))
	# лежачи: зброя вперед, на рівні землі
	var prone_wt := Transform3D(Basis(UP, 0.04), wpiv + Vector3(0.07, -0.08 + bob * 0.5, -0.42))
	var wq := Quaternion(UP, sin(_phase) * 0.03 * k - _turn_s * 0.025) * Quaternion(RIGHT, pitch * 0.66 * stand) * Quaternion(BACK_Z, -lk * 0.25)
	var w_stand := Transform3D(Basis(wq), p_sp2) * Transform3D(Basis(), -wpiv) * wt
	var w_prone := Transform3D(Basis(Quaternion(RIGHT, clampf(look_pitch, -0.2, 0.5) * 0.5)), p_sp2) * Transform3D(Basis(), -wpiv) * prone_wt
	weapon_root.transform = w_stand.interpolate_with(w_prone, pk) if pk > 0.001 else w_stand
	weapon_root.visible = _slot != 2

	# --- руки
	var ish_l := _bi("LeftShoulder")
	var ish_r := _bi("RightShoulder")
	_set_rel(ish_l, Quaternion.IDENTITY)
	_set_rel(ish_r, Quaternion.IDENTITY)
	var q_shl := q_sp2
	var q_shr := q_sp2
	var p_shl := _child_pos(ish_l, isp2, p_sp2, q_sp2)
	var p_shr := _child_pos(ish_r, isp2, p_sp2, q_sp2)
	var p_al := _child_pos(_bi("LeftArm"), ish_l, p_shl, q_shl)
	var p_ar := _child_pos(_bi("RightArm"), ish_r, p_shr, q_shr)
	var qa_l: Quaternion
	var qa_r: Quaternion
	var throwing := _throw_t > 0.0
	if hold or throwing:
		var wtr := weapon_root.transform
		var pole_r := q_sp2 * Vector3(0.7, -1.0, 0.3).lerp(Vector3(1.0, -0.35, 0.3), _aim_k)
		var pole_l := q_sp2 * Vector3(-0.4, -1.0, -0.1)
		var tr := wtr * _hand_r
		if throwing:
			# замах і кидок гранати правою рукою
			var tt := 1.0 - _throw_t / 0.7
			var back_p := p_sp2 + q_sp2 * Vector3(0.22, 0.42, 0.28)
			var front_p := p_sp2 + q_sp2 * Vector3(0.18, 0.2, -0.55)
			tr = back_p.lerp(front_p, smoothstep(0.35, 0.75, tt))
			pole_r = q_sp2 * Vector3(1.0, 0.2, 0.3)
		if hold or throwing:
			qa_r = _solve_arm("Right", q_shr, p_ar, tr, pole_r, q_sp2)
		if hold:
			qa_l = _solve_arm("Left", q_shl, p_al, wtr * _hand_l, pole_l, q_sp2)
	if not hold:
		var asw := sw * 0.9
		var dl := q_sp2 * (Quaternion(RIGHT, -asw) * Vector3(-0.16, -1.0, 0.0).normalized())
		var fl := q_sp2 * (Quaternion(RIGHT, -asw + 0.35 + maxf(0.0, -asw) * 0.6) * Vector3(-0.05, -1.0, 0.0).normalized())
		qa_l = _pose_arm("Left", q_shl, dl, fl, q_sp2)
		if not throwing:
			var dr := q_sp2 * (Quaternion(RIGHT, asw) * Vector3(0.16, -1.0, 0.0).normalized())
			var fr := q_sp2 * (Quaternion(RIGHT, asw + 0.35 + maxf(0.0, asw) * 0.6) * Vector3(0.05, -1.0, 0.0).normalized())
			qa_r = _pose_arm("Right", q_shr, dr, fr, q_sp2)
	# пов'язки на плечах
	var ial := _bi("LeftArm")
	var iar := _bi("RightArm")
	var bl: Vector3 = RP[_bi("LeftForeArm")] - RP[ial]
	var brr: Vector3 = RP[_bi("RightForeArm")] - RP[iar]
	var ra: Vector3 = RP[ial]
	var rb: Vector3 = RP[iar]
	band_l.transform = _frame(ial, p_al, qa_l) * Transform3D(Basis(), ra + bl * 0.42)
	band_r.transform = _frame(iar, p_ar, qa_r) * Transform3D(Basis(), rb + brr * 0.42)
