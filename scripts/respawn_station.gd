extends RigidBody2D

## Respawn station. Bank it and the mole rematerialises on this pad after a
## death instead of at the level's entrance.
##
## The station deliberately owns both halves of that deal: the saved record
## (which scene, which spot) and the animation the mole plays on arrival. The
## pad that lights up when you bank a checkpoint is the same pad you come back
## to, so there is no second object that has to agree with this one.
##
## Progress (autoload) holds the record. mole.gd asks this node to play the
## arrival when a scene loads; game_over.gd sends the mole back here on retry.

## The mole materialises on the pad, not on the exact spot it banked from, so a
## respawn never drops the player inside the station's frame.
@export var spawn_offset := Vector2(0.0, -120.0)

## Turn this off for a station that should light up and take a prompt but never
## becomes the checkpoint - decoration in the mole village, or a cutscene beat.
@export var checkpoints := true

@export var prompt_text := "PRESS E: SET CHECKPOINT"
@export var prompt_offset := Vector2(0.0, -440.0)

const PROMPT_HALF_WIDTH := 190.0
const PROMPT_HEIGHT := 60.0

## The prompt's blue, and the lighter blue it shifts to the moment this pad
## becomes the banked checkpoint - the same beat as the text flips to CHECKPOINT
## SET, so wording and colour read as one state change. The resting value is the
## deeper of the two deliberately: both states have to be blue for the change to
## read as a lightening rather than as the label being repainted some other
## colour. Mirrored into the Prompt node's own font override in respawn_station.tscn
## so the scene shows the resting state before the first _process lands.
const PROMPT_COLOR := Color(0.35, 0.75, 1.0, 1.0)
const PROMPT_COLOR_ACTIVE := Color(0.72, 0.94, 1.0, 1.0)

## Arrival animation. The mole starts sunk below the pad, rises to it, then
## squash-and-stretch lands. Timing is in seconds.
const ARRIVE_SINK := 190.0
const ARRIVE_LEAD_IN := 0.12
const ARRIVE_RISE := 0.34
const ARRIVE_FADE := 0.22
const ARRIVE_POP := 0.2
const ARRIVE_FLASH := 0.4

## Pad light, in energy units. Fully off until the station is banked, then a
## visible cyan glow that marks the active checkpoint.
const LIGHT_IDLE := 0.0
const LIGHT_ACTIVE := 0.9
const LIGHT_FLASH_DECAY := 3.4
const PULSE_RATE := 2.2

@onready var _area: Area2D = $InteractionArea
@onready var _prompt: Label = $Prompt
@onready var _light: PointLight2D = $PadLight

var _mole_nearby := false
var _arriving := false
var _phase := 0.0
var _flash := 0.0
var _pad_particles: CPUParticles2D = null
var _orb_particles: CPUParticles2D = null

func _ready() -> void:
	add_to_group("respawn_station")
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_setup_prompt()
	_setup_particles()
	_phase = randf_range(0.0, TAU)

## The prompt is a top-level Label positioned in world space each frame, which is
## how npc_mole.gd does it: it keeps the label axis-aligned and crisp while the
## station itself is free to be placed at any scale.
func _setup_prompt() -> void:
	_prompt.top_level = true
	_prompt.z_index = 200
	_prompt.z_as_relative = false
	_prompt.light_mask = 0
	_prompt.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_prompt.offset_left = 0.0
	_prompt.offset_top = 0.0
	_prompt.offset_right = 0.0
	_prompt.offset_bottom = 0.0
	if not prompt_text.is_empty():
		_prompt.text = prompt_text
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false

