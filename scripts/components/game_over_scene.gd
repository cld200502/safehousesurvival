extends CanvasLayer
## 游戏结束 —— 显示死因 | 统计 | 读档

signal game_over_action(action: String)  # "restart" | "load_N" | "menu"

var _reason: String = ""
var _kills: int = 0
var _day: int = 1
var _hour: float = 8.0
var _main_panel: Panel
var _save_panel: Panel
var _save_container: Control
var _load_btn: Button
var _show_saves: bool = false


func _ready() -> void:
	_build_ui()


func start_game_over(reason: String, day: int, hour: float, kills: int) -> void:
	_reason = reason
	_kills = kills
	_day = day
	_hour = hour
	_fill_summary()
	visible = true


func _build_ui() -> void:
	layer = 200

	# 暗色背景 + 红色微光
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.008, 0.02, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 红色光晕
	var glow := ColorRect.new()
	glow.position = Vector2(290, 30)
	glow.size = Vector2(700, 660)
	glow.color = Color(0.3, 0.02, 0.02, 0.25)
	add_child(glow)

	# === 主面板 ===
	_main_panel = Panel.new()
	_main_panel.position = Vector2(140, 60)
	_main_panel.size = Vector2(1000, 610)
	var mstyle := StyleBoxFlat.new()
	mstyle.bg_color = Color(0.06, 0.04, 0.08, 0.96)
	mstyle.border_color = Color(0.55, 0.15, 0.15)
	mstyle.set_border_width_all(3)
	mstyle.set_corner_radius_all(10)
	_main_panel.add_theme_stylebox_override("panel", mstyle)
	add_child(_main_panel)

	# === 标题 ===
	var title := Label.new()
	title.text = "游戏结束"
	title.position = Vector2(320, 25)
	title.size = Vector2(360, 55)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 59)
	title.add_theme_color_override("font_color", Color(0.95, 0.15, 0.15))
	_main_panel.add_child(title)

	# 分隔线
	var sep1 := ColorRect.new()
	sep1.position = Vector2(100, 88)
	sep1.size = Vector2(800, 2)
	sep1.color = Color(0.45, 0.1, 0.1, 0.8)
	_main_panel.add_child(sep1)

	# === 死因 ===
	var reason_title := Label.new()
	reason_title.text = "—— 死亡原因 ——"
	reason_title.position = Vector2(100, 105)
	reason_title.size = Vector2(800, 26)
	reason_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_title.add_theme_font_size_override("font_size", 24)
	reason_title.add_theme_color_override("font_color", Color(0.8, 0.45, 0.45))
	_main_panel.add_child(reason_title)

	var reason_label := RichTextLabel.new()
	reason_label.name = "reason_label"
	reason_label.position = Vector2(120, 140)
	reason_label.size = Vector2(760, 65)
	reason_label.bbcode_enabled = true
	reason_label.fit_content = true
	reason_label.add_theme_font_size_override("normal_font_size", 22)
	reason_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	_main_panel.add_child(reason_label)

	# === 统计面板 ===
	var stats_box := Panel.new()
	stats_box.position = Vector2(180, 215)
	stats_box.size = Vector2(640, 100)
	var sstyle := StyleBoxFlat.new()
	sstyle.bg_color = Color(0.08, 0.07, 0.10, 0.8)
	sstyle.border_color = Color(0.25, 0.25, 0.25)
	sstyle.set_border_width_all(1)
	sstyle.set_corner_radius_all(6)
	stats_box.add_theme_stylebox_override("panel", sstyle)
	_main_panel.add_child(stats_box)

	var stats_label := Label.new()
	stats_label.name = "stats_label"
	stats_label.position = Vector2(10, 10)
	stats_label.size = Vector2(620, 80)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 22)
	stats_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.8))
	stats_box.add_child(stats_label)

	# === 分隔线 ===
	var sep2 := ColorRect.new()
	sep2.position = Vector2(100, 330)
	sep2.size = Vector2(800, 1)
	sep2.color = Color(0.3, 0.3, 0.3, 0.6)
	_main_panel.add_child(sep2)

	# === "读档"面板 ===
	_save_panel = Panel.new()
	_save_panel.position = Vector2(60, 345)
	_save_panel.size = Vector2(880, 155)
	var spstyle := StyleBoxFlat.new()
	spstyle.bg_color = Color(0.07, 0.06, 0.10, 0.95)
	spstyle.border_color = Color(0.25, 0.35, 0.55)
	spstyle.set_border_width_all(2)
	spstyle.set_corner_radius_all(6)
	_save_panel.add_theme_stylebox_override("panel", spstyle)
	_save_panel.visible = false
	_main_panel.add_child(_save_panel)

	var saves_title := Label.new()
	saves_title.text = "选择存档"
	saves_title.position = Vector2(20, 8)
	saves_title.size = Vector2(840, 22)
	saves_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saves_title.add_theme_font_size_override("font_size", 21)
	saves_title.add_theme_color_override("font_color", Color(0.5, 0.55, 0.8))
	_save_panel.add_child(saves_title)

	_save_container = Control.new()
	_save_container.position = Vector2(10, 35)
	_save_container.size = Vector2(860, 115)
	_save_panel.add_child(_save_container)
	_build_save_slots()

	# === 按钮区域 ===
	var btn_width: int = 260
	var btn_height: int = 52
	var total_width: int = btn_width * 3 + 20 * 2  # 820
	var start_x: int = (1000 - total_width) / 2  # 90

	# 重新开始按钮
	var restart_btn := Button.new()
	restart_btn.text = "重新开始"
	restart_btn.position = Vector2(start_x, 520)
	restart_btn.size = Vector2(btn_width, btn_height)
	restart_btn.add_theme_font_size_override("font_size", 31)
	restart_btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	var rstyle := StyleBoxFlat.new()
	rstyle.bg_color = Color(0.15, 0.1, 0.05, 0.9)
	rstyle.border_color = Color(0.7, 0.4, 0.15)
	rstyle.set_border_width_all(2)
	rstyle.set_corner_radius_all(6)
	restart_btn.add_theme_stylebox_override("normal", rstyle)
	var rhstyle := StyleBoxFlat.new()
	rhstyle.bg_color = Color(0.25, 0.15, 0.08, 0.95)
	rhstyle.border_color = Color(0.85, 0.5, 0.2)
	rhstyle.set_border_width_all(2)
	rhstyle.set_corner_radius_all(6)
	restart_btn.add_theme_stylebox_override("hover", rhstyle)
	restart_btn.pressed.connect(_on_restart)
	_main_panel.add_child(restart_btn)

	# 读档按钮
	_load_btn = Button.new()
	_load_btn.text = "读取存档"
	_load_btn.position = Vector2(start_x + btn_width + 20, 520)
	_load_btn.size = Vector2(btn_width, btn_height)
	_load_btn.add_theme_font_size_override("font_size", 31)
	_load_btn.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0))
	var lstyle := StyleBoxFlat.new()
	lstyle.bg_color = Color(0.05, 0.08, 0.15, 0.9)
	lstyle.border_color = Color(0.15, 0.4, 0.7)
	lstyle.set_border_width_all(2)
	lstyle.set_corner_radius_all(6)
	_load_btn.add_theme_stylebox_override("normal", lstyle)
	var lhstyle := StyleBoxFlat.new()
	lhstyle.bg_color = Color(0.08, 0.12, 0.22, 0.95)
	lhstyle.border_color = Color(0.25, 0.5, 0.8)
	lhstyle.set_border_width_all(2)
	lhstyle.set_corner_radius_all(6)
	_load_btn.add_theme_stylebox_override("hover", lhstyle)
	_load_btn.pressed.connect(_on_toggle_saves)
	_main_panel.add_child(_load_btn)

	# 返回主菜单按钮
	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.position = Vector2(start_x + (btn_width + 20) * 2, 520)
	menu_btn.size = Vector2(btn_width, btn_height)
	menu_btn.add_theme_font_size_override("font_size", 31)
	menu_btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	var qstyle := StyleBoxFlat.new()
	qstyle.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	qstyle.border_color = Color(0.35, 0.35, 0.4)
	qstyle.set_border_width_all(2)
	qstyle.set_corner_radius_all(6)
	menu_btn.add_theme_stylebox_override("normal", qstyle)
	var qhstyle := StyleBoxFlat.new()
	qhstyle.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	qhstyle.border_color = Color(0.45, 0.45, 0.5)
	qhstyle.set_border_width_all(2)
	qhstyle.set_corner_radius_all(6)
	menu_btn.add_theme_stylebox_override("hover", qhstyle)
	menu_btn.pressed.connect(_on_menu)
	_main_panel.add_child(menu_btn)

	# 操作提示
	var hint := Label.new()
	hint.text = "按 ESC 返回主菜单"
	hint.position = Vector2(300, 582)
	hint.size = Vector2(400, 20)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	_main_panel.add_child(hint)


