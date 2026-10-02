"""Noelle Holiday (Deltarune), segun su sprite y su retrato del juego.

Cierva: pelaje marron claro, hocico con la nariz roja, orejas de ciervo caidas a los
costados y astas ramificadas. Pelo rubio largo con flequillo de costado. Chaleco a cuadros
rojo y verde con escote en V sobre una camisa blanca de cuello redondo, vestido azul oscuro
de manga larga con los puños blancos, piernas de pelaje y botas oscuras.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.84, 0.56, 0.37))
PIEL_CLARA = kit.material("piel_clara", (0.95, 0.78, 0.60))
NARIZ = kit.material("nariz", (0.86, 0.12, 0.14), rugosidad=0.35)
PELO = kit.material("pelo", (0.98, 0.83, 0.30), rugosidad=0.5)
ASTAS = kit.material("astas", (0.70, 0.47, 0.28))
SUETER_A = kit.material("sueter_a", (0.80, 0.12, 0.12))
SUETER_B = kit.material("sueter_b", (0.13, 0.56, 0.24))
CAMISA = kit.material("cuerpo", (0.97, 0.97, 0.95))
OSCURO = kit.material("oscuro", (0.20, 0.18, 0.32))
ZAPATOS = kit.material("zapatos", (0.17, 0.15, 0.24))
PECAS = kit.material("pecas", (0.55, 0.30, 0.17))

# La cabeza, un 12% mas grande que la de una persona: Deltarune es de cabezas grandes.
H = kit.escala_desde((0.0, 0.0, 1.60), 1.12)


def He(centro, radios, rot=(0, 0, 0), seg=32):
    return kit.elipsoide(H(centro), tuple(r * 1.12 for r in radios), rot, seg)


def Hc(a, b, ra, rb=None, seg=24):
    return kit.capsula(H(a), H(b), ra * 1.12, (rb if rb is not None else ra) * 1.12, seg)


def Ht(puntos, radios, seg=16):
    return kit.tubo([H(p) for p in puntos], [r * 1.12 for r in radios], seg)


partes = []

# ------------------------------------------------------------------ Cabeza
cabeza = kit.fundir("cabeza", [
    # El craneo, un poco mas ancho arriba.
    He((0, -0.005, 1.805), (0.168, 0.160, 0.182)),
    # Las mejillas: dan la cara redonda de abajo.
    He((0, 0.040, 1.735), (0.148, 0.122, 0.100)),
    # El hocico de cierva, para adelante.
    He((0, 0.122, 1.712), (0.086, 0.086, 0.070)),
    # Las orejas, caidas a los costados y un poco para atras.
    He((0.212, -0.010, 1.838), (0.108, 0.030, 0.045), rot=(0, 24, -14)),
    He((-0.212, -0.010, 1.838), (0.108, 0.030, 0.045), rot=(0, -24, 14)),
], PIEL, voxel=0.006, suavizado=10, caras=10000)
# El hocico y el adentro de las orejas, mas claros.
kit.pintar(cabeza, PIEL_CLARA, lambda x, y, z: (y > 0.165 and z < 1.80) or (abs(x) > 0.18 and y > -0.02 and abs(x) < 0.33 and z < 1.92))
partes.append((cabeza, "cabeza"))

cuello = kit.fundir("cuello_piel", [kit.capsula((0, -0.01, 1.48), (0, -0.01, 1.66), 0.060)], PIEL, voxel=0.006, suavizado=6, caras=1500)
partes.append((cuello, "cabeza"))

nariz = kit.fundir("nariz", [He((0, 0.207, 1.748), (0.036, 0.026, 0.026))], NARIZ, voxel=0.004, suavizado=4, caras=800)
partes.append((nariz, "cabeza"))

pecas = []
for lado in (-1, 1):
    for k, (dx, dz) in enumerate(((0.052, 1.738), (0.070, 1.724), (0.060, 1.708))):
        p, n = kit.superficie(cabeza, H((lado * dx, 0, dz))[0], H((0, 0, dz))[2])
        if p is not None:
            pecas.append(kit.elipsoide(tuple(p + n * 0.002), (0.0050, 0.0040, 0.0050), seg=10))
partes.append((kit.pieza_fija("pecas", pecas, PECAS), "cabeza"))

# ------------------------------------------------------------------- Astas
astas = []
for lado in (-1, 1):
    base = (lado * 0.075, -0.035, 1.950)
    medio = (lado * 0.118, -0.045, 2.075)
    punta = (lado * 0.155, -0.060, 2.220)
    astas += Ht([base, medio, punta], [0.028, 0.022, 0.015])
    # Las ramas: una para afuera abajo y una para adentro arriba, como en el retrato.
    astas += Ht([medio, (lado * 0.205, -0.040, 2.125), (lado * 0.250, -0.035, 2.152)], [0.019, 0.015, 0.011])
    astas += Ht([(lado * 0.138, -0.052, 2.150), (lado * 0.098, -0.050, 2.215), (lado * 0.088, -0.050, 2.252)], [0.016, 0.013, 0.010])
partes.append((kit.fundir("astas", astas, ASTAS, voxel=0.006, suavizado=4, caras=3500), "cabeza"))

# -------------------------------------------------------------------- Pelo
pelo = [
    # El casquete, cubriendo el craneo por arriba y por atras.
    He((0, -0.032, 1.840), (0.182, 0.172, 0.172)),
    # La melena de atras, hasta los hombros.
    He((0, -0.082, 1.665), (0.188, 0.110, 0.200)),
]
for lado in (-1, 1):
    # Los mechones de los costados, por detras de la cara, cayendo hasta el cuello.
    pelo += Ht([(lado * 0.150, 0.040, 1.905), (lado * 0.176, 0.035, 1.745),
                (lado * 0.172, 0.022, 1.565), (lado * 0.155, 0.010, 1.470)],
               [0.046, 0.048, 0.042, 0.026])
    pelo += Ht([(lado * 0.120, -0.070, 1.885), (lado * 0.190, -0.060, 1.700),
                (lado * 0.182, -0.055, 1.510), (lado * 0.150, -0.060, 1.430)],
               [0.066, 0.070, 0.056, 0.028])
# Mechones sueltos en la espalda: la melena no es una bola, son mechones.
for k in range(5):
    x = -0.12 + k * 0.06
    pelo += Ht([(x, -0.130, 1.760), (x * 1.1, -0.150, 1.580), (x * 1.15, -0.120, 1.455)],
               [0.050, 0.042, 0.022])
# El flequillo, de costado: nace arriba a la derecha y cruza la frente, POR ENCIMA de los
# ojos (estan a 1.82: el borde de abajo del flequillo va por 1.90).
pelo += Ht([(0.095, 0.085, 2.000), (0.030, 0.140, 1.965), (-0.060, 0.152, 1.925), (-0.122, 0.128, 1.900)],
           [0.050, 0.044, 0.034, 0.024])
pelo += Ht([(0.125, 0.090, 1.975), (0.112, 0.140, 1.930), (0.098, 0.150, 1.905)],
           [0.040, 0.030, 0.020])
pelo += Ht([(-0.020, 0.095, 2.000), (-0.100, 0.130, 1.950), (-0.148, 0.100, 1.900)],
           [0.044, 0.034, 0.022])
partes.append((kit.fundir("pelo", pelo, PELO, voxel=0.006, suavizado=8, caras=11000), "cabeza"))

# -------------------------------------------------------------- Chaleco y cuello
chaleco = kit.fundir("chaleco", [
    kit.elipsoide((0, 0.0, 1.36), (0.200, 0.138, 0.215)),
    kit.elipsoide((0, 0.0, 1.20), (0.178, 0.128, 0.130)),
    kit.capsula((-0.150, 0.0, 1.46), (0.150, 0.0, 1.46), 0.084),
], SUETER_A, voxel=0.007, suavizado=8, caras=15000)


def cuadro(x, y, z):
    # Cuadros de 7 cm, alternados, en el pecho y la espalda.
    return (int(math.floor(x / 0.07)) + int(math.floor((z - 1.0) / 0.07))) % 2 == 0


kit.pintar(chaleco, SUETER_B, lambda x, y, z: cuadro(x, y, z))
# El escote en V: la camisa blanca asoma en el medio, arriba, adelante.
kit.pintar(chaleco, CAMISA, lambda x, y, z: y > 0.05 and z > 1.40 + abs(x) * 2.2)
# Y el ribete del chaleco abajo, liso.
kit.pintar(chaleco, SUETER_A, lambda x, y, z: z < 1.115)
partes.append((chaleco, "torso"))

cuello_camisa = []
for lado in (-1, 1):
    # El cuello redondo de la camisa, en dos alas que caen sobre el chaleco.
    cuello_camisa.append(kit.elipsoide((lado * 0.056, 0.074, 1.526), (0.066, 0.040, 0.030), rot=(20, 0, lado * -18)))
cuello_camisa.append(kit.capsula((-0.06, -0.02, 1.53), (0.06, -0.02, 1.53), 0.056))
partes.append((kit.fundir("cuello", cuello_camisa, CAMISA, voxel=0.005, suavizado=6, caras=2500), "torso"))

# -------------------------------------------------------------------- Vestido
# LA POLLERA Y LAS MANGAS VAN SEPARADAS: las manos cuelgan pegadas a la pollera, y en un
# solo objeto el borde de la pollera agarraba peso del antebrazo y se levantaba con el brazo.
falda = [
    # Debajo del chaleco y la pollera acampanada, hasta la mitad del muslo.
    kit.elipsoide((0, 0.0, 1.10), (0.172, 0.122, 0.118)),
    kit.cono((0, 0.0, 1.10), (0, 0.0, 0.760), 0.192, 0.270, seg=48),
    kit.elipsoide((0, 0.0, 0.795), (0.270, 0.212, 0.048)),
]
partes.append((kit.fundir("falda", falda, OSCURO, voxel=0.007, suavizado=8, caras=6000), None))
mangas = []
for lado in (-1, 1):
    # El hombro y las mangas largas.
    mangas.append(kit.capsula((lado * 0.170, 0.0, 1.475), (lado * 0.29, 0.0, 1.450), 0.074, 0.068))
    mangas += kit.tubo([(lado * 0.29, 0.0, 1.45), (lado * 0.29, 0.0, 1.13), (lado * 0.29, 0.0, 0.925)],
                       [0.066, 0.059, 0.054])
partes.append((kit.fundir("mangas", mangas, OSCURO, voxel=0.007, suavizado=8, caras=5000), None))

punos = []
for lado in (-1, 1):
    # Los puños blancos de la camisa, asomando de la manga.
    punos.append(kit.capsula((lado * 0.29, 0.0, 0.945), (lado * 0.29, 0.0, 0.895), 0.060, 0.058))
partes.append((kit.fundir("punos", punos, CAMISA, voxel=0.005, suavizado=6, caras=2000), None))

# --------------------------------------------------------------------- Manos
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.044)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.0045, suavizado=5, caras=5000), None))

# ------------------------------------------------------------------- Piernas
piernas = []
for lado in (-1, 1):
    piernas += kit.pierna(lado, r_muslo=0.074, r_rodilla=0.058, r_tobillo=0.048, hasta=0.30)
partes.append((kit.fundir("piernas", piernas, PIEL, voxel=0.007, suavizado=8, caras=4500), None))

botas = []
for lado in (-1, 1):
    botas.append(kit.capsula((lado * 0.12, 0.0, 0.34), (lado * 0.12, 0.0, 0.12), 0.061, 0.066))
    botas.append(kit.elipsoide((lado * 0.12, 0.058, 0.074), (0.072, 0.118, 0.060)))
partes.append((kit.fundir("botas", botas, ZAPATOS, voxel=0.006, suavizado=6, caras=4000), None))

# -------------------------------------------------------------------- Skins
#
# Cada skin cambia el modelo con lo que la skin dice ser, nada de relleno:
#   snowgrave  la ruta Snowgrave: el pelo le tapa los ojos, el Anillo de Espinas en la mano
#              y carambanos colgando de las astas.
#   aurora     el cielo del norte EN UN SUETER: el pullover de cuello alto y mangas largas
#              con las franjas de la aurora, y las orejeras.
#   escarcha   el frio que se le queda adentro: la corona de escarcha y los carambanos.
#   sombra / otono   la bufanda tejida.          cyber  el visor y los bordes de neon.
#   fiesta     el gorro de Navidad (Holiday).    reno   las astas grandes y la nariz que brilla.
#   menta      la mañana de invierno: el gorro de lana.
HIELO = kit.material("hielo", (0.80, 0.93, 1.00), rugosidad=0.25)
ESPINAS = kit.material("espinas", (0.32, 0.40, 0.48), metal=0.3)
LANA = kit.material("bufanda", (0.46, 0.47, 0.56))
OREJERAS = kit.material("orejeras", (0.88, 0.97, 1.00))
VISOR = kit.material("visor", (0.25, 0.95, 1.00))
NEON = kit.material("neon_bordes", (0.20, 0.90, 0.95))
GORRO = kit.material("gorro", (0.86, 0.14, 0.16))
BORDE_GORRO = kit.material("gorro_borde", (0.98, 0.98, 0.97))
GORRO_LANA = kit.material("gorro_lana", (0.85, 0.97, 0.92))
NARIZ_RENO = kit.material("neon_nariz", (1.00, 0.16, 0.14))

# El flequillo de la ruta Snowgrave: largo y parejo, tapando los ojos.
fleco = []
for k in range(7):
    x = -0.105 + k * 0.035
    fleco += Ht([(x * 0.9, 0.100, 1.985), (x, 0.158, 1.930), (x * 1.06, 0.178, 1.850), (x * 1.08, 0.176, 1.792)],
                [0.032, 0.030, 0.024, 0.006])
partes.append((kit.fundir(kit.de_skin("flequillo", "snowgrave"), fleco, PELO, voxel=0.0055, suavizado=4, caras=3500),
               "cabeza"))
# El Anillo de Espinas, en un dedo de la mano izquierda.
xm, ym, zm = J["mano_l"]
anillo = []
for k in range(16):
    a, b = 2 * math.pi * k / 16, 2 * math.pi * (k + 1) / 16
    anillo.append(kit.capsula((xm + math.cos(a) * 0.016, ym + 0.012 + math.sin(a) * 0.016, zm - 0.050),
                              (xm + math.cos(b) * 0.016, ym + 0.012 + math.sin(b) * 0.016, zm - 0.050), 0.0045, seg=8))
    if k % 2 == 0:
        anillo.append(kit.cono((xm + math.cos(a) * 0.018, ym + 0.012 + math.sin(a) * 0.018, zm - 0.050),
                               (xm + math.cos(a) * 0.034, ym + 0.012 + math.sin(a) * 0.034, zm - 0.046), 0.005, seg=8))
partes.append((kit.fundir(kit.de_skin("anillo", "snowgrave"), anillo, ESPINAS, voxel=0.0018, suavizado=1, caras=2500),
               "codo_l"))
# Los carambanos, colgando de las astas.
carambanos = []
for lado in (-1, 1):
    for t, largo in ((0.25, 0.06), (0.55, 0.09), (0.80, 0.05)):
        a = H((lado * (0.075 + 0.080 * t), -0.040 - 0.020 * t, 1.950 + 0.270 * t))
        carambanos.append(kit.cono(a, (a[0], a[1], a[2] - largo), 0.010, 0.001, seg=10))
    for t, largo in ((0.5, 0.07), (0.9, 0.05)):
        a = H((lado * (0.118 + 0.132 * t), -0.042, 2.075 + 0.077 * t))
        carambanos.append(kit.cono(a, (a[0], a[1], a[2] - largo), 0.009, 0.001, seg=10))
partes.append((kit.pieza_fija(kit.de_skin("carambanos", "snowgrave", "escarcha"), carambanos, HIELO), "cabeza"))
# La corona de escarcha: cristales parados alrededor de la cabeza.
corona = []
for k in range(11):
    a = math.radians(-150 + k * 30)
    base = H((math.sin(a) * 0.170, math.cos(a) * 0.168 - 0.030, 1.955))
    alto = 0.07 if k % 2 else 0.11
    corona.append(kit.cono(base, (base[0] * 1.08, base[1] * 1.08, base[2] + alto), 0.020, 0.002, seg=6))
partes.append((kit.pieza_fija(kit.de_skin("corona_hielo", "escarcha"), corona, HIELO), "cabeza"))

# AURORA: el pullover de cuello alto, con las franjas onduladas de la aurora.
sueter = kit.fundir(kit.de_skin("sueter", "aurora"), [
    kit.elipsoide((0, 0.0, 1.36), (0.206, 0.142, 0.218)),
    kit.elipsoide((0, 0.0, 1.20), (0.184, 0.132, 0.140)),
    kit.capsula((-0.152, 0.0, 1.465), (0.152, 0.0, 1.465), 0.088),
    kit.capsula((0, -0.012, 1.50), (0, -0.012, 1.62), 0.074, 0.070),
], SUETER_A, voxel=0.006, suavizado=8, caras=14000)
kit.pintar(sueter, SUETER_B, lambda x, y, z: math.sin((z + 0.05 * math.sin(x * 18.0)) * 28.0) > 0.25)
partes.append((sueter, "torso"))
mangas_s = []
for lado in (-1, 1):
    mangas_s.append(kit.capsula((lado * 0.170, 0.0, 1.475), (lado * 0.29, 0.0, 1.450), 0.080, 0.074))
    mangas_s += kit.tubo([(lado * 0.29, 0.0, 1.45), (lado * 0.29, 0.0, 1.13), (lado * 0.29, 0.0, 0.905)],
                         [0.072, 0.065, 0.060])
ms = kit.fundir(kit.de_skin("mangas_sueter", "aurora"), mangas_s, SUETER_A, voxel=0.006, suavizado=8, caras=5000)
kit.pintar(ms, SUETER_B, lambda x, y, z: math.sin(z * 28.0) > 0.25)
partes.append((ms, None))
orejeras = [He((lado * 0.168, 0.0, 1.800), (0.040, 0.044, 0.050)) for lado in (-1, 1)]
orejeras += Ht([(-0.150, 0.0, 1.84), (-0.10, -0.01, 1.99), (0.0, -0.02, 2.035), (0.10, -0.01, 1.99), (0.150, 0.0, 1.84)],
               [0.012] * 5, seg=10)
partes.append((kit.fundir(kit.de_skin("orejeras", "aurora"), orejeras, OREJERAS, voxel=0.0045, suavizado=4, caras=3000),
               "cabeza"))
# LA BUFANDA tejida: dos vueltas al cuello y las puntas, una adelante y una atras.
bufanda = []
for vuelta, z in enumerate((1.540, 1.585)):
    for k in range(24):
        a, b = 2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24
        bufanda.append(kit.capsula((math.sin(a) * 0.088, math.cos(a) * 0.080 - 0.012, z),
                                   (math.sin(b) * 0.088, math.cos(b) * 0.080 - 0.012, z), 0.030, seg=10))
bufanda += kit.tubo([(-0.060, 0.070, 1.540), (-0.075, 0.120, 1.420), (-0.072, 0.135, 1.260)], [0.034, 0.032, 0.030])
bufanda += kit.tubo([(0.060, -0.080, 1.540), (0.075, -0.150, 1.420), (0.070, -0.165, 1.300)], [0.034, 0.032, 0.030])
partes.append((kit.fundir(kit.de_skin("bufanda", "sombra", "otono"), bufanda, LANA, voxel=0.006, suavizado=5, caras=5000),
               "torso"))
# CYBER: el visor sobre los ojos y los bordes del chaleco en neon.
visor = []
for k in range(15):
    a = math.radians(-58 + k * (116 / 14))
    visor.append(He((math.sin(a) * 0.168, math.cos(a) * 0.165 - 0.004, 1.822), (0.026, 0.012, 0.022), seg=12))
partes.append((kit.fundir(kit.de_skin("visor", "cyber"), visor, VISOR, voxel=0.004, suavizado=4, caras=2500), "cabeza"))
bordes = []
for lado in (-1, 1):
    bordes.append([kit.pegar(chaleco, (lado * x, 0.3, 1.40 + x * 2.2), 0.004) for x in (0.0, 0.03, 0.06, 0.09, 0.12)])
bordes.append([kit.pegar(chaleco, (math.sin(a) * 0.30, math.cos(a) * 0.30, 1.118), 0.004) for a in
               [i * math.pi / 12 for i in range(25)]])
partes.append((kit.lineas(kit.de_skin("neon_bordes", "cyber"), bordes, 0.0055, NEON), "torso"))
# FIESTA: el gorro de Navidad, de costado entre las astas, con el borde y el pompon blancos.
gb = H((0.0, -0.030, 1.985))
gorro = [kit.cono(gb, H((0.10, -0.10, 2.20)), 0.150 * 1.12, 0.020, seg=32)]
partes.append((kit.fundir(kit.de_skin("gorro", "fiesta"), gorro, GORRO, voxel=0.006, suavizado=4, caras=3000), "cabeza"))
borde = [kit.capsula(H((math.sin(a) * 0.160, math.cos(a) * 0.158 - 0.030, 1.975)),
                     H((math.sin(b) * 0.160, math.cos(b) * 0.158 - 0.030, 1.975)), 0.026, seg=10)
         for a, b in [(2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24) for k in range(24)]]
borde.append(He((0.10, -0.10, 2.20), (0.034, 0.034, 0.034)))
partes.append((kit.fundir(kit.de_skin("gorro_borde", "fiesta"), borde, BORDE_GORRO, voxel=0.005, suavizado=4, caras=3000),
               "cabeza"))
# MENTA: el gorro de lana con el pompon.
lana = [He((0, -0.020, 1.905), (0.182, 0.176, 0.140)),
        Hc((0, -0.020, 1.86), (0, -0.020, 1.89), 0.184, 0.180),
        He((0, -0.020, 2.065), (0.040, 0.040, 0.040))]
gl = kit.fundir(kit.de_skin("gorro_lana", "menta"), lana, GORRO_LANA, voxel=0.006, suavizado=6, caras=4000)
kit.pintar(gl, BORDE_GORRO, lambda x, y, z: z < H((0, 0, 1.895))[2])
partes.append((gl, "cabeza"))
# RENO: las astas grandes, con mas puntas, y la nariz que brilla.
astas_r = []
for lado in (-1, 1):
    base = (lado * 0.075, -0.035, 1.950)
    medio = (lado * 0.130, -0.050, 2.100)
    punta = (lado * 0.190, -0.075, 2.300)
    astas_r += Ht([base, medio, punta], [0.032, 0.025, 0.016])
    for t, sale in ((0.25, 0.10), (0.55, 0.12), (0.80, 0.09)):
        q = (base[0] + (punta[0] - base[0]) * t, -0.05, base[2] + (punta[2] - base[2]) * t)
        astas_r += Ht([q, (q[0] + lado * sale, q[1] + 0.01, q[2] + sale * 0.45)], [0.018, 0.010])
    astas_r += Ht([(lado * 0.150, -0.060, 2.180), (lado * 0.110, -0.055, 2.280)], [0.016, 0.009])
partes.append((kit.fundir(kit.de_skin("astas", "reno"), astas_r, ASTAS, voxel=0.0055, suavizado=4, caras=4500), "cabeza"))
partes.append((kit.fundir(kit.de_skin("nariz_roja", "reno"), [He((0, 0.210, 1.748), (0.042, 0.032, 0.032))], NARIZ_RENO,
                          voxel=0.004, suavizado=4, caras=900), "cabeza"))

for obj, _r in partes:
    if obj.name in ("astas", "nariz"):
        kit.ocultar_en(obj, "reno")
    elif obj.name in ("chaleco", "cuello", "mangas"):
        kit.ocultar_en(obj, "aurora")

# ---------------------------------------------------------------- Esqueleto
arm = kit.esqueleto(J)
brazos_y_torso = ["torso", "hombro_l", "codo_l", "hombro_r", "codo_r"]
for obj, hueso in partes:
    if hueso:
        kit.pesar(obj, arm, J, solo=hueso)
    elif obj.name.startswith("falda"):
        kit.pesar(obj, arm, J, permitidos=["torso", "pierna_l", "pierna_r"])
    elif obj.name.startswith("mangas"):
        kit.pesar(obj, arm, J, permitidos=brazos_y_torso)
    elif obj.name.startswith(("manos", "punos")):
        kit.pesar(obj, arm, J, permitidos=["codo_l", "codo_r"])
    else:
        kit.pesar(obj, arm, J, permitidos=["pierna_l", "rodilla_l", "pierna_r", "rodilla_r"])

# ------------------------------------------------------------------- La cara
# Los ojos y la boca, pegados a la superficie de verdad (un rayo desde adelante).
ojos = {}
giro = 10.0
for lado, clave in ((-1, "l"), (1, "r")):
    pos = H((lado * 0.074, 0.0, 1.822))
    p, n = kit.superficie(cabeza, pos[0], pos[2])
    ojos[clave] = kit.a_juego(tuple(p + n * 0.003), J)
    giro = math.degrees(math.atan2(abs(n.x), n.y))
pb = H((0.0, 0.0, 1.676))
p, n = kit.superficie(cabeza, 0.0, pb[2])
cara = {
    "ojos": {"l": ojos["l"], "r": ojos["r"], "alto": 0.100, "ancho": 0.076,
             "iris": [0.45, 0.28, 0.13], "pestanas": True, "giro": round(giro, 1),
             # Snowgrave: el flequillo le tapa los ojos, como en los sprites de esa ruta.
             "formas": {"noelle_snowgrave": {"oculto": True}}},
    "cejas": {"alto": 0.066, "color": [0.62, 0.42, 0.18], "largo": 0.058},
    "boca": {"pos": kit.a_juego(tuple(p + n * 0.003), J), "ancho": 0.078, "dientes": True},
}
kit.exportar("noelle", arm, cara)
kit.vistas(kit.carpeta_vistas(), "noelle")
