extends Node
## Autoload: Modos
## Que se juega cuando se juega solo.
##
## Antes habia una sola cosa offline —la sala de practica— y esa sala esta pensada para
## PROBAR, no para jugar: los bots reaparecen solos, no se pierde nada al morir y no
## termina nunca. Es util y no es una partida.
##
## Estos tres modos si lo son: tienen una condicion de fin, se pueden perder, y por eso
## pagan monedas y experiencia. La practica no paga, y esa es toda la diferencia que
## necesita el sistema de recompensas para no ser una maquina de monedas gratis.

signal estado_cambio()
## gano, titulo, detalle
signal termino(gano: bool, titulo: String, detalle: String)

const PRACTICA: StringName = &"practica"
const SUPERVIVENCIA: StringName = &"supervivencia"
const CONTRARRELOJ: StringName = &"contrarreloj"
const ULTIMO_EN_PIE: StringName = &"ultimo_en_pie"
const ONLINE: StringName = &"online"

## Cuantas bajas pide contrarreloj.
const META_CONTRARRELOJ: int = 20
## Cuantos bots hay a la vez en contrarreloj.
const BOTS_CONTRARRELOJ: int = 3
## Con cuantos empieza supervivencia y cuantos puede haber a la vez como maximo.
const OLEADA_INICIAL: int = 2
const TOPE_SIMULTANEOS: int = 6
const BOTS_ULTIMO_EN_PIE: int = 5

var actual: StringName = ONLINE
var activo: bool = false
var bajas: int = 0
var oleada: int = 0
var tiempo: float = 0.0
var _terminado: bool = false


func _process(delta: float) -> void:
	if activo and not _terminado:
		tiempo += delta


# ------------------------------------------------------------------ Consultas

func es_offline() -> bool:
	return actual != ONLINE


## La practica es el unico que no paga. Todo lo demas si, incluido el online.
##
## Es la regla que sostiene la economia entera: si la sala donde hay cinco maniquies
## invencibles que reaparecen solos pagara monedas, nadie jugaria ningun otro modo, y las
## monedas dejarian de significar algo.
func da_recompensas() -> bool:
	return actual != PRACTICA


func nombre() -> String:
	match actual:
		PRACTICA: return "Sala de práctica"
		SUPERVIVENCIA: return "Supervivencia"
		CONTRARRELOJ: return "Contrarreloj"
		ULTIMO_EN_PIE: return "Último en pie"
	return "En línea"


func descripcion() -> String:
	match actual:
		PRACTICA:
			return "Bots que reaparecen, ajustes en caliente, nada que perder. No da recompensas."
		SUPERVIVENCIA:
			return "Oleadas que crecen. No reapareces: una muerte y se terminó."
		CONTRARRELOJ:
			return "%d bajas lo más rápido posible. Reapareces, pero el reloj no para." % META_CONTRARRELOJ
		ULTIMO_EN_PIE:
			return "%d contra uno. Nadie reaparece, ni ellos ni vos." % BOTS_ULTIMO_EN_PIE
	return "Contra otros jugadores."


## Cuantos bots pone la arena al empezar.
func bots_iniciales() -> int:
	match actual:
		PRACTICA: return Practica.bots
		SUPERVIVENCIA: return OLEADA_INICIAL
		CONTRARRELOJ: return BOTS_CONTRARRELOJ
		ULTIMO_EN_PIE: return BOTS_ULTIMO_EN_PIE
	return 0


## Vuelve el bot despues de morir?
func reaparecen_bots() -> bool:
	return actual == PRACTICA or actual == CONTRARRELOJ


## Vuelve el jugador despues de morir?
##
## En supervivencia y en ultimo en pie, no: son modos que se pueden PERDER, y un modo que
## no se puede perder no se puede ganar tampoco.
func reaparece_jugador() -> bool:
	return actual != SUPERVIVENCIA and actual != ULTIMO_EN_PIE


# --------------------------------------------------------------------- Partida

func iniciar(modo: StringName) -> void:
	actual = modo
	activo = es_offline() and modo != PRACTICA
	bajas = 0
	oleada = 1 if modo == SUPERVIVENCIA else 0
	tiempo = 0.0
	_terminado = false
	estado_cambio.emit()


func detener() -> void:
	activo = false
	_terminado = true


## La llama la arena cuando muere un bot. Devuelve cuantos bots nuevos hay que poner.
##
## Devolver un numero en vez de spawnear aca es a proposito: quien sabe crear jugadores es
## la arena, y este archivo no tiene por que aprender a hacerlo para contar oleadas.
func bot_murio(vivos_restantes: int) -> int:
	if not activo or _terminado:
		return 0
	bajas += 1
	estado_cambio.emit()

	match actual:
		CONTRARRELOJ:
			if bajas >= META_CONTRARRELOJ:
				_finalizar(true, "¡CONTRARRELOJ COMPLETADO!",
					"%d bajas en %s" % [bajas, reloj()])
				return 0
			return 1
		SUPERVIVENCIA:
			if vivos_restantes > 0:
				return 0
			# Oleada limpia: viene la siguiente, una mas grande.
			oleada += 1
			estado_cambio.emit()
			return mini(OLEADA_INICIAL + oleada - 1, TOPE_SIMULTANEOS)
		ULTIMO_EN_PIE:
			if vivos_restantes <= 0:
				_finalizar(true, "¡ÚLTIMO EN PIE!", "%d contra uno, en %s" % [
					BOTS_ULTIMO_EN_PIE, reloj()])
			return 0
	return 0


## La llama la arena cuando muere el jugador local.
func jugador_murio() -> void:
	if not activo or _terminado:
		return
	match actual:
		SUPERVIVENCIA:
			_finalizar(false, "OLEADA %d" % oleada,
				"%d bajas antes de caer" % bajas)
		ULTIMO_EN_PIE:
			_finalizar(false, "TE GANARON", "%d de %d" % [bajas, BOTS_ULTIMO_EN_PIE])


func _finalizar(gano: bool, titulo: String, detalle: String) -> void:
	if _terminado:
		return
	_terminado = true
	activo = false
	# El plus por ganar sale de aca; las monedas por baja ya se pagaron una por una.
	Progreso.registrar_partida(gano, da_recompensas())
	termino.emit(gano, titulo, detalle)
	estado_cambio.emit()


func reloj() -> String:
	return "%d:%02d" % [int(tiempo) / 60, int(tiempo) % 60]


## Lo que el HUD muestra arriba mientras jugas. "" = este modo no muestra nada.
func marcador() -> String:
	if not activo:
		return ""
	match actual:
		SUPERVIVENCIA:
			return "OLEADA %d    %d bajas" % [oleada, bajas]
		CONTRARRELOJ:
			return "%d / %d    %s" % [bajas, META_CONTRARRELOJ, reloj()]
		ULTIMO_EN_PIE:
			return "QUEDAN %d    %s" % [maxi(0, BOTS_ULTIMO_EN_PIE - bajas), reloj()]
	return ""
