extends RigidBody2D

@export var prompt_text := "PRESS E"
@export var npc_name := "Snail"
## What the dialogue box calls him once the transformation has turned him into
## the Corrupted Snail. The first conversation still uses npc_name.
@export var boss_npc_name := "Corrupted Snail"
@export var portrait_texture: Texture2D = null
@export_multiline var dialogue_text := ""
@export_multiline var post_dialogue_text := ""
@export var condition_wave_path := NodePath("")
@export var unlock_ability := ""
@export var unlock_text := ""
@export var face_player := true
## After the dialogue closes, the player is put this far to the right of the snail
## so the encounter ends with them standing clear of it rather than inside it.
## Negative x moves them left instead.
@export var post_dialogue_clearance := Vector2.ZERO
## Some story snails visibly transform after their dialogue is dismissed.
@export var transform_after_dialogue := false
## Set on a snail that exists only to say its one line and then leaves - the level
## 05 snail is a prisoner calling for help, and there is nothing to come back
## for. Off by default because the snails that do stay are the ones the player is
## meant to be able to talk to again.
@export var remove_after_dialogue := false
## For a snail whose line is only the setup for the arena. Once the arena has been
## cleared that story has already happened, so a save that has done it should not
## have this snail back standing in the level waiting to be rescued a second time.
## Off by default - the arena is the only one-time event with a snail hanging off
## it, and every other snail is unconditional.
@export var skip_if_arena_completed := false
## For a snail whose place in the world is a thing the ending takes away rather
## than a fight the save has already been through. The village snail is the one:
## once the game has been beaten it is not a resident any more, so a finished save
## should not walk into the village and find it still outside asking to be left
## alone. Off by default - every other snail hangs off a fight or a level, not off
## the ending, and the boss that finishes the game must not skip itself.
@export var skip_if_game_completed := false
## Starts a boss fight after the transformation finishes; used by the level 10 snail.
@export var boss_after_dialogue := false
## Set only on the snail that stands between the Corrupted Heart and its own
## fight: its dialogue interrupts the walk's music, and what follows the
## conversation picks that music up further along. Off everywhere else, so the
## other snails in the game say nothing to the soundtrack.
@export var post_heart_music := false
## The artwork faces left at flip_h = false, so flipping points it right.
@export var sprite_faces_left := true

## The scale the snail transforms up to for the boss fight. Everything keyed to
## the fight's size - the collision body, the aura, the spit spawn offset, the
## lane the loot sails into - is derived from this, so this is the one knob.
const TRANSFORM_SCALE := 11.0
const EnemyDamage := preload("res://scripts/enemy.gd")
const EnemySpawn := preload("res://scripts/enemy_spawn.gd")
const IceBomb := preload("res://scripts/ice_bomb.gd")
const SNAIL_GLOW_TEXTURE := preload("res://costume3 (1).svg")
const AURA_COLORS := [Color(0.72, 0.25, 1.0, 0.65), Color(0.82, 0.48, 1.0, 0.32)]
const SNAIL_GLOW_COLOR := Color(0.62, 0.22, 1.0, 1.0)
const AURA_SCALE_FACTORS := [1.18, 1.38]
const TRANSFORM_DURATION := 16.0
const BOSS_TRANSFORM_DURATION := 3.2
const BOSS_HEALTH_BAR_WIDTH := 592.0
const BOSS_HEALTH_BAR_HEIGHT := 48.0
const BOSS_HEALTH_BAR_INSET := 14.0
const BOSS_HEALTH_FILL_INSET := 3.0
const BOSS_HEALTH_BAR_INNER := BOSS_HEALTH_BAR_WIDTH - BOSS_HEALTH_FILL_INSET * 2.0
const BOSS_HEALTH_PANEL_WIDTH := BOSS_HEALTH_BAR_WIDTH + BOSS_HEALTH_BAR_INSET * 2.0
const BOSS_HEALTH_PANEL_HEIGHT := BOSS_HEALTH_BAR_HEIGHT + BOSS_HEALTH_BAR_INSET * 2.0
const BOSS_HEALTH_NAME_HEIGHT := 46.0
const BOSS_HEALTH_NAME_GAP := 12.0
const BOSS_HEALTH_ROOT_WIDTH := BOSS_HEALTH_PANEL_WIDTH
const BOSS_HEALTH_ROOT_HEIGHT := BOSS_HEALTH_NAME_HEIGHT + BOSS_HEALTH_NAME_GAP + BOSS_HEALTH_PANEL_HEIGHT
const BOSS_HEALTH_FONT := preload("res://Baby Doll.otf")

## The real fill snaps to the new total over a short beat so a chunk of damage
## reads as motion instead of a jump. The paler trail bar behind it waits out
## BOSS_HEALTH_TRAIL_DELAY, then slides down to the same total, which shows how
## much a single hit took.
const BOSS_HEALTH_FILL_TWEEN_TIME := 0.12
const BOSS_HEALTH_TRAIL_DELAY := 0.35
const BOSS_HEALTH_TRAIL_TWEEN_TIME := 0.45
const BOSS_HEALTH_TRAIL_COLOR := Color(0.96, 0.82, 0.42, 0.9)

const BOSS_MAX_HEALTH := 500.0
const BOSS_CHASE_SPEED := 50.0
const BOSS_SPIT_INTERVAL := 2.4
const BOSS_PROJECTILE_SPEED := 620.0
const BOSS_LASER_COOLDOWN := 9.0
const BOSS_LASER_CHARGE_TIME := 1.5
const BOSS_LASER_STRIKE_DURATION := 1.25
const BOSS_LASER_TRAVEL_TIME := 0.35
const BOSS_LASER_FADE_TIME := 0.55
const BOSS_LASER_LENGTH := 3000.0
const BOSS_LASER_WIDTH := 136.0
const BOSS_LASER_TILE_SAMPLE_SPACING := 38.0
const BOSS_LASER_DAMAGE := 2.0

## Half health is where the shell stops playing it safe. The crossing fires the
## enrage: a scream, and on a coin flip the ice laser behind it.
const BOSS_ENRAGE_HEALTH_RATIO := 0.5
const BOSS_ENRAGE_SCREAM_TIME := 1.3
const BOSS_SCREAM_SHUDDER_BEATS := 7
const BOSS_SCREAM_SHUDDER_ANGLE := 0.075
const BOSS_SCREAM_RING_COUNT := 3
const BOSS_SCREAM_RING_POINTS := 28
const BOSS_SCREAM_RING_START_RADIUS := 50.0
const BOSS_SCREAM_RING_END_RADIUS := 340.0
const BOSS_SCREAM_RING_TIME := 0.55
const BOSS_SCREAM_RING_STAGGER := 0.11
## The scream is not always followed by the ice laser. When the roll misses, the
## half-health beat is the scream on its own - but the beam is a standing part of
## the second half regardless, so a missed roll only costs the crossing its
## flourish, not the rest of the fight its attack.
const BOSS_ICE_LASER_CHANCE := 0.5
## How long the shell goes between ice beams once it is enraged. Longer than the
## purple laser's cooldown and deliberately not a multiple of it, so the two drift
## against each other rather than arriving in a fixed alternation the mole could
## learn and count.
const BOSS_ICE_LASER_COOLDOWN := 11.0
## The ice beam tracks the mole for this long before it fires, and only settles on
## a direction at the end of it. Committing to a side inside these two seconds is
## what gets you out of the way; standing still does not.
const BOSS_ICE_LASER_AIM_TIME := 2.0
const BOSS_ICE_LASER_STRIKE_DURATION := 1.0
const BOSS_ICE_LASER_TRAVEL_TIME := 0.3
const BOSS_ICE_LASER_FADE_TIME := 0.5
const BOSS_ICE_LASER_WIDTH := 118.0
const BOSS_ICE_LASER_DAMAGE := 2.0
## How long the ice it lays down stays on the floor, and how long it takes to melt
## once that is up. Frozen ground is the part the mole actually feels: it slips on
## it for the whole of the first number.
const BOSS_ICE_LASER_FROST_DURATION := 7.0
const BOSS_ICE_LASER_FROST_FADE_TIME := 1.8
const BOSS_ICE_LASER_ICE_TEXTURE := preload("res://sprites/iceoverlay.png")
## The ice beam and its lights are the same purple laser with the heat taken out:
## cyan light on the beam, white where it is thickest.
const BOSS_ICE_LASER_LIGHT_COLOR := Color(0.45, 0.82, 1.0, 1.0)

const BOSS_TILE_BREAK_INTERVAL := 0.22
const BOSS_MINION_SPAWN_INTERVAL := Vector2(5.0, 8.0)
const BOSS_MINION_MAX_ALIVE := 4
## The cap above counts every node still sitting in the snail_boss_minion group,
## and a minion only ever leaves that group by dying and being freed. A goblin
## add cannot do that on its own: goblin_enemy.gd pins its x velocity, so it walks
## nowhere and stands where it was coughed out until the autoscroller leaves it
## behind, at which point its distance LOD puts it to sleep for good. Four of
## those and _spawn_boss_minion fails its cap check on every tick and the snail
## stops summoning for the rest of the fight. So adds that can no longer reach the
## mole are retired on a sweep instead, which is also what clears an add that fell
## into one of the pits the shell carves - there is no kill plane in the project.
const BOSS_MINION_RETIRE_INTERVAL := 0.5
## How far behind the shell an add may be before it is retired. The snail is the
## leftmost thing in the fight framing and only ever moves right, so an add behind
## it can never catch the mole up, however fast it walks.
const BOSS_MINION_RETIRE_BEHIND := 240.0
## And how far from the mole, for the adds that are still ahead of the snail but
## cannot reach it anyway - a pit, a ledge it cannot climb, terrain it is wedged
## in. Adds are released about 1600px short of the mole and walk in from there, so
## anything past this has stopped making progress.
const BOSS_MINION_RETIRE_DIST := 2200.0
const BOSS_MINION_SCENES: Array[PackedScene] = [
	preload("res://scenes/antenemy.tscn"),
	preload("res://scenes/beetleenemy.tscn"),
	preload("res://scenes/slimeenemy.tscn"),
	# The goblins are the ranged entries. They only throw when they are on screen
	# and have line of sight to the mole, so the fight camera clamping the player
	# into frame is what keeps them actually engaging instead of idling.
	preload("res://scenes/goblinenemy.tscn"),
	preload("res://ice_goblinenemy.tscn"),
]
const BOSS_PROJECTILE_SCENE := preload("res://area_2d.tscn")
const BOSS_LASER_LIGHT_TEXTURE := preload("res://costume3 (1).svg")
const BOSS_LASER_EXPLOSION_SCENE := preload("res://Retro Explosion.tscn")
## Loot drops into the fight: a loose Drill or Holy Water the player grabs on the
## move. These used to be chests, which meant stopping to open one while the
## snail was still firing.
const LootDrop := preload("res://scripts/loot_drop.gd")
const BOSS_LOOT_SPAWN_INTERVAL := 12.0
## The first one waits longer than the rest, so the fight opens with the snail
## and not with loot dropping in on top of the player.
const BOSS_LOOT_FIRST_SPAWN_DELAY := 8.0
## Landed just ahead of the player rather than straight down on their head, so it
## is something to move for instead of something that lands on them.
const BOSS_LOOT_DROP_OFFSET := Vector2(110.0, -500.0)
## Purple fireworks burst at the end of each boss laser.
const BOSS_LASER_FIREWORK_Z := 40
## The snail is a RigidBody2D driven entirely by script, so a bomb landing on its
## shell or an add walking into it must never shove it off script. Bombs, chests,
## coins and debris all sit on the same collision layer as the ground, so the
## layer mask cannot tell them apart - instead every loose body in the arena is
## put on a collision exception with the snail, which leaves the ground solid.
const BOSS_IMMUNE_SWEEP_INTERVAL := 0.1
## Pull back for the large boss, then keep the encounter moving right like an autoscroller.
const BOSS_CAM_ZOOM := Vector2(0.32, 0.32)
const BOSS_CAM_ZOOM_IN_TIME := 2.5
const BOSS_BRIGHTNESS_TRANSITION_TIME := 2.5
const BOSS_CAM_ZOOM_OUT_TIME := 0.8
const BOSS_AUTO_SCROLL_SPEED := 48.0
const BOSS_AUTO_SCROLL_TRACK_SPEED := 260.0
const BOSS_AUTO_SCROLL_SNAIL_SCREEN_RATIO := 0.18
const BOSS_AUTO_SCROLL_PLAYER_SCREEN_RATIO := 0.82
## Extra world space revealed to the right of the framing the two screen ratios
## ask for, as a fraction of the visible width. The autoscroller parks the shell
## left of centre, so without this the right half of the screen is dead space and
## the player has no warning about what is coming at them.
const BOSS_AUTO_SCROLL_HORIZONTAL_LEAD := 0.30
const BOSS_AUTO_SCROLL_VERTICAL_OFFSET := -300.0
const BOSS_AUTO_SCROLL_VERTICAL_FOLLOW := 4.0
## Inset from the fight camera's edge that still counts as on screen. The mole
## is drawn at a quarter scale here, so this is only a little padding - just
## enough that it is never clipped by the edge of the frame.
const BOSS_CAM_CLAMP_MARGIN := Vector2(64.0, 64.0)

var _boss_minion_spawn_timer := 0.0
var _boss_minion_retire_timer := 0.0
const TileBreakSFX := preload("res://scripts/tile_break_sfx.gd")

var _original_sprite_scale := Vector2.ONE
## The shell collider's size as authored, before any transformation scaling.
var _base_body_size := Vector2(114, 56)
var _transform_ground_y := 0.0
var _aura_sprites: Array[Sprite2D] = []
var _transformation_light: PointLight2D = null
var _transformed := false
var _boss_active := false
var _boss_dying := false
var _boss_health := BOSS_MAX_HEALTH
var _boss_spit_timer := 0.0
var _boss_laser_timer := 0.0
var _boss_laser_active := false
var _boss_laser_lines: Array[Line2D] = []
## Latched once the shell has crossed half health, so the enrage only ever fires
## on the hit that crosses it.
var _boss_enraged := false
## An enrage beat (scream, possibly the ice laser) is playing right now. The
## normal spit and laser hold off for its length so nothing fires on top of it.
var _boss_enrage_active := false
## Counts down to the next ice beam. Armed at the start of the fight but only
## ever read once the shell is enraged, so the beam stays out of the first half
## entirely and is not sitting there ready to fire the instant the crossing lands.
var _boss_ice_laser_timer := 0.0
var _boss_ice_laser_active := false
var _boss_ice_laser_lines: Array[Line2D] = []
var _boss_scream_tween: Tween = null
var _boss_aura_shield: Line2D = null
var _boss_break_timer := 0.0
var _boss_loot_spawn_timer := 0.0
var _boss_immune_timer := 0.0
var _boss_contact_timer := 0.0
var _boss_projectile_count := 0
var _boss_ground_y := 0.0
var _boss_hurtbox: Area2D = null
var _boss_player_contact: Area2D = null
var _boss_health_layer: CanvasLayer = null
var _boss_health_fill: ColorRect = null
var _boss_health_trail: ColorRect = null
var _boss_health_bar_tween: Tween = null
var _boss_health_trail_tween: Tween = null
var _boss_hit_tween: Tween = null
var _boss_base_scale := Vector2.ONE
var _boss_cam_zoom_tween: Tween = null
var _boss_cam_restore_zoom := Vector2(0.65, 0.65)
var _boss_auto_camera: Camera2D = null
var _boss_return_camera: Camera2D = null
var _boss_auto_camera_last_snail_x := 0.0
var _boss_ambient_modulate: CanvasModulate = null
var _boss_restore_ambient_color := Color.WHITE
var _boss_vignette_rect: ColorRect = null
var _boss_restore_vignette_material: Material = null
var _boss_vignette_material: ShaderMaterial = null
var _boss_brightness_tween: Tween = null
var _death_box: CanvasLayer = null
var _death_finale_started := false
var _death_black_hole: Node2D = null
var _death_credits_started := false
## Built once and shared by every firework so the death show does not allocate a
## fresh 32x32 texture (and re-upload it) for each burst - texturing a burst per
## frame is what made the browser build buckle under the finale.
var _firework_spark_texture: Texture2D = null

