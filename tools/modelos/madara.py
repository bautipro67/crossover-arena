"""Madara Uchiha, con la armadura de la guerra, segun las notas de su modelo anterior
(Narutopedia).

Pelo negro con reflejo azul, en puntas y hasta la cintura, con un flequillo a los costados
de la cara y un mechon que le tapa casi todo el ojo derecho; armadura carmesi de placas en
el pecho, los hombros, la cintura y los muslos; abajo, el manto azul de cuello alto y
mangas largas; pantalon azul, vendas en las canillas y sandalias azul oscuro; obi marron
claro con un cinturon lila; y el gunbai gris violaceo con una cadena negra. Ojos con el
Sharingan. LA SILUETA ES LA MELENA: de espaldas, que es como se lo ve casi toda la partida,
es lo primero que lo distingue.

Madara Joven (forma "sin_armadura") es el manto del clan sin las placas: todas las placas
son objetos "__sin_sin_armadura".
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

PIEL = kit.material("piel", (0.96, 0.88, 0.80))
PELO = kit.material("pelo", (0.06, 0.07, 0.12), rugosidad=0.5)
MANTO = kit.material("cuerpo", (0.15, 0.19, 0.40))
ARMADURA = kit.material("armadura~acento", (0.66, 0.10, 0.12), rugosidad=0.4)
OBI = kit.material("obi", (0.66, 0.53, 0.38))
CINTURON = kit.material("cinturon", (0.66, 0.56, 0.78))
PANTALON = kit.material("pantalon", (0.13, 0.17, 0.36))
VENDAS = kit.material("vendas", (0.90, 0.88, 0.82))
SANDALIAS = kit.material("sandalias", (0.10, 0.12, 0.24))
GUNBAI = kit.material("gunbai", (0.47, 0.43, 0.55), rugosidad=0.45)
NEGRO = kit.material("cadena", (0.07, 0.07, 0.08), metal=0.3)

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.140, alto=0.182, fondo=0.152, mandibula=0.90, nariz=1.0,
                        menton=1.05)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.054))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))

# EL PELO. El casquete, la coronilla erizada, la melena hasta la cintura abierta en abanico
# y con puntas que salen a los costados, el flequillo largo que enmarca la cara y el mechon
# sobre el ojo derecho (el derecho del personaje es +X).
pelo = [kit.elipsoide((0, -0.025, 1.865), (0.160, 0.168, 0.152)),
        kit.elipsoide((0, -0.130, 1.760), (0.165, 0.110, 0.170))]
for k in range(7):
    a = -1.2 + k * 0.4
    dx = math.sin(a)
    pelo += kit.tubo([(dx * 0.08, -0.03, 1.95), (dx * 0.23, -0.13, 2.03 + math.cos(a) * 0.04)], [0.062, 0.006])
for k in range(11):
    t = -1.0 + k / 5.0
    largo = 0.07 * abs(t) + (0.06 if k % 2 else 0.0)
    pelo += kit.tubo([(t * 0.12, -0.12, 1.86), (t * 0.20, -0.24, 1.62), (t * 0.26, -0.27, 1.38),
                      (t * 0.31, -0.23, 1.08 + largo)], [0.080, 0.086, 0.062, 0.008])
for z in (1.72, 1.55, 1.38, 1.22):
    for lado in (-1, 1):
        pelo += kit.tubo([(lado * 0.20, -0.23, z), (lado * 0.35, -0.21, z - 0.11)], [0.050, 0.006])
for k in range(6):
    x = -0.15 + k * 0.06
    z = 1.55 - (k % 3) * 0.12
    pelo += kit.tubo([(x, -0.30, z), (x * 1.1, -0.38, z - 0.16)], [0.040, 0.006])
for lado in (-1, 1):
    pelo += kit.tubo([(lado * 0.125, 0.07, 1.93), (lado * 0.160, 0.085, 1.78), (lado * 0.166, 0.062, 1.60),
                      (lado * 0.172, 0.035, 1.47)], [0.042, 0.040, 0.032, 0.006])
pelo += kit.tubo([(0.0, 0.135, 1.97), (0.045, 0.172, 1.88), (0.068, 0.170, 1.79), (0.082, 0.150, 1.72)],
                 [0.040, 0.036, 0.028, 0.006])
pelo += kit.tubo([(-0.03, 0.140, 1.97), (-0.07, 0.165, 1.90), (-0.10, 0.150, 1.84)], [0.032, 0.024, 0.005])
partes.append((kit.fundir("pelo", pelo, PELO, voxel=0.0058, suavizado=4, caras=14000), "cabeza"))

# -------------------------------------------------------------------- Torso
# El manto azul, con el cuello alto hasta la barbilla.
torso = kit.torso_humano(pecho=0.192, cintura=0.168, fondo=0.128, hombros=0.170)
torso.append(kit.capsula((0, -0.005, 1.50), (0, -0.005, 1.585), 0.090, 0.088))
partes.append((kit.fundir("manto", torso, MANTO, voxel=0.006, suavizado=8, caras=9000), "torso"))
# El obi marron claro y, arriba, el cinturon lila.
partes.append((kit.fundir("obi", [kit.elipsoide((0, 0.0, 1.040), (0.182, 0.142, 0.050))], OBI,
                          voxel=0.005, suavizado=4, caras=3000), "torso"))
partes.append((kit.fundir("cinturon", [kit.elipsoide((0, 0.0, 1.098), (0.180, 0.140, 0.015))], CINTURON,
                          voxel=0.004, suavizado=3, caras=2500), "torso"))

# LA ARMADURA. El peto en tres placas horizontales con su canto, recortadas de un torso
# inflado; las hombreras en dos laminas que caen hacia afuera; las placas de la cintura en
# abanico alrededor de la cadera; y las de los muslos.
for k, (z0, z1) in enumerate(((1.370, 1.520), (1.255, 1.355), (1.140, 1.240))):
    def banda(x, y, z, z0=z0, z1=z1):
        if not (z0 < z < z1):
            return False
        # Los huecos de los brazos, y el cuello.
        if z > 1.35 and abs(x) > 0.180:
            return False
        return not (z > 1.47 and math.hypot(x, y) < 0.105)
    # De un perfil recto y apenas inflado: con el torso de elipsoides cada placa salia como
    # un rollo inflado.
    inflado = kit.perfil([(1.10, 0.186, 0.140), (1.20, 0.194, 0.144), (1.33, 0.212, 0.150), (1.45, 0.212, 0.146),
                          (1.53, 0.170, 0.124)])
    inflado.append(kit.capsula((-0.160, 0.0, 1.47), (0.160, 0.0, 1.47), 0.088))
    placa = kit.cascara("peto_%d__sin_sin_armadura" % k, inflado, ARMADURA, banda, grosor=0.013, caras=5000)
    partes.append((placa, "torso"))
for lado in (-1, 1):
    s = "l" if lado < 0 else "r"
    cap = kit.cascara("hombrera_%s__sin_sin_armadura" % s,
                      [kit.elipsoide((lado * 0.290, 0.0, 1.450), (0.135, 0.140, 0.080))], ARMADURA,
                      lambda x, y, z: z > 1.400 and abs(x) > 0.205, grosor=0.014, caras=2500)
    lam = kit.cascara("lamina_%s__sin_sin_armadura" % s,
                      [kit.elipsoide((lado * 0.312, 0.0, 1.395), (0.145, 0.148, 0.078))], ARMADURA,
                      lambda x, y, z: 1.335 < z < 1.400 and abs(x) > 0.255, grosor=0.014, caras=2500)
    for o in (cap, lam):
        partes.append((o, "hombro_" + s))
# Las placas de la cintura, largas hasta la mitad del muslo (las del muslo de la referencia):
# nueve, en abanico, con una ranura entre cada una.
falda = [kit.capsula((0, 0.0, 1.03), (0, 0.0, 0.62), 0.200, 0.250, seg=48)]


def sector(x, y, z):
    if not (0.640 < z < 1.010) or math.hypot(x, y) < 0.19:
        return False
    a = (math.atan2(x, y) / (2 * math.pi) * 9.0 + 0.5) % 1.0
    return 0.06 < a < 0.94


partes.append((kit.cascara("faldon__sin_sin_armadura", falda, ARMADURA, sector, grosor=0.014, caras=6000),
               "cadera"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    mangas += kit.brazo(lado, r_hombro=0.066, r_codo=0.060, r_muneca=0.058, hasta=0.880)
partes.append((kit.fundir("mangas", mangas, MANTO, voxel=0.006, suavizado=6, caras=4500), "brazos"))
manos = []
for lado in (-1, 1):
    manos += kit.mano(lado, r=0.044)
partes.append((kit.fundir("manos", manos, PIEL, voxel=0.005, suavizado=5, caras=4000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.97), (0.170, 0.125, 0.090))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.084, r_rodilla=0.068, r_tobillo=0.058, hasta=0.40)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
# Las vendas: vueltas un poco inclinadas, una encima de la otra, de la canilla al tobillo.
vendas = []
for lado in (-1, 1):
    x = lado * 0.12
    for k in range(7):
        z = 0.425 - k * 0.043
        r = 0.054 - k * 0.0016
        vendas.append(kit.capsula((x, -0.012 * lado, z + 0.016), (x, 0.012 * lado, z - 0.016), r, seg=20))
partes.append((kit.fundir("vendas", vendas, VENDAS, voxel=0.0045, suavizado=2, caras=5000), "pies"))
# Las sandalias: la suela, las tiras del empeine y del tobillo; y el pie, a la vista.
pies = []
for lado in (-1, 1):
    pies += kit.zapato(lado, largo=0.108, ancho=0.050, alto=0.040, punta=0.95)
partes.append((kit.fundir("pies", pies, PIEL, voxel=0.005, suavizado=5, caras=3000), "pies"))
sandalias = []
for lado in (-1, 1):
    x = lado * 0.12
    sandalias.append(kit.elipsoide((x, 0.020, 0.034), (0.062, 0.135, 0.016)))
    sandalias.append(kit.capsula((x - 0.052, 0.050, 0.070), (x + 0.052, 0.050, 0.070), 0.014))
    sandalias.append(kit.capsula((x - 0.052, -0.030, 0.100), (x + 0.052, -0.030, 0.100), 0.013))
    sandalias.append(kit.capsula((x, -0.070, 0.050), (x, -0.050, 0.130), 0.016))
partes.append((kit.fundir("sandalias", sandalias, SANDALIAS, voxel=0.0045, suavizado=3, caras=3500), "pies"))

# ---------------------------------------------------------------- El gunbai
# En la mano derecha: el mango largo y la pala grande a la altura de la rodilla, de canto
# hacia el costado; el aro negro alrededor de la pala, la nervadura del medio y la cadena
# que cuelga de la punta del mango.
xm, ym = J["mano_r"][0], J["mano_r"][1]
gun = [kit.elipsoide((xm + 0.01, ym, 0.300), (0.020, 0.200, 0.235), seg=40)]
partes.append((kit.fundir("gunbai", gun, GUNBAI, voxel=0.005, suavizado=3, caras=4000), "codo_r"))
negro = [kit.capsula((xm, ym, 0.930), (xm + 0.01, ym, 0.520), 0.019)]
for k in range(40):
    a = k / 40.0 * 2 * math.pi
    b = (k + 1) / 40.0 * 2 * math.pi
    negro.append(kit.capsula((xm + 0.01, ym + math.sin(a) * 0.205, 0.300 + math.cos(a) * 0.240),
                             (xm + 0.01, ym + math.sin(b) * 0.205, 0.300 + math.cos(b) * 0.240), 0.016, seg=10))
negro.append(kit.capsula((xm + 0.01, ym, 0.520), (xm + 0.01, ym, 0.080), 0.012))
for k in range(9):
    z = 0.900 - k * 0.040
    negro.append(kit.elipsoide((xm - 0.030, ym + 0.020 + k * 0.004, z), (0.008, 0.014, 0.020) if k % 2 else
                               (0.014, 0.008, 0.020), seg=10))
partes.append((kit.fundir("cadena", negro, NEGRO, voxel=0.004, suavizado=2, caras=6000), "codo_r"))

# -------------------------------------------------------------------- Skins
#
#   rikudo   el jinchuriki del Diez Colas: los cuernos, el Rinne Sharingan en la frente,
#            las nueve esferas buscadoras de la verdad en anillo a la espalda, y el
#            Rinnegan en los dos ojos.
#   susanoo  envuelto en el chakra azul: las costillas del Susano'o alrededor del torso.
#   edo      el Edo Tensei: las grietas en la cara y en las manos, y el Rinnegan con el
#            blanco del ojo negro.
#   joven    sin armadura (la forma sin_armadura).
CUERNO = kit.material("cuernos", (0.92, 0.92, 0.94))
TERCER = kit.material("gema_tercer_ojo", (0.92, 0.10, 0.12))
ORBE = kit.material("orbes", (0.05, 0.05, 0.07), rugosidad=0.3)
SUSANOO = kit.material("neon_susanoo", (0.35, 0.55, 1.00))
GRIETA = kit.material("grietas", (0.25, 0.22, 0.24))
cuernos = []
for lado in (-1, 1):
    cuernos += kit.tubo([(lado * 0.045, 0.080, 1.965), (lado * 0.060, 0.050, 2.050), (lado * 0.050, 0.000, 2.110)],
                        [0.026, 0.018, 0.004], seg=12)
partes.append((kit.fundir(kit.de_skin("cuernos", "rikudo"), cuernos, CUERNO, voxel=0.004, suavizado=3, caras=2500), "cabeza"))
p, n = kit.superficie(cabeza, 0.0, 1.890)
c = tuple(p + n * 0.004)
tercero = [kit.elipsoide(c, (0.018, 0.006, 0.024), seg=18)]
kit.orientar(tercero, c, n)
partes.append((kit.fundir(kit.de_skin("tercer_ojo", "rikudo"), tercero, TERCER, voxel=0.0025, suavizado=1, caras=800), "cabeza"))
orbes = []
for k in range(9):
    a = 2 * math.pi * k / 9
    orbes.append(kit.elipsoide((math.cos(a) * 0.36, -0.36, 1.42 + math.sin(a) * 0.36), (0.048, 0.048, 0.048), seg=20))
partes.append((kit.fundir(kit.de_skin("orbes", "rikudo"), orbes, ORBE, voxel=0.005, suavizado=3, caras=4000), "torso"))
# SUSANOO: las costillas de chakra, arcos alrededor del pecho y la espalda.
costillas = []
for k in range(5):
    z = 1.46 - k * 0.075
    r = 0.300 - k * 0.012
    for lado in (-1, 1):
        costillas.append([(lado * math.sin(math.radians(a)) * r, math.cos(math.radians(a)) * r * 0.85 - 0.02, z - 0.02 * math.cos(math.radians(a)))
                          for a in range(20, 175, 12)])
costillas.append([(0.0, -0.27, 1.52 - t * 0.36) for t in (0.0, 0.33, 0.66, 1.0)])
partes.append((kit.lineas(kit.de_skin("costillas", "susanoo"), costillas, 0.018, SUSANOO), "torso"))
# EDO TENSEI: las grietas en la cara y en el dorso de las manos.
grietas = []
for x0, z0, pasos in ((-0.07, 1.78, ((-0.02, -0.03), (-0.01, -0.04), (-0.025, -0.03))),
                      (0.075, 1.77, ((0.02, -0.035), (0.0, -0.04))), (0.03, 1.92, ((0.015, -0.03), (-0.01, -0.025)))):
    pts = [(x0, 0.0, z0)]
    for dx, dz in pasos:
        pts.append((pts[-1][0] + dx, 0.0, pts[-1][2] + dz))
    linea = []
    for x, _y, z in pts:
        q, nq = kit.superficie(cabeza, x, z)
        if q is not None:
            linea.append(tuple(q + nq * 0.002))
    if len(linea) > 1:
        grietas.append(linea)
partes.append((kit.lineas(kit.de_skin("grietas", "edo"), grietas, 0.0035, GRIETA), "cabeza"))

arm = kit.esqueleto(J)
# Las hombreras van con el brazo y las musleras con el muslo, enteras.
for obj, regla in partes:
    if regla.startswith("hombro_") or regla.startswith("pierna_"):
        kit.pesar(obj, arm, J, solo=regla)
kit.pesar_estandar([p for p in partes if not p[1].startswith(("hombro_", "pierna_"))], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.055, 1.815,
                         ojos_extra={"alto": 0.050, "ancho": 0.058, "iris": [0.86, 0.06, 0.06], "estilo": "sharingan",
                                     "formas": {"madara_rikudo": {"estilo": "rinnegan"},
                                                "madara_edo": {"estilo": "rinnegan_edo"}}},
                         cejas={"alto": 0.036, "color": [0.06, 0.07, 0.12], "largo": 0.060},
                         boca_z=1.700, boca_extra={"ancho": 0.056, "dientes": False})
kit.exportar("madara", arm, cara)
