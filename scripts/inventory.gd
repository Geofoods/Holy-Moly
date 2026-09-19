extends Node

signal slots_changed(slot_indices: Array)
signal selected_slot_changed(slot: int)

const MAX_SLOTS := 4
const MAX_HEALTH := 12.0

var slots: Array = [null, null, null, null]
var slot_counts: Array = [0, 0, 0, 0]

var current_level_path: String = "res://scenes/level1.tscn"

## Player health is persistent across level transitions, so the mole carries
## damage (and healed hearts) from one level into the next.
var player_health: float = MAX_HEALTH

## Remembers where the mole left each level so re-entering that level restores
## the same position instead of the scene's default spawn point.
var level_return_positions: Dictionary = {}

func set_level_return_position(path: String, pos: Vector2) -> void:
	if not path.is_empty():
		level_return_positions[path] = pos

func get_level_return_position(path: String) -> Variant:
	return level_return_positions.get(path, null)

var selected_slot: int = -1:
	set(value):
		selected_slot = value
		selected_slot_changed.emit(value)
		SFX.play_ui("ui_click", -12.0, 1.5)

## Chance (0..1) that any consumable is refunded back into the inventory when
## used. Used by the Wax Cache item; 0 by default.
var refund_chance := 0.0

var _initialized := false

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	var shovel := preload("res://resources/shovel.tres")
	add_item(shovel)

func reset() -> void:
	clear()
	level_return_positions.clear()
	player_health = MAX_HEALTH
	_initialized = false

func add_item(item: ItemData) -> bool:
	if item.stackable:
		for i in MAX_SLOTS:
			if slots[i] != null and slots[i].item_name == item.item_name:
				slot_counts[i] += 1
				slots_changed.emit([i])
				SFX.play_ui("item_pickup")
				return true
	for i in MAX_SLOTS:
		if slots[i] == null:
			slots[i] = item
			slot_counts[i] = 1
			slots_changed.emit([i])
			SFX.play_ui("item_pickup")
			return true
	return false

func add_n_items(item: ItemData, count: int) -> void:
	for _j in count:
		add_item(item)

func add_item_at(item: ItemData, idx: int) -> bool:
	if idx < 0 or idx >= MAX_SLOTS:
		return false
	if slots[idx] != null and item.stackable and slots[idx].item_name == item.item_name:
		slot_counts[idx] += 1
		slots_changed.emit([idx])
		SFX.play_ui("item_pickup")
		return true
	for i in range(MAX_SLOTS - 1, idx, -1):
		slots[i] = slots[i - 1]
		slot_counts[i] = slot_counts[i - 1]
	slots[idx] = item
	slot_counts[idx] = 1
	slots_changed.emit([idx])
	SFX.play_ui("item_pickup")
	return true

func remove_item(slot: int) -> void:
	if slot >= 0 and slot < MAX_SLOTS:
		slots[slot] = null
		slot_counts[slot] = 0
		slots_changed.emit([slot])

func use_item(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return false
	var item: ItemData = slots[slot]
	if not item.consumable:
		return false
	slot_counts[slot] -= 1
	if slot_counts[slot] <= 0:
		remove_item(slot)
	else:
		slots_changed.emit([slot])
	if refund_chance > 0.0 and item.stackable and randf() < refund_chance:
		add_item(item)
	return true

func clear() -> void:
	for i in MAX_SLOTS:
		slots[i] = null
		slot_counts[i] = 0
	slots_changed.emit(range(MAX_SLOTS))

func has_empty_slot() -> bool:
	for i in MAX_SLOTS:
		if slots[i] == null:
			return true
	return false
