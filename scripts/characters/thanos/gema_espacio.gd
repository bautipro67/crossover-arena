class_name GemaEspacio
extends Ability
## Slot 2 de Thanos: "GEMA DEL ESPACIO". La azul, la del Teseracto.
##
## Thanos la usa para aparecer donde quiere: abre el espacio y cruza. Aca es un salto
## corto a donde apunta —no todo el mapa como el portal de Rick— y al llegar cae con una
## onda que empuja a los que estaban ahi. Es su forma de alcanzar a alguien, porque
## caminando es el mas lento de todos.

const ALCANCE: float = 15.0
const RADIO: float = 3.5
const DAMAGE: float = 14.0
const KNOCKBACK: float = 8.0
const KNOCKBACK_LIFT: float = 2.4
## Lo que tarda en cruzar: el aviso de adonde va a aparecer.
const CRUCE: float = 0.3


func _init() -> void:
	id = &"gema_espacio"
	display_name = "Gema del Espacio"
	description = "Abre el espacio y aparece hasta %d m adelante, con una onda de %d de daño al llegar." % [
		int(ALCANCE), int(DAMAGE)]
	stamina_cost = 26.0
	cooldown = 10.5
	channel_time = 0.0
	icon_color = Color(0.25, 0.50, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null or not caster3d.has_method("teleport_to"):
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var destino := calcular_destino(caster3d, origin, dir)
	FX.spawn_gema_espacio(caster, caster3d.global_position)
	FX.spawn_gema_espacio(caster, destino)
	await tree.create_timer(CRUCE).timeout
	if Ability.interrumpida(caster3d):
		return
	caster3d.call("teleport_to", destino)
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, destino + Vector3.UP, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - destino, KNOCKBACK, KNOCKBACK_LIFT)
	FX.spawn_pisoton(caster3d, destino, RADIO)


## Adonde cae: hasta ALCANCE metros sobre la mira, antes de la primera pared, sobre el piso,
## dentro del mapa y en un hueco libre. La misma cuenta que el portal de Rick, con tope.
static func calcular_destino(caster: Node3D, origin: Vector3, dir: Vector3) -> Vector3:
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = -caster.global_transform.basis.z
	var punto := caster.global_position + plano * ALCANCE
	var mundo := caster.get_world_3d()
	var espacio := mundo.direct_space_state if mundo != null else null
	if espacio != null:
		var desde := caster.global_position + Vector3.UP * 1.0
		var rayo := PhysicsRayQueryParameters3D.create(desde, desde + plano * ALCANCE)
		rayo.collision_mask = GameConfig.LAYER_WORLD
		rayo.exclude = [caster.get_rid()]
		var golpe := espacio.intersect_ray(rayo)
		if not golpe.is_empty():
			punto = (golpe["position"] as Vector3) - plano * 1.1
		var arriba := Vector3(punto.x, caster.global_position.y + 1.5, punto.z)
		var suelo := PhysicsRayQueryParameters3D.create(arriba, arriba + Vector3.DOWN * 40.0)
		suelo.collision_mask = GameConfig.LAYER_WORLD
		suelo.exclude = [caster.get_rid()]
		var piso := espacio.intersect_ray(suelo)
		punto.y = (piso["position"] as Vector3).y + 0.1 if not piso.is_empty() else caster.global_position.y
	var limite := Arena.ARENA_SIZE * 0.5 - PortalGun.MARGEN_MURO
	punto.x = clampf(punto.x, -limite, limite)
	punto.z = clampf(punto.z, -limite, limite)
	var arena := caster.get_parent() as Arena
	if arena != null:
		punto = arena.find_clear_spot(punto, PortalGun.ESPACIO)
	return punto
