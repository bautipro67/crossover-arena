class_name Rojo
extends Ability
## Slot 2 de Gojo: "ROJO" (Reversal: Red).
##
## Lo contrario del azul: una esfera roja que empuja. Viaja recta y al tocar algo revienta
## y manda lejos a todos los que estan alrededor.

const DAMAGE: float = 23.0
const BLAST_RADIUS: float = 2.6
const SPEED: float = 30.0
const LIFETIME: float = 0.7
const KNOCKBACK: float = 14.0
const KNOCKBACK_LIFT: float = 3.0


func _init() -> void:
	id = &"rojo"
	display_name = "Rojo"
	description = "Una esfera roja que revienta al tocar algo: %d de daño y manda lejos a todos a %.1f m." % [
		int(DAMAGE), BLAST_RADIUS]
	stamina_cost = 28.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.25, 0.25)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var esfera := EsferaRoja.new()
	esfera.damage = 0.0
	esfera.speed = SPEED
	esfera.lifetime = LIFETIME
	Projectile.launch(esfera, caster, origin, rumbo, cosmetic, 0.9)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"gema", (caster as Node3D).global_position + Vector3.UP, -2.0)
