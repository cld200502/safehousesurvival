extends CanvasLayer
## 战斗场景 —— 回合制QTE

signal battle_finished(wins: int, total: int)

var _difficulty: String = "normal"
var _total_rounds: int = 3
var _wins: int = 0
var _criticals: int = 0   # 暴击次数
var _current_round: int = 0
var _running: bool = false

# UI
var _bg: ColorRect
var _left_portrait_frame: Panel        # 左侧立绘框
var _left_portrait_label: Label
var _right_portrait_frame: Panel       # 右侧立绘框
var _right_portrait_label: Label
var _left_name_label: Label            # 左侧名称
var _right_name_label: Label           # 右侧名称
var _text_box: Panel                   # 文字框
var _text_label: RichTextLabel         # 文字内容
var _text_name_label: Label            # 文字名字
var _qte_bar_bg: Panel                 # QTE进度条背景
var _qte_zone: Panel                   # 命中区
var _qte_perfect: Panel                # 完美区
var _qte_miss_left: Panel              # 左侧未命中区
var _qte_miss_right: Panel             # 右侧未命中区
var _qte_pointer: Panel                # 指针
var _qte_hint: Label                   # 操作提示
var _qte_result: Label                 # 结果文字
var _round_label: Label                # 回合标签
var _continue_hint: Label             # 继续提示

# QTE
var _qte_pos: float = 0.0
var _qte_dir: int = 1
var _qte_speed: float = 380.0
var _qte_zone_width: float = 55.0
var _qte_perfect_width: float = 18.0
var _qte_target_center: float = 0.0
var _qte_bar_w: float = 500.0
var _qte_bar_h: float = 40.0
var _qte_finished: bool = false


func start_battle(difficulty: String, total_rounds: int) -> void:
	_difficulty = difficulty
	_total_rounds = total_rounds
	_wins = 0
	_criticals = 0
	_current_round = 0
	_running = true
	GameManager.is_horde_qte_active = true
	_build_ui()
	_setup_qte_params()
	await _show_intro()
	if not _running or GameManager.game_over:
		return
	_begin_rounds()


