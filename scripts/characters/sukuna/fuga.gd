class_name Fuga
extends Ability
## Slot 2 de Sukuna: "FUGA" (Fuego abierto).
##
## Arma una flecha de fuego entre las manos y la suelta: vuela recta, y al tocar algo
## revienta en una explosion grande que quema a todos los que estan alrededor. Lenta para
## lo que es una flecha, asi que de lejos se puede esquivar; de cerca no.

const DAMAGE: float = 22.0
const BLAST_RADIUS: float = 3.6
const SPEED: float = 24.0
const LIFETIME: float = 1.1
const KNOCKBACK: float = 9.0
const KNOCKBACK_LIFT: float = 3.5


func _init() -> void:
	id = &"fuga"
	display_name = "Fuga"
	description = "Una flecha de fuego que revienta al tocar algo: %d de daño a todos a %.1f m." % [
		int(DAMAGE), BLAST_RADIUS]
	stamina_cost = 30.0
	cooldown = 11.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.45, 0.10)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var flecha := FlechaFuga.new()
	flecha.damage = 0.0
	flecha.speed = SPEED
	flecha.lifetime = LIFETIME
	Projectile.launch(flecha, caster, origin, rumbo, cosmetic, 1.0)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"fuego", (caster as Node3D).global_position + Vector3.UP, 0.0)
