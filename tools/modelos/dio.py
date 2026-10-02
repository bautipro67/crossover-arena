"""DIO (JoJo, Parte 3), de la referencia (JoJo Wiki): "una campera con una musculosa
ajustada abajo, y chaparreras"; las mangas de la campera unidas a las muñequeras brillantes;
el cinturon con el corazon verde y las tiras que cuelgan un poco mas abajo; las rodilleras de
corazon y la vincha verde con el corazon en el medio; las botas hasta la rodilla del animé; y
el pelo rubio hasta los hombros. LA CAMPERA ES CORTA: termina debajo del pecho y deja ver la
musculosa negra en la panza. Sin capa: la capa la usa al principio y la tira (la llevan sus
skins que la tienen).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.94, 0.86, 0.82))
PELO = kit.material("pelo", (1.00, 0.86, 0.38), rugosidad=0.5)
VERDE = kit.material("detalle", (0.20, 0.52, 0.32))
CAMPERA = kit.material("cuerpo", (0.90, 0.76, 0.30))
HOMBRERAS = kit.material("acento", (0.93, 0.74, 0.22))
MUSCULOSA = kit.material("musculosa", (0.11, 0.11, 0.14))
JOYA = kit.material("joya", (1.00, 0.80, 0.30), emision=0.4)
PUNOS = kit.material("hebilla", (0.95, 0.82, 0.40), metal=0.8, rugosidad=0.25)
CINTO = kit.material("cinto", (0.32, 0.26, 0.12))
PANTALON = kit.material("pantalon", (0.82, 0.68, 0.26))
BOTAS = kit.material("zapatos", (0.86, 0.72, 0.30))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.150, alto=0.180, fondo=0.158, mandibula=1.08,
                        nariz=1.15, menton=1.05)
cab.append(kit.capsula((0, -0.01, 1.48), (0, -0.01, 1.66), 0.064))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))

# EL PELO: rubio, con volumen arriba y peinado para atras, y mechones lacios que caen a
# los costados de la cara hasta los hombros. La frente queda libre para la vincha.
pelo = [kit.elipsoide((0, -0.040, 1.880), (0.168, 0.165, 0.150))]
for k, dx in enumerate((-0.10, -0.05, 0.0, 0.05, 0.10)):
    pelo += kit.tubo([(dx, 0.090, 1.950), (dx * 1.15, 0.030, 2.000), (dx * 1.25, -0.080, 1.995),
                      (dx * 1.2, -0.175, 1.900)], [0.040, 0.044, 0.036, 0.012])
for lado in (-1, 1):
    for k, dy in enumerate((0.060, 0.000, -0.070)):
        pelo += kit.tubo([(lado * 0.130, dy, 1.940), (lado * 0.172, dy - 0.01, 1.830),
                          (lado * 0.168, dy - 0.02, 1.690), (lado * 0.158, dy - 0.03, 1.580)],
                         [0.042, 0.040, 0.030, 0.008])
    pelo += kit.tubo([(lado * 0.120, 0.105, 1.930), (lado * 0.150, 0.120, 1.820), (lado * 0.150, 0.105, 1.700)],
                     [0.030, 0.026, 0.008])
pelo += [kit.elipsoide((0, -0.110, 1.720), (0.150, 0.080, 0.130))]
for k in range(5):
    x = -0.10 + k * 0.05
    pelo += kit.tubo([(x, -0.13, 1.72), (x * 1.2, -0.15, 1.60)], [0.036, 0.008])
partes.append((kit.fundir("pelo", pelo, PELO, voxel=0.006, suavizado=6, caras=10000), "cabeza"))

# La vincha verde con el corazon adelante: POR FUERA del pelo, cruzando la frente.
banda = [kit.elipsoide((0, -0.012, 1.895), (0.178, 0.178, 0.030))]
corazon = []
for lado in (-1, 1):
    corazon.append(kit.elipsoide((lado * 0.020, 0.172, 1.902), (0.024, 0.016, 0.022)))
corazon.append(kit.cono((0, 0.172, 1.898), (0, 0.172, 1.862), 0.034, 0.002, seg=16))
partes.append((kit.fundir("banda", banda + corazon, VERDE, voxel=0.005, suavizado=4, caras=4000), "cabeza"))

# -------------------------------------------------------------------- Torso
# La musculosa negra, ajustada: el cuerpo de DIO, con el pecho y el abdomen marcados.
perfil = [(0.93, 0.172, 0.124), (1.05, 0.168, 0.120), (1.20, 0.182, 0.128), (1.36, 0.206, 0.136),
          (1.46, 0.204, 0.130), (1.53, 0.156, 0.110)]


def torso(extra=0.0, musculos=True):
    t = kit.perfil([(z, a + extra, f + extra) for z, a, f in perfil])
    t.append(kit.capsula((-0.172, 0.0, 1.47), (0.172, 0.0, 1.47), 0.078 + extra))
    for lado in (-1, 1):
        t.append(kit.elipsoide((lado * 0.088, 0.088 + extra, 1.385), (0.100, 0.056, 0.072)))
        if musculos:
            for z in (1.250, 1.180, 1.110):
                t.append(kit.elipsoide((lado * 0.038, 0.100, z), (0.036, 0.028, 0.030)))
    return t


partes.append((kit.fundir("musculosa", torso(), MUSCULOSA, voxel=0.0055, suavizado=8, caras=11000), "torso"))
partes.append((kit.fundir("joya", [kit.elipsoide((0, 0.150, 1.43), (0.026, 0.012, 0.026), rot=(0, 45, 0))],
                          JOYA, voxel=0.004, suavizado=2, caras=600), "torso"))


# LA CAMPERA CORTA: termina debajo del pecho, abierta adelante en una V ancha.
def campera(x, y, z):
    if not (1.235 < z < 1.565):
        return False
    return not (y > 0.0 and abs(x) < 0.050 + (1.565 - z) * 0.30)


partes.append((kit.cascara("campera", torso(0.016, False), CAMPERA, campera, grosor=0.014, caras=8000), "torso"))
# El cuello de la campera, parado atras.
cuello = [kit.capsula((-0.080, -0.035, 1.575), (0.080, -0.035, 1.575), 0.026)]
partes.append((kit.fundir("cuello", cuello, CAMPERA, voxel=0.005, suavizado=4, caras=1500), "torso"))
# Las hombreras redondeadas de la campera.
for lado in (-1, 1):
    s = "l" if lado < 0 else "r"
    hb = kit.cascara("hombrera_%s" % s, [kit.elipsoide((lado * 0.275, 0.0, 1.470), (0.115, 0.118, 0.090))], HOMBRERAS,
                     lambda x, y, z: z > 1.420 and abs(x) > 0.205, grosor=0.014, caras=2000)
    partes.append((hb, "hombro_" + s))

# --------------------------------------------------------------------- Brazos
# Las mangas largas de la campera, unidas a las muñequeras brillantes.
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.068, r_codo=0.058, r_muneca=0.050, hasta=0.900)
partes.append((kit.fundir("mangas", mangas, CAMPERA, voxel=0.006, suavizado=6, caras=7000), "brazos"))
punos = []
for lado in (-1, 1):
    m = J["mano_r" if lado > 0 else "mano_l"]
    punos.append(kit.capsula((m[0], m[1], 0.935), (m[0], m[1], 0.890), 0.064))
    punos.append(kit.capsula((m[0], m[1], 0.955), (m[0], m[1], 0.945), 0.068))
partes.append((kit.fundir("punos", punos, PUNOS, voxel=0.004, suavizado=3, caras=2500), "manos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.046)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.0045, suavizado=5, caras=6000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.96), (0.168, 0.118, 0.085))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.088, r_rodilla=0.070, r_tobillo=0.058, hasta=0.40)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=7000), "cadera"))
# El cinturon con el corazon verde, y las dos tiras que cuelgan un poco mas abajo.
partes.append((kit.fundir("cinto", [kit.elipsoide((0, 0.0, 1.010), (0.180, 0.130, 0.032))], CINTO, voxel=0.005,
                          suavizado=3, caras=3000), "torso"))
tiras = []
for lado in (-1, 1):
    # Una tira en U: baja del cinturon, cuelga sobre el muslo y vuelve a subir.
    pts = []
    for k in range(9):
        t = k / 8.0
        x = lado * (0.060 + 0.100 * t)
        z = 0.990 - 0.115 * (1.0 - (2.0 * t - 1.0) ** 2)
        pts.append(kit.pegar(kit.bpy.data.objects["pantalon"], (x, 0.3, z), 0.006))
    tiras.append(pts)
partes.append((kit.lineas("tiras", tiras, 0.011, CINTO), "cadera"))
p, n = kit.superficie(kit.bpy.data.objects["cinto"], 0.0, 1.010)
c = tuple(p + n * 0.006)
corazon = [kit.elipsoide((c[0] - 0.016, c[1], c[2] + 0.006), (0.020, 0.010, 0.018)),
           kit.elipsoide((c[0] + 0.016, c[1], c[2] + 0.006), (0.020, 0.010, 0.018)),
           kit.cono((c[0], c[1], c[2] + 0.004), (c[0], c[1], c[2] - 0.030), 0.028, 0.002, seg=16)]
kit.orientar(corazon, c, n)
partes.append((kit.fundir("corazon_cinto", corazon, VERDE, voxel=0.0035, suavizado=2, caras=1200), "torso"))
# Las rodilleras de corazon.
rodilleras = []
for lado in (-1, 1):
    x = lado * 0.12
    rodilleras.append(kit.elipsoide((x + lado * -0.020, 0.076, 0.552), (0.036, 0.016, 0.032)))
    rodilleras.append(kit.elipsoide((x + lado * 0.020, 0.076, 0.552), (0.036, 0.016, 0.032)))
    rodilleras.append(kit.cono((x, 0.076, 0.548), (x, 0.076, 0.492), 0.048, 0.003, seg=16))
partes.append((kit.fundir("rodilleras", rodilleras, VERDE, voxel=0.0045, suavizado=3, caras=2500), "piernas"))
# Las botas hasta la rodilla.
botas = []
for lado in (-1, 1):
    x = lado * 0.12
    botas.append(kit.capsula((x, -0.004, 0.47), (x, 0.0, 0.12), 0.074, 0.064))
    botas.append(kit.elipsoide((x, -0.012, 0.36), (0.074, 0.078, 0.10)))
    botas += kit.zapato(lado, largo=0.118, ancho=0.066, alto=0.058)
partes.append((kit.fundir("botas", botas, BOTAS, voxel=0.006, suavizado=6, caras=4500), "pies"))

# -------------------------------------------------------------------- Skins
#
#   vampiro  el DIO vampiro de Phantom Blood: "un abrigo oscuro con plumas en los hombros",
#            largo, y el pecho al aire debajo.
#   cielo    Mas alla del cielo: el abrigo largo blanco con los bordes dorados y el halo.
#   piedra   "La mascara lo tomo entero": la Mascara de Piedra puesta, con sus colmillos.
#   dorado   la corona.         phantom  el Dio de 1880: la casaca larga y el pañuelo al
#            cuello, y sin la vincha de corazon (es de la parte 3).
import math
TELA = kit.material("tela", (0.09, 0.10, 0.19))
CORONA = kit.material("corona", (1.00, 0.84, 0.32), metal=0.8, rugosidad=0.25)
HALO = kit.material("neon_halo", (1.00, 0.86, 0.40))
PIEDRA = kit.material("mascara", (0.62, 0.60, 0.55), rugosidad=0.9)
HUECO = kit.material("mascara_ojos", (0.10, 0.09, 0.08))
BLANCO = kit.material("bufanda", (0.95, 0.94, 0.90))
ORO_BORDE = kit.material("detalle_borde", (1.00, 0.82, 0.30), metal=0.6)

LARGO = [(0.60, 0.214, 0.164), (0.80, 0.204, 0.156), (0.98, 0.192, 0.148), (1.15, 0.196, 0.150),
         (1.32, 0.224, 0.170), (1.46, 0.220, 0.162), (1.56, 0.168, 0.128)]


def abierto_v(x, y, z):
    return y > 0.0 and abs(x) < 0.080 + max(0.0, z - 1.0) * 0.08


# VAMPIRO: el abrigo oscuro largo, el cuello alto atras y las plumas en los hombros.
partes += kit.abrigo("abrigo", ["vampiro"], CAMPERA, LARGO, abierto_v, hombros=0.172, r_hombros=0.090)
plumas = []
for lado in (-1, 1):
    for k in range(9):
        a = math.radians(-70 + k * 17)
        base = (lado * (0.20 + 0.07 * math.cos(a)), 0.06 * math.sin(a) - 0.02, 1.53)
        punta = (lado * (0.30 + 0.12 * math.cos(a)), 0.10 * math.sin(a) - 0.04, 1.62 + 0.03 * (k % 3))
        plumas += kit.tubo([base, ((base[0] + punta[0]) / 2, (base[1] + punta[1]) / 2, (base[2] + punta[2]) / 2 + 0.02),
                            punta], [0.026, 0.020, 0.004], seg=10)
plumas += kit.tubo([(-0.10, -0.06, 1.56), (0.0, -0.08, 1.66), (0.10, -0.06, 1.56)], [0.040, 0.050, 0.040])
partes.append((kit.fundir(kit.de_skin("plumas", "vampiro"), plumas, TELA, voxel=0.005, suavizado=3, caras=5000), "torso"))
# CIELO: el abrigo blanco largo con los bordes de oro, y el halo.
cielo = kit.abrigo("abrigo_blanco", ["cielo"], CAMPERA, LARGO, abierto_v, hombros=0.172, r_hombros=0.090)
partes += cielo
bordes = []
for lado in (-1, 1):
    bordes.append([kit.pegar(cielo[0][0], (lado * (0.080 + max(0.0, z - 1.0) * 0.08 + 0.006), 0.3, z), 0.004)
                   for z in (1.55, 1.40, 1.25, 1.10, 1.0)])
    bordes.append([kit.pegar(cielo[1][0], (lado * 0.086, 0.3, z), 0.004) for z in (0.99, 0.85, 0.70, 0.62)])
bordes.append([kit.pegar(cielo[1][0], (math.sin(a) * 0.30, math.cos(a) * 0.30, 0.625), 0.004)
               for a in [math.radians(20 + i * 16) for i in range(21)]])
partes.append((kit.lineas(kit.de_skin("borde_oro", "cielo"), bordes, 0.008, ORO_BORDE), "por_distancia"))
halo = []
for k in range(32):
    a, b = 2 * math.pi * k / 32, 2 * math.pi * (k + 1) / 32
    halo.append(kit.capsula((math.sin(a) * 0.15, math.cos(a) * 0.15 - 0.05, 2.10),
                            (math.sin(b) * 0.15, math.cos(b) * 0.15 - 0.05, 2.10), 0.012, seg=8))
partes.append((kit.fundir(kit.de_skin("halo", "cielo"), halo, HALO, voxel=0.004, suavizado=2, caras=2000), "cabeza"))
# PIEDRA: la Mascara de Piedra sobre la cara: la frente con su cresta, los huecos de los
# ojos, los colmillos de abajo y las puntas alrededor.
cara_mascara = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.150 + 0.016, alto=0.180 + 0.016, fondo=0.158 + 0.016,
                                 mandibula=1.08, nariz=1.3, menton=1.05, orejas=False)
cara_mascara.append(kit.capsula((-0.09, 0.15, 1.875), (0.09, 0.15, 1.875), 0.020))
mp = kit.cascara(kit.de_skin("mascara_piedra", "piedra"), cara_mascara, PIEDRA,
                 lambda x, y, z: y > 0.04 and 1.66 < z < 1.95, grosor=0.016, voxel=0.005, caras=5000)
kit.pintar(mp, HUECO, lambda x, y, z: abs(abs(x) - 0.062) < 0.030 and abs(z - 1.815) < 0.020)
partes.append((mp, "cabeza"))
puntas = []
for lado in (-1, 1):
    for t, (x, z) in enumerate(((0.050, 1.665), (0.090, 1.690), (0.140, 1.760), (0.150, 1.860), (0.110, 1.930))):
        b = kit.pegar(mp, (lado * x, 0.3, z), 0.0)
        largo = 0.035 if t else 0.028
        puntas.append(kit.cono(b, (b[0] + lado * largo * 0.6, b[1] + 0.012, b[2] - largo if t < 2 else b[2] + largo * 0.4),
                               0.008, 0.001, seg=8))
partes.append((kit.pieza_fija(kit.de_skin("mascara_puntas", "piedra"), puntas, PIEDRA), "cabeza"))
# DORADO: la corona, con sus puntas, sobre el pelo.
corona = []
for k in range(36):
    a, b = 2 * math.pi * k / 36, 2 * math.pi * (k + 1) / 36
    corona.append(kit.capsula((math.sin(a) * 0.165, math.cos(a) * 0.168 - 0.030, 1.985),
                              (math.sin(b) * 0.165, math.cos(b) * 0.168 - 0.030, 1.985), 0.016, seg=8))
for k in range(8):
    a = 2 * math.pi * k / 8
    corona.append(kit.cono((math.sin(a) * 0.165, math.cos(a) * 0.168 - 0.030, 1.995),
                           (math.sin(a) * 0.172, math.cos(a) * 0.176 - 0.030, 2.075), 0.024, 0.003, seg=8))
partes.append((kit.fundir(kit.de_skin("corona", "dorado"), corona, CORONA, voxel=0.004, suavizado=2, caras=3500), "cabeza"))
# PHANTOM BLOOD: la casaca larga de 1880 y el pañuelo blanco al cuello.
partes += kit.abrigo("casaca", ["phantom"], CAMPERA, LARGO,
                     lambda x, y, z: y > 0.0 and abs(x) < 0.050 + max(0.0, 1.10 - z) * 0.35, hombros=0.172, r_hombros=0.090)
panuelo = [kit.capsula((-0.075, 0.020, 1.570), (0.075, 0.020, 1.570), 0.040),
           kit.elipsoide((0, 0.110, 1.500), (0.050, 0.035, 0.070)),
           kit.elipsoide((0, 0.120, 1.420), (0.040, 0.028, 0.060))]
partes.append((kit.fundir(kit.de_skin("bufanda", "phantom"), panuelo, BLANCO, voxel=0.005, suavizado=5, caras=3000), "torso"))

for obj, _r in partes:
    if obj.name in ("campera", "cuello", "hombrera_l", "hombrera_r"):
        kit.ocultar_en(obj, "vampiro", "cielo", "phantom")
    elif obj.name == "banda":
        kit.ocultar_en(obj, "phantom")

# ------------------------------------------------------------------ Esqueleto
arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla.startswith("hombro_"):
        kit.pesar(obj, arm, J, solo=regla)
    elif regla == "por_distancia":
        kit.pesar(obj, arm, J, permitidos=["torso", "pierna_l", "pierna_r"])
kit.pesar_estandar([p for p in partes if not p[1].startswith("hombro_") and p[1] != "por_distancia"], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.062, 1.815,
                         ojos_extra={"alto": 0.050, "ancho": 0.060, "iris": [0.62, 0.20, 0.16], "pestanas": False,
                                     "formas": {"dio_piedra": {"oculto": True}}},
                         cejas={"alto": 0.040, "color": [0.80, 0.62, 0.20], "largo": 0.058},
                         boca_z=1.697, boca_extra={"ancho": 0.060, "dientes": False})
kit.exportar("dio", arm, cara)
