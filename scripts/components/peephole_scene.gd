extends CanvasLayer
## 猫眼观察场景
## 通过猫眼观察门外的人

signal peephole_result(action: String, npc_data: Dictionary)

var _npc_data: Dictionary = {}
var _running: bool = false
var _observation_count: int = 0
var _max_observations: int = 3

# UI
var _bg: ColorRect
var _peephole_mask: ColorRect
var _peephole_view: Panel
var _npc_portrait_frame: Panel
var _npc_portrait_label: Label
var _npc_name_label: Label
var _text_box: Panel
var _text_name_label: Label
var _text_label: RichTextLabel
var _btn_container: HBoxContainer
var _btn_observe: Button
var _btn_open: Button
var _btn_refuse: Button
var _btn_continue: Button  # "继续"按钮


func _ready() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	"""空格键 = 继续"""
	if not _running:
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.is_echo():
		if _btn_continue and _btn_continue.visible and _btn_continue.disabled == false:
			# 通过 _on_continue_clicked emit信号
			_btn_continue.emit_signal("pressed")
			get_viewport().set_input_as_handled()


func start_peephole(npc_data: Dictionary) -> void:
	_npc_data = npc_data
	_observation_count = 0
	_running = true
	_build_ui()

	# 播放猫眼音效
	_play_peephole_sound()

	# 显示NPC并开始对话
	_show_npc_in_peephole()
	_start_dialogue()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.01, 0.04, 0.99)
	_bg.size = get_viewport().get_visible_rect().size
	# 阻止点击穿透到下层
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var vsize: Vector2 = _bg.size

	# ===== 暗色遮罩 =====
	_peephole_mask = ColorRect.new()
	_peephole_mask.color = Color(0.01, 0.01, 0.02, 0.85)
	_peephole_mask.size = vsize
	_peephole_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.add_child(_peephole_mask)

	# ===== 猫眼圆框 =====
	_peephole_view = Panel.new()
	_peephole_view.position = Vector2(vsize.x / 2.0 - 150, 60)
	_peephole_view.size = Vector2(300, 360)
	var pv_style: StyleBoxFlat = StyleBoxFlat.new()
	pv_style.bg_color = Color(0.05, 0.04, 0.06, 0.95)
	pv_style.border_color = Color(0.6, 0.55, 0.45, 0.9)
	pv_style.set_border_width_all(3)
	pv_style.set_corner_radius_all(150)
	_peephole_view.add_theme_stylebox_override("panel", pv_style)
	_bg.add_child(_peephole_view)

	# NPC头像框
	_npc_portrait_frame = Panel.new()
	_npc_portrait_frame.position = Vector2(30, 30)
	_npc_portrait_frame.size = Vector2(240, 280)
	var npf_style: StyleBoxFlat = StyleBoxFlat.new()
	npf_style.bg_color = Color(0.06, 0.05, 0.08, 0.9)
	npf_style.border_color = Color(0.5, 0.45, 0.4, 0.6)
	npf_style.set_border_width_all(1)
	npf_style.set_corner_radius_all(8)
	_npc_portrait_frame.add_theme_stylebox_override("panel", npf_style)
	_npc_portrait_frame.visible = false
	_peephole_view.add_child(_npc_portrait_frame)

	_npc_portrait_label = Label.new()
	_npc_portrait_label.position = Vector2(10, 10)
	_npc_portrait_label.size = Vector2(220, 250)
	_npc_portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_npc_portrait_label.text = "[ ??? ]"
	_npc_portrait_label.add_theme_font_size_override("font_size", 34)
	_npc_portrait_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_npc_portrait_frame.add_child(_npc_portrait_label)

	# NPC名字 - 圆框顶部标题
	_npc_name_label = Label.new()
	_npc_name_label.position = Vector2(vsize.x / 2.0 - 150, 44)
	_npc_name_label.size = Vector2(300, 30)
	_npc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_npc_name_label.add_theme_font_size_override("font_size", 26)
	_npc_name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_npc_name_label.visible = false
	_bg.add_child(_npc_name_label)

	# ===== 对话框 =====
	_text_box = Panel.new()
	_text_box.position = Vector2(60, vsize.y - 340)
	_text_box.size = Vector2(vsize.x - 120, 240)
	var tb_style: StyleBoxFlat = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.04, 0.03, 0.08, 0.95)
	tb_style.border_color = Color(0.5, 0.4, 0.3, 0.9)
	tb_style.set_border_width_all(2)
	tb_style.set_corner_radius_all(8)
	_text_box.add_theme_stylebox_override("panel", tb_style)
	_bg.add_child(_text_box)

	_text_name_label = Label.new()
	_text_name_label.position = Vector2(24, 8)
	_text_name_label.size = Vector2(_text_box.size.x - 48, 28)
	_text_name_label.add_theme_font_size_override("font_size", 26)
	_text_name_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_text_box.add_child(_text_name_label)

	_text_label = RichTextLabel.new()
	_text_label.position = Vector2(24, 40)
	_text_label.size = Vector2(_text_box.size.x - 48, 90)
	_text_label.bbcode_enabled = true
	_text_label.add_theme_font_size_override("normal_font_size", 26)
	_text_label.add_theme_color_override("default_color", Color(0.93, 0.9, 0.85))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_box.add_child(_text_label)

	# ===== "继续"按钮 =====
	_btn_continue = Button.new()
	_btn_continue.text = "[ 继续 ]"
	_btn_continue.custom_minimum_size = Vector2(100, 32)
	_btn_continue.add_theme_font_size_override("font_size", 22)
	_btn_continue.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_btn_continue.position = Vector2(_text_box.size.x - 120, _text_box.size.y - 44)
	_btn_continue.visible = false
	_btn_continue.pressed.connect(_on_continue_clicked)
	_text_box.add_child(_btn_continue)

	# ===== 决策按钮 =====
	_btn_container = HBoxContainer.new()
	_btn_container.position = Vector2(0, vsize.y - 60)
	_btn_container.size = Vector2(vsize.x, 50)
	_btn_container.add_theme_constant_override("separation", 30)
	_btn_container.alignment = BoxContainer.ALIGNMENT_CENTER

	_btn_observe = Button.new()
	_btn_observe.text = "再聊聊"
	_btn_observe.custom_minimum_size = Vector2(160, 44)
	_btn_observe.add_theme_font_size_override("font_size", 22)
	_btn_observe.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_btn_observe.pressed.connect(_on_observe_more)
	_btn_container.add_child(_btn_observe)

	_btn_open = Button.new()
	_btn_open.text = "收留TA"
	_btn_open.custom_minimum_size = Vector2(160, 44)
	_btn_open.add_theme_font_size_override("font_size", 22)
	_btn_open.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_btn_open.pressed.connect(_on_open_door)
	_btn_container.add_child(_btn_open)

	# 让TA留一晚
	var btn_stay := Button.new()
	btn_stay.text = "AI对话"
	btn_stay.custom_minimum_size = Vector2(160, 44)
	btn_stay.add_theme_font_size_override("font_size", 22)
	btn_stay.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	btn_stay.pressed.connect(_on_ai_question)
	_btn_container.add_child(btn_stay)

	_btn_refuse = Button.new()
	_btn_refuse.text = "关门拒绝"
	_btn_refuse.custom_minimum_size = Vector2(160, 44)
	_btn_refuse.add_theme_font_size_override("font_size", 22)
	_btn_refuse.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	_btn_refuse.pressed.connect(_on_refuse_door)
	_btn_container.add_child(_btn_refuse)

	# 杀害TA
	var btn_kill := Button.new()
	btn_kill.text = "杀害TA"
	btn_kill.custom_minimum_size = Vector2(160, 44)
	btn_kill.add_theme_font_size_override("font_size", 22)
	btn_kill.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	btn_kill.pressed.connect(_on_kill_npc)
	_btn_container.add_child(btn_kill)

	_btn_container.visible = false
	_bg.add_child(_btn_container)


