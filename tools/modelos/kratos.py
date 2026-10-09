"""Kratos, de God of War (el de Midgard, 2018).

Grande y musculoso, la piel blanca de ceniza y el tatuaje rojo que le baja del ojo
izquierdo por la cabeza y le da la vuelta al torso. Pelado, con la barba tupida. El torso
al aire, con la hombrera de metal en el hombro derecho y la correa de cuero que le cruza
el pecho; el cinturon ancho y la falda de cuero por encima del pantalon; los brazales en
los antebrazos y las botas. El Hacha Leviatan en la mano derecha.

Skins:
  guerra   solo color (el cuero negro).
  fimbul   el manto de piel de Ragnarok, sobre los hombros y la espalda.
  griego   el de Grecia: la perilla en vez de la barba y las Hojas del Caos en las manos.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
kit.FACTOR_BRAZO = 1.22
J = kit.juntas()

PIEL = kit.material("piel", (0.86, 0.84, 0.80))
BARBA = kit.material("barba", (0.18, 0.16, 0.15), rugosidad=0.7)
TATUAJE = kit.material("tatuajes", (0.72, 0.10, 0.08))
CUERO = kit.material("correa", (0.30, 0.20, 0.14))
METAL = kit.material("metal", (0.52, 0.52, 0.55), metal=0.8, rugosidad=0.35)
CINTO = kit.material("cinturon", (0.24, 0.16, 0.11))
FALDA = kit.material("falda~cuerpo", (0.36, 0.24, 0.16))
PANTALON = kit.material("pantalon~pantalon", (0.30, 0.20, 0.14))
BOTAS = kit.material("botas~zapatos", (0.22, 0.15, 0.11))
BRAZAL = kit.material("brazales", (0.26, 0.18, 0.12))
ACERO = kit.material("hacha", (0.62, 0.66, 0.72), metal=0.8, rugosidad=0.3)
FILO = kit.material("neon_filo", (0.60, 0.85, 1.00))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.142, alto=0.178, fondo=0.158, mandibula=1.05, nariz=1.1, menton=1.05)
cab.append(kit.capsula((0, -0.01, 1.46), (0, -0.01, 1.66), 0.070))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))


def sobre(obj, x, z, afuera=0.003, desde=(0.0, 1.5), hacia=(0.0, -1.0)):
    p, n = kit.superficie(obj, x, z, desde, hacia)
    if p is None:
        return None
    return tuple(p + n * afuera)


# LA BARBA: tupida, desde las patillas hasta abajo del menton, con el bigote.
barba = [kit.elipsoide((0, 0.090, 1.680), (0.118, 0.080, 0.090)),
         kit.elipsoide((0, 0.115, 1.625), (0.085, 0.060, 0.070))]
for lado in (-1, 1):
    barba.append(kit.elipsoide((lado * 0.115, 0.040, 1.725), (0.040, 0.060, 0.080)))
    barba.append(kit.elipsoide((lado * 0.030, 0.150, 1.718), (0.040, 0.016, 0.014), rot=(0, 0, lado * -15)))
b = kit.fundir("barba", barba, BARBA, voxel=0.005, suavizado=5, caras=5000)
kit.ocultar_en(b, "griego")
partes.append((b, "cabeza"))
# EL TATUAJE de la cabeza: del ojo izquierdo (el izquierdo es -X) sube por la frente y la
# coronilla y baja por la nuca.
linea_cab = []
for k in range(16):
    t = k / 15.0
    a = t * math.pi * 1.05
    # Un camino aproximado por afuera de la cabeza, pegado despues a la superficie.
    aprox = (-0.058 - 0.015 * t, 0.30 * math.cos(a), 1.80 + 0.30 * math.sin(a))
    linea_cab.append(kit.pegar(cabeza, aprox, 0.004))
partes.append((kit.lineas("tatuaje_cabeza", [linea_cab], 0.014, TATUAJE), "cabeza"))

# -------------------------------------------------------------------- Torso
PERFIL = [(0.88, 0.190, 0.140), (1.00, 0.188, 0.140), (1.12, 0.196, 0.144), (1.26, 0.222, 0.155),
          (1.38, 0.246, 0.164), (1.47, 0.240, 0.156), (1.54, 0.180, 0.124)]
torso = kit.perfil(PERFIL)
torso.append(kit.capsula((-0.20, 0.0, 1.48), (0.20, 0.0, 1.48), 0.098))
for lado in (-1, 1):
    torso.append(kit.elipsoide((lado * 0.100, 0.100, 1.380), (0.120, 0.066, 0.086)))
    torso.append(kit.capsula((lado * 0.06, -0.02, 1.56), (lado * 0.21, 0.0, 1.50), 0.062, 0.074))
    for z in (1.250, 1.180, 1.110):
        torso.append(kit.elipsoide((lado * 0.044, 0.118, z), (0.040, 0.030, 0.032)))
pecho = kit.fundir("pecho", torso, PIEL, voxel=0.006, suavizado=8, caras=11000)
partes.append((pecho, "torso"))
# El tatuaje del cuerpo: baja por el lado izquierdo del pecho, da la vuelta por la
# cintura y sube por la espalda.
linea_t = []
for k in range(22):
    t = k / 21.0
    a = math.pi * 0.55 + t * math.pi * 1.35
    z = 1.52 - t * 0.44
    linea_t.append(kit.pegar(pecho, (math.cos(a) * 0.40 - 0.03, math.sin(a) * 0.40, z), 0.005))
partes.append((kit.lineas("tatuaje_torso", [linea_t], 0.018, TATUAJE), "torso"))
# LA HOMBRERA en el hombro derecho (+X) y la correa que cruza hasta la cadera izquierda.
hr = J["hombro_r"]
partes.append((kit.cascara("hombrera", [kit.elipsoide((hr[0] + 0.01, 0.0, hr[2] + 0.02), (0.130, 0.140, 0.110))], METAL,
                           lambda x, y, z: z > hr[2] - 0.06 and x > 0.18, grosor=0.018, caras=3000), "hombro_r"))
correa = []
for k in range(10):
    t = k / 9.0
    x = 0.20 - t * 0.38
    z = 1.50 - t * 0.48
    q = sobre(pecho, x, z, 0.010)
    if q is not None:
        correa.append(q)
correa_b = []
for k in range(10):
    t = k / 9.0
    x = 0.20 - t * 0.38
    z = 1.50 - t * 0.48
    q = sobre(pecho, x, z, 0.010, desde=(0.0, -1.5), hacia=(0.0, 1.0))
    if q is not None:
        correa_b.append(q)
partes.append((kit.lineas("correa", [correa, correa_b], 0.020, CUERO), "torso"))
cint = kit.perfil([(0.93, 0.205, 0.156), (1.04, 0.200, 0.152)])
partes.append((kit.fundir("cinturon", cint, CINTO, voxel=0.005, suavizado=4, caras=4000), "torso"))
p0, n0 = kit.superficie(kit.bpy.data.objects["cinturon"], 0.0, 0.985)
hebilla = [kit.elipsoide(tuple(p0 + n0 * 0.010), (0.050, 0.012, 0.040))]
partes.append((kit.fundir("hebilla", hebilla, METAL, voxel=0.0025, suavizado=2, caras=1200), "torso"))
# LA FALDA de cuero: paneles que caen de la cintura hasta arriba de la rodilla.
falda = kit.perfil([(0.58, 0.240, 0.190), (0.75, 0.222, 0.175), (0.93, 0.202, 0.156)])
partes.append((kit.cascara("falda", falda, FALDA, lambda x, y, z: 0.60 < z < 0.93 and abs(math.atan2(x, y)) % 0.9 > 0.08,
                           grosor=0.012, caras=5000), "cadera"))

# --------------------------------------------------------------------- Brazos
brazos = []
for lado in (-1, 1):
    brazos += kit.brazo(lado, r_hombro=0.074, r_codo=0.064, r_muneca=0.054, hasta=0.86)
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.006, suavizado=6, caras=6000), "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.050)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))
brazales = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    c, m = J["codo" + s], J["mano" + s]
    f = kit.FACTOR_BRAZO
    brazales += kit.tubo([(c[0], c[1], c[2] - 0.06), (m[0], m[1], m[2] + 0.06)], [0.070 * f, 0.062 * f])
partes.append((kit.fundir("brazales", brazales, BRAZAL, voxel=0.005, suavizado=4, caras=3500), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.94), (0.175, 0.130, 0.090))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.100, r_rodilla=0.084, r_tobillo=0.070, hasta=0.32)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6500), "cadera"))
botas = []
for lado in (-1, 1):
    x = lado * 0.12
    botas.append(kit.capsula((x, 0.0, 0.40), (x, 0.0, 0.10), 0.080, 0.076))
    botas += kit.zapato(lado, largo=0.135, ancho=0.074, alto=0.064)
partes.append((kit.fundir("botas", botas, BOTAS, voxel=0.006, suavizado=6, caras=4000), "pies"))

# ------------------------------------------------------------------ El hacha
xm, ym, zm = J["mano_r"]
hacha = [kit.capsula((xm + 0.005, ym - 0.10, zm - 0.02), (xm + 0.005, ym + 0.48, zm - 0.02), 0.020),
         kit.caja((xm + 0.005, ym + 0.42, zm + 0.10), (0.030, 0.140, 0.220))]
ha = kit.fundir("hacha", hacha, ACERO, voxel=0.004, suavizado=2, caras=3000)
kit.ocultar_en(ha, "griego")
partes.append((ha, "codo_r"))
fl = kit.fundir("neon_filo", [kit.caja((xm + 0.005, ym + 0.42, zm + 0.215), (0.032, 0.150, 0.020))], FILO,
                voxel=0.003, suavizado=1, caras=800)
kit.ocultar_en(fl, "griego")
partes.append((fl, "codo_r"))

# ======================================================================== Skins
# FIMBUL: el manto de piel de oso sobre los hombros y la espalda, del invierno de Ragnarok.
PIEL_OSO = kit.material("manto", (0.36, 0.28, 0.22), rugosidad=0.9)
manto_p = kit.perfil([(0.84, 0.272, 0.205), (1.10, 0.258, 0.192), (1.35, 0.268, 0.192), (1.50, 0.256, 0.182),
                      (1.58, 0.176, 0.136)])
manto_p.append(kit.capsula((-0.215, 0.0, 1.49), (0.215, 0.0, 1.49), 0.112))
manto = kit.cascara(kit.de_skin("manto", "fimbul"), manto_p, PIEL_OSO,
                    lambda x, y, z: (y < 0.03 and 0.86 < z < 1.60) or (z > 1.42 and abs(x) > 0.12 and y < 0.12),
                    grosor=0.016, caras=6000)
partes.append((manto, "torso"))
# GRIEGO: la perilla en vez de la barba, y las Hojas del Caos (una en cada mano).
perilla = [kit.elipsoide((0, 0.128, 1.640), (0.040, 0.030, 0.050))]
for lado in (-1, 1):
    perilla.append(kit.elipsoide((lado * 0.032, 0.150, 1.716), (0.034, 0.012, 0.012), rot=(0, 0, lado * -20)))
partes.append((kit.fundir(kit.de_skin("perilla", "griego"), perilla, BARBA, voxel=0.004, suavizado=3, caras=1500),
               "cabeza"))
HOJA_CAOS = kit.material("neon_caos", (1.0, 0.45, 0.15))
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    x, y, z = J["mano" + s]
    hoja = [kit.caja((x, y + 0.20, z - 0.02), (0.020, 0.36, 0.060)),
            kit.cono((x, y + 0.38, z - 0.02), (x, y + 0.46, z - 0.02), 0.032, 0.001, seg=4)]
    partes.append((kit.fundir(kit.de_skin("hoja_caos" + s, "griego"), hoja, HOJA_CAOS, voxel=0.003, suavizado=1,
                              caras=1500), "codo" + s))

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla.startswith("hombro_"):
        kit.pesar(obj, arm, J, solo=regla)
kit.pesar_estandar([p for p in partes if not p[1].startswith("hombro_")], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.056, 1.818,
                         ojos_extra={"alto": 0.044, "ancho": 0.056, "iris": [0.75, 0.55, 0.20], "pestanas": False},
                         cejas={"alto": 0.030, "color": [0.18, 0.16, 0.15], "largo": 0.066},
                         boca_z=1.700, boca_extra={"ancho": 0.064, "dientes": False, "oculto": True,
                                                   "formas": {"griego": {"oculto": False}}})
kit.exportar("kratos", arm, cara)
