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
	burst.scale_amount_min = 0.06
	burst.scale_amount_max = 0.2
	burst.color = color
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
	slash.scale_amount_min = 0.08
	slash.scale_amount_max = 0.22
	slash.color = Color(0.85, 0.96, 1.0, 0.9)
	world.add_child(slash)
	slash.global_position = origin + dir.normalized() * 1.2
	_auto_free(slash, 0.9)
	spawn_slash_arc(caster, origin, dir, Color(0.80, 0.94, 1.0))
	Sfx.play_3d(caster, &"hit_ice", origin, -4.0)


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
	camera_shake(1.6)
	Sfx.play_3d(caster, &"chasquido", centro, 6.0)
	for target: Node3D in CombatUtils._living_targets(caster):
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null and estado.es_invencible():
			continue
		spawn_polvo_chasquido(target)


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
	Sfx.play_3d(caster, &"explosion_psiquica", caster.global_position + Vector3.UP, 4.0)

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
