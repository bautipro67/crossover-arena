class_name PetalShot
extends Ability
## Slot 0 de Flowery: "Petalos".
##
## Golpe basico. NO CUESTA STAMINA (regla central del juego).
##
## ES EL UNICO BASICO A DISTANCIA DEL JUEGO, y ahi esta la identidad de Flowery: Noelle
## y Dio tienen que entrar a tres metros para pegar gratis, ella no. A cambio:
##
##   - el daño va repartido en tres petalos, asi que a distancia entra uno o dos y no
##     los tres;
##   - el cooldown es mas largo que los otros dos basicos (0.75 contra 0.5 y 0.4);
##   - no aplica ningun estado. Un basico gratis, a distancia Y con efecto seria mejor
##     que las habilidades pagas de los demas.
##
## Cuentas: 3 x 5 = 15 cada 0.75s = 20 de daño por segundo si entra TODO, contra los 22
## de Noelle pegando de cerca. O sea que el alcance se paga con que casi nunca entra
## completo.

const DAMAGE: float = 5.0
const PETALS: int = 3
## Apertura del abanico. Angosto: a ocho metros el abanico ya mide dos metros de ancho,
## que es mas o menos un jugador.
const SPREAD_DEG: float = 7.0
const SPEED: float = 24.0
const LIFETIME: float = 0.62


func _init() -> void:
	id = &"petal_shot"
	display_name = "Petalos"
	description = "%d petalos al frente, %d de daño cada uno. Gratis y a distancia." % [
		PETALS, int(DAMAGE)]
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 1.1
	channel_time = 0.0
	icon_color = Color(1.0, 0.86, 0.34)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	spawn_petals(caster, origin, dir, false)


## Version puramente visual que corren los clientes remotos (no hace daño).
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	spawn_petals(caster, origin, dir, true)


static func spawn_petals(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var base := dir.normalized()
	for i: int in range(PETALS):
		# Repartidos alrededor del centro: con PETALS=3 salen a -7, 0 y +7 grados.
		var t := float(i) - float(PETALS - 1) * 0.5
		var angle := deg_to_rad(SPREAD_DEG * t)
		var petal := Petal.new()
		petal.damage = DAMAGE
		petal.speed = SPEED
		petal.lifetime = LIFETIME
		Projectile.launch(petal, caster, origin, base.rotated(Vector3.UP, angle), cosmetic)
	Sfx.play_3d(caster, &"petals", origin, -5.0)
