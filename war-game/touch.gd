extends Control
## Сенсорне керування в стилі сучасних мобільних шутерів: тільки значки, без підписів.
## Зліва — кнопки положення тіла і нахилів, великий джойстик, біг і ходьба.
## Знизу по центру — слоти (аптечка, основна зброя, важка зброя, граната) і смуги здоров'я та броні.
## Справа — приціл, велика кнопка вогню, стрибок, перезарядка, граната, лягти.

const Icons = preload("res://icons.gd")
const JOY_R := 105.0

var move := Vector2.ZERO
var look_delta := Vector2.ZERO
var fire := false
var up := false
var down := false
var jump_pressed := false
var reload_pressed := false
var drone_pressed := false
var boom_pressed := false
var aim_pressed := false
var slot_pressed := false
var slot_select := -1      # вибір слота з панелі: 0 автомат, 1 важка зброя, 2 сховати
var speed_pressed := false
var shop_pressed := false
var bag_pressed := false
var crouch_pressed := false
var stand_pressed := false
var map_pressed := false
var prone_pressed := false
var grenade_pressed := false
var med_pressed := false
var lean_l_pressed := false
var lean_r_pressed := false
var shoulder_pressed := false
var settings_pressed := false
var veh_pressed := false
var in_vehicle := false
var veh_near := false
var recon := false
var auto_sprint := true
var sprint := false        # біг (джойстик далеко вперед або кнопка бігу)
var sprint_lock := false   # біг зафіксовано
var walk := false          # повільна тиха ходьба
var prone := false
var lean := 0

var drone_mode := false
var aiming := false
var crouching := false
var slot_icon := "rifle"
var badges := {}
var speed_level := 2
## Дані для нижньої панелі (заповнює main кожен кадр).
var info := {}

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _held := {}
var _held_last := {}
var _tex := {}

## Власна розкладка HUD: id -> {x, y (частки екрана), s (розмір), a (прозорість), h (приховано)}
var layout := {}
var edit_mode := false
var edit_sel := ""
var _drag_idx := -999
var _drag_off := Vector2.ZERO
var edit_block: Array = []   # області панелей редактора (там не вибираємо елементи)
signal edit_selected(id: String)

const HUD_PATH := "user://hud.cfg"
## Назви елементів для редактора
const ELEMENT_NAMES := {
	"joy": "Джойстик руху", "slots": "Інвентар (слоти)", "minimap": "Міні-карта",
	"stand": "Встати", "crouch": "Присісти", "prone_l": "Лягти (ліва)", "shoulder": "Плече камери",
	"lean_l": "Нахил ліворуч", "lean_r": "Нахил праворуч", "run": "Біг", "walk": "Ходьба",
	"shop": "Магазин", "bag": "Рюкзак", "drone": "FPV-дрон", "aim": "Приціл", "fire": "Вогонь",
	"jump": "Стрибок", "reload": "Перезарядка", "grenade": "Граната", "prone": "Лягти (права)", "settings": "Налаштування", "veh": "Сісти / вийти з машини",
}


func load_layout(profile: int) -> void:
	var c := ConfigFile.new()
	c.load(HUD_PATH)
	layout = c.get_value("profile_%d" % profile, "layout", {})
	queue_redraw()


func save_layout(profile: int) -> void:
	var c := ConfigFile.new()
	c.load(HUD_PATH)
	c.set_value("profile_%d" % profile, "layout", layout)
	c.save(HUD_PATH)


func el(id: String) -> Dictionary:
	return layout.get(id, {})


func el_alpha(id: String) -> float:
	return float(el(id).get("a", 1.0))


func el_hidden(id: String) -> bool:
	return bool(el(id).get("h", false))


func set_el(id: String, key: String, v) -> void:
	var d: Dictionary = layout.get(id, {})
	d[key] = v
	layout[id] = d
	queue_redraw()


func _apply_el(id: String, pos: Vector2, r: float) -> Array:
	var d := el(id)
	var s := get_viewport_rect().size
	if d.has("x"):
		pos = Vector2(float(d.x) * s.x, float(d.y) * s.y)
	return [pos, r * float(d.get("s", 1.0))]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var p := "res://icons/%s.png" % name
		_tex[name] = load(p) if ResourceLoader.exists(p) else null
	return _tex[name]