func _show_npc_in_peephole() -> void:
	_npc_portrait_frame.visible = true
	_npc_name_label.visible = true

	var ntype: String = _npc_data.get("type", "survivor")
	var display_name: String = _npc_data.get("name", "???")
	if ntype == "imposter":
		display_name = _npc_data.get("fake_name", "???")
		_npc_portrait_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	else:
		_npc_portrait_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))

	_npc_name_label.text = display_name
	_npc_portrait_label.text = "[ %s ]" % display_name

	# 呼吸缩放动画
	var tween := create_tween()
	tween.tween_property(_peephole_view, "scale", Vector2(1.05, 1.05), 0.3)
	tween.tween_property(_peephole_view, "scale", Vector2(1.0, 1.0), 0.3)


func _start_dialogue() -> void:
	var intro: String = _npc_data.get("intro", "...")
	_set_text(_npc_data.get("name", "???"), intro)
	await _wait_for_click()
	if not _running: return

	_show_decision_buttons()


# ==================== 决策按钮管理 ====================

func _show_decision_buttons() -> void:
	_btn_container.visible = true
	_btn_continue.visible = false

	if _observation_count >= _max_observations:
		_btn_observe.disabled = true
		_btn_observe.text = "已充分观察"


func _on_observe_more() -> void:
	_btn_container.visible = false

	var lines: Array = _npc_data.get("lines", [])
	if _observation_count < lines.size():
		var line: Dictionary = lines[_observation_count]
		var line_text: String = line.get("text", "")
		_set_text(_npc_data.get("name", "???"), line_text)
		_observation_count += 1
		await _wait_for_click()
		if not _running: return
	else:
		_set_text("", "[i]你仔细观察，但看不出更多信息了...[/i]")
		_observation_count += 1
		await _wait_for_click()
		if not _running: return

	_show_decision_buttons()


