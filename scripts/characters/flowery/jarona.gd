class_name Jarona
extends Ability
## Slot 1 de Flowery: "JARONA".
##
## LA EMBESTIDA DE SU PELEA DE JEFE, tal como funciona en el original: grita "Jarona",
## destella en blanco y se tira de frente. Es un ataque "clashable" — cuando conecta,
## sale rebotado hacia atras, y vuelve a venir.
##
## Aca eso es el bucle entero:
##
##     embiste -> pega -> REBOTA para atras -> vuelve a embestir -> ...
##
## y se corta cuando una pasada no toca a nadie. O sea que el largo del ataque lo decide
## el rival: si te quedas parado en el camino, Flowery te pasa por encima cuatro veces;
## si te corres, la primera pasada al aire lo deja plantado.
##
## Eso es lo que lo hace distinto de cualquier otro golpe del juego: es el unico cuya
## duracion depende de que tan bien lo esquiven.
##
## Cada pasada tiene su propio registro de golpeados, asi que volver a pasarte por
## encima SI vuelve a pegar. El registro por pasada existe para que un solo viaje no te
## cobre cuatro ticks mientras te atraviesa.

const DAMAGE: float = 22.0
## CADA PASADA PEGA MENOS QUE LA ANTERIOR, y esto es lo que la hace jugable.
##
## El problema medido: con daño plano, un rival que no puede salirse del camino —contra
## una pared, o simplemente sin reflejos— comia las diez pasadas enteras. Son 210 de
## daño y un jugador tiene 100. No era fuerte, era un boton de matar.
##
## La alternativa obvia era volver a ponerle un tope de pasadas, y eso ya lo probamos y
## esta mal: convierte "embiste hasta que lo esquives" en "embiste cuatro veces". El
## decaimiento arregla el numero SIN tocar la mecanica: sigue rebotando y volviendo
## mientras siga pegando, y sigue siendo el rival el que decide cuando se termina.
##
## Ademas se lee mejor. El embiste que importa es el primero —el que te agarra
## desprevenido— y los rebotes posteriores son vos siendo arrastrado, no doce embestidas
## igual de fuertes. El numero flotante bajando pasada a pasada cuenta esa historia sola.
const DECAIMIENTO: float = 0.66
## Piso, para que las ultimas pasadas no tiren numeros ridiculos de 0.4 en pantalla.
const DAMAGE_MINIMO: float = 4.0
const SPEED: float = 30.0
## Cuanto dura una ida. A 30 m/s son unos nueve metros.
const PASS_TIME: float = 0.30
## El rebote: mas corto y mas lento que la ida. Es un retroceso, no otra embestida.
const BOUNCE_SPEED: float = 17.0
const BOUNCE_TIME: float = 0.16
const HIT_RADIUS: float = 2.2
const KNOCKBACK: float = 7.0
const KNOCKBACK_LIFT: float = 1.5
## SE REPITE HASTA QUE UNA PASADA FALLE. Esto es un tope de seguridad, no la regla.
##
## Estuvo en 4 y eso estaba mal: convertia la habilidad en "cuatro embestidas" cuando lo
## que tiene que ser es "embiste hasta que lo esquives". Quien decide cuanto dura el
## ataque es el rival, no un numero. El tope solo existe para que un caso raro —alguien
## acorralado contra una pared, sin lugar para salir del camino— no deje al jugador sin
## control para siempre.
const MAX_PASSES: int = 10
## Pausa entre el rebote y la siguiente embestida: LA VENTANA PARA ESQUIVAR.
##
## Subio de 0.12 a 0.32 cuando la habilidad paso a repetirse hasta fallar, y es lo que
## hace que ese cambio no la vuelva una sentencia de muerte. Medido: contra un blanco que
## no se mueve son 210 de daño, y un jugador tiene 100. Con 0.12 no habia forma humana de
## salirse del camino entre pasada y pasada, asi que "hasta que no le de a nada" queria
## decir "hasta que se acabe el tope".
##
## Con 0.32, sumados a los 0.16 del rebote, hay medio segundo para moverse de costado:
## caminando son unos 3 metros y el radio de impacto es 2.2, o sea que salirse ALCANZA.
## Sigue siendo "hasta que falle"; lo que cambia es que fallar ahora es posible.
const REGROUP: float = 0.32
## El rastro que deja la embestida. Sin el, una pasada de tres decimas no se ve:
## el destello del arranque ya se apago cuando el cuerpo va por la mitad.
const ESTELA: Color = Color(1.0, 0.45, 0.40)


