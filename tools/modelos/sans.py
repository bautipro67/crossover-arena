"""Sans, de Undertale, segun las notas de su modelo anterior.

Bajo y ancho, la calavera redonda y GRANDE con la sonrisa de siempre de punta a punta, las
cuencas negras con las pupilas blancas chiquitas y la nariz hueca; la campera celeste
abierta con la capucha de piel blanca caida en la espalda y los cordones, la remera blanca,
el short negro con la raya blanca, las canillas de hueso y las pantuflas rosas. La sonrisa no
se mueve nunca: va modelada sobre la calavera y no como boca animada. Forma "un_ojo" (Mal
Rato): un ojo encendido y grande y el otro apagado.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas({"caderas": (0, 0, 0.74), "cabeza": (0, 0, 1.36),
                "hombro_r": (0.30, 0, 1.24), "codo_r": (0.33, 0, 1.00), "mano_r": (0.34, 0, 0.79),
                "pierna_r": (0.13, 0, 0.72), "rodilla_r": (0.13, 0, 0.41), "pie_r": (0.13, 0, 0.08)})

HUESO = kit.material("hueso~piel", (0.95, 0.95, 0.92))
NEGRO = kit.material("detalle_chico", (0.03, 0.03, 0.05))
CAMPERA = kit.material("campera~cuerpo", (0.33, 0.55, 0.88))
PIEL = kit.material("piel~propio", (0.96, 0.96, 0.96))
REMERA = kit.material("remera", (0.97, 0.97, 0.97))
SHORT = kit.material("short~pantalon", (0.10, 0.10, 0.12))
PANTUFLAS = kit.material("zapatos", (0.96, 0.58, 0.72))

partes = []

# ------------------------------------------------------------------ Calavera
C = (0.0, 0.005, 1.60)
cab = [kit.elipsoide(C, (0.232, 0.212, 0.222)),
       kit.elipsoide((0, 0.045, 1.495), (0.205, 0.175, 0.115)),
       kit.capsula((0, -0.01, 1.30), (0, -0.01, 1.42), 0.060)]
for lado in (-1, 1):
    # Los pomulos, que marcan las cuencas desde abajo.
    cab.append(kit.elipsoide((lado * 0.110, 0.125, 1.565), (0.085, 0.075, 0.060)))
cabeza = kit.fundir("calavera", cab, HUESO, voxel=0.006, suavizado=10, caras=10000)
partes.append((cabeza, "cabeza"))

# La sonrisa: una linea de punta a punta pegada a la calavera, con las rayas de los dientes;
# y la nariz hueca, un corazon chico dado vuelta.
def sobre(x, z, afuera=0.0015):
    p, n = kit.superficie(cabeza, x, z)
    return tuple(p + n * afuera)


def sonrisa_z(x):
    return 1.488 + 0.030 * (x / 0.155) ** 2


cara = []
puntos = [sobre(x / 100.0, sonrisa_z(x / 100.0)) for x in range(-16, 17, 2)]
cara += kit.tubo(puntos, [0.0042] + [0.0055] * (len(puntos) - 2) + [0.0042], seg=8)
for k in range(-3, 4):
    x = k * 0.036
    z = sonrisa_z(x)
    cara += kit.tubo([sobre(x, z + 0.020), sobre(x, z - 0.020)], [0.0035, 0.0035], seg=8)
for lado in (-1, 1):
    q = sobre(lado * 0.011, 1.555, 0.0)
    cara.append(kit.elipsoide(q, (0.011, 0.008, 0.017), rot=(0, lado * 28, 0), seg=14))
partes.append((kit.fundir("cara", cara, NEGRO, voxel=0.0025, suavizado=1, caras=4000), "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.perfil([(0.76, 0.215, 0.165), (0.90, 0.236, 0.180), (1.05, 0.246, 0.186), (1.18, 0.238, 0.172),
                    (1.28, 0.196, 0.148)])
torso.append(kit.capsula((-0.20, 0.0, 1.24), (0.20, 0.0, 1.24), 0.086))
campera = kit.fundir("campera", torso, CAMPERA, voxel=0.006, suavizado=8, caras=11000)
# Abierta adelante: asoma la remera blanca.
kit.pintar(campera, REMERA, lambda x, y, z: y > 0.06 and abs(x) < 0.078 and z < 1.30)
partes.append((campera, "torso"))
# La capucha caida en la espalda, con el borde de piel blanca alrededor del cuello.
partes.append((kit.fundir("capucha", [kit.elipsoide((0, -0.165, 1.185), (0.150, 0.055, 0.115))], CAMPERA,
                          voxel=0.006, suavizado=6, caras=2500), "torso"))
random.seed(3)
piel = []
for k in range(48):
    a = 2 * math.pi * k / 48
    frente = (1 + math.cos(a)) / 2
    p = (math.sin(a) * 0.190, math.cos(a) * 0.160 - 0.035, 1.215 + 0.105 * frente)
    piel.append(kit.elipsoide(p, (0.044 + random.random() * 0.012, 0.044 + random.random() * 0.012,
                                  0.040 + random.random() * 0.010), seg=14))
partes.append((kit.fundir("piel", piel, PIEL, voxel=0.0055, suavizado=4, caras=5000), "torso"))
# Los cordones de la capucha.
cordones = []
for lado in (-1, 1):
    a = kit.superficie(campera, lado * 0.055, 1.28)[0]
    b = kit.superficie(campera, lado * 0.058, 1.13)[0]
    cordones += kit.tubo([(a.x, a.y + 0.012, a.z), (b.x, b.y + 0.014, b.z)], [0.007, 0.007], seg=8)
    cordones.append(kit.capsula((b.x, b.y + 0.014, b.z), (b.x, b.y + 0.014, b.z - 0.020), 0.010, seg=10))
partes.append((kit.fundir("cordones", cordones, REMERA, voxel=0.003, suavizado=2, caras=1500), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.082, r_codo=0.076, r_muneca=0.072, j=J, hasta=0.875)
partes.append((kit.fundir("mangas", mangas, CAMPERA, voxel=0.006, suavizado=6, caras=5000), "brazos"))
punos = []
for lado in (-1, 1):
    m = J["mano_r" if lado > 0 else "mano_l"]
    punos.append(kit.capsula((m[0], m[1], 0.890), (m[0], m[1], 0.862), 0.077))
partes.append((kit.fundir("punos", punos, PIEL, voxel=0.005, suavizado=4, caras=2000), "manos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, j=J, r=0.050, guante=1.15)
partes.append((kit.fundir("manos", manos, HUESO, voxel=0.005, suavizado=5, caras=4500), "manos"))

# -------------------------------------------------------------------- Piernas
short = [kit.elipsoide((0, 0.0, 0.76), (0.215, 0.160, 0.090))]
for lado in (-1, 1):
    x = lado * 0.13
    short.append(kit.capsula((x, 0.0, 0.72), (x, 0.0, 0.53), 0.108, 0.100))
sh = kit.fundir("short", short, SHORT, voxel=0.006, suavizado=8, caras=5000)
# La raya blanca a los costados.
kit.pintar(sh, REMERA, lambda x, y, z: abs(x) > 0.205 and abs(y) < 0.030 and z < 0.80)
partes.append((sh, "cadera"))
canillas = []
for lado in (-1, 1):
    x = lado * 0.13
    canillas += kit.tubo([(x, 0.0, 0.52), (x, 0.0, 0.47), (x, 0.0, 0.19), (x, 0.0, 0.13)], [0.058, 0.044, 0.040, 0.050])
partes.append((kit.fundir("canillas", canillas, HUESO, voxel=0.005, suavizado=5, caras=3000), "pies"))
pantuflas = []
for lado in (-1, 1):
    pantuflas += kit.zapato(lado, j=J, largo=0.150, ancho=0.088, alto=0.072, punta=1.2)
partes.append((kit.fundir("pantuflas", pantuflas, PANTUFLAS, voxel=0.006, suavizado=8, caras=4000), "pies"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
datos = kit.cara_estandar(cabeza, J, 0.088, 1.628,
                          ojos_extra={"alto": 0.084, "ancho": 0.074, "iris": [1.0, 1.0, 1.0], "estilo": "cuenca",
                                      "parte": "pupilas",
                                      "formas": {"un_ojo": {"lado_l": {"estilo": "cuenca_vacia"},
                                                            "lado_r": {"estilo": "cuenca_grande"}}}})
kit.exportar("sans", arm, datos)
