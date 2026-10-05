extends Node

var _player: AudioStreamPlayer = null
var _stream := preload("res://nojisuma-grotto-120967.mp3")
var _target_volume := -18.0

## Whichever tween is currently moving the bed's volume, for the same reason the
## boss theme tracks its own. The bed was the one player whose fades were left
## untracked, so a duck or a fade-out landing mid-move had no way to take it
## over and the two would fight over the same property.
var _bed_volume_tween: Tween = null

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

## The track the run's middle stretch shares. Named once because four scenes want
## it and a track this long should be retargetable in one edit rather than four.
const SHIMMER_TRACK := "res://Shimmer - Sinjin Hawke - FRACTAL FANTASY (128k).mp3"

## The track levels 07 and 08 share. Named for the same reason as the one above.
const MINES_TRACK := "res://Stardew Valley OST - Mines (The Lava Dwellers) - Lewie G (128k).mp3"

## Scenes that carry a track of their own instead of the level bed. Keyed by
## scene path, so a scene is named once here wherever it gets loaded from.
##
## Levels 04 to 06 are one continuous stretch on one track rather than three
## separate ones, and 07 to 08 are another, which is also why
## region_track_survives() lets a track across the boundaries inside a stretch
## instead of restarting the song at each one. Crossing between stretches is a
## different track, so there the old one is faded out and the new one brought up.
const REGION_TRACKS := {
	"res://scenes/molevillage.tscn": "res://Stardew Valley OST - Pelican Town.mp3",
	"res://scenes/level_04.tscn": SHIMMER_TRACK,
	"res://scenes/level_05.tscn": SHIMMER_TRACK,
	"res://scenes/level_06.tscn": SHIMMER_TRACK,
	"res://scenes/Slime Valley.tscn": SHIMMER_TRACK,
	"res://scenes/level_07.tscn": MINES_TRACK,
	"res://scenes/level_08.tscn": MINES_TRACK,
}

## Scenes the mole only passes through on the way somewhere else, where a scene's
## own track keeps playing instead of being torn down and started over later.
## The map is the one that matters: it has no track of its own and no mole to
## restart anything, so dropping the music there meant every jump through it
## reset the song no matter which level was waiting on the other side.
const REGION_PASSTHROUGH := ["res://scenes/map.tscn"]

## How long a scene's own track crossfades into its next pass. The track is a
## little over two minutes, so it has to come round again to cover a level, and
## letting `finished` call play() dropped it straight back to its first bar at
## full volume - which reads as the song restarting rather than as it looping.
## Overlapping the two passes instead makes the join inaudible.
const REGION_LOOP_XFADE := 2.5

## Whether the scene's own track should be carried across a scene change to
## `next_scene` rather than faded out on the way. True when both sides want the
## same track, or when `next_scene` is only a stop on the way to one that does.
## Without this a run of consecutive levels sharing one song would restart it
## from the top at every boundary, which on a track this long means hearing its
## opening over and over instead of once.
##
func scene_path_of(scene_ref: String) -> String:
	if not scene_ref.begins_with("uid://"):
		return scene_ref
	var id := ResourceUID.text_to_id(scene_ref)
	if id == ResourceUID.INVALID_ID:
		return scene_ref
	var path := ResourceUID.get_id_path(id)
	return scene_ref if path.is_empty() else path

## Arrival still has the last word: _update_region_track() hands the track over
## when the next scene wants it and lets it go when the next scene does not, so
## passing through here cannot leave the music stranded somewhere it does not
## belong.
##
## The incoming scene is named however the level happened to be wired, and a level
## saved by the editor points at the next one by uid:// rather than by path. Both
## forms load fine, but only a path matches the tables above - and a uid matching
## nothing reads as "these two scenes do not share a track", which tears the music
## down and starts it over on arrival. So the two forms have to be made to agree
## before the comparison, or every level joined through a uid restarts its music.
func region_track_survives(next_scene: String) -> bool:
	if _region_path.is_empty():
		return false
	var dest := scene_path_of(next_scene)
	if dest in REGION_PASSTHROUGH:
		return true
	return str(REGION_TRACKS.get(dest, "")) == _region_path

## A scene's own track: up while the mole is in it, gone once they step out.
## Kept apart from the bed so arriving somewhere that wants the bed back does not
## first have to unwind this one.
var _region_player: AudioStreamPlayer = null
var _region_path := ""
var _region_volume_tween: Tween = null
var _region_target_volume := -14.0

