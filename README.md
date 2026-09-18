# CrossoverArena

Arena PvP 3D en tercera persona donde cada personaje jugable viene de un juego distinto.
Hoy hay dos: **Noelle Holiday** (Deltarune) y **Dio Brando** (JoJo's Bizarre Adventure).

Hecho en **Godot 4.6.3**, GDScript puro, **sin un solo archivo de assets**: la geometría,
los efectos y hasta los sonidos se generan por código.

---

## Jugar

Hay **tres builds**, todos en `build/`:

| Archivo | Para qué |
|---|---|
| `CrossoverArena-web.zip` (9 MB) | **Jugable en el navegador.** Es el que subís a itch.io como proyecto `HTML`. Tiene `index.html` en la raíz, que es lo que itch exige |
| `CrossoverArena-windows.zip` (35 MB) | Descarga para Windows |
| `server/crossover-server.x86_64` (68 MB) | Servidor dedicado, por si lo corrés en un VPS. Un solo archivo, `.pck` embebido |

**Para dejar el juego online para todos, gratis: [docs/SERVIDOR.md](docs/SERVIDOR.md).**
Va en [Render](https://render.com) en plan gratuito, que regala el subdominio y el
certificado TLS — y sin TLS la versión de itch.io no se conecta a nada, porque el
navegador bloquea un WebSocket inseguro abierto desde una página HTTPS.

El servidor no usa ese binario de 68 MB: el [`Dockerfile`](Dockerfile) baja Godot para
Linux y corre el proyecto desde el código fuente, así el servidor corre exactamente lo
mismo que se testea acá.

El build web se exporta **sin hilos** a proposito. Un build con hilos necesita
`SharedArrayBuffer`, que el navegador solo habilita si la pagina llega con cabeceras de
aislamiento; itch.io solo las manda si marcas una casilla, y si te la olvidas el juego
muere en la pantalla de carga con *"Cross-Origin Isolation ... missing"*. Sin hilos entra
con la configuracion por defecto de itch, que es una cosa menos que puede salir mal.

Para probarlo local:

```bash
python tools/serve_web.py 8060
```

**Desde el editor:**
1. Descomprimí `Godot_v4.6.3-stable_win64.exe.zip` (lo tenés en Descargas).
2. Abrí Godot → **Importar** → elegí la carpeta `CrossoverArena`.
3. F5.

### Los tres modos

| | Para qué |
|---|---|
| **Practicar solo** | Arena con maniquíes. Sin red, sin necesitar a nadie. Es por donde arranca cualquiera que baje el juego. |
| **Hostear partida** | Abrís una partida, hasta 8 jugadores. Sos el peer 1 y además jugás. |
| **Unirse** | Te conectás por IP a alguien que esté hosteando. |

Para probar PvP en la misma PC: en el editor, `Depurar` → `Ejecutar múltiples
instancias` → 2. Una hostea y la otra se une a `127.0.0.1`. Puerto por defecto: **27015**.

**El transporte es WebSocket (TCP), no ENet (UDP).** No es un capricho: el export web
no puede abrir sockets UDP. Si el escritorio usara ENet y el navegador WebSocket serían
dos redes incompatibles y un jugador de navegador nunca podría entrar al servidor de uno
de escritorio. Un solo transporte = todos juegan juntos. El costo es que con mal ping se
nota más que con UDP.

**Desde el navegador solo se puede unirse, no hostear**: una pestaña no puede escuchar en
un puerto. El menú lo detecta y esconde el botón en vez de ofrecer algo que va a fallar.

Gana el primero que llegue a 15 kills. Al terminar, todos vuelven a la sala de espera
y el host puede arrancar otra sin que nadie se reconecte.

---

## Controles

| Acción | Tecla | ¿Cuesta stamina? |
|---|---|---|
| Moverse | `W` `A` `S` `D` | **No** |
| Correr | automático | **No** |
| Dash | `Shift` | **No** — cooldown de 1.4s, con i-frames |
| Saltar | `Espacio` | **No** |
| Golpe básico | Click izquierdo | **No** |
| Habilidad | Click derecho | **Sí** |
| Ultimate | `Q` | **Sí** |
| Marcador | `Tab` | — |
| Pausa / opciones | `Esc` | — |

**Correr automáticamente** viene activado: te movés siempre a velocidad de carrera sin
sostener nada. Si lo apagás en Opciones, caminás por defecto y corrés manteniendo `Ctrl`.
En los dos casos correr es gratis.

> **La regla de la stamina:** existe **solo** para las habilidades. Correr, golpear y
> dashear son gratis, siempre, para todos los personajes. El dash se limita con
> cooldown, no con stamina. Hay tests que fallan si alguien rompe esto.

Para rebindear, editá la tabla `BINDINGS` en
[`scripts/core/game_config.gd`](scripts/core/game_config.gd). El InputMap se registra
por código a propósito, así todos los controles están en un lugar legible.

Sensibilidad del mouse, volumen, pantalla completa y correr automáticamente se cambian
en **Opciones** (menú principal o pausa) y se guardan solos en `user://settings.cfg`.

## Audio

No hay **ni un archivo de audio** en el proyecto: todo se sintetiza como PCM crudo.

- **13 efectos** en [sfx.gd](scripts/audio/sfx.gd). Cada uno es una función corta de
  síntesis: el puñetazo es una sinusoide que cae de 220 Hz a 70 Hz en una décima de
  segundo, y eso es lo que el oído lee como impacto.
- **Dos temas musicales** en [music.gd](scripts/audio/music.gd), los dos en La menor: el
  del menú es lento y frío (pads sostenidos y campanitas), el de combate va a 140 BPM con
  bajo, arpegio y percusión. Cruzan con un fundido de 1.2s.
- La música se genera **en un hilo aparte** (~1.3s): hacerlo en el arranque congelaba el
  juego medio segundo largo. En el navegador va sincrónica a propósito — bloquear el hilo
  principal de una página para joinear un thread está desaconsejado por Emscripten y tira
  error en consola.
- Volumen de efectos y de música son sliders separados en Opciones.

## Aspecto

Todo lo que se ve está generado por código, sin un solo archivo de arte:

- **Cel-shading con contorno.** Los materiales usan luz en bandas, brillo especular duro
  y un contorno negro hecho con un `next_pass` que dibuja las caras traseras infladas.
  Con geometría simple, el shading es lo que separa "estilo" de "placeholder". Todo sale
  de [`scripts/core/art.gd`](scripts/core/art.gd).
- **Personajes articulados.** Una jerarquía de `Node3D` que hacen de hombros, codos,
  caderas y rodillas, rotados por código: ciclo de caminata, animación de golpe y
  respiración al estar quieto. Sin esqueletos ni `AnimationPlayer`.
- **Siluetas.** Es lo único que distingue a un personaje a 20 metros, así que están
  diseñadas para ser opuestas: Noelle alta y angosta con astas, Dio ancho y cuadrado con
  hombreras.
- **Poses de ultimate.** Los canalizados tienen pose propia: Snowgrave levanta los dos
  brazos al cielo con el torso arqueado, ZA WARUDO levanta el derecho y cruza el
  izquierdo. Además dibujan un círculo mágico giratorio con runas a los pies, que es el
  aviso visual que le da al rival el tiempo de reacción que el balance da por sentado.
- **Caras.** Ojos con esclerótica, pupila y punto de brillo, cejas con pivote propio,
  nariz y boca. Parpadean solos cada 2-5 s, entrecierran los ojos y abren la boca al
  recibir un golpe, y frunden el ceño mientras canalizan. La expresión de reposo es por
  personaje: Noelle tiene las cejas altas y casi rectas, Dio las tiene bajas y muy
  inclinadas hacia adentro.
- **Golpes con peso.** El puñetazo sale con una curva rápida (pico en el primer tercio) y
  el torso gira llevando el hombro al frente. Recibir un golpe comprime el cuerpo un
  instante y saca un número de daño flotante.
- **Retroceso.** Cada habilidad empuja distinto, calibrado para que no rompa su propio
  rol: Icicle Strike y MUDA empujan poquito (si te sacaran del alcance, el golpe gratis
  no se podría encadenar), Ice Shock y los cuchillos empujan medio, y Snowgrave es el más
  fuerte del juego — todavía más en la ejecución contra un congelado. ZA WARUDO no empuja
  a propósito: si el tiempo está detenido, nadie se mueve.
- **ZA WARUDO desatura el mundo entero** mientras el tiempo está detenido: comunica el
  estado sin una sola palabra de texto.

---

## Los ultimates: se ganan, no se esperan

Tirar un ultimate pide **dos cosas a la vez**:

1. **La barra de stamina entera (100).** Te deja seco: después de un ultimate no te queda
   ni para una habilidad normal.
2. **El medidor de ultimate al 100%**, y ese **se llena pegando**, no esperando. No hay
   carga pasiva: 0.8 por punto de daño infligido, más 25 al matar. O sea, más o menos un
   ultimate por kill.

El cooldown es de apenas 10s porque **lo que te frena es la carga, no un reloj**.

Dos reglas que sostienen el sistema:

- **El daño de un ultimate no carga el medidor.** Sin esto, un Snowgrave de 260 daba 208
  de carga y el ultimate se pagaba el siguiente solo.
- **Morir no borra la carga.** Se gana peleando, y borrarla al morir castiga dos veces al
  que va perdiendo. Dejarla es lo que le da al que pierde una herramienta para dar vuelta
  la pelea, que es para lo que sirve un ultimate.

El HUD tiene una tercera barra dorada abajo de la stamina, y la carta del ultimate muestra
el porcentaje mientras no esté listo.

## Los personajes

### Noelle Holiday — Deltarune

Control a distancia. No mata sola: prepara la matada.

| Habilidad | Costo | CD | Qué hace |
|---|---|---|---|
| **Icicle Strike** | 0 | 0.5s | 11 de daño, cono 3.2m, **+1 escarcha** |
| **Ice Shock** | 28 | 3.5s | Proyectil, 22 de daño, **+2 escarcha**, ralentiza 25% |
| **Snowgrave** | **100 + medidor** | 10s | Canaliza 1.5s, cono 20m. **65 normal — 260 si está CONGELADO** |

**El sistema de escarcha** es el corazón del kit, y es fiel a la ruta Weird: en Deltarune
Snowgrave no es un hechizo de daño, es lo que remata a los enemigos ya congelados.

- Cada golpe de hielo suma stacks. A los **5 stacks el rival se congela**.
- Congelado: no se mueve ni actúa 2.5s, y recibe **25% más de daño**.
- Los stacks se caen solos, 1 cada 2 segundos.

```
Ice Shock (+2) → Icicle Strike (+1) → Ice Shock (+2) → CONGELADO → Snowgrave → ejecución
```

El canalizado de 1.5s te deja clavado en el piso y se ve de lejos: el rival puede cortar
la línea de visión detrás de una cobertura. Si te congelan **a vos** durante el
canalizado, se cancela y recuperás la mitad de la stamina.

### Dio Brando — JoJo's Bizarre Adventure

Corta distancia. El ultimate le abre la ventana; el daño lo mete a mano.

| Habilidad | Costo | CD | Qué hace |
|---|---|---|---|
| **MUDA MUDA** | 0 | 0.4s | 13 de daño, cono corto de 3m |
| **Knife Throw** | 26 | 4s | Tres cuchillos en abanico, 12 cada uno |
| **ZA WARUDO** | **100 + medidor** | 10s | Canaliza 0.9s, **detiene el tiempo 2.2s** en 20m. Al reanudarse, la andanada de cuchillos impacta junta por **65** |

Con el tiempo detenido los demás no se pueden mover ni actuar, y Dio sí. Tres decisiones
de balance que importan:

1. **Aturde, no congela.** Un aturdido **no** queda ejecutable por Snowgrave. Si fueran
   el mismo estado, Dio + Noelle serían un combo de dos botones que mata desde vida llena.
2. **Necesita línea de visión.** Detrás de una cobertura estás a salvo. Sin eso sería un
   botón sin contrajuego.
3. **El daño llega tarde, a propósito.** Los cuchillos quedan suspendidos durante el
   tiempo detenido y todos impactan juntos cuando se reanuda. Así el control y el daño son
   la misma cosa, y el golpe llega justo cuando el rival recupera el control.

Los dos personajes son opuestos a propósito: Noelle acumula durante toda la pelea y
resuelve con un botón; Dio aprieta un botón y después tiene que trabajar.

---

## Tests

Tres tests headless. Si tocás la economía de stamina, la escarcha o la red, corrélos.

```bash
godot --headless --path . res://tests/smoke_test.tscn
```
86 verificaciones: los dos kits, las reglas de stamina (con y sin auto-correr),
escarcha/congelación, la invariante de aturdido-≠-congelado, proyectiles, retroceso
(dirección, despegue del piso y vuelta del maniquí a su marca), la carga de
ultimates (que sube pegando, que no sube al recibir, que no se autocarga y que sobrevive
a la muerte) y arena.

```bash
godot --headless --path . res://tests/solo_test.tscn
```
34 verificaciones: modo práctica sin red, maniquíes, los 13 efectos, los dos temas
musicales y su generación en hilo, y las opciones.

```bash
godot --headless --path . res://tests/net_test.tscn -- host
godot --headless --path . res://tests/net_test.tscn -- client
```
14 verificaciones en **dos procesos reales** (listen server).

```bash
godot --headless --path . -- --server 27098
godot --headless --path . res://tests/server_test.tscn -- 27098
```
15 verificaciones del **servidor dedicado**, que es el modo de la versión online: que no
se spawnee a sí mismo, que arranque la partida solo, que un cliente pueda jugar contra
él de verdad, y que el cliente **insista contra un servidor dormido** en vez de rendirse
al primer fallo (lo que pasa siempre en el plan gratuito de Render, que apaga la
instancia cuando no hay nadie).

El servidor también se puede arrancar por variable de entorno, que es como lo hace
Render — sin pasarle ningún argumento:

```bash
PORT=27097 godot --headless --path .
```

Todos salen con código 0 si pasan.

### Chequeo visual

Los tres de arriba corren sin render, así que no pueden decirte si algo se **ve** mal.
Para eso está el cuarto:

```bash
godot --path . res://tests/visual_check.tscn -- C:/donde/guardar/las/capturas
```

Abre el juego con ventana de verdad, lo maneja solo (menú → lobby → partida → combate
con los dos personajes) y saca 22 capturas en los momentos clave. **No le pongas
`--headless`**: sin render las capturas salen negras.

Encontró varios bugs que los tests headless no podían ver: el menú principal descentrado
y cortado, la cámara sin el corrimiento al hombro (el cuerpo tapaba la mira), los carteles
de nombre gigantes, el puñetazo que salía hacia atrás, y una pose de ultimate que nunca
se aplicaba porque el handler declaraba un argumento de menos que la señal.

---

## Compilar para publicar

Las *export templates* de Godot 4.6.3 ya están instaladas en esta máquina.

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/CrossoverArena.exe
```

Después se comprime `build/windows/` entero (el `.exe`, el `.pck` y el `LEEME.txt`) en
un zip. El `.pck` tiene que quedar al lado del `.exe` o el juego no arranca.

El preset está en [`export_presets.cfg`](export_presets.cfg) y excluye `tests/`, `docs/`
y los `.md` del build.

### Todo junto, en un comando

`tools/publicar.py` apunta el juego al servidor público, reexporta el web y el Windows,
y rearma los dos `.zip`:

```bash
python tools/publicar.py https://crossover-arena.onrender.com
```

La URL no se puede saber antes de desplegar el servidor: Render la inventa al crear el
servicio. Por eso el orden es servidor primero, esto después, itch al final. El script
convierte `https://` en `wss://` solo, que es el error más fácil de cometer y el más
difícil de diagnosticar, porque falla únicamente en la versión web.

Sin servidor público: `python tools/publicar.py --sin-servidor`.

### Subirlo a itch.io

1. Creá el proyecto, tipo **HTML**, y subí `build/CrossoverArena-web.zip`.
2. Marcá **"This file will be played in the browser"**. Viewport 1280 × 720.
   **No** hace falta "SharedArrayBuffer support": el build va sin hilos justamente para
   no depender de esa casilla.
3. Subí `build/CrossoverArena-windows.zip` como descarga, marcado **Windows**.
4. Precio: **No payment / free**. Es un fangame, no se monetiza.
5. En la descripción, poné el aviso de que Noelle es de Toby Fox y Dio de Hirohiko Araki.

---

## Estructura

```
scripts/
  core/        GameConfig, Net, CharacterDB, Settings (autoloads) y CharacterData
  components/  Health, Stamina, StatusEffects — se enchufan a cualquier entidad
  abilities/   Ability (base), AbilityCaster (el motor), Projectile, CombatUtils
  characters/  Un subdirectorio por personaje: noelle/ y dio/
  player/      Player, cámara en tercera persona, cuerpo visual
  arena/       La arena y los maniquíes, generados por código
  ui/          Menú, sala de espera, HUD, pausa, opciones
  fx/          Efectos visuales (100% cosméticos)
  audio/       Sfx: sintetiza todos los sonidos por código al arrancar
scenes/        main.tscn y player.tscn — mínimas a propósito
tests/         Los tres tests headless
docs/          Arquitectura y guía para sumar personajes
build/         El zip listo para subir
```

- **[docs/AGREGAR_PERSONAJE.md](docs/AGREGAR_PERSONAJE.md)** — cómo sumar el tercero.
- **[docs/ARQUITECTURA.md](docs/ARQUITECTURA.md)** — cómo está armado y qué decide quién.

---

## Estado

Funciona y está verificado corriendo el motor:

- Menú, opciones persistentes, sala de espera con selector de personaje, HUD completo.
- Modo práctica con maniquíes, sin red.
- Hostear / unirse por IP, hasta 8 jugadores, con late join.
- Movimiento en tercera persona con sprint, salto y dash con i-frames.
- Dos personajes completos con kits mecánicamente opuestos.
- Combate server-authoritative: daño, stamina y cooldowns los decide el host.
- Muerte, respawn, marcador, kill feed, fin de partida y vuelta al lobby.
- Audio completo, sintetizado por código.

Lo que **no** está:

- **Modelos y animaciones.** Los personajes son cápsulas con siluetas distintas. Hay un
  bob de caminata procedural y nada más.
- **Música.** Hay efectos de sonido, no hay banda sonora.
- **El balance está probado contra los números, no contra jugadores.** Los 40s de
  cooldown de ZA WARUDO y los 30s de Snowgrave son mi mejor estimación.
- **El movimiento es client-authoritative**, así que un cliente modificado podría
  teletransportarse. Para jugar con conocidos está bien; para abrirlo a desconocidos
  habría que mover el movimiento al servidor con reconciliación.
- Sin bots que peleen: los maniquíes no devuelven golpes.

---

## Aviso legal

Fangame **no comercial**. No está a la venta ni monetizado.

- Noelle Holiday y Deltarune son de **Toby Fox**.
- Dio Brando y JoJo's Bizarre Adventure son de **Hirohiko Araki / Shueisha**.

No hay ninguna relación con ellos ni se reclama ningún derecho sobre esos personajes.
Por eso esto es un juego independiente y no un juego de Roblox: Roblox modera y da de
baja el contenido con personajes con copyright, mientras que un fangame independiente y
gratuito es la forma habitual y aceptada de hacer esto. **No le pongas precio.**
