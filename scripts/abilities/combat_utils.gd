class_name CombatUtils
extends RefCounted
## Helpers de combate reutilizables por cualquier personaje.
## Todo lo que hay aca corre en el SERVIDOR.


## Devuelve los jugadores vivos dentro de un cono frontal, con linea de vision libre.
## La linea de vision es lo que hace que las coberturas de la arena sirvan de verdad:
## si hay una pared en el medio, Snowgrave no te alcanza.
static func get_players_in_cone(caster: Node3D, origin: Vector3, dir: Vector3, range_m: float, angle_deg: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_instance_valid(caster):
		return out
	var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	if flat_dir.is_zero_approx():
		return out
	var cos_limit := cos(deg_to_rad(angle_deg * 0.5))

	for target: Node3D in _living_targets(caster):
		var to_target := target.global_position - origin
		var dist := to_target.length()
		if dist > range_m or dist < 0.01:
			continue
		var flat_to := Vector3(to_target.x, 0.0, to_target.z).normalized()
		if flat_to.dot(flat_dir) < cos_limit:
			continue
		if not has_line_of_sight(caster, origin, target):
			continue
		out.append(target)
	return out


static func get_players_in_sphere(caster: Node3D, origin: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for target: Node3D in _living_targets(caster):
		if origin.distance_to(target.global_position) <= radius:
			out.append(target)
	return out


## Raycast contra el mundo solido. Ignora jugadores y proyectiles.
static func has_line_of_sight(from_node: Node3D, origin: Vector3, target: Node3D) -> bool:
	var world := from_node.get_world_3d()
	if world == null:
		return true
	var space := world.direct_space_state
	if space == null:
		return true
	# Apuntamos al torso, no a los pies, para no chocar contra el propio piso.
	var to := target.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collision_mask = GameConfig.LAYER_WORLD
	query.hit_from_inside = false
	var hit := space.intersect_ray(query)
	return hit.is_empty()


## Aplica daño pasando por los multiplicadores de status del objetivo.
## Es el unico camino que deberian usar las habilidades para dañar.
##
## PEGAR PAGA DOS RECURSOS: carga de ultimate y stamina. Los dos salen de aca, y por eso
## toda habilidad que dañe TIENE que pasar por esta funcion: la que dañe por otro camino
## no recompensa nada y el jugador no entiende por que.
##
## feeds_resources = false para el daño DE LOS ULTIMATES. Sin eso un Snowgrave de 260
## carga el medidor entero Y devuelve la barra de stamina completa, o sea que el ultimate
## se paga el siguiente solo: justo lo que estos dos recursos existen para evitar.
static func deal_damage(target: Node, amount: float, source_id: int, feeds_resources: bool = true) -> float:
	if not is_instance_valid(target) or amount <= 0.0:
		return 0.0
	var health := target.get_node_or_null("Health") as Health
	if health == null or health.is_dead:
		return 0.0
	var mult := 1.0
	var status := target.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		mult = status.get_damage_taken_multiplier()
	# Los bots de practica pegan mas flojo. Se los reconoce por el peer negativo.
	if source_id < 0:
		mult *= GameConfig.BOT_DAMAGE_SCALE
	var final_amount := amount * mult
	var was_alive := not health.is_dead
	health.apply_damage(final_amount, source_id)

	if feeds_resources:
		var attacker := find_player_by_peer(target, source_id)
		if attacker != null:
			var charge := attacker.get_node_or_null("UltimateCharge") as UltimateCharge
			if charge != null:
				charge.add_from_damage(final_amount)
				if was_alive and health.is_dead:
					charge.add_kill_bonus()
			# Y le devuelve stamina. La regeneracion pasiva es lenta a proposito: esta
			# es la via rapida, y solo la cobra el que se anima a entrar a pegar.
			var stam := attacker.get_node_or_null("Stamina") as Stamina
			if stam != null:
				stam.restore_from_damage(final_amount)

	return final_amount


## Busca un jugador por su peer id. `context` solo se usa para llegar al arbol.
static func find_player_by_peer(context: Node, peer_id: int) -> Node:
	if not is_instance_valid(context):
		return null
	var tree := context.get_tree()
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group("players"):
		if is_instance_valid(node) and node.get("peer_id") == peer_id:
			return node
	return null


## Empuja al objetivo. force es el componente horizontal, lift el vertical.
##
## El lift importa mas de lo que parece: un empujon puramente horizontal se lee como
## un resbalon, y uno que despega un poco del piso se lee como un golpe.
static func apply_knockback(target: Node, direction: Vector3, force: float, lift: float = 0.0) -> void:
	if not is_instance_valid(target) or force <= 0.0:
		return
	if not target.has_method("apply_knockback"):
		return
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat.is_zero_approx():
		return
	target.apply_knockback(flat * force + Vector3.UP * lift)


static func apply_chill(target: Node, stacks: int) -> void:
	if not is_instance_valid(target):
		return
	var status := target.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		status.add_chill(stacks)


static func is_frozen(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	var status := target.get_node_or_null("StatusEffects") as StatusEffects
	return status != null and status.is_frozen()


## Jugadores vivos distintos del caster.
static func _living_targets(caster: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var tree := caster.get_tree()
	if tree == null:
		return out
	for node: Node in tree.get_nodes_in_group("players"):
		if node == caster or not is_instance_valid(node):
			continue
		var n3d := node as Node3D
		if n3d == null:
			continue
		var health := node.get_node_or_null("Health") as Health
		if health == null or health.is_dead:
			continue
		out.append(n3d)
	return out
