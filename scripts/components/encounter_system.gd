extends CanvasLayer
## 遭遇战系统 —— 开场QTE逃脱 → 回合制战斗
## 先QTE尝试逃跑 → 失败进入战斗回合 → QTE攻击/逃跑

signal encounter_ended(escaped: bool, player_dead: bool)

# === 阶段 ===
enum Phase { INTRO, ESCAPE_QTE, BATTLE, ENDED }
var _phase := Phase.INTRO
var _zombie_text: String = ""
var _horror_text: String = ""
var _location_name: String = ""
var _danger_level: float = 0.4  # 危险等级

# === 战斗数据 ===
var _player_hp: int = 100
var _player_max_hp: int = 100
var _zombie_hp: int = 50
var _zombie_max_hp: int = 50
var _player_atk: int = 0
var _round_num: int = 1
var _max_rounds: int = 10  # 最大回合数(超时自动结束)

# === UI ===
var _root: Panel
var _text_box: RichTextLabel
var _qte_bar_bg: ColorRect
var _qte_zone: ColorRect            # 命中区
var _qte_perfect_zone: ColorRect    # 完美/暴击区
var _qte_miss_left: ColorRect       # 左侧未命中
var _qte_miss_right: ColorRect      # 右侧未命中
var _qte_pointer: ColorRect         # 移动指针
var _qte_label: Label
var _continue_hint: Label
var _item_panel: Panel  # 物品面板
var _hp_bar_player: ColorRect
var _hp_bar_zombie: ColorRect
var _status_label: Label
# HP文字标签 p_stat/z_stat
var _p_hp_label: Label
var _z_hp_label: Label

# QTE
var _qte_pos: float = 0.0
var _qte_dir: float = 1.0
var _qte_speed: float = 294.0
var _qte_active: bool = false
var _qte_target_center: float = 250.0  # 目标中心/命中区中心
const QTE_BAR_WIDTH: float = 500.0
var _qte_zone_width: float = 70.0      # 命中区宽度
var _qte_perfect_width: float = 18.0   # 完美区宽度


func _ready() -> void:
	_build_ui()
	visible = false


func start_encounter(loc_name: String, zombie_text: String, horror_text: String, danger: float) -> void:
	_location_name = loc_name
	_zombie_text = zombie_text
	_horror_text = horror_text
	_danger_level = danger

	# 同步玩家数据 + 计算属性
	_player_hp = GameManager.hp
	_player_max_hp = GameManager.max_hp
	_player_atk = GameManager.get_total_damage()
	if _player_atk <= 0:
		_player_atk = 8  # 基础攻击力
	# 丧尸等级加成: (1 + 0.2 * level) Lv.1→1.2, Lv.4→1.8
	var level_mult := 1.0 + 0.2 * GameManager.zombie_level
	var z_base := int((40 + danger * 50) * level_mult)  # 基础值 × 等级加成
	_zombie_hp = z_base + randi_range(-5, 10)
	_zombie_max_hp = _zombie_hp
	_max_rounds = 8 + int(danger * 6) + GameManager.zombie_level  # 最大回合 

	_phase = Phase.INTRO
	_round_num = 1
	visible = true
	_item_panel.visible = false
	_show_intro_text()


