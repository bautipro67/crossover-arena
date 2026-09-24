class_name Meeseeks
extends Projectile
## Un Mr. Meeseeks. Persigue al rival mas cercano y revienta encima suyo.
##
## ES EL UNICO PROYECTIL DEL JUEGO QUE BUSCA. Todos los demas viajan rectos y se
## esquivan moviendose de la linea; este corrige el rumbo, asi que esquivarlo pide
## ponerle algo en el medio o sacarle distancia hasta que se le acabe la vida.
##
## No gira instantaneamente a proposito: `GIRO` limita cuanto puede corregir por segundo,
## y de ahi sale el unico contrajuego que tiene. Con giro infinito seria imposible de
## evitar y dejaria de ser un enemigo para ser un temporizador.
const GIRO: float = 2.6
## Deja de corregir cuando ya esta encima: si no, orbita alrededor del rival como una
## polilla y nunca llega a tocarlo.
const CIEGO: float = 1.4

var _objetivo: Node3D = null


func _init() -> void:
	tint = Color(0.35, 0.82, 0.95)
	hit_radius = 0.42
	fall_gravity = 0.0
	impact_sound = &"meeseeks"
	knockback = 4.5
	knockback_lift = 1.6


func _build_visual() -> void:
	var mat := make_glow_material(tint)
	mat.emission_energy_multiplier = 1.1

	# Cuerpo: capsula alta y angosta, como en la serie.
	var cuerpo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.19
	cap.height = 0.66
	cuerpo.mesh = cap
	cuerpo.material_override = mat
	add_child(cuerpo)

	# El pelo naranja: es lo unico que no es celeste y lo que lo hace reconocible.
	var pelo := MeshInstance3D.new()
	var mecha := CylinderMesh.new()
	mecha.top_radius = 0.0
	mecha.bottom_radius = 0.065
	mecha.height = 0.22
	pelo.mesh = mecha
	pelo.material_override = Art.glow(Color(1.0, 0.55, 0.15), 2.0)
	pelo.position = Vector3(0.0, 0.40, 0.0)
	pelo.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	add_child(pelo)

	# Los ojos, enormes y muy juntos.
	var blanco := Art.flat(Color(0.98, 0.98, 1.0))
	var negro := Art.flat(Color(0.05, 0.06, 0.10))
	for side: float in [-1.0, 1.0]:
		var ojo := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.072
		esfera.height = 0.144
		ojo.mesh = esfera
		ojo.material_override = blanco
		ojo.position = Vector3(0.062 * side, 0.20, -0.145)
		add_child(ojo)
		var pupila := MeshInstance3D.new()
		var chica := SphereMesh.new()
		chica.radius = 0.034
		chica.height = 0.068
		pupila.mesh = chica
		pupila.material_override = negro
		pupila.position = Vector3(0.062 * side, 0.20, -0.196)
		add_child(pupila)

	add_trail(Color(0.4, 0.85, 1.0, 0.45), 16)
	add_light(tint, 1.4, 3.0)


func _physics_process(delta: float) -> void:
	_corregir_rumbo(delta)
	super(delta)


## Gira el rumbo hacia el rival vivo mas cercano, con un tope por segundo.
func _corregir_rumbo(delta: float) -> void:
	if not is_instance_valid(_objetivo) or _muerto(_objetivo):
		_objetivo = _buscar()
	if not is_instance_valid(_objetivo):
		return
	var hacia := _objetivo.global_position + Vector3.UP * 0.9 - global_position
	if hacia.length() < CIEGO:
		return
	var deseado := hacia.normalized()
	# rotate_toward respeta el tope de giro y no pasa de largo si ya casi apunta.
	direction = direction.normalized().rotated(
		direction.cross(deseado).normalized() if not direction.cross(deseado).is_zero_approx() else Vector3.UP,
		minf(GIRO * delta, direction.angle_to(deseado)))
	_velocity = direction * speed


func _buscar() -> Node3D:
	var mejor: Node3D = null
	var mejor_dist := 60.0
	for nodo: Node in get_tree().get_nodes_in_group("players"):
		var otro := nodo as Node3D
		if otro == null or otro == shooter or _muerto(otro):
			continue
		if CombatUtils.son_aliados(shooter, otro):
			continue
		var d := global_position.distance_to(otro.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = otro
	return mejor


static func _muerto(nodo: Node) -> bool:
	var health := nodo.get_node_or_null("Health") as Health
	return health == null or health.is_dead
