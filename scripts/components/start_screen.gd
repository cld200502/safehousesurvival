extends Control
## 开始界面 —— 主菜单

var title_label: Label
var subtitle_label: Label
var flavor_label: RichTextLabel
var start_btn: Button
var ai_btn: Button
var info_label: Label
var ai_panel: Panel


func _ready() -> void:
	_build_ui()
	_build_ai_panel()
	# 播放主界面音乐
	_play_menu_music()


func _build_ui() -> void:
	# 黑色背景
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.02)
	bg.size = Vector2(1280, 720)
	bg.position = Vector2(0, 0)
	add_child(bg)

	# 游戏标题
	title_label = Label.new()
	title_label.text = "门外"
	title_label.position = Vector2(0, 100)
	title_label.size = Vector2(1280, 80)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 67)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	add_child(title_label)

	# 副标题
	subtitle_label = Label.new()
	subtitle_label.text = "—— 你能活多久？ ——"
	subtitle_label.position = Vector2(0, 180)
	subtitle_label.size = Vector2(1280, 40)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 34)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(subtitle_label)

	# 游戏简介文字
	flavor_label = RichTextLabel.new()
	flavor_label.bbcode_enabled = true
	flavor_label.text = "[center]\n\n\n\n[color=#AAAAAA]城市沦陷了。\n你把自己锁在公寓里，听着外面世界的崩塌。\n\n白天，你出去搜刮物资。\n晚上，有人来敲门。\n\n[color=yellow]但你怎么知道——门外的那个，到底还是不是人？[/color]\n\n有些东西学会了伪装。\n它们能说话，能呼吸，甚至能哭。\n但它们的细节永远不对。\n\n[color=red]擦亮眼睛，注意每一个破绽。[/color]\n你的命，取决于你能不能分辨。[/color]\n[/center]"
	flavor_label.position = Vector2(190, 250)
	flavor_label.size = Vector2(900, 260)
	flavor_label.add_theme_font_size_override("normal_font_size", 21)
	flavor_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	add_child(flavor_label)

	# 1280 = (1280-400)/2 = 440
	start_btn = Button.new()
	start_btn.text = "开始游戏"
	start_btn.position = Vector2(440, 550)
	start_btn.size = Vector2(400, 55)
	start_btn.add_theme_font_size_override("font_size", 31)
	start_btn.pressed.connect(_on_start)
	add_child(start_btn)

	# AI对话设置按钮
	ai_btn = Button.new()
	ai_btn.text = "AI 设置"
	ai_btn.position = Vector2(440, 620)
	ai_btn.size = Vector2(400, 40)
	ai_btn.add_theme_font_size_override("font_size", 22)
	ai_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	ai_btn.pressed.connect(_show_ai_panel)
	add_child(ai_btn)

	# 操作提示
	info_label = Label.new()
	info_label.text = "A/D 移动 | E/空格 互动 | I 背包 | 鼠标点击UI"
	info_label.position = Vector2(0, 675)
	info_label.size = Vector2(1280, 30)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(info_label)


