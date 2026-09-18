class_name NoelleBasicAttack
extends Ability
## Slot 0 de Noelle: "Icicle Strike".
##
## Golpe basico. NO CUESTA STAMINA (regla central del juego).
## Es la forma barata de apilar escarcha cuando te quedaste sin stamina para Ice Shock:
## te obliga a acercarte, que es el riesgo que paga el ser gratis.

const DAMAGE: float = 11.0
const CONE_RANGE: float = 3.2
const CONE_ANGLE: float = 70.0
const CHILL_STACKS: int = 1
## Empujon chico a proposito: si lo sacara de los 3.2m de alcance, el golpe gratis
## se volveria imposible de encadenar.
const KNOCKBACK: float = 3.5


func _init() -> void:
	id = &"icicle_strike"
	display_name = "Icicle Strike"
	description = "Zarpazo helado al frente. Gratis, corto alcance, suma 1 de escarcha."
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.5
	channel_time = 0.0
	icon_color = Color(0.72, 0.88, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	var targets := CombatUtils.get_players_in_cone(caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE)
	for target: Node3D in targets:
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_chill(target, CHILL_STACKS)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.8)
		FX.spawn_ice_impact(caster, target.global_position + Vector3.UP)
	FX.spawn_melee_arc(caster, origin, dir)
