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

@onready var health: Health = $Health
@onready var stamina: Stamina = $Stamina
@onready var status: StatusEffects = $StatusEffects
@onready var caster: AbilityCaster = $AbilityCaster
@onready var ultimate: UltimateCharge = $UltimateCharge
@onready var camera_pivot: PlayerCamera = $CameraPivot
@onready var visual: PlayerVisual = $Visual
@onready var name_label: Label3D = $NameLabel
@onready var collision: CollisionShape3D = $CollisionShape3D

var _gravity: float = 18.0
var _dash_left: float = 0.0
var _dash_cd_left: float = 0.0
var _iframe_left: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
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
	var frozen := not status.can_act()
	var channeling: bool = caster.is_channeling

	if not is_on_floor():
		velocity.y -= _gravity * delta

	# --- Dash en curso: ignora el input direccional hasta que termina ---
	if _dash_left > 0.0:
		_dash_left = maxf(0.0, _dash_left - delta)
		velocity.x = _dash_dir.x * dash_speed
		velocity.z = _dash_dir.z * dash_speed
		move_and_slide()
		return

	var input_dir := Vector2.ZERO
	# Congelado o canalizando Snowgrave: no te moves. La camara sigue libre.
	if not frozen and not channeling:
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

	if Input.is_action_just_pressed("jump") and is_on_floor() and not frozen and not channeling:
		velocity.y = jump_velocity

	# El cuerpo mira hacia donde apunta la camara.
	var look := camera_pivot.get_yaw()
	rotation.y = look

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player() or health.is_dead:
		return
	if not status.can_act():
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


func _try_dash() -> void:
	if _dash_cd_left > 0.0 or _dash_left > 0.0:
		return
	if caster.is_channeling:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := camera_pivot.get_movement_basis()
	var dir := (basis.x * input_dir.x + basis.z * input_dir.y)
	dir.y = 0.0
	if dir.is_zero_approx():
		# Sin input direccional dasheas hacia adelante.
		dir = -global_transform.basis.z
		dir.y = 0.0
	_dash_dir = dir.normalized()
	_dash_left = dash_duration
	_dash_cd_left = dash_cooldown
	_iframe_left = dash_iframes
	visual.play_dash_trail()
	Sfx.play_3d(self, &"dash", global_position, -6.0)


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
	collision.disabled = true
	name_label.visible = false
	died.emit(killer_id)


## Chispazo cuando el escudo para un golpe. Sin esto el golpe no se siente: el numero
## de daño no aparece y parece que la habilidad del rival fallo, no que la frenaste.
func _on_shield_absorbed(amount: float, _remaining: float) -> void:
	FX.spawn_shield_hit(self, amount)


func _on_health_changed(_current: float, _max_value: float) -> void:
	pass


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
	collision.disabled = false
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
