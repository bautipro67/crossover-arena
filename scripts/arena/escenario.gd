class_name Escenario
extends RefCounted
## LO QUE SE VE DE CADA MAPA (ver Mapas): viste el trazado de la Arena con el tema del lugar.
##
## La Arena arma lo solido —piso, paredes, coberturas, columnas, rampas, con su colision y
## su navmesh, iguales en todos los mapas—, y aca se le pone encima lo que dice donde
## estas: la forma de cada cobertura (ruinas de piedra, cajones nevados, obsidiana con
## espinas, bloques de hielo, cristales), la de cada columna (columnas de marmol, pinos,
## estalagmitas, estandartes, obeliscos), el dibujo del piso, lo que hay del otro lado de
## las paredes (las gradas del coliseo, las casas del pueblo, la torre, los volcanes, el mar
## de nubes), lo que hay en el cielo (la grieta, la luna, las estrellas) y lo que flota en el
## aire (polvo, nieve, brasas, espiritus).
##
## NADA DE ESTO TIENE COLISION: es decoracion. Lo que se toca es lo de la Arena.
##
## TODO EN POCAS MALLAS: cada pieza se suma a un Lote, que junta todo lo de un mismo
## material en una sola malla. Son cientos de piezas por mapa y el build web corre en
## Compatibility: una malla por pieza serian cientos de llamadas de dibujo.

const MITAD := 60.0


## Junta piezas sueltas en una malla por material.
class Lote:
	var _por_mat: Dictionary = {}

	func poner(malla: Mesh, xf: Transform3D, mat: Material) -> void:
		var st: SurfaceTool = _por_mat.get(mat)
		if st == null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			_por_mat[mat] = st
		st.append_from(malla, 0, xf)

	func caja(c: Vector3, t: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
		var m := BoxMesh.new()
		m.size = t
		poner(m, Transform3D(Basis.from_euler(rot * (PI / 180.0)), c), mat)

	func cilindro(c: Vector3, r_abajo: float, r_arriba: float, alto: float, mat: Material, seg: int = 12,
			rot: Vector3 = Vector3.ZERO) -> void:
		var m := CylinderMesh.new()
		m.bottom_radius = r_abajo
		m.top_radius = r_arriba
		m.height = alto
		m.radial_segments = seg
		m.rings = 1
		poner(m, Transform3D(Basis.from_euler(rot * (PI / 180.0)), c), mat)

	func esfera(c: Vector3, r: float, mat: Material, escala: Vector3 = Vector3.ONE, seg: int = 12) -> void:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		poner(m, Transform3D(Basis.from_scale(escala), c), mat)

	func techo_dos_aguas(c: Vector3, t: Vector3, mat: Material, giro: float = 0.0) -> void:
		var m := PrismMesh.new()
		m.size = t
		poner(m, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), c), mat)

	func plano(c: Vector3, t: Vector2, mat: Material, giro: float = 0.0) -> void:
		var m := PlaneMesh.new()
		m.size = t
		poner(m, Transform3D(Basis(Vector3.UP, deg_to_rad(giro)), c), mat)

	func cerrar(padre: Node3D, sombras: bool = true) -> void:
		for mat: Material in _por_mat:
			var st: SurfaceTool = _por_mat[mat]
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombras \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			padre.add_child(mi)
		_por_mat.clear()


static var _mats: Dictionary = {}


## Materiales de decoracion, compartidos: el mismo color, el mismo material (y la misma
## malla en el Lote). Sin contorno: son cientos de piezas, y el contorno es otra pasada.
static func toon(color: Color, contorno: float = 0.0) -> StandardMaterial3D:
	var clave := "t%s%.3f" % [color.to_html(), contorno]
	if not _mats.has(clave):
		_mats[clave] = Art.toon(color, contorno)
	return _mats[clave]


static func luz(color: Color, energia: float = 1.6) -> StandardMaterial3D:
	var clave := "g%s%.2f" % [color.to_html(), energia]
	if not _mats.has(clave):
		_mats[clave] = Art.glow(color, energia)
	return _mats[clave]


# ================================================================== La entrada

## Viste la Arena ya armada. `bloques`: [centro, tamaño] de cada cobertura; `pilares`:
## [base, radio, alto] de cada columna (sin malla: la forma la pone el tema).
static func vestir(arena: Node3D, tema: Dictionary, bloques: Array, pilares: Array) -> void:
	# Lo de adentro de la Arena hace sombra; el piso y lo de afuera no (es mucho, y lejos).
	var cerca := Lote.new()
	var lejos := Lote.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(tema.get("id", "")))
	_piso(lejos, tema, rng)
	for b: Array in bloques:
		_vestir_bloque(cerca, tema, b[0], b[1], rng)
	for p: Array in pilares:
		_pilar(cerca, tema, p[0], p[1], p[2], rng)
	_paredes(cerca, tema, rng)
	match String(tema.get("decorado", "")):
		"gradas": _gradas(lejos, tema, rng)
		"pueblo": _pueblo(lejos, tema, rng)
		"torre": _torre(lejos, tema, rng)
		"caverna": _caverna(lejos, tema, rng)
		"volcan": _volcanes(lejos, tema, rng)
		"vacio": _vacio(lejos, tema, rng)
		"glaciar": _glaciar(lejos, tema, rng)
		"nucleo": _nucleo(lejos, tema, rng)
		"nubes": _nubes(lejos, tema, rng)
		"ciudad": _ciudad(lejos, tema, rng)
		"luna": _luna(lejos, tema, rng)
		"santuario": _santuario(lejos, tema, rng)
	cerca.cerrar(arena, true)
	lejos.cerrar(arena, false)
	_particulas(arena, tema)


# ======================================================================= El piso

