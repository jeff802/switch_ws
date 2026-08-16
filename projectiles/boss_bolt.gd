class_name BossBolt
extends Area2D

enum Style { STONE, SEED, GEAR, LIGHTNING, MAGMA, FROST, CHRONO }

var velocity: Vector2 = Vector2.ZERO
var gravity_force: float = 0.0
var style: Style = Style.STONE
var lifetime: float = 4.0
var spin_speed: float = 0.0


func _ready() -> void:
	add_to_group("boss_projectiles")
	body_entered.connect(_on_body_entered)


func launch(origin: Vector2, initial_velocity: Vector2, new_style: int, new_gravity: float = 0.0) -> void:
	global_position = origin
	velocity = initial_velocity
	style = new_style as Style
	gravity_force = new_gravity
	spin_speed = signf(initial_velocity.x) * (5.5 if style in [Style.GEAR, Style.CHRONO] else 2.5)
	queue_redraw()


func _physics_process(delta: float) -> void:
	velocity.y += gravity_force * delta
	global_position += velocity * delta
	rotation += spin_speed * delta
	lifetime -= delta
	if lifetime <= 0.0 or global_position.y > 340.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1, global_position)
	queue_free()


func _draw() -> void:
	match style:
		Style.SEED:
			PixelArt.diamond(self, Vector2.ZERO, 6.0, Color("173d31"))
			PixelArt.diamond(self, Vector2.ZERO, 4.0, Color("5de17d"))
			PixelArt.rect(self, Vector2(-1, -3), Vector2(2, 3), Color("d9ff8c"))
		Style.GEAR:
			PixelArt.diamond(self, Vector2.ZERO, 7.0, Color("17232b"))
			PixelArt.diamond(self, Vector2.ZERO, 5.0, Color("69ddea"))
			PixelArt.diamond(self, Vector2.ZERO, 2.0, Color("fff0a0"))
			for offset: Vector2 in [Vector2(-8, -1), Vector2(6, -1), Vector2(-1, -8), Vector2(-1, 6)]:
				PixelArt.rect(self, offset, Vector2(3, 3), Color("243b46"))
		Style.LIGHTNING:
			PixelArt.diamond(self, Vector2.ZERO, 7.0, Color("15243d"))
			PixelArt.diamond(self, Vector2.ZERO, 5.0, Color("63d9ff"))
			PixelArt.rect(self, Vector2(-1, -5), Vector2(3, 10), Color("f6ff9a"))
		Style.MAGMA:
			draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.25, 0.05, 0.2))
			PixelArt.diamond(self, Vector2.ZERO, 6.0, Color("7c241d"))
			PixelArt.diamond(self, Vector2.ZERO, 4.0, Color("ff6d32"))
			PixelArt.rect(self, Vector2(-1, -3), Vector2(2, 4), Color("ffe36d"))
		Style.FROST:
			PixelArt.diamond(self, Vector2.ZERO, 7.0, Color("294b6b"))
			PixelArt.diamond(self, Vector2.ZERO, 5.0, Color("8deaff"))
			PixelArt.diamond(self, Vector2.ZERO, 2.0, Color.WHITE)
		Style.CHRONO:
			PixelArt.diamond(self, Vector2.ZERO, 7.0, Color("241b39"))
			PixelArt.diamond(self, Vector2.ZERO, 5.0, Color("c46cff"))
			PixelArt.rect(self, Vector2(-1, -4), Vector2(2, 5), Color("fff1a0"))
			PixelArt.rect(self, Vector2(0, 0), Vector2(4, 2), Color("fff1a0"))
		_:
			PixelArt.rect(self, Vector2(-6, -5), Vector2(12, 10), Color("28363d"))
			PixelArt.rect(self, Vector2(-4, -4), Vector2(6, 4), Color("75888b"))
			PixelArt.rect(self, Vector2(1, 1), Vector2(4, 3), Color("c67b45"))
