class_name EsferaPsiquica
extends Projectile
## El disparo basico de Mob: una onda de telequinesis, chica y rapida.
##
## Celeste con el centro blanco, el color de los poderes de Mob en la serie. Viaja recto y
## se apaga enseguida: es un empujon a distancia corta, no un tiro de punta a punta.


func _init() -> void:
	tint = Color(0.62, 0.80, 1.0)
	hit_radius = 0.30
	fall_gravity = 0.0
	impact_sound = &"psiquico"
	knockback = 2.2
	knockback_lift = 0.4


func _build_visual() -> void:
	var nucleo := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.11
	bola.height = 0.22
	nucleo.mesh = bola
	nucleo.material_override = make_glow_material(Color(0.95, 0.97, 1.0))
	add_child(nucleo)
	# La onda: un anillo que mira hacia donde va, como el aire que se deforma.
	var onda := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.16
	toro.outer_radius = 0.24
	onda.mesh = toro
	var mat := make_glow_material(tint)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	onda.material_override = mat
	onda.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(onda)
	add_trail(Color(0.65, 0.82, 1.0, 0.45), 10)
	add_light(tint, 1.2, 2.6)
