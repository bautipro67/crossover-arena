class_name KunaiLanza
extends Projectile
## El kunai de la lanza: la punta de metal, atada a la mano de Scorpion por la cadena.
##
## Al ensartar a alguien no lo empuja para atras como cualquier proyectil: lo trae (ver
## Lanza.tirar_de). La copia de los clientes tambien frena en el que toca —sin daño ni
## tiron, que son del servidor— para que la cadena se vea tensarse donde pego y no siga
## volando de largo hasta el final del alcance.

var _cadena: CadenaScorpion = null
var _orientado: bool = false


func _init() -> void:
	tint = Color(0.80, 0.76, 0.68)
	hit_radius = 0.42
	fall_gravity = 0.0
	impact_sound = &"cadena"
	knockback = 0.0


func _ready() -> void:
	super()
	if is_instance_valid(shooter) and shooter is Node3D:
		_cadena = CadenaScorpion.crear(shooter as Node3D, self, lifetime + 0.2)


func _build_visual() -> void:
	var metal := Art.metal(Color(0.78, 0.78, 0.82), 0.0)
	# La hoja en rombo, larga hacia adelante (-Z, a donde mira despues de orientarse).
	var hoja := Art.box(Vector3(0.10, 0.025, 0.30), metal, Vector3(0.0, 0.0, -0.10))
	hoja.rotation_degrees = Vector3(0.0, 45.0, 0.0)
	hoja.scale = Vector3(0.7, 1.0, 1.0)
	add_child(hoja)
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = 0.06
	cono.height = 0.16
	punta.mesh = cono
	punta.material_override = metal
	punta.position = Vector3(0.0, 0.0, -0.30)
	punta.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(punta)
	var mango := Art.cylinder(0.022, 0.14, Art.toon(Color(0.10, 0.09, 0.08), 0.0), Vector3(0.0, 0.0, 0.08))
	mango.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	add_child(mango)
	add_light(Color(1.0, 0.75, 0.35), 1.2, 3.0)


func _physics_process(delta: float) -> void:
	if not _orientado and not _velocity.is_zero_approx():
		_orientado = true
		var arriba := Vector3.FORWARD if absf(_velocity.normalized().y) > 0.98 else Vector3.UP
		look_at(global_position + _velocity, arriba)
	if cosmetic_only and not _spent:
		var blanco := _alguien_en(global_position + _velocity * delta)
		if blanco != null:
			_spent = true
			global_position = blanco.global_position + Vector3.UP
			var dueño := shooter as Node3D if is_instance_valid(shooter) else null
			if dueño != null:
				var hacia := dueño.global_position - blanco.global_position
				Lanza.efecto_tiron(dueño, blanco, Vector2(hacia.x, hacia.z).length())
			expire()
			return
	super(delta)


## El tiron en lugar del empujon de siempre. SOLO SERVIDOR (lo llama _revisar_jugadores).
func _on_hit_player(target: Node3D) -> void:
	CombatUtils.deal_damage(target, damage, source_id)
	Lanza.tirar_de(shooter, target)


## Hay un rival en ese punto? La misma cuenta que _revisar_jugadores, sin pegarle a nadie.
func _alguien_en(punto: Vector3) -> Node3D:
	var mundo := get_world_3d()
	var espacio := mundo.direct_space_state if mundo != null else null
	if espacio == null:
		return null
	var forma := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = hit_radius
	forma.shape = esfera
	forma.collision_mask = GameConfig.LAYER_PLAYER
	forma.transform = Transform3D(Basis.IDENTITY, punto)
	if is_instance_valid(shooter):
		forma.exclude = [shooter.get_rid()]
	for golpe: Dictionary in espacio.intersect_shape(forma, 4):
		var cuerpo := golpe.get("collider") as Node3D
		if cuerpo == null or cuerpo == shooter or not cuerpo.is_in_group("players"):
			continue
		if CombatUtils.son_aliados(shooter, cuerpo):
			continue
		var vida := cuerpo.get_node_or_null("Health") as Health
		if vida != null and not vida.is_dead:
			return cuerpo
	return null
