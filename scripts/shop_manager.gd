extends CanvasLayer

signal coins_changed(amount: int)
signal loadout_changed
## Emitted once a purchase really lands (a weapon, ability or item bought for
## coins). The quest log listens for this so buying anything from the shop can
## finish the shopping quest.
signal purchased
## Emitted once an item is sold back to a merchant, carrying the item and the
## coins paid out. The quest log listens for this so selling anything can finish
## the buy-back quest.
signal sold(item: ItemData, amount: int)
## Emitted once the shop panel has closed, so a shopkeeper NPC can drop its
## "busy" state - the panel pauses the tree, so nothing can poll for this.
signal shop_closed(shop_type: String)

const SAVE_PATH := "user://holy_moley_shop.cfg"
## Bumped whenever an old save needs repairing; see _migrate_save().
const SAVE_VERSION := 1
const FONT_PATH := "res://Baby Doll.otf"
const HUD_SHOW_TIME := 1.8

var coins := 0

## While true the shop only changes in memory. The level editor holds it up for
## the duration of a playtest so a previewed weapon pickup, or coins dropped by a
## previewed enemy, cannot rewrite the player's real loadout on disk.
var suppress_save := false

var catalog: Array[WeaponData] = []
var weapon_catalog: Array[WeaponData] = []
var ability_catalog: Array[WeaponData] = []
var item_catalog: Array[ItemData] = []
var item_prices: Dictionary = {}
## The full buy-back price list, in coins, keyed by item name. A merchant pays
## half of this when the player sells (see get_sell_price). It covers the items
## the shop stocks plus everything the mole can pick up out in the world, so the
## sell tab can price loot the shop never sells.
var item_values: Dictionary = {}
var owned: Array[String] = []
var equipped_melee_id := "shovel"
var equipped_ranged_id := ""
## Which weapon the mole is holding: false = the melee tool, true = the equipped
## ranged weapon. The mole reads this for its held sprite, the HUD for the weapon
## slot, and the swap key (Q) toggles it. Kept here rather than on the mole so the
## HUD and the mole share one source of truth across scenes.
var ranged_active := false

var _coin_label: Label = null
var _coin_icon: Control = null
var _coin_hud: Control = null
var _hide_timer: Timer = null
var _panel: CanvasLayer = null

## Who is pictured (and voiced) by the currently open shop panel. The shopkeeper
## NPC fills these in when it opens its own stall; the portable shop from a Shop
## Token leaves them blank, so no face is shown. Cleared when the panel closes.
var merchant_name := ""
var merchant_portrait: Texture2D = null
var merchant_greeting := ""
var merchant_thanks := ""
## Lines for the sell tab: the pitch spoken when it is opened, and the thanks
## spoken each time a piece of loot is bought back. Same lifecycle as the lines
## above - filled by the shopkeeper NPC, cleared with the panel.
var merchant_sell_pitch := ""
var merchant_sell := ""

func _ready() -> void:
	layer = 85
	_build_catalog()
	_build_item_catalog()
	_build_item_values()
	_load_data()
	_setup_coin_hud()
	_loadout_refresh()

func _process(_delta: float) -> void:
	if _coin_hud == null:
		return
	# Cheap no-op while the HUD is hidden (its normal state); only scan the
	# scene when the HUD is visible and may need hiding on entering the menu.
	if _coin_hud.visible:
		var scene := get_tree().current_scene
		var in_menu := scene != null and str(scene.scene_file_path).ends_with("intro.tscn")
		if in_menu:
			_coin_hud.visible = false

