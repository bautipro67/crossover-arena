class_name CombatUtils
extends RefCounted
## Helpers de combate reutilizables por cualquier personaje.
## Todo lo que hay aca corre en el SERVIDOR.


## Devuelve los jugadores vivos dentro de un cono frontal, con linea de vision libre.
## La linea de vision es lo que hace que las coberturas de la arena sirvan de verdad:
## si hay una pared en el medio, Snowgrave no te alcanza.
## OJO: dibuja el volumen si la opcion esta prendida.
##
## Va ACA y no en cada habilidad a proposito. Por estas dos funciones pasa absolutamente
## todo ataque de area del juego, asi que enganchando el dibujo en el consultante, las
## veintitantas habilidades lo heredan sin tocar ninguna — y sobre todo, lo que se dibuja
## es EXACTAMENTE lo que se consulta, no una copia que puede quedar desincronizada.
static func get_players_in_cone(caster: Node3D, origin: Vector3, dir: Vector3, range_m: float, angle_deg: float) -> Array[Node3D]:
	FX.dibujar_cono(caster, origin, dir, range_m, angle_deg)
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


## Idem: dibuja la esfera si la opcion esta prendida.
static func get_players_in_sphere(caster: Node3D, origin: Vector3, radius: float) -> Array[Node3D]:
	FX.dibujar_esfera(caster, origin, radius)
	var out: Array[Node3D] = []
	for target: Node3D in _living_targets(caster):
		if origin.distance_to(target.global_position) <= radius:
			out.append(target)
	return out