func _build_ui() -> void:
	# 暗色背景
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.01, 0.03, 1.0)  # 暗紫黑色
	_bg.size = get_viewport().get_visible_rect().size
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var vsize: Vector2 = _bg.size

	# ===== 左侧立绘框 =====
	_left_portrait_frame = Panel.new()
	_left_portrait_frame.position = Vector2(80, 120)
	_left_portrait_frame.size = Vector2(240, 340)
	var lpf_style: StyleBoxFlat = StyleBoxFlat.new()
	lpf_style.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	lpf_style.border_color = Color(0.3, 0.5, 0.8, 0.7)
	lpf_style.set_border_width_all(2)
	lpf_style.set_corner_radius_all(6)
	_left_portrait_frame.add_theme_stylebox_override("panel", lpf_style)
	_bg.add_child(_left_portrait_frame)

	_left_portrait_label = Label.new()
	_left_portrait_label.position = Vector2(10, 10)
	_left_portrait_label.size = Vector2(220, 300)
	_left_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left_portrait_label.text = "[ 你 ]"
	_left_portrait_label.add_theme_font_size_override("font_size", 34)
	_left_portrait_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	_left_portrait_frame.add_child(_left_portrait_label)

	_left_name_label = Label.new()
	_left_name_label.position = Vector2(0, -28)
	_left_name_label.size = Vector2(240, 24)
	_left_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_name_label.text = "你"
	_left_name_label.add_theme_font_size_override("font_size", 25)
	_left_name_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))

	# ===== 右侧立绘框 =====
	_right_portrait_frame = Panel.new()
	_right_portrait_frame.position = Vector2(vsize.x - 320, 100)
	_right_portrait_frame.size = Vector2(260, 380)
	var rpf_style: StyleBoxFlat = StyleBoxFlat.new()
	rpf_style.bg_color = Color(0.1, 0.04, 0.04, 0.95)
	rpf_style.border_color = Color(0.8, 0.2, 0.2, 0.7)
	rpf_style.set_border_width_all(2)
	rpf_style.set_corner_radius_all(6)
	_right_portrait_frame.add_theme_stylebox_override("panel", rpf_style)
	_bg.add_child(_right_portrait_frame)

	_right_portrait_label = Label.new()
	_right_portrait_label.position = Vector2(10, 10)
	_right_portrait_label.size = Vector2(240, 340)
	_right_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_right_portrait_label.text = "[ 僵尸 ]"
	_right_portrait_label.add_theme_font_size_override("font_size", 34)
	_right_portrait_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_right_portrait_frame.add_child(_right_portrait_label)

	_right_name_label = Label.new()
	_right_name_label.position = Vector2(0, -28)
	_right_name_label.size = Vector2(260, 24)
	_right_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_name_label.text = "丧尸 Lv.%d" % GameManager.zombie_level
	_right_name_label.add_theme_font_size_override("font_size", 25)
	_right_name_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))

	# ===== 文本框 =====
	_text_box = Panel.new()
	_text_box.position = Vector2(60, vsize.y - 280)
	_text_box.size = Vector2(vsize.x - 120, 230)
	var tb_style: StyleBoxFlat = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.04, 0.03, 0.08, 0.95)
	tb_style.border_color = Color(0.5, 0.4, 0.3, 0.9)
	tb_style.set_border_width_all(2)
	tb_style.set_corner_radius_all(8)
	_text_box.add_theme_stylebox_override("panel", tb_style)
	_bg.add_child(_text_box)

	# 说话者名字
	_text_name_label = Label.new()
	_text_name_label.position = Vector2(24, 8)
	_text_name_label.size = Vector2(_text_box.size.x - 48, 28)
	_text_name_label.add_theme_font_size_override("font_size", 25)
	_text_name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_text_box.add_child(_text_name_label)

	# 对话内容
	_text_label = RichTextLabel.new()
	_text_label.position = Vector2(24, 40)
	_text_label.size = Vector2(_text_box.size.x - 48, 120)
	_text_label.bbcode_enabled = true
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.add_theme_font_size_override("bold_font_size", 20)
	_text_label.add_theme_font_size_override("italics_font_size", 20)
	_text_label.add_theme_font_size_override("mono_font_size", 20)
	_text_label.add_theme_color_override("default_color", Color(0.95, 0.93, 0.9))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_box.add_child(_text_label)

	# 继续提示
	_continue_hint = Label.new()
	_continue_hint.text = "按 [空格键] 继续"
	_continue_hint.position = Vector2(0, _text_box.size.y - 46)
	_continue_hint.size = Vector2(_text_box.size.x, 36)
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_hint.add_theme_font_size_override("font_size", 20)
	_continue_hint.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_continue_hint.visible = false
	_bg.add_child(_continue_hint)
	_continue_hint.z_index = 200

	# ===== QTE区域 =====
	var qte_y: float = vsize.y - 310
	var qte_x: float = (vsize.x - _qte_bar_w) / 2.0

	# 回合标签
	_round_label = Label.new()
	_round_label.position = Vector2(0, qte_y - 36)
	_round_label.size = Vector2(vsize.x, 28)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 28)
	_round_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_bg.add_child(_round_label)

	# QTE进度条背景
	_qte_bar_bg = Panel.new()
	var qte_bg_style: StyleBoxFlat = StyleBoxFlat.new()
	qte_bg_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	qte_bg_style.border_color = Color(0.4, 0.35, 0.3, 0.8)
	qte_bg_style.set_border_width_all(2)
	qte_bg_style.set_corner_radius_all(4)
	_qte_bar_bg.add_theme_stylebox_override("panel", qte_bg_style)
	_qte_bar_bg.position = Vector2(qte_x, qte_y)
	_qte_bar_bg.size = Vector2(_qte_bar_w, _qte_bar_h)
	_bg.add_child(_qte_bar_bg)

	# 命中区域 = 黄色
	_qte_zone = Panel.new()
	var zone_style: StyleBoxFlat = StyleBoxFlat.new()
	zone_style.bg_color = Color(0.6, 0.5, 0.1, 0.5)
	zone_style.border_color = Color(0.9, 0.75, 0.15, 0.8)
	zone_style.set_border_width_all(1)
	zone_style.set_corner_radius_all(3)
	_qte_zone.add_theme_stylebox_override("panel", zone_style)
	_qte_zone.size = Vector2(_qte_zone_width, _qte_bar_h - 4)
	_qte_zone.position = Vector2(qte_x, qte_y + 2)
	_bg.add_child(_qte_zone)

	# 完美区 = 绿色/暴击
	_qte_perfect = Panel.new()
	var perf_style: StyleBoxFlat = StyleBoxFlat.new()
	perf_style.bg_color = Color(0.15, 0.85, 0.2, 0.65)
	perf_style.border_color = Color(0.3, 1.0, 0.4, 0.95)
	perf_style.set_border_width_all(1)
	perf_style.set_corner_radius_all(2)
	_qte_perfect.add_theme_stylebox_override("panel", perf_style)
	_qte_perfect.size = Vector2(_qte_perfect_width, _qte_bar_h - 12)
	_qte_perfect.position = Vector2(qte_x, qte_y + 6)
	_bg.add_child(_qte_perfect)

	# 左侧未命中
	_qte_miss_left = Panel.new()
	var miss_style: StyleBoxFlat = StyleBoxFlat.new()
	miss_style.bg_color = Color(0.5, 0.08, 0.05, 0.5)
	miss_style.border_color = Color(0.7, 0.15, 0.1, 0.7)
	miss_style.set_border_width_all(1)
	miss_style.set_corner_radius_all(3)
	_qte_miss_left.add_theme_stylebox_override("panel", miss_style)
	_qte_miss_left.size = Vector2(20, _qte_bar_h - 4)
	_qte_miss_left.position = Vector2(qte_x, qte_y + 2)
	_bg.add_child(_qte_miss_left)

	# 右侧未命中
	_qte_miss_right = Panel.new()
	_qte_miss_right.add_theme_stylebox_override("panel", miss_style)
	_qte_miss_right.size = Vector2(20, _qte_bar_h - 4)
	_qte_miss_right.position = Vector2(qte_x + _qte_bar_w - 20, qte_y + 2)
	_bg.add_child(_qte_miss_right)

	# 移动指针
	_qte_pointer = Panel.new()
	var ptr_style: StyleBoxFlat = StyleBoxFlat.new()
	ptr_style.bg_color = Color(0.95, 0.2, 0.12, 0.95)
	ptr_style.border_color = Color(1.0, 0.5, 0.4, 0.95)
	ptr_style.set_border_width_all(1)
	ptr_style.set_corner_radius_all(2)
	_qte_pointer.add_theme_stylebox_override("panel", ptr_style)
	_qte_pointer.size = Vector2(14, _qte_bar_h - 8)
	_qte_pointer.position = Vector2(qte_x, qte_y + 4)
	_bg.add_child(_qte_pointer)

	# 操作提示文字
	_qte_hint = Label.new()
	_qte_hint.position = Vector2(0, qte_y + _qte_bar_h + 10)
	_qte_hint.size = Vector2(vsize.x, 24)
	_qte_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_hint.add_theme_font_size_override("font_size", 21)
	_qte_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_bg.add_child(_qte_hint)

	# 结果文字
	_qte_result = Label.new()
	_qte_result.position = Vector2(0, qte_y + _qte_bar_h + 36)
	_qte_result.size = Vector2(vsize.x, 32)
	_qte_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_result.add_theme_font_size_override("font_size", 27)
	_bg.add_child(_qte_result)

	# QTE初始隐藏
	_hide_qte_area()

	# 名字标签位置
	var name_y: float = vsize.y - 320
	_left_name_label.position = Vector2(80, name_y)
	_right_name_label.position = Vector2(vsize.x - 320, name_y)
	_bg.add_child(_left_name_label)
	_bg.add_child(_right_name_label)


