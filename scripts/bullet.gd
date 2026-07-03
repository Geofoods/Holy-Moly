extends Area2D

const LIFETIME = 3.0

var velocity := Vector2.ZERO

func setup(vel: Vector2) -> void:
	velocity = vel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		if body.has_method("take_damage"):
			body.take_damage(1)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
