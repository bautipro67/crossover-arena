class_name PortalGun
extends Ability
## Slot 1 de Rick: "PISTOLA DE PORTALES".
##
## Apuntás a cualquier lado del mapa y aparecés ahí. No hay tope de distancia: si lo ves,
## llegás.
##
## POR QUE NO TIENE RANGO. Es lo que se pidió y ademas es lo unico que Rick tiene. Todos
## los demas resuelven la distancia corriendo —Flowery embiste, Dio se tira encima,
## Noelle dispara— y Rick es un viejo flaco que camina mas lento que los tres. Su
## respuesta a la distancia es no recorrerla.
##
## LO QUE LO EQUILIBRA NO ES EL RANGO SINO EL AVISO. El portal de salida se abre ANTES de
## que el cuerpo pase: cualquiera que lo este mirando ve donde va a aparecer y tiene ese
## momento para reaccionar. Un teletransporte instantaneo y silencioso no se puede jugar
## en contra; uno que anuncia el destino, si.

## Cuanto se busca en linea recta antes de darse por vencido. La diagonal del mapa es
## 92 * 1.41 = 130, asi que con 150 se cubre de punta a punta desde cualquier esquina.
const ALCANCE: float = 150.0
## Cuanto se despega de la pared contra la que apuntaste. Sin esto, apuntar a un muro te
## deja con medio cuerpo adentro y la fisica te escupe para cualquier lado.
const DESPEGUE: float = 1.1
## El aviso: el portal de destino se abre y recien despues pasa el cuerpo.
const AVISO: float = 0.35
## Radio libre que necesita el destino para ser valido.
const ESPACIO: float = 0.75
## Cuanto se queda adentro del muro. Sin margen, un portal contra la pared te deja
## rozandola y la fisica te empuja.
const MARGEN_MURO: float = 3.5


func _init() -> void:
	id = &"portal_gun"
	display_name = "Pistola de Portales"
	description = "Abrís un portal donde estés apuntando y aparecés ahí. Sin límite de distancia: todo el mapa."
	stamina_cost = 32.0
	cooldown = 7.0
	channel_time = 0.0
	icon_color = Color(0.45, 0.95, 0.35)


## CORRE EN EL SERVIDOR. Corrutina: abre, avisa, y recien ahi mueve.
func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return

	var destino := calcular_destino(caster3d, origin, dir)
	var salida := caster3d.global_position

	FX.spawn_portal(caster, salida, dir, false)
	FX.spawn_portal(caster, destino, -dir, true)
	Sfx.play_3d(caster, &"portal", salida, -2.0)

	await tree.create_timer(AVISO).timeout
	if not is_instance_valid(caster3d):
		return
	caster3d.call("teleport_to", destino)
	Sfx.play_3d(caster, &"portal", destino, -4.0)
	FX.camera_shake(0.35)


## A donde llega el portal. Publica y estatica para que el arnes pueda medirla sin
## tener que disparar la habilidad entera y esperar el aviso.
##
## Son cuatro pasos y cada uno arregla una forma distinta de terminar adentro de algo:
##
##   1. RAYO: hasta donde llega lo que estas mirando.
##   2. DESPEGUE: un metro para atras, o aparecés dentro de la pared que apuntaste.
##   3. PISO: rayo hacia abajo, porque el punto puede estar en el aire o en lo alto de
##      una cobertura, y ahi hay que pararse ARRIBA, no flotando al lado.
##   4. HUECO LIBRE: find_clear_spot corre el punto si quedo dentro de un bloque.
static func calcular_destino(caster: Node3D, origin: Vector3, dir: Vector3) -> Vector3:
	var plano := dir.normalized()
	if plano.is_zero_approx():
		plano = -caster.global_transform.basis.z
	var espacio := caster.get_world_3d().direct_space_state
	var punto := origin + plano * ALCANCE

	if espacio != null:
		var rayo := PhysicsRayQueryParameters3D.create(origin, punto)
		rayo.collision_mask = GameConfig.LAYER_WORLD
		rayo.exclude = [caster.get_rid()]
		var golpe := espacio.intersect_ray(rayo)
		if not golpe.is_empty():
			punto = golpe["position"] as Vector3
			# Para atras, sobre el mismo rayo: asi el despegue respeta el angulo con el
			# que venias mirando en vez de empujar siempre en la misma direccion.
			punto -= plano * DESPEGUE

		# El piso debajo del punto. Se arranca un metro y medio mas arriba por si el
		# despegue lo dejo apenas hundido en una rampa.
		var desde := punto + Vector3.UP * 1.5
		var suelo := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 60.0)
		suelo.collision_mask = GameConfig.LAYER_WORLD
		suelo.exclude = [caster.get_rid()]
		var piso := espacio.intersect_ray(suelo)
		if not piso.is_empty():
			punto.y = (piso["position"] as Vector3).y + 0.1
		else:
			# Apuntó al cielo: se queda a la altura desde la que disparó.
			punto.y = origin.y - 1.2

	# DENTRO DEL MAPA, SIEMPRE Y ANTES DE BUSCAR HUECO.
	#
	# Es el unico punto del juego que se calcula a 150 metros, asi que es el unico que
	# puede caer fuera de la arena, y confiar en que el que busca el hueco recorte no
	# alcanza: si apuntas al cielo el rayo no pega contra nada y el punto queda a 150
	# metros en linea recta. Se recorta aca, con margen para no quedar pegado al muro.
	var limite := Arena.ARENA_SIZE * 0.5 - MARGEN_MURO
	punto.x = clampf(punto.x, -limite, limite)
	punto.z = clampf(punto.z, -limite, limite)

	# El recorte va ANTES de buscar hueco y no despues.
	#
	# Lo puse tambien despues y fue peor: find_clear_spot corre el punto para sacarlo de
	# una cobertura, y volver a recortarlo lo mete de nuevo adentro. El recorte previo ya
	# alcanza, porque find_clear_spot tambien recorta —incluida su salida de ultimo
	# recurso, que era justamente el agujero por el que uno terminaba fuera del mapa—.
	var arena := caster.get_parent() as Arena
	if arena != null:
		punto = arena.find_clear_spot(punto, ESPACIO)

	# ULTIMO FILTRO: que el punto este REALMENTE libre.
	#
	# find_clear_spot prueba 28 posiciones en espiral y, si ninguna sirve, devuelve la
	# pedida. Eso esta bien para un spawn —siempre hay lugar cerca— pero no para un
	# portal, que puede apuntar al medio de un bloque macizo. Ahi hay que RETROCEDER por
	# el rayo hacia el que dispara: el camino por el que vino la mira es, por definicion,
	# espacio que estaba vacio.
	if espacio != null and _ocupado(espacio, punto):
		for paso: int in range(1, 13):
			var atras := punto - plano * (float(paso) * 1.6)
			atras.y = punto.y
			if not _ocupado(espacio, atras):
				return atras
		# Ni retrocediendo: el portal no te mueve. Mejor que quedar incrustado.
		return caster.global_position
	return punto


## Hay algo solido en ese punto?
static func _ocupado(espacio: PhysicsDirectSpaceState3D, punto: Vector3) -> bool:
	var forma := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = ESPACIO
	forma.shape = esfera
	forma.collision_mask = GameConfig.LAYER_WORLD
	forma.transform = Transform3D(Basis.IDENTITY, punto + Vector3.UP * 1.0)
	return not espacio.intersect_shape(forma, 1).is_empty()