func _build_save_slots() -> void:
	for c in _save_container.get_children():
		c.queue_free()

	for slot_idx in range(1, 9):
		var slot_info: Dictionary = _get_slot_info(slot_idx)
		var has_data: bool = not slot_info.is_empty()

		var slot_bg := Panel.new()
		slot_bg.position = Vector2((slot_idx - 1) * 102 + (slot_idx - 1) * 5, 3)
		slot_bg.size = Vector2(102, 105)
		if has_data:
			var s_style := StyleBoxFlat.new()
			s_style.bg_color = Color(0.1, 0.1, 0.16, 0.95)
			s_style.border_color = Color(0.35, 0.45, 0.65)
			s_style.set_border_width_all(2)
			s_style.set_corner_radius_all(4)
			slot_bg.add_theme_stylebox_override("panel", s_style)
		else:
			var e_style := StyleBoxFlat.new()
			e_style.bg_color = Color(0.05, 0.05, 0.07, 0.9)
			e_style.border_color = Color(0.2, 0.2, 0.25)
			e_style.set_border_width_all(1)
			e_style.set_corner_radius_all(4)
			slot_bg.add_theme_stylebox_override("panel", e_style)
		_save_container.add_child(slot_bg)

		var num_lbl := Label.new()
		num_lbl.text = "存档%d" % slot_idx
		num_lbl.position = Vector2(5, 4)
		num_lbl.size = Vector2(92, 20)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 17)
		num_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		slot_bg.add_child(num_lbl)

		if has_data:
			var info_lbl := Label.new()
			info_lbl.text = "第%s天\n%s\nHP:%d 击杀:%d" % [
				str(slot_info.get("day", "?")),
				slot_info.get("time", "??"),
				slot_info.get("hp", 0),
				slot_info.get("kills", 0),
			]
			info_lbl.position = Vector2(5, 24)
			info_lbl.size = Vector2(92, 48)
			info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info_lbl.add_theme_font_size_override("font_size", 14)
			info_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.88))
			slot_bg.add_child(info_lbl)

			var load_btn := Button.new()
			load_btn.text = "读取"
			load_btn.position = Vector2(18, 76)
			load_btn.size = Vector2(66, 24)
			load_btn.add_theme_font_size_override("font_size", 17)
			load_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			var si := slot_idx
			load_btn.pressed.connect(func(): _on_load_slot(si))
			slot_bg.add_child(load_btn)
		else:
			var empty_lbl := Label.new()
			empty_lbl.text = "—— 空 ——"
			empty_lbl.position = Vector2(5, 40)
			empty_lbl.size = Vector2(92, 22)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 15)
			empty_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.33))
			slot_bg.add_child(empty_lbl)


