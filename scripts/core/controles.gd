extends Node
## Autoload: Controles
## Teclas reasignables. Se guardan en user://controles.cfg.
##
## GameConfig registra las teclas de fabrica al arrancar y esto las pisa con las que el
## jugador haya elegido. Todo el juego lee acciones del InputMap —nadie pregunta por una
## tecla concreta— asi que cambiar el InputMap alcanza para que valga en todos lados.
##
## Y TODO LO QUE MUESTRA UNA TECLA LE PREGUNTA A ESTE ARCHIVO: el HUD, el lobby, las
## opciones. Antes decian "Click izq", "E", "[Shift]" escrito a mano, y con controles
## reasignables eso pasa a ser mentira en el momento en que alguien cambia uno.
##
## ARCHIVO PROPIO y no una seccion de settings.cfg: Settings escribe su archivo entero de
## cero cada vez que guarda, y se llevaria puestas las teclas cada vez que alguien mueve
## el volumen.

const RUTA: String = "user://controles.cfg"

signal cambio()

## Las acciones que se pueden cambiar, en el orden en que se muestran, con su nombre.
##
## ESCAPE NO ESTA, a proposito: es la salida de todos los menus. Si se pudiera reasignar,
## alguien lo pone en otra cosa sin querer y se queda encerrado en una pantalla sin forma
## de volver.
const ACCIONES: Array = [
	["move_forward", "Avanzar"],
	["move_back", "Retroceder"],
	["move_left", "Izquierda"],
	["move_right", "Derecha"],
	["jump", "Saltar"],
	["dash", "Dash"],
	["sprint", "Correr (con el auto-correr apagado)"],
	["attack_basic", "Golpe básico"],
	["ability_1", "Habilidad 1"],
	["ability_2", "Habilidad 2"],
	["ability_ultimate", "Definitiva"],
	["scoreboard", "Tabla de puntos"],
	["practice_panel", "Panel de práctica"],
]

## Para el arnes: con esto en false, las pruebas reasignan teclas sin pisar las del jugador
## que las corre. Mismo motivo que Progreso.guardado_activo.
var guardado_activo: bool = true
## Donde se guarda. Es variable y no constante solo para que el arnes pruebe el guardado
## contra un archivo propio y no contra las teclas reales de quien lo corre.
var ruta_archivo: String = RUTA


func _ready() -> void:
	# La cache se borra ANTES que cualquier otro que escuche `cambio` pregunte: conectada
	# primero, corre primero.
	cambio.connect(func() -> void: _cache_nombres.clear())
	# GameConfig es autoload y arranca antes: las de fabrica ya estan puestas.
	cargar()


func es_reasignable(accion: StringName) -> bool:
	for fila: Array in ACCIONES:
		if StringName(fila[0]) == accion:
			return true
	return false


func nombre_accion(accion: StringName) -> String:
	for fila: Array in ACCIONES:
		if StringName(fila[0]) == accion:
			return fila[1]
	return String(accion)


## El evento principal de una accion: el primero de su lista.
func evento_de(accion: StringName) -> InputEvent:
	if not InputMap.has_action(accion):
		return null
	var eventos := InputMap.action_get_events(accion)
	return eventos[0] if not eventos.is_empty() else null


## Los nombres ya calculados. Se borran con cada cambio de tecla.
##
## HACE FALTA: el HUD pregunta el nombre de la tecla del dash TODOS LOS FRAMES, y armarlo
## pasa por el sistema operativo. Sesenta veces por segundo para una palabra que no cambia.
var _cache_nombres: Dictionary = {}


## Como se llama, para mostrarla, la tecla de una accion.
func nombre_tecla(accion: StringName) -> String:
	if not _cache_nombres.has(accion):
		_cache_nombres[accion] = nombre_evento(evento_de(accion))
	return _cache_nombres[accion]


