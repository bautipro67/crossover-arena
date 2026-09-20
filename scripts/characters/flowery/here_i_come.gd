class_name HereICome
extends Ability
## Slot 2 de Flowery: "Here I Come, San Francisco".
##
## El momento en que se tira contra el Roaring Knight: una carga de frente contra algo
## mucho mas grande que ella.
##
## LO QUE TIENE QUE TRANSMITIR ES EL COMPROMISO, no el daño. Por eso:
##
##   - una vez que arranca NO SE PUEDE FRENAR. Ignora tu input mientras dura, igual que
##     un dash, asi que apuntas antes y despues te aguantas donde caiste;
##   - te deja EXPUESTA al final: durante un segundo recibis 30% mas de daño. Tirarte de
##     cabeza tiene que costar algo, si no es solo un dash con daño;
##   - pega a todo lo que atropella en el camino, una vez por objetivo.
##
## Mecanicamente es el unico desplazamiento largo del juego que ademas hace daño, y es
## lo que le permite a Flowery entrar y salir: dispara petalos de lejos, carga cuando
## quiere presionar, y usa Jarona para sacarse de encima al que la alcanzo.

const DAMAGE: float = 26.0
const SPEED: float = 26.0
const DURATION: float = 0.5
## Radio del atropello. Generoso: si pidiera precision, una carga a 26 m/s seria
## imposible de acertar.
const HIT_RADIUS: float = 2.3
const KNOCKBACK: float = 6.5
const KNOCKBACK_LIFT: float = 1.6
## Cada cuanto revisa a quien atropello. Diez veces en medio segundo: suficiente para
## no pasar de largo a nadie a 26 m/s.
const TICK: float = 0.05
## Cuanto dura la exposicion al terminar, y cuanto daño extra recibe.
const VULNERABLE_TIME: float = 1.0
const VULNERABLE_MULT: float = 1.3


func _init() -> void:
	id = &"here_i_come"
	display_name = "Here I Come, San Francisco"
	description = "Carga %.0fm de frente, %d de daño a lo que atropelles. No se puede frenar y quedas expuesta %.0fs." % [
		SPEED * DURATION, int(DAMAGE), VULNERABLE_TIME]
	stamina_cost = 30.0
	cooldown = 8.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.58, 0.30)


## CORRE EN EL SERVIDOR. Es una corrutina: acompaña la carga mientras dura.
func execute(caster: Node, _origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster.peer_id
	var tree := caster.get_tree()
	if tree == null:
		return

	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = -caster3d.global_transform.basis.z

	caster.call("launch_charge", plano, SPEED, DURATION)
	FX.spawn_charge_burst(caster, caster3d.global_position, plano)

	# Una vez por objetivo: sin esto, un rival que queda pegado al camino comeria diez
	# ticks de 26 y la habilidad haria 260 de daño.
	var ya_golpeados: Dictionary = {}
	var pasos := int(DURATION / TICK)
	for i: int in range(pasos):
		await tree.create_timer(TICK).timeout
		if not is_instance_valid(caster3d):
			return
		var health := caster.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			return

		var aqui := caster3d.global_position
		for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, aqui, HIT_RADIUS):
			var key := target.get_instance_id()
			if ya_golpeados.has(key):
				continue
			ya_golpeados[key] = true
			CombatUtils.deal_damage(target, DAMAGE, source_id)
			CombatUtils.apply_knockback(target, target.global_position - aqui, KNOCKBACK, KNOCKBACK_LIFT)
			FX.spawn_hit_impact(caster, target.global_position + Vector3.UP, DAMAGE,
				Color(1.0, 0.6, 0.3))

	# Y el precio: al frenar queda abierta.
	if not is_instance_valid(caster3d):
		return
	var status := caster.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		status.apply_vulnerable(VULNERABLE_MULT, VULNERABLE_TIME)
	FX.spawn_charge_landing(caster, caster3d.global_position)
