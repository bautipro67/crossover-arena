class_name CadenaScorpion
extends MeshInstance3D
## La cadena de la lanza: una soga de metal que va de la mano de Scorpion a la punta.
##
## Se estira sola cada frame entre los dos extremos, asi sigue al kunai mientras vuela y al
## que ensarto mientras lo arrastra. Si cualquiera de los dos deja de existir —el kunai
## pego y se fue, el rival murio— la cadena se va con el.
##
## ES PURO EFECTO: el daño y el tiron los decide el servidor en Lanza. Por eso corre igual en
## el servidor y en cada cliente.

## Donde sale: la mano, a la altura del pecho.
const ALTO_MANO: float = 1.25
## Donde engancha en el rival: el pecho, no los pies.
const ALTO_BLANCO: float = 1.0

var _desde: WeakRef = null
var _hasta: WeakRef = null
var _alto_hasta: float = 0.0
var _vida: float = 1.0


## Una cadena de `desde` a `hasta`, que dura `segundos` como mucho.
static func crear(desde: Node3D, hasta: Node3D, segundos: float, alto_hasta: float = 0.0) -> CadenaScorpion:
	if not is_instance_valid(desde) or not is_instance_valid(hasta):
		return null
	var mundo := desde.get_parent()
	if mundo == null:
		return null
	var c := CadenaScorpion.new()
	c._desde = weakref(desde)
	c._hasta = weakref(hasta)
	c._alto_hasta = alto_hasta
	c._vida = segundos
	var malla := CylinderMesh.new()
	malla.top_radius = 0.05
	malla.bottom_radius = 0.05
	malla.height = 1.0
	malla.radial_segments = 6
	malla.rings = 1
	c.mesh = malla
	# Sin contorno: una linea de dibujo alrededor de algo tan fino la volveria una soga gruesa.
	c.material_override = Art.metal(Color(0.82, 0.78, 0.70), 0.0)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mundo.add_child(c)
	c._acomodar()
	return c


func _process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0 or not _acomodar():
		queue_free()


## La pone entre los dos extremos. Devuelve false si alguno ya no existe.
func _acomodar() -> bool:
	var a := _desde.get_ref() as Node3D if _desde != null else null
	var b := _hasta.get_ref() as Node3D if _hasta != null else null
	if a == null or b == null or not a.is_inside_tree() or not b.is_inside_tree():
		return false
	var p := a.global_position + Vector3.UP * ALTO_MANO
	var q := b.global_position + Vector3.UP * _alto_hasta
	var tramo := q - p
	var largo := tramo.length()
	if largo < 0.05:
		visible = false
		return true
	visible = true
	var eje := tramo / largo
	# Derecho para abajo el arco de UP a eje no esta definido: se da vuelta a mano.
	var base := Basis(Vector3.RIGHT, PI) if eje.dot(Vector3.UP) < -0.999 else Basis(Quaternion(Vector3.UP, eje))
	global_transform = Transform3D(base * Basis.from_scale(Vector3(1.0, largo, 1.0)), (p + q) * 0.5)
	return true
