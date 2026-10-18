extends Area2D

## A weapon lying in a level, waiting to be found. Weapons normally reach the
## player by being bought from the merchant or handed over by an NPC, so this is
## the level editor's way of putting one in the world: the mole walks into it and
## the weapon joins its loadout, already in hand.

const BOB_SPEED := 4.0
const BOB_HEIGHT := 6.0
const CHIP_SIZE := 48

## A WeaponData id, e.g. "gold_shovel". Set by the level editor.
@export var weapon_id := ""

var _bob_time := 0.0
var _bob_anchor := 0.0
var _bob_anchored := false
var _taken := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var weapon: WeaponData = Shop.get_weapon(weapon_id)
	if weapon == null:
		return
	sprite.texture = _chip(weapon.icon_color)
	sprite.scale = Vector2.ONE
	var initials := _initials(weapon.display_name)
	if initials != "":
		_add_initials(initials)

## The bob's centre is taken on the first frame, once the level editor has placed
## us, so a pickup hovers where it was put rather than around y = 0.
func _physics_process(delta: float) -> void:
	if not _bob_anchored:
		_bob_anchored = true
		_bob_anchor = global_position.y
	_bob_time += delta
	global_position.y = _bob_anchor + sin(_bob_time * BOB_SPEED) * BOB_HEIGHT


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("mole"):
		return
	# Already in the loadout, so leave the pickup lying there for a player who
	# has not bought it yet.
	if Shop.owns(weapon_id):
		return
	_taken = true
	Shop.give(weapon_id)
	Shop.equip(weapon_id)
	queue_free()


## Weapons carry no artwork of their own, only a tint, so the pickup is a chip of
## its colour stamped with the weapon's initials -- the same fallback that items
## without artwork use in the world.
func _chip(color: Color) -> Texture2D:
	var image := Image.create(CHIP_SIZE, CHIP_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	for i in CHIP_SIZE:
		for j in 3:
			image.set_pixel(i, j, Color(1, 1, 1, 0.35))
			image.set_pixel(i, CHIP_SIZE - 1 - j, Color(0, 0, 0, 0.35))
			image.set_pixel(j, i, Color(1, 1, 1, 0.35))
			image.set_pixel(CHIP_SIZE - 1 - j, i, Color(1, 1, 1, 0.35))
	return ImageTexture.create_from_image(image)


func _initials(display_name: String) -> String:
	var letters := ""
	for word in display_name.split(" ", false):
		letters += word.substr(0, 1)
	return letters.to_upper()


func _add_initials(initials: String) -> void:
	var label := Label.new()
	label.text = initials
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-CHIP_SIZE, -CHIP_SIZE) * 0.5
	label.size = Vector2(CHIP_SIZE, CHIP_SIZE)
	label.z_index = 3
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
