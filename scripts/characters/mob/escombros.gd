class_name Escombros
extends Ability
## Slot 1 de Mob: "ESCOMBROS". Levanta pedazos del piso con la telequinesis y los tira
## uno detras de otro.
##
## Es lo que Mob hace en casi todas sus peleas: no le pega a nadie con el cuerpo, le tira
## el mundo encima. Cuatro piedras seguidas, y entre una y otra se puede reapuntar: al que
## esquiva la primera le llega la segunda.

const DAMAGE: float = 7.0
const PIEDRAS: int = 4
const INTERVALO: float = 0.16
const SPEED: float = 28.0
const LIFETIME: float = 1.1


func _init() -> void:
	id = &"escombros"
	display_name = "Escombros"
	description = "Levanta %d piedras con la telequinesis y las tira una tras otra, %d de daño cada una." % [
		PIEDRAS, int(DAMAGE)]
	stamina_cost = 28.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.70, 0.66, 0.62)


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
	for i: int in range(PIEDRAS):
		if i > 0:
			await tree.create_timer(INTERVALO).timeout
			if Ability.interrumpida(caster):
				return
			# El servidor relee la mira; el cliente remoto repite la primera desde donde
			# este el cuerpo ahora (igual que la Rafaga de Ki).
			if not cosmetic and caster.has_method("get_aim_direction"):
				origin = caster.call("get_aim_origin")
				rumbo = (caster.call("get_aim_direction") as Vector3).normalized()
			elif caster is Node3D:
				origin = (caster as Node3D).global_position + Vector3.UP * 1.2
		if rumbo.is_zero_approx():
			return
		var piedra := Escombro.new()
		piedra.damage = DAMAGE
		piedra.speed = SPEED
		piedra.lifetime = LIFETIME
		# Salen de alrededor de Mob, no del pecho: de un costado, del otro, de arriba.
		var costado := Vector3(-rumbo.z, 0.0, rumbo.x).normalized()
		var desvio: Vector3 = [costado * 0.6, -costado * 0.6, Vector3.UP * 0.6, Vector3.ZERO][i % 4]
		Projectile.launch(piedra, caster, origin + desvio, rumbo, cosmetic, 0.9)
		Sfx.play_3d(caster, &"psiquico", origin, -5.0)
