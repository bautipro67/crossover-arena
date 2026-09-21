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
func hit_feedback_for_attacker(amount: float) -> void:
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
		Sfx.play_3d(caster, &"jarona", origin, 0.0)


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
		timer.timeout.connect(func() -> void:
			if is_instance_valid(caster):
				# Cada anillo un poco mas chico: el conjunto se lee como una sola onda
				# con espesor de colores, no como siete ataques.
				spawn_jarona_wave(caster, origin, radius * (1.0 - 0.06 * float(i)), color, false)
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
		timer.timeout.connect(func() -> void:
			if is_instance_valid(caster):
				spawn_jarona_wave(caster, origin,
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
		burst_timer.timeout.connect(func() -> void:
			if is_instance_valid(target):
				spawn_impact_burst(target, target.global_position + Vector3.UP, Color(1.0, 0.82, 0.3, 0.95))
				Sfx.play_3d(target, &"knife", target.global_position + Vector3.UP, 1.0)
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
		rise.tween_property(spike, "global_position", spot + Vector3.UP * (mesh.height * 0.35), 0.13) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_interval(1.1)
		rise.tween_property(spike, "global_position", spot + Vector3.DOWN * mesh.height, 0.5) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		rise.tween_callback(spike.queue_free)


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
		_:
			pass


func _auto_free(node: Node, delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)


func _fade_light(light: OmniLight3D, duration: float) -> void:
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, duration)
	tween.tween_callback(light.queue_free)