func _on_open_door() -> void:
	_btn_container.visible = false
	_set_text("", "[color=#ffcc00]你深吸一口气，缓缓打开了门...[/color]")
	await _wait(1.5)
	if not _running: return

	_running = false
	_process_decision("open")


func _on_refuse_door() -> void:
	_btn_container.visible = false
	_set_text("", "[color=#888888]你决定不开门。\n门外的人站了一会儿，然后离开了...[/color]")
	await _wait(1.5)
	if not _running: return

	_running = false
	_process_decision("reject")


func _on_stay_one_night() -> void:
	_btn_container.visible = false
	_set_text("", "[color=#88ccff]你决定让TA在门外留一晚，明天再看看情况...[/color]")
	await _wait(1.5)
	if not _running: return

	_running = false
	_process_decision("reject")


func _on_kill_npc() -> void:
	_btn_container.visible = false
	var npc_name: String = _npc_data.get("name", "???")
	_set_text("", "你握紧了武器，瞄准 %s ...\n一场搏斗在所难免...\n你已经无法回头了。" % npc_name)
	await _wait(1.5)
	if not _running: return

	# QTE 判定
	var qte_success: bool = await _run_inline_qte("击杀%s —— [空格键确认]" % npc_name)

	if not _running: return

	if qte_success:
		GameManager.killed_npcs.append(npc_name)
		GameManager.modify_morality(-20, "杀死了%s" % npc_name)
		_set_text("", "[color=red]%s倒在了血泊中...\nTA再也没有了呼吸...[/color]" % npc_name)
		await _wait(2.5)
	else:
		GameManager.modify_morality(-5, "攻击了%s但失败了" % npc_name)
		_set_text("", "[color=yellow]%s躲开了你的攻击！\nTA惊恐地逃走了...[/color]" % npc_name)
		await _wait(2.0)

	_running = false
	_process_decision("killed")


# ==================== AI对话 ====================

# AI聊天lambda相关
var _peephole_chat_active: bool = false
var _peephole_npc_dict: Dictionary = {}
var _peephole_npc_name: String = ""
var _peephole_input: LineEdit = null
var _peephole_send_btn: Button = null
var _peephole_close_btn: Button = null

func _on_ai_question() -> void:
	"""通过猫眼与NPC对话 — 搭建聊天UI"""
	_btn_container.visible = false
	_btn_continue.visible = false

	var nname: String = _npc_data.get("name", "???")
	var ntype: String = _npc_data.get("type", "survivor")

	# AI可用性检查
	if not AIDialogue.is_ai_available():
		_set_text("", "[color=red]AI对话不可用，请检查API配置[/color]")
		await _wait_for_click()
		if not _running: return
		_show_decision_buttons()
		return

	_peephole_npc_dict = {
		"name": nname,
		"type": ntype,
		"personality": _npc_data.get("personality", ""),
		"mood": "",
		"speaking_style": _npc_data.get("speaking_style", ""),
		"background": _npc_data.get("intro", ""),
		"secret": _npc_data.get("secret", ""),
	}
	_peephole_npc_name = nname
	_peephole_chat_active = true

	# 搭建聊天UI
	var chat_ui := _setup_peephole_chat_ui(nname)
	_peephole_input = chat_ui["input"]
	_peephole_send_btn = chat_ui["send"]
	_peephole_close_btn = chat_ui["close"]

	# 初始提示
	_text_label.text = "[color=#aaaaaa]你隔着门与%s交谈...\n[/color]" % nname
	_text_name_label.text = ""

	# 连接信号
	_peephole_input.text_submitted.connect(_on_peephole_chat_send)
	_peephole_send_btn.pressed.connect(_on_peephole_chat_send)
	_peephole_close_btn.pressed.connect(_on_peephole_chat_close)

	# 点击背景关闭聊天
	if _bg and _bg.is_connected("gui_input", _on_peephole_bg_clicked):
		_bg.disconnect("gui_input", _on_peephole_bg_clicked)
	_bg.gui_input.connect(_on_peephole_bg_clicked)

	_peephole_input.grab_focus()


