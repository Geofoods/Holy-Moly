extends CharacterBody2D
## One fighter in the online PvP arena.
##
## Every peer instantiates one of these per roster entry, and each node is
## authoritative on its own peer only: the owner reads input and moves itself,
## and the MultiplayerSynchronizer child pushes the result out. Movement
## therefore never needs a round trip, and nothing is simulated twice.
##
## Damage is the one thing that does cross the wire. The attacker's client is the
## only peer running that player's swing, so it is the one that detects the
## overlap, and it reports the hit to the victim's client, which applies it to
## itself. That is exactly one report per landed swing no matter how many peers
## are watching, and it is why the hitbox only ever monitors on the local player.
##
## The balance numbers here are the arena's own rather than the campaign's - the
## campaign mole has twelve hearts and a shop, and neither belongs in a duel.

enum State { IDLE, RUN, AIR, HURT, DEAD }

const HURTBOX_GROUP := &"pvp_hurtbox"

## Movement is the campaign mole's, not the arena's own: the same run speed,
## acceleration, gravity, jump and coyote window, so a duel handles exactly like
## the rest of the game (see the constants at the top of mole.gd). Only the
## combat numbers below are the arena's own.
const SPEED := 700.0
const ACCELERATION := 3600.0
## Airborne steering is damped to 0.6x of the ground value, as in mole.gd.
const AIR_ACCELERATION := 2160.0
const FRICTION := 3600.0
const AIR_FRICTION := 1600.0
const GRAVITY := 2450.0
const JUMP_VELOCITY := -1400.0
const JUMP_CUT := 0.4
const COYOTE_TIME := 0.08

const MAX_HEALTH := 100.0
## Five clean hits to finish someone, so a duel has room to breathe.
const ATTACK_DAMAGE := 20.0
const ATTACK_COOLDOWN := 0.45
const ATTACK_SWING_TIME := 0.22
const ATTACK_ARC := 2.0
const ATTACK_KNOCKBACK := 560.0
const ATTACK_LIFT := -300.0
## How long a player is left alone after walking back in, so a fresh spawn is
## not immediately camped.
const SPAWN_INVULNERABLE_TIME := 0.9
const RESPAWN_DELAY := 1.6
## Movement is dulled, not taken away, while the hit reaction plays out.
const HURT_TIME := 0.25
const HURT_CONTROL := 0.35
## Safety net for anyone who ends up under the room despite the walls.
const VOID_Y := 2000.0

## The body is teleported to wherever the owner says it is, so on remote peers it
## is the sprite that gets smoothed: it trails the authoritative body by a few
## frames instead of the whole character stuttering between packets.
const REMOTE_SMOOTHING := 14.0
const CAMERA_ZOOM := Vector2(0.62, 0.62)

const FLICKER_INTERVAL := 0.16

## --- Replicated state. The names here are the paths in
## resources/pvp_player_sync.tres; renaming one needs that config updated too.
var health: float = MAX_HEALTH
var facing := 1.0
var state := State.IDLE
var alive := true
var invulnerable := false
## Bumped once per swing. Remote peers only see the counter move, so the swing
## animation replays from it rather than needing an RPC of its own.
var attack_serial := 0

var _peer_id := 1
var _is_local := false
## Left untyped on purpose: the arena is reached through has_method/call, since
## naming its script here would be a circular preload.
var _arena = null

var _coyote_timer := 0.0
var _attack_cooldown := 0.0
var _hurt_timer := 0.0
var _invulnerable_timer := 0.0
var _respawn_timer := 0.0
var _swinging := false
## Runs on every peer rather than from the invulnerability timer, so a remote
## player's flicker animates here too instead of freezing at a fixed alpha.
var _flicker_clock := 0.0
var _hit_this_swing: Array[int] = []

## Last values seen from the replicated state, so the visuals only react to an
## actual change rather than being rebuilt every frame.
var _seen_state := state
var _seen_alive := alive
var _seen_facing := facing
var _seen_serial := attack_serial
var _seen_health := health

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _weapon: Node2D = $Weapon
@onready var _hitbox: Area2D = $Weapon/Hitbox
@onready var _nameplate: Label = $Nameplate


