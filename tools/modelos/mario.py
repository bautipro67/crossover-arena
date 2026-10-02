"""Mario, segun las notas de referencia de su modelo anterior.

Gorra roja con la M roja en un circulo blanco, camisa roja de manga larga, overol azul con
dos botones dorados, guantes blancos, zapatos marrones, pelo castaño corto con patillas,
bigote negro grueso y la nariz grande. LA CABEZA GRANDE SOBRE UN CUERPO BAJO Y ANCHO: la
cabeza es casi un tercio del alto, la panza redonda, las piernas cortas. Por eso las juntas
del esqueleto van mucho mas abajo que las de una persona.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
# Mario ya es de dibujo: los guantes grandes y los zapatos grandes son suyos.
kit.FACTOR_BRAZO = kit.FACTOR_PIERNA = kit.FACTOR_MANO = kit.FACTOR_PIE = 1.0
J = kit.juntas({"caderas": (0, 0, 0.60), "cabeza": (0, 0, 1.30),
                "hombro_r": (0.31, 0, 1.16), "codo_r": (0.35, 0, 0.94), "mano_r": (0.37, 0, 0.74),
                "pierna_r": (0.13, 0, 0.58), "rodilla_r": (0.14, 0, 0.33), "pie_r": (0.14, 0, 0.09)})

PIEL = kit.material("piel", (0.99, 0.80, 0.64))
PELO = kit.material("pelo", (0.36, 0.20, 0.10))
BIGOTE = kit.material("bigote", (0.10, 0.07, 0.06))
GORRA = kit.material("gorra~acento", (0.90, 0.14, 0.14))
EMBLEMA = kit.material("emblema", (0.98, 0.98, 0.96))
M = kit.material("m~acento", (0.90, 0.14, 0.14))
CAMISA = kit.material("cuerpo", (0.86, 0.11, 0.13))
OVEROL = kit.material("overol~pantalon", (0.13, 0.27, 0.74))
BOTONES = kit.material("botones", (0.98, 0.80, 0.22), metal=0.4)
GUANTES = kit.material("guantes", (0.97, 0.97, 0.98))
# "~propio": la parte "zapatos" con SU marron de fabrica, no el color de zapato generico.
ZAPATOS = kit.material("zapatos~propio", (0.42, 0.23, 0.10))

C = (0.0, 0.01, 1.60)  # centro del craneo
# La cabeza se arma con estas medidas y despues se baja y se agranda (CABEZA); el torso se
# baja con TORSO. Asi las piezas quedan escritas como en los demas personajes.
CABEZA = dict(d=(0, 0, -0.075), escala=1.06, centro=C)
TORSO = dict(d=(0, 0, -0.050))
partes = []

# -------------------------------------------------------------------- Cabeza
cab = [kit.elipsoide(C, (0.222, 0.205, 0.215)),
       # Los cachetes y la mandibula, redondos y anchos.
       kit.elipsoide((0, 0.060, 1.515), (0.190, 0.160, 0.125)),
       kit.capsula((0, -0.01, 1.30), (0, -0.01, 1.42), 0.085)]
for lado in (-1, 1):
    cab.append(kit.elipsoide((lado * 0.218, -0.005, 1.565), (0.030, 0.045, 0.062), rot=(0, lado * 12, 0)))
kit.mover(cab, **CABEZA)
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))
# La nariz grande, redonda, un poco caida.
partes.append((kit.fundir("nariz", kit.mover([kit.elipsoide((0, 0.238, 1.548), (0.070, 0.060, 0.060))], **CABEZA), PIEL,
                          voxel=0.005, suavizado=6, caras=2000), "cabeza"))
# EL BIGOTE: dos lobulos gruesos que nacen debajo de la nariz y se abren para los costados,
# con las puntas redondeadas hacia abajo.
bigote = []
for lado in (-1, 1):
    bigote.append(kit.elipsoide((lado * 0.050, 0.225, 1.497), (0.062, 0.034, 0.036), rot=(0, lado * 14, 0)))
    bigote.append(kit.elipsoide((lado * 0.105, 0.200, 1.480), (0.046, 0.032, 0.034), rot=(0, lado * 28, 0)))
    bigote.append(kit.elipsoide((lado * 0.145, 0.165, 1.468), (0.030, 0.028, 0.028)))
kit.mover(bigote, **CABEZA)
partes.append((kit.fundir("bigote", bigote, BIGOTE, voxel=0.005, suavizado=6, caras=4000), "cabeza"))
# El pelo: la nuca y las patillas, y los mechones de atras asomando debajo de la gorra.
pelo = [kit.elipsoide((0, -0.105, 1.590), (0.212, 0.135, 0.125))]
for lado in (-1, 1):
    pelo.append(kit.elipsoide((lado * 0.200, 0.055, 1.585), (0.034, 0.050, 0.070)))
for k in range(5):
    x = -0.14 + k * 0.07
    pelo += kit.tubo([(x, -0.16, 1.60), (x * 1.1, -0.205, 1.50)], [0.040, 0.012])
kit.mover(pelo, **CABEZA)
partes.append((kit.fundir("pelo", pelo, PELO, voxel=0.0055, suavizado=6, caras=5000), "cabeza"))
# LA GORRA: la copa redonda, un poco inflada arriba, y la visera para adelante.
gorra = [kit.elipsoide((0, -0.012, 1.700), (0.234, 0.226, 0.168)),
         kit.elipsoide((0, 0.020, 1.760), (0.200, 0.190, 0.120)),
         kit.elipsoide((0, 0.185, 1.672), (0.192, 0.125, 0.024), rot=(-8, 0, 0))]
kit.mover(gorra, **CABEZA)
g = kit.fundir("gorra", gorra, GORRA, voxel=0.006, suavizado=8, caras=8000)
partes.append((g, "cabeza"))
# El circulo blanco con la M, apoyado de frente sobre la copa.
p, n = kit.superficie(g, 0.0, 1.765 - 0.075 - 0.010)
centro = tuple(p + n * 0.004)
emb = [kit.elipsoide(centro, (0.068, 0.010, 0.062), seg=36)]
kit.girar(emb, centro, kit.inclinacion(n))
partes.append((kit.fundir("emblema", emb, EMBLEMA, voxel=0.004, suavizado=3, caras=1800), "cabeza"))
mx, my, mz = centro[0], centro[1] + 0.009, centro[2]
letra = [kit.caja((mx - 0.030, my, mz - 0.002), (0.014, 0.008, 0.070)),
         kit.caja((mx + 0.030, my, mz - 0.002), (0.014, 0.008, 0.070)),
         kit.caja((mx - 0.014, my, mz + 0.008), (0.013, 0.008, 0.050), rot=(0, -32, 0)),
         kit.caja((mx + 0.014, my, mz + 0.008), (0.013, 0.008, 0.050), rot=(0, 32, 0))]
kit.girar(letra, centro, kit.inclinacion(n))
partes.append((kit.pieza_fija("m", letra, M), "cabeza"))

# -------------------------------------------------------------------- Torso
# La camisa roja y, pintado encima, el overol: de la cintura para abajo, el peto adelante y
# los tiradores. Pintado sobre la misma superficie no hay costuras que se separen al moverse.
torso = [kit.elipsoide((0, 0.0, 1.120), (0.232, 0.172, 0.160)),
         kit.elipsoide((0, 0.035, 0.900), (0.262, 0.218, 0.225)),
         kit.capsula((-0.20, 0.0, 1.215), (0.20, 0.0, 1.215), 0.088),
         kit.elipsoide((0, 0.0, 0.720), (0.210, 0.170, 0.110))]
kit.mover(torso, **TORSO)
cuerpo = kit.fundir("torso", torso, CAMISA, voxel=0.0055, suavizado=8, caras=30000)


def es_overol(x, y, z):
    z -= TORSO["d"][2]
    if z < 0.935:
        return True
    # El peto: el rectangulo de adelante, hasta el pecho.
    if y > 0.06 and abs(x) < 0.118 and z < 1.155:
        return True
    # Los tiradores: suben del peto por adelante, pasan el hombro y bajan cruzados atras.
    if y > 0.0 and z < 1.32 and abs(abs(x) - 0.095) < 0.028:
        return True
    if y <= 0.0 and z < 1.32 and abs(abs(x) - (0.095 - (1.32 - z) * 0.15)) < 0.028:
        return True
    return False


# Los bordes rectos: la cintura y el borde de arriba del peto.
kit.cortar(cuerpo, (0, 0, 0.935 + TORSO["d"][2]))
kit.cortar(cuerpo, (0, 0, 1.155 + TORSO["d"][2]))
for lado in (-1, 1):
    kit.cortar(cuerpo, (lado * 0.118, 0, 0), (1, 0, 0))
kit.pintar(cuerpo, OVEROL, es_overol)
partes.append((cuerpo, "torso"))
botones = []
for lado in (-1, 1):
    q, nq = kit.superficie(cuerpo, lado * 0.095, 1.125 + TORSO["d"][2])
    botones.append(kit.elipsoide(tuple(q + nq * 0.006), (0.026, 0.014, 0.026), seg=16))
partes.append((kit.pieza_fija("botones", botones, BOTONES), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.080, r_codo=0.070, r_muneca=0.062, j=J, hasta=0.800)
partes.append((kit.fundir("mangas", mangas, CAMISA, voxel=0.006, suavizado=6, caras=5000), "brazos"))
guantes = []
for lado in (-1, 1):
    guantes += kit.mano(lado, j=J, r=0.064, guante=1.40)
    s = "_l" if lado < 0 else "_r"
    m = J["mano" + s]
    # El puño del guante, ancho y abierto.
    guantes.append(kit.capsula((m[0], m[1], m[2] + 0.090), (m[0], m[1], m[2] + 0.052), 0.074, 0.066))
partes.append((kit.fundir("guantes", guantes, GUANTES, voxel=0.0055, suavizado=6, caras=6000), "manos"))

# -------------------------------------------------------------------- Piernas
piernas = []
for lado in (-1, 1):
    piernas += kit.pierna(lado, r_muslo=0.118, r_rodilla=0.098, r_tobillo=0.090, j=J, hasta=0.15)
partes.append((kit.fundir("piernas", piernas, OVEROL, voxel=0.007, suavizado=8, caras=5000), "cadera"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, j=J, largo=0.175, ancho=0.096, alto=0.080, punta=1.15)
partes.append((kit.fundir("zapatos", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=4500), "pies"))

# -------------------------------------------------------------------- Skins
#
# Los power-ups cambian el color, y lo que cambia la forma es lo que tiene en la mano:
#   fuego  la bola de fuego en la mano.      hielo  la bola de hielo.
#   dorado la Flor Dorada: las monedas de oro dando vueltas alrededor de la cintura.
#   clasico el Jumpman de 1985: la gorra todavia sin la M ni el circulo.
import math
FUEGO = kit.material("neon_fuego", (1.00, 0.50, 0.12))
NUCLEO = kit.material("neon_fuego_centro", (1.00, 0.92, 0.55))
HIELO = kit.material("neon_hielo", (0.60, 0.88, 1.00))
MONEDA = kit.material("moneda", (1.00, 0.84, 0.25), metal=0.8, rugosidad=0.25)
xm, ym, zm = J["mano_r"]
bola = (xm + 0.02, ym + 0.10, zm + 0.02)
partes.append((kit.fundir(kit.de_skin("flor_fuego", "fuego"), [kit.elipsoide(bola, (0.070, 0.070, 0.070))], FUEGO,
                          voxel=0.005, suavizado=3, caras=1500), "codo_r"))
partes.append((kit.fundir(kit.de_skin("fuego_centro", "fuego"), [kit.elipsoide(bola, (0.040, 0.040, 0.040))], NUCLEO,
                          voxel=0.004, suavizado=3, caras=800), "codo_r"))
hielo = [kit.elipsoide(bola, (0.068, 0.068, 0.068))]
for k in range(8):
    a = 2 * math.pi * k / 8
    hielo.append(kit.cono(bola, (bola[0] + math.cos(a) * 0.10, bola[1] + math.sin(a) * 0.10, bola[2] + (0.05 if k % 2 else -0.05)),
                          0.026, 0.002, seg=6))
partes.append((kit.pieza_fija(kit.de_skin("flor_fuego_hielo", "hielo"), hielo, HIELO), "codo_r"))
monedas = []
for k in range(6):
    a = 2 * math.pi * k / 6
    c = (math.cos(a) * 0.36, math.sin(a) * 0.32, 0.86 + 0.06 * math.sin(a * 2))
    m = [kit.capsula((c[0] - math.sin(a) * 0.006, c[1] + math.cos(a) * 0.006, c[2]),
                     (c[0] + math.sin(a) * 0.006, c[1] - math.cos(a) * 0.006, c[2]), 0.050, seg=20)]
    monedas += m
partes.append((kit.fundir(kit.de_skin("moneda", "dorado"), monedas, MONEDA, voxel=0.004, suavizado=2, caras=3000), "torso"))
for obj, _r in partes:
    if obj.name in ("emblema", "m"):
        kit.ocultar_en(obj, "clasico")

arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.083, 1.540,
                         ojos_extra={"alto": 0.100, "ancho": 0.070, "iris": [0.18, 0.40, 0.86], "pestanas": False},
                         cejas={"alto": 0.054, "color": [0.22, 0.13, 0.06], "largo": 0.066},
                         boca_z=1.360, boca_extra={"ancho": 0.070, "dientes": False})
kit.exportar("mario", arm, cara)