func _build_ui() -> void:
	layer = 150

	# 暗色背景
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.03, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_root = Panel.new()
	_root.position = Vector2(60, 30)
	_root.size = Vector2(1080, 620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.08, 0.95)
	style.border_color = Color(0.45, 0.25, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_root.add_theme_stylebox_override("panel", style)
	add_child(_root)

	# === 标题 ===
	var title := Label.new()
	title.name = "encounter_title"
	title.text = "—— 遭遇丧尸 ——"
	title.position = Vector2(400, 12)
	title.size = Vector2(280, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color.ORANGE)
	_root.add_child(title)

	# === 文字框(对话区) ===
	var text_frame := Panel.new()
	text_frame.position = Vector2(40, 55)
	text_frame.size = Vector2(1000, 160)
	var tf_style := StyleBoxFlat.new()
	tf_style.bg_color = Color(0.02, 0.02, 0.04, 0.92)
	tf_style.border_color = Color(0.55, 0.35, 0.15)
	tf_style.set_border_width_all(2)
	tf_style.set_corner_radius_all(3)
	text_frame.add_theme_stylebox_override("panel", tf_style)
	_root.add_child(text_frame)

	_text_box = RichTextLabel.new()
	_text_box.position = Vector2(15, 10)
	_text_box.size = Vector2(970, 140)
	_text_box.bbcode_enabled = true
	_text_box.fit_content = true
	_text_box.add_theme_font_size_override("font_size", 20)
	_text_box.add_theme_font_size_override("normal_font_size", 20)
	_text_box.add_theme_font_size_override("bold_font_size", 20)
	_text_box.add_theme_font_size_override("italics_font_size", 20)
	_text_box.add_theme_font_size_override("mono_font_size", 20)
	_text_box.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	text_frame.add_child(_text_box)

	_continue_hint = Label.new()
	_continue_hint.text = "▼ 点击任意位置继续"
	_continue_hint.position = Vector2(800, 130)
	_continue_hint.size = Vector2(190, 22)
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue_hint.add_theme_font_size_override("font_size", 18)
	_continue_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	text_frame.add_child(_continue_hint)

	# === 状态面板(HP) ===
	# 玩家状态
	var p_stat := Panel.new()
	p_stat.position = Vector2(40, 230)
	p_stat.size = Vector2(340, 90)
	var ps_style := StyleBoxFlat.new()
	ps_style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	ps_style.border_color = Color(0.2, 0.4, 0.7)
	ps_style.set_border_width_all(2)
	ps_style.set_corner_radius_all(4)
	p_stat.add_theme_stylebox_override("panel", ps_style)
	_root.add_child(p_stat)

	var p_title := Label.new()
	p_title.text = "[ 玩家 ]"
	p_title.position = Vector2(10, 8)
	p_title.size = Vector2(320, 24)
	p_title.add_theme_font_size_override("font_size", 22)
	p_title.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	p_stat.add_child(p_title)

	_hp_bar_player = ColorRect.new()
	_hp_bar_player.position = Vector2(10, 38)
	_hp_bar_player.size = Vector2(320, 22)
	_hp_bar_player.color = Color(0.2, 0.7, 0.3)
	p_stat.add_child(_hp_bar_player)

	var p_hp_bg := ColorRect.new()
	p_hp_bg.position = Vector2(10, 38)
	p_hp_bg.size = Vector2(320, 22)
	p_hp_bg.color = Color(0.15, 0.15, 0.18)
	p_stat.move_child(p_hp_bg, p_stat.get_children().find(_hp_bar_player))

	var p_hp_lbl := Label.new()
	p_hp_lbl.name = "p_hp_lbl"
	p_hp_lbl.text = "HP: --/--"
	p_hp_lbl.position = Vector2(10, 64)
	p_hp_lbl.size = Vector2(320, 20)
	p_hp_lbl.add_theme_font_size_override("font_size", 18)
	p_hp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_p_hp_label = p_hp_lbl
	p_stat.add_child(p_hp_lbl)

	# 丧尸状态
	var z_stat := Panel.new()
	z_stat.position = Vector2(700, 230)
	z_stat.size = Vector2(340, 90)
	var zs_style := StyleBoxFlat.new()
	zs_style.bg_color = Color(0.12, 0.05, 0.05, 0.9)
	zs_style.border_color = Color(0.7, 0.2, 0.2)
	zs_style.set_border_width_all(2)
	zs_style.set_corner_radius_all(4)
	z_stat.add_theme_stylebox_override("panel", zs_style)
	_root.add_child(z_stat)

	var z_title := Label.new()
	z_title.text = "[ 丧尸 ]"
	z_title.position = Vector2(10, 8)
	z_title.size = Vector2(320, 24)
	z_title.add_theme_font_size_override("font_size", 22)
	z_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	z_stat.add_child(z_title)

	_hp_bar_zombie = ColorRect.new()
	_hp_bar_zombie.position = Vector2(10, 38)
	_hp_bar_zombie.size = Vector2(320, 22)
	_hp_bar_zombie.color = Color(0.8, 0.2, 0.2)
	z_stat.add_child(_hp_bar_zombie)

	var z_hp_bg := ColorRect.new()
	z_hp_bg.position = Vector2(10, 38)
	z_hp_bg.size = Vector2(320, 22)
	z_hp_bg.color = Color(0.15, 0.15, 0.18)
	z_stat.move_child(z_hp_bg, z_stat.get_children().find(_hp_bar_zombie))

	var z_hp_lbl := Label.new()
	z_hp_lbl.name = "z_hp_lbl"
	z_hp_lbl.text = "HP: --/--"
	z_hp_lbl.position = Vector2(10, 64)
	z_hp_lbl.size = Vector2(320, 20)
	z_hp_lbl.add_theme_font_size_override("font_size", 18)
	z_hp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_z_hp_label = z_hp_lbl
	z_stat.add_child(z_hp_lbl)

	# === QTE区域 ===
	var qte_area := Panel.new()
	qte_area.position = Vector2(140, 350)
	qte_area.size = Vector2(800, 100)
	var qte_style := StyleBoxFlat.new()
	qte_style.bg_color = Color(0.04, 0.04, 0.06, 0.92)
	qte_style.border_color = Color(0.35, 0.35, 0.4)
	qte_style.set_border_width_all(1)
	qte_style.set_corner_radius_all(4)
	qte_area.add_theme_stylebox_override("panel", qte_style)
	_root.add_child(qte_area)

	_qte_label = Label.new()
	_qte_label.text = ""
	_qte_label.position = Vector2(10, 5)
	_qte_label.size = Vector2(780, 24)
	_qte_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_label.add_theme_font_size_override("font_size", 22)
	_qte_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	qte_area.add_child(_qte_label)

	# QTE进度条背景
	_qte_bar_bg = ColorRect.new()
	_qte_bar_bg.position = Vector2(150, 42)
	_qte_bar_bg.size = Vector2(QTE_BAR_WIDTH, 28)
	_qte_bar_bg.color = Color(0.18, 0.14, 0.14)
	qte_area.add_child(_qte_bar_bg)

	# 左侧未命中区
	_qte_miss_left = ColorRect.new()
	_qte_miss_left.position = Vector2(150, 42)
	_qte_miss_left.size = Vector2(20, 28)
	_qte_miss_left.color = Color(0.5, 0.08, 0.05, 0.6)
	qte_area.add_child(_qte_miss_left)

	# 右侧未命中区
	_qte_miss_right = ColorRect.new()
	_qte_miss_right.position = Vector2(150 + QTE_BAR_WIDTH - 20, 42)
	_qte_miss_right.size = Vector2(20, 28)
	_qte_miss_right.color = Color(0.5, 0.08, 0.05, 0.6)
	qte_area.add_child(_qte_miss_right)

	# 命中区域 —— 黄色
	_qte_zone = ColorRect.new()
	_qte_zone.position = Vector2(150, 42)
	_qte_zone.size = Vector2(_qte_zone_width, 28)
	_qte_zone.color = Color(0.6, 0.5, 0.1, 0.5)
	qte_area.add_child(_qte_zone)

	# 完美/暴击区域 —— 绿色
	_qte_perfect_zone = ColorRect.new()
	_qte_perfect_zone.position = Vector2(150, 42)
	_qte_perfect_zone.size = Vector2(_qte_perfect_width, 28)
	_qte_perfect_zone.color = Color(0.15, 0.85, 0.2, 0.65)
	qte_area.add_child(_qte_perfect_zone)

	# 移动指针
	_qte_pointer = ColorRect.new()
	_qte_pointer.position = Vector2(150, 40)
	_qte_pointer.size = Vector2(10, 32)
	_qte_pointer.color = Color(0.95, 0.2, 0.12, 0.95)
	qte_area.add_child(_qte_pointer)

	# QTE提示文字（已移除）
	# var qte_hint := Label.new()

	# === 状态文字 ===
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.position = Vector2(40, 465)
	_status_label.size = Vector2(1000, 26)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 21)
	_root.add_child(_status_label)

	# 攻击按钮
	var atk_btn := Button.new()
	atk_btn.text = "攻击"
	atk_btn.position = Vector2(280, 505)
	atk_btn.size = Vector2(200, 48)
	atk_btn.add_theme_font_size_override("font_size", 25)
	atk_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	atk_btn.pressed.connect(_on_attack_button)
	atk_btn.name = "atk_btn"
	_root.add_child(atk_btn)

	# 物品按钮
	var item_btn := Button.new()
	item_btn.text = "物品"
	item_btn.position = Vector2(520, 505)
	item_btn.size = Vector2(200, 48)
	item_btn.add_theme_font_size_override("font_size", 25)
	item_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	item_btn.pressed.connect(_toggle_item_panel)
	item_btn.name = "item_btn"
	_root.add_child(item_btn)

	# 逃跑按钮
	var run_btn := Button.new()
	run_btn.text = "逃跑"
	run_btn.position = Vector2(760, 505)
	run_btn.size = Vector2(160, 48)
	run_btn.add_theme_font_size_override("font_size", 25)
	run_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	run_btn.pressed.connect(_on_try_flee)
	run_btn.name = "run_btn"
	_root.add_child(run_btn)

	# === 物品面板 ===
	_item_panel = Panel.new()
	_item_panel.position = Vector2(300, 360)
	_item_panel.size = Vector2(480, 220)
	var ip_style := StyleBoxFlat.new()
	ip_style.bg_color = Color(0.08, 0.08, 0.12, 0.97)
	ip_style.border_color = Color(0.4, 0.5, 0.7)
	ip_style.set_border_width_all(2)
	ip_style.set_corner_radius_all(6)
	_item_panel.add_theme_stylebox_override("panel", ip_style)
	_item_panel.visible = false
	_root.add_child(_item_panel)

	var item_title := Label.new()
	item_title.text = "—— 使用物品 ——"
	item_title.position = Vector2(10, 8)
	item_title.size = Vector2(460, 26)
	item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_title.add_theme_font_size_override("font_size", 22)
	item_title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_item_panel.add_child(item_title)

	var close_item_btn := Button.new()
	close_item_btn.text = "关闭"
	close_item_btn.position = Vector2(380, 185)
	close_item_btn.size = Vector2(90, 28)
	close_item_btn.add_theme_font_size_override("font_size", 20)
	close_item_btn.pressed.connect(func(): _item_panel.visible = false)
	_item_panel.add_child(close_item_btn)


