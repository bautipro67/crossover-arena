class_name PlasmaBolt
extends Projectile
## El disparo de la pistola de plasma de Rick. Rapido, chico y verde.
##
## Viaja RECTO, sin caida: es energia, no un objeto. Eso lo hace el unico basico del
## juego que se puede usar a distancia sin compensar apuntando mas arriba, y es la mitad
## de la identidad de Rick: los otros tres tienen que acercarse para pegar.

func _init() -> void:
	tint = Color(0.45, 1.0, 0.35)
	hit_radius = 0.18
	fall_gravity = 0.0
	impact_sound = &"plasma"
	knockback = 1.4
	knockback_lift = 0.2


func _build_visual() -> void:
	# Capsula estirada a lo largo del viaje, no una bola: una bola no dice hacia donde
	# va, y un disparo de energia se lee por su direccion antes que por su color.
	var cuerpo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.075
	cap.height = 0.46
	cuerpo.mesh = cap
	cuerpo.material_override = make_glow_material(tint)
	cuerpo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(cuerpo)

	add_trail(Color(0.5, 1.0, 0.4, 0.55), 14)
	add_light(tint, 1.6, 3.2)
