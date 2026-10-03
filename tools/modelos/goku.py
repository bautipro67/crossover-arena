"""Goku (Dragon Ball Z / Super), segun las notas de referencia de su modelo anterior.

Gi naranja arriba y abajo, camiseta azul oscura debajo (se ve en el cuello en V y en las
mangas cortas), muñequeras y faja azules, botas azul oscuro con cordones amarillos, y el
kanji en un circulo blanco en el pecho y en la espalda. LA SILUETA ES EL PELO: negro, en
puntas duras para arriba y a los costados, con mechones que caen sobre la frente. Y el pelo
del Super Saiyajin para su forma (pelo__f_ssj): las puntas paradas, mas largas, para arriba.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.98, 0.83, 0.68))
PELO = kit.material("pelo", (0.07, 0.07, 0.09), rugosidad=0.5)
GI = kit.material("cuerpo", (0.98, 0.50, 0.12))
CAMISETA = kit.material("camiseta", (0.12, 0.17, 0.42))
FAJA = kit.material("faja", (0.14, 0.22, 0.56))
MUNEQUERAS = kit.material("munequeras", (0.13, 0.20, 0.52))
PANTALON = kit.material("pantalon", (0.96, 0.47, 0.11))
BOTAS = kit.material("zapatos~acento", (0.13, 0.20, 0.52))
CORDONES = kit.material("cordones", (0.95, 0.80, 0.30))
SIMBOLO = kit.material("simbolo", (0.97, 0.97, 0.95))
KANJI = kit.material("kanji", (0.08, 0.08, 0.10))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.150, alto=0.178, fondo=0.155, mandibula=1.05, nariz=0.9)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.068))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))


def pelo_base():
    """El pelo de siempre: puntas duras para arriba, a los costados y para atras, y los
    mechones de la frente."""
    piezas = [kit.elipsoide((0, -0.025, 1.870), (0.166, 0.166, 0.150))]
    # Las puntas grandes, en abanico: siete, largas y afiladas. Mas chicas y muchas se leian
    # como un casco.
    for k in range(7):
        a = -1.40 + k * (2.8 / 6)
        dx, dz = math.sin(a), math.cos(a)
        base = (dx * 0.11, -0.03, 1.91 + dz * 0.05)
        punta = (dx * 0.42, -0.07 - abs(dx) * 0.05, 1.95 + dz * 0.30)
        medio = ((base[0] * 0.4 + punta[0] * 0.6), -0.05, (base[2] * 0.4 + punta[2] * 0.6) + 0.03)
        piezas += kit.tubo([base, medio, punta], [0.090, 0.058, 0.006])
    # Las de atras.
    for k in range(4):
        dx = -0.12 + k * 0.08
        piezas += kit.tubo([(dx * 0.5, -0.10, 1.88), (dx, -0.26, 1.83)], [0.070, 0.010])
    # Los mechones de la frente, cayendo.
    # Los tres mechones de la frente, que terminan ARRIBA de los ojos.
    for dx, largo in ((-0.07, 0.055), (0.0, 0.070), (0.07, 0.050)):
        piezas += kit.tubo([(dx, 0.10, 1.97), (dx * 1.3, 0.165, 1.94), (dx * 1.5, 0.170, 1.94 - largo)],
                           [0.042, 0.030, 0.006])
    return piezas


def pelo_ultra():
    """El Ultra Instinto: el pelo de siempre pero plateado y mas parado, como si flotara;
    las puntas suben en vez de abrirse a los costados."""
    piezas = [kit.elipsoide((0, -0.025, 1.875), (0.168, 0.168, 0.152))]
    for k in range(7):
        a = -1.25 + k * (2.5 / 6)
        dx, dz = math.sin(a), math.cos(a)
        base = (dx * 0.11, -0.03, 1.92 + dz * 0.04)
        punta = (dx * 0.34, -0.08 - abs(dx) * 0.04, 2.02 + dz * 0.34)
        medio = ((base[0] * 0.4 + punta[0] * 0.6), -0.05, (base[2] * 0.4 + punta[2] * 0.6) + 0.04)
        piezas += kit.tubo([base, medio, punta], [0.090, 0.058, 0.006])
    for k in range(4):
        dx = -0.12 + k * 0.08
        piezas += kit.tubo([(dx * 0.5, -0.10, 1.89), (dx * 1.05, -0.25, 1.92)], [0.070, 0.010])
    for dx, largo in ((-0.07, 0.045), (0.0, 0.060), (0.07, 0.040)):
        piezas += kit.tubo([(dx, 0.10, 1.97), (dx * 1.3, 0.165, 1.95), (dx * 1.5, 0.170, 1.95 - largo)],
                           [0.042, 0.030, 0.006])
    return piezas


def pelo_ssj(puntas=9, alto=0.32, grueso=1.0):
    """El Super Saiyajin: las puntas paradas para arriba, mas largas; un solo mechon en la
    frente. El Blue, con menos altura y puntas mas gruesas y marcadas."""
    piezas = [kit.elipsoide((0, -0.020, 1.880), (0.168, 0.168, 0.155))]
    for k in range(puntas):
        a = -1.10 + k * (2.2 / (puntas - 1))
        dx, dz = math.sin(a), math.cos(a)
        base = (dx * 0.11, -0.02, 1.93)
        punta = (dx * 0.26 * (1.0 + (0.32 - alto)), -0.05, 2.02 + dz * alto)
        piezas += kit.tubo([base, ((base[0] + punta[0]) / 2, -0.04, (base[2] + punta[2]) / 2), punta],
                           [0.072 * grueso, 0.048 * grueso, 0.010])
    for k in range(4):
        dx = -0.12 + k * 0.08
        piezas += kit.tubo([(dx * 0.5, -0.10, 1.90), (dx * 1.1, -0.22, 2.05)], [0.068, 0.010])
    piezas += kit.tubo([(0.02, 0.10, 1.96), (0.0, 0.165, 1.90), (-0.02, 0.170, 1.84)], [0.036, 0.024, 0.006])
    return piezas


partes.append((kit.fundir("pelo__sin_ssj+ui+ssj4", pelo_base(), PELO, voxel=0.0058, suavizado=5, caras=10000), "cabeza"))
partes.append((kit.fundir("pelo_ssj__f_goku_ssj", pelo_ssj(), PELO, voxel=0.0058, suavizado=5, caras=10000), "cabeza"))
partes.append((kit.fundir(kit.de_skin("pelo_blue", "blue"), pelo_ssj(8, 0.25, 1.18), PELO, voxel=0.0058, suavizado=5,
                          caras=10000), "cabeza"))
partes.append((kit.fundir("pelo_ui__f_ui", pelo_ultra(), PELO, voxel=0.0058, suavizado=5, caras=10000), "cabeza"))

# -------------------------------------------------------------------- Torso
# Un perfil parejo: el gi cae suelto desde el pecho ancho, sin la cintura de avispa.
torso = kit.perfil([(0.93, 0.186, 0.134), (1.05, 0.184, 0.132), (1.20, 0.196, 0.138), (1.36, 0.222, 0.146),
                    (1.46, 0.220, 0.140), (1.53, 0.168, 0.118)])
torso.append(kit.capsula((-0.185, 0.0, 1.47), (0.185, 0.0, 1.47), 0.080))
for lado in (-1, 1):
    torso.append(kit.elipsoide((lado * 0.092, 0.088, 1.395), (0.112, 0.052, 0.068)))
gi = kit.fundir("gi", torso, GI, voxel=0.006, suavizado=8, caras=11000)
# El cuello en V: la camiseta azul asoma.
kit.pintar(gi, CAMISETA, lambda x, y, z: y > 0.05 and z > 1.36 + abs(x) * 2.0)
partes.append((gi, "torso"))
# El kanji: un circulo blanco a la izquierda del pecho y otro grande en la espalda.
# Apoyados en la tela de verdad (un rayo de adelante y uno de atras).
pf = kit.superficie(gi, -0.095, 1.43)[0]
pb = kit.superficie(gi, 0.0, 1.36, desde=(0.0, -1.5), hacia=(0.0, 1.0))[0]
simbolos = [kit.elipsoide((-0.095, pf.y + 0.002, 1.43), (0.045, 0.012, 0.045)),
            kit.elipsoide((0, pb.y - 0.002, 1.36), (0.085, 0.012, 0.085))]
partes.append((kit.fundir("simbolo", simbolos, SIMBOLO, voxel=0.004, suavizado=2, caras=2000), "torso"))
# EL KANJI 悟 ("Go"), trazo por trazo: el radical del corazon a la izquierda (la raya
# parada y los dos puntos) y a la derecha 五 arriba y 口 abajo. En unidades de -1 a 1, con
# +u hacia la DERECHA DEL QUE MIRA; adelante eso es -X y en la espalda +X.
TRAZOS = [[(-0.72, 0.95), (-0.72, -0.95)], [(-0.95, 0.35), (-0.86, 0.05)], [(-0.56, 0.45), (-0.45, 0.25)],
          [(-0.25, 0.85), (0.95, 0.85)], [(0.32, 0.85), (0.22, 0.20)], [(-0.15, 0.50), (0.74, 0.50), (0.72, 0.18)],
          [(-0.30, 0.18), (1.00, 0.18)],
          [(-0.10, -0.92), (-0.10, -0.05), (0.80, -0.05), (0.80, -0.92)], [(-0.10, -0.85), (0.80, -0.85)]]


def kanji_go(centro, tam, y, hacia):
    return [[(centro[0] + hacia * u * tam, y, centro[2] + v * tam) for u, v in trazo] for trazo in TRAZOS]


trazos = kanji_go((-0.095, 0, 1.43), 0.030, pf.y + 0.0165, -1) + kanji_go((0.0, 0, 1.36), 0.058, pb.y - 0.0165, 1)
partes.append((kit.lineas("kanji", trazos, 0.0042, KANJI), "torso"))
# La faja azul, con el nudo al costado.
faja = [kit.elipsoide((0, 0.0, 1.03), (0.190, 0.145, 0.045)),
        kit.elipsoide((-0.13, 0.11, 1.00), (0.040, 0.030, 0.050)),
        kit.capsula((-0.14, 0.12, 0.98), (-0.15, 0.13, 0.85), 0.022, 0.016)]
partes.append((kit.fundir("faja", faja, FAJA, voxel=0.005, suavizado=5, caras=4000), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h = J["hombro" + s]
    # La manga corta de la camiseta azul.
    mangas += kit.tubo([h, (h[0], h[1], h[2] - 0.17)], [0.082, 0.074])
partes.append((kit.fundir("mangas", mangas, CAMISETA, voxel=0.006, suavizado=6, caras=3000), "brazos"))
brazos = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h, c = J["hombro" + s], J["codo" + s]
    brazos += kit.tubo([(h[0], h[1], h[2] - 0.12), c], [0.074, 0.066])
    brazos += kit.antebrazo(lado, r_codo=0.066, r_muneca=0.052)
    brazos += kit.mano(lado, r=0.050)
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.0055, suavizado=6, caras=7000), "brazos"))
munequeras = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    c = J["codo" + s]
    munequeras.append(kit.capsula((c[0], c[1], 0.96), (c[0], c[1], 0.89), 0.060))
partes.append((kit.fundir("munequeras", munequeras, MUNEQUERAS, voxel=0.005, suavizado=4, caras=2000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.96), (0.185, 0.135, 0.090))]
for lado in (-1, 1):
    # El pantalon del gi es ancho: se abomba en el muslo y la canilla.
    pantalon += kit.pierna(lado, r_muslo=0.098, r_rodilla=0.082, r_tobillo=0.068, hasta=0.30)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6500), "cadera"))
botas = []
for lado in (-1, 1):
    x = lado * 0.12
    botas.append(kit.capsula((x, 0.0, 0.34), (x, 0.0, 0.10), 0.068, 0.066))
    botas += kit.zapato(lado, largo=0.120, ancho=0.068, alto=0.060)
partes.append((kit.fundir("botas", botas, BOTAS, voxel=0.006, suavizado=6, caras=4000), "pies"))
cordones = []
for lado in (-1, 1):
    x = lado * 0.12
    for k in range(4):
        cordones.append(kit.caja((x, 0.066, 0.30 - k * 0.05), (0.060, 0.008, 0.010), rot=(0, 0, 18 if k % 2 else -18)))
partes.append((kit.pieza_fija("cordones", cordones, CORDONES), "pies"))

# EL ULTRA INSTINTO del Torneo del Poder: sin el gi de arriba, el torso al aire y marcado,
# y la camiseta azul hecha jirones colgando de la cintura y de un hombro.
pecho = kit.torso_humano(pecho=0.218, cintura=0.168, fondo=0.130, hombros=0.185)
for lado in (-1, 1):
    pecho.append(kit.elipsoide((lado * 0.090, 0.080, 1.395), (0.112, 0.056, 0.070)))
    for z in (1.250, 1.180, 1.110):
        pecho.append(kit.elipsoide((lado * 0.040, 0.105, z), (0.038, 0.030, 0.032)))
partes.append((kit.fundir("pecho_ui__f_ui", pecho, PIEL, voxel=0.0055, suavizado=8, caras=11000), "torso"))
hombros = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    h = J["hombro" + s]
    hombros += kit.tubo([h, (h[0], h[1], h[2] - 0.16)], [0.078, 0.074])
    hombros.append(kit.elipsoide((h[0] + lado * 0.010, h[1], h[2] - 0.035), (0.084, 0.082, 0.098)))
partes.append((kit.fundir("hombros_ui__f_ui", hombros, PIEL, voxel=0.0055, suavizado=6, caras=4000), "brazos"))
jirones = [kit.elipsoide((0, 0.0, 1.08), (0.182, 0.140, 0.055))]
random_jiron = [(-0.14, 0.10, 1.03, 0.10), (-0.05, 0.13, 1.02, 0.07), (0.06, 0.13, 1.03, 0.11), (0.15, 0.08, 1.04, 0.06),
                (0.0, -0.13, 1.03, 0.09), (-0.12, -0.10, 1.04, 0.08), (0.12, -0.10, 1.03, 0.07)]
for x, y, z, largo in random_jiron:
    jirones.append(kit.cono((x, y, z + 0.02), (x * 1.05, y * 1.05, z - largo), 0.040, 0.004, seg=8))
jirones += kit.tubo([(-0.17, 0.02, 1.47), (-0.20, 0.06, 1.36), (-0.22, 0.03, 1.27)], [0.040, 0.034, 0.006])
partes.append((kit.fundir("jirones_ui__f_ui", jirones, CAMISETA, voxel=0.005, suavizado=3, caras=4000), "torso"))
for obj, _r in partes:
    if obj.name in ("gi", "simbolo", "kanji", "mangas"):
        kit.ocultar_en(obj, "ui")

# EL SUPER SAIYAJIN 4 (Dragon Ball GT): el pelo negro y largo hasta la espalda, el cuerpo
# cubierto de pelaje rojo salvo el pecho, la cola, y el pantalon azul con el cinturon (los
# colores los pone la skin). Sin el gi de arriba.
PELAJE = kit.material("pelaje_rojo!pelaje", (0.72, 0.12, 0.10))


def pelo_ssj4():
    piezas = [kit.elipsoide((0, -0.030, 1.880), (0.172, 0.172, 0.158)),
              kit.elipsoide((0, -0.120, 1.700), (0.160, 0.110, 0.200))]
    # Las puntas de arriba, salvajes, y las largas que caen por la espalda.
    for k in range(9):
        a = -1.15 + k * (2.3 / 8)
        dx, dz = math.sin(a), math.cos(a)
        base = (dx * 0.11, -0.03, 1.93)
        punta = (dx * 0.30, -0.10, 1.98 + dz * 0.20)
        piezas += kit.tubo([base, ((base[0] + punta[0]) / 2, -0.06, (base[2] + punta[2]) / 2 + 0.02), punta],
                           [0.070, 0.046, 0.008])
    for k in range(7):
        dx = -0.15 + k * 0.05
        piezas += kit.tubo([(dx * 0.6, -0.12, 1.86), (dx * 1.2, -0.24, 1.55), (dx * 1.3, -0.22, 1.20)],
                           [0.060, 0.050, 0.010])
    # El flequillo que cae sobre la frente.
    for dx, largo in ((-0.08, 0.070), (-0.02, 0.090), (0.05, 0.075)):
        piezas += kit.tubo([(dx, 0.10, 1.97), (dx * 1.3, 0.168, 1.93), (dx * 1.5, 0.172, 1.93 - largo)],
                           [0.040, 0.028, 0.006])
    return piezas


partes.append((kit.fundir(kit.de_skin("pelo_ssj4", "ssj4"), pelo_ssj4(), PELO, voxel=0.0058, suavizado=5, caras=11000),
               "cabeza"))
cuerpo4 = kit.torso_humano(pecho=0.222, cintura=0.170, fondo=0.134, hombros=0.188)
for lado in (-1, 1):
    cuerpo4.append(kit.elipsoide((lado * 0.090, 0.080, 1.395), (0.112, 0.056, 0.070)))
    for z in (1.250, 1.180, 1.110):
        cuerpo4.append(kit.elipsoide((lado * 0.040, 0.105, z), (0.038, 0.030, 0.032)))
c4 = kit.fundir(kit.de_skin("cuerpo_ssj4", "ssj4"), cuerpo4, PELAJE, voxel=0.0055, suavizado=8, caras=11000)
# El pecho y la panza sin pelaje.
kit.pintar(c4, PIEL, lambda x, y, z: y > 0.03 and abs(x) < 0.150 - max(0.0, z - 1.40) * 0.6 and 1.02 < z < 1.47)
partes.append((c4, "torso"))
brazos4 = []
for lado in (-1, 1):
    s4 = "_l" if lado < 0 else "_r"
    h, c = J["hombro" + s4], J["codo" + s4]
    brazos4 += kit.tubo([h, c], [0.084, 0.068])
    brazos4.append(kit.elipsoide((h[0] + lado * 0.010, h[1], h[2] - 0.035), (0.090, 0.088, 0.100)))
    brazos4 += kit.antebrazo(lado, r_codo=0.068, r_muneca=0.054)
partes.append((kit.fundir(kit.de_skin("brazos_ssj4", "ssj4"), brazos4, PELAJE, voxel=0.0055, suavizado=6, caras=6000),
               "brazos"))
manos4 = []
for lado in (-1, 1):
    manos4 += kit.mano(lado, r=0.050)
partes.append((kit.fundir(kit.de_skin("manos_ssj4", "ssj4"), manos4, PIEL, voxel=0.005, suavizado=5, caras=3500), "manos"))
cola = kit.tubo([(0.0, -0.150, 0.980), (0.10, -0.280, 0.880), (0.20, -0.300, 0.720), (0.24, -0.220, 0.600),
                 (0.20, -0.140, 0.560)], [0.034, 0.036, 0.034, 0.028, 0.012])
partes.append((kit.fundir(kit.de_skin("cola", "ssj4"), cola, PELAJE, voxel=0.004, suavizado=4, caras=3000), "torso"))
for obj, _r in partes:
    if obj.name.split("__")[0] in ("gi", "simbolo", "kanji", "mangas", "brazos"):
        kit.ocultar_en(obj, "ssj4")

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.060, 1.815,
                         ojos_extra={"alto": 0.062, "ancho": 0.058, "iris": [0.10, 0.08, 0.08], "pestanas": False,
                                     "formas": {"ssj4": {"iris": [0.95, 0.78, 0.15]}}},
                         cejas={"alto": 0.042, "color": [0.07, 0.07, 0.09], "largo": 0.060},
                         boca_z=1.697, boca_extra={"ancho": 0.062, "dientes": False})
kit.exportar("goku", arm, cara)