func _build_catalog() -> void:
	catalog = [
		_make_melee("shovel", "Shovel", "The trusty starting tool.", 0, 5.0, 10.0, 2.4, 0.3, Color(0.9, 0.8, 0.55)),
		_make_melee("gold_shovel", "Golden Shovel", "Wide arc, quick swing, double damage.", 160, 10.0, 20.0, 2.8, 0.2, Color(1.0, 0.8, 0.2), true),
		_make_melee("pickaxe", "Pickaxe", "Slow, heavy swings dig a 2x2 block for double damage and send foes flying with double knockback.", 1000, 10.0, 20.0, 2.4, 0.75, Color(0.72, 0.76, 0.85), false, 2, 2.0),
		_make_ranged("wizard_staff", "Wizard Staff", "Fires magic bolts that damage enemies and break blocks from a distance.", 400, 8.0, 14.0, 0.55, 900.0, Color(0.7, 0.35, 1.0)),
	]
	weapon_catalog.clear()
	ability_catalog.clear()
	for w in catalog:
		if w.weapon_type == WeaponData.Type.ABILITY:
			ability_catalog.append(w)
		else:
			weapon_catalog.append(w)

## Items the shop sells. These are consumables/gear (the inventory ItemData
## resources) rather than weapons. Prices are tuned against the coins enemies
## drop, so the cheap staples are always reachable within a couple of levels.
func _build_item_catalog() -> void:
	# The unified general store lists the weapons first and these staples after,
	# so the pager can appear; these four are still the whole item shelf.
	var defs := [
		# Tools
		{"name": "Drill", "price": 70},
		# Explosives
		{"name": "Bomb", "price": 80},
		{"name": "Ice Bomb", "price": 95},
		# Healing
		{"name": "Holy Water", "price": 60},
	]
	for def in defs:
		var item := _find_item(def["name"])
		if item == null:
			continue
		item_catalog.append(item)
		item_prices[def["name"]] = def["price"]

func _find_item(item_name: String) -> ItemData:
	var paths := {
		"Miner's Rations": "res://resources/miners_rations.tres",
		"Potted Honeycomb": "res://resources/potted_honeycomb.tres",
		"Bomb": "res://resources/bomb.tres",
		"Ice Bomb": "res://resources/ice_bomb.tres",
		"Golden Bomb": "res://resources/golden_bomb.tres",
		"Drill": "res://resources/drill.tres",
		"Holy Water": "res://resources/holy_water.tres",
		"Mine": "res://resources/mine.tres",
		"Stink Bomb": "res://resources/stink_bomb.tres",
		"Spark Bomb": "res://resources/spark_bomb.tres",
		"Flare": "res://resources/flare.tres",
		"Coal Lump": "res://resources/coal_lump.tres",
		"Vacuum Jelly": "res://resources/vacuum_jelly.tres",
		"Bounce Mushroom": "res://resources/bounce_mushroom.tres",
		"Shiny Lure": "res://resources/shiny_lure.tres",
		"Compass Charm": "res://resources/compass_charm.tres",
		"Shop Token": "res://resources/shop_token.tres",
		"Grub Stick": "res://resources/grub_stick.tres",
		"Tunnel Gloves": "res://resources/tunnel_gloves.tres",
		"Shelled Backpack": "res://resources/shelled_backpack.tres",
		"Climbing Talons": "res://resources/climbing_talons.tres",
		"Lantern Charm": "res://resources/lantern_charm.tres",
		"Rebound Hook": "res://resources/rebound_hook.tres",
		"Wax Cache": "res://resources/wax_cache.tres",
		"Earthquake Boots": "res://resources/earthquake_boots.tres",
		"Mol-dozer Ram": "res://resources/mol_dozer_ram.tres",
	}
	var path: String = paths.get(item_name, "")
	if path == "":
		return null
	return load(path) as ItemData

