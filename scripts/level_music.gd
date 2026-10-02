extends Node

var _player: AudioStreamPlayer = null
var _stream := preload("res://nojisuma-grotto-120967.mp3")
var _target_volume := -18.0

## The Corrupted Heart's theme. The level bed is faded out when the player
## reaches level 09 and this takes over once the boss has finished talking, so
## the two never play at once.
var _boss_player: AudioStreamPlayer = null
var _boss_stream := preload("res://Grimm (Hollow Knight_ The Grimm Troupe).mp3")
var _boss_target_volume := -16.0

## Whichever tween is currently moving the theme's volume, or null when it is
## sitting still. Tracked so a new move kills the one it replaces instead of
## racing it: two tweens writing the same volume_db fight each other, and the
## fade-in runs long enough that pausing to read the field guide during it is
## an ordinary thing for a player to do.
var _boss_volume_tween: Tween = null

## The level every fade-down in the game bottoms out at. Shared so "silent" is
## one number rather than a -40 copied into each tween.
const SILENT_VOLUME_DB := -40.0

## The theme plays a fifth slower than it was written, 1.2x as long throughout.
## Godot slows audio by resampling rather than time-stretching, so this drops
## the pitch by the same factor as the tempo - the boss has been alone and quiet
## through the whole approach and the track reads better arriving low and
## unhurried. Same treatment the intro menu gives its own music.
const BOSS_PITCH_SCALE := 1.0 / 1.2

## How long the theme takes to leave once the Corrupted Heart is down. Long on
## purpose: the death finale runs well past this, so the track recedes under the
## collapse instead of being cut off at the kill.
const BOSS_DEATH_FADE := 6.0

## Cancels the theme's in-flight volume move, if any, so the caller can start
## its own without the two overlapping.
func _kill_boss_volume_tween() -> void:
	if _boss_volume_tween != null and _boss_volume_tween.is_valid():
		_boss_volume_tween.kill()
	_boss_volume_tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start() -> void:
	# Changing level tears the boss theme down, so the level 09 track cannot
	# bleed into whatever comes next. Called from the mole's ready, so it is the
	# one point that reliably means "a different level is loading".
	stop_boss_track()
	if _player and is_instance_valid(_player):
		return
	_player = AudioStreamPlayer.new()
	_player.stream = _stream
	_player.volume_db = _target_volume
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_player.play)
	_player.play()

## Starts the boss theme from silence and loops it. Already-playing is left
## alone, so re-entering the boss trigger cannot restart the track mid-fade.
##
## The default fade is deliberately long. The tween runs in decibels from the
## silent floor, which back-loads the movement - most of what the ear reads as
## "arriving" happens in the last third - so this settles as a slow swell under
## the fight rather than dropping in behind the dialogue. It outlasts the walk
## from the arena to the boss, so the theme is still arriving when the fight
## properly begins.
func play_boss_track(fade_time := 6.0) -> void:
	if _boss_player != null and is_instance_valid(_boss_player):
		return
	_boss_player = AudioStreamPlayer.new()
	_boss_player.stream = _boss_stream
	_boss_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_boss_player.pitch_scale = BOSS_PITCH_SCALE
	# Starts at the silent floor so the fade in reads as one movement, rather
	# than a track that lands at full level and then ducks. The long default
	# fade means this is still inaudible for the first second or so.
	_boss_player.volume_db = SILENT_VOLUME_DB
	add_child(_boss_player)
	# The theme is shorter than the fight it scores, so it has to loop instead
	# of falling silent partway through the encounter.
	_boss_player.finished.connect(_boss_player.play)
	_boss_player.play()
	_boss_volume_tween = create_tween()
	_boss_volume_tween.tween_property(_boss_player, "volume_db", _boss_target_volume, fade_time)

## Fades the boss theme out and tears it down. `fade_time` of 0 is the instant
## variant used when a level change is already wiping the screen.
func stop_boss_track(fade_time := 0.8) -> void:
	if _boss_player == null or not is_instance_valid(_boss_player):
		_boss_player = null
		return
	# Cleared before the tween is built so a call that lands mid-fade tears the
	# old player down instead of adopting it and leaving it to play on.
	_kill_boss_volume_tween()
	var player := _boss_player
	_boss_player = null
	if fade_time <= 0.0:
		player.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(player.queue_free)

func stop() -> void:
	stop_boss_track()
	if not _player or not is_instance_valid(_player):
		return
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, 1.0)
	tween.tween_callback(_player.queue_free)
	_player = null

## The field guide ducks whatever is playing. Both players are covered: in level
## 09 the bed is already gone, so pausing only the bed would duck nothing at all
## while the boss theme carried on over the popup.
func pause() -> void:
	if _player and is_instance_valid(_player) and _player.playing:
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, 0.4)
		tween.tween_callback(_player.set.bind("stream_paused", true))
	if _boss_player and is_instance_valid(_boss_player) and _boss_player.playing:
		_kill_boss_volume_tween()
		_boss_volume_tween = create_tween()
		_boss_volume_tween.tween_property(_boss_player, "volume_db", SILENT_VOLUME_DB, 0.4)
		_boss_volume_tween.tween_callback(_boss_player.set.bind("stream_paused", true))

func resume() -> void:
	if _player and is_instance_valid(_player):
		_player.stream_paused = false
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", _target_volume, 0.4)
	if _boss_player and is_instance_valid(_boss_player):
		_kill_boss_volume_tween()
		_boss_player.stream_paused = false
		_boss_volume_tween = create_tween()
		_boss_volume_tween.tween_property(_boss_player, "volume_db", _boss_target_volume, 0.4)

func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing
