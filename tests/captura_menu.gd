## Capturas de las pantallas de menu, para mirar un cambio de interfaz sin correr todo
## el chequeo visual: el menu principal, las tarjetas de modos, la sala y la tienda.
##
##   godot --path . --resolution 1280x720 res://tests/captura_menu.tscn -- <carpeta>
extends Node
var _main: Node = null
func _ready() -> void:
	Settings.mostrar_hitboxes = false
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_run.call_deferred()
func _run() -> void:
	var out := String(OS.get_cmdline_user_args()[0])
	for i in range(60): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/menu_a.png")
	var menu: Node = null
	for h in _main.get_children():
		if h is MainMenu: menu = h
	if menu:
		menu.mostrar_modos(true)
		print("vista_ok_modos: ", menu.todo_a_la_vista())
	for i in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/menu_b.png")
	if menu:
		menu.mostrar_modos(false)
		print("vista_ok: ", menu.todo_a_la_vista())
	_main.show_tienda()
	for i in range(30): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/menu_c_tienda.png")
	_main.show_main_menu()
	_main.show_pase()
	for i in range(30): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/menu_d_pase.png")
	get_tree().quit()
