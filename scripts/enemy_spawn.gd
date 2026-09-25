extends Node
## Spawn-in animation for the arena's wave enemies.
##
## The wave manager calls [method play] the moment an enemy is ready. The enemy
## is frozen and shrunk to nothing, then bursts up out of the ground: dirt sprays
## up, the body rises from below while scaling in from zero, and a bright flash
## fades off it. The enemy stays inert and untouchable until it has fully
## emerged, so a wave can never land a free hit while it materialises.
##
## Kept as a static helper (like [TileBreakSFX]) so the effect lives in one place
## and the wave manager only needs a single call per enemy.

## How long the pop takes once it starts.
const DURATION := 0.4
## How far below its resting spot the body starts, so it reads as rising up.
const RISE := 40.0
## Enemies start at (almost) no scale and grow in, rather than appearing whole.
const START_SCALE := 0.05

const DIRT_AMOUNT := 18
const DIRT_LIFETIME := 0.5

## Plays the spawn-in on `enemy`. `delay` staggers the members of a wave so they
## surge in one after another instead of popping as a single block; the enemy is
## held frozen and hidden for that delay.
static func play(enemy: Node2D, delay := 0.0) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var visual := enemy.get_node_or_null("Visual") as Node2D
	if visual == null:
		return

	var base_scale := enemy.scale
	var base_modulate := enemy.modulate
	var base_visual_pos := visual.position
	var areas := _disable_areas(enemy)

	enemy.set_physics_process(false)
	enemy.scale = base_scale * START_SCALE
	enemy.modulate = Color(base_modulate.r + 0.9, base_modulate.g + 0.9, base_modulate.b + 0.9, 0.0)
	visual.position = base_visual_pos + Vector2(0.0, RISE)

	if delay > 0.0:
		# process_always = false, so the stagger waits out pauses along with the
		# tween instead of firing mid-cutscene and leaving the enemy frozen.
		var timer := enemy.get_tree().create_timer(delay, false)
		timer.timeout.connect(_emerge.bind(enemy, visual, areas, base_scale, base_modulate, base_visual_pos))
	else:
		_emerge(enemy, visual, areas, base_scale, base_modulate, base_visual_pos)

## Unbound parameters on purpose: the enemy (or its Visual) may have been freed
## while a staggered delay was still ticking, and assigning a freed instance to a
## typed parameter raises.
static func _emerge(enemy, visual, areas: Array, base_scale: Vector2, base_modulate: Color, base_visual_pos: Vector2) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(visual):
		return
	_spawn_dirt_burst(enemy)
	SFX.play("land", enemy.global_position, -12.0, 0.15, 0.75)

	var tween: Tween = enemy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy, "scale", base_scale, DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, "modulate", base_modulate, DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "position", base_visual_pos, DURATION * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_restore.bind(enemy, areas))

## Hands the enemy back to its own AI once it has fully emerged.
static func _restore(enemy, areas: Array) -> void:
	if not is_instance_valid(enemy):
		return
	enemy.set_physics_process(true)
	for entry in areas:
		var area: Area2D = entry[0]
		if is_instance_valid(area):
			area.set_deferred("monitoring", entry[1])
			area.set_deferred("monitorable", entry[2])

## Turns off the enemy's hurt/hit boxes while it emerges, so nothing can trade
## hits with a half-spawned body. The previous states are returned so they can be
## put back exactly as they were - the hornet's hitbox, for instance, starts out
## unmonitorable, and blanket-enabling it would change how it fights.
static func _disable_areas(enemy: Node2D) -> Array:
	var saved: Array = []
	# The arena enemies disagree on the name of their hurtbox: the older ones use
	# a plain "Area2D", the newer ones "Hurtbox"/"Hitbox".
	for area_name in ["Hurtbox", "Hitbox", "Area2D"]:
		var area := enemy.get_node_or_null(area_name) as Area2D
		if area == null:
			continue
		saved.append([area, area.monitoring, area.monitorable])
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
	return saved

static func _spawn_dirt_burst(enemy: Node2D) -> void:
	var parent := enemy.get_parent()
	if parent == null:
		return
	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = DIRT_AMOUNT
	burst.lifetime = DIRT_LIFETIME
	burst.explosiveness = 1.0
	burst.direction = Vector2(0.0, -1.0)
	burst.spread = 80.0
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 220.0
	burst.gravity = Vector2(0.0, 620.0)
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 8.0
	var grad := Gradient.new()
	grad.set_color(0, Color(0.58, 0.42, 0.26, 0.95))
	grad.set_color(1, Color(0.4, 0.28, 0.16, 0.0))
	burst.color_ramp = grad
	burst.z_index = 4
	parent.add_child(burst)
	burst.global_position = enemy.global_position + Vector2(0.0, RISE)

	var tree := enemy.get_tree()
	if tree != null:
		tree.create_timer(DIRT_LIFETIME + 0.4, false).timeout.connect(func() -> void:
			if is_instance_valid(burst):
				burst.queue_free()
		)