func _init() -> void:
	id = &"jarona"
	display_name = "JARONA"
	description = "Embiste. Cada vez que pega rebota y vuelve, UNA Y OTRA VEZ, hasta que falle una pasada. %d la primera y menos cada rebote. CORTA canalizados." % int(DAMAGE)
	stamina_cost = 28.0
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.36, 0.34)


## CORRE EN EL SERVIDOR. Corrutina: acompaña todas las pasadas.
func execute(caster: Node, _origin: Vector3, dir: Vector3) -> void:
	# Cero fallos tolerados: la PRIMERA pasada al aire la termina. Eso es lo que hace que
	# la duracion la decida el rival.
	await correr_embestida(caster, dir, MAX_PASSES, DAMAGE, Callable(), 0, ESTELA, DECAIMIENTO)


## El bucle de embestidas. Lo comparte con LAST JARONA, que es la version larga.
##
## `estallido` —si viene— se llama en cada rebote con (caster, punto). Es lo que deja
## LAST JARONA detras suyo. Es un Callable y no un bool porque el ultimate necesita que
## la explosion HAGA DAÑO, no solo que se vea.
##
## `fallos_tolerados` es lo que separa a las dos versiones. JARONA va con 0: la primera
## pasada al aire la corta. LAST JARONA va con varios: te sigue viniendo aunque la
## esquives, y por eso dura mas.
## `decaimiento` multiplica el daño en cada pasada. En 1.0 todas pegan igual (asi va el
## ultimate); por debajo, cada rebote pega menos que el anterior.
static func correr_embestida(caster: Node, dir: Vector3, tope: int, damage: float,
		estallido: Callable, fallos_tolerados: int, estela: Color = ESTELA,
		decaimiento: float = 1.0) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var source_id: int = caster.peer_id

	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z

	var fallos := 0
	var golpe := damage
	for pasada: int in range(tope):
		if not is_instance_valid(caster3d):
			return

		# El destello blanco ANTES de cada embestida, como en el original. No es adorno:
		# es el aviso que hace que la embestida se pueda esquivar.
		FX.spawn_jarona_flash(caster3d)
		Sfx.play_3d(caster, &"jarona", caster3d.global_position, -2.0)

		var golpeados: Dictionary = {}
		var tocados := await FloweryDash.pasada(
			caster3d, rumbo, SPEED, PASS_TIME, HIT_RADIUS, golpeados, false, estela)
		if not is_instance_valid(caster3d):
			return

		if tocados.is_empty():
			# Pasada al aire. Esta es la salida del bucle y la razon por la que el ataque
			# no es un boton de daño garantizado: con 0 fallos tolerados, esquivar una
			# vez lo termina.
			fallos += 1
			FloweryDash.frenar(caster3d)
			if fallos > fallos_tolerados:
				return
			# Todavia le quedan ganas: rebota igual y vuelve a probar. Sin esto, tolerar
			# fallos dejaria al personaje clavado en el lugar entre pasada y pasada.
			_dejar_estallido(estallido, caster, caster3d, rumbo)
			await _rebotar_y_reapuntar(caster3d, tree, rumbo)
			if not is_instance_valid(caster3d):
				return
			var reapunte := _hacia_el_mas_cercano(caster3d)
			if not reapunte.is_zero_approx():
				rumbo = reapunte
			continue

		for target: Node3D in tocados:
			CombatUtils.deal_damage(target, golpe, source_id)
			CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
			# Atropellar a alguien le corta el canalizado.
			#
			# Es lo unico del juego que lo hace, y es lo que le da a Flowery un rol que
			# los otros dos no cubren: hasta que existio, un Snowgrave o un ZA WARUDO ya
			# empezado solo se frenaba congelando al que lo tiraba, o sea que solo
			# Noelle podia frenar a Noelle. Un cuerpo a 30 m/s rompiendo la
			# concentracion es ademas lo que uno espera que pase.
			_interrumpir(target)
			FX.spawn_hit_impact(caster, target.global_position + Vector3.UP, golpe,
				Color(1.0, 0.42, 0.36))

		# El proximo embiste pega menos. Solo despues de CONECTAR: una pasada al aire no
		# gasta el golpe fuerte, o esquivar la primera te dejaria peor que comerla.
		golpe = maxf(DAMAGE_MINIMO, golpe * decaimiento)

		# --- Rebote ---
		FloweryDash.frenar(caster3d)
		_dejar_estallido(estallido, caster, caster3d, rumbo)
		# La ultima pasada no rebota: quedarse retrocediendo al final se lee como que
		# el ataque fallo, cuando en realidad conecto.
		if pasada == tope - 1:
			return
		await _rebotar_y_reapuntar(caster3d, tree, rumbo)
		if not is_instance_valid(caster3d):
			return
		# Reapunta hacia el rival despues del rebote: vuelve a venir a por vos, no repite
		# el rumbo viejo al aire.
		var nuevo := _hacia_el_mas_cercano(caster3d)
		if not nuevo.is_zero_approx():
			rumbo = nuevo


