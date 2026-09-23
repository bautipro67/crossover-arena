class_name SpinAttack
extends Ability
## Slot 0 de Sonic: "SPIN ATTACK".
##
## Golpe basico. NO CUESTA STAMINA (regla central del juego).
##
## ES EL ATAQUE DE SU ESPECIE, no un puñetazo con otro nombre. La ficha de Sonic lo dice
## asi: "como implica su especie, Sonic puede enrollarse en una bola concusiva,
## principalmente para atacar enemigos". Es literalmente la primera cosa que el personaje
## sabe hacer desde 1991, asi que su golpe gratis tenia que ser este y no otro.
##
## Comparado con los otros basicos: pega menos que el MUDA de Dio y llega menos lejos que
## el Icicle de Noelle, pero sale mas seguido. Sonic no gana un intercambio, gana la suma
## de muchos intercambios cortos, que es lo que hace un personaje de velocidad.

const DAMAGE: float = 10.0
const CONE_RANGE: float = 2.9
const CONE_ANGLE: float = 70.0
## Casi nada: si empujara fuerte se alejaria solo del rival, y su juego es quedarse encima.
const KNOCKBACK: float = 2.0
## Cuanto avanza el propio Sonic al girar.
##
## UNA BOLA QUE GIRA SE MUEVE. Sin esto el golpe basico era un puñetazo con forma de bola:
## el cuerpo quieto y el daño saliendo adelante. Es poco —medio metro— pero convierte
## quedarse encima del rival en algo que pasa solo al atacar, que es como se juega a
## Sonic: no se acorrala apuntando, se acorrala sin dejar de moverse.
const AVANCE: float = 5.5
const AVANCE_TIEMPO: float = 0.12


func _init() -> void:
	id = &"spin_attack"
	display_name = "Spin Attack"
	description = "Se enrolla en bola y golpea al frente. Gratis y muy rápido."
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.32
	channel_time = 0.0
	icon_color = Color(0.30, 0.55, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.4)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.5, 0.8, 1.0, 0.95))
	var caster3d := caster as Node3D
	if caster3d != null:
		var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
		if not rumbo.is_zero_approx():
			caster3d.call("launch_charge", rumbo, AVANCE, AVANCE_TIEMPO)
	FX.spawn_spin_ball(caster, origin, dir, 0.22)
