extends Node

## The quest log.
##
## A quest is not handed out by a quest giver: it is revealed by reaching the
## place it is about, and it is completed by a piece of progress the save already
## records. So this only tracks which quests have been found, reads the completion
## flag back, and offers a one-time reward. Unlocked, completed and claimed state
## all live in Progress, in the same save file, so a quest cannot be found in one
## save and collected against another.

## Fired when a reward is claimed, so the open menu can refresh itself.
signal quests_changed

## Fired the moment a quest is discovered, carrying its id. The notification
## layer listens for this; retroactive unlocks on load are silent so a returning
## player is not greeted by a wall of banners.
signal quest_unlocked(quest_id: String)

## Fired the moment a quest is finished, carrying its id. The notification layer
## shows a celebratory banner so completing a quest reads as a reward.
signal quest_completed(quest_id: String)

const QUESTS: Array[Dictionary] = [
	{
		"id": "kill_corruption",
		"title": "Kill the Corruption",
		"description": "The Corrupted Heart festers at the bottom of the Corrupted Core. Descend into the darkest depths and destroy it.",
		"reward_coins": 300,
		"icon": "res://boss_bite.webp",
		"icon_region": Rect2(0, 0, 310, 310),
	},
	{
		"id": "save_snail",
		"title": "Save the Snail",
		"description": "A poor snail is trapped in the Arena. Hold out against every wave and clear the arena to set it free.",
		"reward_coins": 200,
		"icon": "res://sprites/snail/Idle Blinking_000.png",
	},
	{
		"id": "defeat_corrupted_snail",
		"title": "Defeat the Corrupted Snail",
		"description": "The snail that took the Corrupted Heart's power must be stopped. Finish the fight and end its curse.",
		"reward_coins": 500,
		"icon": "res://sprites/snail/Idle Blinking_000.png",
		"icon_tint": Color(0.62, 0.34, 0.85, 1),
	},
	{
		"id": "buy_from_shop",
		"title": "Go Shopping",
		"description": "Goblin Gilbert has set up his stall. Buy anything from him to prove you're a paying customer.",
		"reward_coins": 100,
		"icon": "res://sprites/shopt.png",
		"icon_region": Rect2(0, 0, 560, 560),
	},
]

## The scene that reveals each quest, for quests that open simply on arriving
## somewhere. A quest is not listed and its banner does not fire until the mole
## reaches the place the quest is about, so the log fills in as the player explores
## rather than laying out the whole game up front. Quests revealed some other way
## are not here: kill_corruption is handed over by an NPC's `unlocks_quest` (see
## npc_mole.gd), save_snail is handed over when the level 5 cutscene ends (see
## level_05_intro.gd), and buy_from_shop is handed over by Goblin Gilbert's own
## `unlocks_quest` the first time the player talks to him (see shopkeeper_npc.gd).
const UNLOCK_SCENES := {
	"defeat_corrupted_snail": ["res://scenes/level_10.tscn"],
}

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	Shop.purchased.connect(_on_shop_purchased)
	_unlock_already_met()

## Every quest in log order. Read-only by convention; callers should not mutate it.
func get_quests() -> Array[Dictionary]:
	return QUESTS

## Every quest the player has discovered, in log order. The log renders this
## rather than get_quests() so undiscovered quests stay off the page.
func get_unlocked_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest in QUESTS:
		if is_unlocked(quest["id"]):
			out.append(quest)
	return out

func get_quest(quest_id: String) -> Dictionary:
	for quest in QUESTS:
		if quest["id"] == quest_id:
			return quest
	return {}

## The artwork that represents a quest, with any atlas slice applied. Returns
## null when the quest has no icon or its texture is missing, so callers can just
## draw whatever comes back.
func get_quest_icon(quest_id: String) -> Texture2D:
	var quest := get_quest(quest_id)
	if quest.is_empty():
		return null
	var path := str(quest.get("icon", ""))
	if path.is_empty():
		return null
	var base := load(path) as Texture2D
	if base == null:
		return null
	if quest.has("icon_region"):
		var atlas := AtlasTexture.new()
		atlas.atlas = base
		atlas.region = quest["icon_region"]
		return atlas
	return base

