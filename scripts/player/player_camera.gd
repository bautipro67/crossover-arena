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
@export var min_pitch_deg: float = -75.0
@export var max_pitch_deg: float = 75.0
@export var arm_length: float = 3.8
@export var shoulder_offset: float = 0.7
@export var eye_height: float = 1.5

@onready var camera: Camera3D = $Camera3D

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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not _active or not is_instance_valid(_owner_body):
		return
	# El brazo sigue al jugador manualmente porque es top_level.
	# El corrimiento lateral va aca: deja el cuerpo del jugador a un costado en vez de
	# tapar el centro de la pantalla justo donde esta la mira.
	var yaw_basis := Basis(Vector3.UP, _yaw)
	global_position = (_owner_body.global_position
		+ Vector3.UP * eye_height
		+ yaw_basis.x * shoulder_offset)
	global_rotation = Vector3(_pitch, _yaw, 0.0)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	# La sensibilidad sale de las opciones del jugador, no del export.
	var sens := Settings.mouse_sensitivity if Settings != null else mouse_sensitivity
	_yaw -= motion.relative.x * sens
	_pitch -= motion.relative.y * sens
	_pitch = clampf(_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func get_yaw() -> float:
	return _yaw


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
