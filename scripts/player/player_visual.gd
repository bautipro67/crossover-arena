class_name PlayerVisual
extends Node3D
## Cuerpo del personaje: un humanoide articulado armado con primitivas, con ciclo de
## caminata, poses de habilidad y lectura de estado.
##
## No hay modelos ni esqueletos. La estructura es una jerarquia de Node3D que hacen de
## articulaciones (hombros, codos, caderas, rodillas) y que se rotan por codigo.
##
## SENTIDO DE LAS ROTACIONES (esto es lo que mas facil se equivoca):
## el brazo cuelga hacia -Y desde el hombro. Rotando el hombro en X un angulo t, la mano
## queda en (0, -cos t, -sin t). O sea:
##     t = 0      -> brazo colgando
##     t = +PI/2  -> brazo al FRENTE (en Godot el frente es -Z)
##     t = +PI    -> brazo ARRIBA
## Por eso los golpes SUMAN al angulo. Restar manda el brazo para atras.
##
## Cuando tengas modelos de verdad, el punto de entrada es _build_rig(): lo reemplazas
## por la carga del .glb y un AnimationPlayer, y el resto del juego no se entera.

const OUTLINE_WIDTH: float = 0.009

## Ciclo de caminata.
const STEP_SPEED: float = 7.5
const LEG_SWING: float = 0.55
const ARM_SWING: float = 0.42
const BOB_HEIGHT: float = 0.055

## Golpe.
const PUNCH_REACH: float = 1.85
const PUNCH_DECAY: float = 3.4

var body_color: Color = Color(0.85, 0.92, 0.88)
var accent_color: Color = Color(0.45, 0.78, 1.0)
var skin_color: Color = Color(0.98, 0.85, 0.74)
var trouser_color: Color = Color(0.14, 0.16, 0.25)
## Proporciones del cuerpo. Ver CharacterData.build_scale.
var build_scale: Vector3 = Vector3.ONE

# --- Articulaciones ---
var _root: Node3D = null
var _hips: Node3D = null
var _torso: Node3D = null
var _torso_mesh: MeshInstance3D = null
var _head_pivot: Node3D = null
var _shoulder_l: Node3D = null
var _shoulder_r: Node3D = null
var _elbow_l: Node3D = null
var _elbow_r: Node3D = null
var _hip_l: Node3D = null
var _hip_r: Node3D = null
var _knee_l: Node3D = null
var _knee_r: Node3D = null

# --- Materiales (se re-tintan al aplicar el personaje) ---
var _mat_body: StandardMaterial3D = null
var _mat_accent: StandardMaterial3D = null
var _mat_skin: StandardMaterial3D = null
var _mat_dark: StandardMaterial3D = null

# --- Cara ---
var _eye_l: Node3D = null
var _eye_r: Node3D = null
var _brow_l: Node3D = null
var _brow_r: Node3D = null
var _mouth: Node3D = null
var _mouth_mesh: MeshInstance3D = null
var _blink_wait: float = 3.0
var _blink_t: float = 0.0
## Inclinacion base de las cejas: define la expresion de reposo del personaje.
var _brow_tilt: float = 0.0

var _costume: Array[Node3D] = []
## La cabeza y el cuello, guardados para poder cambiarles el material. Todos los
## personajes tienen cabeza de piel salvo los que son bichos, y esos la necesitan de pelo.
var _head_mesh: MeshInstance3D = null
var _neck_mesh: MeshInstance3D = null
var _frost: CPUParticles3D = null
var _freeze_shell: Node3D = null
var _time_marker: Node3D = null
var _channel_fx: Node3D = null

var _status: StatusEffects = null
var _caster: AbilityCaster = null
var _health: Health = null
var _body: CharacterBody3D = null

# Postura suavizada, separada del golpe (ver el comentario en _process).
var _sm_arm_l: float = 0.0
var _sm_arm_r: float = 0.0
var _sm_elbow_l: float = -0.15
var _sm_elbow_r: float = -0.15
var _sm_spread_l: float = 0.0
var _sm_spread_r: float = 0.0

var _cycle: float = 0.0
var _idle: float = 0.0
var _attack_t: float = 0.0
var _hit_t: float = 0.0
var _last_health: float = -1.0

## Pose activa: &"" (ninguna), &"channel_up", &"channel_point", &"release".
var _pose: StringName = &""
var _pose_weight: float = 0.0
var _release_t: float = 0.0
## Cuenta atras del sacudon de impacto de una embestida. Ver golpe_de_embestida().
var _impacto_t: float = 0.0
## Aterrizaje: cuanto queda del achatado al tocar el piso.
var _aterrizaje_t: float = 0.0
## Si el frame anterior estaba en el aire, para detectar el momento exacto de aterrizar.
var _estaba_en_aire: bool = false
## Retroceso de recibir un golpe. Distinto de _hit_t, que es solo el temblor.
var _dolor_t: float = 0.0
## Para la inclinacion: cuanto giro el cuerpo desde el frame anterior.
var _yaw_previo: float = 0.0
var _giro_suave: float = 0.0
## Fase del ciclo de caminata en el frame anterior, para saber cuando cae un pie.
var _paso_previo: float = 0.0


func _ready() -> void:
	_build_rig()
	_body = get_parent() as CharacterBody3D
	_status = get_parent().get_node_or_null("StatusEffects") as StatusEffects
	_caster = get_parent().get_node_or_null("AbilityCaster") as AbilityCaster
	_health = get_parent().get_node_or_null("Health") as Health

	if _status != null:
		_status.chill_changed.connect(_on_chill_changed)
		_status.froze.connect(_on_froze)
		_status.unfroze.connect(_on_unfroze)
		_status.stunned.connect(_on_stunned)
		_status.unstunned.connect(_on_unstunned)
	if _caster != null:
		_caster.ability_used.connect(_on_ability_used)
		_caster.channel_started.connect(_on_channel_started)
		_caster.channel_finished.connect(_on_channel_finished)
		_caster.channel_cancelled.connect(_on_channel_cancelled)
	if _health != null:
		_health.changed.connect(_on_health_changed)
		# `damaged` trae el autor del golpe; `changed` no. Hace falta para que el que
		# pego sienta el impacto y no solo lo vea el que lo recibe.
		_health.damaged.connect(_on_damaged)
		_last_health = _health.current


# ------------------------------------------------------------------ Animacion

