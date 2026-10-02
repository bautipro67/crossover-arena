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
# Rick es flaco y largo: los brazos se quedan finos, adentro de las mangas del guardapolvo.
kit.FACTOR_BRAZO = 1.0
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
# EL GUARDAPOLVO, una tela con espesor: del torso inflado y, de la cintura para abajo, un
# faldon que se abre hasta las rodillas. Abierto adelante, donde se ve la camisa; el de
# arriba va con el torso y el faldon con las piernas, como una pollera.
# Un solo perfil RECTO, de los hombros a las rodillas: es un guardapolvo, no un vestido.
def perfil_gp():
    t = kit.perfil([(0.62, 0.222, 0.160), (0.80, 0.214, 0.154), (0.98, 0.196, 0.144), (1.15, 0.186, 0.138),
                    (1.32, 0.192, 0.140), (1.46, 0.190, 0.136), (1.56, 0.150, 0.118)])
    t.append(kit.capsula((-0.150, 0.0, 1.47), (0.150, 0.0, 1.47), 0.082))
    return t


def abierto(x, y, z):
    # Abierto adelante en una V larga: se ve la camisa hasta el cinto.
    return y > 0.0 and abs(x) < 0.070 + max(0.0, z - 1.0) * 0.06


partes.append((kit.cascara("guardapolvo__sin_pepino", perfil_gp(), GUARDAPOLVO,
                           lambda x, y, z: 0.98 < z < 1.58 and not abierto(x, y, z), grosor=0.014, caras=7000), "torso"))
partes.append((kit.cascara("faldon__sin_pepino", perfil_gp(), GUARDAPOLVO,
                           lambda x, y, z: 0.64 < z <= 1.00 and not abierto(x, y, z), grosor=0.014, caras=5000), "cadera"))
# Las solapas, dobladas hacia afuera sobre el pecho.
solapas = []
for lado in (-1, 1):
    pts = [kit.pegar(kit.bpy.data.objects["guardapolvo__sin_pepino"], (lado * (0.085 + t * 0.03), 0.3, 1.52 - t * 0.20), 0.008)
           for t in (0.0, 0.5, 1.0)]
    solapas += kit.tubo(pts, [0.020, 0.024, 0.012], seg=10)
partes.append((kit.fundir("solapas__sin_pepino", solapas, GUARDAPOLVO, voxel=0.0045, suavizado=3, caras=2000), "torso"))

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

# -------------------------------------------------------------------- Skins
#
#   pickle   PICKLE RICK con la armadura de ratas que se arma en el capitulo: brazos y
#            piernas de pedazos de rata atados, con las colas colgando y el arnes al pecho.
#   maligno  el parche en el ojo.     bata / toxico  las antiparras de laboratorio en la
#            frente; el Toxico, ademas, chorreando baba verde.
#   gala     el moño.                 cosmico  demasiados portales: la pistola de portales.
RATA = kit.material("armadura", (0.45, 0.40, 0.36))
COLA = kit.material("cola_rata", (0.80, 0.62, 0.60))
CUERO = kit.material("arnes", (0.24, 0.18, 0.13))
PARCHE = kit.material("parche", (0.08, 0.08, 0.09))
GAFAS = kit.material("gafas", (0.35, 0.38, 0.42), metal=0.4)
VIDRIO = kit.material("neon_vidrio", (0.70, 0.95, 1.00))
BABA = kit.material("baba", (0.55, 0.95, 0.25))
MONO = kit.material("mono", (0.60, 0.10, 0.15))
PISTOLA = kit.material("pistola", (0.85, 0.86, 0.88), metal=0.5)
PORTAL = kit.material("neon_portal", (0.45, 1.00, 0.35))

