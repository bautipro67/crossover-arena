extends Node
## Autoload: Pase
## Pase de Temporada 0. Treinta escalones, dos vias: la gratuita y la pro.
##
## LAS DOS VIAS AVANZAN CON LA MISMA EXPERIENCIA. Comprar el pro no acelera nada: abre la
## fila de abajo, incluidas las recompensas de los escalones que ya pasaste. Es lo que
## evita que comprarlo tarde se sienta un castigo, y es la unica forma de que la decision
## de comprarlo no sea una carrera contra el reloj.
##
## Y NADA DE LO QUE DA AFECTA UNA PARTIDA: skins, monedas y experiencia. Las monedas solo
## compran mas skins, y la experiencia solo mueve estas mismas barras. Un circuito cerrado
## que empieza y termina en lo cosmetico, a proposito.

const TEMPORADA: int = 0
const NOMBRE: String = "TEMPORADA 0 — APERTURA"
const ESCALONES: int = 30
## Experiencia por escalon. 250 x 30 = 7500 para el pase entero, que a unos 170 por
## partida son unas 45 partidas. Una temporada tiene que durar, pero tiene que terminarse.
const EXP_POR_ESCALON: int = 250

## Tipos de recompensa.
const MONEDAS: StringName = &"monedas"
const EXP: StringName = &"exp"
const SKIN: StringName = &"skin"
const NADA: StringName = &"nada"

## escalon -> [recompensa gratuita, recompensa pro].
## Cada recompensa es [tipo, valor]. El valor es una cantidad o un id de skin.
##
## LA VIA GRATUITA NO ESTA VACIA, y eso importa mas de lo que parece: un pase donde la
## fila de arriba es toda "nada" no es un pase, es un cartel de venta. Aca da monedas en
## casi todos los escalones y dos skins propias, asi que el que no paga igual junta para
## comprarse algo en la tienda.
var _tabla: Dictionary = {}


func _ready() -> void:
	_armar_tabla()


func _armar_tabla() -> void:
	# Por defecto: monedas en la gratuita, mas monedas en la pro.
	for i: int in range(1, ESCALONES + 1):
		var gratis: Array = [MONEDAS, 40 + (i / 5) * 10]
		var pro: Array = [MONEDAS, 90 + (i / 5) * 20]
		# Cada cinco escalones, un empujon de experiencia en vez de monedas.
		if i % 5 == 0:
			gratis = [EXP, 150]
		_tabla[i] = [gratis, pro]

	# Las skins, repartidas para que siempre haya una cerca.
	#
	# La primera de la via pro esta en el escalon 3 y no en el 30: el que compra tiene que
	# recibir algo enseguida, porque si su primera recompensa esta a veinte partidas, lo
	# que compro se parece demasiado a nada.
	_poner(3, null, [SKIN, "dio_dorado"])
	_poner(7, [SKIN, "flowery_nocturno"], null)
	_poner(10, null, [SKIN, "noelle_snowgrave"])
	_poner(14, null, [SKIN, "rick_maligno"])
	_poner(18, [SKIN, "rick_cosmico"], null)
	_poner(22, null, [SKIN, "flowery_omega"])
	_poner(26, null, [SKIN, "dio_vampiro"])
	_poner(24, null, [SKIN, "rick_pickle"])
	# El ultimo escalon es Sonic dorado: es la transformacion que cierra sus juegos, asi
	# que cierra el pase. Una recompensa final tiene que ser reconocible de lejos.
	_poner(30, [MONEDAS, 500], [SKIN, "sonic_super"])


func _poner(escalon: int, gratis: Variant, pro: Variant) -> void:
	var fila: Array = _tabla.get(escalon, [[NADA, 0], [NADA, 0]])
	if gratis != null:
		fila[0] = gratis
	if pro != null:
		fila[1] = pro
	_tabla[escalon] = fila


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


## Cobra una recompensa. Devuelve un texto para mostrar, o "" si no se pudo.
func reclamar(escalon: int, pro: bool) -> String:
	if not se_puede_reclamar(escalon, pro):
		return ""
	var r := recompensa(escalon, pro)
	var tipo := r[0] as StringName
	var texto := ""
	match tipo:
		MONEDAS:
			Progreso.sumar_monedas(int(r[1]))
			texto = "+%d monedas" % int(r[1])
		EXP:
			# OJO: sumar_exp tambien suma al pase, asi que una recompensa de experiencia
			# empuja el propio pase. Es a proposito —se siente bien— pero no puede ser la
			# recompensa de TODOS los escalones o el pase se cobraria solo.
			Progreso.sumar_exp(int(r[1]))
			texto = "+%d de experiencia" % int(r[1])
		SKIN:
			var skin := SkinDB.get_skin(StringName(r[1]))
			if skin == null:
				return ""
			Progreso.desbloquear_skin(skin.id)
			texto = skin.display_name
	Progreso.reclamados[_clave(escalon, pro)] = true
	Progreso.guardar()
	Progreso.cambio.emit()
	return texto


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
	return "—"
