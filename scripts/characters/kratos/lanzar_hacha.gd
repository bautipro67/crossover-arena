class_name LanzarHacha
extends Ability
## Slot 1 de Kratos: "LANZAR EL HACHA".
##
## Lo que hace a Kratos el de Midgard: tira el Hacha Leviatan girando, le pega a todos los
## que cruza y la llama de vuelta a la mano. LA VUELTA TAMBIEN PEGA: el que esquivo la ida
## tiene que fijarse por donde vuelve.

const DAMAGE_IDA: float = 13.0
const DAMAGE_VUELTA: float = 9.0
const SPEED_IDA: float = 30.0
const SPEED_VUELTA: float = 34.0
const ALCANCE: float = 17.0
const RADIO: float = 1.1
const LENTO: float = 0.35
const LENTO_DURA: float = 1.5


func _init() -> void:
	id = &"lanzar_hacha"
	display_name = "Lanzar el Hacha"
	description = "Tira el hacha hasta %d m y la llama de vuelta: %d a la ida y %d a la vuelta, y deja lento." % [
		int(ALCANCE), int(DAMAGE_IDA), int(DAMAGE_VUELTA)]
	stamina_cost = 24.0
	cooldown = 7.0
	channel_time = 0.0
	icon_color = Color(0.60, 0.85, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	tirar(caster, origin, dir, true)


static func tirar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx() or not is_instance_valid(caster):
		return
	var mundo := caster.get_parent()
	if mundo == null or (Cinematica.activa and not cosmetic):
		return
	var hacha := HachaVoladora.new()
	hacha.dueño = caster
	hacha.rumbo = rumbo
	hacha.cosmetica = cosmetic
	mundo.add_child(hacha)
	hacha.global_position = origin + rumbo * 0.9
	if caster is Node3D:
		Sfx.play_3d(caster, &"hacha", (caster as Node3D).global_position + Vector3.UP, 0.0)