func _hide_qte_area() -> void:
	_qte_bar_bg.visible = false
	_qte_zone.visible = false
	_qte_perfect.visible = false
	_qte_miss_left.visible = false
	_qte_miss_right.visible = false
	_qte_pointer.visible = false
	_qte_hint.visible = false
	_qte_result.visible = false
	_round_label.visible = false


func _show_qte_area() -> void:
	_qte_bar_bg.visible = true
	_qte_zone.visible = true
	_qte_perfect.visible = true
	_qte_miss_left.visible = true
	_qte_miss_right.visible = true
	_qte_pointer.visible = true
	_qte_hint.visible = true
	_qte_result.visible = true
	_round_label.visible = true


func _setup_qte_params() -> void:
	var player_dmg: int = GameManager.get_total_damage()
	var helpers: int = GameManager.get_combat_npcs()

	match _difficulty:
		"easy":
			_qte_speed = 294.0; _qte_zone_width = 80.0; _qte_perfect_width = 28.0
		"normal":
			_qte_speed = 399.0; _qte_zone_width = 55.0; _qte_perfect_width = 18.0
		"hard":
			_qte_speed = 441.0; _qte_zone_width = 42.0; _qte_perfect_width = 14.0
		_:
			_qte_speed = 399.0; _qte_zone_width = 55.0; _qte_perfect_width = 18.0

	if player_dmg > 0:
		_qte_zone_width += player_dmg * 0.5
	_qte_speed = maxf(100.0, _qte_speed - helpers * 20.0)
	_qte_zone_width = minf(120.0, _qte_zone_width + helpers * 8.0)


