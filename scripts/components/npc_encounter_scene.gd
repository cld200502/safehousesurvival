extends CanvasLayer
## NPC遭遇场景
## NPC敲门 + 对话 + 选择

signal encounter_result(action: String, npc_data: Dictionary)  # "recruit" / "stay" / "reject"

var _npc_data: Dictionary = {}
var _running: bool = false
var _dialogue_step: int = 0

# UI
var _bg: ColorRect
var _portrait_frame: Panel            # NPC立绘框(左侧)
var _portrait_label: Label
var _npc_name: Label                  # NPC名字
var _npc_title: Label                 # NPC身份
var _text_box: Panel                  # 对话框
var _text_name_label: Label
var _text_label: RichTextLabel
var _btn_container: HBoxContainer     # 按钮容器
var _wait_indicator: Label            # "按空格继续"指示
var _choice_visible: bool = false
var _awaiting_space: bool = false


func start_encounter(npc_data: Dictionary) -> void:
	_npc_data = npc_data
	_dialogue_step = 0
	_running = true
	_build_ui()

	# 初始显示"..."
	var nname: String = npc_data.get("name", "???")
	var ntype: String = npc_data.get("type", "survivor")
	_set_text(nname, "门外传来脚步声...")
	await _wait(1.8)
	if not _running: return

	_show_portrait()
	# 播放对话
	await _play_dialogue()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.01, 0.04, 0.99)
	_bg.size = get_viewport().get_visible_rect().size
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var vsize: Vector2 = _bg.size

	# ===== NPC立绘框 =====
	_portrait_frame = Panel.new()
	_portrait_frame.position = Vector2(80, 80)
	_portrait_frame.size = Vector2(280, 380)
	var pf_style: StyleBoxFlat = StyleBoxFlat.new()
	pf_style.bg_color = Color(0.05, 0.04, 0.08, 0.95)
	pf_style.border_color = Color(0.55, 0.45, 0.35, 0.8)
	pf_style.set_border_width_all(3)
	pf_style.set_corner_radius_all(12)
	_portrait_frame.add_theme_stylebox_override("panel", pf_style)
	_portrait_frame.visible = false
	_bg.add_child(_portrait_frame)

	# NPC名字(顶部)
	_portrait_label = Label.new()
	_portrait_label.position = Vector2(20, 60)
	_portrait_label.size = Vector2(240, 240)
	_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_label.add_theme_font_size_override("font_size", 42)
	_portrait_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))
	_portrait_frame.add_child(_portrait_label)

	# NPC名称标签(下方)
	_npc_name = Label.new()
	_npc_name.position = Vector2(0, 24)
	_npc_name.size = Vector2(280, 30)
	_npc_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_name.add_theme_font_size_override("font_size", 30)
	_npc_name.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_portrait_frame.add_child(_npc_name)

	# NPC身份标签(底部)
	_npc_title = Label.new()
	_npc_title.position = Vector2(20, 330)
	_npc_title.size = Vector2(240, 30)
	_npc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_title.add_theme_font_size_override("font_size", 26)
	_npc_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_npc_title.visible = false
	_portrait_frame.add_child(_npc_title)

	# ===== 对话框 =====
	_text_box = Panel.new()
	_text_box.position = Vector2(400, vsize.y - 300)
	_text_box.size = Vector2(vsize.x - 460, 240)
	var tb_style: StyleBoxFlat = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.04, 0.03, 0.08, 0.95)
	tb_style.border_color = Color(0.45, 0.38, 0.3, 0.85)
	tb_style.set_border_width_all(2)
	tb_style.set_corner_radius_all(8)
	_text_box.add_theme_stylebox_override("panel", tb_style)
	_bg.add_child(_text_box)

	_text_name_label = Label.new()
	_text_name_label.position = Vector2(20, 12)
	_text_name_label.size = Vector2(_text_box.size.x - 40, 26)
	_text_name_label.add_theme_font_size_override("font_size", 26)
	_text_name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_text_box.add_child(_text_name_label)

	_text_label = RichTextLabel.new()
	_text_label.position = Vector2(20, 44)
	_text_label.size = Vector2(_text_box.size.x - 40, 120)
	_text_label.bbcode_enabled = true
	_text_label.add_theme_font_size_override("normal_font_size", 26)
	_text_label.add_theme_font_size_override("bold_font_size", 26)
	_text_label.add_theme_font_size_override("italics_font_size", 26)
	_text_label.add_theme_font_size_override("mono_font_size", 26)
	_text_label.add_theme_color_override("default_color", Color(0.93, 0.9, 0.85))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_box.add_child(_text_label)

	# "按空格继续"提示
	_wait_indicator = Label.new()
	_wait_indicator.text = "[ 按空格继续 ]"
	_wait_indicator.position = Vector2(0, 200)
	_wait_indicator.size = Vector2(_text_box.size.x, 28)
	_wait_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wait_indicator.add_theme_font_size_override("font_size", 26)
	_wait_indicator.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	_wait_indicator.visible = false
	_text_box.add_child(_wait_indicator)

	# ===== 按钮容器 =====
	_btn_container = HBoxContainer.new()
	_btn_container.position = Vector2(0, vsize.y - 50)
	_btn_container.size = Vector2(vsize.x, 44)
	_btn_container.add_theme_constant_override("separation", 20)
	_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_container.visible = false
	_bg.add_child(_btn_container)


