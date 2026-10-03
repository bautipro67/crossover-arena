"""Thanos, con el Guantelete del Infinito, segun las notas de su modelo anterior (el del MCU).

Piel violacea, pelado, el MENTON enorme con las lineas verticales que lo marcan, la frente
pesada sobre los ojos azules; la armadura oscura con los detalles dorados en los hombros, las
cintas cruzadas del pecho y el cinto; las rodilleras doradas; y el Guantelete dorado en la
mano IZQUIERDA, con las seis gemas: cinco en los nudillos y el pulgar, y la del Alma en el
dorso. LA SILUETA ES EL TAMAÑO Y EL GUANTELETE: el torso mas ancho del juego, la cabeza chica
para ese cuerpo, y un brazo que brilla en seis colores.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
# EL CUERPO MAS GRANDE DEL JUEGO: brazos, piernas y manos de titan.
kit.FACTOR_BRAZO = 1.38
kit.FACTOR_PIERNA = 1.28
kit.FACTOR_MANO = 1.40
J = kit.juntas({"hombro_r": (0.31, 0, 1.44), "codo_r": (0.32, 0, 1.12), "mano_r": (0.32, 0, 0.82)})

PIEL = kit.material("piel", (0.62, 0.48, 0.68))
LINEAS = kit.material("lineas", (0.40, 0.30, 0.45))
ARMADURA = kit.material("cuerpo", (0.23, 0.26, 0.38), rugosidad=0.45)
ORO = kit.material("oro~acento", (0.86, 0.68, 0.25), metal=0.8, rugosidad=0.3)
GUANTELETE = kit.material("guantelete", (0.92, 0.74, 0.28), metal=0.8, rugosidad=0.3)
PANTALON = kit.material("pantalon", (0.19, 0.21, 0.30))
BOTAS = kit.material("zapatos~propio", (0.14, 0.15, 0.22))
GEMAS = [kit.material("gema_espacio", (0.25, 0.45, 1.00)), kit.material("gema_mente", (1.00, 0.85, 0.20)),
         kit.material("gema_realidad", (0.95, 0.12, 0.16)), kit.material("gema_poder", (0.62, 0.22, 0.95)),
         kit.material("gema_tiempo", (0.20, 0.90, 0.35)), kit.material("gema_alma", (1.00, 0.52, 0.12))]

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.142, alto=0.180, fondo=0.155, mandibula=1.18, nariz=1.15,
                        menton=1.10, orejas=True)
# EL MENTON enorme, cuadrado y para adelante; la frente pesada en un arco sobre los ojos; y el
# cuello grueso que baja ancho a los hombros.
cab += [kit.elipsoide((0, 0.085, 1.665), (0.108, 0.080, 0.072)),
        kit.elipsoide((0, 0.035, 1.700), (0.128, 0.105, 0.075)),
        kit.capsula((-0.085, 0.120, 1.858), (0.085, 0.120, 1.858), 0.030),
        kit.capsula((0, -0.02, 1.47), (0, -0.01, 1.66), 0.088, 0.078)]
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=9, caras=10000)
partes.append((cabeza, "cabeza"))
# Las lineas del menton: surcos verticales pegados a la piel.
lineas = []
for x in (-0.060, -0.030, 0.0, 0.030, 0.060):
    puntos = []
    for z in (1.715, 1.690, 1.665, 1.640, 1.618):
        p, n = kit.superficie(cabeza, x, z)
        if p is not None:
            puntos.append(tuple(p + n * 0.001))
    if len(puntos) >= 2:
        lineas += kit.tubo(puntos, [0.0045] * len(puntos), seg=8)
partes.append((kit.fundir("lineas", lineas, LINEAS, voxel=0.003, suavizado=1, caras=3000), "cabeza"))

# -------------------------------------------------------------------- Torso
# El torso ancho, con los pectorales y el cuello de la armadura.
torso = kit.perfil([(0.92, 0.190, 0.140), (1.05, 0.192, 0.142), (1.20, 0.212, 0.150), (1.34, 0.240, 0.160),
                    (1.46, 0.236, 0.152), (1.54, 0.180, 0.125)])
torso += [kit.capsula((-0.20, 0.0, 1.48), (0.20, 0.0, 1.48), 0.095)]
for lado in (-1, 1):
    torso.append(kit.elipsoide((lado * 0.100, 0.095, 1.375), (0.118, 0.065, 0.085)))
    # Los trapecios, del cuello al hombro.
    torso.append(kit.capsula((lado * 0.06, -0.02, 1.56), (lado * 0.21, 0.0, 1.50), 0.060, 0.070))
arm_t = kit.fundir("armadura", torso, ARMADURA, voxel=0.006, suavizado=8, caras=11000)
partes.append((arm_t, "torso"))

# El oro: las cintas cruzadas del pecho y el cinto, recortados de un torso apenas inflado
# para que sean placas con canto y no pintura.
def inflado():
    t = kit.perfil([(0.92, 0.204, 0.154), (1.05, 0.206, 0.156), (1.20, 0.226, 0.164), (1.34, 0.254, 0.174),
                    (1.46, 0.250, 0.166), (1.54, 0.194, 0.139)])
    for lado in (-1, 1):
        t.append(kit.elipsoide((lado * 0.100, 0.108, 1.375), (0.124, 0.067, 0.090)))
    return t


def cintas(x, y, z):
    if y < 0.03 or not (1.08 < z < 1.52):
        return False
    return abs(abs(x) - (0.025 + (z - 1.08) * 0.33)) < 0.030


partes.append((kit.cascara("cintas", inflado(), ORO, cintas, grosor=0.012, caras=4000), "torso"))
partes.append((kit.cascara("cinto", inflado(), ORO, lambda x, y, z: 0.985 < z < 1.075, grosor=0.014, caras=4000),
               "torso"))
p, n = kit.superficie(arm_t, 0.0, 1.03)
hebilla = [kit.elipsoide(tuple(p + n * 0.020), (0.050, 0.018, 0.042), seg=28)]
partes.append((kit.fundir("hebilla_oro", hebilla, ORO, voxel=0.004, suavizado=3, caras=1500), "torso"))
# Las hombreras: una cupula y dos laminas que caen hacia afuera.
for lado in (-1, 1):
    s = "l" if lado < 0 else "r"
    piezas = [kit.cascara("hombrera_%s" % s, [kit.elipsoide((lado * 0.305, 0.0, 1.475), (0.140, 0.150, 0.112))], ORO,
                          lambda x, y, z: z > 1.405 and abs(x) > 0.210, grosor=0.018, caras=2500),
              kit.cascara("lamina_%s" % s, [kit.elipsoide((lado * 0.322, 0.0, 1.415), (0.150, 0.158, 0.105))], ORO,
                          lambda x, y, z: 1.340 < z < 1.415 and abs(x) > 0.262, grosor=0.016, caras=2500)]
    for o in piezas:
        partes.append((o, "hombro_" + s))

# --------------------------------------------------------------------- Brazos
# Las mangas cortas de la armadura, los brazos violetas y, en el izquierdo, el Guantelete.
mangas = []
for lado in (-1, 1):
    sx = "_l" if lado < 0 else "_r"
    h = J["hombro" + sx]
    mangas += kit.tubo([h, (h[0], h[1], h[2] - 0.20)], [0.092, 0.084])
partes.append((kit.fundir("mangas", mangas, ARMADURA, voxel=0.006, suavizado=6, caras=3500), "brazos"))
brazos = []
h, c = J["hombro_r"], J["codo_r"]
brazos += kit.tubo([(h[0], h[1], h[2] - 0.14), c], [0.084, 0.074])
brazos += kit.antebrazo(1, r_codo=0.074, r_muneca=0.056, j=J)
brazos += kit.mano(1, j=J, r=0.056)
h, c = J["hombro_l"], J["codo_l"]
brazos += kit.tubo([(h[0], h[1], h[2] - 0.14), c], [0.084, 0.074])
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.0055, suavizado=6, caras=7000), "brazos"))
# EL GUANTELETE: el antebrazo entero de oro, con un reborde en la muñeca, y la mano grande.
xm, ym, zm = J["mano_l"]
gl = kit.tubo([J["codo_l"], (xm, ym, 0.890)], [0.082, 0.070])
gl.append(kit.capsula((xm, ym, 0.915), (xm, ym, 0.885), 0.080))
gl += kit.mano(-1, j=J, r=0.056, guante=1.32)
guante = kit.fundir("guantelete", gl, GUANTELETE, voxel=0.005, suavizado=5, caras=7000)
partes.append((guante, "manos"))
# Las gemas: cuatro en los nudillos (por afuera de la mano), la del pulgar y la del Alma en
# el dorso.
g = 1.32
gemas = []
for k in range(4):
    gemas.append((kit.elipsoide((xm - 0.050 * g, ym + (-0.024 + k * 0.016) * g, zm - 0.036 * g),
                                (0.015, 0.014, 0.017), seg=16), GEMAS[k]))
gemas.append((kit.elipsoide((xm + 0.000, ym + 0.060 * g, zm + 0.010), (0.016, 0.016, 0.018), seg=16), GEMAS[4]))
gemas.append((kit.elipsoide((xm - 0.058 * g, ym, zm + 0.020), (0.014, 0.030, 0.034), seg=18), GEMAS[5]))
for k, (o, mat) in enumerate(gemas):
    o.data.materials.append(mat)
    o.name = "gema_%d" % k
    partes.append((o, "codo_l"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.97), (0.190, 0.140, 0.095))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.098, r_rodilla=0.080, r_tobillo=0.070, hasta=0.30)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6500), "cadera"))
rodilleras = []
for lado in (-1, 1):
    rodilleras.append(kit.elipsoide((lado * 0.12, 0.060, 0.535), (0.068, 0.045, 0.075)))
partes.append((kit.fundir("rodilleras_oro", rodilleras, ORO, voxel=0.005, suavizado=4, caras=2500), "pies"))
botas = []
for lado in (-1, 1):
    x = lado * 0.12
    botas.append(kit.capsula((x, 0.0, 0.34), (x, 0.0, 0.10), 0.074, 0.072))
    botas += kit.zapato(lado, largo=0.135, ancho=0.074, alto=0.064)
partes.append((kit.fundir("botas", botas, BOTAS, voxel=0.006, suavizado=6, caras=4000), "pies"))

# -------------------------------------------------------------------- Skins
#
#   clasico   el de los comics: el casco dorado de titan, abierto en la cara, con las tres
#             crestas arriba y las aletas a los costados.
#   endgame   la armadura de batalla: el casco con la cresta del medio y la espada de dos
#             hojas en la mano.
#   infinito  ya es parte del universo: la capa larga, violeta, con las estrellas encima.
CASCO = kit.material("casco_titan", (0.95, 0.76, 0.26), metal=0.8, rugosidad=0.3)
ESPADA = kit.material("metal", (0.72, 0.74, 0.80), metal=0.85, rugosidad=0.25)
MANGO = kit.material("mango", (0.30, 0.24, 0.20))
CAPA = kit.material("capa", (0.30, 0.12, 0.55))
ESTRELLA = kit.material("neon_estrellas", (1.00, 0.95, 0.80))


def casco(extra=0.018):
    return kit.cabeza_humana((0, 0.0, 1.80), ancho=0.142 + extra, alto=0.180 + extra, fondo=0.155 + extra,
                             mandibula=1.18, nariz=1.0, orejas=False, menton=1.10)


def abierto_cara(x, y, z):
    return y > 0.04 and z < 1.885 and abs(x) < 0.118


partes.append((kit.cascara(kit.de_skin("casco_titan", "clasico"), casco(), CASCO,
                           lambda x, y, z: z > 1.66 and not abierto_cara(x, y, z), grosor=0.016, caras=6000), "cabeza"))
crestas = []
for dx in (-0.055, 0.0, 0.055):
    crestas += kit.tubo([(dx, 0.13, 1.92), (dx * 1.1, 0.02, 2.00), (dx * 1.1, -0.12, 1.96), (dx, -0.17, 1.84)],
                        [0.016, 0.022, 0.020, 0.012], seg=10)
for lado in (-1, 1):
    crestas.append(kit.cono((lado * 0.165, -0.02, 1.80), (lado * 0.235, -0.06, 1.90), 0.050, 0.006, seg=12))
partes.append((kit.fundir(kit.de_skin("casco_titan_crestas", "clasico"), crestas, CASCO, voxel=0.004, suavizado=2,
                          caras=3000), "cabeza"))
casco_e = kit.cascara(kit.de_skin("casco_titan", "endgame"), casco(0.022), CASCO,
                      lambda x, y, z: z > 1.64 and not abierto_cara(x, y, z), grosor=0.018, caras=6000)
partes.append((casco_e, "cabeza"))
cresta = kit.tubo([(0.0, 0.15, 1.90), (0.0, 0.08, 2.02), (0.0, -0.06, 2.05), (0.0, -0.18, 1.95)],
                  [0.014, 0.020, 0.020, 0.010], seg=10)
for lado in (-1, 1):
    cresta += kit.tubo([(lado * 0.12, 0.10, 1.70), (lado * 0.15, 0.13, 1.64), (lado * 0.13, 0.15, 1.60)],
                       [0.020, 0.016, 0.006], seg=10)
partes.append((kit.fundir(kit.de_skin("casco_titan_cresta", "endgame"), cresta, CASCO, voxel=0.004, suavizado=2,
                          caras=2500), "cabeza"))
xm, ym, zm = J["mano_r"]
hoja = [kit.capsula((xm, ym, zm + 0.20), (xm, ym, zm - 0.20), 0.020)]
for sgn in (1, -1):
    base = (xm, ym, zm + sgn * 0.20)
    hoja.append(kit.caja((xm, ym, zm + sgn * 0.48), (0.018, 0.080, 0.52)))
    hoja.append(kit.cono((xm, ym, zm + sgn * 0.74), (xm, ym, zm + sgn * 0.86), 0.050, 0.002, seg=4))
partes.append((kit.fundir(kit.de_skin("espada", "endgame"), hoja, ESPADA, voxel=0.004, suavizado=1, caras=3000), "codo_r"))
partes.append((kit.fundir(kit.de_skin("espada_mango", "endgame"),
                          [kit.capsula((xm, ym, zm + 0.19), (xm, ym, zm - 0.19), 0.024)], MANGO, voxel=0.004, suavizado=2,
                          caras=1200), "codo_r"))
capa = kit.capa("capa", ["infinito"], CAPA, z_abajo=0.22, abre=0.16, cuello=0.08, ancho=0.250, fondo=0.170)
partes.append((capa, "torso"))
import random
random.seed(41)
estrellas = []
for k in range(26):
    x = random.uniform(-0.30, 0.30)
    z = random.uniform(0.30, 1.40)
    q = kit.pegar(capa, (x, -0.6, z), 0.010)
    estrellas.append(kit.elipsoide(q, (0.010, 0.010, 0.010), seg=8))
partes.append((kit.pieza_fija(kit.de_skin("capa_estrellas", "infinito"), estrellas, ESTRELLA), "torso"))
# GRANJERO (Endgame): la armadura colgada de espantapajaros y el en su granja, con una camisa
# blanca de lona arremangada. Sin el Guantelete: el brazo izquierdo al aire, quemado por el
# chasquido.
CAMISA_LONA = kit.material("camisa", (0.88, 0.85, 0.78))
camisa = kit.perfil([(0.90, 0.206, 0.156), (1.05, 0.206, 0.156), (1.20, 0.224, 0.163), (1.34, 0.250, 0.172),
                     (1.46, 0.246, 0.164), (1.54, 0.188, 0.134)])
camisa += [kit.capsula((-0.20, 0.0, 1.48), (0.20, 0.0, 1.48), 0.100)]
for lado in (-1, 1):
    camisa.append(kit.elipsoide((lado * 0.100, 0.100, 1.375), (0.120, 0.066, 0.086)))
    camisa.append(kit.capsula((lado * 0.06, -0.02, 1.56), (lado * 0.21, 0.0, 1.50), 0.062, 0.072))
cam = kit.fundir(kit.de_skin("camisa", "granjero"), camisa, CAMISA_LONA, voxel=0.006, suavizado=8, caras=10000)
# El cuello abierto: se ve la piel.
kit.pintar(cam, PIEL, lambda x, y, z: y > 0.06 and z > 1.44 + abs(x) * 1.6)
partes.append((cam, "torso"))
mangas_lona = []
for lado in (-1, 1):
    sx = "_l" if lado < 0 else "_r"
    h, c = J["hombro" + sx], J["codo" + sx]
    mangas_lona += kit.tubo([h, (c[0], c[1], c[2] + 0.06)], [0.096, 0.090])
    mangas_lona.append(kit.capsula((c[0], c[1], c[2] + 0.10), (c[0], c[1], c[2] + 0.04), 0.096))
partes.append((kit.fundir(kit.de_skin("mangas_lona", "granjero"), mangas_lona, CAMISA_LONA, voxel=0.006, suavizado=6,
                          caras=3500), "brazos"))
brazo_l = kit.antebrazo(-1, r_codo=0.074, r_muneca=0.056, j=J) + kit.mano(-1, j=J, r=0.056)
partes.append((kit.fundir(kit.de_skin("brazo_l", "granjero"), brazo_l, PIEL, voxel=0.0055, suavizado=6, caras=4000),
               "manos"))
cicatrices = []
cl = J["codo_l"]
for k in range(5):
    z0 = cl[2] - 0.04 - k * 0.055
    a0 = k * 1.3
    cicatrices.append([(cl[0] + math.cos(a0 + t) * 0.064, cl[1] + math.sin(a0 + t) * 0.064, z0 - t * 0.02)
                       for t in (0.0, 0.5, 1.0, 1.5, 2.0)])
partes.append((kit.lineas(kit.de_skin("cicatrices", "granjero"), cicatrices, 0.0040, LINEAS), "manos"))
for obj, _r in partes:
    base = obj.name.split("__")[0]
    if base in ("armadura", "cintas", "cinto", "hebilla_oro", "hombrera_l", "hombrera_r", "lamina_l", "lamina_r",
                "mangas", "guantelete", "rodilleras_oro") or base.startswith("gema_"):
        kit.ocultar_en(obj, "granjero")

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla.startswith("hombro_"):
        kit.pesar(obj, arm, J, solo=regla)
kit.pesar_estandar([p for p in partes if not p[1].startswith("hombro_")], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.056, 1.818,
                         ojos_extra={"alto": 0.044, "ancho": 0.054, "iris": [0.30, 0.55, 0.95], "pestanas": False},
                         cejas={"alto": 0.026, "color": [0.42, 0.32, 0.46], "largo": 0.066},
                         boca_z=1.712, boca_extra={"ancho": 0.074, "dientes": False})
kit.exportar("thanos", arm, cara)
