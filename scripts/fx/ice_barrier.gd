class_name IceBarrier
extends Node3D
## Cupula de hielo de la Defensa de Hielo de Noelle.
##
## POR QUE ES UNA CLASE Y NO UN NODO ARMADO DENTRO DE FX: porque tiene que morir cuando
## se acaba el escudo, y averiguar eso desde afuera obliga a engancharse a una señal del
## jugador. La primera version hacia justo eso:
##
##     health.shield_changed.connect(func(v): if v <= 0.0: dome.queue_free())
##
## y dejaba la conexion colgada en el Health para siempre. El jugador vive toda la
## partida, la cupula dura cinco segundos, asi que a la segunda vez que alguien se
## escudaba Godot ya escupia "Lambda capture at index 0 was freed" en cada cambio de
## escudo, y se acumulaba una conexion muerta por cada uso.
##
## Preguntando desde adentro no hay nada que desconectar: cuando el nodo se libera, se
## termina el problema.

## A proposito NO se parece al hielo de un congelado: aquel es una capsula lisa que te
## deja indefenso, esta es una cascara con aristas que te protege. Si se vieran igual,
## el rival no sabria si conviene entrar a pegar o alejarse.
const COLOR: Color = Color(0.62, 0.88, 1.0, 0.34)
const SHARDS: int = 5
const SPIN_SPEED: float = 1.9

## Margen antes de empezar a mirar el escudo.
##
## En un cliente de red la barrera la crea el aviso de "alguien tiro una habilidad", y
## el valor del escudo llega en OTRO mensaje. Hoy el escudo llega primero, pero eso
## depende del orden en que el servidor manda dos RPC distintos: si algun dia se
## invierte, la barrera vería escudo 0 en su primer frame y se suicidaría al instante.
## Doscientos milisegundos de gracia hacen que no importe el orden.
const GRACIA: float = 0.2

var _health: Health = null
var _left: float = 0.0
var _ring: Node3D = null
var _vivido: float = 0.0


static func create(target: Node3D, duration: float) -> IceBarrier:
	if not is_instance_valid(target):
		return null
	var barrier := IceBarrier.new()
	barrier._health = target.get_node_or_null("Health") as Health
	barrier._left = duration
	target.add_child(barrier)
	barrier.position = Vector3(0.0, 1.0, 0.0)
	Sfx.play_3d(target, &"freeze", target.global_position + Vector3.UP, -6.0)
	return barrier


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Sin escritura de profundidad y sin sombra: es una cascara translucida, y si escribe
	# profundidad se tapa a si misma por dentro y se ve como un manchon opaco.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON

	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.95
	sphere.height = 2.3
	# Pocos segmentos = caras planas grandes, o sea cristal y no pelota.
	sphere.radial_segments = 7
	sphere.rings = 4
	dome.mesh = sphere
	dome.material_override = mat
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)

	# Placas girando alrededor: dan la lectura de "esto esta activo" sin tener que
	# mirar el HUD, que en pelea nadie mira.
	_ring = Node3D.new()
	add_child(_ring)
	for i: int in range(SHARDS):
		var shard := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.28, 0.55, 0.1)
		shard.mesh = prism
		shard.material_override = mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.add_child(shard)
		var ang := TAU * float(i) / float(SHARDS)
		shard.position = Vector3(cos(ang) * 1.05, 0.0, sin(ang) * 1.05)
		shard.rotation.y = -ang


func _process(delta: float) -> void:
	if is_instance_valid(_ring):
		_ring.rotation.y += SPIN_SPEED * delta

	_left -= delta
	_vivido += delta
	if _left <= 0.0:
		queue_free()
		return
	# Se va sola cuando le revientan el escudo. Preguntarlo aca en vez de escuchar una
	# señal es lo que evita el problema de las conexiones colgadas que explica la
	# cabecera.
	if _vivido < GRACIA:
		return
	if _health == null or not is_instance_valid(_health) or _health.shield <= 0.0:
		queue_free()
