extends Node

signal slots_changed(slot_indices: Array)

const MAX_SLOTS := 3

var slots: Array = [null, null, null]
var slot_counts: Array = [0, 0, 0]

var _initialized := false

func initialize() -> void:
	if _initialized:
		return
	_initialized = true
	var shovel := preload("res://resources/shovel.tres")
	var bomb := preload("res://resources/bomb.tres")
	add_item(shovel)
	add_n_items(bomb, 5)

func reset() -> void:
	clear()
	_initialized = false

func add_item(item: ItemData) -> bool:
	if item.stackable:
		for i in MAX_SLOTS:
			if slots[i] != null and slots[i].item_name == item.item_name:
				slot_counts[i] += 1
				slots_changed.emit([i])
				return true
	for i in MAX_SLOTS:
		if slots[i] == null:
			slots[i] = item
			slot_counts[i] = 1
			slots_changed.emit([i])
			return true
	return false

func add_n_items(item: ItemData, count: int) -> void:
	for _j in count:
		add_item(item)

func remove_item(slot: int) -> void:
	if slot >= 0 and slot < MAX_SLOTS:
		slots[slot] = null
		slot_counts[slot] = 0
		slots_changed.emit([slot])

func use_item(slot: int, player: Node) -> bool:
	if slot < 0 or slot >= MAX_SLOTS or slots[slot] == null:
		return false
	var item: ItemData = slots[slot]
	if not item.consumable:
		return false
	if item.item_name == "Health Potion":
		if player.has_method("heal") and not player.heal(1):
			return false
	elif item.item_name == "Speed Boots":
		if player.has_method("_activate_speed_boost"):
			player._activate_speed_boost()
	elif item.item_name == "Shield":
		if player.has_method("_activate_shield"):
			player._activate_shield()
	else:
		return false
	slot_counts[slot] -= 1
	if slot_counts[slot] <= 0:
		remove_item(slot)
	else:
		slots_changed.emit([slot])
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
