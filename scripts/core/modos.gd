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
## Todos contra todos: los bots tambien se pelean entre ellos.
const CAMPAL: StringName = &"campal"
## Todo mas rapido: recargas cortas, sin stamina y el ultimate en un rato.
const CAOS: StringName = &"caos"
## Aguantar mientras llueven meteoritos.
const METEORITOS: StringName = &"meteoritos"
## La papa caliente: la bomba pasa al que le pegas, y explota en las manos de alguien.
const BOMBA: StringName = &"bomba"
## Cualquier golpe mata, a todos.
const TOQUE: StringName = &"toque"
## Juntar esferas, una por vez, mientras te cazan.
const ESFERAS: StringName = &"esferas"
## El modo historia. No va en LISTA: tiene su propio boton y su propia pantalla.
const HISTORIA: StringName = &"historia"

## Todos los offline, en el orden en que se muestran: del mas parejo al mas dificil.
const LISTA: Array[StringName] = [DUELO, CAOS, BOMBA, TOQUE, CONTRARRELOJ, ESFERAS, COLINA,
	CAMPAL, METEORITOS, SUPERVIVENCIA, ULTIMO_EN_PIE, JEFES, PRACTICA]

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

## BATALLA CAMPAL: seis en el mapa, todos contra todos. Los bots se pelean entre ellos tanto
## como con vos, asi que no es cinco contra uno: es elegir cuando meterse.
const BOTS_CAMPAL: int = 5

## MODO CAOS: las recargas duran un tercio, nadie gasta stamina y el ultimate se junta tres
## veces mas rapido. Gana el primero que llega a las bajas; perdes si caes demasiadas veces.
const RECARGA_CAOS: float = 0.35
const CARGA_CAOS: float = 3.0
const META_CAOS: int = 10
const MUERTES_CAOS: int = 5
const BOTS_CAOS: int = 3

## LLUVIA DE METEORITOS: aguantar vivo mientras caen del cielo, con dos bots que molestan y
## que tambien se los comen. Cada vez caen mas seguido, y algunos van derecho a donde
## estas parado: quedarse quieto no sirve.
const META_METEORITOS: float = 50.0
const BOTS_METEORITOS: int = 2
## Cada cuanto cae uno, al empezar y al final.
const LLUVIA_INICIO: float = 1.2
const LLUVIA_FINAL: float = 0.45
## Cada cuantos, uno va derecho al jugador.
const LLUVIA_APUNTADOS: int = 4
const METEORO_RADIO: float = 4.0
const METEORO_DAÑO: float = 22.0
## Desde que aparece la sombra hasta que pega. Lo que hay para salir.
const METEORO_CAIDA: float = 1.7

## BOMBA CALIENTE: alguien tiene la bomba y se la pasa PEGANDOLE a otro, con lo que sea.
## Cuando se acaba la mecha explota en las manos del que la tiene, y ese queda afuera.
## Nadie pierde vida a golpes: solo la bomba saca a alguien. Gana el ultimo.
const BOTS_BOMBA: int = 4
## La mecha de la primera ronda, cuanto se acorta en cada una y hasta donde.
## Un segundo mas en las dos puntas (BALANCE 2026-10-02): con la mecha justa, la ronda la
## decidia a quien le tocaba la bomba mas que lo que hacia con ella.
const MECHA_BOMBA: float = 15.0
const MECHA_MENOS: float = 1.5
const MECHA_MINIMA: float = 9.0
## Recien recibida no se puede pasar: un golpe de varios impactos que ya venia en camino
## la devolvia en el mismo instante, y nadie veia quien la tenia.
const GRACIA_BOMBA: float = 0.5
## Y no se le puede devolver enseguida al que te la paso: sin esto, dos pegados se la
## pasaban de ida y vuelta hasta que explotaba al azar en uno.
const SIN_DEVOLVER: float = 1.5
## A cuanto del que la tiene se escapan los bots.
const RADIO_HUIDA: float = 9.0
## De la explosion a la ronda siguiente.
const PAUSA_BOMBA: float = 2.5

