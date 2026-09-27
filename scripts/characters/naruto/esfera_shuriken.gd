class_name EsferaShuriken
extends Projectile
## El Rasen-Shuriken en el aire: la esfera azul con el disco blanco de aspas girando.
##
## Revienta al tocar algo o al final del recorrido, como la esfera de la Gema del Poder.

var _aspas: Node3D = null
var _reventada: bool = false


func _init() -> void:
	tint = Color(0.70, 0.90, 1.0)
	hit_radius = 0.6
	fall_gravity = 0.0
	impact_sound = &"plasma_blast"


func _build_visual() -> void:
	var nucleo := Art.sphere(0.28, Art.glow(Color(0.55, 0.80, 1.0), 2.8))
	add_child(nucleo)
	_aspas = Node3D.new()
	add_child(_aspas)
	var blanco := Art.glow(Color(0.95, 0.98, 1.0), 2.2)
	var disco := Art.cylinder(0.62, 0.04, blanco)
	_aspas.add_child(disco)
	for k: int in range(4):
		var aspa := Art.box(Vector3(1.9, 0.03, 0.22), blanco)
		aspa.rotation_degrees = Vector3(0.0, float(k) * 45.0, 0.0)
		_aspas.add_child(aspa)
	add_trail(Color(0.75, 0.92, 1.0, 0.5), 22)
	add_light(tint, 3.0, 6.0)


func _physics_process(delta: float) -> void:
	if is_instance_valid(_aspas):
		_aspas.rotate_y(delta * 20.0)
	super(delta)


func _on_hit_player(_target: Node3D) -> void:
	_reventar()


func expire() -> void:
	_reventar()
	super()


func _reventar() -> void:
	if _reventada:
		return
	_reventada = true
	FX.spawn_plasma_blast(self, global_position, Rasenshuriken.BLAST_RADIUS)
	FX.spawn_impact_burst(self, global_position, Color(0.80, 0.95, 1.0, 0.95))
	FX.camera_shake(1.4)
	Sfx.play_3d(self, &"plasma_blast", global_position, 3.0)
	if cosmetic_only:
		return
	for victima: Node3D in CombatUtils.get_players_in_sphere(self, global_position, Rasenshuriken.BLAST_RADIUS):
		if victima == shooter:
			continue
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(victima, Rasenshuriken.DAMAGE, source_id, false)
		CombatUtils.apply_knockback(victima, victima.global_position - global_position,
			Rasenshuriken.KNOCKBACK, Rasenshuriken.KNOCKBACK_LIFT)
