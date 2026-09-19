extends Node2D

@onready var mole: CharacterBody2D = $CharacterBody2D2
@onready var dialogue = $DialogueBox

var steps := []
var step_index := -1
var current_checkpoint: Vector2 = Vector2(-28, -116)
var _started_steps := {}
var _kill_enemy: Node = null

func _ready() -> void:
	mole.set_physics_process(false)
	mole.set_process(false)
	mole.death_override = _on_tutorial_death
	dialogue.prev_pressed.connect(_go_back)
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
			"text": "Welcome to the burrow, little mole! Let's learn the basics.",
			"kind": "click",
		},
		{
			"text": "Ready? Let's move!",
			"kind": "click",
			"on_start": func(): mole.set_physics_process(true); mole.set_process(true),
		},
		{
			"text": "MOVE: press A / D or the arrow keys. Walk to the right!",
			"kind": "trigger",
			"node": "MoveTrigger",
		},
		{
			"text": "JUMP: press W, the up arrow, or SPACE!\n**HOLD SPACE LONGER = JUMP HIGHER!** Tap for short hops.\n\nJump over the gap ahead!",
			"kind": "trigger",
			"node": "JumpTrigger",
		},
		{
			"text": "A treasure chest! Walk into it to open it and grab the loot inside.",
			"kind": "chest",
			"node": "TutorialChest",
		},
		{
			"text": "Alright, click on the chest and wall to break them!",
			"kind": "click",
		},
		{
			"text": "A Goblin! It throws explosive mushrooms.\nRIGHT-CLICK to PARRY them back, then close in. KILL it to continue!",
			"kind": "kill",
			"enemy": "GoblinEnemy",
			"checkpoint": Vector2(1800, -116),
		},
		{
			"text": "An Ant! LEFT-CLICK to attack it with your shovel. KILL it to continue!",
			"kind": "kill",
			"enemy": "AntEnemy",
			"checkpoint": Vector2(2200, -116),
		},
		{
			"text": "A Beetle! It charges fast but can't turn mid-rush. Sidestep it, then strike!",
			"kind": "trigger",
			"node": "BeetleTrigger",
			"checkpoint": Vector2(2900, -116),
		},
		{
			"text": "You got a BOMB! Press a number key (1-4) to select it, then LEFT-CLICK toward a wall. Massive damage and destruction!",
			"kind": "trigger",
			"node": "BombWallTrigger",
			"checkpoint": Vector2(3300, -116),
			"on_start": func(): Inventory.add_item(preload("res://resources/bomb.tres")),
		},
		{
			"text": "You got a DRILL! Select it, LEFT-CLICK toward walls. It tunnels through rocks and pierces enemies!",
			"kind": "trigger",
			"node": "DrillWallTrigger",
			"checkpoint": Vector2(3600, -116),
			"on_start": func(): Inventory.add_item(preload("res://resources/drill.tres")),
		},
		{
			"text": "DIG DASH: press SHIFT to tunnel forward, smashing through rocks and enemies in your path!",
			"kind": "click",
		},
	]

func _show_step(i: int) -> void:
	step_index = i
	var step: Dictionary = steps[i]
	if step.has("checkpoint"):
		current_checkpoint = step["checkpoint"]
	# Only run a step's on_start once, so going BACK then forward again doesn't
	# re-grant items or re-run setup.
	if step.has("on_start") and not _started_steps.has(i):
		_started_steps[i] = true
		step["on_start"].call()

	_disconnect_kill()
	if dialogue.next_pressed.is_connected(_advance):
		dialogue.next_pressed.disconnect(_advance)

	# "kill" steps hide NEXT and auto-advance only when the target enemy dies, so
	# the player must defeat it. If the enemy is already gone (e.g. the player hit
	# BACK after killing it) we fall back to a NEXT button. Every other step
	# advances only on a NEXT click. BACK is hidden on the very first step.
	var show_next := true
	if step.get("kind", "") == "kill":
		var enemy := get_node_or_null(NodePath(String(step["enemy"])))
		if enemy != null and is_instance_valid(enemy):
			show_next = false
			_kill_enemy = enemy
			enemy.connect("died", _advance, CONNECT_ONE_SHOT)

	dialogue.show_text(step["text"], i + 1, steps.size(), show_next, i > 0)
	if show_next:
		dialogue.next_pressed.connect(_advance, CONNECT_ONE_SHOT)

func _disconnect_kill() -> void:
	if _kill_enemy != null and is_instance_valid(_kill_enemy):
		if _kill_enemy.is_connected("died", _advance):
			_kill_enemy.disconnect("died", _advance)
	_kill_enemy = null

func _advance() -> void:
	if step_index + 1 >= steps.size():
		_finish()
	else:
		_show_step(step_index + 1)

func _go_back() -> void:
	if step_index > 0:
		_show_step(step_index - 1)

func _finish() -> void:
	_disconnect_kill()
	if dialogue.next_pressed.is_connected(_advance):
		dialogue.next_pressed.disconnect(_advance)
	var ending_text = "Perfect! You're ready, little mole.\nChain kills for COMBOS — good luck down there!"
	dialogue.show_text(ending_text, 0, 0, true)
	dialogue.next_button.text = "PLAY NOW >"
	dialogue.next_pressed.connect(_on_play_now_pressed, CONNECT_ONE_SHOT)

func _on_tutorial_death() -> void:
	mole.velocity = Vector2.ZERO
	mole.global_position = current_checkpoint
	mole.invulnerable = false
	mole.hurt_anim_time_left = 0.0
	mole.health = Inventory.MAX_HEALTH
	mole.set_physics_process(true)
	if is_instance_valid(dialogue) and is_instance_valid(dialogue.main_label):
		var original_text: String = dialogue.main_label.text
		dialogue.main_label.text = "That got you! Right back to it."
		await get_tree().create_timer(1.4).timeout
		if is_instance_valid(dialogue) and is_instance_valid(dialogue.main_label):
			dialogue.main_label.text = original_text

func _on_skip_pressed() -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/intro.tscn")

func _on_play_now_pressed() -> void:
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to("res://scenes/level1.tscn")
