extends CanvasLayer
## 移动端虚拟摇杆 + 触控按钮系统

signal interact_pressed
signal inventory_pressed
signal sprint_pressed(sprint_on: bool)

var joystick_x: float = 0.0
var is_sprinting: bool = false

# 内部节点
var _joystick_bg = null
var _joystick_knob = null
var _touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 70.0
var _knob_radius: float = 30.0

# 按钮
var _interact_btn = null
var _inventory_btn = null
var _sprint_btn = null

# 是否启用
var _enabled: bool = false


func _ready() -> void:
	name = "MobileControls"
	layer = 50
	_detect_platform()
	if not _enabled:
		return
	_build_joystick()
	_build_buttons()


func _detect_platform() -> void:
	var hint = OS.has_touchscreen_ui_hint()
	var screen_small = get_viewport().get_visible_rect().size.x < 900
	var is_web = OS.get_name() == "Web"
	_enabled = hint or screen_small or is_web or _has_mobile_user_agent()
	if _enabled:
		visible = true


func _has_mobile_user_agent() -> bool:
	var ua = OS.get_name()
	return ua in ["Android", "iOS"]


func _build_joystick() -> void:
	# 摇杆底座
	_joystick_bg = Control.new()
	_joystick_bg.name = "JoystickBG"
	_joystick_bg.custom_minimum_size = Vector2(_joystick_radius * 2 + 10, _joystick_radius * 2 + 10)
	_joystick_bg.position = Vector2(40, get_viewport().get_visible_rect().size.y - 180)
	_joystick_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_joystick_bg)

	# 底座视觉（半透明圆）
	var bg_visual = ColorRect.new()
	bg_visual.name = "BgVisual"
	bg_visual.size = Vector2(_joystick_radius * 2, _joystick_radius * 2)
	bg_visual.position = Vector2(_knob_radius, _knob_radius)
	bg_visual.color = Color(1, 1, 1, 0.15)
	_joystick_bg.add_child(bg_visual)
	_apply_circle_style(bg_visual, Color(1, 1, 1, 0.12), _joystick_radius)

	# 摇杆手柄
	_joystick_knob = Control.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.custom_minimum_size = Vector2(_knob_radius * 2, _knob_radius * 2)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_bg.add_child(_joystick_knob)

	var knob_visual = ColorRect.new()
	knob_visual.size = Vector2(_knob_radius * 2 - 4, _knob_radius * 2 - 4)
	knob_visual.position = Vector2(2, 2)
	knob_visual.color = Color(1, 1, 1, 0.35)
	_apply_circle_style(knob_visual, Color(1, 1, 1, 0.32), _knob_radius - 2)
	_joystick_knob.add_child(knob_visual)


func _apply_circle_style(rect: ColorRect, col: Color, radius: float) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = col
	style.set_corner_radius_all(int(radius))
	style.set_border_width_all(1)
	var border_a = min(col.a * 1.5, 0.5)
	style.border_color = Color(col.r, col.g, col.b, border_a)
	rect.add_theme_stylebox_override("panel", style)


func _build_buttons() -> void:
	var vp_size = get_viewport().get_visible_rect().size
	var btn_size = Vector2(70, 70)
	var margin_right = 30.0
	var bottom_y = vp_size.y - 100.0
	var spacing = 80.0

	# 交互按钮
	_interact_btn = _make_touch_button("交互", Color(0.25, 0.55, 0.3, 0.7), btn_size)
	_interact_btn.position = Vector2(vp_size.x - margin_right - btn_size.x, bottom_y)
	add_child(_interact_btn)
	_interact_btn.pressed.connect(func(): interact_pressed.emit())

	# 背包按钮
	_inventory_btn = _make_touch_button("背包", Color(0.35, 0.35, 0.55, 0.7), btn_size)
	_inventory_btn.position = Vector2(vp_size.x - margin_right - btn_size.x - spacing, bottom_y)
	add_child(_inventory_btn)
	_inventory_btn.pressed.connect(func(): inventory_pressed.emit())

	# 冲刺按钮
	_sprint_btn = _make_touch_button("冲刺", Color(0.6, 0.45, 0.15, 0.65), btn_size)
	_sprint_btn.position = Vector2(vp_size.x - margin_right - btn_size.x - spacing * 2, bottom_y)
	add_child(_sprint_btn)
	_sprint_btn.button_down.connect(func(): _on_sprint(true))
	_sprint_btn.button_up.connect(func(): _on_sprint(false))


func _make_touch_button(text_str: String, bg_col: Color, size: Vector2) -> Button:
	var btn = Button.new()
	btn.text = text_str
	btn.custom_minimum_size = size
	btn.size = size
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

	var style = StyleBoxFlat.new()
	style.bg_color = bg_col
	style.set_corner_radius_all(int(size.x / 2))
	style.set_border_width_all(1)
	style.border_color = Color(bg_col.r + 0.15, bg_col.g + 0.15, bg_col.b + 0.15, 0.5)
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = bg_col.lightened(0.15)
	hover_style.set_corner_radius_all(int(size.x / 2))
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(bg_col.r + 0.15, bg_col.g + 0.15, bg_col.b + 0.15, 0.5)
	btn.add_theme_stylebox_override("pressed", hover_style)

	return btn


# ========== 输入处理 ==========

func _input(event: InputEvent) -> void:
	if not _enabled:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var local_pos = _joystick_bg.to_local(event.position)
		var bg_half = _joystick_bg.size / 2.0
		if abs(local_pos.x - bg_half.x) < _joystick_radius + 40 and abs(local_pos.y - bg_half.y) < _joystick_radius + 40:
			_touch_index = event.index
			_joystick_center = event.position
	else:
		if event.index == _touch_index:
			_touch_index = -1
			joystick_x = 0.0
			_reset_knob_position()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return

	var delta = event.position - _joystick_center
	var dist = clampf(delta.length(), 0.0, _joystick_radius)
	if _joystick_radius > 0:
		joystick_x = delta.x / _joystick_radius
	else:
		joystick_x = 0.0

	# 死区
	if abs(joystick_x) < 0.12:
		joystick_x = 0.0

	# 更新手柄位置
	var knob_offset = Vector2(delta.normalized().x * dist, delta.normalized().y * dist)
	_joystick_knob.position = _joystick_bg.size / 2.0 + knob_offset - Vector2(_knob_radius, _knob_radius)


func _reset_knob_position() -> void:
	_joystick_knob.position = (_joystick_bg.size / 2.0) - Vector2(_knob_radius, _knob_radius)


func _on_sprint(on: bool) -> void:
	is_sprinting = on
	sprint_pressed.emit(on)


func _process(_delta: float) -> void:
	if _enabled and not visible:
		visible = true
	elif not _enabled and visible:
		visible = false


## 外部接口：获取移动方向
func get_move_axis() -> float:
	return joystick_x


## 手动切换显隐
func set_enabled(val: bool) -> void:
	_enabled = val
	visible = val
