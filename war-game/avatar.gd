extends Node3D
## Інші гравці на клієнті: модель солдата зі спорядженням, плавний рух і анімація кроку.

const Character = preload("res://character.gd")

var target_pos := Vector3.ZERO
var target_yaw := 0.0
var model: Node3D
var _first := true
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _anim_acc := 0.0


func setup(nick: String, team_color: Color, model_id: int = 0) -> void:
	model = Character.new()
	add_child(model)
	model.setup(team_color, model_id)
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
		var wv := Vector3(position.x - _last_pos.x, 0.0, position.z - _last_pos.z) / delta
		var v := Vector2(wv.x, wv.z).length()
		_speed = lerpf(_speed, v, clampf(delta * 8.0, 0.0, 1.0))
		if model and v > 0.2:
			var lv := Basis(Vector3.UP, rotation.y).inverse() * wv
			model.move_local = Vector2(lv.x, -lv.z)
	_last_pos = position
	if model:
		# оптимізація: далекі бійці анімуються рідше, дуже далекі — ховаються
		_anim_acc += delta
		var cam := get_viewport().get_camera_3d()
		var d := 0.0
		if cam:
			d = cam.global_position.distance_to(global_position)
		model.visible = d < 260.0
		var every := 0.0 if d < 25.0 else (0.033 if d < 60.0 else (0.066 if d < 140.0 else 0.15))
		if model.visible and _anim_acc >= every:
			model.animate(_speed, _anim_acc)
			_anim_acc = 0.0


func snap_to(pos: Vector3, yaw: float) -> void:
	target_pos = pos
	target_yaw = yaw
	position = pos
	rotation.y = yaw
	_last_pos = pos
	_first = false
