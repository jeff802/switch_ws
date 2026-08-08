class_name LevelExit
extends Area2D

@export var unlock_level_id: String = ""
@export_file("*.tscn") var next_scene: String = ""
var entered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if entered or not body.is_in_group("player"):
		return
	entered = true
	GameManager.finish_level(unlock_level_id, next_scene)


func _draw() -> void:
	PixelArt.rect(self, Vector2(-2, -34), Vector2(4, 38), Color("30464d"))
	PixelArt.rect(self, Vector2(2, -32), Vector2(18, 13), Color("38a58b"))
	PixelArt.diamond(self, Vector2(19, -25), 3.0, Color("d7ffe8"))

