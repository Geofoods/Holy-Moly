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

## The track that takes over once the heart is down: the walk from its arena to
## the snail, and then the snail's fight. It has to outlive level 09 - the snail
## lives in level 10 - so it sits on a player of its own rather than in the boss
## slot, which start() tears down on every level change.
var _vessel_player: AudioStreamPlayer = null
var _vessel_stream := preload("res://Hollow Knight OST - Sealed Vessel.mp3")
var _vessel_target_volume := -14.0
var _vessel_volume_tween: Tween = null

## The slice of the vessel track currently looping. `_vessel_loop_end` of 0 means
## run on to the end of the file rather than seeking back to the start of it.
var _vessel_loop_start := 0.0
var _vessel_loop_end := 0.0

## Its opening scores the walk, the snail's conversation interrupts it, and
## whatever follows that point carries the fight.
const VESSEL_OPENING_END := 20.0
const VESSEL_AFTER_SNAIL := 43.0

var _vessel_road_active := false
var _vessel_resume_start := 0.0
var _vessel_resume_end := VESSEL_OPENING_END

## The only stretch the vessel track belongs to: the heart's arena and the walk
## from it to the snail. Allowed across the one boundary between them and dropped
## anywhere else, so it cannot follow the mole out past the fight.
const VESSEL_SCENES := [
	"res://scenes/level_09.tscn",
	"res://scenes/level_10.tscn",
]

## Scenes that carry a track of their own instead of the level bed. Keyed by
## scene path, so a scene is named once here wherever it gets loaded from.
const REGION_TRACKS := {
	"res://scenes/mole_village.tscn": "res://Stardew Valley OST - Pelican Town.mp3",
}

## A scene's own track: up while the mole is in it, gone once they step out.
## Kept apart from the bed so arriving somewhere that wants the bed back does not
## first have to unwind this one.
var _region_player: AudioStreamPlayer = null
var _region_path := ""
var _region_volume_tween: Tween = null
var _region_target_volume := -14.0

## Cancels the theme's in-flight volume move, if any, so the caller can start
## its own without the two overlapping.
func _kill_boss_volume_tween() -> void:
	if _boss_volume_tween != null and _boss_volume_tween.is_valid():
		_boss_volume_tween.kill()
	_boss_volume_tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# A looping slice is caught by watching the playhead rather than by
	# `finished`: that only ever fires at the end of the whole file, so it would
	# let a segment run on into music the mole is not meant to hear. Polling also
	# survives a paused tree, because this autoload always processes - which
	# matters, the snail's dialogue stops the level without stopping us.
	if _vessel_loop_end <= 0.0:
		return
	if _vessel_player == null or not is_instance_valid(_vessel_player):
		return
	if not _vessel_player.playing or _vessel_player.stream_paused:
		return
	if _vessel_player.get_playback_position() < _vessel_loop_end:
		return
	_vessel_player.play(_vessel_loop_start)

## Whether the player is on the stretch of the game this track is scored for. The
## death fade is six seconds long, so the walk can begin while the heart is still
## coming apart, and a run that somehow starts outside it should not pick the
## track up at all.
func _on_the_road_to_the_snail() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return VESSEL_SCENES.has(str(scene.scene_file_path))

func _kill_vessel_volume_tween() -> void:
	if _vessel_volume_tween != null and _vessel_volume_tween.is_valid():
		_vessel_volume_tween.kill()
	_vessel_volume_tween = null

func _kill_region_volume_tween() -> void:
	if _region_volume_tween != null and _region_volume_tween.is_valid():
		_region_volume_tween.kill()
	_region_volume_tween = null