func _ready() -> void:
	# The arena claims these too, but a lone player scene (or a test harness)
	# would otherwise error on a missing "dig_slash" every physics tick.
	ensure_input_actions()
	# The hitbox is off until this player is the one swinging it.
	_hitbox.monitoring = false
	_refresh_animation()


## Called by pvp_arena.gd once the node is in the tree. Authority is set here
## rather than in _ready so it does not matter whether the caller configured the
## instance before or after add_child(). Only the locally owned fighter gets a
## camera, so each peer's viewport follows its own player.
func configure(peer_id: int, arena, spawn_point: Vector2) -> void:
	set_multiplayer_authority(peer_id, true)
	_peer_id = peer_id
	_is_local = peer_id == multiplayer.get_unique_id()
	_arena = arena
	global_position = spawn_point
	_refresh_identity()
	if _is_local:
		var camera := Camera2D.new()
		camera.name = "PlayerCamera"
		camera.zoom = CAMERA_ZOOM
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 8.0
		add_child(camera)
		camera.make_current()


func is_local() -> bool:
	return _is_local


## Turns this player's replication on or off for everyone. The arena calls it
## with false as its room is about to be swapped out for a rematch, so the
## synchronizers of the outgoing match stop talking before the other peer has
## torn its own copy down.
func set_replication_visible(value: bool) -> void:
	var synchronizer := get_node_or_null("Synchronizer") as MultiplayerSynchronizer
	if synchronizer != null:
		synchronizer.public_visibility = value


func _physics_process(delta: float) -> void:
	# Only the owner drives this body. Everyone else's copy is written by the
	# synchronizer, and running a second simulation on top would fight it.
	if not _is_local:
		return

	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
	invulnerable = _invulnerable_timer > 0.0

	if not alive:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0 and _can_respawn():
			_respawn()
		_death_fall(delta)
		return

	if global_position.y > VOID_Y:
		_die(0)
		return

	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_move(delta)
	_attack_input()
	_update_state()


func _process(delta: float) -> void:
	_sync_visuals(delta)


func _move(delta: float) -> void:
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	var control := HURT_CONTROL if _hurt_timer > 0.0 else 1.0
	var direction := Input.get_axis("ui_left", "ui_right")

	if absf(direction) > 0.01:
		facing = signf(direction)
		var accel := (ACCELERATION if is_on_floor() else AIR_ACCELERATION) * control
		velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
	else:
		var friction := FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		velocity.y += GRAVITY * delta
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("ui_accept") and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0
		SFX.play("jump", global_position)
	# Releasing early cuts the rise short, so a jump has a height range instead
	# of being an all-or-nothing hop. Same cut the campaign applies.
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	move_and_slide()


func _attack_input() -> void:
	if _attack_cooldown > 0.0:
		return
	if not InputMap.has_action("dig_slash") or not Input.is_action_just_pressed("dig_slash"):
		return
	# A click on the arena's own buttons is UI, not a swing.
	if get_viewport().gui_get_hovered_control() != null:
		return
	_begin_attack()


func _begin_attack() -> void:
	_attack_cooldown = ATTACK_COOLDOWN
	attack_serial += 1
	# The counter is the trigger the visuals watch, so the value this peer just
	# wrote must not read back as a change and replay the swing twice.
	_seen_serial = attack_serial
	_swinging = true
	_hit_this_swing.clear()
	_hitbox.monitoring = true
	if not _hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		_hitbox.area_entered.connect(_on_hitbox_area_entered)
	SFX.play("swing", global_position)
	_play_swing_visual()

	var tween := create_tween()
	tween.tween_interval(ATTACK_SWING_TIME)
	tween.tween_callback(_end_attack)


