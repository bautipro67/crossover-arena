class_name FloweryDash
extends RefCounted
## Una pasada de embestida de Flowery. La usan sus tres habilidades.
##
## EN EL ORIGINAL, las tres cosas que hace Flowery en su pelea son embestidas:
##   - JARONA      -> grita, destella en blanco y se tira. Es "clashable": le pegas y
##                    lo mandas para atras, y vuelve a venir.
##   - HERE I COME -> la embestida contra el Roaring Knight.
##   - LAST JARONA -> la fase final: SIETE embestidas seguidas.
##
## Todas comparten el mismo esqueleto —lanzarse, revisar a quien atropella, frenar— y
## se diferencian en lo que pasa DESPUES de conectar. Por eso vive aca y no copiado
## tres veces.

## Cada cuanto revisa a quien atropello. A 30 m/s, 20 veces por segundo alcanza para no
## pasar de largo a nadie.
const TICK: float = 0.05


## Corre UNA pasada y devuelve TODO lo que atropello.
##
## `ya_golpeados` se pasa entre pasadas para que un mismo rival no coma dos veces el
## mismo golpe en la misma embestida; pasar un diccionario nuevo lo deja recibir de
## nuevo (que es lo que quiere el rebote de Jarona: cada ida es un golpe nuevo).
## `frenar_al_tocar` corta la embestida en el instante del contacto.
##
## HACE FALTA para Here I Come: sin eso la embestida sigue de largo los 11 metros
## enteros y termina CINCO METROS PASADO el rival, asi que la cadena de golpes que
## viene despues no alcanza a nadie y se corta en el primer tick. Jarona, en cambio,
## atraviesa a proposito: es un embiste, no un agarre.
static func pasada(caster: Node3D, dir: Vector3, speed: float, duration: float,
		radius: float, ya_golpeados: Dictionary, frenar_al_tocar: bool = false,
		estela: Color = Color(0, 0, 0, 0)) -> Array[Node3D]:
	var tocados: Array[Node3D] = []
	if not is_instance_valid(caster):
		return tocados
	var tree := caster.get_tree()
	if tree == null:
		return tocados

	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = -caster.global_transform.basis.z

	caster.call("launch_charge", plano, speed, duration)

	var pasos := maxi(1, int(duration / TICK))
	for i: int in range(pasos):
		# La estela va ANTES de esperar, asi la primera marca cae en el arranque y no
		# recien a los 50 ms, cuando el cuerpo ya se movio metro y medio. Y va en TODOS
		# los tics: dejando una cada dos, a 30 m/s quedaban separadas y se veian como
		# marcas sueltas en vez de un rastro.
		if estela.a > 0.0:
			FX.spawn_dash_streak(caster, caster.global_position, plano, estela)
		await tree.create_timer(TICK).timeout
		if Ability.interrumpida(caster):
			return tocados
		var health := caster.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			return tocados
		# Congelado o con el tiempo detenido encima, la embestida se corta.
		var status := caster.get_node_or_null("StatusEffects") as StatusEffects
		if status != null and not status.can_act():
			return tocados

		for target: Node3D in CombatUtils.get_players_in_sphere(caster, caster.global_position, radius):
			var key := target.get_instance_id()
			if ya_golpeados.has(key):
				continue
			ya_golpeados[key] = true
			tocados.append(target)

		if frenar_al_tocar and not tocados.is_empty():
			frenar(caster)
			return tocados

	return tocados


## Frena la embestida en seco. Para el rebote: si el impulso siguiera, el rebote
## arrancaria peleando contra la inercia de la ida.
static func frenar(caster: Node3D) -> void:
	if not is_instance_valid(caster):
		return
	caster.call("stop_charge")
