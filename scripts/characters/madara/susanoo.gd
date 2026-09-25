class_name Susanoo
extends Ability
## Slot 2 de Madara: "SUSANO'O". El guerrero de chakra azul que lo rodea.
##
## En la serie el Susano'o es a la vez armadura y arma: una caja de costillas que para
## cualquier golpe y un gigante que corta con una espada. Las dos cosas en una habilidad:
## al activarlo, Madara queda envuelto en un escudo por unos segundos y el Susano'o suelta
## un espadazo ancho al frente.
##
## El escudo es el mismo de la Defensa de Hielo de Noelle (Health.add_shield): se come el
## daño antes que la vida y se va solo al vencer.

const ESCUDO: float = 34.0
const DURACION: float = 6.0
const DAMAGE: float = 24.0
const ALCANCE: float = 5.5
const ANGULO: float = 120.0
const KNOCKBACK: float = 9.0
const KNOCKBACK_LIFT: float = 2.5


func _init() -> void:
	id = &"susanoo"
	display_name = "Susano'o"
	description = "Lo envuelve el Susano'o: un escudo de %d por %d s, y un espadazo de %d a %.1f m al frente." % [
		int(ESCUDO), int(DURACION), int(DAMAGE), ALCANCE]
	stamina_cost = 34.0
	cooldown = 15.0
	channel_time = 0.3
	icon_color = Color(0.40, 0.52, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var health := caster.get_node_or_null("Health") as Health
	if health != null:
		health.add_shield(ESCUDO, DURACION)
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(caster3d, origin, dir, ALCANCE, ANGULO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.55, 0.65, 1.0, 0.95))
	FX.spawn_susanoo(caster3d, DURACION)
	FX.spawn_slash_arc(caster, origin, dir, Color(0.45, 0.58, 1.0))
