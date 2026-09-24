extends Node
## Autoload: Mando
## Que los menus se puedan usar con un mando.
##
## Godot ya mueve el foco entre botones con la cruceta y el stick. Le faltaban tres cosas,
## y son las tres de este archivo:
##
##   1. UN PUNTO DE PARTIDA. Sin un boton con foco, la cruceta no tiene desde donde
##      moverse y no pasa nada. El primer toque del mando pone el foco en el primer boton
##      del menu de arriba.
##   2. UN ENCIERRO. Los menus se apilan —la tienda encima del menu principal— y Godot
##      busca el boton mas cercano en la pantalla entera: bajando desde la tienda, el foco
##      se iba al menu de atras, que se ve oscurecido pero sigue ahi.
##   3. VOLVER CON B. Cada menu marca su boton de volver y B lo aprieta.
##
## Los menus se anotan en el grupo "capa_menu" con su nodo raiz. El de arriba es el que se
## dibuja ultimo: el de CanvasLayer mas alto y, a igual capa, el que va despues en el arbol.

const GRUPO: StringName = &"capa_menu"
## El boton que B aprieta. Se marca con set_meta(Mando.META_VOLVER, true).
const META_VOLVER: StringName = &"volver"

const _NAVEGACION: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"ui_accept", &"ui_focus_next", &"ui_focus_prev"]


## Anota un menu. Para que el llamado quede en una linea en cada pantalla.
static func anotar(raiz: Control, volver: BaseButton = null) -> void:
	raiz.add_to_group(GRUPO)
	if volver != null:
		volver.set_meta(META_VOLVER, true)


func _input(event: InputEvent) -> void:
	# Solo el mando. El teclado y el mouse ya se manejaban solos, y el foco que pone esto
	# no tiene por que aparecerle a quien juega con el mouse.
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	# El aviso de "se esta usando el mando" lo da esto tambien. Hace falta: el primer toque
	# se consume aca para poner el foco, y Controles —que es quien lleva la cuenta— corre
	# despues y no se enteraba. Los carteles seguian diciendo "Click izq" hasta el segundo.
	var movio_el_stick: bool = event is InputEventJoypadMotion and absf(event.axis_value) > 0.5
	if (event is InputEventJoypadButton and event.pressed) or movio_el_stick:
		Controles.usar(&"mando")
	var capa := capa_de_arriba()
	if capa == null:
		return

	if event is InputEventJoypadButton and event.is_action_pressed(&"ui_cancel"):
		var volver := _boton_volver(capa)
		if volver != null:
			get_viewport().set_input_as_handled()
			volver.pressed.emit()
		return

	if not _es_navegacion(event):
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco == null or not capa.is_ancestor_of(foco):
		var primero := primer_foco(capa)
		if primero != null:
			primero.grab_focus()
			_mostrar(primero)
			# El primer toque solo pone el foco. Si ademas lo moviera, el boton que queda
			# marcado no seria el primero sino el de al lado, y parece que salto solo.
			get_viewport().set_input_as_handled()
		return
	# Ya hay foco adentro: lo mueve Godot, despues de esto. Recien entonces se puede ver
	# si se escapo del menu.
	_contener.call_deferred(capa, foco)


func _es_navegacion(event: InputEvent) -> bool:
	for accion: StringName in _NAVEGACION:
		if event.is_action_pressed(accion):
			return true
	return false


## Si el foco salio del menu de arriba, vuelve al boton de donde salio.
func _contener(capa: Control, anterior: Control) -> void:
	if not is_instance_valid(capa):
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco != null and not capa.is_ancestor_of(foco) and is_instance_valid(anterior) \
			and anterior.is_visible_in_tree():
		anterior.grab_focus()
		foco = anterior
	if foco != null:
		_mostrar(foco)


## El menu que esta arriba de todo, o null si no hay ninguno abierto.
func capa_de_arriba() -> Control:
	var mejor: Control = null
	var mejor_capa := 0
	for n: Node in get_tree().get_nodes_in_group(GRUPO):
		var c := n as Control
		if c == null or not c.is_visible_in_tree():
			continue
		var capa := _capa_canvas(c)
		if mejor == null or capa > mejor_capa or (capa == mejor_capa and c.is_greater_than(mejor)):
			mejor = c
			mejor_capa = capa
	return mejor


## Hay algun menu abierto encima de la partida?
func hay_menu_abierto() -> bool:
	return capa_de_arriba() != null


static func _capa_canvas(nodo: Node) -> int:
	var n := nodo.get_parent()
	while n != null:
		if n is CanvasLayer:
			return (n as CanvasLayer).layer
		n = n.get_parent()
	return 0


## Donde arranca el foco: el primer boton que se pueda apretar. Si no hay, cualquier
## control que acepte foco (un deslizador, una casilla).
##
## BOTONES PRIMERO, y es por el menu principal: lo primero que tiene es el campo del
## nombre, y arrancar ahi con un mando es arrancar en lo unico que no se puede usar sin
## teclado.
static func primer_foco(capa: Control) -> Control:
	var boton := _buscar(capa, true)
	return boton if boton != null else _buscar(capa, false)


static func _buscar(nodo: Node, solo_botones: bool) -> Control:
	for hijo: Node in nodo.get_children():
		var c := hijo as Control
		if c != null and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE:
			var b := c as BaseButton
			if b != null and not b.disabled:
				return b
			if not solo_botones and b == null:
				return c
		var adentro := _buscar(hijo, solo_botones)
		if adentro != null:
			return adentro
	return null


static func _boton_volver(nodo: Node) -> BaseButton:
	for hijo: Node in nodo.get_children():
		var b := hijo as BaseButton
		if b != null and b.has_meta(META_VOLVER) and b.is_visible_in_tree() and not b.disabled:
			return b
		var adentro := _boton_volver(hijo)
		if adentro != null:
			return adentro
	return null


## Que el control con foco se vea: si esta dentro de una lista con scroll, la lista
## baja hasta el. Sin esto, en la tienda el foco seguia bajando por tarjetas que ya
## estaban fuera de la pantalla.
static func _mostrar(control: Control) -> void:
	var n := control.get_parent()
	while n != null:
		if n is ScrollContainer:
			(n as ScrollContainer).ensure_control_visible(control)
			return
		n = n.get_parent()
