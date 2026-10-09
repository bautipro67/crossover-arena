class_name HinokamiKagura
extends Ability
## Slot 3 de Tanjiro: "DANZA DEL DIOS DEL FUEGO" (Hinokami Kagura). Su definitiva.
##
## La danza que bailaba su padre, hecha tecnica: cambia el agua por fuego. Aca son cuatro
## embestidas encadenadas, cada una al enemigo mas cercano —puede ser el mismo—, y al final
## la Rueda Solar, un remolino de fuego alrededor.
##
## SE VE VENIR: la carga es corta pero a la vista (la katana se prende), y cada embestida
## va a donde esta el enemigo AL SALIR: moverse de costado hace que la siguiente pase de
## largo.

const SALTOS: int = 4
const ALCANCE: float = 14.0
const SPEED: float = 32.0
const DAMAGE: float = 12.0
const RADIO_GOLPE: float = 2.4
const DAMAGE_FINAL: float = 14.0
const RADIO_FINAL: float = 3.6
const ESTELA := Color(1.0, 0.45, 0.10, 0.6)


func _init() -> void:
	id = &"hinokami"
	display_name = "Danza del Dios del Fuego"
	description = "Cuatro embestidas de fuego, cada una al enemigo más cercano (%d cada una), y la Rueda Solar al final (%d alrededor)." % [
		int(DAMAGE), int(DAMAGE_FINAL)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 0.9
	requires_charge = true
	icon_color = Color(1.0, 0.45, 0.12)


func execute(caster: Node, _origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	var tree := caster.get_tree()
	if caster3d == null or tree == null:
		return
	var source_id: int = caster3d.peer_id
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	for k: int in range(SALTOS):
		if Ability.interrumpida(caster3d):
			return
		var blanco := _mas_cercano(caster3d)
		var hacia := rumbo * 6.0
		if blanco != null:
			hacia = blanco.global_position - caster3d.global_position
			hacia.y = 0.0
		if hacia.length() < 0.5:
			hacia = rumbo * 2.0
		var dura := clampf(hacia.length() / SPEED, 0.08, 0.40)
		FX.spawn_estela_fuego(caster3d, caster3d.global_position, hacia.normalized(), hacia.length())
		caster3d.call("launch_charge", hacia.normalized(), SPEED, dura)
		await tree.create_timer(dura).timeout
		if Ability.interrumpida(caster3d):
			return
		var aqui := caster3d.global_position + Vector3.UP
		for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, aqui, RADIO_GOLPE):
			# El daño del ultimate no paga recursos: ver deal_damage.
			CombatUtils.deal_damage(target, DAMAGE, source_id, false)
			CombatUtils.apply_knockback(target, target.global_position - aqui, 3.0, 1.5)
			FX.spawn_impact_burst(caster3d, target.global_position + Vector3.UP, Color(1.0, 0.60, 0.20, 1.0))
		await tree.create_timer(0.08).timeout
	if Ability.interrumpida(caster3d):
		return
	var centro := caster3d.global_position + Vector3.UP
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO_FINAL):
		CombatUtils.deal_damage(target, DAMAGE_FINAL, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - centro, 9.0, 3.0)
	FX.spawn_rueda_solar(caster3d, RADIO_FINAL)


static func _mas_cercano(caster: Node3D) -> Node3D:
	var mejor: Node3D = null
	var dist := ALCANCE
	for t: Node3D in CombatUtils._living_targets(caster):
		var d := t.global_position.distance_to(caster.global_position)
		if d < dist:
			dist = d
			mejor = t
	return mejor