const ITEM_GET := preload("res://scripts/item_get_animation.gd")
## Melee weapons have no artwork of their own, so - like the weapon the mole
## actually carries - the fanfare tints the shovel icon with the weapon colour.
const MELEE_ICON := preload("res://sprites/shovel.png")
## Roughly the dialogue box's slide-away, so the fanfare lands once it is gone.
const FANFARE_DELAY := 0.35
## How long a retiring snail takes to fade out. Slow enough to read as leaving
## rather than being deleted.
const RETIRE_FADE := 0.6
## The grand death: the snail defies the mole one last time, then bursts like a
## firework show while the box is on screen, and the finale blast frees it.
const DEATH_CURSE_TEXT := "HOLY MOLY! I SWEAR WHEN I GO TO HELL I WILL DESTROY ALL MOLES"
## Mirrors dialogue_box.gd's TYPE_SPEED, so the skip-typing timer matches typing.
const DIALOGUE_TYPE_SPEED := 0.018
## Continuous particle bursts while the final dialogue is open. Kept intentionally
## light: the fireworks overlap for the whole dialogue, so the counts here are the
## single biggest driver of whether the browser can survive the finale.
const DEATH_FIREWORK_LOOP_INTERVAL := 0.7
const DEATH_FIREWORK_CLUSTER_COUNT := 4
const DEATH_FIREWORK_PARTICLE_COUNT := 120
## Firework bursts explode inside this radius of the shell rather than on one
## fixed point, so the show reads as coming from him.
const DEATH_FIREWORK_RADIUS_SCALE := 0.42
## Clamp on how far the shell's size may multiply the per-burst particle counts,
## so a huge boss body cannot turn each burst into thousands of particles.
const DEATH_FIREWORK_BLAST_SCALE_MIN := 0.4
const DEATH_FIREWORK_BLAST_SCALE_MAX := 1.4
const DEATH_FIREWORK_COLORS: Array[Color] = [
	Color(0.72, 0.18, 1.0, 1.0), Color(1.0, 0.78, 0.26, 1.0),
	Color(0.35, 0.85, 1.0, 1.0), Color(1.0, 0.32, 0.48, 1.0),
]
const DEATH_SHAKE_STRENGTH := 14.0
const DEATH_SHAKE_DURATION := 0.3
const DEATH_FADE_TIME := 0.8
const DEATH_BLACK_HOLE_DELAY := 0.75
const DEATH_BLACK_HOLE_GROW_TIME := 0.9
const DEATH_BLACK_HOLE_TILE_BATCH := 12
const DEATH_BLACK_HOLE_TILE_INTERVAL := 0.04
const DEATH_BLACK_HOLE_RADIUS_SCALE := 0.38
const DEATH_BLACK_HOLE_SNAIL_PULL_TIME := 2.6
const DEATH_CREDITS_PATH := "res://scenes/credits.tscn"

var _mole_overlapping := false
var _dialogue_open := false
var _condition_met := false
var _label: Label = null
var _dialogue_box: CanvasLayer = null
var _dialogue_focus_camera: Camera2D = null
var _dialogue_return_camera: Camera2D = null
var _dialogue_return_camera_was_enabled := false
var _dialogue_pause_restore_pending := false
var _dialogue_was_paused := false
var _sprite: AnimatedSprite2D = null
var _player: Node2D = null
## Set once this NPC has said everything that matters - it has already handed
## over its tool - so it stops prompting and stops listening for interact.
var _hushed := false

## The reward earned by the last dialogue, held back until the box has slid
## away so the fanfare is not talking over the text that announced it.
var _reward_message := ""
var _reward_icon: Texture2D = null
var _reward_tint := Color.WHITE
var _banner_text := ""

signal dialogue_closed

func _ready() -> void:
	# The story this snail introduces has already been played out, so it is not put
	# in the level at all - whether that is the arena fight it was setting up or the
	# ending that took its place in the village. Checked before anything is wired up,
	# so a skipped snail costs no signal connections and no prompt label.
	if (skip_if_arena_completed and Progress.is_arena_completed()) \
			or (skip_if_game_completed and Progress.is_game_completed()):
		queue_free()
		return
	var zone := get_node_or_null("Area2D") as Area2D
	if zone:
		zone.body_entered.connect(_on_body_entered)
		zone.body_exited.connect(_on_body_exited)
	_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _sprite:
		_original_sprite_scale = _sprite.scale
		var sprite_texture := _current_sprite_texture()
		if sprite_texture:
			_transform_ground_y = _sprite.position.y + sprite_texture.get_size().y * _original_sprite_scale.y * 0.5
		else:
			_transform_ground_y = _sprite.position.y
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape:
		var body_rect := body_shape.shape as RectangleShape2D
		if body_rect:
			_base_body_size = body_rect.size
	_label = get_node_or_null("Area2D/Prompt") as Label
	if _label:
		if prompt_text != "":
			_label.text = prompt_text
		_label.visible = false
		_label.z_index = 100
		_label.z_as_relative = false
		# The same emboldened Baby Doll npc_mole.gd builds for its prompt, so the
		# two read as one UI element rather than as one bold label and one thin
		# one. Matched there by hand rather than from a shared helper because the
		# two nodes are reached by different paths ("Prompt" vs "Area2D/Prompt")
		# and neither scene owns the other's node.
		var variation := FontVariation.new()
		variation.base_font = load("res://Baby Doll.otf") as Font
		variation.variation_embolden = 1.0
		_label.add_theme_font_override("font", variation)
	_hushed = _refresh_hushed()
	_setup_condition()
	if boss_after_dialogue:
		_boss_health = BOSS_MAX_HEALTH

func _physics_process(delta: float) -> void:
	if not _boss_active or _boss_dying:
		return

	# Movement and tunnel clearing are independent of the player and camera. If
	# either is temporarily unavailable, the scripted autoscroller still advances.
	var direction := 1.0
	_sprite.flip_h = (direction > 0.0) == sprite_faces_left
	# This is a scripted autoscroller, not a terrain-bound walker. Keep its
	# altitude and movement deterministic so a seam, slope, or missing camera
	# cannot pin the rigid body in a particular section of the level.
	global_position.y = _boss_ground_y
	linear_velocity.x = BOSS_AUTO_SCROLL_SPEED
	linear_velocity.y = 0.0
	_boss_break_timer -= delta
	if _boss_break_timer <= 0.0:
		_boss_break_timer = BOSS_TILE_BREAK_INTERVAL
		_break_blocks_ahead(direction)

	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return

	if not _boss_laser_active and not _boss_enrage_active and not _boss_ice_laser_active:
		_boss_spit_timer -= delta
		if _boss_spit_timer <= 0.0:
			_boss_spit_timer = BOSS_SPIT_INTERVAL
			_spit_boss_projectile(mole)

		_boss_laser_timer -= delta
		if _boss_laser_timer <= 0.0:
			_boss_laser_timer = BOSS_LASER_COOLDOWN
			_fire_boss_laser(mole)

	# Past half health the ice beam is a standing attack rather than the once-a-fight
	# dice roll the crossing used to be, so it is timed here off the same loop as
	# everything else. Held off while the purple laser is up or an enrage beat is
	# playing: the timer pauses for the duration rather than expiring and firing on
	# top of a beam that is already out, so the shell never crosses two at once.
	if _boss_enraged and not _boss_ice_laser_active and not _boss_enrage_active and not _boss_laser_active:
		_boss_ice_laser_timer -= delta
		if _boss_ice_laser_timer <= 0.0:
			_boss_ice_laser_timer = BOSS_ICE_LASER_COOLDOWN
			_fire_boss_ice_laser(mole)

	_boss_minion_spawn_timer -= delta
	if _boss_minion_spawn_timer <= 0.0:
		_spawn_boss_minion()
		_boss_minion_spawn_timer = randf_range(BOSS_MINION_SPAWN_INTERVAL.x, BOSS_MINION_SPAWN_INTERVAL.y)

	# The summon pool is capped, so an add left behind by the autoscroller has to
	# give its slot back or the snail quietly runs out of adds to call.
	_boss_minion_retire_timer -= delta
	if _boss_minion_retire_timer <= 0.0:
		_boss_minion_retire_timer = BOSS_MINION_RETIRE_INTERVAL
		_retire_stranded_boss_minions()

	_boss_loot_spawn_timer -= delta
	if _boss_loot_spawn_timer <= 0.0:
		_boss_loot_spawn_timer = BOSS_LOOT_SPAWN_INTERVAL
		_spawn_boss_loot()

	# Bombs and adds can be thrown or spawned at any moment, so this is re-checked
	# through the fight rather than only once when the fight begins.
	_boss_immune_timer -= delta
	if _boss_immune_timer <= 0.0:
		_boss_immune_timer = BOSS_IMMUNE_SWEEP_INTERVAL
		_ignore_loose_body_pushes()

	_boss_contact_timer = maxf(0.0, _boss_contact_timer - delta)
	if _boss_contact_timer <= 0.0 and _boss_player_contact != null and _boss_player_contact.overlaps_body(mole):
		_boss_contact_timer = 0.9
		mole.call("take_damage", 1.0, global_position, true)

## An NPC is done talking once the one thing it exists to hand over is already
## in the mole's hands. Anything with no unlock to give talks forever.
func _refresh_hushed() -> bool:
	if unlock_ability == "":
		return false
	var shop := get_tree().get_root().get_node_or_null("/root/Shop")
	return shop != null and shop.has_method("owns") and shop.owns(unlock_ability)

func _setup_condition() -> void:
	if condition_wave_path.is_empty():
		return
	var wm: Node = get_node_or_null(condition_wave_path)
	if wm != null and wm.has_signal("cleared"):
		wm.cleared.connect(_on_condition_met)

func _on_condition_met() -> void:
	_condition_met = true
	if post_dialogue_text != "" and dialogue_text != post_dialogue_text:
		dialogue_text = post_dialogue_text

func _process(delta: float) -> void:
	if _label:
		_label.visible = _mole_overlapping and not _dialogue_open and not _hushed
	_update_facing()
	_update_transformation_aura()
	if _boss_active and not _boss_dying:
		_update_boss_autoscroll_camera(delta)
		_confine_mole_to_boss_camera()

## Flip the sprite only - the body, collision shapes and Area2D are untouched.
func _update_facing() -> void:
	if _boss_active or not face_player or _sprite == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("mole") as Node2D
		if _player == null:
			return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) < 4.0:
		return
	_sprite.flip_h = (dx > 0.0) == sprite_faces_left

func _unhandled_input(event: InputEvent) -> void:
	if not _mole_overlapping or _dialogue_open or _hushed or dialogue_text.is_empty():
		return
	if event.is_action_pressed("interact"):
		_open_dialogue()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_overlapping = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("mole"):
		_mole_overlapping = false

func show_dialogue() -> void:
	if _dialogue_open:
		return
	# Hushed: there is nothing to show, but the caller (the arena camera) is
	# waiting to hear the box close, so answer it or the sequence would stall.
	if _hushed:
		dialogue_closed.emit.call_deferred()
		return
	_open_dialogue()

func _open_dialogue() -> void:
	_dialogue_open = true
	# The walk out of the heart's arena is still scored by its loop. The dialogue
	# opens on top of it, so the loop is let go before the box starts talking.
	if post_heart_music:
		LevelMusic.stop_vessel()
	if boss_after_dialogue:
		# Keep the level running so any active explosions and particles continue
		# under the dialogue. The camera stays on the player for this line; the
		# snail only takes over the framing for the death curse, after the fight.
		_dialogue_was_paused = get_tree().paused
		_dialogue_pause_restore_pending = true
		get_tree().paused = false
	_dialogue_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_dialogue_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_dialogue_box)
	_dialogue_box.next_pressed.connect(_on_dialogue_done)
	_dialogue_box.set_portrait(portrait_texture)
	_dialogue_box.set_npc_name(npc_name)
	_apply_portrait_blink_to(_dialogue_box)
	_dialogue_box.show_text(dialogue_text, 0, 0, true, false)

