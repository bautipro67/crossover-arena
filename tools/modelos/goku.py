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


def pelo_ssj():
    """El Super Saiyajin: las puntas paradas para arriba, mas largas; un solo mechon en la frente."""
    piezas = [kit.elipsoide((0, -0.020, 1.880), (0.168, 0.168, 0.155))]
    for k in range(9):
        a = -1.10 + k * (2.2 / 8)
        dx, dz = math.sin(a), math.cos(a)
        base = (dx * 0.11, -0.02, 1.93)
        punta = (dx * 0.26, -0.05, 2.02 + dz * 0.32)
        piezas += kit.tubo([base, ((base[0] + punta[0]) / 2, -0.04, (base[2] + punta[2]) / 2), punta],
                           [0.072, 0.048, 0.010])
    for k in range(4):
        dx = -0.12 + k * 0.08
        piezas += kit.tubo([(dx * 0.5, -0.10, 1.90), (dx * 1.1, -0.22, 2.05)], [0.068, 0.010])
    piezas += kit.tubo([(0.02, 0.10, 1.96), (0.0, 0.165, 1.90), (-0.02, 0.170, 1.84)], [0.036, 0.024, 0.006])
    return piezas


partes.append((kit.fundir("pelo__sin_ssj", pelo_base(), PELO, voxel=0.0058, suavizado=5, caras=10000), "cabeza"))
partes.append((kit.fundir("pelo__f_ssj", pelo_ssj(), PELO, voxel=0.0058, suavizado=5, caras=10000), "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.torso_humano(pecho=0.225, cintura=0.175, fondo=0.135, hombros=0.185)
for lado in (-1, 1):
    torso.append(kit.elipsoide((lado * 0.092, 0.075, 1.400), (0.118, 0.050, 0.068)))
gi = kit.fundir("gi", torso, GI, voxel=0.006, suavizado=8, caras=11000)
# El cuello en V: la camiseta azul asoma.
kit.pintar(gi, CAMISETA, lambda x, y, z: y > 0.05 and z > 1.36 + abs(x) * 2.0)
partes.append((gi, "torso"))
# El kanji: un circulo blanco a la izquierda del pecho y otro grande en la espalda.
simbolos = [kit.elipsoide((-0.095, 0.150, 1.43), (0.045, 0.012, 0.045)),
            kit.elipsoide((0, -0.140, 1.36), (0.085, 0.012, 0.085))]
partes.append((kit.fundir("simbolo", simbolos, SIMBOLO, voxel=0.004, suavizado=2, caras=2000), "torso"))
kanji = [kit.caja((-0.095, 0.163, 1.43), (0.040, 0.006, 0.008)), kit.caja((-0.095, 0.163, 1.43), (0.008, 0.006, 0.050)),
         kit.caja((0, -0.153, 1.36), (0.075, 0.006, 0.012)), kit.caja((0, -0.153, 1.36), (0.012, 0.006, 0.095))]
partes.append((kit.pieza_fija("kanji", kanji, KANJI), "torso"))
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

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.060, 1.815,
                         ojos_extra={"alto": 0.062, "ancho": 0.058, "iris": [0.10, 0.08, 0.08], "pestanas": False},
                         cejas={"alto": 0.042, "color": [0.07, 0.07, 0.09], "largo": 0.060},
                         boca_z=1.697, boca_extra={"ancho": 0.062, "dientes": False})
kit.exportar("goku", arm, cara)
