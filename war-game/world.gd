extends RefCounted
## Побудова мапи. Генерація детермінована (фіксований seed),
## тому сервер і всі клієнти мають однакову мапу.
## visuals = false — лише колізії (для сервера без графіки).

const HALF := 150.0
const BASE_Z := 120.0


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


static func _col_box(parent: Node3D, size: Vector3, pos: Vector3, rot_y: float = 0.0) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	b.rotation.y = rot_y
	parent.add_child(b)


static func _col_shape(parent: Node3D, shape: Shape3D, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)


static func _vis_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, visuals: bool, rot_y: float = 0.0) -> void:
	_col_box(parent, size, pos, rot_y)
	if visuals:
		_vis_box(parent, size, pos, mat, rot_y)


static func _multi(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


static func build(parent: Node, visuals: bool) -> Node3D:
	var w := Node3D.new()
	w.name = "World"
	parent.add_child(w)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107

	var m_ground := _mat(Color(0.34, 0.39, 0.22))
	var m_field := _mat(Color(0.42, 0.36, 0.24))
	var m_bag := _mat(Color(0.56, 0.5, 0.36))
	var m_wall := _mat(Color(0.58, 0.56, 0.52))
	var m_roof := _mat(Color(0.36, 0.22, 0.16))
	var m_trunk := _mat(Color(0.3, 0.22, 0.15))
	var m_leaf := _mat(Color(0.19, 0.33, 0.14))
	var m_bush := _mat(Color(0.24, 0.36, 0.16))
	var m_hesco := _mat(Color(0.5, 0.46, 0.34))
	var m_crater := _mat(Color(0.22, 0.19, 0.15))
	var m_pole := _mat(Color(0.25, 0.25, 0.25))

	# ---------------------------------------------------------------- небо, світло
	if visuals:
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = Color(0.42, 0.56, 0.74)
		psm.sky_horizon_color = Color(0.74, 0.77, 0.8)
		psm.ground_horizon_color = Color(0.55, 0.55, 0.5)
		psm.ground_bottom_color = Color(0.3, 0.3, 0.26)
		sky.sky_material = psm
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.9
		env.fog_enabled = true
		env.fog_light_color = Color(0.72, 0.75, 0.78)
		env.fog_density = 0.005
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new()
		we.environment = env
		w.add_child(we)

		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
		sun.light_energy = 1.15
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 70.0
		w.add_child(sun)

		var ground := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(HALF * 2.0 + 60.0, HALF * 2.0 + 60.0)
		ground.mesh = pm
		ground.material_override = m_ground
		w.add_child(ground)

		# Розорані поля
		for i in 8:
			var fx := rng.randf_range(-120.0, 120.0)
			var fz := rng.randf_range(-100.0, 100.0)
			_vis_box(w, Vector3(rng.randf_range(20.0, 45.0), 0.02, rng.randf_range(15.0, 35.0)), Vector3(fx, 0.01, fz), m_field, rng.randf_range(-0.3, 0.3))
	else:
		# Тримаємо rng синхронним незалежно від visuals
		for i in 8:
			rng.randf_range(-120.0, 120.0)
			rng.randf_range(-100.0, 100.0)
			rng.randf_range(20.0, 45.0)
			rng.randf_range(15.0, 35.0)
			rng.randf_range(-0.3, 0.3)

	# ---------------------------------------------------------------- земля і межі
	_col_box(w, Vector3(HALF * 2.0 + 60.0, 2.0, HALF * 2.0 + 60.0), Vector3(0.0, -1.0, 0.0))
	for s in [-1.0, 1.0]:
		_col_box(w, Vector3(HALF * 2.0, 40.0, 2.0), Vector3(0.0, 20.0, s * HALF))
		_col_box(w, Vector3(2.0, 40.0, HALF * 2.0), Vector3(s * HALF, 20.0, 0.0))

	# ---------------------------------------------------------------- окопи (лінії мішків з піском)
	var bag_xf: Array = []
	var bag_size := Vector3(4.0, 1.15, 0.9)
	for s in [-1.0, 1.0]:
		for line_z in [44.0, 86.0]:
			for i in range(-34, 35):
				if posmod(i, 6) == 0:
					continue  # проходи
				var x := i * 4.0 + rng.randf_range(-0.3, 0.3)
				var rot := rng.randf_range(-0.08, 0.08)
				for off in [0.0, 1.9]:
					var z: float = s * (line_z + off)
					var pos := Vector3(x, bag_size.y * 0.5, z)
					_col_box(w, bag_size, pos, rot)
					bag_xf.append(Transform3D(Basis(Vector3.UP, rot), pos))
	if visuals:
		var bm := BoxMesh.new()
		bm.size = bag_size
		_multi(w, bm, m_bag, bag_xf)

	# ---------------------------------------------------------------- лісосмуги
	var trunk_xf: Array = []
	var crown_xf: Array = []
	var bush_xf: Array = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.25
	trunk_shape.height = 5.0
	var crown_shape := SphereShape3D.new()
	crown_shape.radius = 1.8
	var rows: Array = []
	for s in [-1.0, 1.0]:
		rows.append([Vector3(-140.0, 0.0, s * 20.0), Vector3(140.0, 0.0, s * 20.0)])
		rows.append([Vector3(-140.0, 0.0, s * 66.0), Vector3(140.0, 0.0, s * 66.0)])
		rows.append([Vector3(s * 62.0, 0.0, -100.0), Vector3(s * 62.0, 0.0, 100.0)])
	for r in rows:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		var t := 0.0
		while t < length:
			t += rng.randf_range(4.0, 7.5)
			var skip := rng.randf() < 0.14
			var p := a + dir * t + side * rng.randf_range(-1.5, 1.5)
			var bush_off := rng.randf_range(-3.0, 3.0)
			var sc := rng.randf_range(0.8, 1.3)
			if skip:
				continue
			_col_shape(w, trunk_shape, p + Vector3(0.0, 2.5, 0.0))
			_col_shape(w, crown_shape, p + Vector3(0.0, 5.2 * sc, 0.0))
			trunk_xf.append(Transform3D(Basis().scaled(Vector3(1.0, sc, 1.0)), p + Vector3(0.0, 2.5 * sc, 0.0)))
			crown_xf.append(Transform3D(Basis().scaled(Vector3(sc, sc * 1.15, sc)), p + Vector3(0.0, 5.2 * sc, 0.0)))
			bush_xf.append(Transform3D(Basis().scaled(Vector3(1.4, 0.8, 1.4)), p + side * bush_off + Vector3(0.0, 0.7, 0.0)))
	if visuals:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.28
		cm.height = 5.0
		cm.radial_segments = 6
		_multi(w, cm, m_trunk, trunk_xf)
		var sm := SphereMesh.new()
		sm.radius = 2.2
		sm.height = 4.4
		sm.radial_segments = 8
		sm.rings = 5
		_multi(w, sm, m_leaf, crown_xf)
		var bush := SphereMesh.new()
		bush.radius = 1.0
		bush.height = 2.0
		bush.radial_segments = 7
		bush.rings = 4
		_multi(w, bush, m_bush, bush_xf)

	# ---------------------------------------------------------------- зруйновані будинки (дзеркально для обох сторін)
	for i in 7:
		var hx := rng.randf_range(-120.0, 120.0)
		var hz := rng.randf_range(26.0, 38.0)
		var rot := rng.randf_range(-0.4, 0.4)
		var ruin := rng.randf_range(0.5, 1.0)
		var roof := rng.randf() < 0.5
		for s in [-1.0, 1.0]:
			_house(w, Vector3(hx * s, 0.0, hz * s), rot, ruin, roof, m_wall, m_roof, visuals)

	# ---------------------------------------------------------------- бази
	for s in [-1.0, 1.0]:
		var bz: float = s * BASE_Z
		for i in range(-7, 8):
			if i == 0 or i == -4 or i == 4:
				continue
			_box(w, Vector3(3.0, 2.2, 1.6), Vector3(i * 3.3, 1.1, bz - s * 14.0), m_hesco, visuals)
		for side in [-1.0, 1.0]:
			for k in range(-3, 4):
				_box(w, Vector3(1.6, 2.2, 3.0), Vector3(side * 34.0, 1.1, bz + k * 3.3), m_hesco, visuals)
		_box(w, Vector3(8.0, 2.6, 5.0), Vector3(0.0, 1.3, bz + s * 10.0), m_hesco, visuals)
		if visuals:
			_vis_box(w, Vector3(0.12, 7.0, 0.12), Vector3(6.0, 3.5, bz + s * 6.0), m_pole)
			var flag_m := _mat(Color(0.2, 0.45, 1.0) if s < 0.0 else Color(1.0, 0.8, 0.15))
			_vis_box(w, Vector3(0.05, 1.1, 1.8), Vector3(6.0, 6.3, bz + s * 6.0 - 0.95), flag_m)

	# ---------------------------------------------------------------- центральна точка захоплення
	for k in 10:
		if k % 3 == 2:
			continue
		var ang := TAU * k / 10.0
		var p := Vector3(cos(ang) * 7.0, 0.575, sin(ang) * 7.0)
		_box(w, Vector3(3.0, 1.15, 0.9), p, m_bag, visuals, -ang + PI * 0.5)
	if visuals:
		var ring := MeshInstance3D.new()
		ring.name = "CapRing"
		var rm := CylinderMesh.new()
		rm.top_radius = 14.0
		rm.bottom_radius = 14.0
		rm.height = 0.04
		rm.radial_segments = 40
		ring.mesh = rm
		var ring_m := StandardMaterial3D.new()
		ring_m.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
		ring_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = ring_m
		ring.position = Vector3(0.0, 0.03, 0.0)
		w.add_child(ring)
		_vis_box(w, Vector3(0.14, 8.0, 0.14), Vector3(0.0, 4.0, 0.0), m_pole)
		var cflag := _vis_box(w, Vector3(0.05, 1.2, 2.0), Vector3(0.0, 7.3, -1.0), _mat(Color(0.9, 0.9, 0.9)))
		cflag.name = "CapFlag"

		# Воронки
		var crater_xf: Array = []
		for i in 40:
			var p := Vector3(rng.randf_range(-130.0, 130.0), 0.02, rng.randf_range(-100.0, 100.0))
			var sc := rng.randf_range(1.0, 2.6)
			crater_xf.append(Transform3D(Basis().scaled(Vector3(sc, 1.0, sc)), p))
		var crm := CylinderMesh.new()
		crm.top_radius = 1.0
		crm.bottom_radius = 1.0
		crm.height = 0.02
		crm.radial_segments = 12
		_multi(w, crm, m_crater, crater_xf)
	return w


static func _house(w: Node3D, c: Vector3, rot: float, ruin: float, roof: bool, m_wall: Material, m_roof: Material, visuals: bool) -> void:
	var node := Node3D.new()
	node.position = c
	node.rotation.y = rot
	w.add_child(node)
	var h := 3.0 * ruin + 0.6
	var t := 0.3
	# задня і бічні стіни
	_box(node, Vector3(8.0, h, t), Vector3(0.0, h * 0.5, -3.0), m_wall, visuals)
	_box(node, Vector3(t, h, 6.0), Vector3(-4.0, h * 0.5, 0.0), m_wall, visuals)
	_box(node, Vector3(t, h * 0.8, 6.0), Vector3(4.0, h * 0.4, 0.0), m_wall, visuals)
	# передня стіна з дверним прорізом
	_box(node, Vector3(3.0, h, t), Vector3(-2.5, h * 0.5, 3.0), m_wall, visuals)
	_box(node, Vector3(3.0, h, t), Vector3(2.5, h * 0.5, 3.0), m_wall, visuals)
	if roof:
		_box(node, Vector3(8.4, 0.25, 4.0), Vector3(0.0, h + 0.1, -1.0), m_roof, visuals)
