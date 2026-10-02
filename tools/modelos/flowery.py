"""Flowery, segun las notas de referencia de su modelo anterior.

Alto y flaco, de piel CHARTREUSE (verde amarillento). Pelo dorado teñido con las RAICES
NEGRAS y el flequillo en puntas hacia ARRIBA. Chaleco verde y naranja sobre una camisa
blanca, pantalon marron, zapatos negros de vestir, y una campera negra COLGADA DE UN
HOMBRO, que rompe la simetria y es lo que mas le cambia la silueta.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.74, 0.84, 0.42))
PELO = kit.material("pelo", (0.99, 0.80, 0.16), rugosidad=0.5)
RAIZ = kit.material("raices", (0.08, 0.07, 0.07))
CAMISA = kit.material("camisa~cuerpo", (0.97, 0.97, 0.95))
CHALECO_A = kit.material("chaleco_a", (0.29, 0.49, 0.27))
CHALECO_B = kit.material("chaleco_b", (0.93, 0.52, 0.15))
CAMPERA = kit.material("campera", (0.12, 0.12, 0.16))
PANTALON = kit.material("pantalon", (0.42, 0.30, 0.19))
ZAPATOS = kit.material("zapatos", (0.08, 0.08, 0.09), rugosidad=0.3)
BOTONES = kit.material("botones", (0.95, 0.85, 0.40))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.142, alto=0.178, fondo=0.152, mandibula=0.92, nariz=0.95)
cab.append(kit.capsula((0, -0.01, 1.48), (0, -0.01, 1.66), 0.055))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))

# EL PELO: casquete negro abajo (las raices) y el teñido dorado arriba, con el flequillo
# en puntas para arriba.
pelo = [kit.elipsoide((0, -0.030, 1.860), (0.158, 0.165, 0.150))]
# Las puntas del flequillo: para arriba y un poco para adelante, de largos distintos, como
# un copete parado con gel. Derechas y del mismo largo se leian como una corona.
for k, (dx, dy, alto) in enumerate(((-0.11, 0.08, 0.10), (-0.065, 0.11, 0.14), (-0.02, 0.12, 0.12),
                                     (0.025, 0.12, 0.15), (0.07, 0.11, 0.11), (0.115, 0.08, 0.09),
                                     (-0.04, 0.05, 0.13), (0.05, 0.05, 0.12))):
    pelo += kit.tubo([(dx * 0.85, dy - 0.02, 1.935), (dx, dy + 0.03, 1.935 + alto * 0.6),
                      (dx * 1.15, dy + 0.07, 1.935 + alto)], [0.040, 0.026, 0.005])
for k, dx in enumerate((-0.09, -0.03, 0.03, 0.09)):
    pelo += kit.tubo([(dx, -0.06, 1.965), (dx * 1.2, -0.13, 2.025), (dx * 1.3, -0.19, 2.035)], [0.045, 0.028, 0.006])
for lado in (-1, 1):
    pelo += kit.tubo([(lado * 0.140, 0.04, 1.900), (lado * 0.160, 0.03, 1.790), (lado * 0.150, 0.0, 1.720)],
                     [0.034, 0.028, 0.008])
pelo_obj = kit.fundir("pelo", pelo, PELO, voxel=0.0055, suavizado=6, caras=10000)
# Las raices negras: lo que queda pegado a la cabeza, abajo del teñido.
kit.pintar(pelo_obj, RAIZ, lambda x, y, z: z < 1.880 and y < 0.10)
partes.append((pelo_obj, "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.torso_humano(pecho=0.185, cintura=0.155, fondo=0.115, hombros=0.165)
camisa = kit.fundir("camisa", torso, CAMISA, voxel=0.006, suavizado=8, caras=8000)
partes.append((camisa, "torso"))
# El chaleco: por encima de la camisa, abierto en V; verde con el borde naranja.
chaleco = [kit.elipsoide((0, 0.004, 1.33), (0.195, 0.124, 0.205)),
           kit.elipsoide((0, 0.004, 1.13), (0.168, 0.118, 0.110))]
ch = kit.fundir("chaleco", chaleco, CHALECO_A, voxel=0.006, suavizado=8, caras=9000)
kit.pintar(ch, CAMISA, lambda x, y, z: y > 0.04 and z > 1.30 + abs(x) * 1.9)
kit.pintar(ch, CHALECO_B, lambda x, y, z: (y > 0.04 and abs(z - (1.30 + abs(x) * 1.9)) < 0.022) or z < 1.035)
partes.append((ch, "torso"))
botones = [kit.elipsoide((0, 0.128, z), (0.012, 0.006, 0.012), seg=12) for z in (1.27, 1.19, 1.11)]
partes.append((kit.pieza_fija("botones", botones, BOTONES), "torso"))
# El cuello de la camisa.
cuello = [kit.elipsoide((lado * 0.05, 0.07, 1.525), (0.055, 0.035, 0.028), rot=(20, 0, lado * -18)) for lado in (-1, 1)]
partes.append((kit.fundir("cuello", cuello, CAMISA, voxel=0.005, suavizado=4, caras=1500), "torso"))

# La campera negra colgada del hombro izquierdo, cayendo por la espalda.
campera = [kit.elipsoide((-0.200, -0.020, 1.470), (0.115, 0.115, 0.070)),
           kit.caja((-0.185, -0.105, 1.180), (0.200, 0.060, 0.560), rot=(-6, 0, 6)),
           kit.caja((-0.120, -0.135, 1.250), (0.230, 0.040, 0.420), rot=(-8, 0, 12)),
           kit.capsula((-0.28, -0.08, 1.40), (-0.30, -0.10, 1.00), 0.045, 0.040)]
partes.append((kit.fundir("campera", campera, CAMPERA, voxel=0.007, suavizado=10, caras=5000), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.058, r_codo=0.050, r_muneca=0.044, hasta=0.900)
partes.append((kit.fundir("mangas", mangas, CAMISA, voxel=0.006, suavizado=6, caras=4000), "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.044)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.97), (0.162, 0.115, 0.085))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.076, r_rodilla=0.060, r_tobillo=0.052, hasta=0.14)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, largo=0.125, ancho=0.060, alto=0.048, punta=0.9)
partes.append((kit.fundir("zapatos", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=3500), "pies"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.058, 1.815,
                         ojos_extra={"alto": 0.062, "ancho": 0.058, "iris": [0.85, 0.65, 0.12], "pestanas": False},
                         cejas={"alto": 0.046, "color": [0.10, 0.08, 0.06], "largo": 0.052},
                         boca_z=1.700, boca_extra={"ancho": 0.072, "dientes": False})
kit.exportar("flowery", arm, cara)
