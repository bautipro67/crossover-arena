class_name CorteVolador
extends Node3D
## Un corte de Desmantelar en el aire: una medialuna fina, blanca con el filo rojo.
##
## No es un Projectile porque no muere al tocar a alguien: lo cruza, le pega una vez y
## sigue. Si se corta contra la primera pared, como un rayo. El daño es del servidor
## (cosmetica = false); la copia de los clientes solo se ve.

var dueño: Node = null
var rumbo: Vector3 = Vector3.FORWARD
var cosmetica: bool = false
var inclinacion: float = 0.0
var _recorrido: float = 0.0
var _tocados: Dictionary = {}


func _ready() -> void:
	var filo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.92
	toro.outer_radius = 1.0
	toro.rings = 24
	toro.ring_segments = 4
	filo.mesh = toro
	var mat := Art.glow(Color(1.0, 0.92, 0.92), 3.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	filo.material_override = mat
	filo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Un anillo aplastado en el eje del rumbo: de frente es una raya larga y fina.
	filo.scale = Vector3(1.0, 0.5, 0.16)
	add_child(filo)
	var borde := MeshInstance3D.new()
	borde.mesh = toro
	borde.material_override = Art.glow(Color(0.95, 0.12, 0.15), 2.4)
	borde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	borde.scale = Vector3(1.06, 0.7, 0.08)
	borde.position = -Vector3.FORWARD * 0.05
	add_child(borde)
	# Mirando hacia donde va: la raya queda cruzada a la linea.
	if not rumbo.is_zero_approx():
		look_at_from_position(global_position, global_position + rumbo, Vector3.UP)
	# El anillo ya esta acostado: aplastado en el rumbo queda una raya curva, el tajo.
	rotate_object_local(Vector3.FORWARD, inclinacion)


func _physics_process(delta: float) -> void:
	var paso := Desmantelar.SPEED * delta
	var desde := global_position
	var hasta := desde + rumbo * paso
	_recorrido += paso
	if _recorrido >= Desmantelar.ALCANCE or _choca(desde, hasta):
		FX.spawn_impact_burst(self, global_position, Color(1.0, 0.85, 0.85, 0.8))
		queue_free()
		return
	global_position = hasta
	if cosmetica or not is_instance_valid(dueño) or not (dueño is Node3D):
		return
	var source_id: int = dueño.get("peer_id")
	for t: Node3D in CombatUtils.get_players_in_sphere(dueño as Node3D, global_position - Vector3.UP * 0.9,
			Desmantelar.RADIO + 0.5):
		if _tocados.has(t):
			continue
		_tocados[t] = true
		CombatUtils.deal_damage(t, Desmantelar.DAMAGE, source_id)
		CombatUtils.apply_knockback(t, rumbo, 2.0, 0.6)
		FX.spawn_cortes(self, t.global_position + Vector3.UP * 1.1, 1)


func _choca(desde: Vector3, hasta: Vector3) -> bool:
	var mundo := get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return false
	var rayo := PhysicsRayQueryParameters3D.create(desde, hasta)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	return not mundo.direct_space_state.intersect_ray(rayo).is_empty()
