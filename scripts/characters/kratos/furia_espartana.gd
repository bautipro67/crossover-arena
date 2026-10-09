class_name FuriaEspartana
extends Ability
## Slot 3 de Kratos: "FURIA ESPARTANA". Su definitiva.
##
## Kratos deja salir lo que lleva adentro: un pisoton que tira a todos los que estan cerca,
## y por unos segundos pega mas fuerte, recibe menos, va mas rapido y nada lo frena. Como
## Super Sonic, pero mas corta y mas pesada: es un premio del pase y no puede ser lo mas
## fuerte del juego.

const DURACION: float = 7.0
const VELOCIDAD: float = 1.2
const RESISTE: float = 0.70
const DAÑO: float = 1.35
const RADIO_PISOTON: float = 4.0
const DAMAGE_PISOTON: float = 20.0


func _init() -> void:
	id = &"furia_espartana"
	display_name = "Furia Espartana"
	description = "Un pisotón que pega %d alrededor, y por %d s pega x%.2f, recibe el %d%% y nada lo frena." % [
		int(DAMAGE_PISOTON), int(DURACION), DAÑO, int(RESISTE * 100.0)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 0.8
	requires_charge = true
	icon_color = Color(0.95, 0.15, 0.10)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var estado := caster3d.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.impulsar(VELOCIDAD, RESISTE, DAÑO, DURACION)
		estado.imparable(DURACION)
	var centro := caster3d.global_position + Vector3.UP * 0.5
	Sfx.play_3d(caster3d, &"furia", centro, 2.0)
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO_PISOTON):
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(target, DAMAGE_PISOTON, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - centro, 9.0, 3.5)
	FX.spawn_furia_espartana(caster3d, DURACION)
	FX.spawn_pisoton(caster3d, caster3d.global_position, RADIO_PISOTON)
	FX.camera_shake(1.4)
