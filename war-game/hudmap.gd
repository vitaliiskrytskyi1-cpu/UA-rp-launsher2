extends Control
## Карта: міні-карта в куті екрана і повноекранна карта.
## Показує окопи, лісосмуги, бази, точку захоплення, себе, побратимів і свій дрон.
## Свою базу завжди видно внизу карти.

const World = preload("res://world.gd")
const Icons = preload("res://icons.gd")

var main
var full := false
var _tex: Texture2D
var _tex_id := ""


static func span() -> float:
	return maxf(float(World.cur.half), float(World.cur.get("hz", World.cur.half)))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(m, is_full: bool) -> void:
	main = m
	full = is_full
	if full:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		anchor_left = 1.0
		anchor_right = 1.0
		offset_left = -230.0
		offset_right = -8.0
		offset_top = 8.0
		offset_bottom = 230.0


func _gui_input(event: InputEvent) -> void:
	if full and ((event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)):
		var p: Vector2 = event.position
		if p.distance_to(Vector2(size.x - 50.0, 50.0)) < 55.0:
			main.close_bigmap()
		accept_event()


func _map_rect() -> Rect2:
	if full:
		var s := size
		var side := minf(s.x, s.y) - 60.0
		return Rect2((s.x - side) * 0.5, 30.0, side, side)
	return Rect2(Vector2.ZERO, size)


func _to_screen(r: Rect2, p: Vector3) -> Vector2:
	var flip := 1.0 if main.my_team == 1 else -1.0
	var k := r.size.x / (span() * 2.0)
	return r.position + r.size * 0.5 + Vector2(p.x * flip, p.z * flip) * k


