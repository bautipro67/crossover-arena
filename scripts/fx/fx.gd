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
	Sfx.play_3d(caster, &"hit_ice", origin, -4.0)


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

	var light := OmniLight3D.new()
	light.light_color = ring_color
	light.light_energy = 2.2
	light.omni_range = 6.0
	light.position = Vector3(0.0, 0.8, 0.0)
	root.add_child(light)

	var spin := outer.create_tween().set_loops()
	spin.tween_property(outer, "rotation:y", TAU, 2.4).from(0.0)
	var counter := inner.create_tween().set_loops()
	counter.tween_property(inner, "rotation:y", -TAU, 1.6).from(0.0)

	return root


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
	Sfx.play_3d(caster, &"hit_punch", origin, -3.0)


## Barrera de hielo de Noelle. Cupula facetada que la sigue y se rompe cuando
## se acaba el escudo.
##
## A proposito NO se parece al hielo de un congelado: aquel es una capsula lisa que te
## deja indefenso, esta es una cascara con aristas que te protege. Si se vieran igual,
## el rival no sabria si conviene entrar a pegar o alejarse.
func spawn_ice_barrier(target: Node3D, duration: float) -> Node3D:
	if not is_instance_valid(target):
		return null
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.95
	sphere.height = 2.3
	# Pocos segmentos = caras planas grandes, o sea cristal y no pelota.
	sphere.radial_segments = 7
	sphere.rings = 4
	dome.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.88, 1.0, 0.30)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	dome.material_override = mat
	target.add_child(dome)
	dome.position = Vector3(0.0, 1.0, 0.0)

	# Placas girando alrededor: dan la lectura de "esto esta activo" sin tener que
	# mirar el HUD, que en pelea nadie mira.
	var ring := Node3D.new()
	dome.add_child(ring)
	for i: int in range(5):
		var shard := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.26, 0.5, 0.1)
		shard.mesh = prism
		shard.material_override = mat
		ring.add_child(shard)
		var ang := TAU * float(i) / 5.0
		shard.position = Vector3(cos(ang) * 1.05, 0.0, sin(ang) * 1.05)
		shard.rotation.y = -ang
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation:y", TAU, 3.2).from(0.0)

	# Se va sola cuando el escudo llega a cero, aunque falte tiempo.
	var health := target.get_node_or_null("Health") as Health
	if health != null:
		health.shield_changed.connect(func(value: float) -> void:
			if value <= 0.0 and is_instance_valid(dome):
				dome.queue_free()
		)
	_auto_free(dome, duration)
	Sfx.play_3d(target, &"freeze", target.global_position + Vector3.UP, -6.0)
	return dome


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