## UN TOQUE: cualquier golpe mata, escudo incluido, a vos y a ellos. Todos reaparecen; se
## gana llegando a las bajas y se pierde cayendo demasiadas veces. Esquivar es todo.
const BOTS_TOQUE: int = 2
const META_TOQUE: int = 5
const MUERTES_TOQUE: int = 8

## CAZA DE ESFERAS: aparece una esfera lejos, con una columna de luz que se ve de todo el
## mapa; la tocas, aparece la siguiente. Tres bots te cazan mientras tanto, y reaparecen.
const META_ESFERAS: int = 7
const MUERTES_ESFERAS: int = 5
const BOTS_ESFERAS: int = 2
## A cuanto del jugador aparece cada una.
const ESFERA_CERCA: float = 18.0
const ESFERA_LEJOS: float = 34.0
## A cuanto hay que pasar para tomarla.
const ESFERA_RADIO: float = 1.8


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
##
## RECALIBRADO cuando se arreglaron los bots (2026-09-24). Con la barra de stamina llena
## "intentaban" el ultimate sin carga y se quedaban la pausa entera sin pegar, Rick y
## Flowery solo disparaban con el rival encima, y nadie apuntaba con adelanto: pegaban
## bastante menos de lo que podian. Arreglados, los modos contra varios se volvieron mucho
## mas duros (colina de 60% a 13%) y estos numeros vuelven a dejarlos donde estaban. Con
## 30 peleas por modo: con 15, el ruido era de doce puntos.
##
## Y OTRA VEZ AL SACARSE LOS COMBOS (2026-09-25). Contra varios, el tambaleo castigaba
## sobre todo al que estaba solo: cada enemigo que le pegaba lo dejaba clavado para el
## siguiente. Sin el, todo se volvio mucho mas facil —colina 97%, contrarreloj 90%, ultimo
## en pie 87%, la torre 67%— y estos numeros los devuelven a donde estaban. Y al subir los
## cooldowns x1.5, al reves y solo en los que el heroe tiene que matar rapido contra uno
## fuerte: duelo 21%, torre 17%, colina 25%.
##
## Todo multiplicado por GameConfig.VIDA, igual que la vida de los personajes. En la historia
## ya viene multiplicada de la mision (ver MisionHistoria._sumar).
func vida_bot(id: int = 0) -> float:
	if actual == HISTORIA:
		return mision.vida_de(id) if is_instance_valid(mision) else 60.0 * GameConfig.VIDA
	return _vida_base() * GameConfig.VIDA


func _vida_base() -> float:
	match actual:
		PRACTICA: return 170.0
		DUELO: return 128.0
		SUPERVIVENCIA: return 36.0 + float(oleada) * 5.0
		CONTRARRELOJ: return 57.0
		ULTIMO_EN_PIE: return 52.0
		# Sube de a poco para no cruzar de golpe el umbral de los 180.
		JEFES: return 94.0 + float(bajas) * 17.0
		COLINA: return 57.0
		# BALANCE 2026-10-02: la campal (63%) y el caos (70%) eran de los mas faciles de la
		# lista, y el ultimo en pie (20%) de los mas dificiles sin ser la torre.
		CAMPAL: return 76.0
		CAOS: return 80.0
		METEORITOS: return 40.0
		# En la bomba y en un toque la vida no cuenta: la primera no saca, el segundo mata.
		BOMBA: return 100.0
		TOQUE: return 100.0
		ESFERAS: return 57.0
	return 170.0


