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
const Settings = preload("res://settings.gd")

## Карти. «field» — генерована лінія фронту, решта — 3D-скани хуторів Фарерських островів
## (Національний музей Фарер, CC0). half — половина розміру, base — відстань баз від центру.
const MAPS := [
	{"id": "front", "name": "Фронт", "file": "front", "half": 200.0, "hz": 200.0, "b0": Vector2(0.0, -172.0), "b1": Vector2(0.0, 172.0), "base_r": 20.0, "cap": 14.0, "hmin": -12.0},
]
const Front = preload("res://front.gd")
static var cur: Dictionary = MAPS[0]
static var cur_index := 0
## Груба карта висот (сітка 1 м) — для точок появи без запитів до фізики.
static var _hgrid := PackedFloat32Array()
static var _hw := 0
static var _hh := 0
static var _hx0 := 0.0
static var _hz0 := 0.0


static func map_count() -> int:
	return MAPS.size()


## Центр бази команди (x, z).
static func base_pos(team: int) -> Vector2:
	var k := "b%d" % team
	if cur.has(k):
		return cur[k]
	var bz := float(cur.get("base", 120.0))
	return Vector2(0.0, -bz if team == 0 else bz)


## Висота землі в точці (x, z) за колізією світу; якщо землі немає — fallback.
static func ground_y(w: Node3D, x: float, z: float, fallback: float = 0.0) -> float:
	if String(cur.id) == "front":
		return Front.height(x, z)
	if cur.has("file") and _hw > 0:
		var gx := int(floor(x - _hx0))
		var gz := int(floor(z - _hz0))
		if gx >= 0 and gz >= 0 and gx < _hw and gz < _hh:
			var v := _hgrid[gz * _hw + gx]
			if v > -9000.0:
				return v
		return fallback
	if w == null or not w.is_inside_tree():
		return fallback
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 300.0, z), Vector3(x, -300.0, z))
	q.collision_mask = 1
	var hit := w.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return fallback
	return hit.position.y


static func _env(w: Node3D, fog: float) -> void:
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
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.71, 0.74)
	env.fog_density = fog
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
	sun.add_to_group("sun")
	sun.shadow_enabled = int(Settings.value("graphics", "shadows", 1)) == 1
	w.add_child(sun)


static func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si)
			if m is StandardMaterial3D:
				var sm := m as StandardMaterial3D
				sm.metallic = 0.0
				sm.metallic_specular = 0.12
				sm.roughness = 1.0
				sm.albedo_color = Color(0.86, 0.86, 0.84)
	for c in n.get_children():
		_no_shadows(c)


## Карта зі скану: рельєф і будівлі — зі скану, колізія — зі спрощеної копії (файл .bin).
static func _build_scan(parent: Node, visuals: bool) -> Node3D:
	var w := Node3D.new()
	w.name = "World"
	parent.add_child(w)
	var file: String = cur.file
	var f := FileAccess.open("res://maps/%s_col.bin" % file, FileAccess.READ)
	if f:
		var n := f.get_32()
		var faces := PackedVector3Array()
		faces.resize(n * 3)
		for i in n * 3:
			faces[i] = Vector3(f.get_float(), f.get_float(), f.get_float())
		f.close()
		_build_hgrid(faces)
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(faces)
		_col_shape(w, sh, Vector3.ZERO)
	else:
		push_warning("map collision missing: " + file)
		_col_box(w, Vector3(400.0, 2.0, 400.0), Vector3(0.0, -1.0, 0.0))
	# невидимі межі карти
	var hx: float = cur.half
	var hz: float = cur.hz
	for s in [-1.0, 1.0]:
		_col_box(w, Vector3(1.0, 300.0, hz * 2.0), Vector3(s * (hx - 1.5), 0.0, 0.0))
		_col_box(w, Vector3(hx * 2.0, 300.0, 1.0), Vector3(0.0, 0.0, s * (hz - 1.5)))
	if not cur.has("no_bags"):
		_scan_trenches(w, visuals)
	_scan_props(w, visuals)
	if visuals:
		_env(w, 0.004)
		var we := w.get_child(w.get_child_count() - 2) as WorldEnvironment
		if we:
			we.environment.tonemap_exposure = 0.92
			we.environment.ambient_light_energy = 0.7
		var scn = load("res://maps/%s.glb" % file)
		if scn:
			var terrain: Node3D = scn.instantiate()
			w.add_child(terrain)
			_no_shadows(terrain)
		if cur.has("floor"):
			_floor_fill(w, file)
		# море/долина навколо, щоб не було порожнечі за краєм
		var sea := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1600.0, 1600.0)
		sea.mesh = pm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.13, 0.22, 0.27)
		sm.roughness = 0.25
		sm.metallic = 0.3
		sea.material_override = sm
		sea.position.y = float(cur.get("hmin", -10.0)) - 2.0
		w.add_child(sea)
	return w