static func _piso(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var piso: Dictionary = tema.get("piso", {})
	var a := toon(piso.get("a", Color.GRAY))
	var b := toon(piso.get("b", Color.GRAY))
	var marca: Color = piso.get("marca", Art.TRIM)
	var junta := toon((piso.get("a", Color.GRAY) as Color).darkened(0.35))
	match String(piso.get("estilo", "")):
		"losas", "torneo", "marmol", "roca", "cristal":
			# Losas de tamaños distintos, con la junta oscura entre una y otra.
			var paso := 6.0 if piso["estilo"] == "torneo" else 4.0
			var n := int(MITAD * 2.0 / paso)
			for i: int in range(n):
				for j: int in range(n):
					var c := Vector3(-MITAD + paso * (i + 0.5), 0.008, -MITAD + paso * (j + 0.5))
					var mat := a if (i + j + (rng.randi() % 3 if piso["estilo"] == "roca" else 0)) % 2 == 0 else b
					lote.plano(c, Vector2(paso - 0.14, paso - 0.14), mat)
			lote.plano(Vector3(0.0, 0.004, 0.0), Vector2(MITAD * 2.0, MITAD * 2.0), junta)
			if piso["estilo"] == "marmol":
				# Las incrustaciones de oro, en anillos.
				for r: float in [8.0, 22.0, 40.0]:
					_anillo_piso(lote, r, 0.22, luz(marca, 0.9))
			if piso["estilo"] == "cristal":
				for i: int in range(n + 1):
					var t := -MITAD + paso * i
					lote.plano(Vector3(t, 0.012, 0.0), Vector2(0.10, MITAD * 2.0), luz(marca, 0.7))
					lote.plano(Vector3(0.0, 0.012, t), Vector2(MITAD * 2.0, 0.10), luz(marca, 0.7))
			if piso["estilo"] == "roca":
				# Los cables por el piso, donde zumban los espiritus.
				for k: int in range(14):
					var x0 := rng.randf_range(-MITAD, MITAD)
					var z0 := rng.randf_range(-MITAD, MITAD)
					var largo := rng.randf_range(10.0, 26.0)
					lote.caja(Vector3(x0, 0.06, z0), Vector3(0.12, 0.10, largo), luz(marca, 1.1),
						Vector3(0.0, rng.randf_range(0.0, 180.0), 0.0))
		"nieve":
			lote.plano(Vector3(0.0, 0.006, 0.0), Vector2(MITAD * 2.0, MITAD * 2.0), a)
			# La calle del pueblo, de punta a punta, con la nieve corrida a los costados.
			var calle := toon(piso.get("calle", Color(0.2, 0.2, 0.24)))
			lote.plano(Vector3(0.0, 0.012, 0.0), Vector2(MITAD * 2.0, 7.0), calle)
			for k: int in range(24):
				lote.plano(Vector3(-MITAD + 5.0 * k + 2.5, 0.016, 0.0), Vector2(2.4, 0.18), toon(Color(0.95, 0.90, 0.55)))
			for k: int in range(60):
				var c := Vector3(rng.randf_range(-MITAD, MITAD), 0.0, rng.randf_range(-MITAD, MITAD))
				if absf(c.z) < 4.5:
					continue
				lote.esfera(c, rng.randf_range(1.2, 3.0), b, Vector3(1.0, 0.12, 1.0), 10)
		"lava":
			for i: int in range(30):
				for j: int in range(30):
					var c := Vector3(-MITAD + 4.0 * (i + 0.5), 0.008, -MITAD + 4.0 * (j + 0.5))
					lote.plano(c, Vector2(3.94, 3.94), a if (i * 7 + j * 3) % 5 else b)
			lote.plano(Vector3(0.0, 0.004, 0.0), Vector2(MITAD * 2.0, MITAD * 2.0), toon(marca.darkened(0.72)))
			# Grietas de lava: lineas quebradas que brillan.
			for k: int in range(26):
				var p := Vector3(rng.randf_range(-MITAD, MITAD), 0.02, rng.randf_range(-MITAD, MITAD))
				var ang := rng.randf_range(0.0, TAU)
				for s: int in range(5):
					ang += rng.randf_range(-0.7, 0.7)
					var largo := rng.randf_range(1.5, 4.0)
					var d := Vector3(cos(ang), 0.0, sin(ang)) * largo
					lote.caja(p + d * 0.5, Vector3(0.22, 0.03, largo), luz(marca, 2.2), Vector3(0.0, rad_to_deg(-ang) + 90.0, 0.0))
					p += d
		"estrellas":
			lote.plano(Vector3(0.0, 0.006, 0.0), Vector2(MITAD * 2.0, MITAD * 2.0), a)
			for k: int in range(420):
				var c := Vector3(rng.randf_range(-MITAD, MITAD), 0.02, rng.randf_range(-MITAD, MITAD))
				var r := rng.randf_range(0.03, 0.10)
				lote.plano(c, Vector2(r, r), luz(Color(0.85, 0.90, 1.0), rng.randf_range(1.0, 2.6)))
			for i: int in range(13):
				var t := -MITAD + 10.0 * i
				lote.plano(Vector3(t, 0.01, 0.0), Vector2(0.05, MITAD * 2.0), luz(marca, 0.35))
				lote.plano(Vector3(0.0, 0.01, t), Vector2(MITAD * 2.0, 0.05), luz(marca, 0.35))
		"hielo":
			for i: int in range(20):
				for j: int in range(20):
					var c := Vector3(-MITAD + 6.0 * (i + 0.5), 0.008, -MITAD + 6.0 * (j + 0.5))
					lote.plano(c, Vector2(5.9, 5.9), a if (i + j) % 2 else b)
			for k: int in range(40):
				var p := Vector3(rng.randf_range(-MITAD, MITAD), 0.02, rng.randf_range(-MITAD, MITAD))
				var ang := rng.randf_range(0.0, TAU)
				for s: int in range(3):
					ang += rng.randf_range(-0.9, 0.9)
					var largo := rng.randf_range(1.0, 3.0)
					var d := Vector3(cos(ang), 0.0, sin(ang)) * largo
					lote.caja(p + d * 0.5, Vector3(0.06, 0.02, largo), toon(Color(0.95, 0.98, 1.0)),
						Vector3(0.0, rad_to_deg(-ang) + 90.0, 0.0))
					p += d


static func _anillo_piso(lote: Lote, r: float, ancho: float, mat: Material) -> void:
	var n := maxi(24, int(r * 3.0))
	for k: int in range(n):
		var a := TAU * k / n
		var largo := TAU * r / n + 0.05
		lote.caja(Vector3(sin(a) * r, 0.02, cos(a) * r), Vector3(ancho, 0.02, largo), mat, Vector3(0.0, rad_to_deg(a), 0.0))


# ================================================================= Coberturas

## La forma de una cobertura, encima del bloque solido de la Arena (que ya tiene su
## color de tema). El bloque es `c` (centro) y `t` (tamaño).
static func _vestir_bloque(lote: Lote, tema: Dictionary, c: Vector3, t: Vector3, rng: RandomNumberGenerator) -> void:
	var cob: Dictionary = tema.get("cobertura", {})
	var tope := toon(cob.get("tope", Color.GRAY))
	var detalle_c: Color = cob.get("detalle", Color.DIM_GRAY)
	var arriba := c.y + t.y * 0.5
	var abajo := c.y - t.y * 0.5
	var area := t.x * t.z
	match String(cob.get("estilo", "")):
		"ruina":
			# Zocalo y cornisa de piedra; pedazos caidos arriba; grietas en las caras.
			lote.caja(Vector3(c.x, abajo + 0.18, c.z), Vector3(t.x + 0.30, 0.36, t.z + 0.30), toon(detalle_c.lightened(0.15)))
			lote.caja(Vector3(c.x, arriba + 0.10, c.z), Vector3(t.x + 0.36, 0.20, t.z + 0.36), tope)
			for k: int in range(clampi(int(area / 18.0), 1, 8)):
				var p := Vector3(c.x + rng.randf_range(-t.x, t.x) * 0.4, arriba + 0.30, c.z + rng.randf_range(-t.z, t.z) * 0.4)
				var s := rng.randf_range(0.4, 0.9)
				lote.caja(p, Vector3(s, s * 0.6, s * 0.8), tope, Vector3(rng.randf_range(-15, 15), rng.randf_range(0, 90), rng.randf_range(-15, 15)))
			_grietas(lote, c, t, toon(detalle_c), rng, 3)
		"nevado":
			# La nieve arriba, gruesa y redondeada, y los carambanos colgando del borde.
			lote.esfera(Vector3(c.x, arriba + 0.10, c.z), 1.0, toon(Color(0.95, 0.97, 1.0)),
				Vector3(t.x * 0.55, 0.32, t.z * 0.55), 14)
			lote.caja(Vector3(c.x, arriba + 0.05, c.z), Vector3(t.x + 0.12, 0.16, t.z + 0.12), toon(Color(0.95, 0.97, 1.0)))
			for k: int in range(clampi(int((t.x + t.z) * 0.8), 2, 20)):
				var lado_x := rng.randf() < 0.5
				var p := Vector3(c.x + (rng.randf_range(-0.5, 0.5) * t.x if lado_x else signf(rng.randf() - 0.5) * t.x * 0.5),
					arriba - 0.25, c.z + (signf(rng.randf() - 0.5) * t.z * 0.5 if lado_x else rng.randf_range(-0.5, 0.5) * t.z))
				lote.cilindro(p, 0.08, 0.0, rng.randf_range(0.3, 0.7), toon(Color(0.80, 0.92, 1.0)), 6, Vector3(180, 0, 0))
			# Las tablas de los cajones.
			for k: int in range(int(t.y / 0.5)):
				lote.caja(Vector3(c.x, abajo + 0.5 * k + 0.25, c.z), Vector3(t.x + 0.04, 0.05, t.z + 0.04), toon(detalle_c))
		"torneo":
			lote.caja(Vector3(c.x, arriba + 0.06, c.z), Vector3(t.x + 0.24, 0.12, t.z + 0.24), toon(Color(0.95, 0.80, 0.35)))
			# Un estandarte colgado en la cara mas larga.
			var en_x := t.x >= t.z
			var colores: Array[Color] = [tema.get("acento", Color.RED), tema.get("acento2", Color.BLUE)]
			var col: Color = colores[rng.randi() % 2]
			if t.y > 1.5:
				var cara := Vector3(c.x, c.y, c.z + t.z * 0.5 + 0.03) if en_x else Vector3(c.x + t.x * 0.5 + 0.03, c.y, c.z)
				var ancho := minf(2.2, (t.x if en_x else t.z) * 0.4)
				lote.caja(cara, Vector3(ancho, t.y * 0.8, 0.05) if en_x else Vector3(0.05, t.y * 0.8, ancho), toon(col))
				lote.caja(cara + Vector3(0.0, t.y * 0.4, 0.0), Vector3(ancho + 0.2, 0.10, 0.10) if en_x else Vector3(0.10, 0.10, ancho + 0.2),
					toon(Color(0.95, 0.80, 0.35)))
		"cripta":
			lote.caja(Vector3(c.x, arriba + 0.06, c.z), Vector3(t.x + 0.20, 0.12, t.z + 0.20), tope)
			_runas(lote, c, t, luz(detalle_c, 1.6), rng)
			# Musgo en el pie.
			lote.caja(Vector3(c.x, abajo + 0.10, c.z), Vector3(t.x + 0.10, 0.20, t.z + 0.10), toon(Color(0.16, 0.26, 0.18)))
		"obsidiana":
			for k: int in range(clampi(int(area / 6.0), 2, 18)):
				var p := Vector3(c.x + rng.randf_range(-0.42, 0.42) * t.x, arriba, c.z + rng.randf_range(-0.42, 0.42) * t.z)
				var alto := rng.randf_range(0.6, 1.8)
				lote.cilindro(p + Vector3(0.0, alto * 0.5, 0.0), rng.randf_range(0.25, 0.5), 0.0, alto, tope, 5,
					Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 90), rng.randf_range(-12, 12)))
			_grietas(lote, c, t, luz(detalle_c, 2.0), rng, 4)
		"vacio":
			_aristas(lote, c, t, luz(detalle_c, 1.8), 0.07)
		"hielo":
			lote.caja(Vector3(c.x, arriba + 0.08, c.z), Vector3(t.x + 0.20, 0.16, t.z + 0.20), tope)
			for k: int in range(clampi(int((t.x + t.z) * 0.9), 2, 24)):
				var lado_x := rng.randf() < 0.5
				var p := Vector3(c.x + (rng.randf_range(-0.5, 0.5) * t.x if lado_x else signf(rng.randf() - 0.5) * t.x * 0.5),
					arriba - 0.3, c.z + (signf(rng.randf() - 0.5) * t.z * 0.5 if lado_x else rng.randf_range(-0.5, 0.5) * t.z))
				lote.cilindro(p, 0.10, 0.0, rng.randf_range(0.4, 0.9), toon(detalle_c), 6, Vector3(180, 0, 0))
			_aristas(lote, c, t, toon(Color(0.95, 0.98, 1.0)), 0.06)
		"cristal":
			for k: int in range(clampi(int(area / 10.0), 1, 10)):
				var p := Vector3(c.x + rng.randf_range(-0.4, 0.4) * t.x, arriba, c.z + rng.randf_range(-0.4, 0.4) * t.z)
				var alto := rng.randf_range(0.8, 2.2)
				var r := rng.randf_range(0.18, 0.40)
				var giro := Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 60), rng.randf_range(-20, 20))
				lote.cilindro(p + Vector3(0.0, alto * 0.5, 0.0), r, r, alto, luz(detalle_c, 1.1), 6, giro)
			_aristas(lote, c, t, luz(tema.get("acento", Color.GOLD), 1.4), 0.06)
		"marmol":
			var oro := toon(detalle_c)
			lote.caja(Vector3(c.x, arriba + 0.06, c.z), Vector3(t.x + 0.24, 0.12, t.z + 0.24), oro)
			lote.caja(Vector3(c.x, abajo + 0.15, c.z), Vector3(t.x + 0.18, 0.30, t.z + 0.18), oro)
			if t.y > 1.6:
				lote.caja(Vector3(c.x, c.y, c.z), Vector3(t.x + 0.04, 0.08, t.z + 0.04), oro)


