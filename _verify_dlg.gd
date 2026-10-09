extends SceneTree

var mc: CanvasLayer = null
var dlg: CanvasLayer = null
var button: Button = null
var state := 0
var frame := 0
var next_pressed := false
var dash_pressed := false
var failures := 0

class Catcher extends Node:
	var hits := []
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch:
			hits.append([event.as_text().get_slice(":", 0), event.position])

func _fail(what: String) -> void:
	failures += 1
	print("FAIL: ", what)

func _check(cond: bool, what: String) -> void:
	if cond:
		print("PASS: ", what)
	else:
		_fail(what)

func _tap(pos: Vector2) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = true
	Input.parse_input_event(t)
	var r := InputEventScreenTouch.new()
	r.index = 0
	r.position = pos
	r.pressed = false
	Input.parse_input_event(r)

func _initialize() -> void:
	mc = load("res://mobile_controls.tscn").instantiate()
	mc.set_script(load("res://scripts/mobile_controls.gd"))
	mc.enabled = true
	root.add_child(mc)
	var catcher := Catcher.new()
	root.add_child(catcher)
	# Loaded at runtime on purpose: dialogue_box.gd names the SFX autoload, and
	# autoload names only resolve once the engine is up, not while a --script
	# probe is being parsed.
	dlg = load("res://scenes/dialogue_box.tscn").instantiate()
	root.add_child(dlg)
	dlg.show_text("One step away from the keyboard.\r\nJust reach out and touch it.", 1, 2, true, false)
	button = dlg.get_node("Panel/MarginContainer/VBoxContainer/NextRow/NextButton") as Button
	button.pressed.connect(func() -> void: next_pressed = true)
	mc.dig_dash_pressed.connect(func() -> void: dash_pressed = true)
	print("button rect=", button.get_global_rect(), " panel offset=", dlg.offset)

func _physics_process(_d: float) -> bool:
	frame += 1
	if state == 0:
		state = 1
	elif state == 1:
		state = 2
	elif state == 2:
		# dialogue open -> overlay must step aside
		print("frame ", frame, ": overlay hidden during dialogue = ", not mc.visible)
		state = 3
	elif state == 3:
		state = 4
	elif state == 4:
		# slide-in is done (offset 0); tap the button where a finger reaches it
		var rect := button.get_global_rect()
		rect.position += dlg.offset
		_tap(rect.get_center())
		print("button real rect=", rect)
		state = 5
	elif state == 5:
		state = 6
	elif state == 6:
		_check(next_pressed, "tap on Next button reaches the dialogue (next fires)")
		_check(not dash_pressed, "tap on Next does NOT fire dig dash")
		_check(not mc.visible, "overlay stays hidden while dialogue open")
		dlg.queue_free()
		state = 7
	elif state == 7:
		state = 8
	elif state == 8:
		_check(mc.visible, "overlay returns after dialogue closes")
		_tap(Vector2(1254, 542))
		state = 9
	elif state == 9:
		state = 10
	elif state == 10:
		_check(dash_pressed, "dig dash button still works after dialogue")
		print("TOTAL FAILURES: ", failures)
		return true
	return false
