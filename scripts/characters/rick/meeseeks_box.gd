class_name MeeseeksBox
extends Ability
## Slot 3 de Rick: "CAJA DE MEESEEKS". Su ultimate.
##
## Aprieta el boton y salen tres Mr. Meeseeks que persiguen al rival mas cercano hasta
## alcanzarlo o hasta desaparecer. Existir les duele: quieren cumplir y dejar de existir,
## y eso es exactamente lo que hacen.
##
## POR QUE ES SU ULTIMATE Y NO OTRA COSA. Los otros tres ultimates del juego se resuelven
## en el instante en que salen: Snowgrave barre un cono, ZA WARUDO congela lo que tiene
## alrededor, LAST JARONA es el propio cuerpo yendo y viniendo. Los tres los decide la
## posicion en la que estabas al apretar.
##
## Este no. Los Meeseeks salen y despues TE BUSCAN, asi que lo que decide si te pegan es
## lo que hagas en los cinco segundos siguientes: si corres, si te tapas detras de algo,
## si los llevas hacia otro. Es el unico ultimate del juego que sigue jugandose despues
## de tirarlo, y es lo que le corresponde al personaje que no gana peleando sino
## resolviendo.
##
## Canaliza 1.0s: abrir la caja tiene que poder verse venir.

const CUANTOS: int = 3
const DAMAGE: float = 34.0
const SPEED: float = 15.0
const VIDA: float = 5.0
## Separacion del abanico de salida, en grados. Salen en abanico y no del mismo punto
## para que no se tapen entre ellos y para que cubran mas de un camino de escape.
const ABANICO: float = 26.0


func _init() -> void:
	id = &"meeseeks_box"
	display_name = "Caja de Meeseeks"
	description = "Canaliza 1s y suelta %d Meeseeks que te PERSIGUEN. %d de daño cada uno." % [
		CUANTOS, int(DAMAGE)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.0
	requires_charge = true
	icon_color = Color(0.35, 0.82, 0.95)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	soltar(caster, origin, dir, false)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	soltar(caster, origin, dir, true)


static func soltar(caster: Node, origin: Vector3, dir: Vector3, cosmetic: bool) -> void:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	FX.spawn_meeseeks_box(caster, origin, rumbo)
	Sfx.play_3d(caster, &"meeseeks", origin, 0.0)

	var mitad := float(CUANTOS - 1) * 0.5
	for i: int in range(CUANTOS):
		var angulo := deg_to_rad((float(i) - mitad) * ABANICO)
		var salida := rumbo.rotated(Vector3.UP, angulo)
		var m := Meeseeks.new()
		m.damage = DAMAGE
		m.speed = SPEED
		# Vidas apenas distintas: si se apagaran los tres en el mismo frame, el final del
		# ultimate se veria como un corte y no como que se fueron cumpliendo.
		m.lifetime = VIDA + float(i) * 0.35
		Projectile.launch(m, caster, origin, salida, cosmetic, 1.2)
