extends "res://scripts/bomb.gd"

func _ready() -> void:
	super()
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)

func _on_body_entered(_body: Node) -> void:
	_explode()
