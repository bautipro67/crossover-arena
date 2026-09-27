class_name RedTotal
extends Ability
## Slot 3 de Spider-Man: "RED TOTAL". Su definitiva.
##
## Salta y dispara telarañas a todos los que tiene alrededor a la vez: los deja pegados al
## piso, casi sin poder moverse, y con un buen golpe de tela encima. Pide linea de vista:
## detras de una cobertura, la tela no llega.

const ALCANCE: float = 16.0
const DAMAGE: float = 30.0
const LENTO: float = 0.8
const LENTO_DURA: float = 2.5


func _init() -> void:
	id = &"red_total"
	display_name = "Red Total"
	description = "Dispara telarañas a todos los que ve a %d m: %d de daño y quedan pegados %.1f s." % [
		int(ALCANCE), int(DAMAGE), LENTO_DURA]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 0.9
	requires_charge = true
	icon_color = Color(0.92, 0.92, 0.95)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster3d.peer_id
	var blancos := alcanzados(caster3d, origin)
	for target: Node3D in blancos:
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null:
			estado.apply_slow(LENTO, LENTO_DURA)
	FX.spawn_red_total(caster3d, blancos)


## Los que alcanza: a menos de ALCANCE y a la vista. La usan el servidor y los clientes.
static func alcanzados(caster: Node3D, origin: Vector3) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for t: Node3D in CombatUtils.get_players_in_sphere(caster, origin, ALCANCE):
		if CombatUtils.has_line_of_sight(caster, origin, t):
			out.append(t)
	return out
