"""Spider-Man (el traje clasico), segun las notas de su modelo anterior.

Todo el cuerpo cubierto y marcado: rojo arriba —la mascara, los hombros, el panel del pecho
y de la espalda que se angosta hasta el cinturon— con los costados azules; la mascara con
los lentes blancos grandes de borde negro, inclinados; la telaraña negra sobre todo lo rojo,
saliendo del centro de la cara y del centro del pecho; la araña negra en el pecho; los
brazos con el antebrazo y el guante rojos; las piernas azules con las botas rojas. El traje
simbionte (forma "simbionte") la lleva grande y blanca adelante y atras. La telaraña es el
objeto "telarana", que el juego esconde en los trajes que no la tienen.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

kit.limpiar()
J = kit.juntas()

ROJO = kit.material("rojo~cuerpo", (0.82, 0.10, 0.12))
AZUL = kit.material("azul~pantalon", (0.12, 0.24, 0.66))
LINEAS = kit.material("lineas", (0.04, 0.04, 0.06))
LENTES = kit.material("lentes", (0.97, 0.97, 1.00))
EMBLEMA = kit.material("emblema", (0.04, 0.04, 0.06))

partes = []

# ------------------------------------------------------------------ Mascara
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.140, alto=0.180, fondo=0.150, mandibula=0.92, nariz=0.55,
                        orejas=False, menton=0.95)
cab.append(kit.capsula((0, -0.01, 1.47), (0, -0.01, 1.66), 0.056))
cabeza = kit.fundir("mascara", cab, ROJO, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))
# Los lentes: el borde negro grueso y el blanco adentro, en gota, con la punta de afuera
# para arriba.
bordes, lentes = [], []
for lado in (-1, 1):
    p, n = kit.superficie(cabeza, lado * 0.058, 1.815)
    c = tuple(p + n * 0.004)
    b = [kit.elipsoide(c, (0.064, 0.010, 0.045), rot=(0, -28 * lado, 0), seg=32)]
    w = [kit.elipsoide((c[0], c[1] + 0.006, c[2]), (0.054, 0.009, 0.035), rot=(0, -28 * lado, 0), seg=32)]
    kit.orientar(b, c, n)
    kit.orientar(w, c, n)
    bordes += b
    lentes += w
partes.append((kit.fundir("bordes_lentes", bordes, LINEAS, voxel=0.0035, suavizado=3, caras=3000), "cabeza"))
partes.append((kit.fundir("lentes", lentes, LENTES, voxel=0.0035, suavizado=3, caras=3000), "cabeza"))

# -------------------------------------------------------------------- Torso
perfil = [(0.90, 0.165, 0.118), (1.05, 0.160, 0.115), (1.20, 0.172, 0.122), (1.36, 0.196, 0.130),
          (1.46, 0.195, 0.124), (1.53, 0.150, 0.105)]
torso = kit.perfil(perfil)
torso.append(kit.capsula((-0.168, 0.0, 1.47), (0.168, 0.0, 1.47), 0.074))
for lado in (-1, 1):
    torso.append(kit.elipsoide((lado * 0.085, 0.082, 1.385), (0.095, 0.052, 0.068)))
    for z in (1.245, 1.175, 1.105):
        torso.append(kit.elipsoide((lado * 0.036, 0.094, z), (0.034, 0.028, 0.030)))
tr = kit.fundir("traje", torso, AZUL, voxel=0.0055, suavizado=8, caras=34000)


def es_rojo(x, y, z):
    """Lo rojo del torso: hombros y parte de arriba, el panel del medio y el cinturon."""
    return z > 1.43 or (z > 0.995 and abs(x) < 0.072 + (z - 0.98) * 0.28) or 0.955 < z <= 0.995


for zc in (1.43, 0.955, 0.995):
    kit.cortar(tr, (0, 0, zc))
kit.pintar(tr, ROJO, es_rojo)
partes.append((tr, "torso"))

# --------------------------------------------------------------------- Brazos
brazos = []
for lado in (-1, 1):
    brazos += kit.brazo(lado, r_hombro=0.066, r_codo=0.054, r_muneca=0.046, hasta=0.875)
    brazos += kit.mano(lado, r=0.046)
br = kit.fundir("brazos", brazos, AZUL, voxel=0.005, suavizado=6, caras=18000)
kit.cortar(br, (0, 0, 1.13))
kit.pintar(br, ROJO, lambda x, y, z: z < 1.13 or abs(x) >= 0.292)
partes.append((br, "brazos"))

# -------------------------------------------------------------------- Piernas
piernas = [kit.elipsoide((0, 0.0, 0.95), (0.150, 0.104, 0.080))]
for lado in (-1, 1):
    piernas += kit.pierna(lado, r_muslo=0.082, r_rodilla=0.062, r_tobillo=0.050, hasta=0.12)
    piernas += kit.zapato(lado, largo=0.115, ancho=0.056, alto=0.050)
pr = kit.fundir("piernas", piernas, AZUL, voxel=0.006, suavizado=8, caras=10000)
kit.cortar(pr, (0, 0, 0.33))
kit.pintar(pr, ROJO, lambda x, y, z: z < 0.33)
partes.append((pr, "cadera"))

# --------------------------------------------------------------- La telaraña
web = []


def esfera(c, r, th, ph):
    """Un punto de un elipsoide de centro c y radios r, con el polo ADELANTE (+Y)."""
    t, f = math.radians(th), math.radians(ph)
    d = (math.sin(t) * math.cos(f), math.cos(t), math.sin(t) * math.sin(f))
    return (c[0] + d[0] * r[0], c[1] + d[1] * r[1], c[2] + d[2] * r[2])


# En la cabeza: diez meridianos que salen del centro de la cara y siete vueltas, con la
# comba de la telaraña entre meridiano y meridiano.
CC, RC = (0.0, -0.005, 1.79), (0.155, 0.165, 0.200)
for k in range(10):
    web.append([kit.pegar(cabeza, esfera(CC, RC, th, k * 36)) for th in range(6, 176, 10)])
for th in (22, 44, 66, 88, 110, 132, 154):
    anillo = []
    for k in range(10):
        anillo.append(kit.pegar(cabeza, esfera(CC, RC, th, k * 36)))
        anillo.append(kit.pegar(cabeza, esfera(CC, RC, th - 5, k * 36 + 18)))
    anillo.append(anillo[0])
    web.append(anillo)


def sobre_torso(x, z, atras):
    p, n = kit.superficie(tr, x, z, desde=(0.0, -1.5 if atras else 1.5), hacia=(0.0, 1.0 if atras else -1.0))
    if p is None or not es_rojo(p.x, p.y, p.z):
        return None
    return tuple(p + n * 0.002)


def tramos(puntos):
    """Corta una polilinea donde sale de lo rojo."""
    salida, actual = [], []
    for p in puntos:
        if p is None:
            if len(actual) > 1:
                salida.append(actual)
            actual = []
        else:
            actual.append(p)
    if len(actual) > 1:
        salida.append(actual)
    return salida


# En el pecho y la espalda: rayos desde el centro y vueltas alrededor.
for atras, zc in ((False, 1.36), (True, 1.33)):
    for k in range(12):
        a = math.radians(k * 30 + 15)
        web += tramos([sobre_torso(math.cos(a) * r, zc + math.sin(a) * r * 1.3, atras)
                       for r in [i * 0.022 for i in range(1, 22)]])
    for r in (0.05, 0.10, 0.16, 0.23, 0.31):
        anillo = []
        for k in range(25):
            a = math.radians(k * 15)
            rr = r * (0.94 if k % 2 else 1.0)
            anillo.append(sobre_torso(math.cos(a) * rr, zc + math.sin(a) * rr * 1.3, atras))
        web += tramos(anillo)
# En los antebrazos y las botas: vueltas y lineas a lo largo.
for lado in (-1, 1):
    s = "_l" if lado < 0 else "_r"
    x0 = J["codo" + s][0]
    for z in (1.08, 1.03, 0.98, 0.93, 0.885):
        web.append([kit.pegar(br, (x0 + math.cos(a) * 0.08, math.sin(a) * 0.08, z))
                    for a in [i * math.pi / 6 for i in range(13)]])
    for k in range(8):
        a = k * math.pi / 4
        web.append([kit.pegar(br, (x0 + math.cos(a) * 0.08, math.sin(a) * 0.08, z / 100.0)) for z in range(112, 86, -3)])
    x0 = lado * 0.12
    for z in (0.30, 0.25, 0.20, 0.15):
        web.append([kit.pegar(pr, (x0 + math.cos(a) * 0.08, math.sin(a) * 0.08, z))
                    for a in [i * math.pi / 6 for i in range(13)]])
    for k in range(8):
        a = k * math.pi / 4
        web.append([kit.pegar(pr, (x0 + math.cos(a) * 0.08, math.sin(a) * 0.08, z / 100.0)) for z in range(32, 11, -3)])
partes.append((kit.lineas("telarana", web, 0.0024, LINEAS), "por_distancia"))

# ----------------------------------------------------------------- La araña
def arana(nombre, escala, caras_, grosor):
    """La araña: el cuerpo en dos partes y las ocho patas, pegadas al pecho (y a la espalda)."""
    piezas = []
    patas = []
    patron = [[(0.010, 0.020), (0.050, 0.052), (0.060, 0.092)],
              [(0.012, 0.010), (0.062, 0.030), (0.082, 0.062)],
              [(0.012, -0.006), (0.062, -0.022), (0.082, -0.054)],
              [(0.010, -0.020), (0.050, -0.052), (0.062, -0.104)]]
    for atras in caras_:
        sgn = -1.0 if atras else 1.0
        zc = 1.365 if not atras else 1.33
        for dz, rx, rz in ((-0.016, 0.019, 0.032), (0.030, 0.012, 0.015)):
            p = kit.pegar(tr, (0.0, sgn * 0.25, zc + dz * escala), 0.003)
            q = kit.pegar(tr, (0.0, sgn * 0.25, zc + dz * escala), 0.0)
            n = (p[0] - q[0], p[1] - q[1], p[2] - q[2])
            e = [kit.elipsoide(p, (rx * escala, 0.006, rz * escala), seg=20)]
            kit.orientar(e, p, n)
            piezas += e
        for lado in (-1, 1):
            for pata in patron:
                patas.append([kit.pegar(tr, (lado * u * escala, sgn * 0.25, zc + v * escala), 0.003) for u, v in pata])
    piezas.append(kit.lineas(nombre + "_patas", patas, grosor, EMBLEMA))
    return kit.pieza_fija(nombre, piezas, EMBLEMA)


partes.append((arana("emblema__sin_simbionte+2099", 0.85, [False], 0.0050), "torso"))
partes.append((arana("emblema_grande__f_simbionte", 2.3, [False, True], 0.0110), "torso"))

# -------------------------------------------------------------------- Skins
#
#   2099    Miguel O'Hara: la araña roja grande con cara de calavera en el pecho y en la
#           espalda, y la capa de tela rota.
#   iron    Iron Spider: las cuatro patas mecanicas doradas saliendo de la espalda.
#   clasico el de Ditko (1962): las alas de telaraña debajo de los brazos.
ROJO_2099 = kit.material("emblema", (0.85, 0.12, 0.14))
CAPA = kit.material("capa", (0.55, 0.08, 0.10))
PATAS = kit.material("metal", (0.90, 0.72, 0.28), metal=0.85, rugosidad=0.3)
ALA = kit.material("ala", (0.10, 0.18, 0.55))


def calavera_2099(atras):
    sgn = -1.0 if atras else 1.0
    zc = 1.32
    piezas = []
    # La cara: dos ojos grandes en gota arriba y la mandibula angosta abajo.
    for lado in (-1, 1):
        q = kit.pegar(tr, (lado * 0.050, sgn * 0.3, zc + 0.08), 0.004)
        e = [kit.elipsoide(q, (0.040, 0.008, 0.055), rot=(0, lado * 25, 0), seg=16)]
        piezas += e
    q = kit.pegar(tr, (0.0, sgn * 0.3, zc - 0.04), 0.004)
    piezas.append(kit.elipsoide(q, (0.030, 0.008, 0.070), seg=16))
    patas = []
    for lado in (-1, 1):
        patas.append([kit.pegar(tr, (lado * x, sgn * 0.3, z), 0.004) for x, z in ((0.07, 1.42), (0.14, 1.50), (0.20, 1.56))])
        patas.append([kit.pegar(tr, (lado * x, sgn * 0.3, z), 0.004) for x, z in ((0.08, 1.36), (0.16, 1.38), (0.22, 1.30))])
        patas.append([kit.pegar(tr, (lado * x, sgn * 0.3, z), 0.004) for x, z in ((0.05, 1.22), (0.13, 1.14), (0.18, 1.04))])
        patas.append([kit.pegar(tr, (lado * x, sgn * 0.3, z), 0.004) for x, z in ((0.03, 1.18), (0.07, 1.06), (0.09, 0.98))])
    piezas.append(kit.lineas("patas_2099_%d" % (1 if atras else 0), patas, 0.012, ROJO_2099))
    return piezas


partes.append((kit.pieza_fija(kit.de_skin("emblema_2099", "2099"), calavera_2099(False) + calavera_2099(True), ROJO_2099),
               "torso"))
capa = kit.capa("capa", ["2099"], CAPA, z_abajo=0.58, abre=0.18, cuello=0.0, ancho=0.205, fondo=0.140)
# Rota: el ruedo en jirones.
bm = kit.bmesh.new()
bm.from_mesh(capa.data)
fuera = [f for f in bm.faces if (f.calc_center_median().z < 0.70 + 0.10 * abs(math.sin(math.atan2(f.calc_center_median().x,
                                                                                                    f.calc_center_median().y) * 7.0)))]
kit.bmesh.ops.delete(bm, geom=fuera, context="FACES")
bm.to_mesh(capa.data)
bm.free()
partes.append((capa, "torso"))
# IRON SPIDER: las patas mecanicas, dos por lado, de la espalda hacia arriba y afuera, y
# con la punta para abajo.
patas = []
for lado in (-1, 1):
    for k, (alto, sale) in enumerate(((1.30, 0.42), (1.12, 0.46))):
        base = (lado * 0.06, -0.14, alto)
        codo = (lado * (0.06 + sale * 0.6), -0.30, alto + 0.30 - k * 0.12)
        punta = (lado * (0.06 + sale), -0.28, alto - 0.10 - k * 0.15)
        patas += kit.tubo([base, codo, punta], [0.024, 0.020, 0.006], seg=10)
        patas.append(kit.elipsoide(codo, (0.030, 0.030, 0.030), seg=12))
partes.append((kit.fundir(kit.de_skin("patas_arana", "iron"), patas, PATAS, voxel=0.004, suavizado=2, caras=4000), "torso"))
# DITKO: las alas de telaraña entre el brazo y el costado.
alas = []
for lado in (-1, 1):
    pts = [(lado * 0.17, 0.0, 1.36), (lado * 0.27, 0.0, 1.43), (lado * 0.30, 0.0, 1.16), (lado * 0.20, 0.0, 1.06)]
    alas.append(kit.caja((lado * 0.24, 0.0, 1.25), (0.10, 0.008, 0.24), rot=(0, lado * -20, 0)))
partes.append((kit.fundir(kit.de_skin("ala", "clasico"), alas, ALA, voxel=0.004, suavizado=3, caras=2000), "por_distancia"))

arm = kit.esqueleto(J)
for obj, regla in partes:
    if regla == "por_distancia":
        kit.pesar(obj, arm, J)
kit.pesar_estandar([p for p in partes if p[1] != "por_distancia"], arm, J)
cara = kit.cara_estandar(cabeza, J, 0.054, 1.818, ojos_extra={"oculto": True, "alto": 0.06, "ancho": 0.06})
kit.exportar("spiderman", arm, cara)
