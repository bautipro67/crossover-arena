class_name ZaWarudo
extends Ability
## Slot 2 de Dio: "ZA WARUDO". El ultimate.
##
## Detiene el tiempo: todos los demas quedan clavados mientras Dio se mueve y pega libre.
## Y mientras estan detenidos se les van clavando cuchillos alrededor que NO impactan
## todavia: cuando el tiempo vuelve a correr, todos caen juntos de golpe.
##
## Es el momento mas reconocible del personaje y ademas resuelve un problema de diseño:
## un ultimate que solo aturde no se siente como un ultimate por mas util que sea. Asi
## el control y el daño son la misma cosa, y el daño llega cuando el rival recupera el
## control, que es cuando mas duele.
##
## COMO SE PAGA:
##   - 100 de stamina: te deja SECO. No hay combo con los cuchillos despues.
##   - medidor de ultimate al 100%, que se llena pegando (ver UltimateCharge).
## El cooldown es corto a proposito: lo que te frena es la carga, no un reloj.
##
## DECISIONES DE BALANCE QUE NO SE TOCAN:
##
## 1. Aturde, NO congela. Un aturdido no queda ejecutable por Snowgrave. Si fueran el
##    mismo estado, Dio + Noelle serian un combo de dos botones que mata desde vida llena.
##
## 2. Requiere LINEA DE VISION (por eso usa un cono de 360 grados y no una esfera pelada).
##    Detras de una cobertura estas a salvo. Sin esto seria un boton sin contrajuego.

const RADIUS: float = 20.0
const STOP_DURATION: float = 2.2
## Daño de la andanada, que impacta toda junta cuando se reanuda el tiempo.
const BURST_DAMAGE: float = 65.0
const BURST_KNOCKBACK: float = 12.0


func _init() -> void:
	id = &"za_warudo"
	display_name = "ZA WARUDO"
	description = "Detiene el tiempo 2.2s en 20m. Al reanudarse, la andanada de cuchillos impacta junta por 65. Necesita linea de vision."
	stamina_cost = 100.0
	requires_charge = true
	cooldown = 10.0
	channel_time = 0.9
	icon_color = Color(1.0, 0.78, 0.25)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	# Cono de 360 grados = esfera, pero pasando por el chequeo de linea de vision.
	var targets := CombatUtils.get_players_in_cone(caster as Node3D, origin, dir, RADIUS, 360.0)
	for target: Node3D in targets:
		var status := target.get_node_or_null("StatusEffects") as StatusEffects
		if status != null:
			status.stun_for(STOP_DURATION)

	FX.spawn_time_stop(caster, origin, RADIUS)
	_schedule_burst(caster, targets, origin)


## La andanada cae cuando se termina el tiempo detenido, no al tirarlo.
##
## Corre solo en el servidor (execute ya lo garantiza), asi que el daño no se duplica.
## Los clientes ven la parte visual por su cuenta: PlayerVisual clava los cuchillos al
## recibir el aturdimiento y los hace impactar al salir, que se sincroniza solo porque
## el estado de aturdimiento ya se replica.
func _schedule_burst(caster: Node, targets: Array[Node3D], origin: Vector3) -> void:
	if not is_instance_valid(caster):
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var source_id: int = caster.peer_id

	await tree.create_timer(STOP_DURATION).timeout
	if Cinematica.activa:
		return

	for target: Node3D in targets:
		if not is_instance_valid(target):
			continue
		var health := target.get_node_or_null("Health") as Health
		if health == null or health.is_dead:
			continue
		# El daño del ultimate NO paga recursos (ni medidor ni stamina): ver deal_damage.
		CombatUtils.deal_damage(target, BURST_DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - origin, BURST_KNOCKBACK, 3.0)
