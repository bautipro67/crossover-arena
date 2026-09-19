class_name StandBarrage
extends Ability
## Slot 2 de Dio: "MUDA MUDA MUDA" del Stand.
##
## La rafaga larga de The World: muchisimos golpes seguidos en el mismo lugar.
##
## DIFERENCIA CON EL GOLPE BASICO, que tambien es una rafaga: el basico resuelve en un
## instante y podes seguir moviendote. Este pega SEIS VECES a lo largo de casi un
## segundo, y cada golpe busca objetivo de nuevo con la direccion que Dio tenga EN ESE
## MOMENTO. O sea que el daño total es alto pero hay que quedarse encima del rival todo
## el rato: si el otro se despega despues del segundo golpe, los otros cuatro pegan al
## aire. Es una herramienta de castigo, no de apertura.
##
## Por eso tampoco clava a Dio en el piso: lo que se premia es perseguir.

const DAMAGE_PER_TICK: float = 13.0
const TICKS: int = 6
const TICK_INTERVAL: float = 0.15
const CONE_RANGE: float = 3.4
const CONE_ANGLE: float = 65.0
## Casi cero, y medido: con 1.2 la propia rafaga empujaba al rival fuera del cono al
## tercer golpe y la mitad de la habilidad pegaba al aire. Lo que queda es un saltito
## vertical que se ve, sin desplazamiento horizontal que arruine los golpes siguientes.
const KNOCKBACK_PER_TICK: float = 0.35
const LIFT_PER_TICK: float = 0.55
## El ultimo si empuja fuerte. Cierra la rafaga con una lectura clara de "termino".
const FINAL_KNOCKBACK: float = 9.0
const FINAL_LIFT: float = 2.4


func _init() -> void:
	id = &"stand_barrage"
	display_name = "Rafaga del Stand"
	description = "%d golpes en %.1fs, %d de daño cada uno. Hay que seguir encima del rival." % [
		TICKS, TICKS * TICK_INTERVAL, int(DAMAGE_PER_TICK)]
	stamina_cost = 32.0
	cooldown = 8.0
	channel_time = 0.0
	icon_color = Color(0.95, 0.75, 0.25)


## CORRE EN EL SERVIDOR. Es una corrutina: se queda viva entre golpe y golpe.
##
## Cada iteracion revalida que el caster siga existiendo y vivo. Sin eso, matar a Dio a
## mitad de la rafaga dejaria los golpes restantes saliendo de un nodo liberado.
func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	var tree := caster.get_tree()
	if tree == null:
		return

	for i: int in range(TICKS):
		if i > 0:
			await tree.create_timer(TICK_INTERVAL).timeout
		if not is_instance_valid(caster):
			return
		var health := caster.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			return
		# Congelado o con el tiempo parado encima, la rafaga se corta.
		var status := caster.get_node_or_null("StatusEffects") as StatusEffects
		if status != null and not status.can_act():
			return

		var caster3d := caster as Node3D
		var here := origin
		var facing := dir
		if caster3d != null:
			here = caster3d.global_position + Vector3.UP * 1.1
			facing = -caster3d.global_transform.basis.z

		var is_last := i == TICKS - 1
		for target: Node3D in CombatUtils.get_players_in_cone(caster3d, here, facing, CONE_RANGE, CONE_ANGLE):
			CombatUtils.deal_damage(target, DAMAGE_PER_TICK, source_id)
			var away := target.global_position - here
			if is_last:
				CombatUtils.apply_knockback(target, away, FINAL_KNOCKBACK, FINAL_LIFT)
			else:
				CombatUtils.apply_knockback(target, away, KNOCKBACK_PER_TICK, LIFT_PER_TICK)
			FX.spawn_impact_burst(caster, target.global_position + Vector3.UP,
				Color(1.0, 0.85, 0.35, 0.95))
		FX.spawn_muda_flurry(caster, here, facing)
