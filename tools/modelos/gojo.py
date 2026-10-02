"""Satoru Gojo, de Jujutsu Kaisen, segun las notas de su modelo anterior.

Alto; el pelo blanco parado para arriba por la venda negra que le tapa los ojos; el
uniforme negro de Jujutsu, largo hasta la cadera, con el cuello alto hasta la barbilla y el
boton en espiral; el pantalon ancho y los zapatos negros. Sin la venda (forma "sin_venda")
el pelo le cae sobre la frente y se ven los Seis Ojos, celestes y con las pestañas blancas.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.98, 0.88, 0.80))
PELO = kit.material("pelo", (0.96, 0.96, 0.98), rugosidad=0.45)
VENDA = kit.material("venda", (0.06, 0.06, 0.08))
UNIFORME = kit.material("uniforme~cuerpo", (0.07, 0.07, 0.10))
BOTON = kit.material("boton", (0.75, 0.62, 0.30), metal=0.7)
PANTALON = kit.material("pantalon", (0.07, 0.07, 0.10))
ZAPATOS = kit.material("zapatos", (0.05, 0.05, 0.06), rugosidad=0.3)

partes = []

# -------------------------------------------------------------------- Cabeza
def craneo(extra=0.0):
    c = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.138 + extra, alto=0.180 + extra, fondo=0.150 + extra,
                          mandibula=0.88, nariz=0.95, menton=1.0, orejas=extra == 0.0)
    if extra == 0.0:
        c.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.052))
    return c


cabeza = kit.fundir("cabeza", craneo(), PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))


def pelo_parado():
    """Con la venda: todo el pelo empujado para arriba en un penacho alto, esponjoso y
    desordenado; no una corona de puntas iguales. Puntas de largos y grosores distintos que
    salen de un volumen grande sobre la venda, y los mechones de los costados."""
    import random
    random.seed(17)
    piezas = [kit.elipsoide((0, -0.020, 1.900), (0.160, 0.168, 0.140)),
              kit.elipsoide((0, -0.030, 1.985), (0.135, 0.140, 0.090)),
              kit.elipsoide((0, -0.080, 1.800), (0.145, 0.115, 0.100))]
    for k in range(24):
        a = random.uniform(0, 2 * math.pi)
        r0 = random.uniform(0.02, 0.12)
        dx, dy = math.sin(a), math.cos(a)
        alto = random.uniform(0.16, 0.30) * (1.0 - r0 * 1.6)
        abre = random.uniform(0.05, 0.13)
        base = (dx * r0, dy * r0 - 0.03, 1.97 + random.uniform(-0.02, 0.03))
        punta = (dx * (r0 + abre), dy * (r0 + abre * 0.8) - 0.05, base[2] + alto)
        medio = ((base[0] + punta[0]) / 2 + dx * 0.012, (base[1] + punta[1]) / 2, (base[2] + punta[2]) / 2)
        piezas += kit.tubo([base, medio, punta], [random.uniform(0.050, 0.068), 0.040, 0.005])
    # Los costados y la nuca: mechones cortos y en punta que tapan el craneo arriba de la venda.
    for k in range(10):
        a = math.radians(55 + k * 25)
        piezas += kit.tubo([(math.sin(a) * 0.13, math.cos(a) * 0.13 - 0.03, 1.86),
                            (math.sin(a) * 0.205, math.cos(a) * 0.195 - 0.04, 1.84 + 0.02 * (k % 2))], [0.046, 0.006])
    return piezas


def pelo_caido():
    """Sin la venda: el pelo cae, con el flequillo sobre la frente y entre los ojos."""
    piezas = [kit.elipsoide((0, -0.020, 1.875), (0.158, 0.166, 0.145)),
              kit.elipsoide((0, -0.075, 1.790), (0.150, 0.118, 0.110))]
    for dx, caida in ((-0.10, 0.035), (-0.055, 0.050), (-0.01, 0.060), (0.035, 0.055), (0.08, 0.045), (0.115, 0.030)):
        piezas += kit.tubo([(dx * 0.8, 0.09, 1.97), (dx * 1.05, 0.165, 1.92), (dx * 1.15, 0.168, 1.94 - caida)],
                           [0.040, 0.028, 0.005])
    for k in range(12):
        a = math.radians(60 + k * (240 / 11))
        piezas += kit.tubo([(math.sin(a) * 0.14, math.cos(a) * 0.15 - 0.02, 1.90),
                            (math.sin(a) * 0.19, math.cos(a) * 0.19 - 0.03, 1.76)], [0.050, 0.008])
    return piezas


partes.append((kit.fundir("pelo__sin_sin_venda", pelo_parado(), PELO, voxel=0.0058, suavizado=4, caras=10000),
               "cabeza"))
partes.append((kit.fundir("pelo__f_sin_venda", pelo_caido(), PELO, voxel=0.0058, suavizado=4, caras=10000), "cabeza"))
# LA VENDA: una franja de tela alrededor de la cabeza, a la altura de los ojos.
partes.append((kit.cascara("venda__sin_sin_venda", craneo(0.010), VENDA, lambda x, y, z: 1.785 < z < 1.870,
                           grosor=0.010, voxel=0.005, caras=5000), "cabeza"))

# -------------------------------------------------------------------- Torso
perfil = [(0.86, 0.172, 0.126), (0.95, 0.165, 0.120), (1.05, 0.160, 0.116), (1.20, 0.172, 0.122),
          (1.36, 0.192, 0.128), (1.46, 0.190, 0.122), (1.53, 0.146, 0.104)]
torso = kit.perfil(perfil)
torso.append(kit.capsula((-0.165, 0.0, 1.47), (0.165, 0.0, 1.47), 0.072))
# El cuello alto, hasta la barbilla, apenas abierto arriba.
torso.append(kit.capsula((0, -0.008, 1.50), (0, -0.002, 1.630), 0.084, 0.092))
uni = kit.fundir("uniforme", torso, UNIFORME, voxel=0.006, suavizado=8, caras=10000)
partes.append((uni, "torso"))
# El boton en espiral, a la izquierda del cuello.
p, n = kit.superficie(uni, -0.040, 1.590)
c = tuple(p + n * 0.006)
disco = [kit.elipsoide(c, (0.020, 0.006, 0.020), seg=24)]
kit.orientar(disco, c, n)
pts = []
for k in range(22):
    t = k / 21
    a = t * 2.6 * math.pi
    r = 0.003 + t * 0.014
    pts.append((c[0] + math.cos(a) * r, c[1] + 0.005, c[2] + math.sin(a) * r))
espiral = kit.tubo(pts, [0.0026] * len(pts), seg=6)
kit.orientar(espiral, c, n)
partes.append((kit.fundir("boton", disco + espiral, BOTON, voxel=0.0018, suavizado=1, caras=2500), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.066, r_codo=0.060, r_muneca=0.056, hasta=0.880)
partes.append((kit.fundir("mangas", mangas, UNIFORME, voxel=0.006, suavizado=6, caras=4500), "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.045)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.92), (0.150, 0.108, 0.080))]
for lado in (-1, 1):
    # El pantalon del uniforme es ANCHO y cae recto.
    pantalon += kit.pierna(lado, r_muslo=0.090, r_rodilla=0.084, r_tobillo=0.082, hasta=0.13)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, largo=0.125, ancho=0.060, alto=0.050, punta=0.95)
partes.append((kit.fundir("zapatos", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=3500), "pies"))

# -------------------------------------------------------------------- Skins
#
#   dominio  el Vacio Infinito: sin la venda, con los Seis Ojos, y el Azul y el Rojo
#            encendidos en las manos (lo que junta para el Purpura).
#   joven    el del colegio: los lentes redondos oscuros en vez de la venda.
#   blanco   los dias libres: la camisa blanca con el cuello abierto y los lentes oscuros.
AZUL = kit.material("neon_azul", (0.30, 0.55, 1.00))
ROJO = kit.material("neon_rojo", (1.00, 0.20, 0.25))
LENTE = kit.material("lentes_oscuros", (0.04, 0.04, 0.06), rugosidad=0.2)
MARCO = kit.material("lentes_marco", (0.70, 0.70, 0.74), metal=0.6)
CAMISA = kit.material("uniforme", (0.92, 0.92, 0.95))
for lado, mat, nombre in ((-1, AZUL, "orbe_azul"), (1, ROJO, "orbe_rojo")):
    xm, ym, zm = J["mano_l" if lado < 0 else "mano_r"]
    partes.append((kit.fundir(kit.de_skin(nombre, "dominio"), [kit.elipsoide((xm, ym + 0.11, zm + 0.02), (0.055, 0.055, 0.055))],
                              mat, voxel=0.004, suavizado=3, caras=1200), "codo_l" if lado < 0 else "codo_r"))
lentes, marco = [], []
for lado in (-1, 1):
    p, n = kit.superficie(cabeza, lado * 0.055, 1.818)
    c = tuple(p + n * 0.012)
    l = [kit.elipsoide(c, (0.030, 0.006, 0.030), seg=20)]
    kit.orientar(l, c, n)
    lentes += l
    aro = []
    for k in range(18):
        a, b = 2 * math.pi * k / 18, 2 * math.pi * (k + 1) / 18
        aro.append(kit.capsula((c[0] + math.cos(a) * 0.031, c[1] + 0.002, c[2] + math.sin(a) * 0.031),
                               (c[0] + math.cos(b) * 0.031, c[1] + 0.002, c[2] + math.sin(b) * 0.031), 0.003, seg=6))
    kit.orientar(aro, c, n)
    marco += aro
    marco += kit.tubo([(lado * 0.086, c[1] - 0.02, 1.822), (lado * 0.140, -0.02, 1.830), (lado * 0.150, -0.10, 1.810)],
                      [0.003, 0.003, 0.003], seg=6)
marco += kit.tubo([(-0.024, 0.165, 1.822), (0.0, 0.170, 1.826), (0.024, 0.165, 1.822)], [0.003] * 3, seg=6)
partes.append((kit.pieza_fija(kit.de_skin("lentes_oscuros", "joven", "blanco"), lentes, LENTE), "cabeza"))
partes.append((kit.fundir(kit.de_skin("lentes_marco", "joven", "blanco"), marco, MARCO, voxel=0.0018, suavizado=1, caras=3000),
               "cabeza"))
# BLANCO: la camisa, con el cuello abierto en V y las solapas del cuello.
camisa = kit.perfil([(0.86, 0.176, 0.130), (0.95, 0.169, 0.124), (1.05, 0.164, 0.120), (1.20, 0.176, 0.126),
                     (1.36, 0.196, 0.132), (1.46, 0.194, 0.126), (1.53, 0.150, 0.108)])
camisa.append(kit.capsula((-0.168, 0.0, 1.47), (0.168, 0.0, 1.47), 0.075))
cm = kit.fundir(kit.de_skin("camisa", "blanco"), camisa, CAMISA, voxel=0.006, suavizado=8, caras=9000)
kit.pintar(cm, kit.bpy.data.materials["piel"], lambda x, y, z: y > 0.05 and z > 1.42 + abs(x) * 2.2)
partes.append((cm, "torso"))
cuello = [kit.elipsoide((lado * 0.060, 0.070, 1.540), (0.060, 0.030, 0.032), rot=(18, 0, lado * -24)) for lado in (-1, 1)]
partes.append((kit.fundir(kit.de_skin("camisa_cuello", "blanco"), cuello, CAMISA, voxel=0.004, suavizado=4, caras=1500),
               "torso"))
for obj, _r in partes:
    if obj.name in ("uniforme", "boton"):
        kit.ocultar_en(obj, "blanco")

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.055, 1.818,
                         ojos_extra={"alto": 0.060, "ancho": 0.056, "iris": [0.45, 0.80, 1.00], "pestanas": True,
                                     "oculto": True, "formas": {"sin_venda": {"oculto": False}}},
                         cejas={"alto": 0.040, "color": [0.92, 0.92, 0.95], "largo": 0.052},
                         boca_z=1.700, boca_extra={"ancho": 0.058, "dientes": False})
kit.exportar("gojo", arm, cara)
