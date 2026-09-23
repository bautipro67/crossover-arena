class_name PerfilBarra
extends PanelContainer
## La tira de perfil: nivel, barra de experiencia y monedas.
##
## Aparece igual en el menu, en el pase y en la tienda. Es un solo nodo y no tres copias
## porque es la clase de cosa que se desincroniza: comprar algo en la tienda tiene que
## descontar monedas en la tira de la tienda Y en la del menu al volver, y con tres
## implementaciones eso se arregla dos veces y se rompe la tercera.
##
## Se actualiza sola: escucha Progreso.cambio. Quien la pone no tiene que acordarse de
## refrescarla despues de cada compra.

var _nivel: Label = null
var _exp_texto: Label = null
var _barra: Panel = null
var _monedas: Label = null


func _ready() -> void:
	add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_SOFT, 10, 6))

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	add_child(fila)

	var caja_nivel := VBoxContainer.new()
	caja_nivel.add_theme_constant_override("separation", 2)
	caja_nivel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(caja_nivel)

	var arriba := HBoxContainer.new()
	arriba.add_theme_constant_override("separation", 8)
	caja_nivel.add_child(arriba)

	_nivel = UITheme.make_label("", 17, UITheme.ACCENT)
	arriba.add_child(_nivel)

	_exp_texto = UITheme.make_label("", 12, UITheme.TEXT_DIM)
	_exp_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arriba.add_child(_exp_texto)

	var partes := UITheme.make_bar(UITheme.ACCENT, UITheme.STAMINA_TRACK, 7)
	var pista: Panel = partes[0]
	_barra = partes[1]
	caja_nivel.add_child(pista)

	var moneda := UITheme.make_label("◆", 18, UITheme.GOLD)
	fila.add_child(moneda)
	_monedas = UITheme.make_label("", 17, UITheme.GOLD)
	_monedas.custom_minimum_size = Vector2(70, 0)
	fila.add_child(_monedas)

	Progreso.cambio.connect(refrescar)
	refrescar()


func _exit_tree() -> void:
	if Progreso.cambio.is_connected(refrescar):
		Progreso.cambio.disconnect(refrescar)


func refrescar() -> void:
	if not is_instance_valid(_nivel):
		return
	_nivel.text = "NIVEL %d" % Progreso.nivel
	if Progreso.nivel >= Progreso.NIVEL_MAXIMO:
		_exp_texto.text = "máximo"
		_barra.anchor_right = 1.0
	else:
		_exp_texto.text = "%d / %d" % [Progreso.exp_actual, Progreso.exp_para_nivel(Progreso.nivel)]
		# La barra se estira con el ancla derecha y no con el tamaño: asi acompaña al
		# contenedor cuando cambia el ancho de la ventana, sin recalcular nada.
		_barra.anchor_right = Progreso.progreso_nivel()
	# El infinito a la vista: si el modo desarrollador estuviera prendido sin avisar, un
	# saldo que no baja al comprar se veria como un bug.
	_monedas.text = "∞" if Progreso.modo_dev else str(Progreso.monedas)
