class_name CienPorCiento
extends Ability
## Slot 3 de Mob: "100%". Su definitiva.
##
## Mob guarda todo lo que siente, y el medidor de la serie cuenta cuanto: cuando llega al
## 100%, lo que venia aguantando sale de una vez. Aca es eso tal cual: se carga a la vista
## —el pelo flota, sube el numero— y revienta en una onda psiquica enorme que manda lejos
## a todos los que tiene cerca. Y despues, unos segundos, sigue al 100%: mas rapido, mas
## resistente y pegando mas fuerte.
##
## El daño de la definitiva no paga recursos: no recarga el medidor ni devuelve stamina.

const RADIO: float = 10.0
const DAMAGE: float = 40.0
const KNOCKBACK: float = 16.0
const KNOCKBACK_LIFT: float = 6.0
## Lo que dura el "100%" despues del estallido.
const DURACION: float = 6.0
const VELOCIDAD: float = 1.2
const RESISTENCIA: float = 0.75
const POTENCIA: float = 1.3


func _init() -> void:
	id = &"cien_por_ciento"
	display_name = "100%"
	description = "Llega al 100%%: una onda psíquica de %d m (%d de daño), y %d s más rápido, más resistente y pegando %d%% más." % [
		int(RADIO), int(DAMAGE), int(DURACION), int(round((POTENCIA - 1.0) * 100.0))]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.2
	requires_charge = true
	icon_color = Color(0.85, 0.92, 1.0)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster.peer_id
	var centro := caster3d.global_position + Vector3.UP
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO):
		# grants_charge = false: un ultimate que pega fuerte no puede recargarse a si mismo.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - caster3d.global_position,
			KNOCKBACK, KNOCKBACK_LIFT)
	var estado := caster.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.impulsar(VELOCIDAD, RESISTENCIA, POTENCIA, DURACION)
	FX.spawn_cien_por_ciento(caster3d, RADIO, DURACION)
