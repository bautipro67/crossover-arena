class_name IceDefense
extends Ability
## Slot 2 de Noelle: "Defensa de Hielo".
##
## En Deltarune Noelle es la que cura y protege, no una artillera. Sus otras dos
## habilidades la empujan a pelear de lejos apilando escarcha; esta es la que le deja
## sobrevivir cuando alguien le cierra la distancia, que es exactamente como se la mata.
##
## No cura: levanta un escudo que se come el daño. La diferencia importa. Una curacion
## premia esconderse a esperar; un escudo con tiempo limitado premia usarlo JUSTO cuando
## te entran, y si lo tiras antes te encuentra sin nada.
##
## Ademas suelta una rafaga de frio que pega escarcha alrededor. Eso es lo que la hace
## una herramienta y no un boton de "no me pegues": el que te acorrala termina un stack
## mas cerca de congelarse, o sea mas cerca de comerse un Snowgrave.

## Cuanto daño se come el escudo antes de romperse.
const SHIELD_AMOUNT: float = 55.0
## Cuanto dura si no se lo rompen antes.
const DURATION: float = 5.0
## Radio de la rafaga de frio al levantarlo.
const CHILL_RADIUS: float = 4.5
const CHILL_STACKS: int = 1


func _init() -> void:
	id = &"ice_defense"
	display_name = "Defensa de Hielo"
	description = "Escudo de %d por %.0fs. Al levantarlo, +%d de escarcha a todo el que tengas cerca." % [
		int(SHIELD_AMOUNT), DURATION, CHILL_STACKS]
	stamina_cost = 30.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.58, 0.86, 1.0)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var health := caster.get_node_or_null("Health") as Health
	if health != null:
		health.add_shield(SHIELD_AMOUNT, DURATION)

	# La rafaga de frio es una esfera y no un cono: sirve para sacarte de encima al que
	# ya te rodeo, asi que castigar la punteria seria castigar justo la situacion para
	# la que existe la habilidad.
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster as Node3D, origin, CHILL_RADIUS):
		CombatUtils.apply_chill(target, CHILL_STACKS)
		FX.spawn_ice_impact(caster, target.global_position + Vector3.UP)
	# Sin daño a proposito: si pegara, seria una habilidad defensiva que ademas carga el
	# ultimate por defenderse, y Noelle no necesita otra via de llegar a Snowgrave.
	var _unused := source_id

	if caster is Node3D:
		FX.spawn_ice_barrier(caster as Node3D, DURATION)