func _show_portrait() -> void:
	_portrait_frame.visible = true
	var nname: String = _npc_data.get("name", "???")
	var ntype: String = _npc_data.get("type", "survivor")
	var ndesc: String = _npc_data.get("desc", "")

	_portrait_label.text = "[ %s ]" % nname

	# 根据类型设置颜色
	match ntype:
		"survivor":
			_portrait_label.add_theme_color_override("font_color", Color(0.65, 0.9, 0.65))
			_npc_title.text = "幸存者"
			_npc_title.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
		"imposter":
			_portrait_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
			_npc_title.text = "??? 可疑人物"
			_npc_title.add_theme_color_override("font_color", Color(0.55, 0.5, 0.6))
		"zombie":
			_portrait_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.25))
			_npc_title.text = "丧尸"
			_npc_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		_:
			_portrait_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			_npc_title.text = "陌生人"
			_npc_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

	_npc_name.text = nname

	# 入场动画
	var tween := create_tween()
	tween.tween_property(_portrait_frame, "position:x", 80, 0.15).from(30)
	tween.tween_property(_portrait_frame, "modulate:a", 1.0, 0.12).from(0.3)


# ==================== 对话流程 ====================

func _play_dialogue() -> void:
	"""播放NPC开场对话"""
	var ntype: String = _npc_data.get("type", "survivor")
	var nname: String = _npc_data.get("name", "???")
	var lines: Array[String] = _get_dialogue_lines(ntype, nname)

	# 播放前两句
	for i in range(2):
		if i >= lines.size():
			break
		_set_text(nname, "[i]\"%s\"[/i]" % lines[i])
		await _wait_space()
		if not _running: return
		_dialogue_step = i + 1

	# 显示选项
	_show_choices()


func _get_dialogue_lines(npc_type: String, npc_name: String) -> Array[String]:
	match npc_type:
		"survivor":
			return [
				"让我进去吧...外面不太安全...",
				"我叫%s...听到这边有动静..." % npc_name,
				"我能干点活，搬东西什么的...",
				"给个角落就行，不占地方的...",
			]
		"imposter":
			return [
				"开门吧，外面冷得很...",
				"我是%s，从东边过来的..." % npc_name,
				"我知道哪里有物资...可以带路...",
				"你不会后悔的...真的...",
			]
		"zombie":
			return [
				"...................",
				"......呃......啊......",
				"...饿...肉...",
				"......砰！砰！砰！......",
			]
		"hidden_infected":
			return [
				"...让我进去...我受伤了...",
				"我叫%s...被抓了一下..." % npc_name,
				"还能走...真的...",
				"不会变的...不会的...",
			]
		_:
			return ["有人吗...", "听到声音了...", "我需要帮忙...%s" % npc_name]


