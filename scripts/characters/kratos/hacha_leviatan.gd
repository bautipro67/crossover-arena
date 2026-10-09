class_name HachaLeviatan
extends Ability
## Slot 0 de Kratos: "HACHA LEVIATAN". Golpe basico, GRATIS como todos.
##
## Un hachazo pesado y mas lento que el basico de los demas. El hacha es de hielo: el que
## la come queda un poco mas lento por un momento.

const DAMAGE: float = 15.0
const CONE_RANGE: float = 3.5
const CONE_ANGLE: float = 74.0
const KNOCKBACK: float = 4.0
const LENTO: float = 0.20
const LENTO_DURA: float = 0.8
const HIELO := Color(0.70, 0.88, 1.0)


func _init() -> void:
	id = &"hacha_leviatan"
	display_name = "Hacha Leviatán"
	description = "Un hachazo de hielo: %d de daño y deja un poco lento. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.80
	channel_time = 0.0
	icon_color = HIELO


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null:
			estado.apply_slow(LENTO, LENTO_DURA)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.75, 0.92, 1.0, 0.95))
	FX.spawn_slash_arc(caster, origin, dir, HIELO)