## Takes the camera off the player and frames the snail for the death curse,
## pulling back to the boss zoom so the whole shell and its fireworks fit on
## screen. The pre-fight line deliberately leaves the camera alone.
func _focus_dialogue_camera_on_snail() -> void:
	if _dialogue_focus_camera != null and is_instance_valid(_dialogue_focus_camera):
		return
	var scene_root := get_tree().current_scene
	var current_camera := get_viewport().get_camera_2d() as Camera2D
	if scene_root == null or current_camera == null:
		return
	_dialogue_return_camera = current_camera
	_dialogue_return_camera_was_enabled = current_camera.enabled
	current_camera.enabled = false
	_dialogue_focus_camera = Camera2D.new()
	_dialogue_focus_camera.name = "SnailDialogueCamera"
	_dialogue_focus_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogue_focus_camera.zoom = current_camera.zoom
	_dialogue_focus_camera.global_position = current_camera.global_position
	scene_root.add_child(_dialogue_focus_camera)
	_dialogue_focus_camera.make_current()
	var focus_position := _sprite.global_position if _sprite != null else global_position
	var focus_tween := _dialogue_focus_camera.create_tween()
	focus_tween.set_parallel(true)
	focus_tween.tween_property(_dialogue_focus_camera, "global_position", focus_position, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	focus_tween.tween_property(_dialogue_focus_camera, "zoom", BOSS_CAM_ZOOM, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _restore_dialogue_camera() -> void:
	if _dialogue_focus_camera != null and is_instance_valid(_dialogue_focus_camera):
		_dialogue_focus_camera.enabled = false
		_dialogue_focus_camera.queue_free()
		_dialogue_focus_camera = null
	if _dialogue_pause_restore_pending:
		_dialogue_pause_restore_pending = false
		get_tree().paused = _dialogue_was_paused
	if _dialogue_return_camera != null and is_instance_valid(_dialogue_return_camera):
		_dialogue_return_camera.enabled = _dialogue_return_camera_was_enabled
		if _dialogue_return_camera_was_enabled:
			_dialogue_return_camera.make_current()
	_dialogue_return_camera = null

## Mirror the NPC's own blink cycle onto a dialogue portrait, if it has one.
func _apply_portrait_blink_to(box: CanvasLayer) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if box == null or sprite == null or sprite.sprite_frames == null:
		return
	var anim := "blink"
	var rest := 0
	var lo := 1.0
	var hi := 3.0
	if "blink_animation" in sprite:
		anim = sprite.blink_animation
		rest = sprite.rest_frame
		lo = sprite.min_interval
		hi = sprite.max_interval
	if not sprite.sprite_frames.has_animation(anim):
		return
	var frames: Array = []
	for i in sprite.sprite_frames.get_frame_count(anim):
		frames.append(sprite.sprite_frames.get_frame_texture(anim, i))
	if frames.size() < 2:
		return
	box.set_portrait_animation(frames, lo, hi, rest, sprite.sprite_frames.get_animation_speed(anim))

func _on_dialogue_done() -> void:
	_start_transformation()
	_grant_unlock()
	_move_player_clear_of_snail()
	# Whatever the dialogue interrupted picks up past it, on the far side of the
	# conversation rather than where the loop left off.
	if post_heart_music:
		LevelMusic.play_vessel_after_snail()
	# This story encounter becomes a boss, not an interactable NPC, after its scene.
	_hushed = true if boss_after_dialogue else _refresh_hushed()
	if remove_after_dialogue:
		_retire_when_dialogue_clears()
	if _dialogue_box == null or not is_instance_valid(_dialogue_box):
		_dialogue_box = null
		_dialogue_open = false
		_restore_dialogue_camera()
		dialogue_closed.emit()
		_show_reward()
		return
	var box := _dialogue_box
	_dialogue_box = null
	box.hide_box()
	# process_always = true, so the reward still plays out if the game is paused
	# underneath it (the arena starts panning back the moment this emits).
	get_tree().create_timer(FANFARE_DELAY).timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
		_restore_dialogue_camera()
		_show_reward()
	)
	_dialogue_open = false
	dialogue_closed.emit()

## Sends a snail off once it has said its line. Hushed immediately, so the prompt
## cannot pop back up over the closing box, and the wait is deliberately
## FANFARE_DELAY long: the box's own teardown is a deferred callback on this node,
## so freeing any sooner would fire it at an instance that is already gone.
func _retire_when_dialogue_clears() -> void:
	_hushed = true
	get_tree().create_timer(FANFARE_DELAY).timeout.connect(_begin_retire)

## Fades the shell out and lets it go. The collider goes at the same time rather
## than at the end of the fade, so the player is never left standing on something
## that is on its way out, and the body is frozen in case the snail was still
## falling when it started talking.
func _begin_retire() -> void:
	if _label != null:
		_label.visible = false
	var interaction_area := get_node_or_null("Area2D") as Area2D
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	freeze = true
	if _sprite == null:
		queue_free()
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, RETIRE_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(_sprite, "scale", _sprite.scale * 0.85, RETIRE_FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

## Puts the player on the far side of the snail once its dialogue is out of the
## way, so they are never left standing inside it. The momentum is cleared too,
## otherwise a fast fall carries straight on through the new spot.
func _move_player_clear_of_snail() -> void:
	if post_dialogue_clearance == Vector2.ZERO:
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	mole.global_position = to_global(post_dialogue_clearance)
	if mole is CharacterBody2D:
		(mole as CharacterBody2D).velocity = Vector2.ZERO

func _start_transformation() -> void:
	if not transform_after_dialogue or _transformed or _sprite == null:
		return
	_transformed = true

	var duration := BOSS_TRANSFORM_DURATION if boss_after_dialogue else TRANSFORM_DURATION
	_siphon_player_aura(duration)
	_add_transformation_light(duration)
	for i in AURA_COLORS.size():
		var aura := Sprite2D.new()
		aura.texture = _current_sprite_texture()
		aura.position = _sprite.position
		aura.scale = _original_sprite_scale * 1.35
		aura.modulate = Color(AURA_COLORS[i].r, AURA_COLORS[i].g, AURA_COLORS[i].b, 0.0)
		aura.z_index = _sprite.z_index - 1
		aura.flip_h = _sprite.flip_h
		var aura_material := CanvasItemMaterial.new()
		aura_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		aura.material = aura_material
		add_child(aura)
		move_child(aura, _sprite.get_index())
		_aura_sprites.append(aura)

		var aura_tween := create_tween()
		aura_tween.set_parallel(true)
		aura_tween.tween_property(aura, "scale", _original_sprite_scale * TRANSFORM_SCALE * AURA_SCALE_FACTORS[i], duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		aura_tween.tween_property(aura, "modulate:a", AURA_COLORS[i].a, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var grow_tween := create_tween()
	var target_scale := _original_sprite_scale * TRANSFORM_SCALE
	if boss_after_dialogue:
		grow_tween.tween_property(_sprite, "scale", target_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		grow_tween.tween_callback(_begin_boss_fight)
	else:
		grow_tween.tween_property(_sprite, "scale", target_scale, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# The boss resizes its own body when the fight starts, but an NPC snail
		# has no such beat, so its collider has to follow the growth here or the
		# shell ends up 11x bigger than the thing the player can stand on.
		grow_tween.tween_method(_resize_boss_body, 0.0, 1.0, duration)

## The snail pulls visible copies of the mole's glow toward itself while keeping
## the mole's own light intact, making the growth feel like a gradual siphon.
func _siphon_player_aura(duration: float) -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var mole_sprite := mole.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if mole_sprite == null:
		return

	var echo_count := 12
	var interval := duration / float(echo_count)
	for i in echo_count:
		if not is_instance_valid(mole) or not is_instance_valid(mole_sprite) or not is_inside_tree():
			return
		_emit_aura_echo(mole_sprite, interval * 2.5)
		if i < echo_count - 1:
			await get_tree().create_timer(interval).timeout

func _add_transformation_light(duration: float) -> void:
	if _sprite == null or _transformation_light != null:
		return
	_transformation_light = PointLight2D.new()
	_transformation_light.name = "TransformationLight"
	_transformation_light.position = _sprite.position
	_transformation_light.texture = SNAIL_GLOW_TEXTURE
	_transformation_light.texture_scale = 1.4
	_transformation_light.color = SNAIL_GLOW_COLOR
	_transformation_light.energy = 1.0
	_transformation_light.range_item_cull_mask = 1023
	_transformation_light.shadow_enabled = true
	_transformation_light.shadow_color = Color(0.05, 0.01, 0.09, 1.0)
	_transformation_light.shadow_filter = 2
	_transformation_light.shadow_filter_smooth = 4.0
	_transformation_light.shadow_item_cull_mask = 1
	add_child(_transformation_light)

	var texture := _current_sprite_texture()
	if texture == null:
		return
	var half_size := texture.get_size() * 0.5
	var occluder_shape := OccluderPolygon2D.new()
	occluder_shape.polygon = PackedVector2Array([
		Vector2(-half_size.x * 0.45, -half_size.y * 0.5),
		Vector2(half_size.x * 0.1, -half_size.y * 0.5),
		Vector2(half_size.x * 0.45, -half_size.y * 0.2),
		Vector2(half_size.x * 0.5, half_size.y * 0.1),
		Vector2(half_size.x * 0.3, half_size.y * 0.42),
		Vector2(-half_size.x * 0.35, half_size.y * 0.45),
		Vector2(-half_size.x * 0.5, half_size.y * 0.15),
		Vector2(-half_size.x * 0.5, -half_size.y * 0.2),
	])
	var occluder := LightOccluder2D.new()
	occluder.name = "TransformationLightOccluder"
	occluder.occluder = occluder_shape
	occluder.occluder_light_mask = 1
	_sprite.add_child(occluder)

	var light_tween := create_tween()
	light_tween.set_parallel(true)
	light_tween.tween_property(_transformation_light, "texture_scale", 4.2, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light_tween.tween_property(_transformation_light, "energy", 1.35, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _emit_aura_echo(source: AnimatedSprite2D, travel_time: float) -> void:
	if source.sprite_frames == null or _sprite == null:
		return
	var texture := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if texture == null:
		return
	var echo := Sprite2D.new()
	echo.texture = texture
	echo.flip_h = source.flip_h
	echo.rotation = source.global_rotation
	echo.global_scale = source.global_scale * 0.8
	echo.modulate = Color(0.82, 0.42, 1.0, 0.7)
	echo.z_index = 20
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	echo.material = additive
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(echo)
	echo.global_position = source.global_position

	var tween := echo.create_tween()
	tween.set_parallel(true)
	tween.tween_property(echo, "global_position", global_position + Vector2(0.0, -24.0), travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(echo, "global_scale", echo.global_scale * 0.3, travel_time)
	tween.tween_property(echo, "modulate:a", 0.0, travel_time)
	tween.chain().tween_callback(echo.queue_free)

func _begin_boss_fight() -> void:
	if not boss_after_dialogue or not is_inside_tree() or _boss_dying:
		return
	_boss_active = true
	_boss_health = BOSS_MAX_HEALTH
	# The fight drives this snail's position by script, so the dash must not be
	# able to shove it off its autoscroll path. It still takes the hit damage.
	add_to_group(&"knockback_locked")
	# Lets the boss's own spawns recognise it - the ice goblin's frost mushroom
	# uses this to leave the shell alone instead of chipping away at the fight.
	add_to_group(&"snail_boss")
	add_to_group(&"boss")
	# Walking into the shell must not shove it either. The mole's collision mask
	# never matched the boss layer, so it was never blocked by the shell to begin
	# with - the solver just used the contact to drag a 500hp boss down a cliff.
	_ignore_mole_pushes()
	if _label != null:
		_label.visible = false
	var interaction_area := get_node_or_null("Area2D") as Area2D
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)
	_boss_spit_timer = 1.0
	_boss_laser_timer = 5.0
	_boss_laser_active = false
	_boss_enraged = false
	_boss_enrage_active = false
	_boss_ice_laser_active = false
	# Armed rather than run: nothing reads this until _boss_enraged is latched, so
	# the first ice beam still has to wait out the enrage and the purple laser's
	# turn at the crossing rather than cutting the scream short.
	_boss_ice_laser_timer = BOSS_ICE_LASER_COOLDOWN
	_boss_minion_spawn_timer = 3.0
	_boss_minion_retire_timer = 0.0
	_boss_break_timer = 0.0
	_boss_loot_spawn_timer = BOSS_LOOT_FIRST_SPAWN_DELAY
	_boss_immune_timer = 0.0
	linear_velocity = Vector2.ZERO
	sleeping = false
	_boss_ground_y = global_position.y
	gravity_scale = 0.0
	collision_layer = 4
	# Boss progress is scripted; the separate hurt/contact areas handle combat,
	# so terrain collisions must not be able to halt the rightward autoscroll.
	collision_mask = 0
	lock_rotation = true
	_boss_base_scale = _sprite.scale
	_resize_boss_body()
	_add_boss_hurtbox()
	_add_boss_aura_shield()
	_create_boss_health_bar()
	_brighten_boss_arena()
	_start_boss_camera_zoom()
	SFX.play("explosion", global_position, -8.0, 0.2, 0.8)

## Returns the camera currently showing the fight (which becomes the autoscroller camera).
func _boss_camera() -> Camera2D:
	if not is_inside_tree():
		return null
	return get_viewport().get_camera_2d() as Camera2D

func _stop_boss_camera_zoom() -> void:
	if _boss_cam_zoom_tween != null and _boss_cam_zoom_tween.is_valid():
		_boss_cam_zoom_tween.kill()
	_boss_cam_zoom_tween = null

func _tween_boss_camera_zoom(camera: Camera2D, target: Vector2, duration: float, target_offset: Vector2) -> void:
	_stop_boss_camera_zoom()
	_boss_cam_zoom_tween = camera.create_tween()
	_boss_cam_zoom_tween.set_parallel(true)
	_boss_cam_zoom_tween.tween_property(camera, "zoom", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boss_cam_zoom_tween.tween_property(camera, "offset", target_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _start_boss_camera_zoom() -> void:
	var current_camera := _boss_camera()
	if current_camera == null:
		return
	_boss_return_camera = current_camera
	_boss_cam_restore_zoom = current_camera.zoom
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return

	_boss_auto_camera = Camera2D.new()
	_boss_auto_camera.name = "SnailBossAutoscrollCamera"
	_boss_auto_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_boss_auto_camera.zoom = current_camera.zoom
	_boss_auto_camera.offset = Vector2.ZERO
	_boss_auto_camera.global_position = current_camera.global_position
	_boss_auto_camera_last_snail_x = global_position.x
	scene_root.add_child(_boss_auto_camera)
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	var target_offset := Vector2.ZERO
	if mole != null and is_instance_valid(mole):
		var target_camera_x := _boss_camera_target_x(_boss_auto_camera, mole, BOSS_CAM_ZOOM.x)
		target_camera_x += _boss_camera_lead_x(_boss_auto_camera, BOSS_CAM_ZOOM.x)
		target_offset.x = (target_camera_x - _boss_auto_camera.global_position.x) * BOSS_CAM_ZOOM.x
	current_camera.enabled = false
	_boss_auto_camera.make_current()
	_tween_boss_camera_zoom(_boss_auto_camera, BOSS_CAM_ZOOM, BOSS_CAM_ZOOM_IN_TIME, target_offset)

func _update_boss_autoscroll_camera(delta: float) -> void:
	if _boss_auto_camera == null or not is_instance_valid(_boss_auto_camera):
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return

	var snail_delta_x := maxf(global_position.x - _boss_auto_camera_last_snail_x, 0.0)
	_boss_auto_camera_last_snail_x = global_position.x
	var desired_x := _boss_camera_target_x(_boss_auto_camera, mole)
	var tracking_step := maxf(desired_x - _boss_auto_camera.global_position.x, 0.0)
	var midpoint_y := (global_position.y + mole.global_position.y) * 0.5
	var target_y := midpoint_y + BOSS_AUTO_SCROLL_VERTICAL_OFFSET
	_boss_auto_camera.global_position.y = lerpf(
		_boss_auto_camera.global_position.y, target_y,
		clampf(BOSS_AUTO_SCROLL_VERTICAL_FOLLOW * delta, 0.0, 1.0))
	var camera_step := minf(snail_delta_x, tracking_step)
	_boss_auto_camera.global_position.x += camera_step
	if _boss_cam_zoom_tween == null or not _boss_cam_zoom_tween.is_valid():
		var target_offset_x := (_boss_camera_target_x(_boss_auto_camera, mole) + _boss_camera_lead_x(_boss_auto_camera) - _boss_auto_camera.global_position.x) * _boss_auto_camera.zoom.x
		_boss_auto_camera.offset.x = move_toward(
			_boss_auto_camera.offset.x, target_offset_x, BOSS_AUTO_SCROLL_SPEED * _boss_auto_camera.zoom.x * delta)

func _boss_camera_target_x(camera: Camera2D, mole: Node2D, zoom_x: float = -1.0) -> float:
	var viewport_width: float = camera.get_viewport_rect().size.x
	var effective_zoom := zoom_x if zoom_x > 0.0 else camera.zoom.x
	var world_view_width := viewport_width / maxf(effective_zoom, 0.01)
	var snail_left_target := global_position.x + world_view_width * (0.5 - BOSS_AUTO_SCROLL_SNAIL_SCREEN_RATIO)
	var mole_right_target := mole.global_position.x - world_view_width * (BOSS_AUTO_SCROLL_PLAYER_SCREEN_RATIO - 0.5)
	return maxf(snail_left_target, mole_right_target) - camera.offset.x / maxf(effective_zoom, 0.01)

func _boss_camera_lead_x(camera: Camera2D, zoom_x: float = -1.0) -> float:
	## Rightward framing bias, in world units.
	##
	## This has to be applied to the finished camera offset rather than folded into
	## _boss_camera_target_x: the target already subtracts offset.x, and the
	## autoscroller then eases offset.x toward that target, so a lead added there
	## cancels itself out and the framing never actually moves.
	var effective_zoom := zoom_x if zoom_x > 0.0 else camera.zoom.x
	var viewport_width: float = camera.get_viewport_rect().size.x
	return viewport_width / maxf(effective_zoom, 0.01) * BOSS_AUTO_SCROLL_HORIZONTAL_LEAD

## Holds the player inside the fight framing. The autoscroller leads the camera
## rather than following it, so nothing else stops the mole running off the side
## of the screen and continuing through terrain the fight cannot be seen from.
func _confine_mole_to_boss_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var half_view := camera.get_viewport_rect().size / camera.zoom * 0.5
	var center := camera.get_screen_center_position()
	var limit_min := center - half_view + BOSS_CAM_CLAMP_MARGIN
	var limit_max := center + half_view - BOSS_CAM_CLAMP_MARGIN
	mole.global_position = Vector2(
		clampf(mole.global_position.x, limit_min.x, limit_max.x),
		clampf(mole.global_position.y, limit_min.y, limit_max.y)
	)

func _brighten_boss_arena() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_boss_ambient_modulate = scene.get_node_or_null("AmbientModulate") as CanvasModulate
	_boss_brightness_tween = create_tween()
	_boss_brightness_tween.set_parallel(true)
	if _boss_ambient_modulate != null:
		_boss_restore_ambient_color = _boss_ambient_modulate.color
		_boss_brightness_tween.tween_property(
			_boss_ambient_modulate, "color", Color(0.9, 0.88, 0.94, 1.0),
			BOSS_BRIGHTNESS_TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	_boss_vignette_rect = scene.get_node_or_null("VignetteLayer/VignetteRect") as ColorRect
	if _boss_vignette_rect != null:
		var original_material := _boss_vignette_rect.material as ShaderMaterial
		if original_material != null:
			_boss_restore_vignette_material = _boss_vignette_rect.material
			_boss_vignette_material = original_material.duplicate() as ShaderMaterial
			_boss_vignette_rect.material = _boss_vignette_material
			var original_darkness: float = float(original_material.get_shader_parameter("darkness"))
			_boss_brightness_tween.tween_method(
				_set_boss_vignette_darkness, original_darkness, 0.12,
				BOSS_BRIGHTNESS_TRANSITION_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _set_boss_vignette_darkness(darkness: float) -> void:
	if _boss_vignette_material != null and is_instance_valid(_boss_vignette_material):
		_boss_vignette_material.set_shader_parameter("darkness", darkness)

func _restore_boss_ambient() -> void:
	if _boss_brightness_tween != null and _boss_brightness_tween.is_valid():
		_boss_brightness_tween.kill()
	_boss_brightness_tween = null
	if _boss_ambient_modulate != null and is_instance_valid(_boss_ambient_modulate):
		var ambient_tween := _boss_ambient_modulate.create_tween()
		ambient_tween.tween_property(_boss_ambient_modulate, "color", _boss_restore_ambient_color, 0.7)
	_boss_ambient_modulate = null
	if _boss_vignette_rect != null and is_instance_valid(_boss_vignette_rect):
		_boss_vignette_rect.material = _boss_restore_vignette_material
	_boss_vignette_rect = null
	_boss_restore_vignette_material = null

func _restore_boss_camera_zoom() -> void:
	_stop_boss_camera_zoom()
	if _boss_auto_camera == null or not is_instance_valid(_boss_auto_camera):
		return
	var final_position := _boss_auto_camera.global_position
	_boss_auto_camera.enabled = false
	_boss_auto_camera.queue_free()
	_boss_auto_camera = null
	if _boss_return_camera != null and is_instance_valid(_boss_return_camera):

		_boss_return_camera.global_position = final_position
		_boss_return_camera.zoom = _boss_cam_restore_zoom
		_boss_return_camera.enabled = true
		_boss_return_camera.make_current()
	_boss_return_camera = null

## Rescales the shell's collider to whatever the sprite currently is, so the
## body never drifts out of sync with the art. The rectangle keeps its original
## proportions and is grown by the same multiple as the sprite, and its base
## stays planted on the ground line so a growing snail does not float.
func _resize_boss_body() -> void:
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape == null or _sprite == null:
		return
	var body_rect := body_shape.shape as RectangleShape2D
	if body_rect == null:
		return
	var visual_scale := _boss_base_scale if _boss_active else _sprite.scale
	var grow := Vector2.ONE
	if _original_sprite_scale.x > 0.0 and _original_sprite_scale.y > 0.0:
		grow = visual_scale / _original_sprite_scale
	if not is_equal_approx(grow.x, 1.0) or not is_equal_approx(grow.y, 1.0):
		body_rect = body_rect.duplicate() as RectangleShape2D
		body_rect.size = _base_body_size * grow
		body_shape.shape = body_rect
	body_shape.position = Vector2(0.0, _transform_ground_y - body_rect.size.y * 0.5)

func _add_boss_hurtbox() -> void:
	_boss_hurtbox = Area2D.new()
	_boss_hurtbox.name = "BossHurtbox"
	_boss_hurtbox.collision_layer = 1
	_boss_hurtbox.collision_mask = 1
	_boss_hurtbox.monitoring = true
	_boss_hurtbox.monitorable = true
	_boss_hurtbox.add_to_group("enemy_hurtbox")
	add_child(_boss_hurtbox)
	var shape := CollisionShape2D.new()
	shape.set_meta("snail_boss_hurt_shape", true)
	var rect := RectangleShape2D.new()
	var boss_size := _boss_body_size()
	rect.size = boss_size
	shape.shape = rect
	shape.position = Vector2(0.0, _transform_ground_y - boss_size.y * 0.5)
	_boss_hurtbox.add_child(shape)
	_boss_hurtbox.area_entered.connect(_on_boss_hurtbox_area_entered)

	_boss_player_contact = Area2D.new()
	_boss_player_contact.name = "BossPlayerContact"
	_boss_player_contact.collision_layer = 0
	_boss_player_contact.collision_mask = 1
	_boss_player_contact.monitoring = true
	_boss_player_contact.monitorable = false
	add_child(_boss_player_contact)
	var contact_shape := CollisionShape2D.new()
	var contact_rect := RectangleShape2D.new()
	contact_rect.size = boss_size
	contact_shape.shape = contact_rect
	contact_shape.position = shape.position
	_boss_player_contact.add_child(contact_shape)

func _add_boss_aura_shield() -> void:
	if _sprite == null:
		return
	var texture := _current_sprite_texture()
	if texture == null:
		return

	var radius := texture.get_size() * 0.62
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ring_index in 2:
		var ring := Line2D.new()
		ring.name = "BossAuraShield" if ring_index == 0 else "BossAuraShieldInner"
		ring.width = 14.0 if ring_index == 0 else 8.0
		ring.default_color = Color(0.76, 0.28, 1.0, 0.85) if ring_index == 0 else Color(0.94, 0.68, 1.0, 0.75)
		ring.z_index = 5
		ring.z_as_relative = false
		ring.joint_mode = Line2D.LINE_JOINT_ROUND
		ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ring.end_cap_mode = Line2D.LINE_CAP_ROUND
		ring.material = additive
		ring.rotation = 0.22 if ring_index == 1 else 0.0
		ring.scale = Vector2.ONE
		var ring_radius := radius * (0.62 if ring_index == 1 else 1.0)
		for i in range(49):
			var angle := TAU * float(i) / 48.0
			ring.add_point(Vector2(cos(angle) * ring_radius.x, sin(angle) * ring_radius.y))
		_sprite.add_child(ring)
		var pulse := ring.create_tween().set_loops()
		pulse.tween_property(ring, "modulate:a", 0.38, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(ring, "modulate:a", 0.9, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var rotation_pulse := ring.create_tween().set_loops()
		rotation_pulse.tween_property(ring, "rotation", TAU if ring_index == 0 else -TAU, 5.0).as_relative()
		var scale_pulse := ring.create_tween().set_loops()
		scale_pulse.tween_property(ring, "scale", Vector2(1.07, 1.07), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		scale_pulse.tween_property(ring, "scale", Vector2(0.94, 0.94), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var width_pulse := ring.create_tween().set_loops()
		width_pulse.tween_property(ring, "width", 20.0 if ring_index == 0 else 12.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		width_pulse.tween_property(ring, "width", 11.0 if ring_index == 0 else 6.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if ring_index == 0:
			_boss_aura_shield = ring

func _on_boss_hurtbox_area_entered(area: Area2D) -> void:
	if not _boss_active or _boss_dying:
		return
	var attacker := area.get_parent()
	if attacker == null:
		return
	if "is_swinging" in attacker and attacker.is_swinging:
		_flash_boss_aura_shield()
	elif attacker.is_in_group("bullet") and attacker.has_method("deflect"):
		attacker.deflect(global_position)
		_flash_boss_aura_shield()

func _flash_boss_aura_shield() -> void:
	if _boss_aura_shield == null or not is_instance_valid(_boss_aura_shield):
		return
	_boss_aura_shield.default_color = Color(1.0, 0.88, 1.0, 1.0)
	var flash := _boss_aura_shield.create_tween()
	flash.tween_property(_boss_aura_shield, "default_color", Color(0.76, 0.28, 1.0, 0.85), 0.25)

## Normal weapon and ability damage is absorbed by the aura shield.
func take_damage(_amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	return

## The drill is the saw-like attack that can pierce the aura shield.
func take_saw_damage(amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	_apply_boss_damage(amount)

## Bombs are not a swing for the shield to soak up: a blast that goes off against
## the shell hurts the snail the way the drill does.
func take_explosion_damage(amount: float, _direction: Vector2 = Vector2.ZERO) -> void:
	_apply_boss_damage(amount)

## Asked by the ice bomb before it freezes anything: a frozen snail only makes
## sense while the fight is actually running.
func can_be_frozen() -> bool:
	return _boss_active and not _boss_dying

func _apply_boss_damage(amount: float) -> void:
	if not _boss_active or _boss_dying or amount <= 0.0:
		return
	_boss_health = maxf(_boss_health - amount, 0.0)
	_flash_boss_aura_shield()
	EnemyDamage.spawn_damage_number(self, amount, get_global_mouse_position(), true)
	SFX.play("enemy_hit", global_position)
	if _boss_hit_tween and _boss_hit_tween.is_valid():
		_boss_hit_tween.kill()
	_boss_hit_tween = create_tween()
	_boss_hit_tween.tween_property(_sprite, "scale:y", _boss_base_scale.y * 0.93, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_boss_hit_tween.tween_property(_sprite, "scale:y", _boss_base_scale.y, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_update_boss_health_bar()
	var mole := get_tree().get_first_node_in_group("mole")
	if mole != null and mole.has_method("screen_shake"):
		mole.screen_shake(8.0, 0.16)
	if _boss_health <= 0.0:
		_defeat_boss()
		return
	_check_boss_enrage()

func _create_boss_health_bar() -> void:
	_boss_health_layer = CanvasLayer.new()
	_boss_health_layer.name = "SnailBossHealthBar"
	_boss_health_layer.layer = 127
	get_parent().add_child(_boss_health_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_top = 18.0
	root.offset_right = BOSS_HEALTH_ROOT_WIDTH * 0.5
	root.offset_bottom = 18.0 + BOSS_HEALTH_ROOT_HEIGHT
	root.custom_minimum_size = Vector2(BOSS_HEALTH_ROOT_WIDTH, BOSS_HEALTH_ROOT_HEIGHT)
	root.z_index = 100
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_health_layer.add_child(root)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	style.border_color = Color(0.42, 0.28, 0.14, 1.0)
	style.set_border_width_all(2)
	var name_panel := Panel.new()
	name_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_panel.offset_left = 0.0
	name_panel.offset_top = 0.0
	name_panel.offset_right = 0.0
	name_panel.offset_bottom = BOSS_HEALTH_NAME_HEIGHT
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", style)
	root.add_child(name_panel)
	var title := Label.new()
	title.text = "Corrupted Snail"
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_left = 0.0
	title.offset_top = 0.0
	title.offset_right = 0.0
	title.offset_bottom = 0.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = false
	title.add_theme_font_override("font", BOSS_HEALTH_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.92, 0.72, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.12, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_child(title)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0.0
	panel.offset_top = BOSS_HEALTH_NAME_HEIGHT + BOSS_HEALTH_NAME_GAP
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	panel.custom_minimum_size = Vector2(BOSS_HEALTH_PANEL_WIDTH, BOSS_HEALTH_PANEL_HEIGHT)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = BOSS_HEALTH_BAR_INSET
	bg.offset_top = BOSS_HEALTH_BAR_INSET
	bg.offset_right = -BOSS_HEALTH_BAR_INSET
	bg.offset_bottom = -BOSS_HEALTH_BAR_INSET
	bg.color = EnemyDamage.health_bar_background_color()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	_boss_health_trail = ColorRect.new()
	_boss_health_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_health_trail.offset_left = BOSS_HEALTH_FILL_INSET
	_boss_health_trail.offset_top = BOSS_HEALTH_FILL_INSET
	_boss_health_trail.offset_right = -BOSS_HEALTH_FILL_INSET
	_boss_health_trail.offset_bottom = -BOSS_HEALTH_FILL_INSET
	_boss_health_trail.color = BOSS_HEALTH_TRAIL_COLOR
	_boss_health_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_boss_health_trail)
	_boss_health_fill = ColorRect.new()
	_boss_health_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_health_fill.offset_left = BOSS_HEALTH_FILL_INSET
	_boss_health_fill.offset_top = BOSS_HEALTH_FILL_INSET
	_boss_health_fill.offset_right = -BOSS_HEALTH_FILL_INSET
	_boss_health_fill.offset_bottom = -BOSS_HEALTH_FILL_INSET
	_boss_health_fill.color = EnemyDamage.health_bar_color(1.0)
	_boss_health_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_boss_health_fill)
	_update_boss_health_bar()

## Width of a bar held at a given fraction of the track, measured from the right
## edge so the bar drains toward the left.
func _boss_health_bar_right(ratio: float) -> float:
	return -(BOSS_HEALTH_FILL_INSET + BOSS_HEALTH_BAR_INNER * (1.0 - ratio))

## The fill eases to the new total. The trail is deliberately left where it is,
## so it keeps showing the pre-hit amount until its delay runs out and it slides
## down to meet the fill.
func _update_boss_health_bar() -> void:
	if _boss_health_fill == null:
		return
	var ratio := clampf(_boss_health / BOSS_MAX_HEALTH, 0.0, 1.0)
	_boss_health_fill.color = EnemyDamage.health_bar_color(ratio)
	var target := _boss_health_bar_right(ratio)

	if _boss_health_bar_tween != null and _boss_health_bar_tween.is_valid():
		_boss_health_bar_tween.kill()
	_boss_health_bar_tween = create_tween()
	_boss_health_bar_tween.tween_method(
		_set_boss_health_fill_right, _boss_health_fill.offset_right, target,
		BOSS_HEALTH_FILL_TWEEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _boss_health_trail == null:
		return
	if _boss_health_trail_tween != null and _boss_health_trail_tween.is_valid():
		_boss_health_trail_tween.kill()
	_boss_health_trail_tween = create_tween()
	_boss_health_trail_tween.tween_interval(BOSS_HEALTH_TRAIL_DELAY)
	_boss_health_trail_tween.tween_method(
		_set_boss_health_trail_right, _boss_health_trail.offset_right, target,
		BOSS_HEALTH_TRAIL_TWEEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func _set_boss_health_fill_right(offset: float) -> void:
	if _boss_health_fill != null and is_instance_valid(_boss_health_fill):
		_boss_health_fill.offset_right = offset

func _set_boss_health_trail_right(offset: float) -> void:
	if _boss_health_trail != null and is_instance_valid(_boss_health_trail):
		_boss_health_trail.offset_right = offset

func _spawn_boss_minion() -> void:
	if not _boss_active or _boss_dying or BOSS_MINION_SCENES.is_empty():
		return
	if get_tree().get_nodes_in_group("snail_boss_minion").size() >= BOSS_MINION_MAX_ALIVE:
		return

	var parent := get_parent() as Node2D
	if parent == null:
		return
	var scene: PackedScene = BOSS_MINION_SCENES.pick_random()
	var minion := scene.instantiate() as Node2D
	if minion == null:
		return
	minion.add_to_group("snail_boss_minion")

	# Release each random enemy from the front of the shell, at the same spot as
	# the snail's spit, so it drops into the arena like it was coughed out.
	var direction := 1.0 if _sprite.flip_h else -1.0
	var texture := _current_sprite_texture()
	var texture_size := texture.get_size() if texture != null else Vector2(585.0, 442.0)
	var spawn_offset := _sprite.position + Vector2(
		direction * texture_size.x * _boss_base_scale.x * 0.32,
		-texture_size.y * _boss_base_scale.y * 0.06
	)
	minion.position = parent.to_local(to_global(spawn_offset))
	parent.add_child(minion)
	# Same burst-in the arena waves use: the minion is frozen, shrunk and
	# untouchable until it has risen out of the dirt, so it can never trade a hit
	# with the player while it is still materialising.
	EnemySpawn.play(minion)
	SFX.play("enemy_fire", to_global(spawn_offset), -8.0, 0.15, 0.85)

## Frees the adds the fight has left behind, so a stationary one that can never
## reach the mole does not sit on a summon slot until the snail runs dry. Driven
## off the same group the cap counts, which means a minion leaves it by being
## retired here exactly as it would by dying - both paths hand the slot back.
func _retire_stranded_boss_minions() -> void:
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	var behind_x := global_position.x - BOSS_MINION_RETIRE_BEHIND
	for node in get_tree().get_nodes_in_group("snail_boss_minion"):
		var minion := node as Node2D
		if minion == null or not is_instance_valid(minion):
			continue
		var stranded := minion.global_position.x < behind_x
		if not stranded and mole != null and is_instance_valid(mole):
			stranded = minion.global_position.distance_to(mole.global_position) > BOSS_MINION_RETIRE_DIST
		if stranded:
			_retire_boss_minion(minion)

## An add the fight has left behind is taken out quietly rather than blinked out of
## existence. The death cue is quiet because it almost always plays off the left of
## the frame, behind the shell. No coins: nobody earned them.
func _retire_boss_minion(minion: Node2D) -> void:
	SFX.play("enemy_death", minion.global_position, -16.0, 0.15, 0.8)
	minion.queue_free()

## Drops a Drill or Holy Water into the arena for the player to grab on the move.
func _spawn_boss_loot() -> void:
	if not _boss_active or _boss_dying:
		return
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var mole := get_tree().get_first_node_in_group("mole") as Node2D
	if mole == null or not is_instance_valid(mole):
		return
	var drop_at: Vector2 = mole.global_position + BOSS_LOOT_DROP_OFFSET
	LootDrop.spawn_random(parent, drop_at)
	SFX.play("coin", drop_at, -12.0, 0.12, 0.9)

## Runs off every hit, but only does its work on the one that carries the shell
## through half health.
func _check_boss_enrage() -> void:
	if _boss_enraged or not _boss_active or _boss_dying:
		return
	if _boss_health > BOSS_MAX_HEALTH * BOSS_ENRAGE_HEALTH_RATIO:
		return
	_boss_enraged = true
	_boss_enrage_active = true
	_scream_boss()
	await get_tree().create_timer(BOSS_ENRAGE_SCREAM_TIME).timeout
	if not is_inside_tree() or not _boss_active or _boss_dying:
		_boss_enrage_active = false
		return
	# The scream is the certain half of the beat. The ice laser is the dice roll on
	# top of it, so a run can end with the shell taking the bite and saying nothing
	# back. Awaited rather than fired off, because the enrage gate is what holds the
	# snail's ordinary attacks off, and that gate is only released on the way out of
	# here - releasing it while the beam was still winding up would let the purple
	# laser start up underneath it.
	if randf() < BOSS_ICE_LASER_CHANCE:
		var mole := get_tree().get_first_node_in_group("mole") as Node2D
		if mole != null and is_instance_valid(mole):
			await _fire_boss_ice_laser(mole)
	_boss_enrage_active = false

## The scream is the half-health tell: the shell shudders, throws off rings of
## sound, and shoves the camera, so the beat lands even if the player is looking
## straight at the snail rather than at the health bar.
func _scream_boss() -> void:
	SFX.play("enemy_fire", global_position, -3.0, 0.05, 0.5)
	SFX.play("hurt", global_position, -6.0, 0.05, 0.65)
	SFX.play("explosion", global_position, -12.0, 0.1, 0.6)
	var mole := get_tree().get_first_node_in_group("mole")
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", 18.0, 0.5)
	_shudder_boss_sprite()
	_spawn_boss_scream_rings()
	_flash_boss_aura_shield()

## A shiver rather than a squash: the hit reaction already owns the sprite's
## scale, and a second tween fighting it over the same property would leave the
## shell stretched when the next hit landed.
func _shudder_boss_sprite() -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		return
	var base_rotation := _sprite.rotation
	if _boss_scream_tween != null and _boss_scream_tween.is_valid():
		_boss_scream_tween.kill()
	_boss_scream_tween = create_tween()
	for beat in BOSS_SCREAM_SHUDDER_BEATS:
		var swing := BOSS_SCREAM_SHUDDER_ANGLE if beat % 2 == 0 else -BOSS_SCREAM_SHUDDER_ANGLE
		_boss_scream_tween.tween_property(_sprite, "rotation", base_rotation + swing, 0.05)
	_boss_scream_tween.tween_property(_sprite, "rotation", base_rotation, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Rings thrown off the shell one after another, so the scream reads as pressure
## spreading out of it rather than as one flash.
func _spawn_boss_scream_rings() -> void:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null or _sprite == null or not is_instance_valid(_sprite):
		return
	var origin := scene_root.to_local(_sprite.global_position)
	for i in BOSS_SCREAM_RING_COUNT:
		var ring := Line2D.new()
		ring.name = "BossScreamRing"
		ring.width = 14.0 - float(i) * 3.0
		ring.default_color = Color(0.78, 0.42, 1.0, 0.7)
		ring.z_index = BOSS_LASER_FIREWORK_Z
		ring.z_as_relative = false
		_set_boss_scream_ring_radius(BOSS_SCREAM_RING_START_RADIUS, ring)
		scene_root.add_child(ring)
		# Staggered by holding each ring still for a beat before it is let go.
		var tween := ring.create_tween()
		tween.tween_interval(float(i) * BOSS_SCREAM_RING_STAGGER)
		tween.set_parallel(true)
		tween.tween_method(_set_boss_scream_ring_radius.bind(ring),
			BOSS_SCREAM_RING_START_RADIUS, BOSS_SCREAM_RING_END_RADIUS, BOSS_SCREAM_RING_TIME)
		tween.tween_property(ring, "modulate:a", 0.0, BOSS_SCREAM_RING_TIME)
		tween.chain().tween_callback(ring.queue_free)

func _set_boss_scream_ring_radius(radius: float, ring: Line2D) -> void:
	if not is_instance_valid(ring) or ring.get_point_count() < BOSS_SCREAM_RING_POINTS:
		return
	for i in ring.get_point_count():
		var angle := TAU * float(i) / float(ring.get_point_count())
		ring.set_point_position(i, Vector2(cos(angle), sin(angle)) * radius)

## The ice beam. Unlike the purple laser, which locks its direction the moment it
## starts charging, this one keeps its aim on the mole for BOSS_ICE_LASER_AIM_TIME
## and only settles at the end of it - so it cannot be dodged by standing still,
## only by committing to a direction while it is winding up. Where it lands, the
## ground stays frozen.
##
## Enraged, this is one attack in a rotation and is entered from _physics_process
## without being awaited, exactly like the purple laser; the coroutine runs on its
## own and _boss_ice_laser_active is what keeps the next tick out.
func _fire_boss_ice_laser(mole: Node2D) -> void:
	if _boss_ice_laser_active or not _boss_active or _boss_dying or not is_instance_valid(mole):
		return
	_boss_ice_laser_active = true
	# Armed here rather than only at the call sites, so the enrage's own roll and
	# the rotation's timer cannot both claim the same beat and put two beams out
	# back to back. Whichever fires, the next one is a full cooldown away.
	_boss_ice_laser_timer = BOSS_ICE_LASER_COOLDOWN
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		_boss_ice_laser_active = false
		return

	var laser_start := _sprite.global_position
	var tracked_end := laser_start + Vector2.RIGHT * 200.0
	var aim := _create_boss_ice_laser_lines(laser_start, tracked_end, true)
	_boss_ice_laser_lines = aim
	SFX.play("enemy_fire", laser_start, -4.0, 0.1, 0.7)
	if mole.has_method("screen_shake"):
		mole.call("screen_shake", 4.0, 0.2)

	var elapsed := 0.0
	var physics_step := 1.0 / float(Engine.physics_ticks_per_second)
	while elapsed < BOSS_ICE_LASER_AIM_TIME:
		await get_tree().physics_frame
		if not is_inside_tree() or not _boss_active or _boss_dying:
			_abort_boss_ice_laser()
			return
		elapsed += physics_step
		var progress := clampf(elapsed / BOSS_ICE_LASER_AIM_TIME, 0.0, 1.0)
		if is_instance_valid(mole) and mole.is_in_group("mole"):
			var aim_vector := mole.global_position - _sprite.global_position
			if aim_vector.length_squared() > 1.0:
				tracked_end = _sprite.global_position + aim_vector.normalized() * BOSS_LASER_LENGTH
		tracked_end = _clip_boss_laser_to_view(laser_start, tracked_end)
		_set_boss_ice_laser_aim(aim, scene_root.to_local(laser_start), scene_root.to_local(tracked_end), progress)

	# Aim settled. Whatever it was pointing at is where it fires.
	var laser_end := _trace_boss_laser(laser_start, (tracked_end - laser_start).normalized(), tracked_end)
	_clear_boss_laser_lines(aim)
	var beam := _create_boss_ice_laser_lines(laser_start, laser_end, false)
	_boss_ice_laser_lines = beam
	_animate_boss_laser(beam)
	_spawn_boss_ice_laser_charge_flash(laser_start)
	SFX.play("explosion", laser_start, -4.0, 0.12, 1.25)
	if mole.has_method("screen_shake"):
		mole.call("screen_shake", 15.0, BOSS_ICE_LASER_STRIKE_DURATION)
	var reached_laser_tip: bool = await _extend_boss_laser_to_tip(beam, laser_start, laser_end, mole,
		BOSS_ICE_LASER_WIDTH, BOSS_ICE_LASER_DAMAGE, BOSS_ICE_LASER_TRAVEL_TIME, true)
	if not reached_laser_tip:
		_abort_boss_ice_laser()
		return
	_freeze_tiles_along_boss_ice_laser(laser_start, laser_end)
	_spawn_boss_ice_laser_impact(laser_end)

	var laser_time_left := BOSS_ICE_LASER_STRIKE_DURATION
	while laser_time_left > 0.0:
		var damage_interval := minf(0.1, laser_time_left)
		await get_tree().create_timer(damage_interval).timeout
		await get_tree().physics_frame
		laser_time_left -= damage_interval
		_damage_mole_in_boss_laser(mole, laser_start, laser_end, BOSS_ICE_LASER_WIDTH, BOSS_ICE_LASER_DAMAGE, true)
	for line in beam:
		if is_instance_valid(line):
			var fade := line.create_tween().set_parallel(true)
			fade.tween_property(line, "modulate:a", 0.0, BOSS_ICE_LASER_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			for child in line.get_children():
				if child is PointLight2D:
					fade.tween_property(child, "energy", 0.0, BOSS_ICE_LASER_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(BOSS_ICE_LASER_FADE_TIME).timeout
	_abort_boss_ice_laser()

## Drops the beam and hands the fight back its normal rhythm.
func _abort_boss_ice_laser() -> void:
	_clear_boss_laser_lines(_boss_ice_laser_lines)
	_boss_ice_laser_lines.clear()
	_boss_ice_laser_active = false

func _create_boss_ice_laser_lines(start: Vector2, finish: Vector2, telegraph: bool) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	var widths: Array[float]
	var colors: Array[Color]
	if telegraph:
		widths = [BOSS_ICE_LASER_WIDTH + 10.0, BOSS_ICE_LASER_WIDTH * 0.34, 22.0]
		colors = [Color(0.08, 0.36, 0.68, 0.34), Color(0.34, 0.72, 1.0, 0.6), Color(0.78, 0.95, 1.0, 0.75)]
	else:
		widths = [BOSS_ICE_LASER_WIDTH + 58.0, BOSS_ICE_LASER_WIDTH + 22.0, BOSS_ICE_LASER_WIDTH, 26.0]
		colors = [Color(0.06, 0.3, 0.62, 0.36), Color(0.2, 0.62, 1.0, 0.68), Color(0.62, 0.92, 1.0, 0.96), Color(0.94, 0.99, 1.0, 1.0)]

	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return lines
	for i in widths.size():
		var line := Line2D.new()
		line.width = widths[i]
		line.default_color = colors[i]
		line.z_index = 25
		line.z_as_relative = false
		# The aim telegraph winds up by growing into the beam it is warning about,
		# so each line needs to know the width it is growing into.
		line.set_meta("ice_full_width", widths[i])
		line.add_point(scene_root.to_local(start))
		line.add_point(scene_root.to_local(finish))
		scene_root.add_child(line)
		lines.append(line)
	_attach_boss_laser_lights(lines, scene_root.to_local(start), scene_root.to_local(finish), telegraph, BOSS_ICE_LASER_LIGHT_COLOR)
	return lines

## Winds the telegraph up over the aim: thin and faint at the start of the two
## seconds, hot and nearly the width of the real beam by the end of it.
func _set_boss_ice_laser_aim(lines: Array[Line2D], local_start: Vector2, local_finish: Vector2, progress: float) -> void:
	var grow := lerpf(0.16, 1.0, progress)
	var flicker := 0.82 + 0.18 * sin(progress * 42.0)
	for line in lines:
		if not is_instance_valid(line) or line.get_point_count() < 2:
			continue
		line.set_point_position(1, local_finish)
		line.width = float(line.get_meta("ice_full_width")) * grow
		line.modulate.a = lerpf(0.3, 1.0, progress) * flicker
		for child in line.get_children():
			if child is PointLight2D and child.has_meta("laser_fraction"):
				var light_fraction := float(child.get_meta("laser_fraction"))
				(child as PointLight2D).position = local_start.lerp(local_finish, light_fraction)

## The ice the beam leaves behind. Coats the ground rather than breaking it open,
## and registers every cell it touches so the mole slips on all of it - which is
## the part that actually changes the fight.
func _freeze_tiles_along_boss_ice_laser(start: Vector2, finish: Vector2) -> void:
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var tilemap := parent.get_node_or_null("TileMap") as TileMap
	if tilemap == null or tilemap.tile_set == null:
		return
	var segment := finish - start
	var distance := segment.length()
	if distance <= 0.0:
		return
	var direction := segment / distance
	var perpendicular := Vector2(-direction.y, direction.x)
	var tile_world_size := Vector2(tilemap.tile_set.tile_size) * tilemap.scale

	# A layer of its own so the whole patch can be melted away together later, the
	# way the ice bomb melts its blast.
	var frost_layer := Node2D.new()
	frost_layer.name = "BossIceFrost"
	frost_layer.z_index = 0
	frost_layer.global_position = Vector2.ZERO
	parent.add_child(frost_layer)

	var sample_count := maxi(1, int(ceil(distance / BOSS_LASER_TILE_SAMPLE_SPACING)))
	var frosted: Dictionary = {}
	for i in range(sample_count + 1):
		var center := start + direction * minf(float(i) * BOSS_LASER_TILE_SAMPLE_SPACING, distance)
		for offset in [-0.5, -0.25, 0.0, 0.25, 0.5]:
			var sample: Vector2 = center + perpendicular * (BOSS_ICE_LASER_WIDTH * float(offset))
			var cell := tilemap.local_to_map(tilemap.to_local(sample))
			if frosted.has(cell) or tilemap.get_cell_source_id(0, cell) == -1:
				continue
			var tile_data := tilemap.get_cell_tile_data(0, cell)
			# Bedrock is what stops the beam, so the ice stops with it rather than
			# coating the wall the shot died against.
			if tile_data != null and (tile_data.get_custom_data("bedrock") as bool):
				continue
			frosted[cell] = true
			var overlay := IceOverlay.new()
			overlay.tilemap = tilemap
			overlay.cell = cell
			overlay.texture = BOSS_ICE_LASER_ICE_TEXTURE
			overlay.position = tilemap.to_global(tilemap.map_to_local(cell))
			overlay.scale = tile_world_size / BOSS_ICE_LASER_ICE_TEXTURE.get_size()
			overlay.modulate = Color(1.0, 1.0, 1.0, randf_range(0.6, 0.9))
			frost_layer.add_child(overlay)
			FrozenTiles.register(cell, BOSS_ICE_LASER_FROST_DURATION)

	if frost_layer.get_child_count() > 0:
		get_tree().create_timer(BOSS_ICE_LASER_FROST_DURATION).timeout.connect(_melt_boss_ice_frost.bind(frost_layer))
	else:
		frost_layer.queue_free()

## Melts the whole strip of frost the beam laid down. Held until the melt is done,
## so the ice is not pulled out from under itself halfway through fading.
##
## Static on purpose, for the same reason the ice bomb's is: the snail can be freed
## out from under this if the fight is abandoned, and a connection to one of its own
## methods would be torn down with it, leaving the frost frozen to the floor.
static func _melt_boss_ice_frost(frost_layer: Node2D) -> void:
	if not is_instance_valid(frost_layer):
		return
	for child in frost_layer.get_children():
		if child is IceOverlay:
			(child as IceOverlay).fade_out(BOSS_ICE_LASER_FROST_FADE_TIME)
	frost_layer.get_tree().create_timer(BOSS_ICE_LASER_FROST_FADE_TIME + 0.1).timeout.connect(frost_layer.queue_free)

func _spawn_boss_ice_laser_charge_flash(world_pos: Vector2) -> void:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return
	var flash := PointLight2D.new()
	flash.name = "BossIceLaserChargeFlash"
	flash.texture = BOSS_LASER_LIGHT_TEXTURE
	flash.texture_scale = 2.4
	flash.color = BOSS_ICE_LASER_LIGHT_COLOR
	flash.energy = 2.4
	flash.shadow_enabled = false
	scene_root.add_child(flash)
	flash.global_position = world_pos
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "energy", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "texture_scale", 4.4, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(flash.queue_free)

## The same impact as the purple laser with the heat swapped for cold, plus the
## shards the ice bomb throws up when it goes off.
func _spawn_boss_ice_laser_impact(world_pos: Vector2) -> void:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return
	var impact_light := PointLight2D.new()
	impact_light.name = "BossIceLaserTipFlash"
	impact_light.texture = BOSS_LASER_LIGHT_TEXTURE
	impact_light.texture_scale = 0.8
	impact_light.color = BOSS_ICE_LASER_LIGHT_COLOR
	impact_light.energy = 3.2
	impact_light.shadow_enabled = false
	scene_root.add_child(impact_light)
	impact_light.global_position = world_pos
	var light_tween := impact_light.create_tween().set_parallel(true)
	light_tween.tween_property(impact_light, "texture_scale", 6.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light_tween.tween_property(impact_light, "energy", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light_tween.chain().tween_callback(impact_light.queue_free)

	var firework := Node2D.new()
	firework.name = "SnailIceLaserFirework"
	firework.z_index = BOSS_LASER_FIREWORK_Z
	firework.z_as_relative = false
	scene_root.add_child(firework)
	firework.global_position = world_pos

	var spark_texture := _make_firework_spark_texture()
	_spawn_laser_firework_burst(firework, spark_texture, 120, 1.5, 480.0, 980.0, Color(0.36, 0.78, 1.0, 1.0))
	get_tree().create_timer(0.16).timeout.connect(func():
		if is_instance_valid(firework):
			_spawn_laser_firework_burst(firework, spark_texture, 72, 1.25, 260.0, 620.0, Color(0.72, 0.94, 1.0, 1.0))
	)

	_spawn_laser_ground_spray(firework, spark_texture, Color(0.42, 0.8, 1.0, 1.0), Color(0.1, 0.34, 0.7, 0.0))
	_spawn_laser_impact_column(firework, spark_texture, Color(0.6, 0.9, 1.0, 1.0), Color(0.16, 0.5, 0.9, 0.0))
	_spawn_ice_laser_shards(firework)

	get_tree().create_timer(2.0).timeout.connect(firework.queue_free)
	SFX.play("explosion", world_pos, -4.0, 0.1, 1.25)
	var mole := get_tree().get_first_node_in_group("mole")
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", 20.0, 0.45)

## Shards thrown off the point of impact, weighted back down so they fall away
## instead of hanging in the air the way the laser sparks do.
func _spawn_ice_laser_shards(parent: Node2D) -> void:
	var shards := CPUParticles2D.new()
	shards.one_shot = true
	shards.amount = 40
	shards.lifetime = 0.8
	shards.explosiveness = 0.9
	shards.direction = Vector2.ZERO
	shards.spread = 180.0
	shards.initial_velocity_min = 140.0
	shards.initial_velocity_max = 380.0
	shards.gravity = Vector2(0.0, 520.0)
	shards.damping_min = 40.0
	shards.damping_max = 110.0
	shards.scale_amount_min = 0.25
	shards.scale_amount_max = 0.7
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.92, 0.99, 1.0, 1.0))
	gradient.set_color(0.4, Color(0.52, 0.84, 1.0, 0.95))
	gradient.set_color(1, Color(0.2, 0.5, 0.85, 0.0))
	shards.color_ramp = gradient
	shards.z_index = 2
	parent.add_child(shards)
	shards.emitting = true

func _fire_boss_laser(mole: Node2D) -> void:
	if _boss_laser_active or not _boss_active or _boss_dying or not is_instance_valid(mole):
		return
	_boss_laser_active = true

	# Lock direction during the warning so the player has time to dodge.
	var laser_start := _sprite.global_position
	var laser_direction := (mole.global_position - laser_start).normalized()
	if laser_direction == Vector2.ZERO:
		laser_direction = Vector2.DOWN
	# The beam burns through dirt but stops at bedrock, and that stopping point is
	# where its impact goes off.
	var laser_end := _trace_boss_laser(laser_start, laser_direction, laser_start + laser_direction * BOSS_LASER_LENGTH)
	laser_end = _clip_boss_laser_to_view(laser_start, laser_end)
	var telegraph := _create_boss_laser_lines(laser_start, laser_end, true)
	_boss_laser_lines = telegraph
	for line in telegraph:
		if not is_instance_valid(line):
			continue
		var alpha_tween := line.create_tween().set_loops(8)
		alpha_tween.tween_property(line, "modulate:a", 0.2, 0.1)
		alpha_tween.tween_property(line, "modulate:a", 1.0, 0.1)
		var base_width := line.width
		var width_tween := line.create_tween().set_loops(8)
		width_tween.tween_property(line, "width", base_width * 0.75, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		width_tween.tween_property(line, "width", base_width * 1.3, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	SFX.play("enemy_fire", laser_start, -2.0, 0.2)
	if mole.has_method("screen_shake"):
		mole.call("screen_shake", 5.0, 0.18)

	await get_tree().create_timer(BOSS_LASER_CHARGE_TIME).timeout
	if not is_inside_tree() or not _boss_active or _boss_dying:
		_clear_boss_laser_lines(telegraph)
		_boss_laser_lines.clear()
		if is_inside_tree():
			_boss_laser_active = false
			_boss_laser_timer = BOSS_LASER_COOLDOWN
		return

	_clear_boss_laser_lines(telegraph)
	var beam := _create_boss_laser_lines(laser_start, laser_end, false)
	_boss_laser_lines = beam
	_animate_boss_laser(beam)
	SFX.play("explosion", laser_start, -3.0, 0.12)
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", 16.0, BOSS_LASER_STRIKE_DURATION)
	var reached_laser_tip: bool = await _extend_boss_laser_to_tip(beam, laser_start, laser_end, mole)
	if not reached_laser_tip:
		_clear_boss_laser_lines(beam)
		_boss_laser_lines.clear()
		if is_inside_tree():
			_boss_laser_active = false
			_boss_laser_timer = BOSS_LASER_COOLDOWN
		return
	_break_blocks_along_boss_laser(laser_start, laser_end)
	# Detonate the purple impact only once the beam's animated tip arrives.
	_spawn_boss_laser_impact(laser_end)

	var laser_time_left := BOSS_LASER_STRIKE_DURATION
	while laser_time_left > 0.0:
		var damage_interval := minf(0.1, laser_time_left)
		await get_tree().create_timer(damage_interval).timeout
		await get_tree().physics_frame
		laser_time_left -= damage_interval
		_damage_mole_in_boss_laser(mole, laser_start, laser_end)
	for line in beam:
		if is_instance_valid(line):
			var fade := line.create_tween().set_parallel(true)
			fade.tween_property(line, "modulate:a", 0.0, BOSS_LASER_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			for child in line.get_children():
				if child is PointLight2D:
					fade.tween_property(child, "energy", 0.0, BOSS_LASER_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(BOSS_LASER_FADE_TIME).timeout
	_clear_boss_laser_lines(beam)
	_boss_laser_lines.clear()
	if is_inside_tree():
		_boss_laser_active = false
		_boss_laser_timer = BOSS_LASER_COOLDOWN

func _create_boss_laser_lines(start: Vector2, finish: Vector2, telegraph: bool) -> Array[Line2D]:
	var lines: Array[Line2D] = []
	var widths: Array[float]
	var colors: Array[Color]
	if telegraph:
		widths = [82.0, 38.0]
		colors = [Color(0.34, 0.02, 0.72, 0.48), Color(0.82, 0.35, 1.0, 0.85)]
	else:
		widths = [BOSS_LASER_WIDTH + 72.0, BOSS_LASER_WIDTH + 28.0, BOSS_LASER_WIDTH, 30.0]
		colors = [Color(0.28, 0.01, 0.58, 0.38), Color(0.62, 0.06, 1.0, 0.7), Color(0.88, 0.42, 1.0, 0.98), Color(0.98, 0.82, 1.0, 1.0)]

	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return lines
	for i in widths.size():
		var line := Line2D.new()
		line.width = widths[i]
		line.default_color = colors[i]
		line.z_index = 25
		line.z_as_relative = false
		line.add_point(scene_root.to_local(start))
		line.add_point(scene_root.to_local(finish))
		scene_root.add_child(line)
		lines.append(line)
	_attach_boss_laser_lights(lines, scene_root.to_local(start), scene_root.to_local(finish), telegraph)
	return lines

func _attach_boss_laser_lights(lines: Array[Line2D], local_start: Vector2, local_finish: Vector2, telegraph: bool, light_color: Color = Color(0.62, 0.2, 1.0, 1.0)) -> void:
	if lines.is_empty() or not is_instance_valid(lines[0]):
		return
	var beam_line := lines[0]
	for fraction in [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875]:
		var light := PointLight2D.new()
		light.name = "BossLaserPurpleLight"
		light.position = local_start.lerp(local_finish, fraction)
		light.set_meta("laser_fraction", fraction)
		light.texture = BOSS_LASER_LIGHT_TEXTURE
		light.texture_scale = 3.0
		light.color = light_color
		light.energy = 0.55 if telegraph else 1.0
		light.range_item_cull_mask = 1023
		light.shadow_enabled = false
		beam_line.add_child(light)

func _extend_boss_laser_to_tip(lines: Array[Line2D], start: Vector2, finish: Vector2, mole: Node2D, width: float = BOSS_LASER_WIDTH, damage: float = BOSS_LASER_DAMAGE, travel_time: float = BOSS_LASER_TRAVEL_TIME, freeze_mole: bool = false) -> bool:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return false
	var local_start := scene_root.to_local(start)
	var local_finish := scene_root.to_local(finish)
	var elapsed := 0.0
	var last_damage_time := 0.0
	var physics_step := 1.0 / float(Engine.physics_ticks_per_second)
	_set_boss_laser_progress(lines, local_start, local_finish, 0.0)
	while elapsed < travel_time:
		await get_tree().physics_frame
		if not is_inside_tree() or not _boss_active or _boss_dying:
			return false
		elapsed += physics_step
		var progress := clampf(elapsed / travel_time, 0.0, 1.0)
		var current_tip := start.lerp(finish, progress)
		_set_boss_laser_progress(lines, local_start, local_finish, progress)
		if elapsed - last_damage_time >= 0.1:
			_damage_mole_in_boss_laser(mole, start, current_tip, width, damage, freeze_mole)
			last_damage_time = elapsed
	_set_boss_laser_progress(lines, local_start, local_finish, 1.0)
	return true

func _set_boss_laser_progress(lines: Array[Line2D], local_start: Vector2, local_finish: Vector2, progress: float) -> void:
	var current_tip := local_start.lerp(local_finish, progress)
	for line in lines:
		if not is_instance_valid(line) or line.get_point_count() < 2:
			continue
		line.set_point_position(1, current_tip)
		for child in line.get_children():
			if child is PointLight2D and child.has_meta("laser_fraction"):
				var light_fraction := float(child.get_meta("laser_fraction"))
				(child as PointLight2D).position = local_start.lerp(local_finish, light_fraction * progress)

func _animate_boss_laser(lines: Array[Line2D]) -> void:
	for line in lines:
		if not is_instance_valid(line):
			continue
		var base_width := line.width
		var tween := line.create_tween().set_loops()
		tween.tween_property(line, "width", base_width * 1.2, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(line, "width", base_width * 0.88, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(line, "width", base_width, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_boss_laser_lines(lines: Array[Line2D]) -> void:
	for line in lines:
		if is_instance_valid(line):
			line.queue_free()

func _damage_mole_in_boss_laser(mole: Node2D, start: Vector2, finish: Vector2, width: float = BOSS_LASER_WIDTH, damage: float = BOSS_LASER_DAMAGE, freeze_mole: bool = false) -> void:
	if not is_instance_valid(mole) or not mole.is_in_group("mole") or not mole.has_method("take_damage") or not (mole is CollisionObject2D):
		return
	var mole_body := mole as CollisionObject2D
	var segment := finish - start
	if segment.length_squared() <= 0.0:
		return
	var beam_shape := RectangleShape2D.new()
	beam_shape.size = Vector2(maxf(segment.length(), 1.0), width + 56.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = beam_shape
	query.transform = Transform2D(segment.angle(), (start + finish) * 0.5)
	query.collision_mask = mole_body.collision_layer
	query.collide_with_bodies = true
	query.collide_with_areas = false
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 32):
		if hit.get("collider") == mole_body:
			mole.call("take_damage", damage, start, true, true)
			if freeze_mole:
				IceBomb.freeze_node(mole, IceBomb.MOLE_FREEZE_DURATION)
			return

func _break_blocks_along_boss_laser(start: Vector2, finish: Vector2) -> void:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		return
	var segment := finish - start
	var distance := segment.length()
	if distance <= 0.0:
		return
	var direction := segment / distance
	var perpendicular := Vector2(-direction.y, direction.x)
	var sample_count := maxi(1, int(ceil(distance / BOSS_LASER_TILE_SAMPLE_SPACING)))
	for i in range(sample_count + 1):
		var center := start + direction * minf(float(i) * BOSS_LASER_TILE_SAMPLE_SPACING, distance)
		for offset in [-BOSS_LASER_WIDTH * 0.5, -BOSS_LASER_WIDTH * 0.25, 0.0, BOSS_LASER_WIDTH * 0.25, BOSS_LASER_WIDTH * 0.5]:
			var sample: Vector2 = center + perpendicular * float(offset)
			var cell := tilemap.local_to_map(tilemap.to_local(sample))
			if tilemap.get_cell_source_id(0, cell) == -1:
				continue
			var tile_data := tilemap.get_cell_tile_data(0, cell)
			if tile_data != null and (tile_data.get_custom_data("bedrock") as bool):
				continue
			TileBreakSFX.break_tile(tilemap, cell, get_parent(), false, TileBreakSFX.DEBRIS_Z_OVER_BEAM)

## Keep the beam's endpoint and impact on-screen when the full-range shot would
## run beyond the camera. Leave room for the explosion particles near the edge.
func _clip_boss_laser_to_view(start: Vector2, finish: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return finish
	var direction := (finish - start).normalized()
	if direction == Vector2.ZERO:
		return finish
	var zoom := camera.zoom
	var half_view := camera.get_viewport_rect().size / zoom * 0.5
	var center := camera.get_screen_center_position()
	var margin := Vector2.ONE * 240.0
	var left := center.x - half_view.x + margin.x
	var right := center.x + half_view.x - margin.x
	var top := center.y - half_view.y + margin.y
	var bottom := center.y + half_view.y - margin.y
	var max_distance := start.distance_to(finish)
	if direction.x > 0.0001:
		max_distance = minf(max_distance, (right - start.x) / direction.x)
	elif direction.x < -0.0001:
		max_distance = minf(max_distance, (left - start.x) / direction.x)
	if direction.y > 0.0001:
		max_distance = minf(max_distance, (bottom - start.y) / direction.y)
	elif direction.y < -0.0001:
		max_distance = minf(max_distance, (top - start.y) / direction.y)
	return start + direction * maxf(max_distance, 0.0)

## Where the beam stops: the first bedrock it runs into, or its full length when
## it never finds any. Mirrors the corrupted heart's laser, so both boss beams
## bite into the same kind of wall.
func _trace_boss_laser(start: Vector2, direction: Vector2, finish: Vector2) -> Vector2:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		return finish
	var distance := start.distance_to(finish)
	var sample_count := maxi(1, int(ceil(distance / BOSS_LASER_TILE_SAMPLE_SPACING)))
	for i in range(1, sample_count + 1):
		var progress := minf(float(i) * BOSS_LASER_TILE_SAMPLE_SPACING, distance)
		var sample := start + direction * progress
		var cell := tilemap.local_to_map(tilemap.to_local(sample))
		var tile_data := tilemap.get_cell_tile_data(0, cell)
		if tile_data != null and (tile_data.get_custom_data("bedrock") as bool):
			return sample
	return finish

## A laser impact is a radial spray of purple sparks rather than an expanding
## ring, so the hit reads as debris thrown off the ground instead of a drawn
## circle scaling up and fading out over the top of it.
func _spawn_boss_laser_impact(world_pos: Vector2) -> void:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return
	var explosion := BOSS_LASER_EXPLOSION_SCENE.instantiate() as GPUParticles2D
	explosion.scale = Vector2.ONE * 2.5
	explosion.modulate = Color(0.68, 0.24, 1.0, 1.0)
	explosion.finished.connect(explosion.queue_free)
	scene_root.add_child(explosion)
	explosion.global_position = world_pos
	explosion.emitting = true
	var impact_light := PointLight2D.new()
	impact_light.name = "BossLaserTipPurpleFlash"
	impact_light.texture = BOSS_LASER_LIGHT_TEXTURE
	impact_light.texture_scale = 0.8
	impact_light.color = Color(0.64, 0.18, 1.0, 1.0)
	impact_light.energy = 3.0
	impact_light.shadow_enabled = false
	scene_root.add_child(impact_light)
	impact_light.global_position = world_pos
	var light_tween := impact_light.create_tween().set_parallel(true)
	light_tween.tween_property(impact_light, "texture_scale", 6.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light_tween.tween_property(impact_light, "energy", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light_tween.chain().tween_callback(impact_light.queue_free)

	var firework := Node2D.new()
	firework.name = "SnailLaserFirework"
	firework.z_index = BOSS_LASER_FIREWORK_Z
	firework.z_as_relative = false
	scene_root.add_child(firework)
	firework.global_position = world_pos

	var spark_texture := _make_firework_spark_texture()
	_spawn_laser_firework_burst(firework, spark_texture, 120, 1.5, 480.0, 980.0, Color(0.72, 0.18, 1.0, 1.0))
	get_tree().create_timer(0.16).timeout.connect(func():
		if is_instance_valid(firework):
			_spawn_laser_firework_burst(firework, spark_texture, 72, 1.25, 260.0, 620.0, Color(0.92, 0.62, 1.0, 1.0))
	)

	# The ground spray: sparks hugging the surface at a shallow angle, so they fan
	# outward along the floor the beam landed on rather than filling a sphere.
	_spawn_laser_ground_spray(firework, spark_texture)
	# The hot core, a tight fast burst straight up through the impact point.
	_spawn_laser_impact_column(firework, spark_texture)

	get_tree().create_timer(2.0).timeout.connect(firework.queue_free)
	SFX.play("explosion", world_pos, -3.0, 0.1)
	var mole := get_tree().get_first_node_in_group("mole")
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", 22.0, 0.45)

## Wide, flat fan of sparks thrown sideways along the ground. `spread` is measured
## from `direction`, so aiming UP with a near-180 spread keeps everything close to
## the horizontal, and the low gravity lets the spray settle rather than arc.
func _spawn_laser_ground_spray(parent: Node2D, spark_texture: Texture2D, hot: Color = Color(0.86, 0.42, 1.0, 1.0), fade: Color = Color(0.4, 0.08, 0.72, 0.0)) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 88
	particles.lifetime = 0.85
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 165.0
	particles.initial_velocity_min = 320.0
	particles.initial_velocity_max = 860.0
	particles.gravity = Vector2(0.0, 620.0)
	particles.damping_min = 40.0
	particles.damping_max = 130.0
	particles.scale_amount_min = 0.22
	particles.scale_amount_max = 0.6
	particles.texture = spark_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.96, 1.0, 1.0))
	gradient.set_color(0.12, hot)
	gradient.set_color(1, fade)
	particles.color_ramp = gradient
	particles.z_index = 1
	parent.add_child(particles)
	particles.emitting = true

## The narrow bright plume off the exact hit point, replacing the old expanding
## sprite flash: fast, short-lived, and tight enough to read as the beam's contact
## point rather than a glow swelling over the whole impact.
func _spawn_laser_impact_column(parent: Node2D, spark_texture: Texture2D, hot: Color = Color(0.94, 0.66, 1.0, 1.0), fade: Color = Color(0.55, 0.12, 0.95, 0.0)) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 46
	particles.lifetime = 0.42
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 18.0
	particles.direction = Vector2.UP
	particles.spread = 34.0
	particles.initial_velocity_min = 420.0
	particles.initial_velocity_max = 1150.0
	particles.gravity = Vector2(0.0, 900.0)
	particles.damping_min = 60.0
	particles.damping_max = 150.0
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.85
	particles.texture = spark_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(0.3, hot)
	gradient.set_color(1, fade)
	particles.color_ramp = gradient
	particles.z_index = 2
	parent.add_child(particles)
	particles.emitting = true

func _spawn_laser_firework_burst(parent: Node2D, spark_texture: Texture2D, amount: int, lifetime: float, min_speed: float, max_speed: float, tint: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = min_speed
	particles.initial_velocity_max = max_speed
	particles.gravity = Vector2(0.0, 280.0)
	particles.damping_min = 24.0
	particles.damping_max = 72.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.4
	particles.texture = spark_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.94, 1.0, 1.0))
	gradient.set_color(0.18, tint)
	gradient.set_color(1, Color(tint.r * 0.5, tint.g * 0.3, tint.b, 0.0))
	particles.color_ramp = gradient
	particles.z_index = 1
	parent.add_child(particles)
	particles.emitting = true

func _make_firework_spark_texture() -> Texture2D:
	if _firework_spark_texture != null:
		return _firework_spark_texture
	const TEXTURE_SIZE := 32
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(TEXTURE_SIZE - 1, TEXTURE_SIZE - 1) * 0.5
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var distance := Vector2(x, y).distance_to(center) / (TEXTURE_SIZE * 0.5)
			var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 2.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_firework_spark_texture = ImageTexture.create_from_image(image)
	return _firework_spark_texture

func _spit_boss_projectile(mole: Node2D) -> void:
	# Spawn at the visual center of the corrupted snail, not offset toward its
	# mouth or pushed outside its shell. The projectile's spawn grace lets it
	# travel out from inside the boss before terrain collisions can explode it.
	var spawn_pos := _sprite.global_position
	var aim := (mole.global_position - spawn_pos).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT if not _sprite.flip_h else Vector2.LEFT
	var spread := deg_to_rad(14.0)
	var angles: Array[float] = [0.0]
	_boss_projectile_count += 1
	if _boss_projectile_count % 4 == 0:
		angles = [-spread, 0.0, spread]
	for angle in angles:
		var direction := aim.rotated(angle)
		var projectile := BOSS_PROJECTILE_SCENE.instantiate() as Area2D
		get_parent().add_child(projectile)
		projectile.global_position = spawn_pos
		projectile.setup(direction * BOSS_PROJECTILE_SPEED)
		projectile.rotation = direction.angle()
	SFX.play("enemy_fire", spawn_pos, -4.0, 0.2, 0.8)

## The shell's collider, measured in the sprite's own scale space. Kept as a
## ratio of the texture so it grows by exactly the same multiple as the sprite
## no matter how far the transformation takes it.
func _boss_body_size() -> Vector2:
	var texture := _current_sprite_texture()
	if texture == null:
		return Vector2(460.0, 350.0)
	var visual_scale := _boss_base_scale if _boss_active else _sprite.scale
	return texture.get_size() * visual_scale * Vector2(0.78, 0.84)

func _break_blocks_ahead(direction: float) -> void:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		return
	var boss_size := _boss_body_size()
	var x_front := global_position.x + direction * (boss_size.x * 0.5 + 35.0)
	var y_top := global_position.y + _transform_ground_y - boss_size.y + 35.0
	var y_bottom := global_position.y + _transform_ground_y - 20.0
	# Clear more than one tile column ahead: the level 10 tilemap is scaled,
	# and the narrow old probe could leave a solid seam directly in the shell's path.
	var tile_width := tilemap.tile_set.tile_size.x * absf(tilemap.global_scale.x)
	var clear_distance := maxf(tile_width * 2.0, 160.0)
	var start := tilemap.local_to_map(tilemap.to_local(Vector2(x_front - 34.0, y_top)))
	var finish := tilemap.local_to_map(tilemap.to_local(Vector2(x_front + clear_distance, y_bottom)))
	for x in range(mini(start.x, finish.x), maxi(start.x, finish.x) + 1):
		for y in range(mini(start.y, finish.y), maxi(start.y, finish.y) + 1):
			var cell := Vector2i(x, y)
			if tilemap.get_cell_source_id(0, cell) != -1:
				TileBreakSFX.break_tile(tilemap, cell, get_parent(), true)
			elif tilemap.get_layers_count() > 1 and tilemap.get_cell_source_id(1, cell) != -1:
				TileBreakSFX.break_decoration_tile(tilemap, cell, get_parent())

## Stops bombs, adds and other loose props from shoving the snail around while it
## is being driven along by script. Collision exceptions are checked before the
## layer and mask rules, so this can exclude a bomb without also excluding the
## ground the snail is standing on - which a mask change could not do, because
## bombs and tiles share a layer.
##
## Only the level's direct children are swept, because everything the player
## throws and everything the fight spawns is parented straight to the level. The
## player is handled by _ignore_mole_pushes instead.
func _ignore_loose_body_pushes() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var tilemap := parent.get_node_or_null("TileMap")
	var mole := get_tree().get_first_node_in_group("mole")
	for child in parent.get_children():
		if child == self or child == tilemap or child == mole:
			continue
		# Static bodies cannot impart momentum, so there is nothing to ignore.
		if not (child is PhysicsBody2D) or (child is StaticBody2D):
			continue
		add_collision_exception_with(child as PhysicsBody2D)
	_ignore_mole_pushes()

## Keeps the player from dragging the boss around. The contact is dropped from
## the solver rather than answered with a counter-force, so the shell still
## collides with tiles and with everything else that drives the fight.
func _ignore_mole_pushes() -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	if mole == null or not is_instance_valid(mole):
		return
	if not (mole is PhysicsBody2D):
		return
	add_collision_exception_with(mole as PhysicsBody2D)
	# Contact damage during the fight runs off a separate Area2D, so losing the
	# physical contact does not cost the player their hit.

func _defeat_boss() -> void:
	_boss_dying = true
	_boss_active = false
	_clear_boss_laser_lines(_boss_laser_lines)
	_boss_laser_lines.clear()
	_boss_laser_active = false
	_abort_boss_ice_laser()
	_boss_enrage_active = false
	set_physics_process(false)
	linear_velocity = Vector2.ZERO
	gravity_scale = 0.0
	_restore_boss_camera_zoom()
	# Keep the boss-fight lighting through the death sequence; restoring it here
	# made the finale and its effects much darker than the fight.
	if _boss_hurtbox != null:
		_boss_hurtbox.set_deferred("monitoring", false)
		_boss_hurtbox.set_deferred("monitorable", false)
		for shape in _boss_hurtbox.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).set_deferred("disabled", true)
	if _boss_player_contact != null:
		_boss_player_contact.set_deferred("monitoring", false)
		_boss_player_contact.set_deferred("monitorable", false)
		for shape in _boss_player_contact.get_children():
			if shape is CollisionShape2D:
				(shape as CollisionShape2D).set_deferred("disabled", true)
	var interaction_area := get_node_or_null("Area2D") as Area2D
	if interaction_area != null:
		interaction_area.set_deferred("monitoring", false)
		interaction_area.set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	var body_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if _boss_health_layer != null:
		var fade := create_tween()
		# CanvasLayer has no modulate - the fade belongs to the bar's root control.
		var bar_root := _boss_health_layer.get_child(0) as CanvasItem
		if bar_root != null:
			fade.tween_property(bar_root, "modulate:a", 0.0, 0.6)
		fade.tween_callback(_boss_health_layer.queue_free)
		_boss_health_layer = null
	_start_grand_death()

## The grand death: the snail defies the mole one last time, fireworks burst
## off its shell the whole time the curse is up, and then it goes out in one
## giant blast - gibs, coins, screen shake - instead of quietly deflating.
func _start_grand_death() -> void:
	_hide_cutscene_ui()
	SFX.play("enemy_death", global_position)
	_show_death_dialogue()
	_spawn_firework_ring()
	_run_death_firework_loop()

## The death cutscene plays to an empty screen: every piece of interface - the
## level's HUD (hearts, buttons, hotbar, popups) and the autoload HUDs (coins,
## combo, map, touch controls) - is hidden and put to sleep for the length of
## the sequence. Nothing is restored: the scene dies into the credits. The
## vignette stays because it is atmosphere rather than interface, and the
## death dialogue is added after this runs, so the snail still gets his last
## words over the empty screen.
func _hide_cutscene_ui() -> void:
	var scene_root := get_tree().current_scene
	if scene_root != null:
		for child in scene_root.get_children():
			if (child is CanvasLayer or child is Control) and child.name != "VignetteLayer":
				_hide_ui_node(child)
	for child in get_tree().root.get_children():
		if child is CanvasLayer or child is Control:
			_hide_ui_node(child)

func _hide_ui_node(node: Node) -> void:
	# CanvasLayer is no CanvasItem, but both it and Control carry visible.
	node.set("visible", false)
	node.process_mode = Node.PROCESS_MODE_DISABLED

## The player dismisses the final dialogue to trigger the finale. Like
## _open_dialogue, the box is configured once it is inside the tree so its
## labels are ready.
func _show_death_dialogue() -> void:
	if _death_box != null:
		return
	_focus_dialogue_camera_on_snail()
	_death_box = preload("res://scenes/dialogue_box.tscn").instantiate()
	_death_box.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(_death_box)
	_setup_death_box.call_deferred()

func _setup_death_box() -> void:
	if _death_box == null or not is_instance_valid(_death_box):
		return
	_death_box.set_npc_name(boss_npc_name)
	_death_box.set_portrait(portrait_texture)
	_apply_portrait_blink_to(_death_box)
	_death_box.next_pressed.connect(_on_death_dialogue_next)
	_death_box.show_text(DEATH_CURSE_TEXT, 0, 0, true, false)
	_death_box.next_button.text = "FINISH"
	var type_duration := DEATH_CURSE_TEXT.length() * DIALOGUE_TYPE_SPEED
	get_tree().create_timer(type_duration + 0.2).timeout.connect(func():
		if is_instance_valid(_death_box):
			_death_box.skip_typing())

func _on_death_dialogue_next() -> void:
	_death_finale()

func _dismiss_death_box() -> void:
	if _death_box == null or not is_instance_valid(_death_box):
		_keep_death_camera_on_snail()
		return
	var box := _death_box
	box.hide_box()
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(box):
			box.queue_free()
		if _death_box == box:
			_death_box = null
		_keep_death_camera_on_snail())

func _run_death_firework_loop() -> void:

	while is_inside_tree() and _death_box != null and is_instance_valid(_death_box):
		await get_tree().create_timer(DEATH_FIREWORK_LOOP_INTERVAL).timeout
		if is_inside_tree() and _death_box != null and is_instance_valid(_death_box):
			for burst in 2:
				_spawn_death_firework()

## One firework exploding at a random point on the snail's shell.
func _spawn_death_firework() -> void:
	if _death_finale_started or not is_instance_valid(self) or not is_inside_tree():
		return
	var body_size := _boss_body_size()
	var radius := maxf(body_size.x, body_size.y) * DEATH_FIREWORK_RADIUS_SCALE
	var offset := Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(radius * 0.3, radius)
	_spawn_death_firework_burst(global_position + offset)

## A cluster of particle bursts around the shell.
func _spawn_firework_ring() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var body_size := _boss_body_size()
	var radius := maxf(body_size.x, body_size.y) * DEATH_FIREWORK_RADIUS_SCALE
	for i in DEATH_FIREWORK_CLUSTER_COUNT:
		var angle := TAU * float(i) / float(DEATH_FIREWORK_CLUSTER_COUNT)
		_spawn_death_firework_burst(global_position + Vector2.from_angle(angle) * radius)

## A dense, layered particle burst sized to read at the boss camera's zoom.
func _spawn_death_firework_burst(world_pos: Vector2) -> void:
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		return
	var body_size := _boss_body_size()
	var blast_scale := clampf(maxf(body_size.x, body_size.y) / 460.0, DEATH_FIREWORK_BLAST_SCALE_MIN, DEATH_FIREWORK_BLAST_SCALE_MAX)
	var firework := Node2D.new()
	firework.z_index = BOSS_LASER_FIREWORK_Z
	firework.z_as_relative = false
	scene_root.add_child(firework)
	firework.global_position = world_pos

	var spark_texture := _make_firework_spark_texture()
	var tint: Color = DEATH_FIREWORK_COLORS.pick_random()
	# Each particle node holds one burst while the central finale waits on input.
	# Large sparks stay legible at the distant camera scale; the old subpixel
	# particle sizes made every shell explosion effectively invisible.
	_spawn_laser_firework_burst(firework, spark_texture, int(DEATH_FIREWORK_PARTICLE_COUNT * blast_scale), 1.3, 420.0, 860.0 * blast_scale, tint)
	_spawn_laser_firework_burst(firework, spark_texture, int(DEATH_FIREWORK_PARTICLE_COUNT * 0.55 * blast_scale), 1.0, 200.0, 540.0 * blast_scale, Color(1.0, 0.94, 1.0, 1.0))
	_spawn_laser_firework_burst(firework, spark_texture, int(DEATH_FIREWORK_PARTICLE_COUNT * 0.35 * blast_scale), 0.8, 100.0, 300.0 * blast_scale, Color(1.0, 0.78, 0.26, 1.0))

	get_tree().create_timer(2.2).timeout.connect(firework.queue_free)
	SFX.play("explosion", world_pos, -4.0, 0.1)

## The shell finally gives out: an enormous blast, the body shattering into gibs
## that tumble away from the explosion, the coin drop - and only then, gone.
func _death_finale() -> void:
	if _death_finale_started:
		return
	if _death_box == null or not is_instance_valid(_death_box):
		return
	_death_finale_started = true
	var body_size := _boss_body_size()

	for i in 6:
		var offset := Vector2(randf_range(-body_size.x, body_size.x) * 0.5, randf_range(-body_size.y, body_size.y) * 0.5)
		get_tree().create_timer(randf_range(0.0, 0.4)).timeout.connect(_spawn_death_firework_burst.bind(global_position + offset))

	var center := global_position
	_spawn_death_firework_burst(center)
	_spawn_death_firework_burst(center + Vector2(-body_size.x * 0.35, -body_size.y * 0.3))
	_spawn_death_firework_burst(center + Vector2(body_size.x * 0.35, -body_size.y * 0.25))
	_shake_camera(2.2)
	if _sprite != null and is_instance_valid(_sprite):
		EnemyDamage.spawn_death_fragments(self, _sprite, Vector2.ZERO, maxf(scale.x * _sprite.scale.x, 0.0), 2.5, true)
	Shop.drop_coins(global_position, 40, 10)
	_dismiss_death_box()
	_begin_black_hole_after_explosion(center, body_size)

	# The shell stays visible until the hole has swallowed the arena tiles.
	# Keep this controller alive until the black-hole pull hands off to credits.

func _shake_camera(strength_multiplier: float = 1.0) -> void:
	var mole := get_tree().get_first_node_in_group("mole")
	if is_instance_valid(mole) and mole.has_method("screen_shake"):
		mole.call("screen_shake", DEATH_SHAKE_STRENGTH * strength_multiplier, DEATH_SHAKE_DURATION)

func _open_black_hole(center: Vector2, body_size: Vector2) -> void:
	if not is_inside_tree() or _death_credits_started:
		return
	var scene_root := get_tree().current_scene as Node2D
	if scene_root == null:
		_go_to_credits()
		return

	_death_black_hole = Node2D.new()
	_death_black_hole.name = "CorruptedSnailBlackHole"
	_death_black_hole.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_black_hole.z_index = 30
	_death_black_hole.z_as_relative = false
	scene_root.add_child(_death_black_hole)
	_death_black_hole.global_position = center
	_death_black_hole.scale = Vector2(0.04, 0.04)
	var radius := maxf(body_size.x, body_size.y) * DEATH_BLACK_HOLE_RADIUS_SCALE

	var aura := PointLight2D.new()
	aura.name = "BlackHolePurpleAura"
	aura.texture = SNAIL_GLOW_TEXTURE
	aura.texture_scale = maxf(radius / 150.0, 1.0)
	aura.color = Color(0.58, 0.12, 1.0, 1.0)
	aura.energy = 1.8
	aura.range_item_cull_mask = 1023
	aura.shadow_enabled = false
	aura.z_index = -2
	_death_black_hole.add_child(aura)
	var aura_pulse := aura.create_tween().set_loops()
	aura_pulse.tween_property(aura, "energy", 2.4, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura_pulse.tween_property(aura, "energy", 1.4, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var halo := Polygon2D.new()
	halo.polygon = _black_hole_circle(radius * 0.9)
	halo.color = Color(0.24, 0.025, 0.42, 0.82)
	halo.z_index = -1
	_death_black_hole.add_child(halo)
	var core := Polygon2D.new()
	core.polygon = _black_hole_circle(radius * 0.53)
	core.color = Color(0.005, 0.0, 0.012, 1.0)
	core.z_index = 1
	_death_black_hole.add_child(core)
	_add_black_hole_ring(_death_black_hole, radius * 0.58, 18.0, Color(0.93, 0.42, 1.0, 0.95))
	_add_black_hole_ring(_death_black_hole, radius * 0.72, 11.0, Color(0.48, 0.12, 0.92, 0.82))
	_add_black_hole_ring(_death_black_hole, radius * 0.91, 6.0, Color(0.22, 0.08, 0.44, 0.62))

	var growth := _death_black_hole.create_tween()
	growth.tween_property(_death_black_hole, "scale", Vector2.ONE, DEATH_BLACK_HOLE_GROW_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	growth.tween_callback(_start_black_hole_tile_suction.bind(center))

func _start_black_hole_tile_suction(center: Vector2) -> void:
	var tilemap := get_parent().get_node_or_null("TileMap") as TileMap
	if tilemap == null:
		_pull_snail_into_black_hole(center)
		return

	var pull_radius := 1800.0
	if _dialogue_focus_camera != null and is_instance_valid(_dialogue_focus_camera):
		var half_view := _dialogue_focus_camera.get_viewport_rect().size / _dialogue_focus_camera.zoom * 0.5
		pull_radius = half_view.length()
	var cell_lookup: Dictionary = {}
	for layer in range(tilemap.get_layers_count()):
		for cell in tilemap.get_used_cells(layer):
			var cell_world := tilemap.to_global(tilemap.map_to_local(cell))
			if cell_world.distance_to(center) <= pull_radius:
				cell_lookup[cell] = true
	var cells: Array[Vector2i] = []
	for cell in cell_lookup:
		cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_world := tilemap.to_global(tilemap.map_to_local(a))
		var b_world := tilemap.to_global(tilemap.map_to_local(b))
		return a_world.distance_squared_to(center) > b_world.distance_squared_to(center))

	var index := 0
	while index < cells.size() and is_inside_tree():
		for batch_offset in range(DEATH_BLACK_HOLE_TILE_BATCH):
			var cell_index := index + batch_offset
			if cell_index >= cells.size():
				break
			var cell: Vector2i = cells[cell_index]
			if tilemap.get_cell_source_id(0, cell) != -1:
				TileBreakSFX.break_tile(tilemap, cell, get_parent(), true, TileBreakSFX.DEBRIS_Z_OVER_BEAM, center, true)
			else:
				for layer in range(1, tilemap.get_layers_count()):
					if tilemap.get_cell_source_id(layer, cell) != -1:
						TileBreakSFX.break_decoration_tile(tilemap, cell, get_parent(), TileBreakSFX.DEBRIS_Z_OVER_BEAM, center, true, layer)
		index += DEATH_BLACK_HOLE_TILE_BATCH
		if index < cells.size():
			await get_tree().create_timer(DEATH_BLACK_HOLE_TILE_INTERVAL).timeout
	_pull_snail_into_black_hole(center)

func _pull_snail_into_black_hole(center: Vector2) -> void:
	if _sprite == null or not is_instance_valid(_sprite):
		_finish_into_black_hole()
		return
	_transformed = false
	_sprite.visible = true
	_sprite.modulate.a = 1.0
	var pull := _death_black_hole.create_tween()
	pull.set_parallel(true)
	pull.tween_property(_sprite, "global_position", center, DEATH_BLACK_HOLE_SNAIL_PULL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pull.tween_property(_sprite, "global_scale", Vector2.ZERO, DEATH_BLACK_HOLE_SNAIL_PULL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pull.tween_property(_sprite, "rotation", TAU * 2.0, DEATH_BLACK_HOLE_SNAIL_PULL_TIME).as_relative()
	for aura in _aura_sprites:
		if is_instance_valid(aura):
			pull.tween_property(aura, "modulate:a", 0.0, DEATH_BLACK_HOLE_SNAIL_PULL_TIME)
	if _dialogue_focus_camera != null and is_instance_valid(_dialogue_focus_camera):
		pull.tween_property(_dialogue_focus_camera, "global_position", center, DEATH_BLACK_HOLE_SNAIL_PULL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		pull.tween_property(_dialogue_focus_camera, "zoom", Vector2(1.3, 1.3), DEATH_BLACK_HOLE_SNAIL_PULL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pull.chain().tween_callback(func():
		_sprite.visible = false
		_finish_into_black_hole()
	)

func _black_hole_circle(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 65:
		var angle := TAU * float(i) / 64.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _add_black_hole_ring(parent: Node2D, radius: float, width: float, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = width
	ring.default_color = color
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	for point in _black_hole_circle(radius):
		ring.add_point(point)
	parent.add_child(ring)
	var spin := ring.create_tween().set_loops()
	spin.tween_property(ring, "rotation", TAU, randf_range(2.4, 4.0)).as_relative()

## The snail is inside the hole now. The camera already rests on the black
## hole and the mole keeps standing where he was - he is never part of the
## pull. A beat on the hole, then the transition carries the credits in.
func _finish_into_black_hole() -> void:
	# Keep pushing into the hole rather than resting on it: the zoom runs on
	# under the closing circle, so the core swallows the frame before the
	# credits take over.
	if _dialogue_focus_camera != null and is_instance_valid(_dialogue_focus_camera):
		var push := _dialogue_focus_camera.create_tween()
		push.tween_property(_dialogue_focus_camera, "zoom", Vector2(3.0, 3.0), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	get_tree().create_timer(0.6).timeout.connect(_go_to_credits)

func _go_to_credits() -> void:
	if _death_credits_started:
		return
	_death_credits_started = true
	# Beating the final boss is what unlocks Boss Rush on the title screen, and
	# it is recorded here rather than in the credits roll so that quitting
	# straight out of the fight still counts.
	Progress.mark_game_completed()
	var transition := preload("res://scenes/scene_transition.tscn").instantiate()
	get_tree().root.add_child(transition)
	transition.change_to(DEATH_CREDITS_PATH)

func _begin_black_hole_after_explosion(center: Vector2, body_size: Vector2) -> void:
	get_tree().create_timer(DEATH_BLACK_HOLE_DELAY).timeout.connect(_open_black_hole.bind(center, body_size))

func _keep_death_camera_on_snail() -> void:
	# Hold the snail's cutscene camera for the black-hole shot instead of restoring
	# the player's camera as soon as the final dialogue closes.
	_dialogue_return_camera = null
	_dialogue_return_camera_was_enabled = false

func _update_transformation_aura() -> void:
	if not _transformed or _sprite == null:
		return
	var texture := _current_sprite_texture()
	if texture:
		_sprite.position.y = _transform_ground_y - texture.get_size().y * _sprite.scale.y * 0.5
	for aura in _aura_sprites:
		if not is_instance_valid(aura):
			continue
		aura.texture = texture
		aura.position.x = _sprite.position.x
		aura.position.y = _transform_ground_y - texture.get_size().y * aura.scale.y * 0.5 if texture else _sprite.position.y
		aura.flip_h = _sprite.flip_h

func _current_sprite_texture() -> Texture2D:
	if _sprite == null or _sprite.sprite_frames == null:
		return null
	return _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)

func _grant_unlock() -> void:
	if unlock_ability == "":
		return
	if not condition_wave_path.is_empty() and not _condition_met:
		return
	var shop := get_tree().get_root().get_node_or_null("/root/Shop")
	if shop == null or not shop.has_method("give"):
		return
	shop.give(unlock_ability)
	if shop.has_method("equip"):
		shop.equip(unlock_ability)
	_prepare_reward()

## Decides how the reward is presented: a tool with artwork of its own gets the
## full "get" fanfare, anything else (story abilities) keeps the plain banner.
func _prepare_reward() -> void:
	var shop := get_tree().get_root().get_node_or_null("/root/Shop")
	var weapon: WeaponData = null
	if shop != null and shop.has_method("get_weapon"):
		weapon = shop.get_weapon(unlock_ability)
	if weapon != null and weapon.weapon_type == WeaponData.Type.MELEE:
		_reward_message = "%s Collected!" % weapon.display_name
		_reward_icon = MELEE_ICON
		_reward_tint = weapon.icon_color
		return
	_banner_text = unlock_text if unlock_text != "" else unlock_ability.to_upper()

func _show_reward() -> void:
	if _reward_message != "":
		var fanfare: CanvasLayer = ITEM_GET.new()
		fanfare.configure(_reward_message, _reward_icon, _reward_tint)
		get_tree().root.add_child(fanfare)
	elif _banner_text != "":
		_show_unlock_banner(_banner_text)

func _show_unlock_banner(label_text: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "UnlockBanner"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 200.0
	label.offset_bottom = 270.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 1))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	var font := load("res://Baby Doll.otf") as Font
	if font:
		label.add_theme_font_override("font", font)
	label.text = "%s UNLOCKED!" % label_text
	layer.add_child(label)
	get_tree().root.add_child(layer)
	var tween := layer.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(layer.queue_free)
