extends Control
## Сенсорне керування з мультитачем.
## Ліва частина екрана — джойстик руху, права — огляд.
## Режим солдата: ВОГОНЬ, ПРИЦІЛ, СТРИБОК, R (перезарядка), ЗБРОЯ, ДРОН, МАГАЗИН.
## Режим дрона: ВИБУХ, ВГОРУ, ВНИЗ, ШВИДКІСТЬ.

const JOY_R := 110.0

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
var speed_pressed := false
var shop_pressed := false

var drone_mode := false
var drone_label := "ДРОН"
var slot_label := "ЗБРОЯ"
var speed_label := "ШВ 1"
var fire_label := "ВОГОНЬ"
var aiming := false

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _held := {}      # індекс дотику -> назва кнопки
var _held_last := {} # індекс дотику -> остання позиція (для огляду під час стрільби)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _buttons() -> Dictionary:
	var s := get_viewport_rect().size
	var u := minf(s.x, s.y) / 720.0
	var red := Color(0.9, 0.25, 0.2)
	var white := Color(0.9, 0.9, 0.9)
	var yellow := Color(1.0, 0.8, 0.15)
	if drone_mode:
		return {
			"boom": [Vector2(s.x - 150.0 * u, s.y - 180.0 * u), 88.0 * u, "ВИБУХ", red],
			"up": [Vector2(s.x - 330.0 * u, s.y - 290.0 * u), 62.0 * u, "ВГОРУ", white],
			"down": [Vector2(s.x - 330.0 * u, s.y - 110.0 * u), 62.0 * u, "ВНИЗ", white],
			"speed": [Vector2(s.x - 150.0 * u, s.y - 375.0 * u), 54.0 * u, speed_label, yellow],
		}
	var aim_col := yellow if aiming else white
	return {
		"fire": [Vector2(s.x - 150.0 * u, s.y - 180.0 * u), 88.0 * u, fire_label, red],
		"aim": [Vector2(s.x - 150.0 * u, s.y - 375.0 * u), 52.0 * u, "ПРИЦІЛ", aim_col],
		"jump": [Vector2(s.x - 330.0 * u, s.y - 105.0 * u), 54.0 * u, "СТРИБОК", white],
		"drone": [Vector2(s.x - 330.0 * u, s.y - 285.0 * u), 58.0 * u, drone_label, yellow],
		"reload": [Vector2(s.x - 490.0 * u, s.y - 100.0 * u), 46.0 * u, "R", white],
		"slot": [Vector2(s.x - 490.0 * u, s.y - 245.0 * u), 50.0 * u, slot_label, white],
		"shop": [Vector2(95.0 * u, 165.0 * u), 50.0 * u, "МАГАЗИН", yellow],
	}


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		var c: Vector2 = b[k][0]
		var r: float = b[k][1]
		if p.distance_to(c) <= r * 1.1:
			return k
	return ""


func reset_input() -> void:
	_joy_index = -1
	_look_index = -1
	_held.clear()
	_held_last.clear()
	move = Vector2.ZERO
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


func _input(event: InputEvent) -> void:
	if not visible:
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
				"slot": slot_pressed = true
				"speed": speed_pressed = true
				"shop": shop_pressed = true
				_:
					if p.x < get_viewport_rect().size.x * 0.42 and _joy_index == -1:
						_joy_index = event.index
						_joy_center = p
						_joy_pos = p
					elif _look_index == -1:
						_look_index = event.index
						_look_last = p
		else:
			if event.index == _joy_index:
				_joy_index = -1
				move = Vector2.ZERO
			if event.index == _look_index:
				_look_index = -1
			_held.erase(event.index)
			_held_last.erase(event.index)
		_update_held()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var p: Vector2 = event.position
		if event.index == _joy_index:
			_joy_pos = p
			var v := _joy_pos - _joy_center
			if v.length() > JOY_R:
				v = v.normalized() * JOY_R
			move = v / JOY_R
		elif event.index == _look_index:
			look_delta += p - _look_last
			_look_last = p
		elif _held.has(event.index) and _held[event.index] == "fire":
			# можна водити прицілом, тримаючи вогонь
			look_delta += p - _held_last[event.index]
			_held_last[event.index] = p


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var s := get_viewport_rect().size
	if _joy_index != -1:
		draw_circle(_joy_center, JOY_R, Color(1, 1, 1, 0.1))
		draw_circle(_joy_pos, 46.0, Color(1, 1, 1, 0.35))
	else:
		var c := Vector2(180.0, s.y - 180.0)
		draw_arc(c, JOY_R, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 3.0)
		draw_circle(c, 40.0, Color(1, 1, 1, 0.12))
	var held := _held.values()
	var b := _buttons()
	for k in b:
		var c: Vector2 = b[k][0]
		var r: float = b[k][1]
		var lbl: String = b[k][2]
		var col: Color = b[k][3]
		var a := 0.28
		if held.has(k):
			a = 0.6
		draw_circle(c, r, Color(col.r, col.g, col.b, a))
		draw_arc(c, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.85), 2.5)
		var fs := int(clampf(r * 0.3, 12.0, 30.0))
		draw_string(font, c + Vector2(-r, fs * 0.35), lbl, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, 0.95))


func _process(_delta: float) -> void:
	queue_redraw()
