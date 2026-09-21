"""Arma las imagenes que pide itch.io a partir de las tomas de render_promo.

itch pide cada una con su proporcion exacta y no recorta por vos: una portada con la
proporcion equivocada sale con barras o estirada. Esto recorta desde el centro de
interes de cada toma, que no siempre es el centro geometrico.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ORIGEN = "build/promo"
DESTINO = "build/itch"
FUENTES = "C:/Windows/Fonts"

os.makedirs(DESTINO, exist_ok=True)


def fuente(nombre, tam):
    return ImageFont.truetype(os.path.join(FUENTES, nombre), tam)


def recorte(img, ancho, alto, cx=0.5, cy=0.5, zoom=1.0):
    """Recorta a la proporcion pedida centrando en (cx, cy) relativos, y escala.

    `zoom` > 1 se acerca. Recortar antes de escalar —y no al reves— es lo que evita
    que el personaje salga chiquito en un mar de piso.
    """
    W, H = img.size
    objetivo = ancho / alto
    # Lado mas grande posible con la proporcion pedida, reducido por el zoom.
    if W / H > objetivo:
        h = H / zoom
        w = h * objetivo
    else:
        w = W / zoom
        h = w / objetivo
    x = cx * W - w / 2
    y = cy * H - h / 2
    x = max(0, min(W - w, x))
    y = max(0, min(H - h, y))
    caja = img.crop((int(x), int(y), int(x + w), int(y + h)))
    return caja.resize((ancho, alto), Image.LANCZOS)


def _fuente_que_entra(d, texto, nombre, ancho_max, tam_inicial):
    """Baja el cuerpo de la letra hasta que el texto entra en `ancho_max`.

    HACE FALTA porque el tamaño se calculaba como fraccion del alto, y en una portada
    de 630x500 eso dio letras tan grandes que "CROSSOVER ARENA" salio como "OSSOVER ARE":
    el titulo se salia por los dos costados. Medir el texto y achicar hasta que entra es
    la unica forma de que funcione en los tres formatos sin ajustar numeros a mano.
    """
    tam = tam_inicial
    while tam > 8:
        f = ImageFont.truetype(os.path.join(FUENTES, nombre), tam)
        caja = d.textbbox((0, 0), texto, font=f)
        if caja[2] - caja[0] <= ancho_max:
            return f
        tam -= 2
    return ImageFont.truetype(os.path.join(FUENTES, nombre), 8)


def titulo_sobre(img, texto, sub=None, alto_rel=0.17, margen=0.055):
    """Escribe el titulo abajo, sobre un degradado oscuro para que se lea siempre."""
    img = img.convert("RGBA")
    W, H = img.size
    velo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dv = ImageDraw.Draw(velo)
    desde = int(H * 0.46)
    for y in range(desde, H):
        p = (y - desde) / max(1, H - desde)
        dv.line([(0, y), (W, y)], fill=(4, 6, 14, int(238 * p ** 1.2)))
    img = Image.alpha_composite(img, velo).convert("RGB")

    d = ImageDraw.Draw(img)
    ancho_util = int(W * 0.90)
    f = _fuente_que_entra(d, texto, "ariblk.ttf", ancho_util, int(H * alto_rel))
    caja = d.textbbox((0, 0), texto, font=f)
    tw, th = caja[2] - caja[0], caja[3] - caja[1]

    alto_sub = 0
    fs = None
    cs = None
    if sub:
        fs = _fuente_que_entra(d, sub, "segoeuib.ttf", ancho_util, max(11, int(th * 0.30)))
        cs = d.textbbox((0, 0), sub, font=fs)
        alto_sub = (cs[3] - cs[1]) + int(H * 0.030)

    # Se apila desde abajo: primero el subtitulo, el titulo encima.
    y_sub = H - int(H * margen) - (cs[3] - cs[1] if cs else 0)
    y_tit = y_sub - int(H * 0.028) - th if sub else H - int(H * margen) - th

    sombra = max(2, H // 240)
    d.text((( W - tw) / 2 - caja[0] + sombra, y_tit - caja[1] + sombra), texto, font=f,
           fill=(2, 3, 10))
    d.text(((W - tw) / 2 - caja[0], y_tit - caja[1]), texto, font=f, fill=(255, 255, 255))
    if sub:
        d.text(((W - (cs[2] - cs[0])) / 2 - cs[0], y_sub - cs[1]), sub, font=fs,
               fill=(178, 198, 234))
    return img


def logo(ancho=1200, alto=340):
    """PNG transparente, horizontal, legible sobre claro y sobre oscuro.

    El truco para que funcione en los dos fondos es el CONTORNO: letras blancas con un
    borde oscuro grueso se leen sobre blanco y sobre negro. Sin borde, una de las dos se
    pierde, y itch lo pone sobre los dos.

    El cuerpo de letra se calcula, no se fija: con 150 fijos "CROSSOVER ARENA" se salia
    por los dos costados de los 1200 px y quedaba "ROSSOVER AREN".
    """
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    a, b = "CROSSOVER ", "ARENA"
    borde = 0

    tam = alto
    while tam > 10:
        f = fuente("ariblk.ttf", tam)
        borde = max(3, tam // 16)
        largo = d.textlength(a, font=f) + d.textlength(b, font=f)
        caja = d.textbbox((0, 0), a + b, font=f)
        if largo + borde * 2 <= ancho * 0.94 and (caja[3] - caja[1]) + borde * 2 <= alto * 0.84:
            break
        tam -= 2
    f = fuente("ariblk.ttf", tam)

    largo = d.textlength(a, font=f) + d.textlength(b, font=f)
    caja = d.textbbox((0, 0), a + b, font=f)
    x = (ancho - largo) / 2
    y = (alto - (caja[3] - caja[1])) / 2 - caja[1]

    for texto, color in ((a, (255, 255, 255)), (b, (255, 214, 92))):
        d.text((x, y), texto, font=f, fill=color, stroke_width=borde,
               stroke_fill=(8, 10, 22))
        x += d.textlength(texto, font=f)
    return img


def abrir(nombre):
    return Image.open(os.path.join(ORIGEN, nombre + ".png"))


trio = abrir("trio")
trio_cerca = abrir("trio_cerca")
pano = abrir("panoramica")
flowery = abrir("retrato_flowery")
cabeza = abrir("retrato_flowery_cabeza")

salidas = []

# --- Portada: 630x500. Es la que falta y la que se ve en todas las listas. ---
# Centrada arriba (cy=0.42) porque abajo solo hay piso.
# zoom 1.15 y no 1.35: con 1.35 el recorte se comia a Dio y a Noelle y quedaba una
# portada de un personaje solo, que no cuenta que el juego es un cruce.
cover = titulo_sobre(recorte(trio, 630, 500, cy=0.46, zoom=1.15),
                     "CROSSOVER ARENA", "Arena PvP 3D en el navegador")
salidas.append(("cover_630x500.png", cover))

# --- Imagen social: 1200x630 (la proporcion que usan Twitter/Facebook al enlazar). ---
social = titulo_sobre(recorte(trio, 1200, 630, cy=0.47, zoom=1.05),
                      "CROSSOVER ARENA", "Deltarune x JoJo · gratis en el navegador",
                      alto_rel=0.15)
salidas.append(("social_1200x630.png", social))

# --- Cover ancha: 21:9 exacto, como pide itch. 1680x720. ---
salidas.append(("wide_1680x720.png", recorte(pano, 1680, 720, cy=0.50, zoom=1.0)))

# --- Favicon: cuadrado. La cabeza de Flowery, que es la mas reconocible. ---
#
# Sale de una TOMA DE CABEZA propia, no recortada del cuerpo entero: recortando, la
# cabeza ocupaba un octavo del alto original y el favicon salia borroso. Ademas el
# recorte a ojo se desfasaba cada vez que movia la camara del retrato, y la primera
# version termino siendo un primer plano del pecho.
salidas.append(("favicon_256.png", recorte(cabeza, 256, 256, cx=0.50, cy=0.47, zoom=1.9)))

# --- Logo transparente ---
salidas.append(("logo_1200x340.png", logo()))

for nombre, img in salidas:
    ruta = os.path.join(DESTINO, nombre)
    img.save(ruta)
    print("   %-24s %s" % (nombre, "x".join(map(str, img.size))))

print("\n%d imagenes en %s/" % (len(salidas), DESTINO))
