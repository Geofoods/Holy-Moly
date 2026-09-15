extends Node2D

## Shiny Lure: a shimmering decoy dropped by the mole. Enemies in the area
## retarget it and waddle over, ignoring the mole for a while.

const LIFETIME := 8.0

var _time := 0.0

func _ready() -> void:
	add_to_group("lure")
	z_index = 2

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _time >= LIFETIME:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
		set_process(false)
		return
	if randf() < 0.05:
		_spawn_spark()

func _spawn_spark() -> void:
	var spark := CPUParticles2D.new()
	spark.emitting = true
	spark.one_shot = true
	spark.amount = 8
	spark.lifetime = 0.4
	spark.explosiveness = 1.0
	spark.direction = Vector2.ZERO
	spark.spread = 180.0
	spark.initial_velocity_min = 30.0
	spark.initial_velocity_max = 80.0
	spark.scale_amount_min = 2.0
	spark.scale_amount_max = 5.0
	spark.color = Color(1.0, 0.9, 0.5, 1.0)
	get_parent().add_child(spark)
	spark.global_position = global_position
	get_tree().create_timer(0.5).timeout.connect(spark.queue_free)

func _draw() -> void:
	var bob := sin(_time * 6.0) * 6.0
	var shine := 0.6 + sin(_time * 10.0) * 0.4
	for i in 3:
		var inset := i * 3.0
		var r := 26.0 - inset
		draw_circle(Vector2(0, bob), r, Color(1.0, 0.82, 0.25 * (i % 2) + 0.8, 1.0))
	draw_circle(Vector2(0, bob), 10.0, Color(1.0, 1.0, 0.6, shine))