# Voces grabadas

Cualquier archivo que pongas acá **reemplaza** a la voz sintetizada por código, sin
tocar nada más. Si no está, el juego la genera como siempre. No hay que configurar
nada ni avisarle a nadie: se busca al armar el banco de sonido.

Los nombres tienen que ser exactamente estos:

| archivo            | quién  | qué dice                      |
|--------------------|--------|-------------------------------|
| `voz_jarona`       | Flowery| ¡JARONA!                      |
| `voz_here_i_come`  | Flowery| ¡HERE I COME, SAN FRANCISCO!  |
| `voz_last_jarona`  | Flowery| ¡LAST JARONA!                 |
| `voz_muda`         | Dio    | ¡MUDA MUDA MUDA!              |
| `voz_za_warudo`    | Dio    | ¡ZA WARUDO!                   |
| `voz_toki`         | Dio    | ¡TOKI YO TOMARE!              |

Con extensión `.ogg` (recomendado) o `.wav`.

## Qué conviene

- **Mono**, 22050 o 32000 Hz. Es un grito que sale de un punto del mapa; el estéreo no
  aporta nada y duplica el peso.
- **Entre 0.5 y 1.3 segundos.** Más largo que eso y el anuncio termina después del
  golpe, con lo cual deja de ser un aviso y pasa a ser un comentario.
- **Sin silencio al principio.** El grito tiene que empezar en el primer milisegundo:
  se dispara en el mismo frame que el destello y que el cartel.
- **Sin reverb ni eco.** El juego ya lo ubica en el espacio 3D; si viene con ambiente
  grabado encima, se escuchan los dos.
- **`.ogg` para publicar.** Pesa una fracción del `.wav`, y la versión web se descarga
  entera antes de empezar a jugar.

## De dónde NO sacarlas

No uses el audio de Deltarune ni del anime de JoJo. Los personajes y las mecánicas en
un fangame gratuito son una zona gris tolerada; las grabaciones de los actores no lo
son, y el audio shippeado es exactamente lo que hace que a una página de itch.io le
caiga una bajada por DMCA. Sería esta página la que se cae.

Grabarlas con un celular funciona bien: son seis gritos cortos.
