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
# Una tela con espesor: la mitad izquierda de un torso inflado, de la espalda al hombro, que
# cae hasta la cadera; y la manga vacia colgando por atras del brazo.
def colgada(x, y, z):
    if not (1.00 < z < 1.60):
        return False
    if x > 0.06 - (1.60 - z) * 0.10:
        return False
    return y < 0.02 or (x < -0.12 and y < 0.11 and z > 1.36)


inflada = kit.torso_humano(pecho=0.206, cintura=0.180, fondo=0.140, hombros=0.170)
partes.append((kit.cascara("campera", inflada, CAMPERA, colgada, grosor=0.016, voxel=0.007, caras=6000), "torso"))
manga = kit.tubo([(-0.30, -0.075, 1.43), (-0.315, -0.10, 1.22), (-0.30, -0.115, 1.02)], [0.058, 0.052, 0.050])
partes.append((kit.fundir("manga_colgada", manga, CAMPERA, voxel=0.006, suavizado=6, caras=2500), "torso"))

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

# -------------------------------------------------------------------- Skins
#
#   omega      los siete colores de las flores a la vez: una corona de siete petalos
#              enormes detras de la cabeza, un color cada uno, y enredaderas en brazos y
#              piernas.
#   dorado     la Flor Dorada de la que salio: el cuello de petalos dorados.
#   primavera  florece, literalmente: flores en el pelo y en la ropa.
#   asgore     el violeta y el dorado del rey: la capa real con el borde dorado y la corona.
#   nocturno   el villano que dice ser: la capa negra de cuello alto.
#   marchito   las flores duraban un dia: flores secas, caidas.
import math
import random
CENTRO = kit.material("centro_flor", (0.98, 0.82, 0.25))
VERDE = kit.material("enredadera", (0.24, 0.52, 0.22))
PETALOS = [kit.material("petalo_%d" % k, c) for k, c in enumerate(
    ((0.95, 0.20, 0.25), (1.00, 0.55, 0.15), (1.00, 0.90, 0.25), (0.35, 0.85, 0.35),
     (0.30, 0.80, 1.00), (0.30, 0.40, 0.95), (0.70, 0.35, 0.95)))]
DORADO = kit.material("petalos", (1.00, 0.84, 0.30), metal=0.4)
FLOR_A = kit.material("flores", (0.98, 0.62, 0.78))
FLOR_B = kit.material("flores_b", (0.98, 0.98, 0.95))
SECO = kit.material("flores_secas", (0.50, 0.36, 0.22))
CAPA_REY = kit.material("capa", (0.40, 0.22, 0.55))
BORDE_REY = kit.material("capa_borde", (0.95, 0.78, 0.30), metal=0.5)
CORONA = kit.material("corona", (0.96, 0.80, 0.32), metal=0.8, rugosidad=0.25)
NEGRA = kit.material("capa_negra", (0.07, 0.07, 0.11))


def flor(centro, normal, radio, petalos=6, caida=0.0):
    """Una flor apoyada en una superficie: los petalos alrededor y el centro."""
    hojas, medio = [], []
    for k in range(petalos):
        a = 2 * math.pi * k / petalos
        p = (centro[0] + math.cos(a) * radio * 0.9, centro[1], centro[2] + math.sin(a) * radio * 0.9 - caida * radio)
        hojas.append(kit.elipsoide(p, (radio * 0.75, radio * 0.18, radio * 0.42), rot=(0, -math.degrees(a), 0), seg=14))
    medio.append(kit.elipsoide(centro, (radio * 0.42, radio * 0.30, radio * 0.42), seg=14))
    kit.orientar(hojas, centro, normal)
    kit.orientar(medio, centro, normal)
    return hojas, medio


# OMEGA: los siete petalos detras de la cabeza.
for k in range(7):
    a = math.radians(-90 + k * (180 / 6))
    c = (math.cos(a) * 0.30, -0.16, 1.86 + math.sin(-a) * 0.0 + abs(math.cos(a)) * -0.04 + 0.30 * math.sin(math.radians(k * 30)))
    a2 = math.radians(k * (360 / 7) + 90)
    c = (math.cos(a2) * 0.29, -0.17, 1.84 + math.sin(a2) * 0.29)
    p = [kit.elipsoide(c, (0.090, 0.022, 0.150), rot=(0, -math.degrees(a2) + 90, 0), seg=20)]
    partes.append((kit.fundir(kit.de_skin("omega_%d" % k, "omega"), p, PETALOS[k], voxel=0.006, suavizado=3, caras=900),
                   "cabeza"))
partes.append((kit.fundir(kit.de_skin("omega_centro", "omega"), [kit.elipsoide((0, -0.175, 1.84), (0.10, 0.03, 0.10))],
                          CENTRO, voxel=0.006, suavizado=3, caras=800), "cabeza"))
vinas = []
brazos_o = [o for o, _r in partes if o.name == "mangas"][0]
piernas_o = [o for o, _r in partes if o.name == "pantalon"][0]
for lado in (-1, 1):
    x = lado * 0.29
    vinas.append([kit.pegar(brazos_o, (x + math.cos(t * 9) * 0.1, math.sin(t * 9) * 0.1, 1.42 - t * 0.55), 0.006)
                  for t in [i / 40 for i in range(41)]])
    x = lado * 0.12
    vinas.append([kit.pegar(piernas_o, (x + math.cos(t * 10 + 1) * 0.12, math.sin(t * 10 + 1) * 0.12, 0.92 - t * 0.74), 0.006)
                  for t in [i / 44 for i in range(45)]])
