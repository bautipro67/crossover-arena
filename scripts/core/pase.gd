extends Node
## Autoload: Pase
## El pase de temporada. Treinta escalones, dos vias: la gratuita y la pro.
##
## TEMPORADA 2. La 1 termino el 2026-09-25: al abrir el juego con un archivo de una
## temporada anterior, lo que se habia alcanzado y no se habia cobrado se cobra solo, y el
## pase arranca de cero. Ver _cerrar_temporada_vieja(). Goku, que era el premio de la 1,
## quedo de todos; el de la 2 es Mob.
##
## LAS DOS VIAS AVANZAN CON LA MISMA EXPERIENCIA. Comprar el pro no acelera nada: abre la
## fila de abajo, incluidas las recompensas de los escalones que ya pasaste. Es lo que
## evita que comprarlo tarde se sienta un castigo, y es la unica forma de que la decision
## de comprarlo no sea una carrera contra el reloj.
##
## Y NADA DE LO QUE DA AFECTA UNA PARTIDA: skins, monedas y experiencia. Las monedas solo
## compran mas skins, y la experiencia solo mueve estas mismas barras. Un circuito cerrado
## que empieza y termina en lo cosmetico, a proposito.

const TEMPORADA: int = 2
const NOMBRE: String = "TEMPORADA 2 — FUERZA PSÍQUICA"
const ESCALONES: int = 30
## Experiencia por escalon. 250 x 30 = 7500 para el pase entero, que a unos 170 por
## partida son unas 45 partidas. Una temporada tiene que durar, pero tiene que terminarse.
const EXP_POR_ESCALON: int = 250

## Tipos de recompensa.
const MONEDAS: StringName = &"monedas"
const EXP: StringName = &"exp"
const SKIN: StringName = &"skin"
## Un personaje entero: el premio del ultimo escalon del pro. Goku en la 1, Mob en la 2.
const PERSONAJE: StringName = &"personaje"
const NADA: StringName = &"nada"

## El aviso de que termino la temporada anterior, para mostrarlo una vez. Ver tomar_aviso().
var aviso_cierre: String = ""

## escalon -> [recompensa gratuita, recompensa pro].
## Cada recompensa es [tipo, valor]. El valor es una cantidad o un id de skin.
##
## LA VIA GRATUITA NO ESTA VACIA, y eso importa mas de lo que parece: un pase donde la
## fila de arriba es toda "nada" no es un pase, es un cartel de venta. Aca da monedas en
## casi todos los escalones y dos skins propias, asi que el que no paga igual junta para
## comprarse algo en la tienda.
var _tabla: Dictionary = {}


## Las tablas de las temporadas que ya terminaron, por numero. Solo se usan para
## cerrarlas: cobrar lo que alguien alcanzo y no llego a reclamar antes de que terminaran.
var _viejas: Dictionary = {}


func _ready() -> void:
	_viejas = {0: _armar_temporada_0(), 1: _armar_temporada_1()}
	_tabla = _armar_temporada_2()
	_cerrar_temporada_vieja()


## Monedas en casi todos los escalones y experiencia cada cinco. Es igual en las dos
## temporadas: lo que cambia entre una y otra son las skins de encima.
func _base() -> Dictionary:
	var t: Dictionary = {}
	for i: int in range(1, ESCALONES + 1):
		var gratis: Array = [MONEDAS, 40 + (i / 5) * 10]
		var pro: Array = [MONEDAS, 90 + (i / 5) * 20]
		# Cada cinco escalones, un empujon de experiencia en vez de monedas.
		if i % 5 == 0:
			gratis = [EXP, 150]
		t[i] = [gratis, pro]
	return t