func _process(delta: float) -> void:
	if _root == null or not is_instance_valid(_body):
		return

	_idle += delta
	_attack_t = maxf(0.0, _attack_t - delta * PUNCH_DECAY)
	_hit_t = maxf(0.0, _hit_t - delta * 6.0)
	_release_t = maxf(0.0, _release_t - delta * 2.2)

	_impacto_t = maxf(0.0, _impacto_t - delta * 3.4)
	_aterrizaje_t = maxf(0.0, _aterrizaje_t - delta * 5.5)
	_dolor_t = maxf(0.0, _dolor_t - delta * 4.0)

	# --- EN EL AIRE: saltando o cayendo ---
	#
	# Se distinguen por el signo de la velocidad vertical, y son poses distintas porque
	# son momentos distintos: saltando el cuerpo se recoge —es un impulso— y cayendo se
	# abre buscando el piso. Con una sola pose para los dos, un salto largo se ve como un
	# maniqui flotando.
	var en_aire := not _body.is_on_floor()
	if en_aire and not _estaba_en_aire and _body.velocity.y > 0.5:
		Sfx.play_3d(self, &"salto", global_position, -8.0)
	if _estaba_en_aire and not en_aire:
		Sfx.play_3d(self, &"aterrizaje", global_position, -6.0)
		# ATERRIZAJE: el golpe contra el piso. Sin esto el salto termina de golpe, y lo
		# que hace que un salto se sienta con peso es como cae, no como sube.
		_aterrizaje_t = 1.0
	_estaba_en_aire = en_aire

	# LA EMBESTIDA MANDA SOBRE CUALQUIER POSE.
	#
	# Se deduce del propio cuerpo —is_dashing()— y no de un aviso por red, porque el
	# estado del dash ya se replica a todos: el que mira ve el cuerpo lanzado igual que
	# el que lo lanzo. Un aviso aparte seria un mensaje de mas para decir algo que ya
	# esta dicho.
	#
	# El impacto si necesita aviso, y por eso _impacto_t viene de afuera: desde el visual
	# no hay forma de distinguir una embestida que conecto de una que paso al aire.
	# PRIORIDAD DE POSES, de mas urgente a menos: el impacto de una embestida tapa todo,
	# despues el dolor de recibir un golpe, despues el dash, y al final el aire.
	if _impacto_t > 0.0:
		_pose = &"impacto"
	elif _dolor_t > 0.0:
		_pose = &"dolor"
	elif _body.is_dashing():
		_pose = &"embiste"
	elif en_aire:
		_pose = &"salto" if _body.velocity.y > 0.5 else &"caida"
	elif _pose == &"embiste" or _pose == &"impacto" or _pose == &"dolor" 			or _pose == &"salto" or _pose == &"caida":
		_pose = &""

	# La pose entra y sale suave: sin esto los brazos se teletransportan.
	var wants_pose := _pose != &""
	_pose_weight = move_toward(_pose_weight, 1.0 if wants_pose else 0.0, delta * 6.0)
	if not wants_pose and is_zero_approx(_pose_weight) and _release_t <= 0.0:
		_pose_weight = 0.0

	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	var moving := speed > 0.6

	if moving:
		_cycle += delta * STEP_SPEED * clampf(speed / 6.0, 0.6, 1.9)
	else:
		_cycle = lerp_angle(_cycle, 0.0, delta * 8.0)

	# --- PASOS ---
	#
	# Se disparan del propio ciclo de caminata, cuando cruza por cero: ahi es exactamente
	# donde una pierna toca el piso, asi que el sonido cae sincronizado con la animacion
	# sin necesidad de llevar un temporizador aparte que se desfase.
	if moving and not en_aire:
		var fase := fmod(_cycle, PI)
		if fase < _paso_previo:
			Sfx.play_3d(self, &"paso", global_position, -17.0)
		_paso_previo = fase
	else:
		_paso_previo = 0.0

	var swing := sin(_cycle) if moving else 0.0
	var amount := clampf(speed / 9.0, 0.0, 1.35)

	# --- Piernas: siempre las manda la caminata ---
	_hip_l.rotation.x = swing * LEG_SWING * amount
	_hip_r.rotation.x = -swing * LEG_SWING * amount
	# La rodilla solo dobla hacia atras, nunca al reves.
	_knee_l.rotation.x = -maxf(0.0, -swing) * 0.7 * amount
	_knee_r.rotation.x = -maxf(0.0, swing) * 0.7 * amount

	# --- Brazos y torso: caminata, y encima el golpe o la pose ---
	var arm_l := -swing * ARM_SWING * amount
	var arm_r := swing * ARM_SWING * amount
	var elbow_l := -absf(arm_l) * 0.5 - 0.15
	var elbow_r := -absf(arm_r) * 0.5 - 0.15
	var spread_l := 0.0
	var spread_r := 0.0
	var torso_x := -0.10 * amount

	var pose := _pose_targets()
	if _pose_weight > 0.001:
		var w: float = _pose_weight
		arm_l = lerpf(arm_l, float(pose["arm_l"]), w)
		arm_r = lerpf(arm_r, float(pose["arm_r"]), w)
		elbow_l = lerpf(elbow_l, float(pose["elbow_l"]), w)
		elbow_r = lerpf(elbow_r, float(pose["elbow_r"]), w)
		spread_l = lerpf(0.0, float(pose["spread_l"]), w)
		spread_r = lerpf(0.0, float(pose["spread_r"]), w)
		torso_x = lerpf(torso_x, float(pose["torso"]), w)

	# La postura base se suaviza; EL GOLPE NO.
	#
	# Antes el golpe entraba en el mismo lerp, y como el suavizado persigue un objetivo
	# que ya esta decayendo, el brazo nunca terminaba de extenderse: se veia un empujon
	# timido en vez de un golpe. Ahora la pose se suaviza y el golpe se SUMA encima,
	# con una curva que sale rapido y vuelve lento.
	_sm_arm_l = lerp_angle(_sm_arm_l, arm_l, delta * 16.0)
	_sm_arm_r = lerp_angle(_sm_arm_r, arm_r, delta * 16.0)
	_sm_spread_l = lerp_angle(_sm_spread_l, spread_l, delta * 12.0)
	_sm_spread_r = lerp_angle(_sm_spread_r, spread_r, delta * 12.0)
	_sm_elbow_l = lerp_angle(_sm_elbow_l, elbow_l, delta * 14.0)
	_sm_elbow_r = lerp_angle(_sm_elbow_r, elbow_r, delta * 14.0)

	var punch_curve := _punch_curve()
	_shoulder_l.rotation.x = _sm_arm_l
	_shoulder_r.rotation.x = _sm_arm_r + punch_curve * PUNCH_REACH
	_shoulder_l.rotation.z = _sm_spread_l
	_shoulder_r.rotation.z = _sm_spread_r
	_elbow_l.rotation.x = _sm_elbow_l
	# El codo se ESTIRA al golpear (hacia 0), no se dobla.
	_elbow_r.rotation.x = _sm_elbow_r + punch_curve * 0.55

	# --- Rebote, respiracion y sacudida al recibir un golpe ---
	var bob := absf(sin(_cycle)) * BOB_HEIGHT * amount if moving else sin(_idle * 1.8) * 0.012
	_root.position.y = bob
	_torso.rotation.x = lerpf(_torso.rotation.x, torso_x - punch_curve * 0.20, delta * 14.0)
	# El torso gira llevando el hombro derecho al frente: es lo que convierte un brazo
	# que se levanta en un golpe con cuerpo atras.
	_torso.rotation.y = lerpf(_torso.rotation.y, -punch_curve * 0.38, delta * 18.0)
	# El golpe recibido comprime el cuerpo un instante: se lee incluso de lejos.
	var punch_scale := 1.0 + _hit_t * 0.12
	# LA PROPORCION SE MULTIPLICA, no se asigna.
	#
	# Esta linea ya la usaba el sacudon del golpe, que estira y encoge el cuerpo en cada
	# impacto. Poner la proporcion del personaje con un scale aparte la pisaria una vez
	# por frame; multiplicandola, las dos cosas conviven.
	# Y el aterrizaje ACHATA: mas ancho y mas bajo. Es el unico momento en que el cuerpo
	# se deforma en la direccion contraria al golpe, y es lo que le da peso a la caida.
	var aterriza := _aterrizaje_t * _aterrizaje_t
	_root.scale = Vector3(
		punch_scale + aterriza * 0.16,
		1.0 + _hit_t * 0.05 - aterriza * 0.20,
		punch_scale + aterriza * 0.16) * build_scale
	# --- INCLINACION AL GIRAR Y AL CORRER ---
	#
	# Es lo que mas separa un cuerpo vivo de un maniqui que se desliza. Una persona que
	# dobla corriendo se INCLINA HACIA ADENTRO de la curva —tiene que hacerlo, o se cae— y
	# una que acelera se tira hacia adelante. Sin esto el personaje gira como una torreta:
	# el cuerpo perfectamente vertical mientras la direccion cambia debajo.
	#
	# El giro se mide del cuerpo y no del mouse a proposito: asi vale igual para los bots
	# y para los otros jugadores, cuya rotacion llega replicada. Si saliera del control
	# local, el unico que se inclinaria seria el que esta jugando.
	var yaw := _body.rotation.y
	# wrapf y no una resta pelada: al cruzar de +PI a -PI la resta da un salto de 2PI y el
	# cuerpo se tira de costado un frame, que se ve como un tiron.
	var giro := wrapf(yaw - _yaw_previo, -PI, PI) / maxf(delta, 0.0001)
	_yaw_previo = yaw
	_giro_suave = lerpf(_giro_suave, clampf(giro, -7.0, 7.0), delta * 7.0)

	# Y tambien inclina al moverse de costado, que es cuando el cuerpo no gira pero el
	# peso igual se va para un lado.
	var lateral := Vector3(_body.velocity.x, 0.0, _body.velocity.z).dot(
		_body.global_transform.basis.x)
	var banqueo := clampf(_giro_suave * 0.050 + lateral * 0.016, -0.26, 0.26)
	# Solo si se esta moviendo: girar parado es mirar alrededor, no doblar una curva.
	_root.rotation.z = lerpf(_root.rotation.z, banqueo * clampf(amount, 0.0, 1.0), delta * 9.0)
	# Hacia adelante al correr. Poco: pasado de rosca el personaje parece que se cae.
	_root.rotation.x = lerpf(_root.rotation.x, -0.085 * clampf(speed / 8.0, 0.0, 1.0), delta * 6.0)

	_animate_face(delta)
	# Y la cabeza mira levemente hacia donde va.
	_head_pivot.rotation.x = lerpf(_head_pivot.rotation.x, 0.08 * amount, delta * 6.0)


## Angulos objetivo de cada pose. Los valores salen de la regla del encabezado:
## +PI/2 es al frente, +PI es arriba.
func _pose_targets() -> Dictionary:
	match _pose:
		&"channel_up":
			# Snowgrave: los dos brazos al cielo, torso arqueado hacia atras.
			# Es la pose mas legible posible de "esta cargando algo grande".
			return {
				"arm_l": 2.85, "arm_r": 2.85,
				"elbow_l": -0.25, "elbow_r": -0.25,
				"spread_l": 0.35, "spread_r": -0.35,
				"torso": 0.16,
			}
		&"channel_point":
			# ZA WARUDO: brazo derecho arriba, izquierdo cruzado sobre el pecho.
			return {
				"arm_l": 1.30, "arm_r": 2.95,
				"elbow_l": -1.25, "elbow_r": -0.15,
				"spread_l": -0.75, "spread_r": -0.20,
				"torso": 0.10,
			}
		&"embiste":
			# EMBISTIENDO: torso volcado al frente y los dos brazos tirados hacia atras,
			# como quien se lanza de cabeza. Es la silueta de alguien que dejo de
			# caminar y se tiro, que es justo lo que no se veia: el cuerpo se movia a
			# treinta metros por segundo con la pose de estar parado.
			return {
				"arm_l": -0.95, "arm_r": -0.95,
				"elbow_l": -0.30, "elbow_r": -0.30,
				"spread_l": -0.35, "spread_r": 0.35,
				"torso": -0.55,
			}
		&"impacto":
			# EL CHOQUE: torso arqueado hacia atras y brazos arriba y abiertos. Es la
			# pose opuesta a la de embestir, y esa inversion es lo que hace que el golpe
			# se lea como un choque y no como que el cuerpo se detuvo.
			return {
				"arm_l": 2.30, "arm_r": 2.30,
				"elbow_l": -0.55, "elbow_r": -0.55,
				"spread_l": 0.85, "spread_r": -0.85,
				"torso": 0.62,
			}
		&"salto":
			# SUBIENDO: brazos arriba y el cuerpo recogido. Es un impulso.
			return {
				"arm_l": 2.30, "arm_r": 2.30,
				"elbow_l": -0.70, "elbow_r": -0.70,
				"spread_l": 0.30, "spread_r": -0.30,
				"torso": -0.12,
			}
		&"caida":
			# CAYENDO: brazos abiertos y afuera, buscando el piso.
			return {
				"arm_l": 1.15, "arm_r": 1.15,
				"elbow_l": -0.20, "elbow_r": -0.20,
				"spread_l": 0.95, "spread_r": -0.95,
				"torso": 0.14,
			}
		&"dolor":
			# RECIBIENDO: el cuerpo se cierra sobre si mismo y los brazos se meten hacia
			# adentro. Es lo contrario de cualquier pose de ataque, y por eso se lee como
			# que te pegaron aunque dure tres decimas.
			return {
				"arm_l": 0.55, "arm_r": 0.55,
				"elbow_l": -1.15, "elbow_r": -1.15,
				"spread_l": -0.55, "spread_r": 0.55,
				"torso": 0.42,
			}
		&"release":
			# Al soltar: los dos brazos al frente, torso volcado hacia adelante.
			return {
				"arm_l": 1.45, "arm_r": 1.45,
				"elbow_l": 0.10, "elbow_r": 0.10,
				"spread_l": 0.25, "spread_r": -0.25,
				"torso": -0.30,
			}
		_:
			return {
				"arm_l": 0.0, "arm_r": 0.0,
				"elbow_l": -0.15, "elbow_r": -0.15,
				"spread_l": 0.0, "spread_r": 0.0,
				"torso": 0.0,
			}


