extends Node2D

@onready var mole: CharacterBody2D = $CharacterBody2D2
@onready var dialogue = $DialogueBox

var steps := []
var step_index := -1
var _pending_signal: Signal
var _has_pending_signal := false

func _ready() -> void:
	mole.set_physics_process(false)
	mole.set_process(false)
	_build_steps()
	_show_step(0)
	_reposition_inventory_ui()

func _reposition_inventory_ui() -> void:
	var inv_ui = get_node_or_null("InventoryUI")
	if inv_ui and inv_ui.has_method("reposition"):
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		inv_ui.reposition(Vector2(vp_size.x / 2.0, 90.0))

func _build_steps() -> void:
	steps = [
		{
			"text": "Welcome, little mole! Corruption is spreading through the burrow, deep across 9 twisted levels below.",
			"kind": "click",
		},
		{
			"text": "Enemies will shoot and charge at you, and gaps or hazards can hurt you too. Let's learn how to survive.",
			"kind": "click",
			"on_start": func(): mole.set_physics_process(true); mole.set_process(true),
		},
		{
			"text": "Use A / D or ◄ ► to move.",
			"kind": "trigger",
			"node": "MoveTrigger",
		},
		{
			"text": "Press W, ▲ or SPACE to jump onto that platform.",
			"kind": "trigger",
			"node": "JumpTrigger",
		},
		{
			"text": "An enemy! Left-click to swing your shovel and defeat it — or just jump past to avoid it.",
			"kind": "trigger",
			"node": "EnemyTrigger",
		},
		{
			"text": "Tip: Right-click to PARRY! Your shovel flips into a guard for 2 seconds. Any bullet that hits it deflects toward your cursor! (5s cooldown)",
			"kind": "click",
		},
		{
			"text": "Nice work! Walk into this chest to open it.",
			"kind": "chest",
			"node": "Chest",
		},
	]

func _show_step(i: int) -> void:
	step_index = i
	var step: Dictionary = steps[i]
	if step.has("on_start"):
		step["on_start"].call()

	_clear_pending_signal()

	# Always show a Next button so the player is never stuck waiting on a
	# trigger/chest that fails to fire — it's a manual fallback alongside
	# the automatic gameplay-based advance.
	dialogue.show_text(step["text"], i + 1, steps.size(), true)
	if dialogue.next_pressed.is_connected(_advance):
		dialogue.next_pressed.disconnect(_advance)
	dialogue.next_pressed.connect(_advance, CONNECT_ONE_SHOT)

	match step["kind"]:
		"trigger":
			var trigger := get_node(String(step["node"]))
			_pending_signal = trigger.body_entered
			_has_pending_signal = true
			trigger.body_entered.connect(_on_trigger_entered, CONNECT_ONE_SHOT)
		"chest":
			var chest := get_node(String(step["node"]))
			var interaction: Node = chest.get_node_or_null("Interaction")
			if interaction == null:
				interaction = chest
			_pending_signal = interaction.opened
			_has_pending_signal = true
			interaction.opened.connect(_advance, CONNECT_ONE_SHOT)

func _clear_pending_signal() -> void:
	if _has_pending_signal and _pending_signal.get_object():
		if _pending_signal.is_connected(_on_trigger_entered):
			_pending_signal.disconnect(_on_trigger_entered)
		if _pending_signal.is_connected(_advance):
			_pending_signal.disconnect(_advance)
	_has_pending_signal = false

func _on_trigger_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_advance()
	else:
		# Reconnect if a non-mole body triggered it first (e.g. the enemy).
		var step: Dictionary = steps[step_index]
		if step["kind"] == "trigger":
			var trigger := get_node(String(step["node"]))
			trigger.body_entered.connect(_on_trigger_entered, CONNECT_ONE_SHOT)

func _advance() -> void:
	_clear_pending_signal()
	if step_index + 1 >= steps.size():
		_finish()
	else:
		_show_step(step_index + 1)

func _finish() -> void:
	_clear_pending_signal()
	if dialogue.next_pressed.is_connected(_advance):
		dialogue.next_pressed.disconnect(_advance)
	dialogue.show_text("Great job! You now know the basics. You're ready to begin your adventure. Good luck!", 0, 0, true)
	dialogue.next_button.text = "PLAY NOW ▸"
	dialogue.next_pressed.connect(_on_play_now_pressed, CONNECT_ONE_SHOT)

func _on_skip_pressed() -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")

func _on_play_now_pressed() -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/main.tscn")
