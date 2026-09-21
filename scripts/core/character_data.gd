class_name CharacterData
extends Resource
## Definicion de un personaje jugable. Un personaje = estos datos + su lista de Ability.
## Para sumar un personaje de otro juego alcanza con registrar uno de estos en CharacterDB.

@export var id: StringName = &""
@export var display_name: String = ""
## De que juego viene el personaje. Se muestra en el lobby.
@export var origin_game: String = ""
## Ropa principal.
@export var body_color: Color = Color.WHITE
## Pelo, trims, detalles. Es el color que mas identifica al personaje.
@export var accent_color: Color = Color.CYAN
## Piel (cara, manos, antebrazos).
@export var skin_color: Color = Color(0.98, 0.85, 0.74)
## Pantalon y cinturon. Hacia falta como campo propio: estaba clavado en un azul oscuro
## para todos, y Flowery usa marron.
@export var trouser_color: Color = Color(0.14, 0.16, 0.25)
## PROPORCIONES DEL CUERPO. Escala el modelo, no la capsula de colision.
##
## Que la colision NO cambie es a proposito: los cuatro ocupan el mismo espacio y reciben
## los golpes igual, asi que un personaje alto no es un blanco mas facil ni uno bajo mas
## dificil. Lo que cambia es la silueta, que es lo que uno reconoce a veinte metros.
@export var build_scale: Vector3 = Vector3.ONE
@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var move_speed: float = 6.0

## Que silueta le dibuja PlayerVisual. Hoy: &"antlers" (Noelle) o &"shoulders" (Dio).
## Es lo que hace que reconozcas al personaje de lejos sin tener modelos de verdad.
@export var silhouette: StringName = &"none"

## Se llena en CharacterDB.build_abilities_for(). Orden: 0 = golpe basico, 1 = habilidad, 2 = ultimate.
var abilities: Array[Ability] = []
