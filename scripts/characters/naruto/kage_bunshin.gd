class_name KageBunshin
extends Ability
## Slot 1 de Naruto: "KAGE BUNSHIN NO JUTSU", los clones de sombra.
##
## Su tecnica de siempre: aparece rodeado de copias suyas que salen corriendo a pegarle al
## rival. Aca son dos clones que persiguen al mas cercano y se deshacen en humo al pegar.

const CUANTOS: int = 2
const DAMAGE: float = 18.0
const SPEED: float = 12.0
const VIDA: float = 3.5
const ABANICO: float = 40.0


func _init() -> void:
	id = &"kage_bunshin"
	display_name = "Kage Bunshin"
	description = "Suelta %d clones de sombra que persiguen al rival: %d de daño cada uno." % [
		CUANTOS, int(DAMAGE)]
	stamina_cost = 30.0
	cooldown = 10.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.62, 0.18)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	soltar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	soltar(caster, origin, dir, true)


static func soltar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		return
	FX.spawn_humo(caster, origin + Vector3.DOWN * 0.6)
	var mitad := float(CUANTOS - 1) * 0.5
	for i: int in range(CUANTOS):
		var salida := rumbo.rotated(Vector3.UP, deg_to_rad((float(i) - mitad) * ABANICO))
		var clon := ClonNaruto.new()
		clon.damage = DAMAGE
		clon.speed = SPEED
		clon.lifetime = VIDA
		Projectile.launch(clon, caster, origin + Vector3.DOWN * 0.3, salida, cosmetic, 1.0)
