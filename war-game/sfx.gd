extends RefCounted
## Звуки: справжні записи з res://sounds (вільна ліцензія CC0, OpenGameArt / The Free Firearm
## Sound Library); якщо файлу немає — синтезований звук.

const RATE := 22050
static var _cache := {}


static var _variants := {}


static func get_sound(kind: String) -> AudioStream:
	# записані варіанти: res://sounds/<kind>_1.ogg, _2.ogg ... (випадковий)
	if not _variants.has(kind):
		var arr: Array = []
		for i in range(1, 9):
			var p := "res://sounds/%s_%d.ogg" % [kind, i]
			if ResourceLoader.exists(p):
				arr.append(load(p))
		_variants[kind] = arr
	var v: Array = _variants[kind]
	if not v.is_empty():
		return v[randi() % v.size()]
	if _cache.has(kind):
		return _cache[kind]
	var s := _make(kind)
	_cache[kind] = s
	return s


## Звук пострілу для зброї.
static func shot_kind(weapon: String) -> String:
	match weapon:
		"ak74": return "shot_ak"
		"aks74u": return "shot_aks"
		"m4": return "shot_m4"
		"svd": return "shot_svd"
		"pkm": return "shot_pkm"
	return "shot_ak"


static func _make(kind: String) -> AudioStreamWAV:
	var dur := 0.3
	var loop := false
	match kind:
		"shot": dur = 0.35
		"shot_heavy": dur = 0.5
		"boom": dur = 1.8
		"drone":
			dur = 0.5
			loop = true
		"step": dur = 0.09
		"reload": dur = 0.5
		"hit": dur = 0.07
		"buy": dur = 0.18
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var lp2 := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for i in n:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var v := 0.0
		match kind:
			"shot":
				lp += (noise - lp) * 0.45
				v = lp * exp(-t * 26.0) * 1.3 + sin(TAU * 95.0 * t) * exp(-t * 22.0) * 0.9
			"shot_heavy":
				lp += (noise - lp) * 0.3
				v = lp * exp(-t * 16.0) * 1.4 + sin(TAU * 70.0 * t) * exp(-t * 14.0) * 1.0
			"boom":
				lp += (noise - lp) * 0.08
				lp2 += (lp - lp2) * 0.15
				v = lp2 * exp(-t * 2.4) * 5.0 + sin(TAU * (48.0 - t * 12.0) * t) * exp(-t * 3.0) * 0.9
			"drone":
				var f := 210.0
				var ph := fmod(t * f, 1.0)
				var ph2 := fmod(t * f * 1.5, 1.0)
				v = (ph * 2.0 - 1.0) * 0.35 + (ph2 * 2.0 - 1.0) * 0.18 + noise * 0.06
			"step":
				lp += (noise - lp) * 0.2
				v = lp * exp(-t * 55.0) * 1.6
			"reload":
				var c1 := exp(-t * 300.0) if t < 0.05 else 0.0
				var t2 := t - 0.32
				var c2 := exp(-t2 * 260.0) if t2 > 0.0 else 0.0
				v = noise * (c1 + c2) * 0.9 + sin(TAU * 1800.0 * t) * (c1 + c2) * 0.3
			"hit":
				v = sin(TAU * 1300.0 * t) * exp(-t * 60.0) * 0.6
			"buy":
				v = (sin(TAU * 880.0 * t) * 0.4 + sin(TAU * 1320.0 * t) * 0.3) * exp(-t * 18.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	return s


## Одноразовий звук у світі (3D) або в інтерфейсі (2D, якщо pos == null).
static func play(parent: Node, kind: String, pos = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return
	var p: Node
	if pos == null:
		var a := AudioStreamPlayer.new()
		a.stream = get_sound(kind)
		a.volume_db = volume_db
		a.pitch_scale = pitch
		a.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		p = a
		parent.add_child(a)
		a.play()
		a.finished.connect(a.queue_free)
	else:
		var a3 := AudioStreamPlayer3D.new()
		a3.stream = get_sound(kind)
		a3.volume_db = volume_db
		a3.pitch_scale = pitch
		a3.unit_size = 14.0 if kind.begins_with("shot") or kind.begins_with("boom") or kind == "rpg" else 6.0
		a3.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		a3.max_distance = 400.0
		p = a3
		parent.add_child(a3)
		a3.global_position = pos
		a3.play()
		a3.finished.connect(a3.queue_free)
