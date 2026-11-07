extends Node3D
## Інші гравці на клієнті: модель солдата зі спорядженням, плавний рух і анімація кроку.

const Character = preload("res://character.gd")

var target_pos := Vector3.ZERO
var target_yaw := 0.0
var model: Node3D
var _first := true
var _last_pos := Vector3.ZERO
var _speed := 0.0


func setup(nick: String, team_color: Color) -> void:
	model = Character.new()
	add_child(model)
	model.setup(team_color)
	var label := Label3D.new()
	label.text = nick
	label.modulate = team_color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.006
	label.position = Vector3(0.0, 2.2, 0.0)
	add_child(label)


func set_gear(eq: Dictionary, slot: int) -> void:
	if model:
		model.set_gear(eq, slot)


func _process(delta: float) -> void:
	if _first:
		position = target_pos
		rotation.y = target_yaw
		_last_pos = position
		_first = false
		return
	var k := clampf(delta * 12.0, 0.0, 1.0)
	position = position.lerp(target_pos, k)
	rotation.y = lerp_angle(rotation.y, target_yaw, k)
	if delta > 0.0:
		var v := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / delta
		_speed = lerpf(_speed, v, clampf(delta * 8.0, 0.0, 1.0))
	_last_pos = position
	if model:
		model.animate(_speed, delta)


func snap_to(pos: Vector3, yaw: float) -> void:
	target_pos = pos
	target_yaw = yaw
	position = pos
	rotation.y = yaw
	_last_pos = pos
	_first = false
