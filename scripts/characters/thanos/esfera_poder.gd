class_name EsferaPoder
extends Projectile
## La descarga de la Gema del Poder: una esfera violeta que revienta al tocar algo.
##
## Revienta tambien contra el piso o una pared, como la granada de Rick: una bola de poder
## que se apaga en silencio al fallar no se sentiria como la gema mas destructiva de las seis.

var blast_damage: float = 20.0
var blast_radius: float = 3.2
var _reventada: bool = false


func _init() -> void:
	tint = Color(0.62, 0.22, 0.95)
	hit_radius = 0.34
	fall_gravity = 0.0
	impact_sound = &"plasma_blast"
	knockback = 0.0


func _build_visual() -> void:
	var nucleo := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.16
	bola.height = 0.32
	nucleo.mesh = bola
	nucleo.material_override = make_glow_material(Color(0.95, 0.85, 1.0))
	add_child(nucleo)
	var halo := MeshInstance3D.new()
	var bola_halo := SphereMesh.new()
	bola_halo.radius = 0.32
	bola_halo.height = 0.64
	halo.mesh = bola_halo
	var mat := make_glow_material(tint)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.45
	halo.material_override = mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	add_trail(Color(0.65, 0.30, 1.0, 0.55), 18)
	add_light(tint, 2.2, 4.5)


func _on_hit_player(target: Node3D) -> void:
	super(target)
	_reventar()


func expire() -> void:
	_reventar()
	super()


func _reventar() -> void:
	if _reventada:
		return
	_reventada = true
	# El efecto siempre, el daño solo en el servidor (igual que la granada de Rick).
	FX.spawn_plasma_blast(self, global_position, blast_radius)
	FX.spawn_impact_burst(self, global_position, Color(0.70, 0.30, 1.0, 0.95))
	Sfx.play_3d(self, &"plasma_blast", global_position, 0.0)
	if cosmetic_only:
		return
	for victima: Node3D in CombatUtils.get_players_in_sphere(self, global_position, blast_radius):
		if victima == shooter:
			continue
		CombatUtils.deal_damage(victima, blast_damage, source_id)
		CombatUtils.apply_knockback(victima, victima.global_position - global_position,
			GemaPoder.KNOCKBACK, GemaPoder.KNOCKBACK_LIFT)
