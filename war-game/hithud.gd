extends Control
## Індикатори влучань: червоні дуги з боку, звідки стріляли, силует тіла з зонами,
## маркер влучання для стрільця.

var main
var hits: Array = []   # [кут світу, час, сила]
var mark_t := 0.0
var mark_zone := 1


func setup(m) -> void:
	main = m
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func add_hit(from: Vector3, zone: int, dmg: int) -> void:
	if main.soldier == null:
		return
	var p: Vector3 = main.soldier.global_position
	var d := Vector2(from.x - p.x, from.z - p.z)
	if from == Vector3.ZERO or d.length() < 0.3:
		return
	hits.append([atan2(d.x, d.y), 1.6, clampf(dmg / 40.0, 0.4, 1.0)])
	if hits.size() > 6:
		hits.pop_front()


func hitmark(zone: int) -> void:
	mark_t = 0.35
	mark_zone = zone


func _process(delta: float) -> void:
	var keep: Array = []
	for h in hits:
		h[1] -= delta
		if h[1] > 0.0:
			keep.append(h)
	hits = keep
	mark_t = maxf(0.0, mark_t - delta)
	queue_redraw()


## Силует людини з підсвіченими зонами. h — висота силуету.
static func draw_body(ci: CanvasItem, top: Vector2, h: float, dmg: Array, flash: Array, alpha: float = 0.8) -> void:
	var u := h / 10.0
	var cx := top.x
	var zones := [
		["c", Vector2(cx, top.y + u * 0.8), u * 0.75],                                 # 0 голова
		["r", Rect2(cx - u * 1.0, top.y + u * 1.75, u * 2.0, u * 1.6)],                # 1 груди
		["r", Rect2(cx - u * 0.9, top.y + u * 3.4, u * 1.8, u * 1.3)],                 # 2 живіт
		["r", Rect2(cx - u * 1.75, top.y + u * 1.85, u * 0.65, u * 3.3)],              # 3 ліва рука (на екрані зліва)
		["r", Rect2(cx + u * 1.1, top.y + u * 1.85, u * 0.65, u * 3.3)],               # 4 права рука
		["r", Rect2(cx - u * 0.9, top.y + u * 4.8, u * 0.8, u * 4.9)],                 # 5 ліва нога
		["r", Rect2(cx + u * 0.1, top.y + u * 4.8, u * 0.8, u * 4.9)],                 # 6 права нога
	]
	for i in zones.size():
		var z: Array = zones[i]
		var d := float(dmg[i]) if i < dmg.size() else 0.0
		var f := float(flash[i]) if i < flash.size() else 0.0
		var k := clampf(d / 60.0, 0.0, 1.0)
		var col := Color(0.75, 0.78, 0.7, 0.35 * alpha).lerp(Color(0.75, 0.1, 0.08, 0.75 * alpha), k)
		col = col.lerp(Color(1.0, 0.12, 0.05, alpha), clampf(f, 0.0, 1.0))
		if z[0] == "c":
			ci.draw_circle(z[1], z[2], col)
			ci.draw_arc(z[1], z[2], 0.0, TAU, 24, Color(0, 0, 0, 0.5 * alpha), 1.5)
		else:
			ci.draw_rect(z[1], col)
			ci.draw_rect(z[1], Color(0, 0, 0, 0.5 * alpha), false, 1.5)


func _draw() -> void:
	if main == null or not main.alive_local:
		return
	var vs := get_viewport_rect().size
	var c := vs * 0.5
	# напрямок пострілу відносно погляду
	var yaw := 0.0
	if main.soldier:
		yaw = main.soldier.rotation.y
	for h in hits:
		var rel: float = h[0] - (yaw + PI)   # 0 = попереду
		var a: float = -rel - PI * 0.5
		var al: float = clampf(h[1] / 1.6, 0.0, 1.0) * float(h[2])
		draw_arc(c, 170.0, a - 0.32, a + 0.32, 20, Color(1.0, 0.1, 0.05, 0.85 * al), 12.0)
		draw_arc(c, 186.0, a - 0.18, a + 0.18, 14, Color(1.0, 0.3, 0.2, 0.6 * al), 5.0)
	# силует з зонами під грошима
	draw_body(self, Vector2(vs.x - 262.0, 14.0), 120.0, main.zone_dmg, main.zone_flash, 0.85)
	# маркер влучання для стрільця
	if mark_t > 0.0:
		var col := Color(1.0, 0.25, 0.2, mark_t / 0.35) if mark_zone == 0 else Color(1, 1, 1, mark_t / 0.35)
		for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + s * 8.0, c + s * 20.0, col, 3.0)