## Una embestida acaba de conectar. Lo llama Player cuando el servidor lo avisa.
func golpe_de_embestida() -> void:
	_impacto_t = 1.0
	# _hit_t SI —es el temblor del cuerpo— pero _attack_t NO.
	#
	# Probe sumarle tambien el sacudon de golpe y era contradictorio: ese sacudon lanza
	# un brazo hacia ADELANTE, justo contra el retroceso que la pose esta haciendo, y las
	# dos poses de la embestida terminaban pareciendose entre si. Un choque no es un
	# puñetazo: el cuerpo no ataca, lo frenan.
	_hit_t = 1.0


## Curva del golpe: 0 -> 1 -> 0, con la salida mucho mas rapida que la vuelta.
## El pow(p, 0.55) adelanta el pico al primer tercio del movimiento.
func _punch_curve() -> float:
	if _attack_t <= 0.0:
		return 0.0
	var p := clampf(1.0 - _attack_t, 0.0, 1.0)
	# ANTICIPACION: el primer 18% del movimiento va hacia ATRAS, no hacia adelante.
	#
	# Es el truco mas viejo de la animacion y el que mas cambia acá: un brazo que sale
	# disparado sin cargar se lee como un teletransporte. Con el tironcito previo, el
	# ojo ve la intencion y el golpe pega mas fuerte sin cambiarle un punto de daño.
	if p < 0.18:
		return -0.32 * sin(PI * (p / 0.18))
	var q := (p - 0.18) / 0.82
	return sin(PI * pow(q, 0.55))


func play_attack() -> void:
	_attack_t = 1.0


func _on_ability_used(_index: int) -> void:
	# Las habilidades con canalizado ya tienen su pose; no queremos que ademas
	# tiren un puñetazo encima.
	if _pose == &"" and _release_t <= 0.0:
		play_attack()


## OJO con la firma: channel_started emite (index, duration). Si declaras un solo
## parametro, Godot falla al invocar el callback y te quedas sin pose ni efecto, en
## silencio salvo un ERROR en consola.
func _on_channel_started(index: int, _duration: float) -> void:
	var ability := _caster.get_ability(index) if _caster != null else null
	if ability == null:
		return
	_attack_t = 0.0
	match ability.id:
		&"za_warudo":
			_pose = &"channel_point"
		_:
			_pose = &"channel_up"
	_channel_fx = FX.spawn_channel_ritual(self, ability.icon_color)

	# OMEGA FLOWERY: la transformacion va DURANTE el canalizado, no despues.
	#
	# En el original, Flowery llama a las otras seis flores y recien entonces revienta.
	# Si la luz arcoiris apareciera junto con el estallido, el rival no tendria el
	# segundo de aviso que hace que un ultimate canalizado sea justo.
	if ability.id == &"last_jarona":
		# El canalizado mas el estallido: la forma se queda un rato despues de soltar.
		OmegaForm.create(self, ability.channel_time + 1.4)


func _on_channel_finished(_index: int) -> void:
	_clear_channel_fx()
	# Pose de descarga, que despues se disuelve sola.
	_pose = &"release"
	_release_t = 1.0
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func() -> void:
		if _pose == &"release":
			_pose = &""
	)


func _on_channel_cancelled(_index: int) -> void:
	_clear_channel_fx()
	_pose = &""


func _clear_channel_fx() -> void:
	if is_instance_valid(_channel_fx):
		_channel_fx.queue_free()
	_channel_fx = null


func _on_health_changed(current: float, _max_value: float) -> void:
	_last_health = current


## Un golpe que conecto. Tres cosas distintas para tres publicos:
##   - el numero y el respingo los ve TODO el mundo (pasa algo, y a quien);
##   - el anillo de impacto marca el punto exacto;
##   - el temblor lo siente SOLO el que pego.
func _on_damaged(amount: float, source_id: int) -> void:
	if amount <= 0.01:
		return
	_hit_t = 1.0
	# Los golpes que valen la pena tambien cambian la POSE, no solo tiemblan. El umbral
	# existe para que un raspon de 2 no te doble en dos.
	if amount >= 8.0:
		_dolor_t = 1.0
	var punto := global_position + Vector3.UP * 1.25
	FX.spawn_damage_number(self, global_position + Vector3.UP * 1.9, amount, amount >= 90.0)

	var color := Color(1.0, 0.62, 0.45) if amount < 90.0 else Color(1.0, 0.85, 0.4)
	FX.spawn_hit_impact(self, punto, amount, color)

	if source_id == Net.local_id() and source_id != _peer_id_del_cuerpo():
		FX.hit_feedback_for_attacker(amount)


## El peer del jugador al que pertenece este visual. Sirve para no temblar cuando el
## golpe te lo pegaste a vos mismo (dummies, daño de entorno).
func _peer_id_del_cuerpo() -> int:
	if is_instance_valid(_body):
		return int(_body.get("peer_id"))
	return 0


# --------------------------------------------------------------- Construccion

func _build_rig() -> void:
	_mat_body = Art.toon(body_color, OUTLINE_WIDTH)
	_mat_accent = Art.toon(accent_color, OUTLINE_WIDTH, 0.45)
	_mat_skin = Art.toon(skin_color, OUTLINE_WIDTH)
	_mat_dark = Art.toon(trouser_color, OUTLINE_WIDTH)

	_root = Node3D.new()
	add_child(_root)

	_hips = Node3D.new()
	_hips.position = Vector3(0.0, 0.95, 0.0)
	_root.add_child(_hips)

	# --- Torso: pivote aparte de la malla, asi inclinarlo no deforma nada ---
	_torso = Node3D.new()
	_torso.position = Vector3(0.0, 0.0, 0.0)
	_hips.add_child(_torso)

	_torso_mesh = Art.capsule(0.225, 0.62, _mat_body, Vector3(0.0, 0.31, 0.0))
	# Torso ligeramente aplastado en Z: un cuerpo no es un cilindro.
	_torso_mesh.scale = Vector3(1.0, 1.0, 0.82)
	_torso.add_child(_torso_mesh)
	# Pecho mas ancho arriba, para que los hombros existan.
	var chest := Art.capsule(0.20, 0.34, _mat_body, Vector3(0.0, 0.50, 0.0))
	chest.scale = Vector3(1.55, 1.0, 0.8)
	_torso.add_child(chest)
	# Cintura.
	var belt := Art.box(Vector3(0.40, 0.12, 0.26), _mat_dark, Vector3(0.0, 0.02, 0.0))
	_torso.add_child(belt)

	# --- Cabeza ---
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0.0, 0.70, 0.0)
	_torso.add_child(_head_pivot)
	_neck_mesh = Art.capsule(0.06, 0.14, _mat_skin, Vector3(0.0, -0.05, 0.0))
	_head_pivot.add_child(_neck_mesh)
	# Cabeza apenas ovalada, no una pelota.
	var head := Art.sphere(0.20, _mat_skin, Vector3(0.0, 0.11, 0.0))
	head.scale = Vector3(0.95, 1.08, 0.95)
	_head_pivot.add_child(head)
	_head_mesh = head
	_build_face()

	# --- Brazos ---
	_shoulder_l = _make_arm(-1.0)
	_elbow_l = _shoulder_l.get_child(1) as Node3D
	_shoulder_r = _make_arm(1.0)
	_elbow_r = _shoulder_r.get_child(1) as Node3D

	# --- Piernas ---
	_hip_l = _make_leg(-1.0)
	_knee_l = _hip_l.get_child(1) as Node3D
	_hip_r = _make_leg(1.0)
	_knee_r = _hip_r.get_child(1) as Node3D

	_build_frost()


## Cara. Dos puntos negros alcanzan para saber hacia donde mira alguien, pero no para
## que parezca una persona: sin cejas ni boca la cabeza sigue siendo una pelota.
##
## Todo va con material sin luz (Art.flat): una cara tiene que leerse igual este en
## sombra o iluminada de frente. Si la sombreas, a contraluz desaparece.
func _build_face() -> void:
	var sclera := Art.flat(Color(0.97, 0.97, 1.0))
	var dark := Art.flat(Color(0.06, 0.07, 0.12))

	for side: float in [-1.0, 1.0]:
		# Pivote por ojo: escalarlo en Y es lo que hace el parpadeo y el entrecerrar.
		var eye := Node3D.new()
		eye.position = Vector3(0.076 * side, 0.128, -0.150)
		_head_pivot.add_child(eye)

		var white := Art.sphere(0.050, sclera)
		white.scale = Vector3(0.92, 1.18, 0.42)
		eye.add_child(white)

		var pupil := Art.sphere(0.027, dark, Vector3(0.0, 0.004, -0.028))
		pupil.scale = Vector3(1.0, 1.25, 0.6)
		eye.add_child(pupil)

		# Brillo: el punto blanco arriba a un costado es lo que hace que un ojo se vea
		# vivo en vez de muerto.
		eye.add_child(Art.sphere(0.011, sclera, Vector3(-0.014 * side, 0.020, -0.044)))

		if side < 0.0:
			_eye_l = eye
		else:
			_eye_r = eye

		# Ceja: un pivote aparte para poder inclinarla segun el estado de animo.
		var brow_pivot := Node3D.new()
		brow_pivot.position = Vector3(0.076 * side, 0.196, -0.150)
		_head_pivot.add_child(brow_pivot)
		var brow := Art.box(Vector3(0.068, 0.017, 0.026), dark)
		brow_pivot.add_child(brow)
		if side < 0.0:
			_brow_l = brow_pivot
		else:
			_brow_r = brow_pivot

	# Nariz.
	var nose := Art.box(Vector3(0.028, 0.030, 0.040), _mat_skin, Vector3(0.0, 0.078, -0.184))
	_head_pivot.add_child(nose)

	# Boca: un pivote para poder abrirla al recibir un golpe.
	_mouth = Node3D.new()
	_mouth.position = Vector3(0.0, 0.030, -0.180)
	_head_pivot.add_child(_mouth)
	_mouth_mesh = Art.box(Vector3(0.052, 0.018, 0.026), dark)
	_mouth.add_child(_mouth_mesh)

	_blink_wait = randf_range(2.0, 4.5)