func _setup_particles() -> void:
	# Built in code rather than in the scene file, matching how the rest of the
	# project makes particles (mole.gd, enemy.gd) and keeping the ramps inline.
	_orb_particles = _make_particles("OrbParticles", 8, 0.9, false)
	_orb_particles.position = Vector2(-4.0, -198.0)
	_orb_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_orb_particles.emission_sphere_radius = 34.0
	_orb_particles.direction = Vector2(0.0, -1.0)
	_orb_particles.spread = 25.0
	_orb_particles.gravity = Vector2(0.0, -40.0)
	_orb_particles.initial_velocity_min = 20.0
	_orb_particles.initial_velocity_max = 55.0
	_orb_particles.scale_amount_min = 1.4
	_orb_particles.scale_amount_max = 3.2
	_orb_particles.color_ramp = _ramp(Color(0.40, 0.92, 1.0, 0.45), Color(0.40, 0.92, 1.0, 0.0))
	add_child(_orb_particles)

	_pad_particles = _make_particles("PadParticles", 26, 0.7, true)
	_pad_particles.position = spawn_offset
	_pad_particles.spread = 180.0
	_pad_particles.initial_velocity_min = 110.0
	_pad_particles.initial_velocity_max = 320.0
	_pad_particles.gravity = Vector2(0.0, 620.0)
	_pad_particles.damping_min = 40.0
	_pad_particles.damping_max = 90.0
	_pad_particles.scale_amount_min = 4.0
	_pad_particles.scale_amount_max = 10.0
	_pad_particles.color_ramp = _ramp(Color(0.55, 0.95, 1.0, 0.95), Color(0.35, 0.8, 0.95, 0.0))
	add_child(_pad_particles)

func _make_particles(node_name: String, amount: int, lifetime: float, one_shot: bool) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.name = node_name
	particles.emitting = false
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.explosiveness = 1.0 if one_shot else 0.0
	particles.lifetime_randomness = 0.35
	particles.z_index = 4
	particles.light_mask = 2
	return particles

func _ramp(from: Color, to: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	return gradient

func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * PULSE_RATE, TAU)
	# The burst flash rides on top of the steady idle/active energy rather than
	# tweening it, so an activation and the breathing light can't fight each
	# other over the same property.
	_flash = maxf(0.0, _flash - delta * LIGHT_FLASH_DECAY)
	var lit := is_checkpoint_active()
	if _light:
		_light.visible = lit
		_light.energy = ((LIGHT_ACTIVE if lit else LIGHT_IDLE) + _flash) * (0.93 + 0.07 * sin(_phase))
	if _orb_particles:
		_orb_particles.emitting = lit
	_position_prompt(lit)

func _position_prompt(lit: bool) -> void:
	# Hidden while arriving so the label doesn't slide in over the animation,
	# and on a station that can't actually bank anything.
	var show := _mole_nearby and checkpoints and not _arriving
	_prompt.visible = show and not prompt_text.is_empty()
	if not _prompt.visible:
		return
	var text := prompt_text
	if lit:
		text = "CHECKPOINT SET"
	_prompt.text = text
	_prompt.add_theme_color_override("font_color", PROMPT_COLOR_ACTIVE if lit else PROMPT_COLOR)
	var at := global_position + prompt_offset
	_prompt.offset_left = at.x - PROMPT_HALF_WIDTH
	_prompt.offset_right = at.x + PROMPT_HALF_WIDTH
	_prompt.offset_top = at.y
	_prompt.offset_bottom = at.y + PROMPT_HEIGHT

## 0..1 breath value the art and the light both read, so they animate as one.
func pulse() -> float:
	return 0.5 + 0.5 * sin(_phase)

## Raw 0..1 ramp of the same breath, for anything that needs a linear rate.
func cycle() -> float:
	return fposmod(_phase, TAU) / TAU

## Whether this pad is the one the mole banked, which is what lights it up.
##
## Matched on the scene alone, not on a recorded point inside the pad. Travel
## from the map has no pad position to record - it only knows the scene - and
## every scene with a station has exactly one, so there is nothing to tell two
## pads apart. Adding a second station to a scene would need the point test
## back.
##
## Reads the activation record rather than the respawn record on purpose. Both
## name the scene the mole is set to arrive at, but the respawn record is also
## written by map travel and by a death, so testing it would light a pad the
## player has walked past without ever using.
func is_checkpoint_active() -> bool:
	if not checkpoints:
		return false
	return Progress.respawn_activated == _scene_path()

