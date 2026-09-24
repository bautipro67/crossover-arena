extends Node
## Autoload: Progreso
## Nivel, monedas y pase de temporada. Se guarda en user://progreso.cfg.
##
## NO TOCA LA JUGABILIDAD, Y ESO ES UNA REGLA DURA, NO UNA INTENCION.
##
## Nada de este archivo devuelve daño, vida, velocidad ni cooldowns, y ningun script de
## combate lo lee. Un jugador de nivel 40 pega exactamente igual que uno de nivel 1, y una
## skin comprada no cambia ni un punto de nada. El arnes lo verifica: si alguien engancha
## esto a una estadistica, el test falla.
##
## El motivo no es purismo. Es un juego de PvP gratuito: en el momento en que subir de
## nivel o pagar da ventaja, el que recien entra ya perdio antes de empezar, y no hay
## progresion que compense eso.
##
## LO QUE SI HACE: dar motivos para volver. Un nivel que sube, monedas que se juntan
## matando, y treinta escalones de pase con cosas para desbloquear.

const RUTA: String = "user://progreso.cfg"

signal cambio()
signal subio_nivel(nivel: int)
signal subio_pase(escalon: int)
signal monedas_cambiaron(monedas: int)

# ------------------------------------------------------------------ Economia
#
# Los numeros salen de una cuenta, no de la nada: una partida tipica son 5-8 bajas, o sea
# unas 100 monedas. El pase pro sale 2500, que son unas 25 partidas. Es bastante, y tiene
# que serlo: si se compra en tres partidas deja de ser una meta a la segunda tarde.

## Monedas por baja. Es la unica fuente de monedas del juego.
const MONEDAS_POR_BAJA: int = 12
## Plus por ganar la partida.
const MONEDAS_POR_VICTORIA: int = 50
## Experiencia por baja, por victoria y por terminar una partida.
const EXP_POR_BAJA: int = 25
const EXP_POR_VICTORIA: int = 100
const EXP_POR_PARTIDA: int = 20
## Lo que cuesta el pase pro.
const PRECIO_PASE_PRO: int = 2500
## Lo que cuesta subir un escalon del pase sin jugarlo.
##
## 200 ES LO QUE SE GANA EN UNA PARTIDA Y MEDIA, que es lo que tarda en subirse un escalon
## jugando (250 de experiencia a unos 170 por partida). A ese precio comprar no es un
## atajo sobre jugar: es cambiar monedas que ya ganaste por avance en vez de por skins.
## Mas barato, el pase se compraria entero con lo que sobra de una semana y dejaria de
## ser algo que se juega.
const PRECIO_ESCALON: int = 200
## Tope de nivel. No es un limite real de nada, es para que la barra signifique algo.
const NIVEL_MAXIMO: int = 60

var nivel: int = 1
var exp_actual: int = 0
var monedas: int = 0
var pase_pro: bool = false
var pase_exp: int = 0
## Escalones ya cobrados, para no darlos dos veces. Guarda claves "5" y "5p" (la pro).
var reclamados: Dictionary = {}
## skin_id -> true
var skins: Dictionary = {}
## character_id -> skin_id equipada
var equipadas: Dictionary = {}
## Los personajes que hubo que ganarse y ya estan ganados: character_id -> true. Los de
## fabrica no figuran aca; ver puede_usar_personaje().
var personajes: Dictionary = {}
## De que temporada es el pase guardado. -1 = no habia archivo (instalacion nueva).
##
## Hace falta para cerrar una temporada: si el archivo es de la 0 y el juego ya va por la
## 1, Pase cobra lo pendiente de la vieja y arranca la nueva de cero. Sin este numero no
## hay forma de distinguir "avance de esta temporada" de "avance de la anterior".
var temporada: int = -1
## Cuando esta en false, guardar() no escribe nada.
##
## EXISTE PARA EL ARNES, y no es un lujo: los tests suben de nivel, gastan monedas y
## compran skins a proposito, y guardan en el MISMO user://progreso.cfg que el jugador.
## Sin esto, correr las pruebas una vez le borraba a quien las corre su nivel, sus monedas
## y todo lo que hubiera desbloqueado. Un arnes no puede cobrarse eso.
var guardado_activo: bool = true