func _process(delta: float) -> void:
	if _phase == Phase.ENDED:
		return

	# QTE
	if _qte_active:
		_qte_pos += _qte_speed * _qte_dir * delta
		if _qte_pos >= QTE_BAR_WIDTH:
			_qte_pos = QTE_BAR_WIDTH
			_qte_dir = -1.0
		elif _qte_pos <= 0:
			_qte_pos = 0
			_qte_dir = 1.0
		if _qte_pointer:
			_qte_pointer.position.x = 150 + _qte_pos


func _input(event: InputEvent) -> void:
	# QTE
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and _qte_active:
			_qte_active = false
			_on_qte_result()
			return
	# INTRO/对话阶段点击推进
	if _phase == Phase.INTRO:
		if (event is InputEventKey and event.pressed and event.keycode != KEY_ESCAPE) \
			or (event is InputEventMouseButton and event.pressed):
			_advance_intro()


# ==================== 开场对话 ====================

var _intro_step: int = 0

func _show_intro_text() -> void:
	_intro_step = 0
	_set_text("[color=orange][b]遭遇丧尸！[/b][/color]\n\n%s" % _zombie_text)
	_update_hp_display()
	_update_zombie_display()
	_hide_battle_ui()

func _advance_intro() -> void:
	_intro_step += 1
	match _intro_step:
		1:
			if _horror_text != "":
				_set_text("[i]%s[/i]" % _horror_text)
			else:
				_advance_intro()  # skip to next
		2:
			_set_text("[color=yellow]你紧张地咽了口唾沫...\n——必须做出选择——[/color]")
			_root.get_node_or_null("encounter_title").text = "—— 尝试逃跑 ——"
		3:
			_start_escape_qte()
		_:
			pass