## Brings the scene's own track in line with wherever the mole has just arrived:
## started for a scene that has one, let go for a scene that does not. This is the
## fade-out on leaving, because arriving anywhere else is what stepping out looks
## like from here - whether the mole walked out through an exit or fast travelled.
func _update_region_track() -> void:
	var scene := get_tree().current_scene
	var wanted := "" if scene == null else str(REGION_TRACKS.get(scene.scene_file_path, ""))
	if wanted.is_empty():
		stop_region()
		return
	# Already carrying this one. A respawn back into the village is not an
	# arrival, and restarting the track over it would cut the music off.
	if wanted == _region_path and _region_player != null and is_instance_valid(_region_player):
		return
	stop_region(0.0)
	_region_path = wanted
	_region_player = AudioStreamPlayer.new()
	_region_player.stream = load(_region_path)
	_region_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_region_player.volume_db = SILENT_VOLUME_DB
	add_child(_region_player)
	# Looped off the end of the file rather than a segment, so nothing has to
	# watch the playhead for a track that is simply the scene's own.
	_region_player.finished.connect(_region_player.play)
	_region_player.play()
	_region_volume_tween = create_tween()
	_region_volume_tween.tween_property(_region_player, "volume_db", _region_target_volume, 2.0)

## Fades a scene's own track out and lets it go, so it cannot follow the mole out
## of the scene it belongs to. 0 tears it down at once.
func stop_region(fade_time := 0.8) -> void:
	if _region_player == null or not is_instance_valid(_region_player):
		_region_player = null
		_region_path = ""
		return
	if _region_volume_tween != null and _region_volume_tween.is_valid():
		_region_volume_tween.kill()
	_region_volume_tween = null
	var player := _region_player
	_region_player = null
	_region_path = ""
	if fade_time <= 0.0:
		player.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(player.queue_free)

## Fades the level bed out and lets it go. The bed is deliberately carried from
## level to level as the mole walks, so this is only for arriving somewhere that
## wants other music instead, or for leaving the game.
func stop_bed(fade_time := 1.0) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(_player.queue_free)
	_player = null

## Runs one slice of the track on a loop, fading it up from silence. Both bounds
## are positions in the song as written - this one is not slowed down, so its
## timestamps are literal.
func _play_vessel_segment(from: float, until: float, fade_time: float) -> void:
	_vessel_resume_start = from
	_vessel_resume_end = until
	_kill_vessel_volume_tween()
	if _vessel_player == null or not is_instance_valid(_vessel_player):
		_vessel_player = AudioStreamPlayer.new()
		_vessel_player.stream = _vessel_stream
		_vessel_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_vessel_player)
	_vessel_loop_start = from
	_vessel_loop_end = until
	_vessel_player.volume_db = SILENT_VOLUME_DB
	_vessel_player.play(from)
	_vessel_volume_tween = create_tween()
	_vessel_volume_tween.tween_property(_vessel_player, "volume_db", _vessel_target_volume, fade_time)

## Called when the heart goes down, once its own theme has finished leaving. The
## walk out of the arena is scored by the vessel's opening on a loop.
func prepare_vessel_road() -> void:
	# Remember the post-heart music handoff immediately, before the death fade
	# finishes, so entering level 10 cannot briefly start the standard level bed.
	_vessel_road_active = true
	_vessel_resume_start = 0.0
	_vessel_resume_end = VESSEL_OPENING_END

func start_vessel_opening(fade_time := 3.0) -> void:
	if not _on_the_road_to_the_snail():
		return
	_vessel_road_active = true
	_play_vessel_segment(0.0, VESSEL_OPENING_END, fade_time)

## Called once the snail has finished talking: skip past the conversation and
## loop what follows, which is what plays under the fight.
func play_vessel_after_snail(fade_time := 3.0) -> void:
	if not _on_the_road_to_the_snail():
		return
	_vessel_road_active = true
	_play_vessel_segment(VESSEL_AFTER_SNAIL, 0.0, fade_time)

## Called the moment the snail's dialogue opens, so the box is not talking over
## the tail of the loop.
func stop_vessel(fade_time := 2.0) -> void:
	if _vessel_player == null or not is_instance_valid(_vessel_player):
		_vessel_player = null
		return
	# Cleared before the tween so the loop check stops reaching for a player that
	# is on its way out.
	_vessel_loop_start = 0.0
	_vessel_loop_end = 0.0
	_kill_vessel_volume_tween()
	var player := _vessel_player
	_vessel_player = null
	if fade_time <= 0.0:
		player.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(player.queue_free)