## Se puede preguntar la distribucion del teclado aca?
##
## SOLO EN ESCRITORIO CON PANTALLA. Godot lo documenta: la funcion existe en Windows, macOS
## y Linux, y en ningun otro lado. En el navegador —que es donde juega la mayoria, porque
## es lo que esta en itch— y en el servidor sin pantalla, llamarla no devuelve nada Y ADEMAS
## tira un error con su traza completa. Paso: con el HUD preguntando cada frame, el log se
## llenaba de errores a sesenta por segundo y la partida se ponia mas lenta.
static func _puede_leer_distribucion() -> bool:
	if OS.has_feature("web"):
		return false
	var ds := DisplayServer.get_name()
	return ds != "headless" and ds != "" and 		(OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linuxbsd"))


## LA TECLA SE NOMBRA COMO LA VE EL JUGADOR, no como esta guardada.
##
## Se guardan teclas FISICAS —el lugar en el teclado— para que WASD quede donde esta en
## cualquier distribucion. Pero en un teclado frances esa misma posicion dice "Z" y no
## "W", y mostrarle "W" a alguien cuyo teclado dice "Z" es mostrarle una tecla que no
## tiene. Se traduce la posicion a la letra de su distribucion antes de nombrarla.
static func nombre_evento(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	var mb := ev as InputEventMouseButton
	if mb != null:
		match mb.button_index:
			MOUSE_BUTTON_LEFT: return "Click izq"
			MOUSE_BUTTON_RIGHT: return "Click der"
			MOUSE_BUTTON_MIDDLE: return "Click rueda"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %d" % mb.button_index
	var k := ev as InputEventKey
	if k == null:
		return "?"
	var codigo := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	# En el servidor sin pantalla no hay distribucion que consultar y esto devuelve nada:
	# se cae al nombre de la posicion, que para una tecla de letra es lo mismo.
	if _puede_leer_distribucion():
		var visible_en_su_teclado := DisplayServer.keyboard_get_keycode_from_physical(codigo)
		if visible_en_su_teclado != KEY_NONE:
			codigo = visible_en_su_teclado
	var nombre := OS.get_keycode_string(codigo)
	match nombre:
		"Space": return "Espacio"
		"Ctrl": return "Ctrl"
		"Shift": return "Shift"
		"Alt": return "Alt"
		"Tab": return "Tab"
		"Enter": return "Enter"
		"BackSpace", "Backspace": return "Borrar"
		"CapsLock": return "Bloq Mayús"
		"Up": return "↑"
		"Down": return "↓"
		"Left": return "←"
		"Right": return "→"
	return nombre if not nombre.is_empty() else "?"


## Se acepta este evento como tecla? Filtra lo que no puede ser un control.
static func es_valido(ev: InputEvent) -> bool:
	var k := ev as InputEventKey
	if k != null:
		if not k.pressed or k.echo:
			return false
		var codigo := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		# Escape queda afuera: es la salida de los menus.
		return codigo != KEY_NONE and codigo != KEY_ESCAPE
	var mb := ev as InputEventMouseButton
	if mb != null:
		if not mb.pressed:
			return false
		# LA RUEDA NO. Un giro de rueda llega como apretar y soltar en el mismo instante,
		# y las acciones que se mantienen —caminar, correr— quedarian sin poder usarse.
		return mb.button_index != MOUSE_BUTTON_WHEEL_UP \
			and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN \
			and mb.button_index != MOUSE_BUTTON_WHEEL_LEFT \
			and mb.button_index != MOUSE_BUTTON_WHEEL_RIGHT
	return false


## Un evento limpio a partir del que llego: solo lo que identifica la tecla.
##
## El que llega trae posicion del mouse, modificadores, si estaba apretado... y si se lo
## guarda asi, el InputMap exige que coincida TODO: una tecla guardada con Shift apretado
## solo responderia con Shift apretado.
static func limpiar(ev: InputEvent) -> InputEvent:
	var k := ev as InputEventKey
	if k != null:
		var nuevo := InputEventKey.new()
		nuevo.physical_keycode = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		return nuevo
	var mb := ev as InputEventMouseButton
	if mb != null:
		var nuevo_mb := InputEventMouseButton.new()
		nuevo_mb.button_index = mb.button_index
		return nuevo_mb
	return null


static func _mismo(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## Asigna una tecla. Devuelve el nombre de la accion con la que se intercambio, o "".
##
## SI LA TECLA YA ERA DE OTRA ACCION, SE INTERCAMBIAN, no se duplica ni se rechaza. Poner
## Espacio en el dash cuando Espacio era saltar deja el salto con la tecla vieja del dash.
## Las otras dos salidas son peores: duplicar hace que una tecla dispare dos cosas a la
## vez, y rechazar obliga a liberar primero la tecla en otra fila, que nadie entiende por
## que tiene que hacer.
func reasignar(accion: StringName, ev: InputEvent) -> String:
	if not es_reasignable(accion) or not es_valido(ev):
		return ""
	var nuevo := limpiar(ev)
	var viejo := evento_de(accion)
	var intercambiada := ""
	for fila: Array in ACCIONES:
		var otra := StringName(fila[0])
		if otra == accion:
			continue
		for e: InputEvent in InputMap.action_get_events(otra):
			if _mismo(e, nuevo):
				InputMap.action_erase_events(otra)
				if viejo != null:
					InputMap.action_add_event(otra, viejo)
				intercambiada = fila[1]
				break
		if not intercambiada.is_empty():
			break
	InputMap.action_erase_events(accion)
	InputMap.action_add_event(accion, nuevo)
	guardar()
	cambio.emit()
	return intercambiada


## Vuelve la MEMORIA a fabrica sin tocar el archivo. Para el arnes: hace falta poder
## simular "cerrar y volver a abrir el juego" —memoria de fabrica, archivo intacto— y
## restablecer() borra el archivo, que es justo lo que no se quiere ahi.
func restablecer_sin_borrar_archivo_para_prueba() -> void:
	var antes := guardado_activo
	guardado_activo = false
	restablecer()
	guardado_activo = antes


## Vuelve todo a las de fabrica, las de GameConfig.
func restablecer() -> void:
	for fila: Array in ACCIONES:
		var accion := StringName(fila[0])
		if not InputMap.has_action(accion):
			continue
		InputMap.action_erase_events(accion)
		for codigo: int in GameConfig.BINDINGS.get(String(accion), []):
			var k := InputEventKey.new()
			k.physical_keycode = codigo
			InputMap.action_add_event(accion, k)
		if GameConfig.MOUSE_BINDINGS.has(String(accion)):
			var mb := InputEventMouseButton.new()
			mb.button_index = GameConfig.MOUSE_BINDINGS[String(accion)]
			InputMap.action_add_event(accion, mb)
	if guardado_activo:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_archivo))
	cambio.emit()


# ------------------------------------------------------------------ Guardado
#
# Cada tecla se guarda como un diccionario chico y no como el InputEvent entero:
# ConfigFile puede serializar un InputEvent, pero con todos sus campos, y cualquier
# cambio de version del motor en esos campos haria que el archivo viejo no cargue.

func guardar() -> void:
	if not guardado_activo:
		return
	var cfg := ConfigFile.new()
	for fila: Array in ACCIONES:
		var ev := evento_de(StringName(fila[0]))
		if ev is InputEventKey:
			cfg.set_value("controles", fila[0], {"tecla": (ev as InputEventKey).physical_keycode})
		elif ev is InputEventMouseButton:
			cfg.set_value("controles", fila[0], {"mouse": (ev as InputEventMouseButton).button_index})
	cfg.save(ruta_archivo)


func cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ruta_archivo) != OK:
		return
	for fila: Array in ACCIONES:
		var accion := StringName(fila[0])
		if not cfg.has_section_key("controles", fila[0]) or not InputMap.has_action(accion):
			continue
		var dato: Variant = cfg.get_value("controles", fila[0])
		if not dato is Dictionary:
			continue
		var ev: InputEvent = null
		if (dato as Dictionary).has("tecla"):
			var k := InputEventKey.new()
			k.physical_keycode = int(dato["tecla"])
			ev = k
		elif (dato as Dictionary).has("mouse"):
			var mb := InputEventMouseButton.new()
			mb.button_index = int(dato["mouse"])
			ev = mb
		# Un archivo tocado a mano puede traer cualquier cosa: si no sirve como control, se
		# queda la de fabrica en vez de dejar la accion sin tecla.
		if ev == null or (ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_ESCAPE):
			continue
		InputMap.action_erase_events(accion)
		InputMap.action_add_event(accion, ev)
	cambio.emit()