# PICKLE: la armadura de ratas. Los brazos y las piernas son tramos atados; cada tramo, una
# rata hecha bollo, y entre tramo y tramo una vuelta de cuero.
ratas, colas, arnes = [], [], []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h, c, m = J["hombro" + s], J["codo" + s], J["mano" + s]
    for a, b in ((h, c), (c, m)):
        for t in (0.25, 0.75):
            q = kit._entre(a, b, t)
            ratas.append(kit.elipsoide(q, (0.056, 0.060, 0.085), seg=18))
            colas += kit.tubo([(q[0] + lado * 0.04, q[1] - 0.04, q[2]), (q[0] + lado * 0.08, q[1] - 0.06, q[2] - 0.08),
                               (q[0] + lado * 0.07, q[1] - 0.04, q[2] - 0.16)], [0.010, 0.007, 0.003], seg=8)
        arnes.append(kit.capsula((b[0], b[1], b[2] + 0.02), (b[0], b[1], b[2] - 0.02), 0.064))
    # Las garras, en la punta del brazo.
    for k in range(3):
        ratas.append(kit.cono((m[0], m[1] + (k - 1) * 0.022, m[2] - 0.05), (m[0] + lado * 0.01, m[1] + (k - 1) * 0.03, m[2] - 0.12),
                              0.014, 0.002, seg=8))
    p, r, f = J["pierna" + s], J["rodilla" + s], J["pie" + s]
    for a, b in ((p, r), (r, f)):
        for t in (0.3, 0.75):
            q = kit._entre(a, b, t)
            ratas.append(kit.elipsoide(q, (0.064, 0.068, 0.095), seg=18))
        arnes.append(kit.capsula((b[0], b[1], b[2] + 0.02), (b[0], b[1], b[2] - 0.02), 0.070))
    ratas.append(kit.elipsoide((f[0], 0.04, 0.05), (0.070, 0.110, 0.045)))
for z in (1.10, 1.45):
    arnes.append(kit.capsula((-0.21, 0.0, z), (0.21, 0.0, z), 0.020))
arnes += kit.tubo([(-0.17, 0.17, 1.47), (0.17, 0.16, 1.08)], [0.018, 0.018])
partes.append((kit.fundir(kit.de_skin("armadura", "pickle"), ratas, RATA, voxel=0.006, suavizado=4, caras=8000),
               "por_distancia"))
partes.append((kit.fundir(kit.de_skin("colas", "pickle"), colas, COLA, voxel=0.003, suavizado=2, caras=3000), "por_distancia"))
partes.append((kit.fundir(kit.de_skin("arnes", "pickle"), arnes, CUERO, voxel=0.005, suavizado=3, caras=4000), "por_distancia"))
# MALIGNO: el parche en el ojo izquierdo, con la tira por la cabeza.
p, n = kit.superficie(cabeza, -0.052, 1.825)
c = tuple(p + n * 0.006)
parche = [kit.elipsoide(c, (0.038, 0.010, 0.032), seg=20)]
kit.orientar(parche, c, n)
for k in range(28):
    a, b = 2 * math.pi * k / 28, 2 * math.pi * (k + 1) / 28
    parche.append(kit.capsula((math.sin(a) * 0.146, math.cos(a) * 0.158 - 0.005, 1.835 + math.cos(a) * 0.03),
                              (math.sin(b) * 0.146, math.cos(b) * 0.158 - 0.005, 1.835 + math.cos(b) * 0.03), 0.005, seg=6))
partes.append((kit.fundir(kit.de_skin("parche", "maligno"), parche, PARCHE, voxel=0.0035, suavizado=2, caras=2500),
               "cabeza"))
# BATA / TOXICO: las antiparras levantadas en la frente.
gafas, vidrios = [], []
for lado in (-1, 1):
    p, n = kit.superficie(cabeza, lado * 0.050, 1.905)
    c = tuple(p + n * 0.016)
    aro = [kit.capsula((c[0], c[1] - 0.010, c[2]), (c[0], c[1] + 0.012, c[2]), 0.032, 0.030, seg=20)]
    kit.orientar(aro, c, n)
    gafas += aro
    v = [kit.elipsoide((c[0], c[1] + 0.014, c[2]), (0.026, 0.006, 0.026), seg=16)]
    kit.orientar(v, c, n)
    vidrios += v
for k in range(28):
    a, b = 2 * math.pi * k / 28, 2 * math.pi * (k + 1) / 28
    gafas.append(kit.capsula((math.sin(a) * 0.150, math.cos(a) * 0.160 - 0.010, 1.905),
                             (math.sin(b) * 0.150, math.cos(b) * 0.160 - 0.010, 1.905), 0.008, seg=6))
