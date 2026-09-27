class_name BolaTela
extends Projectile
## La bola de telaraña de Spider-Man: blanca, con los hilos, y pegajosa.


func _init() -> void:
	tint = Color(0.95, 0.95, 0.97)
	hit_radius = 0.38
	fall_gravity = 0.0
	impact_sound = &"telarana"
	knockback = 1.0


func _build_visual() -> void:
	var tela := Art.toon(Color(0.95, 0.95, 0.97), 0.0)
	add_child(Art.sphere(0.16, tela))
	for k: int in range(4):
		var hilo := Art.box(Vector3(0.44, 0.015, 0.015), tela)
		hilo.rotation_degrees = Vector3(0.0, float(k) * 45.0, 20.0)
		add_child(hilo)
	add_trail(Color(0.95, 0.95, 1.0, 0.45), 14)


func _on_hit_player(target: Node3D) -> void:
	super(target)
	var estado := target.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.apply_slow(Telarana.LENTO, Telarana.LENTO_DURA)
	FX.spawn_telarana_pegada(target)