func _u() -> float:
	var s := get_viewport_rect().size
	return minf(s.x / 1280.0, s.y / 720.0)


func _joy_home() -> Vector2:
	var s := get_viewport_rect().size
	var u := _u()
	return _apply_el("joy", Vector2(205.0 * u, s.y - 160.0 * u), JOY_R)[0]


func _joy_r() -> float:
	return JOY_R * float(el("joy").get("s", 1.0))


## Кнопки: назва -> [центр, радіус, значок, колір, активна]
func _buttons() -> Dictionary:
	var s := get_viewport_rect().size
	var u := _u()
	var white := Color(0.95, 0.95, 0.95)
	var yellow := Color(1.0, 0.82, 0.2)
	if drone_mode:
		var dd := {
			"boom": [Vector2(s.x - 190.0 * u, s.y - 200.0 * u), 86.0 * u, "mark" if recon else "boom", Color(1.0, 0.82, 0.2) if recon else Color(0.95, 0.3, 0.25), false],
			"up": [Vector2(s.x - 380.0 * u, s.y - 300.0 * u), 58.0 * u, "up", white, false],
			"down": [Vector2(s.x - 380.0 * u, s.y - 120.0 * u), 58.0 * u, "down", white, false],
			"speed": [Vector2(s.x - 110.0 * u, s.y - 420.0 * u), 50.0 * u, "speed", yellow, false],
		}
		for k in dd:
			(dd[k] as Array).append(1.0)
		return dd
	if in_vehicle:
		var dv := {
			"veh": [Vector2(s.x - 150.0 * u, s.y - 200.0 * u), 70.0 * u, "exit", white, false],
			"settings": [Vector2(192.0 * u, 92.0 * u), 30.0 * u, "gear", white, false],
		}
		var ov := {}
		for k in dv:
			var pr0 := _apply_el(k, dv[k][0], dv[k][1])
			var b0: Array = dv[k]
			b0[0] = pr0[0]
			b0[1] = pr0[1]
			b0.append(el_alpha(k))
			ov[k] = b0
		return ov
	var lx1 := 82.0 * u
	var lx2 := 196.0 * u
	var r := 44.0 * u
	var d := {
		# зліва: положення тіла, плече камери, нахили
		"stand": [Vector2(lx1, 200.0 * u), r, "stand", white, not crouching and not prone],
		"crouch": [Vector2(lx2, 200.0 * u), r, "crouch", white, crouching],
		"prone_l": [Vector2(lx1, 295.0 * u), r, "prone", white, prone],
		"shoulder": [Vector2(lx2, 295.0 * u), r, "shoulder", white, false],
		"lean_l": [Vector2(lx1, 390.0 * u), r * 0.92, "lean_l", white, lean < 0],
		"lean_r": [Vector2(lx2, 390.0 * u), r * 0.92, "lean_r", white, lean > 0],
		"run": [Vector2(60.0 * u, s.y - 50.0 * u), 40.0 * u, "sprint", white, sprint_lock],
		"walk": [Vector2(350.0 * u, s.y - 50.0 * u), 40.0 * u, "walk", white, walk],
		# угорі зліва: магазин і рюкзак
		"shop": [Vector2(52.0 * u, 92.0 * u), 30.0 * u, "shop", Color(0.5, 1.0, 0.55), false],
		"bag": [Vector2(122.0 * u, 92.0 * u), 30.0 * u, "bag", white, false],
		"drone": [Vector2(s.x - 300.0 * u, 70.0 * u), 40.0 * u, "drone", yellow, false],
		# справа: бій
		"aim": [Vector2(s.x - 100.0 * u, s.y - 420.0 * u), 52.0 * u, "aim", white, aiming],
		"fire": [Vector2(s.x - 215.0 * u, s.y - 215.0 * u), 88.0 * u, "fire", white, false],
		"jump": [Vector2(s.x - 95.0 * u, s.y - 290.0 * u), 44.0 * u, "jump", white, false],
		"reload": [Vector2(s.x - 370.0 * u, s.y - 370.0 * u), 40.0 * u, "reload", white, false],
		"grenade": [Vector2(s.x - 370.0 * u, s.y - 95.0 * u), 48.0 * u, "grenade", white, false],
		"prone": [Vector2(s.x - 85.0 * u, s.y - 85.0 * u), 52.0 * u, "prone", white, prone],
		"settings": [Vector2(192.0 * u, 92.0 * u), 30.0 * u, "gear", white, false],
	}
	if veh_near or edit_mode:
		d["veh"] = [Vector2(s.x - 330.0 * u, s.y - 230.0 * u), 46.0 * u, "apc", yellow, false]
	# власна розкладка гравця
	var out := {}
	for k in d:
		if el_hidden(k) and not edit_mode:
			continue
		var pr := _apply_el(k, d[k][0], d[k][1])
		var b: Array = d[k]
		b[0] = pr[0]
		b[1] = pr[1]
		b.append(el_alpha(k))
		out[k] = b
	return out


