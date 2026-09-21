extends Node
## Ajustes de la SALA DE PRACTICA. Autoload: `Practica`.
##
## QUE RESUELVE. Practicar contra tres bots que pelean esta bien para medir distancias,
## pero es pesimo para casi todo lo demas que uno necesita ensayar:
##
##   - Ver como se ve un combo entero -> te matan a la mitad.
##   - Ensayar el timing de una habilidad -> esperas el cooldown cada vez.
##   - Mirar una animacion de cerca -> el bot se te tira encima.
##   - Aprender a esquivar UN ataque -> hay tres bots tirandote cosas a la vez.
##
## Cada una de esas se arregla con un interruptor, y ninguna se puede arreglar sin uno:
## no hay un solo ajuste "bueno" para todas. Por eso es un panel y no un preset.
##
## TODO ESTO VIVE SOLO EN LA PRACTICA. En una partida de verdad el panel ni se abre, asi
## que nada de aca puede usarse para hacer trampa: el modo solo no abre ningun puerto.

## Se emite cuando cambia cualquier ajuste. La arena y el HUD escuchan para aplicarlo sin
## que haya que reiniciar la partida, que es la mitad de lo que hace util a un panel asi.
signal cambio

## Se emite cuando hay que rehacer los bots (cambio la cantidad). Es aparte de `cambio`
## porque rehacerlos es caro y no hace falta en cada toque de un interruptor.
signal bots_a_rehacer

const MAX_BOTS: int = 5

var bots: int = 3
## Los bots piensan y atacan, o se quedan quietos de maniqui.
var bots_activos: bool = true
## SE PELEAN ENTRE ELLOS. Con esto puesto dejan de tenerte como unico objetivo y se
## eligen entre si tambien, asi que podes mirar la pelea desde afuera —que es la unica
## forma de ver que hace un kit que no estas jugando— o meterte en el medio.
var bots_se_pelean: bool = false
## Multiplicador de daño de los bots, ENCIMA del que ya trae GameConfig. En 0 pegan
## animaciones sin numeros: sirve para ensayar esquives sin morirse cada diez segundos.
var daño_bots: float = 1.0
## Sin gasto de stamina. Para ensayar secuencias sin que la barra corte el ejercicio.
var stamina_infinita: bool = false
## Sin esperas entre habilidades. Para mirar una animacion veinte veces seguidas.
var sin_cooldowns: bool = false
## No podes morir. La vida sigue bajando y se ve en la barra, pero no llega a cero.
var invulnerable: bool = false


## Se puede abrir el panel? Solo en practica.
##
## Lo llama el HUD antes de mostrar nada. Es la unica puerta: si esto da false, el panel
## no existe, asi que ninguno de estos ajustes puede tocarse en una partida con otros.
func disponible() -> bool:
	return Net.solo_mode and not Net.dedicated


## Vuelve todo a los valores de fabrica.
func restablecer() -> void:
	bots = 3
	bots_activos = true
	bots_se_pelean = false
	daño_bots = 1.0
	stamina_infinita = false
	sin_cooldowns = false
	invulnerable = false
	cambio.emit()


func set_bots(cantidad: int) -> void:
	var nuevo := clampi(cantidad, 0, MAX_BOTS)
	if nuevo == bots:
		return
	bots = nuevo
	bots_a_rehacer.emit()
	cambio.emit()


func set_bots_activos(valor: bool) -> void:
	bots_activos = valor
	cambio.emit()


func set_bots_se_pelean(valor: bool) -> void:
	bots_se_pelean = valor
	cambio.emit()


func set_daño_bots(valor: float) -> void:
	daño_bots = maxf(0.0, valor)
	cambio.emit()


func set_stamina_infinita(valor: bool) -> void:
	stamina_infinita = valor
	cambio.emit()


func set_sin_cooldowns(valor: bool) -> void:
	sin_cooldowns = valor
	cambio.emit()


func set_invulnerable(valor: bool) -> void:
	invulnerable = valor
	cambio.emit()