func _hide_battle_ui() -> void:
	_qte_bar_bg.visible = false
	_qte_zone.visible = false
	_qte_perfect_zone.visible = false
	_qte_miss_left.visible = false
	_qte_miss_right.visible = false
	_qte_pointer.visible = false
	_qte_label.text = ""
	var atk_btn: Button = _root.get_node_or_null("atk_btn")
	if atk_btn: atk_btn.visible = false
	var item_btn: Button = _root.get_node_or_null("item_btn")
	if item_btn: item_btn.visible = false
	var run_btn: Button = _root.get_node_or_null("run_btn")
	if run_btn: run_btn.visible = false
	_status_label.text = ""

func _show_battle_ui() -> void:
	_qte_bar_bg.visible = true
	_qte_zone.visible = true
	_qte_perfect_zone.visible = true
	_qte_miss_left.visible = true
	_qte_miss_right.visible = true
	_qte_pointer.visible = true
	var atk_btn: Button = _root.get_node_or_null("atk_btn")
	if atk_btn: atk_btn.visible = true
	var item_btn: Button = _root.get_node_or_null("item_btn")
	if item_btn: item_btn.visible = true
	var run_btn: Button = _root.get_node_or_null("run_btn")
	if run_btn: run_btn.visible = true
	_item_panel.visible = false


# ==================== QTE ====================

