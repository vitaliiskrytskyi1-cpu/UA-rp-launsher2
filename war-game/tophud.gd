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

	# приціл: мушка
	if main.alive_local and main.soldier and not main.soldier.drone_active and main.soldier.in_veh < 0:
		var c := vs * 0.5
		var sd = main.soldier
		if sd.aiming and sd.slot == 0:
			_iron_sight(c, vs, u, float(sd.wdata.zoom) < 30.0)
		else:
			var col2 := Color(1, 1, 1, 0.92)
			var sh := Color(0, 0, 0, 0.55)
			# мушка: стійка з захисними «вушками»
			for k in 2:
				var o := Vector2(1, 1) if k == 0 else Vector2.ZERO
				var cc: Color = sh if k == 0 else col2
				draw_rect(Rect2(c + o + Vector2(-1.5, -1.0), Vector2(3.0, 14.0)), cc)
				draw_arc(c + o + Vector2(0, 6.0), 11.0, PI * 1.05, PI * 1.95, 14, cc, 2.0)
				draw_line(c + o + Vector2(-11.0, 6.0), c + o + Vector2(-11.0, 15.0), cc, 2.0)
				draw_line(c + o + Vector2(11.0, 6.0), c + o + Vector2(11.0, 15.0), cc, 2.0)
			draw_circle(c, 1.5, Color(1, 0.3, 0.2, 0.9))


## Відкритий приціл: цілик знизу, мушка в центрі (для СВД — оптика ПСО).
func _iron_sight(c: Vector2, vs: Vector2, u: float, scope: bool) -> void:
	var dark := Color(0.05, 0.05, 0.04, 0.96)
	if scope:
		var r := vs.y * 0.42
		# затемнення навколо оптики
		var pts := PackedVector2Array()
		for i in 49:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_rect(Rect2(0, 0, c.x - r, vs.y), dark)
		draw_rect(Rect2(c.x + r, 0, vs.x - c.x - r, vs.y), dark)
		for i in 48:
			var a0 := TAU * i / 48.0
			var a1 := TAU * (i + 1) / 48.0
			var p0 := c + Vector2(cos(a0), sin(a0)) * r
			var p1 := c + Vector2(cos(a1), sin(a1)) * r
			var q0 := c + Vector2(cos(a0), sin(a0)) * r * 1.6
			var q1 := c + Vector2(cos(a1), sin(a1)) * r * 1.6
			draw_colored_polygon(PackedVector2Array([p0, q0, q1, p1]), dark)
		draw_arc(c, r, 0.0, TAU, 64, Color(0, 0, 0, 1), 6.0)
		var rc := Color(0.05, 0.05, 0.05, 0.95)
		# шеврони ПСО і шкала
		for k in 4:
			var y := c.y + k * 22.0 * u
			var w := 10.0 * u
			draw_line(Vector2(c.x - w, y + w), Vector2(c.x, y), rc, 2.0)
			draw_line(Vector2(c.x + w, y + w), Vector2(c.x, y), rc, 2.0)
		draw_line(Vector2(c.x - r * 0.8, c.y), Vector2(c.x - 14.0 * u, c.y), rc, 2.0)
		draw_line(Vector2(c.x + 14.0 * u, c.y), Vector2(c.x + r * 0.8, c.y), rc, 2.0)
		for k in range(-4, 5):
			if k != 0:
				draw_line(Vector2(c.x + k * 18.0 * u, c.y - 5.0), Vector2(c.x + k * 18.0 * u, c.y + 5.0), rc, 1.5)
		return
	# цілик: темна планка з прорізом
	var bw := 360.0 * u
	var by := c.y + 30.0 * u
	var notch := 22.0 * u
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - bw, vs.y), Vector2(c.x - bw, by + 18.0 * u), Vector2(c.x - notch, by), Vector2(c.x - notch * 0.7, by + notch), Vector2(c.x + notch * 0.7, by + notch), Vector2(c.x + notch, by), Vector2(c.x + bw, by + 18.0 * u), Vector2(c.x + bw, vs.y)]), dark)
	draw_line(Vector2(c.x - notch, by), Vector2(c.x - notch * 0.7, by + notch), Color(0.25, 0.25, 0.22), 2.0)
	draw_line(Vector2(c.x + notch, by), Vector2(c.x + notch * 0.7, by + notch), Color(0.25, 0.25, 0.22), 2.0)
	# мушка: стійка з кільцем
	var pw := 5.0 * u
	draw_rect(Rect2(c.x - pw * 0.5, c.y, pw, by + notch - c.y), dark)
	draw_rect(Rect2(c.x - 60.0 * u, by + notch * 0.9, 120.0 * u, 260.0 * u), dark)
	draw_arc(c + Vector2(0, 10.0 * u), 26.0 * u, PI * 1.08, PI * 1.92, 24, dark, 5.0 * u)
	draw_line(c + Vector2(-26.0 * u, 10.0 * u), c + Vector2(-26.0 * u, 60.0 * u), dark, 5.0 * u)
	draw_line(c + Vector2(26.0 * u, 10.0 * u), c + Vector2(26.0 * u, 60.0 * u), dark, 5.0 * u)
