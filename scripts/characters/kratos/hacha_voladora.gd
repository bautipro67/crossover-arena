class_name HachaVoladora
extends Node3D
## El Hacha Leviatan en el aire: va recta girando, se clava en la primera pared (o llega al
## alcance) y vuelve a la mano de Kratos, siguiendolo aunque se mueva. Le pega una vez a
## cada uno a la ida y otra vez a la vuelta. El daño es del servidor (cosmetica = false).

var dueño: Node = null
var rumbo: Vector3 = Vector3.FORWARD
var cosmetica: bool = false
var _volviendo: bool = false
var _recorrido: float = 0.0
var _pausa: float = 0.0
var _tocados_ida: Dictionary = {}
var _tocados_vuelta: Dictionary = {}
var _giro: Node3D = null
var _vida: float = 3.0


func _ready() -> void:
	_giro = FX.armar_hacha_leviatan(self)


func _physics_process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0 or not is_instance_valid(dueño) or not (dueño is Node3D):
		queue_free()
		return
	if is_instance_valid(_giro):
		_giro.rotate_object_local(Vector3.RIGHT, delta * 22.0)
	if _pausa > 0.0:
		_pausa -= delta
		return
	var cuerpo := dueño as Node3D
	if not _volviendo:
		var paso := LanzarHacha.SPEED_IDA * delta
		var hasta := global_position + rumbo * paso
		_recorrido += paso
		if _recorrido >= LanzarHacha.ALCANCE or _choca(global_position, hasta):
			# Se clava un instante antes de volver: es lo que se ve en el juego.
			_volviendo = true
			_pausa = 0.18
			FX.spawn_impact_burst(self, global_position, Color(0.75, 0.92, 1.0, 0.8))
			return
		global_position = hasta
	else:
		var mano := cuerpo.global_position + Vector3.UP * 1.1
		var hacia := mano - global_position
		if hacia.length() < 0.8:
			queue_free()
			return
		global_position += hacia.normalized() * minf(hacia.length(), LanzarHacha.SPEED_VUELTA * delta)
	if cosmetica:
		return
	var source_id: int = dueño.get("peer_id")
	var tocados := _tocados_vuelta if _volviendo else _tocados_ida
	for t: Node3D in CombatUtils.get_players_in_sphere(cuerpo, global_position - Vector3.UP * 0.9,
			LanzarHacha.RADIO + 0.4):
		if tocados.has(t):
			continue
		tocados[t] = true
		var dano := LanzarHacha.DAMAGE_VUELTA if _volviendo else LanzarHacha.DAMAGE_IDA
		CombatUtils.deal_damage(t, dano, source_id)
		var estado := t.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null:
			estado.apply_slow(LanzarHacha.LENTO, LanzarHacha.LENTO_DURA)
		FX.spawn_impact_burst(self, t.global_position + Vector3.UP, Color(0.75, 0.92, 1.0, 0.95))


func _choca(desde: Vector3, hasta: Vector3) -> bool:
	var mundo := get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return false
	var rayo := PhysicsRayQueryParameters3D.create(desde, hasta)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	return not mundo.direct_space_state.intersect_ray(rayo).is_empty()