## MODO DESARROLLADOR: monedas infinitas, para probar skins sin tener que jugar horas.
##
## SE PRENDE CON UN ARCHIVO, no con una opcion ni con un argumento, y es a proposito. El
## .exe de Windows es el MISMO que baja cualquiera de itch.io, asi que cualquier cosa
## escrita en el codigo —una constante, una opcion en el menu— la tendrian todos. Un
## archivo en la carpeta de datos del juego existe solo en la maquina donde alguien lo
## puso: en las demas, este codigo lee que no esta y no hace nada.
##
## (Y no rompe ninguna economia: las monedas son locales y solo compran cosmeticos. Quien
## quiera hacer trampa puede editar progreso.cfg a mano desde siempre; esto no le abre
## ninguna puerta que no estuviera abierta.)
const MARCA_DEV: String = "user://modo_desarrollador"
var modo_dev: bool = false
var bajas_totales: int = 0
var partidas_jugadas: int = 0
var victorias: int = 0


func _ready() -> void:
	cargar()
	detectar_modo_dev()


func detectar_modo_dev() -> void:
	modo_dev = FileAccess.file_exists(MARCA_DEV)
	if modo_dev:
		print("[progreso] modo desarrollador: monedas infinitas")


# ------------------------------------------------------------------- Niveles

## Cuanta experiencia cuesta pasar del nivel `n` al siguiente.
##
## Crece despacio y en linea recta. Una curva exponencial hace que los primeros niveles
## vuelen y los ultimos sean inalcanzables, y en un juego sin ventaja por nivel eso solo
## sirve para que la barra deje de moverse.
static func exp_para_nivel(n: int) -> int:
	return 100 + (n - 1) * 45


func exp_faltante() -> int:
	return maxi(0, exp_para_nivel(nivel) - exp_actual)


func progreso_nivel() -> float:
	var total := exp_para_nivel(nivel)
	return clampf(float(exp_actual) / float(maxi(1, total)), 0.0, 1.0)


## Suma experiencia y sube de nivel las veces que haga falta.
##
## El bucle importa: al terminar una partida buena entran 200 o 300 de una, y con un solo
## "if" el sobrante se perderia o el jugador quedaria con la barra llena sin subir.
func sumar_exp(cantidad: int) -> void:
	if cantidad <= 0:
		return
	exp_actual += cantidad
	pase_exp += cantidad
	var subio := false
	while nivel < NIVEL_MAXIMO and exp_actual >= exp_para_nivel(nivel):
		exp_actual -= exp_para_nivel(nivel)
		nivel += 1
		subio = true
		subio_nivel.emit(nivel)
	if nivel >= NIVEL_MAXIMO:
		exp_actual = 0
	if subio:
		guardar()
	cambio.emit()


# ------------------------------------------------------------------- Monedas

func sumar_monedas(cantidad: int) -> void:
	if cantidad <= 0:
		return
	monedas += cantidad
	monedas_cambiaron.emit(monedas)
	cambio.emit()


## Alcanza la plata para esto? Toda la interfaz pregunta ACA y no compara monedas a mano:
## si comparara, el modo desarrollador mostraria los botones de comprar apagados aunque la
## compra fuera a salir bien.
func alcanza(cantidad: int) -> bool:
	return modo_dev or monedas >= cantidad


## Devuelve false si no alcanza. El que llama TIENE que mirar el resultado: es lo unico
## que evita regalar una skin porque el boton se apreto dos veces.
func gastar_monedas(cantidad: int) -> bool:
	if cantidad < 0:
		return false
	# En modo desarrollador la compra sale y el saldo no se toca: "infinitas" quiere decir
	# que no se gastan, no que haya un numero muy grande que algun dia se termina.
	if modo_dev:
		cambio.emit()
		return true
	if monedas < cantidad:
		return false
	monedas -= cantidad
	monedas_cambiaron.emit(monedas)
	cambio.emit()
	guardar()
	return true


# ------------------------------------------------------- Lo que pasa al jugar

## Una baja. La llama el servidor cuando alguien mata a alguien.
##
## `cuenta` viene en false en la sala de practica, y ese es el unico lugar donde no paga.
## Sin eso, "monedas por baja" seria "monedas por quedarse quieto con cinco maniquies
## invencibles que reaparecen solos", y no habria ninguna razon para jugar el resto.
func registrar_baja(cuenta: bool) -> void:
	if not cuenta:
		return
	bajas_totales += 1
	sumar_monedas(MONEDAS_POR_BAJA)
	sumar_exp(EXP_POR_BAJA)


