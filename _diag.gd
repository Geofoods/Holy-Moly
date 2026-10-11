extends SceneTree

var mc = null
var dlg = null
var frame := 0

func _initialize() -> void:
	mc = load("res://mobile_controls.tscn").instantiate()
	mc.set_script(load("res://scripts/mobile_controls.gd"))
	mc.enabled = true
	root.add_child(mc)

func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		# create the dialogue on a real frame, not during _initialize
		dlg = load("res://scenes/dialogue_box.tscn").instantiate()
		root.add_child(dlg)
		print("panel=", dlg.get_node_or_null("Panel"))
		print("step_label=", dlg.get("step_label"))
		var ds = load("res://scripts/dialogue_box.gd")
		print("script equal=", dlg.get_script() == ds)
		dlg.show_text("Hello there", 1, 2, true, false)
		print("show_text ok, offset=", dlg.offset)
		print("f1 visible=", mc.visible, " dialogue_open=", mc._dialogue_is_open())
	elif frame == 3:
		print("f3 visible=", mc.visible, " dialogue_open=", mc._dialogue_is_open())
		dlg.queue_free()
	elif frame == 4:
		print("f4 (after free) visible=", mc.visible, " dialogue_open=", mc._dialogue_is_open())
		for c in root.get_children():
			print("   root child: ", c.name, " script=", c.get_script())
	elif frame == 6:
		print("f6 visible=", mc.visible, " dialogue_open=", mc._dialogue_is_open())
		return true
	return false
