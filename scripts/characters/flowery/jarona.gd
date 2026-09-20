class_name Jarona
extends Ability
## Slot 1 de Flowery: "JARONA".
##
## El grito de su pelea de jefe. Una onda que sale de ella en todas direcciones.
##
## SU RAZON DE SER EN EL ROSTER: es lo unico del juego que INTERRUMPE un canalizado.
##
## Hasta ahora, Snowgrave (1.5s canalizando) y ZA WARUDO (0.9s) solo se podian cortar
## congelando al que canaliza o rompiendole la linea de vision. O sea: Noelle podia
## cortar a Noelle, y nadie mas podia hacer nada. Flowery es la respuesta a los
## preparados — el personaje que le grita en la cara al que se esta cargando algo.
##
## Es radial y no un cono a proposito: se usa cuando ya te tienen rodeado, y pedir
## punteria en ese momento seria pedir justo lo que no tenes.

const DAMAGE: float = 24.0
const RADIUS: float = 7.5
const KNOCKBACK: float = 9.0
const KNOCKBACK_LIFT: float = 2.0


func _init() -> void:
	id = &"jarona"
	display_name = "JARONA"
	description = "Grito en %.0fm a la redonda. %d de daño, empuja fuerte y CORTA cualquier canalizado." % [
		RADIUS, int(DAMAGE)]
	stamina_cost = 28.0
	cooldown = 5.5
	channel_time = 0.0
	icon_color = Color(1.0, 0.72, 0.26)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	var caster3d := caster as Node3D

	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, origin, RADIUS):
		# Linea de vision: si hay una cobertura en el medio, el grito no dobla la esquina.
		# Sin esto, Jarona atravesaria la plataforma central y las coberturas del mapa
		# dejarian de servir contra ella.
		if not CombatUtils.has_line_of_sight(caster3d, origin, target):
			continue

		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, KNOCKBACK_LIFT)
		_interrumpir(target)
		FX.spawn_hit_impact(caster, target.global_position + Vector3.UP, DAMAGE,
			Color(1.0, 0.78, 0.3))

	FX.spawn_jarona_wave(caster, origin, RADIUS)


## Le corta el canalizado al objetivo, si estaba canalizando.
##
## cancel_channel() ya devuelve la mitad de la stamina y avisa a los clientes, asi que
## alcanza con llamarlo: no hay que replicar nada a mano.
static func _interrumpir(target: Node3D) -> void:
	var caster := target.get_node_or_null("AbilityCaster") as AbilityCaster
	if caster != null and caster.is_channeling:
		caster.cancel_channel()
