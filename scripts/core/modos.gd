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
## Se limpio una oleada. La arena cura al jugador cuando pasa.
signal respiro()

const PRACTICA: StringName = &"practica"
const SUPERVIVENCIA: StringName = &"supervivencia"
const CONTRARRELOJ: StringName = &"contrarreloj"
const ULTIMO_EN_PIE: StringName = &"ultimo_en_pie"
const ONLINE: StringName = &"online"
const DUELO: StringName = &"duelo"
const JEFES: StringName = &"jefes"
const COLINA: StringName = &"colina"

## Todos los offline, en el orden en que se muestran: del mas parejo al mas dificil.
const LISTA: Array[StringName] = [DUELO, CONTRARRELOJ, COLINA, SUPERVIVENCIA,
	ULTIMO_EN_PIE, JEFES, PRACTICA]

## Cuantas bajas pide contrarreloj.
##
## ERAN VEINTE Y ERA UNA BARBARIDAD. Medido: contra un bot de 55 de vida, una racha de
## veinte son varios minutos de lo mismo. Un modo de velocidad tiene que durar lo que dura
## una buena racha, no lo que dura la paciencia.
const META_CONTRARRELOJ: int = 12
## Cuantos bots hay a la vez en contrarreloj.
const BOTS_CONTRARRELOJ: int = 3
## Con cuantos empieza supervivencia y cuantos puede haber a la vez como maximo.
const OLEADA_INICIAL: int = 2
const TOPE_SIMULTANEOS: int = 6
const BOTS_ULTIMO_EN_PIE: int = 4
## Cuantos jefes seguidos, uno por vez.
const JEFES_TOTAL: int = 5
## Cuantos segundos hay que tener la zona en Rey de la Colina, y cuantos la disputan.
const META_COLINA: float = 45.0
const BOTS_COLINA: int = 3
## Radio de la zona.
const RADIO_COLINA: float = 9.0


# ------------------------------------------------ Cuanto aguantan los enemigos
#
# ERA UN NUMERO SOLO PARA TODO, Y ESTABA PENSADO PARA LA PRACTICA: 170 de vida contra los
# 100 del jugador, para que un maniqui aguante mientras ensayas combos. En un modo que se
# puede PERDER eso esta al reves. Medido con un jugador de habilidad de bot contra esos
# mismos bots: cero bajas en cuarenta segundos, ni siquiera uno contra uno. No era
# dificil, era imposible.
#
# Ahora cada modo trae los suyos, y la practica se queda con los de antes porque ahi si
# hacen falta.

## Cuantos enemigos trae la oleada `n` de supervivencia.
##
## UNO MAS CADA DOS OLEADAS, no cada una. Supervivencia es una RACHA: hay que pasar la
## oleada 1 Y la 2 Y la 3, y las probabilidades se multiplican. Sumando uno por oleada, la
## cuarta ya era cinco a la vez, y medido el heroe no pasaba de la tercera en ninguna de
## quince corridas. Una racha tiene que empezar facil para que tenga sentido llegar lejos.
##
## Es una funcion y no una cuenta escrita en dos lados porque el simulador de balance la
## necesita tambien: tenia su propia copia, que es justo lo que se desincroniza en silencio.
static func bots_en_oleada(n: int) -> int:
	return mini(OLEADA_INICIAL + (n - 1) / 2, TOPE_SIMULTANEOS)


## Vida de cada enemigo en este modo.
##
## CALIBRADO CON PELEAS SIMULADAS, no a ojo (tests/balance_modos.gd): un heroe con la vida
## y el daño de un jugador contra los enemigos de cada modo, seis veces por modo. La
## primera medicion fue lapidaria: supervivencia, jefes y ultimo en pie daban CERO
## victorias de seis, y el duelo cinco de seis.
##
## Lo que enseño la medicion, y que no es obvio:
##
## - Contra VARIOS, la dificultad crece mucho mas rapido que la cantidad. Dos enemigos
##   no son el doble de dificiles que uno: pegan el doble Y hay que sacarles el doble de
##   vida, asi que son varias veces mas dificiles. Por eso en los modos de muchos cada
##   enemigo tiene que ser bastante mas debil que el del duelo.
## - En uno contra uno hay un punto muy marcado: por debajo de unos 150 de vida el heroe
##   gana casi siempre, y por arriba de 180 pierde casi siempre. La torre subia 48 por
##   jefe y pasaba ese umbral en el segundo, asi que el jefe 1 se ganaba y el 2 no.
func vida_bot() -> float:
	match actual:
		PRACTICA: return 170.0
		DUELO: return 150.0
		SUPERVIVENCIA: return 40.0 + float(oleada) * 6.0
		CONTRARRELOJ: return 55.0
		ULTIMO_EN_PIE: return 50.0
		# Sube de a poco para no cruzar de golpe el umbral de los 180.
		JEFES: return 112.0 + float(bajas) * 20.0
		COLINA: return 60.0
	return 170.0


## Cuanto pega un enemigo, como fraccion del daño normal.
func daño_bot() -> float:
	match actual:
		PRACTICA: return GameConfig.BOT_DAMAGE_SCALE
		DUELO: return 0.72
		SUPERVIVENCIA: return minf(0.21 + float(oleada) * 0.02, 0.40)
		CONTRARRELOJ: return 0.38
		ULTIMO_EN_PIE: return 0.31
		# Los jefes se endurecen tambien pegando, no solo aguantando: un jefe que solo tiene
		# mas vida es la misma pelea mas larga.
		JEFES: return 0.50 + float(bajas) * 0.03
		COLINA: return 0.34
	return GameConfig.BOT_DAMAGE_SCALE