## Прямокутники слотів нижньої панелі.
func _slots() -> Dictionary:
	var s := get_viewport_rect().size
	var u := _u()
	var sc := float(el("slots").get("s", 1.0))
	u *= sc
	var h := 78.0 * u
	var c0 := Vector2(s.x * 0.5 + 9.0 * u, s.y - 62.0 * u - h * 0.5)
	if el("slots").has("x"):
		c0 = Vector2(float(el("slots").x) * s.x, float(el("slots").y) * s.y)
	var y := c0.y - h * 0.5
	var x0 := c0.x - 209.0 * u
	return {
		"s_med": Rect2(x0, y + 10.0 * u, 70.0 * u, h - 10.0 * u),
		"s_primary": Rect2(x0 + 76.0 * u, y, 180.0 * u, h),
		"s_heavy": Rect2(x0 + 262.0 * u, y + 10.0 * u, 80.0 * u, h - 10.0 * u),
		"s_gren": Rect2(x0 + 348.0 * u, y + 10.0 * u, 70.0 * u, h - 10.0 * u),
	}


## Прямокутник міні-карти (з урахуванням розкладки).
func minimap_rect() -> Rect2:
	var s := get_viewport_rect().size
	var sc := float(el("minimap").get("s", 1.0))
	var sz := 222.0 * sc
	var c := Vector2(s.x - 119.0, 119.0)
	if el("minimap").has("x"):
		c = Vector2(float(el("minimap").x) * s.x, float(el("minimap").y) * s.y)
	return Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz))


func _slots_rect() -> Rect2:
	var sl := _slots()
	var r: Rect2 = sl["s_med"]
	for k in sl:
		r = r.merge(sl[k])
	return r.grow_individual(0, 0, 0, 50.0 * _u() * float(el("slots").get("s", 1.0)))


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		var c: Vector2 = b[k][0]
		var rr: float = b[k][1]
		if p.distance_to(c) <= rr * 1.12:
			return k
	if not drone_mode and not in_vehicle:
		if not el_hidden("slots"):
			var sl := _slots()
			for k in sl:
				if (sl[k] as Rect2).grow(6.0).has_point(p):
					return k
		if not el_hidden("minimap") and minimap_rect().has_point(p):
			return "map"
	return ""


## Елемент під пальцем у режимі редагування.
func _edit_pick(p: Vector2) -> String:
	if minimap_rect().has_point(p):
		return "minimap"
	if _slots_rect().has_point(p):
		return "slots"
	var b := _buttons()
	var best := ""
	var bd := 1e9
	for k in b:
		var d: float = p.distance_to(b[k][0])
		if d <= float(b[k][1]) * 1.15 and d < bd:
			bd = d
			best = k
	if best != "":
		return best
	if p.distance_to(_joy_home()) <= _joy_r():
		return "joy"
	return ""