## The merchant's buy-back price list. `item_prices` (the shop's stocking) wins
## where present, so those four items always sell for exactly half his shelf
## price; everything else gets a flat price tuned against what the loot is worth
## in a level. Items left out (the starting shovel, the story-granted grappling
## hook) are not sellable at all and read as value 0.
func _build_item_values() -> void:
	item_values = {
		"Miner's Rations": 20,
		"Potted Honeycomb": 40,
		"Golden Bomb": 130,
		"Mine": 65,
		"Stink Bomb": 75,
		"Spark Bomb": 90,
		"Flare": 35,
		"Coal Lump": 25,
		"Vacuum Jelly": 45,
		"Bounce Mushroom": 45,
		"Shiny Lure": 50,
		"Compass Charm": 55,
		"Shop Token": 120,
		"Grub Stick": 30,
		"Tunnel Gloves": 60,
		"Shelled Backpack": 60,
		"Climbing Talons": 60,
		"Lantern Charm": 60,
		"Rebound Hook": 60,
		"Wax Cache": 70,
		"Earthquake Boots": 65,
		"Mol-dozer Ram": 70,
	}

func _make_ability(id: String, name: String, desc: String, price: int, color: Color) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = name
	w.description = desc
	w.price = price
	w.weapon_type = WeaponData.Type.ABILITY
	w.icon_color = color
	return w

func _make_melee(id: String, name: String, desc: String, price: int, dmg_min: float, dmg_max: float, arc: float, dur: float, color: Color, polished := false, dig_size := 1, knockback := 1.0) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = name
	w.description = desc
	w.price = price
	w.weapon_type = WeaponData.Type.MELEE
	w.min_damage = dmg_min
	w.max_damage = dmg_max
	w.swing_arc = arc
	w.swing_duration = dur
	w.icon_color = color
	w.polished = polished
	w.dig_size = dig_size
	w.knockback_multiplier = knockback
	return w

func _make_ranged(id: String, name: String, desc: String, price: int, dmg_min: float, dmg_max: float, cooldown: float, speed: float, color: Color) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = name
	w.description = desc
	w.price = price
	w.weapon_type = WeaponData.Type.RANGED
	w.min_damage = dmg_min
	w.max_damage = dmg_max
	w.cooldown = cooldown
	w.projectile_speed = speed
	w.icon_color = color
	return w

# --- Lookup ---------------------------------------------------------------

func get_weapon(id: String) -> WeaponData:
	for w in catalog:
		if w.id == id:
			return w
	return null

func owns(id: String) -> bool:
	return id in owned

func get_melee() -> WeaponData:
	return get_weapon(equipped_melee_id)

func get_ranged() -> WeaponData:
	if equipped_ranged_id == "":
		return null
	return get_weapon(equipped_ranged_id)

func has_ranged_weapon() -> bool:
	return equipped_ranged_id != "" and owns(equipped_ranged_id)

## True when this weapon is the one currently held in the shared weapon slot:
## the ranged weapon while it is out, otherwise the melee tool.
func is_active_weapon(id: String) -> bool:
	if ranged_active:
		return id == equipped_ranged_id
	return id == equipped_melee_id

func has_dash_ability() -> bool:
	return owns("dash_ability")

func has_triple_shot() -> bool:
	return owns("triple_shot")

func has_wall_jump() -> bool:
	return owns("wall_jump")

func has_grappling_hook() -> bool:
	return owns("grappling_hook")

# --- Story unlocks ---------------------------------------------------------

## Grants an ability directly (no coin cost, no catalog requirement). Used for
## story unlocks such as the snail's "Grippy Hands" wall jump.
func give(id: String) -> void:
	if owns(id):
		return
	_owned_append(id)
	loadout_changed.emit()
	_save_data()
	SFX.play_ui("item_pickup", -4.0, 1.1)

# --- Purchasing / equipping ----------------------------------------------

func buy(w: WeaponData) -> bool:
	if w == null or w.price > coins or owns(w.id):
		return false
	coins -= w.price
	_owned_append(w.id)
	if w.weapon_type == WeaponData.Type.MELEE:
		equipped_melee_id = w.id
		ranged_active = false
	elif w.weapon_type == WeaponData.Type.RANGED:
		equipped_ranged_id = w.id
		# Buying a ranged weapon brings it straight out, so the purchase is
		# visible in the HUD's weapon slot instead of silently tucked away.
		ranged_active = true
	coins_changed.emit(coins)
	loadout_changed.emit()
	_save_data()
	SFX.play_ui("item_pickup", -4.0, 1.1)
	purchased.emit()
	return true

