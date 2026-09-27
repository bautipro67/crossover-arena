class_name GomuGatling
extends Ability
## Slot 1 de Luffy: "GOMU GOMU NO GATLING".
##
## Estira y encoge los brazos tan rapido que parecen cien: una lluvia de piñas adelante.
## Hay que seguir encima del rival mientras dura, como la rafaga del Stand de Dio.

const DAMAGE_PER_TICK: float = 4.0
const TICKS: int = 8
const TICK_INTERVAL: float = 0.12
const CONE_RANGE: float = 4.5
const CONE_ANGLE: float = 55.0
const FINAL_KNOCKBACK: float = 8.0


func _init() -> void:
	id = &"gomu_gatling"
	display_name = "Gomu Gomu no Gatling"
	description = "Una lluvia de %d piñas en %.1f s, %.1f de daño cada una, hasta %.1f m." % [
		TICKS, float(TICKS) * TICK_INTERVAL, DAMAGE_PER_TICK, CONE_RANGE]
	stamina_cost = 28.0
	cooldown = 10.0
	channel_time = 0.0
	icon_color = Color(0.95, 0.30, 0.20)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
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
		FX.spawn_brazo_goma(caster3d, aqui, frente.rotated(Vector3.UP, randf_range(-0.35, 0.35)), CONE_RANGE)
		var ultimo := i == TICKS - 1
		for target: Node3D in CombatUtils.get_players_in_cone(caster3d, aqui, frente, CONE_RANGE, CONE_ANGLE):
			CombatUtils.deal_damage(target, DAMAGE_PER_TICK, source_id)
			var afuera := target.global_position - aqui
			CombatUtils.apply_knockback(target, afuera, FINAL_KNOCKBACK if ultimo else 0.3, 2.2 if ultimo else 0.4)
