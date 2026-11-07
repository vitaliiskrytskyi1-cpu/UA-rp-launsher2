extends RefCounted
## Карта «Фронт» 400×400 м: рельєф (сітка 1 м) з викопаними окопами і бліндажами,
## бункери, мішки з піском, колючий дріт, протитанкові їжаки, руїни, артилерія під
## маскувальними сітками, посадки. Текстури — з набору гравця (texpack/).
## Дані генеруються заздалегідь (maps/front_h.bin, front_m.bin, front_layout.json),
## тому сервер і клієнти мають однакову карту.

const Settings = preload("res://settings.gd")

static var layout := {}
static var heights := PackedFloat32Array()
static var tmask := PackedByteArray()
static var n := 0
static var x0 := 0.0
static var _shapes := {}
static var _scenes := {}

const VIS_RANGE := {"wire_coil": 90.0, "wire_x": 90.0, "hedgehog": 140.0, "bags_u": 170.0, "bags_low": 150.0, "bags_line": 150.0}


static func load_data() -> void:
	if n > 0:
		return
	var f := FileAccess.open("res://maps/front_h.bin", FileAccess.READ)
	n = f.get_32()
	var _n2 := f.get_32()
	x0 = f.get_float()
	var _z0 := f.get_float()
	heights = f.get_buffer(n * n * 4).to_float32_array()
	f.close()
	var fm := FileAccess.open("res://maps/front_m.bin", FileAccess.READ)
	if fm:
		tmask = fm.get_buffer(n * n)
		fm.close()
	var fl := FileAccess.open("res://maps/front_layout.json", FileAccess.READ)
	layout = JSON.parse_string(fl.get_as_text())
	fl.close()


static func h_at(i: int, j: int) -> float:
	i = clampi(i, 0, n - 1)
	j = clampi(j, 0, n - 1)
	return heights[i * n + j]


## Висота рельєфу (білінійна).
static func height(x: float, z: float) -> float:
	var fx := x - x0
	var fz := z - x0
	var j := int(floorf(fx))
	var i := int(floorf(fz))
	var tx := fx - j
	var tz := fz - i
	var a := lerpf(h_at(i, j), h_at(i, j + 1), tx)
	var b := lerpf(h_at(i + 1, j), h_at(i + 1, j + 1), tx)
	return lerpf(a, b, tz)


static func build(parent: Node, visuals: bool, World) -> Node3D:
	load_data()
	var w := Node3D.new()
	w.name = "World"
	parent.add_child(w)
	# рельєф: колізія
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	hs.map_data = heights
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = hs
	body.add_child(cs)
	w.add_child(body)
	# межі карти
	var half := float(layout.half)
	for s in [-1.0, 1.0]:
		World._col_box(w, Vector3(half * 2.0, 80.0, 1.0), Vector3(0.0, 20.0, s * (half - 1.0)))
		World._col_box(w, Vector3(1.0, 80.0, half * 2.0), Vector3(s * (half - 1.0), 20.0, 0.0))
	_build_props(w, visuals)
	_build_dugouts(w, visuals)
	_village(w, visuals)
	if visuals:
		World._env(w, 0.0045)
		_terrain(w)
		_nets(w)
		_trees(w)
		_base_decor(w, World)
		_grass(w)
	return w


# ---------------------------------------------------------------- матеріали

