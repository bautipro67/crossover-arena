class_name Petal
extends Projectile
## Petalo del ataque basico de Flowery. Chico, rapido y descartable.
##
## No hace nada mas que daño: el kit de Flowery ya tiene un interruptor (Jarona) y una
## carga; si el petalo ademas aplicara un estado, su ataque GRATIS seria mejor que las
## habilidades pagas de los otros dos personajes.


func _init() -> void:
	tint = Color(1.0, 0.86, 0.32)
	hit_radius = 0.28
	# Casi sin empuje: son varios seguidos y si empujaran, el primero sacaria al rival
	# del camino de los otros dos.
	knockback = 1.4
	knockback_lift = 0.2


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	# Un petalo: una esfera achatada, no un prisma. La silueta tiene que distinguirse de
	# las esquirlas de hielo de Noelle aunque las dos sean cosas chicas que vuelan.
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	sphere.radial_segments = 8
	sphere.rings = 4
	mesh_instance.mesh = sphere
	mesh_instance.scale = Vector3(1.0, 0.35, 1.6)
	var mat := make_glow_material(tint)
	mat.albedo_color.a = 0.95
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	add_light(Color(1.0, 0.82, 0.3))
	add_trail(Color(1.0, 0.9, 0.5, 0.7))
