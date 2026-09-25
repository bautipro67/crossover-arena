class_name SuperSonic
extends Ability
## Slot 3 de Sonic: "SUPER SONIC". Su definitiva.
##
## Dorado, mas rapido, pegando mas fuerte y aguantando mucho mas.
##
## LOS TRES EFECTOS Y EL LIMITE SALEN DE LA FICHA, no de un balanceo inventado: "todas sus
## habilidades superan ampliamente a las normales", "es casi invulnerable", y "esta
## transformacion consume mucha energia, asi que no se puede mantener por mucho tiempo".
## La duracion corta no es un recorte mio, es la regla del personaje.
##
## "CASI invulnerable" Y NO invulnerable, tambien por la ficha, y encima es lo unico que
## puede funcionar en un PvP: una definitiva que te vuelve intocable no se juega en contra,
## se espera a que termine. Recibiendo un tercio del daño, el rival todavia puede matarlo
## si se compromete — solo que le va a costar tres veces mas, que es lo que tiene que
## costarle pelear contra alguien que solto su ultimate.
##
## LO QUE NO ESTA: volar. Es canonico y no entra — el mapa se juega en el piso, y un
## personaje que se va para arriba cinco segundos no esta peleando, esta esperando arriba.

const DURACION: float = 8.0
## x1.55 de velocidad. Sonic ya es el mas rapido del juego; esto lo vuelve inalcanzable.
const VELOCIDAD: float = 1.55
## Recibe el 35% del daño. Es el "casi" de "casi invulnerable".
const RESISTENCIA: float = 0.45
## Y reparte un 45% mas.
const POTENCIA: float = 1.35
## Radio del estallido dorado al transformarse.
const RADIO_ESTALLIDO: float = 6.0
const DAÑO_ESTALLIDO: float = 18.0


func _init() -> void:
	id = &"super_sonic"
	display_name = "Super Sonic"
	description = "%.0fs dorado: x%.2f de velocidad, %d%% más de daño y recibís solo el %d%%." % [
		DURACION, VELOCIDAD, int((POTENCIA - 1.0) * 100.0), int(RESISTENCIA * 100.0)]
	stamina_cost = 100.0
	cooldown = 0.0
	channel_time = 0.6
	requires_charge = true
	icon_color = Color(1.0, 0.88, 0.25)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var estado := caster.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.impulsar(VELOCIDAD, RESISTENCIA, POTENCIA, DURACION)

	# El estallido al transformarse: despeja a los que estaban encima. Sin el, soltar la
	# definitiva estando acorralado te deja igual de acorralado pero dorado.
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, origin, RADIO_ESTALLIDO):
		CombatUtils.deal_damage(target, DAÑO_ESTALLIDO, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, 11.0, 3.2)

	FX.spawn_super_sonic(caster3d, DURACION)
	FX.camera_shake(1.6)
	Sfx.play_3d(caster, &"channel", origin, 2.0)