func _on_peephole_chat_send(_text: String = "") -> void:
	"""发送消息 — 更新UI并调用AI"""
	if not _peephole_chat_active:
		return
	if not is_instance_valid(_peephole_input):
		return

	var msg: String = _peephole_input.text.strip_edges()
	if msg == "":
		return
	_peephole_input.text = ""
	_peephole_input.editable = false
	_peephole_send_btn.disabled = true

	# 显示用户消息 + 等待提示
	_text_label.text = "[color=#999999][你说]: \"%s\"[/color]\n\n[color=#aaaaaa]%s正在思考...[/color]" % [msg, _peephole_npc_name]
	_text_name_label.text = ""

	# 调用AI并等待回复
	AIDialogue.ask_npc(_peephole_npc_dict, msg, func(reply: String, success: bool, _error_msg: String):
		if not _peephole_chat_active or not _running:
			return
		if not is_instance_valid(_peephole_input):
			return
		if success and reply != "":
			_text_label.text = "[color=#999999][你说]: \"%s\"[/color]\n\n[color=#88FFAA][b]%s:[/b] \"%s\"[/color]" % [msg, _peephole_npc_name, reply]
		else:
			_text_label.text = "[color=#999999][你说]: \"%s\"[/color]\n\n[color=#aaaaaa]%s沉默了...[/color]" % [msg, _peephole_npc_name]
		_text_name_label.text = _peephole_npc_name
		_peephole_input.editable = true
		_peephole_send_btn.disabled = false
		_peephole_input.grab_focus()
	)


func _on_peephole_chat_close() -> void:
	_peephole_chat_active = false
	_remove_peephole_chat_ui()
	# 断开背景点击
	if _bg and _bg.is_connected("gui_input", _on_peephole_bg_clicked):
		_bg.disconnect("gui_input", _on_peephole_bg_clicked)
	_show_decision_buttons()


