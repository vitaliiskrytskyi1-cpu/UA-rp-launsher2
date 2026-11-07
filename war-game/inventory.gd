extends Control
## Рюкзак / спорядження: комірки зі значками і кількістю.

const Icons = preload("res://icons.gd")
const Gear = preload("res://gear.gd")

var main


func setup(m) -> void:
	main = m
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		hide()
		main.on_bag_closed()
		accept_event()


func _cells() -> Array:
	var cells: Array = []
	var s = main.soldier
	if s == null or not main.profile.has("eq"):
		return cells
	var eq: Dictionary = s.eq
	var wn: String = Gear.WEAPONS[eq.w].name
	cells.append(["rifle", "%d/%d" % [s.in_mag, int(s.wdata.mag)], wn])
	cells.append(["mag", "×%d" % s.mags, "Магазини"])
	cells.append(["drone", "×%d" % s.drones, "FPV-дрони"])
	if eq.x != "none":
		cells.append(["rpg" if eq.x == "rpg" else "mortar", "×%d" % s.heavy_ammo, Gear.HEAVY[eq.x].name])
	cells.append(["armor", "" if eq.a == "none" else Gear.ARMOR[eq.a].name.replace("Бронежилет, ", ""), "Броня"])
	cells.append(["helmet", "є" if eq.h != "none" else "—", "Шолом"])
	cells.append(["rig", "%d" % Gear.mag_capacity(eq), "Розгрузка"])
	cells.append(["bag", "%d/%d" % [s.drones, Gear.drone_slots(eq)], Gear.PACK[eq.p].name])
	return cells


func _draw() -> void:
	if main == null:
		return
	var font := ThemeDB.fallback_font
	var vs := size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.72))
	var cells := _cells()
	var cols := 4
	var cell := minf(vs.x / 5.2, vs.y / 3.4)
	var gap := cell * 0.12
	var total_w := cols * cell + (cols - 1) * gap
	var origin := Vector2((vs.x - total_w) * 0.5, vs.y * 0.18)
	Icons.draw(self, "bag", Vector2(origin.x + 26.0, origin.y - 40.0), 44.0, Color(1, 0.8, 0.15))
	var s = main.soldier
	if s:
		var w := Gear.weight(s.eq, s.mags, s.drones, s.heavy_ammo)
		draw_string(font, Vector2(origin.x + 60.0, origin.y - 30.0), "%.1f кг   •   %d%%" % [w, int(Gear.speed_mult(w) * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1))
	for i in cells.size():
		var cx := i % cols
		var cy := i / cols
		var p := origin + Vector2(cx * (cell + gap), cy * (cell + gap))
		var rect := Rect2(p, Vector2(cell, cell))
		draw_rect(rect, Color(0.16, 0.18, 0.13, 0.95))
		draw_rect(rect, Color(0.6, 0.62, 0.45, 0.9), false, 2.0)
		var c: Array = cells[i]
		Icons.draw(self, c[0], p + Vector2(cell * 0.5, cell * 0.42), cell * 0.5, Color(0.92, 0.9, 0.8))
		draw_string(font, p + Vector2(0, cell * 0.12), String(c[1]), HORIZONTAL_ALIGNMENT_RIGHT, cell - 8.0, int(cell * 0.13), Color(1, 0.85, 0.3))
		draw_string(font, p + Vector2(0, cell - 10.0), String(c[2]), HORIZONTAL_ALIGNMENT_CENTER, cell, int(cell * 0.1), Color(0.85, 0.85, 0.85))
	Icons.draw(self, "close", Vector2(vs.x - 50.0, 50.0), 40.0, Color(1, 1, 1, 0.9))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()
