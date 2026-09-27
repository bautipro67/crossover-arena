class_name Rasenshuriken
extends Ability
## Slot 3 de Naruto: "RASEN-SHURIKEN". Su definitiva.
##
## El Rasengan con chakra de viento: una esfera con cuatro aspas que se tira y revienta en
## una tormenta de cortes. Aca viaja recto y revienta al tocar algo —un rival, el piso,
## una pared— o al final del recorrido, en una esfera grande.

const DAMAGE: float = 55.0
const BLAST_RADIUS: float = 5.5
const SPEED: float = 22.0
const LIFETIME: float = 1.6
const KNOCKBACK: float = 10.0
const KNOCKBACK_LIFT: float = 3.0


func _init() -> void:
	id = &"rasenshuriken"
	display_name = "Rasen-Shuriken"
	description = "Tira la esfera de viento con aspas: revienta en %.1f m y hace %d de daño a todos." % [
		BLAST_RADIUS, int(DAMAGE)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.2
	requires_charge = true
	icon_color = Color(0.70, 0.90, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var s := EsferaShuriken.new()
	s.damage = 0.0
	s.speed = SPEED
	s.lifetime = LIFETIME
	Projectile.launch(s, caster, origin, rumbo, cosmetic, 1.0)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"psiquico", (caster as Node3D).global_position + Vector3.UP, 0.0)
