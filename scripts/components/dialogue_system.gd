extends CanvasLayer
## 对话系统 —— 敲门NPC对话

var dialogue_panel: Panel
var name_label: Label
var intro_label: Label
var clue_label: RichTextLabel
var current_line_index: int = 0
var btn_open: Button
var btn_refuse: Button
var btn_next: Button
var btn_ask: Button
var current_npc: Dictionary = {}
var lines: Array = []
var show_all_lines: bool = false


func _ready() -> void:
	_build_ui()
	hide()


func _build_ui() -> void:
	dialogue_panel = Panel.new()
	dialogue_panel.position = Vector2(240, 80)
	dialogue_panel.size = Vector2(800, 560)
	dialogue_panel.self_modulate = Color(0.08, 0.08, 0.08, 0.96)
	add_child(dialogue_panel)

	# NPC名字
	name_label = Label.new()
	name_label.position = Vector2(30, 20)
	name_label.add_theme_font_size_override("font_size", 31)
	name_label.add_theme_color_override("font_color", Color.YELLOW)
	dialogue_panel.add_child(name_label)

	# 对话/介绍文字
	intro_label = Label.new()
	intro_label.position = Vector2(30, 70)
	intro_label.size = Vector2(740, 200)
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.add_theme_font_size_override("font_size", 22)
	intro_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	dialogue_panel.add_child(intro_label)

	# 线索/结果文字
	clue_label = RichTextLabel.new()
	clue_label.position = Vector2(30, 280)
	clue_label.size = Vector2(740, 160)
	clue_label.bbcode_enabled = true
	clue_label.add_theme_font_size_override("normal_font_size", 20)
	clue_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.7))
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_panel.add_child(clue_label)

	# 按钮容器
	var btn_container := HBoxContainer.new()
	btn_container.position = Vector2(30, 460)
	btn_container.add_theme_constant_override("separation", 15)
	dialogue_panel.add_child(btn_container)

	btn_ask = Button.new()
	btn_ask.text = "询问"
	btn_ask.size = Vector2(170, 50)
	btn_ask.add_theme_font_size_override("font_size", 21)
	btn_ask.pressed.connect(_on_ask)
	btn_container.add_child(btn_ask)

	btn_next = Button.new()
	btn_next.text = "继续..."
	btn_next.size = Vector2(170, 50)
	btn_next.add_theme_font_size_override("font_size", 21)
	btn_next.pressed.connect(_on_next_line)
	btn_next.visible = false
	btn_container.add_child(btn_next)

	btn_open = Button.new()
	btn_open.text = "开门"
	btn_open.size = Vector2(170, 50)
	btn_open.add_theme_font_size_override("font_size", 21)
	btn_open.add_theme_color_override("font_color", Color.GREEN)
	btn_open.pressed.connect(_on_open_door)
	btn_container.add_child(btn_open)

	btn_refuse = Button.new()
	btn_refuse.text = "不开门"
	btn_refuse.size = Vector2(170, 50)
	btn_refuse.add_theme_font_size_override("font_size", 21)
	btn_refuse.add_theme_color_override("font_color", Color.RED)
	btn_refuse.pressed.connect(_on_refuse_door)
	btn_container.add_child(btn_refuse)


func start_dialogue(npc_data: Dictionary) -> void:
	current_npc = npc_data
	current_line_index = 0
	show_all_lines = false
	lines = npc_data.get("lines", [])
	var display_name := npc_data.get("name", "???")
	if npc_data.get("type", "") == "imposter":
		display_name = npc_data.get("fake_name", "???") + "?"
	name_label.text = "——%s" % display_name
	intro_label.text = "%s" % npc_data.get("intro", "...")
	clue_label.clear()
	btn_ask.visible = lines.size() > 0
	btn_next.visible = false
	btn_open.visible = true
	btn_refuse.visible = true
	show()


func _on_ask() -> void:
	"""询问NPC——获取更多信息"""
	if current_line_index < lines.size():
		var line: Dictionary = lines[current_line_index]
		var line_text: String = line.get("text", "")
		var new_text := intro_label.text + "\n\n"
		if line.get("speaker", "npc") == "npc":
			new_text += "[对方说] " + line_text
		else:
			new_text += line_text
		intro_label.text = new_text
		current_line_index += 1
		# 询问两轮后显示线索
		if current_line_index >= 2:
			clue_label.text = "[color=gray]似乎得到了一些有用的信息...[/color]"

	if current_line_index >= lines.size():
		btn_ask.visible = false
		btn_next.visible = false
		clue_label.text += "\n[color=yellow]你已经了解了足够的信息。[/color]"


func _on_next_line() -> void:
	if current_line_index < lines.size():
		_on_ask()


func _on_open_door() -> void:
	_process_decision(true)


func _on_refuse_door() -> void:
	_process_decision(false)


func _process_decision(accepted: bool) -> void:
	hide()
	if accepted:
		GameManager.popup_message.emit("[color=green]你打开了门...[/color]")
	else:
		GameManager.popup_message.emit("[color=red]你拒绝了对方的请求...[/color]")

	await get_tree().create_timer(1.2).timeout

	# 通知GameManager处理NPC
	GameManager.process_door_decision(accepted)
	if accepted and current_npc.get("type", "") == "survivor":
		# 通知main生成NPC
		var main_node := get_parent()
		if main_node and main_node.has_node("UILayer"):
			var ui := main_node.get_node("UILayer")
			if ui.has_signal("npc_spawned"):
				ui.npc_spawned.emit(current_npc)
		GameManager.popup_message.emit("[color=green]%s加入了你的安全屋[/color]" % current_npc.get("name", ""))
