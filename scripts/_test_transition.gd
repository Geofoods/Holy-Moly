extends Node

## Temporary harness for the circle-wipe pause change. Deleted after the check.
##
## Drives a real SceneTransition to a real target scene and asserts the four
## things that matter:
##   1. the transition still completes (a frozen tween would soft-lock the game)
##   2. the tree is actually held paused for the whole wipe
##   3. the outgoing scene genuinely stops ticking while paused
##   4. the tree is handed back running, so the new scene ticks

const TARGET := "res://scenes/_test_target.tscn"
const FRAME_LIMIT := 2000

## The wipe is 0.8s in + 0.8s out, so a correct hold is dozens of frames. This
## floor only exists to catch "paused for a single frame", not to pin timing.
const MIN_PAUSED_FRAMES := 10

class Ticker extends Node:
	var ticks := 0
	func _process(_delta: float) -> void:
		ticks += 1

class Observer extends Node:
	var target: String = ""
	var ticker: Ticker = null
	var fails: Array[String] = []
	var paused_frames := 0
	var ticks_first_paused := -1
	var ticks_last_paused := -1
	var finished := false
	var watched_frames := 0

	func _ready() -> void:
		name = "TransitionObserver"
		# Must keep running to watch the tree it is about to freeze.
		process_mode = Node.PROCESS_MODE_ALWAYS
		_begin.call_deferred()

	func _begin() -> void:
		var tree := get_tree()
		await tree.process_frame

		# A plain pausable node in the outgoing scene, to detect if it keeps moving.
		ticker = Ticker.new()
		ticker.name = "Ticker"
		tree.current_scene.add_child(ticker)
		await tree.process_frame

		var transition := load("res://scenes/scene_transition.tscn").instantiate()
		tree.root.add_child(transition)
		transition.call("change_to", target)

		while finished == false:
			watched_frames += 1
			if watched_frames > FRAME_LIMIT:
				_check(false, "transition never finished - the wipe tween is frozen by the pause")
				_report()
				tree.quit(1)
				return
			await tree.process_frame

	## Sample every frame. Boundary-safe freeze detection: compare the ticker on
	## the first paused frame against the last paused frame, so a tick that lands
	## on the same frame the pause began or ended can't produce a false failure.
	func _process(_delta: float) -> void:
		if get_tree().paused == false:
			return
		paused_frames += 1
		if ticks_first_paused < 0:
			ticks_first_paused = ticker.ticks
		ticks_last_paused = ticker.ticks

	## Called by the target scene, which can only reach here while running.
	func report() -> void:
		_check(get_tree().paused == false, "tree is running when the new scene ticks")
		_report()
		finished = true
		get_tree().quit(0 if fails.is_empty() else 1)

	func _check(passed: bool, label: String) -> void:
		if passed:
			print("  PASS  %s" % label)
		else:
			fails.append(label)
			print("  FAIL  %s" % label)

	func _fail(label: String) -> void:
		_check(false, label)

	func _report() -> void:
		_check(paused_frames >= MIN_PAUSED_FRAMES,
			"tree held paused for the wipe (%d frames)" % paused_frames)
		_check(ticks_first_paused == ticks_last_paused,
			"outgoing scene frozen while paused (%d -> %d ticks)" % [ticks_first_paused, ticks_last_paused])
		var now := get_tree().current_scene
		_check(now != null and now.scene_file_path == target, "new scene became the current scene")
		print("")
		if fails.is_empty():
			print("scene transition pause: all checks passed")
		else:
			print("scene transition pause: %d FAILED" % fails.size())

func _ready() -> void:
	var observer := Observer.new()
	observer.target = TARGET
	get_tree().root.add_child(observer)