func buy_item(item: ItemData) -> bool:
	if item == null:
		return false
	var price: int = item_prices.get(item.item_name, 0)
	if price <= 0 or coins < price:
		return false
	if not Inventory.add_item(item):
		return false
	coins -= price
	coins_changed.emit(coins)
	_save_data()
	SFX.play_ui("item_pickup", -4.0, 1.2)
	purchased.emit()
	return true

## What a merchant would ask for this item, used as the basis of the sell price.
## The shop's own stock prices take priority, then the wider buy-back list.
## Returns 0 for anything a merchant will not trade in.
func get_item_value(item: ItemData) -> int:
	if item == null:
		return 0
	if item_prices.has(item.item_name):
		return int(item_prices[item.item_name])
	return int(item_values.get(item.item_name, 0))

## What a merchant pays for one unit: half of get_item_value(), rounded down and
## never below one coin. Returns 0 for untradeable items so callers can disable
## their sell button.
func get_sell_price(item: ItemData) -> int:
	var value := get_item_value(item)
	if value <= 0:
		return 0
	return maxi(1, value / 2)

## Sells one unit out of an inventory slot and pays the seller half its value.
## Returns false when the slot is empty or the item cannot be traded, so a
## disabled button and a dead click behave the same way.
func sell_inventory_slot(slot: int) -> bool:
	if slot < 0 or slot >= Inventory.MAX_SLOTS:
		return false
	var item: ItemData = Inventory.slots[slot]
	if item == null:
		return false
	var price := get_sell_price(item)
	if price <= 0:
		return false
	Inventory.remove_one(slot)
	coins += price
	coins_changed.emit(coins)
	_save_data()
	SFX.play_ui("coin", -6.0, 1.1)
	sold.emit(item, price)
	return true

func equip(id: String) -> bool:
	var w := get_weapon(id)
	if w == null or not owns(id) or w.weapon_type == WeaponData.Type.ABILITY:
		return false
	if w.weapon_type == WeaponData.Type.MELEE:
		equipped_melee_id = id
		ranged_active = false
	else:
		equipped_ranged_id = id
		ranged_active = true
	loadout_changed.emit()
	_save_data()
	SFX.play_ui("ui_click", -12.0, 1.2)
	return true

# --- Coins ----------------------------------------------------------------

func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	coins_changed.emit(coins)
	_poke_coin_hud()
	_save_data()

func drop_coins(world_pos: Vector2, count: int, value_per_coin: int = 1) -> void:
	if count <= 0 or value_per_coin <= 0:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var coin_scene := preload("res://scenes/coin.tscn")
	for i in count:
		var coin = coin_scene.instantiate()
		coin.value = value_per_coin
		coin.global_position = world_pos + Vector2(randf_range(-30.0, 30.0), randf_range(-50.0, 0.0))
		scene.call_deferred("add_child", coin)

# --- Shop UI --------------------------------------------------------------

## The stock a shop panel shows. "all" is the unified merchant's shelf: every
## weapon and ability the shop sells, then the consumable items.
func get_shop_list(shop_type: String) -> Array:
	match shop_type:
		"abilities":
			return ability_catalog
		"items":
			return item_catalog
		"all":
			var list: Array = []
			list.append_array(_for_sale(weapon_catalog))
			list.append_array(ability_catalog)
			list.append_array(item_catalog)
			return list
		_:
			return _for_sale(weapon_catalog)

## The weapons a merchant is willing to stock. The golden shovel is held back: it
## is a reward from the Arena snail (see The Arena.tscn), not shelf stock, so it is
## filtered out here even though it stays in `weapon_catalog` for the loadout
## picker (inventory_ui.gd) and in `catalog` for get_weapon() lookups.
func _for_sale(weapons: Array) -> Array:
	var out: Array = []
	for w in weapons:
		if w.id == "gold_shovel":
			continue
		out.append(w)
	return out