## Cejas y boca segun el personaje. Es lo que separa "cara generica" de "ese personaje":
## la misma geometria con las cejas al reves ya cuenta otra cosa.
func _apply_expression(brow_tilt: float, brow_height: float, mouth_width: float) -> void:
	if _brow_l == null or _brow_r == null:
		return
	_brow_tilt = brow_tilt
	_brow_l.position.y = 0.196 + brow_height
	_brow_r.position.y = 0.196 + brow_height
	if _mouth_mesh != null:
		var mesh := _mouth_mesh.mesh as BoxMesh
		if mesh != null:
			mesh.size = Vector3(mouth_width, 0.018, 0.026)


## Parpadeo, entrecerrar al recibir un golpe, y cejas fruncidas mientras canaliza.
func _animate_face(delta: float) -> void:
	if _eye_l == null:
		return

	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_wait = randf_range(2.0, 5.0)
		_blink_t = 0.13
	_blink_t = maxf(0.0, _blink_t - delta)

	var openness := 0.10 if _blink_t > 0.0 else 1.0
	# Al recibir un golpe se entrecierran los ojos.
	openness = minf(openness, 1.0 - _hit_t * 0.75)
	_eye_l.scale.y = openness
	_eye_r.scale.y = openness

	# Cejas: hacia adentro y abajo cuando esta canalizando o recien golpeado.
	var intensity := maxf(_pose_weight, _hit_t)
	var tilt := _brow_tilt + intensity * 0.55
	_brow_l.rotation.z = lerp_angle(_brow_l.rotation.z, -tilt, delta * 10.0)
	_brow_r.rotation.z = lerp_angle(_brow_r.rotation.z, tilt, delta * 10.0)

	# La boca se abre al recibir un golpe.
	if _mouth != null:
		var open := 1.0 + _hit_t * 2.6
		_mouth.scale = Vector3(1.0 - _hit_t * 0.25, open, 1.0)