partes.append((kit.lineas(kit.de_skin("enredadera", "omega"), vinas, 0.010, VERDE), "por_distancia"))
# DORADO: el cuello de petalos dorados, alrededor del cuello, para arriba y para afuera.
cuello_p = []
for k in range(12):
    a = 2 * math.pi * k / 12
    c = (math.sin(a) * 0.115, math.cos(a) * 0.100 - 0.010, 1.555)
    cuello_p.append(kit.elipsoide(c, (0.050, 0.014, 0.080), rot=(-math.cos(a) * 55, 0, math.degrees(a)), seg=14))
partes.append((kit.fundir(kit.de_skin("petalos", "dorado"), cuello_p, DORADO, voxel=0.0045, suavizado=3, caras=4000),
               "torso"))
# PRIMAVERA: flores en el pelo y en la ropa.
pelo_o = [o for o, _r in partes if o.name == "pelo"][0]
chaleco_o = [o for o, _r in partes if o.name == "chaleco"][0]
hojas_a, hojas_b, centros = [], [], []
for k, (obj, x, z) in enumerate(((pelo_o, -0.10, 1.95), (pelo_o, 0.08, 2.00), (pelo_o, 0.13, 1.90),
                                 (chaleco_o, -0.11, 1.38), (chaleco_o, 0.12, 1.22), (chaleco_o, -0.06, 1.12))):
    p, n = kit.superficie(obj, x, z)
    if p is None:
        continue
    h, m = flor(tuple(p + n * 0.010), n, 0.034 if k < 3 else 0.030)
    (hojas_a if k % 2 == 0 else hojas_b).extend(h)
    centros.extend(m)
partes.append((kit.pieza_fija(kit.de_skin("flores", "primavera"), hojas_a, FLOR_A), "torso"))
partes.append((kit.pieza_fija(kit.de_skin("flores_b", "primavera"), hojas_b, FLOR_B), "torso"))
partes.append((kit.pieza_fija(kit.de_skin("flores_centro", "primavera"), centros, CENTRO), "torso"))
# MARCHITO: las mismas flores, secas y caidas, con los petalos para abajo.
secas = []
for k, (obj, x, z) in enumerate(((chaleco_o, -0.11, 1.38), (chaleco_o, 0.12, 1.22), (pelo_o, 0.10, 1.96))):
    p, n = kit.superficie(obj, x, z)
    if p is None:
        continue
    h, m = flor(tuple(p + n * 0.010), n, 0.032, petalos=5, caida=0.6)
    secas += h + m
partes.append((kit.pieza_fija(kit.de_skin("flores", "marchito"), secas, SECO), "torso"))
# ASGORE: la capa real violeta con el borde dorado, y la corona chica.
capa_rey = kit.capa("capa", ["asgore"], CAPA_REY, z_abajo=0.30, abre=0.14, cuello=0.10)
partes.append((capa_rey, "torso"))
borde = [[kit.pegar(capa_rey, (math.sin(a) * 0.5, math.cos(a) * 0.5 - 0.1, 0.32), 0.004) for a in
          [math.radians(95 + i * 8.5) for i in range(21)]]]
partes.append((kit.lineas(kit.de_skin("capa_borde", "asgore"), borde, 0.012, BORDE_REY), "torso"))
corona = []
for k in range(30):
    a, b = 2 * math.pi * k / 30, 2 * math.pi * (k + 1) / 30
    corona.append(kit.capsula((math.sin(a) * 0.125, math.cos(a) * 0.125 - 0.04, 2.075),
                              (math.sin(b) * 0.125, math.cos(b) * 0.125 - 0.04, 2.075), 0.016, seg=8))
for k in range(5):
    a = 2 * math.pi * k / 5
    corona.append(kit.cono((math.sin(a) * 0.125, math.cos(a) * 0.125 - 0.04, 2.085),
                           (math.sin(a) * 0.130, math.cos(a) * 0.130 - 0.04, 2.175), 0.026, 0.003, seg=8))
partes.append((kit.fundir(kit.de_skin("corona", "asgore"), corona, CORONA, voxel=0.0035, suavizado=2, caras=2500), "cabeza"))
# NOCTURNO: la capa negra larga con el cuello alto del villano.
partes.append((kit.capa("capa", ["nocturno"], NEGRA, z_abajo=0.35, abre=0.12, cuello=0.16), "torso"))
for obj, _r in partes:
    if obj.name in ("campera", "manga_colgada"):
        # La campera colgada del hombro no va con una capa encima.
        kit.ocultar_en(obj, "asgore", "nocturno")

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla == "por_distancia":
        kit.pesar(obj, arm, J)
kit.pesar_estandar([p for p in partes if p[1] != "por_distancia"], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.058, 1.815,
                         ojos_extra={"alto": 0.062, "ancho": 0.058, "iris": [0.85, 0.65, 0.12], "pestanas": False},
                         cejas={"alto": 0.046, "color": [0.10, 0.08, 0.06], "largo": 0.052},
                         boca_z=1.700, boca_extra={"ancho": 0.072, "dientes": False})
kit.exportar("flowery", arm, cara)
