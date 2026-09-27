class_name Purpura
extends Ability
## Slot 3 de Gojo: "PÚRPURA" (Hollow Purple). Su definitiva.
##
## Junta el azul y el rojo, y lo que sale es una esfera violeta que BORRA todo lo que toca.
## Aca es una esfera enorme y lenta que atraviesa todo —rivales, coberturas, paredes— y le
## pega una vez a cada uno que toca en el camino.
##
## SE VE VENIR: la carga es larga, y la esfera es enorme y va despacio. Se esquiva
## saliendo de la linea, no escondiendose detras de algo.

const DAMAGE: float = 60.0
const RADIO: float = 1.8
const SPEED: float = 18.0
const LIFETIME: float = 2.2
const KNOCKBACK: float = 9.0
const KNOCKBACK_LIFT: float = 2.5


func _init() -> void:
	id = &"purpura"
	display_name = "Púrpura"
	description = "Junta el azul y el rojo: una esfera violeta enorme que atraviesa todo y hace %d de daño a cada uno que toca." % int(DAMAGE)
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.4
	requires_charge = true
	icon_color = Color(0.70, 0.30, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx() or not is_instance_valid(caster):
		return
	var mundo := caster.get_parent()
	if mundo == null:
		return
	var esfera := EsferaPurpura.new()
	esfera.dueño = caster
	esfera.rumbo = rumbo
	esfera.cosmetica = cosmetic
	mundo.add_child(esfera)
	esfera.global_position = origin + rumbo * 1.5
	FX.camera_shake(1.6)
	Sfx.play_3d(caster, &"psiquico", origin, 4.0)
