"""Scorpion (Hanzo Hasashi), segun las notas de su modelo anterior (el traje de MK9).

La capucha negra con la ventana de los ojos, la mascara amarilla de la nariz para abajo con
la costura del medio y los ojos blancos sin pupila; el chaleco amarillo en V con los bordes
negros sobre la ropa negra, las hombreras, el cinturon negro ancho con el faldon amarillo
adelante y atras; los protectores amarillos de antebrazos y canillas con sus correas, los
guantes y los tabi negros. El kunai con la soga enrollada a la cadera derecha y la espada a
la espalda, con el mango asomando sobre el hombro derecho. LA SILUETA ES LA CAPUCHA Y LA
ESPADA. Las piezas "mascara..." son las que el juego saca para mostrar la calavera.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.84, 0.66, 0.52))
CAPUCHA = kit.material("capucha", (0.07, 0.07, 0.08))
MASCARA = kit.material("mascara", (0.97, 0.77, 0.19))
TRAJE = kit.material("traje~cuerpo", (0.95, 0.74, 0.12))
ROPA = kit.material("ropa~acento", (0.08, 0.08, 0.09))
PANTALON = kit.material("pantalon", (0.10, 0.10, 0.11))
TABI = kit.material("zapatos", (0.06, 0.06, 0.07))
SOGA = kit.material("soga", (0.52, 0.40, 0.25))
METAL = kit.material("metal", (0.76, 0.76, 0.80), metal=0.8, rugosidad=0.3)

partes = []

# -------------------------------------------------------------------- Cabeza
def craneo(extra=0.0):
    c = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.142 + extra, alto=0.180 + extra, fondo=0.152 + extra,
                          mandibula=0.95, nariz=1.0, orejas=extra == 0.0)
    c.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.058 + extra))
    return c


cabeza = kit.fundir("cabeza", craneo(), PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))
# LA CAPUCHA: toda la cabeza y el cuello, menos la ventana de los ojos.
capucha = kit.cascara("capucha", craneo(0.013) + [kit.elipsoide((0, -0.035, 1.700), (0.150, 0.150, 0.150))], CAPUCHA,
                      lambda x, y, z: z > 1.50 and not (y > 0.04 and 1.772 < z < 1.856 and abs(x) < 0.118),
                      grosor=0.012, voxel=0.006, caras=8000)
partes.append((capucha, "cabeza"))
# LA MASCARA: de la nariz para abajo, envolviendo hasta las orejas, con la costura del medio.
mascara = kit.cascara("mascara", craneo(0.022) + [kit.elipsoide((0, 0.172, 1.755), (0.030, 0.026, 0.032))], MASCARA,
                      lambda x, y, z: y > -0.03 and 1.60 < z < 1.772, grosor=0.012, voxel=0.005, caras=6000)
partes.append((mascara, "cabeza"))
costura = [kit.superficie(mascara, 0.0, z)[0] for z in (1.768, 1.74, 1.71, 1.68, 1.65, 1.625)]
partes.append((kit.lineas("mascara_costura", [[tuple(p) for p in costura]], 0.0045, ROPA), "cabeza"))

# -------------------------------------------------------------------- Torso
perfil = [(0.90, 0.170, 0.122), (1.05, 0.166, 0.118), (1.20, 0.180, 0.126), (1.36, 0.202, 0.134),
          (1.46, 0.200, 0.128), (1.53, 0.154, 0.108)]


def torso(extra=0.0):
    t = kit.perfil([(z, a + extra, f + extra) for z, a, f in perfil])
    t.append(kit.capsula((-0.168, 0.0, 1.47), (0.168, 0.0, 1.47), 0.076 + extra))
    for lado in (-1, 1):
        t.append(kit.elipsoide((lado * 0.085, 0.084 + extra, 1.385), (0.095, 0.052, 0.068)))
    return t


ropa = torso() + [kit.capsula((0, -0.008, 1.50), (0, -0.006, 1.57), 0.080, 0.078)]
partes.append((kit.fundir("ropa", ropa, ROPA, voxel=0.006, suavizado=8, caras=9000), "torso"))


def v_abierta(z):
    """El ancho de la V del chaleco a esa altura."""
    return max(0.0, (z - 1.18) * 0.36)


def chaleco(x, y, z):
    if not (0.98 < z < 1.545):
        return False
    if y > 0.0 and abs(x) < v_abierta(z):
        return False
    return not (abs(x) > 0.172 and z < 1.50)


partes.append((kit.cascara("chaleco", torso(0.012), TRAJE, chaleco, grosor=0.012, caras=8000), "torso"))
partes.append((kit.cascara("bordes", torso(0.020), ROPA,
                           lambda x, y, z: y > 0.0 and 1.18 < z < 1.545 and v_abierta(z) <= abs(x) < v_abierta(z) + 0.024,
                           grosor=0.010, caras=3000), "torso"))
for lado in (-1, 1):
    s = "l" if lado < 0 else "r"
    hombrera = [kit.cascara("hombrera_%s" % s, [kit.elipsoide((lado * 0.290, 0.0, 1.465), (0.128, 0.136, 0.100))], TRAJE,
                            lambda x, y, z: z > 1.395 and abs(x) > 0.205, grosor=0.014, caras=2500),
                kit.cascara("correa_%s" % s, [kit.elipsoide((lado * 0.290, 0.0, 1.465), (0.134, 0.142, 0.106))], ROPA,
                            lambda x, y, z: z > 1.395 and abs(abs(x) - 0.300) < 0.016, grosor=0.010, caras=800)]
    for o in hombrera:
        partes.append((o, "hombro_" + s))
# El cinturon negro y el faldon amarillo, adelante y atras, con el ribete negro abajo.
partes.append((kit.fundir("cinturon", [kit.elipsoide((0, 0.0, 1.000), (0.186, 0.140, 0.058))], ROPA, voxel=0.005,
                          suavizado=4, caras=3000), "torso"))
falda = [kit.capsula((0, 0.0, 0.99), (0, 0.0, 0.66), 0.190, 0.220, seg=48)]


def faldon(x, y, z):
    a = abs(math.degrees(math.atan2(x, y)))
    return 0.680 < z < 0.975 and math.hypot(x, y) > 0.17 and (a < 34 or a > 146)


fl = kit.cascara("faldon", falda, TRAJE, faldon, grosor=0.012, caras=4000)
kit.cortar(fl, (0, 0, 0.715))
kit.pintar(fl, ROPA, lambda x, y, z: z < 0.715)
partes.append((fl, "cadera"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.068, r_codo=0.058, r_muneca=0.050, hasta=0.875)
    mangas += kit.mano(lado, r=0.048, guante=1.08)
partes.append((kit.fundir("mangas", mangas, ROPA, voxel=0.0055, suavizado=6, caras=7000), "brazos"))
for lado in (-1, 1):
    s = "l" if lado < 0 else "r"
    x = J["codo_" + s][0]
    guarda = kit.cascara("guarda_%s" % s, kit.tubo([(x, 0, 1.10), (x, 0, 0.900)], [0.072, 0.064]), TRAJE,
                         lambda x_, y, z: 0.905 < z < 1.095, grosor=0.012, caras=2000)
    correas = kit.cascara("correas_%s" % s, kit.tubo([(x, 0, 1.10), (x, 0, 0.900)], [0.078, 0.070]), ROPA,
                          lambda x_, y, z: abs(z - 1.05) < 0.011 or abs(z - 0.95) < 0.011, grosor=0.008, caras=1200)
    for o in (guarda, correas):
        partes.append((o, "codo_" + s))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.95), (0.155, 0.108, 0.080))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.084, r_rodilla=0.068, r_tobillo=0.056, hasta=0.13)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
for lado in (-1, 1):
    s = "l" if lado < 0 else "r"
    x = lado * 0.12
    canillera = kit.cascara("canillera_%s" % s, kit.tubo([(x, 0.008, 0.52), (x, 0.004, 0.17)], [0.076, 0.066]), TRAJE,
                            lambda x_, y, z: y > -0.010 and 0.18 < z < 0.50, grosor=0.012, caras=2000)
    correas = kit.cascara("correas_c_%s" % s, kit.tubo([(x, 0.008, 0.52), (x, 0.004, 0.17)], [0.082, 0.072]), ROPA,
                          lambda x_, y, z: abs(z - 0.43) < 0.012 or abs(z - 0.26) < 0.012, grosor=0.008, caras=1200)
    for o in (canillera, correas):
        partes.append((o, "rodilla_" + s))
tabi = []
for lado in (-1, 1):
    tabi += kit.zapato(lado, largo=0.118, ancho=0.058, alto=0.050, punta=0.95)
partes.append((kit.fundir("tabi", tabi, TABI, voxel=0.006, suavizado=6, caras=3500), "pies"))

# ----------------------------------------------------- El kunai y la espada
# La soga enrollada en la cadera derecha, en vueltas, y el kunai colgando.
soga = []
for vuelta in range(3):
    pts = []
    for k in range(25):
        a = 2 * math.pi * k / 24
        pts.append((0.212 + vuelta * 0.012, 0.025 + math.cos(a) * 0.060, 0.930 + math.sin(a) * 0.060))
    soga += kit.tubo(pts, [0.011] * len(pts), seg=8)
partes.append((kit.fundir("soga", soga, SOGA, voxel=0.004, suavizado=2, caras=4000), "torso"))
kunai = [kit.elipsoide((0.226, 0.045, 0.800), (0.008, 0.022, 0.060), seg=16),
         kit.capsula((0.226, 0.045, 0.860), (0.226, 0.045, 0.905), 0.008),
         kit.elipsoide((0.226, 0.045, 0.915), (0.004, 0.014, 0.014), seg=12)]
partes.append((kit.fundir("kunai", kunai, METAL, voxel=0.0025, suavizado=1, caras=2000), "torso"))
# La espada a la espalda: del hombro derecho a la cadera izquierda.
c = (0.0, -0.172, 1.30)
e = (math.sin(math.radians(35)), 0.0, math.cos(math.radians(35)))


def sobre_eje(t):
    return (c[0] + e[0] * t, c[1], c[2] + e[2] * t)


vaina = [kit.caja(c, (0.046, 0.034, 0.72), rot=(0, 35, 0))]
partes.append((kit.fundir("vaina", vaina, ROPA, voxel=0.004, suavizado=3, caras=2000), "torso"))
guarda = [kit.elipsoide(sobre_eje(0.372), (0.050, 0.044, 0.008), rot=(0, 35, 0), seg=24),
          kit.elipsoide(sobre_eje(0.575), (0.026, 0.026, 0.012), rot=(0, 35, 0), seg=16)]
partes.append((kit.fundir("guarda", guarda, METAL, voxel=0.003, suavizado=2, caras=1500), "torso"))
mango = [kit.capsula(sobre_eje(0.38), sobre_eje(0.57), 0.021)]
partes.append((kit.fundir("mango", mango, TRAJE, voxel=0.004, suavizado=3, caras=1200), "torso"))
envoltura = []
for k in range(6):
    t = 0.395 + k * 0.030
    a, b = sobre_eje(t), sobre_eje(t + 0.022)
    envoltura.append([(a[0] - 0.022 * e[2], a[1] - 0.004, a[2] + 0.022 * e[0]),
                      (b[0] + 0.022 * e[2], b[1] - 0.012, b[2] - 0.022 * e[0])])
partes.append((kit.lineas("envoltura", envoltura, 0.0045, ROPA), "torso"))

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla.startswith(("hombro_", "codo_", "rodilla_")):
        kit.pesar(obj, arm, J, solo=regla)
kit.pesar_estandar([p for p in partes if not p[1].startswith(("hombro_", "codo_", "rodilla_"))], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.056, 1.814,
                         ojos_extra={"alto": 0.034, "ancho": 0.056, "iris": [1.0, 0.98, 0.90], "estilo": "brillo"})
kit.exportar("scorpion", arm, cara)