## Lineas quebradas sobre las caras de un bloque (grietas, o lava si el material brilla).
static func _grietas(lote: Lote, c: Vector3, t: Vector3, mat: Material, rng: RandomNumberGenerator, n: int) -> void:
	if t.y < 1.0:
		return
	for k: int in range(n):
		var cara := rng.randi() % 4
		var u := rng.randf_range(-0.4, 0.4)
		var z0 := c.y + rng.randf_range(-0.3, 0.3) * t.y
		var largo := rng.randf_range(0.5, 1.2) * minf(t.y, 2.5)
		var p: Vector3
		var tam: Vector3
		match cara:
			0: p = Vector3(c.x + u * t.x, z0, c.z + t.z * 0.5 + 0.02); tam = Vector3(0.07, largo, 0.03)
			1: p = Vector3(c.x + u * t.x, z0, c.z - t.z * 0.5 - 0.02); tam = Vector3(0.07, largo, 0.03)
			2: p = Vector3(c.x + t.x * 0.5 + 0.02, z0, c.z + u * t.z); tam = Vector3(0.03, largo, 0.07)
			_: p = Vector3(c.x - t.x * 0.5 - 0.02, z0, c.z + u * t.z); tam = Vector3(0.03, largo, 0.07)
		lote.caja(p, tam, mat, Vector3(0.0, 0.0, rng.randf_range(-25, 25)) if cara < 2 else Vector3(rng.randf_range(-25, 25), 0.0, 0.0))


## Las runas que brillan en las caras de un bloque de la cripta.
static func _runas(lote: Lote, c: Vector3, t: Vector3, mat: Material, rng: RandomNumberGenerator) -> void:
	if t.y < 1.2:
		return
	for cara: int in range(4):
		var en_z := cara < 2
		var ancho := t.x if en_z else t.z
		var n := clampi(int(ancho / 2.5), 1, 6)
		for k: int in range(n):
			var u := -ancho * 0.5 + ancho * (k + 0.5) / n
			var p := Vector3(c.x + u, c.y, c.z + (t.z * 0.5 + 0.02) * (1 if cara == 0 else -1)) if en_z \
				else Vector3(c.x + (t.x * 0.5 + 0.02) * (1 if cara == 2 else -1), c.y, c.z + u)
			var alto := minf(t.y * 0.5, 1.1)
			var grosor := Vector3(0.06, alto, 0.03) if en_z else Vector3(0.03, alto, 0.06)
			lote.caja(p, grosor, mat)
			var tr := Vector3(0.38, 0.06, 0.03) if en_z else Vector3(0.03, 0.06, 0.38)
			lote.caja(p + Vector3(0.0, alto * rng.randf_range(-0.3, 0.3), 0.0), tr, mat)


## Las doce aristas de un bloque, como lineas (hielo, vacio, cristal).
static func _aristas(lote: Lote, c: Vector3, t: Vector3, mat: Material, g: float) -> void:
	var h := t * 0.5
	for sy: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			lote.caja(c + Vector3(0.0, h.y * sy, h.z * sz), Vector3(t.x + g, g, g), mat)
		for sx: float in [-1.0, 1.0]:
			lote.caja(c + Vector3(h.x * sx, h.y * sy, 0.0), Vector3(g, g, t.z + g), mat)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			lote.caja(c + Vector3(h.x * sx, 0.0, h.z * sz), Vector3(g, t.y + g, g), mat)


# ==================================================================== Columnas

## La forma de una columna. La colision es el cilindro de la Arena: lo que se ve cerca del
## piso tiene que tener mas o menos ese radio; lo de arriba (la copa de un pino, el
## estandarte) puede salirse, porque queda por encima de las cabezas.
static func _pilar(lote: Lote, tema: Dictionary, base: Vector3, r: float, alto: float, rng: RandomNumberGenerator) -> void:
	var pil: Dictionary = tema.get("pilar", {})
	var col := toon(pil.get("color", Color.GRAY))
	var det_c: Color = pil.get("detalle", Color.DIM_GRAY)
	var det := toon(det_c)
	var c := base + Vector3(0.0, alto * 0.5, 0.0)
	match String(pil.get("estilo", "")):
		"columna":
			lote.cilindro(c, r, r * 0.92, alto - 0.8, col, 16)
			lote.cilindro(base + Vector3(0.0, 0.25, 0.0), r * 1.30, r * 1.20, 0.5, det, 16)
			lote.caja(base + Vector3(0.0, 0.06, 0.0), Vector3(r * 2.8, 0.12, r * 2.8), det)
			lote.cilindro(base + Vector3(0.0, alto - 0.42, 0.0), r * 0.95, r * 1.30, 0.34, det, 16)
			lote.caja(base + Vector3(0.0, alto - 0.12, 0.0), Vector3(r * 2.9, 0.24, r * 2.9), det)
			# Las estrias del fuste.
			for k: int in range(8):
				var a := TAU * k / 8.0
				lote.caja(base + Vector3(sin(a) * r * 0.98, alto * 0.5, cos(a) * r * 0.98), Vector3(0.06, alto - 1.4, 0.06),
					toon((pil.get("color", Color.GRAY) as Color).darkened(0.12)), Vector3(0.0, rad_to_deg(a), 0.0))
		"pino":
			lote.cilindro(base + Vector3(0.0, 1.6, 0.0), r * 0.55, r * 0.45, 3.2, det, 10)
			var verde: Color = pil.get("color", Color.DARK_GREEN)
			for k: int in range(4):
				var y := 2.4 + k * (alto - 2.0) * 0.22
				var radio := r * (3.6 - k * 0.7)
				lote.cilindro(base + Vector3(0.0, y + 1.1, 0.0), radio, 0.0, 2.6, toon(verde.lightened(0.04 * k)), 12)
				lote.cilindro(base + Vector3(0.0, y + 1.6, 0.0), radio * 0.7, 0.0, 1.6, toon(Color(0.93, 0.96, 1.0)), 12)
		"estandarte":
			lote.cilindro(c, r * 0.35, r * 0.30, alto, toon(Color(0.80, 0.70, 0.40)), 10)
			lote.cilindro(base + Vector3(0.0, 0.4, 0.0), r * 1.1, r * 0.9, 0.8, col, 12)
			lote.caja(base + Vector3(0.0, alto - 0.4, 0.0), Vector3(r * 3.2, 0.12, 0.12), toon(Color(0.80, 0.70, 0.40)))
			var colores: Array[Color] = [tema.get("acento", Color.RED), tema.get("acento2", Color.BLUE)]
			var color_b: Color = colores[rng.randi() % 2]
			lote.caja(base + Vector3(0.0, alto - 2.2, 0.0), Vector3(r * 3.0, 3.4, 0.06), toon(color_b))
			lote.caja(base + Vector3(0.0, alto - 3.95, 0.0), Vector3(r * 3.0, 0.14, 0.08), toon(Color(0.95, 0.80, 0.35)))
		"estalagmita":
			lote.cilindro(c, r * 1.25, r * 0.15, alto, col, 9)
			for k: int in range(3):
				var a := rng.randf_range(0.0, TAU)
				lote.cilindro(base + Vector3(sin(a) * r * 1.3, 0.8, cos(a) * r * 1.3), r * 0.5, 0.0, 1.8, col, 7)
			# Los hongos que brillan al pie.
			for k: int in range(4):
				var a2 := rng.randf_range(0.0, TAU)
				lote.esfera(base + Vector3(sin(a2) * r * 1.5, 0.15, cos(a2) * r * 1.5), 0.18, luz(det_c, 1.6),
					Vector3(1.0, 0.6, 1.0), 8)
		"espina":
			lote.cilindro(c, r * 1.20, 0.05, alto, col, 6, Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))
			for k: int in range(4):
				var a := TAU * k / 4.0 + rng.randf_range(-0.3, 0.3)
				var y := rng.randf_range(alto * 0.3, alto * 0.7)
				lote.cilindro(base + Vector3(sin(a) * r * 0.9, y, cos(a) * r * 0.9), r * 0.30, 0.0, 1.6, col, 5,
					Vector3(cos(a) * 55.0, 0.0, -sin(a) * 55.0))
			lote.caja(c, Vector3(0.10, alto * 0.7, r * 2.0 + 0.04), luz(det_c, 2.2))
		"obelisco":
			lote.caja(c, Vector3(r * 1.7, alto, r * 1.7), col)
			lote.cilindro(base + Vector3(0.0, alto + 0.6, 0.0), r * 1.2, 0.0, 1.2, col, 4)
			for sx: float in [-1.0, 1.0]:
				lote.caja(base + Vector3(r * 0.86 * sx, alto * 0.5, 0.0), Vector3(0.04, alto * 0.9, 0.10), luz(det_c, 1.8))
				lote.caja(base + Vector3(0.0, alto * 0.5, r * 0.86 * sx), Vector3(0.10, alto * 0.9, 0.04), luz(det_c, 1.8))
		"hielo":
			lote.cilindro(c, r * 1.10, r * 0.35, alto, col, 6)
			lote.cilindro(base + Vector3(0.0, alto + 0.8, 0.0), r * 0.35, 0.0, 1.6, col, 6)
			for k: int in range(5):
				var a := rng.randf_range(0.0, TAU)
				var largo := rng.randf_range(1.5, 3.5)
				lote.cilindro(base + Vector3(sin(a) * r, largo * 0.4, cos(a) * r), r * 0.4, 0.0, largo, toon(det_c), 6,
					Vector3(cos(a) * 25.0, 0.0, -sin(a) * 25.0))
		"cristal":
			lote.cilindro(c, r * 1.05, r * 1.05, alto, toon(pil.get("color", Color.PURPLE)), 6)
			lote.cilindro(base + Vector3(0.0, alto + 0.7, 0.0), r * 1.05, 0.0, 1.4, toon(pil.get("color", Color.PURPLE)), 6)
			lote.cilindro(base + Vector3(0.0, alto * 0.5, 0.0), r * 1.08, r * 1.08, 0.18, luz(det_c, 1.6), 6)
			for k: int in range(4):
				var a := rng.randf_range(0.0, TAU)
				var largo := rng.randf_range(1.0, 2.5)
				lote.cilindro(base + Vector3(sin(a) * r * 1.4, largo * 0.4, cos(a) * r * 1.4), r * 0.35, r * 0.35, largo,
					luz((pil.get("color", Color.PURPLE) as Color).lightened(0.3), 1.0), 6, Vector3(cos(a) * 30.0, 0.0, -sin(a) * 30.0))
		_:
			lote.cilindro(c, r, r, alto, col, 14)


