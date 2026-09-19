extends Node

var _state := 0
var _inst: Node = null

func _ready() -> void:
	print("PROBE ready")

func _physics_process(_delta: float) -> void:
	if _state == 0:
		_inst = load("res://scenes/The Arena.tscn").instantiate()
		get_tree().root.add_child(_inst)
		_state = 1
	elif _state == 1:
		_state = 2
	elif _state == 2:
		var space := _inst.get_world_2d().direct_space_state
		for n in ["Enemy", "Enemy2", "Enemy3", "Enemy4", "Enemy5"]:
			var e := _inst.get_node_or_null(n) as Node2D
			if e == null:
				print(n, " missing")
				continue
			var from := Vector2(e.global_position.x, e.global_position.y - 40.0)
			var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 1500))
			q.collide_with_areas = false
			var r := space.intersect_ray(q)
			print(n, " pos=", e.global_position, " floor=", -1.0 if r.is_empty() else r.position.y)
		for ray in [
			["downL", Vector2(7800, -300), Vector2(7800, 800)],
			["downM", Vector2(8600, -300), Vector2(8600, 800)],
			["downR", Vector2(9900, -300), Vector2(9900, 800)],
			["left", Vector2(8600, -300), Vector2(6600, -300)],
			["right", Vector2(8600, -300), Vector2(11000, -300)],
			["upL", Vector2(8600, -300), Vector2(8600, -1700)],
			["upR", Vector2(9900, -300), Vector2(9900, -1700)],
		]:
			var qq := PhysicsRayQueryParameters2D.create(ray[1], ray[2])
			qq.collide_with_areas = false
			var rr := space.intersect_ray(qq)
			print(ray[0], " from ", ray[1], " -> ", "NONE" if rr.is_empty() else str(rr.position))
		get_tree().quit()