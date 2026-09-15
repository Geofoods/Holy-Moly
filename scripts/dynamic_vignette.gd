extends ColorRect

const SURFACE_Y := 850.0
const ABOVE_INNER := 0.50
const ABOVE_OUTER := 0.85
const BELOW_INNER := 0.42
const BELOW_OUTER := 0.72
const TRANSITION_SPEED := 2.0

var target_inner := ABOVE_INNER
var target_outer := ABOVE_OUTER

func _process(delta: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	if not mole:
		return

	var depth: float = mole.global_position.y - SURFACE_Y
	var t := clampf(depth / 500.0, 0.0, 1.0)
	target_inner = lerp(ABOVE_INNER, BELOW_INNER, t)
	target_outer = lerp(ABOVE_OUTER, BELOW_OUTER, t)

	var mat := material as ShaderMaterial
	var current_inner: float = mat.get_shader_parameter("inner_radius")
	var current_outer: float = mat.get_shader_parameter("outer_radius")
	mat.set_shader_parameter("inner_radius", lerp(current_inner, target_inner, TRANSITION_SPEED * delta))
	mat.set_shader_parameter("outer_radius", lerp(current_outer, target_outer, TRANSITION_SPEED * delta))
