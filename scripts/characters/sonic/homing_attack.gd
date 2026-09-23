class_name HomingAttack
extends Ability
## Slot 2 de Sonic: "HOMING ATTACK".
##
## Se traba en un rival y se lanza contra el enrollado en bola.
##
## ES SU MOVIMIENTO MAS RECONOCIBLE de la era 3D, y es el unico del juego que no hay que
## apuntar con precision: busca solo. Eso no lo hace un boton gratis — lo que pide es
## ELEGIR BIEN A QUIEN, porque te deja pegado al que atacaste y sin nada para salir hasta
## que vuelva el cooldown.
##
## SIN BLANCO NO SALE, y devuelve la stamina. Un homing al vacio seria un dash comun con
## otro nombre, y ademas dejaria a Sonic volando hacia la nada por haberse equivocado de
## momento. Que no salga es informacion: no habia nadie a tiro.

const DAMAGE: float = 26.0
## Hasta donde busca. Generoso a proposito: es una herramienta para cerrar distancia.
const ALCANCE: float = 18.0
## Cuan al frente tiene que estar. No es 360: se traba en lo que estas mirando.
const ANGULO: float = 100.0
const VELOCIDAD: float = 34.0
const KNOCKBACK: float = 6.5
const KNOCKBACK_LIFT: float = 3.4
## Donde frena respecto del rival, para no quedar adentro suyo.
const FRENO: float = 1.5

# ------------------------------------------------------------------ El encadenado
#
# ACERTAR DEVUELVE CASI TODO EL COOLDOWN, y eso no es un numero de balance: es LA
# sensacion del personaje. En sus juegos el homing rebota de un enemigo al siguiente sin
# tocar el piso, y una version donde pegas una vez y esperas cinco segundos tiene el
# nombre del movimiento pero ninguna de sus propiedades.
#
# Lo que lo mantiene honesto es que la cadena se paga con STAMINA, no con cooldown: cada
# salto cuesta lo mismo que el primero, asi que encadenar cuatro veces te deja sin barra y
# sin nada para salir. La habilidad no se vuelve gratis, se vuelve RAPIDA, que es otra
# cosa: premia acertar seguido y castiga igual de fuerte errar en el medio.
const COOLDOWN_AL_ACERTAR: float = 0.45
## Cuantos saltos seguidos antes de que el cooldown vuelva a ser el entero. Sin tope, con
## suficiente stamina se cruza el mapa entero rebotando y nadie lo puede tocar.
const CADENA_MAXIMA: int = 4
## Cuanto dura la ventana de la cadena. Si te tomas mas tiempo, es un ataque nuevo.
const VENTANA_CADENA: float = 2.2


func _init() -> void:
	id = &"homing_attack"
	display_name = "Homing Attack"
	description = "Se traba en el rival más cercano y se lanza (%d). Si acertás, vuelve casi al instante: encadena hasta %d veces." % [
		int(DAMAGE), CADENA_MAXIMA]
	stamina_cost = 22.0
	cooldown = 5.0
	channel_time = 0.0
	icon_color = Color(0.55, 0.85, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return

	var blanco := _mejor_blanco(caster3d, origin, dir)
	if blanco == null:
		# Sin blanco no se gasta nada. Devolver la stamina es lo unico honesto: la
		# habilidad no paso, y cobrarla igual castiga por no tener a nadie cerca.
		var st := caster.get_node_or_null("Stamina") as Stamina
		if st != null:
			st.devolver(stamina_cost)
		Sfx.play_2d(&"no_stamina", -8.0)
		return

	FX.spawn_homing_lock(caster, blanco.global_position)
	Sfx.play_3d(caster, &"dash", origin, -2.0)

	# El vuelo: se persigue al blanco frame a frame, que es lo que lo hace "homing". Con
	# una direccion fija calculada al salir, cualquiera lo esquiva caminando de costado.
	var recorrido := 0.0
	while recorrido < ALCANCE * 1.6:
		await tree.physics_frame
		if not is_instance_valid(caster3d) or not is_instance_valid(blanco):
			return
		if blanco.health.is_dead:
			break
		var hacia: Vector3 = blanco.global_position - caster3d.global_position
		var falta := hacia.length()
		if falta <= FRENO:
			break
		# SE REAPUNTA EN CADA FRAME, y eso es lo que lo hace "homing".
		#
		# Se reusa launch_charge —el mismo empujon que usan los otros dashes— pidiendolo de
		# a tramos cortos en vez de uno largo: cada llamada reemplaza la direccion, asi que
		# pedirlo seguido es perseguir. Con una sola llamada al salir, la direccion queda
		# fija y el rival lo esquiva caminando de costado.
		recorrido += VELOCIDAD * 0.05
		caster3d.call("launch_charge", hacia.normalized(), VELOCIDAD, 0.08)
		FX.spawn_dash_streak(caster, caster3d.global_position, hacia.normalized(),
			Color(0.4, 0.7, 1.0, 0.6))

	if not is_instance_valid(caster3d) or not is_instance_valid(blanco):
		return
	if caster3d.global_position.distance_to(blanco.global_position) > FRENO * 2.6:
		return

	var source_id: int = caster.peer_id
	var empuje: Vector3 = blanco.global_position - caster3d.global_position
	CombatUtils.deal_damage(blanco, DAMAGE, source_id)
	_premiar_cadena(caster)
	CombatUtils.apply_knockback(blanco, empuje, KNOCKBACK, KNOCKBACK_LIFT)
	# Y REBOTA HACIA ATRAS, como en los juegos: pegar te separa. Sin el rebote, el homing
	# te deja pegado al rival y se vuelve un boton de "estoy encima tuyo gratis".
	CombatUtils.apply_knockback(caster3d, -empuje, KNOCKBACK * 0.55, 3.0)
	FX.spawn_impact_burst(caster, blanco.global_position + Vector3.UP, Color(0.6, 0.9, 1.0, 1.0))
	FX.camera_shake(1.1)


## Acorta el cooldown tras acertar, hasta el tope de la cadena.
##
## El contador vive en el propio caster con set_meta y no en esta clase: la instancia de
## la habilidad es COMPARTIDA —CharacterDB la construye una vez— asi que un contador aca
## seria el mismo para todos los Sonic de la partida, y la cadena de uno cortaria la del
## otro.
func _premiar_cadena(caster: Node) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	var ultimo := float(caster.get_meta(&"homing_ultimo", -99.0))
	var cuantos := int(caster.get_meta(&"homing_cadena", 0))
	if ahora - ultimo > VENTANA_CADENA:
		cuantos = 0
	cuantos += 1
	caster.set_meta(&"homing_ultimo", ahora)
	caster.set_meta(&"homing_cadena", cuantos)
	if cuantos > CADENA_MAXIMA:
		return
	var caster_node := caster.get_node_or_null("AbilityCaster") as AbilityCaster
	if caster_node != null:
		caster_node.acortar_cooldown(2, COOLDOWN_AL_ACERTAR)
		FX.spawn_homing_lock(caster, (caster as Node3D).global_position)


## El rival mas cercano dentro del cono del frente. Null si no hay ninguno.
static func _mejor_blanco(caster: Node3D, origin: Vector3, dir: Vector3) -> Node3D:
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster.global_transform.basis.z
	var mejor: Node3D = null
	var mejor_dist := ALCANCE + 1.0
	for t: Node3D in CombatUtils.get_players_in_cone(caster, origin, rumbo, ALCANCE, ANGULO):
		var d := origin.distance_to(t.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = t
	return mejor
