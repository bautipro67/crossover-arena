class_name KiEsfera
extends Projectile
## Una esfera de ki: la bola de energia que Goku dispara de a varias.
##
## Una BOLA y no una capsula, al reves que el plasma de Rick: el ki de Dragon Ball se
## dibuja siempre como una esfera con un halo, y es lo que la separa a primera vista de
## un disparo de pistola.


func _init() -> void:
	tint = Color(0.55, 0.85, 1.0)
	hit_radius = 0.24
	fall_gravity = 0.0
	impact_sound = &"plasma"
	knockback = 1.8
	knockback_lift = 0.3


func _build_visual() -> void:
	var nucleo := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.13
	bola.height = 0.26
	nucleo.mesh = bola
	nucleo.material_override = make_glow_material(Color(0.92, 0.97, 1.0))
	add_child(nucleo)

	# El halo: una esfera mas grande y transparente alrededor del nucleo blanco. El ki se
	# lee por ese borde de color, no por el centro, que casi siempre es blanco.
	var halo := MeshInstance3D.new()
	var bola_halo := SphereMesh.new()
	bola_halo.radius = 0.24
	bola_halo.height = 0.48
	halo.mesh = bola_halo
	var mat := make_glow_material(tint)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.40
	halo.material_override = mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	add_trail(Color(0.55, 0.85, 1.0, 0.5), 12)
	add_light(tint, 1.8, 3.4)
