class_name Teletransportacion
extends Ability
## Slot 2 de Goku: "TELETRANSPORTACION" (Shunkan Ido).
##
## Aparece DETRAS del rival que esta mirando y le pega un rodillazo en la espalda.
##
## ES COMO LA USA EL EN LA SERIE: no para escaparse, para aparecer donde el otro no esta
## mirando. Y es lo que la separa del portal de Rick, que te lleva a un LUGAR: esta te lleva
## a una PERSONA. Por eso, igual que el Homing de Sonic, necesita un blanco.
##
## SIN BLANCO NO SALE, y devuelve la stamina. Una teletransportacion al vacio seria un
## portal peor, y cobrarla igual castiga por no tener a nadie a tiro.
##
## "DETRAS" ES DETRAS DE SU ESPALDA, no del otro lado de donde estabas vos. Si el rival te
## esta mirando, terminas detras de el; si te daba la espalda, igual: la tecnica es
## aparecer donde no mira.

## Subio de 16 a 22: aparecer detras tiene que dar ventaja, no solo reubicarte.
const DAMAGE: float = 22.0
const ALCANCE: float = 24.0
## Cuan al frente tiene que estar: la que estas mirando, no la que tenes al costado.
const ANGULO: float = 60.0
## A cuanto de su espalda aparece.
const DETRAS: float = 1.5
## El instante entre desaparecer y aparecer. Casi nada: la tecnica es instantanea, pero
## sin ninguna pausa el cuerpo del que mira salta sin que se vea que se fue.
const DESAPARECE: float = 0.10
const KNOCKBACK: float = 7.0
const KNOCKBACK_LIFT: float = 3.0


func _init() -> void:
	id = &"teletransportacion"
	display_name = "Teletransportación"
	description = "Aparecés detrás de la espalda del rival que estás mirando y le pegás un rodillazo (%d)." % int(DAMAGE)
	stamina_cost = 30.0
	cooldown = 12.0
	channel_time = 0.0
	icon_color = Color(0.85, 0.95, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return

	var blanco := CombatUtils.mas_cercano_en_cono(caster3d, origin, dir, ALCANCE, ANGULO)
	if blanco == null:
		var st := caster.get_node_or_null("Stamina") as Stamina
		if st != null:
			st.devolver(stamina_cost)
		Sfx.play_2d(&"no_stamina", -8.0)
		return

	FX.spawn_teletransporte(caster, caster3d.global_position)
	Sfx.play_3d(caster, &"dash", caster3d.global_position, -2.0)

	await tree.create_timer(DESAPARECE).timeout
	if Ability.interrumpida(caster3d) or not is_instance_valid(blanco) or blanco.health.is_dead:
		return

	var destino := calcular_destino(caster3d, blanco)
	# Mirando a la espalda del rival: aparecer detras y de espaldas a el seria aparecer
	# en el lugar justo mirando para el otro lado.
	var hacia := blanco.global_position - destino
	var yaw := atan2(-hacia.x, -hacia.z)
	caster3d.call("teleport_to", destino, yaw)
	FX.spawn_teletransporte(caster, destino)
	Sfx.play_3d(caster, &"dash", destino, -2.0)

	var source_id: int = caster.peer_id
	CombatUtils.deal_damage(blanco, DAMAGE, source_id)
	CombatUtils.apply_knockback(blanco, hacia, KNOCKBACK, KNOCKBACK_LIFT)
	FX.spawn_impact_burst(caster, blanco.global_position + Vector3.UP, Color(1.0, 0.85, 0.45, 1.0))
	FX.camera_shake(0.9)


## El punto detras de la espalda del rival, en el piso y libre.
static func calcular_destino(caster: Node3D, blanco: Node3D) -> Vector3:
	# Hacia donde mira el rival: su frente es -Z, como el de todos.
	var frente := -blanco.global_transform.basis.z
	frente.y = 0.0
	if frente.is_zero_approx():
		frente = blanco.global_position - caster.global_position
		frente.y = 0.0
	frente = frente.normalized()
	var punto := blanco.global_position - frente * DETRAS
	# Una pared detras del rival: se busca el hueco libre mas cercano. Sin esto, alguien
	# con la espalda contra un muro te mandaba adentro del muro.
	var arena := caster.get_parent() as Arena
	if arena != null:
		punto = arena.find_clear_spot(punto, 0.6)
	return punto