## Cuanto pega un enemigo, como fraccion del daño normal.
##
## `id` es el peer del bot (-1, -2...). Solo lo usa la historia, donde cada enemigo pega
## distinto: un eco no pega como Dio.
func daño_bot(id: int = 0) -> float:
	if actual == HISTORIA:
		return mision.daño_de(id) if is_instance_valid(mision) else 0.4
	match actual:
		PRACTICA: return GameConfig.BOT_DAMAGE_SCALE
		DUELO: return 0.72
		SUPERVIVENCIA: return minf(0.17 + float(oleada) * 0.018, 0.36)
		CONTRARRELOJ: return 0.37
		ULTIMO_EN_PIE: return 0.30
		# Los jefes se endurecen tambien pegando, no solo aguantando: un jefe que solo tiene
		# mas vida es la misma pelea mas larga.
		JEFES: return 0.40 + float(bajas) * 0.03
		COLINA: return 0.30
		CAMPAL: return 0.36
		CAOS: return 0.36
		METEORITOS: return 0.08
		BOMBA: return 0.4
		TOQUE: return 0.4
		ESFERAS: return 0.30
	return GameConfig.BOT_DAMAGE_SCALE

var actual: StringName = ONLINE
var activo: bool = false
var bajas: int = 0
var oleada: int = 0
var tiempo: float = 0.0
## Cuantos segundos lleva el jugador adentro del circulo, acumulados.
var colina_avance: float = 0.0
var colina_dentro: bool = false
## Cuantas veces cayo el jugador. Lo cuentan los modos en los que se reaparece pero se
## puede perder: caos, un toque y la caza de esferas.
var muertes: int = 0
## Cuantas esferas lleva juntadas.
var esferas: int = 0
## Quien tiene la bomba (su peer) y como se llama. 0 = nadie: entre una ronda y otra.
var bomba_de: int = 0
var bomba_nombre: String = ""
## Cuanto le queda a la mecha, y que ronda va.
var mecha: float = 0.0
var ronda_bomba: int = 0
var _bomba_gracia: float = 0.0
var _bomba_anterior: int = 0
var _bomba_anterior_t: float = 0.0
var _terminado: bool = false
## El capitulo que se esta jugando en el modo historia. -1 = ninguno.
var capitulo: int = -1
## La pelea del capitulo, mientras dura. EN LA HISTORIA MANDA ELLA: quien aparece, de que
## lado, cuanto aguanta y pega cada uno, y cuando se gana o se pierde. Este archivo solo
## le pregunta. Ver MisionHistoria.
var mision: Node = null


## Arranca un capitulo de la historia.
func iniciar_historia(i: int) -> void:
	capitulo = i
	iniciar(HISTORIA)


func _process(delta: float) -> void:
	if activo and not _terminado:
		tiempo += delta
		if actual == METEORITOS and tiempo >= META_METEORITOS:
			_finalizar(true, "¡SOBREVIVISTE A LA LLUVIA!", "%d segundos bajo los meteoritos" % int(
				META_METEORITOS))


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


## Por cuanto se multiplican las monedas y la experiencia. Solo lo mueve la dificultad de
## la historia: mas dificil, mas paga.
func premio() -> float:
	if actual == HISTORIA:
		return float(Historia.dificultad(Progreso.dificultad_historia)["premio"])
	return 1.0


## Los bots se eligen entre ellos? En la batalla campal y en la bomba, donde el que la tiene
## se la quiere pasar a cualquiera (y en la practica, si el panel lo pide: eso lo mira
## BotBrain aparte).
func todos_contra_todos() -> bool:
	return actual == CAMPAL or actual == BOMBA


## Los golpes no sacan vida? Solo en la bomba: ahi lo unico que saca a alguien es la bomba.
func sin_daño() -> bool:
	return actual == BOMBA


## Cualquier golpe mata? Solo en un toque.
func un_toque() -> bool:
	return actual == TOQUE


# ------------------------------------------------------------------- La bomba

## La mecha de la ronda `r`: cada ronda mas corta, hasta un minimo.
func mecha_de_ronda(r: int) -> float:
	return maxf(MECHA_MINIMA, MECHA_BOMBA - MECHA_MENOS * float(r - 1))


## Le da la bomba a alguien al empezar una ronda. La llama la arena, que es la que sabe
## quienes quedan.
func dar_bomba(peer: int, quien: String) -> void:
	ronda_bomba += 1
	mecha = mecha_de_ronda(ronda_bomba)
	bomba_de = peer
	bomba_nombre = quien
	_bomba_gracia = GRACIA_BOMBA
	_bomba_anterior = 0
	_bomba_anterior_t = 0.0
	estado_cambio.emit()


