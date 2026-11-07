extends RefCounted
## Налаштування гри: зберігаються у user://settings.cfg (ConfigFile) і застосовуються одразу.
## Розділи: main (нік, сервер), graphics, audio, controls, mic, hud.

const PATH := "user://settings.cfg"
static var _cfg: ConfigFile

const DEFAULTS := {
	"graphics": {"quality": 1, "textures": 1, "fps": 60, "shadows": 1, "grass": 1.0},
	"audio": {"master": 0.9, "music": 0.5, "sfx": 0.9},
	"controls": {"sens": 1.0, "aim_sens": 1.0, "drone_sens": 1.0, "invert_y": 0, "auto_sprint": 1, "hud_profile": 1},
	"mic": {"enabled": 0, "device": "Default", "volume": 0.8, "push_to_talk": 1},
}


static func cfg() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)
	return _cfg


static func value(sec: String, key: String, def = null):
	if def == null and DEFAULTS.has(sec) and DEFAULTS[sec].has(key):
		def = DEFAULTS[sec][key]
	var c := cfg()
	if c.has_section_key(sec, key):
		return c.get_value(sec, key)
	return def


static func set_value(sec: String, key: String, v, save_now: bool = true) -> void:
	cfg().set_value(sec, key, v)
	if save_now:
		cfg().save(PATH)


static func save() -> void:
	cfg().save(PATH)


## Застосувати графіку, FPS і гучність.
static func apply(tree: SceneTree) -> void:
	# шини звуку
	for b in ["Music", "SFX"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_vol("Master", float(value("audio", "master")))
	_vol("Music", float(value("audio", "music")))
	_vol("SFX", float(value("audio", "sfx")))
	var fps := int(value("graphics", "fps"))
	Engine.max_fps = fps
	if tree == null:
		return
	var vp := tree.root
	var q := int(value("graphics", "quality"))
	vp.scaling_3d_scale = [0.7, 0.85, 1.0][clampi(q, 0, 2)]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][clampi(q, 0, 2)]
	vp.mesh_lod_threshold = [4.0, 1.5, 1.0][clampi(q, 0, 2)]
	vp.texture_mipmap_bias = [1.0, 0.0, -0.5][clampi(int(value("graphics", "textures")), 0, 2)]
	var shadows := int(value("graphics", "shadows")) == 1
	for s in tree.get_nodes_in_group("sun"):
		(s as DirectionalLight3D).shadow_enabled = shadows
	var gr := float(value("graphics", "grass"))
	for g in tree.get_nodes_in_group("grass"):
		(g as GeometryInstance3D).visible = gr > 0.05
		(g as GeometryInstance3D).visibility_range_end = 55.0 * maxf(gr, 0.05)


static func _vol(bus: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, lin <= 0.01)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 0.001)))
