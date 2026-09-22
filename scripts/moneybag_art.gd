extends RefCounted
class_name MoneyBagArt

## Shared loader for the moneybag artwork. Mirrors CoinArt: the source PNG has
## transparent padding around the bag, so we compute the opaque region too.

const TEXTURE_PATH := "res://sprites/moneybag.png"

static var _texture: Texture2D = null
static var _region := Rect2()
static var _loaded := false

static func texture() -> Texture2D:
	_ensure_loaded()
	return _texture

## Opaque bounds of the artwork, in texture pixels. Empty if there is no art.
static func region() -> Rect2:
	_ensure_loaded()
	return _region

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not ResourceLoader.exists(TEXTURE_PATH):
		return
	var tex := load(TEXTURE_PATH) as Texture2D
	if tex == null:
		return
	_texture = tex
	_region = Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed() and img.decompress() != OK:
		return
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		_region = Rect2(used)