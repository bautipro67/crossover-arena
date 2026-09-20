class_name OmegaForm
extends Node3D
## La transformacion de Flowery al tirar LAST JARONA.
##
## EN EL ORIGINAL: al llamar a las otras seis flores, Flowery pasa a "Omega Flowery" —
## el cuerpo envuelto en luz arcoiris que cambia rapido, y el pelo en puntas.
##
## Eso es lo que esto reproduce, y es la parte del ultimate que mas hacia falta: antes
## era una onda naranja que podria haber sido de cualquiera. El que lo mira tiene que
## saber que lo que viene no es una habilidad mas.
##
## Va como hijo del Player, se autodestruye sola, y no toca nada de la logica: si borras
## este archivo el ultimate sigue funcionando igual, solo que sin espectaculo.

## Los siete colores de las flores. El ciclo pasa por todos, y esa es la idea: la forma
## Omega es la suma de las siete, no un color nuevo.
const COLORES: Array[Color] = [
	Color(1.0, 0.24, 0.24),   # rojo
	Color(1.0, 0.58, 0.18),   # naranja
	Color(1.0, 0.92, 0.26),   # amarillo
	Color(0.36, 0.90, 0.38),  # verde
	Color(0.30, 0.62, 1.0),   # azul
	Color(0.30, 0.92, 0.94),  # aqua
	Color(0.74, 0.40, 0.98),  # violeta
]
## Vueltas de color por segundo. Rapido: en el original la luz "cambia rapidamente", y
## si va lento se lee como un aura tranquila en vez de como algo desbocado.
const VELOCIDAD: float = 4.5
const PICOS: int = 7


var _left: float = 0.0
var _t: float = 0.0
var _mat: StandardMaterial3D = null
var _luz: OmniLight3D = null
var _pelo: Array[MeshInstance3D] = []


static func create(target: Node3D, duration: float) -> OmegaForm:
	if not is_instance_valid(target):
		return null
	var forma := OmegaForm.new()
	forma._left = duration
	target.add_child(forma)
	forma.position = Vector3(0.0, 1.0, 0.0)
	return forma


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.30)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission_energy_multiplier = 3.0
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	# Envoltura del cuerpo: una capsula un poco mas grande que el jugador.
	var aura := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.46
	capsula.height = 2.1
	aura.mesh = capsula
	aura.material_override = _mat
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aura)

	# PELO EN PUNTAS. Es el detalle que en el original lo vuelve reconocible al
	# instante, y sin el la transformacion es "el mismo con un aura de color".
	for i: int in range(PICOS):
		var pico := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.075
		cono.height = 0.52 - 0.05 * absf(float(i) - float(PICOS) * 0.5)
		pico.mesh = cono
		pico.material_override = _mat
		pico.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Abanico alrededor de la cabeza, abriendose hacia arriba y atras.
		var t := float(i) / float(PICOS - 1) - 0.5
		pico.position = Vector3(t * 0.34, 0.92, 0.06 + absf(t) * 0.10)
		pico.rotation_degrees = Vector3(18.0, 0.0, -t * 58.0)
		add_child(pico)
		_pelo.append(pico)

	_luz = OmniLight3D.new()
	_luz.omni_range = 9.0
	_luz.light_energy = 4.0
	_luz.shadow_enabled = false
	add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return

	# Interpola ENTRE colores consecutivos en vez de saltar de uno a otro: saltando se
	# ve como un cartel de neon roto, interpolando se ve como luz.
	var pos := fmod(_t * VELOCIDAD, float(COLORES.size()))
	var i := int(pos)
	var f := pos - float(i)
	var color := COLORES[i].lerp(COLORES[(i + 1) % COLORES.size()], f)

	_mat.emission = color
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.34)
	if _luz != null:
		_luz.light_color = color

	# Los picos laten con el ciclo: el pelo "vibra" con la luz.
	var pulso := 1.0 + sin(_t * VELOCIDAD * TAU) * 0.10
	for pico: MeshInstance3D in _pelo:
		if is_instance_valid(pico):
			pico.scale = Vector3(1.0, pulso, 1.0)
