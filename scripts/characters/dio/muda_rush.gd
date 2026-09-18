class_name MudaRush
extends Ability
## Slot 0 de Dio: "MUDA MUDA MUDA".
##
## Golpe basico. NO CUESTA STAMINA (regla central del juego).
##
## Comparado con el Icicle Strike de Noelle: pega mas fuerte y mas rapido, pero el
## cono es mas corto y angosto. Dio es un peleador de distancia corta: su golpe gratis
## es su herramienta principal, no un relleno mientras espera cooldowns.

const DAMAGE: float = 13.0
const CONE_RANGE: float = 3.0
const CONE_ANGLE: float = 60.0
## Casi nada: MUDA es una rafaga, si empujara de verdad Dio se alejaria solo del rival.
const KNOCKBACK: float = 2.4


func _init() -> void:
	id = &"muda_rush"
	display_name = "MUDA MUDA"
	description = "Rafaga de golpes al frente. Gratis, rapida, corto alcance."
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.4
	channel_time = 0.0
	icon_color = Color(1.0, 0.82, 0.3)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.5)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.85, 0.35, 0.95))
	FX.spawn_muda_flurry(caster, origin, dir)
