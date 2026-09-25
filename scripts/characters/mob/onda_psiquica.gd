class_name OndaPsiquica
extends Ability
## Slot 0 de Mob: "ONDA PSIQUICA". Golpe basico, GRATIS como todos.
##
## Mob no pelea con los puños: no es atletico, y en la serie apenas corre. Lo que tiene es
## telequinesis, y la usa para empujar lo que tiene adelante. Por eso su basico es a
## distancia, como el de Rick, pero CORTA: se apaga a unos doce metros.

## 8 y no 11: a distancia y alejandose, con 11 Mob ganaba nueve de cada diez duelos
## simulados, y es el premio del pase: no puede ser el mas fuerte.
const DAMAGE: float = 8.0
const SPEED: float = 32.0
const LIFETIME: float = 0.38


func _init() -> void:
	id = &"onda_psiquica"
	display_name = "Onda Psíquica"
	description = "Un empujón de telequinesis a distancia corta, %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.78
	channel_time = 0.0
	icon_color = Color(0.62, 0.80, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	disparar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	disparar(caster, origin, dir, true)


static func disparar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var onda := EsferaPsiquica.new()
	onda.damage = DAMAGE
	onda.speed = SPEED
	onda.lifetime = LIFETIME
	Projectile.launch(onda, caster, origin, rumbo, cosmetic, 0.8)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"psiquico", (caster as Node3D).global_position + Vector3.UP, -6.0)