static func pack_mat(name: String, scale: float = 0.25, tint: Color = Color(1, 1, 1)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	var p := "res://texpack/%s.jpg" % name
	if ResourceLoader.exists(p):
		m.albedo_texture = load(p)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 g = texture(grass_tex, wpos.xz * 0.22).rgb;
	vec3 g2 = texture(grass_tex, wpos.xz * 0.031).rgb;
	g = mix(g, g2, 0.35) * vec3(0.72, 0.74, 0.55);
	vec3 d = texture(dirt_tex, wpos.xz * 0.35 + wpos.y * 0.2).rgb * 1.25;
	float steep = 1.0 - smoothstep(0.55, 0.85, COLOR.g);
	float k = clamp(COLOR.r + steep, 0.0, 1.0);
	ALBEDO = mix(g, d, k);
	ROUGHNESS = 1.0;
}
"""


static func _terrain(w: Node3D) -> void:
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if ResourceLoader.exists("res://texpack/grass.jpg"):
		mat.set_shader_parameter("grass_tex", load("res://texpack/grass.jpg"))
		mat.set_shader_parameter("dirt_tex", load("res://texpack/dirt.jpg"))
	# квадрати 40 м; де немає окопів — сітка 2 м (учетверо менше трикутників)
	var chunk := 60
	var i0 := 0
	while i0 < n - 1:
		var j0 := 0
		while j0 < n - 1:
			var i1 := mini(i0 + chunk, n - 1)
			var j1 := mini(j0 + chunk, n - 1)
			var step := 2
			if tmask.size() > 0:
				for i in range(i0, i1 + 1):
					for j in range(j0, j1 + 1):
						if tmask[i * n + j] > 0:
							step = 1
							break
					if step == 1:
						break
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var ni := (i1 - i0) / step + 1
			var nj := (j1 - j0) / step + 1
			for a in ni:
				var i := i0 + a * step
				for b in nj:
					var j := j0 + b * step
					var nx := h_at(i, j - 1) - h_at(i, j + 1)
					var nz := h_at(i - 1, j) - h_at(i + 1, j)
					var nrm := Vector3(nx, 2.0, nz).normalized()
					var mk := 0.0
					if tmask.size() > 0:
						mk = float(tmask[i * n + j]) / 255.0
					verts.append(Vector3(x0 + j, h_at(i, j), x0 + i))
					norms.append(nrm)
					cols.append(Color(mk, nrm.y, 0.0))
			for a in ni - 1:
				for b in nj - 1:
					var v := a * nj + b
					idx.append_array([v, v + 1, v + nj, v + 1, v + nj + 1, v + nj])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			w.add_child(mi)
			j0 += chunk
		i0 += chunk


# ---------------------------------------------------------------- обʼєкти

static func _prop_shape(t: String) -> Shape3D:
	if _shapes.has(t):
		return _shapes[t]
	var meta = JSON.parse_string(FileAccess.get_file_as_string("res://maps/props_col.json"))
	var shape: Shape3D = null
	if typeof(meta) == TYPE_DICTIONARY and meta.has(t) and not t.begins_with("wire"):
		var m: Dictionary = meta[t]
		if int(m.n) > 0:
			var f := FileAccess.open("res://maps/props_col.bin", FileAccess.READ)
			f.seek(int(m.off) * 12)
			var fl := f.get_buffer(int(m.n) * 36).to_float32_array()
			f.close()
			var faces := PackedVector3Array()
			faces.resize(int(m.n) * 3)
			for k in faces.size():
				faces[k] = Vector3(fl[k * 3], fl[k * 3 + 1], fl[k * 3 + 2])
			var cp := ConcavePolygonShape3D.new()
			cp.backface_collision = true
			cp.set_faces(faces)
			shape = cp
		else:
			var b := BoxShape3D.new()
			b.size = Vector3(float(m.size[0]), float(m.size[1]), float(m.size[2]))
			shape = b
	_shapes[t] = shape
	return shape


static func _prop_scene(t: String) -> PackedScene:
	if not _scenes.has(t):
		var p := "res://models/props/%s.glb" % t
		_scenes[t] = load(p) if ResourceLoader.exists(p) else null
	return _scenes[t]


static func _build_props(w: Node3D, visuals: bool) -> void:
	# колізія: одне тіло на всі обʼєкти (менше вузлів фізики)
	var body := StaticBody3D.new()
	w.add_child(body)
	var groups := {}
	for pr in layout.props:
		var t := String(pr.t)
		var xf := Transform3D(Basis(Vector3.UP, float(pr.yaw)), Vector3(float(pr.x), float(pr.y), float(pr.z)))
		var sh := _prop_shape(t)
		if sh != null:
			var cs := CollisionShape3D.new()
			cs.shape = sh
			cs.transform = xf
			if sh is BoxShape3D:
				cs.transform = xf * Transform3D(Basis(), Vector3(0.0, (sh as BoxShape3D).size.y * 0.5, 0.0))
			body.add_child(cs)
		if visuals:
			if not groups.has(t):
				groups[t] = []
			groups[t].append(xf)
	if not visuals:
		return
	# вигляд: MultiMesh на кожну частину моделі і квадрат 50 м — десятки викликів малювання замість сотень
	for t in groups:
		var ps := _prop_scene(t)
		if ps == null:
			continue
		var inst: Node3D = ps.instantiate()
		var parts: Array = []
		_collect_meshes(inst, Transform3D.IDENTITY, parts)
		inst.free()
		var ov: Material = _ov_mat(t) if OVERRIDE.has(t) else null
		for part in parts:
			var mesh: Mesh = part[0]
			var local: Transform3D = part[1]
			var xfs: Array = []
			for xf in groups[t]:
				xfs.append((xf as Transform3D) * local)
			_multi_chunks(w, mesh, ov if ov else part[2], xfs, float(VIS_RANGE.get(t, 260.0)))


static func _collect_meshes(n0: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf := parent_xf
	if n0 is Node3D:
		xf = parent_xf * (n0 as Node3D).transform
	if n0 is MeshInstance3D and (n0 as MeshInstance3D).mesh:
		var mi := n0 as MeshInstance3D
		out.append([mi.mesh, xf, mi.material_override])
	for c in n0.get_children():
		_collect_meshes(c, xf, out)


const OVERRIDE := {"bunker": ["cement", 0.35, Color(0.62, 0.62, 0.58)], "ruin": ["ruin", 0.3, Color(0.6, 0.58, 0.55)], "hedgehog": ["metal", 0.8, Color(0.35, 0.3, 0.27)], "tower": ["greenmetal", 0.6, Color(0.8, 0.8, 0.8)], "wire_x": ["metal", 1.5, Color(0.3, 0.28, 0.25)], "wire_coil": ["metal", 1.5, Color(0.4, 0.38, 0.35)], "bags_u": ["sandbag", 0.9, Color(0.8, 0.75, 0.62)], "bags_low": ["sandbag", 0.9, Color(0.8, 0.75, 0.62)], "bags_line": ["sandbag", 0.9, Color(0.8, 0.75, 0.62)]}
static var _ov := {}


static func _ov_mat(t: String) -> Material:
	if not _ov.has(t):
		var d: Array = OVERRIDE[t]
		_ov[t] = pack_mat(String(d[0]), float(d[1]), d[2])
	return _ov[t]


static func _override(n0: Node, m: Material) -> void:
	if n0 is GeometryInstance3D:
		(n0 as GeometryInstance3D).material_override = m
	for c in n0.get_children():
		_override(c, m)


static func _set_range(n0: Node, r: float) -> void:
	if n0 is GeometryInstance3D:
		var g := n0 as GeometryInstance3D
		g.visibility_range_end = r
		g.visibility_range_end_margin = 10.0
		if r < 120.0:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n0.get_children():
		_set_range(c, r)


## Бліндажі: накат з колод над кімнатою, присипаний землею.
static func _build_dugouts(w: Node3D, visuals: bool) -> void:
	var B := Batch.new(w, visuals)
	var m_log := pack_mat("dirt", 0.8, Color(0.75, 0.6, 0.45))
	var m_soil := pack_mat("dirt", 0.4)
	var log_m := CylinderMesh.new()
	log_m.top_radius = 0.15
	log_m.bottom_radius = 0.16
	log_m.height = 4.0
	log_m.radial_segments = 6
	var mound_m := SphereMesh.new()
	mound_m.radius = 1.0
	mound_m.height = 0.6
	mound_m.is_hemisphere = true
	mound_m.radial_segments = 10
	mound_m.rings = 3
	for d in layout.dugouts:
		var x := float(d.x)
		var z := float(d.z)
		var y := float(d.y)
		var rot := int(d.get("rot", 0)) == 1
		B.box(Vector3(x, y + 0.15, z), Vector3(3.8, 0.6, 5.0) if rot else Vector3(5.0, 0.6, 3.8), null, Vector3.ZERO, true)
		for k in 11:
			var lb := Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5) if rot else Vector3(PI * 0.5, 0.0, 0.0))
			var lp := Vector3(x, y - 0.05, z - 2.25 + k * 0.45) if rot else Vector3(x - 2.25 + k * 0.45, y - 0.05, z)
			B.mesh(log_m, Transform3D(lb, lp), m_log)
		var ms := Vector3(2.2, 1.0, 2.8) if rot else Vector3(2.8, 1.0, 2.2)
		var mp := Vector3(x + float(d.s) * 0.3, y + 0.05, z) if rot else Vector3(x, y + 0.05, z + float(d.s) * 0.3)
		B.mesh(mound_m, Transform3D(Basis().scaled(ms), mp), m_soil)
	B.commit(w, 220.0)


## Маскувальні сітки на стійках.
static func _nets(w: Node3D) -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D camo : source_color, filter_linear_mipmap, repeat_enable;
void fragment() {
	vec2 g = fract(UV * vec2(40.0, 40.0));
	float hole = step(0.18, g.x) * step(0.18, g.y) * step(g.x, 0.82) * step(g.y, 0.82);
	vec3 c = texture(camo, UV * 3.0).rgb;
	vec2 cell = floor(UV * 40.0);
	float rnd = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	if (hole > 0.5 && rnd < 0.3) discard;
	ALBEDO = c * 1.5 + vec3(0.06, 0.09, 0.03);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	if ResourceLoader.exists("res://texpack/camo.jpg"):
		mat.set_shader_parameter("camo", load("res://texpack/camo.jpg"))
	var m_pole := pack_mat("dirt", 1.0, Color(0.6, 0.5, 0.4))
	var NB := Batch.new(w, true)
	for nt in layout.nets:
		var x := float(nt.x)
		var z := float(nt.z)
		var wd := float(nt.w)
		var dp := float(nt.d)
		var hh := float(nt.h)
		var y := height(x, z)
		var pm := PlaneMesh.new()
		pm.size = Vector2(wd, dp)
		pm.subdivide_width = 6
		pm.subdivide_depth = 6
		NB.mesh(pm, Transform3D(Basis(), Vector3(x, y + hh, z)), mat)
		# краї сітки спускаються до землі
		for s in [-1.0, 1.0]:
			var sp := PlaneMesh.new()
			sp.size = Vector2(wd, hh * 1.2)
			NB.mesh(sp, Transform3D(Basis.from_euler(Vector3(s * 0.95, 0.0, 0.0)), Vector3(x, y + hh * 0.55, z + s * (dp * 0.5 + hh * 0.3))), mat)
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04
			cm.bottom_radius = 0.05
			cm.height = hh
			cm.radial_segments = 5
			var px: float = x + c.x * wd * 0.45
			var pz: float = z + c.y * dp * 0.45
			NB.mesh(cm, Transform3D(Basis(), Vector3(px, height(px, pz) + hh * 0.5, pz)), m_pole)
	NB.commit(w, 220.0)


## Посадки (лісосмуги).
static func _trees(w: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var m_bark := pack_mat("dirt", 0.9, Color(0.55, 0.42, 0.32))
	var m_leaf := pack_mat("grass", 0.6, Color(0.55, 0.8, 0.45))
	var trunk_xf: Array = []
	var crown_xf: Array = []
	for line in layout.trees:
		var a := Vector2(float(line[0][0]), float(line[0][1]))
		var b := Vector2(float(line[1][0]), float(line[1][1]))
		var length := a.distance_to(b)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var t := 0.0
		while t < length:
			t += rng.randf_range(3.0, 6.0)
			if rng.randf() < 0.1:
				continue
			for row in 2:
				var p := a + dir * t + side * (row * 3.5 + rng.randf_range(-1.0, 1.0))
				var gy := height(p.x, p.y)
				var sc := rng.randf_range(0.8, 1.4)
				trunk_xf.append(Transform3D(Basis().scaled(Vector3(1.0, sc, 1.0)), Vector3(p.x, gy + 3.0 * sc, p.y)))
				var rb := Basis(Vector3.UP, rng.randf() * TAU)
				crown_xf.append(Transform3D(rb.scaled(Vector3(sc, sc * 1.15, sc)), Vector3(p.x, gy + 5.8 * sc, p.y)))
				crown_xf.append(Transform3D(rb.scaled(Vector3(sc * 0.7, sc * 0.8, sc * 0.7)), Vector3(p.x + 0.9, gy + 4.7 * sc, p.y + 0.3)))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.28
	cm.height = 6.0
	cm.radial_segments = 6
	_multi_chunks(w, cm, m_bark, trunk_xf)
	var sm := SphereMesh.new()
	sm.radius = 2.1
	sm.height = 4.0
	sm.radial_segments = 8
	sm.rings = 5
	_multi_chunks(w, sm, m_leaf, crown_xf)


## MultiMesh, розбитий на квадрати 50 м (щоб далекі частини відсікались).
static func _multi_chunks(w: Node3D, mesh: Mesh, mat: Material, xforms: Array, rng_end: float = 260.0, colors: Array = []) -> void:
	var groups := {}
	for k in xforms.size():
		var o: Vector3 = (xforms[k] as Transform3D).origin
		var key := Vector2i(int(floorf(o.x / 80.0)), int(floorf(o.z / 80.0)))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(k)
	for key in groups:
		var arr: Array = groups[key]
		var center := Vector3(key.x * 80.0 + 40.0, 0.0, key.y * 80.0 + 40.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not colors.is_empty()
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for k in arr.size():
			var xf: Transform3D = xforms[arr[k]]
			xf.origin -= center
			mm.set_instance_transform(k, xf)
			if mm.use_colors:
				mm.set_instance_color(k, colors[arr[k]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if mat:
			mmi.material_override = mat
		mmi.position = center
		mmi.visibility_range_end = rng_end
		if rng_end < 150.0:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.add_child(mmi)


static func _base_decor(w: Node3D, World) -> void:
	var m_box := pack_mat("greenmetal", 1.2)
	for t in 2:
		var bp: Vector2 = World.base_pos(t)
		for k in 4:
			var bx := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.2, 0.6, 0.6)
			bx.mesh = bm
			bx.material_override = m_box
			var px := bp.x - 6.0 + k * 1.4
			var pz := bp.y + (6.0 if t == 0 else -6.0)
			bx.position = Vector3(px, height(px, pz) + 0.3, pz)
			w.add_child(bx)


## Трава (лише поза окопами).
static func _grass(w: Node3D) -> void:
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _grass_tex()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	gm.alpha_scissor_threshold = 0.4
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	gm.roughness = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(1.1, 0.65)
	qm.center_offset = Vector3(0.0, 0.32, 0.0)
	var r := RandomNumberGenerator.new()
	r.seed = 4243
	var chunk := 25.0
	var half := float(layout.half)
	var cx := -half
	while cx < half:
		var cz := -half
		while cz < half:
			var xf: Array = []
			var center := Vector3(cx + chunk * 0.5, 0.0, cz + chunk * 0.5)
			for k in 45:
				var px := cx + r.randf() * chunk
				var pz := cz + r.randf() * chunk
				var i := int(roundf(pz - x0))
				var j := int(roundf(px - x0))
				if tmask.size() > 0 and tmask[clampi(i, 0, n - 1) * n + clampi(j, 0, n - 1)] > 40:
					continue
				if absf(pz - 8.0) < 7.5 or absf(px) < 4.0 or absf(pz + 42.0) < 3.5:
					continue
				var p := Vector3(px, height(px, pz), pz)
				var rot := r.randf() * PI
				var sc := r.randf_range(0.7, 1.4)
				xf.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(sc, sc, sc)), p - center))
				xf.append(Transform3D(Basis(Vector3.UP, rot + PI * 0.5).scaled(Vector3(sc, sc, sc)), p - center))
			if not xf.is_empty():
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = qm
				mm.instance_count = xf.size()
				for k in xf.size():
					mm.set_instance_transform(k, xf[k])
				var mmi := MultiMeshInstance3D.new()
				mmi.multimesh = mm
				mmi.material_override = gm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = 55.0 * float(Settings.value("graphics", "grass", 1.0))
				mmi.add_to_group("grass")
				mmi.position = center
				w.add_child(mmi)
			cz += chunk
		cx += chunk


static func _grass_tex() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for b in 22:
		var bx := r.randf_range(4.0, 60.0)
		var lean := r.randf_range(-12.0, 12.0)
		var h := r.randf_range(26.0, 62.0)
		var col := Color(r.randf_range(0.2, 0.35), r.randf_range(0.35, 0.5), r.randf_range(0.1, 0.18))
		for i in int(h):
			var t := float(i) / h
			var x := clampi(int(bx + lean * t * t), 0, 63)
			img.set_pixel(x, 63 - i, col.darkened(0.25 * (1.0 - t)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ================================================================ село, дороги, поля (за заготовкою гравця)
# Уся статична геометрія зливається в один меш на матеріал і квадрат 60 м:
# сотні коробок дають лише кілька десятків викликів малювання.

class Batch:
	var groups := {}   # "cx,cz,mat" -> [SurfaceTool, Material, Vector3 center]
	var col_body: StaticBody3D
	var visuals := true

	func _init(w: Node3D, vis: bool) -> void:
		visuals = vis
		col_body = StaticBody3D.new()
		w.add_child(col_body)

	func box(pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, collide: bool = false) -> void:
		var b := Basis.from_euler(rot)
		if collide:
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = size
			cs.shape = sh
			cs.transform = Transform3D(b, pos)
			col_body.add_child(cs)
		if not visuals or mat == null:
			return
		_add(BoxMesh.new(), size, Transform3D(b, pos), mat)

	func mesh(m: PrimitiveMesh, xf: Transform3D, mat: Material) -> void:
		if visuals:
			_add(m, Vector3.ZERO, xf, mat)

	func _add(m: PrimitiveMesh, size: Vector3, xf: Transform3D, mat: Material) -> void:
		if m is BoxMesh and size != Vector3.ZERO:
			(m as BoxMesh).size = size
		var cx := int(floorf(xf.origin.x / 60.0))
		var cz := int(floorf(xf.origin.z / 60.0))
		var key := "%d,%d,%d" % [cx, cz, mat.get_instance_id()]
		if not groups.has(key):
			var st0 := SurfaceTool.new()
			st0.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = [st0, mat, Vector3(cx * 60.0 + 30.0, 0.0, cz * 60.0 + 30.0)]
		var g: Array = groups[key]
		var local := xf
		local.origin -= g[2]
		(g[0] as SurfaceTool).append_from(m, 0, local)

	func commit(w: Node3D, rng_end: float = 320.0) -> void:
		for key in groups:
			var g: Array = groups[key]
			var mi := MeshInstance3D.new()
			mi.mesh = (g[0] as SurfaceTool).commit()
			mi.material_override = g[1]
			mi.position = g[2]
			mi.visibility_range_end = rng_end
			w.add_child(mi)
		groups.clear()


static var _cmats := {}


static func cmat(c: Color, rough: float = 1.0) -> StandardMaterial3D:
	var key := str(c)
	if not _cmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_cmats[key] = m
	return _cmats[key]


static func _village(w: Node3D, visuals: bool) -> void:
	var B := Batch.new(w, visuals)
	var plaster := pack_mat("cement", 0.3, Color(0.95, 0.88, 0.7))
	var plaster_old := pack_mat("ruin", 0.3, Color(0.75, 0.74, 0.64))
	var roof := cmat(Color(0.22, 0.13, 0.10), 0.9)
	var roof_light := cmat(Color(0.32, 0.22, 0.16), 0.9)
	var brick := cmat(Color(0.34, 0.19, 0.13), 0.95)
	var wood := cmat(Color(0.25, 0.16, 0.09), 0.95)
	var wood_light := cmat(Color(0.39, 0.28, 0.16), 0.95)
	var glass := cmat(Color(0.055, 0.09, 0.105), 0.22)
	var concrete := pack_mat("cement", 0.35, Color(0.7, 0.7, 0.65))
	var dark := cmat(Color(0.07, 0.065, 0.052))
	var asphalt := cmat(Color(0.13, 0.15, 0.15), 0.95)
	var dirt := pack_mat("dirt", 0.3, Color(1.1, 1.0, 0.9))
	var dirt_light := pack_mat("dirt", 0.3, Color(1.45, 1.3, 1.1))
	var field := pack_mat("dirt", 0.12, Color(1.15, 1.05, 0.7))
	var metal := pack_mat("metal", 0.6, Color(0.4, 0.42, 0.4))
	var sandbag := pack_mat("sandbag", 0.8)
	var blue := cmat(Color(0.08, 0.23, 0.38), 0.85)
	var red := cmat(Color(0.42, 0.12, 0.09), 0.85)
	# будинки
	for hd in layout.get("houses", []):
		var pos := Vector3(float(hd.x), float(hd.y), float(hd.z))
		var s := float(hd.s)
		var wd := float(hd.w)
		var dp := float(hd.d)
		var hh := float(hd.h)
		var old: bool = hd.old
		B.box(pos + Vector3(0, hh * 0.5, 0), Vector3(wd, hh, dp), plaster_old if old else plaster, Vector3.ZERO, true)
		var rm: Material = roof if old else roof_light
		B.box(pos + Vector3(0, hh + 1.25 * s, -dp * 0.25), Vector3(wd + 1.4, 0.42, dp * 0.58), rm, Vector3(-0.48, 0, 0), true)
		B.box(pos + Vector3(0, hh + 1.25 * s, dp * 0.25), Vector3(wd + 1.4, 0.42, dp * 0.58), rm, Vector3(0.48, 0, 0), true)
		B.box(pos + Vector3(0, hh + 2.0 * s, 0), Vector3(wd + 1.5, 0.35, 0.45), roof)
		B.box(pos + Vector3(wd * 0.31, hh + 2.25 * s, -dp * 0.18), Vector3(1.0 * s, 2.3 * s, 1.0 * s), brick)
		B.box(pos + Vector3(0, 1.35 * s, dp * 0.505), Vector3(1.65 * s, 2.7 * s, 0.14), wood)
		for side in [-1.0, 1.0]:
			var wp: Vector3 = pos + Vector3(side * 4.2 * s, 3.55 * s, dp * 0.505)
			var ww := 1.8 * s
			var wh := 1.45 * s
			B.box(wp, Vector3(ww + 0.35, wh + 0.35, 0.18), wood_light)
			B.box(wp + Vector3(0, 0, 0.12), Vector3(ww, wh, 0.08), glass)
			B.box(wp, Vector3(0.10, wh, 0.1), wood)
			B.box(wp + Vector3(0, -wh * 0.58, 0.12), Vector3(ww + 0.5, 0.18, 0.32), concrete)
			B.box(pos + Vector3(side * wd * 0.505, 3.45 * s, 0), Vector3(0.14, 1.4 * s, 1.8 * s), glass)
		B.box(pos + Vector3(0, 0.18 * s, dp * 0.58), Vector3(2.5 * s, 0.36 * s, 0.9 * s), concrete)
		if hd.yard:
			_fence(B, pos + Vector3(13 * s, 0, 0), 19 * s, wood, wood_light)
			B.box(pos + Vector3(-11 * s, 1.35 * s, -7 * s), Vector3(4 * s, 2.7 * s, 4 * s), wood, Vector3.ZERO, true)
			B.box(pos + Vector3(-11 * s, 3.0 * s, -7 * s), Vector3(4.8 * s, 0.45 * s, 4.8 * s), roof, Vector3.ZERO, true)
	# зруйнований будинок
	for r in layout.get("ruins", []):
		var p := Vector3(float(r.x), height(float(r.x), float(r.z)), float(r.z))
		B.box(p + Vector3(0, 2.2, -5), Vector3(12, 4.4, 0.7), brick, Vector3.ZERO, true)
		B.box(p + Vector3(-5.8, 1.8, 0), Vector3(0.7, 3.6, 10), concrete, Vector3.ZERO, true)
		B.box(p + Vector3(0, 5.2, 0), Vector3(13, 0.35, 0.45), wood, Vector3(0, 0, 0.18))
	for f in layout.get("fences", []):
		var fp := Vector3(float(f.x), height(float(f.x), float(f.z)), float(f.z))
		_fence(B, fp, float(f.len), wood, wood_light)
	# дороги і поля (на рівних ділянках)
	B.box(Vector3(0, 0.03, 8), Vector3(560, 0.10, 9), asphalt)
	B.box(Vector3(0, 0.025, 14), Vector3(560, 0.08, 1.8), dirt_light)
	B.box(Vector3(0, 0.025, 2), Vector3(560, 0.08, 1.8), dirt_light)
	B.box(Vector3(0, 0.035, -42), Vector3(350, 0.12, 5.5), dirt_light)
	for zz in range(-255, 256, 30):
		if absf(zz - 8.0) > 8.0:
			B.box(Vector3(0, 0.035, zz), Vector3(6, 0.12, 30.5), dirt)
	B.box(Vector3(0, 0.03, -205), Vector3(390, 0.07, 130), field)
	B.box(Vector3(0, 0.03, 220), Vector3(410, 0.07, 105), field)
	for i in 26:
		B.box(Vector3(-190.0 + i * 15.0, 0.07, -205), Vector3(0.34, 0.035, 118), dirt)
	for i in 22:
		B.box(Vector3(-185.0 + i * 17.0, 0.07, 220), Vector3(0.32, 0.035, 94), dirt)
	# бази: укриття штабу, мішки, позначки команд
	var half := float(layout.half)
	for t in 2:
		var cx := -255.0 if t == 0 else 255.0
		var c := Vector3(cx, height(cx, 0.0), 0.0)
		var face := 1.0 if t == 0 else -1.0
		B.box(c + Vector3(0, 0.05, 0), Vector3(58, 0.12, 72), dirt)
		B.box(c + Vector3(-face * 18.0, 2.7, -18), Vector3(15, 5.4, 12), concrete, Vector3.ZERO, true)
		B.box(c + Vector3(-face * 18.0, 5.7, -18), Vector3(16, 0.8, 13), dirt, Vector3.ZERO, true)
		for side in [-1.0, 1.0]:
			B.box(c + Vector3(face * 14.0, 0.8, side * 18.0), Vector3(2.5, 1.6, 12), sandbag, Vector3.ZERO, true)
		B.box(c + Vector3(face * 4.0, 0.3, 27), Vector3(5, 0.5, 5), blue if t == 0 else red)
	# орієнтири: водонапірна вежа, спостережні вишки
	var tw := Vector3(-205, height(-205, -35), -35)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.45
	cyl.height = 10.0
	cyl.radial_segments = 9
	B.mesh(cyl, Transform3D(Basis(), tw + Vector3(0, 5, 0)), metal)
	var tank := CylinderMesh.new()
	tank.top_radius = 4.0
	tank.bottom_radius = 4.0
	tank.height = 4.0
	tank.radial_segments = 14
	B.mesh(tank, Transform3D(Basis(), tw + Vector3(0, 11, 0)), metal)
	B.box(tw + Vector3(0, 5, 0), Vector3(0.9, 10, 0.9), null, Vector3.ZERO, true)
	B.box(tw + Vector3(0, 11, 0), Vector3(8, 4, 8), null, Vector3.ZERO, true)
	for wp2 in [Vector3(205, 0, -175), Vector3(-205, 0, 175)]:
		var p2: Vector3 = wp2 + Vector3(0, height(wp2.x, wp2.z), 0)
		for lx in [-2.5, 2.5]:
			for lz in [-2.5, 2.5]:
				B.box(p2 + Vector3(lx, 4, lz), Vector3(0.35, 8, 0.35), wood, Vector3.ZERO, true)
		B.box(p2 + Vector3(0, 8, 0), Vector3(7, 0.5, 7), wood, Vector3.ZERO, true)
		B.box(p2 + Vector3(0, 11, 0), Vector3(8, 0.4, 8), roof)
		B.box(p2 + Vector3(0, 4, 3.7), Vector3(0.8, 8, 0.25), metal)
	B.commit(w, 360.0)
	if visuals:
		_trees2(w)


static func _fence(B, origin: Vector3, length: float, wood: Material, wood_light: Material) -> void:
	var count := int(length / 2.5)
	for i in count + 1:
		var lx := -length * 0.5 + float(i) * 2.5
		var p := origin + Vector3(lx, 0, 0)
		p.y = height(p.x, p.z)
		B.box(p + Vector3(0, 0.75, 0), Vector3(0.22, 1.5, 0.22), wood, Vector3.ZERO, true)
		if i < count:
			B.box(p + Vector3(1.25, 1.0, 0), Vector3(2.5, 0.14, 0.16), wood_light)


## Дерева, кущі і камені за заготовкою (MultiMesh по квадратах — дешево для телефона).
static func _trees2(w: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4172026
	var trunk := cmat(Color(0.20, 0.13, 0.075))
	var bark := cmat(Color(0.29, 0.19, 0.11))
	var leaf_cols := [Color(0.10, 0.19, 0.095), Color(0.16, 0.25, 0.12), Color(0.22, 0.29, 0.14)]
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.vertex_color_use_as_albedo = true
	leaf_mat.roughness = 1.0
	var rock := cmat(Color(0.31, 0.30, 0.26))
	var t_xf: Array = []
	var b_xf: Array = []
	var l_xf := [[], [], []]
	for tp in layout.get("tree_pts", []):
		var x := float(tp[0])
		var z := float(tp[1])
		var s := float(tp[2])
		var base := Vector3(x, height(x, z), z)
		var th := rng.randf_range(5.2, 7.3) * s
		t_xf.append(Transform3D(Basis().scaled(Vector3(s, th / 6.0, s)), base + Vector3(0, th * 0.5, 0)))
		for bi in 3:
			var ang := float(bi) * TAU / 3.0 + float(tp[3])
			var a := base + Vector3(0, th * 0.56, 0)
			var e := a + Vector3(cos(ang) * 1.7 * s, 1.25 * s, sin(ang) * 1.7 * s)
			var d := e - a
			var yb := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT) * Basis(Vector3.RIGHT, -PI * 0.5)
			b_xf.append(Transform3D(yb.scaled(Vector3(s, d.length() / 2.0, s)), (a + e) * 0.5))
		var cc := base + Vector3(0, th + 1.2 * s, 0)
		for ci in 5:
			var off := Vector3(rng.randf_range(-1.25, 1.25), rng.randf_range(-0.65, 1.15), rng.randf_range(-1.25, 1.25)) * s
			var rr := rng.randf_range(1.35, 1.95) * s
			l_xf[rng.randi_range(0, 2)].append(Transform3D(Basis().scaled(Vector3(rr, rr, rr)), cc + off))
	for sh in layout.get("shrubs", []):
		var x2 := float(sh[0])
		var z2 := float(sh[1])
		var s2 := float(sh[2])
		var p := Vector3(x2, height(x2, z2), z2)
		l_xf[0 if rng.randf() < 0.5 else 1].append(Transform3D(Basis().scaled(Vector3(0.8 * s2 * 1.4, 0.8 * s2 * 0.9, 0.8 * s2 * 1.2)), p + Vector3(0, 0.65 * s2, 0)))
		l_xf[2].append(Transform3D(Basis().scaled(Vector3.ONE * 0.55 * s2), p + Vector3(0.55 * s2, 0.9 * s2, 0.2 * s2)))
	var r_xf: Array = []
	for rk in layout.get("rocks", []):
		var x3 := float(rk[0])
		var z3 := float(rk[1])
		var s3 := float(rk[2])
		r_xf.append(Transform3D(Basis().scaled(Vector3(s3 * rng.randf_range(0.8, 1.5), s3 * rng.randf_range(0.45, 0.85), s3 * rng.randf_range(0.8, 1.4))), Vector3(x3, height(x3, z3) + s3 * 0.2, z3)))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.19
	cm.bottom_radius = 0.34
	cm.height = 6.0
	cm.radial_segments = 6
	_multi_chunks(w, cm, trunk, t_xf, 320.0)
	var bm := CylinderMesh.new()
	bm.top_radius = 0.08
	bm.bottom_radius = 0.15
	bm.height = 2.0
	bm.radial_segments = 5
	_multi_chunks(w, bm, bark, b_xf, 160.0)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 5
	var all_xf: Array = []
	var all_col: Array = []
	for k in 3:
		for xf in l_xf[k]:
			all_xf.append(xf)
			all_col.append(leaf_cols[k])
	_multi_chunks(w, sm, leaf_mat, all_xf, 320.0, all_col)
	var rm := SphereMesh.new()
	rm.radius = 1.0
	rm.height = 1.25
	rm.radial_segments = 6
	rm.rings = 4
	_multi_chunks(w, rm, rock, r_xf, 120.0)