## El rival vivo mas cercano dentro de un cono, con linea de vision. Null si no hay.
##
## Para las habilidades que se traban en UNA persona —la teletransportacion de Goku—: el
## cono es el que estas mirando, asi que elegis a quien apuntando, no por descarte.
static func mas_cercano_en_cono(caster: Node3D, origin: Vector3, dir: Vector3,
		alcance: float, angulo: float) -> Node3D:
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster.global_transform.basis.z
	var mejor: Node3D = null
	var mejor_dist := alcance + 1.0
	for t: Node3D in get_players_in_cone(caster, origin, rumbo, alcance, angulo):
		var d := origin.distance_to(t.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = t
	return mejor


## Los jugadores vivos a lo largo de un rayo recto: un cilindro de `radio` desde `origin`
## hasta `largo` metros en `dir`. Dibuja el volumen si la opcion esta prendida.
##
## NO CHEQUEA PAREDES POR SI MISMA: el que llama ya corta el largo donde el rayo pega
## contra el mundo, que es lo que hace el Kamehameha. Asi el rayo atraviesa gente —como
## en la serie— pero no paredes.
##
## La distancia se mide al CENTRO DEL PECHO (un metro arriba de los pies), no a los pies:
## un rayo a la altura del pecho que pasa rozando la cabeza de alguien bajo como Sonic no
## lo tiene que errar por medir contra el piso.
static func get_players_in_line(caster: Node3D, origin: Vector3, dir: Vector3,
		largo: float, radio: float) -> Array[Node3D]:
	FX.dibujar_rayo(caster, origin, dir, largo, radio)
	var out: Array[Node3D] = []
	if not is_instance_valid(caster):
		return out
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return out
	for target: Node3D in _living_targets(caster):
		var pecho := target.global_position + Vector3.UP * 1.0
		var t := (pecho - origin).dot(rumbo)
		if t < 0.0 or t > largo:
			continue
		var cercano := origin + rumbo * t
		if cercano.distance_to(pecho) <= radio:
			out.append(target)
	return out


## Pelean del mismo lado? Solo si los dos tienen equipo y es el mismo.
##
## Sin equipo (-1) nadie es aliado de nadie, que es el todos contra todos de siempre: por
## eso esto no cambia nada fuera del modo historia.
static func son_aliados(a: Node, b: Node) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b) or a == b:
		return false
	var ea: int = int(a.get("equipo")) if a.get("equipo") != null else -1
	var eb: int = int(b.get("equipo")) if b.get("equipo") != null else -1
	return ea >= 0 and ea == eb


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
		# Y encima de eso, lo que diga el panel de practica. En 0 los bots siguen
		# atacando y animando igual pero no sacan vida: es el modo para ensayar esquives
		# sin morirse cada diez segundos.
		# LO DECIDE EL MODO, no una constante sola para todo el juego.
		#
		# 0.45 era el numero de la practica, donde los bots tienen que pegar flojo para
		# poder ensayar sin morirse. En un duelo eso convierte al rival en un muñeco, y en
		# supervivencia hace que la oleada 9 pegue igual que la 1.
		mult *= Modos.daño_bot(source_id) * Practica.daño_bots
	# Y lo que multiplique EL QUE PEGA. Hoy solo lo mueve Super Sonic, que canonicamente
	# hace que "todas sus habilidades superen ampliamente a las normales". Se busca al
	# atacante igual que unas lineas mas abajo para los recursos, asi que no agrega una
	# busqueda que no estuviera pasando ya.
	var atacante := find_player_by_peer(target, source_id)
	# UN ALIADO NO SE PEGA, venga el golpe por donde venga. Las consultas de area ya los
	# dejan afuera, pero esto es la ultima puerta: cualquier habilidad que llegue aca con un
	# blanco de su propio equipo —una nueva, o una que busque blancos a su manera— no le
	# saca vida a nadie de su lado.
	if atacante != null and son_aliados(atacante, target):
		return 0.0
	if atacante != null:
		var est := atacante.get_node_or_null("StatusEffects") as StatusEffects
		if est != null:
			mult *= est.get_damage_dealt_multiplier()
	var final_amount := amount * mult
	var was_alive := not health.is_dead
	var vida_antes := health.current
	health.apply_damage(final_amount, source_id)

	# EL TAMBALEO DEL COMBO, en el unico camino por el que pasa todo el daño del juego: asi
	# lo heredan las treinta y pico habilidades sin tocar ninguna.
	#
	# Solo si el golpe LLEGO A LA VIDA. Un golpe que se come entero el escudo de hielo no
	# pego, y no puede trabar a nadie: el escudo existe justamente para cortar combos.
	if status != null and (health.current < vida_antes or (was_alive and health.is_dead)):
		status.tambalear(StatusEffects.TAMBALEO)

	# LOS RECURSOS SE PAGAN SOBRE EL DAÑO SIN LA REBAJA DE LOS BOTS.
	#
	# Un bot pega a un tercio, y si ademas cargara el medidor con ese tercio tardaria el
	# TRIPLE que una persona en juntar su ultimate. Medido: en 26 segundos de pelea los
	# tres bots juntos no llegaban ni a la mitad del medidor, o sea que habilitarles el
	# ultimate no servia de nada porque no lo tiraban nunca.
	#
	# Esa lentitud no es una decision de diseño, es un efecto secundario de la rebaja de
	# daño del modo practica. Cobrando los recursos sobre el golpe sin rebajar, el bot
	# junta su ultimate al mismo ritmo que lo juntaria un rival de verdad —que es contra
	# lo que uno quiere practicar— y sigue pegando flojo.
	var para_recursos := amount * (mult / maxf(0.01, Modos.daño_bot(source_id) * Practica.daño_bots)) if source_id < 0 else final_amount

	if feeds_resources:
		var attacker := find_player_by_peer(target, source_id)
		if attacker != null:
			var charge := attacker.get_node_or_null("UltimateCharge") as UltimateCharge
			if charge != null:
				charge.add_from_damage(para_recursos)
				if was_alive and health.is_dead:
					charge.add_kill_bonus()
			# Y le devuelve stamina. La regeneracion pasiva es lenta a proposito: esta
			# es la via rapida, y solo la cobra el que se anima a entrar a pegar.
			var stam := attacker.get_node_or_null("Stamina") as Stamina
			if stam != null:
				stam.restore_from_damage(para_recursos)

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
		# Los del mismo lado no son blanco: un aliado no te puede pegar ni vos a el.
		if son_aliados(caster, node):
			continue
		var n3d := node as Node3D
		if n3d == null:
			continue
		var health := node.get_node_or_null("Health") as Health
		if health == null or health.is_dead:
			continue
		out.append(n3d)
	return out
