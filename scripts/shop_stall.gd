extends Node2D

## Market stall drawn around the merchant mole so the shopkeeper reads as a
## shopkeeper rather than another villager. Everything is procedural, matching
## the way shop_gate.gd draws its signposts.
##
## Sized in the NPC's local space - the shopkeeper scene is placed at the same
## 0.25 scale the village NPCs use, so these numbers are 4x their on-screen size.

const AWNING_TOP := -470.0
const AWNING_BOTTOM := -340.0
const COUNTER_TOP := 60.0
const COUNTER_BOTTOM := 200.0
const HALF_WIDTH := 400.0
const POST_HALF := 24.0
const COIN_Y := -40.0
const COIN_RADIUS := 55.0
const STRIPES := 8
const OUTLINE := 8.0

const COL_WOOD := Color(0.45, 0.29, 0.15, 1)
const COL_WOOD_DARK := Color(0.26, 0.16, 0.08, 1)
const COL_WOOD_LIGHT := Color(0.62, 0.42, 0.22, 1)
const COL_OUTLINE := Color(0.15, 0.09, 0.04, 1)
const COL_AWNING := Color(0.78, 0.25, 0.22, 1)
const COL_AWNING_ALT := Color(0.95, 0.86, 0.68, 1)
const COL_GOLD := Color(1.0, 0.82, 0.25, 1)

func _ready() -> void:
	light_mask = 2
	queue_redraw()

func _stripe_width() -> float:
	return (HALF_WIDTH * 2.0) / float(STRIPES)

func _stripe_color(index: int) -> Color:
	return COL_AWNING if index % 2 == 0 else COL_AWNING_ALT

func _draw() -> void:
	_draw_posts()
	_draw_awning()
	_draw_counter()

func _draw_posts() -> void:
	var height := COUNTER_BOTTOM - AWNING_TOP
	for side in [-1.0, 1.0]:
		var cx: float = side * (HALF_WIDTH - POST_HALF)
		var post := Rect2(cx - POST_HALF, AWNING_TOP, POST_HALF * 2.0, height)
		draw_rect(post, COL_WOOD)
		draw_rect(post, COL_OUTLINE, false, OUTLINE)

func _draw_awning() -> void:
	var sw := _stripe_width()
	var band := Rect2(-HALF_WIDTH, AWNING_TOP, HALF_WIDTH * 2.0, AWNING_BOTTOM - AWNING_TOP)
	for i in STRIPES:
		draw_rect(Rect2(-HALF_WIDTH + sw * i, AWNING_TOP, sw, band.size.y), _stripe_color(i))
		# Scalloped hem, one triangle per stripe, so the awning reads as cloth
		# rather than a flat signboard.
		var cx := -HALF_WIDTH + sw * (float(i) + 0.5)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - sw * 0.5, AWNING_BOTTOM),
			Vector2(cx + sw * 0.5, AWNING_BOTTOM),
			Vector2(cx, AWNING_BOTTOM + sw * 0.55),
		]), _stripe_color(i))
	# Ridge pole the awning is tied to.
	draw_rect(Rect2(-HALF_WIDTH - 18.0, AWNING_TOP - 44.0, HALF_WIDTH * 2.0 + 36.0, 52.0), COL_WOOD_DARK)
	draw_rect(band, COL_OUTLINE, false, OUTLINE)

func _draw_counter() -> void:
	var width := HALF_WIDTH * 2.0
	# Slab the goods are laid out on, jutting slightly past the posts.
	var slab := Rect2(-HALF_WIDTH - 30.0, COUNTER_TOP - 48.0, width + 60.0, 58.0)
	draw_rect(slab, COL_WOOD_LIGHT)
	draw_rect(slab, COL_OUTLINE, false, OUTLINE)

	var face := Rect2(-HALF_WIDTH, COUNTER_TOP + 10.0, width, COUNTER_BOTTOM - COUNTER_TOP - 10.0)
	draw_rect(face, COL_WOOD)
	for i in range(1, 4):
		var x := -HALF_WIDTH + width * (float(i) / 4.0)
		draw_line(Vector2(x, face.position.y + 16.0), Vector2(x, face.end.y - 12.0), COL_WOOD_DARK, 6.0)
	draw_rect(face, COL_OUTLINE, false, OUTLINE)

	# A coin on the counter top - the universal "buy things here" sign.
	var coin := Vector2(0.0, COIN_Y)
	draw_circle(coin, COIN_RADIUS, COL_GOLD)
	draw_circle(coin, COIN_RADIUS, COL_OUTLINE, false, OUTLINE)
	draw_arc(coin, COIN_RADIUS * 0.55, 0.0, TAU, 24, COL_OUTLINE, 8.0)
