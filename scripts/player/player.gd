class_name Player
extends CharacterBody3D
## Jugador en tercera persona.
##
## ###########################################################################
## COSTOS DE STAMINA — la regla que no se toca:
##   correr (sprint)  -> GRATIS
##   golpe basico     -> GRATIS
##   dash             -> GRATIS (se limita con cooldown, no con stamina)
##   saltar           -> GRATIS
##   habilidades      -> LO UNICO que consume stamina
## ###########################################################################
##
## RED: el movimiento es client-authoritative (cada uno manda su transform y el
## servidor lo retransmite). El combate es server-authoritative. Es el reparto
## clasico para un juego chico: movimiento responsivo, daño imposible de falsear.

signal died(killer_id: int)
signal respawned()

# --- Movimiento (nada de esto cuesta stamina) ---
@export var walk_speed: float = 6.0
@export var sprint_multiplier: float = 1.55
@export var acceleration: float = 14.0
@export var friction: float = 16.0
@export var jump_velocity: float = 5.2

# --- Dash: se limita con COOLDOWN, no con stamina ---
@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 1.4
@export var dash_iframes: float = 0.15

## Cuanto dura la ventana en la que un empujon te arrastra. Durante ese rato seguis
## teniendo control, pero parcial: podes corregir el rumbo, no cancelar el empujon.
const KNOCKBACK_CONTROL_TIME: float = 0.28

## Escalon maximo que el cuerpo sube solo.
##
## GODOT NO SUBE ESCALONES: move_and_slide frena en seco contra cualquier labio
## vertical, por bajo que sea. El navmesh, en cambio, SI los da por subibles
## (agent_max_climb), asi que le promete a los bots caminos que el cuerpo no puede
## recorrer. Medido: el bot de Flowery se pasaba el 83% de la partida clavado contra el
## costado de una rampa de acceso, donde el labio mide 39 centimetros. El navegador le
## marcaba el camino derecho por encima y el cuerpo no se podia levantar.
##
## No es solo cosa de bots: a un jugador humano le pasa igual: las cuatro rampas de la
## plataforma central tienen un borde de tobillo que te frena en seco si no las encaras
## por la punta baja. Una pared invisible, en la practica.
##
## TIENE QUE SER MAYOR que Arena.NAV_MAX_CLIMB, por al menos una celda del navmesh: el
## cuerpo tiene que poder subir MAS de lo que el navegador promete, nunca menos. El por
## que del margen esta explicado en Arena.NAV_MAX_CLIMB.
const STEP_HEIGHT: float = 0.5
## Cuanto sondea hacia adelante para ver si del otro lado hay donde pisar.
const STEP_PROBE: float = 0.42

var peer_id: int = 1
var player_name: String = "Jugador"
## Bot de entrenamiento: lo maneja un BotBrain y sus muertes no suman al marcador.
var is_dummy: bool = false
## Donde se planta un bot. Si no tiene a quien pegarle, vuelve caminando solo.
var home_position: Vector3 = Vector3.ZERO

## --- Lo que escribe el BotBrain, leido por _process_bot ---
## Direccion horizontal en la que quiere moverse, normalizada. Cero = quieto.
var bot_move_dir: Vector3 = Vector3.ZERO
## Hacia donde quiere mirar.
var bot_look_yaw: float = 0.0
## Si el bot quiere correr. Sin esto camina a 6 m/s mientras el jugador con auto-correr
## va a 9.3, o sea que no lo alcanza NUNCA: perseguir seria puro adorno.
var bot_wants_run: bool = false
## Direccion de apuntado que pisa a la de la camara.
##
## HACE FALTA porque un bot no tiene camara activa, y get_aim_direction() sale del
## CameraPivot: apagado, devolveria una direccion sin sentido y las habilidades del bot
## saldrian para cualquier lado.
var aim_override: Vector3 = Vector3.ZERO
var character_id: StringName = &"noelle"
## De que lado pelea. -1 = de ninguno: todos contra todos, que es como se juega en linea.
##
## Solo lo usa el modo historia, donde hay ALIADOS: con equipo, los golpes, los
## proyectiles y los bots no tocan a los del mismo lado. Ver CombatUtils.son_aliados.
var equipo: int = -1
## Hacia donde lo hace caminar una cinematica (cero = quieto). Solo mientras hay una
## cinematica: ahi el teclado no manda, manda la escena.
var guion_dir: Vector3 = Vector3.ZERO

