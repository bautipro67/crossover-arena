# Sonidos grabados

Cualquier archivo que pongas en esta carpeta **reemplaza** al sonido que el juego genera
por código, sin tocar nada más. Si no está, el juego lo sintetiza como siempre. Se busca
solo, al arrancar.

El nombre tiene que ser **exactamente** el de la tabla, con extensión `.ogg`
(recomendado) o `.wav`. Ejemplo: `hit_punch.ogg`.

✓ = ya tiene archivo grabado.

## Interfaz

| archivo      | cuándo suena                                             |
|--------------|----------------------------------------------------------|
| `ui_click`   | apretar cualquier botón de los menús                     |
| `ui_hover`   | pasar el mouse por un botón (sin archivo, no suena)      |
| `no_stamina` | una habilidad que no sale: sin stamina o sin blanco      |
| `respawn`    | reaparecer, y curarse entre oleadas o entre jefes        |
| `victoria`   | ganar una partida (sin archivo, no suena)                |
| `derrota`    | perder una partida (sin archivo, no suena)               |

## Movimiento

| archivo      | cuándo suena                         |
|--------------|--------------------------------------|
| `paso`       | cada paso (muy bajito, se repite mucho) |
| `salto`      | al saltar                            |
| `aterrizaje` | al caer al piso                      |
| `dash`       | el dash, y casi todas las embestidas |

## Golpes y estados (de todos)

| archivo     | cuándo suena                                         |
|-------------|------------------------------------------------------|
| `golpe` ✓   | CADA golpe que conecta, de cualquiera (sin archivo, no suena) |
| `hit_punch` | una piña o patada que conecta (Muda, clones, escombros) |
| `hit_ice`   | un zarpazo o golpe cuerpo a cuerpo con filo          |
| `death`     | alguien muere                                        |
| `muerte_<personaje>` | la muerte de ese personaje en vez de la de todos: `muerte_sonic` ✓, `muerte_goku`, `muerte_mario`... |
| `channel`   | empezar a cargar una definitiva                      |
| `freeze`    | alguien queda congelado                              |

## Por personaje

| archivo              | personaje  | qué es                                         |
|----------------------|------------|------------------------------------------------|
| `ice_shock` ✓        | Noelle     | el proyectil de hielo                           |
| `snowgrave` ✓        | Noelle     | la definitiva                                   |
| `knife`              | Dio        | los cuchillos                                   |
| `za_warudo`          | Dio        | el tiempo que se detiene                        |
| `petals`             | Flowery    | los pétalos                                     |
| `last_jarona`        | Flowery    | la definitiva                                   |
| `plasma`             | Rick       | el disparo de plasma                            |
| `plasma_blast`       | Rick       | la granada (y otras explosiones)                |
| `portal` ✓           | Rick       | la pistola de portales                          |
| `meeseeks` ✓         | Rick       | la caja de Meeseeks                             |
| `super_sonic`        | Sonic      | la transformación (sin archivo: `channel`)      |
| `luz_sonic`          | Sonic      | cada golpe a la velocidad de la luz (sin archivo: `hit_punch`) |
| `fuego`              | Mario / Scorpion | la bola de fuego y el fuego del infierno  |
| `estrella`           | Mario      | la Superestrella                                |
| `katon`              | Madara     | el muro de fuego                                |
| `susanoo`            | Madara     | el Susano'o                                     |
| `meteorito`          | Madara     | los meteoritos (y la lluvia del modo)           |
| `psiquico`           | Mob        | la onda y los escombros                         |
| `explosion_psiquica` | Mob        | la barrera                                      |
| `cien_por_ciento`    | Mob        | el 100% (sin archivo: `explosion_psiquica`)     |
| `chasquido`          | Thanos     | el chasquido                                    |
| `gema`               | Thanos     | las gemas del Poder y del Espacio               |
| `cadena`             | Scorpion   | el kunai con la cadena                          |
| `hueso`              | Sans       | los huesos                                      |
| `telarana`           | Spider-Man | las telarañas                                   |
| `sentido_aracnido`   | Spider-Man | el sentido arácnido (sin archivo: `dash`)       |
| `goma`               | Luffy      | el brazo de goma                                |
| `gear_fifth`         | Luffy      | el Gear Fifth (sin archivo: `goma`)             |

## Modos de juego