func _edit_center(id: String) -> Vector2:
	match id:
		"joy": return _joy_home()
		"slots":
			var sl := _slots()
			var r: Rect2 = sl["s_med"]
			for k in sl:
				r = r.merge(sl[k])
			return r.get_center()
		"minimap": return minimap_rect().get_center()
	var b := _buttons()
	return b[id][0] if b.has(id) else Vector2.ZERO


func reset_input() -> void:
	_joy_index = -1
	_look_index = -1
	_held.clear()
	_held_last.clear()
	move = Vector2.ZERO
	sprint = false
	sprint_lock = false
	fire = false
	up = false
	down = false
	look_delta = Vector2.ZERO
	queue_redraw()


func _update_held() -> void:
	var vals := _held.values()
	fire = vals.has("fire")
	up = vals.has("up")
	down = vals.has("down")


func _edit_input(event: InputEvent) -> void:
	var s := get_viewport_rect().size
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	var idx := 0
	var moved := false
	if event is InputEventScreenTouch:
		pos = event.position
		idx = event.index
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pos = event.position
		idx = event.index
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		idx = -1
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and _drag_idx == -1:
		pos = event.position
		idx = -1
		moved = true
	else:
		return
	if pressed and _drag_idx == -999:
		for r in edit_block:
			if (r as Rect2).has_point(pos):
				return
		var id := _edit_pick(pos)
		if id != "":
			edit_sel = id
			_drag_idx = idx
			_drag_off = _edit_center(id) - pos
			edit_selected.emit(id)
			get_viewport().set_input_as_handled()
	elif moved and idx == _drag_idx and edit_sel != "":
		var c := pos + _drag_off
		c.x = clampf(c.x, 20.0, s.x - 20.0)
		c.y = clampf(c.y, 20.0, s.y - 20.0)
		set_el(edit_sel, "x", c.x / s.x)
		set_el(edit_sel, "y", c.y / s.y)
		get_viewport().set_input_as_handled()
	elif released and idx == _drag_idx:
		_drag_idx = -999


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if edit_mode:
		_edit_input(event)
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			var b := _hit_button(p)
			match b:
				"fire", "up", "down":
					_held[event.index] = b
					_held_last[event.index] = p
				"jump": jump_pressed = true
				"reload": reload_pressed = true
				"drone": drone_pressed = true
				"boom": boom_pressed = true
				"aim": aim_pressed = true
				"speed": speed_pressed = true
				"shop": shop_pressed = true
				"bag": bag_pressed = true
				"settings": settings_pressed = true
				"veh": veh_pressed = true
				"crouch": crouch_pressed = true
				"stand": stand_pressed = true
				"map": map_pressed = true
				"prone", "prone_l": prone_pressed = true
				"grenade", "s_gren": grenade_pressed = true
				"s_med": med_pressed = true
				"s_primary": slot_select = 0
				"s_heavy": slot_select = 1
				"lean_l": lean_l_pressed = true
				"lean_r": lean_r_pressed = true
				"shoulder": shoulder_pressed = true
				"run":
					sprint_lock = not sprint_lock
					sprint = sprint_lock
					walk = false
					if sprint_lock:
						move = Vector2(0.0, -1.0)
					elif _joy_index == -1:
						move = Vector2.ZERO
				"walk":
					walk = not walk
					if walk:
						sprint_lock = false
						sprint = false
				_:
					var home := _joy_home()
					var near_joy := p.distance_to(home) < _joy_r() * 1.9
					if (near_joy or (p.x < get_viewport_rect().size.x * 0.42 and p.y > get_viewport_rect().size.y * 0.35)) and _joy_index == -1:
						_joy_index = event.index
						_joy_center = p
						_joy_pos = p
						if sprint_lock:
							sprint_lock = false
							sprint = false
							move = Vector2.ZERO
					elif _look_index == -1:
						_look_index = event.index
						_look_last = p
		else:
			if event.index == _joy_index:
				_joy_index = -1
				if sprint_lock:
					move = Vector2(0.0, -1.0)
					sprint = true
				else:
					move = Vector2.ZERO
					sprint = false
			if event.index == _look_index:
				_look_index = -1
			_held.erase(event.index)
			_held_last.erase(event.index)
		_update_held()
	elif event is InputEventScreenDrag:
		var p: Vector2 = event.position
		var jr := _joy_r()
		if event.index == _joy_index:
			_joy_pos = p
			var v := _joy_pos - _joy_center
			sprint = (v.y < -jr * 1.05 and absf(v.x) < jr * 0.8) and not walk and auto_sprint
			sprint_lock = v.y < -jr * 1.75 and absf(v.x) < jr * 0.8 and auto_sprint
			if v.length() > jr:
				v = v.normalized() * jr
			move = v / jr
			if walk:
				move *= 0.45
		elif event.index == _look_index:
			look_delta += p - _look_last
			_look_last = p
		elif _held.has(event.index) and _held[event.index] == "fire":
			look_delta += p - _held_last[event.index]
			_held_last[event.index] = p