func _fill_summary() -> void:
	var reason_lbl: RichTextLabel = _main_panel.get_node_or_null("reason_label")
	if reason_lbl:
		reason_lbl.text = "[center]%s[/center]" % _reason

	var stats_lbl: Label = _main_panel.get_node_or_null("stats_label")
	if stats_lbl:
		var h: int = int(_hour) % 24
		var m: int = int((_hour - float(h)) * 60)
		stats_lbl.text = "第 %d 天      |      存活至 %02d:%02d     |      击杀 %d 只丧尸" % [_day, h, m, _kills]

	_build_save_slots()


func _get_slot_info(slot: int) -> Dictionary:
	var file := FileAccess.open("user://save_%d.json" % slot, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return {}
	var data = json.get_data()
	var h: int = int(data.get("hour", 8.0)) % 24
	return {
		"day": data.get("day", 1),
		"time": "%02d:%02d" % [h, int((data.get("hour", 8.0) - h) * 60)],
		"hp": data.get("hp", 100),
		"kills": data.get("kills", 0),
	}


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_menu()


# ==================== 按钮回调 ====================
func _on_restart() -> void:
	game_over_action.emit("restart")
	queue_free()


func _on_load_slot(slot: int) -> void:
	game_over_action.emit("load_%d" % slot)
	queue_free()


func _on_toggle_saves() -> void:
	_show_saves = not _show_saves
	_save_panel.visible = _show_saves
	_load_btn.text = "隐藏存档" if _show_saves else "读取存档"


func _on_menu() -> void:
	game_over_action.emit("menu")
	queue_free()
