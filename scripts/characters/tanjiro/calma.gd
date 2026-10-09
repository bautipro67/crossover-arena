class_name Calma
extends Ability
## Slot 2 de Tanjiro: "RESPIRACION DEL AGUA, UNDECIMA FORMA: CALMA" (Nagi).
##
## La forma que invento Giyu: el agua se queda quieta, y todo lo que entra en el alcance de
## la espada se corta. Aca: por un momento NO LO TOCA NADA (StatusEffects.estrella), y cada
## tanto corta a los que estan cerca. Es su forma de aguantar una rafaga o una definitiva
## parado en el lugar.

const DURACION: float = 1.2
const RADIO: float = 3.2
const DAMAGE: float = 6.0
const CADA: float = 0.3


func _init() -> void:
	id = &"calma"
	display_name = "Calma"
	description = "Por %.1f s nada lo toca, y corta a todos los que se acercan a %.1f m (%d cada %.1f s)." % [
		DURACION, RADIO, int(DAMAGE), CADA]
	stamina_cost = 26.0
	cooldown = 11.0
	channel_time = 0.0
	icon_color = Color(0.70, 0.88, 1.0)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	var tree := caster.get_tree()
	if caster3d == null or tree == null:
		return
	var estado := caster3d.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.estrella(DURACION)
	FX.spawn_calma(caster3d, RADIO, DURACION)
	var source_id: int = caster3d.peer_id
	var ticks := int(DURACION / CADA)
	for i: int in range(ticks):
		await tree.create_timer(CADA).timeout
		if Ability.interrumpida(caster3d):
			return
		var centro := caster3d.global_position + Vector3.UP
		for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO):
			CombatUtils.deal_damage(target, DAMAGE, source_id)
			FX.spawn_slash_arc(caster3d, centro, target.global_position - centro, CorteTanjiro.AGUA)
