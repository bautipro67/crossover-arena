class_name GemaPoder
extends Ability
## Slot 1 de Thanos: "GEMA DEL PODER". La violeta, la que destruye.
##
## En la pelea de Titan, Thanos descarga la Gema del Poder desde el Guantelete en rafagas
## violetas. Aca es una esfera que viaja recta y revienta al tocar algo —un rival, el piso,
## una pared— con un estallido que empuja a todos alrededor.

const IMPACT_DAMAGE: float = 8.0
const BLAST_DAMAGE: float = 18.0
const BLAST_RADIUS: float = 3.6
const SPEED: float = 26.0
const LIFETIME: float = 1.2
const KNOCKBACK: float = 9.0
const KNOCKBACK_LIFT: float = 2.6


func _init() -> void:
	id = &"gema_poder"
	display_name = "Gema del Poder"
	description = "Una descarga violeta que revienta al tocar algo: %d de daño a todos a %.1f m." % [
		int(BLAST_DAMAGE), BLAST_RADIUS]
	stamina_cost = 30.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.62, 0.22, 0.95)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var esfera := EsferaPoder.new()
	esfera.damage = IMPACT_DAMAGE
	esfera.speed = SPEED
	esfera.lifetime = LIFETIME
	esfera.blast_damage = BLAST_DAMAGE
	esfera.blast_radius = BLAST_RADIUS
	Projectile.launch(esfera, caster, origin, rumbo, cosmetic, 0.9)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"gema", (caster as Node3D).global_position + Vector3.UP, -2.0)
