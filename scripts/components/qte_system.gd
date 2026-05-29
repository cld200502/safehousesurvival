extends CanvasLayer

# ========== QTE 轮盘系统 / 旋转指针确认 ==========

signal qte_result(result_type, accuracy)

@export var rotation_speed = 220.0
@export var zone_angle = 45.0
@export var perfect_zone_angle = 15.0

var is_active = false
var current_angle = 0.0
var zone_center = 0.0
var zone_start = 0.0
var result_emitted = false

@onready var qte_panel = $QTEPanel
@onready var qte_bg = $QTEPanel/Bg
@onready var needle = $QTEPanel/Needle
@onready var result_label = $QTEPanel/ResultLabel
@onready var hint_label = $QTEPanel/HintLabel

# 移动端触屏按钮
var _touch_btn: Button = null


func _ready():
	if is_instance_valid(qte_panel):
		qte_panel.visible = false
	set_process(false)
	_draw_qte_bg()
	_build_touch_button()


func _draw_qte_bg():
	var size = 300
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = size / 2

	# 
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x - center, y - center).length()
			if dist < 135 and dist > 120:
				img.set_pixel(x, y, Color(0.3, 0.25, 0.2, 0.9))
			elif dist < 140 and dist >= 135:
				img.set_pixel(x, y, Color(0.5, 0.4, 0.3))
			elif dist < 122:
				img.set_pixel(x, y, Color(0.1, 0.08, 0.06, 0.85))

	# 
	for i in range(36):
		var ang = i * 10.0 * PI / 180.0
		for r in range(120, 138):
			var px = int(center + cos(ang) * r)
			var py = int(center + sin(ang) * r)
			if px >= 0 and px < size and py >= 0 and py < size:
				img.set_pixel(px, py, Color(0.6, 0.55, 0.45))

	# 
	for x in range(center - 6, center + 6):
		for y in range(center - 6, center + 6):
			if Vector2(x - center, y - center).length() <= 6:
				img.set_pixel(x, y, Color(0.4, 0.35, 0.3))

	qte_bg.texture = ImageTexture.create_from_image(img)

	# 
	if is_instance_valid(needle):
		var needle_img = Image.create(130, 6, false, Image.FORMAT_RGBA8)
		needle_img.fill(Color(0, 0, 0, 0))
		for px in range(120):
			var w = 2.0 * (1.0 - px / 120.0) + 1.0
			for py in range(int(-w), int(w) + 1):
				var y = 3 + py
				if y >= 0 and y < 6:
					needle_img.set_pixel(px, y, Color(1, 0.25, 0.15))
		needle.texture = ImageTexture.create_from_image(needle_img)
		needle.pivot_offset = Vector2(5, 3)


func start_qte(difficulty = "normal"):
	match difficulty:
		"easy":
			rotation_speed = 157.5
			zone_angle = 60.0
			perfect_zone_angle = 25.0
		"normal":
			rotation_speed = 231.0
			zone_angle = 45.0
			perfect_zone_angle = 15.0
		"hard":
			rotation_speed = 315.0
			zone_angle = 30.0
			perfect_zone_angle = 10.0
		"extreme":
			rotation_speed = 420.0
			zone_angle = 18.0
			perfect_zone_angle = 5.0

	current_angle = randf() * 360.0
	zone_center = randf() * 360.0
	zone_start = fmod(zone_center - zone_angle / 2.0 + 360.0, 360.0)
	is_active = true
	result_emitted = false
	if is_instance_valid(qte_panel):
		qte_panel.visible = true
	if is_instance_valid(hint_label):
		if OS.has_touchscreen_ui_hint():
			hint_label.text = "在指针进入绿色区域时点击下方按钮确认"
		else:
			hint_label.text = "在指针进入绿色区域时按下 [空格键] 确认"
	if is_instance_valid(result_label):
		result_label.text = ""
	set_process(true)
	# 显示移动端触控按钮
	_show_touch_button(true)


func _process(delta):
	if not is_active:
		return

	current_angle = fmod(current_angle + rotation_speed * delta, 360.0)
	if is_instance_valid(needle):
		needle.rotation_degrees = current_angle

	if Input.is_key_pressed(KEY_SPACE):
		_check_result()

	# 移动端：点击屏幕任意位置或触控按钮
	if Input.is_action_just_pressed("ui_accept") or (OS.has_touchscreen_ui_hint() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_check_result()


func _check_result():
	if not is_active or result_emitted:
		return

	is_active = false
	set_process(false)

	var diff = abs(fmod(current_angle - zone_center + 180.0, 360.0) - 180.0)
	var accuracy = clamp((zone_angle / 2.0 - diff) / (zone_angle / 2.0), 0.0, 1.0)

	var result_type
	if diff <= perfect_zone_angle / 2.0:
		result_type = "perfect"
		if is_instance_valid(result_label):
			result_label.text = "完美！"
			result_label.add_theme_color_override("font_color", Color.GREEN)
	elif diff <= zone_angle / 2.0:
		result_type = "good"
		if is_instance_valid(result_label):
			result_label.text = "不错！"
			result_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		result_type = "miss"
		if is_instance_valid(result_label):
			result_label.text = "未命中..."
			result_label.add_theme_color_override("font_color", Color.RED)

	result_emitted = true
	qte_result.emit(result_type, accuracy)

	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(qte_panel):
		qte_panel.visible = false
	_show_touch_button(false)


func stop_qte():
	is_active = false
	set_process(false)
	if is_instance_valid(qte_panel):
		qte_panel.visible = false
	_show_touch_button(false)
	result_emitted = true


# ========== 移动端触控按钮 ==========

func _build_touch_button() -> void:
	"""构建QTE专用的大按钮"""
	_touch_btn = Button.new()
	_touch_btn.name = "QTETouchBtn"
	_touch_btn.text = "确认"
	_touch_btn.custom_minimum_size = Vector2(200, 80)
	_touch_btn.add_theme_font_size_override("font_size", 32)
	_touch_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.25, 0.85)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.9, 0.45, 0.7)
	_touch_btn.add_theme_stylebox_override("normal", style)
	var pressed_s := style.duplicate()
	pressed_s.bg_color = Color(0.15, 0.75, 0.2, 0.95)
	_touch_btn.add_theme_stylebox_override("pressed", pressed_s)
	_touch_btn.pressed.connect(_check_result)
	_touch_btn.visible = false
	add_child(_touch_btn)


func _show_touch_button(show: bool) -> void:
	if not is_instance_valid(_touch_btn):
		return
	_touch_btn.visible = show and OS.has_touchscreen_ui_hint()
	if show:
		var vp_size := get_viewport().get_visible_rect().size
		_touch_btn.position = Vector2((vp_size.x - 200) / 2, vp_size.y * 0.72)
