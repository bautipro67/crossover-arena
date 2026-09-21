class_name Grenade
extends Projectile
## La granada de plasma en vuelo. Revienta al tocar cualquier cosa Y al agotarse.
##
## LAS DOS SALIDAS IMPORTAN. Un proyectil normal muere de dos maneras —choca o se le
## acaba la vida— y la segunda suele ser invisible. En una granada no puede serlo: si
## explotara solo al chocar, tirarla al aire libre no haria nada, y el jugador que la
## ve caer al piso sin reventar cree que la habilidad fallo.

var blast_damage: float = 26.0
var blast_radius: float = 4.6
var _reventada: bool = false


func _init() -> void:
	tint = Color(0.55, 1.0, 0.30)
	hit_radius = 0.26
	impact_sound = &"plasma"
	knockback = 1.0
	knockback_lift = 0.2


func _build_visual() -> void:
	var cuerpo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.16
	esfera.height = 0.32
	cuerpo.mesh = esfera
	cuerpo.material_override = make_glow_material(tint)
	add_child(cuerpo)

	# Anillo alrededor: gira con el vuelo y es lo que la distingue del disparo comun,
	# que tambien es una cosa verde que viaja.
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.19
	toro.outer_radius = 0.24
	anillo.mesh = toro
	anillo.material_override = Art.glow(Color(0.85, 1.0, 0.6), 2.2)
	anillo.rotation_degrees = Vector3(72.0, 0.0, 0.0)
	add_child(anillo)

	add_trail(Color(0.6, 1.0, 0.4, 0.5), 18)
	add_light(tint, 2.0, 4.0)


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
	# EL EFECTO SIEMPRE, EL DAÑO SOLO EN EL SERVIDOR.
	#
	# La copia cosmetica que corre en los clientes remotos tiene que explotar IGUAL: si
	# se saliera antes de llegar aca, los demas verian la granada desaparecer en silencio
	# y recibir daño de la nada.
	FX.spawn_plasma_blast(self, global_position, blast_radius)
	Sfx.play_3d(self, &"plasma_blast", global_position, -1.0)
	if cosmetic_only:
		return
	for victima: Node3D in CombatUtils.get_players_in_sphere(self, global_position, blast_radius):
		if victima == shooter:
			continue
		CombatUtils.deal_damage(victima, blast_damage, source_id)
		CombatUtils.apply_knockback(victima, victima.global_position - global_position,
			PlasmaGrenade.KNOCKBACK, PlasmaGrenade.KNOCKBACK_LIFT)
