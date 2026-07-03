extends Label

func _process(_delta):
	var mole = get_tree().get_first_node_in_group("mole")
	if mole:
		text = "HP " + str(mole.health) + "/6"
