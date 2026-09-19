extends SceneTree

var _state := 0
var inst: Node = null
var frame := 0

func _physics_process(_delta: float) -> bool:
	frame += 1
	print("tick ", frame, " state=", _state)
	if _state == 0:
		inst = load("res://scenes/The Arena.tscn").instantiate()
		print("instantiated")
		root.add_child(inst)
		print("added")
		_state = 1
	elif _state == 1:
		_state = 2
	elif _state == 2:
		print("BEFORE world")
		var w := inst.get_world_2d()
		print("world ok ", w)
		print("BEFORE space")
		var space := w.direct_space_state
		print("space ok")
		var q := PhysicsRayQueryParameters2D.create(Vector2(8600, -300), Vector2(8600, 800))
		q.collide_with_areas = false
		var r := space.intersect_ray(q)
		print("ray empty=", r.is_empty())
		if not r.is_empty():
			print("hit=", r.position)
		return true
	return false