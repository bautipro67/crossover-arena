class_name Snowgrave
extends Ability
## Slot 2 de Noelle: "Snowgrave". El ultimate.
##
## En la ruta Weird de Deltarune, Snowgrave no es un hechizo de daño cualquiera: es lo
## que remata a los enemigos ya congelados. Aca funciona igual y por eso es buen PvP:
##
##   - Contra alguien NO congelado hace 40 y lo congela 2s. Molesto, no letal.
##   - Contra alguien CONGELADO hace 200. Ejecucion.
##
## O sea que el ultimate solo, sin setup, no gana peleas. Tenes que apilar 5 de escarcha
## primero (Ice Shock / Icicle Strike), y recien ahi rematar.
##
## El canalizado de 1.5s te deja clavado en el piso y es visible desde lejos: el rival
## tiene tiempo de romper la linea de vision detras de una cobertura o salir del cono.
## Si te congelan a vos durante el canalizado, se cancela y recuperas media stamina.
##
## COMO SE PAGA:
##   - 100 de stamina: te deja SECA. Despues de tirarlo no te queda ni para un Ice Shock.
##   - medidor de ultimate al 100%, que se llena pegando (ver UltimateCharge).
## O sea que el combo completo es: pelear para cargar, apilar escarcha hasta congelar,
## y recien ahi rematar. Tres pasos, no un boton.

const DAMAGE_NORMAL: float = 65.0
const DAMAGE_FROZEN: float = 260.0
const CONE_RANGE: float = 20.0
const CONE_ANGLE: float = 60.0
const FREEZE_ON_HIT: float = 2.0
const KNOCKBACK: float = 8.0
## La ejecucion tiene que sentirse distinta tambien en el cuerpo, no solo en el numero.
const KNOCKBACK_EXECUTE: float = 13.0


func _init() -> void:
	id = &"snowgrave"
	display_name = "Snowgrave"
	description = "Canaliza 1.5s y barre un cono de 20m. 65 de daño normal, 260 si el rival esta congelado."
	stamina_cost = 100.0
	requires_charge = true
	# Cooldown corto a proposito: lo que te frena es la carga, no un reloj.
	cooldown = 10.0
	channel_time = 1.5
	icon_color = Color(0.85, 0.95, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	var targets := CombatUtils.get_players_in_cone(caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE)

	for target: Node3D in targets:
		var push := target.global_position - origin
		if CombatUtils.is_frozen(target):
			# Ejecucion. Esto es Snowgrave haciendo lo que hace en Deltarune.
			# El daño del ultimate NO carga el medidor: ver deal_damage.
			CombatUtils.deal_damage(target, DAMAGE_FROZEN, source_id, false)
			CombatUtils.apply_knockback(target, push, KNOCKBACK_EXECUTE, 3.5)
		else:
			CombatUtils.deal_damage(target, DAMAGE_NORMAL, source_id, false)
			CombatUtils.apply_knockback(target, push, KNOCKBACK, 2.0)
			var status := target.get_node_or_null("StatusEffects") as StatusEffects
			if status != null:
				status.freeze_for(FREEZE_ON_HIT)

	FX.spawn_snowgrave(caster, origin, dir, CONE_RANGE, CONE_ANGLE)
	FX.spawn_ice_spikes(caster, origin, dir, CONE_RANGE, CONE_ANGLE)
