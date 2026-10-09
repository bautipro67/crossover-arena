class_name HojasDelCaos
extends Ability
## Slot 2 de Kratos: "HOJAS DEL CAOS".
##
## Las espadas encadenadas de su pasado en Grecia: las hace girar alrededor, prendidas
## fuego. Tres vueltas que cortan a todos los que estan cerca, y la ultima los tira afuera.

const RADIO: float = 4.4
const VUELTAS: int = 3
const CADA: float = 0.26
const DAMAGE: float = 8.0
const KNOCKBACK_FINAL: float = 8.0


func _init() -> void:
	id = &"hojas_caos"
	display_name = "Hojas del Caos"
	description = "Hace girar las espadas encadenadas: %d vueltas de %d de daño a todos a %.1f m, y la última los tira lejos." % [
		VUELTAS, int(DAMAGE), RADIO]
	stamina_cost = 28.0
	cooldown = 10.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.45, 0.15)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	var tree := caster.get_tree()
	if caster3d == null or tree == null:
		return
	var source_id: int = caster3d.peer_id
	for i: int in range(VUELTAS):
		if i > 0:
			await tree.create_timer(CADA).timeout
		if Ability.interrumpida(caster3d):
			return
		var centro := caster3d.global_position + Vector3.UP
		FX.spawn_hojas_caos(caster3d, RADIO)
		Sfx.play_3d(caster3d, &"cadenas", centro, -2.0)
		var ultima := i == VUELTAS - 1
		for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO):
			CombatUtils.deal_damage(target, DAMAGE, source_id)
			CombatUtils.apply_knockback(target, target.global_position - centro,
				KNOCKBACK_FINAL if ultima else 0.4, 2.0 if ultima else 0.2)