func _draw() -> void:
	if main == null:
		return
	var r := _map_rect()
	if full:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
		draw_circle(Vector2(size.x - 50.0, 50.0), 30.0, Color(0, 0, 0, 0.6))
		Icons.draw(self, "close", Vector2(size.x - 50.0, 50.0), 40.0, Color(1, 1, 1, 0.9))
	draw_rect(r, Color(0.22, 0.27, 0.16, 0.88))
	draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
	var lw := 3.0 if full else 1.6
	var scan: bool = World.cur.has("file")
	if scan:
		# вид згори на скан місцевості
		if _tex_id != String(World.cur.id):
			_tex_id = String(World.cur.id)
			_tex = load("res://maps/%s_top.png" % World.cur.file)
		if _tex:
			var flip := 1.0 if main.my_team == 1 else -1.0
			var c := r.position + r.size * 0.5
			draw_set_transform(c, 0.0 if flip > 0.0 else PI, Vector2.ONE)
			draw_texture_rect(_tex, Rect2(-r.size * 0.5, r.size), false, Color(1, 1, 1, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rows := []
	for s in [-1.0, 1.0]:
		rows.append([Vector3(-140, 0, s * 20), Vector3(140, 0, s * 20)])
		rows.append([Vector3(-140, 0, s * 66), Vector3(140, 0, s * 66)])
		rows.append([Vector3(s * 62, 0, -38), Vector3(s * 62, 0, 38)])
		rows.append([Vector3(s * 100, 0, s * 92), Vector3(s * 100, 0, s * 140)])
	for row in ([] if scan else rows):
		draw_line(_to_screen(r, row[0]), _to_screen(r, row[1]), Color(0.12, 0.3, 0.1), lw * 2.2)
	# окопи
	for tz in ([] if scan else World.TRENCH_Z):
		draw_line(_to_screen(r, Vector3(-World.TRENCH_X, 0, tz)), _to_screen(r, Vector3(World.TRENCH_X, 0, tz)), Color(0.45, 0.33, 0.2), lw * 1.6)
	# бази
	for t in 2:
		var bp := World.base_pos(t)
		var br: float = World.cur.base_r
		var a := _to_screen(r, Vector3(bp.x - br, 0, bp.y - br * 0.45))
		var b := _to_screen(r, Vector3(bp.x + br, 0, bp.y + br * 0.45))
		var rect := Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())
		var col: Color = main.TEAM_COLORS[t]
		draw_rect(rect, Color(col.r, col.g, col.b, 0.25))
		draw_rect(rect, col, false, lw)
	# точка захоплення
	var cc := _to_screen(r, Vector3.ZERO)
	var cr := float(World.cur.cap) * r.size.x / (span() * 2.0)
	var capcol := Color(1, 1, 1, 0.8)
	if main.capture <= -100.0:
		capcol = main.TEAM_COLORS[0]
	elif main.capture >= 100.0:
		capcol = main.TEAM_COLORS[1]
	draw_circle(cc, cr, Color(capcol.r, capcol.g, capcol.b, 0.35))
	draw_arc(cc, cr, 0.0, TAU, 24, capcol, lw)

	# побратими
	var dot := 6.0 if full else 3.5
	for id in main.avatars:
		if not main.players.has(id) or main.players[id].team != main.my_team:
			continue
		var av = main.avatars[id]
		if av.visible:
			draw_circle(_to_screen(r, av.position), dot, main.TEAM_COLORS[main.my_team])
			if full:
				var font := ThemeDB.fallback_font
				draw_string(font, _to_screen(r, av.position) + Vector2(8, 4), str(main.players[id].nick), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))
	# вороги, яких бачить розвідник
	for id in main.avatars:
		if not main.players.has(id) or main.players[id].team == main.my_team:
			continue
		if main.is_spotted(id):
			var ep := _to_screen(r, main.avatars[id].position)
			draw_circle(ep, dot * 1.1, Color(1.0, 0.15, 0.1))
			draw_arc(ep, dot * 1.9, 0.0, TAU, 12, Color(1.0, 0.3, 0.2, 0.7), 1.5)
	# техніка
	for vid in main.vnodes:
		var vn = main.vnodes[vid]
		if not vn.alive:
			continue
		var vp := _to_screen(r, vn.global_position)
		var vc: Color = main.TEAM_COLORS[int(vn.team)] if int(vn.team) == main.my_team or main.is_spotted(-1000 - vid) else Color(0, 0, 0, 0)
		if vc.a > 0.0:
			draw_rect(Rect2(vp - Vector2(dot, dot * 0.7), Vector2(dot * 2.0, dot * 1.4)), vc)
			draw_rect(Rect2(vp - Vector2(dot, dot * 0.7), Vector2(dot * 2.0, dot * 1.4)), Color(0, 0, 0, 0.8), false, 1.0)
	# ціль від розвідника
	if main.waypoint_t > 0.0:
		var wp := _to_screen(r, main.waypoint)
		var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 150.0)
		draw_line(wp, wp + Vector2(0, -dot * 4.0), Color(1, 0.85, 0.2), 2.0)
		draw_colored_polygon(PackedVector2Array([wp + Vector2(0, -dot * 4.0), wp + Vector2(dot * 2.6, -dot * 3.2), wp + Vector2(0, -dot * 2.4)]), Color(1, 0.3, 0.15, blink))
	# я і мій дрон
	var me = main.soldier
	if me and main.alive_local:
		var p := _to_screen(r, me.global_position)
		var flip := 1.0 if main.my_team == 1 else -1.0
		var yaw: float = me.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw)) * flip
		var side := Vector2(-fwd.y, fwd.x)
		var s2 := 9.0 if full else 6.0
		draw_colored_polygon(PackedVector2Array([p + fwd * s2 * 1.4, p - fwd * s2 * 0.8 + side * s2 * 0.8, p - fwd * s2 * 0.4, p - fwd * s2 * 0.8 - side * s2 * 0.8]), Color(1, 1, 1))
		if me.drone_active and me.drone_node:
			var dp := _to_screen(r, me.drone_node.global_position)
			draw_line(p, dp, Color(1, 0.8, 0.2, 0.6), 1.0)
			draw_circle(dp, dot * 0.9, Color(1, 0.3, 0.2))
		if me.mortar_valid:
			var mp := _to_screen(r, me.mortar_target)
			draw_arc(mp, dot * 2.0, 0.0, TAU, 16, Color(1, 0.3, 0.2), 2.0)
	if full:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(r.position.x, r.end.y + 24.0), "", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color(1, 1, 1, 0.8))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()
