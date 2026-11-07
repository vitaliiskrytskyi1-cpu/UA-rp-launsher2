extends RefCounted
## Векторні значки для кнопок і інвентаря (малюються кодом, без файлів).

static func draw(ci: CanvasItem, name: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.09)
	match name:
		"fire":
			# куля
			var pts := PackedVector2Array([c + Vector2(-s * 0.18, s * 0.45), c + Vector2(-s * 0.18, -s * 0.1), c + Vector2(0, -s * 0.48), c + Vector2(s * 0.18, -s * 0.1), c + Vector2(s * 0.18, s * 0.45)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(-s * 0.22, s * 0.2), c + Vector2(s * 0.22, s * 0.2), Color(0, 0, 0, 0.5), w * 0.6)
		"aim":
			ci.draw_arc(c, s * 0.38, 0.0, TAU, 32, col, w)
			ci.draw_circle(c, s * 0.06, col)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				ci.draw_line(c + d * s * 0.2, c + d * s * 0.5, col, w)
		"jump", "up":
			_arrow(ci, c, s, col, w, -1.0)
		"down":
			_arrow(ci, c, s, col, w, 1.0)
		"crouch":
			# людина присіла: голова, тулуб, зігнуті ноги
			ci.draw_circle(c + Vector2(s * 0.05, -s * 0.36), s * 0.11, col)
			ci.draw_line(c + Vector2(s * 0.02, -s * 0.22), c + Vector2(-s * 0.1, s * 0.08), col, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.08), c + Vector2(s * 0.2, s * 0.12), col, w * 1.2)
			ci.draw_line(c + Vector2(s * 0.2, s * 0.12), c + Vector2(s * 0.14, s * 0.42), col, w * 1.2)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.08), c + Vector2(-s * 0.22, s * 0.42), col, w * 1.2)
			ci.draw_line(c + Vector2(-s * 0.02, -s * 0.12), c + Vector2(s * 0.3, -s * 0.08), col, w)
		"stand":
			ci.draw_circle(c + Vector2(0, -s * 0.38), s * 0.11, col)
			ci.draw_line(c + Vector2(0, -s * 0.25), c + Vector2(0, s * 0.1), col, w * 1.3)
			ci.draw_line(c + Vector2(0, s * 0.1), c + Vector2(-s * 0.14, s * 0.45), col, w * 1.2)
			ci.draw_line(c + Vector2(0, s * 0.1), c + Vector2(s * 0.14, s * 0.45), col, w * 1.2)
			ci.draw_line(c + Vector2(0, -s * 0.15), c + Vector2(s * 0.3, -s * 0.05), col, w)
		"reload":
			ci.draw_arc(c, s * 0.32, 0.4, TAU - 0.3, 28, col, w)
			var tip := c + Vector2(cos(0.4), sin(0.4)) * s * 0.32
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.16, -s * 0.02), tip + Vector2(s * 0.12, -s * 0.06), tip + Vector2(0, s * 0.16)]), col)
		"rifle":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.48, -s * 0.07), Vector2(s * 0.62, s * 0.12)), col)
			ci.draw_line(c + Vector2(s * 0.14, -s * 0.03), c + Vector2(s * 0.5, -s * 0.03), col, w * 0.8)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.48, -s * 0.07), c + Vector2(-s * 0.48, s * 0.18), c + Vector2(-s * 0.3, s * 0.05)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.05, s * 0.05), c + Vector2(s * 0.05, s * 0.05), c + Vector2(s * 0.1, s * 0.32), c + Vector2(0, s * 0.34)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.05), Vector2(s * 0.07, s * 0.14)), col)
		"rpg":
			ci.draw_line(c + Vector2(-s * 0.48, s * 0.08), c + Vector2(s * 0.2, s * 0.08), col, w * 1.6)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.2, -s * 0.06), c + Vector2(s * 0.5, s * 0.08), c + Vector2(s * 0.2, s * 0.22)]), col)
			ci.draw_line(c + Vector2(-s * 0.1, s * 0.14), c + Vector2(-s * 0.1, s * 0.34), col, w)
		"mortar":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.38), c + Vector2(s * 0.2, -s * 0.42), col, w * 1.8)
			ci.draw_line(c + Vector2(-s * 0.04, -s * 0.02), c + Vector2(s * 0.28, s * 0.4), col, w * 0.9)
			ci.draw_line(c + Vector2(-s * 0.44, s * 0.4), c + Vector2(-s * 0.14, s * 0.4), col, w * 1.2)
		"hands":
			ci.draw_arc(c + Vector2(0, s * 0.05), s * 0.26, PI, TAU, 16, col, w * 1.2)
			for i in 4:
				var x := -s * 0.2 + i * s * 0.13
				ci.draw_line(c + Vector2(x, s * 0.05), c + Vector2(x, -s * 0.32), col, w)
			ci.draw_line(c + Vector2(-s * 0.26, s * 0.05), c + Vector2(-s * 0.4, -s * 0.12), col, w)
		"drone":
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.3, s * 0.3), col, w)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.3), c + Vector2(-s * 0.3, s * 0.3), col, w)
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				ci.draw_arc(c + d * s * 0.3, s * 0.15, 0.0, TAU, 16, col, w * 0.7)
			ci.draw_rect(Rect2(c - Vector2(s * 0.1, s * 0.1), Vector2(s * 0.2, s * 0.2)), col)
		"boom":
			var pts := PackedVector2Array()
			for i in 16:
				var r := s * (0.48 if i % 2 == 0 else 0.22)
				var a := TAU * i / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
		"speed":
			ci.draw_arc(c + Vector2(0, s * 0.1), s * 0.38, PI, TAU, 24, col, w)
			ci.draw_line(c + Vector2(0, s * 0.1), c + Vector2(s * 0.25, -s * 0.18), col, w * 1.2)
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.06, col)
		"shop":
			ci.draw_line(c + Vector2(-s * 0.45, -s * 0.3), c + Vector2(-s * 0.3, -s * 0.3), col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.22), c + Vector2(s * 0.42, -s * 0.22), c + Vector2(s * 0.32, s * 0.12), c + Vector2(-s * 0.2, s * 0.12)]), col)
			ci.draw_circle(c + Vector2(-s * 0.14, s * 0.3), s * 0.08, col)
			ci.draw_circle(c + Vector2(s * 0.26, s * 0.3), s * 0.08, col)
		"bag":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.22), Vector2(s * 0.64, s * 0.66)), col)
			ci.draw_arc(c + Vector2(0, -s * 0.22), s * 0.16, PI, TAU, 12, col, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.22, s * 0.08), Vector2(s * 0.44, s * 0.22)), Color(0, 0, 0, 0.35))
		"map":
			var pts := PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.3), c + Vector2(-s * 0.15, -s * 0.4), c + Vector2(s * 0.15, -s * 0.3), c + Vector2(s * 0.45, -s * 0.4), c + Vector2(s * 0.45, s * 0.3), c + Vector2(s * 0.15, s * 0.4), c + Vector2(-s * 0.15, s * 0.3), c + Vector2(-s * 0.45, s * 0.4)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(-s * 0.15, -s * 0.4), c + Vector2(-s * 0.15, s * 0.3), Color(0, 0, 0, 0.4), w * 0.6)
			ci.draw_line(c + Vector2(s * 0.15, -s * 0.3), c + Vector2(s * 0.15, s * 0.4), Color(0, 0, 0, 0.4), w * 0.6)
		"armor":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.36), c + Vector2(-s * 0.12, -s * 0.36), c + Vector2(0, -s * 0.24), c + Vector2(s * 0.12, -s * 0.36), c + Vector2(s * 0.36, -s * 0.36), c + Vector2(s * 0.36, s * 0.42), c + Vector2(-s * 0.36, s * 0.42)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.1), Vector2(s * 0.48, s * 0.36)), Color(0, 0, 0, 0.3), false, w * 0.6)
		"helmet":
			ci.draw_arc(c + Vector2(0, s * 0.12), s * 0.4, PI, TAU, 20, col, w * 2.4)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, s * 0.12), c + Vector2(s * 0.4, s * 0.12), c + Vector2(s * 0.48, s * 0.26), c + Vector2(-s * 0.48, s * 0.26)]), col)
			ci.draw_arc(c + Vector2(0, s * 0.12), s * 0.26, PI, TAU, 16, col, w * 3.0)
		"rig":
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.42 + i * s * 0.3, -s * 0.2), Vector2(s * 0.24, s * 0.5)), col)
			ci.draw_line(c + Vector2(-s * 0.45, -s * 0.3), c + Vector2(s * 0.45, -s * 0.3), col, w)
		"mag":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.16, -s * 0.42), c + Vector2(s * 0.12, -s * 0.42), c + Vector2(s * 0.24, s * 0.42), c + Vector2(-s * 0.04, s * 0.42)]), col)
			ci.draw_line(c + Vector2(-s * 0.1, -s * 0.3), c + Vector2(s * 0.08, -s * 0.3), Color(0, 0, 0, 0.4), w * 0.6)
		"rocket":
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.0), c + Vector2(s * 0.1, 0), col, w * 1.4)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.05, -s * 0.16), c + Vector2(s * 0.45, 0), c + Vector2(s * 0.05, s * 0.16)]), col)
			ci.draw_line(c + Vector2(-s * 0.4, -s * 0.12), c + Vector2(-s * 0.4, s * 0.12), col, w)
		"mine":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.14, -s * 0.2), c + Vector2(s * 0.14, s * 0.22), c + Vector2(-s * 0.14, s * 0.22), c + Vector2(-s * 0.14, -s * 0.2)]), col)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.42), c + Vector2(s * 0.2, s * 0.42), col, w)
			ci.draw_line(c + Vector2(0, s * 0.22), c + Vector2(0, s * 0.42), col, w)
		"grenade":
			# осколкова граната з чекою
			ci.draw_circle(c + Vector2(0, s * 0.08), s * 0.3, col)
			for i in 3:
				ci.draw_line(c + Vector2(-s * 0.28, s * (-0.06 + i * 0.13)), c + Vector2(s * 0.28, s * (-0.06 + i * 0.13)), Color(0, 0, 0, 0.45), w * 0.6)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.34), Vector2(s * 0.2, s * 0.14)), col)
			ci.draw_line(c + Vector2(s * 0.1, -s * 0.3), c + Vector2(s * 0.34, -s * 0.12), col, w)
			ci.draw_arc(c + Vector2(-s * 0.2, -s * 0.36), s * 0.1, 0.0, TAU, 14, col, w * 0.8)
		"prone":
			# людина лежить
			ci.draw_circle(c + Vector2(-s * 0.36, s * 0.08), s * 0.1, col)
			ci.draw_line(c + Vector2(-s * 0.24, s * 0.14), c + Vector2(s * 0.42, s * 0.2), col, w * 1.4)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.0), c + Vector2(-s * 0.02, -s * 0.08), col, w)
			ci.draw_line(c + Vector2(-s * 0.48, s * 0.3), c + Vector2(s * 0.48, s * 0.3), Color(col.r, col.g, col.b, 0.5), w * 0.7)
		"lean_l", "lean_r":
			var sg := -1.0 if name == "lean_l" else 1.0
			ci.draw_circle(c + Vector2(sg * s * 0.24, -s * 0.3), s * 0.1, col)
			ci.draw_line(c + Vector2(sg * s * 0.18, -s * 0.18), c + Vector2(0, s * 0.12), col, w * 1.3)
			ci.draw_line(c + Vector2(0, s * 0.12), c + Vector2(-s * 0.12, s * 0.45), col, w * 1.2)
			ci.draw_line(c + Vector2(0, s * 0.12), c + Vector2(s * 0.12, s * 0.45), col, w * 1.2)
			ci.draw_arc(c + Vector2(0, s * 0.1), s * 0.42, -PI * 0.5 - 0.6 if sg < 0.0 else -PI * 0.5 + 0.1, -PI * 0.5 - 0.1 if sg < 0.0 else -PI * 0.5 + 0.6, 10, col, w * 0.7)
		"sprint":
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.36), s * 0.1, col)
			ci.draw_line(c + Vector2(s * 0.06, -s * 0.24), c + Vector2(-s * 0.08, s * 0.06), col, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.08, s * 0.06), c + Vector2(s * 0.18, s * 0.2), col, w * 1.2)
			ci.draw_line(c + Vector2(s * 0.18, s * 0.2), c + Vector2(s * 0.12, s * 0.44), col, w * 1.2)
			ci.draw_line(c + Vector2(-s * 0.08, s * 0.06), c + Vector2(-s * 0.32, s * 0.36), col, w * 1.2)
			ci.draw_line(c + Vector2(s * 0.02, -s * 0.16), c + Vector2(s * 0.3, -s * 0.02), col, w)
			ci.draw_line(c + Vector2(s * 0.02, -s * 0.16), c + Vector2(-s * 0.26, -s * 0.1), col, w)
			for i in 3:
				ci.draw_line(c + Vector2(-s * 0.48, -s * 0.2 + i * s * 0.14), c + Vector2(-s * 0.36, -s * 0.2 + i * s * 0.14), col, w * 0.6)
		"walk":
			ci.draw_circle(c + Vector2(0, -s * 0.36), s * 0.1, col)
			ci.draw_line(c + Vector2(0, -s * 0.24), c + Vector2(0, s * 0.08), col, w * 1.3)
			ci.draw_line(c + Vector2(0, s * 0.08), c + Vector2(-s * 0.12, s * 0.44), col, w * 1.2)
			ci.draw_line(c + Vector2(0, s * 0.08), c + Vector2(s * 0.1, s * 0.44), col, w * 1.2)
			ci.draw_line(c + Vector2(0, -s * 0.16), c + Vector2(-s * 0.14, s * 0.06), col, w)
			ci.draw_line(c + Vector2(0, -s * 0.16), c + Vector2(s * 0.14, s * 0.04), col, w)
		"skull":
			ci.draw_circle(c + Vector2(0, -s * 0.06), s * 0.3, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.16, s * 0.12), Vector2(s * 0.32, s * 0.2)), col)
			ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.06), s * 0.08, Color(0, 0, 0, 0.85))
			ci.draw_circle(c + Vector2(s * 0.12, -s * 0.06), s * 0.08, Color(0, 0, 0, 0.85))
		"people":
			ci.draw_circle(c + Vector2(-s * 0.16, -s * 0.18), s * 0.12, col)
			ci.draw_circle(c + Vector2(s * 0.16, -s * 0.18), s * 0.12, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.02), Vector2(s * 0.28, s * 0.36)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.04, -s * 0.02), Vector2(s * 0.28, s * 0.36)), col)
		"clock":
			ci.draw_arc(c, s * 0.36, 0.0, TAU, 28, col, w)
			ci.draw_line(c, c + Vector2(0, -s * 0.24), col, w)
			ci.draw_line(c, c + Vector2(s * 0.18, 0), col, w)
		"shoulder":
			ci.draw_circle(c + Vector2(0, -s * 0.12), s * 0.14, col)
			ci.draw_arc(c + Vector2(0, s * 0.3), s * 0.3, PI, TAU, 16, col, w * 1.2)
			_arrow2(ci, c + Vector2(-s * 0.42, -s * 0.12), s * 0.2, col, w, -1.0)
			_arrow2(ci, c + Vector2(s * 0.42, -s * 0.12), s * 0.2, col, w, 1.0)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * i / 10.0
				var rr := s * (0.46 if i % 2 == 0 else 0.19)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"radio":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.12), Vector2(s * 0.44, s * 0.56)), col)
			ci.draw_line(c + Vector2(s * 0.12, -s * 0.12), c + Vector2(s * 0.16, -s * 0.48), col, w)
			ci.draw_arc(c + Vector2(s * 0.16, -s * 0.48), s * 0.12, -2.4, -0.7, 10, col, w * 0.7)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.14, -s * 0.02), Vector2(s * 0.28, s * 0.12)), Color(0, 0, 0, 0.5))
		"medkit":
			ci.draw_rect(Rect2(c - Vector2(s * 0.4, s * 0.3), Vector2(s * 0.8, s * 0.6)), col)
			ci.draw_rect(Rect2(c - Vector2(s * 0.06, s * 0.2), Vector2(s * 0.12, s * 0.4)), Color(0.8, 0.1, 0.1))
			ci.draw_rect(Rect2(c - Vector2(s * 0.2, s * 0.06), Vector2(s * 0.4, s * 0.12)), Color(0.8, 0.1, 0.1))
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + d * s * 0.26, c + d * s * 0.44, col, s * 0.13)
			ci.draw_arc(c, s * 0.27, 0.0, TAU, 28, col, s * 0.12)
			ci.draw_arc(c, s * 0.1, 0.0, TAU, 16, col, w)
		"close":
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(s * 0.3, s * 0.3), col, w * 1.3)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.3), c + Vector2(-s * 0.3, s * 0.3), col, w * 1.3)
		_:
			ci.draw_circle(c, s * 0.2, col)


static func _arrow(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float, dir: float) -> void:
	ci.draw_line(c + Vector2(0, -dir * s * 0.4), c + Vector2(0, dir * s * 0.4), col, w * 1.4)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, dir * s * 0.45), c + Vector2(-s * 0.28, dir * s * 0.1), c + Vector2(s * 0.28, dir * s * 0.1)]), col)


static func _arrow2(ci: CanvasItem, c: Vector2, s: float, col: Color, w: float, dir: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(dir * s * 0.5, 0), c + Vector2(-dir * s * 0.3, -s * 0.4), c + Vector2(-dir * s * 0.3, s * 0.4)]), col)
