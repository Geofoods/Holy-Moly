extends RefCounted
class_name CoinArt

## Shared loader for the coin artwork. The source PNG has transparent padding
## around the coin, so we also work out the opaque region once and hand that to
## callers - otherwise the coin draws much smaller than its nominal size.

const TEXTURE_PATH := "res://sprites/coin.png"

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
