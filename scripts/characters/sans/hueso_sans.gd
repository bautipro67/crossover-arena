class_name HuesoSans
extends Ability
## Slot 0 de Sans: "HUESO". Golpe basico, GRATIS como todos.
##
## En su pelea de Undertale todo son huesos: se los tira de frente, de costado, del piso. El
## basico es el mas simple: un hueso que vuela recto y rapido. Es de los pocos basicos a
## distancia, y lo paga pegando poco.

const DAMAGE: float = 10.0
const SPEED: float = 30.0
const LIFETIME: float = 0.45


func _init() -> void:
	id = &"hueso"
	display_name = "Hueso"
	description = "Tira un hueso que vuela recto: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.55
	channel_time = 0.0
	icon_color = Color(0.95, 0.95, 0.92)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var hueso := HuesoVolador.new()
	hueso.damage = DAMAGE
	hueso.speed = SPEED
	hueso.lifetime = LIFETIME
	Projectile.launch(hueso, caster, origin, rumbo, cosmetic, 0.7)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"hueso", (caster as Node3D).global_position + Vector3.UP, -4.0)
