class_name Lanza
extends Ability
## Slot 1 de Scorpion: "LANZA", el "¡GET OVER HERE!".
##
## Su movimiento de siempre, desde el primer Mortal Kombat: tira un kunai atado a una
## cadena, y si ensarta a alguien lo ARRASTRA hasta tenerlo adelante. Aca es igual: el kunai
## viaja recto, y al que toca lo trae de un tiron hasta quedar a un paso de Scorpion.
##
## SE VE VENIR: el grito sale al tirarla, como en el juego, y la cadena se ve en el aire.
## Lo unico que no se trae es lo invencible (la Superestrella).
##
## Y EL QUE LLEGA, LLEGA ATONTADO, como en el juego —ahi queda parado un momento, listo para
## el golpe—. Aca no se lo aturde (el tambaleo por golpe se saco a pedido): queda lento un
## rato. Sin eso, medido, el que peleaba de lejos volvia a su distancia antes del primer
## tajo y Scorpion perdia casi todos los duelos (17%).

const DAMAGE: float = 14.0
const ALCANCE: float = 22.0
const SPEED: float = 46.0
## A que velocidad lo arrastra, y a cuanto de Scorpion lo deja.
const TIRON_SPEED: float = 30.0
const QUEDA: float = 1.8
## Lo lento que queda el que llega, y cuanto dura.
const ATONTADO: float = 0.45
const ATONTADO_DURA: float = 1.6


func _init() -> void:
	id = &"lanza"
	display_name = "Lanza"
	description = "Tira el kunai con la cadena: %d de daño, arrastra al que ensarta hasta tenerlo adelante y lo deja lento. Hasta %d m." % [
		int(DAMAGE), int(ALCANCE)]
	stamina_cost = 28.0
	cooldown = 8.0
	channel_time = 0.0
	icon_color = Color(0.80, 0.76, 0.68)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


## Version puramente visual para los clientes remotos.
static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var kunai := KunaiLanza.new()
	kunai.damage = DAMAGE
	kunai.speed = SPEED
	kunai.lifetime = ALCANCE / SPEED
	Projectile.launch(kunai, caster, origin, rumbo, cosmetic, 0.7)
	if is_instance_valid(caster) and caster is Node3D:
		Sfx.play_3d(caster, &"cadena", (caster as Node3D).global_position + Vector3.UP, -1.0)


## SOLO SERVIDOR. El tiron: lo arrastra hasta dejarlo a QUEDA metros de Scorpion.
##
## Va por launch_charge —la maquinaria del dash— y no moviendolo a mano: el movimiento es
## del dueño de cada cuerpo, y es el unico empujon que el dueño aplica y todos ven igual.
static func tirar_de(caster: Node, target: Node3D) -> void:
	if not is_instance_valid(caster) or not (caster is Node3D) or not is_instance_valid(target):
		return
	var estado := target.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null and estado.es_invencible():
		return
	var hacia := (caster as Node3D).global_position - target.global_position
	var plano := Vector3(hacia.x, 0.0, hacia.z)
	var dist := plano.length()
	efecto_tiron(caster, target, dist)
	if estado != null:
		estado.apply_slow(ATONTADO, ATONTADO_DURA + maxf(0.0, dist - QUEDA) / TIRON_SPEED)
	if dist <= QUEDA + 0.2 or not target.has_method("launch_charge"):
		return
	target.call("launch_charge", plano / dist, TIRON_SPEED, (dist - QUEDA) / TIRON_SPEED)


## La cadena tensa mientras lo trae. Corre en el servidor y en cada cliente.
static func efecto_tiron(caster: Node, target: Node3D, dist: float) -> void:
	if not is_instance_valid(caster) or not (caster is Node3D) or not is_instance_valid(target):
		return
	CadenaScorpion.crear(caster as Node3D, target, maxf(0.2, (dist - QUEDA) / TIRON_SPEED) + 0.15,
		CadenaScorpion.ALTO_BLANCO)
	FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.78, 0.30, 0.95))
	Sfx.play_3d(caster, &"cadena", target.global_position + Vector3.UP, 0.0)
