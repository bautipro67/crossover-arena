class_name HuesoVolador
extends Projectile
## Un hueso de Sans en el aire: blanco, con los dos nudos de las puntas, girando.

var _gira: Node3D = null


func _init() -> void:
	tint = Color(0.95, 0.95, 0.92)
	hit_radius = 0.34
	fall_gravity = 0.0
	impact_sound = &"hueso"
	knockback = 2.0


func _build_visual() -> void:
	_gira = Node3D.new()
	add_child(_gira)
	var blanco := Art.toon(Color(0.96, 0.96, 0.93), 0.01)
	var cana := Art.capsule(0.045, 0.46, blanco)
	cana.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	_gira.add_child(cana)
	for lado: float in [-1.0, 1.0]:
		for arriba: float in [-1.0, 1.0]:
			_gira.add_child(Art.sphere(0.055, blanco, Vector3(0.24 * lado, 0.04 * arriba, 0.0)))
	add_light(Color(0.85, 0.92, 1.0), 0.8, 2.5)


func _physics_process(delta: float) -> void:
	if is_instance_valid(_gira):
		_gira.rotate_y(delta * 14.0)
	super(delta)
