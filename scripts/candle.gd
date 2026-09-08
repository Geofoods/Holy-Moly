extends RigidBody2D

func _ready() -> void:
	var mole = get_tree().get_first_node_in_group("mole")
	if mole is CollisionObject2D:
		add_collision_exception_with(mole)