## Leans the weapon through the arc. The mirror is applied to `Weapon` rather
## than to the sprite, so the hitbox travels with the swing and the reach stays
## symmetrical: a negative X scale maps the whole pivot, hitbox included.
func _play_swing_visual() -> void:
	_weapon.scale.x = facing
	_weapon.rotation = -ATTACK_ARC * 0.5 * facing
	var tween := create_tween()
	tween.tween_property(_weapon, "rotation", ATTACK_ARC * 0.5 * facing, ATTACK_SWING_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _end_attack() -> void:
	_swinging = false
	_hitbox.monitoring = false
	if _hitbox.area_entered.is_connected(_on_hitbox_area_entered):
		_hitbox.area_entered.disconnect(_on_hitbox_area_entered)


## Only the owner reaches this: it is the only peer whose swing enables the
## hitbox. A target is claimed once per swing, so sweeping across someone does
## not land two hits.
func _on_hitbox_area_entered(area: Area2D) -> void:
	if not _is_local or not _swinging:
		return
	if not area.is_in_group(HURTBOX_GROUP):
		return
	var victim = area.get_parent()
	if victim == null or victim == self:
		return
	if not victim.has_method("receive_hit"):
		return
	var victim_id: int = victim.get_multiplayer_authority()
	if victim_id == _peer_id or _hit_this_swing.has(victim_id):
		return
	_hit_this_swing.append(victim_id)
	var direction: Vector2 = (victim.global_position - global_position).normalized()
	victim.receive_hit.rpc_id(victim_id, ATTACK_DAMAGE, direction, _peer_id)


## Applied on the victim's own peer, which is the authority on this node's health.
## Every other peer reads the result back through the synchronizer.
##
## This is host-trust netcode: the sender is checked against the announced
## attacker and the roster, which stops an honest client from scoring by
## accident, but it is not an anti-cheat. A competitive build would resolve hits
## on the server instead.
@rpc("any_peer", "call_remote", "reliable")
func receive_hit(amount: float, direction: Vector2, attacker_id: int) -> void:
	if not _is_local or not alive:
		return
	if not Net.in_match:
		return
	if multiplayer.get_remote_sender_id() != attacker_id:
		return
	if attacker_id == _peer_id or not Net.players.has(attacker_id):
		return
	if invulnerable:
		return
	hurt(amount, direction, attacker_id)


## Split out from the RPC so a hazard could damage a player without going
## through the network at all.
func hurt(amount: float, direction: Vector2, attacker_id: int) -> void:
	health = maxf(0.0, health - amount)
	_hurt_timer = HURT_TIME
	_invulnerable_timer = SPAWN_INVULNERABLE_TIME
	invulnerable = true
	velocity = Vector2(direction.x * ATTACK_KNOCKBACK, ATTACK_LIFT)
	SFX.play("hurt", global_position)
	_damage_flash()
	if health <= 0.0:
		_die(attacker_id)


func _die(killer_id: int) -> void:
	if not alive:
		return
	alive = false
	state = State.DEAD
	health = 0.0
	velocity = Vector2.ZERO
	if _hitbox.monitoring:
		_end_attack()
	SFX.play("death", global_position)
	_respawn_timer = RESPAWN_DELAY
	if Net.in_match:
		Net.report_kill(_peer_id, killer_id)


## A dead player keeps falling until it lands, so a kill in mid-air reads as a
## body dropping rather than one frozen in the air.
func _death_fall(delta: float) -> void:
	if is_on_floor():
		velocity = Vector2.ZERO
		return
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.y += GRAVITY * delta
	move_and_slide()


func _respawn() -> void:
	alive = true
	state = State.IDLE
	health = MAX_HEALTH
	_hurt_timer = 0.0
	_invulnerable_timer = SPAWN_INVULNERABLE_TIME
	invulnerable = true
	velocity = Vector2.ZERO
	global_position = _pick_spawn_point()
	_sprite.position = Vector2.ZERO


## Nothing comes back once the match is over. With no session at all the arena is
## being walked on its own - see pvp_arena.gd - so a death still respawns.
func _can_respawn() -> bool:
	return Net.in_match or not Net.is_online()


## The arena hands back the spawn point furthest from the fight, so a respawn
## does not walk straight back into whoever just won the exchange.
func _pick_spawn_point() -> Vector2:
	if _arena != null and _arena.has_method("spawn_point_for"):
		var point: Vector2 = _arena.call("spawn_point_for", _peer_id)
		return point
	return global_position


func _update_state() -> void:
	if _hurt_timer > 0.0:
		state = State.HURT
	elif not is_on_floor():
		state = State.AIR
	elif absf(velocity.x) > 20.0:
		state = State.RUN
	else:
		state = State.IDLE


## Everything visual here is derived from replicated state, so the same code
## draws the local player and everyone else's copy of them.
func _sync_visuals(delta: float) -> void:
	_flicker_clock += delta
	if _seen_alive != alive or _seen_state != state:
		_seen_alive = alive
		_seen_state = state
		_refresh_animation()
	if _seen_health != health:
		_seen_health = health
		queue_redraw()
	if _seen_facing != facing:
		_seen_facing = facing
		_sprite.flip_h = facing < 0.0
		if not _swinging:
			_weapon.scale.x = facing
	if _seen_serial != attack_serial:
		_seen_serial = attack_serial
		_play_swing_visual()
	# Flickers on every peer while the i-frames are up, so a hit that will not
	# count reads as one instead of leaving both players guessing.
	if invulnerable:
		_sprite.modulate.a = 0.4 if fmod(_flicker_clock, FLICKER_INTERVAL) > FLICKER_INTERVAL * 0.5 else 0.95
	else:
		_sprite.modulate.a = 1.0
	if not _is_local:
		_sprite.position = _sprite.position.lerp(Vector2.ZERO, clampf(REMOTE_SMOOTHING * delta, 0.0, 1.0))


func _refresh_animation() -> void:
	match state:
		State.DEAD:
			_sprite.play("hurtground")
		State.HURT:
			_sprite.play("hurt")
		State.AIR:
			_sprite.play("jump")
		State.RUN:
			_sprite.play("walk")
		_:
			_sprite.play("idle")


func _refresh_identity() -> void:
	var tint := Net.player_color_of(_peer_id)
	_sprite.self_modulate = tint
	_nameplate.text = Net.player_name_of(_peer_id)
	_nameplate.add_theme_color_override("font_color", tint)


func _damage_flash() -> void:
	var flash := _sprite.create_tween()
	flash.tween_property(_sprite, "self_modulate", Color(3.0, 3.0, 3.0, 1.0), 0.05)
	flash.tween_property(_sprite, "self_modulate", Net.player_color_of(_peer_id), 0.15)


## The health bar sits over the head and is drawn by the player itself, so there
## is no extra node per fighter to keep in step.
func _draw() -> void:
	if not alive or health >= MAX_HEALTH or health <= 0.0:
		return
	var width := 110.0
	var height := 12.0
	var origin := Vector2(-width * 0.5, -186.0)
	draw_rect(Rect2(origin - Vector2(2.0, 2.0), Vector2(width + 4.0, height + 4.0)), Color(0, 0, 0, 0.75))
	var ratio := clampf(health / MAX_HEALTH, 0.0, 1.0)
	draw_rect(Rect2(origin, Vector2(width * ratio, height)), _health_color(ratio))


func _health_color(ratio: float) -> Color:
	if ratio < 0.5:
		return Color(0.9, 0.2, 0.2).lerp(Color(0.95, 0.75, 0.2), ratio * 2.0)
	return Color(0.95, 0.75, 0.2).lerp(Color(0.35, 0.9, 0.4), (ratio - 0.5) * 2.0)


## The campaign registers its bindings the first time a level loads, but the PvP
## arena can be the first thing a session ever plays, so the handful it reads are
## claimed here too. Same physical keys as mole.gd, so WASD works in both.
static func ensure_input_actions() -> void:
	_ensure_key(&"ui_accept", KEY_W)
	_ensure_key(&"ui_accept", KEY_SPACE)
	_ensure_key(&"ui_accept", KEY_UP)
	_ensure_key(&"ui_left", KEY_A)
	_ensure_key(&"ui_right", KEY_D)
	_ensure_mouse(&"dig_slash", MOUSE_BUTTON_LEFT)


static func _ensure_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _ensure_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
