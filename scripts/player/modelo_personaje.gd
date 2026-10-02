class_name ModeloPersonaje
extends RefCounted
## Los personajes modelados en Blender (tools/modelos/), y lo que hace falta para usarlos
## con la animacion de PlayerVisual.
##
## LA ANIMACION NO CAMBIA. PlayerVisual sigue moviendo sus pivotes —hombros, codos,
## rodillas, torso, cabeza— exactamente como antes; con un modelo puesto, las piezas del
## rig se esconden y cada frame el giro de cada pivote se copia a su hueso del esqueleto.
## Asi un personaje con modelo camina, pega, canaliza y festeja igual que uno sin modelo, y
## el que todavia no tiene se sigue viendo como siempre.
##
## LAS SKINS TAMBIEN: cada material del modelo se llama como una parte ("pelo",
## "sueter_a", "piel") y se reemplaza por el toon del juego con el color que la skin diga
## para esa parte (PlayerVisual._tono).

const CARPETA := "res://assets/modelos/"

## Pivote de PlayerVisual que mueve cada hueso. Mismo nombre que en el kit de Blender.
const HUESOS: Array[StringName] = [&"caderas", &"torso", &"cabeza", &"hombro_l", &"codo_l",
	&"hombro_r", &"codo_r", &"pierna_l", &"rodilla_l", &"pierna_r", &"rodilla_r"]


static func ruta(id: StringName) -> String:
	return CARPETA + String(id) + ".glb"


static func existe(id: StringName) -> bool:
	return ResourceLoader.exists(ruta(id))


## La cara del modelo (donde van los ojos, la boca, las cejas), o {} si no la trae.
static func cara(id: StringName) -> Dictionary:
	var archivo := CARPETA + String(id) + ".json"
	if not FileAccess.file_exists(archivo):
		return {}
	var texto := FileAccess.get_file_as_string(archivo)
	var datos: Variant = JSON.parse_string(texto)
	return datos if datos is Dictionary else {}


static func esqueleto_de(raiz: Node) -> Skeleton3D:
	if raiz is Skeleton3D:
		return raiz
	for hijo: Node in raiz.get_children():
		var s := esqueleto_de(hijo)
		if s != null:
			return s
	return null