func _show_intro() -> void:
	# 开场对话
	_set_text("", "夜色中，丧尸的嘶吼声越来越近...")
	await _wait_click()
	if not _running: return

	_set_text("", "你必须守住这扇门。")
	await _wait_click()
	if not _running: return

	var helpers: int = GameManager.get_combat_npcs()
	if helpers > 0:
		_set_text("", "有同伴在身边，战斗会轻松一些。")
		await _wait_click()
		if not _running: return

	_set_text("", "准备战斗！")
	await _wait_click()


func _set_text(name_str: String, text: String) -> void:
	_text_name_label.text = name_str if name_str != "" else ""
	_text_label.text = "[color=#e8e0d0]" + text + "[/color]"


func _wait_click() -> void:
	_continue_hint.visible = true
	# 等待玩家点击继续
	await get_tree().process_frame
	while true:
		await get_tree().process_frame
		if not is_instance_valid(_continue_hint):
			return
		if Input.is_action_just_pressed("ui_accept"):
			break
	_continue_hint.visible = false


func _on_continue() -> void:
	pass


func _begin_rounds() -> void:
	for i in range(_total_rounds):
		if not _running or GameManager.game_over:
			break
		_current_round = i + 1
		var result: int = await _run_qte_round()
		if result >= 1:   # 命中 = 获胜
			_wins += 1
		if result == 2:   # 完美命中 = 暴击
			_criticals += 1
		# === 回合间过渡 ===
		if _current_round < _total_rounds:
			if not _running or GameManager.game_over:
				break
			await _round_pause(result)

	_end_battle()


func _round_pause(last_result: int) -> void:
	"""回合间暂停，显示过渡文字"""
	# 1. QTE区域隐藏后，先让玩家看到上一回合结果
	_hide_qte_area()
	_show_text_box_children()
	await _wait_click()
	if not _running:
		return

	# 2. 根据结果显示过渡文字
	var transitions: Dictionary = {
		2: [  # 暴击
			"完美一击！丧尸被重创！",
			"漂亮！这一击直击要害！",
			"丧尸发出痛苦的嘶吼...",
		],
		1: [  # 普通命中
			"击中了！丧尸后退了几步。",
			"有效攻击！继续压制...",
			"打中了！不要给它喘息的机会！",
		],
		0: [  # 未命中
			"[color=#ff6644]没打中！丧尸趁机逼近...[/color]",
			"攻击落空了！保持冷静！",
			"[color=#ff6644]失误了...还有机会！[/color]",
		],
	}
	var texts: Array = transitions.get(last_result, transitions[1])
	var chosen: String = texts[randi() % texts.size()]
	_set_text("", chosen)
	await _wait_click()
	if not _running:
		return

	# 3. 提示剩余回合
	var remaining: int = _total_rounds - _current_round
	if remaining == 1:
		_set_text("", "[color=#ff8844]最后一回合！坚持住！[/color]")
	else:
		_set_text("", "[color=#ff8844]还剩 %d 个回合...[/color]" % remaining)
	await _wait_click()


