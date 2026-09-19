# Servidor online gratis

Guía para dejar CrossoverArena jugable en itch.io, con un servidor público al que entra
cualquiera desde el navegador, **sin pagar nada**.

Usa [Render](https://render.com) en plan gratuito, igual que Ajedrez Maestro.

---

## Por qué Render y no un VPS

itch.io te da **archivos y una página**: sirve el juego, no corre tu servidor. El servidor
va en otro lado sí o sí.

Y no alcanza con cualquier lado. itch.io sirve la página por **HTTPS**, y un navegador
**bloquea** un WebSocket inseguro (`ws://`) abierto desde una página segura: lo trata como
contenido mixto. O sea:

> Sin certificado TLS en el servidor, el juego web **no se conecta a nada**.

Antes eso obligaba a comprar un dominio (~10 USD/año) y configurar Caddy para sacar el
certificado. Render te da las dos cosas de arriba:

| | |
|---|---|
| Subdominio | `https://loquesea.onrender.com`, gratis |
| Certificado TLS | Lo emite y lo renueva solo |
| WebSockets | Soportados en todos los planes, incluido el gratuito |

Así que la guía del VPS (dominio + Caddy + systemd + firewall) queda al final, como
plan B para cuando el gratuito te quede chico.

---

## La diferencia con Ajedrez Maestro

Aquel servidor es Node, y su `render.yaml` dice `runtime: node`. Este es un juego de
Godot, así que va por **Docker**: Render construye el [`Dockerfile`](../Dockerfile) del
repo y corre la imagen. El plan sigue siendo el gratuito; cambia cómo se construye, no
cuánto cuesta.

El Dockerfile **no exporta el juego**: baja el binario de Godot para Linux (69 MB) y corre
el proyecto directo desde el código fuente. Exportar habría obligado a bajar los *export
templates*, que pesan 1.2 GB en cada build. De paso, el servidor corre exactamente el
mismo código que probás local.

---

## El recorrido completo, de un vistazo

```
   tu PC                GitHub                 Render              itch.io
  ┌──────┐   push     ┌────────┐   build     ┌────────┐         ┌────────┐
  │codigo│ ─────────> │  repo  │ ──────────> │servidor│ <═══════│ juego  │
  └──────┘            └────────┘             └────────┘  wss:// └────────┘
                                                  │                  ▲
                                                  │ te da la URL     │ subis el zip
                                                  └──────────────────┘
                                                    publicar.py la escribe
                                                    adentro del juego
```

Render **no** lee tu carpeta: lee un repo de GitHub. Por eso el primer paso es empujar el
código, aunque el servidor no lo vayas a tocar nunca mas.

Y el orden importa: la URL no existe hasta que Render crea el servicio, y el juego la
necesita adentro. Por eso **el servidor va primero y el juego después**.

---

## Paso 1: subir el proyecto a GitHub

### 1.1 — El repositorio local

Si nunca hiciste `git init` en esta carpeta:

```bash
git init -b main && git add -A && git commit -m "CrossoverArena"
```

`build/` esta en `.gitignore` a proposito: son 44 MB de artefactos que se regeneran, y el
servidor no los necesita porque corre desde el codigo fuente.

### 1.2 — Crear el repo vacio en GitHub

Entra a **[github.com/new](https://github.com/new)** y:

| Campo | Que poner |
|---|---|
| Repository name | `crossover-arena` |
| Public / Private | Cualquiera. Render funciona con los dos |
| Add a README file | **DESMARCADO** |
| Add .gitignore | **None** |
| Choose a license | **None** |

> **Lo importante son esas tres ultimas.** Si le agregas un README, GitHub crea un commit
> que tu repo local no tiene, el primer `push` se rechaza con *"failed to push some refs"*
> y hay que resolverlo a mano. Un repo vacio evita todo eso.

### 1.3 — Empujar

```bash
git remote add origin https://github.com/TU_USUARIO/crossover-arena.git
```

```bash
git push -u origin main
```

Si te pide credenciales, Windows abre una ventana de GitHub para que entres. Tiene que
terminar con algo como `main -> main`.

---

## Paso 2: crear el servicio en Render

### 2.1 — Blueprint

1. Entra a **[dashboard.render.com](https://dashboard.render.com)**
2. Arriba a la derecha: **New +** → **Blueprint**
3. Si es tu primera vez, te va a pedir conectar GitHub: **Connect GitHub** y le das
   acceso al repo (podes darle solo a `crossover-arena`, no hace falta a todos)
4. Elegi `crossover-arena` de la lista → **Connect**

Render lee [`render.yaml`](../render.yaml) y te muestra lo que va a crear: **un** servicio
web llamado `crossover-arena`, plan **Free**, runtime **Docker**.

5. **Apply**

> **Si no aparece el repo en la lista:** es permiso de GitHub, no de Render. Andá a
> GitHub → Settings → Applications → Render → Configure y agregá el repositorio.

### 2.2 — Esperar el build

El primer build tarda **entre 4 y 8 minutos**. En la pestaña **Logs** vas a ver, en orden:

```
==> Cloning from https://github.com/TU_USUARIO/crossover-arena
==> Building Docker image...
Step 3/12 : RUN curl -fsSL -o /tmp/godot.zip ...      <- baja Godot, 69 MB
Step 6/12 : RUN godot --headless --path /app --import
==> Uploading build...
==> Deploying...
```

Y al final, lo unico que te importa:

```
[servidor] CrossoverArena escuchando WebSocket en el puerto 10000
==> Your service is live 🎉
```

Ese numero de puerto **no es 27015 y va a cambiar en cada deploy**: lo elige Render y lo
pasa por la variable de entorno `PORT`. El juego la lee solo. No la fijes a mano ni le
pases `--server`: si el servidor escucha en un puerto distinto al que Render espera, el
deploy queda marcado como caido estando sano.

### 2.3 — La URL

Arriba de todo en la pagina del servicio, debajo del nombre, Render muestra:

```
https://crossover-arena.onrender.com
```

**Copiá esa, no la de este ejemplo.** Si el nombre `crossover-arena` ya estaba tomado por
otra persona en Render, la tuya va a tener un sufijo (`crossover-arena-a1b2`).

### 2.4 — Comprobar que esta vivo ANTES de tocar el juego

```bash
python tools/probar_servidor.py https://crossover-arena.onrender.com
```

Esto hace el apretón de manos de WebSocket a mano y te dice donde falla si falla: DNS,
TCP, TLS o el protocolo. Tiene que terminar en:

```
  [ok]  DNS resuelve a 216.24.57.x
  [ok]  TCP conectado (0.4s)
  [ok]  TLS negociado (TLSv1.3)
  [ok]  apreton de manos WebSocket completo

SERVIDOR VIVO. Tardo 0.6 segundos en contestar.
```

Hacer esto primero te ahorra muchisimo tiempo: si el servidor esta mal, lo sabes en dos
segundos en vez de reexportar el juego entero, subirlo a itch y descubrir alla que no
conecta sin saber de que lado esta el problema.

Si te dice **404**, eso es el proxy de Render y no tu juego: el servicio no esta
corriendo. Si te dice **502** o **503**, la instancia esta despertando o el deploy se
cayo. En los dos casos, a los logs.

---

## Paso 3: apuntar el juego al servidor

Con la URL confirmada:

```bash
python tools/publicar.py https://crossover-arena.onrender.com
```

Eso hace tres cosas de una:

1. Escribe la URL en `GameConfig.OFFICIAL_SERVER_URL`, **pasandola de `https://` a
   `wss://`** — que es lo que necesita el WebSocket, y el error mas facil de cometer a
   mano porque solo falla en la version web.
2. Reexporta el build web y el de Windows.
3. Rearma los dos `.zip`.

Termina diciendote:

```
servidor oficial -> wss://crossover-arena.onrender.com
   zip -> build/CrossoverArena-web.zip (9.2 MB)
   zip -> build/CrossoverArena-windows.zip (34.4 MB)
```

A partir de ahi el menu principal muestra un boton **JUGAR ONLINE** que entra directo, sin
que el jugador escriba ninguna direccion.

Para volver atras y dejarlo sin servidor oficial:
`python tools/publicar.py --sin-servidor`.

---

## Paso 4: subir a itch.io

1. **Dashboard** → *Create new project*
2. **Kind of project**: `HTML`
3. Subí `build/CrossoverArena-web.zip` y marcá **"This file will be played in the browser"**
4. **Viewport**: 1280 × 720, con *fullscreen button* activado
5. **No** hace falta marcar "SharedArrayBuffer support" (ver abajo)
6. **Pricing**: `No payment`. Es un fangame, no se monetiza
7. Subí también `build/CrossoverArena-windows.zip` como descarga opcional, marcado Windows

Para subidas repetidas conviene [butler](https://itch.io/docs/butler/):

```bash
butler push build/CrossoverArena-web.zip usuario/crossover-arena:html
```

### Por qué el build web va sin hilos

Si subís un export de Godot hecho **con hilos**, itch.io lo muestra así y no arranca nunca:

> Error — The following features required to run Godot projects on the Web are missing:
> Cross-Origin Isolation · SharedArrayBuffer

No es un problema del juego. Los hilos en el navegador usan `SharedArrayBuffer`, que solo
existe si la página llega *cross-origin isolated*, y eso depende de dos cabeceras
(`Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy`) que itch.io manda **solo**
si marcás la casilla "SharedArrayBuffer support".

Se puede arreglar marcándola. Pero el preset está en `variant/thread_support=false`, o sea
**sin hilos**, que resuelve lo mismo sin depender de una casilla: el juego entra con la
configuración por defecto de itch, y sigue entrando si algún día la desmarcás sin querer o
lo embebés en otro lado. Para un juego que es casi todo geometría generada por código, los
hilos no cambiaban gran cosa.

Antes de subir nada, probalo exactamente como lo va a servir itch:

```bash
python tools/serve_web.py 8060 --sin-aislamiento
```

Si arranca ahí, arranca en itch. Ese flag sirve el build **sin** las cabeceras, que es el
caso que rompía.

---

## Lo que hay que saber del plan gratuito

**La instancia se duerme.** Tras un rato sin nadie conectado, Render la apaga. El primero
que entra después la despierta, y eso puede tardar cerca de un minuto.

El juego lo contempla: al conectar **insiste hasta 75 segundos** (`Net.WAKE_TIMEOUT`) y la
sala de espera muestra *"Despertando el servidor gratuito… 23s"*. Sin eso, el primer
jugador vería "no se pudo conectar" en un servidor que estaba prendiéndose, y no volvería.

Lo que no se salva es una **partida en curso cuando se duerme**: el estado vive en memoria
y se pierde. Mismo problema que tiene Ajedrez Maestro con sus partidas.

**Recursos.** El plan gratuito da CPU compartida y 512 MB de RAM, de sobra para este juego
(es headless: no renderiza ni reproduce audio). Y 750 horas de instancia al mes, que
alcanzan para tener un solo servicio prendido todo el mes.

**Una sola partida a la vez.** El servidor corre una arena y mete ahí a todo el que entre,
hasta `GameConfig.MAX_PLAYERS`. No hay salas separadas.

---

## Si algo no arranca

**Lo primero, siempre:**

```bash
python tools/probar_servidor.py https://TU-SERVICIO.onrender.com
```

Eso separa "el servidor esta mal" de "el juego esta mal", que es la pregunta que hace
perder mas tiempo. Te dice en que capa se rompe: DNS, TCP, TLS o el protocolo.

**Render dice "no open ports detected".** El servidor no llegó a escuchar. Mirá los logs:
si no aparece la línea `[servidor] ... escuchando WebSocket en el puerto N`, el proceso
murió antes. Si aparece pero con un puerto raro, algo está pisando la variable `PORT`.

**El deploy queda en "unhealthy".** Fijate que no le hayas puesto `healthCheckPath` al
servicio. `render.yaml` lo omite a propósito: Render lo verifica mandando un GET normal y
esperando un 200, pero el servidor de Godot habla WebSocket, no HTTP, así que ese GET no
se responde y Render lo marcaría caído estando perfecto.

**El juego de itch no conecta pero el de escritorio sí.** Casi siempre es `ws://` en vez
de `wss://`. Revisá `OFFICIAL_SERVER_URL`; `tools/publicar.py` ya hace esa conversión.

**Tarda muchísimo la primera vez y después va bien.** Es el arranque en frío, es así.

---

## Probarlo local antes de subir nada

```bash
# Terminal 1: el servidor, igual que lo arranca Render (por variable de entorno)
PORT=27015 godot --headless --path .
```

```bash
# Terminal 2: servir el build web como lo sirve itch.io por defecto
python tools/serve_web.py 8060 --sin-aislamiento
```

Abrí `http://localhost:8060`, escribí `127.0.0.1` y puerto `27015`, y dale UNIRSE. En
local va por `ws://` porque no hay HTTPS de por medio.

Los tests automáticos hacen este recorrido solos:

```bash
godot --headless --path . res://tests/server_test.tscn -- 27097
```

Ese arnés verifica también que el cliente insista contra un servidor dormido, que es el
caso que se da siempre en el plan gratuito.

---

## Plan B: VPS propio

Si el arranque en frío molesta o querés varias partidas a la vez, un VPS de ~5 USD/mes lo
resuelve. Cambia que el certificado lo tenés que sacar vos.

```bash
godot --headless --path . --export-release "Linux Server" build/server/crossover-server.x86_64
scp build/server/crossover-server.x86_64 usuario@TU_IP:/opt/crossover/
```

`/etc/systemd/system/crossover.service`:

```ini
[Unit]
Description=CrossoverArena dedicated server
After=network.target

[Service]
Type=simple
User=crossover
WorkingDirectory=/opt/crossover
ExecStart=/opt/crossover/crossover-server.x86_64 --headless -- --server 27015
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

TLS con [Caddy](https://caddyserver.com), que saca y renueva el certificado de Let's
Encrypt solo. Necesitás un dominio apuntando a la IP con un registro `A`.

`/etc/caddy/Caddyfile`:

```
juego.midominio.com {
    reverse_proxy 127.0.0.1:27015
}
```

Abrí el 80 y el 443, y **no** abras el 27015 hacia afuera: que solo lo alcance Caddy desde
adentro.

---

## Cosas que conviene saber antes de abrirlo al público

**El movimiento es client-authoritative.** El daño, la stamina y los cooldowns los decide
el servidor, pero la posición la manda cada cliente. Entre conocidos da lo mismo; en un
servidor público, alguien con el juego modificado puede teletransportarse o correr al
triple. Si lo abrís en serio, agregá una validación de velocidad máxima en el servidor.

**El transporte es TCP, no UDP.** El export web no puede abrir sockets UDP, así que todo
el juego usa WebSocket. Con buen ping no se nota; con mal ping se nota más que con UDP,
porque TCP reordena y reenvía. Por eso `render.yaml` usa la región **ohio** y no
frankfurt: desde Argentina es bastante menos ping, y en un juego de pelea eso sí importa.

**Las rutas de nodo tienen que coincidir.** Godot direcciona los RPC por ruta. El servidor
y el cliente corren los dos `main.tscn`, así que el árbol es idéntico y funciona. Si algún
día cambiás dónde cuelga la partida en un lado y no en el otro, los paquetes dejan de
rutearse y Godot desconecta al peer. Es un error silencioso y caro de encontrar.

**Un servidor vacío espanta igual que no tener servidor.** El problema más difícil de un
multijugador chico no es técnico. Por eso el modo **Practicar solo** está primero en el
menú: el que entra y no encuentra a nadie igual tiene algo que hacer.