func _show_choices() -> void:
	"""显示操作选项"""
	_choice_visible = true
	_btn_container.visible = true
	_wait_indicator.visible = false

	# 清空旧按钮
	for c in _btn_container.get_children():
		c.queue_free()

	var ntype: String = _npc_data.get("type", "survivor")

	# 收留按钮
	var recruit_btn := Button.new()
	recruit_btn.text = "收留TA"
	recruit_btn.custom_minimum_size = Vector2(180, 40)
	recruit_btn.add_theme_font_size_override("font_size", 26)
	recruit_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	recruit_btn.pressed.connect(func(): _on_choice("recruit"))
	_btn_container.add_child(recruit_btn)

	# 继续对话
	var talk_btn := Button.new()
	talk_btn.text = "继续观察"
	talk_btn.custom_minimum_size = Vector2(160, 40)
	talk_btn.add_theme_font_size_override("font_size", 26)
	talk_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7))
	talk_btn.pressed.connect(func(): _on_talk_more())
	_btn_container.add_child(talk_btn)

	# 拒绝
	var reject_btn := Button.new()
	reject_btn.text = "不开门"
	reject_btn.custom_minimum_size = Vector2(160, 40)
	reject_btn.add_theme_font_size_override("font_size", 26)
	reject_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	reject_btn.pressed.connect(func(): _on_choice("reject"))
	_btn_container.add_child(reject_btn)

	# 攻击TA
	var kill_btn := Button.new()
	kill_btn.text = "攻击TA"
	kill_btn.custom_minimum_size = Vector2(160, 40)
	kill_btn.add_theme_font_size_override("font_size", 26)
	kill_btn.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	kill_btn.pressed.connect(func(): _on_kill())
	_btn_container.add_child(kill_btn)


func _on_talk_more() -> void:
	"""继续对话"""
	_btn_container.visible = false
	_choice_visible = false

	var ntype: String = _npc_data.get("type", "survivor")
	var nname: String = _npc_data.get("name", "???")
	var lines: Array[String] = _get_dialogue_lines(ntype, nname)

	_dialogue_step += 1
	if _dialogue_step < lines.size():
		_set_text(nname, "[i]\"%s\"[/i]" % lines[_dialogue_step])
	else:
		var wait_lines := [
			"你还在犹豫什么...",
			"TA焦急地等待着你的答复...",
			"时间一分一秒地流逝...",
			"TA的眼神中充满了期待...",
			"外面的风声越来越大了...",
			"TA的呼吸变得急促起来...",
		]
		_set_text(nname, "[color=#888888]%s[/color]" % wait_lines[randi() % wait_lines.size()])

	await _wait_space()
	if not _running: return

	_show_choices()


func _on_choice(action: String) -> void:
	"""处理选择"""
	_running = false
	encounter_result.emit(action, _npc_data)
	queue_free()


func _on_kill() -> void:
	"""攻击NPC——QTE判定"""
	_btn_container.visible = false
	_choice_visible = false
	_wait_indicator.visible = false
	
	var nname: String = _npc_data.get("name", "???")
	
	# 攻击描述
	_set_text("", "你举起武器，瞄准了%s...\n一场搏斗在所难免...\n你已经无法回头了。" % nname)
	await _wait(1.5)
	if not _running: return
	
	# 执行QTE
	var qte_success: bool = await _run_inline_qte("击杀%s —— [空格键确认]" % nname)
	
	if not _running: return
	
	if qte_success:
		GameManager.killed_npcs.append(nname)
		GameManager.modify_morality(-20, "杀死了%s" % nname)
		_set_text("", "[color=red]%s倒在了血泊中...\nTA再也没有了呼吸...[/color]" % nname)
		await _wait(2.5)
	else:
		GameManager.modify_morality(-5, "攻击了%s但失败了" % nname)
		_set_text("", "[color=yellow]%s躲开了你的攻击！\nTA惊恐地逃走了...[/color]" % nname)
		await _wait(2.0)
	
	_running = false
	encounter_result.emit("killed", _npc_data)
	queue_free()


