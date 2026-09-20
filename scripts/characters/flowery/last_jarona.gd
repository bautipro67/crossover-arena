class_name LastJarona
extends Ability
## Slot 3 de Flowery: "LAST JARONA". Su ultimate.
##
## El ultimo grito, el que se tira cuando ya no queda nada. Canaliza y revienta en una
## onda que barre toda la zona.
##
## LAS TRES FORMAS DE ULTIMATE DEL JUEGO, y por que esta es distinta:
##
##   Snowgrave   -> CONO largo. Premia apuntar y haber congelado antes.
##   ZA WARUDO   -> ESFERA que para el tiempo. Premia lo que hagas DESPUES.
##   Last Jarona -> ESFERA que pega YA, con el daño cayendo con la distancia.
##
## O sea: el de Noelle pide preparacion, el de Dio abre una ventana, y este no pide nada
## mas que estar en el medio. Es el ultimate del que va perdiendo, y eso es exactamente
## lo que es en su pelea: un ultimo intento.
##
## El daño CAE CON LA DISTANCIA en vez de ser plano. Con daño plano, un radio de 22
## metros seria "aprieto Q y gana el que tenga mas rango"; con caida, el que esta lejos
## se come un raspon y el que la dejo acercarse se come el golpe entero. Se puede
## responder alejandose, que es lo que un ultimate radial necesita para no ser un boton.

const RADIUS: float = 22.0
## Daño en el centro y en el borde. Entre medio interpola.
const DAMAGE_CENTER: float = 110.0
const DAMAGE_EDGE: float = 34.0
## Hasta aca se cobra el daño maximo, sin caida.
const CORE_RADIUS: float = 6.0
const KNOCKBACK: float = 14.0
const KNOCKBACK_LIFT: float = 6.0


func _init() -> void:
	id = &"last_jarona"
	display_name = "LAST JARONA"
	description = "Canaliza 1.2s y revienta en %.0fm. %d de daño en el centro, %d en el borde. Corta todo canalizado." % [
		RADIUS, int(DAMAGE_CENTER), int(DAMAGE_EDGE)]
	stamina_cost = 100.0
	cooldown = 10.0
	# Canaliza: el rival tiene que poder verlo venir y alejarse o cortarlo.
	channel_time = 1.2
	requires_charge = true
	icon_color = Color(1.0, 0.46, 0.22)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	var caster3d := caster as Node3D

	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, origin, RADIUS):
		if not CombatUtils.has_line_of_sight(caster3d, origin, target):
			continue

		var dist := origin.distance_to(target.global_position)
		var amount := DAMAGE_CENTER
		if dist > CORE_RADIUS:
			var t := clampf((dist - CORE_RADIUS) / (RADIUS - CORE_RADIUS), 0.0, 1.0)
			amount = lerpf(DAMAGE_CENTER, DAMAGE_EDGE, t)

		# El daño del ultimate NO paga recursos (ni medidor ni stamina): ver deal_damage.
		CombatUtils.deal_damage(target, amount, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, KNOCKBACK_LIFT)
		Jarona._interrumpir(target)
		FX.spawn_hit_impact(caster, target.global_position + Vector3.UP, amount,
			Color(1.0, 0.55, 0.25))

	FX.spawn_last_jarona(caster, origin, RADIUS)
