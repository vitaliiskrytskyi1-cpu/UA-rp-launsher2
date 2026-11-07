extends Node3D
## Інші гравці на клієнті: модель солдата з плавним рухом.

var target_pos := Vector3.ZERO
var target_yaw := 0.0
var _first := true


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, sc: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	add_child(mi)


func setup(nick: String, team_color: Color) -> void:
	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = Color(0.33, 0.37, 0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.22, 0.16)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.84, 0.67, 0.54)
	var gun := StandardMaterial3D.new()
	gun.albedo_color = Color(0.1, 0.1, 0.1)
	var band := StandardMaterial3D.new()
	band.albedo_color = team_color
	band.emission_enabled = true
	band.emission = team_color * 0.5

	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 1.0
	_mesh(torso, Vector3(0.0, 1.1, 0.0), uniform)

	var leg := BoxMesh.new()
	leg.size = Vector3(0.18, 0.8, 0.2)
	_mesh(leg, Vector3(-0.12, 0.4, 0.0), dark)
	_mesh(leg, Vector3(0.12, 0.4, 0.0), dark)

	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.32
	_mesh(head, Vector3(0.0, 1.66, 0.0), skin)

	var helmet := SphereMesh.new()
	helmet.radius = 0.2
	helmet.height = 0.4
	_mesh(helmet, Vector3(0.0, 1.74, 0.0), dark, Vector3(1.0, 0.65, 1.0))

	var vest := BoxMesh.new()
	vest.size = Vector3(0.62, 0.45, 0.42)
	_mesh(vest, Vector3(0.0, 1.2, 0.0), dark)

	var armband := BoxMesh.new()
	armband.size = Vector3(0.7, 0.1, 0.44)
	_mesh(armband, Vector3(0.0, 1.42, 0.0), band)

	var rifle := BoxMesh.new()
	rifle.size = Vector3(0.07, 0.09, 0.8)
	_mesh(rifle, Vector3(0.22, 1.2, -0.32), gun)

	var label := Label3D.new()
	label.text = nick
	label.modulate = team_color
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.006
	label.position = Vector3(0.0, 2.15, 0.0)
	add_child(label)


func _process(delta: float) -> void:
	if _first:
		position = target_pos
		rotation.y = target_yaw
		_first = false
		return
	var k := clampf(delta * 12.0, 0.0, 1.0)
	position = position.lerp(target_pos, k)
	rotation.y = lerp_angle(rotation.y, target_yaw, k)


func snap_to(pos: Vector3, yaw: float) -> void:
	target_pos = pos
	target_yaw = yaw
	position = pos
	rotation.y = yaw
	_first = false