func _run_inline_qte(title: String) -> bool:
	"""内联QTE小游戏
	返回: true=成功, false=失败"""
	var vp_size := _bg.size
	var bar_w := 480.0
	var bar_h := 40.0
	var bar_x := (vp_size.x - bar_w) / 2.0
	var bar_y := vp_size.y * 0.6
	
	# 创建QTE UI层
	var qte_layer := Control.new()
	qte_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte_layer.position = Vector2(bar_x, 0)
	_bg.add_child(qte_layer)
	
	# 标题
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(0, -50)
	title_lbl.size = Vector2(bar_w, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	qte_layer.add_child(title_lbl)
	
	# 背景条
	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_bg.color = Color(0.3, 0.15, 0.15)
	qte_layer.add_child(bar_bg)
	
	# 命中区域(很窄)
	var zone_w := 24.0  # 极窄的命中区
	var zone_center: float = randf_range(zone_w, bar_w - zone_w)
	var good_zone := ColorRect.new()
	good_zone.size = Vector2(zone_w, bar_h)
	good_zone.position = Vector2(zone_center - zone_w / 2.0, 0)
	good_zone.color = Color(0.15, 0.7, 0.2)
	qte_layer.add_child(good_zone)
	
	# 滑动指针
	var slider_w := 12.0
	var slider := ColorRect.new()
	slider.size = Vector2(slider_w, bar_h + 4)
	slider.position = Vector2(0, -2)
	slider.color = Color(1.0, 0.2, 0.1)
	qte_layer.add_child(slider)
	
	# 提示文字
	var hint_lbl := Label.new()
	hint_lbl.text = "[ 空格键攻击 ]"
	hint_lbl.position = Vector2(0, bar_h + 15)
	hint_lbl.size = Vector2(bar_w, 30)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 20)
	hint_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	qte_layer.add_child(hint_lbl)
	
	var speed := 560.0  # 快速移动
	var direction := 1.0
	var slider_x := 0.0
	var done := false
	var success := false
	
	while not done and _running:
		await get_tree().process_frame
		slider_x += speed * direction * 0.016
		
		if slider_x >= bar_w - slider_w:
			slider_x = bar_w - slider_w
			direction = -1.0
		elif slider_x <= 0:
			slider_x = 0
			direction = 1.0
		
		slider.position.x = slider_x
		
		# 检测空格键
		if Input.is_key_pressed(KEY_SPACE):
			var slider_center := slider_x + slider_w / 2.0
			var diff: float = abs(slider_center - zone_center)
			success = diff <= zone_w / 2.0
			
			if success:
				slider.color = Color(0.2, 1.0, 0.2)
				hint_lbl.text = "命中！"
			else:
				slider.color = Color(0.4, 0.4, 0.4)
				hint_lbl.text = "未命中..."
			
			await get_tree().create_timer(0.8).timeout
			done = true
	
	return success


# ==================== 工具函数 ====================

func _wait(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _wait_space() -> void:
	"""等待玩家按空格键"""
	_awaiting_space = true
	_wait_indicator.visible = true
	# 闪烁动画
	var blink_tween := create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(_wait_indicator, "modulate:a", 0.3, 0.6)
	blink_tween.tween_property(_wait_indicator, "modulate:a", 1.0, 0.6)

	while _awaiting_space and _running:
		await get_tree().process_frame

	if blink_tween.is_valid():
		blink_tween.kill()
	_wait_indicator.visible = false
	_wait_indicator.modulate.a = 1.0


func _set_text(name_str: String, text: String) -> void:
	_text_name_label.text = name_str if name_str != "" else ""
	_text_label.text = text


func _input(event: InputEvent) -> void:
	if _awaiting_space and not _choice_visible:
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
			_awaiting_space = false
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _running:
		pass  # ESC在此场景中不退出