## The pass of the track fading in over the one currently playing, live only for
## the length of a crossfade. Two players exist at once at the loop point, so this
## is where the incoming one waits before it is promoted. See _advance_region_loop().
var _region_next_player: AudioStreamPlayer = null

## The arena's fight theme. It starts once the snail in "The Arena" has said its
## line and gives up when the waves are cleared, so it cannot be a region track -
## those belong to a whole scene, and this one only exists for the middle of one.
var _arena_player: AudioStreamPlayer = null
var _arena_stream := preload("res://Hollow Knight OST - Nosk [youaretube.com].mp3")
var _arena_target_volume := -16.0
var _arena_volume_tween: Tween = null

func _kill_bed_volume_tween() -> void:
	if _bed_volume_tween != null and _bed_volume_tween.is_valid():
		_bed_volume_tween.kill()
	_bed_volume_tween = null

## Cancels the theme's in-flight volume move, if any, so the caller can start
## its own without the two overlapping.
func _kill_boss_volume_tween() -> void:
	if _boss_volume_tween != null and _boss_volume_tween.is_valid():
		_boss_volume_tween.kill()
	_boss_volume_tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	_advance_region_loop()
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

## Keeps a scene's own track looping seamlessly. Polled rather than left to
## `finished`, which only reports that a pass is already over - far too late to
## start the next one underneath it.
##
## Two things happen here, both driven off the playhead so that neither depends
## on a tween surviving: a crossfade is begun shortly before the pass runs out,
## and once the incoming pass has been playing long enough to have taken over, it
## is promoted to be the track. The promotion is deliberately not a tween
## callback, because a dialogue opening mid-crossfade kills the region's volume
## tween and would take the swap down with it, stranding the music on the pass
## that had already faded out.
func _advance_region_loop() -> void:
	if _region_player == null or not is_instance_valid(_region_player):
		return
	if _region_next_player != null and is_instance_valid(_region_next_player):
		if _region_next_player.get_playback_position() >= REGION_LOOP_XFADE:
			_promote_region_next()
		return
	if not _region_player.playing or _region_player.stream_paused:
		return
	var stream := _region_player.stream as AudioStreamMP3
	if stream == null:
		return
	if stream.get_length() - _region_player.get_playback_position() > REGION_LOOP_XFADE:
		return
	_begin_region_loop()

## Brings the next pass in under the last REGION_LOOP_XFADE seconds of this one.
func _begin_region_loop() -> void:
	var outgoing := _region_player
	var incoming := AudioStreamPlayer.new()
	incoming.stream = outgoing.stream
	incoming.process_mode = Node.PROCESS_MODE_ALWAYS
	incoming.volume_db = SILENT_VOLUME_DB
	add_child(incoming)
	incoming.play()
	incoming.finished.connect(_on_region_track_finished)
	# The outgoing pass is about to run out, so its own loop handler has to go or
	# it would start over underneath the pass fading in.
	if outgoing.finished.is_connected(_on_region_track_finished):
		outgoing.finished.disconnect(_on_region_track_finished)
	_region_next_player = incoming
	_kill_region_volume_tween()
	# Both fades share the region's one tween slot, so a dialogue opening across
	# the loop point takes the pair down together with the rest of the music
	# rather than fighting them for the same property.
	_region_volume_tween = create_tween()
	_region_volume_tween.set_parallel(true)
	_region_volume_tween.tween_property(incoming, "volume_db", _region_target_volume, REGION_LOOP_XFADE)
	_region_volume_tween.tween_property(outgoing, "volume_db", SILENT_VOLUME_DB, REGION_LOOP_XFADE)

## Hands the region slot to the pass that has just faded in and lets the pass that
## faded out go.
func _promote_region_next() -> void:
	var outgoing := _region_player
	var incoming := _region_next_player
	_region_next_player = null
	if incoming == null or not is_instance_valid(incoming):
		return
	_region_player = incoming
	if is_instance_valid(outgoing):
		outgoing.queue_free()

