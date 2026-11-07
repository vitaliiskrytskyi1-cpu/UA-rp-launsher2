extends RefCounted
## Побудова мапи. Генерація детермінована (фіксований seed),
## тому сервер і всі клієнти мають однакову мапу.
## visuals = false — лише колізії (для сервера без графіки).
## Текстури Poly Haven (CC0) завантажуються при збірці в папку res://tex/.

const HALF := 150.0
const BASE_Z := 120.0
const TRENCH_Z := [-86.0, -44.0, 44.0, 86.0]
const TRENCH_W := 2.4
const TRENCH_D := 1.9
const TRENCH_X := 140.0

static var _mats := {}


static func tex_mat(name: String, fallback: Color, scale: float = 0.25, tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, str(scale), str(tint)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	var p := "res://tex/%s_diff_1k.jpg" % name
	if name != "" and ResourceLoader.exists(p):
		m.albedo_texture = load(p)
		m.albedo_color = tint
		var n := "res://tex/%s_nor_gl_1k.jpg" % name
		if ResourceLoader.exists(n):
			m.normal_enabled = true
			m.normal_texture = load(n)
			m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(scale, scale, scale)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		m.albedo_color = fallback
	_mats[key] = m
	return m


static func _col_box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	b.rotation = rot
	parent.add_child(b)


static func _col_shape(parent: Node3D, shape: Shape3D, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)


static func _vis_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, visuals: bool, rot: Vector3 = Vector3.ZERO) -> void:
	_col_box(parent, size, pos, rot)
	if visuals:
		_vis_box(parent, size, pos, mat, rot)


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

	var m_ground := tex_mat("forrest_ground_01", Color(0.34, 0.39, 0.22), 0.22, Color(0.95, 1.0, 0.9))
	var m_field := tex_mat("dry_mud_field_001", Color(0.42, 0.36, 0.24), 0.12)
	var m_mud := tex_mat("brown_mud_02", Color(0.3, 0.24, 0.17), 0.4)
	var m_plank := tex_mat("weathered_brown_planks", Color(0.42, 0.32, 0.22), 0.45)
	var m_bag := tex_mat("hessian_230", Color(0.56, 0.5, 0.36), 0.8, Color(0.85, 0.78, 0.6))
	var m_hesco := tex_mat("hessian_380", Color(0.5, 0.46, 0.34), 0.5, Color(0.8, 0.74, 0.58))
	var m_wall := tex_mat("damaged_plaster", Color(0.62, 0.6, 0.56), 0.35)
	var m_roof := tex_mat("roof_planks", Color(0.36, 0.22, 0.16), 0.4)
	var m_bark := tex_mat("bark_brown_02", Color(0.3, 0.22, 0.15), 0.8)
	var m_leaf := tex_mat("forest_leaves_02", Color(0.19, 0.33, 0.14), 0.6, Color(0.55, 0.85, 0.45))
	var m_bush := tex_mat("forest_leaves_02", Color(0.24, 0.36, 0.16), 0.9, Color(0.6, 0.8, 0.45))
	var m_pole := tex_mat("", Color(0.25, 0.25, 0.25))

	# ---------------------------------------------------------------- небо, світло
	if visuals:
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = Color(0.38, 0.52, 0.7)
		psm.sky_horizon_color = Color(0.72, 0.75, 0.78)
		psm.ground_horizon_color = Color(0.55, 0.55, 0.5)
		psm.ground_bottom_color = Color(0.3, 0.3, 0.26)
		psm.sun_angle_max = 20.0
		sky.sky_material = psm
		env.sky = sky
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.75
		env.fog_enabled = true
		env.fog_light_color = Color(0.68, 0.71, 0.74)
		env.fog_density = 0.006
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.05
		var we := WorldEnvironment.new()
		we.environment = env
		w.add_child(we)

		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-42.0, 35.0, 0.0)
		sun.light_energy = 1.25
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 60.0
		w.add_child(sun)

	# ---------------------------------------------------------------- земля з викопаними окопами
	var full := HALF + 30.0
	var edges: Array = [-full]
	for tz in TRENCH_Z:
		edges.append(tz - TRENCH_W * 0.5)
		edges.append(tz + TRENCH_W * 0.5)
	edges.append(full)
	var i := 0
	while i < edges.size():
		var z0: float = edges[i]
		var z1: float = edges[i + 1]
		var seg := z1 - z0
		_col_box(w, Vector3(full * 2.0, 4.0, seg), Vector3(0.0, -2.0, (z0 + z1) * 0.5))
		if visuals:
			_vis_box(w, Vector3(full * 2.0, 4.0, seg), Vector3(0.0, -2.0, (z0 + z1) * 0.5), m_ground)
		i += 2
	for tz in TRENCH_Z:
		# земля за кінцями окопу
		for s in [-1.0, 1.0]:
			var cx: float = s * (TRENCH_X + (full - TRENCH_X) * 0.5)
			_box(w, Vector3(full - TRENCH_X, 4.0, TRENCH_W), Vector3(cx, -2.0, tz), m_ground, visuals)
		# дно окопу
		_box(w, Vector3(TRENCH_X * 2.0, 1.0, TRENCH_W), Vector3(0.0, -TRENCH_D - 0.5, tz), m_mud, visuals)
		if visuals:
			# дерев'яні укріплення стінок
			for side in [-1.0, 1.0]:
				_vis_box(w, Vector3(TRENCH_X * 2.0, TRENCH_D, 0.06), Vector3(0.0, -TRENCH_D * 0.5, tz + side * (TRENCH_W * 0.5 - 0.03)), m_plank)
			# стійки
			var post_xf: Array = []
			var px := -TRENCH_X
			while px < TRENCH_X:
				for side in [-1.0, 1.0]:
					post_xf.append(Transform3D(Basis(), Vector3(px, -TRENCH_D * 0.5 + 0.1, tz + side * (TRENCH_W * 0.5 - 0.08))))
				px += 2.5
			var pm := BoxMesh.new()
			pm.size = Vector3(0.12, TRENCH_D + 0.2, 0.1)
			_multi(w, pm, m_bark, post_xf)
		# виходи з окопу (пандуси)
		var ex := -120.0
		while ex <= 120.0:
			var ang := atan2(TRENCH_D, 4.4)
			_box(w, Vector3(4.8, 0.3, TRENCH_W - 0.1), Vector3(ex, -TRENCH_D * 0.5 - 0.1, tz), m_mud, visuals, Vector3(0.0, 0.0, ang))
			ex += 40.0

	# ---------------------------------------------------------------- бруствери з мішків (з боку противника) і бліндажі
	var bag_xf: Array = []
	var bag_size := Vector3(3.0, 0.55, 0.9)
	for tz in TRENCH_Z:
		var toward: float = -signf(tz)  # напрямок до центру мапи
		var pz: float = tz + toward * (TRENCH_W * 0.5 + 0.5)
		var k := -46
		while k <= 46:
			if posmod(k, 4) != 0:  # бійниці
				var x := k * 3.0 + rng.randf_range(-0.1, 0.1)
				var pos := Vector3(x, bag_size.y * 0.5, pz)
				_col_box(w, bag_size, pos)
				bag_xf.append(Transform3D(Basis(), pos))
				bag_xf.append(Transform3D(Basis(), pos + Vector3(0.0, 0.5, toward * 0.15)).scaled_local(Vector3(1.0, 0.9, 0.8)))
			k += 1
		# бліндажі: накат з колод над окопом
		var dx := -112.0
		while dx <= 112.0:
			_col_box(w, Vector3(4.2, 0.45, TRENCH_W + 1.4), Vector3(dx, 0.2, tz))
			if visuals:
				var log_m := CylinderMesh.new()
				log_m.top_radius = 0.16
				log_m.bottom_radius = 0.17
				log_m.height = TRENCH_W + 1.4
				log_m.radial_segments = 8
				var log_xf: Array = []
				var lx := dx - 1.9
				while lx <= dx + 1.95:
					log_xf.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(lx, 0.12, tz)))
					lx += 0.34
				_multi(w, log_m, m_bark, log_xf)
				_vis_box(w, Vector3(4.4, 0.35, TRENCH_W + 1.6), Vector3(dx, 0.45, tz), m_mud)
			dx += 56.0
	if visuals:
		var bm := BoxMesh.new()
		bm.size = bag_size
		_multi(w, bm, m_bag, bag_xf)

	# ---------------------------------------------------------------- поля
	for f in 8:
		var fx := rng.randf_range(-120.0, 120.0)
		var fz := rng.randf_range(-100.0, 100.0)
		var fs := Vector3(rng.randf_range(20.0, 45.0), 0.02, rng.randf_range(10.0, 25.0))
		var fr := rng.randf_range(-0.3, 0.3)
		if visuals:
			var ok := true
			for tz in TRENCH_Z:
				if absf(fz - tz) < fs.z * 0.5 + 3.0:
					ok = false
			if ok:
				_vis_box(w, fs, Vector3(fx, 0.012, fz), m_field, Vector3(0.0, fr, 0.0))

	# ---------------------------------------------------------------- межі мапи
	for s in [-1.0, 1.0]:
		_col_box(w, Vector3(HALF * 2.0, 40.0, 2.0), Vector3(0.0, 20.0, s * HALF))
		_col_box(w, Vector3(2.0, 40.0, HALF * 2.0), Vector3(s * HALF, 20.0, 0.0))

	# ---------------------------------------------------------------- лісосмуги
	var trunk_xf: Array = []
	var crown_xf: Array = []
	var bush_xf: Array = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.25
	trunk_shape.height = 6.0
	var crown_shape := SphereShape3D.new()
	crown_shape.radius = 1.8
	var rows: Array = []
	for s in [-1.0, 1.0]:
		rows.append([Vector3(-140.0, 0.0, s * 20.0), Vector3(140.0, 0.0, s * 20.0)])
		rows.append([Vector3(-140.0, 0.0, s * 66.0), Vector3(140.0, 0.0, s * 66.0)])
		rows.append([Vector3(s * 62.0, 0.0, -38.0), Vector3(s * 62.0, 0.0, 38.0)])
		rows.append([Vector3(s * 100.0, 0.0, s * 92.0), Vector3(s * 100.0, 0.0, s * 140.0)])
	for r in rows:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var side := Vector3(-dir.z, 0.0, dir.x)
		var t := 0.0
		while t < length:
			t += rng.randf_range(3.5, 6.5)
			var skip := rng.randf() < 0.12
			var p := a + dir * t + side * rng.randf_range(-1.5, 1.5)
			var bush_off := rng.randf_range(-3.0, 3.0)
			var sc := rng.randf_range(0.8, 1.35)
			var rot := rng.randf_range(0.0, TAU)
			if skip:
				continue
			var in_trench := false
			for tz in TRENCH_Z:
				if absf(p.z - tz) < 3.5:
					in_trench = true
			if in_trench:
				continue
			_col_shape(w, trunk_shape, p + Vector3(0.0, 3.0, 0.0))
			_col_shape(w, crown_shape, p + Vector3(0.0, 5.8 * sc, 0.0))
			trunk_xf.append(Transform3D(Basis().scaled(Vector3(1.0, sc, 1.0)), p + Vector3(0.0, 3.0 * sc, 0.0)))
			var cb := Basis(Vector3.UP, rot)
			crown_xf.append(Transform3D(cb.scaled(Vector3(sc, sc * 1.1, sc)), p + Vector3(0.0, 5.8 * sc, 0.0)))
			crown_xf.append(Transform3D(cb.scaled(Vector3(sc * 0.75, sc * 0.8, sc * 0.75)), p + Vector3(0.9 * sc, 4.8 * sc, 0.4)))
			crown_xf.append(Transform3D(cb.scaled(Vector3(sc * 0.7, sc * 0.75, sc * 0.7)), p + Vector3(-0.8 * sc, 4.6 * sc, -0.5)))
			bush_xf.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(1.5, 0.9, 1.5)), p + side * bush_off + Vector3(0.0, 0.7, 0.0)))
	if visuals:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.17
		cm.bottom_radius = 0.3
		cm.height = 6.0
		cm.radial_segments = 7
		_multi(w, cm, m_bark, trunk_xf)
		var sm := SphereMesh.new()
		sm.radius = 2.1
		sm.height = 4.2
		sm.radial_segments = 9
		sm.rings = 6
		_multi(w, sm, m_leaf, crown_xf)
		var bush := SphereMesh.new()
		bush.radius = 1.0
		bush.height = 2.0
		bush.radial_segments = 8
		bush.rings = 5
		_multi(w, bush, m_bush, bush_xf)

	# ---------------------------------------------------------------- зруйновані будинки (дзеркально)
	for h in 7:
		var hx := rng.randf_range(-120.0, 120.0)
		var hz := rng.randf_range(26.0, 35.0)
		var rot := rng.randf_range(-0.4, 0.4)
		var ruin := rng.randf_range(0.5, 1.0)
		var roof := rng.randf() < 0.5
		for s in [-1.0, 1.0]:
			_house(w, Vector3(hx * s, 0.0, hz * s), rot, ruin, roof, m_wall, m_roof, visuals)

	# ---------------------------------------------------------------- бази
	for s in [-1.0, 1.0]:
		var bz: float = s * BASE_Z
		for k in range(-7, 8):
			if k == 0 or k == -4 or k == 4:
				continue
			_box(w, Vector3(3.0, 2.2, 1.6), Vector3(k * 3.3, 1.1, bz - s * 14.0), m_hesco, visuals)
		for side in [-1.0, 1.0]:
			for k in range(-3, 4):
				_box(w, Vector3(1.6, 2.2, 3.0), Vector3(side * 34.0, 1.1, bz + k * 3.3), m_hesco, visuals)
		_box(w, Vector3(8.0, 2.6, 5.0), Vector3(0.0, 1.3, bz + s * 10.0), m_hesco, visuals)
		if visuals:
			_vis_box(w, Vector3(0.12, 7.0, 0.12), Vector3(6.0, 3.5, bz + s * 6.0), m_pole)
			var flag_m := tex_mat("", Color(0.2, 0.45, 1.0) if s < 0.0 else Color(1.0, 0.8, 0.15))
			_vis_box(w, Vector3(0.05, 1.1, 1.8), Vector3(6.0, 6.3, bz + s * 6.0 - 0.95), flag_m)
			# ящики з боєприпасами (магазин спорядження)
			for k in 3:
				_vis_box(w, Vector3(1.2, 0.6, 0.6), Vector3(-6.0 + k * 1.4, 0.3, bz + s * 6.0), tex_mat("", Color(0.3, 0.34, 0.22)))

	# ---------------------------------------------------------------- центральна точка захоплення
	for k in 10:
		if k % 3 == 2:
			continue
		var ang := TAU * k / 10.0
		var p := Vector3(cos(ang) * 7.0, 0.55, sin(ang) * 7.0)
		_box(w, Vector3(3.0, 1.1, 0.9), p, m_bag, visuals, Vector3(0.0, -ang + PI * 0.5, 0.0))
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
		_vis_box(w, Vector3(0.05, 1.2, 2.0), Vector3(0.0, 7.3, -1.0), tex_mat("", Color(0.9, 0.9, 0.9)))

		# воронки
		var crater_xf: Array = []
		for c in 45:
			var p := Vector3(rng.randf_range(-130.0, 130.0), 0.015, rng.randf_range(-100.0, 100.0))
			var sc := rng.randf_range(1.0, 2.8)
			crater_xf.append(Transform3D(Basis().scaled(Vector3(sc, 1.0, sc)), p))
		var crm := CylinderMesh.new()
		crm.top_radius = 1.0
		crm.bottom_radius = 1.0
		crm.height = 0.02
		crm.radial_segments = 12
		_multi(w, crm, m_mud, crater_xf)
	return w


static func _house(w: Node3D, c: Vector3, rot: float, ruin: float, roof: bool, m_wall: Material, m_roof: Material, visuals: bool) -> void:
	var node := Node3D.new()
	node.position = c
	node.rotation.y = rot
	w.add_child(node)
	var h := 3.0 * ruin + 0.6
	var t := 0.3
	_box(node, Vector3(8.0, h, t), Vector3(0.0, h * 0.5, -3.0), m_wall, visuals)
	_box(node, Vector3(t, h, 6.0), Vector3(-4.0, h * 0.5, 0.0), m_wall, visuals)
	_box(node, Vector3(t, h * 0.8, 6.0), Vector3(4.0, h * 0.4, 0.0), m_wall, visuals)
	_box(node, Vector3(3.0, h, t), Vector3(-2.5, h * 0.5, 3.0), m_wall, visuals)
	_box(node, Vector3(3.0, h, t), Vector3(2.5, h * 0.5, 3.0), m_wall, visuals)
	if roof:
		_box(node, Vector3(8.4, 0.25, 4.0), Vector3(0.0, h + 0.1, -1.0), m_roof, visuals)
