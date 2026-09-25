class_name IceShock
extends Ability
## Slot 1 de Noelle: "Ice Shock".
##
## El hechizo de ataque de Noelle en Deltarune. Aca es un proyectil que apila 2 de
## escarcha y ralentiza: es la herramienta principal para llegar a los 5 stacks y
## congelar al rival desde lejos.
##
## CUESTA STAMINA (28).

const PROJECTILE_SPEED: float = 26.0
const PROJECTILE_LIFETIME: float = 3.0
## Bajo de 22 a 19: con el escudo y el congelamiento, Noelle seguia arriba de todos en
## los duelos simulados.
const DAMAGE: float = 19.0
const CHILL_STACKS: int = 2
const SLOW_PERCENT: float = 0.25
const SLOW_DURATION: float = 2.0


func _init() -> void:
	id = &"ice_shock"
	display_name = "Ice Shock"
	description = "Proyectil de hielo. %d de daño, +%d de escarcha y ralentiza %d%% por %.0fs." % [
		int(DAMAGE), CHILL_STACKS, int(SLOW_PERCENT * 100.0), SLOW_DURATION]
	stamina_cost = 28.0
	cooldown = 3.5
	channel_time = 0.0
	icon_color = Color(0.4, 0.75, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	spawn_shard(caster, origin, dir, false)


## Version puramente visual que corren los clientes remotos (no hace daño).
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	spawn_shard(caster, origin, dir, true)


static func spawn_shard(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var shard := IceShard.new()
	shard.damage = DAMAGE
	shard.speed = PROJECTILE_SPEED
	shard.lifetime = PROJECTILE_LIFETIME
	shard.chill_stacks = CHILL_STACKS
	shard.slow_percent = SLOW_PERCENT
	shard.slow_duration = SLOW_DURATION
	Projectile.launch(shard, caster, origin, dir, cosmetic)
	Sfx.play_3d(caster, &"ice_shock", origin, -2.0)
