class_name KnifeThrow
extends Ability
## Slot 1 de Dio: "Knife Throw".
##
## Tira tres cuchillos en abanico. A distancia media el abanico se abre y normalmente
## le pega uno solo; de cerca entran los tres. Eso lo hace la recompensa por meterse,
## que es exactamente lo que Dio quiere hacer.
##
## CUESTA STAMINA (26).

## Bajo de 12 a 10 (36 a 30 los tres): cuchillos y rafaga juntos seguian bajando a
## cualquiera de 100 en dos habilidades. Medido en duelos simulados, Dio 65%.
const DAMAGE: float = 12.0
const SPEED: float = 34.0
const LIFETIME: float = 2.5
const KNIFE_COUNT: int = 3
const SPREAD_DEG: float = 7.0


func _init() -> void:
	id = &"knife_throw"
	display_name = "Knife Throw"
	description = "Tres cuchillos en abanico, %d de daño cada uno. De cerca entran los tres." % int(DAMAGE)
	stamina_cost = 26.0
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(0.9, 0.9, 0.95)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	spawn_volley(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	spawn_volley(caster, origin, dir, true)


static func spawn_volley(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var base_dir := dir.normalized()
	if base_dir.is_zero_approx():
		return
	# Abrimos el abanico en el plano horizontal, alrededor del eje Y.
	var half := float(KNIFE_COUNT - 1) * 0.5
	for i: int in range(KNIFE_COUNT):
		var angle := deg_to_rad((float(i) - half) * SPREAD_DEG)
		var shot_dir := base_dir.rotated(Vector3.UP, angle)
		var knife := Knife.new()
		knife.damage = DAMAGE
		knife.speed = SPEED
		knife.lifetime = LIFETIME
		Projectile.launch(knife, caster, origin, shot_dir, cosmetic, 0.9)
	Sfx.play_3d(caster, &"knife", origin, -3.0)
