class_name FuegoInfernal
extends Ability
## Slot 2 de Scorpion: "FUEGO DEL INFIERNO" (Hellfire).
##
## En Mortal Kombat X y 11 Scorpion golpea el piso y abajo del rival se abre el fuego del
## Inframundo: una columna de llamas que lo levanta. Aca igual: cae sobre el primer rival
## de la mira —o donde termina la mira, si no hay nadie— despues de un aviso en el piso.
##
## EL AVISO ES CORTO pero se ve: el circulo de brasas aparece bajo los pies apenas sale.
## Combina con la lanza: el que se trajo queda justo adelante, donde es facil apuntarle.

const ALCANCE: float = 20.0
## Lo ancho de la mira para encontrar a quien caerle.
const RADIO_MIRA: float = 2.2
const RADIO: float = 3.0
const DAMAGE: float = 24.0
## Del aviso a la columna.
const AVISO: float = 0.55
const KNOCKBACK: float = 2.0
const KNOCKBACK_LIFT: float = 7.5


func _init() -> void:
	id = &"fuego_infernal"
	display_name = "Fuego del Infierno"
	description = "Abre el Inframundo bajo el rival que apuntás: una columna de fuego de %d de daño que lo levanta." % int(DAMAGE)
	stamina_cost = 30.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.42, 0.10)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var punto := donde(caster3d, origin, dir)
	FX.spawn_fuego_infernal(caster, punto, RADIO, AVISO)
	await tree.create_timer(AVISO).timeout
	if Ability.interrumpida(caster3d):
		return
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, punto + Vector3.UP, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - punto, KNOCKBACK, KNOCKBACK_LIFT)


## Donde sale: el primer rival sobre la mira, o la pared o el piso donde termina. Siempre
## apoyado en el piso. La usan el servidor y los clientes: es la misma cuenta en los dos.
static func donde(caster: Node3D, origin: Vector3, dir: Vector3) -> Vector3:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster.global_transform.basis.z
	var punto := origin + rumbo * ALCANCE
	var mas_cerca := INF
	for t: Node3D in CombatUtils.get_players_in_line(caster, origin, rumbo, ALCANCE, RADIO_MIRA):
		var d := origin.distance_to(t.global_position)
		if d < mas_cerca:
			mas_cerca = d
			punto = t.global_position
	var mundo := caster.get_world_3d()
	var espacio := mundo.direct_space_state if mundo != null else null
	if espacio == null:
		return punto
	if is_inf(mas_cerca):
		var rayo := PhysicsRayQueryParameters3D.create(origin, origin + rumbo * ALCANCE)
		rayo.collision_mask = GameConfig.LAYER_WORLD
		rayo.exclude = [caster.get_rid()]
		var golpe := espacio.intersect_ray(rayo)
		if not golpe.is_empty():
			punto = (golpe["position"] as Vector3) - rumbo * 0.5
	var abajo := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 3.0, punto + Vector3.DOWN * 60.0)
	abajo.collision_mask = GameConfig.LAYER_WORLD
	var piso := espacio.intersect_ray(abajo)
	if not piso.is_empty():
		punto = piso["position"]
	return punto
