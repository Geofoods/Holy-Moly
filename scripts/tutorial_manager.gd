extends Node2D

@onready var mole: CharacterBody2D = $CharacterBody2D2
@onready var dialogue = $DialogueBox

var steps := []
var step_index := -1
var _pending_signal: Signal
var _has_pending_signal := false
var current_checkpoint: Vector2 = Vector2(-28, -116)

func _ready() -> void:
	mole.set_physics_process(false)
	mole.set_process(false)
	mole.death_override = _on_tutorial_death
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
			"text": "Ready? Let's move.",
			"kind": "click",
			"on_start": func(): mole.set_physics_process(true); mole.set_process(true),
		},
		{
			"text": "MOVE: press A / D or ◄ ►.",
			"kind": "trigger",
			"node": "MoveTrigger",
		},
		{
			"text": "JUMP: press W, ▲, or SPACE. Hold longer for higher jumps, tap for short hops!",
			"kind": "trigger",
			"node": "JumpTrigger",
		},
		{
			"text": "An Ant! The weakest enemy here. Left-click to attack with your shovel, or just outrun it.",
			"kind": "trigger",
			"node": "EnemyTrigger",
			"checkpoint": Vector2(2500, -116),
		},
		{
			"text": "Nice! Walk into the chest to open it.",
			"kind": "chest",
			"node": "Chest",
		},
		{
			"text": "TIP: Right-click to PARRY — it deflects enemy projectiles back at them! 3 second cooldown.",
			"kind": "click",
		},
		{
			"text": "A Beetle! It charges fast but can't turn mid-rush. Sidestep the rush, then punish while they recover.",
			"kind": "trigger",
			"node": "BeetleTrigger",
			"checkpoint": Vector2(6050, -116),
		},
		{
			"text": "A Goblin! It throws explosive mushrooms at you. Keep moving and close the gap to strike.",
			"kind": "trigger",
			"node": "GoblinTrigger",
			"checkpoint": Vector2(7300, -116),
		},
		{
			"text": "You got a Bomb! Press its slot number (shown in the hotbar), then Left-click toward the wall to blow it open. Bombs deal massive damage to enemies and tiles!",
			"kind": "trigger",
			"node": "BombWallTrigger",
			"checkpoint": Vector2(8350, -116),
			"on_start": func(): Inventory.add_item(preload("res://resources/bomb.tres")),
		},
		{
			"text": "You got a Drill! It tunnels through rock and damages enemies. Select it, then Left-click toward the wall ahead. It lasts a few seconds.",
			"kind": "trigger",
			"node": "DrillWallTrigger",
			"checkpoint": Vector2(9200, -116),
			"on_start": func(): Inventory.add_item(preload("res://resources/drill.tres")),
		},
		{
			"text": "COMBAT TIPS: Keep moving to dodge attacks. Use your Shovel for close-range hits. Parry (right-click) to send projectiles back at enemies!",
			"kind": "click",
		},
		{
			"text": "SURVIVAL TIPS: Stay alert for enemies around corners. Use the terrain to your advantage. A perfect combo lets you move faster!",
			"kind": "click",
		},
		{
			"text": "ITEMS & HOTBAR: Pick up Bombs and Drills to unlock new ways to fight and break through walls. Press 1, 2, or 3 to select items.",
			"kind": "click",
		},
	]

func _show_step(i: int) -> void:
	step_index = i
	var step: Dictionary = steps[i]
	if step.has("checkpoint"):
		current_checkpoint = step["checkpoint"]
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
	var ending_text = "Perfect! You've mastered the basics:\n• MOVE (A/D or ◄►) and JUMP (W/SPACE)\n• ATTACK (Left-click) and PARRY (Right-click)\n• BOMB for massive damage and destruction\n• DRILL to tunnel and pierce enemies\n\nRemember: Stay mobile, parry projectiles, and use items strategically. Your combo multiplier speeds you up! Ready for the real adventure?"
	dialogue.show_text(ending_text, 0, 0, true)
	dialogue.next_button.text = "PLAY NOW ▸"
	dialogue.next_pressed.connect(_on_play_now_pressed, CONNECT_ONE_SHOT)

func _on_tutorial_death() -> void:
	mole.velocity = Vector2.ZERO
	mole.global_position = current_checkpoint
	mole.invulnerable = false
	mole.hurt_anim_time_left = 0.0
	mole.health = 6
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
	transition.change_to("res://scenes/main.tscn")
