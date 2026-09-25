class_name BolaDeFuego
extends Ability
## Slot 1 de Mario: "BOLA DE FUEGO". La de la Flor de Fuego.
##
## Una bola que sale hacia adelante y abajo y va picando por el piso (ver BolaFuego). Es
## la herramienta de media distancia de Mario: pega como un Ice Shock pero sin escarcha,
## sale mas seguido, y al picar es mas dificil de embocar contra alguien que se mueve.
##
## 20 de daño: con 16, en duelos simulados Mario ganaba 1 de cada 5.

const DAMAGE: float = 20.0
const SPEED: float = 21.0
const LIFETIME: float = 1.9


func _init() -> void:
	id = &"bola_de_fuego"
	display_name = "Bola de Fuego"
	description = "Una bola de fuego que va picando por el piso. %d de daño." % int(DAMAGE)
	stamina_cost = 18.0
	cooldown = 2.7
	channel_time = 0.0
	icon_color = Color(1.0, 0.55, 0.15)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	lanzar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	lanzar(caster, origin, dir, true)


static func lanzar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	# Hacia adelante y un poco hacia abajo, sin importar cuanto mire para arriba el que la
	# tira: una bola de fuego no se tira al cielo, se tira al piso para que pique.
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		return
	var bola := BolaFuego.new()
	bola.damage = DAMAGE
	bola.speed = SPEED
	bola.lifetime = LIFETIME
	Projectile.launch(bola, caster, origin - Vector3.UP * 0.3, (plano + Vector3.DOWN * 0.25).normalized(),
		cosmetic, 0.7)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"fuego", (caster as Node3D).global_position + Vector3.UP, -2.0)
