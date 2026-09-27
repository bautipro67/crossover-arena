class_name ClonNaruto
extends Meeseeks
## Un clon de sombra de Naruto: corre hacia el rival mas cercano, le pega y se deshace en
## humo. La persecucion es la de los Meeseeks de Rick; cambia lo que se ve.


func _init() -> void:
	super()
	tint = Color(1.0, 0.58, 0.14)
	impact_sound = &"hit_punch"
	knockback = 4.0
	knockback_lift = 1.4


func _build_visual() -> void:
	var naranja := Art.toon(Color(1.0, 0.55, 0.12), 0.01)
	var negro := Art.toon(Color(0.10, 0.10, 0.14), 0.01)
	var rubio := Art.toon(Color(1.0, 0.85, 0.25), 0.01)
	var piel := Art.toon(Color(0.98, 0.82, 0.66), 0.01)
	var cuerpo := Art.capsule(0.18, 0.62, naranja, Vector3(0.0, -0.05, 0.0))
	add_child(cuerpo)
	add_child(Art.box(Vector3(0.34, 0.12, 0.30), negro, Vector3(0.0, 0.22, 0.0)))
	add_child(Art.sphere(0.15, piel, Vector3(0.0, 0.42, 0.0)))
	for k: int in range(6):
		var ang := TAU * float(k) / 6.0
		var pua := MeshInstance3D.new()
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.06
		cono.height = 0.16
		pua.mesh = cono
		pua.material_override = rubio
		pua.position = Vector3(cos(ang) * 0.09, 0.56, sin(ang) * 0.09)
		pua.rotation = Vector3(sin(ang) * 0.7, 0.0, -cos(ang) * 0.7)
		add_child(pua)
	add_child(Art.box(Vector3(0.26, 0.04, 0.02), Art.metal(Color(0.75, 0.76, 0.80), 0.0), Vector3(0.0, 0.47, -0.14)))
	add_trail(Color(0.95, 0.95, 0.95, 0.35), 12)


func expire() -> void:
	# Se deshace en humo, como todos los clones de sombra: pegue o no pegue.
	FX.spawn_humo(self, global_position)
	super()