func _start_escape_qte() -> void:
	_phase = Phase.ESCAPE_QTE
	_continue_hint.text = ""
	_qte_label.text = "[空格键逃跑]"
	_show_qte_visuals()
	# 逃跑QTE: 高速、宽区域
	_reset_qte_with_zones(441.0, 90.0, 22.0)


func _reset_qte_with_zones(speed: float, zone_w: float, perfect_w: float) -> void:
	"""重置QTE——设置速度、区域宽度、完美区宽度"""
	_qte_speed = speed
	_qte_pos = 0.0
	_qte_dir = 1.0
	_qte_active = true
	_qte_zone_width = zone_w
	_qte_perfect_width = perfect_w

	# 随机目标中心/命中区中心位置
	var bar_x: float = 150.0
	var min_center := zone_w / 2.0
	var max_center := QTE_BAR_WIDTH - zone_w / 2.0
	_qte_target_center = randf_range(min_center, max_center)

	# 设置命中区域位置
	_qte_zone.size = Vector2(zone_w, 28)
	_qte_zone.position.x = bar_x + _qte_target_center - zone_w / 2.0

	# 设置完美区域位置
	_qte_perfect_zone.size = Vector2(perfect_w, 28)
	_qte_perfect_zone.position.x = bar_x + _qte_target_center - perfect_w / 2.0

	# 设置左侧未命中区域
	_qte_miss_left.position.x = bar_x
	_qte_miss_left.size.x = maxf(1, _qte_zone.position.x - bar_x)

	# 设置右侧未命中区域
	_qte_miss_right.position.x = _qte_zone.position.x + zone_w
	_qte_miss_right.size.x = maxf(1, bar_x + QTE_BAR_WIDTH - _qte_miss_right.position.x)

	_qte_pointer.position = Vector2(bar_x, 40)


func _reset_qte(speed: float, zone_w: float, perfect_w: float) -> void:
	"""兼容旧接口"""
	_reset_qte_with_zones(speed, zone_w, perfect_w)


func _on_qte_result() -> void:
	if _is_battle_flee:
		_process_escape_result()
		return
	match _phase:
		Phase.ESCAPE_QTE:
			_process_escape_result()
		Phase.BATTLE:
			_process_attack_qte_result()


	# 以上函数已废弃，使用 _process_escape_result 统一处理


func _show_qte_visuals() -> void:
	_qte_bar_bg.visible = true
	_qte_zone.visible = true
	_qte_perfect_zone.visible = true
	_qte_miss_left.visible = true
	_qte_miss_right.visible = true
	_qte_pointer.visible = true


# ==================== 战斗系统 ====================

func _start_battle() -> void:
	_phase = Phase.BATTLE
	_show_battle_ui()
	_qte_label.text = " 第 %d 回合 —— 选择行动 " % _round_num
	_qte_active = false
	_status_label.text = "准备战斗..."
	_update_hp_display()
	_update_zombie_display()
	_set_text("[color=red]逃脱失败！丧尸向你扑来！[/color]\n\n")


func _on_attack_button() -> void:
	if _phase != Phase.BATTLE or _qte_active:
		return
	_set_text("[color=yellow]—— 瞄准攻击！[空格键确认] [/color]\n[color=gray]===QTE指针移动中===[/color]")
	_status_label.text = "QTE攻击中..."
	# 攻击QTE: 速度随危险等级增加，命中区50%
	var speed := 315.0 + _danger_level * 336.0  # 315~651
	var zone := 55.0
	var perf := 14.0
	_reset_qte_with_zones(speed, zone, perf)
	_qte_label.text = "QTE攻击 —— [空格键确认] "


