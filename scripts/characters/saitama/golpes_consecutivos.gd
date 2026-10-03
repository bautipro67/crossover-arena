class_name GolpesConsecutivos
extends Ability
## Slot 1 de Saitama: "GOLPES NORMALES CONSECUTIVOS".
##
## Muchos golpes normales, uno atras del otro, tan rapido que se ven cien puños a la vez.
## Y TAN RAPIDOS QUE EL AIRE PEGA: el viento de cada piña llega a media distancia, en una
## franja angosta. Es lo unico que tiene Saitama para el que pelea de lejos; sin eso, Rick
## y Flowery lo tenian corriendo detras toda la pelea. El ultimo empuja lejos.

const DAMAGE_PER_TICK: float = 3.4
const TICKS: int = 10
const TICK_INTERVAL: float = 0.1
const CONE_RANGE: float = 6.0
const CONE_ANGLE: float = 42.0
const FINAL_KNOCKBACK: float = 9.0


func _init() -> void:
	id = &"golpes_consecutivos"
	display_name = "Golpes normales consecutivos"
	description = "%d golpes normales en %.1f s, %.1f de daño cada uno, hasta %.1f m. El último empuja lejos." % [
		TICKS, float(TICKS) * TICK_INTERVAL, DAMAGE_PER_TICK, CONE_RANGE]
	stamina_cost = 28.0
	cooldown = 10.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.75, 0.15)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	var tree := caster.get_tree()
	if caster3d == null or tree == null:
		return
	var source_id: int = caster3d.peer_id
	for i: int in range(TICKS):
		if i > 0:
			await tree.create_timer(TICK_INTERVAL).timeout
		if Ability.interrumpida(caster3d):
			return
		var vida := caster3d.get_node_or_null("Health") as Health
		var estado := caster3d.get_node_or_null("StatusEffects") as StatusEffects
		if (vida != null and vida.is_dead) or (estado != null and not estado.can_act()):
			return
		var aqui := caster3d.global_position + Vector3.UP * 1.1
		var frente := -caster3d.global_transform.basis.z
		var ultimo := i == TICKS - 1
		FX.spawn_puños(caster3d, aqui, frente)
		for target: Node3D in CombatUtils.get_players_in_cone(caster3d, aqui, frente, CONE_RANGE, CONE_ANGLE):
			CombatUtils.deal_damage(target, DAMAGE_PER_TICK, source_id)
			CombatUtils.apply_knockback(target, target.global_position - aqui,
				FINAL_KNOCKBACK if ultimo else 0.3, 2.4 if ultimo else 0.4)
