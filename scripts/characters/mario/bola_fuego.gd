class_name BolaFuego
extends Projectile
## La bola de fuego de Mario: la de la Flor de Fuego.
##
## REBOTA POR EL PISO, que es lo que la hace de Mario y no un disparo mas. Sale hacia
## abajo, pega en el suelo y salta, y sigue saltando mientras avanza. Contra una pared se
## apaga. Por eso se esquiva distinto que todo lo demas del juego: no alcanza con correrse
## de costado, hay que mirar donde va a picar.
##
## El rebote lo hace ella misma, en el servidor y en la copia de los clientes: las dos
## chocan con el mismo piso, asi que la copia rebota donde rebota la de verdad.

## Cuanto sube despues de cada pique.
const REBOTE: float = 5.2
## Cuantos piques antes de apagarse sola.
const PIQUES: int = 6

var _piques: int = 0


func _init() -> void:
	tint = Color(1.0, 0.55, 0.15)
	hit_radius = 0.32
	fall_gravity = 22.0
	impact_sound = &"fuego"
	knockback = 3.0
	knockback_lift = 1.2


func _build_visual() -> void:
	var nucleo := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.16
	bola.height = 0.32
	nucleo.mesh = bola
	nucleo.material_override = make_glow_material(Color(1.0, 0.92, 0.55))
	add_child(nucleo)
	# La llama alrededor: naranja y transparente. El fuego se lee por el borde, no por el
	# centro, que es casi blanco.
	var llama := MeshInstance3D.new()
	var bola_llama := SphereMesh.new()
	bola_llama.radius = 0.28
	bola_llama.height = 0.56
	llama.mesh = bola_llama
	var mat := make_glow_material(tint)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.45
	llama.material_override = mat
	llama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(llama)
	add_trail(Color(1.0, 0.45, 0.10, 0.6), 18)
	add_light(tint, 2.0, 3.6)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		expire()
		return
	_velocity.y -= fall_gravity * delta
	var desde := global_position
	var hasta := desde + _velocity * delta
	if not cosmetic_only and _revisar_jugadores(hasta):
		return
	var espacio := get_world_3d().direct_space_state
	if espacio != null:
		var rayo := PhysicsRayQueryParameters3D.create(desde, hasta)
		rayo.collision_mask = GameConfig.LAYER_WORLD
		var choque := espacio.intersect_ray(rayo)
		if not choque.is_empty():
			var normal := choque["normal"] as Vector3
			# PISO: pica y vuelve a subir. Un piso es lo que mira para arriba; una pared o
			# el costado de una cobertura, no.
			if normal.y > 0.6 and _piques < PIQUES:
				_piques += 1
				global_position = (choque["position"] as Vector3) + normal * 0.05
				_velocity.y = REBOTE
				return
			_spent = true
			global_position = choque["position"] as Vector3
			_spawn_impact_fx()
			expire()
			return
	global_position = hasta
