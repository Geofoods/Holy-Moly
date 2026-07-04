extends Node2D

@onready var mole: CharacterBody2D = $CharacterBody2D2
@onready var dialogue = $DialogueBox

var steps := []
var step_index := -1

func _ready() -> void:
	mole.set_physics_process(false)
	mole.set_process(false)
	_build_steps()
	_show_step(0)

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
		{
			"text": "Almost there — head to the glowing exit to finish up.",
			"kind": "trigger",
			"node": "ExitTrigger",
		},
	]

func _show_step(i: int) -> void:
	step_index = i
	var step: Dictionary = steps[i]
	if step.has("on_start"):
		step["on_start"].call()

	dialogue.show_text(step["text"], i + 1, steps.size(), step["kind"] == "click")

	match step["kind"]:
		"click":
			dialogue.next_pressed.connect(_advance, CONNECT_ONE_SHOT)
		"trigger":
			var trigger := get_node(String(step["node"]))
			trigger.body_entered.connect(_on_trigger_entered, CONNECT_ONE_SHOT)
		"chest":
			var chest := get_node(String(step["node"]))
			chest.opened.connect(_advance, CONNECT_ONE_SHOT)

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
	if step_index + 1 >= steps.size():
		_finish()
	else:
		_show_step(step_index + 1)

func _finish() -> void:
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