# ===================================================================== Paredes

## Lo que se ve en la cara de adentro de las paredes (el muro solido es de la Arena).
static func _paredes(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var par: Dictionary = tema.get("pared", {})
	var trim: Color = par.get("trim", Art.TRIM)
	var color: Color = par.get("color", Art.WALL)
	var h := 12.0
	for lado: int in range(4):
		for k: int in range(10):
			var u := -MITAD + 6.0 + k * 12.0
			var pos := _sobre_pared(lado, u, 0.0)
			var adentro := _hacia_adentro(lado)
			var giro := _giro_pared(lado)
			match String(par.get("estilo", "")):
				"coliseo":
					# Arcos con la sombra adentro, y una antorcha entre arco y arco.
					lote.caja(pos + Vector3(0.0, 3.6, 0.0) + adentro * 0.6, _rot_tam(Vector3(5.2, 7.2, 0.3), lado), toon(color.darkened(0.55)))
					lote.cilindro(pos + Vector3(0.0, 7.2, 0.0) + adentro * 0.62, 2.6, 2.6, 0.32, toon(color.darkened(0.55)), 14,
						_rot_eje(lado))
					var antorcha := _sobre_pared(lado, u + 6.0, 0.0) + adentro * 0.9
					lote.cilindro(antorcha + Vector3(0.0, 4.4, 0.0), 0.10, 0.18, 0.9, toon(Color(0.30, 0.22, 0.14)), 8)
					lote.esfera(antorcha + Vector3(0.0, 5.05, 0.0), 0.28, luz(trim, 3.0), Vector3(1.0, 1.4, 1.0), 8)
				"pueblo":
					# Una cerca de madera con nieve arriba, y faroles cada tanto.
					for t: int in range(6):
						var poste := _sobre_pared(lado, u - 5.0 + t * 2.0, 0.0) + adentro * 0.7
						lote.caja(poste + Vector3(0.0, 1.1, 0.0), _rot_tam(Vector3(0.28, 2.2, 0.16), lado), toon(color))
						lote.caja(poste + Vector3(0.0, 2.28, 0.0), _rot_tam(Vector3(0.36, 0.14, 0.24), lado), toon(Color(0.95, 0.97, 1.0)))
					lote.caja(pos + Vector3(0.0, 1.5, 0.0) + adentro * 0.62, _rot_tam(Vector3(12.0, 0.18, 0.10), lado), toon(color.darkened(0.2)))
					lote.caja(pos + Vector3(0.0, 0.7, 0.0) + adentro * 0.62, _rot_tam(Vector3(12.0, 0.18, 0.10), lado), toon(color.darkened(0.2)))
					if k % 2 == 0:
						var farol := pos + adentro * 2.0
						lote.cilindro(farol + Vector3(0.0, 2.2, 0.0), 0.09, 0.09, 4.4, toon(Color(0.12, 0.12, 0.14)), 8)
						lote.caja(farol + Vector3(0.0, 4.55, 0.0), Vector3(0.45, 0.55, 0.45), toon(Color(0.12, 0.12, 0.14)))
						lote.esfera(farol + Vector3(0.0, 4.5, 0.0), 0.22, luz(trim, 3.0), Vector3.ONE, 8)
				"torneo":
					# Las tribunas pintadas y una bandera arriba de cada tramo.
					lote.caja(pos + Vector3(0.0, 2.0, 0.0) + adentro * 0.55, _rot_tam(Vector3(11.4, 0.4, 0.12), lado), luz(trim, 0.9))
					var mastil := pos + adentro * 0.2
					lote.cilindro(mastil + Vector3(0.0, h + 2.5, 0.0), 0.08, 0.08, 5.0, toon(Color(0.80, 0.70, 0.40)), 8)
					var colores: Array[Color] = [tema.get("acento", Color.RED), tema.get("acento2", Color.BLUE), Color(0.95, 0.80, 0.35)]
					lote.caja(mastil + Vector3(0.0, h + 4.2, 0.0) + _a_lo_largo(lado) * 0.9, _rot_tam(Vector3(1.8, 1.1, 0.05), lado),
						toon(colores[k % 3]))
				"caverna":
					# Roca rugosa: piedras grandes contra la pared, y caños con luz.
					for t: int in range(3):
						var roca := _sobre_pared(lado, u + rng.randf_range(-5.0, 5.0), 0.0) + adentro * rng.randf_range(0.5, 1.6)
						lote.esfera(roca + Vector3(0.0, rng.randf_range(1.0, 7.0), 0.0), rng.randf_range(1.2, 2.6), toon(color.lightened(0.05)),
							Vector3(1.0, rng.randf_range(0.7, 1.4), 0.8), 8)
					lote.caja(pos + Vector3(0.0, 5.0 + (k % 3) * 1.5, 0.0) + adentro * 0.75, _rot_tam(Vector3(12.0, 0.10, 0.10), lado), luz(trim, 1.4))
				"volcan":
					# Riscos de obsidiana y cascadas de lava cayendo por la pared.
					for t: int in range(3):
						var punta := _sobre_pared(lado, u + rng.randf_range(-5.0, 5.0), 0.0) + adentro * rng.randf_range(0.6, 1.8)
						var alto := rng.randf_range(4.0, 11.0)
						lote.cilindro(punta + Vector3(0.0, alto * 0.5, 0.0), rng.randf_range(0.8, 1.6), 0.0, alto, toon(color), 5)
					if k % 3 == 1:
						lote.caja(pos + Vector3(0.0, h * 0.5, 0.0) + adentro * 0.56, _rot_tam(Vector3(1.6, h, 0.06), lado), luz(trim, 2.6))
						lote.esfera(pos + adentro * 1.4, 1.0, luz(trim, 2.6), Vector3(2.4, 0.15, 1.6), 10)
				"vacio":
					for t: int in range(16):
						var p := _sobre_pared(lado, u + rng.randf_range(-6.0, 6.0), 0.0) + adentro * 0.53
						var r := rng.randf_range(0.03, 0.09)
						lote.caja(p + Vector3(0.0, rng.randf_range(0.5, h), 0.0), Vector3(r, r, r), luz(Color(0.9, 0.92, 1.0), 2.2))
				"glaciar":
					for t: int in range(3):
						var punta := _sobre_pared(lado, u + rng.randf_range(-5.0, 5.0), 0.0) + adentro * rng.randf_range(0.6, 1.6)
						var alto := rng.randf_range(4.0, 10.0)
						lote.cilindro(punta + Vector3(0.0, alto * 0.5, 0.0), rng.randf_range(0.9, 1.8), 0.0, alto,
							toon(color.lightened(rng.randf_range(0.0, 0.2))), 6)
					for t: int in range(10):
						var p := _sobre_pared(lado, u + rng.randf_range(-6.0, 6.0), 0.0) + adentro * 0.6
						lote.cilindro(p + Vector3(0.0, h - 0.6, 0.0), 0.16, 0.0, rng.randf_range(0.8, 2.0), toon(Color(0.85, 0.94, 1.0)), 6,
							Vector3(180, 0, 0))
				"cristal":
					lote.caja(pos + Vector3(0.0, h * 0.5, 0.0) + adentro * 0.55, _rot_tam(Vector3(0.12, h, 0.08), lado), luz(trim, 1.4))
					for t: int in range(2):
						var punta := _sobre_pared(lado, u + rng.randf_range(-5.0, 5.0), 0.0) + adentro * 1.0
						var alto := rng.randf_range(3.0, 8.0)
						lote.cilindro(punta + Vector3(0.0, alto * 0.5, 0.0), 0.7, 0.7, alto, luz(color.lightened(0.3), 0.9), 6,
							Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15)))
				"ciudad":
					# La baranda de una calle, con postes de luz cada tanto.
					lote.caja(pos + Vector3(0.0, 0.5, 0.0) + adentro * 0.7, _rot_tam(Vector3(12.0, 1.0, 0.5), lado), toon(color))
					lote.caja(pos + Vector3(0.0, 1.05, 0.0) + adentro * 0.7, _rot_tam(Vector3(12.0, 0.12, 0.6), lado),
						toon(color.lightened(0.15)))
					if k % 2 == 0:
						var poste := pos + adentro * 1.4
						lote.cilindro(poste + Vector3(0.0, 3.0, 0.0), 0.1, 0.1, 6.0, toon(Color(0.30, 0.31, 0.34)), 8)
						lote.caja(poste + Vector3(0.0, 6.0, 0.0) + adentro * 0.6, _rot_tam(Vector3(0.3, 0.12, 1.4), lado),
							toon(Color(0.30, 0.31, 0.34)))
						lote.esfera(poste + Vector3(0.0, 5.9, 0.0) + adentro * 1.2, 0.2, luz(trim, 2.4), Vector3(1.4, 0.6, 1.4), 8)
				"nubes":
					# Una balaustrada de marmol con el pasamanos dorado.
					for t: int in range(12):
						var balaustre := _sobre_pared(lado, u - 5.5 + t, 0.0) + adentro * 0.75
						lote.cilindro(balaustre + Vector3(0.0, 0.6, 0.0), 0.16, 0.12, 1.2, toon(color), 8)
					lote.caja(pos + Vector3(0.0, 1.28, 0.0) + adentro * 0.75, _rot_tam(Vector3(12.0, 0.18, 0.40), lado), toon(Color(1.0, 0.82, 0.35)))