func _on_peephole_bg_clicked(event: InputEvent) -> void:
	"""点击背景关闭聊天"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_peephole_chat_close()


func _setup_peephole_chat_ui(nname: String) -> Dictionary:
	"""搭建聊天输入UI，返回{input, send, close}"""
	var tb_size: Vector2 = _text_box.size

	# 输入框 — 底部
	var edit := LineEdit.new()
	edit.name = "PeepholeChatInput"
	edit.position = Vector2(24, tb_size.y - 55)
	edit.size = Vector2(tb_size.x - 210, 44)
	edit.placeholder_text = "对%s说点什么..." % nname
	edit.add_theme_font_size_override("font_size", 24)
	_text_box.add_child(edit)

	# 发送按钮
	var s_btn := Button.new()
	s_btn.name = "PeepholeChatSend"
	s_btn.text = "发送"
	s_btn.position = Vector2(tb_size.x - 176, tb_size.y - 55)
	s_btn.size = Vector2(56, 44)
	s_btn.add_theme_font_size_override("font_size", 24)
	s_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	_text_box.add_child(s_btn)

	# 关闭按钮 — 右侧
	var c_btn := Button.new()
	c_btn.name = "PeepholeChatClose"
	c_btn.text = "[ 关闭 ]"
	c_btn.position = Vector2(tb_size.x - 110, tb_size.y - 55)
	c_btn.size = Vector2(96, 44)
	c_btn.add_theme_font_size_override("font_size", 24)
	c_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_text_box.add_child(c_btn)

	# 缩小文字区域
	_text_label.size.y = 88

	# 隐藏继续按钮
	_btn_continue.visible = false

	return {"input": edit, "send": s_btn, "close": c_btn}


func _remove_peephole_chat_ui() -> void:
	"""移除聊天UI"""
	for child_name in ["PeepholeChatInput", "PeepholeChatSend", "PeepholeChatClose"]:
		var node := _text_box.get_node_or_null(child_name)
		if node:
			node.queue_free()
	# 恢复文字区域大小
	_text_label.size.y = 90


func _show_peephole_text_input(prompt: String) -> String:
	"""弹出文本输入框"""
	var vp := get_viewport().get_visible_rect()
	var popup := CanvasLayer.new()
	popup.name = "PeepholeTextInput"
	popup.layer = 160
	add_child(popup)

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.3)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim_bg)

	var panel := Panel.new()
	panel.position = Vector2((vp.size.x - 420) / 2, (vp.size.y - 150) / 2)
	panel.size = Vector2(420, 150)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.06, 0.06, 0.10, 0.97)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.5, 0.45, 0.35)
	ds.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ds)
	popup.add_child(panel)

	var label := Label.new()
	label.text = prompt
	label.position = Vector2(0, 12)
	label.size = Vector2(420, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	panel.add_child(label)

	var edit := LineEdit.new()
	edit.position = Vector2(30, 50)
	edit.size = Vector2(360, 34)
	edit.placeholder_text = "输入你的问题..."
	edit.add_theme_font_size_override("font_size", 16)
	panel.add_child(edit)

	var s_btn := Button.new()
	s_btn.text = "确认"
	s_btn.position = Vector2(100, 100)
	s_btn.size = Vector2(100, 34)
	s_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(s_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(220, 100)
	cancel_btn.size = Vector2(100, 34)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(cancel_btn)

	var result: String = ""

	s_btn.pressed.connect(func():
		result = edit.text.strip_edges()
		popup.queue_free()
	)
	cancel_btn.pressed.connect(func():
		popup.queue_free()
	)
	edit.text_submitted.connect(func(_t: String):
		result = edit.text.strip_edges()
		popup.queue_free()
	)

	# 等待弹窗关闭
	while is_instance_valid(popup):
		await get_tree().process_frame

	return result


func _process_decision(action: String) -> void:
	# peephole场景结束
	await get_tree().create_timer(0.3).timeout

	peephole_result.emit(action, _npc_data)
	queue_free()


# ==================== 工具函数 ====================

func _set_text(name_str: String, text: String) -> void:
	_text_name_label.text = name_str if name_str != "" else ""
	_text_label.text = text
	_btn_continue.visible = true  # 显示"继续"按钮


func _on_continue_clicked() -> void:
	# 隐藏继续按钮并发出信号
	_continue_clicked.emit()
	_btn_continue.visible = false


signal _continue_clicked()


func _wait_for_click() -> void:
	"""等待点击继续按钮"""
	_btn_continue.visible = true
	while _running and not is_queued_for_deletion():
		if not _btn_continue or not is_instance_valid(_btn_continue):
			break
		await get_tree().process_frame
		if not _btn_continue.visible:
			break


func _wait(duration: float) -> void:
	_btn_continue.visible = false
	await get_tree().create_timer(duration).timeout


func _play_peephole_sound() -> void:
	var sound_path := "res://assets/sounds/qiaomenhou.wav"
	if not ResourceLoader.exists(sound_path):
		return
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = load(sound_path)
	audio_player.volume_db = 6.0  # +6dB
	add_child(audio_player)
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()


# ==================== QTE 杀害系统 ====================

func _run_inline_qte(title: String) -> bool:
	"""内联QTE小游戏（杀害NPC用）
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
	title_lbl.position = Vector2(0, bar_y - 50)
	title_lbl.size = Vector2(bar_w, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	qte_layer.add_child(title_lbl)

	# 背景条
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(0, bar_y)
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_bg.color = Color(0.3, 0.15, 0.15)
	qte_layer.add_child(bar_bg)

	# 命中区域(很窄)
	var zone_w := 24.0
	var zone_center: float = randf_range(zone_w, bar_w - zone_w)
	var good_zone := ColorRect.new()
	good_zone.position = Vector2(zone_center - zone_w / 2.0, bar_y)
	good_zone.size = Vector2(zone_w, bar_h)
	good_zone.color = Color(0.15, 0.7, 0.2)
	qte_layer.add_child(good_zone)

	# 滑动指针
	var slider_w := 12.0
	var slider := ColorRect.new()
	slider.position = Vector2(0, bar_y - 2)
	slider.size = Vector2(slider_w, bar_h + 4)
	slider.color = Color(1.0, 0.2, 0.1)
	qte_layer.add_child(slider)

	# 提示文字
	var hint_lbl := Label.new()
	hint_lbl.text = "[ 空格键攻击 ]"
	hint_lbl.position = Vector2(0, bar_y + bar_h + 15)
	hint_lbl.size = Vector2(bar_w, 30)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 20)
	hint_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	qte_layer.add_child(hint_lbl)

	var speed := 560.0
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

	qte_layer.queue_free()
	return success
