class_name GearCoin
extends Area2D

@export var value: int = 1
@export var heals: bool = false
@export var collectible_id: String = ""

var age: float = 0.0
var collected: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	age += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	AudioManager.play("checkpoint" if heals else "coin")
	GameEvents.collectible_collected.emit(collectible_id, value, heals)
	if heals and body.has_method("heal"):
		body.heal(1)
	set_deferred("monitoring", false)
	visible = false
	queue_free()


func _draw() -> void:
	var bob := 0.0
	if heals:
		# Healing heart pickup (original).
		draw_circle(Vector2(-2.5, 0.0 + bob), 3.2, Color("e95f6a"))
		draw_circle(Vector2(2.5, 0.0 + bob), 3.2, Color("e95f6a"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-4.5, 1.5 + bob), Vector2(4.5, 1.5 + bob), Vector2(0.0, 6.0 + bob),
		]), Color("e95f6a"))
		PixelArt.rect(self, Vector2(-1, -1 + bob), Vector2(2, 4), Color("ffb3b8"))
		return
	# Classic gold coin (original pixel design).
	draw_circle(Vector2(0.0, bob), 6.0, Color("f7c948"))
	draw_circle(Vector2(0.0, bob), 4.0, Color("e8a33d"))
	PixelArt.rect(self, Vector2(-1, -5 + bob), Vector2(2, 10), Color("ffdf80"))
	PixelArt.rect(self, Vector2(-3, -2 + bob), Vector2(6, 2), Color("c97b1c"))
	PixelArt.rect(self, Vector2(-3, 0 + bob), Vector2(6, 2), Color("c97b1c"))
