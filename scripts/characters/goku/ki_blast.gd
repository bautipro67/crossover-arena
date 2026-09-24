class_name KiBlast
extends Ability
## Slot 1 de Goku: "RAFAGA DE KI". Tres esferas de energia, una detras de otra.
##
## EN RAFAGA Y NO UNA SOLA, porque asi las tira el en la serie: un brazo y el otro,
## seguido, mientras avanza. Tambien es lo que la separa del Ice Shock de Noelle, que es
## un tiro unico y fuerte. Esta pide sostener la mira: las tres juntas pegan lo mismo que
## un Ice Shock, pero solo si las tres llegan.
##
## LA DIRECCION SE RELEE EN CADA ESFERA. La primera sale hacia donde apuntabas al apretar,
## las otras dos hacia donde apuntas en ese momento: se puede corregir en el medio.

const DAMAGE: float = 8.0
const DISPAROS: int = 3
## Entre una esfera y la siguiente.
const INTERVALO: float = 0.13
const SPEED: float = 36.0
const LIFETIME: float = 1.3


func _init() -> void:
	id = &"ki_blast"
	display_name = "Ráfaga de Ki"
	description = "Tres esferas de ki seguidas, %d de daño cada una. Se puede reapuntar entre una y otra." % int(DAMAGE)
	stamina_cost = 24.0
	cooldown = 4.0
	channel_time = 0.0
	icon_color = Color(0.55, 0.85, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	disparar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	disparar(caster, origin, dir, true)


static func disparar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var tree := caster.get_tree() if is_instance_valid(caster) else null
	if tree == null:
		return
	var rumbo := dir.normalized()
	for i: int in range(DISPAROS):
		if i > 0:
			await tree.create_timer(INTERVALO).timeout
			if not is_instance_valid(caster):
				return
			# El servidor relee la mira; el cliente remoto no la sabe y repite la primera,
			# desde donde este el cuerpo ahora. Se ven casi igual y el daño lo decide el
			# servidor igual.
			if not cosmetic and caster.has_method("get_aim_direction"):
				origin = caster.call("get_aim_origin")
				rumbo = (caster.call("get_aim_direction") as Vector3).normalized()
			elif caster is Node3D:
				origin = (caster as Node3D).global_position + Vector3.UP * 1.2
		if rumbo.is_zero_approx():
			return
		var esfera := KiEsfera.new()
		esfera.damage = DAMAGE
		esfera.speed = SPEED
		esfera.lifetime = LIFETIME
		# Una de cada mano: corrida a un costado y al otro, alternando.
		var costado := Vector3(-rumbo.z, 0.0, rumbo.x).normalized() * (0.28 if i % 2 == 0 else -0.28)
		Projectile.launch(esfera, caster, origin + costado, rumbo, cosmetic, 0.9)
		# En las dos versiones: el sonido es local, y cada pantalla toca el suyo.
		Sfx.play_3d(caster, &"plasma", origin, -4.0)
