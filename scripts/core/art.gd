class_name Art
extends RefCounted
## Fabrica de materiales y paleta del juego.
##
## Todo el aspecto sale de aca. Como no hay assets, lo que salva el look no es el
## detalle de la geometria sino el SHADING: cel-shading con bandas duras y un contorno
## negro. Con eso, unas primitivas puestas con criterio se leen como un estilo elegido
## y no como un placeholder.
##
## El contorno se hace con el truco clasico de Godot: un next_pass que dibuja las caras
## de atras infladas y sin luz. No necesita shaders propios ni una segunda malla.

# --------------------------------------------------------------------- Paleta

const OUTLINE := Color(0.03, 0.04, 0.08)

## Mundo: azules frios y desaturados para que los personajes resalten.
const FLOOR_DARK := Color(0.13, 0.16, 0.26)
const FLOOR_LIGHT := Color(0.17, 0.21, 0.33)
const WALL := Color(0.09, 0.11, 0.19)
# Las coberturas tienen que separarse del piso de un vistazo: desde arriba, con los
# valores viejos (0.22 contra un piso de 0.13-0.17) se confundian con el damero y el
# mapa parecia vacio.
const COVER := Color(0.30, 0.37, 0.54)
const COVER_TOP := Color(0.44, 0.54, 0.74)
const TRIM := Color(0.35, 0.75, 1.0)

## Acentos de personaje.
const ICE := Color(0.55, 0.85, 1.0)
const GOLD := Color(1.0, 0.78, 0.22)


# ------------------------------------------------------------------ Materiales

## Contorno. Se usa como next_pass de los materiales normales.
static func outline(width: float, color: Color = OUTLINE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = width
	return m


## Material base del juego: luz en bandas, brillo especular duro, borde iluminado
## y contorno negro.
static func toon(color: Color, outline_width: float = 0.012, rim_amount: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = true
	m.rim = rim_amount
	m.rim_tint = 0.25
	if outline_width > 0.0:
		m.next_pass = outline(outline_width)
	return m


## Toon con TEXTURA DE PELO. Para los personajes que son bichos y no personas.
##
## Un toon liso es piel: una superficie continua y perfecta. El pelaje se distingue por que
## la luz no corta limpio — el borde entre luz y sombra queda deshilachado, porque cada
## pelo apunta para un lado. Eso se consigue con un mapa de normales de ruido ESTIRADO en
## un eje, que imita hebras: con el sombreado toon, el corte de luz sigue esas hebras y se
## vuelve dentado.
##
## El ruido se genera por codigo —FastNoiseLite— asi que sigue sin haber un solo archivo
## de textura. Y se comparte: generar un ruido de 256x256 por personaje y por respawn es
## trabajo tirado, el mismo sirve para todos.
static var _normal_pelo: NoiseTexture2D = null

static func pelaje(color: Color, outline_width: float = 0.012) -> StandardMaterial3D:
	var m := toon(color, outline_width, 0.35)
	if _normal_pelo == null:
		var ruido := FastNoiseLite.new()
		ruido.noise_type = FastNoiseLite.TYPE_CELLULAR
		ruido.frequency = 0.09
		ruido.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
		_normal_pelo = NoiseTexture2D.new()
		_normal_pelo.width = 256
		_normal_pelo.height = 256
		_normal_pelo.seamless = true
		_normal_pelo.as_normal_map = true
		_normal_pelo.bump_strength = 6.0
		_normal_pelo.noise = ruido
	m.normal_enabled = true
	m.normal_texture = _normal_pelo
	m.normal_scale = 0.9
	# Estirado en un eje: celdas alargadas se leen como hebras, redondas como granito.
	m.uv1_scale = Vector3(5.0, 1.6, 1.0)
	m.roughness = 1.0
	return m


## Igual que toon pero emitiendo luz propia. Para los detalles que tienen que cantar:
## trims del mapa, proyectiles, acentos de personaje.
static func glow(color: Color, energy: float = 2.0, outline_width: float = 0.0) -> StandardMaterial3D:
	var m := toon(color, outline_width, 0.7)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## Superficie metalica (cuchillos, detalles duros).
static func metal(color: Color, outline_width: float = 0.01) -> StandardMaterial3D:
	var m := toon(color, outline_width, 0.8)
	m.metallic = 0.85
	m.roughness = 0.25
	return m


## Material translucido (hielo, auras, cupulas).
static func glass(color: Color, alpha: float = 0.45, energy: float = 1.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.rim_enabled = true
	m.rim = 0.9
	return m


## Material sin luz, de color plano. Para cosas que tienen que leerse siempre igual
## sin importar de donde venga la luz.
static func flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


# -------------------------------------------------------------------- Helpers

## Crea un MeshInstance3D con una caja ya materializada.
static func box(size: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi


static func capsule(radius: float, height: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.01)
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi


static func sphere(radius: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi


static func cylinder(radius: float, height: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	return mi