## Last resort for a pass that runs out without the crossfade having caught it -
## a track whose length the poll cannot read, or one the poll lost track of. Starts
## the next pass from the top rather than leaving a gap, fading back up to where
## the track normally sits.
func _on_region_track_finished() -> void:
	if _region_player == null or not is_instance_valid(_region_player):
		return
	_kill_region_volume_tween()
	_region_player.play()
	_region_volume_tween = _fade_to_target(_region_player, _region_target_volume, REGION_LOOP_XFADE)

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

func _kill_arena_volume_tween() -> void:
	if _arena_volume_tween != null and _arena_volume_tween.is_valid():
		_arena_volume_tween.kill()
	_arena_volume_tween = null

## Brings the scene's own track in line with wherever the mole has just arrived:
## started for a scene that has one, let go for a scene that does not. This is the
## fade-out on leaving, because arriving anywhere else is what stepping out looks
## like from here - whether the mole walked out through an exit or fast travelled.
func _update_region_track() -> void:
	var scene := get_tree().current_scene
	var scene_path := "" if scene == null else str(scene.scene_file_path)
	# The map is a pass-through rather than a place the mole has arrived, and it
	# carries a mole of its own, so start() runs there like any other arrival.
	# Left to fall through to the empty case below it would read the map as a
	# scene with no track and tear the music down on the way past - which is what
	# restarted the song on every level, since the map's doors are how the next
	# level is picked. Returning leaves the track exactly where it was so the
	# level on the other side of the map picks it back up mid-song.
	if scene_path in REGION_PASSTHROUGH:
		return
	var wanted := str(REGION_TRACKS.get(scene_path, ""))
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
	# Looped by crossfading the next pass in under this one rather than by
	# restarting off `finished`, so the join is inaudible - see
	# _advance_region_loop(). `finished` stays connected as a backstop.
	_region_player.finished.connect(_on_region_track_finished)
	_region_player.play()
	_region_volume_tween = create_tween()
	_region_volume_tween.tween_property(_region_player, "volume_db", _region_target_volume, 2.0)

## Fades a scene's own track out and lets it go, so it cannot follow the mole out
## of the scene it belongs to. 0 tears it down at once.
func stop_region(fade_time := 0.8) -> void:
	if _region_volume_tween != null and _region_volume_tween.is_valid():
		_region_volume_tween.kill()
	_region_volume_tween = null
	# A crossfade in flight means two players: the pass fading out and the one
	# fading in. Both have to go, or the incoming pass keeps playing over whatever
	# the mole walked into. The tween that was driving them is already dead by
	# here, so freeing them cannot trip it.
	if _region_next_player != null and is_instance_valid(_region_next_player):
		_region_next_player.queue_free()
	_region_next_player = null
	if _region_player == null or not is_instance_valid(_region_player):
		_region_player = null
		_region_path = ""
		return
	var player := _region_player
	_region_player = null
	_region_path = ""
	if fade_time <= 0.0:
		player.queue_free()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(player.queue_free)

## Brings the arena theme up from silence as the fight is about to begin. The
## fade starts while the tree is still paused for the snail's dialogue, which is
## why the player is PROCESS_MODE_ALWAYS and the fade is short enough that the
## track is still arriving as the pan back to the arena finishes.
##
## The level bed is cut rather than ducked underneath it, and handed back by
## stop_arena_track(). Ducking would mean holding its volume somewhere between
## two numbers and hoping the field guide's own duck in the middle of a fight
## untangles cleanly; cutting keeps exactly one thing playing, and the bed is
## cheap to put back because nothing here has to survive a scene change.
func play_arena_track(fade_time := 2.5) -> void:
	if _arena_player != null and is_instance_valid(_arena_player):
		return
	_kill_arena_volume_tween()
	stop_bed()
	_arena_player = AudioStreamPlayer.new()
	_arena_player.stream = _arena_stream
	_arena_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_arena_player.volume_db = SILENT_VOLUME_DB
	add_child(_arena_player)
	# The theme is shorter than the waves it scores, so it loops rather than
	# falling silent partway through the fight.
	_arena_player.finished.connect(_arena_player.play)
	_arena_player.play()
	_arena_volume_tween = create_tween()
	_arena_volume_tween.tween_property(_arena_player, "volume_db", _arena_target_volume, fade_time)