func is_shop_open(shop_type: String = "") -> bool:
	if _panel == null or not is_instance_valid(_panel):
		return false
	return shop_type.is_empty() or String(_panel.get("shop_type")) == shop_type

## Opens a shop panel. "all" is the single merchant's full stock (weapons,
## abilities and items) and is the default; the narrower types remain for
## anything that wants a single-category panel.
##
## `merchant` optionally describes who is running the stall, so the panel can
## picture them in its top-left corner and thank the player as they buy. Keys:
## "name", "portrait", "greeting", "thanks", "sell_pitch" and "sell"; anything
## missing just stays blank (the panel falls back to its own defaults).
func open_shop(shop_type: String = "all", merchant: Dictionary = {}) -> void:
	if shop_type not in ["all", "weapons", "abilities", "items"]:
		shop_type = "all"
	if _panel != null and is_instance_valid(_panel):
		if String(_panel.get("shop_type")) == shop_type:
			return
		_panel.queue_free()
	var scene := get_tree().current_scene
	if scene == null:
		return
	merchant_name = str(merchant.get("name", ""))
	merchant_portrait = merchant.get("portrait", null) as Texture2D
	merchant_greeting = str(merchant.get("greeting", ""))
	merchant_thanks = str(merchant.get("thanks", ""))
	merchant_sell_pitch = str(merchant.get("sell_pitch", ""))
	merchant_sell = str(merchant.get("sell", ""))
	var panel: CanvasLayer = preload("res://scripts/shop_ui.gd").new()
	panel.set("shop_type", shop_type)
	panel.tree_exited.connect(func() -> void:
		if _panel != panel:
			return
		_panel = null
		_clear_merchant()
		shop_closed.emit(shop_type)
	)
	scene.add_child(panel)
	_panel = panel

## Wipes the pictured merchant once their panel is gone, so a later Shop Token
## panel does not inherit Gilbert's face and lines.
func _clear_merchant() -> void:
	merchant_name = ""
	merchant_portrait = null
	merchant_greeting = ""
	merchant_thanks = ""
	merchant_sell_pitch = ""
	merchant_sell = ""

# --- Persistence ----------------------------------------------------------

func _owned_append(id: String) -> void:
	if id not in owned:
		owned.append(id)

func _loadout_refresh() -> void:
	if not owns(equipped_melee_id):
		equipped_melee_id = "shovel"
	if equipped_ranged_id != "" and not owns(equipped_ranged_id):
		equipped_ranged_id = ""
	if not has_ranged_weapon():
		ranged_active = false

	# Base moveset, granted on every boot like the shovel so existing saves pick
	# it up too. The wall jump is not an unlock any more - it is part of how the
	# mole moves from the first level, so nothing has to buy or earn it.
	for id in ["shovel", "wall_jump"]:
		_owned_append(id)
	equipped_melee_id = "shovel" if not owns(equipped_melee_id) else equipped_melee_id

	loadout_changed.emit()

## Clears persisted currency and purchases while preserving the starter shovel.
func clear_save_data() -> void:
	coins = 0
	owned.clear()
	equipped_melee_id = "shovel"
	equipped_ranged_id = ""
	ranged_active = false
	_loadout_refresh()
	coins_changed.emit(coins)
	_save_data()

func _save_data() -> void:
	# The level editor raises this for the duration of a playtest: previewing a
	# level must not hand the player permanent unlocks or bank the coins a
	# previewed enemy dropped.
	if suppress_save:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "version", SAVE_VERSION)
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "equipped_melee", equipped_melee_id)
	cfg.set_value("shop", "equipped_ranged", equipped_ranged_id)
	cfg.set_value("shop", "owned", ",".join(owned))
	cfg.save(SAVE_PATH)

