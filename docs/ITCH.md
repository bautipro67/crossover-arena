# Qué poner en la página de itch.io

Todo el texto de acá se copia y se pega. Lo de la primera sección **no es opcional**:
son los campos que, mal puestos, hacen que el juego no arranque en el navegador.

---

## 1. Configuración — los campos que pueden romper el juego

| Campo de itch | Qué poner | Por qué |
|---|---|---|
| **Kind of project** | `HTML` | Si queda en "Downloadable", nadie lo juega en el navegador. |
| **Uploads** → `CrossoverArena-web.zip` | Marcar ✅ **This file will be played in the browser** | Es el zip que tiene `index.html` en la raíz, que es lo que itch busca. |
| **Uploads** → `CrossoverArena-windows.zip` | **NO** marcar esa casilla. Marcar plataforma 🪟 Windows | Es la descarga opcional. Si la marcás como jugable, itch se confunde sobre cuál servir. |
| **Viewport dimensions** | `1280` × `720` | Es la resolución de diseño del juego. Con otra, la interfaz queda cortada o diminuta. |
| **Fullscreen button** | ✅ Activado | Es un juego en tercera persona; a 1280×720 embebido se juega incómodo. |
| **SharedArrayBuffer support** | ❌ **DEJAR DESMARCADO** | Ver abajo. Es el que más problemas da. |
| **Mobile friendly** | ✅ Activado, orientación **Landscape** | Tiene controles táctiles: stick a la izquierda y botones a la derecha, pensados para el celular acostado. Parado, la pantalla de 1280×720 queda diminuta. |
| **Pricing** | `No payments` | Ver la sección de aviso legal. |
| **Release status** | `Released` | |

### Sobre SharedArrayBuffer — dejalo desmarcado

Es el error más común al subir un juego de Godot y vale la pena entenderlo una vez.

Un export web **con hilos** necesita `SharedArrayBuffer`, que el navegador solo habilita
si la página viene con cabeceras de aislamiento. Ese checkbox de itch las agrega. Si tu
build usa hilos y no lo marcás, el juego muere al arrancar con un
`Cross-Origin Isolation ... missing`.

**Este build está compilado SIN hilos a propósito** (`thread_support=false`), justamente
para no depender de ese checkbox. Ya lo probé servido en local sin las cabeceras —que es
exactamente la configuración por defecto de itch— y arranca normal.

Marcarlo igual no lo mejora y puede traer problemas con otros embebidos de la página. No
lo toques.

---

## 2. Título y frase corta

**Title**

```
CrossoverArena
```

**Short description / tagline** (aparece en las tarjetas y en el buscador)

```
Arena PvP 3D donde se cruzan personajes de juegos distintos. Gratis y en el navegador.
```

---

## 3. Descripción (el cuadro de texto grande)