func _armar_temporada_0() -> Dictionary:
	var t := _base()
	# La primera de la via pro esta en el escalon 3 y no en el 30: el que compra tiene que
	# recibir algo enseguida, porque si su primera recompensa esta a veinte partidas, lo
	# que compro se parece demasiado a nada.
	_poner(t, 3, null, [SKIN, "dio_dorado"])
	_poner(t, 7, [SKIN, "flowery_nocturno"], null)
	_poner(t, 10, null, [SKIN, "noelle_snowgrave"])
	_poner(t, 14, null, [SKIN, "rick_maligno"])
	_poner(t, 18, [SKIN, "rick_cosmico"], null)
	_poner(t, 22, null, [SKIN, "flowery_omega"])
	_poner(t, 26, null, [SKIN, "dio_vampiro"])
	_poner(t, 24, null, [SKIN, "rick_pickle"])
	_poner(t, 30, [MONEDAS, 500], [SKIN, "sonic_super"])
	return t


func _armar_temporada_1() -> Dictionary:
	var t := _base()
	# Mismo reparto que la 0: la primera pro enseguida, las legendarias al final, y dos
	# skins en la via gratuita para que el que no paga igual se lleve algo propio.
	_poner(t, 3, null, [SKIN, "sonic_metal"])
	_poner(t, 7, [SKIN, "noelle_otono"], null)
	_poner(t, 10, null, [SKIN, "flowery_primavera"])
	_poner(t, 14, null, [SKIN, "rick_toxico"])
	_poner(t, 18, [SKIN, "dio_blanco"], null)
	_poner(t, 22, null, [SKIN, "noelle_aurora"])
	_poner(t, 26, null, [SKIN, "dio_cielo"])
	# EL ULTIMO ESCALON DEL PRO ES GOKU, y es lo UNICO que lo desbloquea: no se vende ni
	# sale de ningun otro lado. Completar el pase pro entero es la condicion, tal cual.
	_poner(t, 30, [MONEDAS, 500], [PERSONAJE, "goku"])
	return t


func _armar_temporada_2() -> Dictionary:
	var t := _base()
	# El mismo reparto que la 1 y la 0.
	_poner(t, 3, null, [SKIN, "mario_hielo"])
	_poner(t, 7, [SKIN, "sonic_boom"], null)
	_poner(t, 10, null, [SKIN, "dio_phantom"])
	_poner(t, 14, null, [SKIN, "flowery_asgore"])
	_poner(t, 18, [SKIN, "madara_joven"], null)
	_poner(t, 22, null, [SKIN, "noelle_cyber"])
	_poner(t, 26, null, [SKIN, "sonic_hyper"])
	# EL ULTIMO ESCALON DEL PRO ES MOB, como Goku en la 1: es lo unico que lo desbloquea.
	_poner(t, 30, [MONEDAS, 500], [PERSONAJE, "mob"])
	return t


func _poner(t: Dictionary, escalon: int, gratis: Variant, pro: Variant) -> void:
	var fila: Array = t.get(escalon, [[NADA, 0], [NADA, 0]])
	if gratis != null:
		fila[0] = gratis
	if pro != null:
		fila[1] = pro
	t[escalon] = fila


# ---------------------------------------------------------- Cierre de temporada

