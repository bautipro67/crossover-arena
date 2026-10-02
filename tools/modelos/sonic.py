"""Sonic, segun las notas de su modelo anterior.

Proporcion de dibujo: la cabeza GRANDE, casi un tercio del cuerpo, un ovalo un poco mas
ancho que alto; las seis puas de la nuca barriendo hacia atras, casi horizontales, en
abanico y de tres largos; las dos espinas de la espalda y la cola corta; las orejas
triangulares con el interior durazno; los ojos verdes UNIDOS por el blanco; el hocico ancho
durazno con la nariz negra; los brazos y la panza durazno; los guantes blancos con el puño;
las piernas finas azules y las zapatillas rojas con la tira y el puño blancos. Todo lo azul
con el pelaje del juego (Art.pelaje). Formas: "super" (las puas se paran para arriba) y
"clasico" (el de 1991: las puas mas cortas).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
# Sonic es FINO de verdad: brazos y piernas de palito, lisos, y las manos y las
# zapatillas ya van a su tamaño de dibujo.
kit.FACTOR_BRAZO = kit.FACTOR_PIERNA = kit.FACTOR_MANO = kit.FACTOR_PIE = 1.0
kit.MUSCULOS = False
J = kit.juntas({"caderas": (0, 0, 0.74), "cabeza": (0, 0, 1.28),
                "hombro_r": (0.20, 0, 1.18), "codo_r": (0.23, 0, 0.97), "mano_r": (0.25, 0, 0.77),
                "pierna_r": (0.095, 0, 0.72), "rodilla_r": (0.10, 0, 0.40), "pie_r": (0.10, 0, 0.09)})

PELO = kit.material("pelo!pelaje", (0.13, 0.40, 0.86))
PUA = kit.material("pua!pelaje", (0.11, 0.35, 0.78))
CUERPO = kit.material("cuerpo!pelaje", (0.13, 0.40, 0.86))
PIERNAS = kit.material("pantalon!pelaje", (0.11, 0.33, 0.72))
PIEL = kit.material("piel", (0.99, 0.79, 0.58))
BLANCO = kit.material("blanco_ojos", (0.97, 0.97, 1.00))
NARIZ = kit.material("nariz", (0.10, 0.09, 0.11), rugosidad=0.3)
GUANTE = kit.material("guante", (0.97, 0.97, 0.98))
ZAPATOS = kit.material("zapatos", (0.87, 0.16, 0.14))
HEBILLA = kit.material("hebilla", (0.95, 0.78, 0.25), metal=0.7)

C = (0.0, 0.0, 1.54)
partes = []

# -------------------------------------------------------------------- Cabeza
cab = [kit.elipsoide(C, (0.245, 0.225, 0.232)),
       kit.capsula((0, -0.01, 1.24), (0, -0.01, 1.36), 0.060)]
cabeza = kit.fundir("cabeza", cab, PELO, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))
# El blanco que une los dos ojos, pegado a la cara.
p, n = kit.superficie(cabeza, 0.0, 1.585)
c = tuple(p + n * 0.002)
mancha = [kit.elipsoide((c[0] - 0.050, c[1], c[2]), (0.070, 0.016, 0.082)),
          kit.elipsoide((c[0] + 0.050, c[1], c[2]), (0.070, 0.016, 0.082)),
          kit.elipsoide((c[0], c[1], c[2] - 0.010), (0.060, 0.016, 0.055))]
kit.orientar(mancha, c, n)
mb = kit.fundir("blanco_ojos", mancha, BLANCO, voxel=0.004, suavizado=4, caras=3000)
partes.append((mb, "cabeza"))
# El hocico ancho y saliente, y la nariz.
partes.append((kit.fundir("hocico", [kit.elipsoide((0, 0.150, 1.452), (0.150, 0.115, 0.088)),
                                     kit.elipsoide((0, 0.205, 1.470), (0.090, 0.070, 0.060))], PIEL,
                          voxel=0.005, suavizado=6, caras=4000), "cabeza"))
partes.append((kit.fundir("nariz", [kit.elipsoide((0, 0.272, 1.500), (0.034, 0.026, 0.026))], NARIZ, voxel=0.003,
                          suavizado=3, caras=1200), "cabeza"))
# Las orejas: triangulos chicos arriba, con el interior durazno.
orejas, dentro = [], []
for lado in (-1, 1):
    orejas.append(kit.cono((lado * 0.115, -0.010, 1.700), (lado * 0.165, -0.025, 1.880), 0.066, 0.004))
    q = (lado * 0.128, 0.030, 1.765)
    d = [kit.elipsoide(q, (0.030, 0.010, 0.050), rot=(0, lado * -14, 0))]
    kit.orientar(d, q, (lado * 0.25, 1.0, 0.0))
    dentro += d
partes.append((kit.fundir("orejas", orejas, PUA, voxel=0.0045, suavizado=3, caras=2500), "cabeza"))
partes.append((kit.fundir("orejas_dentro", dentro, PIEL, voxel=0.0035, suavizado=2, caras=1200), "cabeza"))


def puas(estilo):
    """Las seis puas de la nuca. "normal": para atras, casi horizontales; "super": paradas;
    "clasico": las mismas, mas cortas."""
    tabla = [(0.00, 1.640, 0.66, 6, 0), (-0.09, 1.650, 0.60, 10, -20), (0.09, 1.650, 0.60, 10, 20),
             (-0.13, 1.545, 0.50, 22, -32), (0.13, 1.545, 0.50, 22, 32), (0.00, 1.470, 0.44, 28, 0)]
    piezas = []
    for x, z, largo, baja, giro in tabla:
        if estilo == "super":
            baja = -50 - (28 - baja)
            largo *= 0.95
        if estilo == "hyper":
            # Hyper Sonic: las puas paradas del todo, mas largas y mas abiertas.
            baja = -62 - (28 - baja) * 0.8
            giro *= 1.5
            largo *= 1.22
        if estilo == "clasico":
            largo *= 0.72
        b = kit.pegar(cabeza, (x, -0.30, z), -0.03)
        d = (math.sin(math.radians(giro)) * math.cos(math.radians(baja)),
             -math.cos(math.radians(giro)) * math.cos(math.radians(baja)), -math.sin(math.radians(baja)))
        medio = (b[0] + d[0] * largo * 0.5, b[1] + d[1] * largo * 0.5, b[2] + d[2] * largo * 0.5 + 0.025)
        punta = (b[0] + d[0] * largo, b[1] + d[1] * largo, b[2] + d[2] * largo)
        piezas += kit.tubo([b, medio, punta], [0.078, 0.050, 0.005])
    return piezas


partes.append((kit.fundir("puas__sin_super+clasico", puas("normal"), PUA, voxel=0.0058, suavizado=4, caras=7000),
               "cabeza"))
partes.append((kit.fundir("puas_super__f_super+oscuro", puas("super"), PUA, voxel=0.0058, suavizado=4, caras=7000),
               "cabeza"))
partes.append((kit.fundir(kit.de_skin("puas_hyper", "hyper"), puas("hyper"), PUA, voxel=0.0058, suavizado=4, caras=8000),
               "cabeza"))
partes.append((kit.fundir("puas_clasico__f_clasico", puas("clasico"), PUA, voxel=0.0058, suavizado=4, caras=6000),
               "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.perfil([(0.74, 0.118, 0.100), (0.86, 0.132, 0.112), (1.00, 0.140, 0.118), (1.12, 0.138, 0.112),
                    (1.22, 0.112, 0.092)])
torso.append(kit.capsula((-0.14, 0.0, 1.18), (0.14, 0.0, 1.18), 0.056))
cuerpo = kit.fundir("cuerpo", torso, CUERPO, voxel=0.005, suavizado=8, caras=8000)
# La panza durazno, una mancha que sigue la curva del cuerpo.
kit.pintar(cuerpo, PIEL, lambda x, y, z: y > 0.02 and (x / 0.098) ** 2 + ((z - 0.95) / 0.20) ** 2 < 1.0)
partes.append((cuerpo, "torso"))
espinas = []
for k, z in enumerate((1.12, 0.95)):
    b = kit.pegar(cuerpo, (0.0, -0.3, z), -0.02)
    espinas += kit.tubo([b, (0.0, b[1] - 0.14, z - 0.06)], [0.058, 0.005])
# La cola corta.
b = kit.pegar(cuerpo, (0.0, -0.3, 0.78), -0.02)
espinas += kit.tubo([b, (0.0, b[1] - 0.10, 0.75), (0.0, b[1] - 0.14, 0.72)], [0.055, 0.040, 0.006])
partes.append((kit.fundir("espinas", espinas, PUA, voxel=0.005, suavizado=3, caras=2500), "torso"))

# --------------------------------------------------------------------- Brazos
brazos = []
for lado in (-1, 1):
    brazos += kit.brazo(lado, r_hombro=0.040, r_codo=0.034, r_muneca=0.032, j=J, hasta=0.86)
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.0045, suavizado=5, caras=3500), "brazos"))
guantes = []
for lado in (-1, 1):
    guantes += kit.mano(lado, j=J, r=0.048, guante=1.45)
    m = J["mano_r" if lado > 0 else "mano_l"]
    guantes.append(kit.capsula((m[0], m[1], m[2] + 0.105), (m[0], m[1], m[2] + 0.070), 0.062, 0.056))
partes.append((kit.fundir("guantes", guantes, GUANTE, voxel=0.005, suavizado=6, caras=5000), "manos"))

# -------------------------------------------------------------------- Piernas
piernas = [kit.elipsoide((0, 0.0, 0.76), (0.115, 0.095, 0.060))]
for lado in (-1, 1):
    piernas += kit.pierna(lado, r_muslo=0.048, r_rodilla=0.042, r_tobillo=0.040, j=J, hasta=0.15)
partes.append((kit.fundir("piernas", piernas, PIERNAS, voxel=0.005, suavizado=6, caras=4500), "cadera"))
zapatos, blancos, hebillas = [], [], []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, j=J, largo=0.175, ancho=0.078, alto=0.072, punta=1.25)
    x = J["pie_r" if lado > 0 else "pie_l"][0]
    # El puño blanco arriba de la zapatilla y la tira cruzada sobre el empeine.
    blancos.append(kit.capsula((x, -0.012, 0.175), (x, -0.012, 0.145), 0.060))
    blancos.append(kit.caja((x, 0.055, 0.105), (0.162, 0.040, 0.040), rot=(-30, 0, 0)))
    hebillas.append(kit.caja((x + lado * 0.078, 0.050, 0.100), (0.012, 0.030, 0.030), rot=(-30, 0, 0)))
partes.append((kit.fundir("zapatillas", zapatos, ZAPATOS, voxel=0.006, suavizado=7, caras=5000), "pies"))
partes.append((kit.fundir("tiras", blancos, GUANTE, voxel=0.004, suavizado=3, caras=3000), "pies"))
partes.append((kit.fundir("hebillas", hebillas, HEBILLA, voxel=0.003, suavizado=1, caras=800), "pies"))

# -------------------------------------------------------------------- Skins
#
#   super / hyper  las puas paradas; las de Hyper, mas largas y abiertas (puas_hyper).
#   oscuro   negro con VETAS ROJAS: las vetas, a lo largo de cada pua.
#   metal    Metal Sonic: el reactor en el pecho, el propulsor en la espalda, las aletas de
#            metal en la cabeza y la cara sin boca.
#   boom     el de la serie: el pañuelo al cuello y las cintas en brazos y piernas.
Vector = kit.Vector
VETA = kit.material("vetas", (0.88, 0.13, 0.13))
METAL = kit.material("metal", (0.62, 0.66, 0.74), metal=0.8, rugosidad=0.3)
REACTOR = kit.material("neon_reactor", (1.00, 0.55, 0.20))
PANUELO = kit.material("bufanda", (0.82, 0.68, 0.46))
CINTA = kit.material("cinta", (0.92, 0.90, 0.84))
pu = [o for o, _r in partes if o.name.startswith("puas_super")][0]
vetas = []
for x, z, largo, baja, giro in [(0.00, 1.640, 0.66, 6, 0), (-0.09, 1.650, 0.60, 10, -20), (0.09, 1.650, 0.60, 10, 20),
                                (-0.13, 1.545, 0.50, 22, -32), (0.13, 1.545, 0.50, 22, 32)]:
    baja = -50 - (28 - baja)
    b = kit.pegar(cabeza, (x, -0.30, z), -0.03)
    d = (math.sin(math.radians(giro)) * math.cos(math.radians(baja)), -math.cos(math.radians(giro)) * math.cos(math.radians(baja)),
         -math.sin(math.radians(baja)))
    vetas.append([kit.pegar(pu, (b[0] + d[0] * largo * t, b[1] + d[1] * largo * t - 0.05, b[2] + d[2] * largo * t), 0.003)
                  for t in (0.15, 0.35, 0.55, 0.75)])
partes.append((kit.lineas(kit.de_skin("vetas", "oscuro"), vetas, 0.009, VETA), "cabeza"))
# METAL: el reactor redondo en el pecho, el propulsor atras y las aletas de la cabeza.
cu = [o for o, _r in partes if o.name == "cuerpo"][0]
p, n = kit.superficie(cu, 0.0, 1.06)
c = tuple(p + n * 0.006)
reactor = [kit.elipsoide(c, (0.062, 0.012, 0.062), seg=28)]
kit.orientar(reactor, c, n)
partes.append((kit.fundir(kit.de_skin("propulsor_reactor", "metal"), reactor, REACTOR, voxel=0.004, suavizado=2, caras=1500),
               "torso"))
p, n = kit.superficie(cu, 0.0, 1.10, desde=(0.0, -1.5), hacia=(0.0, 1.0))
metal = [kit.capsula(tuple(p + n * 0.03), tuple(p + n * 0.10), 0.050, 0.060),
         kit.capsula(tuple(p + n * 0.03 + Vector((0, 0, -0.10))), tuple(p + n * 0.09 + Vector((0, 0, -0.12))), 0.040, 0.046)]
anillo = []
for k in range(24):
    a, b2 = 2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24
    anillo.append(kit.capsula((c[0] + math.cos(a) * 0.066, c[1] + 0.004, c[2] + math.sin(a) * 0.066),
                              (c[0] + math.cos(b2) * 0.066, c[1] + 0.004, c[2] + math.sin(b2) * 0.066), 0.010, seg=6))
kit.orientar(anillo, c, n)
metal += anillo
for lado in (-1, 1):
    metal.append(kit.cono((lado * 0.10, 0.04, 1.73), (lado * 0.16, -0.02, 1.86), 0.030, 0.004, seg=10))
partes.append((kit.fundir(kit.de_skin("propulsor", "metal"), metal, METAL, voxel=0.004, suavizado=2, caras=4000), "torso"))
# BOOM: el pañuelo atado al cuello y las cintas de deporte.
panuelo = []
for k in range(24):
    a, b2 = 2 * math.pi * k / 24, 2 * math.pi * (k + 1) / 24
    panuelo.append(kit.capsula((math.sin(a) * 0.070, math.cos(a) * 0.066 - 0.010, 1.245),
                               (math.sin(b2) * 0.070, math.cos(b2) * 0.066 - 0.010, 1.245), 0.022, seg=8))
panuelo.append(kit.cono((0, 0.07, 1.24), (0, 0.10, 1.12), 0.060, 0.006, seg=16))
partes.append((kit.fundir(kit.de_skin("bufanda", "boom"), panuelo, PANUELO, voxel=0.004, suavizado=3, caras=2500), "torso"))
cintas = []
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    m = J["mano" + s]
    cintas.append(kit.capsula((m[0], m[1], m[2] + 0.13), (m[0], m[1], m[2] + 0.10), 0.040))
    r = J["rodilla" + s]
    for dz in (0.06, -0.06):
        cintas.append(kit.capsula((r[0], r[1], r[2] + dz + 0.012), (r[0], r[1], r[2] + dz - 0.012), 0.050))
partes.append((kit.fundir(kit.de_skin("cinta", "boom"), cintas, CINTA, voxel=0.004, suavizado=2, caras=3000), "por_distancia"))

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla == "por_distancia":
        kit.pesar(obj, arm, J)
partes = [p for p in partes if p[1] != "por_distancia"]
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(mb, J, 0.050, 1.592,
                         ojos_extra={"alto": 0.115, "ancho": 0.072, "iris": [0.20, 0.72, 0.30], "pestanas": False},
                         cejas={"alto": 0.072, "color": [0.10, 0.30, 0.70], "largo": 0.060})
# La boca va sobre el hocico, no sobre la mancha de los ojos.
hocico = [o for o, _r in partes if o.name == "hocico"][0]
p, n = kit.superficie(hocico, 0.0, 1.418)
cara["boca"] = {"pos": kit.a_juego(tuple(p + n * 0.003), J), "ancho": 0.090, "dientes": False,
                # Metal Sonic no tiene boca.
                "formas": {"sonic_metal": {"oculto": True}}}
kit.exportar("sonic", arm, cara)
