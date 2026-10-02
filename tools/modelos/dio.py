"""DIO (JoJo, Parte 3), segun las notas de referencia de su modelo anterior.

Rubio de pelo en puntas, banda VERDE en la frente con un corazon (el corazon es el motivo
del diseño: se repite en la banda y en las rodilleras). Campera amarilla con hombreras
anchas, musculosa negra en el medio del pecho, la joya dorada, pantalon amarillo con las
rodilleras de corazon, y la capa oscura en la espalda. Piel palida, mandibula marcada.
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
PANTALON = kit.material("pantalon", (0.82, 0.68, 0.26))
ZAPATOS = kit.material("zapatos", (0.55, 0.45, 0.18))
TELA = kit.material("tela", (0.09, 0.10, 0.19))
LABIOS = kit.material("labios", (0.30, 0.42, 0.30))

partes = []

# -------------------------------------------------------------------- Cabeza
cab = kit.cabeza_humana((0, 0.0, 1.80), ancho=0.150, alto=0.180, fondo=0.158, mandibula=1.08,
                        nariz=1.15, menton=1.05)
cab.append(kit.capsula((0, -0.01, 1.48), (0, -0.01, 1.66), 0.062))
cabeza = kit.fundir("cabeza", cab, PIEL, voxel=0.006, suavizado=10, caras=9000)
partes.append((cabeza, "cabeza"))

# EL PELO: rubio, con volumen arriba y peinado para atras, y mechones lacios que caen a
# los costados de la cara hasta el cuello. La frente queda libre para la banda.
pelo = [kit.elipsoide((0, -0.040, 1.880), (0.168, 0.165, 0.150))]
# El copete: mechones que salen de arriba de la frente y se van para atras.
for k, dx in enumerate((-0.10, -0.05, 0.0, 0.05, 0.10)):
    pelo += kit.tubo([(dx, 0.090, 1.950), (dx * 1.15, 0.030, 2.000), (dx * 1.25, -0.080, 1.995),
                      (dx * 1.2, -0.175, 1.900)], [0.040, 0.044, 0.036, 0.012])
for lado in (-1, 1):
    # Los mechones de los costados, lacios, hasta el cuello.
    for k, dy in enumerate((0.060, 0.000, -0.070)):
        pelo += kit.tubo([(lado * 0.130, dy, 1.940), (lado * 0.172, dy - 0.01, 1.830),
                          (lado * 0.165, dy - 0.02, 1.690), (lado * 0.150, dy - 0.03, 1.610)],
                         [0.042, 0.040, 0.030, 0.008])
    # Y uno que cae por delante de la oreja, enmarcando la cara.
    pelo += kit.tubo([(lado * 0.120, 0.105, 1.930), (lado * 0.150, 0.120, 1.820), (lado * 0.150, 0.105, 1.700)],
                     [0.030, 0.026, 0.008])
# La nuca.
pelo += [kit.elipsoide((0, -0.110, 1.720), (0.150, 0.080, 0.120))]
partes.append((kit.fundir("pelo", pelo, PELO, voxel=0.006, suavizado=6, caras=9000), "cabeza"))

# La banda verde con el corazon adelante: POR FUERA del pelo, cruzando la frente.
banda = [kit.elipsoide((0, -0.012, 1.895), (0.178, 0.178, 0.030))]
corazon = []
for lado in (-1, 1):
    corazon.append(kit.elipsoide((lado * 0.020, 0.172, 1.902), (0.024, 0.016, 0.022)))
corazon.append(kit.cono((0, 0.172, 1.898), (0, 0.172, 1.862), 0.034, 0.002, seg=16))
partes.append((kit.fundir("banda", banda + corazon, VERDE, voxel=0.005, suavizado=4, caras=4000), "cabeza"))

# -------------------------------------------------------------------- Torso
torso = kit.torso_humano(pecho=0.215, cintura=0.170, fondo=0.130, hombros=0.175)
# El pecho marcado: Dio es musculoso, y la musculosa pegada lo deja ver.
for lado in (-1, 1):
    torso.append(kit.elipsoide((lado * 0.085, 0.080, 1.385), (0.100, 0.060, 0.072)))
campera = kit.fundir("campera", torso, CAMPERA, voxel=0.006, suavizado=8, caras=14000)
# La musculosa negra: la franja del medio del pecho, donde la campera esta abierta.
kit.pintar(campera, MUSCULOSA, lambda x, y, z: y > 0.04 and abs(x) < 0.075 + (1.50 - z) * 0.05 and 1.02 < z < 1.53)
partes.append((campera, "torso"))
partes.append((kit.fundir("joya", [kit.elipsoide((0, 0.148, 1.42), (0.030, 0.014, 0.030), rot=(0, 45, 0))],
                          JOYA, voxel=0.004, suavizado=2, caras=600), "torso"))
# Las hombreras: anchas y redondeadas, con una punta corta hacia afuera.
hombreras = []
for lado in (-1, 1):
    hombreras.append(kit.elipsoide((lado * 0.250, 0.0, 1.495), (0.120, 0.105, 0.075), rot=(0, lado * -15, 0)))
    hombreras.append(kit.cono((lado * 0.300, 0.0, 1.520), (lado * 0.400, 0.0, 1.545), 0.035, 0.004, seg=14))
partes.append((kit.fundir("hombreras", hombreras, HOMBRERAS, voxel=0.006, suavizado=6, caras=4000), "torso"))

# La capa: cae de los hombros hasta las rodillas, abriendose.
# Acampanada: tramos cada vez mas anchos y mas separados del cuerpo, que el remallado funde
# en una tela continua.
capa = []
for k in range(14):
    t = k / 13.0
    capa.append(kit.caja((0, -0.150 - t * 0.09, 1.46 - t * 0.68), (0.40 + t * 0.20, 0.026, 0.07), rot=(-4 - t * 10, 0, 0)))
partes.append((kit.fundir("capa", capa, TELA, voxel=0.008, suavizado=16, caras=4000), "torso"))

# --------------------------------------------------------------------- Brazos
mangas = []
for lado in (-1, 1):
    # La manga corta de la campera, hasta el codo.
    mangas += kit.tubo([kit.juntas()["hombro_l" if lado < 0 else "hombro_r"],
                        kit.juntas()["codo_l" if lado < 0 else "codo_r"]], [0.075, 0.064])
partes.append((kit.fundir("mangas", mangas, CAMPERA, voxel=0.007, suavizado=6, caras=3500), "brazos"))
brazos = []
for lado in (-1, 1):
    brazos += kit.antebrazo(lado, r_codo=0.062, r_muneca=0.048)
    brazos += kit.mano(lado, r=0.048)
partes.append((kit.fundir("brazos", brazos, PIEL, voxel=0.0055, suavizado=6, caras=6000), "manos"))

# -------------------------------------------------------------------- Piernas
pantalon = [kit.elipsoide((0, 0.0, 0.96), (0.180, 0.125, 0.085))]
for lado in (-1, 1):
    pantalon += kit.pierna(lado, r_muslo=0.090, r_rodilla=0.072, r_tobillo=0.058, hasta=0.16)
partes.append((kit.fundir("pantalon", pantalon, PANTALON, voxel=0.007, suavizado=8, caras=6000), "cadera"))
rodilleras = []
for lado in (-1, 1):
    x = lado * 0.12
    rodilleras.append(kit.elipsoide((x + lado * -0.016, 0.072, 0.545), (0.030, 0.014, 0.028)))
    rodilleras.append(kit.elipsoide((x + lado * 0.016, 0.072, 0.545), (0.030, 0.014, 0.028)))
    rodilleras.append(kit.cono((x, 0.072, 0.540), (x, 0.072, 0.495), 0.040, 0.003, seg=16))
partes.append((kit.fundir("rodilleras", rodilleras, VERDE, voxel=0.005, suavizado=3, caras=2500), "piernas"))
zapatos = []
for lado in (-1, 1):
    zapatos += kit.zapato(lado, largo=0.120, ancho=0.068, alto=0.060)
partes.append((kit.fundir("zapatos", zapatos, ZAPATOS, voxel=0.006, suavizado=6, caras=3500), "pies"))

# ------------------------------------------------------------------ Esqueleto
arm = kit.esqueleto(J)
kit.pesar_estandar(partes, arm, J)
cara = kit.cara_estandar(cabeza, J, 0.062, 1.815,
                         ojos_extra={"alto": 0.050, "ancho": 0.060, "iris": [0.62, 0.20, 0.16], "pestanas": False},
                         cejas={"alto": 0.040, "color": [0.80, 0.62, 0.20], "largo": 0.058},
                         boca_z=1.697, boca_extra={"ancho": 0.060, "dientes": False})
kit.exportar("dio", arm, cara)
kit.vistas(kit.carpeta_vistas(), "dio")