## Fades the arena theme out once the waves are cleared and, unless told
## otherwise, gives the level bed back to the scene - which is left with no music
## of its own otherwise. The default fade is timed to cover the camera's hold on
## the shattering wall, so the theme recedes under the payoff instead of being cut
## off by it.
##
## `restore_bed` is off for the level-change path, where start() is about to make
## that decision itself and two callers doing it would race.
func stop_arena_track(fade_time := 3.0, restore_bed := true) -> void:
	if _arena_player == null or not is_instance_valid(_arena_player):
		_arena_player = null
		return
	# Cleared before the tween is built, so a call landing mid-fade tears the old
	# player down rather than adopting it and leaving it to play on.
	_kill_arena_volume_tween()
	var player := _arena_player
	_arena_player = null
	if fade_time <= 0.0:
		player.queue_free()
		if restore_bed:
			_start_bed()
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	tween.tween_callback(player.queue_free)
	if restore_bed:
		tween.tween_callback(_start_bed)

## Fades the level bed out and lets it go. The bed is deliberately carried from
## level to level as the mole walks, so this is only for arriving somewhere that
## wants other music instead, or for leaving the game.
func stop_bed(fade_time := 1.0) -> void:
	if not _player or not is_instance_valid(_player):
		return
	# The bed is the one track a dialogue is most likely to have faded down a
	# moment earlier - the arena borrows its slot the instant the snail's box
	# closes - so the duck's fade has to be cancelled here or the bed would swell
	# back up for a frame before this one takes it down again.
	_kill_bed_volume_tween()
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
	# Same reasoning for the arena theme, which normally retires with the waves.
	# This only bites if the mole walks out of the arena mid-fight. Instant, so the
	# cut lands under the scene wipe that got us here - and the bed this borrows
	# comes back with the next scene's own start().
	stop_arena_track(0.0, false)
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
	_start_bed()

## Brings the level bed up on a player of its own. Split out of start() because
## the arena theme borrows the bed's slot for the length of a fight and has to
## hand it straight back, without re-running the level-change bookkeeping that
## start() does on the way in.
func _start_bed() -> void:
	if _player != null and is_instance_valid(_player):
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
	# screen - so the walk's track and the village's go with the rest of it. The
	# arena theme goes too: dying mid-fight drops straight into game over, and it
	# must not come back with the bed when the mole retries.
	stop_vessel(0.8)
	stop_region(0.8)
	stop_arena_track(0.8, false)
	stop_bed()

## Fades one player down to silence and hands back the tween, so the caller can
## park it in that player's own slot and kill it if something else wants the
## volume before this finishes.
func _fade_to_silent(player: AudioStreamPlayer, fade_time: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_VOLUME_DB, fade_time)
	return tween

## The same in the other direction, back to wherever that track normally sits.
func _fade_to_target(player: AudioStreamPlayer, target: float, fade_time: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target, fade_time)
	return tween

## The field guide ducks whatever is playing. Every player is covered: in level
## 09 the bed is already gone, and in the village the bed never started, so
## pausing only the bed would duck nothing at all while the track carrying the
## scene played on over the popup.
func pause() -> void:
	if _player and is_instance_valid(_player) and _player.playing:
		_kill_bed_volume_tween()
		_bed_volume_tween = _fade_to_silent(_player, 0.4)
		_bed_volume_tween.tween_callback(_player.set.bind("stream_paused", true))
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
	# The arena theme holds the scene alone once the bed has been cut for it, so it
	# is the only thing the field guide could duck while the waves are running.
	if _arena_player and is_instance_valid(_arena_player) and _arena_player.playing:
		_kill_arena_volume_tween()
		_arena_volume_tween = create_tween()
		_arena_volume_tween.tween_property(_arena_player, "volume_db", SILENT_VOLUME_DB, 0.4)
		_arena_volume_tween.tween_callback(_arena_player.set.bind("stream_paused", true))

func resume() -> void:
	if _player and is_instance_valid(_player):
		_player.stream_paused = false
		_kill_bed_volume_tween()
		_bed_volume_tween = _fade_to_target(_player, _target_volume, 0.4)
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
	if _arena_player and is_instance_valid(_arena_player):
		_kill_arena_volume_tween()
		_arena_player.stream_paused = false
		_arena_volume_tween = create_tween()
		_arena_volume_tween.tween_property(_arena_player, "volume_db", _arena_target_volume, 0.4)

func is_playing() -> bool:
	return _player != null and is_instance_valid(_player) and _player.playing
