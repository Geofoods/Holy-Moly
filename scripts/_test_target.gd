extends Node2D

## Temporary target for the scene transition pause harness. Deleted after the check.

var _frames := 0
var _observer: Node = null

func _ready() -> void:
	_observer = get_node_or_null("/root/TransitionObserver")
	set_process(true)

func _process(_delta: float) -> void:
	# This only runs at all if the tree is unpaused, so reaching the callback is
	# itself the proof that the transition handed the tree back.
	_frames += 1
	if _frames == 5 and _observer != null:
		_observer.call("report")