```
Una arena de peleas 3D en tercera persona donde se cruzan personajes que nunca se
conocieron. Abrís el navegador, elegís personaje y peleás: contra bots o contra otra
gente.

═══ PERSONAJES ═══

❄ NOELLE HOLIDAY — Deltarune
   Control y hielo. Congela, se protege y, si la dejás cargar, borra del mapa.
   Icicle Strike · Ice Shock · Defensa de Hielo · SNOWGRAVE

⏳ DIO BRANDO — JoJo's Bizarre Adventure
   Presión y castigo. Ráfagas del Stand, cuchillos a distancia y el tiempo detenido.
   MUDA MUDA · Knife Throw · Ráfaga del Stand · ZA WARUDO

🌼 FLOWERY — Deltarune
   Embestidas. Todo su kit es tirarse encima tuyo, y no para hasta que lo esquives.
   Pétalos · JARONA · Here I Come, San Francisco · LAST JARONA

🧪 RICK SANCHEZ — Rick and Morty
   El más lento de todos y de los que menos aguantan: lo compensa con aparatos y con
   un portal a cualquier punto del mapa.
   Pistola de Plasma · Pistola de Portales · Granada de Plasma · Caja de Meeseeks

💨 SONIC — Sonic the Hedgehog
   El más rápido y el más frágil. Entra, pega y se va antes de que le respondan.
   Spin Attack · Spin Dash · Homing Attack · SUPER SONIC

🔥 GOKU — Dragon Ball  (se gana completando el pase pro de la Temporada 1)
   El todoterreno. Aparece detrás de tu espalda y carga el rayo a la vista de todos.
   Combo de Golpes · Ráfaga de Ki · Teletransportación · KAMEHAMEHA

═══ MODO HISTORIA — PARTE 1: LA GRIETA ═══

Un experimento de Rick rompe la pared entre los mundos, y todo lo que cae por la grieta
termina en la Arena: un coliseo entre mundos que vive de las peleas. Diez capítulos con
escenas cinematográficas hechas en el propio juego —planos, primeros planos, técnicas en
pantalla— y peleas con objetivos: proteger a Rick mientras arma un rastreador, aguantar
en una zona, sobrevivir frente a DIO, pelear junto a aliados que se suman en el medio.
Jugás con Noelle, Sonic, Rick y Flowery, contra los ecos que fabrica la Arena y contra
quien la quiere para él.

═══ COMBOS ═══

Cada golpe deja al rival tambaleando un instante: alcanza para encadenar el golpe básico
con tus habilidades antes de que se reponga. El contador de combo cuenta la cadena.

═══ MODOS ═══

▸ ONLINE — Servidor público, entrás directo desde el menú. Sin cuenta, sin descargar
  nada.

▸ SIN CONEXIÓN — contra bots que pelean de verdad: te rodean, esquivan con dash, te
  corren a cortarte el canalizado y usan su ultimate.
  · Duelo — uno contra uno, parejo. El mejor lugar para aprender un personaje.
  · Supervivencia — oleadas que crecen, y una sola vida.
  · Contrarreloj — 12 bajas lo más rápido posible.
  · Último en pie — 4 contra uno, todos a la vez, nadie reaparece.
  · Torre de jefes — 5 enemigos de a uno, cada uno más duro que el anterior.
  · Rey de la colina — aguantá 45 segundos dentro del círculo.
  · Sala de práctica — ver abajo.

═══ TEMPORADA 1: TORNEO DE ARTES MARCIALES ═══

Jugar da experiencia y monedas: subís de nivel (del 1 al 60) y avanzás los 30 escalones
del pase, con skins, monedas y experiencia de premio. El pase pro se desbloquea con
monedas que se ganan peleando, fuera de la sala de práctica.

El último escalón del pase pro es GOKU: no se vende ni sale de otro lado. Los
escalones también se compran, a 200 monedas cada uno: lo que se gana en el tiempo que
tarda subirlo jugando.

31 skins entre el pase y la tienda, 12 nuevas en esta temporada. Cuanto más rara, más
se nota: las raras recolorean el personaje entero, las épicas suman un acabado (metal,
piedra, sombra) o un accesorio, y las legendarias un aura y ojos que brillan. En la tienda hay un probador para verla
puesta antes de comprarla.

Todo es cosmético: ni el nivel ni las skins cambian vida, daño, velocidad, hitbox ni
silueta. Y las monedas no se compran con plata: solo se ganan jugando.

═══ CONTROLES ═══

WASD ......... moverse          Click izq .... golpe básico
Espacio ...... saltar           Click der .... habilidad 1
Shift ........ dash             E ............ habilidad 2
Ctrl ......... correr           Q ............ ultimate
Tab .......... marcador         P ............ panel de práctica

Se pueden cambiar todos en Opciones → Controles.

CON MANDO: stick izquierdo moverse, stick derecho cámara, RT golpe, LT habilidad 1,
RB habilidad 2, Y ultimate, A saltar, B dash, Start pausa. Los menús también se usan
con el mando.

EN EL CELULAR: stick a la izquierda (aparece donde apoyás el pulgar), botones a la
derecha, y arrastrando el dedo por la pantalla girás la cámara.

═══ SALA DE PRÁCTICA CONFIGURABLE ═══

Adentro del modo práctica, la tecla P abre un panel para armar el entrenamiento que
necesites sin volver al menú:

  · Cuántos bots hay (de 0 a 5), en caliente
  · Que se peleen entre ellos, para ver de afuera un kit que no jugás
  · Cuánto pegan (x0, x0.5, x1, x2) — en x0 atacan igual pero no te sacan vida
  · Stamina infinita, sin esperas entre habilidades, no poder morir
  · Curar todo, para volver al estado inicial sin esperar

Y en Opciones se pueden ver las cajas de colisión de jugadores, bots y ataques.

═══ LA PRIMERA CONEXIÓN ONLINE TARDA ═══

El servidor es gratuito y se duerme cuando no hay nadie jugando. La primera conexión
después de un rato puede tardar hasta un minuto mientras despierta: el juego te avisa
en pantalla y reintenta solo. A partir de ahí entra al instante.

═══ HECHO POR CÓDIGO ═══

No hay ni un solo modelo 3D ni una textura en el proyecto: los personajes, la arena, los
efectos y la música se generan por código al arrancar. Por eso el juego pesa lo que pesa
y carga rápido. Algunas frases y sonidos de los personajes son clips de sus obras
originales.

Hecho con Godot 4.

═══ AVISO ═══

Fangame gratuito y sin fines de lucro, sin relación con los autores originales.

Noelle Holiday y Flowery son de Deltarune, creación de Toby Fox.
Dio Brando es de JoJo's Bizarre Adventure, creación de Hirohiko Araki (Shueisha).
Rick Sanchez es de Rick and Morty, creación de Justin Roiland y Dan Harmon (Adult Swim).
Sonic es de Sonic the Hedgehog, de SEGA.
Goku es de Dragon Ball, creación de Akira Toriyama (Bird Studio / Shueisha, Toei Animation).
Los clips de voz y sonido pertenecen a sus respectivos dueños.

Este juego no se vende, no acepta donaciones y no tiene publicidad. Si alguno de los
titulares quiere que se baje, se baja.
```

