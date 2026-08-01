extends Camera3D

## 演示用航点循环飞行相机；点击屏幕暂停/继续。

@export var cruise_speed: float = 900.0
@export var look_smooth: float = 3.5
@export var bank_amount_deg: float = 10.0

## World-space waypoints. Empty = use built-in island/cloud corridor.
@export var waypoints: Array[Vector3] = []

var _paused: bool = false
var _segment: int = 0
var _t: float = 0.0
var _fps_label: Label
var _hint_label: Label
var _path: Array[Vector3] = []


func _ready() -> void:
	current = true
	_path = waypoints.duplicate()
	if _path.is_empty():
		_path = [
			Vector3(0, 7800, 9000),
			Vector3(-1500, 7200, 4500),
			Vector3(1800, 7000, 500),
			Vector3(-900, 7400, -2500),
			Vector3(1400, 7100, -5500),
			Vector3(-700, 7600, -9000),
			Vector3(1100, 7300, -12500),
			Vector3(-400, 7500, -16000),
			Vector3(200, 7800, -19000),
		]
	global_position = _path[0]
	await get_tree().process_frame
	await get_tree().process_frame
	_build_hud()


func _build_hud() -> void:
	var vs := get_viewport().get_visible_rect().size
	var short_side := maxf(minf(vs.x, vs.y), 720.0)
	var font_hud := int(short_side * 0.045)
	var margin := short_side * 0.04

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_hint_label = Label.new()
	_hint_label.text = "网格体积云飞行 · 点击屏幕暂停/继续"
	_hint_label.add_theme_font_size_override("font_size", font_hud)
	_hint_label.modulate = Color(1, 1, 1, 0.9)
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.offset_left = margin
	_hint_label.offset_top = margin * 0.6
	_hint_label.offset_right = -margin
	_hint_label.offset_bottom = margin * 0.6 + font_hud * 1.6
	layer.add_child(_hint_label)

	_fps_label = Label.new()
	_fps_label.text = "FPS: --"
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", font_hud)
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_fps_label.add_theme_constant_override("shadow_offset_x", 3)
	_fps_label.add_theme_constant_override("shadow_offset_y", 3)
	_fps_label.modulate = Color(1, 1, 0.7, 1.0)
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.offset_left = -short_side * 0.35
	_fps_label.offset_top = margin * 0.6
	_fps_label.offset_right = -margin
	_fps_label.offset_bottom = margin * 0.6 + font_hud * 1.6
	layer.add_child(_fps_label)


func _toggle_pause() -> void:
	_paused = not _paused
	if _hint_label:
		_hint_label.text = ("已暂停 · 点击继续" if _paused else "网格体积云飞行 · 点击屏幕暂停/继续")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_toggle_pause()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_pause()


func _process(delta: float) -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if _paused or _path.size() < 2:
		return

	var a := _path[_segment]
	var b := _path[(_segment + 1) % _path.size()]
	var seg_len := a.distance_to(b)
	if seg_len < 0.001:
		_segment = (_segment + 1) % _path.size()
		_t = 0.0
		return

	_t += (cruise_speed * delta) / seg_len
	while _t >= 1.0:
		_t -= 1.0
		_segment = (_segment + 1) % _path.size()
		a = _path[_segment]
		b = _path[(_segment + 1) % _path.size()]
		seg_len = maxf(a.distance_to(b), 0.001)
		_t = minf(_t, 0.999)

	# Ease in/out for a smoother flight feel.
	var u := _t * _t * (3.0 - 2.0 * _t)
	var pos := a.lerp(b, u)
	global_position = pos

	var look_target := b.lerp(_path[(_segment + 2) % _path.size()], 0.35)
	var desired := Transform3D(Basis.looking_at(look_target - pos, Vector3.UP), pos)
	global_transform = global_transform.interpolate_with(desired, 1.0 - exp(-look_smooth * delta))

	var move_dir := (b - a).normalized()
	var bank := clampf(-move_dir.y * 2.5, -1.0, 1.0) * deg_to_rad(bank_amount_deg)
	rotation.z = lerpf(rotation.z, bank, 1.0 - exp(-delta * 3.0))
