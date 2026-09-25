class_name Superestrella
extends Ability
## Slot 3 de Mario: "SUPERESTRELLA". Su definitiva.
##
## Como en los juegos: unos segundos INVENCIBLE, mas rapido, y el que toca sale volando.
##
## INVENCIBLE DE VERDAD, no "casi" como Super Sonic: nada le saca vida ni lo frena —ni un
## golpe, ni la escarcha, ni el tiempo detenido, ni un empujon— (ver
## StatusEffects.estrella). Lo que la equilibra es lo mismo que en el original: dura poco,
## y la contra es la de siempre contra un Mario con estrella, que es no dejarse tocar.
## Correrse, esperar a que se apague, y recien ahi volver.
##
## El daño de la definitiva no paga recursos: no recarga el medidor ni devuelve stamina.

const DURACION: float = 6.0
const VELOCIDAD: float = 1.35
## A esta distancia del cuerpo, cuenta como tocado.
const RADIO: float = 1.5
const DAMAGE: float = 9.0
## Cuanto espera para volver a pegarle al MISMO rival. Sin esto, uno pegado al cuerpo se
## comeria diez golpes por segundo.
const ENTRE_GOLPES: float = 0.5
const KNOCKBACK: float = 8.0
const KNOCKBACK_LIFT: float = 3.0
const TIC: float = 0.1


func _init() -> void:
	id = &"superestrella"
	display_name = "Superestrella"
	description = "%.0fs invencible: nada te saca vida ni te frena, vas x%.2f más rápido, y el que tocás sale volando (%d)." % [
		DURACION, VELOCIDAD, int(DAMAGE)]
	stamina_cost = 100.0
	cooldown = 0.0
	channel_time = 0.5
	requires_charge = true
	icon_color = Color(1.0, 0.90, 0.25)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var estado := caster.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.estrella(DURACION)
		estado.impulsar(VELOCIDAD, 1.0, 1.0, DURACION)
	FX.spawn_estrella(caster3d, DURACION)
	FX.camera_shake(1.0)
	Sfx.play_3d(caster, &"estrella", origin, 2.0)
	_tocar(caster3d)


## El que se le acerca, sale volando. Corre mientras dura la estrella.
func _tocar(caster3d: Node3D) -> void:
	var tree := caster3d.get_tree()
	if tree == null:
		return
	var source_id: int = caster3d.get("peer_id")
	var ultimos: Dictionary = {}
	var t := 0.0
	while t < DURACION:
		await tree.create_timer(TIC).timeout
		t += TIC
		if Ability.interrumpida(caster3d):
			return
		var health := caster3d.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			return
		var centro := caster3d.global_position + Vector3.UP * 0.9
		for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO):
			var clave := target.get_instance_id()
			if t - float(ultimos.get(clave, -99.0)) < ENTRE_GOLPES:
				continue
			ultimos[clave] = t
			CombatUtils.deal_damage(target, DAMAGE, source_id, false)
			CombatUtils.apply_knockback(target, target.global_position - caster3d.global_position,
				KNOCKBACK, KNOCKBACK_LIFT)
			FX.spawn_impact_burst(caster3d, target.global_position + Vector3.UP,
				Color.from_hsv(fmod(t * 1.7, 1.0), 0.6, 1.0, 0.95))