partes.append((kit.fundir(kit.de_skin("gafas", "bata", "toxico"), gafas, GAFAS, voxel=0.0035, suavizado=2, caras=3000),
               "cabeza"))
partes.append((kit.pieza_fija(kit.de_skin("gafas_vidrio", "bata", "toxico"), vidrios, VIDRIO), "cabeza"))
# La baba del Toxico: gotas que chorrean de los hombros y del guardapolvo.
random.seed(23)
gp_o = [o for o, _r in partes if o.name.startswith("guardapolvo")][0]
baba = []
for k in range(16):
    x = random.uniform(-0.20, 0.20)
    z = random.uniform(1.05, 1.52)
    q = kit.pegar(gp_o, (x, 0.4 if k % 2 else -0.4, z), 0.004)
    largo = random.uniform(0.04, 0.10)
    baba += kit.tubo([q, (q[0], q[1], q[2] - largo * 0.6), (q[0], q[1], q[2] - largo)], [0.012, 0.009, 0.014], seg=8)
partes.append((kit.fundir(kit.de_skin("baba", "toxico"), baba, BABA, voxel=0.003, suavizado=2, caras=3000), "torso"))
# GALA: el moño debajo del cuello.
mono = [kit.elipsoide((-0.030, 0.112, 1.545), (0.030, 0.014, 0.020), rot=(0, 0, 12)),
        kit.elipsoide((0.030, 0.112, 1.545), (0.030, 0.014, 0.020), rot=(0, 0, -12)),
        kit.elipsoide((0.0, 0.118, 1.545), (0.010, 0.012, 0.012))]
partes.append((kit.fundir(kit.de_skin("mono", "gala"), mono, MONO, voxel=0.003, suavizado=2, caras=1500), "torso"))
# COSMICO: la pistola de portales en la mano derecha, con la carga verde.
xm, ym, zm = J["mano_r"]
pist = [kit.caja((xm + 0.005, ym + 0.060, zm - 0.010), (0.040, 0.120, 0.050)),
        kit.capsula((xm + 0.005, ym + 0.120, zm - 0.010), (xm + 0.005, ym + 0.160, zm - 0.010), 0.020),
        kit.caja((xm + 0.005, ym + 0.020, zm - 0.050), (0.030, 0.035, 0.060))]
partes.append((kit.fundir(kit.de_skin("pistola", "cosmico"), pist, PISTOLA, voxel=0.004, suavizado=2, caras=2000), "codo_r"))
partes.append((kit.fundir(kit.de_skin("pistola_carga", "cosmico"),
                          [kit.capsula((xm + 0.005, ym + 0.030, zm + 0.022), (xm + 0.005, ym + 0.090, zm + 0.022), 0.016)],
                          PORTAL, voxel=0.003, suavizado=2, caras=800), "codo_r"))

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla == "por_distancia":
        kit.pesar(obj, arm, J)
kit.pesar_estandar([p for p in partes if p[1] != "por_distancia"], arm, J)
# La cara del pepino: sobre el pepinillo, no sobre la cabeza (escondida adentro).
pep_ojos = {}
for lado, clave in ((-1, "l"), (1, "r")):
    p, n = kit.superficie(pp, lado * 0.058, 1.800)
    pep_ojos[clave] = kit.a_juego(tuple(p + n * 0.003), J)
p, n = kit.superficie(pp, 0.0, 1.700)
pep_boca = kit.a_juego(tuple(p + n * 0.003), J)
cara = kit.cara_estandar(cabeza, J, 0.052, 1.825,
                         ojos_extra={"alto": 0.062, "ancho": 0.055, "iris": [0.1, 0.1, 0.1], "estilo": "simple"},
                         cejas={"alto": 0.040, "color": [0.55, 0.70, 0.78], "largo": 0.088},
                         boca_z=1.695, boca_extra={"ancho": 0.070, "dientes": False})
cara["ojos"]["formas"] = {"pepino": {"l": pep_ojos["l"], "r": pep_ojos["r"], "alto": 0.075, "ancho": 0.066}}
cara["boca"]["formas"] = {"pepino": {"pos": pep_boca, "ancho": 0.090}}
kit.exportar("rick", arm, cara)
