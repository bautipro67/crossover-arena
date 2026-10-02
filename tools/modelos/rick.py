"""Rick Sanchez, segun las notas de referencia de su modelo anterior.

Alto y flaco. Pelo celeste grisaceo, salvaje y en puntas, con ENTRADAS (la frente alta y
el pelo saliendo de los costados y de atras). Uniceja. Guardapolvo blanco ABIERTO con dos
faldones rectos, camisa celeste, pantalon marron con cinto de hebilla dorada, y las medias
blancas asomando porque el pantalon le queda corto. Y Pickle Rick, para su skin: un
pepinillo con su cara (los objetos __f_pepino / __sin_pepino).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.90, 0.78, 0.63))
PELO = kit.material("pelo", (0.66, 0.80, 0.86), rugosidad=0.55)
CAMISA = kit.material("cuerpo", (0.62, 0.80, 0.88))
GUARDAPOLVO = kit.material("guardapolvo", (0.95, 0.96, 0.97))
PANTALON = kit.material("pantalon", (0.45, 0.33, 0.22))
CINTO = kit.material("cinto", (0.28, 0.19, 0.12))
HEBILLA = kit.material("hebilla", (0.85, 0.70, 0.25), metal=0.6)
MEDIAS = kit.material("medias", (0.93, 0.93, 0.90))
ZAPATOS = kit.material("zapatos~acento", (0.26, 0.18, 0.12))
PEPINO = kit.material("pepino", (0.36, 0.62, 0.22))
PEPINO_CLARO = kit.material("pepino_claro", (0.55, 0.78, 0.32))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.138, alto=0.190, fondo=0.150, mandibula=0.95, nariz=1.1,
                        menton=1.1)
cab.append(kit.capsula((0, -0.01, 1.48), (0, -0.01, 1.66), 0.050))
cabeza = kit.fundir("cabeza__sin_pepino", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))

# EL PELO: puntas que salen de los costados y de atras, en forma de U invertida; la frente y
# la coronilla de adelante quedan despejadas (las entradas).
pelo = [kit.elipsoide((0, -0.065, 1.850), (0.150, 0.120, 0.150))]
puntas = []
for k in range(9):
    ang = -1.25 + k * (2.5 / 8)
    import math
    dx, dy = math.sin(ang), -math.cos(ang)
    base = (dx * 0.120, dy * 0.110 - 0.02, 1.900 + 0.03 * math.cos(ang))
    punta = (dx * 0.250, dy * 0.230 - 0.05, 1.960 + 0.07 * math.cos(ang))
    puntas += kit.tubo([base, punta], [0.050, 0.006])
# Y arriba, para atras de las entradas: la coronilla tiene pelo, lo despejado es la frente.
for k, (dx, dy) in enumerate(((-0.06, -0.02), (0.0, -0.04), (0.06, -0.02), (-0.03, -0.09), (0.03, -0.09))):
    puntas += kit.tubo([(dx * 0.8, dy, 1.960), (dx * 1.6, dy - 0.07, 2.080)], [0.046, 0.006])
for lado in (-1, 1):
    # Las de los costados, mas bajas, sobre las orejas.
    for k, dz in enumerate((1.86, 1.80)):
        puntas += kit.tubo([(lado * 0.130, -0.02, dz), (lado * 0.245, -0.03, dz + 0.03)], [0.044, 0.006])
partes.append((kit.fundir("pelo__sin_pepino", pelo + puntas, PELO, voxel=0.0055, suavizado=5, caras=9000), "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.torso_humano(pecho=0.172, cintura=0.150, fondo=0.112, hombros=0.155)
partes.append((kit.fundir("camisa__sin_pepino", torso, CAMISA, voxel=0.006, suavizado=8, caras=7000), "torso"))
# El guardapolvo: abierto adelante, con dos faldones rectos hasta las rodillas.
guarda = [kit.capsula((-0.16, 0.0, 1.47), (0.16, 0.0, 1.47), 0.085)]
for lado in (-1, 1):
    guarda.append(kit.caja((lado * 0.120, 0.012, 1.150), (0.130, 0.235, 0.660)))
    guarda.append(kit.caja((lado * 0.135, 0.020, 0.700), (0.115, 0.230, 0.300), rot=(0, lado * -4, 0)))
gp = kit.fundir("guardapolvo__sin_pepino", guarda, GUARDAPOLVO, voxel=0.007, suavizado=10, caras=8000)
# Abierto: adelante, en el medio, se ve la camisa.
partes.append((gp, "torso"))
# Las solapas.
solapas = [kit.caja((lado * 0.070, 0.125, 1.38), (0.050, 0.020, 0.200), rot=(0, 0, lado * -14)) for lado in (-1, 1)]
partes.append((kit.fundir("solapas__sin_pepino", solapas, GUARDAPOLVO, voxel=0.005, suavizado=4, caras=2000), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.064, r_codo=0.056, r_muneca=0.050, hasta=0.905)
partes.append((kit.fundir("mangas__sin_pepino", mangas, GUARDAPOLVO, voxel=0.006, suavizado=6, caras=4500), "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.042)
partes.append((kit.fundir("manos__sin_pepino", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.97), (0.150, 0.110, 0.085))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.070, r_rodilla=0.056, r_tobillo=0.050, hasta=0.22)
partes.append((kit.fundir("pantalon__sin_pepino", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=5500), "cadera"))
cinto = [kit.elipsoide((0, 0.0, 1.000), (0.162, 0.118, 0.026))]
partes.append((kit.fundir("cinto__sin_pepino", cinto, CINTO, voxel=0.005, suavizado=4, caras=2500), "torso"))
partes.append((kit.fundir("hebilla__sin_pepino", [kit.caja((0, 0.120, 1.000), (0.050, 0.012, 0.036))], HEBILLA,
                          voxel=0.004, suavizado=2, caras=500), "torso"))
medias = []
for lado in (-1, 1):
    medias.append(kit.capsula((lado * 0.12, 0.0, 0.23), (lado * 0.12, 0.0, 0.10), 0.046))
partes.append((kit.fundir("medias__sin_pepino", medias, MEDIAS, voxel=0.005, suavizado=4, caras=2000), "pies"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, largo=0.120, ancho=0.060, alto=0.050)
partes.append((kit.fundir("zapatos__sin_pepino", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=3000), "pies"))

# ------------------------------------------------------------------ Pickle Rick
pep = [kit.capsula((0, 0.0, 0.18), (0, 0.0, 1.84), 0.205, 0.168)]
import random
random.seed(7)
verrugas = []
for k in range(70):
    z = 0.25 + random.random() * 1.45
    a = random.random() * 6.283
    r = 0.205 - (z - 0.18) / 1.66 * 0.037
    verrugas.append(kit.elipsoide((math.cos(a) * r, math.sin(a) * r, z), (0.018, 0.018, 0.024), seg=10))
pp = kit.fundir("pepino__f_pepino", pep + verrugas, PEPINO, voxel=0.007, suavizado=6, caras=8000)
kit.pintar(pp, PEPINO_CLARO, lambda x, y, z: y > 0.10 and 1.62 < z < 1.95)
partes.append((pp, "torso"))
pelo_pep = [kit.tubo([(math.sin(a) * 0.14, -math.cos(a) * 0.12, 1.86), (math.sin(a) * 0.24, -math.cos(a) * 0.22, 1.92)],
                     [0.035, 0.006]) for a in (-0.9, -0.3, 0.3, 0.9)]
partes.append((kit.fundir("pelo_pepino__f_pepino", pelo_pep, PEPINO, voxel=0.005, suavizado=3, caras=1500), "torso"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.052, 1.825,
                         ojos_extra={"alto": 0.062, "ancho": 0.055, "iris": [0.1, 0.1, 0.1], "estilo": "simple"},
                         cejas={"alto": 0.040, "color": [0.55, 0.70, 0.78], "largo": 0.088},
                         boca_z=1.695, boca_extra={"ancho": 0.070, "dientes": False})
kit.exportar("rick", arm, cara)