func _run_qte_round() -> int:
	"""运行一个QTE回合 返回值:0=未命中 1=命中 2=暴击"""
	_hide_text_box_children()  # QTE时隐藏对话

	# 显示当前回合的战斗描述
	var desc_texts: Array[String] = [
		"丧尸扑了过来...",
		"丧尸再次发动攻击！",
		"丧尸越来越疯狂了！",
		"它不打算停下...",
		"这是最后的冲击！",
	]
	var desc: String = desc_texts[clampi(_current_round - 1, 0, desc_texts.size() - 1)]
	_set_text("", "[color=#ff8844]" + desc + "[/color]")
	await get_tree().create_timer(0.4).timeout
	if not _running:
		return 0

	_text_label.text = ""
	_show_qte_area()

	# 回合数和提示
	_round_label.text = " 第 %d / %d 回合 " % [_current_round, _total_rounds]
	_qte_hint.text = "[空格键攻击]"
	_qte_result.text = ""

	# 随机生成目标区域位置
	var qte_x: float = _qte_bar_bg.position.x
	_qte_target_center = randf_range(_qte_zone_width, _qte_bar_w - _qte_zone_width)
	# 设置命中区域位置
	_qte_zone.position.x = qte_x + _qte_target_center - _qte_zone_width / 2.0
	_qte_zone.size.x = _qte_zone_width
	# 设置完美区域位置
	_qte_perfect.position.x = qte_x + _qte_target_center - _qte_perfect_width / 2.0
	_qte_perfect.size.x = _qte_perfect_width
	# 设置未命中区域
	_qte_miss_left.size.x = maxf(1, _qte_zone.position.x - qte_x)
	_qte_miss_left.position.x = qte_x
	_qte_miss_right.position.x = _qte_zone.position.x + _qte_zone_width
	_qte_miss_right.size.x = maxf(1, qte_x + _qte_bar_w - _qte_miss_right.position.x)

	# 指针初始位置和方向
	_qte_pos = 0.0
	_qte_dir = 1
	_qte_finished = false

	while not _qte_finished:
		await get_tree().process_frame
		if not is_instance_valid(_qte_pointer) or not _running:
			return 0

		_qte_pos += _qte_dir * _qte_speed * get_process_delta_time()
		if _qte_pos >= _qte_bar_w - 14:
			_qte_pos = _qte_bar_w - 14
			_qte_dir = -1
		elif _qte_pos <= 0:
			_qte_pos = 0
			_qte_dir = 1
		_qte_pointer.position.x = qte_x + _qte_pos

		if Input.is_key_pressed(KEY_SPACE):
			_qte_finished = true
			var ptr_center: float = _qte_pos + 7.0
			var diff: float = abs(ptr_center - _qte_target_center)

			if diff <= _qte_perfect_width / 2.0:
				# === 暴击！ ===
				_qte_result.text = "[color=#00ff44]暴击！[/color]"
				_set_text("", "[color=#00ff44]完美暴击！丧尸受到重创！[/color]")
				return 2
			elif diff <= _qte_zone_width / 2.0:
				# === 命中 ===
				_qte_result.text = "[color=#ffcc00]命中！[/color]"
				_set_text("", "[color=#ffcc00]击中了！[/color]")
				return 1
			else:
				# === 未命中 ===
				_qte_result.text = "[color=#ff4444]未命中...[/color]"
				_set_text("", "[color=#ff4444]没打中...[/color]")
				return 0

	return 0


func _hide_text_box_children() -> void:
	_text_name_label.visible = false
	_text_label.visible = false
	_continue_hint.visible = false


func _show_text_box_children() -> void:
	_text_name_label.visible = true
	_text_label.visible = true


func _end_battle() -> void:
	_hide_qte_area()
	_show_text_box_children()

	var need: int = maxi(1, _total_rounds - 1)
	if _wins >= need:
		var result_text: String = "[color=#88ff88]战斗胜利！\n成功击退了丧尸！[/color]"
		if _criticals > 0:
			result_text += "\n[color=#00ff44][b]其中 %d 次暴击，干掉了 %d 只丧尸！[/b][/color]" % [_criticals, _criticals]
			for i in range(_criticals):
				GameManager.add_kill()
		_set_text("", result_text)
	else:
		_set_text("", "[color=#ff6666]战斗失败...丧尸冲破了防线...[/color]")

	await _wait_click()

	_running = false
	GameManager.is_horde_qte_active = false
	battle_finished.emit(_wins, _total_rounds)
	queue_free()


func _input(event: InputEvent) -> void:
	# ESC键不做处理（防止误退出）
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		pass  # ESC战斗场景中不退出
