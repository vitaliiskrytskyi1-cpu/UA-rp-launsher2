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
	var chunk := 40
	var i0 := 0
	while i0 < n - 1:
		var j0 := 0
		while j0 < n - 1:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var i1 := mini(i0 + chunk, n - 1)
			var j1 := mini(j0 + chunk, n - 1)
			var cols := j1 - j0 + 1
			for i in range(i0, i1 + 1):
				for j in range(j0, j1 + 1):
					var y := h_at(i, j)
					var nx := h_at(i, j - 1) - h_at(i, j + 1)
					var nz := h_at(i - 1, j) - h_at(i + 1, j)
					var nrm := Vector3(nx, 2.0, nz).normalized()
					var mk := 0.0
					if tmask.size() > 0:
						mk = float(tmask[i * n + j]) / 255.0
					st.set_color(Color(mk, nrm.y, 0.0))
					st.set_normal(nrm)
					st.add_vertex(Vector3(x0 + j, y, x0 + i))
			for i in range(0, i1 - i0):
				for j in range(0, j1 - j0):
					var a := i * cols + j
					st.add_index(a)
					st.add_index(a + 1)
					st.add_index(a + cols)
					st.add_index(a + 1)
					st.add_index(a + cols + 1)
					st.add_index(a + cols)
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
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
	for pr in layout.props:
		var t := String(pr.t)
		var xf := Transform3D(Basis(Vector3.UP, float(pr.yaw)), Vector3(float(pr.x), float(pr.y), float(pr.z)))
		var sh := _prop_shape(t)
		if sh != null:
			var b := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = sh
			if sh is BoxShape3D:
				cs.position.y = (sh as BoxShape3D).size.y * 0.5
			b.add_child(cs)
			b.transform = xf
			w.add_child(b)
		if visuals:
			var ps := _prop_scene(t)
			if ps:
				var node: Node3D = ps.instantiate()
				node.transform = xf
				w.add_child(node)
				if OVERRIDE.has(t):
					_override(node, _ov_mat(t))
				_set_range(node, float(VIS_RANGE.get(t, 260.0)))


const OVERRIDE := {"bunker": ["cement", 0.35, Color(0.62, 0.62, 0.58)], "ruin": ["ruin", 0.3, Color(0.6, 0.58, 0.55)], "hedgehog": ["metal", 0.8, Color(0.35, 0.3, 0.27)], "tower": ["greenmetal", 0.6, Color(0.8, 0.8, 0.8)], "wire_x": ["metal", 1.5, Color(0.3, 0.28, 0.25)], "wire_coil": ["metal", 1.5, Color(0.4, 0.38, 0.35)]}
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
	var m_log := pack_mat("dirt", 0.8, Color(0.75, 0.6, 0.45))
	var m_soil := pack_mat("dirt", 0.4)
	var log_m := CylinderMesh.new()
	log_m.top_radius = 0.15
	log_m.bottom_radius = 0.16
	log_m.height = 4.0
	log_m.radial_segments = 8
	for d in layout.dugouts:
		var x := float(d.x)
		var z := float(d.z)
		var y := float(d.y)
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(5.0, 0.6, 3.8)
		cs.shape = bs
		b.add_child(cs)
		b.position = Vector3(x, y + 0.15, z)
		w.add_child(b)
		if visuals:
			for k in 11:
				var lg := MeshInstance3D.new()
				lg.mesh = log_m
				lg.material_override = m_log
				lg.rotation = Vector3(PI * 0.5, 0.0, 0.0)
				lg.position = Vector3(x - 2.25 + k * 0.45, y - 0.05, z)
				w.add_child(lg)
			var mound := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 1.0
			sm.height = 0.6
			sm.is_hemisphere = true
			mound.mesh = sm
			mound.scale = Vector3(2.8, 1.0, 2.2)
			mound.position = Vector3(x, y + 0.05, z + float(d.s) * 0.3)
			mound.material_override = m_soil
			w.add_child(mound)
			# лампа всередині
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.8, 0.5)
			lamp.light_energy = 0.8
			lamp.omni_range = 4.0
			lamp.position = Vector3(x, y - 0.6, z)
			w.add_child(lamp)


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
		var net := MeshInstance3D.new()
		net.mesh = pm
		net.material_override = mat
		net.position = Vector3(x, y + hh, z)
		net.visibility_range_end = 200.0
		w.add_child(net)
		# краї сітки спускаються до землі
		for s in [-1.0, 1.0]:
			var side := MeshInstance3D.new()
			var sp := PlaneMesh.new()
			sp.size = Vector2(wd, hh * 1.2)
			side.mesh = sp
			side.material_override = mat
			side.rotation = Vector3(s * 0.95, 0.0, 0.0)
			side.position = Vector3(x, y + hh * 0.55, z + s * (dp * 0.5 + hh * 0.3))
			side.visibility_range_end = 200.0
			w.add_child(side)
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var pole := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04
			cm.bottom_radius = 0.05
			cm.height = hh
			cm.radial_segments = 5
			pole.mesh = cm
			pole.material_override = m_pole
			var px: float = x + c.x * wd * 0.45
			var pz: float = z + c.y * dp * 0.45
			pole.position = Vector3(px, height(px, pz) + hh * 0.5, pz)
			w.add_child(pole)


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
static func _multi_chunks(w: Node3D, mesh: Mesh, mat: Material, xforms: Array, rng_end: float = 260.0) -> void:
	var groups := {}
	for xf in xforms:
		var o: Vector3 = (xf as Transform3D).origin
		var key := Vector2i(int(floorf(o.x / 50.0)), int(floorf(o.z / 50.0)))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(xf)
	for key in groups:
		var arr: Array = groups[key]
		var center := Vector3(key.x * 50.0 + 25.0, 0.0, key.y * 50.0 + 25.0)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for k in arr.size():
			var xf: Transform3D = arr[k]
			xf.origin -= center
			mm.set_instance_transform(k, xf)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.position = center
		mmi.visibility_range_end = rng_end
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
			for k in 60:
				var px := cx + r.randf() * chunk
				var pz := cz + r.randf() * chunk
				var i := int(roundf(pz - x0))
				var j := int(roundf(px - x0))
				if tmask.size() > 0 and tmask[clampi(i, 0, n - 1) * n + clampi(j, 0, n - 1)] > 40:
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
