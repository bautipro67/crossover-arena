class_name Telarana
extends Ability
## Slot 1 de Spider-Man: "TELARAÑA".
##
## El disparo de siempre de sus lanzarredes: una bola de tela que se pega al que toca y lo
## deja pegoteado —lento— un buen rato.

const DAMAGE: float = 12.0
const SPEED: float = 34.0
const LIFETIME: float = 0.6
const LENTO: float = 0.6
const LENTO_DURA: float = 2.2


func _init() -> void:
	id = &"telarana"
	display_name = "Telaraña"
	description = "Una bola de telaraña: %d de daño y el que la come queda pegoteado, lento %.1f s." % [
		int(DAMAGE), LENTO_DURA]
	stamina_cost = 22.0
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(0.92, 0.92, 0.95)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var bola := BolaTela.new()
	bola.damage = DAMAGE
	bola.speed = SPEED
	bola.lifetime = LIFETIME
	Projectile.launch(bola, caster, origin, rumbo, cosmetic, 0.7)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"telarana", (caster as Node3D).global_position + Vector3.UP, -2.0)
