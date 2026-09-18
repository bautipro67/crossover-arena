# Servidor dedicado de CrossoverArena para Render (u otro hosting con Docker).
#
# NO exporta el juego: corre el proyecto directo desde el codigo fuente con el binario
# de Godot para Linux. Eso evita bajar los export templates, que pesan 1.2 GB, y hace
# que el servidor corra exactamente el mismo codigo que se testea local.
#
# El binario de Godot para Linux solo depende de glibc (verificado leyendo su DT_NEEDED:
# librt, libpthread, libdl, libm, libc). Las librerias graficas las carga con dlopen y
# solo si las necesita, y con --headless nunca las necesita. Por eso alcanza con una
# imagen base pelada, sin X11 ni drivers de video.

# ---------------------------------------------------------------- Etapa 1: Godot
FROM debian:bookworm-slim AS godot

ARG GODOT_VERSION=4.6.3-stable

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/godot.zip \
      "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip" \
 && unzip -j /tmp/godot.zip -d /tmp \
 && mv /tmp/Godot_v${GODOT_VERSION}_linux.x86_64 /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm /tmp/godot.zip

WORKDIR /app
COPY project.godot icon.svg icon.svg.import ./
COPY scenes ./scenes
COPY scripts ./scripts

# Importar aca, en el build, y no en cada arranque. Importa poco tiempo pero el plan
# gratuito de Render apaga la instancia cuando no hay nadie, asi que el arranque en frio
# es lo que espera el jugador que entra primero: todo lo que se pueda hacer antes, mejor.
#
# Si falla no abortamos: el juego no tiene assets (todo es geometria y sonido generados
# por codigo), asi que Godot lo resuelve solo al arrancar.
RUN godot --headless --path /app --import || echo "aviso: la importacion previa fallo, se hara al arrancar"

# ------------------------------------------------------------- Etapa 2: la imagen
FROM debian:bookworm-slim

# tini para que las señales lleguen bien: sin un init decente, Godot queda como PID 1 y
# el SIGTERM que manda Render al apagar la instancia no lo termina limpio.
RUN apt-get update \
 && apt-get install -y --no-install-recommends tini \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /usr/sbin/nologin juego

COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot
COPY --from=godot --chown=juego:juego /app /app

# HOME explicito. Docker NO lo cambia solo al poner USER: se queda en /root, que este
# usuario no puede escribir, y ahi Godot no puede crear su carpeta de datos (user://).
ENV HOME=/home/juego

USER juego
WORKDIR /app

# Render inyecta PORT con un valor distinto en cada deploy. Main._is_dedicated_server()
# ve esa variable y arranca en modo servidor sin necesidad de pasarle --server.
# El 27015 es solo el valor por defecto para correr la imagen a mano.
ENV PORT=27015
EXPOSE 27015

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["godot", "--headless", "--path", "/app"]
