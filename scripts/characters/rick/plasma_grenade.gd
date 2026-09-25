class_name PlasmaGrenade
extends Ability
## Slot 2 de Rick: "GRANADA DE PLASMA".
##
## La tira en arco y revienta en un radio. Es lo que le da respuesta a alguien que se le
## metio encima —que es la situacion en la que Rick pierde— y lo unico de su kit que no
## necesita puntería fina.
##
## VA EN ARCO Y NO RECTA, a proposito. Un proyectil recto ya lo tiene en el basico; el
## arco pide medir la distancia en vez de apuntar, sirve para tirar por encima de una
## cobertura, y le da al rival el tiempo de vuelo para salirse del circulo.

const IMPACT_DAMAGE: float = 10.0
## Subio de 26 a 32: la granada tarda en caer y se esquiva, y tiene que valer la pena.
const BLAST_DAMAGE: float = 32.0
## Subio de 4.6 a 5.2: tarda en caer, y con el radio justo casi nunca agarraba a nadie.
const BLAST_RADIUS: float = 5.2
const SPEED: float = 22.0
## Mecha. Con la deteccion de impacto arreglada revienta al tocar el piso, asi que esto
## solo aplica a una granada tirada al aire libre. 1.6 y no 2.4: el reclamo fue que
## tardaba en explotar, y aunque la causa real era que atravesaba el piso, dos segundos y
## medio colgada en el aire igual se siente a que no paso nada.
const LIFETIME: float = 1.6
const CAIDA: float = 11.0
const KNOCKBACK: float = 7.5
const KNOCKBACK_LIFT: float = 2.4


func _init() -> void:
	id = &"plasma_grenade"
	display_name = "Granada de Plasma"
	description = "La tira en arco. Revienta en %d metros y hace %d." % [
		int(BLAST_RADIUS), int(BLAST_DAMAGE)]
	stamina_cost = 30.0
	# Bajo de 8 a 6: es lo unico que Rick tiene para sacar mucho de golpe, y con 8 salia
	# una vez por pelea.
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(0.6, 1.0, 0.3)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	# Un poco hacia arriba: sin esto, apuntando al piso la granada se clava a dos metros
	# y el arco no existe.
	rumbo = (rumbo + Vector3.UP * 0.30).normalized()
	var g := Grenade.new()
	g.damage = IMPACT_DAMAGE
	g.speed = SPEED
	g.lifetime = LIFETIME
	g.fall_gravity = CAIDA
	g.blast_damage = BLAST_DAMAGE
	g.blast_radius = BLAST_RADIUS
	Projectile.launch(g, caster, origin, rumbo, cosmetic, 0.9)