| archivo         | modo          | qué es                                  |
|-----------------|---------------|-----------------------------------------|
| `bomba_tic`     | Bomba caliente| el tic de los últimos tres segundos (sin archivo: `ui_click`) |
| `bomba_pasa`    | Bomba caliente| la bomba que cambia de manos (sin archivo: `hit_punch`) |
| `bomba_explota` | Bomba caliente| la explosión (sin archivo: `plasma_blast`) |
| `esfera`        | Caza de esferas | tomar una esfera (sin archivo: `gema`) |

## Voces

| archivo             | quién      | qué dice                       |
|---------------------|------------|--------------------------------|
| `voz_jarona` ✓      | Flowery    | ¡JARONA!                       |
| `voz_here_i_come` ✓ | Flowery    | ¡HERE I COME, SAN FRANCISCO!   |
| `voz_last_jarona` ✓ | Flowery    | ¡LAST JARONA!                  |
| `voz_muda` ✓        | Dio        | ¡MUDA MUDA MUDA!               |
| `voz_za_warudo` ✓   | Dio        | ¡ZA WARUDO!                    |
| `voz_toki` ✓        | Dio        | ¡TOKI YO TOMARE!               |
| `voz_kamehameha` ✓  | Goku       | KA-ME-HA-ME-HA (con el HA grabado, el ¡HA! sintetizado se calla) |
| `voz_ha`            | Goku       | ¡HAAA!                         |
| `voz_wahoo` ✓       | Mario      | ¡WAHOO!                        |
| `voz_lets_go` ✓     | Mario      | ¡LET'S-A GO!                   |
| `voz_katon`         | Madara     | ¡KATON: GŌKA MESSHITSU!        |
| `voz_susanoo`       | Madara     | ¡SUSANO'O!                     |
| `voz_tengai`        | Madara     | ¡TENGAI SHINSEI!               |
| `voz_cien`          | Mob        | 100%                           |
| `voz_inevitable` ✓  | Thanos     | Soy inevitable.                |
| `voz_get_over_here` ✓ | Scorpion | ¡GET OVER HERE!                |
| `voz_venganza`      | Scorpion   | ¡VENGANZA!                     |
| `voz_mal_rato`      | Sans       | vas a pasar un mal rato.       |
| `voz_kage_bunshin`  | Naruto     | ¡KAGE BUNSHIN NO JUTSU!        |
| `voz_rasengan` ✓    | Naruto     | ¡RASENGAN!                     |
| `voz_rasenshuriken` | Naruto     | ¡RASEN-SHURIKEN!               |
| `voz_gomu_gomu` ✓   | Luffy      | ¡GOMU GOMU NO...! (Gatling y Rocket) |
| `voz_gear_fifth`    | Luffy      | ¡GEAR FIFTH!                   |
| `voz_vecino`        | Spider-Man | ¡TU AMIGABLE VECINO!           |
| `voz_purpura`       | Gojo       | ¡PÚRPURA!                      |

## Música

| archivo           | cuándo suena                 |
|-------------------|------------------------------|
| `musica_menu`     | en los menús (en bucle)      |
| `musica_combate`  | en las partidas (en bucle)   |

Solo `.ogg` para la música: se repite sola, y un `.wav` de varios minutos pesa demasiado
para la versión web.

## Qué conviene

- **Mono**, 32000 o 44100 Hz. El juego ubica cada sonido en el espacio 3D; el estéreo
  no aporta nada y duplica el peso. La música sí puede ser estéreo.
- **Cortos.** Los efectos, entre 0.1 y 1 segundo; las voces, entre 0.5 y 1.3. Una voz
  más larga que eso termina después del golpe y deja de ser un aviso.
- **Sin silencio al principio.** Todo se dispara en el mismo instante que el efecto
  visual.
- **Sin reverb ni eco.** El juego ya lo pone en el espacio.
- **`.ogg` para publicar.** La versión web se descarga entera antes de jugar.

## De dónde NO sacarlos

No uses audio sacado de los juegos, series o películas (Deltarune, JoJo, Dragon Ball,
Mario, Naruto...). Los personajes en un fangame gratis son una zona tolerada; las
grabaciones originales no, y son justamente lo que hace que bajen una página de itch.io
por DMCA. Sirven los sonidos que grabes vos o los de bibliotecas libres con licencia
CC0 (por ejemplo, freesound.org filtrando por CC0).
