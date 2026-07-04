extends Node

signal slots_changed(slot_indices: Array)

const MAX_SLOTS := 3

var slots: Array = [null, null, null]

func add_item(item: ItemData) -> bool:
	for i in MAX_SLOTS:
		if slots[i] == null:
			slots[i] = item
			slots_changed.emit([i])
			return true
	return false

func remove_item(slot: int) -> void:
	if slot >= 0 and slot < MAX_SLOTS:
		slots[slot] = null
		slots_changed.emit([slot])

func use_item(slot: int, player: Node) -> bool:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return false
	var item: ItemData = slots[slot]
	var used := _apply_effect(item, player)
	if used:
		remove_item(slot)
	return used

func _apply_effect(item: ItemData, player: Node) -> bool:
	if item.item_name == "Health Potion":
		if player.has_method("heal"):
			return player.heal(1)
	return false

func clear() -> void:
	for i in MAX_SLOTS:
		slots[i] = null
	slots_changed.emit(range(MAX_SLOTS))

func has_empty_slot() -> bool:
	for i in MAX_SLOTS:
		if slots[i] == null:
			return true
	return false
