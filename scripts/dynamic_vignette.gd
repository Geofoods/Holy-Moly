extends ColorRect

const SURFACE_Y := 850.0
const ABOVE_INNER := 0.50
const ABOVE_OUTER := 0.85
const BELOW_INNER := 0.42
const BELOW_OUTER := 0.72
const TRANSITION_SPEED := 2.0

var target_inner := ABOVE_INNER
var target_outer := ABOVE_OUTER

var _settled := false
var _last_target_inner := -1.0
var _last_target_outer := -1.0

func _process(delta: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	if not mole:
		return

	var depth: float = mole.global_position.y - SURFACE_Y
	var t := clampf(depth / 500.0, 0.0, 1.0)
	target_inner = lerp(ABOVE_INNER, BELOW_INNER, t)
	target_outer = lerp(ABOVE_OUTER, BELOW_OUTER, t)

	# Once the transition has converged, stop pushing shader uniforms to the
	# GPU every frame (uniform uploads invalidate material state even when
	# the value is unchanged). Resume when the mole's depth changes the target.
	if target_inner != _last_target_inner or target_outer != _last_target_outer:
		_settled = false
		_last_target_inner = target_inner
		_last_target_outer = target_outer
	if _settled:
		return
	var mat := material as ShaderMaterial
	var current_inner: float = mat.get_shader_parameter("inner_radius")
	var current_outer: float = mat.get_shader_parameter("outer_radius")
	var new_inner: float = lerp(current_inner, target_inner, TRANSITION_SPEED * delta)
	var new_outer: float = lerp(current_outer, target_outer, TRANSITION_SPEED * delta)
	if absf(new_inner - target_inner) < 0.001 and absf(new_outer - target_outer) < 0.001:
		new_inner = target_inner
		new_outer = target_outer
		_settled = true
	mat.set_shader_parameter("inner_radius", new_inner)
	mat.set_shader_parameter("outer_radius", new_outer)