## Si el archivo es de una temporada anterior, la cierra.
##
## LO QUE SE ALCANZO Y NO SE COBRO, SE COBRA SOLO. Es lo unico justo: esas recompensas ya
## estaban ganadas —el jugador llego al escalon, y si era pro, pago el pase—, y que una
## temporada termine no puede ser la forma de quitarselas. Despues el pase arranca de cero:
## la experiencia, el pro y lo reclamado son de una temporada, no del jugador.
##
## LO QUE NO SE TOCA: nivel, monedas, skins, personajes. Eso es del jugador.
func _cerrar_temporada_vieja() -> void:
	if Progreso.temporada < 0:
		# Instalacion nueva: no hay nada viejo que cerrar.
		Progreso.temporada = TEMPORADA
		return
	if Progreso.temporada >= TEMPORADA:
		return
	var vieja := Progreso.temporada
	var cobradas := cobrar_pendientes(_viejas.get(vieja, {}))
	var tenia_pro := Progreso.pase_pro
	Progreso.pase_exp = 0
	Progreso.pase_pro = false
	Progreso.reclamados = {}
	Progreso.temporada = TEMPORADA
	Progreso.guardar()
	Progreso.cambio.emit()
	aviso_cierre = "Terminó la Temporada %d y empezó la Temporada %d: Fuerza Psíquica." % [vieja, TEMPORADA]
	# El premio de la 1 queda para todos (ver CharacterDB: Goku ya no pide desbloqueo).
	if vieja <= 1:
		aviso_cierre += " Goku ahora es de todos: ya lo podés elegir."
	if cobradas > 0:
		aviso_cierre += " Se cobraron solas %d recompensas que tenías pendientes." % cobradas
	if tenia_pro:
		aviso_cierre += " El pase pro es por temporada: el de la %d se compra aparte." % TEMPORADA


## Cobra lo alcanzado y no reclamado de una tabla. Devuelve cuantas cobro.
func cobrar_pendientes(tabla: Dictionary) -> int:
	var hasta := clampi(Progreso.pase_exp / EXP_POR_ESCALON, 0, ESCALONES)
	var n := 0
	for i: int in range(1, hasta + 1):
		for pro: bool in [false, true]:
			if pro and not Progreso.pase_pro:
				continue
			if Progreso.reclamados.get(_clave(i, pro), false):
				continue
			var fila: Array = tabla.get(i, [[NADA, 0], [NADA, 0]])
			if _dar(fila[1] if pro else fila[0]).is_empty():
				continue
			Progreso.reclamados[_clave(i, pro)] = true
			n += 1
	return n


## El aviso de cierre, una sola vez: el que lo muestra se lo lleva.
func tomar_aviso() -> String:
	var a := aviso_cierre
	aviso_cierre = ""
	return a


# ----------------------------------------------------------------- Consultas

## En que escalon esta el jugador. 0 = todavia no llego al primero.
func escalon_actual() -> int:
	return clampi(Progreso.pase_exp / EXP_POR_ESCALON, 0, ESCALONES)


## Cuanto le falta para el siguiente, de 0 a 1.
func progreso_escalon() -> float:
	if escalon_actual() >= ESCALONES:
		return 1.0
	return float(Progreso.pase_exp % EXP_POR_ESCALON) / float(EXP_POR_ESCALON)


func recompensa(escalon: int, pro: bool) -> Array:
	var fila: Array = _tabla.get(escalon, [[NADA, 0], [NADA, 0]])
	return fila[1] if pro else fila[0]


func _clave(escalon: int, pro: bool) -> String:
	return "%d%s" % [escalon, "p" if pro else ""]


func reclamada(escalon: int, pro: bool) -> bool:
	return Progreso.reclamados.get(_clave(escalon, pro), false)


## Se puede cobrar? Hay que haber llegado, no haberla cobrado, y tener el pro si es pro.
func se_puede_reclamar(escalon: int, pro: bool) -> bool:
	if escalon < 1 or escalon > ESCALONES:
		return false
	if escalon > escalon_actual():
		return false
	if pro and not Progreso.pase_pro:
		return false
	if reclamada(escalon, pro):
		return false
	return (recompensa(escalon, pro)[0] as StringName) != NADA


## Cuantos escalones faltan para el final.
func escalones_restantes() -> int:
	return ESCALONES - escalon_actual()


