"""Naruto Uzumaki (Shippuden), segun las notas de su modelo anterior.

El pelo rubio en puntas para todos lados, con los mechones largos a los costados de la
cara; la bandana de Konoha con la placa de metal y la hoja grabada, y las tiras del nudo
atras; los tres bigotes en cada mejilla y los ojos celestes; la campera naranja con la parte
de arriba negra, el cuello alto, el cierre y el remolino rojo de los Uzumaki en la espalda;
el pantalon naranja, el portakunai en el muslo derecho y las sandalias oscuras con los dedos
al aire. Forma "kurama": el pelo mas largo, con las dos puntas que se paran como orejas.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.98, 0.82, 0.66))
PELO = kit.material("pelo", (1.00, 0.85, 0.25), rugosidad=0.5)
BANDANA = kit.material("bandana", (0.10, 0.12, 0.20))
PLACA = kit.material("placa", (0.78, 0.80, 0.84), metal=0.8, rugosidad=0.3)
GRABADO = kit.material("grabado", (0.36, 0.38, 0.42), metal=0.6)
LINEAS = kit.material("lineas", (0.25, 0.14, 0.10))
CAMPERA = kit.material("campera~cuerpo", (1.00, 0.52, 0.10))
NEGRO = kit.material("negro~acento", (0.10, 0.10, 0.14))
CIERRE = kit.material("cierre", (0.85, 0.85, 0.88))
REMOLINO = kit.material("remolino", (0.85, 0.20, 0.12))
PANTALON = kit.material("pantalon", (1.00, 0.52, 0.10))
PORTAKUNAI = kit.material("portakunai", (0.14, 0.14, 0.16))
VENDA = kit.material("venda", (0.92, 0.90, 0.85))
SANDALIAS = kit.material("zapatos", (0.12, 0.14, 0.28))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.146, alto=0.178, fondo=0.152, mandibula=0.92, nariz=0.80,
                        menton=0.95)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.054))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))


def pelo(largo=1.0, orejas=False):
    """Las puntas para todos lados, mas largas y paradas con el manto de Kurama."""
    piezas = [kit.elipsoide((0, -0.020, 1.875), (0.160, 0.168, 0.150)),
              kit.elipsoide((0, -0.075, 1.790), (0.152, 0.118, 0.115)),
              kit.elipsoide((0, -0.090, 1.730), (0.122, 0.085, 0.070))]
    # La nuca: puntas cortas para abajo y para atras, que tapan hasta el cuello.
    for k in range(7):
        dx = -0.12 + k * 0.04
        piezas += kit.tubo([(dx, -0.12, 1.80), (dx * 1.25, -0.20, 1.70)], [0.045, 0.006])
    # Alrededor y para arriba: catorce puntas en abanico, de largos distintos.
    for k in range(14):
        a = math.radians(-160 + k * (320 / 13))
        dx, dy = math.sin(a), math.cos(a)
        alto = 0.04 + 0.08 * (1 - abs(dy)) * 0.5 + (0.03 if k % 2 else 0.0)
        base = (dx * 0.12, dy * 0.12 - 0.03, 1.93)
        punta = (dx * (0.27 + 0.03 * (k % 3)) * largo, dy * 0.25 * largo - 0.05, 1.98 + alto * largo)
        medio = ((base[0] + punta[0]) / 2, (base[1] + punta[1]) / 2, (base[2] + punta[2]) / 2 + 0.02)
        piezas += kit.tubo([base, medio, punta], [0.072, 0.048, 0.006])
    # Arriba de todo, para atras.
    for dx in (-0.06, 0.0, 0.06):
        piezas += kit.tubo([(dx, -0.02, 1.98), (dx * 1.8, -0.12, 2.12 + 0.04 * largo)], [0.060, 0.006])
    # El flequillo en puntas sobre la bandana y los mechones largos a los costados de la cara.
    for dx in (-0.09, -0.03, 0.03, 0.09):
        piezas += kit.tubo([(dx * 0.8, 0.10, 1.96), (dx * 1.1, 0.175, 1.96), (dx * 1.3, 0.195, 1.92)],
                           [0.040, 0.026, 0.005])
    for lado in (-1, 1):
        piezas += kit.tubo([(lado * 0.130, 0.07, 1.92), (lado * 0.158, 0.085, 1.80), (lado * 0.150, 0.075, 1.70)],
                           [0.036, 0.030, 0.005])
    if orejas:
        for lado in (-1, 1):
            piezas += kit.tubo([(lado * 0.09, 0.00, 1.99), (lado * 0.14, 0.02, 2.16), (lado * 0.15, 0.02, 2.30)],
                               [0.070, 0.045, 0.006])
    return piezas


partes.append((kit.fundir("pelo__sin_kurama", pelo(), PELO, voxel=0.0058, suavizado=4, caras=11000), "cabeza"))
partes.append((kit.fundir("pelo__f_kurama", pelo(1.25, True), PELO, voxel=0.0058, suavizado=4, caras=11000),
               "cabeza"))

# LA BANDANA: la tela alrededor de la frente, el nudo atras con las dos tiras y la placa.
tela = []
for k in range(48):
    a, b = 2 * math.pi * k / 48, 2 * math.pi * (k + 1) / 48
    tela.append(kit.capsula((math.sin(a) * 0.158, math.cos(a) * 0.166 - 0.005, 1.885),
                            (math.sin(b) * 0.158, math.cos(b) * 0.166 - 0.005, 1.885), 0.024, seg=12))
tela.append(kit.elipsoide((0, -0.175, 1.885), (0.035, 0.030, 0.030)))
for lado in (-1, 1):
    tela += kit.tubo([(lado * 0.015, -0.180, 1.880), (lado * 0.050, -0.230, 1.800), (lado * 0.065, -0.245, 1.700)],
                     [0.020, 0.018, 0.016], seg=10)
partes.append((kit.fundir("bandana", tela, BANDANA, voxel=0.0045, suavizado=3, caras=5000), "cabeza"))
p, n = kit.superficie(cabeza, 0.0, 1.885)
centro = (0.0, p.y + 0.030, 1.885)
placa = [kit.caja(centro, (0.150, 0.014, 0.056))]
kit.girar(placa, centro, kit.inclinacion(n))
partes.append((kit.fundir("placa", placa, PLACA, voxel=0.003, suavizado=2, caras=1500), "cabeza"))
# La hoja de Konoha grabada: la espiral y la punta de la hoja.
hoja = []
cx, cy, cz = centro[0], centro[1] + 0.008, centro[2]
pts = []
for k in range(26):
    t = k / 25
    a = t * 3.2 * math.pi
    r = 0.003 + t * 0.016
    pts.append((cx + math.cos(a) * r, cy, cz + math.sin(a) * r))
pts.append((cx + 0.028, cy, cz - 0.004))
pts.append((cx + 0.010, cy, cz - 0.018))
hoja += kit.tubo(pts, [0.0022] * len(pts), seg=6)
kit.girar(hoja, centro, kit.inclinacion(n))
partes.append((kit.fundir("grabado", hoja, GRABADO, voxel=0.0016, suavizado=1, caras=2000), "cabeza"))

# Los bigotes: tres por mejilla, pegados a la piel.
bigotes = []
for lado in (-1, 1):
    for k in range(3):
        z = 1.752 - k * 0.016
        a = kit.superficie(cabeza, lado * 0.075, z + 0.004)[0]
        b = kit.superficie(cabeza, lado * 0.120, z - 0.002)[0]
        bigotes += kit.tubo([tuple(a), tuple(b)], [0.0032, 0.0028], seg=6)
partes.append((kit.fundir("lineas", bigotes, LINEAS, voxel=0.002, suavizado=1, caras=2500), "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.perfil([(0.93, 0.172, 0.124), (1.05, 0.170, 0.122), (1.20, 0.180, 0.128), (1.36, 0.196, 0.134),
                    (1.46, 0.192, 0.128), (1.53, 0.150, 0.108)])
torso.append(kit.capsula((-0.165, 0.0, 1.47), (0.165, 0.0, 1.47), 0.074))
# El cuello alto, abierto un poco adelante.
torso.append(kit.capsula((0, -0.010, 1.50), (0, -0.010, 1.585), 0.086, 0.090))
campera = kit.fundir("campera", torso, CAMPERA, voxel=0.006, suavizado=8, caras=18000)
# Lo de arriba negro: los hombros, la parte alta del pecho y de la espalda, y el cuello.
kit.cortar(campera, (0, 0, 1.390))
kit.pintar(campera, NEGRO, lambda x, y, z: z > 1.390)
partes.append((campera, "torso"))
# El cierre, de arriba abajo por el medio.
cierre = []
pts = [tuple(kit.superficie(campera, 0.0, z)[0]) for z in (1.56, 1.45, 1.33, 1.21, 1.09, 0.95)]
cierre += kit.tubo([(x, y + 0.004, z) for x, y, z in pts], [0.0065] * len(pts), seg=8)
partes.append((kit.fundir("cierre", cierre, CIERRE, voxel=0.003, suavizado=1, caras=1500), "torso"))
# El remolino rojo en la espalda.
pts = []
for k in range(40):
    t = k / 39
    a = t * 3.6 * math.pi
    r = 0.012 + t * 0.060
    p, n = kit.superficie(campera, math.cos(a) * r, 1.24 + math.sin(a) * r, desde=(0.0, -1.5), hacia=(0.0, 1.0))
    pts.append(tuple(p + n * 0.003))
partes.append((kit.fundir("remolino", kit.tubo(pts, [0.011] * len(pts), seg=8), REMOLINO, voxel=0.0035, suavizado=2,
                          caras=3000), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.066, r_codo=0.058, r_muneca=0.054, hasta=0.880)
mg = kit.fundir("mangas", mangas, CAMPERA, voxel=0.006, suavizado=6, caras=9000)
kit.cortar(mg, (0, 0, 1.395))
kit.pintar(mg, NEGRO, lambda x, y, z: z > 1.395)
partes.append((mg, "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.044)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.97), (0.160, 0.115, 0.085))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.080, r_rodilla=0.066, r_tobillo=0.060, hasta=0.20)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
# El portakunai en el muslo derecho, atado con la venda.
porta = [kit.caja((0.205, 0.020, 0.700), (0.045, 0.070, 0.090))]
partes.append((kit.fundir("portakunai", porta, PORTAKUNAI, voxel=0.004, suavizado=3, caras=1500), "pierna_r"))
partes.append((kit.fundir("venda", [kit.capsula((0.12, 0.0, 0.745), (0.12, 0.0, 0.715), 0.087)], VENDA, voxel=0.004,
                          suavizado=2, caras=1500), "pierna_r"))
# Las sandalias, con los dedos al aire.
pies = []
for lado in (-1, 1):
    pies += kit.zapato(lado, largo=0.110, ancho=0.052, alto=0.042, punta=0.95)
partes.append((kit.fundir("pies", pies, PIEL, voxel=0.005, suavizado=5, caras=3000), "pies"))
sandalias = []
for lado in (-1, 1):
    x = lado * 0.12
    sandalias.append(kit.elipsoide((x, 0.020, 0.034), (0.062, 0.135, 0.016)))
    # El talon y el empeine cerrados, la canilla con la tela: los dedos quedan afuera.
    sandalias.append(kit.capsula((x, -0.025, 0.06), (x, -0.010, 0.22), 0.062, 0.062))
    sandalias.append(kit.elipsoide((x, 0.030, 0.070), (0.060, 0.055, 0.042)))
partes.append((kit.fundir("sandalias", sandalias, SANDALIAS, voxel=0.005, suavizado=4, caras=3500), "pies"))

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla.startswith("pierna_"):
        kit.pesar(obj, arm, J, solo=regla)
kit.pesar_estandar([p for p in partes if not p[1].startswith("pierna_")], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.056, 1.812,
                         ojos_extra={"alto": 0.064, "ancho": 0.058, "iris": [0.25, 0.55, 0.95], "pestanas": False,
                                     "formas": {"kurama": {"iris": [1.0, 0.55, 0.10]}}},
                         cejas={"alto": 0.040, "color": [0.80, 0.60, 0.15], "largo": 0.052},
                         boca_z=1.698, boca_extra={"ancho": 0.066, "dientes": False})
kit.exportar("naruto", arm, cara)