# ==================== AI ====================
func _build_ai_panel() -> void:
	ai_panel = Panel.new()
	ai_panel.position = Vector2(190, 50)
	ai_panel.size = Vector2(900, 620)
	ai_panel.visible = false

	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	pstyle.set_corner_radius_all(12)
	pstyle.set_border_width_all(2)
	pstyle.border_color = Color(0.3, 0.3, 0.25, 0.8)
	ai_panel.add_theme_stylebox_override("panel", pstyle)
	add_child(ai_panel)

	# AI设置标题
	var title := Label.new()
	title.text = "=== AI对话设置 ==="
	title.position = Vector2(0, 14)
	title.size = Vector2(900, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	ai_panel.add_child(title)

	# AI功能说明
	var desc := RichTextLabel.new()
	desc.text = """[color=#AAAAAA]AI对话为可选功能，不配置也能正常游戏，NPC将使用预设对话。
启用后NPC会根据性格智能生成回复，体验更沉浸。[/color]"""
	desc.position = Vector2(40, 58)
	desc.size = Vector2(820, 60)
	desc.bbcode_enabled = true
	desc.add_theme_font_size_override("normal_font_size", 16)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ai_panel.add_child(desc)

	var y_start := 135
	var line_h := 44
	var label_w := 140
	var field_w := 480
	var field_x := 200

	# --- 启用开关 ---
	var enabled_label := Label.new()
	enabled_label.text = "AI对话开关:"
	enabled_label.position = Vector2(40, y_start)
	enabled_label.size = Vector2(label_w, line_h)
	enabled_label.add_theme_font_size_override("font_size", 20)
	enabled_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ai_panel.add_child(enabled_label)

	var enabled_box := CheckBox.new()
	enabled_box.text = "启用（需填入API密钥后开启）"
	enabled_box.position = Vector2(field_x, y_start)
	enabled_box.size = Vector2(500, line_h)
	enabled_box.button_pressed = AIDialogue.ai_enabled
	enabled_box.add_theme_font_size_override("font_size", 18)
	ai_panel.add_child(enabled_box)

	# --- API URL ---
	y_start += line_h + 8
	var url_label := Label.new()
	url_label.text = "API地址:"
	url_label.position = Vector2(40, y_start)
	url_label.size = Vector2(label_w, line_h)
	url_label.add_theme_font_size_override("font_size", 20)
	url_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ai_panel.add_child(url_label)

	var url_edit := LineEdit.new()
	url_edit.text = AIDialogue.api_url
	url_edit.position = Vector2(field_x, y_start)
	url_edit.size = Vector2(field_w, 32)
	url_edit.add_theme_font_size_override("font_size", 16)
	ai_panel.add_child(url_edit)

	# --- API Key ---
	y_start += line_h + 8
	var key_label := Label.new()
	key_label.text = "API密钥:"
	key_label.position = Vector2(40, y_start)
	key_label.size = Vector2(label_w, line_h)
	key_label.add_theme_font_size_override("font_size", 20)
	key_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ai_panel.add_child(key_label)

	var key_edit := LineEdit.new()
	key_edit.text = AIDialogue.api_key
	key_edit.secret = true
	key_edit.position = Vector2(field_x, y_start)
	key_edit.size = Vector2(field_w, 32)
	key_edit.add_theme_font_size_override("font_size", 16)
	key_edit.placeholder_text = "sk-xxxxxxxxxxxxxxxx"
	ai_panel.add_child(key_edit)

	# --- 模型选择 ---
	y_start += line_h + 8
	var model_label := Label.new()
	model_label.text = "模型名称:"
	model_label.position = Vector2(40, y_start)
	model_label.size = Vector2(label_w, line_h)
	model_label.add_theme_font_size_override("font_size", 20)
	model_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ai_panel.add_child(model_label)

	var model_edit := LineEdit.new()
	model_edit.text = AIDialogue.ai_model
	model_edit.position = Vector2(field_x, y_start)
	model_edit.size = Vector2(field_w, 32)
	model_edit.add_theme_font_size_override("font_size", 16)
	ai_panel.add_child(model_edit)

	# --- 温度参数 ---
	y_start += line_h + 8
	var temp_label := Label.new()
	temp_label.text = "创意度(0-2):"
	temp_label.position = Vector2(40, y_start)
	temp_label.size = Vector2(label_w, line_h)
	temp_label.add_theme_font_size_override("font_size", 20)
	temp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ai_panel.add_child(temp_label)

	var temp_slider := HSlider.new()
	temp_slider.min_value = 0.0
	temp_slider.max_value = 2.0
	temp_slider.step = 0.05
	temp_slider.value = AIDialogue.ai_temperature
	temp_slider.position = Vector2(field_x, y_start + 2)
	temp_slider.size = Vector2(300, 20)
	ai_panel.add_child(temp_slider)

	var temp_value := Label.new()
	temp_value.text = "%.2f" % AIDialogue.ai_temperature
	temp_value.position = Vector2(field_x + 310, y_start)
	temp_value.size = Vector2(80, 24)
	temp_value.add_theme_font_size_override("font_size", 18)
	temp_value.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	ai_panel.add_child(temp_value)
	temp_slider.value_changed.connect(func(v: float): temp_value.text = "%.2f" % v)

	# --- 预设 ---
	y_start += line_h + 16
	var preset_label := Label.new()
	preset_label.text = "快速预设:"
	preset_label.position = Vector2(40, y_start)
	preset_label.size = Vector2(label_w, 30)
	preset_label.add_theme_font_size_override("font_size", 20)
	preset_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ai_panel.add_child(preset_label)

	var presets := [
		{"name": "DeepSeek", "url": "https://api.deepseek.com/v1/chat/completions", "model": "deepseek-chat"},
		{"name": "OpenAI", "url": "https://api.openai.com/v1/chat/completions", "model": "gpt-4o-mini"},
		{"name": "Ollama()", "url": "http://localhost:11434/v1/chat/completions", "model": "qwen2.5:7b"},
	]
	var px := 200
	for pre in presets:
		var pbtn := Button.new()
		pbtn.text = pre["name"]
		pbtn.position = Vector2(px, y_start - 2)
		pbtn.size = Vector2(120, 30)
		pbtn.add_theme_font_size_override("font_size", 16)
		pbtn.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
		pbtn.pressed.connect(func(u=pre["url"], m=pre["model"]):
			url_edit.text = u
			model_edit.text = m
		)
		ai_panel.add_child(pbtn)
		px += 135

	# --- 保存/返回按钮 ---
	y_start += line_h + 24
	var save_btn := Button.new()
	save_btn.text = "保存设置"
	save_btn.position = Vector2(field_x, y_start)
	save_btn.size = Vector2(200, 40)
	save_btn.add_theme_font_size_override("font_size", 22)
	save_btn.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	save_btn.pressed.connect(func():
		var config := {
			"enabled": enabled_box.button_pressed,
			"api_url": url_edit.text.strip_edges(),
			"api_key": key_edit.text.strip_edges(),
			"model": model_edit.text.strip_edges(),
			"temperature": temp_slider.value,
			"max_tokens": 400,
		}
		AIDialogue.set_config(config)
		_hide_ai_panel()
	)
	ai_panel.add_child(save_btn)

	# --- 返回按钮 ---
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(field_x + 220, y_start)
	back_btn.size = Vector2(150, 40)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.add_theme_color_override("font_color", Color(0.9, 0.65, 0.4))
	back_btn.pressed.connect(_hide_ai_panel)
	ai_panel.add_child(back_btn)


func _show_ai_panel() -> void:
	ai_panel.visible = true
	title_label.visible = false
	subtitle_label.visible = false
	flavor_label.visible = false
	start_btn.visible = false
	ai_btn.visible = false
	info_label.visible = false


func _hide_ai_panel() -> void:
	ai_panel.visible = false
	title_label.visible = true
	subtitle_label.visible = true
	flavor_label.visible = true
	start_btn.visible = true
	ai_btn.visible = true
	info_label.visible = true


func _play_menu_music() -> void:
	var sound_path := "res://assets/sounds/zhujiemian.wav"
	if not ResourceLoader.exists(sound_path):
		return
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = load(sound_path)
	add_child(audio_player)
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()


func _on_start() -> void:
	# 移除开始界面层(CanvasLayer)并启动主游戏场景
	var layer := get_parent()
	if layer:
		layer.queue_free()
	var main := get_node("/root/Main")
	if main and main.has_method("start_new_game"):
		main.start_new_game()