## Un golpe de `de` a `a`: si el que pega tiene la bomba, pasa. Devuelve si paso.
##
## LA LLAMA CombatUtils.deal_damage, el unico lugar por el que pasan todos los golpes: asi
## la bomba pasa con cualquier habilidad, la de un personaje que todavia no existe incluida.
func golpe_bomba(de: int, a: Node) -> bool:
	if actual != BOMBA or not activo or _terminado or bomba_de == 0 or de != bomba_de:
		return false
	if _bomba_gracia > 0.0 or not is_instance_valid(a):
		return false
	var peer := int(a.get("peer_id"))
	if peer == de or (peer == _bomba_anterior and _bomba_anterior_t > 0.0):
		return false
	var salud := a.get_node_or_null("Health") as Health
	if salud == null or salud.is_dead:
		return false
	_bomba_anterior = de
	_bomba_anterior_t = SIN_DEVOLVER
	bomba_de = peer
	bomba_nombre = String(a.get("player_name"))
	_bomba_gracia = GRACIA_BOMBA
	estado_cambio.emit()
	return true


## Corre la mecha. Devuelve true el frame en que explota: sacar al que la tiene, el ruido y
## la ronda siguiente son de la arena.
func avanzar_bomba(delta: float) -> bool:
	if actual != BOMBA or not activo or _terminado or bomba_de == 0:
		return false
	_bomba_gracia = maxf(0.0, _bomba_gracia - delta)
	_bomba_anterior_t = maxf(0.0, _bomba_anterior_t - delta)
	mecha -= delta
	if mecha > 0.0:
		return false
	mecha = 0.0
	return true


## Despues de la explosion, nadie la tiene hasta la ronda siguiente.
func soltar_bomba() -> void:
	bomba_de = 0
	bomba_nombre = ""
	estado_cambio.emit()


# ------------------------------------------------------------- Las esferas

## La llama la arena cuando el jugador toca la esfera.
func esfera_tomada() -> void:
	if not activo or _terminado or actual != ESFERAS:
		return
	esferas += 1
	estado_cambio.emit()
	if esferas >= META_ESFERAS:
		_finalizar(true, "¡JUNTASTE LAS %d ESFERAS!" % META_ESFERAS, "%d caídas, en %s" % [
			muertes, reloj()])


## Por cuanto se multiplica cada recarga. Solo el modo caos la acorta.
##
## ES PARA TODOS, bots incluidos: un caos en el que solo vos tiras el doble no es caos, es
## ventaja. Fuera de los modos offline siempre da 1, asi que el online no cambia.
func ritmo_recarga() -> float:
	return RECARGA_CAOS if actual == CAOS else 1.0


## Nadie gasta stamina? Solo en el modo caos.
func stamina_libre() -> bool:
	return actual == CAOS


## Por cuanto se multiplica lo que carga el ultimate pegando.
func ritmo_carga() -> float:
	return CARGA_CAOS if actual == CAOS else 1.0


## Cada cuanto cae un meteorito en la lluvia, segun cuanto va de partida: cada vez mas seguido.
func espera_meteorito() -> float:
	return lerpf(LLUVIA_INICIO, LLUVIA_FINAL, clampf(tiempo / META_METEORITOS, 0.0, 1.0))


