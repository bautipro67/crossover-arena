extends Node
## Autoload: FX
## Todos los efectos visuales del juego, generados por codigo (no hay assets todavia).
##
## REGLA: los FX son SIEMPRE puramente cosmeticos. Nunca aplican daño, status ni logica.
## Si borras este archivo entero el juego tiene que seguir funcionando igual.

var _camera: Camera3D = null
## La arena registra su Environment para poder gradear la imagen en momentos clave.
var _environment: Environment = null
var _base_saturation: float = 1.0
var _shake_strength: float = 0.0
var _shake_decay: float = 6.0


func _process(delta: float) -> void:
	if _shake_strength <= 0.0 or not is_instance_valid(_camera):
		return
	_shake_strength = maxf(0.0, _shake_strength - _shake_decay * delta)
	var offset := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		0.0
	) * _shake_strength * 0.15
	_camera.h_offset = offset.x
	_camera.v_offset = offset.y


## La arena registra su Environment al construirse.
func register_environment(env: Environment) -> void:
	_environment = env
	_base_saturation = env.adjustment_saturation if env != null else 1.0


## Le baja el color al mundo entero mientras el tiempo esta detenido.
##
## Es el efecto que le da peso a ZA WARUDO: no alcanza con particulas alrededor del
## que lo tira, tiene que sentirse que algo le paso al MUNDO. Y de paso comunica el
## estado sin texto: si esta gris, no te podes mover.
func time_stop_grade(duration: float) -> void:
	if _environment == null:
		return
	var env := _environment
	var tween := create_tween()
	tween.tween_property(env, "adjustment_saturation", 0.12, 0.18)
	tween.tween_interval(maxf(0.0, duration - 0.6))
	tween.tween_property(env, "adjustment_saturation", _base_saturation, 0.42)


## La camara local se registra sola para poder temblar.
func register_camera(cam: Camera3D) -> void:
	_camera = cam


func camera_shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func _world_of(context: Node) -> Node:
	if not is_instance_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else context.get_tree().root


## Estallido de hielo. Atajo del burst generico con la paleta de Noelle.
func spawn_ice_impact(context: Node, position: Vector3) -> void:
	spawn_impact_burst(context, position, Color(0.75, 0.93, 1.0, 0.95))


## Estallido generico en un punto, del color que le pases.
func spawn_impact_burst(context: Node, position: Vector3, color: Color) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var burst := CPUParticles3D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 28
	burst.lifetime = 0.55
	burst.explosiveness = 0.95
	burst.direction = Vector3.UP
	burst.spread = 75.0
	burst.initial_velocity_min = 3.0
	burst.initial_velocity_max = 7.0
	burst.gravity = Vector3(0.0, -9.0, 0.0)
	burst.scale_amount_min = 0.10
	burst.scale_amount_max = 0.30
	burst.color = color
	# Chispas de luz que se apagan, no cubitos (ver Art.particula_suave).
	burst.mesh = Art.particula_suave()
	burst.color_ramp = Art.rampa_que_se_apaga(color)
	world.add_child(burst)
	burst.global_position = position
	_auto_free(burst, 1.4)


## Arco del golpe basico: un destello corto delante del jugador.
func spawn_melee_arc(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var slash := CPUParticles3D.new()
	slash.emitting = true
	slash.one_shot = true
	slash.amount = 20
	slash.lifetime = 0.3
	slash.explosiveness = 1.0
	slash.direction = dir.normalized()
	slash.spread = 40.0
	slash.initial_velocity_min = 5.0
	slash.initial_velocity_max = 9.0
	slash.gravity = Vector3.ZERO
	slash.scale_amount_min = 0.10
	slash.scale_amount_max = 0.26
	slash.color = Color(0.85, 0.96, 1.0, 0.9)
	slash.mesh = Art.particula_suave()
	slash.color_ramp = Art.rampa_que_se_apaga(Color(0.85, 0.96, 1.0, 0.9))
	world.add_child(slash)
	slash.global_position = origin + dir.normalized() * 1.2
	_auto_free(slash, 0.9)
	spawn_slash_arc(caster, origin, dir, Color(0.80, 0.94, 1.0))
	Sfx.play_3d(caster, &"hit_ice", origin, -4.0)


## Cuando sono el ultimo golpe que conecto. Ver spawn_hit_impact.
var _ultimo_golpe_ms: int = 0


## Impacto de un golpe que CONECTO. Es lo que hace que pegar se sienta.
##
## Antes, acertar un golpe basico producia un puñado de particulas y un numero. Se veia
## que pasaba algo, pero no se SENTIA: el mismo efecto que tiene errar, mas un numero.
## Lo que da peso es la combinacion de tres cosas baratas:
##
##   1. un anillo que se expande en el punto exacto del impacto, que marca DONDE;
##   2. un destello corto, que marca CUANDO;
##   3. temblor de camara proporcional al daño, SOLO para el que pego.
##
## El punto 3 es el importante y el que faltaba. El temblor estaba solo en los
## ultimates, asi que el 90% de los golpes del juego no movian nada.
func spawn_hit_impact(context: Node, position: Vector3, amount: float, color: Color) -> void:
	var world := _world_of(context)
	if world == null:
		return

	# Anillo que se abre. Un toro plano escalado por un tween: se lee como una onda.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.46
	ring.mesh = torus
	var mat := Art.glow(color, 2.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	world.add_child(ring)
	ring.global_position = position
	# De canto hacia la camara: un anillo horizontal casi no se ve desde atras del hombro.
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	if _camera != null and is_instance_valid(_camera):
		ring.look_at(_camera.global_position, Vector3.UP)

	var escala := 1.0 + clampf(amount / 40.0, 0.2, 2.2)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3.ONE * escala, 0.26).from(Vector3.ONE * 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.26).from(0.95)
	tw.chain().tween_callback(ring.queue_free)

	# EL SONIDO DEL GOLPE QUE CONECTA (assets/audio/golpe.ogg). Uno cada 40 ms como mucho:
	# un daño que pega muchas veces seguidas —una quemadura, una rafaga— sonaba como un
	# redoble.
	var ahora := Time.get_ticks_msec()
	if ahora - _ultimo_golpe_ms >= 40:
		_ultimo_golpe_ms = ahora
		Sfx.play_3d(context, &"golpe", position, -5.0 + clampf(amount / 12.0, 0.0, 4.0))

	# CHISPAS: salen para todos lados desde el punto del golpe. El anillo dice DONDE y el
	# destello CUANDO; las chispas dicen CUANTO, porque un golpe fuerte tira mas.
	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.one_shot = true
	chispas.amount = clampi(8 + int(amount * 0.5), 8, 30)
	chispas.lifetime = 0.32
	chispas.explosiveness = 1.0
	chispas.direction = Vector3.UP
	chispas.spread = 180.0
	chispas.initial_velocity_min = 3.5
	chispas.initial_velocity_max = 8.0
	chispas.gravity = Vector3(0.0, -9.0, 0.0)
	chispas.scale_amount_min = 0.06
	chispas.scale_amount_max = 0.14
	chispas.color = color.lightened(0.35)
	chispas.mesh = Art.particula_suave()
	chispas.color_ramp = Art.rampa_que_se_apaga(color.lightened(0.35))
	world.add_child(chispas)
	chispas.global_position = position
	_auto_free(chispas, 0.8)

	# Destello.
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 2.0 + clampf(amount / 25.0, 0.0, 3.0)
	luz.omni_range = 4.5
	luz.shadow_enabled = false
	world.add_child(luz)
	luz.global_position = position
	_fade_light(luz, 0.22)


## Temblor para EL QUE PEGO, escalado al daño.
##
## Va aparte de spawn_hit_impact porque el impacto lo ve todo el mundo y el temblor
## solo lo siente el autor: si temblara la camara de todos, cada golpe en la otra punta
## del mapa te sacudiria la pantalla.
func hit_feedback_for_attacker(amount: float, _victima: Node = null) -> void:
	camera_shake(clampf(0.18 + amount * 0.012, 0.18, 1.1))


## Arco de un golpe cuerpo a cuerpo: una media luna que barre y se desvanece.
##
## Reemplaza a las particulas sueltas del zarpazo: un puñado de puntos no dice en que
## DIRECCION fue el golpe, y la direccion es justo lo que el rival necesita leer.
##
## Se construye con ImmediateMesh y no con un puñado de quads. El primer intento eran
## seis cuadrados repartidos en abanico y se veian exactamente como lo que eran: seis
## cuadrados, como postes de una cerca. Una tira de triangulos da una hoja continua,
## que es lo que el ojo lee como "un tajo".
func spawn_slash_arc(caster: Node, origin: Vector3, dir: Vector3, color: Color) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = Vector3.FORWARD

	var mat := Art.glow(color, 2.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Sin escritura de profundidad: es una hoja de luz, no un objeto solido, y si
	# escribe profundidad se recorta contra el cuerpo del que pega.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	var pasos := 16
	for i: int in range(pasos + 1):
		var t := float(i) / float(pasos)
		var ang := deg_to_rad(-46.0 + 92.0 * t)
		# El grosor se afina en las dos puntas: una media luna, no una banana.
		var grosor := 1.05 * sin(PI * t)
		var r_int := 0.95
		var r_ext := r_int + grosor
		mesh.surface_add_vertex(Vector3(sin(ang) * r_int, 0.0, -cos(ang) * r_int))
		mesh.surface_add_vertex(Vector3(sin(ang) * r_ext, 0.0, -cos(ang) * r_ext))
	mesh.surface_end()

	var hoja := MeshInstance3D.new()
	hoja.mesh = mesh
	hoja.material_override = mat
	world.add_child(hoja)
	# Adelantada medio metro: centrada en el cuerpo, la mitad del arco queda detras del
	# personaje y el golpe parece salir de la espalda.
	var centro := origin + plano * 0.45
	hoja.global_position = centro
	hoja.look_at(centro + plano, Vector3.UP)
	# Inclinada: una media luna horizontal, vista desde atras del hombro, se ve de
	# canto y practicamente desaparece.
	hoja.rotate_object_local(Vector3.RIGHT, deg_to_rad(-28.0))

	# Barre de un lado al otro mientras se apaga.
	var tw := hoja.create_tween().set_parallel()
	var giro_final := hoja.rotation.y + deg_to_rad(34.0)
	var giro_inicial := hoja.rotation.y - deg_to_rad(26.0)
	tw.tween_property(hoja, "rotation:y", giro_final, 0.28).from(giro_inicial)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28).from(1.0)
	tw.chain().tween_callback(hoja.queue_free)


## JARONA: onda circular que se abre desde Flowery.
##
## Un anillo que crece, y no una explosion de particulas, porque lo que el rival tiene
## que leer es HASTA DONDE llega. Con particulas no sabes si te alcanzo o no; con un
## borde que se expande, ves el limite.
func spawn_jarona_wave(caster: Node, origin: Vector3, radius: float,
		color: Color = Color(1.0, 0.78, 0.30), con_sonido: bool = true) -> void:
	var world := _world_of(caster)
	if world == null:
		return

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	ring.mesh = torus
	var mat := Art.glow(color, 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	world.add_child(ring)
	ring.global_position = origin + Vector3.UP * 0.25

	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(radius, 3.0, radius), 0.34).from(Vector3(0.6, 1.0, 0.6))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.34).from(0.95)
	tw.chain().tween_callback(ring.queue_free)

	# Petalos saliendo disparados con la onda.
	var petals := CPUParticles3D.new()
	petals.emitting = true
	petals.one_shot = true
	petals.amount = 40
	petals.lifetime = 0.5
	petals.explosiveness = 1.0
	petals.direction = Vector3.ZERO
	petals.spread = 180.0
	petals.initial_velocity_min = radius * 1.2
	petals.initial_velocity_max = radius * 2.0
	petals.gravity = Vector3(0.0, -3.0, 0.0)
	petals.scale_amount_min = 0.12
	petals.scale_amount_max = 0.3
	petals.color = color
	world.add_child(petals)
	petals.global_position = origin + Vector3.UP * 0.8
	_auto_free(petals, 1.2)

	# Solo el primero de una cadena suena y sacude: siete gritos superpuestos son ruido,
	# y siete temblores encimados marean.
	if con_sonido:
		camera_shake(0.7)
		Sfx.play_3d(caster, &"hit_punch", origin, 2.0)


## Los siete colores de las flores del capitulo, en orden.
const SOUL_COLORS: Array[Color] = [
	Color(1.0, 0.24, 0.24), Color(1.0, 0.58, 0.18), Color(1.0, 0.92, 0.26),
	Color(0.36, 0.90, 0.38), Color(0.30, 0.62, 1.0), Color(0.30, 0.92, 0.94),
	Color(0.74, 0.40, 0.98),
]


## JARONA: siete anillos encadenados, uno por cada flor.
##
## La primera version era un anillo dorado. Funcionaba, pero podria haber sido de
## cualquiera: la pelea de Flowery es LA DE LAS SIETE FLORES DE COLORES, y el ataque
## tiene que leerse como eso.
func spawn_soul_rings(caster: Node, origin: Vector3, radius: float) -> void:
	for i: int in range(SOUL_COLORS.size()):
		var color := SOUL_COLORS[i]
		var retardo := float(i) * 0.035
		if i == 0:
			spawn_jarona_wave(caster, origin, radius, color)
			continue
		var timer := get_tree().create_timer(retardo)
		# Por referencia debil: si el que la tiro ya no existe cuando vence el retardo, la
		# funcion lo nota sin que Godot se queje de una captura liberada.
		var ref: WeakRef = weakref(caster)
		timer.timeout.connect(func() -> void:
			var quien: Node = ref.get_ref()
			if is_instance_valid(quien):
				# Cada anillo un poco mas chico: el conjunto se lee como una sola onda
				# con espesor de colores, no como siete ataques.
				spawn_jarona_wave(quien, origin, radius * (1.0 - 0.06 * float(i)), color, false)
		)


## El destello blanco ANTES de cada embestida de Flowery.
##
## No es adorno. En el original, Flowery grita y destella en blanco justo antes de
## tirarse, y ese destello es lo unico que te da el tiempo de reaccion para esquivarla.
## Sin el, una embestida a 30 m/s es un golpe sin aviso.
func spawn_jarona_flash(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 1.0, 1.0)
	luz.light_energy = 7.0
	luz.omni_range = 6.0
	luz.shadow_enabled = false
	target.add_child(luz)
	luz.position = Vector3(0.0, 1.1, 0.0)
	_fade_light(luz, 0.16)

	# Cascara blanca de un frame y medio sobre el cuerpo: el "flash" propiamente dicho.
	var cascara := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.5
	capsula.height = 2.1
	cascara.mesh = capsula
	var mat := Art.glow(Color(1.0, 1.0, 1.0), 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cascara.material_override = mat
	cascara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(cascara)
	cascara.position = Vector3(0.0, 1.0, 0.0)
	var tw := cascara.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18).from(0.85)
	tw.tween_callback(cascara.queue_free)