@onready var health: Health = $Health
@onready var stamina: Stamina = $Stamina
@onready var status: StatusEffects = $StatusEffects
@onready var caster: AbilityCaster = $AbilityCaster
@onready var ultimate: UltimateCharge = $UltimateCharge
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var visual: PlayerVisual = $Visual
@onready var name_label: Label3D = $NameLabel
@onready var collision: CollisionShape3D = $CollisionShape3D
var _caja_colision: MeshInstance3D = null

var _gravity: float = 18.0
var _dash_left: float = 0.0
var _dash_cd_left: float = 0.0
var _iframe_left: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
## Velocidad de dash que pisa a la normal mientras dura una carga. 0 = usar dash_speed.
var dash_speed_override: float = 0.0
var _knock_t: float = 0.0
var _net_accum: float = 0.0
var _target_pos: Vector3 = Vector3.ZERO
var _target_yaw: float = 0.0
var _has_net_target: bool = false


func _ready() -> void:
	add_to_group("players")
	collision_layer = GameConfig.LAYER_PLAYER
	collision_mask = GameConfig.LAYER_WORLD
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	_target_pos = global_position
	_target_yaw = rotation.y

	health.died.connect(_on_died)
	health.changed.connect(_on_health_changed)
	health.shield_absorbed.connect(_on_shield_absorbed)

	name_label.text = player_name
	# Al propio jugador no le mostramos su cartel en la cara.
	name_label.visible = not is_local_player()
	camera_pivot.set_active(is_local_player())

	_caja_colision = FX.marcar_cuerpo(self, collision)
	Settings.changed.connect(_actualizar_caja)


## Muestra la capsula de choque solo si la opcion esta prendida Y el cuerpo la tiene.
##
## Muerto no se dibuja: la colision se apaga al morir, y una caja que se ve donde no hay
## nada que golpear es exactamente la clase de mentira que esta opcion existe para evitar.
func _actualizar_caja() -> void:
	if is_instance_valid(_caja_colision):
		_caja_colision.visible = Settings.mostrar_hitboxes and not health.is_dead


## Aplica los datos del personaje elegido. Lo llama la Arena al spawnear.
func setup_character(data: CharacterData) -> void:
	if data == null:
		return
	character_id = data.id
	walk_speed = data.move_speed
	health.set_max(data.max_health)
	stamina.set_max(data.max_stamina)
	stamina.owner_peer_id = peer_id
	ultimate.owner_peer_id = peer_id
	caster.owner_peer_id = peer_id
	caster.setup(CharacterDB.build_abilities_for(data.id))
	visual.apply_character(data)

	# Efectos que pertenecen al personaje ANTERIOR. Sin esto, cambiar de Dio a otro
	# personaje mientras The World estaba invocado dejaba al Stand dorado pegado al
	# nuevo cuerpo hasta que se le acababa el tiempo.
	var stand := get_node_or_null("TheWorld")
	if stand != null:
		stand.queue_free()


func is_local_player() -> bool:
	return peer_id == Net.local_id()


func is_invulnerable() -> bool:
	return _iframe_left > 0.0


## Origen de las habilidades: el pecho del jugador, no la camara.
## Asi el raycast de linea de vision sale del cuerpo y las coberturas funcionan bien.
func get_aim_origin() -> Vector3:
	return global_position + Vector3.UP * 1.2


## Direccion de apuntado: del pecho hacia el punto que esta bajo la mira.
##
## No es lo mismo que la direccion de la camara: como la camara va corrida al hombro,
## apuntar paralelo a ella hace que las habilidades pasen al costado de lo que estas
## mirando. Esto corrige esa paralaje.
func get_aim_direction() -> Vector3:
	if not aim_override.is_zero_approx():
		return aim_override.normalized()
	if not is_instance_valid(camera_pivot):
		return -global_transform.basis.z
	var target := camera_pivot.get_aim_point()
	var dir := target - get_aim_origin()
	if dir.is_zero_approx():
		return camera_pivot.get_aim_direction()
	return dir.normalized()


