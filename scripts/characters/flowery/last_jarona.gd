class_name LastJarona
extends Ability
## Slot 3 de Flowery: "LAST JARONA". Su ultimate.
##
## ES JARONA, la misma embestida que rebota y vuelve, con dos diferencias:
##
##   1. DEJA EXPLOSIONES DETRAS. En cada rebote revienta el tramo que acaba de recorrer,
##      asi que el campo se va llenando de zonas que ya no podes pisar y el espacio
##      seguro se achica pasada a pasada.
##   2. DURA MAS, y no por tener un numero mas grande sino por la razon correcta: JARONA
##      se termina en cuanto una pasada va al aire, y esta AGUANTA VARIOS FALLOS. Te
##      sigue viniendo aunque la esquives. Esquivarla una vez no alcanza.
##
## Y mientras canaliza lo transforma en OMEGA FLOWERY: luz ciclando por los siete colores
## de las flores y el pelo en puntas.
##
## El canalizado de 1.2s es el aviso. Sin el, una cadena de embestidas sin previo seria
## imposible de responder.

## Tope de pasadas. Igual que en JARONA es una red, no la regla: lo que la termina de
## verdad es fallar mas veces que FALLOS_TOLERADOS.
const PASSES: int = 16
## A LA PAR DEL OTRO ULTIMATE, no por encima.
##
## Estaba en 30 por embestida y 22 por explosion, que medido daba 350 de daño total.
## Snowgrave —el otro ultimate del juego, que cuesta exactamente lo mismo: la barra
## entera de stamina mas el medidor al 100%— pega 260. Un ultimate que pega 90 mas que
## el otro por el mismo precio no es una opcion, es LA opcion, y el personaje que lo
## tiene deja de competir con los demas.
##
## No lleva decaimiento como JARONA a proposito: el ultimate SI es un boton de matar, y
## para eso pide canalizar 1.2 segundos a la vista de todos.
const DAMAGE: float = 23.0
## CUANTAS VECES PODES ESQUIVARLA Y QUE IGUAL SIGA. Esto es lo unico que la hace durar
## mas que JARONA, que se corta con el primer fallo.
const FALLOS_TOLERADOS: int = 3
## Daño de la explosion que deja atras en cada rebote, y su radio.
const BLAST_DAMAGE: float = 17.0
const BLAST_RADIUS: float = 5.0
## Dorada, no roja como la de JARONA: en la fase final Flowery ya es Omega.
const ESTELA: Color = Color(1.0, 0.80, 0.34)


func _init() -> void:
	id = &"last_jarona"
	display_name = "LAST JARONA"
	description = "Canaliza 1.2s y embiste igual que JARONA, dejando explosiones detras. Aguanta %d esquives antes de cortarse. %d por embestida, %d por explosion." % [
		FALLOS_TOLERADOS, int(DAMAGE), int(BLAST_DAMAGE)]
	stamina_cost = 100.0
	cooldown = 10.0
	# Canaliza: el rival tiene que poder verlo venir.
	channel_time = 1.2
	requires_charge = true
	icon_color = Color(1.0, 0.46, 0.22)


func execute(caster: Node, _origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	FX.spawn_last_jarona(caster, caster3d.global_position, BLAST_RADIUS)

	# EL MISMO BUCLE QUE JARONA, no una copia con otros numeros.
	#
	# Antes esta habilidad tenia su propio bucle de siete pasadas, y por eso se
	# desincronizo: cuando JARONA paso a repetirse hasta fallar, esta se quedo siendo
	# "siete embestidas fijas" y dejaron de parecerse. Compartiendo el bucle, cualquier
	# cosa que se arregle en una vale para las dos, y la relacion entre ellas queda dicha
	# en los argumentos: mismo ataque, con estallido y con aguante.
	await Jarona.correr_embestida(
		caster, dir, PASSES, DAMAGE, _explotar, FALLOS_TOLERADOS, ESTELA, 1.0,
		"¡LAST JARONA!", &"voz_last_jarona")


## La explosion que deja atras. La llama el bucle de JARONA en cada rebote.
##
## El daño del ultimate NO paga recursos: no recarga el medidor ni devuelve stamina.
static func _explotar(caster: Node, punto: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, punto, BLAST_RADIUS):
		CombatUtils.deal_damage(target, BLAST_DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - punto, 6.0, 2.0)
	FX.spawn_jarona_blast(caster3d, punto)