## La explosion que LAST JARONA deja en cada rebote.
##
## Va hacia ARRIBA y se queda un instante, no es un estallido plano: tiene que leerse
## como una zona que acaba de reventar y por la que no querés pasar.
func spawn_jarona_blast(context: Node, position: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return

	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	bola.mesh = esfera
	var mat := Art.glow(Color(1.0, 0.52, 0.20), 3.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bola.material_override = mat
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(bola)
	bola.global_position = position + Vector3.UP * 0.9

	var tw := bola.create_tween().set_parallel()
	tw.tween_property(bola, "scale", Vector3.ONE * 2.6, 0.38).from(Vector3.ONE * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.38).from(0.9)
	tw.chain().tween_callback(bola.queue_free)

	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.one_shot = true
	chispas.amount = 26
	chispas.lifetime = 0.55
	chispas.explosiveness = 1.0
	chispas.direction = Vector3.UP
	chispas.spread = 80.0
	chispas.initial_velocity_min = 4.0
	chispas.initial_velocity_max = 11.0
	chispas.gravity = Vector3(0.0, -12.0, 0.0)
	chispas.scale_amount_min = 0.1
	chispas.scale_amount_max = 0.3
	chispas.color = Color(1.0, 0.66, 0.26, 0.95)
	world.add_child(chispas)
	chispas.global_position = position + Vector3.UP * 0.6
	_auto_free(chispas, 1.4)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.56, 0.24)
	luz.light_energy = 5.0
	luz.omni_range = 7.0
	luz.shadow_enabled = false
	world.add_child(luz)
	luz.global_position = position + Vector3.UP * 1.0
	_fade_light(luz, 0.4)

	camera_shake(0.55)


## Arranque de la carga: estela hacia adelante.
func spawn_charge_burst(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var trail := CPUParticles3D.new()
	trail.emitting = true
	trail.one_shot = true
	trail.amount = 30
	trail.lifetime = 0.45
	trail.explosiveness = 0.75
	trail.direction = -dir.normalized()
	trail.spread = 22.0
	trail.initial_velocity_min = 3.0
	trail.initial_velocity_max = 9.0
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.28
	trail.color = Color(1.0, 0.62, 0.30, 0.9)
	world.add_child(trail)
	trail.global_position = origin + Vector3.UP * 0.9
	_auto_free(trail, 1.0)
	camera_shake(0.4)


## Una marca de estela en el camino de una embestida.
##
## POR QUE HACE FALTA. Las tres habilidades de Flowery son embestidas, y una embestida
## dura tres decimas: el estallido del arranque ya se apago cuando el cuerpo va por la
## mitad, y en el medio no se ve NADA. Mirando capturas del momento exacto del impacto de
## Here I Come no habia ni un pixel que dijera que estaba pasando un ataque — se veia al
## personaje parado al lado del rival.
##
## La estela es lo que convierte "el personaje cambio de lugar" en "el personaje se tiro".
## Se deja una cada dos tics, asi que el rastro queda continuo sin llenar la escena.
func spawn_dash_streak(caster: Node, origin: Vector3, dir: Vector3, color: Color) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var streak := MeshInstance3D.new()
	# FINA Y LARGA, y las medidas importan. La primera version era una capsula de 0.34 de
	# radio por 1.9 de largo: a 30 m/s, dejando una cada dos tics, quedaban a tres metros
	# una de otra con solo 1.9 de largo, o sea con un metro de hueco en el medio. En
	# pantalla no se leia una estela sino salchichas rosas sueltas tiradas en el piso.
	# Con 3.6 de largo y una por tic, cada marca se solapa con la siguiente y el rastro
	# sale continuo.
	var cap := CapsuleMesh.new()
	cap.radius = 0.17
	cap.height = 3.6
	streak.mesh = cap
	var mat := Art.glow(color, 1.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Translucida: se van a superponer varias y si cada una fuera opaca el rastro seria
	# un tubo solido en vez de un halo.
	mat.albedo_color = Color(color.r, color.g, color.b, 0.34)
	# Sin sombra ni profundidad: es un rastro de luz, no un cuerpo. Con profundidad se
	# recorta contra el personaje y parece una capsula solida metida adentro de el.
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	streak.material_override = mat
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(streak)
	streak.global_position = origin + Vector3.UP * 0.9
	# Acostada a lo largo del rumbo: una capsula parada se lee como una columna, no como
	# velocidad.
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if not plano.is_zero_approx():
		streak.look_at_from_position(streak.global_position, streak.global_position + plano, Vector3.UP)
		streak.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	var tween := streak.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.24)
	tween.tween_property(streak, "scale", Vector3(0.3, 1.0, 0.3), 0.24)
	tween.chain().tween_callback(streak.queue_free)


## Frenada de la carga. Marca el momento en que Flowery queda expuesta.
func spawn_charge_landing(caster: Node, origin: Vector3) -> void:
	spawn_jarona_wave(caster, origin, 3.2, Color(1.0, 0.55, 0.28))


## LAST JARONA. El momento mas ruidoso del kit de Flowery: tres ondas encadenadas,
## destello y un temblor que se siente.
func spawn_last_jarona(caster: Node, origin: Vector3, radius: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return

	# Tres anillos desfasados: uno solo, por grande que sea, se lee como el de Jarona
	# con otro tamaño. Encadenados se leen como algo de otra categoria.
	# Los SIETE colores, uno tras otro. Es la forma Omega: la suma de las siete flores.
	for i: int in range(SOUL_COLORS.size()):
		var retardo := float(i) * 0.075
		var timer := get_tree().create_timer(retardo)
		var ref: WeakRef = weakref(caster)
		timer.timeout.connect(func() -> void:
			var quien: Node = ref.get_ref()
			if is_instance_valid(quien):
				spawn_jarona_wave(quien, origin,
					radius * (0.45 + 0.09 * float(i)), SOUL_COLORS[i], false)
		)

	# Energia 7 y no 12: sumada a la luz de la forma Omega, que ya esta encendida encima
	# del jugador, la de 12 terminaba de quemar la pantalla entera a blanco. Un ultimate
	# tiene que verse enorme, no tapar lo que pasa.
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.72, 0.38)
	flash.light_energy = 7.0
	flash.omni_range = radius * 1.4
	flash.shadow_enabled = false
	world.add_child(flash)
	flash.global_position = origin + Vector3.UP * 1.5
	_fade_light(flash, 0.7)

	camera_shake(2.6)
	Sfx.play_3d(caster, &"last_jarona", origin, 3.0)


## Snowgrave. Tiene que ser el momento mas dramatico del juego:
## destello blanco-azulado, ola de escarcha barriendo el cono, y temblor de camara.
func spawn_snowgrave(caster: Node, origin: Vector3, dir: Vector3, cone_range: float, cone_angle: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	if flat_dir.is_zero_approx():
		flat_dir = Vector3.FORWARD

	# Ola de escarcha que barre el piso.
	var wave := CPUParticles3D.new()
	wave.emitting = true
	wave.one_shot = true
	wave.amount = 220
	wave.lifetime = 1.1
	wave.explosiveness = 0.85
	wave.direction = flat_dir
	wave.spread = cone_angle * 0.5
	wave.initial_velocity_min = cone_range * 0.55
	wave.initial_velocity_max = cone_range * 1.05
	wave.gravity = Vector3(0.0, -1.5, 0.0)
	wave.scale_amount_min = 0.12
	wave.scale_amount_max = 0.5
	wave.color = Color(0.88, 0.97, 1.0, 0.95)
	world.add_child(wave)
	wave.global_position = origin + Vector3.DOWN * 0.6
	_auto_free(wave, 2.4)

	# Destello de luz.
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.8, 0.95, 1.0)
	flash.light_energy = 14.0
	flash.omni_range = 22.0
	world.add_child(flash)
	flash.global_position = origin
	_fade_light(flash, 0.7)

	Sfx.play_3d(caster, &"snowgrave", origin, 2.0)
	camera_shake(1.6)


## Aura alrededor del que esta canalizando. Devuelve el nodo para poder sacarlo despues.
func spawn_channel_aura(caster: Node3D) -> Node3D:
	if not is_instance_valid(caster):
		return null
	var aura := CPUParticles3D.new()
	aura.emitting = true
	aura.amount = 60
	aura.lifetime = 1.0
	aura.direction = Vector3.UP
	aura.spread = 12.0
	aura.initial_velocity_min = 1.5
	aura.initial_velocity_max = 3.5
	aura.gravity = Vector3.ZERO
	aura.scale_amount_min = 0.06
	aura.scale_amount_max = 0.18
	aura.color = Color(0.7, 0.9, 1.0, 0.9)
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 0.9
	caster.add_child(aura)
	aura.position = Vector3.ZERO
	return aura


## Ritual de canalizado: circulo magico girando a los pies, particulas que suben y luz.
## Es el aviso visual de que alguien esta cargando un ultimate: tiene que verse de lejos
## y darle al rival el tiempo de reaccion que el balance da por sentado.
func spawn_channel_ritual(caster: Node3D, color: Color) -> Node3D:
	if not is_instance_valid(caster):
		return null
	var root := Node3D.new()
	caster.add_child(root)
	root.position = Vector3(0.0, 0.05, 0.0)

	# El color de icono de las habilidades es casi blanco (para que se lea en el HUD),
	# y en 3D un anillo blanco con mucha emision se convierte en una mancha. Le subimos
	# la saturacion y bajamos la energia para que se lea como un circulo de color.
	var ring_color := color
	ring_color.s = maxf(ring_color.s, 0.62)
	ring_color.v = minf(ring_color.v, 0.92)
	var glow_mat := Art.glow(ring_color, 1.35)

	# Dos anillos concentricos que giran en sentidos opuestos.
	var outer := MeshInstance3D.new()
	var outer_mesh := TorusMesh.new()
	outer_mesh.inner_radius = 1.16
	outer_mesh.outer_radius = 1.24
	outer.mesh = outer_mesh
	outer.material_override = glow_mat
	root.add_child(outer)

	var inner := MeshInstance3D.new()
	var inner_mesh := TorusMesh.new()
	inner_mesh.inner_radius = 0.72
	inner_mesh.outer_radius = 0.78
	inner.mesh = inner_mesh
	inner.material_override = glow_mat
	inner.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(inner)

	# Runas: cuatro bloques sobre el anillo exterior.
	for i: int in range(4):
		var angle := TAU * float(i) / 4.0
		var rune := Art.box(Vector3(0.11, 0.03, 0.30), glow_mat,
			Vector3(cos(angle) * 1.20, 0.04, sin(angle) * 1.20))
		rune.rotation.y = -angle
		outer.add_child(rune)

	var rise := CPUParticles3D.new()
	rise.emitting = true
	rise.amount = 70
	rise.lifetime = 1.1
	rise.direction = Vector3.UP
	rise.spread = 6.0
	rise.initial_velocity_min = 2.0
	rise.initial_velocity_max = 4.2
	rise.gravity = Vector3.ZERO
	rise.scale_amount_min = 0.05
	rise.scale_amount_max = 0.16
	rise.color = ring_color
	rise.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	rise.emission_ring_radius = 1.22
	rise.emission_ring_inner_radius = 0.95
	rise.emission_ring_height = 0.1
	rise.emission_ring_axis = Vector3.UP
	root.add_child(rise)

	# 1.6 y no 2.2. Sobre el piso claro de la plataforma central, 2.2 ya dejaba la
	# superficie al borde del blanco puro, y a Flowery —que ademas enciende la forma
	# Omega encima— lo empujaba del otro lado: el piso salia quemado en media pantalla y
	# durante el canalizado no se veia ni la arena ni donde estaban los rivales.
	var light := OmniLight3D.new()
	light.light_color = ring_color
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = Vector3(0.0, 0.8, 0.0)
	root.add_child(light)

	var spin := outer.create_tween().set_loops()
	spin.tween_property(outer, "rotation:y", TAU, 2.4).from(0.0)
	var counter := inner.create_tween().set_loops()
	counter.tween_property(inner, "rotation:y", -TAU, 1.6).from(0.0)

	return root


## Un portal verde. `entrada` false es el de salida (de donde saliste), true el de
## llegada, que se abre ANTES y es el aviso de a donde vas a aparecer.
func spawn_portal(caster: Node, origin: Vector3, dir: Vector3, entrada: bool) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = Vector3.FORWARD

	var raiz := Node3D.new()
	world.add_child(raiz)
	raiz.global_position = origin + Vector3.UP * 1.0
	# Parado y encarado al rumbo: un portal acostado en el piso se lee como un charco.
	raiz.look_at_from_position(raiz.global_position, raiz.global_position + plano, Vector3.UP)

	var verde := Color(0.42, 1.0, 0.32)
	# El anillo. Es lo unico que se ve de lejos, asi que va con harta emision.
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.78
	toro.outer_radius = 0.95
	anillo.mesh = toro
	anillo.material_override = Art.glow(verde, 3.4)
	anillo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	raiz.add_child(anillo)

	# El disco de adentro, translucido: sin el, el anillo se lee como un aro y no como
	# un agujero a otro lado.
	var disco := MeshInstance3D.new()
	var plano_mesh := PlaneMesh.new()
	plano_mesh.size = Vector2(1.62, 1.62)
	disco.mesh = plano_mesh
	var mat := Art.glow(Color(0.20, 0.75, 0.28), 1.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.20, 0.75, 0.28, 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disco.material_override = mat
	disco.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	raiz.add_child(disco)

	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 34
	chispas.lifetime = 0.7
	chispas.direction = Vector3.ZERO
	chispas.spread = 180.0
	chispas.initial_velocity_min = 0.6
	chispas.initial_velocity_max = 2.4
	chispas.gravity = Vector3.ZERO
	chispas.scale_amount_min = 0.05
	chispas.scale_amount_max = 0.17
	chispas.color = verde
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	chispas.emission_ring_radius = 0.9
	chispas.emission_ring_inner_radius = 0.75
	chispas.emission_ring_height = 0.1
	chispas.emission_ring_axis = Vector3.UP
	raiz.add_child(chispas)

	var luz := OmniLight3D.new()
	luz.light_color = verde
	luz.light_energy = 2.6
	luz.omni_range = 5.5
	luz.shadow_enabled = false
	raiz.add_child(luz)

	# El de llegada dura mas: tiene que seguir abierto cuando el cuerpo aparece, o el
	# aviso se apaga justo antes de que sirva para algo.
	var vida := 1.15 if entrada else 0.7
	var giro := anillo.create_tween().set_loops()
	giro.tween_property(anillo, "rotation:y", TAU, 1.1).from(0.0)
	var cierre := raiz.create_tween()
	cierre.tween_interval(vida * 0.55)
	cierre.tween_property(raiz, "scale", Vector3(0.05, 0.05, 0.05), vida * 0.45)
	cierre.tween_callback(raiz.queue_free)


## Explosion de la granada de plasma.
func spawn_plasma_blast(caster: Node, origin: Vector3, radius: float) -> void:
	spawn_jarona_wave(caster, origin, radius, Color(0.55, 1.0, 0.32))
	var world := _world_of(caster)
	if world == null:
		return
	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.one_shot = true
	chispas.amount = 46
	chispas.lifetime = 0.7
	chispas.explosiveness = 0.92
	chispas.direction = Vector3.UP
	chispas.spread = 85.0
	chispas.initial_velocity_min = 4.0
	chispas.initial_velocity_max = 12.0
	chispas.gravity = Vector3(0.0, -9.0, 0.0)
	chispas.scale_amount_min = 0.07
	chispas.scale_amount_max = 0.24
	chispas.color = Color(0.7, 1.0, 0.45)
	world.add_child(chispas)
	chispas.global_position = origin
	_auto_free(chispas, 1.4)

	var flash := OmniLight3D.new()
	flash.light_color = Color(0.55, 1.0, 0.35)
	flash.light_energy = 5.5
	flash.omni_range = radius * 2.0
	flash.shadow_enabled = false
	world.add_child(flash)
	flash.global_position = origin + Vector3.UP * 0.8
	_fade_light(flash, 0.45)
	camera_shake(1.0)


## La caja abriendose. Chica y corta: lo que importa es lo que sale de ella.
func spawn_meeseeks_box(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var caja := MeshInstance3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3(0.5, 0.42, 0.5)
	caja.mesh = cubo
	caja.material_override = Art.toon(Color(0.24, 0.62, 0.80), 0.012)
	world.add_child(caja)
	caja.global_position = origin + dir.normalized() * 0.9
	var salto := caja.create_tween()
	salto.tween_property(caja, "position:y", caja.position.y + 0.5, 0.18)
	salto.parallel().tween_property(caja, "rotation:y", TAU, 0.5)
	salto.tween_property(caja, "scale", Vector3.ZERO, 0.25)
	salto.tween_callback(caja.queue_free)

	var humo := CPUParticles3D.new()
	humo.emitting = true
	humo.one_shot = true
	humo.amount = 30
	humo.lifetime = 0.8
	humo.explosiveness = 0.85
	humo.direction = Vector3.UP
	humo.spread = 60.0
	humo.initial_velocity_min = 1.5
	humo.initial_velocity_max = 5.0
	humo.gravity = Vector3.ZERO
	humo.scale_amount_min = 0.08
	humo.scale_amount_max = 0.26
	humo.color = Color(0.42, 0.85, 0.98)
	world.add_child(humo)
	humo.global_position = origin + dir.normalized() * 0.9
	_auto_free(humo, 1.5)


## La frase que grita un personaje al usar una habilidad.
##
## VA COLGADA DEL CUERPO, no dejada en el mundo. Flowery grita "¡JARONA!" justo antes de
## salir disparado a treinta metros por segundo: una burbuja plantada en el aire se
## quedaria atras al instante y parecería que la dijo otro. Colgada de el, lo acompaña.
##
## Y REEMPLAZA A LA ANTERIOR. El JARONA son diez embestidas seguidas y cada una grita:
## si se apilaran, a la tercera no se leeria ninguna. Reemplazandose se lee como lo que
## es, un canto que se repite, que es exactamente como suena en el juego original.
func spawn_grito(caster: Node, texto: String, color: Color) -> void:
	var cuerpo := caster as Node3D
	if not is_instance_valid(cuerpo):
		return

	var previo := cuerpo.get_node_or_null(^"GritoFrase")
	if previo != null:
		previo.name = &"GritoViejo"
		previo.queue_free()

	var label := Label3D.new()
	label.name = &"GritoFrase"
	label.text = texto
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 52
	# Contorno grueso y oscuro: es como se leen los carteles de los dos juegos de los que
	# salen estos personajes, y ademas es lo unico que hace legible un texto blanco contra
	# un mapa que tiene cielo claro arriba y piso claro abajo.
	label.outline_size = 20
	label.modulate = color
	label.outline_modulate = Color(0.04, 0.03, 0.08)
	label.pixel_size = 0.0055
	cuerpo.add_child(label)
	label.position = Vector3(0.0, 2.45, 0.0)

	# Entra de golpe y grande, se asienta, y recien al final se va. El rebote inicial es
	# lo que lo hace leer como un grito y no como un cartel que aparecio.
	label.scale = Vector3.ONE * 0.45
	var tw := label.create_tween()
	tw.tween_property(label, "scale", Vector3.ONE * 1.12, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector3.ONE, 0.07)
	tw.tween_interval(0.42)
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", 3.05, 0.34)
	tw.tween_property(label, "modulate:a", 0.0, 0.34)
	tw.chain().tween_callback(label.queue_free)


# --------------------------------------------------------------------- Sonic
#
# Todo lo de Sonic es LA MISMA BOLA AZUL en distintos tamaños y velocidades: el golpe
# basico, el spin dash y el homing son los tres el mismo gesto —enrollarse y chocar— y
# dibujarlos parecidos es lo correcto, no pereza. Es lo que hace que se lea "esto es
# Sonic" antes de distinguir cual de las tres fue.

## La bola girando. El gesto basico del que salen los otros dos.
func spawn_spin_ball(caster: Node, origin: Vector3, dir: Vector3, duracion: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.55
	esfera.height = 1.1
	bola.mesh = esfera
	var mat := Art.glow(Color(0.30, 0.55, 1.0), 2.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bola.material_override = mat
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(bola)
	bola.global_position = origin + dir.normalized() * 1.1 + Vector3.UP * 0.2

	var tw := bola.create_tween()
	tw.set_parallel(true)
	# Gira rapidisimo y se achata en el eje del giro: una esfera girando se ve quieta,
	# una esfera achatada girando se ve girar.
	tw.tween_property(bola, "rotation:x", TAU * 4.0, duracion)
	tw.tween_property(bola, "scale", Vector3(1.25, 0.72, 1.25), duracion * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracion).from(0.85)
	tw.chain().tween_callback(bola.queue_free)


## La carga del Spin Dash: la bola girando en el lugar, cada vez mas rapido.
func spawn_spin_charge(caster: Node3D, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.62
	esfera.height = 1.0
	bola.mesh = esfera
	var mat := Art.glow(Color(0.25, 0.50, 1.0), 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bola.material_override = mat
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Colgada del cuerpo: la carga es EN EL LUGAR, pero el jugador puede seguir girando
	# para elegir hacia donde va a salir, y la bola tiene que acompañarlo.
	caster.add_child(bola)
	bola.position = Vector3(0.0, 0.55, 0.0)

	var polvo := CPUParticles3D.new()
	polvo.emitting = true
	polvo.amount = 24
	polvo.lifetime = 0.35
	polvo.direction = Vector3(0.0, 0.3, -1.0)
	polvo.spread = 25.0
	polvo.initial_velocity_min = 3.0
	polvo.initial_velocity_max = 7.0
	polvo.scale_amount_min = 0.05
	polvo.scale_amount_max = 0.16
	polvo.color = Color(0.6, 0.8, 1.0, 0.8)
	caster.add_child(polvo)
	polvo.position = Vector3(0.0, 0.2, 0.0)

	var tw := bola.create_tween()
	tw.set_parallel(true)
	# Acelerando: arranca lento y termina a toda velocidad, que es lo que se oye y se ve
	# en el original mientras se carga.
	tw.tween_property(bola, "rotation:x", TAU * 7.0, duracion).set_ease(Tween.EASE_IN)
	tw.tween_property(bola, "scale", Vector3(1.15, 0.8, 1.15), duracion)
	tw.chain().tween_callback(bola.queue_free)
	_auto_free(polvo, duracion + 0.5)


## La mira del Homing Attack sobre el rival elegido.
##
## Es el unico ataque del juego que elige blanco solo, asi que TIENE que decir cual eligio:
## sin esto, el jugador suelta la habilidad sin saber contra quien va, y cuando sale hacia
## otro parece un error del juego en vez de una decision suya.
func spawn_homing_lock(context: Node, position: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var mira := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.85
	toro.outer_radius = 1.05
	mira.mesh = toro
	var mat := Art.glow(Color(0.55, 0.9, 1.0), 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mira.material_override = mat
	mira.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mira.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	world.add_child(mira)
	mira.global_position = position + Vector3.UP

	var tw := mira.create_tween()
	tw.set_parallel(true)
	# Se cierra sobre el blanco: entra grande y se ajusta. Al reves —abriendose— se lee
	# como algo que se suelta, no como algo que se traba.
	tw.tween_property(mira, "scale", Vector3.ONE * 0.75, 0.22).from(Vector3.ONE * 2.2)
	tw.tween_property(mira, "rotation:y", TAU, 0.5)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_delay(0.18)
	tw.chain().tween_callback(mira.queue_free)


## Super Sonic: el aura dorada mientras dura la transformacion.
func spawn_super_sonic(caster: Node3D, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var viejo := caster.get_node_or_null(^"AuraSuper")
	if viejo != null:
		viejo.queue_free()

	var aura := Node3D.new()
	aura.name = &"AuraSuper"
	caster.add_child(aura)
	aura.position = Vector3(0.0, 1.0, 0.0)

	var cascara := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.72
	capsula.height = 2.5
	cascara.mesh = capsula
	var mat := Art.glow(Color(1.0, 0.88, 0.25), 3.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color.a = 0.30
	cascara.material_override = mat
	cascara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(cascara)

	# Chispas doradas subiendo: es lo que en los juegos dice "esto esta transformado" y no
	# "esto tiene un escudo". Suben, no caen — la energia sale del cuerpo.
	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 40
	chispas.lifetime = 0.8
	chispas.direction = Vector3.UP
	chispas.spread = 30.0
	chispas.initial_velocity_min = 1.5
	chispas.initial_velocity_max = 4.0
	chispas.gravity = Vector3(0.0, 2.0, 0.0)
	chispas.scale_amount_min = 0.05
	chispas.scale_amount_max = 0.14
	chispas.color = Color(1.0, 0.92, 0.45, 0.9)
	aura.add_child(chispas)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.85, 0.30)
	luz.light_energy = 2.6
	luz.omni_range = 7.0
	luz.shadow_enabled = false
	aura.add_child(luz)

	# Late, no queda fijo: un aura quieta se confunde con parte del personaje.
	var tw := cascara.create_tween()
	tw.set_loops(int(duracion / 0.5) + 1)
	tw.tween_property(mat, "albedo_color:a", 0.42, 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.22, 0.25)
	_auto_free(aura, duracion)


# ------------------------------------------------------------------ Mario

## El pisoton del Super Salto: la onda en el piso y el polvo que levanta.
##
## BLANCA Y BAJA, pegada al suelo, y no dorada como la de JARONA: es un golpe contra el
## piso, no energia. La onda llega hasta el radio que pega, para que se vea hasta donde
## alcanzo.
func spawn_pisoton(context: Node, origin: Vector3, radius: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.86
	toro.outer_radius = 1.0
	anillo.mesh = toro
	var mat := Art.glow(Color(1.0, 0.96, 0.86), 2.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	anillo.material_override = mat
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(anillo)
	anillo.global_position = origin + Vector3.UP * 0.12
	var tw := anillo.create_tween().set_parallel()
	tw.tween_property(anillo, "scale", Vector3(radius, 1.6, radius), 0.28).from(Vector3(0.5, 1.0, 0.5))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.32).from(0.9)
	tw.chain().tween_callback(anillo.queue_free)

	var polvo := CPUParticles3D.new()
	polvo.emitting = true
	polvo.one_shot = true
	polvo.amount = 36
	polvo.lifetime = 0.6
	polvo.explosiveness = 1.0
	polvo.direction = Vector3(0.0, 0.3, 0.0)
	polvo.spread = 90.0
	polvo.flatness = 0.8
	polvo.initial_velocity_min = radius * 1.2
	polvo.initial_velocity_max = radius * 2.2
	polvo.gravity = Vector3(0.0, -2.0, 0.0)
	polvo.scale_amount_min = 0.12
	polvo.scale_amount_max = 0.32
	polvo.color = Color(0.85, 0.80, 0.72, 0.8)
	world.add_child(polvo)
	polvo.global_position = origin + Vector3.UP * 0.25
	_auto_free(polvo, 1.2)


## La Superestrella: el cuerpo titilando en todos los colores, con chispas.
##
## TITILA, no brilla parejo: en los juegos Mario con estrella cambia de color todo el
## tiempo, y ese parpadeo es lo que dice "no lo toques" desde la otra punta del mapa.
##
## Se llama AuraSuper, como el aura de Super Sonic y la de los jefes potenciados, a
## proposito: las escenas del modo historia la esconden y la escena final la saca por ese
## nombre (ver Cinematica._congelar_pelea y MisionHistoria._ganar).
func spawn_estrella(caster: Node3D, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var viejo := caster.get_node_or_null(^"AuraSuper")
	if viejo != null:
		viejo.queue_free()
	var aura := Node3D.new()
	aura.name = &"AuraSuper"
	caster.add_child(aura)
	aura.position = Vector3(0.0, 1.0, 0.0)

	var cascara := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.62
	capsula.height = 2.1
	cascara.mesh = capsula
	var mat := Art.glow(Color(1.0, 0.9, 0.3), 2.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color.a = 0.22
	cascara.material_override = mat
	cascara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(cascara)

	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 36
	chispas.lifetime = 0.7
	chispas.direction = Vector3.UP
	chispas.spread = 60.0
	chispas.initial_velocity_min = 1.0
	chispas.initial_velocity_max = 3.0
	chispas.gravity = Vector3.ZERO
	chispas.scale_amount_min = 0.05
	chispas.scale_amount_max = 0.13
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chispas.emission_sphere_radius = 0.6
	var arcoiris := Gradient.new()
	arcoiris.set_color(0, Color(1.0, 0.3, 0.3))
	arcoiris.set_color(1, Color(0.4, 0.6, 1.0))
	arcoiris.add_point(0.33, Color(1.0, 0.95, 0.3))
	arcoiris.add_point(0.66, Color(0.4, 1.0, 0.5))
	chispas.color_initial_ramp = arcoiris
	aura.add_child(chispas)

	var luz := OmniLight3D.new()
	luz.light_energy = 2.4
	luz.omni_range = 6.0
	luz.shadow_enabled = false
	aura.add_child(luz)

	# El titileo: la cascara y la luz pasan por los colores del arcoiris, rapido.
	var colores: Array[Color] = [Color(1.0, 0.25, 0.25), Color(1.0, 0.85, 0.2),
		Color(0.35, 1.0, 0.45), Color(0.35, 0.7, 1.0), Color(0.85, 0.4, 1.0)]
	var tw := cascara.create_tween()
	tw.set_loops(int(duracion / (0.09 * colores.size())) + 1)
	for c: Color in colores:
		tw.tween_callback(func() -> void:
			mat.albedo_color = Color(c.r, c.g, c.b, 0.26)
			mat.emission = c
			luz.light_color = c)
		tw.tween_interval(0.09)
	_auto_free(aura, duracion)


# ------------------------------------------------------------------ Madara

## Katon: Gōka Messhitsu. Un muro de fuego que barre el cono entero.
##
## MUCHO Y DENSO, no chispas sueltas: en la serie tapa el horizonte. Dos capas —el fuego
## que avanza pegado al piso y las llamas que suben— y un fogonazo de luz naranja.
func spawn_katon(caster: Node, origin: Vector3, dir: Vector3, alcance: float, angulo: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = Vector3.FORWARD
	# Naranja saturado y con poca opacidad: la mezcla es aditiva, y con colores claros y
	# cientos de llamas encimadas el muro salia BLANCO, como una nube de vapor.
	var fuego := Gradient.new()
	fuego.set_color(0, Color(1.0, 0.50, 0.10, 0.40))
	fuego.set_color(1, Color(0.35, 0.03, 0.0, 0.0))
	fuego.add_point(0.4, Color(0.95, 0.26, 0.03, 0.32))
	for capa: int in range(2):
		var llamas := CPUParticles3D.new()
		llamas.emitting = true
		llamas.one_shot = true
		llamas.amount = 150 if capa == 0 else 80
		llamas.lifetime = 0.9 if capa == 0 else 1.2
		llamas.explosiveness = 0.7
		llamas.direction = (plano + Vector3.UP * (0.05 if capa == 0 else 0.35)).normalized()
		llamas.spread = angulo * 0.5
		llamas.flatness = 0.55 if capa == 0 else 0.2
		llamas.initial_velocity_min = alcance * 0.6
		llamas.initial_velocity_max = alcance * 1.15
		llamas.damping_min = alcance * 0.35
		llamas.damping_max = alcance * 0.55
		llamas.gravity = Vector3(0.0, 2.5 if capa == 0 else 5.0, 0.0)
		llamas.scale_amount_min = 0.35
		llamas.scale_amount_max = 0.9 if capa == 0 else 1.3
		llamas.color_ramp = fuego
		var malla := QuadMesh.new()
		malla.size = Vector2(1.0, 1.0)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = Art.punto_suave()
		malla.material = mat
		llamas.mesh = malla
		world.add_child(llamas)
		llamas.global_position = origin + Vector3.DOWN * (0.7 if capa == 0 else 0.2)
		_auto_free(llamas, 2.0)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.2)
	luz.light_energy = 10.0
	luz.omni_range = alcance * 1.4
	world.add_child(luz)
	luz.global_position = origin + plano * alcance * 0.45
	_fade_light(luz, 0.9)
	Sfx.play_3d(caster, &"katon", origin, 2.0)
	camera_shake(0.8)


## El Susano'o: la caja de costillas azul que lo envuelve mientras dura el escudo.
##
## TRANSLUCIDO Y MAS GRANDE QUE EL: el Susano'o es un gigante de chakra con el usuario
## adentro. Un caparazon tenue, las costillas a la altura del pecho y llamas azules
## subiendo. Sin nada solido y SIN CRANEO: la camara va justo detras de la cabeza, y un
## craneo brillante ahi le tapaba la vista al propio jugador los cinco segundos.
func spawn_susanoo(caster: Node3D, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var viejo := caster.get_node_or_null(^"Susanoo")
	if viejo != null:
		viejo.queue_free()
	var raiz := Node3D.new()
	raiz.name = &"Susanoo"
	caster.add_child(raiz)
	raiz.position = Vector3(0.0, 1.1, 0.0)

	var azul := Color(0.38, 0.52, 1.0)
	var mat := Art.glow(azul, 1.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color.a = 0.30
	var velo := Art.glow(azul, 0.8)
	velo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	velo.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	velo.cull_mode = BaseMaterial3D.CULL_DISABLED
	velo.albedo_color.a = 0.10

	# El caparazon: una capsula grande y casi transparente alrededor del cuerpo.
	var caparazon := Art.capsule(0.85, 2.3, velo, Vector3(0.0, -0.05, 0.0))
	caparazon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(caparazon)
	# Las costillas: aros alrededor del pecho, achatados adelante y atras.
	for i: int in range(4):
		var costilla := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.66 - float(i) * 0.05
		toro.outer_radius = 0.72 - float(i) * 0.05
		costilla.mesh = toro
		costilla.material_override = mat
		costilla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		costilla.position = Vector3(0.0, 0.55 - float(i) * 0.18, 0.0)
		costilla.scale = Vector3(1.0, 1.0, 0.75)
		raiz.add_child(costilla)

	var llamas := CPUParticles3D.new()
	llamas.emitting = true
	llamas.amount = 44
	llamas.lifetime = 0.8
	llamas.direction = Vector3.UP
	llamas.spread = 20.0
	llamas.initial_velocity_min = 1.0
	llamas.initial_velocity_max = 2.4
	llamas.gravity = Vector3.ZERO
	llamas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	llamas.emission_sphere_radius = 0.9
	llamas.scale_amount_min = 0.08
	llamas.scale_amount_max = 0.2
	llamas.color = Color(0.45, 0.6, 1.0, 0.7)
	raiz.add_child(llamas)

	var luz := OmniLight3D.new()
	luz.light_color = azul
	luz.light_energy = 2.2
	luz.omni_range = 5.0
	raiz.add_child(luz)

	# Aparece creciendo y se apaga al final, no de golpe.
	raiz.scale = Vector3.ONE * 0.6
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, duracion - 0.6))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(raiz.queue_free)
	Sfx.play_3d(caster, &"susanoo", caster.global_position + Vector3.UP, 1.0)


## Tengai Shinsei: los dos meteoritos, la sombra que marca donde caen y los impactos.
##
## Todo el reloj del efecto sale de las constantes de TengaiShinsei, las mismas con las
## que el servidor decide cuando pega: la explosion se ve cuando se pierde la vida.
##
## LLEGAN EN DIAGONAL desde ADELANTE, mas alla del punto: bajando desde atras de Madara
## pasaban por encima de la camara y no se veian nunca. El segundo viene arriba y detras
## del primero: se ve uno solo hasta que el primero pega, como en la serie.
func spawn_tengai_shinsei(context: Node, punto: Vector3, rumbo: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var plano := Vector3(rumbo.x, 0.0, rumbo.z).normalized()
	if plano.is_zero_approx():
		plano = Vector3.FORWARD
	_marca_meteorito(world, punto, TengaiShinsei.RADIO_PRIMERO, TengaiShinsei.CAIDA)
	# GIGANTES, a pedido (2026-09-25): el doble de ancho que antes, rocas que tapan medio
	# cielo. Salen desde un poco mas lejos pero no el doble: si no, desde lejos se verian
	# del mismo tamaño que las chicas y solo crecerian al llegar.
	# La roca mide lo mismo que el golpe: lo que se ve caer es lo que pega.
	_meteorito(world, punto, plano, 78.0, 44.0, TengaiShinsei.CAIDA, TengaiShinsei.RADIO_PRIMERO,
		TengaiShinsei.RADIO_PRIMERO)
	_meteorito(world, punto, plano, 125.0, 70.0, TengaiShinsei.CAIDA + TengaiShinsei.ENTRE,
		TengaiShinsei.RADIO_SEGUNDO, TengaiShinsei.RADIO_SEGUNDO)
	# La marca del segundo aparece cuando cae el primero: antes, el que mira arriba ve uno.
	var tree := world.get_tree()
	if tree == null:
		return
	var ref: WeakRef = weakref(world)
	tree.create_timer(TengaiShinsei.CAIDA).timeout.connect(func() -> void:
		var w := ref.get_ref() as Node
		if w != null and w.is_inside_tree():
			_marca_meteorito(w, punto, TengaiShinsei.RADIO_SEGUNDO, TengaiShinsei.ENTRE))
	Sfx.play_3d(context, &"meteorito", punto, 2.0)


## La sombra roja en el piso, latiendo, hasta que cae.
func _marca_meteorito(world: Node, punto: Vector3, radio: float, dura: float) -> void:
	var disco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = radio
	cil.bottom_radius = radio
	cil.height = 0.04
	disco.mesh = cil
	var mat := Art.glow(Color(1.0, 0.22, 0.08), 1.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color.a = 0.18
	disco.material_override = mat
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(disco)
	disco.global_position = punto + Vector3.UP * 0.08
	var tw := disco.create_tween()
	tw.set_loops(int(dura / 0.4) + 1)
	tw.tween_property(mat, "albedo_color:a", 0.36, 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.16, 0.2)
	_auto_free(disco, dura)


## Un meteorito: la roca, la cola de fuego y la luz, bajando hasta `punto`; y al llegar,
## la explosion.
func _meteorito(world: Node, punto: Vector3, plano: Vector3, alto: float, atras: float,
		dura: float, radio: float, tamaño: float, fuerte: bool = true) -> void:
	var roca := Node3D.new()
	world.add_child(roca)
	var cuerpo := Art.sphere(tamaño, Art.toon(Color(0.30, 0.20, 0.15), 0.03, 0.2))
	cuerpo.scale = Vector3(1.0, 0.9, 1.1)
	roca.add_child(cuerpo)
	# Las grietas encendidas: muchas y chicas, asomando apenas de la roca. Pocas y grandes
	# parecian ojos.
	var brasa := Art.glow(Color(1.0, 0.42, 0.08), 2.2)
	for k: int in range(14):
		var ang := TAU * float(k) / 14.0
		var grieta := Art.sphere(tamaño * 0.12, brasa,
			Vector3(cos(ang), sin(ang * 2.3) * 0.7, sin(ang)).normalized() * tamaño * 0.93)
		grieta.scale = Vector3(1.8, 0.35, 1.0)
		roca.add_child(grieta)
	var cola := CPUParticles3D.new()
	cola.emitting = true
	# Segun el tamaño: una roca chica de la lluvia no necesita la cola de una montaña, y
	# caen varias a la vez.
	cola.amount = int(clampf(tamaño * 14.0, 28.0, 110.0))
	cola.lifetime = 0.9
	cola.local_coords = false
	cola.direction = Vector3.UP
	cola.spread = 25.0
	cola.initial_velocity_min = 2.0
	cola.initial_velocity_max = 6.0
	cola.gravity = Vector3.ZERO
	cola.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cola.emission_sphere_radius = tamaño * 0.8
	cola.scale_amount_min = tamaño * 0.3
	cola.scale_amount_max = tamaño * 0.6
	var fuego := Gradient.new()
	fuego.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	fuego.set_color(1, Color(0.3, 0.1, 0.05, 0.0))
	cola.color_ramp = fuego
	roca.add_child(cola)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.5, 0.2)
	luz.light_energy = 4.0
	luz.omni_range = tamaño * 5.0
	roca.add_child(luz)

	var desde := punto + Vector3.UP * alto + plano * atras
	roca.global_position = desde
	var tw := roca.create_tween()
	tw.tween_property(roca, "global_position", punto + Vector3.UP * tamaño * 0.4, dura) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(cuerpo, "rotation", Vector3(2.4, 1.1, 0.6), dura)
	tw.tween_callback(func() -> void:
		cola.emitting = false
		_explosion_meteorito(roca, punto, radio, fuerte))
	# Se hunde en el crater y se va.
	tw.tween_property(roca, "scale", Vector3.ONE * 0.15, 0.7).set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_IN)
	tw.tween_callback(roca.queue_free)


## Un meteorito suelto, el de la lluvia: la sombra en el piso y la roca que baja en diagonal
## desde cualquier lado. Mas chico que los de Madara y sin la sacudida fuerte: caen uno por
## segundo, y con la de Madara la pantalla no pararia de temblar.
func spawn_meteorito_suelto(context: Node, punto: Vector3, radio: float, dura: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var ang := randf() * TAU
	_marca_meteorito(world, punto, radio, dura)
	_meteorito(world, punto, Vector3(cos(ang), 0.0, sin(ang)), 40.0, 20.0, dura, radio, 2.0, false)
	Sfx.play_3d(context, &"meteorito", punto, -9.0)


func _explosion_meteorito(context: Node, punto: Vector3, radio: float, fuerte: bool = true) -> void:
	spawn_pisoton(context, punto, radio)
	spawn_plasma_blast(context, punto + Vector3.UP, radio * 0.8)
	var world := _world_of(context)
	if world != null:
		var polvo := CPUParticles3D.new()
		polvo.emitting = true
		polvo.one_shot = true
		polvo.amount = 90 if fuerte else 36
		polvo.lifetime = 1.6
		polvo.explosiveness = 0.95
		polvo.direction = Vector3.UP
		polvo.spread = 70.0
		polvo.initial_velocity_min = radio * 0.8
		polvo.initial_velocity_max = radio * 1.8
		polvo.gravity = Vector3(0.0, -6.0, 0.0)
		polvo.scale_amount_min = 0.4
		polvo.scale_amount_max = 1.2
		polvo.color = Color(0.45, 0.36, 0.30, 0.85)
		world.add_child(polvo)
		polvo.global_position = punto + Vector3.UP * 0.5
		_auto_free(polvo, 2.2)
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.6, 0.25)
		luz.light_energy = 16.0
		luz.omni_range = radio * 3.0
		world.add_child(luz)
		luz.global_position = punto + Vector3.UP * 2.0
		_fade_light(luz, 0.9)
	camera_shake(2.4 if fuerte else 0.5)
	Sfx.play_3d(context, &"plasma_blast", punto, 4.0 if fuerte else -4.0)
	Sfx.play_3d(context, &"aterrizaje", punto, 6.0 if fuerte else -2.0)


# ------------------------------------------------------- Temporada 3: comunes

## El anillo de espinas de la ruta Snowgrave: un aro celeste con puas, flotando y girando en
## un rincon del mapa. Se queda hasta que alguien lo toma (lo saca la mision).
##
## SE TIENE QUE PODER ENCONTRAR. La primera version era un aro de cuarenta centimetros
## con una luz chica, y desde donde arranca Noelle no se veia: estar escondido no puede
## querer decir estar invisible. Ahora es mas grande, brilla mas y tiene una columna de
## destellos de hielo que sube y se ve desde lejos.
func armar_anillo_espinas(context: Node, pos: Vector3) -> Node3D:
	var world := _world_of(context)
	if world == null:
		return null
	var anillo := Node3D.new()
	anillo.name = &"AnilloEspinas"
	world.add_child(anillo)
	anillo.global_position = pos + Vector3.UP * 1.1
	var hielo := Art.glow(Color(0.60, 0.85, 1.0), 3.0)
	var giro := Node3D.new()
	anillo.add_child(giro)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.34
	toro.outer_radius = 0.46
	aro.mesh = toro
	aro.material_override = hielo
	aro.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	giro.add_child(aro)
	for k: int in range(10):
		var ang := TAU * float(k) / 10.0
		var pua := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.05
		cono.height = 0.24
		pua.mesh = cono
		pua.material_override = hielo
		pua.position = Vector3(cos(ang) * 0.52, sin(ang) * 0.52, 0.0)
		pua.rotation = Vector3(0.0, 0.0, ang - PI * 0.5)
		giro.add_child(pua)
	# La columna de destellos: lo que se ve de lejos, por encima de las coberturas.
	var destellos := CPUParticles3D.new()
	destellos.emitting = true
	destellos.amount = 40
	destellos.lifetime = 2.2
	destellos.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	destellos.emission_sphere_radius = 0.5
	destellos.direction = Vector3.UP
	destellos.spread = 8.0
	destellos.initial_velocity_min = 1.6
	destellos.initial_velocity_max = 2.6
	destellos.gravity = Vector3.ZERO
	destellos.scale_amount_min = 0.08
	destellos.scale_amount_max = 0.16
	destellos.color = Color(0.70, 0.90, 1.0, 0.9)
	var punto := QuadMesh.new()
	punto.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Art.punto_suave()
	punto.material = mat
	destellos.mesh = punto
	anillo.add_child(destellos)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.60, 0.85, 1.0)
	luz.light_energy = 3.5
	luz.omni_range = 7.0
	anillo.add_child(luz)
	var tw := giro.create_tween().set_loops()
	tw.tween_property(giro, "rotation:y", TAU, 2.4).from(0.0)
	return anillo


## El hueso de DIO, de la ruta del Cielo: un hueso dorado que flota y gira, con la misma
## columna de destellos que el anillo de espinas —en dorado— para que se vea de lejos.
func armar_hueso_dio(context: Node, pos: Vector3) -> Node3D:
	var world := _world_of(context)
	if world == null:
		return null
	var hueso := Node3D.new()
	hueso.name = &"HuesoDio"
	world.add_child(hueso)
	hueso.global_position = pos + Vector3.UP * 1.1
	var oro := Art.glow(Color(1.0, 0.82, 0.35), 2.6)
	var giro := Node3D.new()
	hueso.add_child(giro)
	var cana := Art.capsule(0.07, 0.62, oro)
	cana.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	giro.add_child(cana)
	for lado: float in [-1.0, 1.0]:
		for arriba: float in [-1.0, 1.0]:
			giro.add_child(Art.sphere(0.085, oro, Vector3(0.32 * lado, 0.06 * arriba, 0.0)))
	var destellos := CPUParticles3D.new()
	destellos.emitting = true
	destellos.amount = 40
	destellos.lifetime = 2.2
	destellos.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	destellos.emission_sphere_radius = 0.5
	destellos.direction = Vector3.UP
	destellos.spread = 8.0
	destellos.initial_velocity_min = 1.6
	destellos.initial_velocity_max = 2.6
	destellos.gravity = Vector3.ZERO
	destellos.scale_amount_min = 0.08
	destellos.scale_amount_max = 0.16
	destellos.color = Color(1.0, 0.85, 0.40, 0.9)
	var punto := QuadMesh.new()
	punto.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Art.punto_suave()
	punto.material = mat
	destellos.mesh = punto
	hueso.add_child(destellos)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.85, 0.40)
	luz.light_energy = 3.5
	luz.omni_range = 7.0
	hueso.add_child(luz)
	var tw := giro.create_tween().set_loops()
	tw.tween_property(giro, "rotation:y", TAU, 2.4).from(0.0)
	return hueso


# ------------------------------------------------------------- Modos de juego

## La bomba de la bomba caliente: negra y redonda, con la mecha y la chispa encendida. La
## arena la cuelga arriba de la cabeza de quien la tiene y hace latir la luz ("Luz").
func armar_bomba(context: Node) -> Node3D:
	var world := _world_of(context)
	if world == null:
		return null
	var bomba := Node3D.new()
	bomba.name = &"Bomba"
	world.add_child(bomba)
	var negro := Art.toon(Color(0.10, 0.10, 0.12))
	var cuerpo := Art.sphere(0.30, negro)
	bomba.add_child(cuerpo)
	# El brillo del costado: sin el, de lejos era un agujero negro flotando.
	bomba.add_child(Art.sphere(0.07, Art.glow(Color(0.85, 0.85, 0.95), 1.2), Vector3(-0.13, 0.14, -0.18)))
	var boca := Art.cylinder(0.10, 0.10, Art.toon(Color(0.35, 0.35, 0.40)), Vector3(0.0, 0.31, 0.0))
	bomba.add_child(boca)
	var mecha := Art.cylinder(0.025, 0.20, Art.toon(Color(0.80, 0.70, 0.50)), Vector3(0.04, 0.44, 0.0))
	mecha.rotation_degrees = Vector3(0.0, 0.0, -18.0)
	bomba.add_child(mecha)
	var chispa := Art.sphere(0.06, Art.glow(Color(1.0, 0.65, 0.20), 4.0), Vector3(0.08, 0.55, 0.0))
	bomba.add_child(chispa)
	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 18
	chispas.lifetime = 0.5
	chispas.direction = Vector3.UP
	chispas.spread = 60.0
	chispas.initial_velocity_min = 0.8
	chispas.initial_velocity_max = 1.8
	chispas.gravity = Vector3(0.0, -2.0, 0.0)
	chispas.scale_amount_min = 0.03
	chispas.scale_amount_max = 0.06
	chispas.color = Color(1.0, 0.75, 0.30)
	chispas.position = Vector3(0.08, 0.55, 0.0)
	bomba.add_child(chispas)
	var luz := OmniLight3D.new()
	luz.name = &"Luz"
	luz.light_color = Color(1.0, 0.45, 0.15)
	luz.light_energy = 2.0
	luz.omni_range = 5.0
	luz.shadow_enabled = false
	luz.position = Vector3(0.0, 0.5, 0.0)
	bomba.add_child(luz)
	return bomba


## La explosion de la bomba: un fogonazo, el humo y una luz que se apaga.
func spawn_explosion_bomba(context: Node, pos: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return
	spawn_impact_burst(context, pos, Color(1.0, 0.55, 0.12))
	spawn_impact_burst(context, pos + Vector3.UP * 0.4, Color(1.0, 0.85, 0.35))
	var bola := Art.sphere(1.0, _brillo_alfa(Color(1.0, 0.55, 0.15), 3.0, 0.85))
	world.add_child(bola)
	bola.global_position = pos
	bola.scale = Vector3.ONE * 0.3
	var tw := bola.create_tween()
	tw.tween_property(bola, "scale", Vector3.ONE * 3.2, 0.35)
	tw.parallel().tween_property(bola.material_override, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(bola.queue_free)
	var humo := CPUParticles3D.new()
	humo.emitting = true
	humo.one_shot = true
	humo.amount = 36
	humo.lifetime = 1.1
	humo.explosiveness = 0.9
	humo.direction = Vector3.UP
	humo.spread = 80.0
	humo.initial_velocity_min = 2.0
	humo.initial_velocity_max = 4.5
	humo.damping_min = 2.0
	humo.damping_max = 3.5
	humo.gravity = Vector3(0.0, 1.0, 0.0)
	humo.scale_amount_min = 0.35
	humo.scale_amount_max = 0.8
	humo.color = Color(0.30, 0.28, 0.28, 0.85)
	world.add_child(humo)
	humo.global_position = pos
	_auto_free(humo, 1.8)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.20)
	luz.light_energy = 8.0
	luz.omni_range = 12.0
	world.add_child(luz)
	luz.global_position = pos
	_fade_light(luz, 0.6)


## Una esfera de la caza: dorada, flotando y girando, con una columna de luz alta que se
## ve desde cualquier punto del mapa, por encima de las coberturas.
func armar_esfera(context: Node, pos: Vector3) -> Node3D:
	var world := _world_of(context)
	if world == null:
		return null
	var esfera := Node3D.new()
	esfera.name = &"Esfera"
	world.add_child(esfera)
	esfera.global_position = pos
	var flota := Node3D.new()
	flota.position = Vector3.UP * 1.1
	esfera.add_child(flota)
	flota.add_child(Art.sphere(0.45, Art.glow(Color(1.0, 0.70, 0.18), 2.2)))
	# Las estrellas de adentro, para que no sea una pelota lisa.
	for k: int in range(4):
		var ang := TAU * float(k) / 4.0
		flota.add_child(Art.sphere(0.06, Art.glow(Color(0.95, 0.20, 0.15), 2.0),
			Vector3(cos(ang) * 0.18, sin(ang) * 0.18, -0.40)))
	var columna := Art.cylinder(0.22, 40.0, _brillo_alfa(Color(1.0, 0.80, 0.30), 2.0, 0.35),
		Vector3(0.0, 20.0, 0.0))
	columna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	esfera.add_child(columna)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.75, 0.30)
	luz.light_energy = 3.0
	luz.omni_range = 7.0
	luz.position = Vector3.UP * 1.2
	esfera.add_child(luz)
	var tw := flota.create_tween().set_loops()
	tw.tween_property(flota, "position:y", 1.35, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(flota, "position:y", 1.1, 0.9).set_trans(Tween.TRANS_SINE)
	var giro := flota.create_tween().set_loops()
	giro.tween_property(flota, "rotation:y", TAU, 3.0).from(0.0)
	return esfera


## Un material de brillo que se puede desvanecer. Todos los efectos de abajo lo usan.
func _brillo_alfa(color: Color, energia: float, alfa: float) -> StandardMaterial3D:
	var mat := Art.glow(color, energia)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color.a = alfa
	return mat


## Una barra entre dos puntos, orientada. La usan los rayos, los brazos de goma y los hilos.
func _barra(world: Node, desde: Vector3, hasta: Vector3, radio: float, mat: Material) -> MeshInstance3D:
	var barra := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = 1.0
	malla.radial_segments = 8
	barra.mesh = malla
	barra.material_override = mat
	barra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(barra)
	var tramo := hasta - desde
	var largo := maxf(0.05, tramo.length())
	var eje := tramo / largo
	var base := Basis(Vector3.RIGHT, PI) if eje.dot(Vector3.UP) < -0.999 else Basis(Quaternion(Vector3.UP, eje))
	barra.global_transform = Transform3D(base * Basis.from_scale(Vector3(1.0, largo, 1.0)), (desde + hasta) * 0.5)
	return barra


## Humo blanco: como se van y vienen los clones de sombra.
func spawn_humo(context: Node, pos: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var humo := CPUParticles3D.new()
	humo.emitting = true
	humo.one_shot = true
	humo.amount = 28
	humo.lifetime = 0.7
	humo.explosiveness = 0.9
	humo.direction = Vector3.UP
	humo.spread = 90.0
	humo.initial_velocity_min = 1.0
	humo.initial_velocity_max = 2.6
	humo.damping_min = 2.0
	humo.damping_max = 4.0
	humo.gravity = Vector3(0.0, 0.8, 0.0)
	humo.scale_amount_min = 0.25
	humo.scale_amount_max = 0.55
	humo.color = Color(0.92, 0.92, 0.94, 0.8)
	world.add_child(humo)
	humo.global_position = pos + Vector3.UP * 0.6
	_auto_free(humo, 1.2)
	Sfx.play_3d(context, &"dash", pos, -8.0)


# ------------------------------------------------------------------- Sans

## Huesos del piso: la linea que avisa en el piso y, al vencer el aviso, los huesos.
func spawn_huesos_piso(context: Node, desde: Vector3, rumbo: Vector3, largo: float, aviso: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var plano := Vector3(rumbo.x, 0.0, rumbo.z).normalized()
	if plano.is_zero_approx():
		return
	var marca := _barra(world, desde + Vector3.UP * 0.06, desde + plano * largo + Vector3.UP * 0.06, 0.9,
		_brillo_alfa(Color(0.75, 0.88, 1.0), 1.4, 0.25))
	marca.scale = Vector3(1.0, 1.0, 0.04)
	_auto_free(marca, aviso)
	var tree := world.get_tree()
	if tree == null:
		return
	var ref: WeakRef = weakref(world)
	tree.create_timer(aviso).timeout.connect(func() -> void:
		var w := ref.get_ref() as Node
		if w == null or not w.is_inside_tree():
			return
		var blanco := Art.toon(Color(0.96, 0.96, 0.93), 0.01)
		var n := int(largo / 0.8)
		for k: int in range(n):
			var hueso := Art.capsule(0.07, 1.2, blanco)
			w.add_child(hueso)
			hueso.global_position = desde + plano * (0.8 + float(k) * 0.8) + Vector3.DOWN * 0.6
			var tw := hueso.create_tween()
			tw.tween_property(hueso, "position:y", hueso.position.y + 1.1, 0.12)
			tw.tween_interval(0.35)
			tw.tween_property(hueso, "position:y", hueso.position.y - 0.2, 0.2)
			tw.tween_callback(hueso.queue_free)
		Sfx.play_3d(w, &"hueso", desde + plano * largo * 0.5, 2.0))


## Alma azul: el corazon azul que le queda arriba al que la recibio, mientras dura.
func spawn_alma_azul(context: Node, origin: Vector3, blanco: Node3D) -> void:
	var world := _world_of(context)
	if world == null:
		return
	Sfx.play_3d(context, &"gema", origin, -2.0)
	if blanco == null or not is_instance_valid(blanco):
		spawn_impact_burst(context, origin + (context as Node3D).global_transform.basis.z * -2.0 if context is Node3D else origin,
			Color(0.3, 0.5, 1.0, 0.8))
		return
	var linea := _barra(world, origin, blanco.global_position + Vector3.UP, 0.05, _brillo_alfa(Color(0.35, 0.55, 1.0), 2.0, 0.7))
	var tw := linea.create_tween()
	tw.tween_property(linea.material_override, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(linea.queue_free)
	var corazon := Node3D.new()
	var azul := Art.glow(Color(0.25, 0.45, 1.0), 2.6)
	for lado: float in [-1.0, 1.0]:
		corazon.add_child(Art.sphere(0.09, azul, Vector3(0.06 * lado, 0.04, 0.0)))
	var punta := Art.box(Vector3(0.13, 0.13, 0.09), azul, Vector3(0.0, -0.04, 0.0))
	punta.rotation_degrees = Vector3(0.0, 0.0, 45.0)
	corazon.add_child(punta)
	blanco.add_child(corazon)
	corazon.position = Vector3(0.0, 2.35, 0.0)
	_auto_free(corazon, AlmaAzul.LENTO_DURA)
	spawn_impact_burst(context, blanco.global_position + Vector3.UP, Color(0.3, 0.5, 1.0, 0.95))


## Una calavera de dragon, la de los Gaster Blaster, mirando hacia `rumbo`.
func _calavera_blaster(world: Node, pos: Vector3, rumbo: Vector3) -> Node3D:
	var c := Node3D.new()
	world.add_child(c)
	c.global_position = pos
	var arriba := Vector3.FORWARD if absf(rumbo.normalized().y) > 0.98 else Vector3.UP
	c.look_at(pos + rumbo, arriba)
	var hueso := Art.toon(Color(0.96, 0.96, 0.94), 0.012)
	var negro := Art.flat(Color(0.03, 0.03, 0.05))
	var craneo := Art.sphere(0.45, hueso)
	craneo.scale = Vector3(1.0, 0.8, 1.35)
	c.add_child(craneo)
	var hocico := Art.box(Vector3(0.5, 0.25, 0.55), hueso, Vector3(0.0, -0.1, -0.55))
	c.add_child(hocico)
	for lado: float in [-1.0, 1.0]:
		c.add_child(Art.sphere(0.11, negro, Vector3(0.2 * lado, 0.12, -0.42)))
		c.add_child(Art.sphere(0.04, Art.glow(Color(0.55, 0.85, 1.0), 3.0), Vector3(0.2 * lado, 0.12, -0.5)))
		var cuerno := Art.box(Vector3(0.08, 0.08, 0.5), hueso, Vector3(0.32 * lado, 0.25, 0.35))
		cuerno.rotation_degrees = Vector3(-25.0, 18.0 * lado, 0.0)
		c.add_child(cuerno)
	return c


## Las calaveras durante la carga: aparecen donde van a tirar y miran al cruce.
func spawn_blasters_carga(caster: Node3D, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var world := _world_of(caster)
	if world == null:
		return
	for r: Array in GasterBlaster.rayos_de(caster, -caster.global_transform.basis.z):
		var c := _calavera_blaster(world, r[0], r[1])
		c.scale = Vector3.ONE * 0.2
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_auto_free(c, duracion + 0.05)


## Los Gaster Blaster: las calaveras y los tres rayos.
func spawn_gaster_blaster(caster: Node, rayos: Array, largo: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	for r: Array in rayos:
		var desde: Vector3 = r[0]
		var rumbo: Vector3 = r[1]
		var c := _calavera_blaster(world, desde, rumbo)
		_auto_free(c, 0.7)
		var mat := _brillo_alfa(Color(0.92, 0.97, 1.0), 2.2, 0.8)
		var rayo := _barra(world, desde + rumbo * 0.8, desde + rumbo * largo, 0.42, mat)
		var tw := rayo.create_tween().set_parallel()
		tw.tween_property(rayo, "scale:x", 0.05, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(rayo, "scale:z", 0.05, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
		tw.chain().tween_callback(rayo.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.85, 0.95, 1.0)
	luz.light_energy = 10.0
	luz.omni_range = 16.0
	world.add_child(luz)
	luz.global_position = (rayos[0][0] as Vector3)
	_fade_light(luz, 0.6)
	camera_shake(1.8)
	Sfx.play_3d(caster, &"snowgrave", (rayos[0][0] as Vector3), 0.0)


# ----------------------------------------------------------------- Naruto

## La esfera que se arma en la mano: el Rasengan mientras se carga y mientras corre.
func spawn_esfera_mano(caster: Node3D, color: Color, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var esfera := Node3D.new()
	caster.add_child(esfera)
	esfera.position = Vector3(0.32, 1.15, -0.45)
	esfera.add_child(Art.sphere(0.18, Art.glow(color.lightened(0.4), 3.0)))
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.2
	toro.outer_radius = 0.26
	anillo.mesh = toro
	anillo.material_override = Art.glow(color, 2.4)
	esfera.add_child(anillo)
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 2.5
	luz.omni_range = 3.5
	esfera.add_child(luz)
	var tw := esfera.create_tween().set_loops(int(duracion / 0.2) + 1)
	tw.tween_property(anillo, "rotation:y", TAU, 0.2).from(0.0)
	_auto_free(esfera, duracion)


# ------------------------------------------------------------------ Luffy

## El brazo de goma: se estira hasta la punta y vuelve.
func spawn_brazo_goma(caster: Node3D, origin: Vector3, rumbo: Vector3, largo: float,
		grosor: float = 1.0) -> void:
	if not is_instance_valid(caster):
		return
	var world := _world_of(caster)
	if world == null:
		return
	var piel := Art.toon(Color(0.96, 0.78, 0.62), 0.01)
	var punta := origin + rumbo.normalized() * largo
	# `grosor`: en Gear Fifth el brazo engorda y el puño se vuelve gigante.
	var brazo := _barra(world, origin, punta, 0.07 * minf(grosor, 1.8), piel)
	var puño := Art.sphere(0.14 * grosor * 1.2 if grosor > 1.0 else 0.14, piel)
	world.add_child(puño)
	puño.global_position = punta
	var tw := brazo.create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(puño.queue_free)
	tw.tween_callback(brazo.queue_free)
	Sfx.play_3d(caster, &"goma", origin, -6.0)


## El Gear Fifth: el aura blanca con las nubes, mientras dura.
func spawn_gear_fifth(caster: Node3D, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var viejo := caster.get_node_or_null(^"AuraSuper")
	if viejo != null:
		viejo.queue_free()
	var aura := Node3D.new()
	aura.name = &"AuraSuper"
	caster.add_child(aura)
	aura.position = Vector3(0.0, 1.0, 0.0)
	var cascara := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.75
	capsula.height = 2.5
	cascara.mesh = capsula
	# TENUE A PROPOSITO: blanca y con mucho brillo tapaba a Luffy entero, y un efecto que
	# esconde al personaje es una ventaja en un PvP.
	var mat := _brillo_alfa(Color(1.0, 1.0, 0.98), 0.7, 0.10)
	cascara.material_override = mat
	cascara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(cascara)
	# Las nubes blancas del Nika, alrededor de los hombros: suben despacio y se abren.
	var nubes := CPUParticles3D.new()
	nubes.emitting = true
	nubes.amount = 26
	nubes.lifetime = 1.2
	nubes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	nubes.emission_sphere_radius = 0.7
	nubes.direction = Vector3.UP
	nubes.spread = 40.0
	nubes.initial_velocity_min = 0.3
	nubes.initial_velocity_max = 1.0
	nubes.gravity = Vector3(0.0, 0.6, 0.0)
	nubes.scale_amount_min = 0.2
	nubes.scale_amount_max = 0.45
	nubes.color = Color(1.0, 1.0, 1.0, 0.8)
	aura.add_child(nubes)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.98, 0.92)
	luz.light_energy = 2.4
	luz.omni_range = 7.0
	aura.add_child(luz)
	var tw := cascara.create_tween()
	tw.set_loops(int(duracion / 0.5) + 1)
	tw.tween_property(mat, "albedo_color:a", 0.14, 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.07, 0.25)
	_auto_free(aura, duracion)
	spawn_pisoton(caster, caster.global_position, GearFifth.RADIO_ESTALLIDO)
	camera_shake(1.4)
	Sfx.play_3d(caster, &"estrella", caster.global_position, 0.0)


# ------------------------------------------------------------- Spider-Man

## La tela pegada en el que la comio: una mancha blanca que dura lo que dura lo lento.
func spawn_telarana_pegada(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var tela := Node3D.new()
	target.add_child(tela)
	tela.position = Vector3(0.0, 0.9, 0.0)
	var blanco := Art.toon(Color(0.95, 0.95, 0.97), 0.0)
	for k: int in range(5):
		var hilo := Art.box(Vector3(0.7, 0.02, 0.02), blanco)
		hilo.rotation_degrees = Vector3(float(k) * 36.0, float(k) * 36.0, 30.0)
		tela.add_child(hilo)
	_auto_free(tela, Telarana.LENTO_DURA)


## El balanceo: el hilo que sube desde la mano hacia un punto alto, adelante.
func spawn_hilo_balanceo(caster: Node3D, rumbo: Vector3, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var world := _world_of(caster)
	if world == null:
		return
	var ancla := caster.global_position + rumbo * 7.0 + Vector3.UP * 12.0
	var mat := Art.toon(Color(0.95, 0.95, 0.97), 0.0)
	var hilo := _barra(world, caster.global_position + Vector3.UP * 1.4, ancla, 0.025, mat)
	var tw := hilo.create_tween()
	tw.tween_interval(duracion)
	tw.tween_callback(hilo.queue_free)


## Red Total: un hilo a cada uno que alcanza, y la tela encima.
func spawn_red_total(caster: Node3D, blancos: Array) -> void:
	if not is_instance_valid(caster):
		return
	var world := _world_of(caster)
	if world == null:
		return
	var mat := Art.toon(Color(0.95, 0.95, 0.97), 0.0)
	var desde := caster.global_position + Vector3.UP * 1.3
	for t: Node3D in blancos:
		if not is_instance_valid(t):
			continue
		var hilo := _barra(world, desde, t.global_position + Vector3.UP, 0.03, mat)
		var tw := hilo.create_tween()
		tw.tween_interval(0.35)
		tw.tween_callback(hilo.queue_free)
		var pegada := Node3D.new()
		t.add_child(pegada)
		pegada.position = Vector3(0.0, 0.9, 0.0)
		for k: int in range(6):
			var h := Art.box(Vector3(0.9, 0.02, 0.02), mat)
			h.rotation_degrees = Vector3(float(k) * 30.0, float(k) * 30.0, 25.0)
			pegada.add_child(h)
		_auto_free(pegada, RedTotal.LENTO_DURA)
	spawn_impact_burst(caster, desde, Color(0.95, 0.95, 1.0, 0.9))
	camera_shake(0.9)
	Sfx.play_3d(caster, &"telarana", desde, 3.0)


# ------------------------------------------------------------------- Gojo

## Azul: el punto que atrae, con el remolino que se cierra hacia el centro.
func spawn_azul(context: Node, punto: Vector3, radio: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var esfera := Art.sphere(0.45, Art.glow(Color(0.35, 0.60, 1.0), 3.0))
	world.add_child(esfera)
	esfera.global_position = punto
	var tw := esfera.create_tween()
	tw.tween_property(esfera, "scale", Vector3.ONE * 1.4, 0.5).from(Vector3.ONE * 0.3)
	tw.tween_property(esfera, "scale", Vector3.ONE * 0.05, 0.3)
	tw.tween_callback(esfera.queue_free)
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = radio * 0.92
	toro.outer_radius = radio
	anillo.mesh = toro
	var mat := _brillo_alfa(Color(0.35, 0.60, 1.0), 2.0, 0.6)
	anillo.material_override = mat
	world.add_child(anillo)
	anillo.global_position = punto + Vector3.DOWN * 0.8
	var tw2 := anillo.create_tween().set_parallel()
	tw2.tween_property(anillo, "scale", Vector3.ONE * 0.1, 0.6)
	tw2.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw2.chain().tween_callback(anillo.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.35, 0.60, 1.0)
	luz.light_energy = 5.0
	luz.omni_range = radio * 1.6
	world.add_child(luz)
	luz.global_position = punto
	_fade_light(luz, 0.8)
	Sfx.play_3d(context, &"portal", punto, -1.0)


# --------------------------------------------------------------- Scorpion

## El Fuego del Infierno: el circulo de brasas que avisa y, al vencer el aviso, la columna.
##
## El reloj sale de FuegoInfernal.AVISO, el mismo con el que el servidor decide cuando
## pega: las llamas suben cuando se pierde la vida.
func spawn_fuego_infernal(context: Node, punto: Vector3, radio: float, aviso: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	_marca_meteorito(world, punto, radio, aviso)
	Sfx.play_3d(context, &"fuego", punto, -2.0)
	var tree := world.get_tree()
	if tree == null:
		return
	var ref: WeakRef = weakref(world)
	tree.create_timer(aviso).timeout.connect(func() -> void:
		var w := ref.get_ref() as Node
		if w != null and w.is_inside_tree():
			_columna_fuego(w, punto, radio, true))


## Llamas del Inframundo alrededor de un cuerpo: como entra y como se va Scorpion en las
## escenas, que es su teletransporte de siempre.
func spawn_llamas_infierno(context: Node, pos: Vector3) -> void:
	var world := _world_of(context)
	if world != null:
		_columna_fuego(world, pos, 1.1, false)


## Una columna de fuego que sube desde el piso.
func _columna_fuego(world: Node, punto: Vector3, radio: float, fuerte: bool) -> void:
	var fuego := Gradient.new()
	fuego.set_color(0, Color(1.0, 0.62, 0.15, 0.55))
	fuego.set_color(1, Color(0.40, 0.04, 0.0, 0.0))
	fuego.add_point(0.35, Color(1.0, 0.30, 0.04, 0.45))
	var llamas := CPUParticles3D.new()
	llamas.emitting = true
	llamas.one_shot = true
	llamas.amount = 110 if fuerte else 60
	llamas.lifetime = 0.8
	llamas.explosiveness = 0.75
	llamas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	llamas.emission_sphere_radius = radio * 0.7
	llamas.direction = Vector3.UP
	llamas.spread = 12.0
	llamas.initial_velocity_min = 6.0 if fuerte else 3.5
	llamas.initial_velocity_max = 12.0 if fuerte else 6.0
	llamas.damping_min = 4.0
	llamas.damping_max = 7.0
	llamas.gravity = Vector3(0.0, 2.0, 0.0)
	llamas.scale_amount_min = 0.4
	llamas.scale_amount_max = 1.1 if fuerte else 0.8
	llamas.color_ramp = fuego
	var malla := QuadMesh.new()
	malla.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Art.punto_suave()
	malla.material = mat
	llamas.mesh = malla
	world.add_child(llamas)
	llamas.global_position = punto + Vector3.UP * 0.2
	_auto_free(llamas, 1.6)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.45, 0.12)
	luz.light_energy = 9.0 if fuerte else 4.0
	luz.omni_range = radio * 4.0
	world.add_child(luz)
	luz.global_position = punto + Vector3.UP * 1.5
	_fade_light(luz, 0.7)
	spawn_impact_burst(world, punto + Vector3.UP, Color(1.0, 0.50, 0.12, 0.95))
	if fuerte:
		camera_shake(0.6)
		Sfx.play_3d(world, &"katon", punto, -1.0)


## El Aliento del Infierno: el fuego del Katon, corrido al rojo del Inframundo, saliendo de
## la calavera.
func spawn_aliento_infierno(caster: Node, origin: Vector3, dir: Vector3, alcance: float, angulo: float) -> void:
	spawn_katon(caster, origin, dir, alcance, angulo)
	camera_shake(1.0)


## La calavera de Scorpion: lo que hay abajo de la mascara. La usan la carga del Aliento
## del Infierno (un rato, mientras escupe) y la skin legendaria (para siempre).
##
## OPACA a proposito: un disfraz que deja ver a traves es una ventaja en un PvP.
func armar_calavera(padre: Node3D, hueso: Color, con_llamas: bool) -> Node3D:
	var calavera := Node3D.new()
	calavera.name = &"Calavera"
	padre.add_child(calavera)
	calavera.position = Vector3(0.0, 0.11, 0.0)
	var mat_hueso := Art.toon(hueso, 0.012)
	var negro := Art.flat(Color(0.04, 0.02, 0.02))
	var brasa := Art.glow(Color(1.0, 0.45, 0.10), 3.0)
	var craneo := Art.sphere(0.218, mat_hueso)
	craneo.scale = Vector3(0.95, 1.02, 1.0)
	calavera.add_child(craneo)
	for lado: float in [-1.0, 1.0]:
		var cuenca := Art.sphere(0.055, negro, Vector3(0.075 * lado, 0.02, -0.180))
		cuenca.scale = Vector3(1.1, 1.0, 0.5)
		calavera.add_child(cuenca)
		calavera.add_child(Art.sphere(0.02, brasa, Vector3(0.075 * lado, 0.02, -0.205)))
	var nariz := Art.box(Vector3(0.04, 0.05, 0.02), negro, Vector3(0.0, -0.05, -0.205))
	calavera.add_child(nariz)
	var mandibula := Art.box(Vector3(0.20, 0.07, 0.16), mat_hueso, Vector3(0.0, -0.17, -0.06))
	calavera.add_child(mandibula)
	for k: int in range(6):
		var diente := Art.box(Vector3(0.018, 0.03, 0.01), negro,
			Vector3((float(k) - 2.5) * 0.028, -0.12, -0.192))
		calavera.add_child(diente)
	if con_llamas:
		for k: int in range(5):
			var llama := MeshInstance3D.new()
			var cono := CylinderMesh.new()
			cono.top_radius = 0.0
			cono.bottom_radius = 0.06
			cono.height = 0.16 + float(k % 2) * 0.06
			llama.mesh = cono
			llama.material_override = brasa
			llama.position = Vector3((float(k) - 2.0) * 0.07, 0.24 - absf(float(k) - 2.0) * 0.03, 0.03)
			llama.rotation_degrees = Vector3(-8.0, 0.0, (float(k) - 2.0) * -12.0)
			calavera.add_child(llama)
	return calavera


# ----------------------------------------------------------------- Thanos

## La Gema del Espacio: el espacio que se abre en azul donde sale y donde llega.
func spawn_gema_espacio(context: Node, pos: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.7
	toro.outer_radius = 0.85
	anillo.mesh = toro
	var mat := Art.glow(Color(0.30, 0.55, 1.0), 2.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	anillo.material_override = mat
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(anillo)
	anillo.global_position = pos + Vector3.UP * 1.0
	anillo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var tw := anillo.create_tween().set_parallel()
	tw.tween_property(anillo, "scale", Vector3.ONE * 1.6, 0.45).from(Vector3.ONE * 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5).from(0.9)
	tw.chain().tween_callback(anillo.queue_free)
	spawn_impact_burst(context, pos + Vector3.UP, Color(0.35, 0.60, 1.0, 0.95))
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.35, 0.55, 1.0)
	luz.light_energy = 5.0
	luz.omni_range = 6.0
	world.add_child(luz)
	luz.global_position = pos + Vector3.UP
	_fade_light(luz, 0.5)
	Sfx.play_3d(context, &"portal", pos, -3.0)


## El Chasquido: el destello de las seis gemas desde el Guantelete, y el polvo en cada
## enemigo, esten donde esten. Corre igual en el servidor y en cada cliente: los enemigos
## del que chasquea se calculan en cada pantalla con la misma regla.
func spawn_chasquido(caster: Node3D) -> void:
	if not is_instance_valid(caster):
		return
	var world := _world_of(caster)
	if world == null:
		return
	var gemas: Array[Color] = [Color(0.25, 0.45, 1.0), Color(1.0, 0.85, 0.2), Color(0.95, 0.12, 0.16),
		Color(0.62, 0.22, 0.95), Color(0.2, 0.9, 0.35), Color(1.0, 0.52, 0.12)]
	var centro := caster.global_position + Vector3.UP * 1.6
	for k: int in range(gemas.size()):
		var anillo := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.9
		toro.outer_radius = 1.0
		anillo.mesh = toro
		var mat := Art.glow(gemas[k], 3.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		anillo.material_override = mat
		anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(anillo)
		anillo.global_position = centro
		anillo.rotation_degrees = Vector3(90.0 + float(k) * 30.0, float(k) * 30.0, 0.0)
		var tw := anillo.create_tween().set_parallel()
		tw.tween_property(anillo, "scale", Vector3.ONE * (7.0 + float(k)), 0.7).from(Vector3.ONE * 0.2) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.7).from(0.85)
		tw.chain().tween_callback(anillo.queue_free)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.92, 0.75)
	luz.light_energy = 14.0
	luz.omni_range = 20.0
	world.add_child(luz)
	luz.global_position = centro
	_fade_light(luz, 0.9)
	# LA ONDA QUE BARRE EL MAPA: el chasquido le llega a todos, este donde este, y eso tiene
	# que verse. Un anillo blanco a ras del piso que sale de Thanos y cruza la arena entera.
	var onda := MeshInstance3D.new()
	var toro_onda := TorusMesh.new()
	toro_onda.inner_radius = 0.96
	toro_onda.outer_radius = 1.0
	onda.mesh = toro_onda
	var mat_onda := Art.glow(Color(1.0, 0.95, 0.85), 2.6)
	mat_onda.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	onda.material_override = mat_onda
	onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(onda)
	onda.global_position = caster.global_position + Vector3.UP * 0.4
	var tw_onda := onda.create_tween().set_parallel()
	tw_onda.tween_property(onda, "scale", Vector3(70.0, 3.0, 70.0), 1.1).from(Vector3(1.0, 1.0, 1.0)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_onda.tween_property(mat_onda, "albedo_color:a", 0.0, 1.1).from(0.9)
	tw_onda.chain().tween_callback(onda.queue_free)
	camera_shake(1.6)
	Sfx.play_3d(caster, &"chasquido", centro, 6.0)
	for target: Node3D in CombatUtils._living_targets(caster):
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null and estado.es_invencible():
			continue
		spawn_polvo_chasquido(target)


## EL SENTIDO ARACNIDO: las rayitas que le salen de la cabeza cuando siente venir el golpe,
## como en las historietas. Blancas y cortas, en abanico, y se van enseguida.
func spawn_sentido_aracnido(cuerpo: Node3D) -> void:
	if not is_instance_valid(cuerpo):
		return
	var rayas := Node3D.new()
	cuerpo.add_child(rayas)
	rayas.position = Vector3(0.0, 2.05, 0.0)
	var mat := Art.glow(Color(1.0, 1.0, 0.95), 2.5)
	for k: int in range(7):
		var ang := deg_to_rad(-75.0 + float(k) * 25.0)
		var raya := Art.box(Vector3(0.035, 0.22, 0.035), mat,
			Vector3(sin(ang) * 0.30, cos(ang) * 0.22, 0.0))
		raya.rotation = Vector3(0.0, 0.0, -ang)
		rayas.add_child(raya)
	var tw := rayas.create_tween()
	tw.tween_property(rayas, "scale", Vector3.ONE * 1.3, 0.12).from(Vector3.ONE * 0.4)
	tw.tween_interval(0.25)
	tw.tween_property(rayas, "scale", Vector3.ZERO, 0.12)
	tw.tween_callback(rayas.queue_free)
	Sfx.play_3d(cuerpo, &"sentido_aracnido", cuerpo.global_position, -4.0)


## LAS SEIS GEMAS SE ENCIENDEN DE A UNA mientras Thanos carga el chasquido, alrededor del
## Guantelete en alto (la mano izquierda). Al final se juntan en el puño: es el aviso de
## que viene, y lo que dice cuanto falta. Lo guarda el visual para sacarlo si se corta.
func spawn_gemas_carga(caster: Node3D, duracion: float) -> Node3D:
	if not is_instance_valid(caster):
		return null
	var gemas: Array[Color] = [Color(0.25, 0.45, 1.0), Color(1.0, 0.85, 0.2), Color(0.95, 0.12, 0.16),
		Color(0.62, 0.22, 0.95), Color(0.2, 0.9, 0.35), Color(1.0, 0.52, 0.12)]
	var aro := Node3D.new()
	aro.name = &"GemasCarga"
	caster.add_child(aro)
	aro.position = Vector3(-0.32, 2.25, 0.0)
	var paso := maxf(0.05, duracion * 0.8 / float(gemas.size()))
	for k: int in range(gemas.size()):
		var ang := TAU * float(k) / float(gemas.size())
		var gema := Art.sphere(0.07, Art.glow(gemas[k], 3.5), Vector3(cos(ang) * 0.48, sin(ang) * 0.48, 0.0))
		gema.scale = Vector3.ZERO
		aro.add_child(gema)
		var tw := gema.create_tween()
		tw.tween_interval(paso * float(k))
		tw.tween_property(gema, "scale", Vector3.ONE * 1.4, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(gema, "scale", Vector3.ONE, 0.10)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.85, 0.55)
	luz.light_energy = 0.5
	luz.omni_range = 4.0
	luz.shadow_enabled = false
	aro.add_child(luz)
	var tl := luz.create_tween()
	tl.tween_property(luz, "light_energy", 4.5, duracion)
	# Gira, y al final se cierra sobre el puño.
	var giro := aro.create_tween()
	giro.tween_property(aro, "rotation:z", TAU * 1.5, duracion).from(0.0)
	var cierre := aro.create_tween()
	cierre.tween_interval(duracion * 0.8)
	cierre.tween_property(aro, "scale", Vector3.ONE * 0.15, duracion * 0.2)
	cierre.tween_callback(aro.queue_free)
	return aro


## El que se hace polvo con el chasquido: una nube de ceniza del tamaño del cuerpo, que se
## lleva el viento de a poco. Mas grande y mas larga que la de los que sobreviven.
func spawn_desintegrar(target: Node3D) -> void:
	var world := _world_of(target)
	if world == null:
		return
	var polvo := CPUParticles3D.new()
	polvo.emitting = true
	polvo.one_shot = true
	polvo.amount = 220
	polvo.lifetime = 2.6
	polvo.explosiveness = 0.15
	polvo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	polvo.emission_box_extents = Vector3(0.32, 0.95, 0.22)
	polvo.direction = Vector3(1.0, 0.8, 0.2)
	polvo.spread = 30.0
	polvo.initial_velocity_min = 0.5
	polvo.initial_velocity_max = 2.0
	polvo.gravity = Vector3(1.1, 0.5, 0.0)
	polvo.scale_amount_min = 0.05
	polvo.scale_amount_max = 0.13
	var ceniza := Gradient.new()
	ceniza.set_color(0, Color(0.50, 0.38, 0.30, 1.0))
	ceniza.set_color(1, Color(0.30, 0.26, 0.24, 0.0))
	polvo.color_ramp = ceniza
	world.add_child(polvo)
	polvo.global_position = target.global_position + Vector3.UP * 1.0
	_auto_free(polvo, 3.2)


## El polvo del chasquido: el cuerpo se deshace en ceniza que se lleva el viento.
func spawn_polvo_chasquido(target: Node3D) -> void:
	var world := _world_of(target)
	if world == null:
		return
	var polvo := CPUParticles3D.new()
	polvo.emitting = true
	polvo.one_shot = true
	polvo.amount = 70
	polvo.lifetime = 1.8
	polvo.explosiveness = 0.35
	polvo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	polvo.emission_box_extents = Vector3(0.3, 0.9, 0.2)
	polvo.direction = Vector3(1.0, 0.6, 0.0)
	polvo.spread = 35.0
	polvo.initial_velocity_min = 0.6
	polvo.initial_velocity_max = 1.8
	polvo.gravity = Vector3(0.8, 0.3, 0.0)
	polvo.scale_amount_min = 0.04
	polvo.scale_amount_max = 0.10
	var ceniza := Gradient.new()
	ceniza.set_color(0, Color(0.55, 0.42, 0.32, 0.95))
	ceniza.set_color(1, Color(0.35, 0.30, 0.28, 0.0))
	polvo.color_ramp = ceniza
	world.add_child(polvo)
	polvo.global_position = target.global_position + Vector3.UP * 1.0
	_auto_free(polvo, 2.4)


# -------------------------------------------------------------------- Mob

## La Barrera de Mob: una burbuja celeste alrededor del cuerpo, y el empujon que sale de
## ella al levantarla.
func spawn_barrera(caster: Node3D, duracion: float, radio: float) -> void:
	if not is_instance_valid(caster):
		return
	var viejo := caster.get_node_or_null(^"Barrera")
	if viejo != null:
		viejo.queue_free()
	var burbuja := MeshInstance3D.new()
	burbuja.name = &"Barrera"
	var esfera := SphereMesh.new()
	esfera.radius = 1.15
	esfera.height = 2.3
	burbuja.mesh = esfera
	var mat := Art.glow(Color(0.60, 0.78, 1.0), 1.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color.a = 0.16
	burbuja.material_override = mat
	burbuja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	caster.add_child(burbuja)
	burbuja.position = Vector3(0.0, 1.0, 0.0)
	var tw := burbuja.create_tween()
	tw.tween_property(burbuja, "scale", Vector3.ONE, 0.18).from(Vector3.ONE * 0.4) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, duracion - 0.5))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(burbuja.queue_free)
	spawn_pisoton(caster, caster.global_position, radio)
	Sfx.play_3d(caster, &"psiquico", caster.global_position + Vector3.UP, 2.0)


## El 100%: la onda que revienta, y el aura que queda mientras dura.
##
## EL PELO FLOTA EN PUNTAS, como en la serie cuando llega al 100%: unas puntas de luz
## arriba de la cabeza. Se llama AuraSuper, como la de Super Sonic y la de la estrella:
## las escenas del modo historia la esconden por ese nombre.
func spawn_cien_por_ciento(caster: Node3D, radio: float, duracion: float) -> void:
	if not is_instance_valid(caster):
		return
	var world := _world_of(caster)
	if world != null:
		var onda := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 1.0
		esfera.height = 2.0
		onda.mesh = esfera
		var mat_onda := Art.glow(Color(0.80, 0.90, 1.0), 2.4)
		mat_onda.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_onda.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat_onda.cull_mode = BaseMaterial3D.CULL_DISABLED
		onda.material_override = mat_onda
		onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(onda)
		onda.global_position = caster.global_position + Vector3.UP
		var tw := onda.create_tween().set_parallel()
		tw.tween_property(onda, "scale", Vector3.ONE * radio, 0.45).from(Vector3.ONE * 0.5) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mat_onda, "albedo_color:a", 0.0, 0.5).from(0.28)
		tw.chain().tween_callback(onda.queue_free)
		spawn_pisoton(caster, caster.global_position, radio)
		var luz := OmniLight3D.new()
		luz.light_color = Color(0.80, 0.90, 1.0)
		luz.light_energy = 12.0
		luz.omni_range = radio * 1.6
		world.add_child(luz)
		luz.global_position = caster.global_position + Vector3.UP * 1.5
		_fade_light(luz, 0.8)
	camera_shake(2.0)
	Sfx.play_3d(caster, &"cien_por_ciento", caster.global_position + Vector3.UP, 4.0)

	var viejo := caster.get_node_or_null(^"AuraSuper")
	if viejo != null:
		viejo.queue_free()
	var aura := Node3D.new()
	aura.name = &"AuraSuper"
	caster.add_child(aura)
	aura.position = Vector3(0.0, 1.0, 0.0)
	# Tenue: bien opaca, la capsula lo tapaba entero los seis segundos. Lo que se tiene que
	# ver es Mob con el pelo flotando, no una pastilla blanca.
	var brillo := Art.glow(Color(0.82, 0.92, 1.0), 0.8)
	brillo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	brillo.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	brillo.albedo_color.a = 0.07
	var cascara := Art.capsule(0.6, 2.0, brillo)
	cascara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.add_child(cascara)
	# Las puntas del pelo, flotando para arriba.
	var puntas := Art.glow(Color(0.90, 0.95, 1.0), 2.6)
	for k: int in range(7):
		var ang := TAU * float(k) / 7.0
		var pivote := Node3D.new()
		pivote.position = Vector3(cos(ang) * 0.13, 0.95, sin(ang) * 0.13)
		pivote.rotation = Vector3(sin(ang) * 0.5, 0.0, -cos(ang) * 0.5)
		aura.add_child(pivote)
		var cono := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = 0.0
		malla.bottom_radius = 0.05
		malla.height = 0.28
		cono.mesh = malla
		cono.material_override = puntas
		cono.position = Vector3(0.0, 0.14, 0.0)
		pivote.add_child(cono)
	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 30
	chispas.lifetime = 0.8
	chispas.direction = Vector3.UP
	chispas.spread = 40.0
	chispas.initial_velocity_min = 0.8
	chispas.initial_velocity_max = 2.2
	chispas.gravity = Vector3.ZERO
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chispas.emission_sphere_radius = 0.6
	chispas.scale_amount_min = 0.05
	chispas.scale_amount_max = 0.12
	chispas.color = Color(0.85, 0.93, 1.0, 0.85)
	aura.add_child(chispas)
	var luz_aura := OmniLight3D.new()
	luz_aura.light_color = Color(0.80, 0.90, 1.0)
	luz_aura.light_energy = 1.8
	luz_aura.omni_range = 5.0
	aura.add_child(luz_aura)
	_auto_free(aura, duracion)


# ------------------------------------------------------------------- Goku

## Teletransportacion: el destello donde desaparece o aparece.
##
## UNA COLUMNA DE LUZ QUE SE CIERRA, no una explosion: en la serie la tecnica no hace ruido
## ni humo, el cuerpo se va como una imagen que se apaga. Una explosion se leeria como un
## ataque, y lo que tiene que decir es "estaba aca y ya no".
func spawn_teletransporte(context: Node, pos: Vector3) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var columna := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = 0.55
	malla.bottom_radius = 0.55
	malla.height = 2.2
	columna.mesh = malla
	var mat := Art.glow(Color(0.85, 0.95, 1.0), 3.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_color.a = 0.55
	columna.material_override = mat
	columna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(columna)
	columna.global_position = pos + Vector3.UP * 1.1

	var tw := columna.create_tween()
	tw.set_parallel(true)
	# Se afina hasta desaparecer: el cuerpo "se va" por el medio.
	tw.tween_property(columna, "scale", Vector3(0.05, 1.15, 0.05), 0.28).from(Vector3.ONE)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tw.chain().tween_callback(columna.queue_free)
	spawn_impact_burst(context, pos + Vector3.UP, Color(0.85, 0.95, 1.0, 0.9))


## La esfera de energia entre las manos mientras carga el Kamehameha.
##
## CRECE CON LA CARGA: arranca chica y llega a su tamaño justo al soltar. Es el reloj del
## ataque para el que lo esta viendo venir: cuanto mas grande, menos falta.
func spawn_kame_carga(caster: Node3D, duracion: float) -> Node3D:
	if not is_instance_valid(caster):
		return null
	var carga := Node3D.new()
	carga.name = &"CargaKame"
	caster.add_child(carga)
	# Al costado del cuerpo, a la altura de la cadera: donde Goku junta las manos.
	carga.position = Vector3(0.42, 0.95, 0.10)

	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.22
	esfera.height = 0.44
	bola.mesh = esfera
	bola.material_override = Art.glow(Color(0.60, 0.88, 1.0), 4.5)
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carga.add_child(bola)

	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 30
	chispas.lifetime = 0.45
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chispas.emission_sphere_radius = 0.7
	# Hacia adentro: la energia se junta en las manos, no sale de ellas.
	chispas.radial_accel_min = -9.0
	chispas.radial_accel_max = -6.0
	chispas.gravity = Vector3.ZERO
	chispas.scale_amount_min = 0.03
	chispas.scale_amount_max = 0.08
	chispas.color = Color(0.70, 0.92, 1.0, 0.9)
	carga.add_child(chispas)

	var luz := OmniLight3D.new()
	luz.light_color = Color(0.55, 0.85, 1.0)
	luz.light_energy = 2.2
	luz.omni_range = 5.0
	luz.shadow_enabled = false
	carga.add_child(luz)

	var tw := bola.create_tween()
	tw.tween_property(bola, "scale", Vector3.ONE * 1.25, maxf(0.1, duracion)).from(Vector3.ONE * 0.2)
	return carga


## El rayo del Kamehameha, del largo que llego (el entero, o hasta la pared).
##
## UN CILINDRO QUE SE ENSANCHA DE GOLPE Y SE APAGA DESPACIO. El pico de ancho al salir es
## el "¡HA!"; el apagado lento es lo que deja ver POR DONDE paso, que es lo que el que lo
## esquivo por poco necesita ver para entender que estuvo cerca.
func spawn_kamehameha(caster: Node, origin: Vector3, dir: Vector3, largo: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx() or largo <= 0.1:
		return
	var rayo := Node3D.new()
	world.add_child(rayo)
	rayo.global_position = origin + rumbo * (largo * 0.5)
	rayo.look_at(origin + rumbo * largo, Vector3.UP if absf(rumbo.y) < 0.98 else Vector3.RIGHT)

	# El nucleo blanco y el borde celeste: dos cilindros, como el ki de las esferas.
	var capas: Array = [[0.45, Color(0.95, 0.99, 1.0), 1.0], [0.95, Color(0.45, 0.80, 1.0), 0.55]]
	var mats: Array[StandardMaterial3D] = []
	for capa: Array in capas:
		var tubo := MeshInstance3D.new()
		var malla := CylinderMesh.new()
		malla.top_radius = capa[0]
		malla.bottom_radius = capa[0]
		malla.height = largo
		tubo.mesh = malla
		var mat := Art.glow(capa[1], 4.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.albedo_color.a = capa[2]
		tubo.material_override = mat
		tubo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# El cilindro nace parado en +Y; se lo acuesta sobre el -Z del look_at.
		tubo.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rayo.add_child(tubo)
		mats.append(mat)

	# La bola de la punta, donde el rayo choca.
	var punta := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 1.3
	bola.height = 2.6
	punta.mesh = bola
	var mat_punta := Art.glow(Color(0.75, 0.93, 1.0), 4.0)
	mat_punta.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_punta.albedo_color.a = 0.7
	punta.material_override = mat_punta
	punta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(punta)
	punta.global_position = origin + rumbo * largo
	mats.append(mat_punta)

	var luz := OmniLight3D.new()
	luz.light_color = Color(0.55, 0.85, 1.0)
	luz.light_energy = 5.0
	luz.omni_range = 12.0
	luz.shadow_enabled = false
	world.add_child(luz)
	luz.global_position = origin + rumbo * minf(largo, 6.0)
	_fade_light(luz, 0.9)

	var tw := rayo.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rayo, "scale", Vector3(1.0, 1.0, 1.0), 0.08).from(Vector3(0.2, 0.2, 1.0))
	for m: StandardMaterial3D in mats:
		tw.tween_property(m, "albedo_color:a", 0.0, 0.75).set_delay(0.25)
	tw.tween_property(punta, "scale", Vector3.ONE * 1.6, 0.9)
	tw.chain().tween_callback(func() -> void:
		rayo.queue_free()
		if is_instance_valid(punta):
			punta.queue_free())
	spawn_impact_burst(caster, origin + rumbo * largo, Color(0.75, 0.93, 1.0, 1.0))


# ------------------------------------------------------- Cajas de colision
#
# Se dibujan solo con la opcion prendida. Existen porque "me pego sin tocarme" es la queja
# numero uno de cualquier juego de peleas, y sin poder VER el alcance no hay manera de
# saber si es cierto o si el que se queja calculo mal.
#
# TODO SALE DE LA FORMA DE VERDAD, nunca de un numero copiado. La capsula se lee del
# CollisionShape3D del jugador y los conos y esferas los dibuja el mismo codigo que los
# consulta. Una caja de colision dibujada a mano al lado de la real es peor que no
# dibujar nada: muestra con total seguridad algo que no es cierto.

## Verde lo que se puede golpear, naranja lo que golpea. Con los dos del mismo color un
## cono de ataque se confunde con la capsula del que lo tira, que es justo al lado.
const HITBOX_COLOR := Color(0.25, 1.0, 0.45)
const ATAQUE_COLOR := Color(1.0, 0.62, 0.18)


func _material_hitbox(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


## El volumen de un ataque en cono, en el instante en que pregunta a quien toca.
func dibujar_cono(context: Node, origin: Vector3, dir: Vector3, alcance: float,
		angulo_grados: float) -> void:
	if not Settings.mostrar_hitboxes:
		return
	var world := _world_of(context)
	if world == null:
		return
	var cono := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = alcance * tan(deg_to_rad(angulo_grados * 0.5))
	malla.bottom_radius = 0.05
	malla.height = alcance
	cono.mesh = malla
	cono.material_override = _material_hitbox(ATAQUE_COLOR)
	cono.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(cono)
	# El cilindro nace con su eje en +Y, la boca ANCHA arriba, y el ataque sale hacia
	# `dir`: hay que acostarlo con la boca hacia adelante.
	#
	# MENOS noventa grados, no mas. Con +90 el +Y local terminaba apuntando a +Z, que es
	# ATRAS: la boca ancha quedaba del lado del que ataca, pegada a la camara, y el cono se
	# veia como una cupula gigante tapando media pantalla. Con -90, +Y va a -Z, que es el
	# frente del nodo despues del look_at.
	cono.global_position = origin + dir.normalized() * (alcance * 0.5)
	cono.look_at(origin + dir.normalized() * alcance, Vector3.UP)
	cono.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	_auto_free(cono, 0.45)


## El volumen de un ataque en esfera.
func dibujar_esfera(context: Node, origin: Vector3, radio: float) -> void:
	if not Settings.mostrar_hitboxes:
		return
	var world := _world_of(context)
	if world == null:
		return
	var bola := MeshInstance3D.new()
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	bola.mesh = malla
	bola.material_override = _material_hitbox(ATAQUE_COLOR)
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(bola)
	bola.global_position = origin
	_auto_free(bola, 0.45)


## El volumen de un rayo recto: un cilindro del largo y el radio que consulta
## CombatUtils.get_players_in_line.
func dibujar_rayo(context: Node, origin: Vector3, dir: Vector3, largo: float, radio: float) -> void:
	if not Settings.mostrar_hitboxes:
		return
	var world := _world_of(context)
	if world == null:
		return
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx() or largo <= 0.0:
		return
	var tubo := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = largo
	tubo.mesh = malla
	tubo.material_override = _material_hitbox(ATAQUE_COLOR)
	tubo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tubo)
	tubo.global_position = origin + rumbo * (largo * 0.5)
	tubo.look_at(origin + rumbo * largo, Vector3.UP if absf(rumbo.y) < 0.98 else Vector3.RIGHT)
	tubo.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_auto_free(tubo, 0.45)


## La capsula de un cuerpo. Se queda puesta y se prende o apaga con la opcion.
##
## Se lee del CollisionShape3D en vez de escribir las medidas a mano: si alguien cambia la
## capsula del jugador, esto la sigue sin que nadie se acuerde de actualizar dos numeros.
func marcar_cuerpo(cuerpo: Node3D, forma: CollisionShape3D) -> MeshInstance3D:
	if not is_instance_valid(cuerpo) or forma == null:
		return null
	var capsula := forma.shape as CapsuleShape3D
	if capsula == null:
		return null
	var marca := MeshInstance3D.new()
	marca.name = &"CajaColision"
	var malla := CapsuleMesh.new()
	malla.radius = capsula.radius
	malla.height = capsula.height
	marca.mesh = malla
	marca.material_override = _material_hitbox(HITBOX_COLOR)
	marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cuerpo.add_child(marca)
	marca.position = forma.position
	marca.visible = Settings.mostrar_hitboxes
	return marca


## Numero de daño flotante.
func spawn_damage_number(context: Node, position: Vector3, amount: float, is_execute: bool = false) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var label := Label3D.new()
	label.text = str(int(round(amount)))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 96 if is_execute else 64
	label.outline_size = 12
	label.modulate = Color(1.0, 0.45, 0.45) if is_execute else Color(1.0, 0.95, 0.75)
	label.outline_modulate = Color(0.05, 0.05, 0.1)
	world.add_child(label)
	label.global_position = position + Vector3.UP * 0.4

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector3.UP * 1.6, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## Hielo sobre un jugador congelado. Devuelve el nodo para poder sacarlo al descongelarse.
func spawn_freeze_shell(target: Node3D) -> Node3D:
	if not is_instance_valid(target):
		return null
	var shell := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.62
	capsule.height = 2.1
	shell.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.82, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.75, 1.0)
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = mat
	target.add_child(shell)
	shell.position = Vector3(0.0, 1.0, 0.0)
	Sfx.play_3d(target, &"freeze", target.global_position + Vector3.UP, -2.0)
	return shell


## THE WORLD: invoca el Stand de Dio detras de el.
##
## `punch_hz` > 0 le hace tirar trompadas a esa frecuencia (para MUDA y la rafaga);
## en 0 solo flota (para ZA WARUDO, donde el Stand esta parado y lo que actua es Dio).
func summon_stand(caster: Node, duration: float, punch_hz: float = 0.0) -> void:
	var cuerpo := caster as Node3D
	if cuerpo == null:
		return
	# Uno solo por vez: encadenando MUDA se apilaban tres Stands superpuestos.
	var previo := cuerpo.get_node_or_null("TheWorld")
	if previo != null:
		previo.queue_free()
	var ghost := StandGhost.create(cuerpo, duration, punch_hz)
	if ghost != null:
		ghost.name = "TheWorld"


## Rafaga de golpes de Dio. Muchos destellos cortos y amarillos, rapido.
func spawn_muda_flurry(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var flurry := CPUParticles3D.new()
	flurry.emitting = true
	flurry.one_shot = true
	flurry.amount = 34
	flurry.lifetime = 0.35
	flurry.explosiveness = 0.9
	flurry.direction = dir.normalized()
	flurry.spread = 30.0
	flurry.initial_velocity_min = 6.0
	flurry.initial_velocity_max = 12.0
	flurry.gravity = Vector3.ZERO
	flurry.scale_amount_min = 0.08
	flurry.scale_amount_max = 0.26
	flurry.color = Color(1.0, 0.85, 0.35, 0.95)
	world.add_child(flurry)
	flurry.global_position = origin + dir.normalized() * 1.2
	_auto_free(flurry, 1.0)
	spawn_slash_arc(caster, origin, dir, Color(1.0, 0.86, 0.38))
	# El Stand es quien pega. Sin el se veia a Dio tirando trompadas al aire.
	summon_stand(caster, 0.55, 7.0)
	Sfx.play_3d(caster, &"hit_punch", origin, -3.0)


## Barrera de hielo de Noelle. La logica vive en IceBarrier, que se autodestruye sola
## cuando se acaba el escudo o el tiempo.
func spawn_ice_barrier(target: Node3D, duration: float) -> Node3D:
	return IceBarrier.create(target, duration)


## Chispazo cuando el escudo se come un golpe.
func spawn_shield_hit(target: Node3D, amount: float) -> void:
	if not is_instance_valid(target) or amount <= 0.0:
		return
	spawn_impact_burst(target, target.global_position + Vector3.UP, Color(0.7, 0.92, 1.0, 0.95))


## Rafaga larga del Stand de Dio: muchos destellos encadenados en el tiempo.
##
## Se dibuja tick a tick y no de una, porque lo que vende la rafaga es la REPETICION.
## Un solo estallido grande se lee como un golpe fuerte, no como veinte golpes.
func spawn_stand_barrage(caster: Node, origin: Vector3, dir: Vector3, ticks: int, interval: float) -> void:
	for i: int in range(ticks):
		if i > 0:
			await get_tree().create_timer(interval).timeout
		if not is_instance_valid(caster):
			return
		var here := origin
		var facing := dir
		if caster is Node3D:
			here = (caster as Node3D).global_position + Vector3.UP * 1.1
			facing = -(caster as Node3D).global_transform.basis.z
		spawn_muda_flurry(caster, here, facing)


## ZA WARUDO. Onda dorada que se expande desde Dio y deja el mundo en penumbra.
## Tiene que leerse al instante: cuando ves esto, ya perdiste el control.
func spawn_time_stop(caster: Node, center: Vector3, radius: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return

	var wave := CPUParticles3D.new()
	wave.emitting = true
	wave.one_shot = true
	wave.amount = 260
	wave.lifetime = 1.4
	wave.explosiveness = 1.0
	wave.direction = Vector3.ZERO
	wave.spread = 180.0
	wave.initial_velocity_min = radius * 0.6
	wave.initial_velocity_max = radius * 1.1
	wave.gravity = Vector3.ZERO
	wave.scale_amount_min = 0.15
	wave.scale_amount_max = 0.55
	wave.color = Color(1.0, 0.82, 0.25, 0.95)
	world.add_child(wave)
	wave.global_position = center + Vector3.UP * 1.0
	_auto_free(wave, 2.6)

	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.3)
	flash.light_energy = 18.0
	flash.omni_range = radius * 1.6
	world.add_child(flash)
	flash.global_position = center + Vector3.UP
	_fade_light(flash, 1.1)

	Sfx.play_3d(caster, &"za_warudo", center, 3.0)
	time_stop_grade(ZaWarudo.STOP_DURATION)
	# En ZA WARUDO el Stand aparece y se QUEDA QUIETO: el que actua es Dio, el Stand
	# esta ahi para que se vea quien paro el tiempo.
	summon_stand(caster, ZaWarudo.STOP_DURATION + 1.0, 0.0)
	camera_shake(2.2)


## Marca de tiempo detenido: un anillo dorado y una corona de cuchillos suspendidos
## apuntando al jugador.
##
## Los cuchillos son la mitad de la lectura de ZA WARUDO: comunican que el daño ya esta
## decidido y que solo falta que el tiempo vuelva a correr. Sin ellos, el aturdimiento
## se lee como "no me puedo mover" y no como "estoy muerto y todavia no me entere".
func spawn_time_stop_marker(target: Node3D) -> Node3D:
	if not is_instance_valid(target):
		return null
	var root := Node3D.new()
	target.add_child(root)
	root.position = Vector3(0.0, 1.05, 0.0)

	var gold := Art.glow(Color(1.0, 0.78, 0.22), 1.4)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.70
	torus.outer_radius = 0.92
	ring.mesh = torus
	ring.material_override = gold
	root.add_child(ring)

	# Corona de cuchillos, apuntando hacia adentro.
	var blade_mat := Art.metal(Color(0.88, 0.88, 0.94), 0.012)
	var blades := Node3D.new()
	root.add_child(blades)
	for i: int in range(9):
		var angle := TAU * float(i) / 9.0
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(angle) * 1.35, sin(float(i) * 1.7) * 0.42, sin(angle) * 1.35)
		blades.add_child(pivot)
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.40, 0.11)
		blade.mesh = mesh
		blade.material_override = blade_mat
		pivot.add_child(blade)
		# La punta mira al centro.
		pivot.look_at(root.global_position, Vector3.UP)
		pivot.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 3.0).from(0.0)

	return root


## El tiempo vuelve a correr: los cuchillos se cierran sobre el objetivo y revientan.
func release_time_stop_marker(marker: Node3D, target: Node3D) -> void:
	if not is_instance_valid(marker):
		return
	var blades := marker.get_child(1) if marker.get_child_count() > 1 else null
	if blades is Node3D:
		for pivot: Node in (blades as Node3D).get_children():
			var p := pivot as Node3D
			if p == null:
				continue
			var tween := p.create_tween()
			tween.tween_property(p, "position", Vector3(0.0, 0.0, 0.0), 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	if is_instance_valid(target):
		var burst_timer := get_tree().create_timer(0.10)
		var ref: WeakRef = weakref(target)
		burst_timer.timeout.connect(func() -> void:
			var blanco: Node3D = ref.get_ref()
			if is_instance_valid(blanco):
				spawn_impact_burst(blanco, blanco.global_position + Vector3.UP, Color(1.0, 0.82, 0.3, 0.95))
				Sfx.play_3d(blanco, &"knife", blanco.global_position + Vector3.UP, 1.0)
				camera_shake(1.1)
		)

	var free_timer := get_tree().create_timer(0.35)
	free_timer.timeout.connect(func() -> void:
		if is_instance_valid(marker):
			marker.queue_free()
	)


## Puas de hielo que brotan del piso a lo largo del cono de Snowgrave.
##
## Es lo que le da huella al golpe: las particulas se van en un segundo y no queda
## nada, y un ultimate que cuesta la barra entera tiene que dejar marca en el mundo.
func spawn_ice_spikes(caster: Node, origin: Vector3, dir: Vector3, cone_range: float, cone_angle: float) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	if flat.is_zero_approx():
		return

	var ice := Art.glass(Art.ICE, 0.72, 1.1)
	var half_angle := deg_to_rad(cone_angle * 0.5)

	for i: int in range(22):
		var t := float(i) / 21.0
		var angle := randf_range(-half_angle, half_angle)
		var distance := lerpf(2.0, cone_range * 0.95, t) * randf_range(0.75, 1.1)
		var spot := origin + flat.rotated(Vector3.UP, angle) * distance
		spot.y = 0.0

		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = randf_range(0.22, 0.42)
		mesh.height = randf_range(1.3, 2.6)
		spike.mesh = mesh
		spike.material_override = ice
		spike.rotation_degrees = Vector3(randf_range(-11.0, 11.0), randf_range(0.0, 360.0), randf_range(-11.0, 11.0))
		world.add_child(spike)
		# Arranca hundida y brota: aparecer de golpe se lee como un glitch.
		spike.global_position = spot + Vector3.DOWN * mesh.height
		var rise := spike.create_tween()
		rise.tween_interval(t * 0.22)
		rise.tween_property(spike, "global_position", spot + Vector3.UP * (mesh.height * 0.35), 0.13) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_interval(1.1)
		rise.tween_property(spike, "global_position", spot + Vector3.DOWN * mesh.height, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		rise.tween_callback(spike.queue_free)


## La marca del rival fijado (ver PlayerCamera.fijar_o_soltar): un triangulo rojo que
## flota arriba de su cabeza, girando.
##
## SE VE A TRAVES DE LAS PAREDES, a proposito: fijar es para no perderlo de vista, y detras
## de una cobertura es justo cuando mas hace falta saber donde esta. Es de quien fija y de
## nadie mas: la crea su camara, en su pantalla.
func spawn_marca_fijado(target: Node3D) -> Node3D:
	if not is_instance_valid(target):
		return null
	var raiz := Node3D.new()
	raiz.name = &"MarcaFijado"
	target.add_child(raiz)
	raiz.position = Vector3(0.0, 2.75, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.22, 0.18)
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.30
	cono.bottom_radius = 0.0
	cono.height = 0.46
	cono.radial_segments = 3
	punta.mesh = cono
	punta.material_override = mat
	punta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(punta)
	var tw := raiz.create_tween().set_loops()
	tw.tween_property(raiz, "position:y", 2.95, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(raiz, "position:y", 2.75, 0.45).set_trans(Tween.TRANS_SINE)
	var giro := punta.create_tween().set_loops()
	giro.tween_property(punta, "rotation:y", TAU, 1.6).from(0.0)
	return raiz


## Lo llaman los clientes remotos cuando el servidor avisa que alguien tiro una habilidad.
## Solo reproduce lo visual: el daño ya esta resuelto en el servidor.
func play_ability_cosmetic(caster: Node, ability_id: StringName, origin: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(caster):
		return
	match ability_id:
		&"icicle_strike":
			spawn_melee_arc(caster, origin, dir)
		&"ice_shock":
			IceShock.spawn_cosmetic(caster, origin, dir)
		&"snowgrave":
			spawn_snowgrave(caster, origin, dir, Snowgrave.CONE_RANGE, Snowgrave.CONE_ANGLE)
		&"muda_rush":
			spawn_muda_flurry(caster, origin, dir)
		&"knife_throw":
			KnifeThrow.spawn_cosmetic(caster, origin, dir)
		&"za_warudo":
			spawn_time_stop(caster, origin, ZaWarudo.RADIUS)
		&"ice_defense":
			if caster is Node3D:
				spawn_ice_barrier(caster as Node3D, IceDefense.DURATION)
		&"stand_barrage":
			spawn_stand_barrage(caster, origin, dir, StandBarrage.TICKS, StandBarrage.TICK_INTERVAL)
		&"petal_shot":
			PetalShot.spawn_cosmetic(caster, origin, dir)
		&"goku_combo":
			spawn_melee_arc(caster, origin, dir)
		&"ki_blast":
			KiBlast.spawn_cosmetic(caster, origin, dir)
		&"teletransportacion":
			# La salida nada mas. La llegada la replica _net_teleport, y el cliente no sabe
			# a donde va el servidor hasta que el cuerpo aparece.
			spawn_teletransporte(caster, origin - Vector3.UP * 1.2)
		&"kamehameha":
			if caster is Node3D:
				var rumbo := dir.normalized()
				spawn_kamehameha(caster, origin, rumbo,
					Kamehameha.largo_hasta_pared(caster as Node3D, origin, rumbo))
		&"plasma_shot":
			PlasmaShot.spawn_cosmetic(caster, origin, dir)
		&"plasma_grenade":
			PlasmaGrenade.spawn_cosmetic(caster, origin, dir)
		&"meeseeks_box":
			MeeseeksBox.spawn_cosmetic(caster, origin, dir)
		&"portal_gun":
			# El portal de SALIDA nada mas. El de destino no se puede replicar desde aca
			# porque el cliente no sabe a donde apunto el servidor, y el salto en si ya
			# lo replica _net_teleport.
			spawn_portal(caster, origin, dir, false)
		&"jarona":
			# El movimiento del cuerpo ya lo replica el transform; aca solo el destello.
			if caster is Node3D:
				spawn_jarona_flash(caster as Node3D)
		&"here_i_come":
			spawn_charge_burst(caster, origin, dir)
		&"last_jarona":
			spawn_last_jarona(caster, origin, LastJarona.BLAST_RADIUS)
		&"mario_combo":
			spawn_melee_arc(caster, origin, dir)
		&"bola_de_fuego":
			BolaDeFuego.spawn_cosmetic(caster, origin, dir)
		&"super_salto":
			# La salida nada mas: el cuerpo lo mueve el transform, y el pisoton lo decide
			# el servidor cuando aterriza.
			if caster is Node3D:
				spawn_impact_burst(caster, (caster as Node3D).global_position + Vector3.UP * 0.2,
					Color(0.95, 0.92, 0.85, 0.8))
		&"superestrella":
			if caster is Node3D:
				spawn_estrella(caster as Node3D, Superestrella.DURACION)
		&"puno_titan":
			spawn_melee_arc(caster, origin, dir)
		&"gema_poder":
			GemaPoder.spawn_cosmetic(caster, origin, dir)
		&"gema_espacio":
			if caster is Node3D:
				var c3 := caster as Node3D
				spawn_gema_espacio(caster, c3.global_position)
				spawn_gema_espacio(caster, GemaEspacio.calcular_destino(c3, origin, dir))
		&"chasquido":
			if caster is Node3D:
				spawn_chasquido(caster as Node3D)
		&"hueso":
			HuesoSans.spawn_cosmetic(caster, origin, dir)
		&"huesos_piso":
			if caster is Node3D:
				spawn_huesos_piso(caster, (caster as Node3D).global_position,
					HuesosPiso.rumbo_de(caster as Node3D, dir), HuesosPiso.LARGO, HuesosPiso.AVISO)
		&"alma_azul":
			if caster is Node3D:
				spawn_alma_azul(caster, origin, AlmaAzul.primero_en_la_mira(caster as Node3D, origin, dir))
		&"gaster_blaster":
			if caster is Node3D:
				spawn_gaster_blaster(caster, GasterBlaster.rayos_de(caster as Node3D, dir), GasterBlaster.LARGO)
		&"taijutsu_naruto", &"golpe_aracnido", &"golpe_gojo":
			spawn_melee_arc(caster, origin, dir)
		&"kage_bunshin":
			KageBunshin.spawn_cosmetic(caster, origin, dir)
		&"rasengan":
			if caster is Node3D:
				spawn_esfera_mano(caster as Node3D, Color(0.45, 0.75, 1.0), Rasengan.CARGA + Rasengan.DURATION)
		&"rasenshuriken":
			Rasenshuriken.spawn_cosmetic(caster, origin, dir)
		&"gomu_pistol":
			if caster is Node3D:
				spawn_brazo_goma(caster as Node3D, origin, dir.normalized(),
					GomuPistol.LARGO * GearFifth.por(caster, GearFifth.ALCANCE), GearFifth.por(caster, GearFifth.ANCHO))
		&"gomu_gatling":
			if caster is Node3D:
				spawn_brazo_goma(caster as Node3D, origin, dir.normalized(),
					GomuGatling.CONE_RANGE * GearFifth.por(caster, GearFifth.ALCANCE), GearFifth.por(caster, GearFifth.ANCHO))
		&"gomu_rocket":
			if caster is Node3D:
				spawn_brazo_goma(caster as Node3D, origin, dir.normalized(), 9.0, GearFifth.por(caster, GearFifth.ANCHO))
		&"gear_fifth":
			if caster is Node3D:
				GearFifth.activar(caster as Node3D)
				spawn_gear_fifth(caster as Node3D, GearFifth.DURACION)
		&"telarana":
			Telarana.spawn_cosmetic(caster, origin, dir)
		&"balanceo":
			if caster is Node3D:
				spawn_hilo_balanceo(caster as Node3D, Vector3(dir.x, 0.0, dir.z).normalized(), Balanceo.DURATION)
		&"red_total":
			if caster is Node3D:
				spawn_red_total(caster as Node3D, RedTotal.alcanzados(caster as Node3D, origin))
		&"azul":
			if caster is Node3D:
				spawn_azul(caster, Azul.donde(caster as Node3D, origin, dir), Azul.RADIO)
		&"rojo":
			Rojo.spawn_cosmetic(caster, origin, dir)
		&"purpura":
			Purpura.spawn_cosmetic(caster, origin, dir)
		&"katana_scorpion":
			spawn_slash_arc(caster, origin, dir, Color(1.0, 0.80, 0.35))
		&"lanza":
			Lanza.spawn_cosmetic(caster, origin, dir)
		&"fuego_infernal":
			if caster is Node3D:
				spawn_fuego_infernal(caster, FuegoInfernal.donde(caster as Node3D, origin, dir),
					FuegoInfernal.RADIO, FuegoInfernal.AVISO)
		&"aliento_infierno":
			spawn_aliento_infierno(caster, origin, dir, AlientoInfierno.ALCANCE, AlientoInfierno.ANGULO)
		&"onda_psiquica":
			OndaPsiquica.spawn_cosmetic(caster, origin, dir)
		&"escombros":
			Escombros.spawn_cosmetic(caster, origin, dir)
		&"barrera_psiquica":
			if caster is Node3D:
				spawn_barrera(caster as Node3D, BarreraPsiquica.DURACION, BarreraPsiquica.RADIO)
		&"cien_por_ciento":
			if caster is Node3D:
				spawn_cien_por_ciento(caster as Node3D, CienPorCiento.RADIO, CienPorCiento.DURACION)
		&"gunbai":
			spawn_melee_arc(caster, origin, dir)
		&"goka_messhitsu":
			spawn_katon(caster, origin, dir, GokaMesshitsu.ALCANCE, GokaMesshitsu.ANGULO)
		&"susanoo":
			if caster is Node3D:
				spawn_susanoo(caster as Node3D, Susanoo.DURACION)
			spawn_slash_arc(caster, origin, dir, Color(0.45, 0.58, 1.0))
		&"tengai_shinsei":
			if caster is Node3D:
				var c3 := caster as Node3D
				spawn_tengai_shinsei(caster, TengaiShinsei.donde_caen(c3, origin, dir),
					TengaiShinsei.rumbo_de(c3, dir))
		&"golpe_normal":
			spawn_melee_arc(caster, origin, dir)
		&"golpes_consecutivos":
			if caster is Node3D:
				spawn_rafaga_saitama(caster as Node3D)
		&"saltos_serios":
			if caster is Node3D:
				spawn_saltos_serios(caster as Node3D)
		&"golpe_serio":
			GolpeSerio.spawn_cosmetic(caster, origin, dir)
		&"partir":
			spawn_slash_arc(caster, origin, dir, Partir.ROJO)
		&"desmantelar":
			Desmantelar.spawn_cosmetic(caster, origin, dir)
		&"fuga":
			Fuga.spawn_cosmetic(caster, origin, dir)
		&"santuario":
			SantuarioMalevolo.spawn_cosmetic(caster, origin, dir)
		_:
			pass


func _auto_free(node: Node, delay: float) -> void:
	# Conectado al metodo del nodo y no a una funcion que lo capture: si el nodo se libera
	# antes —salir de la partida con un efecto en el aire—, la conexion se va con el y no
	# queda una captura liberada que Godot reporte como error.
	get_tree().create_timer(delay).timeout.connect(node.queue_free)


func _fade_light(light: OmniLight3D, duration: float) -> void:
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)


# =================================================================== Temporada 4
#
# Saitama y Sukuna. Sus definitivas tienen ademas una escena para el que las tira (ver
# EscenaUlti); lo de aca es lo que ven TODOS, cada uno desde donde esta mirando.


## POLVO Y VIENTO QUE NO SUMAN LUZ. Art.particula_suave se SUMA a lo que hay detras (es
## para chispas): sesenta encimadas cerca de la camara de la escena de la definitiva se
## volvian una nube blanca que tapaba a Saitama entero. Esta se mezcla, no se suma.
var _particula_mezcla: QuadMesh = null


func _particula_polvo() -> QuadMesh:
	if _particula_mezcla != null:
		return _particula_mezcla
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = Art.punto_suave()
	_particula_mezcla = QuadMesh.new()
	_particula_mezcla.size = Vector2(1.0, 1.0)
	_particula_mezcla.material = mat
	return _particula_mezcla


## Rayitas de viento: alargadas en la direccion en que se mueven, sin brillo propio.
func _raya_de_viento() -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(0.025, 0.42, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	return m


## Un material que brilla y se puede apagar con el alfa.
func _brillo_que_se_apaga(color: Color, energia: float) -> StandardMaterial3D:
	var mat := Art.glow(color, energia)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## LA IMAGEN RESIDUAL de los Saltos Serios: una silueta del color del traje que se queda
## donde estaba y se apaga. Tres seguidas, en zigzag, se leen como "esta en todos lados".
func spawn_imagen_residual(cuerpo: Node3D, color: Color) -> void:
	var world := _world_of(cuerpo)
	if world == null:
		return
	var sombra := Node3D.new()
	world.add_child(sombra)
	sombra.global_transform = cuerpo.global_transform
	var mat := _brillo_que_se_apaga(color, 1.6)
	var capa := _brillo_que_se_apaga(Color(1.0, 0.98, 0.95), 1.2)
	sombra.add_child(Art.capsule(0.32, 1.25, mat, Vector3(0.0, 0.95, 0.0)))
	sombra.add_child(Art.sphere(0.2, mat, Vector3(0.0, 1.72, 0.0)))
	sombra.add_child(Art.box(Vector3(0.62, 1.0, 0.04), capa, Vector3(0.0, 1.05, 0.24)))
	var tw := sombra.create_tween().set_parallel()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4).from(0.55)
	tw.tween_property(capa, "albedo_color:a", 0.0, 0.4).from(0.45)
	tw.chain().tween_callback(sombra.queue_free)


## Los saltos vistos desde otra pantalla: el cuerpo lo mueve la red, las siluetas no.
func spawn_saltos_serios(cuerpo: Node3D) -> void:
	for k: int in range(SaltosSerios.SALTOS):
		if k > 0:
			await get_tree().create_timer(SaltosSerios.DURACION_SALTO).timeout
		if not is_instance_valid(cuerpo):
			return
		spawn_imagen_residual(cuerpo, Color(1.0, 0.85, 0.20))


## LOS PUÑOS de los Golpes Normales Consecutivos: un puñado de guantes rojos que salen
## disparados hacia adelante y se apagan. Muchos a la vez, en distintos lugares, que es
## como el manga dibuja "golpes tan rapidos que parecen cien".
func spawn_puños(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var world := _world_of(caster)
	if world == null:
		return
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var costado := rumbo.cross(Vector3.UP).normalized()
	for k: int in range(4):
		var mat := _brillo_que_se_apaga(Color(0.95, 0.15, 0.15), 1.4)
		var puño := Art.sphere(0.17, mat)
		world.add_child(puño)
		var desde := origin + rumbo * 0.5 + costado * randf_range(-0.55, 0.55) + Vector3.UP * randf_range(-0.35, 0.35)
		puño.global_position = desde
		var tw := puño.create_tween().set_parallel()
		tw.tween_property(puño, "global_position", desde + rumbo * randf_range(1.6, 2.6), 0.14)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.16).from(0.9)
		tw.chain().tween_callback(puño.queue_free)
	spawn_slash_arc(caster, origin, rumbo, Color(1.0, 0.95, 0.80))
	Sfx.play_3d(caster, &"hit_punch", origin, -5.0)


## La rafaga vista desde otra pantalla, golpe a golpe (ver spawn_stand_barrage).
func spawn_rafaga_saitama(caster: Node3D) -> void:
	for i: int in range(GolpesConsecutivos.TICKS):
		if i > 0:
			await get_tree().create_timer(GolpesConsecutivos.TICK_INTERVAL).timeout
		if not is_instance_valid(caster):
			return
		spawn_puños(caster, caster.global_position + Vector3.UP * 1.1, -caster.global_transform.basis.z)


## LA CARGA DEL GOLPE SERIO, la que ven todos: el puño atras, el viento que se arremolina
## alrededor y el piso que se levanta. Va pegada al cuerpo y se borra al soltar.
func spawn_carga_golpe_serio(cuerpo: Node3D, duracion: float) -> Node3D:
	if not is_instance_valid(cuerpo):
		return null
	var carga := Node3D.new()
	carga.name = &"CargaGolpeSerio"
	cuerpo.add_child(carga)

	# El viento: rayitas que giran alrededor y se cierran sobre el puño derecho.
	var viento := CPUParticles3D.new()
	viento.amount = 28
	viento.lifetime = 0.5
	viento.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	viento.emission_ring_axis = Vector3.UP
	viento.emission_ring_radius = 1.5
	viento.emission_ring_inner_radius = 0.9
	viento.emission_ring_height = 1.8
	viento.radial_accel_min = -14.0
	viento.radial_accel_max = -8.0
	viento.tangential_accel_min = 10.0
	viento.tangential_accel_max = 16.0
	viento.gravity = Vector3.ZERO
	viento.scale_amount_min = 0.7
	viento.scale_amount_max = 1.2
	viento.color = Color(1.0, 0.98, 0.92, 0.5)
	viento.mesh = _raya_de_viento()
	viento.particle_flag_align_y = true
	viento.position = Vector3(0.0, 1.0, 0.0)
	carga.add_child(viento)

	# Piedritas que flotan: el piso no aguanta lo que viene.
	var piedras := CPUParticles3D.new()
	piedras.amount = 26
	piedras.lifetime = 1.2
	piedras.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	piedras.emission_sphere_radius = 2.6
	piedras.direction = Vector3.UP
	piedras.spread = 15.0
	piedras.initial_velocity_min = 0.8
	piedras.initial_velocity_max = 2.0
	piedras.gravity = Vector3(0.0, 0.4, 0.0)
	piedras.scale_amount_min = 0.06
	piedras.scale_amount_max = 0.16
	piedras.color = Color(0.55, 0.50, 0.45)
	piedras.position = Vector3(0.0, 0.1, 0.0)
	carga.add_child(piedras)

	# El aro de polvo en el piso, que se abre mientras carga.
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.9
	toro.outer_radius = 1.0
	aro.mesh = toro
	var mat_aro := _brillo_que_se_apaga(Color(0.95, 0.90, 0.80), 1.4)
	mat_aro.albedo_color.a = 0.55
	aro.material_override = mat_aro
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aro.position = Vector3(0.0, 0.08, 0.0)
	carga.add_child(aro)
	var tw := aro.create_tween()
	tw.tween_property(aro, "scale", Vector3(3.2, 1.0, 3.2), maxf(0.1, duracion)).from(Vector3(0.6, 1.0, 0.6))

	# El brillo en el puño derecho (atras, a la altura del pecho, que es donde lo tiene).
	var puño := Art.sphere(0.12, Art.glow(Color(1.0, 0.95, 0.75), 1.6), Vector3(0.38, 1.25, 0.42))
	puño.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carga.add_child(puño)
	var tw2 := puño.create_tween()
	tw2.tween_property(puño, "scale", Vector3.ONE * 1.8, maxf(0.1, duracion)).from(Vector3.ONE * 0.3)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.92, 0.7)
	luz.light_energy = 0.8
	luz.omni_range = 3.5
	luz.position = Vector3(0.38, 1.25, 0.42)
	carga.add_child(luz)
	camera_shake(0.5)
	return carga


## EL GOLPE SERIO: la onda que barre la linea. La ven todos y tiembla la camara de todos:
## es el golpe que en la serie partio las nubes del planeta.
##
## Tres capas: el tubo de viento que se abre (por donde paso), los anillos de choque que
## salen en fila (hacia donde iba) y, al final de la linea, un anillo enorme en el cielo,
## las nubes abriendose.
func spawn_golpe_serio(caster: Node, origin: Vector3, rumbo: Vector3, largo: float) -> void:
	var world := _world_of(caster)
	if world == null or rumbo.is_zero_approx() or largo <= 0.1:
		return
	var base := Basis.looking_at(rumbo, Vector3.UP if absf(rumbo.y) < 0.95 else Vector3.FORWARD)

	# --- El tubo: un cono acostado, del ancho real con el que pega ---
	var tubo := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.bottom_radius = GolpeSerio.ANCHO
	cil.top_radius = GolpeSerio.ANCHO + GolpeSerio.ABRE * largo
	cil.height = largo
	cil.radial_segments = 24
	cil.cap_top = false
	cil.cap_bottom = false
	tubo.mesh = cil
	var mat_tubo := _brillo_que_se_apaga(Color(1.0, 0.97, 0.88), 0.9)
	tubo.material_override = mat_tubo
	tubo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tubo)
	# El eje Y del cilindro sobre el rumbo: girado desde la base que mira hacia -Z.
	tubo.global_basis = base * Basis(Vector3.RIGHT, -PI * 0.5)
	tubo.global_position = origin + rumbo * (largo * 0.5)
	var tw := tubo.create_tween().set_parallel()
	tw.tween_property(tubo, "scale", Vector3(1.35, 1.0, 1.35), 0.6).from(Vector3(0.3, 1.0, 0.3)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat_tubo, "albedo_color:a", 0.0, 0.7).from(0.32)
	tw.chain().tween_callback(tubo.queue_free)

	# --- Los anillos de choque, en fila, cada uno un poco despues ---
	var n := clampi(int(largo / 4.0), 2, 9)
	for k: int in range(n):
		var d := largo * (float(k) + 0.5) / float(n)
		var anillo := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.88
		toro.outer_radius = 1.0
		anillo.mesh = toro
		var mat := _brillo_que_se_apaga(Color(1.0, 0.95, 0.80), 1.2)
		mat.albedo_color.a = 0.0
		anillo.material_override = mat
		anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(anillo)
		anillo.global_basis = base * Basis(Vector3.RIGHT, PI * 0.5)
		anillo.global_position = origin + rumbo * d
		var r := GolpeSerio.ANCHO + GolpeSerio.ABRE * d + 0.6
		var t2 := anillo.create_tween()
		t2.tween_interval(0.025 * float(k))
		t2.set_parallel()
		t2.tween_property(anillo, "scale", Vector3(r * 1.5, 1.0, r * 1.5), 0.45).from(Vector3(r * 0.4, 1.0, r * 0.4)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t2.tween_property(mat, "albedo_color:a", 0.0, 0.45).from(0.7)
		t2.chain().tween_callback(anillo.queue_free)

	# --- Polvo levantado a lo largo de toda la linea ---
	var polvo := CPUParticles3D.new()
	polvo.emitting = true
	polvo.one_shot = true
	polvo.amount = 90
	polvo.lifetime = 1.1
	polvo.explosiveness = 0.9
	polvo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	polvo.emission_box_extents = Vector3(GolpeSerio.ANCHO, 0.3, largo * 0.5)
	polvo.direction = Vector3.UP
	polvo.spread = 60.0
	polvo.initial_velocity_min = 2.0
	polvo.initial_velocity_max = 6.0
	polvo.gravity = Vector3(0.0, -3.0, 0.0)
	polvo.scale_amount_min = 0.15
	polvo.scale_amount_max = 0.45
	polvo.color = Color(0.80, 0.75, 0.66, 0.55)
	polvo.mesh = _particula_polvo()
	world.add_child(polvo)
	var plano := Vector3(rumbo.x, 0.0, rumbo.z).normalized()
	if not plano.is_zero_approx():
		polvo.global_basis = Basis.looking_at(plano, Vector3.UP)
	polvo.global_position = Vector3(origin.x, 0.3, origin.z) + plano * (largo * 0.5)
	_auto_free(polvo, 2.0)

	# --- Las nubes que se abren: un anillo enorme alla arriba, al final de la linea ---
	var cielo := MeshInstance3D.new()
	var toro_cielo := TorusMesh.new()
	toro_cielo.inner_radius = 0.9
	toro_cielo.outer_radius = 1.0
	cielo.mesh = toro_cielo
	var mat_cielo := _brillo_que_se_apaga(Color(1.0, 1.0, 0.95), 1.8)
	cielo.material_override = mat_cielo
	cielo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(cielo)
	cielo.global_position = Vector3(origin.x, 34.0, origin.z) + plano * minf(largo + 10.0, 40.0)
	var tw3 := cielo.create_tween().set_parallel()
	tw3.tween_property(cielo, "scale", Vector3(60.0, 2.0, 60.0), 1.4).from(Vector3(4.0, 1.0, 4.0)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw3.tween_property(mat_cielo, "albedo_color:a", 0.0, 1.4).from(0.8)
	tw3.chain().tween_callback(cielo.queue_free)

	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.96, 0.85)
	luz.light_energy = 6.0
	luz.omni_range = 14.0
	world.add_child(luz)
	luz.global_position = origin + rumbo * 2.0
	_fade_light(luz, 0.6)
	camera_shake(2.4)
	Sfx.play_3d(caster, &"golpe_serio", origin, 6.0)


## Unos tajos en el aire: rayas finas, blancas con el filo rojo, que aparecen de golpe en
## cualquier angulo y se apagan. Los cortes de Sukuna no se ven venir; se ven cuando ya
## cortaron.
func spawn_cortes(context: Node, pos: Vector3, cuantos: int) -> void:
	var world := _world_of(context)
	if world == null:
		return
	for k: int in range(cuantos):
		var raya := Node3D.new()
		world.add_child(raya)
		raya.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		raya.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var mat := _brillo_que_se_apaga(Color(1.0, 0.96, 0.96), 3.2)
		var filo := _brillo_que_se_apaga(Color(0.95, 0.10, 0.12), 2.6)
		raya.add_child(Art.box(Vector3(1.7, 0.035, 0.035), mat))
		raya.add_child(Art.box(Vector3(1.5, 0.07, 0.02), filo, Vector3(0.0, -0.04, 0.0)))
		var tw := raya.create_tween().set_parallel()
		tw.tween_property(raya, "scale", Vector3.ONE, 0.06).from(Vector3(0.1, 1.0, 1.0))
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.28).from(1.0).set_delay(0.06)
		tw.tween_property(filo, "albedo_color:a", 0.0, 0.28).from(1.0).set_delay(0.06)
		tw.chain().tween_callback(raya.queue_free)
	Sfx.play_3d(context, &"corte", pos, -8.0)


## La explosion de Fuga: una bola de fuego que se abre hasta el radio real y se apaga,
## con llamaradas que suben.
func spawn_explosion_fuga(context: Node, pos: Vector3, radio: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var nucleo := _brillo_que_se_apaga(Color(1.0, 0.85, 0.5), 3.4)
	var bola := Art.sphere(1.0, nucleo)
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(bola)
	bola.global_position = pos
	var borde := _brillo_que_se_apaga(Color(1.0, 0.35, 0.05), 2.4)
	var halo := Art.sphere(1.0, borde)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(halo)
	halo.global_position = pos
	var tw := bola.create_tween().set_parallel()
	tw.tween_property(bola, "scale", Vector3.ONE * radio * 0.7, 0.25).from(Vector3.ONE * 0.3)
	tw.tween_property(nucleo, "albedo_color:a", 0.0, 0.45).from(0.95)
	tw.chain().tween_callback(bola.queue_free)
	var tw2 := halo.create_tween().set_parallel()
	tw2.tween_property(halo, "scale", Vector3.ONE * radio, 0.35).from(Vector3.ONE * 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(borde, "albedo_color:a", 0.0, 0.6).from(0.8)
	tw2.chain().tween_callback(halo.queue_free)
	var llamas := CPUParticles3D.new()
	llamas.emitting = true
	llamas.one_shot = true
	llamas.amount = 60
	llamas.lifetime = 0.9
	llamas.explosiveness = 0.85
	llamas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	llamas.emission_sphere_radius = radio * 0.6
	llamas.direction = Vector3.UP
	llamas.spread = 40.0
	llamas.initial_velocity_min = 2.0
	llamas.initial_velocity_max = 5.0
	llamas.gravity = Vector3(0.0, 3.0, 0.0)
	llamas.scale_amount_min = 0.2
	llamas.scale_amount_max = 0.5
	llamas.mesh = Art.particula_suave()
	llamas.color_ramp = Art.rampa_que_se_apaga(Color(1.0, 0.5, 0.1, 0.95))
	world.add_child(llamas)
	llamas.global_position = pos
	_auto_free(llamas, 1.6)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.55, 0.15)
	luz.light_energy = 8.0
	luz.omni_range = radio * 3.0
	world.add_child(luz)
	luz.global_position = pos
	_fade_light(luz, 0.7)
	camera_shake(0.9)
	Sfx.play_3d(context, &"plasma_blast", pos, 2.0)
	Sfx.play_3d(context, &"fuego", pos, 0.0)


## EL SANTUARIO MALEVOLO: un templo oscuro de techo curvo, sobre una montaña de huesos y
## con una boca de dientes en el frente. Mira hacia +Z del nodo que devuelve (de frente a
## los que estan delante de Sukuna) y mide unos siete metros: se ve desde toda la arena.
func armar_santuario() -> Node3D:
	var templo := Node3D.new()
	templo.name = &"Santuario"
	var hueso := Art.toon(Color(0.90, 0.86, 0.76))
	var madera := Art.toon(Color(0.16, 0.08, 0.08))
	var rojo := Art.toon(Color(0.55, 0.06, 0.08))
	var techo := Art.toon(Color(0.10, 0.08, 0.09))
	var boca := Art.flat(Color(0.25, 0.02, 0.04))
	# La montaña de huesos: calaveras y huesos largos apilados en cono.
	var semilla := RandomNumberGenerator.new()
	semilla.seed = 4711
	for k: int in range(34):
		var a := semilla.randf() * TAU
		var alto := semilla.randf()
		var r := (1.0 - alto) * 3.2 + 0.4
		var p := Vector3(cos(a) * r, alto * 1.4, sin(a) * r * 0.8)
		if k % 3 == 0:
			var hb := Art.capsule(0.12, 1.1, hueso, p)
			hb.rotation = Vector3(semilla.randf() * TAU, semilla.randf() * TAU, PI * 0.5)
			templo.add_child(hb)
		else:
			templo.add_child(Art.sphere(0.32 + semilla.randf() * 0.12, hueso, p))
	# La plataforma y los cuatro pilares.
	templo.add_child(Art.box(Vector3(4.6, 0.35, 3.4), madera, Vector3(0.0, 1.55, 0.0)))
	for x: float in [-1.9, 1.9]:
		for z: float in [-1.3, 1.3]:
			templo.add_child(Art.cylinder(0.16, 2.8, rojo, Vector3(x, 3.1, z)))
	# La boca: un hueco oscuro entre los pilares de adelante, con dientes arriba y abajo.
	templo.add_child(Art.box(Vector3(3.0, 1.6, 0.2), boca, Vector3(0.0, 2.6, 1.32)))
	var diente := Art.toon(Color(0.96, 0.94, 0.88))
	for k: int in range(9):
		var x := -1.35 + 2.7 * float(k) / 8.0
		for arriba: bool in [true, false]:
			var d := MeshInstance3D.new()
			var cono := CylinderMesh.new()
			cono.top_radius = 0.0 if not arriba else 0.11
			cono.bottom_radius = 0.11 if not arriba else 0.0
			cono.height = 0.42
			d.mesh = cono
			d.material_override = diente
			d.position = Vector3(x, 3.22 if arriba else 1.98, 1.45)
			templo.add_child(d)
	# El techo: dos aleros anchos y oscuros, con las puntas levantadas.
	for piso: int in range(2):
		var y := 4.6 + float(piso) * 1.15
		var ancho := 6.4 - float(piso) * 1.6
		templo.add_child(Art.box(Vector3(ancho, 0.28, ancho * 0.72), techo, Vector3(0.0, y, 0.0)))
		templo.add_child(Art.box(Vector3(ancho * 0.92, 0.1, ancho * 0.66), rojo, Vector3(0.0, y - 0.18, 0.0)))
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var punta := Art.box(Vector3(0.9, 0.2, 0.3), techo,
					Vector3(sx * ancho * 0.5, y + 0.2, sz * ancho * 0.36))
				punta.rotation = Vector3(0.0, atan2(sz, sx) * -1.0, 0.0)
				punta.rotate_object_local(Vector3.FORWARD, 0.5 * sx)
				templo.add_child(punta)
	templo.add_child(Art.box(Vector3(1.4, 0.5, 1.0), techo, Vector3(0.0, 6.35, 0.0)))
	# Cuernos de vaca a los costados del techo (el santuario esta lleno de cráneos).
	for sx: float in [-1.0, 1.0]:
		var cuerno := Art.capsule(0.09, 1.3, hueso, Vector3(sx * 2.4, 5.3, 1.6))
		cuerno.rotation = Vector3(0.0, 0.0, -0.9 * sx)
		templo.add_child(cuerno)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.15, 0.12)
	luz.light_energy = 3.5
	luz.omni_range = 9.0
	luz.position = Vector3(0.0, 2.6, 2.2)
	templo.add_child(luz)
	for m: Node in templo.get_children():
		var gi := m as GeometryInstance3D
		if gi != null:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return templo


## Donde va el santuario: tres metros y medio detras del que lo invoca, de frente a lo
## que el tiene adelante.
func _lugar_santuario(centro: Vector3, frente: Vector3) -> Transform3D:
	var plano := Vector3(frente.x, 0.0, frente.z).normalized()
	if plano.is_zero_approx():
		plano = Vector3.FORWARD
	# El templo mira hacia +Z: la base que "mira" hacia -plano deja su +Z sobre plano.
	var base := Basis.looking_at(-plano, Vector3.UP)
	return Transform3D(base, Vector3(centro.x, 0.0, centro.z) - plano * 3.5)


## LA CARGA DEL SANTUARIO, la que ven todos: el templo sube del piso detras de Sukuna
## mientras junta las manos. Se borra al soltar; el dominio arma el suyo ya parado.
func spawn_santuario_alzandose(cuerpo: Node3D, duracion: float) -> Node3D:
	var world := _world_of(cuerpo)
	if world == null:
		return null
	var templo := armar_santuario()
	world.add_child(templo)
	var lugar := _lugar_santuario(cuerpo.global_position, -cuerpo.global_transform.basis.z)
	templo.global_transform = lugar
	var arriba := lugar.origin
	templo.global_position = arriba - Vector3.UP * 7.0
	var tw := templo.create_tween()
	tw.tween_property(templo, "global_position", arriba, maxf(0.1, duracion * 0.92)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var humo := CPUParticles3D.new()
	humo.amount = 50
	humo.lifetime = 1.0
	humo.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	humo.emission_box_extents = Vector3(3.2, 0.2, 2.4)
	humo.direction = Vector3.UP
	humo.spread = 30.0
	humo.initial_velocity_min = 1.0
	humo.initial_velocity_max = 2.5
	humo.gravity = Vector3.ZERO
	humo.scale_amount_min = 0.4
	humo.scale_amount_max = 0.9
	humo.mesh = Art.particula_suave()
	humo.color_ramp = Art.rampa_que_se_apaga(Color(0.25, 0.02, 0.04, 0.8))
	templo.add_child(humo)
	# Pegado al piso aunque el templo este subiendo: va como hijo, asi que se corrige.
	humo.top_level = true
	humo.global_position = arriba + Vector3.UP * 0.2
	camera_shake(0.7)
	Sfx.play_3d(cuerpo, &"dominio", arriba, 2.0)
	return templo


## EL DOMINIO ABIERTO: el templo parado, el circulo rojo del piso con el radio real y el
## mundo entero mas oscuro mientras dura. Va colgado del nodo del dominio y se va con el.
func spawn_dominio_sukuna(dominio: Node3D, frente: Vector3, radio: float, duracion: float) -> void:
	if not is_instance_valid(dominio):
		return
	var templo := armar_santuario()
	dominio.add_child(templo)
	templo.global_transform = _lugar_santuario(dominio.global_position, frente)
	# Al final se hunde, no desaparece de golpe.
	var tw := templo.create_tween()
	tw.tween_interval(maxf(0.0, duracion - 0.45))
	tw.tween_property(templo, "position:y", templo.position.y - 7.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# El borde: hasta aca corta. Tiene que leerse desde adentro y desde afuera.
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.97
	toro.outer_radius = 1.0
	toro.rings = 64
	aro.mesh = toro
	var mat_aro := _brillo_que_se_apaga(Color(1.0, 0.12, 0.14), 2.6)
	aro.material_override = mat_aro
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dominio.add_child(aro)
	aro.position = Vector3(0.0, 0.1, 0.0)
	aro.scale = Vector3(radio, 3.0, radio)
	# El piso de adentro, oscuro y rojizo.
	var piso := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.02
	disco.radial_segments = 48
	piso.mesh = disco
	var mat_piso := Art.flat(Color(0.30, 0.0, 0.03, 0.28))
	mat_piso.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	piso.material_override = mat_piso
	piso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dominio.add_child(piso)
	piso.position = Vector3(0.0, 0.06, 0.0)
	var tw2 := piso.create_tween().set_parallel()
	tw2.tween_property(piso, "scale", Vector3(radio, 1.0, radio), 0.35).from(Vector3(0.5, 1.0, 0.5)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(aro, "scale", Vector3(radio, 3.0, radio), 0.35).from(Vector3(0.5, 3.0, 0.5)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw2.chain().tween_interval(maxf(0.0, duracion - 0.8))
	tw2.chain().tween_property(mat_aro, "albedo_color:a", 0.0, 0.4)
	tw2.parallel().tween_property(mat_piso, "albedo_color:a", 0.0, 0.4)
	dominio_grade(duracion)
	Sfx.play_3d(dominio, &"dominio", dominio.global_position + Vector3.UP, 4.0)


## El mundo se apaga mientras el dominio esta abierto: menos color, como ZA WARUDO pero
## sin llegar al gris.
func dominio_grade(duracion: float) -> void:
	if _environment == null:
		return
	var env := _environment
	var tween := create_tween()
	tween.tween_property(env, "adjustment_saturation", 0.45, 0.25)
	tween.tween_interval(maxf(0.0, duracion - 0.65))
	tween.tween_property(env, "adjustment_saturation", _base_saturation, 0.4)


## LO QUE SE JUNTA en los capitulos de recolectar, y lo que esconden las rutas: un dedo de
## Sukuna (envuelto en papel de sellos), una bolsa del supermercado de Saitama, el folleto
## de la oferta, el cubo de la Prision. Flota, gira, y tiene una columna de luz encima para
## que se encuentre desde lejos: un objetivo que no se ve es un capitulo que no se termina.
func armar_juntable(context: Node, pos: Vector3, tipo: String) -> Node3D:
	var world := _world_of(context)
	if world == null:
		return null
	var cosa := Node3D.new()
	cosa.name = StringName("Juntable_" + tipo)
	world.add_child(cosa)
	cosa.global_position = pos + Vector3.UP * 1.0
	var giro := Node3D.new()
	cosa.add_child(giro)
	var color := Color(1.0, 0.85, 0.40)
	match tipo:
		"dedo":
			# Un dedo seco y oscuro, con el sello de papel atado.
			color = Color(0.95, 0.20, 0.25)
			var carne := Art.toon(Color(0.36, 0.22, 0.22))
			var falange := Art.capsule(0.07, 0.34, carne, Vector3(0.0, 0.0, 0.0))
			giro.add_child(falange)
			var punta := Art.capsule(0.065, 0.24, carne, Vector3(0.0, 0.25, 0.04))
			punta.rotation.x = 0.4
			giro.add_child(punta)
			giro.add_child(Art.box(Vector3(0.18, 0.12, 0.17), Art.toon(Color(0.92, 0.88, 0.76)), Vector3(0.0, -0.05, 0.0)))
			giro.add_child(Art.box(Vector3(0.05, 0.13, 0.18), Art.toon(Color(0.75, 0.10, 0.12)), Vector3(0.0, -0.05, 0.0)))
			giro.rotation.z = 0.5
		"bolsa":
			# La bolsa del supermercado, con un puerro asomando.
			color = Color(1.0, 0.95, 0.70)
			giro.add_child(Art.box(Vector3(0.42, 0.46, 0.26), Art.toon(Color(0.96, 0.96, 0.94)), Vector3(0.0, 0.0, 0.0)))
			giro.add_child(Art.box(Vector3(0.43, 0.08, 0.27), Art.toon(Color(0.86, 0.12, 0.14)), Vector3(0.0, 0.1, 0.0)))
			var puerro := Art.capsule(0.05, 0.5, Art.toon(Color(0.45, 0.80, 0.30)), Vector3(0.1, 0.36, 0.0))
			puerro.rotation.z = -0.3
			giro.add_child(puerro)
		"folleto":
			# EL FOLLETO DE LA OFERTA: un papel amarillo con un sello rojo de "¡OFERTA!".
			color = Color(1.0, 0.90, 0.30)
			giro.add_child(Art.box(Vector3(0.46, 0.62, 0.02), Art.toon(Color(1.0, 0.92, 0.35))))
			giro.add_child(Art.box(Vector3(0.3, 0.16, 0.03), Art.toon(Color(0.90, 0.12, 0.14)), Vector3(0.0, 0.14, 0.0)))
			giro.add_child(Art.box(Vector3(0.34, 0.04, 0.03), Art.toon(Color(0.15, 0.15, 0.18)), Vector3(0.0, -0.08, 0.0)))
			giro.add_child(Art.box(Vector3(0.28, 0.04, 0.03), Art.toon(Color(0.15, 0.15, 0.18)), Vector3(0.0, -0.18, 0.0)))
		"cubo":
			# LA PRISION: un cubo de piedra con un ojo en cada cara.
			color = Color(0.70, 0.55, 1.0)
			giro.add_child(Art.box(Vector3(0.42, 0.42, 0.42), Art.toon(Color(0.30, 0.28, 0.34))))
			for k: int in range(4):
				var ojo := Art.sphere(0.07, Art.glow(Color(0.85, 0.75, 1.0), 2.4))
				var a := float(k) * PI * 0.5
				ojo.position = Vector3(sin(a) * 0.22, 0.0, cos(a) * 0.22)
				giro.add_child(ojo)
		_:
			giro.add_child(Art.sphere(0.2, Art.glow(color, 2.4)))
	for n: Node in giro.get_children():
		var gi := n as GeometryInstance3D
		if gi != null:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La columna de luz que lo marca de lejos.
	var columna := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.18
	cil.bottom_radius = 0.32
	cil.height = 9.0
	cil.cap_top = false
	cil.cap_bottom = false
	columna.mesh = cil
	var mat := _brillo_que_se_apaga(color, 1.6)
	mat.albedo_color.a = 0.28
	columna.material_override = mat
	columna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	columna.position = Vector3(0.0, 3.6, 0.0)
	cosa.add_child(columna)
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 2.4
	luz.omni_range = 5.0
	cosa.add_child(luz)
	var tw := giro.create_tween().set_loops()
	tw.tween_property(giro, "rotation:y", TAU, 2.6).from(0.0)
	var flota := giro.create_tween().set_loops()
	flota.tween_property(giro, "position:y", 0.15, 0.9).set_trans(Tween.TRANS_SINE)
	flota.tween_property(giro, "position:y", -0.05, 0.9).set_trans(Tween.TRANS_SINE)
	return cosa


## El aviso de un tajo que cae (la lluvia de cortes de la historia): un circulo rojo que se
## cierra hasta el borde real mientras corre el aviso. Cuando se completa, corta.
func spawn_aviso_corte(context: Node, punto: Vector3, radio: float, aviso: float) -> void:
	var world := _world_of(context)
	if world == null:
		return
	var marca := Node3D.new()
	world.add_child(marca)
	marca.global_position = punto + Vector3.UP * 0.06
	var borde := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.92
	toro.outer_radius = 1.0
	toro.rings = 40
	borde.mesh = toro
	var mat := _brillo_que_se_apaga(Color(1.0, 0.15, 0.18), 2.2)
	borde.material_override = mat
	borde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	borde.scale = Vector3(radio, 1.0, radio)
	marca.add_child(borde)
	var lleno := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.02
	lleno.mesh = disco
	var mat_lleno := _brillo_que_se_apaga(Color(0.9, 0.05, 0.08), 1.2)
	mat_lleno.albedo_color.a = 0.35
	lleno.material_override = mat_lleno
	lleno.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marca.add_child(lleno)
	var tw := lleno.create_tween()
	tw.tween_property(lleno, "scale", Vector3(radio, 1.0, radio), aviso).from(Vector3(0.1, 1.0, 0.1))
	tw.tween_callback(marca.queue_free)