## Deja el estallido DETRAS del cuerpo, no encima.
##
## Encima se pierde: queda tapado por el personaje y por el destello de la pasada. Un par
## de metros atras, sobre el camino que acaba de recorrer, es donde se lee que va dejando
## un reguero, que es lo que hace a LAST JARONA distinta de JARONA.
static func _dejar_estallido(estallido: Callable, caster: Node, caster3d: Node3D,
		rumbo: Vector3) -> void:
	if estallido.is_null() or not is_instance_valid(caster3d):
		return
	estallido.call(caster, caster3d.global_position - rumbo * 2.2)


## El retroceso entre pasada y pasada, con su pausa. Es la ventana para esquivar.
static func _rebotar_y_reapuntar(caster3d: Node3D, tree: SceneTree, rumbo: Vector3) -> void:
	var vacio: Dictionary = {}
	await FloweryDash.pasada(caster3d, -rumbo, BOUNCE_SPEED, BOUNCE_TIME, 0.1, vacio)
	if not is_instance_valid(caster3d):
		return
	FloweryDash.frenar(caster3d)
	await tree.create_timer(REGROUP).timeout


## Direccion al rival vivo mas cercano, para reapuntar entre pasadas.
static func _hacia_el_mas_cercano(caster: Node3D) -> Vector3:
	var mejor: Node3D = null
	var mejor_dist := 24.0
	for target: Node3D in CombatUtils.get_players_in_sphere(caster, caster.global_position, 24.0):
		var d := caster.global_position.distance_to(target.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = target
	if mejor == null:
		return Vector3.ZERO
	var dir := mejor.global_position - caster.global_position
	dir.y = 0.0
	return dir.normalized()


## Le corta el canalizado al objetivo, si estaba canalizando.
##
## cancel_channel() ya devuelve la mitad de la stamina y avisa a los clientes, asi que
## alcanza con llamarlo: no hay que replicar nada a mano.
static func _interrumpir(target: Node3D) -> void:
	var caster := target.get_node_or_null("AbilityCaster") as AbilityCaster
	if caster != null and caster.is_channeling:
		caster.cancel_channel()