var actual: StringName = ONLINE
var activo: bool = false
var bajas: int = 0
var oleada: int = 0
var tiempo: float = 0.0
## Cuantos segundos lleva el jugador adentro del circulo, acumulados.
var colina_avance: float = 0.0
var colina_dentro: bool = false
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
		DUELO: return "Duelo"
		JEFES: return "Torre de jefes"
		COLINA: return "Rey de la colina"
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
			return "%d contra uno, todos a la vez. Nadie reaparece." % BOTS_ULTIMO_EN_PIE
		DUELO:
			return "Uno contra uno, parejo. El mejor lugar para aprender un personaje."
		JEFES:
			return "%d enemigos, de a uno, cada uno más duro que el anterior." % JEFES_TOTAL
		COLINA:
			return "Aguantá %d segundos dentro del círculo. Si te salen, el reloj para." % int(META_COLINA)
	return "Contra otros jugadores."


## Cuantos bots pone la arena al empezar.
func bots_iniciales() -> int:
	match actual:
		PRACTICA: return Practica.bots
		SUPERVIVENCIA: return OLEADA_INICIAL
		CONTRARRELOJ: return BOTS_CONTRARRELOJ
		ULTIMO_EN_PIE: return BOTS_ULTIMO_EN_PIE
		DUELO: return 1
		JEFES: return 1
		COLINA: return BOTS_COLINA
	return 0


## Vuelve el bot despues de morir?
func reaparecen_bots() -> bool:
	return actual == PRACTICA or actual == CONTRARRELOJ or actual == COLINA


## Vuelve el jugador despues de morir?
##
## En supervivencia y en ultimo en pie, no: son modos que se pueden PERDER, y un modo que
## no se puede perder no se puede ganar tampoco.
func reaparece_jugador() -> bool:
	return actual == PRACTICA or actual == CONTRARRELOJ or actual == ONLINE or actual == COLINA


# --------------------------------------------------------------------- Partida

func iniciar(modo: StringName) -> void:
	actual = modo
	activo = es_offline() and modo != PRACTICA
	bajas = 0
	oleada = 1 if modo == SUPERVIVENCIA else 0
	colina_avance = 0.0
	colina_dentro = false
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
			# Y EL JUGADOR SE CURA ENTRE OLEADAS.
			#
			# Sin esto el modo era una sola vida para toda la partida: cualquier error de la
			# oleada 2 se pagaba en la 7, cuando ya no quedaba nada que hacer. Curar entre
			# oleadas convierte "aguanta sin equivocarte nunca" en "aguanta cada oleada", que
			# es lo que un modo de oleadas tiene que pedir.
			respiro.emit()
			return bots_en_oleada(oleada)
		ULTIMO_EN_PIE:
			if vivos_restantes <= 0:
				_finalizar(true, "¡ÚLTIMO EN PIE!", "%d contra uno, en %s" % [
					BOTS_ULTIMO_EN_PIE, reloj()])
			return 0
		DUELO:
			_finalizar(true, "¡GANASTE EL DUELO!", "En %s" % reloj())
			return 0
		JEFES:
			if bajas >= JEFES_TOTAL:
				_finalizar(true, "¡TORRE COMPLETADA!", "%d jefes en %s" % [bajas, reloj()])
				return 0
			# Un respiro entre jefes: son peleas largas, y encadenarlas sin curar hace que la
			# torre la decida el primero en vez del ultimo.
			respiro.emit()
			return 1
	return 0


## La llama la arena cada frame de fisica mientras se juega Rey de la Colina.
##
## EL RELOJ PARA AL SALIR, no retrocede. Retroceder castiga dos veces —te sacaron Y
## perdiste lo hecho— y convierte una salida mala en una partida perdida sin remedio. Que
## se pause ya alcanza para que valga la pena volver.
func avanzar_colina(dentro: bool, delta: float) -> void:
	if not activo or _terminado or actual != COLINA:
		return
	colina_dentro = dentro
	if not dentro:
		return
	colina_avance += delta
	if colina_avance >= META_COLINA:
		_finalizar(true, "¡REY DE LA COLINA!", "Aguantaste %d segundos en %s" % [
			int(META_COLINA), reloj()])


## La llama la arena cuando muere el jugador local.
func jugador_murio() -> void:
	if not activo or _terminado:
		return
	match actual:
		SUPERVIVENCIA:
			_finalizar(false, "OLEADA %d" % oleada,
				"%d bajas antes de caer" % bajas)
		DUELO:
			_finalizar(false, "PERDISTE EL DUELO", "Probá con otro personaje.")
		JEFES:
			_finalizar(false, "JEFE %d" % (bajas + 1), "Llegaste al jefe %d de %d" % [
				bajas + 1, JEFES_TOTAL])
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
		DUELO:
			return "DUELO    %s" % reloj()
		JEFES:
			return "JEFE %d / %d    %s" % [mini(bajas + 1, JEFES_TOTAL), JEFES_TOTAL, reloj()]
		COLINA:
			# Dice tambien si el reloj esta corriendo: sin eso, estar afuera se ve igual que
			# estar adentro y no se entiende por que no avanza.
			return "%s  %d / %d s" % [
				"EN LA ZONA" if colina_dentro else "FUERA DE LA ZONA",
				int(colina_avance), int(META_COLINA)]
	return ""
