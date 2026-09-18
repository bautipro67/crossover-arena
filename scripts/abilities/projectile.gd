class_name Projectile
extends Area3D
## Proyectil generico, reutilizable por cualquier personaje. Se arma por codigo.
##
## AUTORIDAD: en el SERVIDOR (cosmetic_only = false) detecta impactos y aplica daño.
## En los clientes remotos (cosmetic_only = true) es solo un visual que viaja igual.
## NUNCA spawnees uno no-cosmetico desde un cliente: tendrias daño doble.
##
## Para hacer un proyectil nuevo: extends Projectile y sobreescribi _build_visual()
## y _on_hit_player(). Ver ice_shard.gd y knife.gd como ejemplos.

var direction: Vector3 = Vector3.FORWARD
var speed: float = 26.0
var lifetime: float = 3.0
var damage: float = 10.0
var source_id: int = 1
var cosmetic_only: bool = false
var shooter: Node = null
## Caida del proyectil. 0 = viaja perfectamente recto.
## OJO: no se puede llamar "gravity" a secas, Area3D ya tiene esa propiedad nativa.
var fall_gravity: float = 0.0
var tint: Color = Color(0.6, 0.85, 1.0)
var hit_radius: float = 0.35
## Que sonido suena al impactar. Lo cambia cada proyectil en su _init().
var impact_sound: StringName = &"hit_ice"
## Empujon al impactar. Va en la clase base porque lo quiere cualquier proyectil.
var knockback: float = 0.0
var knockback_lift: float = 0.0

var _spent: bool = false
var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = GameConfig.LAYER_PROJECTILE
	collision_mask = GameConfig.LAYER_WORLD | GameConfig.LAYER_PLAYER
	monitoring = not cosmetic_only
	monitorable = false
	_velocity = direction.normalized() * speed

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = hit_radius
	shape.shape = sphere
	add_child(shape)

	_build_visual()

	if not cosmetic_only:
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		expire()
		return
	if fall_gravity > 0.0:
		_velocity.y -= fall_gravity * delta
	global_position += _velocity * delta


## Spawnea el proyectil en el mundo del caster y lo devuelve ya posicionado.
static func launch(proj: Projectile, caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool, offset: float = 0.8) -> Projectile:
	if not is_instance_valid(caster):
		return null
	var world := caster.get_parent()
	if world == null:
		return null
	var safe_dir := dir.normalized()
	if safe_dir.is_zero_approx():
		safe_dir = Vector3.FORWARD
	proj.shooter = caster
	proj.source_id = caster.peer_id
	proj.direction = safe_dir
	proj.cosmetic_only = cosmetic
	world.add_child(proj)
	# La posicion se setea DESPUES de entrar al arbol: antes no existe global_position.
	proj.global_position = origin + safe_dir * offset
	return proj


# --------------------------------------------------------------- Sobreescribibles

## Como se ve. Por defecto una esfera emisiva del color de tint.
func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = hit_radius
	sphere.height = hit_radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = make_glow_material(tint)
	add_child(mesh_instance)


## Que pasa al pegarle a un jugador vivo. Por defecto solo daña.
func _on_hit_player(target: Node3D) -> void:
	CombatUtils.deal_damage(target, damage, source_id)
	CombatUtils.apply_knockback(target, direction, knockback, knockback_lift)


## Efecto de impacto (visual + sonido).
func _spawn_impact_fx() -> void:
	FX.spawn_impact_burst(self, global_position, tint)
	Sfx.play_3d(self, impact_sound, global_position, -3.0)


# ------------------------------------------------------------------- Utilidades

static func make_glow_material(color: Color) -> StandardMaterial3D:
	return Art.glow(color, 2.8)


func add_trail(color: Color, amount: int = 24) -> void:
	var trail := CPUParticles3D.new()
	trail.amount = amount
	trail.lifetime = 0.45
	trail.local_coords = false
	trail.direction = Vector3.ZERO
	trail.spread = 25.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 1.0
	trail.scale_amount_min = 0.05
	trail.scale_amount_max = 0.16
	trail.gravity = Vector3.ZERO
	trail.color = color
	trail.emitting = true
	add_child(trail)


func add_light(color: Color, energy: float = 2.0, light_range: float = 4.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	add_child(light)


func _on_body_entered(body: Node3D) -> void:
	if _spent or cosmetic_only:
		return
	if body == shooter:
		return

	if body.is_in_group("players"):
		var health := body.get_node_or_null("Health") as Health
		if health == null or health.is_dead:
			return
		_spent = true
		_on_hit_player(body)
		_spawn_impact_fx()
		expire()
		return

	# Impacto contra el mundo.
	_spent = true
	_spawn_impact_fx()
	expire()


func expire() -> void:
	set_physics_process(false)
	if is_inside_tree():
		queue_free()