func nombre() -> String:
	match actual:
		PRACTICA: return "Sala de práctica"
		SUPERVIVENCIA: return "Supervivencia"
		CONTRARRELOJ: return "Contrarreloj"
		ULTIMO_EN_PIE: return "Último en pie"
		DUELO: return "Duelo"
		JEFES: return "Torre de jefes"
		COLINA: return "Rey de la colina"
		CAMPAL: return "Batalla campal"
		CAOS: return "Modo caos"
		METEORITOS: return "Lluvia de meteoritos"
		BOMBA: return "Bomba caliente"
		TOQUE: return "Un toque"
		ESFERAS: return "Caza de esferas"
		HISTORIA: return "Historia"
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
		CAMPAL:
			return "Seis en el mapa, todos contra todos: los bots también se pelean entre ellos. Quedá último en pie."
		CAOS:
			return "Recargas cortísimas, sin stamina y el ultimate en un rato. %d bajas ganan; %d caídas pierden." % [
				META_CAOS, MUERTES_CAOS]
		METEORITOS:
			return "Aguantá %d segundos mientras caen meteoritos, cada vez más seguido. No reapareces." % int(
				META_METEORITOS)
		BOMBA:
			return "Alguien tiene la bomba: pegale a otro para pasársela antes de que explote. Los golpes no sacan vida. Quedá último de cinco."
		TOQUE:
			return "Cualquier golpe mata, a todos. %d bajas ganan; %d caídas pierden." % [META_TOQUE, MUERTES_TOQUE]
		ESFERAS:
			return "Juntá %d esferas, una por vez, con %d bots cazándote. Seguí la columna de luz. %d caídas pierden." % [
				META_ESFERAS, BOTS_ESFERAS, MUERTES_ESFERAS]
		HISTORIA:
			return String(Historia.capitulo(capitulo).get("titulo", ""))
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
		CAMPAL: return BOTS_CAMPAL
		CAOS: return BOTS_CAOS
		METEORITOS: return BOTS_METEORITOS
		BOMBA: return BOTS_BOMBA
		TOQUE: return BOTS_TOQUE
		ESFERAS: return BOTS_ESFERAS
		# La arena no pone a nadie: los pone la mision, cada uno con su lado y su papel.
		HISTORIA: return 0
	return 0


## Vuelve el bot despues de morir?
func reaparecen_bots() -> bool:
	return actual in [PRACTICA, CONTRARRELOJ, COLINA, CAOS, METEORITOS, TOQUE, ESFERAS]


## Vuelve el jugador despues de morir?
##
## En supervivencia y en ultimo en pie, no: son modos que se pueden PERDER, y un modo que
## no se puede perder no se puede ganar tampoco.
func reaparece_jugador() -> bool:
	return actual in [PRACTICA, CONTRARRELOJ, ONLINE, COLINA, CAOS, TOQUE, ESFERAS]


# --------------------------------------------------------------------- Partida

func iniciar(modo: StringName) -> void:
	# Salir de la historia por cualquier otro modo olvida el capitulo: si no, un modo
	# libre leeria la vida de los enemigos del ultimo capitulo jugado.
	if modo != HISTORIA:
		capitulo = -1
	actual = modo
	activo = es_offline() and modo != PRACTICA
	bajas = 0
	oleada = 1 if modo == SUPERVIVENCIA else 0
	colina_avance = 0.0
	colina_dentro = false
	muertes = 0
	esferas = 0
	bomba_de = 0
	bomba_nombre = ""
	mecha = 0.0
	ronda_bomba = 0
	_bomba_gracia = 0.0
	_bomba_anterior = 0
	_bomba_anterior_t = 0.0
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
		CAMPAL:
			# Cuentan todas las caidas, las tuyas y las que se hicieron entre ellos: lo que
			# importa es quedar solo.
			if vivos_restantes <= 0:
				_finalizar(true, "¡GANASTE LA BATALLA CAMPAL!", "El último de seis, en %s" % reloj())
			return 0
		CAOS:
			if bajas >= META_CAOS:
				_finalizar(true, "¡DOMINASTE EL CAOS!", "%d bajas y %d caídas en %s" % [
					bajas, muertes, reloj()])
			return 0
		TOQUE:
			if bajas >= META_TOQUE:
				_finalizar(true, "¡NI UN RASGUÑO!", "%d bajas y %d caídas en %s" % [
					bajas, muertes, reloj()])
			return 0
		BOMBA:
			# Las bajas son explosiones: quedar solo es ganar.
			if vivos_restantes <= 0:
				_finalizar(true, "¡SOBREVIVISTE A LA BOMBA!", "El último de %d, en %s" % [
					BOTS_BOMBA + 1, reloj()])
			return 0
		DUELO:
			_finalizar(true, "¡GANASTE EL DUELO!", "En %s" % reloj())
			return 0
		HISTORIA:
			# Quien gana lo decide la mision, con su objetivo: no siempre es "no queda nadie".
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
		CAMPAL:
			_finalizar(false, "QUEDASTE AFUERA", "Cayeron %d de %d antes que vos" % [bajas, BOTS_CAMPAL])
		CAOS:
			muertes += 1
			estado_cambio.emit()
			if muertes >= MUERTES_CAOS:
				_finalizar(false, "EL CAOS TE GANÓ", "%d bajas de %d" % [bajas, META_CAOS])
		METEORITOS:
			_finalizar(false, "TE APLASTARON", "Aguantaste %s de %d segundos" % [
				reloj(), int(META_METEORITOS)])
		BOMBA:
			_finalizar(false, "¡BOOM!", "Te explotó en la ronda %d" % maxi(1, ronda_bomba))
		TOQUE:
			muertes += 1
			estado_cambio.emit()
			if muertes >= MUERTES_TOQUE:
				_finalizar(false, "UN TOQUE ALCANZÓ", "%d bajas de %d" % [bajas, META_TOQUE])
		ESFERAS:
			muertes += 1
			estado_cambio.emit()
			if muertes >= MUERTES_ESFERAS:
				_finalizar(false, "TE CAZARON", "%d esferas de %d" % [esferas, META_ESFERAS])
		HISTORIA:
			# Tambien la mision: escucha la muerte del jugador por su cuenta.
			pass


