class_name PlasmaShot
extends Ability
## Slot 0 de Rick: su pistola de plasma. GRATIS, como todos los basicos.
##
## ES EL UNICO BASICO A DISTANCIA DEL JUEGO. Noelle zarpa, Dio da trompadas y Flowery
## tira petalos a tres metros: los tres tienen que estar encima para usar lo que no
## cuesta nada. Rick dispara de lejos, y eso le da una forma de pelear que no existia.
##
## El precio esta en otro lado: es el mas lento, el mas fragil, y el tiro viaja, asi que
## de cerca —donde los demas ganan— es el peor de los cuatro.

## Subio de 9 a 14. Es lo unico que Rick hace de lejos, y con 9 perdia todos los
## intercambios: en duelos simulados gano 1 de 80.
const DAMAGE: float = 14.0
const SPEED: float = 42.0
const LIFETIME: float = 1.6


func _init() -> void:
	id = &"plasma_shot"
	display_name = "Pistola de Plasma"
	description = "Disparo de plasma, %d de daño. Gratis y a distancia." % int(DAMAGE)
	stamina_cost = 0.0
	# Bajo de 0.55 a 0.5, el mismo ritmo que el golpe de Noelle.
	cooldown = 0.75
	channel_time = 0.0
	icon_color = Color(0.45, 0.95, 0.35)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	disparar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	disparar(caster, origin, dir, true)


static func disparar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var bolt := PlasmaBolt.new()
	bolt.damage = DAMAGE
	bolt.speed = SPEED
	bolt.lifetime = LIFETIME
	Projectile.launch(bolt, caster, origin, rumbo, cosmetic, 0.9)
