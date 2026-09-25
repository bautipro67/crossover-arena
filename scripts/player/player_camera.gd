class_name PlayerCamera
extends SpringArm3D
## Camara de tercera persona sobre el hombro.
##
## El brazo es top_level = true: se desacopla de la rotacion del Player para que el
## cuerpo pueda girar siguiendo a la camara sin que la rotacion se aplique dos veces.
##
## Importante para Snowgrave: durante el canalizado el jugador no se mueve, pero la
## camara SI sigue girando. Canalizas y reapuntas.

@export var mouse_sensitivity: float = 0.0025

## Stick derecho a fondo: cuantos radianes por segundo gira, con la sensibilidad de fabrica.
## 2.6 es media vuelta en poco mas de un segundo, la velocidad tipica de un shooter.
const GIRO_MANDO: float = 2.6
## Arrastrar el dedo: radianes por pixel. Cruzar media pantalla es girar unos 90 grados.
const GIRO_TACTIL: float = 0.0045
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = 75.0
@export var arm_length: float = 3.8
@export var shoulder_offset: float = 0.7
@export var eye_height: float = 1.5

@onready var camera: Camera3D = $Camera3D

## FIJAR AL RIVAL. Con un objetivo fijado la camara lo sigue sola y la mira queda sobre su
## pecho: como las habilidades salen hacia donde esta la mira, todas van hacia el sin
## tener que apuntar. Mientras dura, el mouse y el stick no giran la camara.
##
## Se fija al MAS CERCANO, que es lo que se pidio: apretar y que la camara gire derecho
## hacia el enemigo que tenes mas cerca. Si ese cae, pasa solo al siguiente mas cercano,
## asi en una pelea contra varios no hay que volver a apretar despues de cada baja.
signal fijado_cambio(objetivo: Node3D)
## Hasta donde busca a quien fijar, y a partir de donde lo suelta si se aleja.
const ALCANCE_FIJADO: float = 45.0
const SUELTA_A: float = 60.0
## Que tan rapido gira hacia el fijado. Alto: "que gire directamente", pero sin el salto
## seco de un corte, que marea.
const GIRO_FIJADO: float = 12.0

var objetivo: Node3D = null
var _marca: Node3D = null

var _yaw: float = 0.0
var _pitch: float = -0.15
var _active: bool = false
var _owner_body: Node3D = null


func _ready() -> void:
	_owner_body = get_parent() as Node3D
	top_level = true
	spring_length = arm_length
	collision_mask = GameConfig.LAYER_WORLD
	margin = 0.3
	# OJO: NO le pongas el offset lateral a la Camera3D. SpringArm3D reposiciona a sus
	# hijos cada frame, asi que cualquier position que le setees se pisa. El offset va
	# aplicado al brazo entero, abajo en _process().
	camera.position = Vector3.ZERO
	camera.current = false
	if _owner_body != null:
		_yaw = _owner_body.rotation.y


func set_active(active: bool) -> void:
	_active = active
	camera.current = active
	set_process(active)
	set_process_input(active)
	if active:
		FX.register_camera(camera)
		Controles.capturar_mouse()
	else:
		soltar()


func _process(delta: float) -> void:
	if not _active or not is_instance_valid(_owner_body):
		return
	_girar_con_stick(delta)
	_seguir_fijado(delta)
	# El brazo sigue al jugador manualmente porque es top_level.
	# El corrimiento lateral va aca: deja el cuerpo del jugador a un costado en vez de
	# tapar el centro de la pantalla justo donde esta la mira.
	var yaw_basis := Basis(Vector3.UP, _yaw)
	global_position = (_owner_body.global_position
		+ Vector3.UP * eye_height
		+ yaw_basis.x * shoulder_offset)
	global_rotation = Vector3(_pitch, _yaw, 0.0)


func _input(event: InputEvent) -> void:
	# En una cinematica la camara es la de la escena: mover el mouse no gira nada.
	if not _active or Cinematica.activa:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	# Un dedo arrastrando tambien llega como mouse, y lo gira ControlesTactiles. Si
	# contara aca, cada arrastre giraria la camara dos veces.
	if motion.device == InputEvent.DEVICE_ID_EMULATION:
		return
	# La sensibilidad sale de las opciones del jugador, no del export.
	var sens := Settings.mouse_sensitivity if Settings != null else mouse_sensitivity
	_girar(motion.relative.x * sens, motion.relative.y * sens)


func _girar(dx: float, dy: float) -> void:
	# Con alguien fijado, la camara es suya.
	if is_instance_valid(objetivo):
		return
	_yaw -= dx
	_pitch -= dy
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


## Cuanto de la sensibilidad de fabrica eligio el jugador. El deslizador de opciones es
## uno solo y vale para las tres formas de mirar: mouse, stick y dedo.
func _factor_sensibilidad() -> float:
	return Settings.mouse_sensitivity / 0.0025 if Settings != null else 1.0


## El stick derecho.
##
## LA RESPUESTA ES CUADRATICA: el giro crece con el cuadrado de cuanto se inclina. Con una
## lineal, apuntar fino es imposible —el primer milimetro ya gira rapido— y es la razon
## por la que casi todos los juegos de mando la usan.
##
## CON UN MENU ABIERTO NO GIRA: en la pausa se navega con el mando, y la camara de atras
## no tiene por que moverse mientras tanto.
func _girar_con_stick(delta: float) -> void:
	var v := Input.get_vector(&"mirar_izquierda", &"mirar_derecha", &"mirar_arriba", &"mirar_abajo")
	if v.is_zero_approx() or Mando.hay_menu_abierto() or Cinematica.activa:
		return
	var giro := v * v.length() * GIRO_MANDO * _factor_sensibilidad() * delta
	_girar(giro.x, giro.y)


