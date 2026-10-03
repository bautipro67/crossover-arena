class_name DominioSukuna
extends Node3D
## El Santuario Malevolo abierto: el templo detras de Sukuna, un circulo rojo en el piso
## que marca hasta donde llega, y cortes que aparecen y desaparecen por todo el area.
##
## El daño es del servidor (cosmetica = false): cada CADA segundos, un corte a cada rival
## que este adentro del circulo. La copia de los clientes solo se ve, y es la misma: el
## circulo que ven es exactamente hasta donde pega.

var dueño: Node = null
var cosmetica: bool = false
var frente: Vector3 = Vector3.FORWARD
var _vida: float = SantuarioMalevolo.DURACION
var _proximo: float = SantuarioMalevolo.CADA
var _primero: bool = true
## El aviso a los bots (BotBrain.peligros): que salgan del circulo, como saldria una persona.
var _peligro: Dictionary = {}


func _ready() -> void:
	# Diferido: el que lo crea lo ubica DESPUES de meterlo al arbol (antes no hay posicion
	# global), y el templo y el circulo se arman donde quedo.
	_armar_fx.call_deferred()


func _exit_tree() -> void:
	if not _peligro.is_empty():
		BotBrain.peligros.erase(_peligro)


func _armar_fx() -> void:
	if not cosmetica:
		_peligro = {"punto": global_position, "radio": SantuarioMalevolo.RADIO, "reaccion": 0.35, "dueño": dueño}
		BotBrain.peligros.append(_peligro)
	var rumbo := Vector3(frente.x, 0.0, frente.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = Vector3.FORWARD
	FX.spawn_dominio_sukuna(self, rumbo, SantuarioMalevolo.RADIO, SantuarioMalevolo.DURACION)
	FX.camera_shake(1.2)


func _physics_process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	_proximo -= delta
	if _proximo > 0.0 and not _primero:
		return
	_proximo = SantuarioMalevolo.CADA
	var dano := SantuarioMalevolo.DAMAGE_INICIAL if _primero else SantuarioMalevolo.DAMAGE_CORTE
	_primero = false
	for t: Node3D in adentro():
		FX.spawn_cortes(self, t.global_position + Vector3.UP * randf_range(0.6, 1.6), 2)
		if cosmetica:
			continue
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(t, dano, dueño.get("peer_id"), false)
	# Cortes sueltos por el area aunque no haya nadie: el dominio se ve vivo.
	for k: int in range(3):
		var a := randf() * TAU
		var r := sqrt(randf()) * SantuarioMalevolo.RADIO
		FX.spawn_cortes(self, global_position + Vector3(cos(a) * r, randf_range(0.4, 2.2), sin(a) * r), 1)


## Los rivales vivos dentro del circulo. Cuenta en el piso, sin la altura: un salto no
## te saca del dominio.
func adentro() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_instance_valid(dueño):
		return out
	for t: Node3D in CombatUtils._living_targets(dueño):
		var d := Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z)
		if d.length() <= SantuarioMalevolo.RADIO:
			out.append(t)
	return out