---

## 4. Metadatos

| Campo | Valor |
|---|---|
| **Classification** | Games |
| **Genre** | Action |
| **Tags** | `3d`, `arena`, `fangame`, `fighting`, `multiplayer`, `pvp`, `singleplayer`, `third-person`, `deltarune`, `jojos-bizarre-adventure`, `rick-and-morty`, `sonic-the-hedgehog`, `dragon-ball` |
| **Made with** | Godot |
| **Inputs** | Keyboard, Mouse, Gamepad (any), Touchscreen |
| **Average session** | A few minutes |
| **Languages** | Spanish (español) |
| **Accessibility** | Dejar vacío (el juego no tiene opciones de accesibilidad todavía) |

No pongas tags de cosas que el juego no tiene. itch penaliza eso y además te trae gente
que se va decepcionada, que es peor que no traer a nadie.

---

## 5. Imágenes — ya están hechas, en `build/itch/`

Se generan con dos pasos, los dos por código como todo lo demás:

```bash
godot --path . res://tests/render_promo.tscn -- build/promo
python tools/promo.py
```

El primero renderiza tomas **limpias, sin HUD**, con los tres personajes posados a mano
(las capturas de `build/capturas/` no sirven: tienen barras de vida y nombres flotando,
que es basura en una portada). El segundo las recorta a las proporciones exactas que
pide itch y les pone el título.

### Portada (cover image) — la que te falta

⚠️ **No se sube desde "Promo images".** Está en **Editar proyecto**, más abajo, en
`Cover image`. Es la que hace que en las listas aparezca una estrella gris en vez de tu
juego.

| Archivo | Dónde va |
|---|---|
| `cover_630x500.png` | Editar proyecto → **Cover image** |

### Promo images — la pantalla donde estás

Las cuatro son opcionales. Yo subiría las cuatro igual: la social es la que se ve cuando
alguien comparte el link, y sin ella sale un recorte al azar.

| Campo de itch | Archivo | Por qué esa medida |
|---|---|---|
| **Social media image** | `social_1200x630.png` | 1200×630 es la proporción que usan Twitter y Facebook al desplegar un enlace. |
| **Favicon** | `favicon_256.png` | Tiene que ser **cuadrado**. Es la cabeza de Flowery, que es lo más reconocible a 16 px. |
| **Wide cover** | `wide_1680x720.png` | itch exige **21:9 exacto**. Es la arena entera. |
| **Logo** | `logo_1200x340.png` | PNG transparente y horizontal. Letras blancas con contorno oscuro grueso: así se lee sobre fondo claro **y** sobre oscuro, que es lo que itch pide y donde suele fallar un logo. |

### Capturas de la galería — de `build/capturas/`

Poné 5 o 6, y en este orden. La primera es la que más se mira:

1. `13_za_warudo.png` — el momento más espectacular del juego
2. `09_snowgrave.png` — el otro ultimate, y muestra a Noelle
3. `17_bots_peleando.png` — muestra que hay pelea de verdad, no un maniquí
4. `26_panel_de_practica.png` — la sala configurable, que es lo que lo diferencia
5. `22_jarona.png` — Flowery embistiendo, con la estela
6. `18_mapa_desde_arriba.png` — el mapa entero, para que se vea la escala

Evitá las de diagnóstico (`06c_medidor_vacio`, `05b_cara_de_cerca`): son útiles para
desarrollar y no dicen nada a alguien que pasa scrolleando.

## 6. Sobre el precio — importante

Ponelo en **No payments**. Ni "Donation", ni "Name your own price" con mínimo cero.

Un fangame que usa personajes ajenos se sostiene sobre que no gana plata con ellos. En
cuanto hay un botón de pago o de donación —aunque nadie done—, deja de ser eso. Es la
razón por la que a muchos fangames los bajan y a la mayoría no.

Por lo mismo: no le pongas publicidad, no lo enlaces a un Patreon y no pidas propinas en
la descripción.

---

## 7. Lo que conviene saber, aunque no vaya en la página

- **El movimiento lo decide el cliente.** El combate lo valida el servidor, pero la
  posición no: alguien que modifique el juego puede moverse más rápido. Para partidas
  entre conocidos no importa; si el online se llena de gente, va a aparecer.
- **El servidor de Render se duerme** a los ~15 minutos sin nadie. Está contemplado en el
  juego (reintenta hasta 75 segundos y avisa en pantalla), pero si alguien se queja de
  que "no conecta", casi siempre es eso y es cuestión de esperar.
- **Actualizar el juego** en itch es reemplazar el zip en la misma página, no crear una
  nueva: así conservás las vistas, los comentarios y el link.