## Compra un escalon: el pase sube uno, como si se hubiera jugado.
##
## SUBE EL PASE Y NADA MAS. El nivel del jugador no se toca: es el numero de lo que jugo,
## y comprarlo le haria mentir. Tampoco cobra nada solo: el escalon queda alcanzado y se
## reclama como cualquier otro, asi el jugador ve que le toco.
func comprar_escalon() -> bool:
	if escalon_actual() >= ESCALONES:
		return false
	if not Progreso.gastar_monedas(Progreso.PRECIO_ESCALON):
		return false
	# Sobre la experiencia que ya habia, no redondeando al escalon: si ibas por la mitad
	# del 5, quedas en la mitad del 6. Redondear para abajo te cobraria media partida.
	Progreso.pase_exp = mini(Progreso.pase_exp + EXP_POR_ESCALON, ESCALONES * EXP_POR_ESCALON)
	Progreso.subio_pase.emit(escalon_actual())
	Progreso.guardar()
	Progreso.cambio.emit()
	return true


## Cobra una recompensa. Devuelve un texto para mostrar, o "" si no se pudo.
func reclamar(escalon: int, pro: bool) -> String:
	if not se_puede_reclamar(escalon, pro):
		return ""
	var texto := _dar(recompensa(escalon, pro))
	if texto.is_empty():
		return ""
	Progreso.reclamados[_clave(escalon, pro)] = true
	Progreso.guardar()
	Progreso.cambio.emit()
	return texto


## Entrega una recompensa. Devuelve el texto de lo que dio, o "" si no dio nada.
func _dar(r: Array) -> String:
	match r[0] as StringName:
		MONEDAS:
			Progreso.sumar_monedas(int(r[1]))
			return "+%d monedas" % int(r[1])
		EXP:
			# OJO: sumar_exp tambien suma al pase, asi que una recompensa de experiencia
			# empuja el propio pase. Es a proposito —se siente bien— pero no puede ser la
			# recompensa de TODOS los escalones o el pase se cobraria solo.
			Progreso.sumar_exp(int(r[1]))
			return "+%d de experiencia" % int(r[1])
		SKIN:
			var skin := SkinDB.get_skin(StringName(r[1]))
			if skin == null:
				return ""
			Progreso.desbloquear_skin(skin.id)
			return skin.display_name
		PERSONAJE:
			var id := StringName(r[1])
			if not CharacterDB.has_character(id):
				return ""
			Progreso.desbloquear_personaje(id)
			return "¡%s desbloqueado!" % CharacterDB.get_character(id).display_name
	return ""


## Cobra todo lo que este disponible de una. Devuelve cuantas cosas cobro.
##
## Existe porque sin esto un jugador que vuelve despues de una semana tiene que apretar
## cuarenta botones antes de poder jugar.
func reclamar_todo() -> int:
	var n := 0
	for i: int in range(1, ESCALONES + 1):
		for pro: bool in [false, true]:
			if se_puede_reclamar(i, pro) and not reclamar(i, pro).is_empty():
				n += 1
	return n


func hay_algo_para_reclamar() -> bool:
	for i: int in range(1, ESCALONES + 1):
		if se_puede_reclamar(i, false) or se_puede_reclamar(i, true):
			return true
	return false


## Comprar el pase pro. Devuelve false si no alcanzan las monedas.
func comprar_pro() -> bool:
	if Progreso.pase_pro:
		return false
	if not Progreso.gastar_monedas(Progreso.PRECIO_PASE_PRO):
		return false
	Progreso.pase_pro = true
	Progreso.guardar()
	Progreso.cambio.emit()
	return true


## Texto corto de una recompensa, para el recuadro del escalon.
func describir(escalon: int, pro: bool) -> String:
	var r := recompensa(escalon, pro)
	match r[0] as StringName:
		MONEDAS:
			return "%d monedas" % int(r[1])
		EXP:
			return "%d EXP" % int(r[1])
		SKIN:
			var s := SkinDB.get_skin(StringName(r[1]))
			return s.display_name if s != null else "?"
		PERSONAJE:
			var id := StringName(r[1])
			if not CharacterDB.has_character(id):
				return "?"
			return "PERSONAJE: %s" % CharacterDB.get_character(id).display_name.to_upper()
	return "—"
