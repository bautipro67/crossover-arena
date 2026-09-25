class_name Ability
extends Resource
## Clase base de toda habilidad, de cualquier personaje de cualquier juego.
##
## Para crear una habilidad nueva: extends Ability, seteas los datos en _init()
## y sobreescribis execute(). execute() SIEMPRE corre en el servidor.

@export var id: StringName = &""
@export var display_name: String = ""
@export var description: String = ""

## Costo en stamina. 0 = gratis (los golpes basicos van en 0 por diseño).
@export var stamina_cost: float = 0.0
@export var cooldown: float = 1.0
## Si es > 0, el jugador queda clavado en el piso mientras canaliza (la camara sigue libre).
@export var channel_time: float = 0.0
## Color placeholder del icono en el HUD hasta que haya arte.
@export var icon_color: Color = Color.WHITE
## Si es true, ademas de la stamina necesita el medidor de ultimate al 100%.
## Ese medidor se llena PEGANDO, no esperando: ver UltimateCharge.
@export var requires_charge: bool = false


## Condiciones extra propias de la habilidad. El chequeo de stamina y cooldown lo hace
## AbilityCaster, no hace falta repetirlo aca.
func can_use(_caster: Node) -> bool:
	return true


## CORRE EN EL SERVIDOR. Aca va el efecto real: daño, status, spawn de proyectiles.
func execute(_caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	pass


func get_cost() -> float:
	return stamina_cost


## ¿Hay que cortar una habilidad que va por la mitad?
##
## Las que son corrutinas —pasadas, rafagas, cadenas, vuelos— lo preguntan cada vez que
## vuelven de una espera. Una escena del modo historia las corta: sin esto, una JARONA que
## venia rebotando seguia en medio del dialogo, con su destello, su "¡JARONA!" y sus ondas
## en cada pasada, aunque ya no moviera a nadie ni sacara vida.
##
## Sin tipo a proposito: el que la tiro puede ya no existir.
static func interrumpida(caster) -> bool:
	return not is_instance_valid(caster) or Cinematica.activa
