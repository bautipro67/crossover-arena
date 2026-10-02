"""Mob (Shigeo Kageyama), con el uniforme del colegio, segun las notas de su modelo anterior.

Pelo negro azabache en forma de TAZON —el flequillo recto a la altura de las cejas y el
resto parejo alrededor—, ojos negros y la cara sin expresion; el gakuran negro del colegio
Sal, con el cuello alto, el borde blanco de la camisa y los botones dorados; el pantalon
negro y los zapatos negros. LA SILUETA ES EL TAZON: una cabeza redonda y lisa, sin una sola
punta. Formas: "cien" (al 100% el pelo flota en puntas y los ojos brillan) y "manga_corta"
(el uniforme de verano).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.98, 0.88, 0.80))
PELO = kit.material("pelo", (0.05, 0.05, 0.07), rugosidad=0.45)
GAKURAN = kit.material("cuerpo", (0.09, 0.09, 0.12))
CUELLO = kit.material("cuello", (0.96, 0.96, 0.95))
BOTONES = kit.material("botones", (0.95, 0.78, 0.25), metal=0.5)
PANTALON = kit.material("pantalon", (0.08, 0.08, 0.10))
ZAPATOS = kit.material("zapatos~propio", (0.06, 0.06, 0.08), rugosidad=0.3)

partes = []

# -------------------------------------------------------------------- Cabeza
# Un chico: la cara redonda, la nariz chica y el menton suave.
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.148, alto=0.180, fondo=0.155, mandibula=0.88, nariz=0.70,
                        menton=0.85)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.050))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))


def suave(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)


def borde_tazon(x, y):
    """La altura del borde del pelo alrededor de la cabeza: recto arriba de las cejas
    adelante, a la altura de las orejas a los costados y mas bajo en la nuca."""
    a = abs(math.degrees(math.atan2(x, y)))
    return 1.872 - 0.095 * suave(32, 70, a) - 0.105 * suave(105, 165, a)


# EL TAZON: una cascara gruesa de pelo, con el borde parejo, y unos mechones apenas marcados
# en la superficie para que no sea una bocha lisa.
casco = [kit.elipsoide((0, -0.012, 1.858), (0.168, 0.176, 0.162)),
         kit.elipsoide((0, -0.050, 1.780), (0.160, 0.150, 0.110))]
for k in range(14):
    a = math.radians(-150 + k * (300 / 13))
    casco += kit.tubo([(math.sin(a) * 0.05, math.cos(a) * 0.05 - 0.02, 2.00),
                       (math.sin(a) * 0.168, math.cos(a) * 0.176 - 0.012, 1.86)], [0.030, 0.026], seg=12)
tazon = kit.cascara("pelo__sin_cien", casco, PELO, lambda x, y, z: z > borde_tazon(x, y), grosor=0.030,
                    voxel=0.0055, suavizado=6, caras=9000, bordes=6)
partes.append((tazon, "cabeza"))

# AL 100%: el pelo se levanta entero en puntas, como llamas.
cien = [kit.elipsoide((0, -0.015, 1.875), (0.160, 0.168, 0.140))]
for k in range(11):
    a = 2 * math.pi * k / 11
    dx, dy = math.sin(a), math.cos(a)
    largo = 0.20 + 0.05 * (k % 3)
    cien += kit.tubo([(dx * 0.10, dy * 0.10 - 0.02, 1.96), (dx * 0.17, dy * 0.17 - 0.03, 1.96 + largo * 0.55),
                      (dx * 0.20, dy * 0.20 - 0.04, 1.96 + largo)], [0.060, 0.040, 0.006])
for k in range(5):
    a = 2 * math.pi * k / 5 + 0.3
    cien += kit.tubo([(math.sin(a) * 0.04, math.cos(a) * 0.04, 2.00), (math.sin(a) * 0.06, math.cos(a) * 0.06, 2.24)],
                     [0.050, 0.006])
partes.append((kit.fundir("pelo__f_cien", cien, PELO, voxel=0.0058, suavizado=4, caras=9000), "cabeza"))

# -------------------------------------------------------------------- Torso
# El gakuran: cerrado hasta el cuello alto, largo hasta la cadera.
torso = kit.perfil([(0.92, 0.160, 0.116), (1.05, 0.160, 0.115), (1.20, 0.168, 0.118), (1.36, 0.180, 0.124),
                    (1.46, 0.178, 0.118), (1.53, 0.140, 0.100)])
torso.append(kit.capsula((-0.155, 0.0, 1.47), (0.155, 0.0, 1.47), 0.070))
torso.append(kit.capsula((0, -0.005, 1.50), (0, -0.005, 1.575), 0.080, 0.078))
gak = kit.fundir("gakuran", torso, GAKURAN, voxel=0.006, suavizado=8, caras=9000)
partes.append((gak, "torso"))
# El borde blanco de la camisa, asomando arriba del cuello alto.
cuello = []
for k in range(36):
    a, b = 2 * math.pi * k / 36, 2 * math.pi * (k + 1) / 36
    cuello.append(kit.capsula((math.sin(a) * 0.078, math.cos(a) * 0.076 - 0.005, 1.648),
                              (math.sin(b) * 0.078, math.cos(b) * 0.076 - 0.005, 1.648), 0.009, seg=10))
partes.append((kit.fundir("cuello", cuello, CUELLO, voxel=0.0035, suavizado=2, caras=2000), "torso"))
# La costura del medio y los cinco botones dorados, sobre la superficie.
botones = []
for k in range(5):
    z = 1.47 - k * 0.105
    p, n = kit.superficie(gak, 0.0, z)
    botones.append(kit.elipsoide(tuple(p + n * 0.006), (0.020, 0.010, 0.020), seg=16))
partes.append((kit.pieza_fija("botones", botones, BOTONES), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.062, r_codo=0.055, r_muneca=0.052, hasta=0.885)
    # El puño de la manga.
    s = "_l" if lado < 0 else "_r"
    m = J["mano" + s]
    mangas.append(kit.capsula((m[0], m[1], 0.905), (m[0], m[1], 0.885), 0.054))
partes.append((kit.fundir("mangas__sin_manga_corta", mangas, GAKURAN, voxel=0.0055, suavizado=6, caras=4500),
               "brazos"))
cortas = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h = J["hombro" + s]
    cortas += kit.tubo([h, (h[0], h[1], h[2] - 0.20)], [0.066, 0.060])
partes.append((kit.fundir("mangas_cortas__f_manga_corta", cortas, GAKURAN, voxel=0.0055, suavizado=6, caras=2500),
               "brazos"))
brazos = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h, c = J["hombro" + s], J["codo" + s]
    brazos += kit.tubo([(h[0], h[1], h[2] - 0.16), c], [0.050, 0.046])
    brazos += kit.antebrazo(lado, r_codo=0.046, r_muneca=0.038)
    brazos += kit.mano(lado, r=0.040)
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.005, suavizado=5, caras=6000), "brazos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.95), (0.150, 0.110, 0.080))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.074, r_rodilla=0.062, r_tobillo=0.056, hasta=0.13)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, largo=0.118, ancho=0.058, alto=0.050, punta=0.95)
partes.append((kit.fundir("zapatos", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=3500), "pies"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.058, 1.812,
                         ojos_extra={"alto": 0.060, "ancho": 0.052, "iris": [0.06, 0.06, 0.08], "pestanas": False,
                                     "formas": {"cien": {"estilo": "brillo", "iris": [0.85, 0.93, 1.00]}}},
                         cejas={"alto": 0.040, "color": [0.05, 0.05, 0.07], "largo": 0.050},
                         boca_z=1.700, boca_extra={"ancho": 0.040, "dientes": False})
kit.exportar("mob", arm, cara)
