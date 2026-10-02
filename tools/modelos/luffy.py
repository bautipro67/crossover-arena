"""Monkey D. Luffy, segun las notas de su modelo anterior.

El sombrero de paja con la cinta roja, el pelo negro revuelto, la cicatriz debajo del ojo
izquierdo; el chaleco rojo abierto sin mangas con la cicatriz en X del pecho, la faja
amarilla con el nudo al costado, el short azul con el ruedo doblado, las piernas al aire y
las sandalias. Formas: "kimono" (Wano: el kimono cerrado con las mangas anchas),
"sin_cicatriz" (el del East Blue, antes de Marineford: sin la X) y "nika" (Gear 5: el pelo
blanco, largo y parado como llamas).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.96, 0.78, 0.62))
PELO = kit.material("pelo", (0.06, 0.06, 0.08), rugosidad=0.5)
CICATRIZ = kit.material("cicatriz", (0.62, 0.30, 0.24))
SOMBRERO = kit.material("sombrero", (0.95, 0.82, 0.45))
TRAMA = kit.material("trama", (0.82, 0.68, 0.34))
CINTA = kit.material("cinta", (0.82, 0.12, 0.12))
CHALECO = kit.material("cuerpo", (0.82, 0.12, 0.12))
BOTONES = kit.material("botones", (0.95, 0.80, 0.30))
FAJA = kit.material("faja~acento", (0.95, 0.80, 0.25))
SHORT = kit.material("pantalon", (0.22, 0.38, 0.72))
RUEDO = kit.material("ruedo", (0.42, 0.54, 0.79))
SANDALIAS = kit.material("zapatos", (0.55, 0.38, 0.22))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.146, alto=0.178, fondo=0.152, mandibula=0.92, nariz=0.85,
                        menton=0.95)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.052))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))
# La cicatriz debajo del ojo izquierdo (el izquierdo del personaje es -X): dos puntadas.
marcas = []
for k in range(2):
    z = 1.772 - k * 0.012
    a = kit.superficie(cabeza, -0.044, z + 0.002)[0]
    b = kit.superficie(cabeza, -0.074, z - 0.002)[0]
    marcas += kit.tubo([tuple(a), tuple(b)], [0.0036, 0.0036], seg=6)
partes.append((kit.fundir("cicatriz_ojo", marcas, CICATRIZ, voxel=0.002, suavizado=1, caras=1000), "cabeza"))


def pelo_revuelto():
    random.seed(11)
    piezas = [kit.elipsoide((0, -0.020, 1.870), (0.160, 0.168, 0.148)),
              kit.elipsoide((0, -0.075, 1.780), (0.150, 0.115, 0.110))]
    # Mechones cortos y gruesos para todos lados, que asoman debajo del ala.
    # Adelante no: ahi va la cara.
    for k in range(14):
        a = math.radians((-170 + k * (240 / 13) if k < 7 else 50 + (k - 7) * (120 / 6)) + random.uniform(-6, 6))
        dx, dy = math.sin(a), math.cos(a)
        z0 = 1.84 + random.uniform(-0.03, 0.03)
        largo = 0.085 + random.uniform(0, 0.04)
        piezas += kit.tubo([(dx * 0.140, dy * 0.145 - 0.02, z0),
                            (dx * (0.140 + largo), dy * (0.145 + largo) - 0.02, z0 - 0.06 - random.uniform(0, 0.04))],
                           [0.042, 0.006])
    # El flequillo en mechones sobre la frente.
    for dx, caida in ((-0.08, 0.050), (-0.03, 0.060), (0.025, 0.055), (0.075, 0.045)):
        piezas += kit.tubo([(dx, 0.11, 1.95), (dx * 1.15, 0.165, 1.90), (dx * 1.25, 0.170, 1.95 - caida)],
                           [0.040, 0.028, 0.006])
    return piezas


def pelo_nika():
    """Gear 5: el pelo blanco, largo y parado, ondulado como llamas o nubes."""
    random.seed(5)
    piezas = [kit.elipsoide((0, -0.020, 1.880), (0.165, 0.172, 0.155))]
    for k in range(13):
        a = math.radians(-165 + k * (330 / 12))
        dx, dy = math.sin(a), math.cos(a)
        base = (dx * 0.12, dy * 0.12 - 0.03, 1.93)
        pts = [base]
        for t in (0.35, 0.70, 1.0):
            onda = math.sin(t * 6 + k) * 0.04
            pts.append((dx * (0.12 + 0.20 * t) + onda * dy, dy * (0.12 + 0.18 * t) - 0.05, 1.93 + 0.30 * t))
        piezas += kit.tubo(pts, [0.075, 0.062, 0.040, 0.008])
    for dx, caida in ((-0.08, 0.07), (-0.02, 0.09), (0.05, 0.08)):
        piezas += kit.tubo([(dx, 0.11, 1.95), (dx * 1.2, 0.17, 1.90), (dx * 1.3, 0.17, 1.95 - caida)],
                           [0.042, 0.030, 0.006])
    return piezas


partes.append((kit.fundir("pelo__sin_nika", pelo_revuelto(), PELO, voxel=0.0058, suavizado=4, caras=9000), "cabeza"))
partes.append((kit.fundir("pelo__f_nika", pelo_nika(), PELO, voxel=0.0060, suavizado=5, caras=10000), "cabeza"))

# EL SOMBRERO DE PAJA: la copa, el ala ancha y un poco caida en el borde, la cinta roja y la
# trama de la paja en anillos sobre el ala y la copa.
sz = 1.955
copa = [kit.capsula((0, -0.010, sz), (0, -0.010, sz + 0.095), 0.168, 0.158, seg=40)]
ala = [kit.elipsoide((0, -0.010, sz - 0.010), (0.345, 0.335, 0.018), seg=56),
       kit.elipsoide((0, -0.010, sz - 0.022), (0.330, 0.320, 0.012), seg=56)]
partes.append((kit.fundir("sombrero", copa + ala, SOMBRERO, voxel=0.0055, suavizado=5, caras=9000), "cabeza"))
trama = []
for r in (0.205, 0.245, 0.285, 0.320):
    for k in range(48):
        a, b = 2 * math.pi * k / 48, 2 * math.pi * (k + 1) / 48
        trama.append(kit.capsula((math.sin(a) * r, math.cos(a) * r * 0.97 - 0.010, sz + 0.005 - (r - 0.2) * 0.03),
                                 (math.sin(b) * r, math.cos(b) * r * 0.97 - 0.010, sz + 0.005 - (r - 0.2) * 0.03),
                                 0.0035, seg=6))
for z in (sz + 0.115, sz + 0.150):
    for k in range(40):
        a, b = 2 * math.pi * k / 40, 2 * math.pi * (k + 1) / 40
        trama.append(kit.capsula((math.sin(a) * 0.162, math.cos(a) * 0.162 - 0.010, z),
                                 (math.sin(b) * 0.162, math.cos(b) * 0.162 - 0.010, z), 0.0035, seg=6))
partes.append((kit.fundir("trama", trama, TRAMA, voxel=0.0025, suavizado=1, caras=8000), "cabeza"))
cinta = [kit.capsula((0, -0.010, sz + 0.020), (0, -0.010, sz + 0.075), 0.172, 0.167, seg=40)]
partes.append((kit.fundir("cinta", cinta, CINTA, voxel=0.004, suavizado=3, caras=3000), "cabeza"))

# -------------------------------------------------------------------- Torso
# El pecho al aire, flaco pero marcado, con la X; arriba, el chaleco rojo abierto.
perfil = [(1.00, 0.156, 0.112), (1.05, 0.156, 0.112), (1.20, 0.168, 0.120), (1.36, 0.186, 0.128),
          (1.46, 0.184, 0.122), (1.53, 0.140, 0.100)]
pecho = kit.perfil(perfil)
pecho.append(kit.capsula((-0.160, 0.0, 1.47), (0.160, 0.0, 1.47), 0.070))
for lado in (-1, 1):
    pecho.append(kit.elipsoide((lado * 0.075, 0.085, 1.385), (0.085, 0.045, 0.060)))
torso = kit.fundir("pecho", pecho, PIEL, voxel=0.006, suavizado=8, caras=9000)
partes.append((torso, "torso"))
x_cic = []
for lado in (-1, 1):
    pts = []
    for t in range(7):
        u = t / 6.0
        x = lado * (-0.085 + 0.170 * u)
        z = 1.46 - 0.22 * u
        pts.append(tuple(kit.superficie(torso, x, z)[0]))
    x_cic += kit.tubo(pts, [0.0060] * len(pts), seg=8)
partes.append((kit.fundir("cicatriz__sin_sin_cicatriz", x_cic, CICATRIZ, voxel=0.003, suavizado=2, caras=2500),
               "torso"))


def inflado(extra):
    t = kit.perfil([(z, a + extra, f + extra) for z, a, f in perfil])
    t.append(kit.capsula((-0.150, 0.0, 1.47), (0.150, 0.0, 1.47), 0.070 + extra))
    for lado in (-1, 1):
        t.append(kit.elipsoide((lado * 0.075, 0.085 + extra, 1.385), (0.085, 0.045, 0.060)))
    return t


def chaleco(x, y, z):
    if z < 1.035 or z > 1.56:
        return False
    # Abierto adelante: la abertura se ensancha hacia arriba.
    if y > 0.0 and abs(x) < 0.040 + (z - 1.035) * 0.14:
        return False
    # Sin mangas: los huecos de los brazos.
    return not (abs(x) > 0.170 and z < 1.50)


partes.append((kit.cascara("chaleco__sin_kimono", inflado(0.014), CHALECO, chaleco, grosor=0.012, caras=7000),
               "torso"))
# EL KIMONO de Wano: cerrado, cruzado en V, con mangas anchas hasta el codo.
partes.append((kit.cascara("kimono__f_kimono", inflado(0.016), CHALECO,
                           lambda x, y, z: 1.035 < z < 1.56 and not (y > 0.0 and abs(x) < 0.050 - (1.56 - z) * 0.18),
                           grosor=0.012, caras=7000), "torso"))
mangas_k = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h = J["hombro" + s]
    mangas_k += kit.tubo([h, (h[0], h[1], h[2] - 0.28)], [0.080, 0.096])
partes.append((kit.fundir("mangas__f_kimono", mangas_k, CHALECO, voxel=0.006, suavizado=6, caras=3500), "brazos"))
# La faja amarilla, con el nudo y las puntas colgando al costado izquierdo.
faja = [kit.elipsoide((0, 0.0, 1.020), (0.178, 0.135, 0.052)),
        kit.elipsoide((-0.150, 0.090, 1.010), (0.040, 0.030, 0.040))]
faja += kit.tubo([(-0.150, 0.100, 0.990), (-0.170, 0.110, 0.900), (-0.175, 0.105, 0.830)], [0.026, 0.024, 0.020])
faja += kit.tubo([(-0.135, 0.105, 0.990), (-0.130, 0.115, 0.920)], [0.022, 0.018])
partes.append((kit.fundir("faja", faja, FAJA, voxel=0.005, suavizado=4, caras=4000), "torso"))

# --------------------------------------------------------------------- Brazos
brazos = []
for lado in (-1, 1):
    brazos += kit.brazo(lado, r_hombro=0.058, r_codo=0.050, r_muneca=0.042, hasta=0.875)
    brazos += kit.mano(lado, r=0.044)
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.0055, suavizado=6, caras=7000), "brazos"))

# -------------------------------------------------------------------- Piernas
short = [kit.elipsoide((0, 0.0, 0.97), (0.162, 0.118, 0.085))]
for lado in (-1, 1):
    x = lado * 0.12
    short.append(kit.capsula((x, 0.0, 0.92), (x, 0.0, 0.60), 0.088, 0.084))
partes.append((kit.fundir("short", short, SHORT, voxel=0.006, suavizado=8, caras=5500), "cadera"))
ruedo = []
for lado in (-1, 1):
    x = lado * 0.12
    ruedo.append(kit.capsula((x, 0.0, 0.600), (x, 0.0, 0.565), 0.094))
partes.append((kit.fundir("ruedo", ruedo, RUEDO, voxel=0.005, suavizado=3, caras=2500), "piernas"))
piernas = []
for lado in (-1, 1):
    x = lado * 0.12
    piernas += kit.tubo([(x, 0.0, 0.58), J["rodilla_r" if lado > 0 else "rodilla_l"], (x, 0.0, 0.10)],
                        [0.062, 0.054, 0.042])
    piernas += kit.zapato(lado, largo=0.108, ancho=0.050, alto=0.040, punta=0.95)
partes.append((kit.fundir("piernas", piernas, PIEL, voxel=0.0055, suavizado=6, caras=6000), "piernas"))
sandalias = []
for lado in (-1, 1):
    x = lado * 0.12
    sandalias.append(kit.elipsoide((x, 0.020, 0.032), (0.060, 0.132, 0.014)))
    sandalias.append(kit.capsula((x - 0.050, 0.060, 0.062), (x + 0.050, 0.060, 0.062), 0.012))
    sandalias.append(kit.capsula((x, 0.075, 0.040), (x, 0.060, 0.064), 0.010))
partes.append((kit.fundir("sandalias", sandalias, SANDALIAS, voxel=0.0045, suavizado=3, caras=2500), "pies"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.057, 1.812,
                         ojos_extra={"alto": 0.066, "ancho": 0.058, "iris": [0.10, 0.08, 0.08], "pestanas": False},
                         cejas={"alto": 0.042, "color": [0.06, 0.06, 0.08], "largo": 0.050},
                         boca_z=1.698, boca_extra={"ancho": 0.078, "dientes": False})
kit.exportar("luffy", arm, cara)
