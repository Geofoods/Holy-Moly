extends CanvasLayer

signal coins_changed(amount: int)
signal loadout_changed

const SAVE_PATH := "user://holy_moley_shop.cfg"
const FONT_PATH := "res://Baby Doll.otf"
const HUD_SHOW_TIME := 1.8

var coins := 0

var catalog: Array[WeaponData] = []
var owned: Array[String] = []
var equipped_melee_id := "shovel"
var equipped_ranged_id := ""

var _coin_label: Label = null
var _coin_icon: Control = null
var _coin_hud: Control = null
var _hide_timer: Timer = null
var _panel: CanvasLayer = null

func _ready() -> void:
	layer = 85
	_build_catalog()
	_load_data()
	_grant_all_weapons_for_testing() # TODO: remove before release
	_setup_coin_hud()
	_loadout_refresh()

func _process(_delta: float) -> void:
	if _coin_hud == null:
		return
	var scene := get_tree().current_scene
	var in_menu := scene != null and scene.scene_file_path.ends_with("intro.tscn")
	if in_menu:
		_coin_hud.visible = false

func _grant_all_weapons_for_testing() -> void:
	for w in catalog:
		_owned_append(w.id)
		if w.weapon_type == WeaponData.Type.MELEE:
			equipped_melee_id = w.id
		elif w.weapon_type == WeaponData.Type.RANGED and equipped_ranged_id == "":
			equipped_ranged_id = w.id

func _build_catalog() -> void:
	catalog = [
		_make_melee("shovel", "Shovel", "The trusty starting tool.", 0, 5.0, 10.0, 2.4, 0.3, Color(0.9, 0.8, 0.55)),
		_make_melee("iron_shovel", "Iron Shovel", "A heavier swing that bites harder.", 60, 14.0, 20.0, 2.4, 0.24, Color(0.7, 0.75, 0.85)),
		_make_melee("gold_shovel", "Golden Shovel", "Wide arc, quick swing, big damage.", 160, 22.0, 30.0, 2.8, 0.2, Color(1.0, 0.8, 0.2)),
		_make_ranged("pistol", "Pistol", "Reliable sidearm. Semi-automatic.", 80, 10.0, 14.0, 0.45, 1500.0, Color(0.8, 0.9, 1.0)),
		_make_ranged("revolver", "Revolver", "Slow shots, devastating punch.", 220, 26.0, 36.0, 0.8, 1800.0, Color(1.0, 0.5, 0.3)),
		_make_ranged("wizard_staff", "Wizard Staff", "Arcane bolts crackle from this gnarled staff.", 140, 18.0, 26.0, 0.55, 1200.0, Color(0.7, 0.35, 1.0)),
		_make_ability("dash_ability", "Dash Impact", "Dig-dash slams enemies with knockback and damage. Airborne shift slams a damaging ground pound (also breaks blocks).", 120, Color(0.6, 0.9, 1.0)),
		_make_ability("triple_shot", "Triple Shot", "Ranged weapons fire 3 shots in a spread.", 200, Color(1.0, 0.7, 0.3)),
		_make_ability("wall_jump", "Wall Jump Grip", "Grip the tunnels like a true mole: press Jump while pressed against a wall to kick off it. Holding toward the wall slows your fall while sliding.", 150, Color(0.55, 0.85, 0.45)),
		_make_ability("grappling_hook", "Grappling Hook", "A selectable tool that fills the SECOND hotbar slot: select it, then LEFT-CLICK toward your cursor to fire a cable and reel yourself over gaps and up to high ledges. Hold to pull, release to let go.", 130, Color(0.85, 0.65, 0.3)),
	]

func _make_ability(id: String, name: String, desc: String, price: int, color: Color) -> WeaponData:
	var w := WeaponData.new()
	w.id = id
	w.display_name = name
	w.description = desc
	w.price = price
	w.weapon_type = WeaponData.Type.ABILITY
	w.icon_color = color
	return w

func _make_melee(id: String, name: String, desc: String, price: int, dmg_min: float, dmg_max: float, arc: float, dur: float, color: Color) -> WeaponData:
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

func has_dash_ability() -> bool:
	return owns("dash_ability")

func has_triple_shot() -> bool:
	return owns("triple_shot")

func has_wall_jump() -> bool:
	return owns("wall_jump")

func has_grappling_hook() -> bool:
	return owns("grappling_hook")

func can_afford(w: WeaponData) -> bool:
	return not owns(w.id) and coins >= w.price

# --- Purchasing / equipping ----------------------------------------------

func buy(w: WeaponData) -> bool:
	if w == null or w.price > coins or owns(w.id):
		return false
	coins -= w.price
	_owned_append(w.id)
	if w.weapon_type == WeaponData.Type.MELEE:
		equipped_melee_id = w.id
	elif w.weapon_type == WeaponData.Type.RANGED:
		equipped_ranged_id = w.id
	coins_changed.emit(coins)
	loadout_changed.emit()
	_save_data()
	SFX.play_ui("item_pickup", -4.0, 1.1)
	return true

func equip(id: String) -> bool:
	var w := get_weapon(id)
	if w == null or not owns(id) or w.weapon_type == WeaponData.Type.ABILITY:
		return false
	if w.weapon_type == WeaponData.Type.MELEE:
		equipped_melee_id = id
	else:
		equipped_ranged_id = id
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
		scene.add_child(coin)
		coin.global_position = world_pos + Vector2(randf_range(-30.0, 30.0), randf_range(-50.0, 0.0))

# --- Shop UI --------------------------------------------------------------

func open_shop() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var panel := preload("res://scripts/shop_ui.gd").new()
	panel.tree_exited.connect(func() -> void:
		_panel = null
	)
	scene.add_child(panel)
	_panel = panel

# --- Persistence ----------------------------------------------------------

func _owned_append(id: String) -> void:
	if id not in owned:
		owned.append(id)

func _loadout_refresh() -> void:
	if not owns(equipped_melee_id):
		equipped_melee_id = "shovel"
	if equipped_ranged_id != "" and not owns(equipped_ranged_id):
		equipped_ranged_id = ""

	_owned_append("shovel")
	equipped_melee_id = "shovel" if not owns(equipped_melee_id) else equipped_melee_id

	loadout_changed.emit()

func _save_data() -> void:
	var cfg := ConfigFile.new()
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
	coins_changed.emit(coins)

# --- HUD ------------------------------------------------------------------

func _setup_coin_hud() -> void:
	_coin_hud = HBoxContainer.new()
	_coin_hud.name = "CoinHud"
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

func _hide_coin_hud() -> void:
	if _coin_hud == null:
		return
	var tw := create_tween()
	tw.tween_property(_coin_hud, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_hide_coin_hud_finish)

func _hide_coin_hud_finish() -> void:
	if _coin_hud:
		_coin_hud.visible = false
