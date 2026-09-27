class_name HuesosPiso
extends Ability
## Slot 1 de Sans: "HUESOS DEL PISO".
##
## El ataque que todos recuerdan de su pelea: una fila de huesos que sale del piso hacia
## adelante. Aca es una linea recta en la direccion de la mira; primero se marca en el
## piso y despues salen, y al que agarran lo levantan.

const LARGO: float = 14.0
## Lo ancho de la fila, de cada lado de la linea.
const RADIO: float = 1.2
const DAMAGE: float = 20.0
## Del aviso a los huesos.
const AVISO: float = 0.4
const KNOCKBACK_LIFT: float = 5.0


func _init() -> void:
	id = &"huesos_piso"
	display_name = "Huesos del Piso"
	description = "Una fila de huesos sale del piso hacia adelante, %d m: %d de daño al que agarre." % [
		int(LARGO), int(DAMAGE)]
	stamina_cost = 26.0
	cooldown = 8.0
	channel_time = 0.0
	icon_color = Color(0.85, 0.92, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var rumbo := rumbo_de(caster3d, dir)
	var desde := caster3d.global_position
	FX.spawn_huesos_piso(caster, desde, rumbo, LARGO, AVISO)
	await tree.create_timer(AVISO).timeout
	if Ability.interrumpida(caster3d):
		return
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_line(caster3d, desde + Vector3.UP, rumbo, LARGO, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, rumbo, 1.5, KNOCKBACK_LIFT)


## Hacia donde sale la fila: la mira, pero pegada al piso.
static func rumbo_de(caster: Node3D, dir: Vector3) -> Vector3:
	var plano := Vector3(dir.x, 0.0, dir.z)
	if plano.is_zero_approx():
		plano = -caster.global_transform.basis.z
	return plano.normalized()
