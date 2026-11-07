extends Control
## Верхня панель: живих, вбито, час бою, компас з градусами, приціл.

const Icons = preload("res://icons.gd")

var main
var round_t := 0.0


func setup(m) -> void:
	main = m
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _badge(pos: Vector2, icon: String, text: String, w: float, h: float) -> void:
	var font := ThemeDB.fallback_font
	var r := Rect2(pos, Vector2(w, h))
	draw_rect(r, Color(0.05, 0.06, 0.08, 0.72))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
	Icons.draw(self, icon, pos + Vector2(h * 0.5, h * 0.5), h * 0.62, Color(1, 1, 1, 0.92))
	draw_string(font, pos + Vector2(h * 0.95, h * 0.7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.55), Color(1, 1, 1))


func _process(delta: float) -> void:
	if main and main.alive_local:
		round_t += delta
	queue_redraw()


func _draw() -> void:
	if main == null:
		return
	var vs := get_viewport_rect().size
	var u := minf(vs.x / 1280.0, vs.y / 720.0)
	var font := ThemeDB.fallback_font
	var h := 30.0 * u
	# живих / вбито / час
	var alive := 1 if main.alive_local else 0
	for id in main.avatars:
		if main.avatars[id].visible:
			alive += 1
	var kills := 0
	if main.players.has(main.my_id):
		kills = int(main.players[main.my_id].kills)
	_badge(Vector2(14.0 * u, 12.0 * u), "people", "%d" % alive, 86.0 * u, h)
	_badge(Vector2(106.0 * u, 12.0 * u), "skull", "%d" % kills, 76.0 * u, h)
	var t := int(round_t)
	_badge(Vector2(188.0 * u, 12.0 * u), "clock", "%02d:%02d" % [t / 60, t % 60], 104.0 * u, h)

	# компас
	var cw := 520.0 * u
	var cx := vs.x * 0.5
	var cy := 30.0 * u
	var heading := 0.0
	if main.soldier:
		heading = fposmod(-rad_to_deg(main.soldier.rotation.y), 360.0)
	draw_rect(Rect2(cx - cw * 0.5, cy - 20.0 * u, cw, 36.0 * u), Color(0, 0, 0, 0.25))
	var px_per_deg := cw / 130.0
	var start := int(floor((heading - 65.0) / 15.0)) * 15
	var d := start
	var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	while d <= heading + 65.0:
		var x := cx + (d - heading) * px_per_deg
		var a := 1.0 - absf(d - heading) / 70.0
		var dd := int(fposmod(d, 360.0))
		var col := Color(1, 1, 1, clampf(a, 0.0, 1.0) * 0.9)
		draw_line(Vector2(x, cy - 18.0 * u), Vector2(x, cy - 10.0 * u), col, 1.5)
		var label: String = names.get(dd, str(dd))
		var fsz := int((19.0 if names.has(dd) else 15.0) * u)
		draw_string(font, Vector2(x - 30.0 * u, cy + 8.0 * u), label, HORIZONTAL_ALIGNMENT_CENTER, 60.0 * u, fsz, col)
		d += 15
	# поточний курс
	var box := Rect2(cx - 34.0 * u, cy - 4.0 * u, 68.0 * u, 30.0 * u)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 7.0 * u, cy - 20.0 * u), Vector2(cx + 7.0 * u, cy - 20.0 * u), Vector2(cx, cy - 11.0 * u)]), Color(1, 1, 1))
	draw_rect(box, Color(0.05, 0.06, 0.08, 0.85))
	draw_string(font, box.position + Vector2(0.0, 23.0 * u), "%d" % (int(round(heading)) % 360), HORIZONTAL_ALIGNMENT_CENTER, box.size.x, int(24.0 * u), Color(1, 1, 1))

	# приціл
	if main.alive_local and main.soldier and not main.soldier.drone_active:
		var c := vs * 0.5
		var g := 9.0 if not main.soldier.aiming else 4.0
		var col2 := Color(1, 1, 1, 0.9)
		for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + v * g, c + v * (g + 12.0), col2, 2.0)
		draw_circle(c, 1.6, col2)
