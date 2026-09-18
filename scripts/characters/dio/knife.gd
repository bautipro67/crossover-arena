class_name Knife
extends Projectile
## Cuchillo de Dio. Viaja rapido y con un poco de caida, asi a distancia larga hay
## que compensar apuntando mas arriba.

func _init() -> void:
	tint = Color(0.85, 0.85, 0.9)
	hit_radius = 0.22
	fall_gravity = 4.0
	impact_sound = &"knife"
	knockback = 2.6
	knockback_lift = 0.5


func _build_visual() -> void:
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.5, 0.14)
	blade.mesh = mesh
	var mat := make_glow_material(tint)
	mat.metallic = 0.9
	mat.roughness = 0.2
	mat.emission_energy_multiplier = 0.8
	blade.material_override = mat
	blade.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(blade)

	add_trail(Color(0.9, 0.9, 1.0, 0.5), 12)