## Un punto pegado a la pared `lado` (0 norte, 1 sur, 2 oeste, 3 este), a `u` metros a lo
## largo, a `y` de alto.
static func _sobre_pared(lado: int, u: float, y: float) -> Vector3:
	match lado:
		0: return Vector3(u, y, -MITAD)
		1: return Vector3(u, y, MITAD)
		2: return Vector3(-MITAD, y, u)
		_: return Vector3(MITAD, y, u)


static func _hacia_adentro(lado: int) -> Vector3:
	match lado:
		0: return Vector3(0, 0, 1)
		1: return Vector3(0, 0, -1)
		2: return Vector3(1, 0, 0)
		_: return Vector3(-1, 0, 0)


static func _a_lo_largo(lado: int) -> Vector3:
	return Vector3(1, 0, 0) if lado < 2 else Vector3(0, 0, 1)


static func _giro_pared(lado: int) -> float:
	return 0.0 if lado < 2 else 90.0


## Un tamaño pensado para las paredes norte y sur, girado para las del este y el oeste.
static func _rot_tam(t: Vector3, lado: int) -> Vector3:
	return t if lado < 2 else Vector3(t.z, t.y, t.x)


static func _rot_eje(lado: int) -> Vector3:
	return Vector3(90, 0, 0) if lado < 2 else Vector3(0, 0, 90)


## Un punto afuera de la Arena, a `d` metros de la pared `lado`.
static func _afuera(lado: int, u: float, d: float, y: float = 0.0) -> Vector3:
	return _sobre_pared(lado, u, y) - _hacia_adentro(lado) * d


# =================================================================== Decorados