func _process_attack_qte_result() -> void:
	if _phase != Phase.BATTLE:
		return

	# 计算QTE结果
	var ptr_center := _qte_pos
	var diff := absf(ptr_center - _qte_target_center)
	var base_dmg := _player_atk
	var multiplier := 0.3
	var grade := "未命中"

	if diff <= _qte_perfect_width / 2.0:
		# === 暴击 / 完美命中 ===
		multiplier = 1.5 + randf() * 0.5  # 150% ~ 200%
		grade = "暴击！"
	elif diff <= _qte_zone_width / 2.0:
		# === 普通命中 ===
		multiplier = 1.0 + randf() * 0.3  # 100% ~ 130%
		grade = "命中"
	else:
		# === 未命中 ===
		multiplier = 0.3
		grade = "未命中"

	var final_dmg := int(base_dmg * multiplier)
	if final_dmg < 1:
		final_dmg = 1

	_zombie_hp -= final_dmg
	var color_tag := "red" if multiplier >= 1.5 else ("yellow" if multiplier >= 0.8 else "gray")

	_set_text("[color=%s][b]%s[/b][/color]  造成[color=red]%d[/color]点伤害 (基础:%d × %.0f%%)" % [
		color_tag, grade, final_dmg, _player_atk, multiplier * 100.0])
	_status_label.text = "%s → 丧尸 -%d HP" % [grade, final_dmg]
	_update_zombie_display()

	await get_tree().create_timer(0.4).timeout

	# 检查丧尸是否死亡
	if _zombie_hp <= 0:
		_zombie_hp = 0
		_update_zombie_display()
		_set_text("[color=green][b]丧尸被击败了！[/b][/color]\n你松了一口气...")
		GameManager.add_kill()
		# 战利品掉落
		if randf() < 0.5:
			var loot_table := ["wood_stick", "steel_shard", "cloth", "glass_shard", "raw_meat"]
			var loot: String = loot_table[randi() % loot_table.size()]
			GameManager.add_item(loot)
			var loot_name: String = GameManager.ITEM_DATA.get(loot, {}).get("name", loot)
			_set_text(_get_text() + "\n[color=green]获得: %s[/color]" % loot_name)
		await get_tree().create_timer(0.75).timeout
		# 同步HP回GameManager
		GameManager.hp = _player_hp
		_end_encounter(false, false)
		return

	# 丧尸反击
	_zombie_counterattack()

	# 检查玩家是否死亡
	if _player_hp <= 0:
		_player_hp = 0
		GameManager.hp = 0
		_update_hp_display()
		_set_text("[color=red][b]你倒下了...[/b][/color]")
		await get_tree().create_timer(0.75).timeout
		_end_encounter(false, true)
		return

	_round_num += 1
	if _round_num > _max_rounds:
		# 超过最大回合，强制结束
		var flee_dmg := randi_range(8, 18)
		_player_hp = maxi(0, _player_hp - flee_dmg)
		GameManager.modify_hp(-flee_dmg)
		_set_text("[color=orange]战斗持续太久，你勉强脱身...\n受到 %d 点伤害[/color]" % flee_dmg)
		_update_hp_display()
		await get_tree().create_timer(0.75).timeout
		_end_encounter(true, false)
		return

	# 下一回合提示
	_qte_label.text = " 第 %d 回合 —— 选择行动 " % _round_num
	_status_label.text = "等待你的行动..."
	_set_text("[color=gray]第 %d/%d 回合 —— 丧尸还在逼近...[/color]" % [_round_num, _max_rounds])


func _zombie_counterattack() -> void:
	# 丧尸基础攻击力: 8~26 (随危险等级增加)
	var base_z_dmg := int(8 + _danger_level * 18)  # 8~26
	# 丧尸残血时攻击力下降
	var hp_ratio := float(_zombie_hp) / float(_zombie_max_hp)
	if hp_ratio < 0.3:
		base_z_dmg = int(base_z_dmg * 0.5)
	elif hp_ratio < 0.6:
		base_z_dmg = int(base_z_dmg * 0.75)

	var z_dmg: int = max(3, base_z_dmg + randi_range(-3, 5))
	_player_hp = max(0, _player_hp - z_dmg)
	GameManager.modify_hp(-z_dmg)
	_update_hp_display()

	_set_text(_get_text() + "\n\n[color=red]丧尸反击！你受到 %d 点伤害[/color]" % z_dmg)


func _toggle_item_panel() -> void:
	if _phase != Phase.BATTLE:
		return
	_item_panel.visible = not _item_panel.visible
	if _item_panel.visible:
		_refresh_item_list()