func registrar_partida(gano: bool, cuenta: bool) -> void:
	if not cuenta:
		return
	partidas_jugadas += 1
	var exp_total := EXP_POR_PARTIDA
	if gano:
		victorias += 1
		exp_total += EXP_POR_VICTORIA
		sumar_monedas(MONEDAS_POR_VICTORIA)
	sumar_exp(exp_total)
	guardar()


# ---------------------------------------------------------------------- Skins

func tiene_skin(skin_id: StringName) -> bool:
	return skins.get(String(skin_id), false)


func desbloquear_skin(skin_id: StringName) -> void:
	if skin_id == &"":
		return
	skins[String(skin_id)] = true
	cambio.emit()
	guardar()


## Que skin tiene puesta un personaje. &"" = la de fabrica.
func skin_de(character_id: StringName) -> StringName:
	return StringName(equipadas.get(String(character_id), ""))


func equipar_skin(character_id: StringName, skin_id: StringName) -> void:
	if skin_id != &"" and not tiene_skin(skin_id):
		return
	if skin_id == &"":
		equipadas.erase(String(character_id))
	else:
		equipadas[String(character_id)] = String(skin_id)
	cambio.emit()
	guardar()


# ------------------------------------------------------------------ Personajes

## Se puede elegir este personaje? Los de fabrica siempre; los que hay que ganarse, solo
## si ya se ganaron.
func puede_usar_personaje(character_id: StringName) -> bool:
	if not CharacterDB.has_character(character_id):
		return false
	var data := CharacterDB.get_character(character_id)
	return not data.requiere_desbloqueo or personajes.get(String(character_id), false)


func desbloquear_personaje(character_id: StringName) -> void:
	if not CharacterDB.has_character(character_id):
		return
	personajes[String(character_id)] = true
	cambio.emit()
	guardar()


# ------------------------------------------------------------------ Guardado

func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RUTA) != OK:
		return
	nivel = clampi(int(cfg.get_value("nivel", "nivel", 1)), 1, NIVEL_MAXIMO)
	exp_actual = maxi(0, int(cfg.get_value("nivel", "exp", 0)))
	monedas = maxi(0, int(cfg.get_value("economia", "monedas", 0)))
	pase_pro = bool(cfg.get_value("pase", "pro", false))
	pase_exp = maxi(0, int(cfg.get_value("pase", "exp", 0)))
	reclamados = cfg.get_value("pase", "reclamados", {}) as Dictionary
	skins = cfg.get_value("skins", "desbloqueadas", {}) as Dictionary
	equipadas = cfg.get_value("skins", "equipadas", {}) as Dictionary
	personajes = cfg.get_value("personajes", "desbloqueados", {}) as Dictionary
	# Un archivo sin temporada es de la 0: es la unica que existio antes de este campo.
	temporada = int(cfg.get_value("pase", "temporada", 0))
	bajas_totales = maxi(0, int(cfg.get_value("stats", "bajas", 0)))
	partidas_jugadas = maxi(0, int(cfg.get_value("stats", "partidas", 0)))
	victorias = maxi(0, int(cfg.get_value("stats", "victorias", 0)))


func guardar() -> void:
	if not guardado_activo:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("nivel", "nivel", nivel)
	cfg.set_value("nivel", "exp", exp_actual)
	cfg.set_value("economia", "monedas", monedas)
	cfg.set_value("pase", "pro", pase_pro)
	cfg.set_value("pase", "exp", pase_exp)
	cfg.set_value("pase", "reclamados", reclamados)
	cfg.set_value("skins", "desbloqueadas", skins)
	cfg.set_value("skins", "equipadas", equipadas)
	cfg.set_value("personajes", "desbloqueados", personajes)
	cfg.set_value("pase", "temporada", temporada)
	cfg.set_value("stats", "bajas", bajas_totales)
	cfg.set_value("stats", "partidas", partidas_jugadas)
	cfg.set_value("stats", "victorias", victorias)
	cfg.save(RUTA)


## Borra todo. La usa el arnes para no correr sobre el progreso real de quien lo ejecuta.
func borrar_todo() -> void:
	nivel = 1
	exp_actual = 0
	monedas = 0
	pase_pro = false
	pase_exp = 0
	reclamados = {}
	skins = {}
	equipadas = {}
	personajes = {}
	temporada = Pase.TEMPORADA
	bajas_totales = 0
	partidas_jugadas = 0
	victorias = 0
	cambio.emit()
