class_name SuperSalto
extends Ability
## Slot 2 de Mario: "SUPER SALTO". Salta alto y cae con un pisoton que aplasta alrededor.
##
## El salto es lo primero que se sabe de Mario —se llamo Jumpman antes de llamarse Mario—
## y el pisoton es como les gana a casi todos sus enemigos: cayendoles encima. Aca el
## pisoton pega en redondo al aterrizar, asi que sirve para meterse en el medio de varios
## y para zafar de uno que lo tenia encerrado: mientras sube no lo alcanza nadie a pie.
##
## EL SALTO LO HACE EL MISMO EMPUJON QUE LOS GOLPES (Player.apply_knockback), que ya viaja
## por la red al dueño del cuerpo. No pasa por CombatUtils.apply_knockback, y a proposito:
## ese camino lo frena la Superestrella, y con la estrella puesta Mario tiene que poder
## seguir saltando.

const IMPULSO_ARRIBA: float = 11.0
const IMPULSO_ADELANTE: float = 6.0
const RADIO: float = 4.0
const DAMAGE: float = 30.0
const KNOCKBACK: float = 8.0
const KNOCKBACK_LIFT: float = 3.5
## Lo minimo en el aire antes de contar el aterrizaje (recien salido, todavia esta en el
## piso), y lo maximo que se lo espera: con la gravedad del juego el salto dura 1.2 s.
const MINIMO_EN_EL_AIRE: float = 0.3
const MAXIMO_EN_EL_AIRE: float = 1.8


func _init() -> void:
	id = &"super_salto"
	display_name = "Súper Salto"
	description = "Salta bien alto y cae con un pisotón: %d de daño a todos a %.1f m." % [
		int(DAMAGE), RADIO]
	stamina_cost = 26.0
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(0.95, 0.30, 0.25)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null or not caster3d.has_method("apply_knockback"):
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	caster3d.call("apply_knockback", plano * IMPULSO_ADELANTE + Vector3.UP * IMPULSO_ARRIBA)
	Sfx.play_3d(caster, &"salto", caster3d.global_position, 2.0)
	FX.spawn_impact_burst(caster, caster3d.global_position + Vector3.UP * 0.2, Color(0.95, 0.92, 0.85, 0.8))

	var t := 0.0
	while t < MAXIMO_EN_EL_AIRE:
		await tree.physics_frame
		t += caster3d.get_physics_process_delta_time()
		if Ability.interrumpida(caster3d):
			return
		var health := caster.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			return
		if t >= MINIMO_EN_EL_AIRE and _en_el_piso(caster3d):
			break

	# EL PISOTON, donde cayo.
	var punto := caster3d.global_position
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, punto + Vector3.UP * 0.5, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - punto, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.85, 0.35, 0.95))
	FX.spawn_pisoton(caster3d, punto, RADIO)
	FX.camera_shake(1.2)
	Sfx.play_3d(caster, &"aterrizaje", punto, 4.0)


## Tiene piso a menos de un palmo. Con un rayo y no con is_on_floor(): en el servidor, el
## cuerpo de un jugador remoto sigue la posicion que llega por la red y no corre su propia
## fisica, asi que is_on_floor() ahi no dice nada.
static func _en_el_piso(cuerpo: Node3D) -> bool:
	var espacio := cuerpo.get_world_3d().direct_space_state
	if espacio == null:
		return true
	var desde := cuerpo.global_position + Vector3.UP * 0.15
	var rayo := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 0.4)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	return not espacio.intersect_ray(rayo).is_empty()