static func _build_hgrid(faces: PackedVector3Array) -> void:
	var hx: float = cur.half
	var hz: float = cur.hz
	_hx0 = -hx
	_hz0 = -hz
	_hw = int(ceil(hx * 2.0)) + 1
	_hh = int(ceil(hz * 2.0)) + 1
	_hgrid = PackedFloat32Array()
	_hgrid.resize(_hw * _hh)
	_hgrid.fill(-9999.0)
	var i := 0
	while i + 2 < faces.size():
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		i += 3
		var y := maxf(a.y, maxf(b.y, c.y))
		var x0 := int(floor(minf(a.x, minf(b.x, c.x)) - _hx0))
		var x1 := int(floor(maxf(a.x, maxf(b.x, c.x)) - _hx0))
		var z0 := int(floor(minf(a.z, minf(b.z, c.z)) - _hz0))
		var z1 := int(floor(maxf(a.z, maxf(b.z, c.z)) - _hz0))
		for gz in range(maxi(z0, 0), mini(z1, _hh - 1) + 1):
			for gx in range(maxi(x0, 0), mini(x1, _hw - 1) + 1):
				var k := gz * _hw + gx
				if y > _hgrid[k]:
					_hgrid[k] = y


## Лінії укріплень на скані: бруствери з мішків з піском і дерев'яні стійки, по рельєфу.
## По одній лінії перед кожною базою (поперек напрямку на точку) і дві короткі біля центру.
## Земля між модулями карти «Окопи» (прямокутники з maps/<file>_floor.json).
static func _floor_fill(w: Node3D, file: String) -> void:
	var f := FileAccess.open("res://maps/%s_floor.json" % file, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return
	var y := float(d.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for r in d.rects:
		var x0 := float(r[0])
		var z0 := float(r[1])
		var x1 := x0 + float(r[2])
		var z1 := z0 + float(r[3])
		for v in [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]:
			st.set_uv(Vector2(v.x, v.z) * 0.25)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := tex_mat("forrest_ground_01", Color(0.34, 0.39, 0.22), 0.25, Color(0.95, 1.0, 0.9))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	w.add_child(mi)


## Бронетранспортери М113 біля баз (модель і колізія).
static func _scan_props(w: Node3D, visuals: bool) -> void:
	for t in 2:
		var bp := base_pos(t)
		var dir := (-bp).normalized()
		var side := Vector2(-dir.y, dir.x)
		var p2 := bp + side * (float(cur.base_r) + 4.0)
		var y := ground_y(w, p2.x, p2.y, -9999.0)
		if y < -9000.0:
			continue
		var yaw := atan2(dir.x, dir.y)
		_col_box(w, Vector3(3.0, 2.4, 5.3), Vector3(p2.x, y + 1.2, p2.y), Vector3(0.0, yaw, 0.0))
		if visuals and ResourceLoader.exists("res://models/m113.glb"):
			var ps = load("res://models/m113.glb")
			if ps:
				var apc: Node3D = ps.instantiate()
				apc.position = Vector3(p2.x, y, p2.y)
				apc.rotation.y = yaw
				w.add_child(apc)


static func _scan_trenches(w: Node3D, visuals: bool) -> void:
	var m_bag := tex_mat("hessian_230", Color(0.56, 0.5, 0.36), 0.8, Color(0.85, 0.78, 0.6))
	var m_plank := tex_mat("weathered_brown_planks", Color(0.42, 0.32, 0.22), 0.45)
	var m_mud := tex_mat("brown_mud_02", Color(0.3, 0.24, 0.17), 0.4)
	var lines: Array = []
	var span := minf(float(cur.half), float(cur.hz))
	for t in 2:
		var bp := base_pos(t)
		var c := bp * 0.5
		var dir := (-bp).normalized()
		var side := Vector2(-dir.y, dir.x)
		var ln := clampf(span * 0.7, 14.0, 60.0)
		lines.append([c - side * ln * 0.5, c + side * ln * 0.5, dir])
		# коротка позиція біля точки захоплення
		var c2 := bp.normalized() * float(cur.cap) * 1.7
		lines.append([c2 - side * 7.0, c2 + side * 7.0, dir])
	for l in lines:
		var a: Vector2 = l[0]
		var b: Vector2 = l[1]
		var face: Vector2 = l[2]   # куди дивиться бруствер (на противника)
		var n := int(a.distance_to(b) / 2.0)
		for i in n:
			var p := a.lerp(b, (i + 0.5) / float(n))
			# зигзаг траншеї
			var zz := 0.6 if (i / 3) % 2 == 0 else -0.6
			p += face * zz
			var y := ground_y(w, p.x, p.y, -9999.0)
			if y < -9000.0:
				continue
			var yb := ground_y(w, p.x - face.x * 1.6, p.y - face.y * 1.6, y)
			if absf(yb - y) > 1.4:
				continue
			var ang := atan2(b.x - a.x, b.y - a.y)
			var front := Vector3(p.x, y + 0.45, p.y)
			_box(w, Vector3(0.9, 1.0, 2.15), front, m_bag, visuals, Vector3(0.0, ang, 0.0))
			if visuals:
				# верхній ряд мішків і дошки задньої стінки
				_vis_box(w, Vector3(0.7, 0.28, 2.1), front + Vector3(0.0, 0.62, 0.0), m_bag, Vector3(0.0, ang, 0.08))
				var back := Vector3(p.x - face.x * 1.5, yb + 0.25, p.y - face.y * 1.5)
				_vis_box(w, Vector3(0.12, 0.6, 2.1), back, m_plank, Vector3(0.0, ang, 0.0))
				_vis_box(w, Vector3(1.4, 0.08, 2.1), Vector3((p.x + back.x) * 0.5, (y + yb) * 0.5 + 0.02, (p.y + back.z) * 0.5), m_mud, Vector3(0.0, ang, 0.0))
				if i % 2 == 0:
					_vis_box(w, Vector3(0.1, 1.3, 0.1), front + Vector3(face.x * -0.5, 0.2, face.y * -0.5), m_plank)


## Позначки баз і кільце точки захоплення (після того, як світ у дереві сцени).
static func decorate_scan(w: Node3D, visuals: bool) -> void:
	if not visuals:
		return
	var cy := ground_y(w, 0.0, 0.0)
	var ring := MeshInstance3D.new()
	ring.name = "CapRing"
	var rm := CylinderMesh.new()
	rm.top_radius = float(cur.cap)
	rm.bottom_radius = float(cur.cap)
	rm.height = 0.08
	rm.radial_segments = 48
	ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1, 1, 1, 0.25)
	ring.material_override = rmat
	ring.position = Vector3(0.0, cy + 0.3, 0.0)
	w.add_child(ring)
	var cols := [Color(0.25, 0.5, 1.0), Color(1.0, 0.8, 0.15)]
	for t in 2:
		var bp := base_pos(t)
		var bz := bp.y
		var by := ground_y(w, bp.x, bz)
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 6.0
		pole.mesh = cm
		pole.position = Vector3(bp.x + 2.5, by + 3.0, bz)
		w.add_child(pole)
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(1.6, 1.0, 0.04)
		flag.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = cols[t]
		fmat.emission_enabled = true
		fmat.emission = cols[t] * 0.3
		flag.material_override = fmat
		flag.position = Vector3(bp.x + 3.35, by + 5.4, bz)
		w.add_child(flag)


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


static func build(parent: Node, visuals: bool, map_idx: int = 0) -> Node3D:
	cur_index = clampi(map_idx, 0, MAPS.size() - 1)
	cur = MAPS[cur_index]
	if String(cur.id) == "front":
		return Front.build(parent, visuals, load("res://world.gd"))
	if cur.has("file"):
		return _build_scan(parent, visuals)
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
		sun.add_to_group("sun")
		sun.shadow_enabled = int(Settings.value("graphics", "shadows", 1)) == 1
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

	# ---------------------------------------------------------------- загородження: колючий дріт і протитанкові «їжаки»
	var m_metal := tex_mat("", Color(0.22, 0.2, 0.18))
	var m_rust := tex_mat("", Color(0.27, 0.19, 0.14))
	var beam_xf: Array = []
	var post_xf2: Array = []
	for tz in TRENCH_Z:
		var toward: float = -signf(tz)
		var hz: float = tz + toward * 9.0
		var hx := -132.0
		while hx <= 132.0:
			if fposmod(hx + 120.0, 40.0) > 4.0:
				_col_box(w, Vector3(1.1, 0.9, 1.1), Vector3(hx, 0.45, hz))
				for k in 3:
					var bb := Basis(Vector3.UP, k * TAU / 3.0) * Basis(Vector3.RIGHT, 0.95)
					beam_xf.append(Transform3D(bb, Vector3(hx, 0.55, hz)))
			hx += 11.0
		var wz: float = tz + toward * 5.5
		var wx := -138.0
		while wx <= 138.0:
			post_xf2.append(Transform3D(Basis(), Vector3(wx, 0.45, wz)))
			wx += 3.0
		if visuals:
			for hh in [0.3, 0.6, 0.85]:
				var wire := _vis_box(w, Vector3(276.0, 0.015, 0.015), Vector3(0.0, hh, wz), m_metal)
				wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if visuals:
		var beam := BoxMesh.new()
		beam.size = Vector3(0.12, 1.5, 0.12)
		_multi(w, beam, m_rust, beam_xf)
		var post := CylinderMesh.new()
		post.top_radius = 0.035
		post.bottom_radius = 0.04
		post.height = 0.9
		post.radial_segments = 5
		_multi(w, post, m_plank, post_xf2)

	# ---------------------------------------------------------------- підбита техніка (укриття)
	var wrecks := [[Vector3(40.0, 0.0, -60.0), 0.3, true], [Vector3(-70.0, 0.0, -28.0), -0.6, false], [Vector3(-40.0, 0.0, 60.0), 0.3, true], [Vector3(70.0, 0.0, 28.0), -0.6, false]]
	for wr in wrecks:
		var wn := Node3D.new()
		wn.position = wr[0]
		wn.rotation.y = wr[1]
		w.add_child(wn)
		if wr[2]:
			_box(wn, Vector3(3.4, 1.2, 6.6), Vector3(0.0, 0.75, 0.0), m_rust, visuals)  # корпус танка
			_box(wn, Vector3(2.2, 0.75, 2.6), Vector3(0.0, 1.7, 0.4), m_rust, visuals, Vector3(0.0, 0.5, 0.0))  # башта
			if visuals:
				var gun := MeshInstance3D.new()
				var gm := CylinderMesh.new()
				gm.top_radius = 0.09
				gm.bottom_radius = 0.11
				gm.height = 4.2
				gun.mesh = gm
				gun.material_override = m_metal
				gun.position = Vector3(1.2, 1.6, -1.4)
				gun.rotation = Vector3(PI * 0.5 - 0.15, 0.5, 0.0)
				wn.add_child(gun)
				for s in [-1.0, 1.0]:
					_vis_box(wn, Vector3(0.6, 0.7, 6.8), Vector3(s * 1.55, 0.35, 0.0), m_metal)  # гусениці
		else:
			_box(wn, Vector3(2.8, 1.6, 7.4), Vector3(0.0, 1.2, 0.0), m_rust, visuals)  # БТР
			_box(wn, Vector3(1.0, 0.5, 1.2), Vector3(0.0, 2.2, -1.0), m_rust, visuals)
			if visuals:
				for zz in [-2.6, -0.9, 0.9, 2.6]:
					for s in [-1.0, 1.0]:
						_vis_box(wn, Vector3(0.35, 1.0, 1.0), Vector3(s * 1.45, 0.5, zz), m_metal)

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
		_grass(w)
	return w


static func _grass_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for b in 22:
		var x0 := r.randf_range(4.0, 60.0)
		var lean := r.randf_range(-12.0, 12.0)
		var h := r.randf_range(26.0, 62.0)
		var col := Color(r.randf_range(0.25, 0.45), r.randf_range(0.38, 0.55), r.randf_range(0.12, 0.22))
		if r.randf() < 0.25:
			col = Color(0.55, 0.5, 0.3)  # суха трава
		for i in int(h):
			var t := float(i) / h
			var x := int(x0 + lean * t * t)
			var y := 63 - i
			var wdt := 2 if t < 0.6 else 1
			for dx in wdt:
				var px := clampi(x + dx, 0, 63)
				img.set_pixel(px, y, col.darkened(0.25 * (1.0 - t)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _grass(w: Node3D) -> void:
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _grass_texture()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	gm.alpha_scissor_threshold = 0.4
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.roughness = 1.0
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var qm := QuadMesh.new()
	qm.size = Vector2(1.1, 0.65)
	qm.center_offset = Vector3(0.0, 0.32, 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var chunk := 25.0
	var cx := -HALF
	while cx < HALF:
		var cz := -HALF
		while cz < HALF:
			var xf: Array = []
			var center := Vector3(cx + chunk * 0.5, 0.0, cz + chunk * 0.5)
			for i in 70:
				var p := Vector3(cx + r.randf() * chunk, 0.0, cz + r.randf() * chunk)
				var ok := true
				for tz in TRENCH_Z:
					if absf(p.z - tz) < 2.0:
						ok = false
				if absf(absf(p.z) - BASE_Z) < 16.0 and absf(p.x) < 36.0:
					ok = false
				if not ok:
					continue
				var rot := r.randf() * PI
				var sc := r.randf_range(0.7, 1.4)
				var b := Basis(Vector3.UP, rot).scaled(Vector3(sc, sc, sc))
				xf.append(Transform3D(b, p - center))
				xf.append(Transform3D(Basis(Vector3.UP, rot + PI * 0.5).scaled(Vector3(sc, sc, sc)), p - center))
			if not xf.is_empty():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = qm
				mm.instance_count = xf.size()
				for i in xf.size():
					mm.set_instance_transform(i, xf[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = gm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 55.0 * float(Settings.value("graphics", "grass", 1.0))
				mmi.add_to_group("grass")
				mmi.visibility_range_end_margin = 8.0
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				mmi.position = center
				w.add_child(mmi)
			cz += chunk
		cx += chunk


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