func _make_arm(side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(0.29 * side, 0.50, 0.0)
	_torso.add_child(shoulder)

	shoulder.add_child(Art.capsule(0.072, 0.32, _mat_body, Vector3(0.0, -0.16, 0.0)))

	var elbow := Node3D.new()
	elbow.position = Vector3(0.0, -0.32, 0.0)
	shoulder.add_child(elbow)
	elbow.add_child(Art.capsule(0.064, 0.28, _mat_skin, Vector3(0.0, -0.14, 0.0)))
	# Mano: una caja redondeada lee mejor que una esfera, que parece una pelota pegada.
	var hand := Art.box(Vector3(0.12, 0.14, 0.10), _mat_skin, Vector3(0.0, -0.31, 0.0))
	elbow.add_child(hand)
	return shoulder


func _make_leg(side: float) -> Node3D:
	var hip := Node3D.new()
	hip.position = Vector3(0.12 * side, -0.02, 0.0)
	_hips.add_child(hip)

	hip.add_child(Art.capsule(0.092, 0.40, _mat_dark, Vector3(0.0, -0.20, 0.0)))

	var knee := Node3D.new()
	knee.position = Vector3(0.0, -0.40, 0.0)
	hip.add_child(knee)
	knee.add_child(Art.capsule(0.078, 0.38, _mat_dark, Vector3(0.0, -0.19, 0.0)))
	knee.add_child(Art.box(Vector3(0.155, 0.10, 0.27), _mat_accent, Vector3(0.0, -0.41, -0.05)))
	return hip


func _build_frost() -> void:
	_frost = CPUParticles3D.new()
	_frost.emitting = false
	_frost.amount = 40
	_frost.lifetime = 1.2
	_frost.direction = Vector3.UP
	_frost.spread = 30.0
	_frost.initial_velocity_min = 0.3
	_frost.initial_velocity_max = 1.2
	_frost.gravity = Vector3(0.0, -0.6, 0.0)
	_frost.scale_amount_min = 0.03
	_frost.scale_amount_max = 0.11
	_frost.color = Art.ICE
	_frost.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_frost.emission_sphere_radius = 0.5
	_frost.position = Vector3(0.0, 1.0, 0.0)
	add_child(_frost)


# ------------------------------------------------------------------ Personaje

func apply_character(data: CharacterData) -> void:
	if data == null:
		return
	body_color = data.body_color
	accent_color = data.accent_color
	skin_color = data.skin_color
	trouser_color = data.trouser_color
	build_scale = data.build_scale

	_mat_body.albedo_color = body_color
	_mat_accent.albedo_color = accent_color
	_mat_accent.emission = accent_color
	_mat_skin.albedo_color = skin_color
	_mat_dark.albedo_color = trouser_color

	_build_costume(data.silhouette)


## Lo que distingue a un personaje de otro a 20 metros. Es lo mas importante que
## dibujamos: en una pelea no ves colores, ves siluetas.
func _build_costume(kind: StringName) -> void:
	for node: Node3D in _costume:
		if is_instance_valid(node):
			node.queue_free()
	_costume.clear()
	# La cabeza vuelve a ser de piel antes de vestir a nadie. Sin esto, pasar de Sonic a
	# otro personaje —en el lobby, o por un bot rehecho— dejaba al humano con la cabeza
	# azul de pelaje, porque el cambio de material no es parte del disfraz que se borra.
	if is_instance_valid(_head_mesh):
		_head_mesh.material_override = _mat_skin
		_head_mesh.scale = Vector3(0.95, 1.08, 0.95)
	if is_instance_valid(_neck_mesh):
		_neck_mesh.material_override = _mat_skin
	if is_instance_valid(_head_pivot):
		_head_pivot.scale = Vector3.ONE

	match kind:
		&"antlers":
			_build_noelle()
		&"shoulders":
			_build_dio()
		&"petals":
			_build_flowery()
		&"labcoat":
			_build_rick()
		&"quills":
			_build_sonic()
		_:
			pass


## Flowery: el humanoide del Dark World, la forma de la Flor Dorada.
##
## LAS DOS PRIMERAS VERSIONES ESTUVIERON MAL porque las hice de memoria. La referencia
## dice, y cada punto corrige algo que yo tenia al reves:
##
##   - PIEL CHARTREUSE (verde amarillento). Yo le habia puesto piel palida, y con el pelo
##     dorado encima la cabeza entera quedaba del mismo tono: una bola amarilla sin
##     rasgos. El verde es ademas lo unico que lo separa de cualquier otro rubio.
##   - PELO DORADO TEÑIDO, CON LAS RAICES NEGRAS. Ese contraste es la mitad del
##     personaje y yo no lo tenia.
##   - FLEQUILLO APUNTANDO HACIA ARRIBA, en puntas. Yo le habia hecho una raya al
##     costado con el pelo cayendo, que es casi lo contrario.
##   - CHALECO VERDE Y NARANJA. Yo tenia verde con ribete marron.
##   - PANTALON MARRON y ZAPATOS NEGROS de vestir. Yo tenia pantalon oscuro y zapatos
##     amarillos.
##   - UNA CAMPERA NEGRA COLGADA DEL HOMBRO, que no tenia. Es lo que mas le cambia la
##     silueta: rompe la simetria y se lee de espaldas, que es como se lo ve casi toda
##     la partida.
##
## Es alto y flaco, y se viste de preppy. La flor dorada de seis petalos es su forma del
## Light World, no esta: los petalos aparecen en sus ataques, que es donde corresponden.
##
## SILUETA: vertical y angosta, con el bulto asimetrico de la campera en un hombro y las
## puntas del pelo arriba. Se separa de Noelle (astas anchas) y de Dio (hombreras
## simetricas) justamente por esa asimetria.
func _build_flowery() -> void:
	# Sonrisa ancha y cejas apenas caidas: la cordialidad que no termina de cerrar.
	_apply_expression(-0.10, 0.008, 0.082)

	var oro := Art.toon(Color(0.99, 0.80, 0.16), OUTLINE_WIDTH)
	# Las raices. Casi negro, no gris: tiene que leerse como "teñido", no como sombra.
	var raiz := Art.toon(Color(0.09, 0.09, 0.12), OUTLINE_WIDTH)
	var verde := Art.toon(Color(0.29, 0.49, 0.27), OUTLINE_WIDTH)
	var naranja := Art.toon(Color(0.93, 0.52, 0.15), OUTLINE_WIDTH)
	var campera := Art.toon(Color(0.12, 0.12, 0.16), OUTLINE_WIDTH)
	var camisa := Art.toon(Color(0.97, 0.97, 0.95), OUTLINE_WIDTH)

	# --- Pelo ---
	#
	# Medidas contra la cabeza real: esfera de radio 0.20 centrada en y=0.11, o sea
	# coronilla en 0.326 y cara en z=-0.19, con las cejas en y=0.196.

	# Raices: masa oscura que asoma por la NUCA. Va mas abajo, mas angosta y CORRIDA
	# HACIA ATRAS que la dorada.
	#
	# Lo de atras es lo que costo. Centrada como la dorada, el negro le ganaba en ancho
	# justo a la altura de las orejas —ahi la esfera dorada ya venia cerrandose y la
	# oscura estaba en su parte mas gruesa— y el personaje quedaba con dos manchas
	# negras a los costados de la cara: auriculares, no raices. Empujada 9 cm hacia
	# atras, a esa altura la tapa el dorado y solo se ve desde atras, que es donde van.
	var base := Art.sphere(0.198, raiz, Vector3(0.0, 0.148, 0.088))
	base.scale = Vector3(0.97, 0.95, 1.02)
	_costume_add(_head_pivot, base)
	# El dorado encima, un poco mas ancho y mas alto: se come todo menos esa franja.
	var teñido := Art.sphere(0.200, oro, Vector3(0.0, 0.200, 0.042))
	teñido.scale = Vector3(1.06, 0.88, 1.04)
	_costume_add(_head_pivot, teñido)

	# FLEQUILLO EN PUNTAS HACIA ARRIBA.
	#
	# CORTAS, ADELANTE Y MUY INCLINADAS. Es un flequillo peinado para arriba, no una
	# corona, y la diferencia esta toda en estos tres numeros. La primera version las
	# hizo de 30 cm, casi verticales y repartidas de oreja a oreja: el resultado era
	# literalmente una corona de rey. Un flequillo nace SOBRE LA FRENTE —en el tercio de
	# adelante—, es mas corto que la cabeza y se echa hacia adelante antes de subir.
	for i: int in range(4):
		var t := float(i) / 3.0 - 0.5
		var punta := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.055
		cono.height = 0.20 - 0.05 * absf(t) * 2.0
		punta.mesh = cono
		punta.material_override = oro
		punta.position = Vector3(t * 0.21, 0.300, -0.128)
		punta.rotation_degrees = Vector3(-40.0, 0.0, -t * 34.0)
		_costume_add(_head_pivot, punta)

	# Patillas finas por delante de la oreja: cierran el pelo contra la mandibula sin
	# hacer bulto. DORADAS y no oscuras: en negro se sumaban a la mancha de la nuca y
	# volvia el efecto orejera que la correccion de arriba acababa de sacar.
	for side: float in [-1.0, 1.0]:
		var patilla := Art.sphere(0.058, oro, Vector3(0.184 * side, 0.152, -0.042))
		patilla.scale = Vector3(0.36, 1.10, 1.00)
		_costume_add(_head_pivot, patilla)

	# --- Chaleco verde y naranja sobre la camisa blanca ---
	# El torso ya es la camisa. El chaleco es una capa por encima, abierta al frente.
	for side: float in [-1.0, 1.0]:
		var panel := Art.box(Vector3(0.17, 0.42, 0.30), verde, Vector3(0.115 * side, 0.34, 0.0))
		_costume_add(_torso, panel)
	_costume_add(_torso, Art.box(Vector3(0.38, 0.40, 0.13), verde, Vector3(0.0, 0.32, 0.13)))
	for side: float in [-1.0, 1.0]:
		var hombro := Art.sphere(0.105, verde, Vector3(0.165 * side, 0.50, 0.075))
		hombro.scale = Vector3(0.85, 0.72, 1.15)
		_costume_add(_torso, hombro)

	# EL NARANJA: la franja baja y los dos bordes del frente. Es el segundo color del
	# chaleco y lo que lo despega de ser un peto verde cualquiera.
	_costume_add(_torso, Art.box(Vector3(0.42, 0.06, 0.32), naranja, Vector3(0.0, 0.135, 0.0)))
	for side: float in [-1.0, 1.0]:
		var borde := Art.box(Vector3(0.042, 0.42, 0.045), naranja,
			Vector3(0.037 * side, 0.34, -0.152))
		_costume_add(_torso, borde)

	# --- Cuello de la camisa ---
	for side: float in [-1.0, 1.0]:
		var collar := Art.box(Vector3(0.085, 0.05, 0.07), camisa,
			Vector3(0.055 * side, 0.585, -0.115))
		collar.rotation_degrees = Vector3(0.0, 0.0, -22.0 * side)
		_costume_add(_torso, collar)

	# --- LA CAMPERA NEGRA AL HOMBRO ---
	#
	# Lo que mas le cambia la silueta, y por eso vale la pena aunque sean cuatro cajas:
	# es lo unico asimetrico del personaje. De espaldas —que es como se lo ve casi toda
	# la partida— un bulto oscuro sobre un hombro se reconoce a veinte metros, mientras
	# que el color del chaleco a esa distancia ya es una mancha.
	var colgada := Art.box(Vector3(0.20, 0.30, 0.17), campera, Vector3(0.255, 0.50, 0.055))
	colgada.rotation_degrees = Vector3(0.0, 0.0, -13.0)
	_costume_add(_torso, colgada)
	# La parte que cae por la espalda, mas angosta abajo.
	var cola := Art.box(Vector3(0.155, 0.26, 0.12), campera, Vector3(0.245, 0.27, 0.115))
	cola.rotation_degrees = Vector3(0.0, 0.0, -7.0)
	_costume_add(_torso, cola)
	# Y el pliegue de arriba, que la redondea contra el hombro.
	var pliegue := Art.sphere(0.105, campera, Vector3(0.235, 0.615, 0.03))
	pliegue.scale = Vector3(0.95, 0.62, 1.05)
	_costume_add(_torso, pliegue)


## Un corazon, con dos esferas y un rombo. Es el motivo que se repite por todo el diseño
## de Dio en la Parte 3: la banda, las rodilleras, el pantalon.
func _corazon(padre: Node3D, material: StandardMaterial3D, pos: Vector3, tam: float) -> void:
	var raiz := Node3D.new()
	raiz.position = pos
	padre.add_child(raiz)
	_costume.append(raiz)
	# Los dos lobulos de arriba.
	for side: float in [-1.0, 1.0]:
		var lobulo := Art.sphere(tam * 0.52, material, Vector3(tam * 0.44 * side, tam * 0.36, 0.0))
		lobulo.scale = Vector3(1.0, 1.0, 0.45)
		raiz.add_child(lobulo)
	# Y la punta de abajo: un cuadrado girado 45 grados.
	var punta := Art.box(Vector3(tam * 1.25, tam * 1.25, tam * 0.45), material, Vector3.ZERO)
	punta.rotation_degrees = Vector3(0.0, 0.0, 45.0)
	raiz.add_child(punta)


## Rick: el viejo del guardapolvo.
##
## HECHO CONTRA LA REFERENCIA DESDE EL PRIMER INTENTO, que es lo que no hice con los
## otros tres:
##
##   - Alto y FLACO, con las extremidades finas.
##   - Pelo CELESTE GRISACEO, salvaje y en puntas, con ENTRADAS: la coronilla despejada
##     y el pelo saliendo de los costados. Esa forma de U invertida es su silueta.
##   - UNICEJA. Una sola linea sobre los dos ojos.
##   - GUARDAPOLVO BLANCO abierto, sobre camisa celeste.
##   - Pantalon marron con CINTO de hebilla dorada.
##   - Y las medias blancas asomando, porque el pantalon le queda corto.
##
## SILUETA: el guardapolvo abierto le da dos faldones rectos que cuelgan y no se mueven
## como los de nadie mas. De lejos es una L blanca vertical, que no se parece ni a las
## astas de Noelle, ni a los hombros de Dio, ni a la campera al hombro de Flowery.
func _build_rick() -> void:
	# Cejas bajas y rectas, boca chica y torcida: el gesto de alguien a quien todo le
	# parece una perdida de tiempo.
	_apply_expression(0.06, -0.010, 0.050)

	var pelo := Art.toon(Color(0.66, 0.80, 0.86), OUTLINE_WIDTH)
	var guardapolvo := Art.toon(Color(0.95, 0.96, 0.97), OUTLINE_WIDTH)
	var cinto := Art.toon(Color(0.28, 0.19, 0.12), OUTLINE_WIDTH)
	var hebilla := Art.toon(Color(0.85, 0.70, 0.25), OUTLINE_WIDTH)

	# --- Pelo: tupe arriba, entradas ATRAS ---
	#
	# LO TENIA AL REVES. La primera version puso la masa de pelo en la nuca y dejo la
	# coronilla pelada, y el resultado era un calvo con una cresta detras. La referencia
	# dice lo contrario: un TUPE que cubre la parte de arriba y adelante, y la pelada en
	# la NUCA. Es la diferencia entre Rick y un punk.
	# ARRIBA Y CORRIDO HACIA ATRAS. Centrado y bajo, la esfera del tupe baja hasta y=0.087
	# y le tapa los ojos, que estan en 0.128. Es la tercera vez que cometo ese error en
	# este archivo —ya me habia pasado con Flowery y con Noelle— asi que van las cuentas:
	# los ojos estan en y=0.128 y las cejas en y=0.196, y el borde de abajo del pelo tiene
	# que quedar POR ENCIMA de 0.196 en la parte de adelante.
	var tupe := Art.sphere(0.196, pelo, Vector3(0.0, 0.255, 0.015))
	tupe.scale = Vector3(1.04, 0.72, 0.95)
	_costume_add(_head_pivot, tupe)

	# Las puntas salen del tupe hacia arriba y ATRAS, no hacia adelante: es pelo sin
	# peinar que se fue para atras solo, no un flequillo.
	for i: int in range(7):
		var t := float(i) / 6.0 - 0.5
		var punta := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.052
		# Mas largas en el medio: un abanico parejo se lee como una corona.
		cono.height = 0.30 - absf(t) * 0.26
		punta.mesh = cono
		punta.material_override = pelo
		punta.position = Vector3(t * 0.30, 0.345, 0.010 + absf(t) * 0.022)
		punta.rotation_degrees = Vector3(26.0, 0.0, -t * 58.0)
		_costume_add(_head_pivot, punta)

	# Patillas finas por delante de la oreja. Chicas: anchas se leen como orejeras, que
	# es lo que me paso con Flowery y con Noelle.
	for side: float in [-1.0, 1.0]:
		var patilla := Art.sphere(0.044, pelo, Vector3(0.180 * side, 0.168, -0.030))
		patilla.scale = Vector3(0.36, 0.95, 0.78)
		_costume_add(_head_pivot, patilla)

	# --- LA UNICEJA ---
	#
	# Una sola barra sobre los dos ojos. _build_face ya dibujo dos cejas separadas a
	# y=0.196, asi que esta va apenas mas adelante y las tapa: es mas barato que rehacer
	# la cara y deja la expresion animada funcionando igual.
	#
	# Va PEGADA A LA CARA y fina. La primera version era gruesa y a la altura del
	# nacimiento del pelo, y ahi arriba no se leia como ceja sino como vincha.
	var uniceja := Art.box(Vector3(0.205, 0.019, 0.028),
		Art.flat(Color(0.56, 0.68, 0.76)), Vector3(0.0, 0.188, -0.176))
	_costume_add(_head_pivot, uniceja)

	# --- Guardapolvo ABIERTO ---
	# Espalda entera y dos solapas al frente, separadas: por el medio se ve la camisa
	# celeste, que es lo que lo lee como abierto y no como un mameluco blanco.
	_costume_add(_torso, Art.box(Vector3(0.42, 0.46, 0.13), guardapolvo, Vector3(0.0, 0.34, 0.13)))
	for side: float in [-1.0, 1.0]:
		_costume_add(_torso, Art.box(Vector3(0.15, 0.46, 0.30), guardapolvo,
			Vector3(0.135 * side, 0.34, 0.0)))
		var hombro := Art.sphere(0.108, guardapolvo, Vector3(0.168 * side, 0.50, 0.06))
		hombro.scale = Vector3(0.88, 0.76, 1.12)
		_costume_add(_torso, hombro)
		# Faldon: baja por debajo de la cintura y es lo que lo hace alto de lejos.
		var faldon := Art.box(Vector3(0.155, 0.30, 0.16), guardapolvo,
			Vector3(0.145 * side, 0.02, 0.055))
		_costume_add(_torso, faldon)

	# Cuello del guardapolvo.
	for side: float in [-1.0, 1.0]:
		var solapa := Art.box(Vector3(0.10, 0.06, 0.08), guardapolvo,
			Vector3(0.062 * side, 0.578, -0.108))
		solapa.rotation_degrees = Vector3(0.0, 0.0, -26.0 * side)
		_costume_add(_torso, solapa)

	# --- Cinto marron con hebilla dorada ---
	_costume_add(_torso, Art.box(Vector3(0.44, 0.070, 0.30), cinto, Vector3(0.0, 0.085, 0.0)))
	_costume_add(_torso, Art.box(Vector3(0.085, 0.062, 0.32), hebilla, Vector3(0.0, 0.085, -0.02)))

	# --- Medias blancas ---
	# El pantalon le queda corto y se le ven: es un detalle chico y es de los que mas
	# dicen del personaje, porque nadie mas del juego tiene la ropa mal puesta.
	var media := Art.toon(Color(0.93, 0.93, 0.90), OUTLINE_WIDTH)
	for rodilla: Node3D in [_knee_l, _knee_r]:
		if is_instance_valid(rodilla):
			_costume_add(rodilla, Art.capsule(0.082, 0.13, media, Vector3(0.0, -0.335, 0.0)))


## Noelle: chica reno. Silueta alta y angosta, con el peso arriba.
##
## REHECHA CONTRA LA REFERENCIA. La primera version la arme de memoria y le puse pelo
## pelirrojo, un vestido verde liso y piel de persona. La referencia dice:
##
##   - Monstruo RENO de pelaje claro, NARIZ ROJA —el guiño a Rudolph, y el rasgo que
##     mas la identifica—, pecas y astas chicas.
##   - Pelo RUBIO DORADO y largo.
##   - SUETER A CUADROS ROJO Y VERDE con escote en V y MANGAS NEGRAS, sobre una CAMISA
##     BLANCA, y POLLERA NEGRA.
##
## Se eligio su ropa de siempre y no la capa blanca del Dark World por dos razones: el
## cuadrille rojo y verde se reconoce a veinte metros y una capa blanca no, y ademas una
## capa blanca se perderia entre sus propios efectos de hielo, que son todos blancos.
func _build_noelle() -> void:
	# Cejas altas y casi rectas, boca chica: lee como timida y preocupada, que es
	# exactamente Noelle.
	_apply_expression(-0.06, 0.012, 0.044)

	var pelo := Art.toon(Color(0.96, 0.84, 0.44), OUTLINE_WIDTH)
	var rojo := Art.toon(Color(0.72, 0.17, 0.19), OUTLINE_WIDTH)
	var verde := Art.toon(Color(0.16, 0.44, 0.25), OUTLINE_WIDTH)
	var negro := Art.toon(Color(0.14, 0.14, 0.18), OUTLINE_WIDTH)

	# --- Pelo rubio: casquete, melena y flequillo ---
	var cap := Art.sphere(0.212, pelo, Vector3(0.0, 0.14, 0.015))
	cap.scale = Vector3(1.02, 1.02, 1.02)
	_costume_add(_head_pivot, cap)
	var strands: Array = [
		{"pos": Vector3(0.0, -0.02, 0.15), "size": Vector3(0.26, 0.40, 0.16), "rot": -6.0},
		{"pos": Vector3(-0.15, -0.06, 0.12), "size": Vector3(0.14, 0.34, 0.14), "rot": -10.0},
		{"pos": Vector3(0.15, -0.06, 0.12), "size": Vector3(0.14, 0.34, 0.14), "rot": -10.0},
	]
	for strand: Dictionary in strands:
		var piece := Art.capsule(float(strand["size"].x) * 0.5, float(strand["size"].y), pelo, strand["pos"])
		piece.rotation_degrees = Vector3(float(strand["rot"]), 0.0, 0.0)
		_costume_add(_head_pivot, piece)
	# FLEQUILLO REDONDEADO Y POR ENCIMA DE LAS CEJAS.
	#
	# Era una caja plana a y=0.21 y le cruzaba la cara justo a la altura de los ojos:
	# de frente se le veia una tabla amarilla y dos ojos asomando abajo. Es el mismo
	# error que ya habia cometido con Flowery. Las cejas estan en y=0.196, asi que el
	# pelo tiene que nacer por encima de eso, y una esfera achatada no tiene el canto
	# recto que delataba a la caja.
	var flequillo := Art.sphere(0.125, pelo, Vector3(0.0, 0.268, -0.118))
	flequillo.scale = Vector3(1.58, 0.62, 0.78)
	_costume_add(_head_pivot, flequillo)

	# --- LA NARIZ ROJA ---
	#
	# Es lo que mas la identifica y no estaba. Va encima de la nariz de piel que dibuja
	# _build_face, un poco mas grande, para taparla entera.
	var nariz := Art.sphere(0.036, Art.toon(Color(0.86, 0.18, 0.16), OUTLINE_WIDTH),
		Vector3(0.0, 0.078, -0.196))
	nariz.scale = Vector3(1.15, 1.0, 1.1)
	_costume_add(_head_pivot, nariz)

	# Pecas: tres por mejilla. Chiquitas, pero en los primeros planos del lobby se ven.
	var peca := Art.toon(Color(0.80, 0.60, 0.46), 0.0)
	for side: float in [-1.0, 1.0]:
		for i: int in range(3):
			var f := float(i)
			_costume_add(_head_pivot, Art.sphere(0.011, peca,
				Vector3((0.115 + f * 0.030) * side, 0.072 - f * 0.014, -0.176)))

	# --- Astas: tres segmentos por lado, en angulos distintos ---
	var antler := Art.toon(Color(0.95, 0.92, 0.85), OUTLINE_WIDTH)
	for side: float in [-1.0, 1.0]:
		var base := Node3D.new()
		base.position = Vector3(0.10 * side, 0.26, 0.0)
		base.rotation_degrees = Vector3(-12.0, 0.0, -22.0 * side)
		_head_pivot.add_child(base)
		_costume.append(base)
		base.add_child(Art.capsule(0.030, 0.28, antler, Vector3(0.0, 0.14, 0.0)))
		var tip := Node3D.new()
		tip.position = Vector3(0.0, 0.28, 0.0)
		tip.rotation_degrees = Vector3(0.0, 0.0, -20.0 * side)
		base.add_child(tip)
		tip.add_child(Art.capsule(0.024, 0.22, antler, Vector3(0.0, 0.11, 0.0)))
		# Punta lateral: es lo que hace que se lea como asta y no como cuerno.
		var branch := Art.capsule(0.020, 0.16, antler, Vector3(0.045 * side, 0.08, 0.0))
		branch.rotation_degrees = Vector3(0.0, 0.0, -45.0 * side)
		tip.add_child(branch)

	# --- EL SUETER A CUADROS ---
	#
	# Un cuadrille no se puede pintar con un material solo, asi que son baldosas: cuatro
	# columnas por tres filas, alternando rojo y verde, adelante y atras.
	#
	# Van CURVADAS hacia atras en los extremos (la z crece con el cuadrado de x): puestas
	# todas en el mismo plano, las columnas de los costados se hunden en el torso, que es
	# una capsula, y el cuadrille se corta por la mitad.
	for fila: int in range(3):
		for col: int in range(4):
			var x := -0.165 + float(col) * 0.110
			var y := 0.285 + float(fila) * 0.112
			var hundido := pow(absf(x) / 0.20, 2.0) * 0.060
			var mat := rojo if (fila + col) % 2 == 0 else verde
			# Escote en V: las dos baldosas de arriba al centro quedan afuera y dejan ver
			# la camisa blanca, que es lo que hace que se lea como sueter y no como peto.
			if fila == 2 and (col == 1 or col == 2):
				continue
			_costume_add(_torso, Art.box(Vector3(0.108, 0.110, 0.08), mat,
				Vector3(x, y, -0.185 + hundido)))
			_costume_add(_torso, Art.box(Vector3(0.108, 0.110, 0.08), mat,
				Vector3(x, y, 0.185 - hundido)))

	# --- Mangas negras sobre la camisa ---
	for brazo: Node3D in [_shoulder_l, _shoulder_r]:
		if is_instance_valid(brazo):
			_costume_add(brazo, Art.capsule(0.080, 0.30, negro, Vector3(0.0, -0.15, 0.0)))

	# --- Pollera negra ---
	var skirt := MeshInstance3D.new()
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.25
	skirt_mesh.bottom_radius = 0.43
	skirt_mesh.height = 0.42
	skirt.mesh = skirt_mesh
	skirt.material_override = negro
	skirt.position = Vector3(0.0, -0.08, 0.0)
	_costume_add(_hips, skirt)
	# Vivo claro abajo: le despega el borde de las piernas, que tambien son oscuras.
	_costume_add(_hips, Art.cylinder(0.445, 0.05, Art.toon(Color(0.86, 0.87, 0.92), 0.0),
		Vector3(0.0, -0.27, 0.0)))

	# Cuello de la camisa, asomando por el escote.
	for side: float in [-1.0, 1.0]:
		var collar := Art.box(Vector3(0.10, 0.055, 0.075), Art.toon(Color(0.97, 0.97, 0.95), OUTLINE_WIDTH),
			Vector3(0.058 * side, 0.585, -0.12))
		collar.rotation_degrees = Vector3(0.0, 0.0, -24.0 * side)
		_costume_add(_torso, collar)


## Dio: silueta ancha y cuadrada, lo mas opuesto posible a Noelle.
func _build_dio() -> void:
	# Cejas bajas y muy inclinadas hacia adentro, boca ancha: ceño de superioridad.
	_apply_expression(0.42, -0.014, 0.070)
	var hair := Art.toon(Art.GOLD.lightened(0.10), OUTLINE_WIDTH)

	var cap := Art.sphere(0.212, hair, Vector3(0.0, 0.15, 0.01))
	_costume_add(_head_pivot, cap)
	# Pelo en puntas.
	var spikes: Array = [
		{"pos": Vector3(0.0, 0.33, -0.02), "rot": Vector3(-20.0, 0.0, 0.0), "len": 0.28},
		{"pos": Vector3(-0.13, 0.30, 0.03), "rot": Vector3(-8.0, 0.0, 28.0), "len": 0.24},
		{"pos": Vector3(0.13, 0.30, 0.03), "rot": Vector3(-8.0, 0.0, -28.0), "len": 0.24},
		{"pos": Vector3(0.0, 0.25, 0.17), "rot": Vector3(32.0, 0.0, 0.0), "len": 0.22},
		{"pos": Vector3(-0.09, 0.28, 0.14), "rot": Vector3(24.0, 0.0, 18.0), "len": 0.18},
		{"pos": Vector3(0.09, 0.28, 0.14), "rot": Vector3(24.0, 0.0, -18.0), "len": 0.18},
	]
	for spike: Dictionary in spikes:
		var pivot := Node3D.new()
		pivot.position = spike["pos"]
		pivot.rotation_degrees = spike["rot"]
		_head_pivot.add_child(pivot)
		_costume.append(pivot)
		pivot.add_child(Art.capsule(0.042, float(spike["len"]), hair, Vector3(0.0, float(spike["len"]) * 0.4, 0.0)))

	# --- Banda VERDE en la frente, con su corazon ---
	#
	# La tenia dorada, del mismo color que el pelo y las hombreras, asi que desaparecia.
	# En la Parte 3 la banda es verde y lleva un corazon: el corazon es EL motivo de su
	# diseño —se repite en la banda, en las rodilleras y en el pantalon— y no estaba en
	# ninguna parte. Es lo que lo separa de "un rubio de amarillo".
	var verde_dio := Art.toon(Color(0.20, 0.52, 0.32), OUTLINE_WIDTH)
	_costume_add(_head_pivot, Art.box(Vector3(0.43, 0.085, 0.43), verde_dio, Vector3(0.0, 0.20, 0.0)))
	_corazon(_head_pivot, verde_dio, Vector3(0.0, 0.205, -0.216), 0.055)

	# Hombreras. ANCHAS PERO NO ENORMES.
	#
	# Estaban en radio 0.23 escaladas a 1.3, o sea mas anchas que su propia cabeza: en
	# pantalla eran dos globos amarillos que le tapaban la cara y los brazos. La
	# referencia habla de una CAMPERA, no de una armadura. Se achicaron a la mitad y la
	# punta quedo corta: sigue leyendose ancho y cuadrado —que es lo que lo separa de
	# Noelle a veinte metros— sin parecer un jugador de futbol americano.
	for side: float in [-1.0, 1.0]:
		var pad := Art.sphere(0.145, _mat_accent, Vector3(0.245 * side, 0.545, 0.0))
		pad.scale = Vector3(1.15, 0.85, 1.05)
		_costume_add(_torso, pad)
		var spike := Art.capsule(0.032, 0.13, _mat_accent, Vector3(0.335 * side, 0.575, 0.0))
		spike.rotation_degrees = Vector3(0.0, 0.0, -52.0 * side)
		_costume_add(_torso, spike)

	# Musculosa negra debajo de la campera: la franja oscura en el medio del pecho es lo
	# que le da el contraste que el amarillo entero no tiene.
	var musculosa := Art.toon(Color(0.11, 0.11, 0.14), OUTLINE_WIDTH)
	_costume_add(_torso, Art.box(Vector3(0.17, 0.44, 0.10), musculosa, Vector3(0.0, 0.40, -0.175)))

	# Corazones en las rodilleras, el otro lugar donde el motivo se repite.
	for rodilla: Node3D in [_knee_l, _knee_r]:
		if is_instance_valid(rodilla):
			_corazon(rodilla, verde_dio, Vector3(0.0, -0.17, -0.082), 0.048)

	# Capa: dos tramos que se angostan y se separan del cuerpo. Un solo bloque plano
	# se lee como una tabla pegada a la espalda, no como tela.
	var cloth := Art.toon(Color(0.09, 0.10, 0.19), OUTLINE_WIDTH)
	var cape_top := Art.box(Vector3(0.50, 0.46, 0.07), cloth, Vector3(0.0, 0.40, 0.19))
	cape_top.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	_costume_add(_torso, cape_top)
	var cape_bottom := Art.box(Vector3(0.36, 0.44, 0.06), cloth, Vector3(0.0, 0.02, 0.27))
	cape_bottom.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	_costume_add(_torso, cape_bottom)

	# Corazon en el pecho, guiño a su diseño.
	_costume_add(_torso, Art.box(Vector3(0.13, 0.13, 0.05), Art.glow(Art.GOLD, 1.2), Vector3(0.0, 0.42, -0.17)))


## Sonic: el erizo.
##
## CONTRA LA FICHA, punto por punto, antes de dibujar nada:
##
##   - "SEIS PUAS LARGAS en la parte de atras de la cabeza". Seis, no las que queden
##     lindas: es el numero que dice la referencia y es lo que hace su silueta.
##   - "DOS ESPINAS que sobresalen de su espalda", aparte de las de la cabeza.
##   - Orejas CHICAS Y TRIANGULARES, arriba.
##   - Piel durazno en brazos, hocico, dentro de las orejas y FRENTE DEL TORSO. Esa
##     panza clara es la mitad de como se lo reconoce de frente.
##   - Guantes BLANCOS y zapatillas ROJAS.
##   - Cola corta.
##
## Y ES BAJO: mide 100 cm contra el metro setenta y pico de los otros. Por eso su
## build_scale lo achata en vez de estirarlo — al lado de Dio tiene que notarse que le
## llega al pecho.
##
## SILUETA: seis puas largas saliendo para atras en abanico. De lejos es una flecha
## apuntando hacia atras, que no se parece a las astas de Noelle, a los hombros de Dio,
## a los faldones de Rick ni a la campera de Flowery.
func _build_sonic() -> void:
	# Cejas bien inclinadas y boca ancha: el gesto canchero de alguien que llega tarde a
	# propósito.
	_apply_expression(0.30, -0.008, 0.075)

	# PELAJE, NO PIEL. La cabeza entera es azul con textura de pelo; lo unico durazno es el
	# hocico. Antes la cabeza salia del material de piel que usan los humanos, y Sonic
	# quedaba con una cara de persona color carne con puas azules pegadas atras.
	var pua := Art.pelaje(Color(0.11, 0.35, 0.78), OUTLINE_WIDTH)
	var pelo_cabeza := Art.pelaje(Color(0.13, 0.40, 0.86), OUTLINE_WIDTH)
	if is_instance_valid(_head_mesh):
		_head_mesh.material_override = pelo_cabeza
		# Un poco mas ancha que alta: la cabeza de Sonic es un ovalo acostado, no el
		# huevo parado de un humano.
		_head_mesh.scale = Vector3(1.04, 1.0, 1.0)
	if is_instance_valid(_neck_mesh):
		_neck_mesh.material_override = pelo_cabeza
	var piel := Art.toon(Color(0.99, 0.79, 0.58), OUTLINE_WIDTH)
	var guante := Art.toon(Color(0.97, 0.97, 0.98), OUTLINE_WIDTH)
	var nariz := Art.toon(Color(0.10, 0.09, 0.11), OUTLINE_WIDTH)

	# LA CABEZA MAS GRANDE. Sonic es de proporcion caricaturesca: la cabeza le ocupa como
	# un tercio del cuerpo. Con la cabeza estandar quedaba un erizo de cabeza chica, que
	# no se parece a el aunque todo lo demas este bien.
	_head_pivot.scale = Vector3.ONE * 1.22

	# --- LAS SEIS PUAS, hacia ATRAS (el frente del modelo es -Z) ---
	#
	# En abanico y con tres largos distintos: seis puas iguales se ven como un peine. Las
	# del medio son las mas largas, que es como estan en cualquier dibujo de referencia.
	# BARREN HACIA ATRAS, CASI HORIZONTALES. Estaban entre 52 y 84 grados, que las dejaba
	# casi paradas: de frente se veian como una corona de pinches sobre la cabeza y de
	# perfil como un mohawk. Las de Sonic salen de la NUCA y van para atras — ese abanico
	# horizontal es su silueta, y parado o corriendo es lo primero que se reconoce.
	#
	# 96 a 118 grados: pasado de 90 la punta queda por DEBAJO de la horizontal, que es
	# como cuelgan las de abajo en cualquier dibujo suyo. Y mas largas, porque la ficha
	# las llama "puas LARGAS" y a 0.30 eran muñones.
	var puas: Array = [
		{"pos": Vector3(0.00, 0.14, 0.15), "rot": Vector3(96.0, 0.0, 0.0), "len": 0.66},
		{"pos": Vector3(-0.10, 0.15, 0.13), "rot": Vector3(100.0, -20.0, 0.0), "len": 0.60},
		{"pos": Vector3(0.10, 0.15, 0.13), "rot": Vector3(100.0, 20.0, 0.0), "len": 0.60},
		{"pos": Vector3(-0.14, 0.05, 0.14), "rot": Vector3(112.0, -32.0, 0.0), "len": 0.50},
		{"pos": Vector3(0.14, 0.05, 0.14), "rot": Vector3(112.0, 32.0, 0.0), "len": 0.50},
		{"pos": Vector3(0.00, -0.02, 0.16), "rot": Vector3(118.0, 0.0, 0.0), "len": 0.44},
	]
	for p: Dictionary in puas:
		var pivote := Node3D.new()
		pivote.position = p["pos"]
		pivote.rotation_degrees = p["rot"]
		_head_pivot.add_child(pivote)
		_costume.append(pivote)
		var largo: float = p["len"]
		# Conos y no capsulas: una pua termina en punta. Con capsulas quedaban salchichas.
		var cono := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = 0.0
		# Mas finas en la base: una pua termina en punta y arranca angosta. A 0.075 se
		# veian como conos de trafico.
		malla.bottom_radius = 0.058
		malla.height = largo
		cono.mesh = malla
		cono.material_override = pua
		cono.position = Vector3(0.0, largo * 0.5, 0.0)
		pivote.add_child(cono)

	# --- Orejas: triangulos chicos, arriba ---
	for lado: float in [-1.0, 1.0]:
		var oreja := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.075
		m.height = 0.15
		oreja.mesh = m
		oreja.material_override = pua
		oreja.position = Vector3(0.105 * lado, 0.265, 0.02)
		oreja.rotation_degrees = Vector3(0.0, 0.0, -14.0 * lado)
		_costume_add(_head_pivot, oreja)
		# El interior durazno, que es lo que las hace orejas y no cuernitos.
		var dentro := Art.sphere(0.036, piel, Vector3(0.105 * lado, 0.245, -0.03))
		dentro.scale = Vector3(1.0, 1.3, 0.5)
		_costume_add(_head_pivot, dentro)

	# --- MECHONES: rompen la esfera lisa ---
	#
	# Una bola perfecta se lee como una cabeza de muñeco aunque tenga textura. Unos
	# mechones cortos arriba y a los costados, donde el pelo nace y se junta con las puas,
	# le dan el borde irregular que tiene cualquier cosa con pelo.
	var mechones: Array = [
		[Vector3(0.00, 0.30, 0.02), Vector3(-30.0, 0.0, 0.0), 0.12],
		[Vector3(-0.09, 0.28, 0.04), Vector3(-18.0, 0.0, 24.0), 0.10],
		[Vector3(0.09, 0.28, 0.04), Vector3(-18.0, 0.0, -24.0), 0.10],
		[Vector3(-0.18, 0.16, 0.06), Vector3(0.0, 0.0, 70.0), 0.09],
		[Vector3(0.18, 0.16, 0.06), Vector3(0.0, 0.0, -70.0), 0.09],
		[Vector3(-0.17, 0.05, 0.08), Vector3(20.0, 0.0, 95.0), 0.08],
		[Vector3(0.17, 0.05, 0.08), Vector3(20.0, 0.0, -95.0), 0.08],
	]
	for m: Array in mechones:
		var mechon := MeshInstance3D.new()
		var malla_m := CylinderMesh.new()
		malla_m.top_radius = 0.0
		malla_m.bottom_radius = 0.045
		malla_m.height = m[2]
		mechon.mesh = malla_m
		mechon.material_override = pelo_cabeza
		mechon.position = m[0]
		mechon.rotation_degrees = m[1]
		_costume_add(_head_pivot, mechon)

	# --- OJOS VERDES Y UNIDOS, como dice la ficha ---
	#
	# "Dos ojos unidos" y "verdes (antes negros)". Los ojos del rig son blancos con pupila
	# oscura, como los de cualquiera: a Sonic le falta el iris verde, y el puente blanco
	# que junta los dos en una sola mancha, que es lo mas reconocible de su cara.
	var iris := Art.flat(Color(0.20, 0.72, 0.30))
	var blanco := Art.flat(Color(0.97, 0.97, 1.0))
	for ojo: Node3D in [_eye_l, _eye_r]:
		if ojo == null:
			continue
		var anillo := Art.sphere(0.034, iris, Vector3(0.0, 0.004, -0.024))
		anillo.scale = Vector3(1.0, 1.25, 0.55)
		_costume_add(ojo, anillo)
	var puente := Art.sphere(0.052, blanco, Vector3(0.0, 0.138, -0.150))
	puente.scale = Vector3(1.25, 0.72, 0.55)
	_costume_add(_head_pivot, puente)

	# --- El hocico: ancho, abajo y bien saliente ---
	#
	# Era una bolita chica y centrada que no se leia. El hocico de Sonic es ANCHO y sale
	# bastante: de frente es media cara, y es lo que lo separa de "un tipo azul".
	var hocico := Art.sphere(0.145, piel, Vector3(0.0, -0.055, -0.155))
	hocico.scale = Vector3(1.35, 0.78, 1.0)
	_costume_add(_head_pivot, hocico)
	# Y la nariz: un punto negro arriba del hocico. Es chiquito y hace la mitad del
	# trabajo — sin el, el hocico es un bulto.
	var punta := Art.sphere(0.042, nariz, Vector3(0.0, -0.012, -0.235))
	punta.scale = Vector3(1.2, 0.9, 1.0)
	_costume_add(_head_pivot, punta)

	# --- Las DOS espinas de la espalda, aparte de las de la cabeza ---
	for i: int in range(2):
		var espina := MeshInstance3D.new()
		var m2 := CylinderMesh.new()
		m2.top_radius = 0.0
		m2.bottom_radius = 0.07
		m2.height = 0.30
		espina.mesh = m2
		espina.material_override = pua
		espina.position = Vector3(0.0, 0.16 - float(i) * 0.24, 0.20)
		espina.rotation_degrees = Vector3(72.0, 0.0, 0.0)
		_costume_add(_torso, espina)

	# --- La panza durazno, al frente ---
	#
	# Aplastada contra el pecho, no una pelota pegada encima: a 0.42 de profundidad se
	# veia como una bola aparte. Es una MANCHA de color, tiene que seguir la curva del
	# cuerpo.
	var panza := Art.sphere(0.21, piel, Vector3(0.0, -0.03, -0.135))
	panza.scale = Vector3(0.95, 1.30, 0.22)
	_costume_add(_torso, panza)

	# --- Guantes blancos ---
	#
	# Van sobre el antebrazo, en los codos: la mano del modelo es la punta de ese hueso.
	for codo: Node3D in [_elbow_l, _elbow_r]:
		if codo == null:
			continue
		var mano := Art.sphere(0.088, guante, Vector3(0.0, -0.30, 0.0))
		_costume_add(codo, mano)
		# El puño del guante, un poco mas arriba y mas ancho.
		var puño := Art.cylinder(0.078, 0.07, guante, Vector3(0.0, -0.225, 0.0))
		_costume_add(codo, puño)

	# --- La cola corta ---
	var cola := Art.sphere(0.075, pua, Vector3(0.0, -0.26, 0.17))
	cola.scale = Vector3(0.9, 0.7, 1.5)
	_costume_add(_torso, cola)

	# --- La tira blanca de las zapatillas ---
	#
	# El zapato ya sale rojo solo, porque usa el color de acento del personaje; lo que
	# falta es la correa blanca cruzada, que es lo que las vuelve LAS zapatillas de Sonic
	# y no unos zapatos rojos cualquiera.
	for rodilla: Node3D in [_knee_l, _knee_r]:
		if rodilla == null:
			continue
		var correa := Art.box(Vector3(0.17, 0.045, 0.10), guante, Vector3(0.0, -0.40, -0.11))
		_costume_add(rodilla, correa)


func _costume_add(parent: Node3D, node: MeshInstance3D) -> void:
	parent.add_child(node)
	_costume.append(node)


# --------------------------------------------------------------------- Estado

func _on_chill_changed(stacks: int) -> void:
	if _frost == null:
		return
	if stacks <= 0:
		_frost.emitting = false
		return
	_frost.emitting = true
	# CPUParticles3D no tiene amount_ratio (eso es de GPUParticles3D), movemos amount.
	var ratio := clampf(float(stacks) / float(StatusEffects.MAX_CHILL), 0.15, 1.0)
	_frost.amount = maxi(4, int(round(60.0 * ratio)))


func _on_froze() -> void:
	if _freeze_shell == null:
		_freeze_shell = FX.spawn_freeze_shell(self)
	if _frost != null:
		_frost.emitting = false


func _on_unfroze() -> void:
	if is_instance_valid(_freeze_shell):
		_freeze_shell.queue_free()
	_freeze_shell = null


func _on_stunned() -> void:
	if _time_marker == null:
		_time_marker = FX.spawn_time_stop_marker(self)


## El tiempo vuelve a correr: los cuchillos suspendidos se cierran y revientan.
##
## Va atado a que se termine el aturdimiento y no al ultimate, asi se sincroniza solo
## en todos los peers: el estado de aturdimiento ya se replica, el daño ya lo resolvio
## el servidor, y esto es puro visual encima.
func _on_unstunned() -> void:
	if is_instance_valid(_time_marker):
		FX.release_time_stop_marker(_time_marker, self)
	_time_marker = null


func set_dead(dead: bool) -> void:
	visible = not dead
	if dead:
		_pose = &""
		_pose_weight = 0.0
		_clear_channel_fx()
		if is_instance_valid(_freeze_shell):
			_freeze_shell.queue_free()
		_freeze_shell = null
		if is_instance_valid(_time_marker):
			_time_marker.queue_free()
		_time_marker = null


func play_dash_trail() -> void:
	var trail := CPUParticles3D.new()
	trail.emitting = true
	trail.one_shot = true
	trail.amount = 34
	trail.lifetime = 0.45
	trail.explosiveness = 0.85
	trail.direction = Vector3.UP
	trail.spread = 40.0
	trail.initial_velocity_min = 0.5
	trail.initial_velocity_max = 2.4
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.04
	trail.scale_amount_max = 0.15
	trail.color = Color(0.9, 0.97, 1.0, 0.7)
	trail.position = Vector3(0.0, 0.9, 0.0)
	add_child(trail)
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(trail):
			trail.queue_free()
	)