## Where the mole materialises: on the pad, clear of the station's frame.
func spawn_point() -> Vector2:
	return global_position + spawn_offset

func _scene_path() -> String:
	var scene := get_tree().current_scene
	return "" if scene == null else str(scene.scene_file_path)

func _unhandled_input(event: InputEvent) -> void:
	if not _mole_nearby or not checkpoints or _arriving:
		return
	if event.is_action_pressed("interact"):
		_bank()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_nearby = false

## Records this station as the checkpoint: the scene it stands in plus the spot
## the mole banked it from. Re-banking is allowed and just overwrites the
## record, so walking back to a station is a no-op that still gives feedback.
func _bank() -> void:
	var scene := _scene_path()
	if scene.is_empty():
		return
	# The mole's own position is the record, same as level_exit.gd saves on the
	# way out of a level. The pad decides where the mole actually reappears.
	var mole := _nearest_mole()
	var pos := mole.global_position if mole != null else spawn_point()
	# Banking only remembers what the mole has saved: positions recorded from
	# here on are the ones "after the station", and they are rewound when the
	# mole actually comes back - by a map teleport here or by a death that
	# respawns here - not while it is still walking forward.
	Progress.activate_respawn(scene, pos)
	_flash = ARRIVE_FLASH
	_pad_particles.emitting = true
	SFX.play_ui("parry_activate", -10.0, 1.4)
	SFX.play("item_pickup", spawn_point(), -8.0, 0.1)

func _nearest_mole() -> Node2D:
	for body in _area.get_overlapping_bodies():
		if body.is_in_group("mole") and body is Node2D:
			return body as Node2D
	return null

## Drops the mole onto the pad and materialises it: it rises out of the pad,
## pops upright, and only then gets its controls back, so a respawn reads as an
## arrival rather than a teleport.
##
## Fire and forget - mole.gd calls this without awaiting so its own _ready keeps
## setting the level up while the animation plays.
func spawn_mole_in(mole: Node2D) -> void:
	if _arriving or mole == null or not is_instance_valid(mole):
		return
	_arriving = true

	var target := spawn_point()
	var base_scale: Vector2 = mole.scale
	var body_light := mole.get_node_or_null("MoleLight") as PointLight2D
	var base_light := body_light.energy if body_light != null else 0.0

	mole.global_position = target - Vector2(0.0, ARRIVE_SINK)
	if mole is CharacterBody2D:
		(mole as CharacterBody2D).velocity = Vector2.ZERO
	mole.modulate.a = 0.0
	if body_light:
		body_light.energy = 0.0
	# Hold the mole still for the whole arrival. Without this the player can
	# walk off the pad mid-animation and the materialise reads as a glitch.
	mole.set_physics_process(false)
	_flash = ARRIVE_FLASH

	var rise := create_tween()
	rise.tween_interval(ARRIVE_LEAD_IN)
	rise.tween_callback(_burst)
	rise.tween_property(mole, "global_position", target, ARRIVE_RISE) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rise.parallel().tween_property(mole, "modulate:a", 1.0, ARRIVE_FADE)
	if body_light:
		rise.parallel().tween_property(body_light, "energy", base_light, ARRIVE_FADE)
	await rise.finished

	var pop := create_tween()
	pop.tween_property(mole, "scale", base_scale * Vector2(0.74, 1.24), ARRIVE_POP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(mole, "scale", base_scale * Vector2(1.16, 0.88), ARRIVE_POP * 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop.tween_property(mole, "scale", base_scale, ARRIVE_POP * 1.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished

	mole.set_physics_process(true)
	# The mole was teleported, not walked, so its floor memory has to be reset
	# or it treats the arrival as a landing and fires a dust puff mid-air.
	if "was_on_floor" in mole:
		mole.set("was_on_floor", true)
	SFX.play("land", target, -8.0, 0.1)
	_arriving = false

func _burst() -> void:
	_pad_particles.emitting = true
	SFX.play_ui("parry_activate", -14.0, 1.9)
