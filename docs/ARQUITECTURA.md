# Arquitectura

## Los autoloads

Están en `project.godot` y arrancan en este orden:

| Autoload | Archivo | Qué hace |
|---|---|---|
| `GameConfig` | `scripts/core/game_config.gd` | Constantes globales y el registro del InputMap. Va primero porque todo depende de sus constantes. |
| `CharacterDB` | `scripts/core/character_db.gd` | Registro de personajes jugables y fábrica de sus habilidades. |
| `Net` | `scripts/core/net.gd` | Conexión, lista de jugadores, marcador y helpers de RPC. |
| `FX` | `scripts/fx/fx.gd` | Efectos visuales. 100% cosmético. |
| `Sfx` | `scripts/audio/sfx.gd` | Sonido. Sintetiza todo el banco por código al arrancar. |
| `Settings` | `scripts/core/settings.gd` | Opciones del jugador, persistidas en `user://settings.cfg`. |

`FX` y `Sfx` son **siempre cosméticos**. Si borrás los dos archivos enteros, el juego
tiene que seguir funcionando exactamente igual. Ninguno aplica daño, estado ni lógica.

**El InputMap se define por código**, en `GameConfig.BINDINGS`, no en `project.godot`.
Es a propósito: los controles quedan en una tabla legible que se puede leer y cambiar
sin pelear con el formato serializado de Godot.

## Componentes

Un jugador es un `CharacterBody3D` con cuatro nodos hijos que hacen todo el trabajo.
Se buscan **por nombre exacto**, así que si los renombrás se rompe:

| Nodo | Clase | Responsabilidad |
|---|---|---|
| `Health` | `Health` | Vida, muerte, revivir. |
| `Stamina` | `Stamina` | La barra de stamina y su regeneración. |
| `StatusEffects` | `StatusEffects` | Escarcha, congelación, ralentizaciones. |
| `AbilityCaster` | `AbilityCaster` | El motor de habilidades: validación, cooldowns, canalizado. |

Son independientes entre sí: se los podés enchufar a un enemigo de IA o a un objeto
destructible sin tocarlos.

## Quién decide qué en la red

Es un **listen server**: el host es el peer 1 y además juega. El reparto de autoridad:

| Cosa | Quién manda | Por qué |
|---|---|---|
| Posición y rotación | **El cliente dueño** | Para que moverse se sienta instantáneo. Cada uno manda su transform 20 veces por segundo y el servidor lo retransmite. |
| Daño, vida, muerte | **El servidor** | Es lo que un tramposo querría falsear. |
| Stamina y cooldowns | **El servidor** | Idem. El cliente predice para que la barra no tenga lag, pero el servidor corrige. |
| Estados (escarcha, freeze) | **El servidor** | Se replican a todos porque hay que dibujarlos. |
| Spawn, respawn, kills | **El servidor** | — |

La contrapartida honesta de que el movimiento sea client-authoritative: un cliente
modificado podría teletransportarse o moverse más rápido. Para un juego entre conocidos
está bien; si algún día lo abrís a desconocidos, el movimiento hay que moverlo al
servidor con reconciliación.

## Una habilidad, paso a paso

Qué pasa exactamente cuando apretás `Q` para tirar Snowgrave:

1. **`Player._unhandled_input`** detecta la acción y llama `caster.request_use(2)`.
2. **`AbilityCaster.request_use`** valida localmente (¿estoy vivo? ¿congelado? ¿en
   cooldown? ¿me alcanza la stamina?). Si falla, emite `ability_failed` con el motivo
   y el HUD destella en rojo. **Esta validación es solo para el feedback**, no manda.
3. Si pasa, el cliente **predice**: baja su barra de stamina y arranca el cooldown
   visual, así la UI reacciona sin esperar la red.
4. Manda `_srv_request_use.rpc_id(1, ...)` al servidor. Si somos el host, la llama directo.
5. **El servidor revalida todo de cero**, incluido que el `sender` sea el dueño de ese
   jugador (antitrampa básico), y sanea la dirección que mandó el cliente.
6. El servidor gasta la stamina de verdad, arranca el cooldown y avisa al dueño.
7. Como Snowgrave tiene `channel_time = 1.5`, empieza el canalizado y se lo avisa a
   todos. El `Player` ve `caster.is_channeling` y bloquea el movimiento (la cámara no).
8. A los 1.5s, el servidor llama `_finish_channel()`, **reapunta con la mira actual**
   y ejecuta `Snowgrave.execute()`, que busca objetivos en el cono y aplica daño.
9. El servidor manda `_net_played` a los clientes para que reproduzcan lo visual. El
   daño ya está resuelto, los clientes solo dibujan.

Si durante el paso 7 congelan al caster, `AbilityCaster._on_owner_frozen()` cancela el
canalizado y le devuelve el 50% de la stamina.

## El detalle que más cuesta descubrir: los peers "listos"

