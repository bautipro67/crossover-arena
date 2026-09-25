class_name Escombro
extends Projectile
## Un pedazo de escombro que Mob tira con la telequinesis: una piedra con el borde celeste
## de su poder. Gira mientras vuela.


var _roca: MeshInstance3D = null


func _init() -> void:
	tint = Color(0.62, 0.80, 1.0)
	hit_radius = 0.34
	fall_gravity = 0.0
	impact_sound = &"hit_punch"
	knockback = 3.0
	knockback_lift = 0.6


func _build_visual() -> void:
	_roca = MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(0.34, 0.26, 0.30)
	_roca.mesh = caja
	_roca.material_override = Art.toon(Color(0.46, 0.42, 0.40), 0.01)
	_roca.rotation_degrees = Vector3(20.0, 35.0, 10.0)
	add_child(_roca)
	add_trail(Color(0.62, 0.80, 1.0, 0.45), 10)
	add_light(tint, 0.9, 2.2)


func _process(delta: float) -> void:
	if is_instance_valid(_roca):
		_roca.rotate_x(delta * 9.0)
		_roca.rotate_y(delta * 6.0)
