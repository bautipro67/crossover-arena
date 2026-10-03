"""Saitama, de One Punch Man.

El traje de heroe: un enterito amarillo liso con un cierre corto en el cuello, un cinturon
negro con una hebilla redonda, guantes rojos hasta la mitad del antebrazo, botas rojas
hasta la mitad de la pierna y una capa blanca prendida con dos broches negros. Pelado,
la cara de siempre: ojos chicos, sin cejas marcadas, cara de nada. De contextura comun:
la fuerza no se le nota en el cuerpo.

Skins:
  jersey      solo color (el jersey rojo de entrenar).
  oficinista  el de antes de ser heroe: pelo negro, saco negro, camisa blanca, corbata.
  rasgado     despues de la pelea con Boros: el traje roto, la capa hecha jirones y un
              guante menos.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.98, 0.84, 0.72), rugosidad=0.4)
TRAJE = kit.material("traje~cuerpo", (0.98, 0.84, 0.16))
CIERRE = kit.material("cierre", (0.50, 0.42, 0.10))
CINTURON = kit.material("cinturon", (0.08, 0.08, 0.09))
HEBILLA = kit.material("hebilla", (0.55, 0.55, 0.60), metal=0.8, rugosidad=0.3)
GUANTES = kit.material("guantes~acento", (0.86, 0.10, 0.12))
BOTAS = kit.material("botas~zapatos", (0.86, 0.10, 0.12))
CAPA = kit.material("capa", (0.96, 0.96, 0.94))
BROCHE = kit.material("broche", (0.06, 0.06, 0.07))

partes = []

# -------------------------------------------------------------------- Cabeza
# PELADO, y la cabeza redonda y lisa: es lo que se reconoce. Una cabeza un poco ovalada,
# el menton suave y las orejas chicas.
cabeza_p = kit.cabeza_humana((0, 0.0, 1.81), ancho=0.144, alto=0.182, fondo=0.158, mandibula=0.86, nariz=0.75,
                             menton=0.92)
cabeza_p.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.052))
cabeza = kit.fundir("cabeza", cabeza_p, PIEL, voxel=0.006, suavizado=12, caras=9000)
partes.append((cabeza, "cabeza"))

# -------------------------------------------------------------------- Torso
# El enterito: liso, sin costuras a la vista, un poco holgado.
PERFIL = [(0.86, 0.168, 0.124), (0.95, 0.162, 0.120), (1.05, 0.156, 0.116), (1.20, 0.168, 0.122),
          (1.36, 0.190, 0.130), (1.46, 0.188, 0.124), (1.53, 0.140, 0.100)]


def cuerpo(extra=0.0):
    t = kit.perfil([(z, a + extra, f + extra) for z, a, f in PERFIL])
    t.append(kit.capsula((-0.165, 0.0, 1.47), (0.165, 0.0, 1.47), 0.072 + extra))
    # El cuello redondo del enterito, bajo.
    t.append(kit.capsula((0, -0.008, 1.50), (0, -0.004, 1.545), 0.074 + extra, 0.076 + extra))
    return t


traje = kit.fundir("traje", cuerpo(), TRAJE, voxel=0.006, suavizado=8, caras=10000)
kit.ocultar_en(traje, "oficinista", "rasgado")
partes.append((traje, "torso"))
# El cierre corto del cuello, adelante.
cierre = []
for k in range(6):
    z = 1.490 + k * 0.011
    p, n = kit.superficie(traje, 0.0, z)
    if p is not None:
        c = tuple(p + n * 0.003)
        cierre.append(kit.elipsoide(c, (0.007, 0.003, 0.0055)))
ci = kit.fundir("cierre", cierre, CIERRE, voxel=0.0018, suavizado=1, caras=1200)
kit.ocultar_en(ci, "oficinista")
partes.append((ci, "torso"))
# El cinturon con la hebilla redonda.
cint = kit.perfil([(0.975, 0.172, 0.128), (1.035, 0.169, 0.126)])
cinturon = kit.fundir("cinturon", cint, CINTURON, voxel=0.005, suavizado=4, caras=4000)
kit.ocultar_en(cinturon, "oficinista")
partes.append((cinturon, "torso"))
p, n = kit.superficie(cinturon, 0.0, 1.005)
c = tuple(p + n * 0.006)
disco = [kit.elipsoide(c, (0.030, 0.008, 0.030), seg=28)]
kit.orientar(disco, c, n)
hebilla = kit.fundir("hebilla", disco, HEBILLA, voxel=0.002, suavizado=2, caras=1500)
kit.ocultar_en(hebilla, "oficinista")
partes.append((hebilla, "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.064, r_codo=0.056, r_muneca=0.050, hasta=0.95)
m = kit.fundir("mangas", mangas, TRAJE, voxel=0.006, suavizado=6, caras=4500)
kit.ocultar_en(m, "oficinista")
partes.append((m, "brazos"))


def guante(lado, puno=True):
    """El guante rojo: de la mitad del antebrazo a los dedos, con el puño ancho."""
    s = "_l" if lado < 0 else "_r"
    c, mn = J["codo" + s], J["mano" + s]
    medio = (c[0] + (mn[0] - c[0]) * 0.42, c[1], c[2] + (mn[2] - c[2]) * 0.42)
    f = kit.FACTOR_BRAZO
    piezas = kit.tubo([medio, (mn[0], mn[1], mn[2] + 0.06)], [0.054 * f, 0.050 * f])
    if puno:
        piezas.append(kit.capsula((medio[0], medio[1], medio[2] - 0.005), (medio[0], medio[1], medio[2] + 0.030),
                                  0.066 * f, 0.070 * f))
    piezas += kit.mano(lado, r=0.046, guante=1.10)
    return piezas


# El izquierdo se pierde con la skin "rasgado": esa mano va pelada.
gl = kit.fundir("guante_l", guante(-1), GUANTES, voxel=0.005, suavizado=5, caras=3500)
kit.ocultar_en(gl, "oficinista", "rasgado")
partes.append((gl, "manos"))
gr = kit.fundir("guante_r", guante(1), GUANTES, voxel=0.005, suavizado=5, caras=3500)
kit.ocultar_en(gr, "oficinista")
partes.append((gr, "manos"))

# -------------------------------------------------------------------- Piernas
piernas = [kit.elipsoide((0, 0.0, 0.93), (0.140, 0.100, 0.074))]
for lado in (-1, 1):
    piernas += kit.pierna(lado, r_muslo=0.084, r_rodilla=0.068, r_tobillo=0.058, hasta=0.36)
pi = kit.fundir("piernas_traje", piernas, TRAJE, voxel=0.007, suavizado=8, caras=6000)
kit.ocultar_en(pi, "oficinista")
partes.append((pi, "cadera"))


def bota(lado):
    s = "_l" if lado < 0 else "_r"
    x, y, z = J["rodilla" + s]
    f = kit.FACTOR_PIERNA
    piezas = kit.tubo([(x, y - 0.006, 0.43), (x, y, 0.12)], [0.064 * f, 0.056 * f])
    # El borde de arriba, mas ancho, como el de un guante.
    piezas.append(kit.capsula((x, y - 0.006, 0.40), (x, y - 0.006, 0.445), 0.074 * f, 0.078 * f))
    piezas += kit.zapato(lado, largo=0.118, ancho=0.062, alto=0.056, punta=0.95)
    return piezas


botas = []
for lado in (-1, 1):
    botas += bota(lado)
b = kit.fundir("botas", botas, BOTAS, voxel=0.006, suavizado=6, caras=4500)
kit.ocultar_en(b, "oficinista")
partes.append((b, "pies"))

# ----------------------------------------------------------------------- Capa
# LA CAPA BLANCA hasta las pantorrillas, prendida adelante con dos broches negros.
capa = kit.capa("capa", (), CAPA, z_abajo=0.40, abre=0.12, ancho=0.205, fondo=0.140)
capa.name = "capa"
kit.ocultar_en(capa, "oficinista", "rasgado")
partes.append((capa, "torso"))
broches = []
for lado in (-1, 1):
    p, n = kit.superficie(traje, lado * 0.120, 1.48)
    c = tuple(p + n * 0.010)
    d = [kit.elipsoide(c, (0.020, 0.008, 0.020), seg=24)]
    kit.orientar(d, c, n)
    broches += d
br = kit.fundir("broches", broches, BROCHE, voxel=0.002, suavizado=2, caras=1500)
kit.ocultar_en(br, "oficinista")
partes.append((br, "torso"))

# ======================================================================== Skins
#
# OFICINISTA: pelo negro corto y despeinado, saco y pantalon negros, camisa blanca con el
# cuello, corbata, las manos sin guantes y zapatos negros.
PELO = kit.material("pelo", (0.06, 0.06, 0.07), rugosidad=0.5)
SACO = kit.material("saco~cuerpo", (0.12, 0.12, 0.15))
CAMISA = kit.material("camisa", (0.95, 0.95, 0.96))
CORBATA = kit.material("corbata~acento", (0.62, 0.10, 0.12))
ZAPATOS = kit.material("zapatos~propio", (0.05, 0.05, 0.06), rugosidad=0.3)


def pelo_negro():
    import random
    random.seed(23)
    piezas = [kit.elipsoide((0, -0.012, 1.870), (0.150, 0.160, 0.125)),
              kit.elipsoide((0, -0.070, 1.800), (0.142, 0.110, 0.100))]
    # El flequillo corto, partido, y mechones en punta alrededor.
    for dx, caida in ((-0.095, 0.020), (-0.050, 0.035), (-0.005, 0.040), (0.040, 0.030), (0.085, 0.020)):
        piezas += kit.tubo([(dx * 0.8, 0.09, 1.955), (dx * 1.05, 0.160, 1.925), (dx * 1.12, 0.166, 1.925 - caida)],
                           [0.034, 0.024, 0.005])
    for k in range(14):
        a = math.radians(55 + k * (250 / 13)) + random.uniform(-0.08, 0.08)
        piezas += kit.tubo([(math.sin(a) * 0.13, math.cos(a) * 0.14 - 0.02, 1.90),
                            (math.sin(a) * 0.175, math.cos(a) * 0.18 - 0.03, 1.80 + random.uniform(-0.02, 0.02))],
                           [0.042, 0.007])
    return piezas


partes.append((kit.fundir(kit.de_skin("pelo", "oficinista"), pelo_negro(), PELO, voxel=0.0055, suavizado=4,
                          caras=8000), "cabeza"))
saco_p = [(0.84, 0.176, 0.132), (0.95, 0.170, 0.128), (1.05, 0.164, 0.124), (1.20, 0.176, 0.128),
          (1.36, 0.196, 0.136), (1.46, 0.194, 0.130), (1.53, 0.146, 0.106)]
saco = kit.perfil(saco_p)
saco.append(kit.capsula((-0.170, 0.0, 1.47), (0.170, 0.0, 1.47), 0.076))
# El saco abierto adelante en V: ahi se ve la camisa.
sc = kit.cascara(kit.de_skin("saco", "oficinista"), saco, SACO,
                 lambda x, y, z: not (y > 0.04 and z > 1.24 and abs(x) < (z - 1.24) * 0.42 + 0.010) and z > 0.84,
                 grosor=0.012, caras=9000)
partes.append((sc, "torso"))
camisa = kit.fundir(kit.de_skin("camisa", "oficinista"), cuerpo(-0.006), CAMISA, voxel=0.006, suavizado=8, caras=8000)
partes.append((camisa, "torso"))
corbata = [kit.elipsoide((0, 0.0, 1.535), (0.020, 0.012, 0.018))]
pts = []
for k in range(9):
    z = 1.52 - k * 0.045
    p, n = kit.superficie(camisa, 0.0, z)
    if p is not None:
        pts.append(tuple(p + n * 0.006))
for k in range(len(pts) - 1):
    ancho = 0.016 + 0.010 * k / (len(pts) - 1)
    corbata.append(kit.capsula(pts[k], pts[k + 1], ancho * 0.55, ancho * 0.55 + 0.002))
partes.append((kit.fundir(kit.de_skin("corbata", "oficinista"), corbata, CORBATA, voxel=0.003, suavizado=2, caras=2000),
               "torso"))
mangas_saco = []
for lado in (-1, 1):
    mangas_saco += kit.brazo(lado, r_hombro=0.066, r_codo=0.058, r_muneca=0.054, hasta=0.88)
partes.append((kit.fundir(kit.de_skin("mangas_saco", "oficinista"), mangas_saco, SACO, voxel=0.006, suavizado=6,
                          caras=4500), "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.045)
partes.append((kit.fundir(kit.de_skin("manos", "oficinista"), manos, PIEL, voxel=0.005, suavizado=5, caras=4000),
               "manos"))
pant = [kit.elipsoide((0, 0.0, 0.92), (0.150, 0.108, 0.080))]
for lado in (-1, 1):
    pant += kit.pierna(lado, r_muslo=0.086, r_rodilla=0.076, r_tobillo=0.068, hasta=0.13)
partes.append((kit.fundir(kit.de_skin("pantalon_saco", "oficinista"), pant, SACO, voxel=0.007, suavizado=8, caras=6000),
               "cadera"))
zap = []
for lado in (-1, 1):
    zap += kit.zapato(lado, largo=0.122, ancho=0.056, alto=0.046, punta=0.9)
partes.append((kit.fundir(kit.de_skin("zapatos", "oficinista"), zap, ZAPATOS, voxel=0.006, suavizado=6, caras=3000),
               "pies"))

# RASGADO: el traje con agujeros (abajo se ve la piel), la capa hecha jirones hasta la
# cintura, y la mano izquierda sin guante.
torso_piel = kit.fundir(kit.de_skin("torso_piel", "rasgado"), cuerpo(-0.008), PIEL, voxel=0.006, suavizado=8,
                        caras=7000)
partes.append((torso_piel, "torso"))


def agujero(x, y, z):
    # Desgarros: el hombro derecho, un costado y el pecho izquierdo, con bordes irregulares.
    for cx, cy, cz, r in ((0.17, 0.0, 1.43, 0.075), (-0.07, 0.12, 1.33, 0.060), (0.10, 0.10, 1.12, 0.055),
                          (-0.15, -0.05, 1.20, 0.060)):
        ruido = 0.012 * math.sin(x * 140.0) * math.cos(z * 120.0)
        if (x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2 < (r + ruido) ** 2:
            return True
    return False


roto = kit.cascara(kit.de_skin("traje_roto", "rasgado"), cuerpo(0.002), TRAJE,
                   lambda x, y, z: not agujero(x, y, z), grosor=0.010, caras=9000)
partes.append((roto, "torso"))
mano_l = kit.fundir(kit.de_skin("mano_l", "rasgado"), kit.mano(-1, r=0.045), PIEL, voxel=0.005, suavizado=5,
                    caras=2000)
partes.append((mano_l, "manos"))
capa_rota = kit.capa("capa_rota", ("rasgado",), CAPA, z_abajo=0.86, abre=0.08, ancho=0.205, fondo=0.140)
# Los jirones: el borde de abajo cortado en dientes.
import bmesh  # noqa: E402
bm = bmesh.new()
bm.from_mesh(capa_rota.data)
fuera = []
for f in bm.faces:
    c = f.calc_center_median()
    lim = 0.86 + 0.16 * (0.5 + 0.5 * math.sin(c.x * 38.0)) * (0.5 + 0.5 * math.cos(c.x * 17.0))
    if c.z < lim:
        fuera.append(f)
bmesh.ops.delete(bm, geom=fuera, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(capa_rota.data)
bm.free()
partes.append((capa_rota, "torso"))

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
# LA CARA DE SIEMPRE: ojos chicos y simples, sin cejas, la boca chica. Con la skin del
# oficinista, la cara "seria" de los recuerdos: ojos de anime con pupila.
cara = kit.cara_estandar(cabeza, J, 0.052, 1.822,
                         ojos_extra={"alto": 0.040, "ancho": 0.040, "iris": [0.10, 0.08, 0.06], "estilo": "simple",
                                     "formas": {"oficinista": {"estilo": "anime", "alto": 0.050, "ancho": 0.048,
                                                               "iris": [0.18, 0.14, 0.12]}}},
                         boca_z=1.712, boca_extra={"ancho": 0.040, "dientes": False})
kit.exportar("saitama", arm, cara)
