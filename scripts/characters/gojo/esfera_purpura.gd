class_name EsferaPurpura
extends Node3D
## El Purpura en el aire: una esfera violeta enorme que avanza despacio y ATRAVIESA todo.
##
## No es un Projectile porque un Projectile muere al tocar una pared o a alguien, y esta no
## muere con nada: sigue de largo y le pega una sola vez a cada uno que toca. El daño es
## del servidor (cosmetica = false); la copia de los clientes solo se ve.

var dueño: Node = null
var rumbo: Vector3 = Vector3.FORWARD
var cosmetica: bool = false
var _vida: float = Purpura.LIFETIME
var _tocados: Dictionary = {}


func _ready() -> void:
	var nucleo := Art.sphere(Purpura.RADIO * 0.55, Art.glow(Color(0.95, 0.80, 1.0), 3.2))
	add_child(nucleo)
	add_child(Art.sphere(Purpura.RADIO, Art.glow(Color(0.62, 0.22, 0.95), 2.4)))
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.70, 0.35, 1.0)
	luz.light_energy = 6.0
	luz.omni_range = 9.0
	add_child(luz)
	var chispas := CPUParticles3D.new()
	chispas.emitting = true
	chispas.amount = 40
	chispas.lifetime = 0.6
	chispas.local_coords = false
	chispas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	chispas.emission_sphere_radius = Purpura.RADIO
	chispas.gravity = Vector3.ZERO
	chispas.initial_velocity_min = 0.5
	chispas.initial_velocity_max = 2.0
	chispas.scale_amount_min = 0.08
	chispas.scale_amount_max = 0.2
	chispas.color = Color(0.80, 0.55, 1.0, 0.8)
	add_child(chispas)


func _physics_process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	global_position += rumbo * Purpura.SPEED * delta
	if cosmetica or not is_instance_valid(dueño) or not (dueño is Node3D):
		return
	var source_id: int = dueño.get("peer_id")
	for t: Node3D in CombatUtils.get_players_in_sphere(dueño as Node3D, global_position, Purpura.RADIO + 0.6):
		if _tocados.has(t):
			continue
		_tocados[t] = true
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(t, Purpura.DAMAGE, source_id, false)
		CombatUtils.apply_knockback(t, t.global_position - global_position, Purpura.KNOCKBACK, Purpura.KNOCKBACK_LIFT)
		FX.spawn_impact_burst(self, t.global_position + Vector3.UP, Color(0.80, 0.45, 1.0, 0.95))