static func _v(a: Variant, defecto: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return defecto


static func _c(a: Variant, defecto: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return defecto


# ---------------------------------------------------------------- La cara

static var _texturas: Dictionary = {}


## EL OJO DIBUJADO: blanco, iris con degrade, pupila, dos brillos, el parpado de arriba
## marcado y, si tiene, las pestañas. Una esfera no tiene nada de eso, y es la parte de la
## cara que mas dice de un personaje.
static func textura_ojo(iris: Color, pestanas: bool, espejado: bool, estilo: String = "anime") -> ImageTexture:
	var clave := "ojo_%s_%s_%s_%s" % [iris.to_html(), pestanas, espejado, estilo]
	if _texturas.has(clave):
		return _texturas[clave]
	var w := 128
	var h := 160
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 64.0
	var cy := 88.0
	var rx := 52.0
	var ry := 64.0
	var oscuro := Color(0.10, 0.06, 0.06)
	for y: int in range(h):
		for x: int in range(w):
			var px := float(x) if not espejado else float(w - 1 - x)
			var dx := (px - cx) / rx
			var dy := (float(y) - cy) / ry
			var e := dx * dx + dy * dy
			if e > 1.0:
				# El parpado de arriba y las pestañas, por fuera del blanco.
				var ex := (px - cx) / (rx + 9.0)
				var ey := (float(y) - cy) / (ry + 9.0)
				if ex * ex + ey * ey <= 1.0 and float(y) < cy - ry * 0.25:
					img.set_pixel(x, y, oscuro)
				elif pestanas and float(y) < cy - ry * 0.55 and px > cx + rx * 0.45 and px < cx + rx + 18.0 \
						and float(y) > cy - ry - 22.0 and absf((px - cx - rx * 0.55) * 0.9 - (cy - ry * 0.55 - float(y))) < 5.0:
					img.set_pixel(x, y, oscuro)
				continue
			var col := Color(0.98, 0.98, 1.0)
			var ix := px - cx
			var iy := float(y) - (cy + 8.0)
			var di := sqrt(ix * ix + iy * iy)
			# "brillo": el ojo entero encendido y sin pupila (Scorpion).
			if estilo == "brillo":
				img.set_pixel(x, y, iris.lerp(Color.WHITE, clampf(1.0 - e, 0.0, 1.0) * 0.6))
				continue
			# "cuenca": el agujero negro de una calavera con la pupila chica de luz (Sans).
			# "cuenca_vacia": la cuenca apagada; "cuenca_grande": la pupila encendida y grande
			# (Sans en la pelea, con un ojo prendido y el otro no).
			if estilo.begins_with("cuenca"):
				var dc := sqrt(ix * ix + (float(y) - cy) * (float(y) - cy))
				var radio := 0.0 if estilo == "cuenca_vacia" else (26.0 if estilo == "cuenca_grande" else 13.0)
				var luz := iris.lerp(Color.WHITE, clampf(1.0 - dc / maxf(radio, 1.0), 0.0, 1.0) * 0.7)
				img.set_pixel(x, y, luz if dc < radio else Color(0.02, 0.02, 0.03))
				continue
			# "simple": el blanco con una pupila chica y oscura, sin iris (Rick, los dibujos
			# animados). "anime": iris grande con degrade.
			if estilo == "simple":
				if di < 15.0:
					col = Color(0.05, 0.04, 0.05)
				img.set_pixel(x, y, col)
				continue
			if di < 40.0:
				var t := clampf((float(y) - (cy - 32.0)) / 72.0, 0.0, 1.0)
				col = iris.darkened(0.45).lerp(iris.lightened(0.25), t)
				if di > 36.0:
					col = iris.darkened(0.6)
				if di < 17.0:
					col = Color(0.04, 0.03, 0.05)
				if estilo == "sharingan" and di >= 17.0 and di < 36.0:
					# El anillo fino y las tres comas (tomoe) sobre el anillo.
					if absf(di - 26.0) < 1.6:
						col = Color(0.12, 0.02, 0.02)
					for k: int in range(3):
						var a := deg_to_rad(90.0 + 120.0 * float(k))
						var tm := Vector2(ix, iy) - Vector2(cos(a), sin(a)) * 26.0
						var cola := Vector2(ix, iy) - Vector2(cos(a + 0.45), sin(a + 0.45)) * 26.0
						if tm.length() < 6.5 or cola.length() < 3.2:
							col = Color(0.04, 0.02, 0.02)
			# El parpado proyecta sombra sobre el blanco de arriba.
			if dy < -0.55 and di >= 40.0:
				col = col.darkened(0.12)
			img.set_pixel(x, y, col)
	# Los brillos, encima de todo (no en los ojos que son luz o un agujero).
	var brillos: Array = [] if estilo == "brillo" or estilo.begins_with("cuenca") else [[Vector2(48, 70), 12.0], [Vector2(80, 108), 6.0]]
	for b: Array in brillos:
		var c: Vector2 = b[0]
		if espejado:
			c.x = float(w - 1) - c.x
		var r: float = b[1]
		for y: int in range(int(c.y - r), int(c.y + r) + 1):
			for x: int in range(int(c.x - r), int(c.x + r) + 1):
				if x >= 0 and y >= 0 and x < w and y < h and Vector2(x, y).distance_to(c) <= r:
					img.set_pixel(x, y, Color(1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	_texturas[clave] = tex
	return tex


## LA BOCA DIBUJADA: una sonrisa, y si tiene, los dientes de adelante.
static func textura_boca(dientes: bool) -> ImageTexture:
	var clave := "boca_%s" % dientes
	if _texturas.has(clave):
		return _texturas[clave]
	var w := 128
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var oscuro := Color(0.20, 0.07, 0.07)
	for x: int in range(10, 118):
		var t := (float(x) - 64.0) / 54.0
		var y0 := 14.0 + 18.0 * (1.0 - t * t)
		for y: int in range(int(y0) - 3, int(y0) + 4):
			if y >= 0 and y < h:
				img.set_pixel(x, y, oscuro)
	if dientes:
		for k: int in range(2):
			var x0 := 50 + k * 15
			for y: int in range(31, 52):
				for x: int in range(x0, x0 + 13):
					var borde := x == x0 or x == x0 + 12 or y == 51
					img.set_pixel(x, y, oscuro if borde else Color(1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	_texturas[clave] = tex
	return tex


static func quad(tam: Vector2, tex: Texture2D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = tam
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m