func _refresh_item_list() -> void:
	# 清空旧物品按钮
	for c in _item_panel.get_children():
		if c.name not in ["", "close"] and not (c is Label) and not (c is Button):
			c.queue_free()
	# 收集需要移除的物品行
	var to_remove := []
	for c in _item_panel.get_children():
		if c.has_method("get") and c.name != "":
			if c.name.begins_with("item_btn_") or c.name.begins_with("item_lbl_"):
				to_remove.append(c)
	for c in to_remove:
		c.queue_free()

	# 创建消耗品按钮
	var y_offset := 36
	var found_any := false
	for i in range(GameManager.inventory.size()):
		var item_data: Dictionary = GameManager.inventory[i]
		var item_id: String = item_data.get("id", "")
		var amount: int = item_data.get("amount", 0)
		var info: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
		if info.get("type", "") == "consumable":
			found_any = true
			var name: String = info.get("name", item_id)
			var effect: String = info.get("effect", "")
			var desc: String = info.get("desc", "")

			# 物品行面板
			var row := Panel.new()
			row.name = "item_row_%d" % i
			row.position = Vector2(10, y_offset)
			row.size = Vector2(460, 34)
			var r_style := StyleBoxFlat.new()
			r_style.bg_color = Color(0.1, 0.1, 0.14, 0.8)
			r_style.set_corner_radius_all(3)
			r_style.border_color = Color(0.3, 0.35, 0.45)
			r_style.set_border_width_all(1)
			row.add_theme_stylebox_override("panel", r_style)
			_item_panel.add_child(row)

			var lbl := Label.new()
			lbl.name = "item_lbl_%d" % i
			lbl.text = "%s x%d | %s" % [name, amount, desc]
			lbl.position = Vector2(8, 6)
			lbl.size = Vector2(310, 22)
			lbl.add_theme_font_size_override("font_size", 17)
			lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
			row.add_child(lbl)

			var use_btn := Button.new()
			use_btn.name = "item_btn_%d" % i
			use_btn.text = "使用"
			use_btn.position = Vector2(360, 4)
			use_btn.size = Vector2(85, 26)
			use_btn.add_theme_font_size_override("font_size", 17)
			use_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
			var idx := i  # capture
			use_btn.pressed.connect(func(): _use_consumable(idx))
			row.add_child(use_btn)

			y_offset += 38

	if not found_any:
		var empty_lbl := Label.new()
		empty_lbl.text = "没有可用的消耗品..."
		empty_lbl.position = Vector2(10, 50)
		empty_lbl.size = Vector2(460, 24)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 20)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_item_panel.add_child(empty_lbl)


func _use_consumable(inv_idx: int) -> void:
	if inv_idx < 0 or inv_idx >= GameManager.inventory.size():
		return
	var result: String = GameManager.use_item_by_index(inv_idx)
	# 同步HP
	_player_hp = GameManager.hp
	_player_hp = mini(_player_hp, _player_max_hp)
	_update_hp_display()
	_status_label.text = result
	_set_text("[color=cyan]%s[/color]" % result)
	_item_panel.visible = false

	# 检查玩家是否死亡
	if _player_hp <= 0:
		await get_tree().create_timer(0.5).timeout
		_end_encounter(false, true)
		return

	# 丧尸反击
	_zombie_counterattack()
	if _player_hp <= 0:
		_player_hp = 0
		GameManager.hp = 0
		_update_hp_display()
		_set_text(_get_text() + "\n[color=red]你倒下了...[/color]")
		await get_tree().create_timer(0.75).timeout
		_end_encounter(false, true)
		return

	_round_num += 1
	if _round_num > _max_rounds:
		var flee_dmg := randi_range(8, 18)
		_player_hp = maxi(0, _player_hp - flee_dmg)
		GameManager.modify_hp(-flee_dmg)
		_update_hp_display()
		_set_text("[color=orange]战斗太久，勉强脱身...受到 %d 点伤害[/color]" % flee_dmg)
		await get_tree().create_timer(0.75).timeout
		_end_encounter(true, false)
		return

	_qte_label.text = " 第 %d 回合 —— 选择行动 " % _round_num
	_status_label.text = "等待你的行动..."


var _is_battle_flee: bool = false  # 战斗中逃跑标记


func _on_try_flee() -> void:
	if _phase != Phase.BATTLE or _qte_active:
		return
	# 战斗中逃跑QTE
	_is_battle_flee = true
	_set_text("[color=yellow]—— 寻找逃跑机会！[空格键确认] [/color]")
	_status_label.text = "QTE逃跑中..."
	_reset_qte_with_zones(480.0, 50.0, 14.0)  # 逃跑区域更窄
	_qte_label.text = "QTE逃跑 —— [空格键确认]"


