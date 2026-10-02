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


## LA VITRINA DEL MENU: el personaje de cuerpo entero, girando despacio, con una luz de
## contorno de su color y un circulo de luz en el piso. Es lo primero que se ve al abrir
## el juego, asi que tiene que verse como un personaje en un escenario y no como un
## muñeco en una caja.
static func vitrina(personaje: StringName, tam: Vector2) -> SubViewportContainer:
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.custom_minimum_size = tam
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.msaa_3d = Viewport.MSAA_4X
	contenedor.add_child(vista)

	var data := CharacterDB.get_character(personaje)
	var color := data.accent_color if data != null else UITheme.ACCENT
	var ent := Environment.new()
	ent.background_mode = Environment.BG_CLEAR_COLOR
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.55, 0.60, 0.78)
	ent.ambient_light_energy = 0.55
	ent.tonemap_mode = Environment.TONE_MAPPER_ACES
	ent.glow_enabled = true
	ent.glow_intensity = 0.45
	var mundo := WorldEnvironment.new()
	mundo.environment = ent
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.15
	sol.rotation_degrees = Vector3(-28.0, 30.0, 0.0)
	vista.add_child(sol)
	# El contraluz de su color: recorta la silueta contra el fondo.
	var contra := DirectionalLight3D.new()
	contra.light_color = color.lightened(0.2)
	contra.light_energy = 1.6
	contra.rotation_degrees = Vector3(-15.0, 200.0, 0.0)
	vista.add_child(contra)

	var alto := data.build_scale.y if data != null else 1.0
	var camara := Camera3D.new()
	camara.fov = 30.0
	vista.add_child(camara)
	var ojo := Vector3(0.0, 1.25 * alto, 5.6)
	var mira := Vector3(0.0, 1.08 * alto, 0.0)
	camara.transform = Transform3D(Basis.looking_at(mira - ojo, Vector3.UP), ojo)

	# El circulo del piso: un disco que brilla y un aro que late.
	var disco := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.85
	cilindro.bottom_radius = 0.85
	cilindro.height = 0.02
	disco.mesh = cilindro
	var mat_disco := Art.glow(color, 0.9)
	mat_disco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_disco.albedo_color.a = 0.35
	disco.material_override = mat_disco
	vista.add_child(disco)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.92
	toro.outer_radius = 0.97
	aro.mesh = toro
	aro.material_override = Art.glow(color, 2.6)
	aro.position = Vector3(0.0, 0.02, 0.0)
	vista.add_child(aro)
	var late := aro.create_tween().set_loops()
	late.tween_property(aro, "scale", Vector3(1.08, 1.0, 1.08), 1.2).set_trans(Tween.TRANS_SINE)
	late.tween_property(aro, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_SINE)

	var pivote := Node3D.new()
	pivote.rotation_degrees = Vector3(0.0, 200.0, 0.0)
	vista.add_child(pivote)
	var gira := pivote.create_tween().set_loops()
	gira.tween_property(pivote, "rotation_degrees:y", 200.0 + 360.0, 16.0).from(200.0)
	if data != null:
		var visual := PlayerVisual.new()
		var vestido := SkinDB.aplicar(data, Progreso.skin_de(personaje))
		visual.ready.connect(func() -> void: visual.apply_character(vestido), CONNECT_ONE_SHOT)
		pivote.add_child(visual)
	return contenedor
