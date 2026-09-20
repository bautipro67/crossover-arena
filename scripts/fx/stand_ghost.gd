class_name StandGhost
extends Node3D
## The World: el Stand de Dio, que aparece detras de el cuando ataca.
##
## POR QUE HACIA FALTA. Dio tenia MUDA, la rafaga y ZA WARUDO, y en los tres el Stand
## —que es literalmente lo que pega en el original— no aparecia por ningun lado. Se veia
## a un tipo dorado tirando trompadas al aire. El Stand no es un adorno: es EL rasgo
## reconocible del personaje.
##
## Es translucido y dorado, flota detras del hombro y desaparece solo. Como todo en FX,
## es puramente cosmetico: si borras este archivo el daño sale igual.

const COLOR: Color = Color(0.96, 0.78, 0.30)
## Cuanto tarda en aparecer y en irse. Corto: el Stand se materializa de golpe.
const FADE: float = 0.12

var _left: float = 0.0
var _total: float = 0.0
var _mat: StandardMaterial3D = null
var _brazo_izq: Node3D = null
var _brazo_der: Node3D = null
var _t: float = 0.0
## Si es > 0, los brazos tiran trompadas a esa frecuencia (la rafaga MUDA).
var _punch_hz: float = 0.0


static func create(target: Node3D, duration: float, punch_hz: float = 0.0) -> StandGhost:
	if not is_instance_valid(target):
		return null
	var ghost := StandGhost.new()
	ghost._left = duration
	ghost._total = duration
	ghost._punch_hz = punch_hz
	target.add_child(ghost)
	# AL COSTADO, no atras.
	#
	# Atras es donde va en el manga, pero este juego es en tercera persona con la camara
	# sobre el hombro: puesto atras, el Stand queda ENTRE la camara y Dio y te tapa la
	# pantalla entera. Al costado y un poco adelante se ve completo y no estorba.
	ghost.position = Vector3(0.85, 0.35, -0.15)
	ghost.rotation_degrees = Vector3(0.0, -14.0, 0.0)
	return ghost


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, 0.0)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = COLOR
	# Bajo a proposito. Con 1.5 el Stand salia como una mancha blanca: se veia que habia
	# algo, no QUE habia. Con menos emision se leen la cresta, las hombreras y los brazos.
	_mat.emission_energy_multiplier = 0.55
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Sin profundidad ni sombra: es una aparicion, no un cuerpo. Con profundidad se
	# recorta contra Dio y parece una estatua metida adentro de el.
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	# --- Torso ---
	_agregar(CapsuleMesh.new(), Vector3(0.0, 0.28, 0.0), Vector3(1.15, 1.0, 0.85), func(m: Mesh) -> void:
		var c := m as CapsuleMesh
		c.radius = 0.20
		c.height = 0.86)
	# Cintura marcada: sin ella el torso y las hombreras se funden en un borron.
	_agregar(CapsuleMesh.new(), Vector3(0.0, -0.10, 0.0), Vector3(1.0, 1.0, 0.8), func(m: Mesh) -> void:
		var c := m as CapsuleMesh
		c.radius = 0.13
		c.height = 0.34)

	# --- Cabeza, con la cresta de The World ---
	_agregar(SphereMesh.new(), Vector3(0.0, 0.84, 0.0), Vector3(1.0, 1.12, 1.0), func(m: Mesh) -> void:
		var sp := m as SphereMesh
		sp.radius = 0.165
		sp.height = 0.33)
	# La cresta de The World: es lo que lo hace reconocible de un vistazo.
	_agregar(BoxMesh.new(), Vector3(0.0, 1.04, 0.02), Vector3.ONE, func(m: Mesh) -> void:
		(m as BoxMesh).size = Vector3(0.075, 0.22, 0.28))

	# --- Hombreras ---
	for side: float in [-1.0, 1.0]:
		_agregar(SphereMesh.new(), Vector3(0.30 * side, 0.58, 0.0), Vector3(1.25, 0.85, 1.1),
			func(m: Mesh) -> void:
				var sp := m as SphereMesh
				sp.radius = 0.135
				sp.height = 0.27)

	# --- Brazos, que son los que pegan ---
	_brazo_izq = _brazo(-1.0)
	_brazo_der = _brazo(1.0)


func _brazo(side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0.30 * side, 0.52, 0.0)
	add_child(pivot)
	var brazo := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.082
	cap.height = 0.58
	brazo.mesh = cap
	brazo.material_override = _mat
	brazo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brazo.position = Vector3(0.0, -0.26, 0.0)
	pivot.add_child(brazo)
	# Puño.
	var puno := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.11
	esfera.height = 0.22
	puno.mesh = esfera
	puno.material_override = _mat
	puno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puno.position = Vector3(0.0, -0.54, 0.0)
	pivot.add_child(puno)
	return pivot


func _agregar(mesh: Mesh, pos: Vector3, escala: Vector3, configurar: Callable) -> void:
	configurar.call(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = escala
	add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return

	# Entra y sale con un fundido corto en los extremos.
	var alfa := 0.72
	var vivido := _total - _left
	if vivido < FADE:
		alfa *= vivido / FADE
	elif _left < FADE:
		alfa *= _left / FADE
	_mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, alfa)

	if _punch_hz <= 0.0:
		# Sin rafaga: flota apenas, para que no parezca una estatua pegada a la espalda.
		position.y = 0.35 + sin(_t * 3.0) * 0.04
		return

	# MUDA MUDA MUDA: los dos brazos alternados, medio ciclo desfasados.
	var fase := _t * _punch_hz * TAU
	if is_instance_valid(_brazo_izq):
		_brazo_izq.rotation.x = -1.35 + sin(fase) * 1.15
	if is_instance_valid(_brazo_der):
		_brazo_der.rotation.x = -1.35 + sin(fase + PI) * 1.15