## Un dedo arrastrando sobre la pantalla. Lo llama ControlesTactiles.
func girar_por_toque(relativo: Vector2) -> void:
	var k := GIRO_TACTIL * _factor_sensibilidad()
	_girar(relativo.x * k, relativo.y * k)


func get_yaw() -> float:
	return _yaw


# ------------------------------------------------------------------ Fijar al rival

## La tecla de fijar: si no hay nadie fijado, fija al mas cercano; si hay, suelta.
func fijar_o_soltar() -> void:
	if is_instance_valid(objetivo):
		soltar()
	else:
		_fijar(mas_cercano())


func soltar() -> void:
	_fijar(null)


func esta_fijado() -> bool:
	return is_instance_valid(objetivo)


## El rival vivo mas cercano, dentro de ALCANCE_FIJADO. Los aliados no cuentan.
func mas_cercano() -> Node3D:
	if not is_instance_valid(_owner_body) or not _owner_body.is_inside_tree():
		return null
	var mejor: Node3D = null
	var mejor_dist := ALCANCE_FIJADO
	for t: Node3D in CombatUtils._living_targets(_owner_body):
		if not t.visible:
			continue
		var d := _owner_body.global_position.distance_to(t.global_position)
		if d < mejor_dist:
			mejor = t
			mejor_dist = d
	return mejor


func _fijar(nuevo: Node3D) -> void:
	if is_instance_valid(_marca):
		_marca.queue_free()
	_marca = null
	var antes := objetivo
	objetivo = nuevo
	if is_instance_valid(nuevo):
		_marca = FX.spawn_marca_fijado(nuevo)
	if antes != nuevo:
		fijado_cambio.emit(nuevo)


## Ya no se puede seguir: murio, se escondio (un retirado de la historia), se fue lejos o
## ahora es del mismo equipo.
func _no_sirve(t: Node3D) -> bool:
	if not is_instance_valid(t) or not t.is_inside_tree() or not t.visible:
		return true
	var health := t.get_node_or_null("Health") as Health
	if health == null or health.is_dead:
		return true
	if CombatUtils.son_aliados(_owner_body, t):
		return true
	return _owner_body.global_position.distance_to(t.global_position) > SUELTA_A


func _seguir_fijado(delta: float) -> void:
	if objetivo == null:
		return
	var propia := _owner_body.get_node_or_null("Health") as Health
	if propia != null and propia.is_dead:
		soltar()
		return
	if _no_sirve(objetivo):
		# El siguiente mas cercano, o nadie.
		_fijar(mas_cercano())
		if objetivo == null:
			return
	# En una escena la camara es de la escena.
	if Cinematica.activa:
		return
	# DESDE EL PIVOTE DEL BRAZO, no desde el cuerpo: la camara mira a traves de ese punto,
	# asi que apuntando el brazo al pecho del rival, la mira queda justo encima de el.
	var desde := (_owner_body.global_position + Vector3.UP * eye_height
		+ Basis(Vector3.UP, _yaw).x * shoulder_offset)
	var hacia := (objetivo.global_position + Vector3.UP * 1.1) - desde
	var plano := Vector2(hacia.x, hacia.z).length()
	if plano < 0.3:
		return
	var yaw_deseado := atan2(-hacia.x, -hacia.z)
	# JUSTO AL PECHO, sin inclinar de mas: la mira es por donde salen las habilidades, y
	# corrida hacia abajo quedaba en los pies del rival y los proyectiles pegaban en el piso.
	var pitch_deseado := clampf(atan2(hacia.y, plano),
		deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	var k := 1.0 - exp(-GIRO_FIJADO * delta)
	_yaw = lerp_angle(_yaw, yaw_deseado, k)
	_pitch = lerpf(_pitch, pitch_deseado, k)


func set_yaw(value: float) -> void:
	_yaw = value


## Base de movimiento: solo el giro horizontal, sin inclinacion.
## Asi mirar al piso no te hace caminar hacia abajo.
func get_movement_basis() -> Basis:
	return Basis(Vector3.UP, _yaw)


## Hacia donde apunta la camara de verdad (esto si incluye la inclinacion).
func get_aim_direction() -> Vector3:
	if not is_instance_valid(camera):
		return Vector3.FORWARD
	return -camera.global_transform.basis.z


## Punto del mundo que esta debajo de la mira.
##
## Con la camara corrida al hombro, la camara y el pecho del jugador no miran al mismo
## lado: si las habilidades salieran paralelas a la camara, te errarian a lo que tenes
## apuntado. Buscamos el punto real bajo la mira y despues apuntamos el pecho ahi.
func get_aim_point(max_distance: float = 120.0) -> Vector3:
	if not is_instance_valid(camera):
		return Vector3.ZERO
	var from := camera.global_position
	var to := from + get_aim_direction() * max_distance
	var world := get_world_3d()
	if world == null:
		return to
	var space := world.direct_space_state
	if space == null:
		return to
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PLAYER
	if is_instance_valid(_owner_body):
		query.exclude = [_owner_body.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return to
	return hit["position"]