func _process_escape_result() -> void:
	# 计算指针位置 + 判定
	var ptr_center := _qte_pos
	var diff := absf(ptr_center - _qte_target_center)
	var in_perfect := diff <= _qte_perfect_width / 2.0
	var in_zone := diff <= _qte_zone_width / 2.0

	if _is_battle_flee:
		# === 战斗中逃跑判定 ===
		_is_battle_flee = false
		if in_perfect or in_zone:
			var dmg := randi_range(5, 15)
			_player_hp = max(0, _player_hp - dmg)
			GameManager.modify_hp(-dmg)
			_update_hp_display()
			_set_text("[color=yellow]成功逃脱！[/color]\n受到 %d 点伤害" % dmg)
			_status_label.text = ">>> 逃脱成功 <<<"
			GameManager.hp = _player_hp
			_qte_active = false
			await get_tree().create_timer(1).timeout
			_end_encounter(true, false)
		else:
			var fail_dmg := randi_range(10, 22)
			_player_hp = max(0, _player_hp - fail_dmg)
			GameManager.modify_hp(-fail_dmg)
			_update_hp_display()
			_set_text("[color=red]逃跑失败！[/color]\n受到 %d 点伤害" % fail_dmg)
			_status_label.text = "逃跑失败"
			await get_tree().create_timer(0.5).timeout
			if _player_hp <= 0:
				_end_encounter(false, true)
				return
			_round_num += 1
			if _round_num > _max_rounds:
				var flee_dmg2 := randi_range(8, 18)
				_player_hp = maxi(0, _player_hp - flee_dmg2)
				GameManager.modify_hp(-flee_dmg2)
				_update_hp_display()
				_set_text("[color=orange]战斗太久，勉强脱身...受到 %d 点伤害[/color]" % flee_dmg2)
				await get_tree().create_timer(0.75).timeout
				_end_encounter(true, false)
				return
			_qte_label.text = " 第 %d 回合 —— 选择行动 " % _round_num
			_status_label.text = "等待你的行动..."
	else:
		# === 开场逃跑QTE判定 ===
		if in_perfect:
			_set_text("[color=green][b]完美逃脱！[/b][/color]\n你没有受伤就甩掉了丧尸！")
			_status_label.text = ">>> 完美逃脱 <<<"
			_qte_active = false
			await get_tree().create_timer(0.25).timeout
			_end_encounter(true, false)
		elif in_zone:
			var dmg := randi_range(5, 12)
			GameManager.modify_hp(-dmg)
			_player_hp -= dmg
			_set_text("[color=yellow]勉强逃脱...[/color]\n受到 %d 点伤害" % dmg)
			_status_label.text = ">>> 逃脱(-%dHP) <<<" % dmg
			_update_hp_display()
			_qte_active = false
			await get_tree().create_timer(0.25).timeout
			_end_encounter(true, false)
		else:
			_set_text("[color=red][b]逃脱失败！[/b][/color]\n丧尸挡住了你的去路！")
			_status_label.text = ">>> 逃脱失败 <<<"
			_root.get_node_or_null("encounter_title").text = "—— 战斗开始 ——"
			_qte_active = false
			await get_tree().create_timer(0.75).timeout
			_start_battle()



# ==================== 结束遭遇 ====================

func _end_encounter(escaped: bool, dead: bool) -> void:
	_phase = Phase.ENDED
	_qte_active = false
	visible = false
	# 在 queue_free 之前禁用 _input/_process
	set_process(false)
	set_process_input(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	encounter_ended.emit(escaped, dead)
	queue_free()


# ==================== 辅助函数 ====================

func _set_text(text: String) -> void:
	_text_box.text = text

func _get_text() -> String:
	return _text_box.text if _text_box else ""

func _update_hp_display() -> void:
	if not _hp_bar_player or not is_instance_valid(_hp_bar_player):
		return
	var ratio := float(_player_hp) / float(_player_max_hp) if _player_max_hp > 0 else 0.0
	_hp_bar_player.size.x = 320.0 * clampf(ratio, 0.0, 1.0)
	# 根据血量比例改变颜色
	if ratio > 0.6:
		_hp_bar_player.color = Color(0.2, 0.7, 0.3)
	elif ratio > 0.3:
		_hp_bar_player.color = Color(0.8, 0.7, 0.2)
	else:
		_hp_bar_player.color = Color(0.8, 0.2, 0.2)

	if _p_hp_label and is_instance_valid(_p_hp_label):
		_p_hp_label.text = "生命: %d / %d    攻击力: %d" % [_player_hp, _player_max_hp, _player_atk]

func _update_zombie_display() -> void:
	if not _hp_bar_zombie or not is_instance_valid(_hp_bar_zombie):
		return
	var ratio := float(_zombie_hp) / float(_zombie_max_hp) if _zombie_max_hp > 0 else 0.0
	_hp_bar_zombie.size.x = 320.0 * clampf(ratio, 0.0, 1.0)

	if _z_hp_label and is_instance_valid(_z_hp_label):
		_z_hp_label.text = "生命: %d / %d" % [_zombie_hp, _zombie_max_hp]
