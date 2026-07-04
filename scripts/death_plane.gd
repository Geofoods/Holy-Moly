extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole") and body.has_method("start_fall_off_map_drain"):
		body.start_fall_off_map_drain()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole") and body.has_method("stop_fall_off_map_drain"):
		body.stop_fall_off_map_drain()


func _on_nextlevel_area_entered(area: Area2D) -> void:
	pass # Replace with function body.
