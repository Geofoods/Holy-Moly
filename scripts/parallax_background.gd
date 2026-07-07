extends Node2D

var layer_textures: Array[Texture2D] = [
	preload("res://1.png"),
	preload("res://2.png"),
	preload("res://3.png"),
	preload("res://4.png"),
]

var scroll_speeds: Array[float] = [0.05, 0.15, 0.4, 0.8]

var layer_sprites: Array[Array] = []

@export var parallax_scale: float = 2.0
@export var x_scroll_multiplier: float = 0.25
@export var y_scroll_multiplier: float = 0.05

func _ready() -> void:
	await get_tree().process_frame
	if get_viewport_rect().size == Vector2.ZERO:
		await get_tree().process_frame
	_build_layers()

func _build_layers() -> void:
	var vp_size: Vector2 = get_viewport_rect().size

	for i in layer_textures.size():
		var tex: Texture2D = layer_textures[i]
		if not tex:
			continue

		var tex_size: Vector2 = tex.get_size()
		var scale_factor: Vector2 = vp_size / tex_size * parallax_scale
		var scaled_w: float = tex_size.x * scale_factor.x

		var a := Sprite2D.new()
		a.texture = tex
		a.centered = false
		a.scale = scale_factor
		a.position = Vector2(0, 0)
		add_child(a)

		var b := Sprite2D.new()
		b.texture = tex
		b.centered = false
		b.scale = scale_factor
		b.position = Vector2(scaled_w, 0)
		add_child(b)

		layer_sprites.append([a, b])

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return

	var cam_x: float = camera.global_position.x
	var cam_y: float = camera.global_position.y
	var vp_size: Vector2 = get_viewport_rect().size

	for i in layer_sprites.size():
		var speed: float = scroll_speeds[i]
		var pair: Array = layer_sprites[i]
		var a: Sprite2D = pair[0]
		var b: Sprite2D = pair[1]
		var tex_size: Vector2 = a.texture.get_size()
		var zoom_scale: float = 1.0 / max(camera.zoom.x, 0.01)
		var scale_factor: Vector2 = vp_size / tex_size * parallax_scale * zoom_scale
		a.scale = scale_factor
		b.scale = scale_factor
		var scaled_w: float = tex_size.x * scale_factor.x

		var offset_x: float = -cam_x * speed * x_scroll_multiplier
		offset_x = fmod(offset_x, scaled_w)
		if offset_x > 0:
			offset_x -= scaled_w

		var offset_y: float = -cam_y * speed * y_scroll_multiplier

		a.position.x = offset_x
		b.position.x = offset_x + scaled_w
		a.position.y = offset_y
		b.position.y = offset_y
