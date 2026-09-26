class_name Chasquido
extends Ability
## Slot 3 de Thanos: "EL CHASQUIDO". Su definitiva.
##
## Con las seis gemas en el Guantelete, Thanos chasquea los dedos y la mitad de todo lo que
## vive desaparece. Aca es eso, como se pidio: TODOS LOS ENEMIGOS PIERDEN LA MITAD DE LA
## VIDA QUE TIENEN, esten donde esten del mapa. La mitad de lo que les queda, no de la vida
## entera: por eso no mata nunca, y por eso rinde mas cuanto antes se usa.
##
## INEVITABLE: no lo frena un escudo (ver Health.apply_damage, ignora_escudo) ni una pared.
## Lo unico que se salva es lo invencible —Mario con la Superestrella—, que es invencible.
##
## SE VE VENIR: el canalizado es largo, con el Guantelete en alto y las gemas encendidas.
## No se puede esquivar, pero se puede cortar: congelarlo o aturdirlo lo cancela.
##
## No paga recursos: no recarga el medidor ni devuelve stamina.

const FRACCION: float = 0.5


func _init() -> void:
	id = &"chasquido"
	display_name = "El Chasquido"
	description = "Chasquea los dedos con las seis gemas: TODOS los enemigos pierden la mitad de la vida que les queda. No lo frenan ni los escudos ni las paredes."
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.5
	requires_charge = true
	icon_color = Color(0.95, 0.80, 0.30)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null or Cinematica.activa:
		return
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils._living_targets(caster3d):
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null and estado.es_invencible():
			continue
		var health := target.get_node_or_null("Health") as Health
		if health == null or health.is_dead:
			continue
		health.apply_damage(health.current * FRACCION, source_id, true)
	FX.spawn_chasquido(caster3d)