## El final de un capitulo. Lo llama la mision.
func terminar_historia(gano: bool, titulo: String, detalle: String) -> void:
	if actual != HISTORIA:
		return
	_finalizar(gano, titulo, detalle)


func _finalizar(gano: bool, titulo: String, detalle: String) -> void:
	if _terminado:
		return
	_terminado = true
	activo = false
	# El plus por ganar sale de aca; las monedas por baja ya se pagaron una por una.
	Progreso.registrar_partida(gano, da_recompensas(), premio())
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
		CAMPAL:
			return "QUEDAN %d    %s" % [maxi(0, BOTS_CAMPAL - bajas), reloj()]
		CAOS:
			return "%d / %d BAJAS    %d / %d CAÍDAS" % [bajas, META_CAOS, muertes, MUERTES_CAOS]
		METEORITOS:
			return "AGUANTÁ %d s" % maxi(0, ceili(META_METEORITOS - tiempo))
		BOMBA:
			var quedan := maxi(0, BOTS_BOMBA - bajas)
			if bomba_de == 0:
				return "QUEDAN %d    PRÓXIMA RONDA..." % quedan
			if bomba_de == Net.local_id():
				return "¡TENÉS LA BOMBA!  %.1f s    QUEDAN %d" % [mecha, quedan]
			return "LA BOMBA: %s  %.1f s    QUEDAN %d" % [bomba_nombre, mecha, quedan]
		TOQUE:
			return "%d / %d BAJAS    %d / %d CAÍDAS" % [bajas, META_TOQUE, muertes, MUERTES_TOQUE]
		ESFERAS:
			return "ESFERAS %d / %d    %d / %d CAÍDAS" % [esferas, META_ESFERAS, muertes, MUERTES_ESFERAS]
		JEFES:
			return "JEFE %d / %d    %s" % [mini(bajas + 1, JEFES_TOTAL), JEFES_TOTAL, reloj()]
		HISTORIA:
			return mision.texto_objetivo() if is_instance_valid(mision) else ""
		COLINA:
			# Dice tambien si el reloj esta corriendo: sin eso, estar afuera se ve igual que
			# estar adentro y no se entiende por que no avanza.
			return "%s  %d / %d s" % [
				"EN LA ZONA" if colina_dentro else "FUERA DE LA ZONA",
				int(colina_avance), int(META_COLINA)]
	return ""