func start() -> void:
	# Changing level tears the boss theme down, so the level 09 track cannot
	# bleed into whatever comes next. Called from the mole's ready, so it is the
	# one point that reliably means "a different level is loading".
	stop_boss_track()
	# The vessel track is meant to cross the boundary between the heart's arena
	# and the snail's level, and only that one, so it is left running here for the
	# two scenes it belongs to and let go everywhere else.
	if not _on_the_road_to_the_snail():
		_vessel_road_active = false
		stop_vessel(0.8)
	elif _vessel_road_active and (_vessel_player == null or not is_instance_valid(_vessel_player)):
		# A scene transition can outlive the current segment's player (for example
		# if the heart's death fade ends during the level wipe). Resume the intended
		# vessel segment instead of falling back to the ordinary level bed.
		_play_vessel_segment(_vessel_resume_start, _vessel_resume_end, 2.0)
	# A scene with a track of its own is either bringing that track up or being
	# left without one, depending on where the mole has arrived.
	_update_region_track()
	if _region_player != null and is_instance_valid(_region_player):
		# The village should sound like the village, so the bed is let go rather
		# than left running underneath - the bed is reused across levels, so it
		# would otherwise be the track still playing on arrival.
		stop_bed()
		return
	# A track that has already claimed this level keeps it. The walk's track is
	# still up when the mole arrives at the snail, and the bed has to stay out from
	# under it - level 10 is a full level rather than a silent one, so this asks
	# whether something is actually playing rather than asking about the scene.
	# That distinction is what makes jumping straight to level 10 still get the
	# bed: nothing has been inherited, so the bed is the right thing to fall back
	# on.
	if _vessel_player != null and is_instance_valid(_vessel_player):
		return
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
## variant used when a level change is already wiping the screen. `then` runs once
## the track is gone, which is how the walk out of the heart's arena is handed its
## own music rather than overlapping the theme that just died.
func stop_boss_track(fade_time := 0.8, then: Callable = Callable()) -> void:
	if _boss_player == null or not is_instance_valid(_boss_player):
		_boss_player = null
		if then.is_valid():
			then.call()
		return
	# Cleared before the tween is built so a call that lands mid-fade tears the
	# old player down instead of adopting it and leaving it to play on.
	_kill_boss_volume_tween()
	var player := _boss_player
	_boss_player = null
	if fade_time <= 0.0:
		player.queue_free()
		if then.is_valid():
			then.call()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(player.queue_free)
	if then.is_valid():
		tween.tween_callback(then)

func stop() -> void:
	stop_boss_track()
	_vessel_road_active = false
	# Everything here is leaving the game for good - credits, game over, the title
	# screen - so the walk's track and the village's go with the rest of it.
	stop_vessel(0.8)
	stop_region(0.8)
	stop_bed()

## The field guide ducks whatever is playing. Every player is covered: in level
## 09 the bed is already gone, and in the village the bed never started, so
## pausing only the bed would duck nothing at all while the track carrying the
## scene played on over the popup.
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
	# The walk from the heart is the one stretch where the bed is silent and this
	# is the only thing playing, so the field guide has to be able to duck it.
	if _vessel_player and is_instance_valid(_vessel_player) and _vessel_player.playing:
		_kill_vessel_volume_tween()
		_vessel_volume_tween = create_tween()
		_vessel_volume_tween.tween_property(_vessel_player, "volume_db", SILENT_VOLUME_DB, 0.4)
		_vessel_volume_tween.tween_callback(_vessel_player.set.bind("stream_paused", true))
	# Same for a scene carrying its own track - the village has no bed to duck.
	if _region_player and is_instance_valid(_region_player) and _region_player.playing:
		_kill_region_volume_tween()
		_region_volume_tween = create_tween()
		_region_volume_tween.tween_property(_region_player, "volume_db", SILENT_VOLUME_DB, 0.4)
		_region_volume_tween.tween_callback(_region_player.set.bind("stream_paused", true))

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
	if _vessel_player and is_instance_valid(_vessel_player):
		_kill_vessel_volume_tween()
		_vessel_player.stream_paused = false
		_vessel_volume_tween = create_tween()
		_vessel_volume_tween.tween_property(_vessel_player, "volume_db", _vessel_target_volume, 0.4)
	if _region_player and is_instance_valid(_region_player):
		_kill_region_volume_tween()
		_region_player.stream_paused = false
		_region_volume_tween = create_tween()
		_region_volume_tween.tween_property(_region_player, "volume_db", _region_target_volume, 0.4)

func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing
