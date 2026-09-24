class_name Retrato
extends RefCounted
## El retrato de un personaje: su cuerpo de verdad en 3D, en un rincon con luz propia.
##
## El juego no tiene imagenes, y el mismo PlayerVisual que se ve en la partida —con la
## skin que tenga puesta— es lo que mejor dice quien habla. Lo usan las lineas que se
## dicen en plena pelea.


## Un retrato listo para agregar a la interfaz. `cara` = encuadre de la cara; si no, medio
## cuerpo.
static func crear(personaje: StringName, tam: Vector2, cara: bool = true) -> SubViewportContainer:
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.custom_minimum_size = tam
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.msaa_3d = Viewport.MSAA_2X
	contenedor.add_child(vista)

	var ent := Environment.new()
	ent.background_mode = Environment.BG_CLEAR_COLOR
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.55, 0.60, 0.75)
	ent.ambient_light_energy = 0.6
	ent.tonemap_mode = Environment.TONE_MAPPER_ACES
	var mundo := WorldEnvironment.new()
	mundo.environment = ent
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.1
	sol.rotation_degrees = Vector3(-30.0, 35.0, 0.0)
	vista.add_child(sol)

	var data := CharacterDB.get_character(personaje)
	var alto := 1.55 * (data.build_scale.y if data != null else 1.0)
	var camara := Camera3D.new()
	camara.fov = 28.0 if cara else 30.0
	vista.add_child(camara)
	var ojo := Vector3(0.0, alto - 0.05, 1.9) if cara else Vector3(0.0, 1.45, 3.4)
	var mira := Vector3(0.0, alto - 0.12, 0.0) if cara else Vector3(0.0, 1.35, 0.0)
	camara.transform = Transform3D(Basis.looking_at(mira - ojo, Vector3.UP), ojo)

	var pivote := Node3D.new()
	# Tres cuartos: de frente parece una foto carnet.
	pivote.rotation_degrees = Vector3(0.0, 200.0, 0.0)
	vista.add_child(pivote)
	if data != null:
		var visual := PlayerVisual.new()
		# El cuerpo se arma en _ready, y el retrato todavia no esta en la escena cuando se
		# crea: vestirlo antes falla porque no hay materiales. Se viste al estar listo.
		var vestido := SkinDB.aplicar(data, Progreso.skin_de(personaje))
		visual.ready.connect(func() -> void: visual.apply_character(vestido), CONNECT_ONE_SHOT)
		pivote.add_child(visual)
	return contenedor