## SOLO SERVIDOR. Empuja al jugador.
##
## OJO CON LA RED: el movimiento es client-authoritative, asi que sumarle velocidad
## en el servidor no se ve — el dueño sigue mandando su propio transform y lo pisa.
## Hay que pedirle AL DUEÑO que se empuje a si mismo.
func apply_knockback(impulse: Vector3) -> void:
	if not Net.is_server():
		return
	if is_dummy or is_local_player() or multiplayer.multiplayer_peer == null:
		_apply_knockback_local(impulse)
		return
	Net.rpc_ready_id(self, peer_id, &"_net_knockback", [impulse])


@rpc("authority", "call_remote", "reliable")
func _net_knockback(impulse: Vector3) -> void:
	_apply_knockback_local(impulse)


## SOLO SERVIDOR. Lanza al jugador en una direccion, como un dash largo.
##
## Lo usa "Here I Come San Francisco". Va por el mismo camino que el empujon y por la
## misma razon: el movimiento es client-authoritative, asi que mover al jugador desde el
## servidor no se ve — el dueño sigue mandando su propio transform y lo pisa.
##
## Reusa la maquinaria del dash (_dash_left / _dash_dir) en vez de inventar un estado
## nuevo: asi la carga ignora el input direccional igual que un dash, que es
## exactamente lo que tiene que pasar cuando te tiras de cabeza contra alguien.
func launch_charge(dir: Vector3, speed: float, duration: float) -> void:
	if not Net.is_server():
		return
	if is_dummy or is_local_player() or multiplayer.multiplayer_peer == null:
		_apply_charge_local(dir, speed, duration)
		return
	Net.rpc_ready_id(self, peer_id, &"_net_charge", [dir, speed, duration])


@rpc("authority", "call_remote", "reliable")
func _net_charge(dir: Vector3, speed: float, duration: float) -> void:
	_apply_charge_local(dir, speed, duration)


## SOLO SERVIDOR. Corta una carga en seco.
##
## Lo usa el rebote de JARONA: sin frenar, el rebote arranca peleando contra la inercia
## de la ida y el cambio de direccion se ve como un patinazo en vez de como un rebote.
func stop_charge() -> void:
	if not Net.is_server():
		return
	if is_dummy or is_local_player() or multiplayer.multiplayer_peer == null:
		_apply_stop_charge()
		return
	Net.rpc_ready_id(self, peer_id, &"_net_stop_charge", [])


@rpc("authority", "call_remote", "reliable")
func _net_stop_charge() -> void:
	_apply_stop_charge()


func _apply_stop_charge() -> void:
	_dash_left = 0.0
	dash_speed_override = 0.0
	velocity.x = 0.0
	velocity.z = 0.0


