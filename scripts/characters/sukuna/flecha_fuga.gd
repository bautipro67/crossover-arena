class_name FlechaFuga
extends Projectile
## La flecha de Fuga en el aire: una lanza de fuego que revienta al tocar algo.

var _reventada: bool = false


func _init() -> void:
	tint = Color(1.0, 0.45, 0.10)
	hit_radius = 0.42
	fall_gravity = 0.0
	impact_sound = &"plasma_blast"


func _build_visual() -> void:
	# La flecha va acostada sobre el rumbo: el eje largo del cilindro mira hacia donde vuela.
	var cuerpo := Node3D.new()
	add_child(cuerpo)
	if not direction.is_zero_approx():
		cuerpo.basis = Basis.looking_at(direction.normalized(), Vector3.UP)
	var asta := Art.cylinder(0.07, 2.2, Art.glow(Color(1.0, 0.85, 0.55), 3.4))
	asta.rotation.x = PI * 0.5
	cuerpo.add_child(asta)
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.26
	cono.height = 0.7
	punta.mesh = cono
	punta.material_override = Art.glow(Color(1.0, 0.55, 0.12), 3.0)
	punta.rotation.x = -PI * 0.5
	punta.position = Vector3(0.0, 0.0, -1.3)
	cuerpo.add_child(punta)
	add_trail(Color(1.0, 0.40, 0.08, 0.6), 28)
	add_light(tint, 3.0, 6.0)


func _on_hit_player(_target: Node3D) -> void:
	_reventar()


func expire() -> void:
	_reventar()
	super()


func _reventar() -> void:
	if _reventada:
		return
	_reventada = true
	FX.spawn_explosion_fuga(self, global_position, Fuga.BLAST_RADIUS)
	if cosmetic_only:
		return
	for victima: Node3D in CombatUtils.get_players_in_sphere(self, global_position, Fuga.BLAST_RADIUS):
		if victima == shooter:
			continue
		CombatUtils.deal_damage(victima, Fuga.DAMAGE, source_id)
		CombatUtils.apply_knockback(victima, victima.global_position - global_position,
			Fuga.KNOCKBACK, Fuga.KNOCKBACK_LIFT)
