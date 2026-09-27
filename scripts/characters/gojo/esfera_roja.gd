class_name EsferaRoja
extends Projectile
## El Rojo de Gojo en el aire: una esfera roja que revienta al tocar algo y empuja a todos.

var _reventada: bool = false


func _init() -> void:
	tint = Color(1.0, 0.22, 0.20)
	hit_radius = 0.36
	fall_gravity = 0.0
	impact_sound = &"plasma_blast"


func _build_visual() -> void:
	add_child(Art.sphere(0.18, Art.glow(Color(1.0, 0.75, 0.70), 3.0)))
	var halo := Art.sphere(0.34, Art.glow(tint, 2.2))
	add_child(halo)
	add_trail(Color(1.0, 0.30, 0.25, 0.55), 18)
	add_light(tint, 2.4, 4.5)


func _on_hit_player(_target: Node3D) -> void:
	_reventar()


func expire() -> void:
	_reventar()
	super()


func _reventar() -> void:
	if _reventada:
		return
	_reventada = true
	FX.spawn_plasma_blast(self, global_position, Rojo.BLAST_RADIUS)
	FX.spawn_impact_burst(self, global_position, Color(1.0, 0.35, 0.30, 0.95))
	Sfx.play_3d(self, &"plasma_blast", global_position, 0.0)
	if cosmetic_only:
		return
	for victima: Node3D in CombatUtils.get_players_in_sphere(self, global_position, Rojo.BLAST_RADIUS):
		if victima == shooter:
			continue
		CombatUtils.deal_damage(victima, Rojo.DAMAGE, source_id)
		CombatUtils.apply_knockback(victima, victima.global_position - global_position,
			Rojo.KNOCKBACK, Rojo.KNOCKBACK_LIFT)