# ---------------------------------------------------------------- малювання

var _alpha := 1.0


func _c(c: Color) -> Color:
	return Color(c.r, c.g, c.b, c.a * _alpha)


func _round_btn(c: Vector2, r: float, icon: String, col: Color, active: bool, held: bool) -> void:
	draw_circle(c, r, _c(Color(0.0, 0.0, 0.0, 0.42 if not held else 0.6)))
	if active:
		draw_circle(c, r, _c(Color(1.0, 0.82, 0.2, 0.28)))
	draw_arc(c, r, 0.0, TAU, 48, _c(Color(1, 1, 1, 0.35) if not active else Color(1.0, 0.82, 0.2, 0.95)), 2.0)
	Icons.draw(self, icon, c, r * 0.95, _c(Color(col.r, col.g, col.b, 0.95)))


func _draw_tex_fit(t: Texture2D, r: Rect2, mod: Color = Color(1, 1, 1, 1)) -> void:
	if t == null:
		return
	var ts := t.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var sz := ts * k
	draw_texture_rect(t, Rect2(r.position + (r.size - sz) * 0.5, sz), false, _c(mod))


func _edit_mark(c: Vector2, r: float, id: String, rect: Rect2 = Rect2()) -> void:
	var sel := id == edit_sel
	var col := Color(1.0, 0.82, 0.2, 0.95) if sel else Color(1, 1, 1, 0.35)
	if rect.size != Vector2.ZERO:
		draw_rect(rect, col, false, 3.0 if sel else 1.5)
	else:
		draw_arc(c, r + 6.0, 0.0, TAU, 48, col, 3.0 if sel else 1.5)
	if el_hidden(id):
		draw_line(c + Vector2(-r, -r) * 0.6, c + Vector2(r, r) * 0.6, Color(1, 0.3, 0.2, 0.9), 3.0)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var s := get_viewport_rect().size
	var u := _u()
	if edit_mode:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.25))
	# джойстик
	var home := _joy_home()
	var jr := _joy_r()
	_alpha = el_alpha("joy") * (0.35 if edit_mode and el_hidden("joy") else 1.0)
	if not el_hidden("joy") or edit_mode:
		if _joy_index != -1:
			draw_circle(_joy_center, jr, _c(Color(0, 0, 0, 0.25)))
			draw_arc(_joy_center, jr, 0.0, TAU, 64, _c(Color(1, 1, 1, 0.4)), 3.0)
			draw_circle(_joy_pos, 46.0, _c(Color(0.85, 0.85, 0.85, 0.55)))
			if auto_sprint:
				var lc := _joy_center + Vector2(0.0, -jr * 1.9)
				draw_circle(lc, 30.0, _c(Color(1, 0.82, 0.2, 0.6 if sprint_lock else 0.2)))
				Icons.draw(self, "sprint", lc, 40.0, _c(Color(1, 1, 1, 0.9)))
		elif not drone_mode:
			draw_circle(home, jr, _c(Color(0, 0, 0, 0.22)))
			draw_arc(home, jr, 0.0, TAU, 64, _c(Color(1, 1, 1, 0.35)), 3.0)
			draw_arc(home, jr * 0.62, 0.0, TAU, 48, _c(Color(1, 1, 1, 0.12)), 2.0)
			for d in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
				var tip: Vector2 = home + d * jr * 0.86
				var side := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([tip + d * 8.0, tip + side * 7.0, tip - side * 7.0]), _c(Color(1, 1, 1, 0.45)))
			draw_circle(home, 44.0 * jr / JOY_R, _c(Color(0.8, 0.8, 0.8, 0.4)))
		else:
			draw_arc(home, jr, 0.0, TAU, 64, _c(Color(1, 1, 1, 0.25)), 3.0)
	if edit_mode:
		_alpha = 1.0
		_edit_mark(home, jr, "joy")

	var held := _held.values()
	var b := _buttons()
	for k in b:
		var bb: Array = b[k]
		_alpha = float(bb[5]) * (0.35 if edit_mode and el_hidden(k) else 1.0)
		_round_btn(bb[0], bb[1], bb[2], bb[3], bb[4], held.has(k))
		if badges.has(k):
			var bc: Vector2 = bb[0] + Vector2(bb[1] * 0.72, -bb[1] * 0.72)
			var br := maxf(12.0, bb[1] * 0.28)
			draw_circle(bc, br, _c(Color(0.08, 0.08, 0.08, 0.92)))
			var fs := int(br * 1.1)
			draw_string(font, bc + Vector2(-br, fs * 0.36), str(badges[k]), HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, fs, _c(Color(1, 1, 1)))
		if edit_mode:
			_alpha = 1.0
			_edit_mark(bb[0], bb[1], k)
	if drone_mode:
		_alpha = 1.0
		var c: Vector2 = b["speed"][0]
		var rr: float = b["speed"][1]
		for i in 3:
			var on := i < speed_level
			draw_rect(Rect2(c + Vector2(-rr * 0.45 + i * rr * 0.32, rr * 1.15), Vector2(rr * 0.24, rr * 0.16)), Color(1, 0.8, 0.15, 0.95 if on else 0.25))
		return
	if edit_mode:
		_edit_mark(Vector2.ZERO, 0.0, "minimap", minimap_rect())
		draw_string(font, minimap_rect().position + Vector2(8, 28), "Міні-карта", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))
	if (el_hidden("slots") or in_vehicle) and not edit_mode:
		return

	# ---- нижня панель: слоти, здоров'я, броня
	_alpha = el_alpha("slots") * (0.35 if edit_mode and el_hidden("slots") else 1.0)
	var sc := float(el("slots").get("s", 1.0))
	u *= sc
	var sl := _slots()
	var slot: int = info.get("slot", 0)
	var fs2 := int(22.0 * u)
	for k in sl:
		var r: Rect2 = sl[k]
		var sel: bool = (k == "s_primary" and slot == 0) or (k == "s_heavy" and slot == 1)
		draw_rect(r, _c(Color(0, 0, 0, 0.45)))
		draw_rect(r, _c(Color(1.0, 0.82, 0.2, 0.95) if sel else Color(1, 1, 1, 0.25)), false, 2.5 if sel else 1.5)
		if k == "s_primary" or k == "s_heavy":
			draw_line(r.position + Vector2(r.size.x * 0.5 - 8.0, -10.0), r.position + Vector2(r.size.x * 0.5, -18.0), _c(Color(1, 1, 1, 0.5)), 2.0)
			draw_line(r.position + Vector2(r.size.x * 0.5 + 8.0, -10.0), r.position + Vector2(r.size.x * 0.5, -18.0), _c(Color(1, 1, 1, 0.5)), 2.0)
	var rp: Rect2 = sl["s_primary"]
	_draw_tex_fit(tex(String(info.get("w_icon", "ak47"))), Rect2(rp.position + Vector2(rp.size.x * 0.3, 6.0), Vector2(rp.size.x * 0.66, rp.size.y * 0.62)))
	draw_string(font, rp.position + Vector2(10.0, rp.size.y - 12.0), "%d" % int(info.get("in_mag", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(30.0 * u), _c(Color(1, 1, 1)))
	draw_string(font, rp.position + Vector2(10.0 + 40.0 * u, rp.size.y - 12.0), "/ %d" % int(info.get("reserve", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, _c(Color(0.85, 0.85, 0.85)))
	var rh: Rect2 = sl["s_heavy"]
	var hv: String = info.get("heavy", "none")
	if hv != "none":
		_draw_tex_fit(tex(hv) if hv == "rpg" else null, Rect2(rh.position + Vector2(8.0, 4.0), Vector2(rh.size.x - 16.0, rh.size.y * 0.6)))
		if hv != "rpg":
			Icons.draw(self, "mortar", rh.position + Vector2(rh.size.x * 0.5, rh.size.y * 0.38), rh.size.y * 0.55, _c(Color(1, 1, 1, 0.95)))
		draw_string(font, rh.position + Vector2(0.0, rh.size.y - 8.0), "%d" % int(info.get("heavy_ammo", 0)), HORIZONTAL_ALIGNMENT_CENTER, rh.size.x, fs2, _c(Color(1, 1, 1)))
	else:
		Icons.draw(self, "hands", rh.get_center(), rh.size.y * 0.6, _c(Color(1, 1, 1, 0.5 if slot != 2 else 0.95)))
	var rm: Rect2 = sl["s_med"]
	_draw_tex_fit(tex("medkit"), rm.grow(-8.0))
	draw_string(font, rm.position + Vector2(0.0, rm.size.y - 6.0), "%d" % int(info.get("med", 0)), HORIZONTAL_ALIGNMENT_RIGHT, rm.size.x - 6.0, fs2, _c(Color(1, 1, 1)))
	var heal: float = info.get("heal", 0.0)
	if heal > 0.0:
		draw_rect(Rect2(rm.position + Vector2(0.0, rm.size.y - 6.0), Vector2(rm.size.x * heal, 6.0)), _c(Color(0.4, 1.0, 0.45)))
	var rg: Rect2 = sl["s_gren"]
	_draw_tex_fit(tex("grenade"), rg.grow(-12.0), Color(1, 1, 1, 0.95))
	draw_string(font, rg.position + Vector2(0.0, rg.size.y - 6.0), "%d" % int(info.get("gren", 0)), HORIZONTAL_ALIGNMENT_RIGHT, rg.size.x - 6.0, fs2, _c(Color(1, 1, 1)))
	# смуги здоров'я і броні
	var bx := rp.position.x
	var bw := rh.end.x - rp.position.x
	var by := rp.end.y + 12.0 * u
	var hp: float = info.get("hp", 100.0)
	var ar: float = info.get("armor", 0.0)
	draw_string(font, Vector2(bx - 26.0 * u, by + 15.0 * u), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(24.0 * u), _c(Color(1, 1, 1)))
	draw_rect(Rect2(bx, by, bw, 14.0 * u), _c(Color(0, 0, 0, 0.5)))
	draw_rect(Rect2(bx, by, bw * clampf(hp / 100.0, 0.0, 1.0), 14.0 * u), _c(Color(0.95, 0.95, 0.95) if hp > 30.0 else Color(0.95, 0.25, 0.2)))
	draw_string(font, Vector2(bx + bw + 8.0, by + 13.0 * u), "%d" % int(hp), HORIZONTAL_ALIGNMENT_LEFT, -1, int(20.0 * u), _c(Color(1, 1, 1)))
	by += 22.0 * u
	Icons.draw(self, "armor", Vector2(bx - 15.0 * u, by + 7.0 * u), 18.0 * u, _c(Color(1, 1, 1, 0.9)))
	draw_rect(Rect2(bx, by, bw, 14.0 * u), _c(Color(0, 0, 0, 0.5)))
	draw_rect(Rect2(bx, by, bw * clampf(ar / 100.0, 0.0, 1.0), 14.0 * u), _c(Color(0.25, 0.5, 1.0)))
	draw_string(font, Vector2(bx + bw + 8.0, by + 13.0 * u), "%d" % int(ar), HORIZONTAL_ALIGNMENT_LEFT, -1, int(20.0 * u), _c(Color(1, 1, 1)))
	_alpha = 1.0
	if edit_mode:
		_edit_mark(Vector2.ZERO, 0.0, "slots", _slots_rect())


func _process(_delta: float) -> void:
	queue_redraw()