func _load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = maxi(int(cfg.get_value("shop", "coins", 0)), 0)
	equipped_melee_id = str(cfg.get_value("shop", "equipped_melee", "shovel"))
	equipped_ranged_id = str(cfg.get_value("shop", "equipped_ranged", ""))
	var owned_str := str(cfg.get_value("shop", "owned", ""))
	if owned_str != "":
		for id in owned_str.split(","):
			_owned_append(id)
	var version := int(cfg.get_value("shop", "version", 0))
	if version < SAVE_VERSION:
		_migrate_save(version)
	coins_changed.emit(coins)

## Repairs saves written by older builds, then stamps them with SAVE_VERSION so
## each fix runs once.
##
## Version 1 drops the golden shovel. It used to be handed to every player by a
## debug grant, which was then written into the save the first time a coin was
## picked up - so the mole started every run already holding it. It is earned
## from the snail now, and must not be sitting in `owned` before that.
func _migrate_save(from_version: int) -> void:
	if from_version < 1:
		owned.erase("gold_shovel")
		if equipped_melee_id == "gold_shovel":
			equipped_melee_id = "shovel"
	_save_data()

# --- HUD ------------------------------------------------------------------

func _setup_coin_hud() -> void:
	_coin_hud = HBoxContainer.new()
	_coin_hud.name = "CoinHud"
	_coin_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_hud.anchor_left = 0.0
	_coin_hud.anchor_top = 0.0
	_coin_hud.offset_left = 16.0
	_coin_hud.offset_top = 12.0
	_coin_hud.offset_right = 300.0
	_coin_hud.offset_bottom = 60.0
	_coin_hud.add_theme_constant_override("separation", 8)

	_coin_icon = Control.new()
	_coin_icon.name = "CoinHudIcon"
	_coin_icon.custom_minimum_size = Vector2(24, 26)
	_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_icon.set_script(preload("res://scripts/coin_hud_icon.gd"))
	_coin_hud.add_child(_coin_icon)

	_coin_label = Label.new()
	_coin_label.name = "CoinHudLabel"
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var font := load(FONT_PATH) as Font
	if font:
		_coin_label.add_theme_font_override("font", font)
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_coin_label.add_theme_constant_override("outline_size", 5)
	_coin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_coin_hud.add_child(_coin_label)

	add_child(_coin_hud)
	_coin_hud.visible = false

	_hide_timer = Timer.new()
	_hide_timer.name = "CoinHudHideTimer"
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_hide_coin_hud)
	add_child(_hide_timer)

	_update_coin_label(coins)
	coins_changed.connect(_update_coin_label)

func _update_coin_label(amount: int) -> void:
	if _coin_label:
		_coin_label.text = str(amount)

func _poke_coin_hud() -> void:
	if _coin_hud == null or _hide_timer == null:
		return
	_coin_hud.visible = true
	if _coin_hud.modulate.a < 1.0:
		var tw := create_tween()
		tw.tween_property(_coin_hud, "modulate:a", 1.0, 0.12)
	_hide_timer.start(HUD_SHOW_TIME)

## Brings the coin counter on screen at full opacity right away and holds it,
## for reward animations that play while the tree is paused: both the fade-in
## tween above and the auto-hide timer stand still under a pause, so the quest
## log cannot use _poke_coin_hud. Returns the counter's centre in screen space so
## a caller can aim a flying-coin animation at it, or Vector2.ZERO when there is
## no counter to aim at.
func reveal_coin_hud() -> Vector2:
	if _coin_hud == null:
		return Vector2.ZERO
	_coin_hud.visible = true
	_coin_hud.modulate.a = 1.0
	if _hide_timer != null:
		# Restarted rather than left running: under the pause it does not tick, so
		# once the menu closes the counter lingers for the usual window and then
		# fades itself out on its own.
		_hide_timer.start(HUD_SHOW_TIME)
	return _coin_hud.get_global_rect().get_center()

func _hide_coin_hud() -> void:
	if _coin_hud == null:
		return
	var tw := create_tween()
	tw.tween_property(_coin_hud, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_hide_coin_hud_finish)

func _hide_coin_hud_finish() -> void:
	if _coin_hud:
		_coin_hud.visible = false
