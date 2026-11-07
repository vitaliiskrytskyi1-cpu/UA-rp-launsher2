extends Control
## Сенсорне керування зі значками і мультитачем.
## Ліва частина екрана — джойстик руху, права — огляд.

const Icons = preload("res://icons.gd")
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
var bag_pressed := false
var crouch_pressed := false
var map_pressed := false

var drone_mode := false
var aiming := false
var crouching := false
var slot_icon := "rifle"
var badges := {}      # кнопка -> число на значку
var speed_level := 2

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _look_index := -1
var _look_last := Vector2.ZERO
var _held := {}
var _held_last := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _buttons() -> Dictionary:
	var s := get_viewport_rect().size
	var u := minf(s.x, s.y) / 720.0
	var red := Color(0.92, 0.28, 0.22)
	var white := Color(0.92, 0.92, 0.92)
	var yellow := Color(1.0, 0.8, 0.15)
	var green := Color(0.45, 0.9, 0.5)
	if drone_mode:
		return {
			"boom": [Vector2(s.x - 150.0 * u, s.y - 180.0 * u), 88.0 * u, "boom", red],
			"up": [Vector2(s.x - 320.0 * u, s.y - 285.0 * u), 62.0 * u, "up", white],
			"down": [Vector2(s.x - 320.0 * u, s.y - 105.0 * u), 62.0 * u, "down", white],
			"speed": [Vector2(s.x - 150.0 * u, s.y - 375.0 * u), 54.0 * u, "speed", yellow],
		}
	return {
		"fire": [Vector2(s.x - 150.0 * u, s.y - 180.0 * u), 88.0 * u, "fire", red],
		"aim": [Vector2(s.x - 150.0 * u, s.y - 375.0 * u), 52.0 * u, "aim", yellow if aiming else white],
		"jump": [Vector2(s.x - 315.0 * u, s.y - 92.0 * u), 50.0 * u, "jump", white],
		"crouch": [Vector2(s.x - 450.0 * u, s.y - 92.0 * u), 50.0 * u, "stand" if crouching else "crouch", yellow if crouching else white],
		"reload": [Vector2(s.x - 315.0 * u, s.y - 228.0 * u), 48.0 * u, "reload", white],
		"slot": [Vector2(s.x - 450.0 * u, s.y - 228.0 * u), 48.0 * u, slot_icon, white],
		"drone": [Vector2(s.x - 300.0 * u, s.y - 370.0 * u), 54.0 * u, "drone", yellow],
		"shop": [Vector2(70.0 * u, 160.0 * u), 44.0 * u, "shop", green],
		"bag": [Vector2(70.0 * u, 265.0 * u), 44.0 * u, "bag", white],
	}


func _hit_button(p: Vector2) -> String:
	var b := _buttons()
	for k in b:
		var c: Vector2 = b[k][0]
		var r: float = b[k][1]
		if p.distance_to(c) <= r * 1.1:
			return k
	# міні-карта у верхньому правому куті
	var s := get_viewport_rect().size
	if not drone_mode and Rect2(s.x - 230.0, 8.0, 222.0, 222.0).has_point(p):
		return "map"
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
				"bag": bag_pressed = true
				"crouch": crouch_pressed = true
				"map": map_pressed = true
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
		var icon: String = b[k][2]
		var col: Color = b[k][3]
		var a := 0.22
		if held.has(k):
			a = 0.55
		draw_circle(c, r, Color(0.05, 0.05, 0.05, 0.35))
		draw_circle(c, r, Color(col.r, col.g, col.b, a))
		draw_arc(c, r, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.9), 2.5)
		Icons.draw(self, icon, c, r * 0.95, Color(1, 1, 1, 0.95))
		if badges.has(k):
			var bc := c + Vector2(r * 0.72, -r * 0.72)
			var br := maxf(13.0, r * 0.3)
			draw_circle(bc, br, Color(0.1, 0.1, 0.1, 0.9))
			draw_arc(bc, br, 0.0, TAU, 20, col, 2.0)
			var fs := int(br * 1.1)
			draw_string(font, bc + Vector2(-br, fs * 0.36), str(badges[k]), HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, fs, Color(1, 1, 1))
	if drone_mode and b.has("speed"):
		var c: Vector2 = b["speed"][0]
		var r: float = b["speed"][1]
		for i in 3:
			var on := i < speed_level
			draw_rect(Rect2(c + Vector2(-r * 0.45 + i * r * 0.32, r * 1.15), Vector2(r * 0.24, r * 0.16)), Color(1, 0.8, 0.15, 0.95 if on else 0.25))


func _process(_delta: float) -> void:
	queue_redraw()
