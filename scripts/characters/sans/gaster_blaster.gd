class_name GasterBlaster
extends Ability
## Slot 3 de Sans: "GASTER BLASTER". Su definitiva.
##
## Las calaveras de dragon que aparecen alrededor de Sans y disparan. Aca son tres: una a
## cada lado y una arriba, y las tres apuntan al MISMO punto adelante. El que queda donde
## se cruzan se come los tres rayos; el que se corre, uno o ninguno.
##
## SE VE VENIR: las calaveras aparecen durante la carga, mirando a donde van a tirar.

## Donde se cruzan los rayos, adelante de Sans.
const CRUCE: float = 12.0
const LARGO: float = 30.0
const RADIO: float = 1.1
## Por rayo. El que esta en el cruce se come los tres.
const DAMAGE: float = 24.0
const KNOCKBACK: float = 5.0


func _init() -> void:
	id = &"gaster_blaster"
	display_name = "Gaster Blaster"
	description = "Tres calaveras de dragón disparan al mismo punto: %d de daño por rayo, y donde se cruzan pegan los tres." % int(DAMAGE)
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.0
	requires_charge = true
	icon_color = Color(0.85, 0.95, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster3d.peer_id
	var rayos := rayos_de(caster3d, dir)
	var cuantos: Dictionary = {}
	for r: Array in rayos:
		for t: Node3D in CombatUtils.get_players_in_line(caster3d, r[0], r[1], LARGO, RADIO):
			cuantos[t] = int(cuantos.get(t, 0)) + 1
	for t: Node3D in cuantos:
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(t, DAMAGE * float(cuantos[t]), source_id, false)
		CombatUtils.apply_knockback(t, t.global_position - caster3d.global_position, KNOCKBACK, 1.5)
	FX.spawn_gaster_blaster(caster, rayos, LARGO)


## Los tres rayos: [desde, rumbo]. Desde los costados y desde arriba de Sans, hacia el cruce.
## La usan el servidor y los clientes.
static func rayos_de(caster: Node3D, dir: Vector3) -> Array:
	var plano := Vector3(dir.x, 0.0, dir.z)
	if plano.is_zero_approx():
		plano = -caster.global_transform.basis.z
	plano = plano.normalized()
	var costado := plano.cross(Vector3.UP).normalized()
	var base := caster.global_position + Vector3.UP * 1.2
	var cruce := base + plano * CRUCE
	var out: Array = []
	for desde: Vector3 in [base + costado * 2.4 + Vector3.UP * 0.6, base - costado * 2.4 + Vector3.UP * 0.6,
			base + Vector3.UP * 2.4 - plano * 0.8]:
		out.append([desde, (cruce - desde).normalized()])
	return out
