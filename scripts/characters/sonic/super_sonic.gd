class_name SuperSonic
extends Ability
## Slot 3 de Sonic: "SUPER SONIC". Su definitiva.
##
## Dorado, mas rapido, pegando mas fuerte y aguantando mucho mas.
##
## Y DESDE EL 2026-10-01, ADEMAS, LO QUE ES SOLO SUYO: se pidio que las definitivas
## genericas fueran distintas, y esta era la misma transformacion que el Gear Fifth y el
## 100%. Ahora apenas se transforma sale a la velocidad de la luz contra cada enemigo a
## tiro (el Light Speed Attack de Sonic Adventure), y mientras dura nada lo congela, lo
## aturde ni lo frena. Lo de la ficha (pega mas, casi invulnerable, dura poco) queda.
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
## Recibe el 45% del daño. Es el "casi" de "casi invulnerable".
const RESISTENCIA: float = 0.45
## Y reparte un 35% mas.
const POTENCIA: float = 1.35
## Radio del estallido dorado al transformarse.
const RADIO_ESTALLIDO: float = 6.0
const DAÑO_ESTALLIDO: float = 18.0
## EL ATAQUE A LA VELOCIDAD DE LA LUZ (Light Speed Attack, de Sonic Adventure): apenas se
## transforma sale disparado contra cada enemigo que tenga a tiro, uno detras de otro.
const LUZ_ALCANCE: float = 22.0
const LUZ_BLANCOS: int = 5
const LUZ_DAÑO: float = 16.0
const LUZ_VELOCIDAD: float = 62.0
## Lo que tarda como mucho en llegar a cada uno: si se le escapa, sigue con el siguiente.
const LUZ_TOPE: float = 0.45


func _init() -> void:
	id = &"super_sonic"
	display_name = "Super Sonic"
	description = "Se transforma y sale a la velocidad de la luz contra hasta %d enemigos a %d m, uno tras otro (%d a cada uno). Después, %.0f s dorado: x%.2f de velocidad, %d%% más de daño, recibe el %d%%, y nada lo congela, lo aturde ni lo frena." % [
		LUZ_BLANCOS, int(LUZ_ALCANCE), int(LUZ_DAÑO), DURACION, VELOCIDAD,
		int((POTENCIA - 1.0) * 100.0), int(RESISTENCIA * 100.0)]
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
		# Y NADA LO PARA: es lo que lo separa de la Superestrella de Mario, a la que no se
		# puede tocar. A Super Sonic se le puede pegar, pero no frenarlo.
		estado.imparable(DURACION)

	# El estallido al transformarse: despeja a los que estaban encima. Sin el, soltar la
	# definitiva estando acorralado te deja igual de acorralado pero dorado.
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, origin, RADIO_ESTALLIDO):
		CombatUtils.deal_damage(target, DAÑO_ESTALLIDO, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - origin, 11.0, 3.2)

	FX.spawn_super_sonic(caster3d, DURACION)
	FX.camera_shake(1.6)
	Sfx.play_3d(caster, &"super_sonic", origin, 2.0)
	await _velocidad_de_la_luz(caster3d)


## Uno por uno, del mas cercano al mas lejano: llega, le pega y sigue. Cada uno una vez.
func _velocidad_de_la_luz(caster3d: Node3D) -> void:
	var tree := caster3d.get_tree()
	if tree == null:
		return
	var source_id: int = caster3d.get("peer_id")
	var blancos: Array = CombatUtils.get_players_in_sphere(caster3d, caster3d.global_position, LUZ_ALCANCE)
	blancos = blancos.filter(func(t: Node3D) -> bool:
		return CombatUtils.has_line_of_sight(caster3d, caster3d.get_aim_origin(), t))
	blancos.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return caster3d.global_position.distance_to(a.global_position) \
			< caster3d.global_position.distance_to(b.global_position))
	var golpeados := 0
	for blanco: Node3D in blancos:
		if golpeados >= LUZ_BLANCOS:
			break
		var t := 0.0
		while t < LUZ_TOPE:
			await tree.physics_frame
			t += 1.0 / 60.0
			if Ability.interrumpida(caster3d) or not is_instance_valid(blanco):
				return
			var vida := blanco.get_node_or_null("Health") as Health
			if vida == null or vida.is_dead:
				break
			var hacia: Vector3 = blanco.global_position - caster3d.global_position
			if hacia.length() <= 1.6:
				break
			caster3d.call("launch_charge", hacia.normalized(), LUZ_VELOCIDAD, 0.06)
			FX.spawn_dash_streak(caster3d, caster3d.global_position, hacia.normalized(),
				Color(1.0, 0.86, 0.30, 0.7))
		if not is_instance_valid(blanco) or caster3d.global_position.distance_to(blanco.global_position) > 2.6:
			continue
		var empuje: Vector3 = blanco.global_position - caster3d.global_position
		CombatUtils.deal_damage(blanco, LUZ_DAÑO, source_id, false)
		CombatUtils.apply_knockback(blanco, empuje, 7.0, 3.0)
		FX.spawn_impact_burst(caster3d, blanco.global_position + Vector3.UP, Color(1.0, 0.90, 0.35))
		Sfx.play_3d(caster3d, &"luz_sonic", blanco.global_position, 0.0)
		golpeados += 1
