"""Ryomen Sukuna, de Jujutsu Kaisen, en el cuerpo de Itadori.

El uniforme negro del colegio de hechiceria con la capucha roja colgando atras del cuello
y el boton en espiral; el pantalon oscuro. El pelo rosado corto peinado para atras, con
los costados rapados oscuros. LO QUE LO HACE SUKUNA: el segundo par de ojos, rojos y
rasgados, debajo de los ojos de siempre; las marcas negras en las mejillas y en la frente,
y las dos franjas negras tatuadas en cada muñeca. Los ojos, rojos.

Skins:
  carmesi  solo color (el uniforme rojo oscuro).
  kimono   en el cuerpo de Megumi: el kimono blanco con el obi negro, mangas anchas y el
           pelo negro en puntas.
  heian    su verdadera forma: cuatro brazos, una segunda cara en el costado derecho, el
           kimono abierto y una boca en el vientre. El pelo rosado mas largo.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.93, 0.80, 0.70))
PELO = kit.material("pelo", (0.95, 0.60, 0.62), rugosidad=0.5)
RAPADO = kit.material("rapado", (0.20, 0.13, 0.13), rugosidad=0.8)
TATUAJES = kit.material("tatuajes", (0.05, 0.03, 0.04))
OJOS2 = kit.material("ojos2", (0.72, 0.05, 0.08))
UNIFORME = kit.material("uniforme~cuerpo", (0.09, 0.10, 0.14))
CAPUCHA = kit.material("capucha~acento", (0.82, 0.10, 0.14))
BOTON = kit.material("boton", (0.78, 0.64, 0.30), metal=0.7)
PANTALON = kit.material("pantalon~pantalon", (0.08, 0.08, 0.10))
ZAPATOS = kit.material("zapatos~zapatos", (0.10, 0.09, 0.10), rugosidad=0.35)

KIMONO_SKINS = ("kimono", "heian")
partes = []


def craneo(extra=0.0):
    c = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.140 + extra, alto=0.178 + extra, fondo=0.152 + extra,
                          mandibula=0.92, nariz=0.95, menton=1.0, orejas=extra == 0.0)
    if extra == 0.0:
        c.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.054))
    return c


cabeza = kit.fundir("cabeza", craneo(), PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))
# HEIAN: la misma cabeza con la segunda cara crecida en el costado derecho, de una pieza
# (pegada como pieza aparte, el contorno la hacia ver como un par de anteojos).
cab_h = craneo() + [kit.elipsoide((0.088, 0.105, 1.800), (0.050, 0.034, 0.072), rot=(0, 0, -28))]
cabeza_heian = kit.fundir(kit.de_skin("cabeza_heian", "heian"), cab_h, PIEL, voxel=0.006, suavizado=10, caras=9500)
partes.append((cabeza_heian, "cabeza"))
kit.ocultar_en(cabeza, "heian")


# ------------------------------------------------------------------- El pelo
def pelo_itadori():
    """Corto, en puntas, peinado para atras: cuando Sukuna toma el cuerpo se lo tira hacia
    atras con la mano. Solo arriba: los costados van rapados."""
    import random
    random.seed(41)
    piezas = [kit.elipsoide((0, -0.030, 1.920), (0.130, 0.146, 0.074)),
              kit.elipsoide((0, -0.060, 1.895), (0.124, 0.136, 0.070))]
    for k in range(18):
        x = random.uniform(-0.10, 0.10)
        y0 = random.uniform(-0.06, 0.12)
        base = (x, y0, 1.92 + random.uniform(-0.01, 0.02))
        punta = (x * 1.25, y0 - random.uniform(0.10, 0.16), base[2] + random.uniform(0.03, 0.07))
        piezas += kit.tubo([base, ((base[0] + punta[0]) / 2, (base[1] + punta[1]) / 2, base[2] + 0.03), punta],
                           [0.040, 0.028, 0.005])
    return piezas


pelo = kit.fundir("pelo", pelo_itadori(), PELO, voxel=0.0055, suavizado=4, caras=9000)
kit.ocultar_en(pelo, *KIMONO_SKINS)
partes.append((pelo, "cabeza"))
rapado = kit.cascara("rapado", craneo(0.004), RAPADO,
                     lambda x, y, z: 1.76 < z < 1.90 and y < 0.02 and not (abs(x) > 0.12 and z < 1.84 and y > -0.05),
                     grosor=0.006, voxel=0.005, caras=6000)
kit.ocultar_en(rapado, "kimono")
partes.append((rapado, "cabeza"))


# --------------------------------------------------- Las marcas de la cara
def sobre(obj, x, z, afuera=0.003):
    p, n = kit.superficie(obj, x, z)
    if p is None:
        return None
    return tuple(p + n * afuera)


marcas = []
ojos2 = []
for lado in (-1, 1):
    # El segundo ojo, debajo del de siempre: rasgado, rojo, con el parpado negro.
    c = sobre(cabeza, lado * 0.056, 1.778, 0.002)
    p, n = kit.superficie(cabeza, lado * 0.056, 1.778)
    e = [kit.elipsoide(c, (0.020, 0.004, 0.0065), rot=(0, lado * -8, 0))]
    kit.orientar(e, c, n)
    ojos2 += e
    marcas.append([sobre(cabeza, lado * (0.056 + dx), 1.778 + 0.006 * (1 - (dx / 0.024) ** 2), 0.004)
                   for dx in (-0.024, -0.012, 0.0, 0.012, 0.024)])
    # La raya de la mejilla, hacia la oreja.
    marcas.append([sobre(cabeza, lado * x, 1.752 - (x - 0.05) * 0.10, 0.003) for x in (0.050, 0.075, 0.100, 0.118)])
    # Las de la frente, cortas y curvas, sobre las cejas.
    marcas.append([sobre(cabeza, lado * x, 1.868 + (x - 0.03) * 0.25, 0.003) for x in (0.020, 0.040, 0.060)])
marcas = [[p for p in m if p is not None] for m in marcas]
partes.append((kit.lineas("tatuajes_cara", marcas, 0.0028, TATUAJES), "cabeza"))
partes.append((kit.fundir("ojos2", ojos2, OJOS2, voxel=0.0015, suavizado=1, caras=1500), "cabeza"))

# -------------------------------------------------------------------- Torso
PERFIL = [(0.86, 0.172, 0.126), (0.95, 0.165, 0.120), (1.05, 0.160, 0.116), (1.20, 0.174, 0.124),
          (1.36, 0.196, 0.130), (1.46, 0.192, 0.124), (1.53, 0.146, 0.104)]


def torso_p(extra=0.0, cuello=True):
    t = kit.perfil([(z, a + extra, f + extra) for z, a, f in PERFIL])
    t.append(kit.capsula((-0.168, 0.0, 1.47), (0.168, 0.0, 1.47), 0.074 + extra))
    if cuello:
        t.append(kit.capsula((0, -0.010, 1.50), (0, -0.004, 1.600), 0.086, 0.092))
    return t


uni = kit.fundir("uniforme", torso_p(), UNIFORME, voxel=0.006, suavizado=8, caras=10000)
kit.ocultar_en(uni, *KIMONO_SKINS)
partes.append((uni, "torso"))
# El boton en espiral, como el de todos los del colegio.
p, n = kit.superficie(uni, -0.045, 1.560)
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
bt = kit.fundir("boton", disco + espiral, BOTON, voxel=0.0018, suavizado=1, caras=2500)
kit.ocultar_en(bt, *KIMONO_SKINS)
partes.append((bt, "torso"))
# LA CAPUCHA ROJA de la campera de abajo, colgando atras del cuello alto.
capucha = [kit.elipsoide((0, -0.118, 1.555), (0.135, 0.070, 0.092)),
           kit.elipsoide((0, -0.096, 1.505), (0.150, 0.060, 0.052)),
           kit.elipsoide((0, -0.140, 1.470), (0.092, 0.040, 0.060))]
cp = kit.fundir("capucha", capucha, CAPUCHA, voxel=0.006, suavizado=6, caras=4000)
kit.ocultar_en(cp, *KIMONO_SKINS)
partes.append((cp, "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.066, r_codo=0.060, r_muneca=0.056, hasta=0.900)
mg = kit.fundir("mangas", mangas, UNIFORME, voxel=0.006, suavizado=6, caras=4500)
kit.ocultar_en(mg, *KIMONO_SKINS)
partes.append((mg, "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.046)
    s = "_l" if lado < 0 else "_r"
    x, y, z = J["mano" + s]
    manos.append(kit.capsula((x, y, z + 0.02), (x, y, z + 0.085), 0.046 * kit.FACTOR_BRAZO, 0.050 * kit.FACTOR_BRAZO))
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4500), "manos"))


# LAS DOS FRANJAS de cada muñeca.
def franjas(x, y, zs, r):
    out = []
    for z in zs:
        out.append([(x + math.cos(a) * r, y + math.sin(a) * r, z) for a in [2 * math.pi * k / 20 for k in range(21)]])
    return out


tat = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    x, y, z = J["mano" + s]
    tat += franjas(x, y, (z + 0.050, z + 0.068), 0.050 * kit.FACTOR_BRAZO + 0.002)
partes.append((kit.lineas("tatuajes_munecas", tat, 0.0035, TATUAJES), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.92), (0.150, 0.108, 0.080))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.088, r_rodilla=0.080, r_tobillo=0.074, hasta=0.13)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, largo=0.122, ancho=0.064, alto=0.058, punta=0.95)
partes.append((kit.fundir("zapatos", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=3500), "pies"))

# ======================================================================== Skins
KIMONO = kit.material("kimono~cuerpo", (0.95, 0.94, 0.90))
OBI = kit.material("obi", (0.06, 0.06, 0.08))
BOCA = kit.material("boca_vientre", (0.30, 0.03, 0.05))
DIENTES = kit.material("dientes", (0.96, 0.94, 0.88))

# --- El kimono: cruzado en V adelante; en Heian, abierto hasta el obi ---
K_PERFIL = [(0.84, 0.182, 0.136), (0.95, 0.176, 0.130), (1.05, 0.170, 0.126), (1.20, 0.180, 0.130),
            (1.36, 0.200, 0.136), (1.46, 0.196, 0.130), (1.53, 0.152, 0.110)]


def kimono_cuerpo():
    t = kit.perfil(K_PERFIL)
    t.append(kit.capsula((-0.172, 0.0, 1.47), (0.172, 0.0, 1.47), 0.078))
    return t


def escote(x, y, z, hasta):
    return y > 0.03 and z > hasta and abs(x) < (z - hasta) * 0.40 + 0.010


partes.append((kit.cascara(kit.de_skin("kimono", "kimono"), kimono_cuerpo(), KIMONO,
                           lambda x, y, z: z < 1.575 and not escote(x, y, z, 1.30), grosor=0.012, caras=9000), "torso"))
partes.append((kit.cascara(kit.de_skin("kimono_heian", "heian"), kimono_cuerpo(), KIMONO,
                           lambda x, y, z: z < 1.575 and not (y > 0.02 and z > 1.02 and abs(x) < 0.095 + (z - 1.02) * 0.10),
                           grosor=0.012, caras=9000), "torso"))
# Abajo, en el kimono y en Heian: el pecho y el vientre.
pecho = kit.fundir(kit.de_skin("pecho", *KIMONO_SKINS), torso_p(-0.004, False), PIEL, voxel=0.006, suavizado=8,
                   caras=7000)
partes.append((pecho, "torso"))
obi = kit.perfil([(0.96, 0.186, 0.140), (1.08, 0.182, 0.136)])
partes.append((kit.fundir(kit.de_skin("obi", *KIMONO_SKINS), obi, OBI, voxel=0.005, suavizado=4, caras=4000), "torso"))
# Las mangas anchas que cuelgan.
mk = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h, c = J["hombro" + s], J["codo" + s]
    mk += kit.tubo([h, c, (c[0] + lado * 0.01, c[1], c[2] - 0.13)], [0.078 * kit.FACTOR_BRAZO, 0.092 * kit.FACTOR_BRAZO,
                                                                      0.105 * kit.FACTOR_BRAZO])
    mk.append(kit.elipsoide((c[0] + lado * 0.01, c[1] - 0.02, c[2] - 0.10), (0.090, 0.110, 0.080)))
    mk += kit.antebrazo(lado, 0.058, 0.050, hasta=0.900)
partes.append((kit.fundir(kit.de_skin("mangas_kimono", *KIMONO_SKINS), mk, KIMONO, voxel=0.006, suavizado=6, caras=5500),
               "brazos"))


# --- El pelo de Megumi: negro, en puntas para todos lados ---
def pelo_megumi():
    import random
    random.seed(9)
    piezas = [kit.elipsoide((0, -0.020, 1.890), (0.150, 0.162, 0.115)),
              kit.elipsoide((0, -0.070, 1.810), (0.145, 0.115, 0.100))]
    for k in range(30):
        a = random.uniform(-math.pi * 0.85, math.pi * 0.85)
        el = random.uniform(0.15, 1.0)
        dx, dy = math.sin(a), math.cos(a)
        base = (dx * 0.10 * el, dy * 0.10 * el - 0.03, 1.90 + 0.04 * (1 - el))
        punta = (dx * (0.10 + random.uniform(0.07, 0.13)), dy * (0.08 + random.uniform(0.04, 0.10)) - 0.05,
                 base[2] + random.uniform(0.03, 0.12))
        piezas += kit.tubo([base, punta], [random.uniform(0.040, 0.055), 0.005])
    return piezas


partes.append((kit.fundir(kit.de_skin("pelo_megumi", "kimono"), pelo_megumi(), PELO, voxel=0.0058, suavizado=4,
                          caras=10000), "cabeza"))


# --- HEIAN: el pelo rosado mas largo y salvaje, los otros dos brazos, la segunda cara y la
# boca del vientre ---
def pelo_heian():
    import random
    random.seed(77)
    piezas = [kit.elipsoide((0, -0.030, 1.895), (0.150, 0.160, 0.110)),
              kit.elipsoide((0, -0.090, 1.800), (0.150, 0.110, 0.115))]
    for k in range(26):
        x = random.uniform(-0.12, 0.12)
        y0 = random.uniform(-0.08, 0.12)
        base = (x, y0, 1.91 + random.uniform(-0.01, 0.03))
        punta = (x * 1.45, y0 - random.uniform(0.16, 0.26), base[2] + random.uniform(-0.02, 0.08))
        piezas += kit.tubo([base, ((base[0] + punta[0]) / 2, (base[1] + punta[1]) / 2, base[2] + 0.04), punta],
                           [0.046, 0.032, 0.005])
    return piezas


partes.append((kit.fundir(kit.de_skin("pelo_heian", "heian"), pelo_heian(), PELO, voxel=0.0058, suavizado=4,
                          caras=10000), "cabeza"))
# Los otros dos brazos: salen de los costados, abajo de los de siempre, y miran adelante.
extra = []
for lado in (-1, 1):
    h2 = (lado * 0.200, 0.010, 1.260)
    c2 = (lado * 0.390, 0.110, 1.110)
    m2 = (lado * 0.430, 0.250, 1.060)
    f = kit.FACTOR_BRAZO
    extra += kit.tubo([h2, c2, m2], [0.056 * f, 0.050 * f, 0.044 * f])
    extra.append(kit.elipsoide((h2[0] + lado * 0.02, h2[1], h2[2] - 0.01), (0.060, 0.058, 0.070)))
    j2 = dict(J)
    j2["mano_l" if lado < 0 else "mano_r"] = (m2[0], m2[1] + 0.03, m2[2] - 0.02)
    mano2 = kit.mano(lado, j=j2, r=0.044)
    kit.girar(mano2, (m2[0], m2[1] + 0.03, m2[2] - 0.02), (-70, 0, 0))
    extra += mano2
partes.append((kit.fundir(kit.de_skin("brazos_extra", "heian"), extra, PIEL, voxel=0.005, suavizado=5, caras=7000),
               "torso"))
tat_extra = []
for lado in (-1, 1):
    for t in (0.70, 0.78):
        cx, cy, cz = lado * (0.390 + 0.040 * t), 0.110 + 0.140 * t, 1.110 - 0.050 * t
        tat_extra.append([(cx + math.cos(a) * 0.050, cy, cz + math.sin(a) * 0.050)
                          for a in [2 * math.pi * k / 20 for k in range(21)]])
partes.append((kit.lineas(kit.de_skin("tat_extra", "heian"), tat_extra, 0.0035, TATUAJES), "torso"))
# LA SEGUNDA CARA: sus dos ojos rasgados y el borde marcado, como una mascara.
ojos_m = []
for dz in (0.035, 0.000):
    q = sobre(cabeza_heian, 0.100, 1.800 + dz, 0.002)
    p, n = kit.superficie(cabeza_heian, 0.100, 1.800 + dz)
    e = [kit.elipsoide(q, (0.016, 0.005, 0.006))]
    kit.orientar(e, q, n)
    ojos_m += e
borde = [[q for q in (sobre(cabeza_heian, 0.088 + math.cos(a) * 0.040, 1.800 + math.sin(a) * 0.066, 0.003)
                      for a in [2 * math.pi * k / 24 for k in range(25)]) if q is not None]]
partes.append((kit.lineas(kit.de_skin("tat_cara2", "heian"), borde, 0.0026, TATUAJES), "cabeza"))
partes.append((kit.fundir(kit.de_skin("ojos_cara2", "heian"), ojos_m, OJOS2, voxel=0.0015, suavizado=1, caras=1200),
               "cabeza"))
# LA BOCA DEL VIENTRE, con los dientes.
pb = sobre(pecho, 0.0, 1.12, 0.004)
pbn = kit.superficie(pecho, 0.0, 1.12)[1]
boca = [kit.elipsoide(pb, (0.060, 0.014, 0.022))]
kit.orientar(boca, pb, pbn)
partes.append((kit.fundir(kit.de_skin("boca_vientre", "heian"), boca, BOCA, voxel=0.002, suavizado=2, caras=1500), "torso"))
dientes = []
for k in range(7):
    x = -0.042 + k * 0.014
    for arriba in (1, -1):
        base = (pb[0] + x, pb[1] + 0.012, pb[2] + arriba * 0.014)
        dientes.append(kit.cono(base, (base[0], base[1] + 0.002, base[2] - arriba * 0.012), 0.005))
partes.append((kit.fundir(kit.de_skin("dientes_vientre", "heian"), dientes, DIENTES, voxel=0.0015, suavizado=1,
                          caras=1500), "torso"))
# Las marcas del pecho: dos rayas que bajan por cada lado.
tp = []
for lado in (-1, 1):
    tp.append([q for q in (sobre(pecho, lado * x, z, 0.003) for x, z in ((0.06, 1.38), (0.08, 1.30), (0.085, 1.22)))
               if q is not None])
partes.append((kit.lineas(kit.de_skin("tat_pecho", "heian"), tp, 0.0035, TATUAJES), "torso"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.055, 1.815,
                         ojos_extra={"alto": 0.052, "ancho": 0.054, "iris": [0.85, 0.10, 0.12], "pestanas": False},
                         cejas={"alto": 0.030, "color": [0.30, 0.15, 0.15], "largo": 0.050},
                         boca_z=1.700, boca_extra={"ancho": 0.058, "dientes": True})
kit.exportar("sukuna", arm, cara)
