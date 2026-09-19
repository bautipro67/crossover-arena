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
	_root.scale = Vector3(punch_scale, 1.0 + _hit_t * 0.05, punch_scale)
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
	_mat_dark = Art.toon(Color(0.14, 0.16, 0.25), OUTLINE_WIDTH)

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
	_head_pivot.add_child(Art.capsule(0.06, 0.14, _mat_skin, Vector3(0.0, -0.05, 0.0)))
	# Cabeza apenas ovalada, no una pelota.
	var head := Art.sphere(0.20, _mat_skin, Vector3(0.0, 0.11, 0.0))
	head.scale = Vector3(0.95, 1.08, 0.95)
	_head_pivot.add_child(head)
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

	_mat_body.albedo_color = body_color
	_mat_accent.albedo_color = accent_color
	_mat_accent.emission = accent_color
	_mat_skin.albedo_color = skin_color

	_build_costume(data.silhouette)


## Lo que distingue a un personaje de otro a 20 metros. Es lo mas importante que
## dibujamos: en una pelea no ves colores, ves siluetas.
func _build_costume(kind: StringName) -> void:
	for node: Node3D in _costume:
		if is_instance_valid(node):
			node.queue_free()
	_costume.clear()

	match kind:
		&"antlers":
			_build_noelle()
		&"shoulders":
			_build_dio()
		_:
			pass


## Noelle: chica reno. Silueta alta y angosta, con el peso arriba.
func _build_noelle() -> void:
	# Cejas altas y casi rectas, boca chica: lee como timida y preocupada, que es
	# exactamente Noelle.
	_apply_expression(-0.06, 0.012, 0.044)
	var hair := Art.toon(accent_color.darkened(0.08), OUTLINE_WIDTH)

	# Pelo: varias piezas redondeadas en vez de una tabla plana.
	var cap := Art.sphere(0.212, hair, Vector3(0.0, 0.14, 0.015))
	cap.scale = Vector3(1.02, 1.02, 1.02)
	_costume_add(_head_pivot, cap)
	# Melena: tres mechones que se angostan hacia abajo.
	var strands: Array = [
		{"pos": Vector3(0.0, -0.02, 0.15), "size": Vector3(0.26, 0.40, 0.16), "rot": -6.0},
		{"pos": Vector3(-0.15, -0.06, 0.12), "size": Vector3(0.14, 0.34, 0.14), "rot": -10.0},
		{"pos": Vector3(0.15, -0.06, 0.12), "size": Vector3(0.14, 0.34, 0.14), "rot": -10.0},
	]
	for strand: Dictionary in strands:
		var piece := Art.capsule(float(strand["size"].x) * 0.5, float(strand["size"].y), hair, strand["pos"])
		piece.rotation_degrees = Vector3(float(strand["rot"]), 0.0, 0.0)
		_costume_add(_head_pivot, piece)
	# Flequillo.
	var fringe := Art.box(Vector3(0.34, 0.09, 0.12), hair, Vector3(0.0, 0.21, -0.145))
	_costume_add(_head_pivot, fringe)

	# Astas: tres segmentos por lado, en angulos distintos.
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

	# Vestido: cono invertido desde la cintura, con vivo claro abajo.
	var skirt := MeshInstance3D.new()
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.25
	skirt_mesh.bottom_radius = 0.43
	skirt_mesh.height = 0.42
	skirt.mesh = skirt_mesh
	skirt.material_override = Art.toon(body_color.darkened(0.10), OUTLINE_WIDTH)
	skirt.position = Vector3(0.0, -0.08, 0.0)
	_costume_add(_hips, skirt)
	_costume_add(_hips, Art.cylinder(0.445, 0.06, Art.toon(body_color.lightened(0.35), 0.0), Vector3(0.0, -0.27, 0.0)))

	# Bufanda con las dos puntas colgando.
	_costume_add(_torso, Art.capsule(0.21, 0.16, _mat_accent, Vector3(0.0, 0.66, 0.0)))
	for side: float in [-1.0, 1.0]:
		var tail := Art.box(Vector3(0.13, 0.38, 0.09), _mat_accent, Vector3(0.11 * side, 0.46, 0.16))
		tail.rotation_degrees = Vector3(16.0, 0.0, 8.0 * side)
		_costume_add(_torso, tail)


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

	# Banda en la frente.
	_costume_add(_head_pivot, Art.box(Vector3(0.43, 0.085, 0.43), _mat_accent, Vector3(0.0, 0.20, 0.0)))

	# Hombreras: el rasgo mas fuerte de su silueta.
	for side: float in [-1.0, 1.0]:
		var pad := Art.sphere(0.23, _mat_accent, Vector3(0.30 * side, 0.56, 0.0))
		pad.scale = Vector3(1.3, 0.95, 1.15)
		_costume_add(_torso, pad)
		var spike := Art.capsule(0.048, 0.22, _mat_accent, Vector3(0.44 * side, 0.62, 0.0))
		spike.rotation_degrees = Vector3(0.0, 0.0, -50.0 * side)
		_costume_add(_torso, spike)

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