## The tint a quest's icon should be drawn with (e.g. the corrupted snail),
## white when the quest defines none.
func get_quest_icon_tint(quest_id: String) -> Color:
	var quest := get_quest(quest_id)
	return quest.get("icon_tint", Color(1, 1, 1, 1))

## Whether the piece of progress a quest is keyed to has happened yet.
func is_complete(quest_id: String) -> bool:
	match quest_id:
		"kill_corruption":
			return Progress.corrupted_defeated
		"save_snail":
			return Progress.arena_completed
		"defeat_corrupted_snail":
			return Progress.is_game_completed()
		"buy_from_shop":
			return Progress.is_shop_purchased()
	return false

## Whether a quest has been discovered. Finishing a quest always counts as having
## found it, so a completed quest never shows as locked even if its reveal scene
## was somehow missed.
func is_unlocked(quest_id: String) -> bool:
	return Progress.is_quest_unlocked(quest_id) or is_complete(quest_id)

## Opens a quest and, unless silent, posts the unlock banner. Already-unlocked
## quests are a no-op so a reveal can be attempted freely on every scene load.
func unlock(quest_id: String, silent := false) -> void:
	if is_unlocked(quest_id):
		return
	Progress.mark_quest_unlocked(quest_id)
	if not silent:
		quest_unlocked.emit(quest_id)
	quests_changed.emit()

## Reveals any quest whose area the save already shows as visited (or that is
## already done). Runs once at startup and stays quiet, so a continue does not
## announce quests the player found last session.
func _unlock_already_met() -> void:
	for quest in QUESTS:
		var id: String = quest["id"]
		if is_unlocked(id):
			continue
		for scene_path in UNLOCK_SCENES.get(id, []):
			if Progress.has_visited(scene_path):
				unlock(id, true)
				break

func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_unlock_for_path(str(scene.scene_file_path))

func _unlock_for_path(path: String) -> void:
	for quest in QUESTS:
		var id: String = quest["id"]
		if is_unlocked(id):
			continue
		if path in UNLOCK_SCENES.get(id, []):
			unlock(id, false)

func unlocked_count() -> int:
	return get_unlocked_quests().size()

## Whether the reward for a quest has already been collected.
func is_rewarded(quest_id: String) -> bool:
	return Progress.is_quest_claimed(quest_id)

## True only when the quest is done and its reward is still there to take.
func can_claim(quest_id: String) -> bool:
	return is_complete(quest_id) and not is_rewarded(quest_id)

func completed_count() -> int:
	var count := 0
	for quest in QUESTS:
		if is_complete(quest["id"]):
			count += 1
	return count

func total_count() -> int:
	return QUESTS.size()

## Hands over a finished quest's reward. Returns false when there is nothing to
## take, so the menu can lean on this as both the check and the action.
func claim(quest_id: String) -> bool:
	if not can_claim(quest_id):
		return false
	var quest := get_quest(quest_id)
	if quest.is_empty():
		return false
	var coins := int(quest.get("reward_coins", 0))
	if coins > 0:
		Shop.add_coins(coins)
	Progress.mark_quest_claimed(quest_id)
	quests_changed.emit()
	return true

## A purchase landed, so the shopping quest is done. Records the flag and posts
## the completion banner the first time; every later purchase is a quiet no-op.
func _on_shop_purchased() -> void:
	Progress.mark_shop_purchased()
	announce_completion_if_new("buy_from_shop")

## Announces a quest's completion if it became finished just now. Call this
## once in the place that first sets the completion flag. It unlocks silently if
## needed and posts the completion banner only once.
func announce_completion_if_new(quest_id: String) -> void:
	if quest_id.is_empty():
		return
	if not is_complete(quest_id):
		return
	if Progress.has_completed_banner_shown(quest_id):
		return
	# Ensure it is unlocked so it appears in the log.
	if not is_unlocked(quest_id):
		unlock(quest_id, true)
	Progress.mark_completed_banner_shown(quest_id)
	quest_completed.emit(quest_id)
	quests_changed.emit()