Cuando un cliente se une, pasan unos frames entre que recibe `match_started` y que su
`Arena` termina de crear los nodos de jugador. Si el servidor le manda RPCs en esa
ventana, apuntan a nodos que todavía no existen y ENet tira
`Node not found` / `Invalid packet received`, y esos paquetes se pierden.

La solución está en `Net`: el cliente avisa con `Arena._srv_client_ready()` cuando ya
armó la arena, y recién ahí el servidor lo agrega a `_ready_peers`. Todo lo que dependa
de que el receptor tenga el nodo creado usa:

```gdscript
Net.rpc_ready(self, &"_mi_metodo", [arg1, arg2])      # a todos los peers listos
Net.rpc_ready_id(self, peer_id, &"_mi_metodo", [...]) # a uno solo, si esta listo
```

en vez de `.rpc()` directo. Los RPCs de `Net` en sí pueden usar `.rpc()` normal, porque
`Net` es un autoload y siempre existe en todos los peers.

**Si agregás un RPC nuevo en un nodo de partida, usá `Net.rpc_ready`.** Es el error que
más fácil se cuela y solo se ve cuando probás con dos instancias de verdad.

## Audio sin archivos de audio

No hay ni un `.wav` en el proyecto. `Sfx._build_bank()` genera los 13 efectos como PCM
crudo al arrancar: calcula los samples float, los convierte a 16 bits y los mete en un
`AudioStreamWAV` en memoria.

Cada sonido es una función chiquita de síntesis. Por ejemplo, el puñetazo de Dio es una
sinusoide cuya frecuencia cae de 220 Hz a 70 Hz en una décima de segundo — esa caída es
lo que el oído lee como "impacto". El "no te alcanza la stamina" es una onda cuadrada
grave, fea a propósito.

El costo es despreciable (unos pocos cientos de miles de samples en total) y a cambio el
zip queda chico y no hay que preocuparse por licencias de samples. Si algún día conseguís
audio de verdad, reemplazás `_build_bank()` por precargas y nada más cambia: todos llaman
a `Sfx.play_3d()` / `Sfx.play_2d()`.

## Los dos estados que NO son lo mismo

`StatusEffects` maneja congelación y aturdimiento por separado, y la diferencia es una
decisión de balance, no un detalle de implementación:

| | `freeze_for()` | `stun_for()` |
|---|---|---|
| Quién lo causa | Escarcha de Noelle (5 stacks), Snowgrave | ZA WARUDO de Dio |
| Bloquea moverse y actuar | Sí | Sí |
| `is_frozen()` devuelve | `true` | **`false`** |
| Snowgrave lo ejecuta (200 de daño) | **Sí** | **No** |
| Daño recibido | +25% | normal |

Si fueran el mismo estado, un Dio y una Noelle jugando juntos tendrían un combo de dos
botones (ZA WARUDO → Snowgrave) que mata a todo el mundo desde vida llena. Hay un test
en `smoke_test.gd` (`_test_time_stop`) que verifica que sigan separados.

## Modo práctica: el juego sin red

`Net.start_solo()` arma la lista de jugadores a mano y **no crea ningún peer**. El resto
del juego ya funcionaba así: `Net.is_server()` devuelve `true` cuando
`multiplayer_peer == null`, o sea que sin red el cliente se trata a sí mismo como
servidor y toda la lógica autoritativa corre normal.

La trampa de ese camino es que **cualquier `.rpc()` tira error cuando no hay peer**. Por
eso `Net` tiene el guard `_has_peer()` antes de cada broadcast, y `Net.rpc_ready()` sale
temprano. El test `solo_test.tscn` existe justamente para cubrir ese camino, que una
partida normal nunca ejercita.

Cuando `Net.solo_mode` está prendido, la `Arena` además spawnea maniquíes: son `Player`
normales con `is_dummy = true`, peer id negativo y 250 de vida. Al tener peer id que no
es el local, nunca leen input ni se llevan la cámara. Sus muertes no suman al marcador.

## Orden de arranque de una partida

```
MainMenu → HOSTEAR → Net.host_game() → Lobby → EMPEZAR → Net.start_match()
                                                              ↓
                                          Main._on_match_started()
                                                              ↓
                                    crea Arena + HUD + PauseMenu
                                                              ↓
                        Arena._ready(): arma el mapa por codigo
                                                              ↓
                   servidor: se spawnea a si mismo | cliente: _srv_client_ready()
```

## Los .tscn son mínimos a propósito

Solo hay tres escenas: `main.tscn` (un nodo con script), `player.tscn` (el esqueleto de
nodos) y las dos de tests. Todo lo demás — la arena, el HUD, los menús, los cuerpos de
los personajes, las partículas — se construye por código.

La razón: los `.tscn` son difíciles de revisar en un diff y fáciles de romper sin darse
cuenta. Con la geometría en código, un cambio de mapa es un cambio de código que se lee
en un `git diff` y se testea.

Cuando tengas modelos de verdad, el punto de entrada es `PlayerVisual._build_body()`:
reemplazás esa función por la carga del `.glb` y el resto del juego no se entera.
