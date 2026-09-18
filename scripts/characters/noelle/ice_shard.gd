class_name IceShard
extends Projectile
## Proyectil de Ice Shock: ademas de daño, apila escarcha y ralentiza.

var chill_stacks: int = 2
var slow_percent: float = 0.25
var slow_duration: float = 2.0


func _init() -> void:
	tint = Color(0.55, 0.85, 1.0)
	hit_radius = 0.35
	knockback = 5.5
	knockback_lift = 1.2


func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.9, 0.35)
	mesh_instance.mesh = prism
	var mat := make_glow_material(tint)
	mat.albedo_color.a = 0.85
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat
	# La punta del prisma mira hacia adelante.
	mesh_instance.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	add_child(mesh_instance)

	add_light(Color(0.5, 0.8, 1.0))
	add_trail(Color(0.7, 0.92, 1.0, 0.8))


func _on_hit_player(target: Node3D) -> void:
	# La base ya hace daño y empuja; aca solo sumamos lo propio del hielo.
	super._on_hit_player(target)
	CombatUtils.apply_chill(target, chill_stacks)
	var status := target.get_node_or_null("StatusEffects") as StatusEffects
	if status != null:
		status.apply_slow(slow_percent, slow_duration)
