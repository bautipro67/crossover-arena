class_name Desmantelar
extends Ability
## Slot 1 de Sukuna: "DESMANTELAR" (Kai).
##
## Su tecnica de siempre: cortes invisibles que salen volando y rebanan lo que encuentran.
## Aca son tres medialunas finas en abanico cerrado que cruzan a la gente —le pegan una
## vez a cada uno— y se cortan contra la primera pared.

const DAMAGE: float = 9.0
const CORTES: int = 3
const ABANICO: float = 9.0
const SPEED: float = 34.0
const ALCANCE: float = 20.0
const RADIO: float = 0.9


func _init() -> void:
	id = &"desmantelar"
	display_name = "Desmantelar"
	description = "Tres cortes que vuelan %d m en abanico y atraviesan a la gente: %d de daño cada uno." % [
		int(ALCANCE), int(DAMAGE)]
	stamina_cost = 22.0
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(0.85, 0.85, 0.92)


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
	for k: int in range(CORTES):
		var giro := deg_to_rad(ABANICO) * (float(k) - float(CORTES - 1) * 0.5)
		var corte := CorteVolador.new()
		corte.dueño = caster
		corte.rumbo = rumbo.rotated(Vector3.UP, giro)
		corte.cosmetica = cosmetic
		# Cada uno inclinado distinto: tres rayas iguales se leen como una sola.
		corte.inclinacion = [-0.5, 0.35, -0.15][k % 3]
		mundo.add_child(corte)
		corte.global_position = origin + corte.rumbo * 0.9
	if caster is Node3D:
		Sfx.play_3d(caster, &"corte", (caster as Node3D).global_position + Vector3.UP, -1.0)