func _apply_charge_local(dir: Vector3, speed: float, duration: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.is_zero_approx():
		flat = -global_transform.basis.z
	_dash_dir = flat.normalized()
	_dash_left = duration
	# OJO: NO toca _dash_cd_left. La carga es una habilidad con su propio cooldown y su
	# propio costo de stamina; gastarte ademas el dash seria cobrarte dos veces.
	dash_speed_override = speed
	visual.play_dash_trail()


func _apply_knockback_local(impulse: Vector3) -> void:
	velocity.x += impulse.x
	velocity.z += impulse.z
	if impulse.y > 0.0:
		velocity.y = maxf(velocity.y, impulse.y)
	# Ventana en la que el empujon manda por encima del input. Sin esto no se ve nada:
	# la friccion del movimiento normal lo mata en dos frames.
	_knock_t = KNOCKBACK_CONTROL_TIME


# --------------------------------------------------------------- Ciclo de vida

func _physics_process(delta: float) -> void:
	_dash_cd_left = maxf(0.0, _dash_cd_left - delta)
	_iframe_left = maxf(0.0, _iframe_left - delta)
	_knock_t = maxf(0.0, _knock_t - delta)

	# Los maniquies no los controla nadie, pero si los empujan tienen que moverse y
	# despues volver a su lugar. Si no, el modo practica se desarma a los diez golpes.
	if is_dummy:
		_process_bot(delta)
		return

	if not is_local_player():
		_follow_network_target(delta)
		return

	if health.is_dead:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_handle_local_movement(delta)
	_replicate(delta)


func _handle_local_movement(delta: float) -> void:
	if Cinematica.activa:
		_mover_por_guion(delta)
		return
	var frozen := not status.can_act()
	var channeling: bool = caster.is_channeling

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# --- Dash en curso: ignora el input direccional hasta que termina ---
	if _dash_left > 0.0:
		_dash_left = maxf(0.0, _dash_left - delta)
		var vel := dash_speed_override if dash_speed_override > 0.0 else dash_speed
		velocity.x = _dash_dir.x * vel
		velocity.z = _dash_dir.z * vel
		move_and_slide()
		if is_zero_approx(_dash_left):
			dash_speed_override = 0.0
		return

	var input_dir := Vector2.ZERO
	var en_menu := _mando_en_menu()
	# Congelado o canalizando Snowgrave: no te moves. La camara sigue libre.
	if not frozen and not channeling and not en_menu:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var basis := camera_pivot.get_movement_basis()
	var wish := (basis.x * input_dir.x + basis.z * input_dir.y)
	wish.y = 0.0
	wish = wish.normalized()

	# Correr: NO cuesta stamina NUNCA.
	# Con "correr automaticamente" prendido (por defecto) corres siempre; si lo apagas,
	# corres manteniendo la tecla de sprint.
	var wants_run: bool = Settings.auto_run or Input.is_action_pressed("sprint")
	var speed := walk_speed
	if wants_run and not frozen and not channeling:
		speed *= sprint_multiplier
	speed *= status.get_move_speed_multiplier()

	var accel := acceleration * delta * walk_speed
	var brake := friction * delta * walk_speed
	if _knock_t > 0.0:
		# Mientras dura el empujon el control es parcial. La friccion normal (casi 100
		# unidades por segundo) mataba cualquier impulso antes de que se viera.
		accel *= 0.22
		brake *= 0.10

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish.is_zero_approx():
		horizontal = horizontal.move_toward(Vector3.ZERO, brake)
	else:
		horizontal = horizontal.move_toward(wish * speed, accel)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var puede_saltar := is_on_floor() and not frozen and not channeling and not en_menu
	if Input.is_action_just_pressed("jump") and puede_saltar:
		velocity.y = jump_velocity

	# El cuerpo mira hacia donde apunta la camara.
	var look := camera_pivot.get_yaw()
	rotation.y = look

	move_and_slide()
	_resolver_escalon(wish)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player() or health.is_dead or Cinematica.activa:
		return
	if not status.can_act():
		return
	if _mando_en_menu() and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return

	# Dash: SIN COSTO DE STAMINA. Solo cooldown.
	if event.is_action_pressed("dash"):
		_try_dash()
	elif event.is_action_pressed("attack_basic"):
		caster.request_use(0)
	elif event.is_action_pressed("ability_1"):
		caster.request_use(1)
	elif event.is_action_pressed("ability_2"):
		caster.request_use(2)
	elif event.is_action_pressed("ability_ultimate"):
		# El ultimate es el ULTIMO del kit, no el tercero. El orden del array es el
		# mismo que el del HUD a proposito: si no coincidieran, cada vez que alguien
		# agregue una habilidad tendria que acordarse de la excepcion.
		caster.request_use(3)


## El jugador en una cinematica: camina hacia guion_dir y mira hacia donde la escena puso
## la camara del jugador. Sin correr: en una escena se camina, no se pelea.
func _mover_por_guion(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	var plano := Vector3(guion_dir.x, 0.0, guion_dir.z)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var objetivo := plano.normalized() * walk_speed if not plano.is_zero_approx() else Vector3.ZERO
	horizontal = horizontal.move_toward(objetivo, acceleration * delta * walk_speed)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	rotation.y = camera_pivot.get_yaw()
	move_and_slide()


## Con un mando, un menu abierto encima de la partida se maneja con el mismo stick y los
## mismos botones que el personaje: el stick izquierdo recorre la pausa, A aprieta. Si el
## personaje tambien los leyera, navegar la pausa lo haria caminar, y reanudar lo haria
## saltar. Con teclado no pasa: el menu se usa con el mouse, que no mueve a nadie.
func _mando_en_menu() -> bool:
	return Controles.dispositivo == &"mando" and Mando.hay_menu_abierto()


func _try_dash() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := camera_pivot.get_movement_basis()
	var dir := (basis.x * input_dir.x + basis.z * input_dir.y)
	dir.y = 0.0
	# Sin input direccional dasheas hacia adelante.
	dash_hacia(dir)


## Dash en una direccion explicita. Devuelve true si salio.
##
## EXISTE SEPARADA DE _try_dash PORQUE LOS BOTS NO PUEDEN USAR ESA.
##
## _try_dash saca la direccion de Input.get_vector() y de la camara. Un bot no tiene
## camara, y —lo importante— Input es GLOBAL: un bot llamando a _try_dash leeria las
## teclas que esta apretando el jugador humano en ese instante. Sus esquives irian para
## donde te estas moviendo vos.
func dash_hacia(dir: Vector3) -> bool:
	if _dash_cd_left > 0.0 or _dash_left > 0.0:
		return false
	if caster.is_channeling or health.is_dead or not status.can_act():
		return false
	var plano := Vector3(dir.x, 0.0, dir.z)
	if plano.is_zero_approx():
		plano = -global_transform.basis.z
		plano.y = 0.0
	if plano.is_zero_approx():
		return false
	_dash_dir = plano.normalized()
	_dash_left = dash_duration
	_dash_cd_left = dash_cooldown
	_iframe_left = dash_iframes
	visual.play_dash_trail()
	Sfx.play_3d(self, &"dash", global_position, -6.0)
	return true


## Maniqui: recibe el empujon, se frena solo y despues vuelve caminando a su marca.
## Fisica de un bot. Lo QUE hace lo decide BotBrain; aca solo se ejecuta, para que la
## gravedad, la friccion y el empujon se comporten igual que con un jugador de verdad.
func _process_bot(delta: float) -> void:
	# Red de seguridad: si por lo que sea se cayo del mundo, vuelve a su marca en vez
	# de seguir cayendo para siempre.
	if global_position.y < -5.0:
		global_position = home_position + Vector3.UP * 0.5
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# Los bots tambien pueden ser lanzados: si un bot Flowery usa su carga y esto no
	# estuviera aca, la habilidad le cobraria stamina y no lo moveria un centimetro.
	if _dash_left > 0.0:
		_dash_left = maxf(0.0, _dash_left - delta)
		var dv := dash_speed_override if dash_speed_override > 0.0 else dash_speed
		velocity.x = _dash_dir.x * dv
		velocity.z = _dash_dir.z * dv
		move_and_slide()
		if is_zero_approx(_dash_left):
			dash_speed_override = 0.0
		return

	var frozen := not status.can_act()
	var wish := Vector3.ZERO if frozen else bot_move_dir
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()

	var speed := walk_speed
	if bot_wants_run and not frozen:
		speed *= sprint_multiplier
	speed *= status.get_move_speed_multiplier()
	var accel := acceleration * delta * walk_speed
	var brake := friction * delta * walk_speed
	if _knock_t > 0.0:
		# Mismo criterio que con un jugador: durante el empujon la friccion no puede
		# matar el impulso antes de que se vea.
		accel *= 0.22
		brake *= 0.10

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish.is_zero_approx():
		horizontal = horizontal.move_toward(Vector3.ZERO, brake)
	else:
		horizontal = horizontal.move_toward(wish * speed, accel)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not frozen:
		rotation.y = lerp_angle(rotation.y, bot_look_yaw, minf(1.0, delta * 9.0))

	move_and_slide()
	_resolver_escalon(wish)


## Sube un escalon bajo que tenga justo adelante. Devuelve true si subio.
##
## Se llama DESPUES de move_and_slide, cuando ya sabemos que choco. El sondeo es el
## clasico de tres pasos —levantar, avanzar, dejar caer— y cada paso tiene su motivo:
##
##   1. LEVANTAR: si no hay aire encima, no hay escalon que valga, es una pared.
##   2. AVANZAR:  si arriba sigue bloqueado, tampoco: es una pared mas alta que el paso.
##   3. CAER:     si del otro lado no hay piso al alcance, es un precipicio, no un
##                escalon, y subirse seria caminar al vacio.
##
## Solo si los tres dan, mueve el cuerpo. Las coberturas del mapa miden de 1.4 a 4.4
## metros, muy por encima de STEP_HEIGHT, asi que esto no las vuelve escalables.
func _subir_escalon(direccion: Vector3) -> bool:
	if direccion.is_zero_approx():
		return false
	var plano := Vector3(direccion.x, 0.0, direccion.z).normalized()
	if plano.is_zero_approx():
		return false

	var t := global_transform
	var arriba := Vector3.UP * STEP_HEIGHT
	if test_move(t, arriba):
		return false
	t.origin += arriba

	var avance := plano * STEP_PROBE
	if test_move(t, avance):
		return false
	t.origin += avance

	var golpe := KinematicCollision3D.new()
	if not test_move(t, Vector3.DOWN * (STEP_HEIGHT + 0.05), golpe):
		return false

	global_position = t.origin + golpe.get_travel()
	return true


## Despues de moverse: si quedo trabado contra un labio bajo, lo sube.
##
## `intencion` es hacia donde QUERIA ir, no hacia donde quedo apuntando la velocidad:
## move_and_slide ya la deslizo a lo largo de la pared, y usar eso lo haria sondear
## paralelo al obstaculo en vez de contra el.
func _resolver_escalon(intencion: Vector3) -> void:
	if not is_on_wall() or not is_on_floor():
		return
	# La rapidez se mide ANTES de tocar nada: si se calcula sobre la marcha, el segundo
	# eje se computa con el primero ya pisado.
	var rapidez := Vector3(velocity.x, 0.0, velocity.z).length()
	if _subir_escalon(intencion):
		# move_and_slide se comio la velocidad contra la pared; se la devolvemos para que
		# no quede frenandose arriba de cada escalon.
		velocity.x = intencion.x * rapidez
		velocity.z = intencion.z * rapidez


func get_dash_cooldown_ratio() -> float:
	if dash_cooldown <= 0.0:
		return 0.0
	return _dash_cd_left / dash_cooldown


func is_dashing() -> bool:
	return _dash_left > 0.0


# ------------------------------------------------------------------- Muerte

func _on_died(killer_id: int) -> void:
	caster.reset_state()
	velocity = Vector3.ZERO
	_dash_left = 0.0
	visual.set_dead(true)
	Sfx.play_3d(self, &"death", global_position, -1.0)
	# DIFERIDO, no directo.
	#
	# Morir se dispara DENTRO de una consulta fisica: las habilidades buscan a quien
	# pegarle con intersect_shape, y el daño —y con el la muerte— sale de ahi adentro.
	# Apagar la forma en ese momento es cambiarle el estado al servidor de fisica
	# mientras esta recorriendo sus propias consultas, y Godot lo rechaza:
	#
	#   "Can't change this state while flushing queries.
	#    Use call_deferred() or set_deferred() ... instead."
	#
	# Lo encontre en la consola del navegador jugando el build exportado; en los arneses
	# de escritorio no aparecia. La consecuencia de no diferirlo es que el cadaver a
	# veces se queda solido y sigue frenando embestidas.
	collision.set_deferred("disabled", true)
	_actualizar_caja()
	name_label.visible = false
	died.emit(killer_id)


## Chispazo cuando el escudo para un golpe. Sin esto el golpe no se siente: el numero
## de daño no aparece y parece que la habilidad del rival fallo, no que la frenaste.
func _on_shield_absorbed(amount: float, _remaining: float) -> void:
	FX.spawn_shield_hit(self, amount)


func _on_health_changed(_current: float, _max_value: float) -> void:
	pass


## SOLO SERVIDOR. Avisa a todos que una embestida acaba de conectar.
##
## El golpe lo decide el servidor, pero la ANIMACION tiene que verla todo el mundo. No
## se puede deducir en el cliente: desde afuera, una embestida que conecta y una que
## pasa al aire terminan igual —el cuerpo frena— asi que el unico que sabe cual fue es
## el que resolvio el impacto.
## Grita una frase, y la replica. La dice el servidor y la ven los dos.
##
## TIENE QUE VERSE EN LA PANTALLA DEL OTRO, sobre todo en la del otro. La frase es el
## aviso de que viene el ataque; si solo la viera el que la dice, seria decoracion para
## el que menos la necesita.
func avisar_grito(texto: String, voz: StringName) -> void:
	if not Net.is_server():
		return
	Net.rpc_ready(self, &"_net_grito", [texto, voz])
	_grito(texto, voz)


@rpc("authority", "call_remote", "reliable")
func _net_grito(texto: String, voz: StringName) -> void:
	_grito(texto, voz)


## LA VOZ Y EL CARTEL SALEN DE LA MISMA LLAMADA, a proposito.
##
## Es lo unico que garantiza que se oiga lo que se lee. Si la voz la tirara la habilidad
## y el cartel este otro camino, cualquier diferencia de un frame entre los dos —o peor,
## que uno se replique y el otro no— dejaria a un jugador leyendo "¡ZA WARUDO!" en
## silencio y al otro escuchandolo sin ver nada.
##
## El cartel ademas es la red de seguridad de la voz: el banco de sonido se genera a lo
## largo del arranque y las voces son lo ultimo en estar listo, asi que en los primeros
## segundos de una partida play_3d se sale sin hacer nada. Ahi el texto es lo unico que
## queda, y es mejor que nada.
func _grito(texto: String, voz: StringName) -> void:
	FX.spawn_grito(self, texto, Frases.color_de(character_id))
	if voz != &"":
		Sfx.play_3d(self, voz, global_position, 4.0)


func avisar_impacto_embestida() -> void:
	if not Net.is_server():
		return
	Net.rpc_ready(self, &"_net_impacto_embestida", [])
	_impacto_embestida()


@rpc("authority", "call_remote", "reliable")
func _net_impacto_embestida() -> void:
	_impacto_embestida()


func _impacto_embestida() -> void:
	if is_instance_valid(visual):
		visual.golpe_de_embestida()


## SOLO SERVIDOR. Teletransporta el cuerpo a un punto y avisa a todos.
##
## POR QUE NO ALCANZA CON PONER global_position EN EL SERVIDOR.
##
## El movimiento de este juego es AUTORIDAD DEL CLIENTE: cada uno manda su propia
## posicion y el servidor la acepta. Si el servidor moviera el cuerpo por su cuenta, el
## siguiente paquete del cliente —que todavia se cree en el lugar viejo— lo devolveria
## ahi, y el teletransporte duraria una fraccion de segundo.
##
## Por eso viaja como RPC a todos, incluido el dueño: el que manda su posicion aplica el
## salto primero y despues reporta el lugar nuevo. Es el mismo camino que usa respawn_at.
##
## `yaw` es opcional: hacia donde queda mirando al llegar. Lo usa la teletransportacion de
## Goku, que aparece detras de alguien y tiene que quedar mirandolo; el portal de Rick no
## lo pasa y conserva la direccion con la que entro. NAN = no girar.
func teleport_to(destino: Vector3, yaw: float = NAN) -> void:
	if not Net.is_server():
		return
	# Siempre los dos argumentos por la red, aunque el yaw no se use: un RPC con un
	# parametro opcional que a veces llega y a veces no es como se arman los "numero de
	# argumentos equivocado" que solo aparecen en linea.
	Net.rpc_ready(self, &"_net_teleport", [destino, yaw])
	_apply_teleport(destino, yaw)


@rpc("authority", "call_remote", "reliable")
func _net_teleport(destino: Vector3, yaw: float) -> void:
	_apply_teleport(destino, yaw)


func _apply_teleport(destino: Vector3, yaw: float = NAN) -> void:
	if not is_nan(yaw):
		rotation.y = yaw
		_target_yaw = yaw
		# La camara manda la rotacion del cuerpo del jugador local: si no se la gira a
		# ella, el proximo frame el cuerpo vuelve a mirar para donde miraba la camara.
		if is_local_player() and is_instance_valid(camera_pivot):
			camera_pivot.set_yaw(yaw)
	global_position = destino
	# El objetivo de interpolacion tambien, o los clientes remotos ven al cuerpo
	# DESLIZARSE hasta el destino en vez de aparecer ahi.
	_target_pos = destino
	velocity = Vector3.ZERO
	# Y se corta cualquier embestida en curso: salir de un portal con la inercia de
	# una carga encima manda al personaje volando apenas llega.
	_dash_left = 0.0
	dash_speed_override = 0.0


## SOLO SERVIDOR. Revive y reposiciona.
func respawn_at(spawn_position: Vector3, yaw: float) -> void:
	if not Net.is_server():
		return
	health.revive_full()
	stamina.restore_full()
	status.clear_all()
	caster.reset_state()
	Net.rpc_ready(self, &"_net_respawn", [spawn_position, yaw])
	_apply_respawn(spawn_position, yaw)


func _apply_respawn(spawn_position: Vector3, yaw: float) -> void:
	global_position = spawn_position
	rotation.y = yaw
	_target_pos = spawn_position
	_target_yaw = yaw
	velocity = Vector3.ZERO
	_dash_left = 0.0
	_dash_cd_left = 0.0
	visual.set_dead(false)
	Sfx.play_3d(self, &"respawn", spawn_position, -3.0)
	# Tambien diferido, por simetria: revivir puede caer dentro de una consulta igual que
	# morir, y ademas asi el par apagar/prender se aplica siempre en el mismo momento del
	# frame. Mezclar uno directo con uno diferido es como se consiguen cadaveres solidos.
	collision.set_deferred("disabled", false)
	_actualizar_caja()
	name_label.visible = not is_local_player()
	if is_local_player() and is_instance_valid(camera_pivot):
		camera_pivot.set_yaw(yaw)
	respawned.emit()


@rpc("authority", "call_remote", "reliable")
func _net_respawn(spawn_position: Vector3, yaw: float) -> void:
	_apply_respawn(spawn_position, yaw)


# ---------------------------------------------------------------------- Red

func _replicate(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	_net_accum += delta
	var interval := 1.0 / GameConfig.NET_TICK_HZ
	if _net_accum < interval:
		return
	_net_accum = 0.0
	if multiplayer.is_server():
		Net.rpc_ready(self, &"_net_transform", [global_position, rotation.y, velocity])
	else:
		_srv_transform.rpc_id(1, global_position, rotation.y, velocity)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _srv_transform(pos: Vector3, yaw: float, vel: Vector3) -> void:
	if not multiplayer.is_server():
		return
	# Solo el dueño puede mover su propio jugador.
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_target_pos = pos
	_target_yaw = yaw
	velocity = vel
	_has_net_target = true
	# Retransmitimos al resto. El propio dueño lo ignora en _net_transform.
	Net.rpc_ready(self, &"_net_transform", [pos, yaw, vel])


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_transform(pos: Vector3, yaw: float, vel: Vector3) -> void:
	if is_local_player():
		return
	_target_pos = pos
	_target_yaw = yaw
	velocity = vel
	_has_net_target = true


## Los jugadores remotos se interpolan hacia la ultima posicion conocida.
func _follow_network_target(delta: float) -> void:
	if not _has_net_target:
		return
	# Si la diferencia es enorme (respawn, teleport) saltamos directo.
	if global_position.distance_to(_target_pos) > 6.0:
		global_position = _target_pos
	else:
		global_position = global_position.lerp(_target_pos, clampf(delta * 14.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 14.0, 0.0, 1.0))