## EL COLISEO: las gradas en escalones alrededor, con publico, y la grieta del cielo.
static func _gradas(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var piedra: Color = tema["pared"]["color"]
	for lado: int in range(4):
		for nivel: int in range(5):
			var d := 2.5 + nivel * 4.0
			var y := 6.0 + nivel * 3.2
			lote.caja(_afuera(lado, 0.0, d, y * 0.5), _rot_tam(Vector3(MITAD * 2.0 + d * 2.0, y, 4.2), lado),
				toon(piedra.lightened(0.04 * nivel)))
			# El publico: ecos sentados que miran la pelea.
			for k: int in range(18):
				var u := rng.randf_range(-MITAD - d, MITAD + d)
				var p := _afuera(lado, u, d, y)
				var colores: Array[Color] = [Color(0.30, 0.25, 0.45), Color(0.45, 0.30, 0.55), Color(0.25, 0.30, 0.50), Color(0.55, 0.40, 0.60)]
				lote.caja(p + Vector3(0.0, 0.45, 0.0), Vector3(0.6, 0.9, 0.6), toon(colores[k % 4]))
				lote.esfera(p + Vector3(0.0, 1.15, 0.0), 0.28, toon(Color(0.12, 0.10, 0.18)), Vector3.ONE, 6)
		# Arcos grandes arriba de la ultima grada.
		for k: int in range(8):
			var u := -MITAD + 7.5 + k * 15.0
			var p := _afuera(lado, u, 21.0, 22.0)
			lote.caja(p, _rot_tam(Vector3(2.0, 8.0, 2.0), lado), toon(piedra.darkened(0.1)))
		lote.caja(_afuera(lado, 0.0, 21.0, 26.4), _rot_tam(Vector3(MITAD * 2.0 + 44.0, 1.2, 2.4), lado), toon(piedra.darkened(0.1)))
	_grieta_del_cielo(lote, tema)


## La grieta del cielo roto: una cicatriz de luz cruzando el cielo.
static func _grieta_del_cielo(lote: Lote, tema: Dictionary) -> void:
	var color: Color = tema.get("grieta", Color(0.85, 0.55, 1.0))
	var p := Vector3(-140.0, 120.0, -90.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k: int in range(16):
		var q := p + Vector3(rng.randf_range(14.0, 22.0), rng.randf_range(-8.0, 8.0), rng.randf_range(6.0, 14.0))
		var medio := (p + q) * 0.5
		var largo := p.distance_to(q)
		var xf := Transform3D(Basis.looking_at((q - p).normalized(), Vector3.UP), medio)
		var m := BoxMesh.new()
		m.size = Vector3(rng.randf_range(1.6, 3.4), 0.6, largo)
		lote.poner(m, xf, luz(color, 3.2))
		p = q


## HOMETOWN: las casas del pueblo detras de la cerca, con las ventanas prendidas, y el
## arbol de Navidad de la plaza.
static func _pueblo(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var paredes_casa: Array[Color] = [Color(0.62, 0.40, 0.32), Color(0.75, 0.70, 0.58), Color(0.40, 0.46, 0.58), Color(0.66, 0.56, 0.40)]
	for lado: int in range(4):
		for k: int in range(7):
			var u := -MITAD + 9.0 + k * 17.0 + rng.randf_range(-2.0, 2.0)
			var d := rng.randf_range(8.0, 14.0)
			var ancho := rng.randf_range(8.0, 12.0)
			var alto := rng.randf_range(5.0, 8.0)
			var base := _afuera(lado, u, d)
			lote.caja(base + Vector3(0.0, alto * 0.5, 0.0), _rot_tam(Vector3(ancho, alto, 8.0), lado), toon(paredes_casa[(k + lado) % 4]))
			lote.techo_dos_aguas(base + Vector3(0.0, alto + 1.6, 0.0), _rot_tam(Vector3(ancho + 1.0, 3.2, 9.0), lado),
				toon(Color(0.95, 0.97, 1.0)), _giro_pared(lado))
			# Ventanas prendidas en la cara que mira a la Arena.
			for v: int in range(2):
				var w := base + _hacia_adentro(lado) * 4.05 + _a_lo_largo(lado) * (v * 2.0 - 1.0) * ancho * 0.25
				lote.caja(w + Vector3(0.0, alto * 0.55, 0.0), _rot_tam(Vector3(1.3, 1.4, 0.08), lado), luz(Color(1.0, 0.78, 0.40), 2.0))
			lote.caja(base + _hacia_adentro(lado) * 4.05 + Vector3(0.0, 1.1, 0.0), _rot_tam(Vector3(1.2, 2.2, 0.08), lado),
				toon(Color(0.30, 0.20, 0.14)))
			lote.caja(base + Vector3(0.0, alto + 2.6, 0.0) + _a_lo_largo(lado) * ancho * 0.25, Vector3(0.7, 2.0, 0.7),
				toon(Color(0.35, 0.25, 0.22)))
	# El arbol de Navidad, detras de la cerca del norte, con sus luces.
	var arbol := _afuera(0, 0.0, 16.0)
	lote.cilindro(arbol + Vector3(0.0, 1.5, 0.0), 0.8, 0.7, 3.0, toon(Color(0.36, 0.24, 0.16)), 10)
	for k: int in range(5):
		lote.cilindro(arbol + Vector3(0.0, 4.0 + k * 3.0, 0.0), 7.0 - k * 1.2, 0.0, 5.0, toon(Color(0.12, 0.36, 0.22)), 14)
	for k: int in range(40):
		var y := rng.randf_range(3.0, 17.0)
		var r := (7.0 - (y - 3.0) * 0.38) * 0.75
		var a := rng.randf_range(0.0, TAU)
		var colores: Array[Color] = [Color(1.0, 0.25, 0.25), Color(1.0, 0.85, 0.3), Color(0.3, 0.7, 1.0), Color(0.4, 1.0, 0.5)]
		lote.esfera(arbol + Vector3(sin(a) * r, y, cos(a) * r), 0.3, luz(colores[k % 4], 2.4), Vector3.ONE, 6)
	lote.esfera(arbol + Vector3(0.0, 20.5, 0.0), 0.9, luz(Color(1.0, 0.85, 0.35), 3.0), Vector3.ONE, 8)
	# La luna es el disco del cielo, que sigue a la luz de la luna (ver Mapas, "sol").


## LA TORRE: arriba de la torre del medio sigue la torre de verdad, altisima, con
## ventanas; y alrededor, las tribunas del torneo.
static func _torre(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var piedra := toon(Color(0.80, 0.78, 0.72))
	var y := 8.7
	var lado_t := 6.0
	for k: int in range(9):
		var alto := 7.0
		lote.caja(Vector3(0.0, y + alto * 0.5, 0.0), Vector3(lado_t, alto, lado_t), piedra)
		lote.caja(Vector3(0.0, y + alto, 0.0), Vector3(lado_t + 0.8, 0.5, lado_t + 0.8), toon(Color(0.95, 0.80, 0.35)))
		for cara: int in range(4):
			var a := TAU * cara / 4.0
			lote.caja(Vector3(sin(a) * (lado_t * 0.5 + 0.02), y + alto * 0.5, cos(a) * (lado_t * 0.5 + 0.02)),
				Vector3(1.0, 2.0, 0.06) if cara % 2 == 0 else Vector3(0.06, 2.0, 1.0), luz(tema["luces"]["centro"], 2.2))
		y += alto
		lado_t *= 0.94
	lote.cilindro(Vector3(0.0, y + 3.0, 0.0), lado_t * 0.6, 0.0, 6.0, toon(Color(0.95, 0.80, 0.35)), 4)
	lote.esfera(Vector3(0.0, y + 7.5, 0.0), 2.0, luz(Color(0.55, 0.85, 1.0), 3.0), Vector3(1.0, 1.4, 1.0), 8)
	# Las tribunas afuera, en escalones, con banderas.
	for lado: int in range(4):
		for nivel: int in range(4):
			var d := 2.5 + nivel * 4.0
			var alto_g := 4.0 + nivel * 3.0
			lote.caja(_afuera(lado, 0.0, d, alto_g * 0.5), _rot_tam(Vector3(MITAD * 2.0 + d * 2.0, alto_g, 4.2), lado),
				toon(Color(0.70, 0.67, 0.60).darkened(0.05 * nivel)))
			for k: int in range(14):
				var u := rng.randf_range(-MITAD - d, MITAD + d)
				var p := _afuera(lado, u, d, alto_g)
				var colores: Array[Color] = [tema["acento"], tema["acento2"], Color(0.95, 0.80, 0.35), Color(0.30, 0.60, 0.35)]
				lote.caja(p + Vector3(0.0, 0.45, 0.0), Vector3(0.6, 0.9, 0.6), toon(colores[k % 4]))
				lote.esfera(p + Vector3(0.0, 1.15, 0.0), 0.28, toon(Color(0.85, 0.70, 0.55)), Vector3.ONE, 6)
	_montanas(lote, toon(Color(0.40, 0.42, 0.55)), toon(Color(0.92, 0.94, 1.0)), rng, 200.0, 70.0)


## EL SOTANO: el techo de roca con las estalactitas, y caños por todos lados.
static func _caverna(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var roca := toon(Color(0.14, 0.14, 0.16))
	lote.caja(Vector3(0.0, 26.0, 0.0), Vector3(MITAD * 2.0 + 20.0, 2.0, MITAD * 2.0 + 20.0), roca)
	for k: int in range(70):
		var p := Vector3(rng.randf_range(-MITAD, MITAD), 25.0, rng.randf_range(-MITAD, MITAD))
		var largo := rng.randf_range(2.0, 9.0)
		lote.cilindro(p - Vector3(0.0, largo * 0.5, 0.0), rng.randf_range(0.5, 1.4), 0.0, largo, roca, 7, Vector3(180, 0, 0))
	for k: int in range(18):
		var p := Vector3(rng.randf_range(-MITAD, MITAD), 24.5, rng.randf_range(-MITAD, MITAD))
		lote.esfera(p, rng.randf_range(0.4, 0.9), luz(tema["acento"], 2.0), Vector3(1.0, 1.6, 1.0), 6)
	# Las paredes de roca siguen por encima del muro hasta el techo.
	for lado: int in range(4):
		lote.caja(_afuera(lado, 0.0, 1.5, 19.0), _rot_tam(Vector3(MITAD * 2.0 + 6.0, 14.0, 3.0), lado), roca)
		for k: int in range(6):
			var u := -MITAD + 10.0 + k * 20.0
			lote.cilindro(_sobre_pared(lado, u, 0.0) + _hacia_adentro(lado) * 1.0 + Vector3(0.0, 12.5, 0.0), 0.35, 0.35, 25.0,
				toon(Color(0.30, 0.28, 0.24)), 10)


## EL INFRAMUNDO: los volcanes del horizonte, con la boca encendida, y cadenas colgando.
static func _volcanes(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var roca := toon(Color(0.10, 0.07, 0.07))
	for k: int in range(10):
		var a := TAU * k / 10.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(150.0, 230.0)
		var alto := rng.randf_range(50.0, 95.0)
		var base := Vector3(sin(a) * d, 0.0, cos(a) * d)
		lote.cilindro(base + Vector3(0.0, alto * 0.5, 0.0), alto * 0.75, alto * 0.08, alto, roca, 10)
		lote.esfera(base + Vector3(0.0, alto + 1.0, 0.0), alto * 0.09, luz(tema["acento"], 3.2), Vector3(1.0, 0.4, 1.0), 10)
		lote.caja(base + Vector3(alto * 0.05, alto * 0.6, 0.0), Vector3(alto * 0.03, alto * 0.8, alto * 0.02), luz(tema["acento"], 2.4),
			Vector3(0.0, rad_to_deg(a), -12.0))
	for lado: int in range(4):
		lote.caja(_afuera(lado, 0.0, 6.0, 7.0), _rot_tam(Vector3(MITAD * 2.0 + 20.0, 14.0, 6.0), lado), roca)
	# Cadenas que bajan del cielo rojo, de eslabones.
	for k: int in range(8):
		var p := Vector3(rng.randf_range(-MITAD, MITAD), 40.0, rng.randf_range(-MITAD, MITAD))
		for e: int in range(14):
			lote.cilindro(p - Vector3(0.0, e * 0.9, 0.0), 0.28, 0.28, 0.12, toon(Color(0.20, 0.18, 0.18)), 10,
				Vector3(90 if e % 2 else 0, 0, 90))


## EL VACIO: un cielo lleno de estrellas y la espiral de una galaxia.
static func _vacio(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	for k: int in range(500):
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var r := rng.randf_range(0.4, 1.6)
		lote.esfera(dir * 280.0, r, luz(Color(0.85, 0.90, 1.0), rng.randf_range(1.5, 4.0)), Vector3.ONE, 4)
	for k: int in range(260):
		var t := float(k) / 260.0
		var a := t * TAU * 2.0
		var radio := 20.0 + t * 90.0
		var p := Vector3(cos(a) * radio, 170.0 + sin(a * 0.5) * 6.0, sin(a) * radio - 120.0)
		lote.esfera(p, rng.randf_range(0.8, 2.2), luz((tema["acento2"] as Color).lerp(tema["acento"], t), 2.6), Vector3.ONE, 4)
	# Formas que flotan quietas alrededor de la Arena.
	for k: int in range(14):
		var a := TAU * k / 14.0
		var p := Vector3(sin(a) * 95.0, rng.randf_range(10.0, 45.0), cos(a) * 95.0)
		lote.caja(p, Vector3.ONE * rng.randf_range(3.0, 7.0), toon(Color(0.06, 0.06, 0.12)),
			Vector3(rng.randf_range(0, 90), rng.randf_range(0, 90), rng.randf_range(0, 90)))


## LA ARENA HELADA: montañas nevadas y un muro de hielo encima de la pared.
static func _glaciar(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	_montanas(lote, toon(Color(0.60, 0.70, 0.82)), toon(Color(0.96, 0.98, 1.0)), rng, 180.0, 85.0)
	for lado: int in range(4):
		for k: int in range(12):
			var u := -MITAD + 5.0 + k * 10.0
			var alto := rng.randf_range(10.0, 22.0)
			lote.cilindro(_afuera(lado, u, rng.randf_range(2.0, 6.0), alto * 0.5), rng.randf_range(2.5, 4.5), 0.0, alto,
				toon(Color(0.62, 0.78, 0.92).lightened(rng.randf_range(0.0, 0.2))), 6)


static func _montanas(lote: Lote, roca: Material, nieve: Material, rng: RandomNumberGenerator, d: float, alto_max: float) -> void:
	for k: int in range(16):
		var a := TAU * k / 16.0 + rng.randf_range(-0.1, 0.1)
		var dist := d + rng.randf_range(0.0, 60.0)
		var alto := rng.randf_range(alto_max * 0.5, alto_max)
		var base := Vector3(sin(a) * dist, 0.0, cos(a) * dist)
		lote.cilindro(base + Vector3(0.0, alto * 0.5, 0.0), alto * 0.9, 0.0, alto, roca, 8)
		lote.cilindro(base + Vector3(0.0, alto * 0.84, 0.0), alto * 0.29, 0.0, alto * 0.32, nieve, 8)


## EL NUCLEO: el cristal gigante encima de la torre, con sus anillos, y las islas que
## cuelgan dadas vuelta del cielo (la gravedad se da vuelta).
static func _nucleo(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var c := Vector3(0.0, 24.0, 0.0)
	lote.cilindro(c + Vector3(0.0, 4.5, 0.0), 3.6, 0.0, 9.0, luz(tema["acento"], 2.2), 6)
	lote.cilindro(c - Vector3(0.0, 4.5, 0.0), 3.6, 0.0, 9.0, luz(tema["acento"], 2.2), 6, Vector3(180, 0, 0))
	for k: int in range(3):
		var r := 7.0 + k * 3.0
		for s: int in range(40):
			var a := TAU * s / 40.0
			lote.caja(c + Vector3(sin(a) * r, 0.0, cos(a) * r), Vector3(0.25, 0.25, TAU * r / 40.0 + 0.1), luz(tema["acento2"], 1.8),
				Vector3(20.0 * (k - 1), rad_to_deg(a), 0.0))
	var roca := toon(Color(0.22, 0.16, 0.26))
	var pasto := toon(Color(0.40, 0.28, 0.52))
	for k: int in range(12):
		var a := TAU * k / 12.0 + rng.randf_range(-0.2, 0.2)
		var d := rng.randf_range(70.0, 130.0)
		var p := Vector3(sin(a) * d, rng.randf_range(45.0, 80.0), cos(a) * d)
		var ancho := rng.randf_range(8.0, 18.0)
		# Dada vuelta: la punta de la isla mira para arriba y lo de arriba cuelga abajo.
		lote.cilindro(p + Vector3(0.0, ancho * 0.5, 0.0), ancho * 0.1, ancho * 0.7, ancho, roca, 8)
		lote.cilindro(p - Vector3(0.0, 0.4, 0.0), ancho * 0.72, ancho * 0.72, 0.8, pasto, 8)
		for t: int in range(3):
			lote.cilindro(p - Vector3(rng.randf_range(-ancho, ancho) * 0.4, 2.5, rng.randf_range(-ancho, ancho) * 0.4),
				0.8, 0.0, 4.0, roca, 6, Vector3(180, 0, 0))
	for lado: int in range(4):
		lote.caja(_afuera(lado, 0.0, 3.0, 9.0), _rot_tam(Vector3(MITAD * 2.0 + 10.0, 18.0, 4.0), lado), toon(Color(0.18, 0.11, 0.26)))


## EL CIELO: el mar de nubes alrededor, los halos de oro y el sol enorme.
static func _nubes(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var nube := toon(Color(0.88, 0.86, 0.84))
	var sombra := toon(Color(0.78, 0.76, 0.80))
	for k: int in range(90):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(68.0, 190.0)
		var p := Vector3(sin(a) * d, rng.randf_range(-6.0, 4.0), cos(a) * d)
		var r := rng.randf_range(6.0, 16.0)
		lote.esfera(p, r, nube if k % 3 else sombra, Vector3(1.4, 0.55, 1.2), 10)
	for k: int in range(5):
		var p := Vector3(rng.randf_range(-90.0, 90.0), rng.randf_range(40.0, 75.0), rng.randf_range(-90.0, 90.0))
		var r := rng.randf_range(10.0, 22.0)
		for s: int in range(36):
			var a := TAU * s / 36.0
			lote.caja(p + Vector3(sin(a) * r, 0.0, cos(a) * r), Vector3(0.7, 0.7, TAU * r / 36.0 + 0.2), luz(tema["acento"], 2.0),
				Vector3(0.0, rad_to_deg(a), 0.0))
	lote.esfera(Vector3(120.0, 160.0, -240.0), 30.0, luz(Color(1.0, 0.95, 0.75), 2.6), Vector3.ONE, 16)


# ================================================================== Particulas

## Lo que flota en el aire. POCAS, CHICAS Y LENTAS: es ambiente, no puede tapar la pelea.
static func _particulas(arena: Node3D, tema: Dictionary) -> void:
	var part: Dictionary = tema.get("particulas", {})
	var tipo := String(part.get("tipo", ""))
	if tipo == "":
		return
	var p := CPUParticles3D.new()
	p.name = &"Ambiente"
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(MITAD, 8.0, MITAD)
	p.position = Vector3(0.0, 8.0, 0.0)
	p.amount = 160
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.4
	p.mesh = Art.particula_suave()
	p.color = part.get("color", Color.WHITE)
	p.color_ramp = Art.rampa_que_se_apaga(part.get("color", Color.WHITE))
	p.scale_amount_min = 0.015
	p.scale_amount_max = 0.030
	match tipo:
		"polvo":
			p.amount = 90
		"nieve_arriba":
			# La nieve de Hometown, la de "Nieve hacia arriba": sube en vez de caer.
			p.amount = 420
			p.position = Vector3(0.0, 1.0, 0.0)
			p.emission_box_extents = Vector3(MITAD, 1.0, MITAD)
			p.gravity = Vector3(0.0, 0.35, 0.0)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.6
			p.spread = 25.0
			p.lifetime = 14.0
			p.preprocess = 14.0
		"ventisca":
			p.amount = 650
			p.position = Vector3(0.0, 14.0, 0.0)
			p.emission_box_extents = Vector3(MITAD, 2.0, MITAD)
			p.gravity = Vector3(-2.2, -2.6, 0.6)
			p.direction = Vector3.DOWN
			p.spread = 20.0
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.scale_amount_min = 0.040
			p.scale_amount_max = 0.080
		"brasas":
			p.amount = 240
			p.position = Vector3(0.0, 0.5, 0.0)
			p.emission_box_extents = Vector3(MITAD, 0.5, MITAD)
			p.gravity = Vector3(0.0, 1.2, 0.0)
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.scale_amount_min = 0.030
			p.scale_amount_max = 0.070
		"espiritus":
			p.amount = 90
			p.scale_amount_min = 0.125
			p.scale_amount_max = 0.225
			p.initial_velocity_max = 0.8
		"fragmentos":
			p.amount = 70
			p.gravity = Vector3(0.0, 0.15, 0.0)
			p.scale_amount_min = 0.090
			p.scale_amount_max = 0.160
		"estrellas":
			p.amount = 200
			p.initial_velocity_max = 0.15
			p.scale_amount_min = 0.030
			p.scale_amount_max = 0.080
		"escombros_arriba":
			# Lo del nucleo: piedritas que suben, porque ahi la gravedad se da vuelta.
			var piedra := BoxMesh.new()
			piedra.size = Vector3(0.25, 0.20, 0.22)
			piedra.material = Art.toon(Color(0.40, 0.30, 0.50), 0.0)
			p.mesh = piedra
			p.color_ramp = null
			p.amount = 80
			p.position = Vector3(0.0, 0.5, 0.0)
			p.emission_box_extents = Vector3(MITAD, 0.5, MITAD)
			p.gravity = Vector3(0.0, 0.6, 0.0)
			p.angular_velocity_min = -60.0
			p.angular_velocity_max = 60.0
			p.scale_amount_min = 0.300
			p.scale_amount_max = 0.700
			p.lifetime = 12.0
			p.preprocess = 12.0
		"chispas_doradas":
			p.amount = 150
			p.gravity = Vector3(0.0, -0.05, 0.0)
			p.scale_amount_min = 0.040
			p.scale_amount_max = 0.090
	arena.add_child(p)


## CIUDAD Z (y SHINJUKU, con "ruinas"): edificios grises detras del muro, con las ventanas
## en filas, carteles y tanques de agua en las terrazas. En ruinas, los techos rotos y
## algunos inclinados, como despues de una pelea entre los mas fuertes.
static func _ciudad(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var ruinas: bool = tema.get("ruinas", false)
	var grises: Array[Color] = [Color(0.56, 0.57, 0.60), Color(0.66, 0.64, 0.60), Color(0.46, 0.48, 0.53),
		Color(0.72, 0.70, 0.66)]
	var vidrio := toon(Color(0.30, 0.42, 0.55)) if not ruinas else toon(Color(0.12, 0.13, 0.16))
	var prendida := luz(Color(1.0, 0.86, 0.55), 1.6)
	for lado: int in range(4):
		for k: int in range(9):
			var u := -MITAD + 6.0 + k * 14.0 + rng.randf_range(-2.0, 2.0)
			var d := rng.randf_range(8.0, 18.0)
			var ancho := rng.randf_range(9.0, 13.0)
			var alto := rng.randf_range(16.0, 46.0)
			if ruinas and k % 3 == 1:
				alto *= 0.5
			var base := _afuera(lado, u, d)
			var color := grises[(k + lado) % grises.size()]
			var giro := Vector3.ZERO
			if ruinas and k % 4 == 2:
				giro = Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
			lote.caja(base + Vector3(0.0, alto * 0.5, 0.0), _rot_tam(Vector3(ancho, alto, 10.0), lado), toon(color), giro)
			# Las ventanas en la cara que mira a la Arena, en filas.
			var cara := base + _hacia_adentro(lado) * 5.05
			var pisos := int(alto / 3.2)
			for f: int in range(1, pisos):
				for v: int in range(3):
					var w := cara + _a_lo_largo(lado) * (float(v) - 1.0) * ancho * 0.3 + Vector3(0.0, float(f) * 3.2, 0.0)
					var encendida := not ruinas and rng.randf() < 0.18
					lote.caja(w, _rot_tam(Vector3(ancho * 0.22, 1.5, 0.08), lado), prendida if encendida else vidrio)
			if ruinas:
				# El techo roto: bloques sueltos arriba y un hueco negro.
				for t: int in range(3):
					lote.caja(base + Vector3(rng.randf_range(-3.0, 3.0), alto + rng.randf_range(0.3, 1.6), rng.randf_range(-3.0, 3.0)),
						Vector3(rng.randf_range(1.0, 3.0), rng.randf_range(0.6, 2.0), rng.randf_range(1.0, 3.0)), toon(color.darkened(0.2)),
						Vector3(rng.randf_range(-30, 30), rng.randf_range(0, 90), rng.randf_range(-30, 30)))
			else:
				# Un tanque de agua o un cartel en la terraza.
				if k % 2 == 0:
					lote.cilindro(base + Vector3(2.0, alto + 1.4, 0.0), 1.2, 1.2, 2.8, toon(Color(0.62, 0.40, 0.30)), 10)
				else:
					lote.caja(base + Vector3(0.0, alto + 1.8, 0.0) + _hacia_adentro(lado) * 3.0,
						_rot_tam(Vector3(6.0, 2.6, 0.3), lado), luz(tema.get("acento", Color.RED), 1.3))
	if ruinas:
		# El humo de la ciudad que se quema, en columnas lejanas.
		for k: int in range(10):
			var a := TAU * float(k) / 10.0 + rng.randf_range(-0.2, 0.2)
			var p := Vector3(sin(a) * 120.0, 0.0, cos(a) * 120.0)
			for s: int in range(6):
				lote.esfera(p + Vector3(float(s) * 2.0, 20.0 + float(s) * 9.0, 0.0), 6.0 + float(s) * 2.0,
					toon(Color(0.20, 0.18, 0.20).lightened(0.05 * s)), Vector3(1.0, 0.8, 1.0), 8)
	else:
		# Las nubes de un dia de sol, como en la serie.
		for k: int in range(26):
			var a := rng.randf_range(0.0, TAU)
			var p := Vector3(sin(a) * rng.randf_range(90.0, 180.0), rng.randf_range(55.0, 90.0), cos(a) * rng.randf_range(90.0, 180.0))
			lote.esfera(p, rng.randf_range(8.0, 16.0), toon(Color(0.98, 0.98, 1.0)), Vector3(1.8, 0.6, 1.2), 10)


## LA LUNA: el piso gris lleno de crateres, el cielo negro con estrellas y la Tierra grande,
## azul, sobre el horizonte. Donde termino la pelea con el señor del universo.
static func _luna(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var roca := toon(Color(0.48, 0.48, 0.50))
	var oscura := toon(Color(0.30, 0.30, 0.33))
	for k: int in range(400):
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		lote.esfera(dir * 280.0, rng.randf_range(0.4, 1.4), luz(Color(0.95, 0.95, 1.0), rng.randf_range(1.5, 3.5)), Vector3.ONE, 4)
	# La Tierra: el mar, los continentes y las nubes.
	var tierra := Vector3(-120.0, 70.0, -200.0)
	lote.esfera(tierra, 40.0, luz(Color(0.20, 0.42, 0.85), 1.0), Vector3.ONE, 24)
	for k: int in range(7):
		var d := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), 1.0).normalized()
		lote.esfera(tierra + d * 37.0, rng.randf_range(8.0, 14.0), luz(Color(0.30, 0.62, 0.30), 0.9), Vector3(1.0, 0.7, 0.3), 10)
	for k: int in range(6):
		var d := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7), 1.0).normalized()
		lote.esfera(tierra + d * 39.5, rng.randf_range(6.0, 12.0), luz(Color(0.95, 0.97, 1.0), 1.0), Vector3(1.6, 0.6, 0.3), 10)
	# Crateres y lomas del otro lado del muro.
	for k: int in range(60):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(70.0, 200.0)
		var p := Vector3(sin(a) * d, -1.0, cos(a) * d)
		var r := rng.randf_range(5.0, 14.0)
		lote.cilindro(p, r, r * 0.8, 3.0, roca if k % 2 else oscura, 16)
		lote.cilindro(p + Vector3(0.0, 1.55, 0.0), r * 0.7, r * 0.7, 0.2, oscura, 16)
	for k: int in range(24):
		var a := rng.randf_range(0.0, TAU)
		var p := Vector3(sin(a) * rng.randf_range(80.0, 170.0), 0.0, cos(a) * rng.randf_range(80.0, 170.0))
		lote.esfera(p, rng.randf_range(10.0, 26.0), roca, Vector3(1.6, 0.5, 1.3), 10)


## EL SANTUARIO MALEVOLO: el templo de Sukuna enorme detras del muro norte, montañas de
## craneos alrededor, torii negros y una luna roja.
static func _santuario(lote: Lote, tema: Dictionary, rng: RandomNumberGenerator) -> void:
	var hueso := toon(Color(0.86, 0.82, 0.72))
	var madera := toon(Color(0.14, 0.07, 0.07))
	var rojo := toon(Color(0.50, 0.05, 0.07))
	var techo := toon(Color(0.08, 0.06, 0.07))
	# El templo: tres veces el de la definitiva, al fondo.
	var base := Vector3(0.0, 0.0, -MITAD - 40.0)
	var s := 4.0
	for k: int in range(90):
		var a := rng.randf_range(0.0, TAU)
		var alto := rng.randf()
		var r := (1.0 - alto) * 3.4 * s + 1.0
		lote.esfera(base + Vector3(cos(a) * r, alto * 1.6 * s, sin(a) * r * 0.7), rng.randf_range(0.9, 1.6), hueso, Vector3.ONE, 8)
	lote.caja(base + Vector3(0.0, 1.6 * s, 0.0), Vector3(4.8, 0.4, 3.4) * s, madera)
	for x: float in [-1.9, 1.9]:
		for z: float in [-1.3, 1.3]:
			lote.cilindro(base + Vector3(x * s, 3.1 * s, z * s), 0.18 * s, 0.18 * s, 2.8 * s, rojo, 10)
	lote.caja(base + Vector3(0.0, 2.6 * s, 1.32 * s), Vector3(3.0, 1.6, 0.2) * s, toon(Color(0.22, 0.02, 0.04)))
	for k: int in range(9):
		var x := (-1.35 + 2.7 * float(k) / 8.0) * s
		lote.cilindro(base + Vector3(x, 3.22 * s, 1.45 * s), 0.11 * s, 0.0, 0.42 * s, hueso, 6, Vector3(180, 0, 0))
		lote.cilindro(base + Vector3(x, 1.98 * s, 1.45 * s), 0.11 * s, 0.0, 0.42 * s, hueso, 6)
	for piso: int in range(2):
		var y := (4.6 + float(piso) * 1.15) * s
		var ancho := (6.4 - float(piso) * 1.6) * s
		lote.caja(base + Vector3(0.0, y, 0.0), Vector3(ancho, 0.3 * s, ancho * 0.72), techo)
		lote.caja(base + Vector3(0.0, y - 0.18 * s, 0.0), Vector3(ancho * 0.92, 0.1 * s, ancho * 0.66), rojo)
	lote.caja(base + Vector3(0.0, 6.35 * s, 0.0), Vector3(1.4, 0.5, 1.0) * s, techo)
	# Montañas de craneos por todo el borde, y torii negros.
	for lado: int in range(4):
		for k: int in range(6):
			var u := -MITAD + 10.0 + k * 20.0 + rng.randf_range(-4.0, 4.0)
			var p := _afuera(lado, u, rng.randf_range(10.0, 26.0))
			var r := rng.randf_range(4.0, 8.0)
			for c: int in range(14):
				var a := rng.randf_range(0.0, TAU)
				var h := rng.randf()
				lote.esfera(p + Vector3(cos(a) * (1.0 - h) * r, h * r * 0.8, sin(a) * (1.0 - h) * r), rng.randf_range(0.6, 1.1), hueso,
					Vector3.ONE, 6)
		for k: int in range(3):
			var u := -MITAD + 20.0 + k * 40.0
			var p := _afuera(lado, u, 6.0)
			var lado_x := _a_lo_largo(lado) * 3.4
			lote.cilindro(p + lado_x + Vector3(0.0, 5.0, 0.0), 0.4, 0.4, 10.0, techo, 8)
			lote.cilindro(p - lado_x + Vector3(0.0, 5.0, 0.0), 0.4, 0.4, 10.0, techo, 8)
			lote.caja(p + Vector3(0.0, 9.6, 0.0), _rot_tam(Vector3(10.0, 0.6, 0.8), lado), techo)
			lote.caja(p + Vector3(0.0, 8.2, 0.0), _rot_tam(Vector3(8.0, 0.4, 0.5), lado), rojo)
	# La luna roja.
	lote.esfera(Vector3(90.0, 110.0, -160.0), 18.0, luz(Color(0.95, 0.18, 0.15), 1.6), Vector3.ONE, 20)
