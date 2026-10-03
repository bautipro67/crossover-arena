class_name SantuarioMalevolo
extends Ability
## Slot 3 de Sukuna: "EXPANSION DE DOMINIO: SANTUARIO MALEVOLO". Su definitiva.
##
## Junta las manos en el sello de Enma y detras de el sube su santuario: un templo de
## huesos con bocas. Al soltar, el dominio se abre alrededor y TODO lo que quedo adentro
## recibe cortes sin parar mientras dura. En la serie es un golpe que no se puede errar;
## aca tampoco hace falta apuntar.
##
## LA CONTRA ES IRSE. El dominio queda clavado donde se abrio (no lo sigue a Sukuna) y
## dura poco: el que estaba cerca del borde sale corriendo y come dos o tres cortes, el
## que estaba encima de Sukuna se los come todos. Y la carga es larga y a la vista: el
## templo subiendo se ve desde toda la arena.

const RADIO: float = 12.0
const DURACION: float = 3.2
## El corte de entrada, al abrirse.
const DAMAGE_INICIAL: float = 12.0
const DAMAGE_CORTE: float = 3.9
const CADA: float = 0.32


func _init() -> void:
	id = &"santuario"
	display_name = "Santuario Malévolo"
	description = "Expansión de dominio: durante %.1f s, todo lo que esté a %d m del santuario recibe cortes sin parar (%d al abrirse y %.1f cada %.2f s)." % [
		DURACION, int(RADIO), int(DAMAGE_INICIAL), DAMAGE_CORTE, CADA]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.5
	requires_charge = true
	icon_color = Color(0.85, 0.08, 0.12)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	abrir(caster, false)


static func spawn_cosmetic(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	abrir(caster, true)


static func abrir(caster: Node, cosmetic: bool) -> void:
	if not (caster is Node3D) or not is_instance_valid(caster):
		return
	var mundo := caster.get_parent()
	if mundo == null or (Cinematica.activa and not cosmetic):
		return
	var cuerpo := caster as Node3D
	var dominio := DominioSukuna.new()
	dominio.dueño = caster
	dominio.cosmetica = cosmetic
	dominio.frente = -cuerpo.global_transform.basis.z
	mundo.add_child(dominio)
	dominio.global_position = Vector3(cuerpo.global_position.x, 0.0, cuerpo.global_position.z)
