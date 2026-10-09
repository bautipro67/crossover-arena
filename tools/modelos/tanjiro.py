"""Tanjiro Kamado, de Demon Slayer.

El uniforme negro de los cazadores con el cinturon blanco; ENCIMA, el haori a cuadros verde
y negro, abierto adelante y hasta la mitad del muslo; el pantalon negro ancho, las vendas
blancas de la canilla y las sandalias. El pelo bordo, corto, en puntas y peinado para
atras con la frente al aire; la cicatriz en el lado izquierdo de la frente; los aros
hanafuda (una tablita blanca con el sol rojo). La katana negra en la mano derecha.

Skins:
  kimono   solo color (el kimono de cuando vendia carbon).
  kitsune  la mascara de zorro de Sakonji, a un costado de la cabeza.
  marca    la Marca del Cazador crecida (la llama roja en toda la frente) y la hoja roja.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.96, 0.83, 0.70))
PELO = kit.material("pelo", (0.42, 0.10, 0.10), rugosidad=0.5)
CICATRIZ = kit.material("cicatriz", (0.62, 0.16, 0.14))
ARO = kit.material("aros", (0.96, 0.95, 0.90))
SOL = kit.material("aros_sol", (0.85, 0.15, 0.12))
UNIFORME = kit.material("uniforme~cuerpo", (0.09, 0.10, 0.13))
BOTONES = kit.material("botones", (0.85, 0.78, 0.45), metal=0.5)
CINTURON = kit.material("cinturon", (0.94, 0.94, 0.92))
HAORI_A = kit.material("haori_a~acento", (0.14, 0.46, 0.34))
HAORI_B = kit.material("haori_b", (0.06, 0.06, 0.07))
PANTALON = kit.material("pantalon~pantalon", (0.09, 0.10, 0.13))
VENDAS = kit.material("vendas", (0.93, 0.93, 0.90))
SANDALIAS = kit.material("zapatos~propio", (0.62, 0.52, 0.38))
HOJA = kit.material("hoja", (0.10, 0.10, 0.12), metal=0.7, rugosidad=0.25)
TSUBA = kit.material("tsuba", (0.20, 0.20, 0.22), metal=0.6)
MANGO = kit.material("mango", (0.12, 0.10, 0.10))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.138, alto=0.176, fondo=0.150, mandibula=0.88, nariz=0.9, menton=0.95)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.052))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))


def pelo():
    """Corto y en PUNTAS que se abren para todos lados, peinado para atras desde la frente;
    la frente al aire. Lo que se reconoce de lejos son las puntas, no un casquete liso."""
    import random
    random.seed(5)
    piezas = [kit.elipsoide((0, -0.040, 1.880), (0.142, 0.150, 0.100)),
              kit.elipsoide((0, -0.090, 1.800), (0.140, 0.110, 0.105))]
    # Las de arriba y los costados: gruesas en la base, largas, abiertas hacia atras.
    for k in range(34):
        a = random.uniform(-2.9, 2.9)
        el = random.uniform(0.2, 1.0)
        dx, dy = math.sin(a), math.cos(a)
        base = (dx * 0.10 * el, dy * 0.09 * el - 0.04, 1.90 + 0.04 * (1.0 - el))
        largo = random.uniform(0.10, 0.17)
        punta = (dx * (0.10 * el + largo * 0.9), dy * (0.09 * el) - 0.06 - largo * 0.5, base[2] + largo * 0.45)
        piezas += kit.tubo([base, punta], [random.uniform(0.046, 0.062), 0.006])
    # Las del flequillo: nacen en la frente y suben para atras.
    for dx in (-0.08, -0.03, 0.02, 0.07):
        piezas += kit.tubo([(dx, 0.10, 1.92), (dx * 1.2, 0.06, 2.00), (dx * 1.4, -0.02, 2.04)], [0.040, 0.030, 0.006])
    # Los mechones de la nuca y la colita atada.
    for k in range(6):
        x = -0.10 + k * 0.04
        piezas += kit.tubo([(x, -0.14, 1.82), (x * 1.1, -0.20, 1.69)], [0.042, 0.008])
    return piezas


partes.append((kit.fundir("pelo", pelo(), PELO, voxel=0.0056, suavizado=4, caras=9000), "cabeza"))


def sobre(obj, x, z, afuera=0.003):
    p, n = kit.superficie(obj, x, z)
    if p is None:
        return None
    return tuple(p + n * afuera)


# La cicatriz: una mancha chica en el lado izquierdo de la frente (el izquierdo es -X).
c = sobre(cabeza, -0.055, 1.885, 0.002)
p, n = kit.superficie(cabeza, -0.055, 1.885)
cic = [kit.elipsoide(c, (0.026, 0.004, 0.016), rot=(0, 20, 0))]
kit.orientar(cic, c, n)
cicatriz = kit.fundir("cicatriz", cic, CICATRIZ, voxel=0.0015, suavizado=1, caras=800)
kit.ocultar_en(cicatriz, "marca")
partes.append((cicatriz, "cabeza"))
# Los aros hanafuda colgando de las orejas.
aros, soles = [], []
for lado in (-1, 1):
    x = lado * 0.152
    aros.append(kit.caja((x, -0.005, 1.700), (0.006, 0.030, 0.062)))
    aros.append(kit.capsula((x, -0.005, 1.745), (x, -0.005, 1.735), 0.004))
    soles.append(kit.elipsoide((x + lado * 0.004, -0.005, 1.712), (0.003, 0.012, 0.012)))
partes.append((kit.fundir("aros", aros, ARO, voxel=0.0015, suavizado=1, caras=1200), "cabeza"))
partes.append((kit.fundir("aros_sol", soles, SOL, voxel=0.0012, suavizado=1, caras=600), "cabeza"))

# -------------------------------------------------------------------- Torso
PERFIL = [(0.86, 0.168, 0.124), (0.95, 0.162, 0.120), (1.05, 0.158, 0.116), (1.20, 0.170, 0.122),
          (1.36, 0.190, 0.128), (1.46, 0.188, 0.122), (1.53, 0.144, 0.102)]


def cuerpo(extra=0.0):
    t = kit.perfil([(z, a + extra, f + extra) for z, a, f in PERFIL])
    t.append(kit.capsula((-0.165, 0.0, 1.47), (0.165, 0.0, 1.47), 0.072 + extra))
    t.append(kit.capsula((0, -0.008, 1.50), (0, -0.004, 1.585), 0.078 + extra, 0.082 + extra))
    return t


uni = kit.fundir("uniforme", cuerpo(), UNIFORME, voxel=0.006, suavizado=8, caras=9000)
partes.append((uni, "torso"))
botones = []
for k in range(5):
    q = sobre(uni, 0.0, 1.52 - k * 0.075, 0.006)
    if q is not None:
        botones.append(kit.elipsoide(q, (0.011, 0.008, 0.011)))
partes.append((kit.fundir("botones", botones, BOTONES, voxel=0.0018, suavizado=1, caras=1500), "torso"))
cint = kit.perfil([(0.97, 0.173, 0.129), (1.06, 0.170, 0.127)])
partes.append((kit.fundir("cinturon", cint, CINTURON, voxel=0.005, suavizado=4, caras=4000), "torso"))

# EL HAORI A CUADROS: abierto adelante, hasta la mitad del muslo, mangas anchas al codo.
HAORI = [(0.70, 0.205, 0.160), (0.86, 0.196, 0.150), (1.00, 0.186, 0.142), (1.20, 0.192, 0.142),
         (1.36, 0.206, 0.146), (1.46, 0.204, 0.140), (1.53, 0.158, 0.112)]


def abierto(x, y, z):
    return y > 0.02 and abs(x) < 0.085 + max(0.0, z - 1.25) * 0.08


haori = kit.abrigo("haori", [], HAORI_A, HAORI, abierto, z_abajo=0.72, corte=1.0, hombros=0.168, r_hombros=0.084)
for obj, _r in haori:
    # El nombre sin forma: de fabrica, en todas.
    obj.name = obj.name.split("__")[0]
    kit.pintar(obj, HAORI_B, lambda x, y, z: (int(math.floor((x + 1.0) / 0.062)) + int(math.floor(z / 0.062))) % 2 == 0)
partes += haori

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.062, r_codo=0.054, r_muneca=0.048, hasta=0.90)
partes.append((kit.fundir("mangas", mangas, UNIFORME, voxel=0.006, suavizado=6, caras=4500), "brazos"))
mh = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h, cdo = J["hombro" + s], J["codo" + s]
    mh += kit.tubo([h, (cdo[0] + lado * 0.01, cdo[1], cdo[2] + 0.04)], [0.078, 0.084])
m_obj = kit.fundir("mangas_haori", mh, HAORI_A, voxel=0.006, suavizado=5, caras=3500)
kit.pintar(m_obj, HAORI_B, lambda x, y, z: (int(math.floor((y + 1.0) / 0.062)) + int(math.floor(z / 0.062))) % 2 == 0)
partes.append((m_obj, "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.044)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.92), (0.150, 0.110, 0.082))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.090, r_rodilla=0.080, r_tobillo=0.060, hasta=0.40)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
vendas = []
for lado in (-1, 1):
    x = lado * 0.12
    for k in range(6):
        z = 0.42 - k * 0.048
        vendas.append(kit.capsula((x, -0.010 * lado, z + 0.018), (x, 0.010 * lado, z - 0.018), 0.060 - k * 0.002, seg=20))
partes.append((kit.fundir("vendas", vendas, VENDAS, voxel=0.0045, suavizado=2, caras=5000), "pies"))
sand = []
for lado in (-1, 1):
    sand += kit.zapato(lado, largo=0.112, ancho=0.054, alto=0.044, punta=0.95)
partes.append((kit.fundir("sandalias", sand, SANDALIAS, voxel=0.005, suavizado=5, caras=3000), "pies"))

# ------------------------------------------------------------------ La katana
xm, ym, zm = J["mano_r"]
hoja = [kit.caja((xm + 0.004, ym + 0.40, zm - 0.020), (0.012, 0.66, 0.036)),
        kit.cono((xm + 0.004, ym + 0.73, zm - 0.020), (xm + 0.004, ym + 0.80, zm - 0.005), 0.018, 0.001, seg=4)]
h_obj = kit.fundir("hoja", hoja, HOJA, voxel=0.003, suavizado=1, caras=2000)
kit.ocultar_en(h_obj, "marca")
partes.append((h_obj, "codo_r"))
partes.append((kit.fundir("tsuba", [kit.elipsoide((xm + 0.004, ym + 0.060, zm - 0.020), (0.045, 0.010, 0.040))],
                          TSUBA, voxel=0.002, suavizado=1, caras=1200), "codo_r"))
partes.append((kit.fundir("mango", [kit.capsula((xm + 0.004, ym - 0.090, zm - 0.020), (xm + 0.004, ym + 0.050, zm - 0.020),
                                                0.018)], MANGO, voxel=0.002, suavizado=1, caras=1200), "codo_r"))

# ======================================================================== Skins
# KITSUNE: la mascara de zorro de Sakonji (blanca, con las marcas rojas y la sonrisa),
# corrida al costado izquierdo de la cabeza.
MASCARA = kit.material("mascara_kitsune", (0.97, 0.96, 0.92))
MARCAS = kit.material("mascara_marcas", (0.85, 0.15, 0.15))
mc = (-0.150, 0.040, 1.860)
mascara = [kit.elipsoide(mc, (0.020, 0.075, 0.090)),
           kit.cono((mc[0] - 0.010, mc[1] + 0.06, mc[2] + 0.07), (mc[0] - 0.020, mc[1] + 0.04, mc[2] + 0.13), 0.024, 0.004),
           kit.cono((mc[0] - 0.010, mc[1] - 0.04, mc[2] + 0.07), (mc[0] - 0.020, mc[1] - 0.06, mc[2] + 0.13), 0.024, 0.004)]
partes.append((kit.fundir(kit.de_skin("mascara_kitsune", "kitsune"), mascara, MASCARA, voxel=0.003, suavizado=3,
                          caras=2500), "cabeza"))
marcas_m = [kit.elipsoide((mc[0] - 0.021, mc[1] + 0.03, mc[2] + 0.02), (0.003, 0.012, 0.006)),
            kit.elipsoide((mc[0] - 0.021, mc[1] - 0.03, mc[2] + 0.02), (0.003, 0.012, 0.006)),
            kit.elipsoide((mc[0] - 0.021, mc[1], mc[2] - 0.045), (0.003, 0.030, 0.004))]
partes.append((kit.fundir(kit.de_skin("mascara_marcas", "kitsune"), marcas_m, MARCAS, voxel=0.0015, suavizado=1,
                          caras=800), "cabeza"))
# MARCA: la llama roja crecida sobre toda la frente izquierda, y la katana roja.
LLAMA = kit.material("marca_llama", (0.75, 0.10, 0.10))
llama = []
for k in range(7):
    q = sobre(cabeza, -0.085 + k * 0.022, 1.870 + 0.02 * math.sin(k * 1.3), 0.002)
    if q is not None:
        llama.append(kit.elipsoide(q, (0.020, 0.006, 0.030 + 0.012 * (k % 2))))
partes.append((kit.fundir(kit.de_skin("marca_llama", "marca"), llama, LLAMA, voxel=0.0018, suavizado=2, caras=1500),
               "cabeza"))
HOJA_ROJA = kit.material("hoja_roja", (0.78, 0.10, 0.08), metal=0.6, rugosidad=0.25)
partes.append((kit.fundir(kit.de_skin("hoja_roja", "marca"), [kit.caja((xm + 0.004, ym + 0.40, zm - 0.020),
                                                                       (0.012, 0.66, 0.036)),
                                                              kit.cono((xm + 0.004, ym + 0.73, zm - 0.020),
                                                                       (xm + 0.004, ym + 0.80, zm - 0.005), 0.018, 0.001,
                                                                       seg=4)],
                          HOJA_ROJA, voxel=0.003, suavizado=1, caras=2000), "codo_r"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.055, 1.812,
                         ojos_extra={"alto": 0.058, "ancho": 0.056, "iris": [0.62, 0.12, 0.12], "pestanas": False},
                         cejas={"alto": 0.034, "color": [0.32, 0.08, 0.08], "largo": 0.054},
                         boca_z=1.700, boca_extra={"ancho": 0.054, "dientes": False})
kit.exportar("tanjiro", arm, cara)
