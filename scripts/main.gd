extends Node2D
## 主游戏场景——2D核心管理

signal _knock_dialog_signal  # 

@onready var player: CharacterBody2D = $Player
@onready var door_area: Area2D = $DoorArea
var door_sprite: Sprite2D = null  # 
@onready var cabinets_parent: Node2D = $Cabinets
@onready var bed_area: Area2D = $BedArea
@onready var bed_visual: ColorRect = $BedArea/BedVisual
@onready var room_npcs_parent: Node2D = $RoomNPCs
@onready var ui_layer: CanvasLayer = $UILayer
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
var furniture_parent: Node2D  # /

var time_paused: bool = false
var last_hour_floor: int = -1
var night_phase_started: bool = false
var _game_over_handling: bool = false  # 

# 
var _day_knock_count: int = 0  # 
var _night_knock_count: int = 0  # 
const MAX_DAY_KNOCKS: int = 6    # 6-11
const MAX_NIGHT_KNOCKS: int = 12   # 12
var _peephole_active: bool = false  # /
var _guest_house_full_knock_count: int = 0  # 2
var is_dialog_open: bool = false  # /player
var _knock_dialog_done: bool = false  # lambda
var _knock_processing: bool = false  # 
var _explore_returned: bool = false  # signallambda
var _explore_action: String = ""  # 
var _explore_guest_house_started: bool = false  # 
var _house_ended: bool = false  # 
var _house_action: String = ""  # 


func _set_dialog_locked(locked: bool) -> void:
	"""NPCQTE"""
	is_dialog_open = locked

var cabinet_configs: Array = [
	{"name": "食品柜", "pos": Vector2(80, 740), "items": ["food", "tomato"]},
	{"name": "衣物柜", "pos": Vector2(380, 740), "items": ["cloth", "cola"]},
	{"name": "工具柜", "pos": Vector2(680, 740), "items": ["wood_stick", "herb"]},
	{"name": "杂物柜", "pos": Vector2(230, 740), "items": ["glass_shard", "key"]},
]


func _ready() -> void:
	randomize()
	_setup_background()
	_connect_signals()
	_create_cabinets()
	_create_furniture()
	_spawn_mobile_controls()  # 移动端触控
	set_process(false)
	_show_start_screen()


func _spawn_mobile_controls() -> void:
	"""创建移动端虚拟摇杆层"""
	var mc := CanvasLayer.new()
	mc.name = "MobileControls"
	mc.set_script(load("res://scripts/components/mobile_controls.gd"))
	add_child(mc)


func _show_start_screen() -> void:
	# 
	set_process(false)
	GameManager.game_started = false
	# HUD
	if ui_layer.has_method("hide_hud"):
		ui_layer.hide_hud()
	#  StartLayer / GameOverScenequeue_free 
	for c in get_children():
		if c is CanvasLayer and c.name in ["StartLayer", "GameOverScene"]:
			c.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "StartLayer"; layer.layer = 1000
	add_child(layer)
	var start_scene: Node = load("res://scenes/start_screen.tscn").instantiate()
	layer.add_child(start_scene)


func _connect_signals() -> void:
	GameManager.npc_knocking.connect(_on_npc_knocking)
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.ending_triggered.connect(_on_ending)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.dream_triggered.connect(_on_dream_started)
	GameManager.dream_ended.connect(_on_dream_ended)
	if ui_layer.has_signal("npc_spawned"):
		ui_layer.npc_spawned.connect(_on_npc_spawned)


func _setup_background() -> void:
	# 
	var bg := Sprite2D.new()
	bg.name = "RoomBackground"
	add_child(bg)

	var wall_tex = load("res://assets/textures/wall4.png")
	if wall_tex:
		bg.texture = wall_tex
		bg.centered = true
		bg.position = Vector2(640, 360)
		var tex_size: Vector2 = wall_tex.get_size()
		bg.scale = Vector2(1280.0 / tex_size.x, 720.0 / tex_size.y) * 5.0
	else:
		push_warning("[main.gd] 未找到墙壁纹理资源")
	bg.modulate = Color(1, 1, 1, 1)
	bg.z_index = -10


func _on_dream_started() -> void:
	is_dialog_open = true


func _on_dream_ended() -> void:
	is_dialog_open = false


func start_new_game() -> void:
	GameManager.reset_game()
	# ===  ===
	#  ExploreScene 
	GameManager.is_exploring = false
	GameManager.is_in_guest_house = false
	#  ExploreScene
	for c in get_children():
		if c is Node2D and c.name == "ExploreScene":
			c.queue_free()
	#  Node2D 
	for c in get_children():
		if c is Node2D and c != player:
			c.visible = true
	if player:
		player.visible = true
	# ===  ===
	# 1.  CanvasLayer GameOverScene / StartLayer / EncounterSystem 
	#     UILayer  DialogueLayer UI 
	for c in get_children():
		if c is CanvasLayer and c.name != "UILayer" and c.name != "DialogueLayer":
			c.queue_free()
	# 2. 
	for c in dialogue_layer.get_children():
		c.queue_free()
	# 3.  NPC
	_clear_room_npcs()
	# 4. 
	_create_cabinets()
	_create_furniture()
	# 5. NPC
	_create_sister_npc()
	# 6.  = 
	if player:
		player.position = Vector2(576, 750)  #  ground_y 
		player.velocity = Vector2.ZERO
	# 6. 
	if door_sprite:
		door_sprite.modulate = Color.WHITE
		door_sprite.visible = true
	# ===  ===
	last_hour_floor = -1
	night_phase_started = false
	_day_knock_count = 0
	_night_knock_count = 0
	_knock_timer = 0.0
	_peephole_active = false
	is_dialog_open = false
	_game_over_handling = false
	time_paused = false
	# ===  HUD  ===
	GameManager.game_started = true
	if ui_layer.has_method("show_hud"):
		ui_layer.show_hud()
	GameManager.door_state_changed.emit(GameManager.door_hp, GameManager.door_max_hp, GameManager.door_reinforce_level)
	set_process(true)
	# ===  ===
	await _show_game_intro()
	# 1
	if has_node("/root/TutorialManager"):
		$"/root/TutorialManager".start_tutorial()


func resume_from_load() -> void:
	_clear_room_npcs()
	_create_cabinets_from_save()
	_create_furniture()
	_add_room_npc_nodes()
	# NPC
	_create_sister_npc()
	last_hour_floor = -1
	night_phase_started = GameManager.is_night()
	_day_knock_count = 0
	_night_knock_count = 0
	GameManager.game_started = true
	if ui_layer.has_method("show_hud"):
		ui_layer.show_hud()
	GameManager.door_state_changed.emit(GameManager.door_hp, GameManager.door_max_hp, GameManager.door_reinforce_level)
	set_process(true)


# ====================  ====================
var _knock_timer: float = 0.0
var _knock_interval: float = 8.0  # 8

func _process(delta: float) -> void:
	if GameManager.game_over:
		return
	_check_game_over()

	# 6-1112
	# is_dialog_open
	var can_knock_dialog: bool = not is_dialog_open or GameManager.is_in_guest_house
	if not GameManager.active_npc_data and not GameManager.is_horde_qte_active and can_knock_dialog and not _peephole_active:
		_knock_timer += delta
		if _knock_timer >= _knock_interval:
			_knock_timer = 0.0
			# 
			var ui_blocked: bool = false
			if ui_layer.has_method("has_any_popup_open"):
				ui_blocked = ui_layer.has_any_popup_open()
			if not ui_blocked:
				var is_night := GameManager.is_night()
				var current_count: int = _night_knock_count if is_night else _day_knock_count
				var max_count: int = MAX_NIGHT_KNOCKS if is_night else (6 + randi() % 6)  # 6-11

				if current_count < max_count:
					# 
					if GameManager.is_in_guest_house:
						_knock_interval = randf_range(12.0, 15.0)  # 12-15
					elif is_night:
						_knock_interval = randf_range(9.0, 15.0)  # 
					else:
						_knock_interval = randf_range(12.0, 25.0)  # 

				# 70%90%*0.7
				var trigger_chance: float = 0.7 if not is_night else 0.9
				if not GameManager.is_in_guest_house:
					trigger_chance *= 0.7
				# 2
				if GameManager.is_in_guest_house and _is_guest_house_room_full():
					if _guest_house_full_knock_count >= 2:
						trigger_chance = 0.0
				if randf() < trigger_chance:
					GameManager.trigger_knock()
					if GameManager.is_in_guest_house:
						_guest_house_full_knock_count += 1
					if is_night:
						_night_knock_count += 1
					else:
						_day_knock_count += 1
				else:
					# 
					_knock_interval = randf_range(60.0, 120.0)


func _after_action(hours_spent: float) -> void:
	var was_night := GameManager.is_night()
	var crossed := GameManager.consume_time(hours_spent)
	var is_now_night := GameManager.is_night()

	if crossed:
		# ——新的一天，NPC事件结算弹窗（不可点击关闭，仅按钮关闭）
		_on_new_day()

	if GameManager.is_midnight() and not crossed:
		if ui_layer.has_method("show_midnight_warning"):
			ui_layer.show_midnight_warning()

	if is_now_night and not was_night:
		night_phase_started = true
		GameManager.popup_message.emit("夜幕降临了...\n丧尸变得更加活跃")

	if not is_now_night and was_night:
		night_phase_started = false
		GameManager.popup_message.emit("一觉睡到天亮...\n")

	# 
	# 
	# 
	var can_knock_act: bool = not is_dialog_open or GameManager.is_in_guest_house
	var ui_blocked2: bool = false
	if ui_layer.has_method("has_any_popup_open"):
		ui_blocked2 = ui_layer.has_any_popup_open()
	if GameManager.is_night() and GameManager.door_cooldown <= 0 and not GameManager.active_npc_data and can_knock_act and not ui_blocked2:
		# cooldown 
		if _night_knock_count < MAX_NIGHT_KNOCKS:
			GameManager.door_cooldown = GameManager.DOOR_COOLDOWN_MAX
			GameManager.trigger_knock()
			_night_knock_count += 1
	# 
	elif not GameManager.is_night() and GameManager.door_cooldown <= 0 and not GameManager.active_npc_data and can_knock_act and not ui_blocked2:
		var day_max := 6 + randi() % 6
		if _day_knock_count < day_max and randf() < 0.60:
			GameManager.door_cooldown = GameManager.DOOR_COOLDOWN_MAX
			GameManager.trigger_knock()
			_day_knock_count += 1


# ====================  ====================
func _trigger_zombie_horde() -> void:
	var zlv := GameManager.zombie_level
	var difficulty := GameManager.get_door_difficulty()
	var rounds := clampi(zlv + 1, 2, 5)  # 

	GameManager.is_horde_qte_active = true
	GameManager.zombie_horde_triggered.emit(difficulty)

	# ===  ===
	var horde_warning := _create_horde_warning_ui()
	var ws_dict: Dictionary = horde_warning
	await get_tree().create_timer(3.0).timeout
	if GameManager.game_over:
		return
	# 
	var fade_tween := create_tween()
	var warning_label: Label = ws_dict["label"]
	var warning_bg: ColorRect = ws_dict["bg"]
	fade_tween.tween_property(warning_label, "modulate:a", 0.0, 0.5)
	fade_tween.parallel().tween_property(warning_bg, "color:a", 0.0, 0.5)
	await fade_tween.finished
	var warning_layer: CanvasLayer = ws_dict["layer"]
	if is_instance_valid(warning_layer):
		warning_layer.queue_free()
	await get_tree().process_frame

	GameManager.popup_message.emit("[color=red][b]遭遇丧尸 Lv.%d\n准备战斗！[/b][/color]\n 需要赢得 %d 回合" % [zlv, rounds])
	await get_tree().create_timer(1.5).timeout
	if GameManager.game_over:
		return

	# 
	var battle_scene: CanvasLayer = _create_battle_scene()
	add_child(battle_scene)
	await get_tree().process_frame  # 
	var wins: int = 0
	var total: int = rounds
	battle_scene.battle_finished.connect(func(w: int, t: int): wins = w; total = t)
	if battle_scene.has_method("start_battle"):
		battle_scene.start_battle(difficulty, rounds)
	await battle_scene.battle_finished
	var need := maxi(1, rounds - 1)

	if wins >= need:
		GameManager.popup_message.emit("[color=green]成功击退尸潮！\n安全屋守住了...[/color]")
		GameManager.add_kill()
		if randf() < 0.6:
			var loot_table := ["wood_stick", "steel_shard", "cloth", "glass_shard", "ammo", "raw_meat"]
			var loot: String = loot_table[randi() % loot_table.size()] as String
			GameManager.add_item(loot)
			var name: String = GameManager.ITEM_DATA.get(loot, {}).get("name", loot)
			GameManager.popup_message.emit("战利品: %s" % name)
	else:
		GameManager.damage_door(40 + zlv * 10)
		GameManager.modify_hp(-25 - zlv * 5)
		GameManager.modify_sanity(-30 - zlv * 5)
		GameManager.popup_message.emit("[color=red]尸潮突破了防线...\n你受到了严重伤害[/color]")
		if GameManager.door_hp <= 0:
			await get_tree().create_timer(1.0).timeout
			GameManager.trigger_game_over("大门被丧尸攻破了...")
	GameManager.is_horde_qte_active = false


func _create_battle_scene() -> CanvasLayer:
	var scene := CanvasLayer.new()
	scene.set_script(load("res://scripts/components/battle_scene.gd"))
	scene.name = "BattleScene"
	return scene


func _create_horde_warning_ui() -> Dictionary:
	"""UI {layer, bg, label}"""
	var layer := CanvasLayer.new()
	layer.name = "HordeWarningLayer"
	layer.layer = 200
	add_child(layer)

	var vp_size := get_viewport().get_visible_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.size = vp_size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var label := Label.new()
	label.text = "    丧尸来袭    "
	label.size = Vector2(vp_size.x, vp_size.y)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	label.add_theme_color_override("font_color", Color(1.0, 0.08, 0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)

	return {"layer": layer, "bg": bg, "label": label}


func _on_npc_knocking(npc_data: Dictionary) -> void:
	# 
	if _knock_processing:
		GameManager.active_npc_data = {}  # 
		return
	# ===  ===
	# npc_house_scene
	if (is_dialog_open or _peephole_active or GameManager.is_exploring) and not GameManager.is_in_guest_house:
		GameManager.active_npc_data = {}  # 
		return
	# /
	if ui_layer.has_method("has_any_popup_open") and ui_layer.has_any_popup_open() and not GameManager.is_in_guest_house:
		GameManager.active_npc_data = {}  # 
		return
	# →Q&A
	if GameManager.is_in_guest_house:
		# NPC/
		var house_ref = get_node_or_null("NpcHouseScene")
		if house_ref and (house_ref.is_ui_active or house_ref.block_all_interaction):
			GameManager.active_npc_data = {}  # 
			return
		_knock_processing = true
		_door_knock_effect()
		await _show_guest_house_knock_alert(npc_data)
		_knock_processing = false
		return

	# ""
	_knock_processing = true
	_door_knock_effect()
	await _show_knock_alert_dialog_inline(npc_data)
	_knock_processing = false


func _show_knock_alert_dialog_inline(npc_data: Dictionary) -> void:
	"""''''"""
	is_dialog_open = true

	# 
	for c in get_children():
		if c is CanvasLayer and c.name == "KnockAlertLayer":
			c.queue_free()
	# 
	for c in get_children():
		if c is CanvasLayer and c.name == "IgnoreKnockMsgLayer":
			c.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "KnockAlertLayer"
	layer.layer = 100
	add_child(layer)

	var dialog := Panel.new()
	dialog.name = "KnockAlertDialog"
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport().get_visible_rect()
	var pw := 420
	var ph := 220
	dialog.position = Vector2((vp.size.x - pw) / 2, (vp.size.y - ph) / 2)
	dialog.size = Vector2(pw, ph)

	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", ds)
	layer.add_child(dialog)

	# 
	var title := Label.new()
	title.text = "有人敲门"
	title.position = Vector2(0, 22); title.size = Vector2(pw, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	dialog.add_child(title)

	# 描述
	var desc := Label.new()
	desc.text = "谁会这个时候来访？"
	desc.position = Vector2(0, 62); desc.size = Vector2(pw, 28)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
	dialog.add_child(desc)

	_knock_dialog_done = false

	# 去门边 → 消耗1行动力
	var btn_go := Button.new()
	btn_go.text = "开门（消耗1行动点）"
	btn_go.position = Vector2((pw - 200) / 2, 110)
	btn_go.size = Vector2(200, 40)
	_set_simple_btn(btn_go, Color(0.18, 0.22, 0.28), Color(0.5, 0.52, 0.58))
	btn_go.add_theme_font_size_override("font_size", 20)
	dialog.add_child(btn_go)

	# 无视
	var btn_ignore := Button.new()
	btn_ignore.text = "装作不在家"
	btn_ignore.position = Vector2((pw - 160) / 2, 162)
	btn_ignore.size = Vector2(160, 36)
	_set_simple_btn(btn_ignore, Color(0.12, 0.12, 0.14), Color(0.4, 0.4, 0.42))
	btn_ignore.add_theme_font_size_override("font_size", 18)
	dialog.add_child(btn_ignore)

	btn_go.pressed.connect(func():
		if _knock_dialog_done: return
		_knock_dialog_done = true
		layer.queue_free()
		# 
		_start_peephole_from_knock(npc_data)
	)
	btn_ignore.pressed.connect(func():
		if _knock_dialog_done: return
		_knock_dialog_done = true
		layer.queue_free()
		is_dialog_open = false
		GameManager.active_npc_data = {}  # NPC
		_show_ignore_knock_message()
	)


	# 
	while not _knock_dialog_done:
		await get_tree().process_frame


func _start_peephole_from_knock(npc_data: Dictionary) -> void:
	""""""
	if _peephole_active:
		return
	if GameManager.active_npc_data.is_empty():
		return
	if GameManager.get_actions_left() < 1:
		GameManager.popup_message.emit("行动力不足，需要至少1点行动力")
		GameManager.active_npc_data = {}
		is_dialog_open = false
		return

	# is_dialog_open  true
	_peephole_active = true
	GameManager.consume_actions(1)

	var peephole_scene: Node = load("res://scripts/components/peephole_scene.gd").new()
	add_child(peephole_scene)
	peephole_scene.peephole_result.connect(_on_peephole_result)
	peephole_scene.start_peephole(npc_data)


func _show_ignore_knock_message() -> void:
	"""CanvasLayer """
	var msgs := [
		"装作不在家...希望对方快点离开",
		"你屏住呼吸，静静等待",
		"门外安静了下来...",
		"但愿不是什么危险的东西...",
	]
	var layer := CanvasLayer.new()
	layer.name = "IgnoreKnockMsgLayer"
	layer.layer = 99
	add_child(layer)

	var vp := get_viewport().get_visible_rect()
	var msg_label := Label.new()
	msg_label.text = msgs[randi() % msgs.size()]
	msg_label.position = Vector2(0, vp.size.y - 170)
	msg_label.size = Vector2(vp.size.x, 40)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 25)
	msg_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	msg_label.name = "IgnoreKnockMsg"
	layer.add_child(msg_label)

	await get_tree().create_timer(2.5).timeout
	if is_instance_valid(layer):
		layer.queue_free()


# ==================== Q&A ====================
func _show_guest_house_knock_alert(npc_data: Dictionary) -> void:
	""""""
	is_dialog_open = true
	# npc_house_sceneNPC
	var house_ref = get_node_or_null("NpcHouseScene")
	if house_ref:
		house_ref.block_all_interaction = true

	# 
	for c in get_children():
		if c is CanvasLayer and c.name == "GuestKnockAlertLayer":
			c.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "GuestKnockAlertLayer"
	layer.layer = 100
	add_child(layer)

	var dialog := Panel.new()
	dialog.name = "GuestKnockAlertDialog"
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var vp := get_viewport().get_visible_rect()
	var pw: int = 460
	dialog.position = Vector2((vp.size.x - pw) / 2, vp.size.y * 0.35)
	dialog.size = Vector2(pw, 220)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.35, 0.32, 0.28)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	dialog.add_theme_stylebox_override("panel", style)
	layer.add_child(dialog)

	var title := Label.new()
	title.text = "有人敲门"
	title.position = Vector2(20, 18)
	title.size = Vector2(pw - 40, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.6))
	dialog.add_child(title)

	var desc := Label.new()
	desc.text = "%s说门外有人...\n要不要去看看？(消耗1行动力)" % GameManager.guest_house_owner
	desc.position = Vector2(25, 62)
	desc.size = Vector2(pw - 50, 60)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 19)
	desc.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75))
	dialog.add_child(desc)

	var btn_container := HBoxContainer.new()
	btn_container.position = Vector2(30, 135)
	btn_container.size = Vector2(pw - 60, 50)
	dialog.add_child(btn_container)

	var go_btn := Button.new()
	go_btn.text = "去看看 (消耗1行动力)"
	go_btn.custom_minimum_size = Vector2(210, 44)
	go_btn.add_theme_font_size_override("font_size", 21)
	var g_style := StyleBoxFlat.new()
	g_style.bg_color = Color(0.22, 0.30, 0.22, 0.9)
	g_style.border_color = Color(0.45, 0.55, 0.40)
	g_style.set_border_width_all(1)
	g_style.set_corner_radius_all(8)
	go_btn.add_theme_stylebox_override("normal", g_style)
	go_btn.pressed.connect(_on_guest_knock_go_peephole.bind(layer, npc_data))
	btn_container.add_child(go_btn)

	var ignore_btn := Button.new()
	ignore_btn.text = "不管他"
	ignore_btn.custom_minimum_size = Vector2(180, 44)
	ignore_btn.add_theme_font_size_override("font_size", 21)
	var i_style := StyleBoxFlat.new()
	i_style.bg_color = Color(0.30, 0.22, 0.22, 0.9)
	i_style.border_color = Color(0.55, 0.38, 0.35)
	i_style.set_border_width_all(1)
	i_style.set_corner_radius_all(8)
	ignore_btn.add_theme_stylebox_override("normal", i_style)
	ignore_btn.pressed.connect(_on_guest_knock_ignore.bind(layer))
	btn_container.add_child(ignore_btn)

	_guest_knock_alert_done = false
	while not _guest_knock_alert_done:
		await get_tree().process_frame


var _guest_knock_alert_done: bool = false


func _on_guest_knock_go_peephole(layer: CanvasLayer, npc_data: Dictionary) -> void:
	"""''→Q&A"""
	if _guest_knock_alert_done:
		return
	_guest_knock_alert_done = true
	layer.queue_free()

	if GameManager.get_actions_left() < 1:
		GameManager.popup_message.emit("行动力不足，需要至少1点行动力")
		is_dialog_open = false
		# npc_house_scene
		var house_ref2 = get_node_or_null("NpcHouseScene")
		if house_ref2:
			house_ref2.block_all_interaction = false
		return

	_peephole_active = true
	is_dialog_open = true
	GameManager.consume_actions(1)

	# NPC
	GameManager.active_npc_data = npc_data.duplicate()

	var peephole_scene: Node = load("res://scripts/components/peephole_scene.gd").new()
	add_child(peephole_scene)
	peephole_scene.peephole_result.connect(_on_guest_house_peephole_result)
	peephole_scene.start_peephole(npc_data)


func _on_guest_knock_ignore(layer: CanvasLayer) -> void:
	"""''"""
	if _guest_knock_alert_done:
		return
	_guest_knock_alert_done = true
	layer.queue_free()
	# npc_house_scene
	var house_ref = get_node_or_null("NpcHouseScene")
	if house_ref:
		house_ref.block_all_interaction = false

	var msgs := [
		"还是不要多管闲事...",
		"让主人自己去处理吧",
	]
	for m in msgs:
		GameManager.popup_message.emit(m)
		await get_tree().create_timer(1.5).timeout

	is_dialog_open = false


func _on_guest_house_peephole_result(action: String, npc_data: Dictionary) -> void:
	"""npc_house_sceneNPC"""
	_peephole_active = false
	match action:
		"open":
			# npc_house_scene+
			var house_ref = get_node_or_null("NpcHouseScene")
			if house_ref and house_ref.has_method("accept_knocker"):
				await house_ref.accept_knocker(npc_data)
			is_dialog_open = false
		"killed":
			var kn: String = npc_data.get("name", "???")
			if kn in GameManager.killed_npcs:
				GameManager.popup_message.emit("[color=red]你杀害了 %s ...[/color]" % kn, 2.5)
			var house_ref2 = get_node_or_null("NpcHouseScene")
			if house_ref2:
				house_ref2.block_all_interaction = false
			GameManager.active_npc_data = {}
			is_dialog_open = false
		_:
			# reject / stay 等其他情况
			var result: Dictionary = GameManager.process_door_decision(false)
			GameManager.popup_message.emit(result.get("msg", ""))
			GameManager.active_npc_data = {}
			var house_ref3 = get_node_or_null("NpcHouseScene")
			if house_ref3:
				house_ref3.block_all_interaction = false
			GameManager.active_npc_data = {}
			is_dialog_open = false


func _on_knock_go_to_door() -> void:
	"""——"""
	pass


func _on_peephole_result(action: String, npc_data: Dictionary) -> void:
	""""""
	#  is_dialog_open  _peephole_active
	#  NPC npc_encounter_scene
	match action:
		"open":
			var enc_scene: Node = load("res://scripts/components/npc_encounter_scene.gd").new()
			add_child(enc_scene)
			enc_scene.encounter_result.connect(_on_encounter_result)
			enc_scene.start_encounter(npc_data)
		"killed":
			_peephole_active = false
			is_dialog_open = false
			var kn: String = npc_data.get("name", "???")
			if kn in GameManager.killed_npcs:
				GameManager.popup_message.emit("[color=red]你杀害了 %s ...[/color]" % kn, 2.5)
			GameManager.active_npc_data = {}
		_:
			# reject / stay 等其他情况
			is_dialog_open = false
			_peephole_active = false
			var result: Dictionary = GameManager.process_door_decision(false)
			GameManager.popup_message.emit(result.get("msg", ""))
			GameManager.active_npc_data = {}


func _on_encounter_result(action: String, npc_data: Dictionary = {}) -> void:
	""""""
	# NPC
	_peephole_active = false
	is_dialog_open = false

	match action:
		"recruit":
			# NPC process_door_decision 
			GameManager.active_npc_data = npc_data
			var result: Dictionary = GameManager.process_door_decision(true)
			# 
			if result.get("ok", true) and GameManager.get_room_npc_by_name(npc_data.get("name", "")):
				ui_layer.npc_spawned.emit(npc_data)
			GameManager.popup_message.emit(result.get("msg", ""))

		"stay":
			# NPC
			if GameManager.room_npcs.size() >= GameManager.MAX_ROOM_NPCS:
				GameManager.popup_message.emit("安全屋已满，最多容纳%d个NPC\n%s无奈地离开了。" % [GameManager.MAX_ROOM_NPCS, npc_data.get("name", "???")])
				return
			GameManager.active_npc_data = npc_data
			var result2: Dictionary = GameManager.process_door_decision(true)
			# 
			if result2.get("ok", true) and GameManager.get_room_npc_by_name(npc_data.get("name", "")):
				ui_layer.npc_spawned.emit(npc_data)
			GameManager.popup_message.emit(result2.get("msg", ""))

		"reject":
			GameManager.active_npc_data = npc_data
			var result3: Dictionary = GameManager.process_door_decision(false)
			GameManager.popup_message.emit(result3.get("msg", ""))

		"killed":
			# NPC
			var kn: String = npc_data.get("name", "???")
			if kn in GameManager.killed_npcs:
				GameManager.popup_message.emit("[color=red]你杀害了 %s ...[/color]" % kn, 2.5)

	GameManager.active_npc_data = {}
	is_dialog_open = false


func _show_game_intro() -> void:
	""""""
	is_dialog_open = true
	var layer := CanvasLayer.new()
	layer.name = "GameIntroLayer"
	layer.layer = 110
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.03, 0.95)
	bg.size = get_viewport().get_visible_rect().size
	layer.add_child(bg)

	var vs := get_viewport().get_visible_rect().size

	var title := Label.new()
	title.text = "—— 序章 ——"
	title.position = Vector2(0, vs.y * 0.06)
	title.size = Vector2(vs.x, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	layer.add_child(title)

	var lines := [
		"你在一间陌生的房间里醒来。",
		"",
		"窗外是死寂的城市，灰蒙蒙的天空下，",
		"街道上散落着废弃的车辆和杂物。",
		"远处偶尔传来低沉的嘶吼——那是丧尸。",
		"",
		"你不记得自己是怎么来到这里的。",
		"唯一知道的是，外面已经不安全了。",
		"",
		"这间屋子暂时是你的避风港——",
		"一扇铁门，几面墙壁，和角落里积灰的柜子。",
		"",
		"你摸了摸口袋，只有一点点食物和水。",
		"要活下去，你必须小心管理资源，",
		"做出每一个决定。",
		"",
		"[color=#ffcc00]点击屏幕或按 [空格键] 开始...[/color]",
	]

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = "\n".join(lines)
	text.fit_content = true
	text.size = Vector2(vs.x * 0.52, 0)
	text.position = Vector2(vs.x * 0.06, vs.y * 0.16)
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_color_override("default_color", Color(0.85, 0.82, 0.78))
	layer.add_child(text)

	# =====  =====
	var panel_x := vs.x * 0.60
	var panel_w := vs.x * 0.34
	var panel_h := vs.y * 0.72

	var tutorial_panel := Panel.new()
	tutorial_panel.position = Vector2(panel_x, vs.y * 0.16)
	tutorial_panel.size = Vector2(panel_w, panel_h)

	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.06, 0.05, 0.08, 0.85)
	tstyle.set_corner_radius_all(8)
	tstyle.set_border_width_all(1)
	tstyle.border_color = Color(0.25, 0.22, 0.18, 0.6)
	tutorial_panel.add_theme_stylebox_override("panel", tstyle)
	layer.add_child(tutorial_panel)

	var tut_title := Label.new()
	tut_title.text = "操作指南"
	tut_title.position = Vector2(12, 12)
	tut_title.size = Vector2(panel_w - 24, 32)
	tut_title.add_theme_font_size_override("font_size", 24)
	tut_title.add_theme_color_override("font_color", Color(0.9, 0.78, 0.45))
	tutorial_panel.add_child(tut_title)

	# 
	var sep2 := ColorRect.new()
	sep2.position = Vector2(12, 48)
	sep2.size = Vector2(panel_w - 24, 1)
	sep2.color = Color(0.15, 0.13, 0.1)
	tutorial_panel.add_child(sep2)

	var tut_text := RichTextLabel.new()
	tut_text.bbcode_enabled = true
	tut_text.position = Vector2(16, 58)
	tut_text.size = Vector2(panel_w - 32, panel_h - 74)
	tut_text.fit_content = false
	tut_text.scroll_active = false
	tut_text.add_theme_font_size_override("normal_font_size", 16)
	tut_text.add_theme_color_override("default_color", Color(0.72, 0.7, 0.65))

	tut_text.text = """[color=#ffcc66][b]移动[/b][/color]
PC: A / D  或  ← →   左右移动
手机: 左下角虚拟摇杆

[color=#ffcc66][b]交互[/b][/color]
PC: E 或  空格键   与物品/NPC/门互动
手机: 右下角 [交互] 按钮

[color=#ffcc66][b]NPC 互动[/b][/color]
PC: 鼠标左键   点击屋内 NPC
手机: 直接点击 NPC 角色
      可以选择对话、检查、交换物资等

[color=#ffcc66][b]背包与合成[/b][/color]
PC: I 键   打开/关闭背包
手机: 右下角 [背包] 按钮

[color=#ffcc66][b]通用[/b][/color]
空格键/点击  确认选择  /  跳过对话  /  QTE
ESC      关闭面板  /  切换全屏
[冲刺]按钮(手机)  按住加速移动

[color=#888888]
管理好食物、水和理智。
每一个选择都很重要。
活下去。
[/color]"""
	tutorial_panel.add_child(tut_text)

	# 
	var started := false
	while not started:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			started = true
		if Input.is_action_just_pressed("ui_cancel"):
			started = true
		# 移动端：点击屏幕任意位置也可开始
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or (OS.has_touchscreen_ui_hint() and Input.is_action_just_pressed("ui_touch")):
			started = true

	# 
	var tween := create_tween()
	tween.tween_property(bg, "color:a", 0.0, 0.8)
	tween.tween_callback(func():
		if is_instance_valid(layer):
			layer.queue_free()
		if is_instance_valid(bg):
			bg.queue_free()
	)
	await tween.finished

	is_dialog_open = false


func _is_guest_house_room_full() -> bool:
	""">=5"""
	var house_ref = get_node_or_null("NpcHouseScene")
	if house_ref and house_ref.has_method("get_room_npc_count"):
		return house_ref.get_room_npc_count() >= 5
	return false


func _door_knock_effect() -> void:
	if not is_instance_valid(door_sprite):
		return

	# 
	_play_knock_sound()

	# 
	var orig_x := door_sprite.position.x
	var tween := create_tween()
	tween.tween_property(door_sprite, "position:x", orig_x + 8.0, 0.08)
	tween.tween_property(door_sprite, "position:x", orig_x - 7.0, 0.08)
	tween.tween_property(door_sprite, "position:x", orig_x + 5.0, 0.06)
	tween.tween_property(door_sprite, "position:x", orig_x, 0.06)


func _play_knock_sound() -> void:
	var sound_path := "res://assets/sounds/qiaoqiao.wav"
	if not ResourceLoader.exists(sound_path):
		return
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = load(sound_path)
	audio_player.volume_db = 6.0  # +6dB
	add_child(audio_player)
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()


# ==================== () ====================
func on_explore(location_id: String) -> void:
	if GameManager.is_exploring or GameManager.game_over:
		return
	if GameManager.is_midnight():
		GameManager.popup_message.emit("午夜12点之后太危险了，不能外出")
		return

	var loc: Dictionary = GameManager.EXPLORE_LOCATIONS.get(location_id, {})
	if loc.is_empty():
		return

	var actions: int = loc.get("time_actions", 1)
	var remain := GameManager.get_actions_left()
	if remain < actions:
		GameManager.popup_message.emit("行动力不足，无法外出探索")
		return

	GameManager.is_exploring = true
	is_dialog_open = true  # 
	var loc_name: String = loc.get("name", "")

	# 
	_after_action(actions * GameManager.ACTION_HOURS)
	if GameManager.game_over:
		GameManager.is_exploring = false
		is_dialog_open = false
		return

	# === HUD++ ===
	# NPC
	for c in get_children():
		if c is Node2D and c != player:
			c.visible = false
	player.visible = false

	# 
	var explore_scene := Node2D.new()
	explore_scene.set_script(load("res://scripts/components/explore_scene.gd"))
	explore_scene.name = "ExploreScene"
	add_child(explore_scene)
	await get_tree().process_frame

	_explore_returned = false
	_explore_action = ""
	explore_scene.explore_ended.connect(func(act: String):
		_explore_returned = true
		_explore_action = act
	)

	#  enter_guest_house NPCHUD
	_explore_guest_house_started = false
	explore_scene.enter_guest_house.connect(func():
		_explore_guest_house_started = true
		_guest_house_full_knock_count = 0  # 
	)

	explore_scene.start_explore(loc)

	#   
	while not _explore_returned and not _explore_guest_house_started:
		await get_tree().process_frame

	# ===  NPC  ===
	if _explore_guest_house_started:
		# UICanvasLayer
		if is_instance_valid(explore_scene):
			for c in explore_scene.get_children():
				if c is CanvasLayer:
					c.queue_free()
		#  NPC 
		_explore_action = await _run_npc_house_scene(explore_scene)

	# 
	if _explore_action == "sleep" and GameManager.is_in_guest_house:
		await _sleep_to_morning()
		if GameManager.game_over:
			if is_instance_valid(explore_scene):
				explore_scene.queue_free()
			GameManager.is_exploring = false
			is_dialog_open = false
			return
		# /
		_explore_action = await _run_npc_house_scene(explore_scene)
		# 

	# ===  ===
	if is_instance_valid(explore_scene):
		explore_scene.queue_free()
	# NPC
	for c in get_children():
		if c is Node2D and c != player:
			c.visible = true
	player.visible = true
	GameManager.is_exploring = false
	is_dialog_open = false

	# 
	if _explore_action == "player_dead":
		return

	# 
	if _explore_action == "sleep":
		await _sleep_to_morning()
		return


# ==================== NPC  ====================
func _run_npc_house_scene(explore_ref: Variant) -> String:
	"""NPCHUD"""
	if not is_instance_valid(explore_ref):
		return ""
	# explore_scene
	for c in explore_ref.get_children():
		if c is Node2D or c is Camera2D:
			c.visible = false

	# NPC
	var npc_house := Node2D.new()
	npc_house.set_script(load("res://scripts/components/npc_house_scene.gd"))
	npc_house.name = "NpcHouseScene"
	add_child(npc_house)
	await get_tree().process_frame

	var house_action: String = ""
	_house_ended = false
	npc_house.house_ended.connect(func(act: String):
		_house_action = act
		_house_ended = true
	)

	# 
	var loc_data: Dictionary = explore_ref.location_data if explore_ref.has_method("get") else {}
	var owner_name: String = GameManager.guest_house_owner
	var npcs: Array = GameManager.guest_house_npcs.duplicate()

	# explore_scenelocation_data
	if explore_ref.has_method("location_data") or ("location_data" in explore_ref):
		pass
	# 
	if "location_data" in explore_ref and explore_ref.location_data is Dictionary:
		loc_data = explore_ref.location_data

	npc_house.start_house(loc_data, owner_name, npcs)

	# active_npc_data
	GameManager.active_npc_data = {}

	# 5 Timer 
	var entry_knock_timer := Timer.new()
	entry_knock_timer.one_shot = true
	entry_knock_timer.wait_time = 5.0
	entry_knock_timer.timeout.connect(func():
		if is_instance_valid(npc_house) and not _house_ended and not GameManager.active_npc_data:
			GameManager.trigger_knock()
		entry_knock_timer.queue_free()
	)
	npc_house.add_child(entry_knock_timer)
	entry_knock_timer.start()

	while not _house_ended:
		await get_tree().process_frame

	# NPC
	npc_house.queue_free()

	return _house_action


# ====================  ====================
func _on_guest_house_knock(npc_data: Dictionary) -> void:
	""""""
	if not GameManager.is_in_guest_house:
		return
	#  NPC npc_house_scene
	var house_ref = get_node_or_null("NpcHouseScene")
	if house_ref and house_ref.has_method("on_guest_knock"):
		house_ref.on_guest_knock(npc_data)
		return
	# 
	var ref = GameManager.explore_scene_ref
	if ref and ref.has_method("on_guest_knock"):
		ref.on_guest_knock(npc_data)


# ====================  ====================
func _create_cabinets() -> void:
	for c in cabinets_parent.get_children():
		cabinets_parent.remove_child(c)
		c.queue_free()
	GameManager.cabinet_items.clear()

	for cfg in cabinet_configs:
		var cab := Area2D.new()
		cab.name = cfg["name"]; cab.position = cfg["pos"]
		cab.add_to_group("cabinet")
		var col := CollisionShape2D.new()
		col.shape = RectangleShape2D.new()
		col.shape.size = Vector2(90, 90)
		cab.add_child(col)
		# 
		var cab_sprite := Sprite2D.new()
		cab_sprite.name = "CabinetSprite"
		var cab_tex: Texture2D = null
		if ResourceLoader.exists("res://assets/textures/guigui.png"):
			cab_tex = load("res://assets/textures/guigui.png")
		if cab_tex:
			cab_sprite.texture = cab_tex
			cab_sprite.scale = Vector2(0.25, 0.25)
			cab_sprite.position = Vector2(0, -45)
		else:
			# 无纹理后备
			var cab_bg: Panel = Panel.new()
			cab_bg.position = Vector2(-50, -65)
			cab_bg.size = Vector2(100, 30)
			cab_bg.self_modulate = Color(0.05, 0.05, 0.05, 0.9)
			var cb_style: StyleBoxFlat = StyleBoxFlat.new()
			cb_style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
			cb_style.border_color = Color(0.8, 0.8, 0.5)
			cb_style.set_border_width_all(1)
			cb_style.set_corner_radius_all(4)
			cab_bg.add_theme_stylebox_override("panel", cb_style)
			cab.add_child(cab_bg)
			var label := Label.new()
			label.text = "[" + cfg["name"] + "]"; label.position = Vector2(-45, -62)
			label.size = Vector2(90, 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 25)
			label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
			cab.add_child(label)
		cab.add_child(cab_sprite)
		cabinets_parent.add_child(cab)
		GameManager.cabinet_items[cab.get_instance_id()] = cfg["items"].duplicate(true)


func _create_cabinets_from_save() -> void:
	for c in cabinets_parent.get_children():
		cabinets_parent.remove_child(c)
		c.queue_free()
	var saved_items := GameManager.cabinet_items.duplicate()
	GameManager.cabinet_items.clear()
	var idx := 0
	for cfg in cabinet_configs:
		var cab := Area2D.new()
		cab.name = cfg["name"]; cab.position = cfg["pos"]
		cab.add_to_group("cabinet")
		var col := CollisionShape2D.new()
		col.shape = RectangleShape2D.new()
		col.shape.size = Vector2(90, 90)
		cab.add_child(col)
		# 
		var cab_sprite := Sprite2D.new()
		cab_sprite.name = "CabinetSprite"
		var cab_tex: Texture2D = null
		if ResourceLoader.exists("res://assets/textures/guigui.png"):
			cab_tex = load("res://assets/textures/guigui.png")
		if cab_tex:
			cab_sprite.texture = cab_tex
			cab_sprite.scale = Vector2(0.25, 0.25)
			cab_sprite.position = Vector2(0, -45)
		else:
			# 无纹理后备
			var cab_bg2: Panel = Panel.new()
			cab_bg2.position = Vector2(-50, -65)
			cab_bg2.size = Vector2(100, 30)
			cab_bg2.self_modulate = Color(0.05, 0.05, 0.05, 0.9)
			var cb2_style: StyleBoxFlat = StyleBoxFlat.new()
			cb2_style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
			cb2_style.border_color = Color(0.8, 0.8, 0.5)
			cb2_style.set_border_width_all(1)
			cb2_style.set_corner_radius_all(4)
			cab_bg2.add_theme_stylebox_override("panel", cb2_style)
			cab.add_child(cab_bg2)
			var label := Label.new()
			label.text = "[" + cfg["name"] + "]"; label.position = Vector2(-45, -62)
			label.size = Vector2(90, 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 25)
			label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
			cab.add_child(label)
		cab.add_child(cab_sprite)
		cabinets_parent.add_child(cab)
		var instance_id := cab.get_instance_id()
		var old_keys := saved_items.keys()
		if idx < old_keys.size():
			GameManager.cabinet_items[instance_id] = saved_items[old_keys[idx]]
		else:
			GameManager.cabinet_items[instance_id] = cfg["items"].duplicate(true)
		idx += 1


func on_cabinet_interact(cabinet: Area2D) -> void:
	var cid: int = cabinet.get_instance_id()
	if not GameManager.cabinet_items.has(cid):
		return
	var items: Array = GameManager.cabinet_items[cid]
	# ID
	if ui_layer.has_method("show_cabinet_panel"):
		ui_layer.show_cabinet_panel(cid, items)


# ==================== /() ====================
func _create_furniture() -> void:
	#  Furniture 
	if not furniture_parent:
		furniture_parent = Node2D.new()
		furniture_parent.name = "Furniture"
		add_child(furniture_parent)
	else:
		for c in furniture_parent.get_children():
			c.queue_free()

	# 储物箱
	var storage_obj := _make_furniture_obj("储物箱", Vector2(1140, 770), "storage_obj", Color(0.6, 0.4, 0.1))
	furniture_parent.add_child(storage_obj)

	# 工作台
	var craft_obj := _make_furniture_obj("工作台", Vector2(980, 770), "craft_obj", Color(0.4, 0.5, 0.6))
	furniture_parent.add_child(craft_obj)

	# 垃圾桶
	var trash_obj := _make_furniture_obj("垃圾桶", Vector2(830, 770), "trash_obj", Color(0.3, 0.7, 0.3))
	furniture_parent.add_child(trash_obj)

	# 小猫
	var cat_node := _create_cat_sprite()
	furniture_parent.add_child(cat_node)

	# menmen.png
	_setup_door_texture()


func _setup_door_texture() -> void:
	# []
	var old_door := door_area.get_node_or_null("DoorVisual") as ColorRect
	if old_door:
		old_door.visible = false
	var door_label := door_area.get_node_or_null("DoorLabel")
	if door_label:
		door_label.visible = false

	# 
	if not door_sprite or not is_instance_valid(door_sprite):
		door_sprite = Sprite2D.new()
		door_sprite.name = "DoorSprite"
		add_child(door_sprite)

	var door_tex = load("res://assets/textures/menmen.png")
	if not door_tex:
		door_tex = load("res://assets/textures/men.png")
	if door_tex:
		door_sprite.texture = door_tex
		door_sprite.scale = Vector2(0.18, 0.18)
		door_sprite.position = Vector2(1300, 640)
		door_sprite.z_index = -1


func _make_furniture_obj(name_str: String, pos: Vector2, group_name: String, label_color: Color) -> Area2D:
	var obj := Area2D.new()
	obj.name = name_str
	obj.position = pos
	obj.add_to_group(group_name)

	# 视觉方块（隐藏，只保留名字标签）
	var visual := ColorRect.new()
	visual.name = "Visual"
	visual.size = Vector2(110, 110)
	visual.position = Vector2(-55, -55)
	visual.color = label_color.darkened(0.3)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.visible = false
	obj.add_child(visual)

	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(110, 110)
	col.shape = rect_shape
	obj.add_child(col)

	# 名字标签背景
	var label_bg: Panel = Panel.new()
	label_bg.name = "LabelBg"
	label_bg.position = Vector2(-60, -80)
	label_bg.size = Vector2(120, 32)
	label_bg.self_modulate = Color(0.05, 0.05, 0.05, 0.9)
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	bg_style.border_color = label_color
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(4)
	label_bg.add_theme_stylebox_override("panel", bg_style)
	obj.add_child(label_bg)

	# 名字标签
	var label := Label.new()
	label.name = "NameLabel"
	label.text = "[%s]" % name_str
	label.position = Vector2(-55, -77)
	label.size = Vector2(110, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", label_color)
	obj.add_child(label)

	return obj


func _create_cat_sprite() -> Area2D:
	"""——"""
	var cat := Area2D.new()
	cat.name = "Cat"
	cat.position = Vector2(80, 750)  # 
	cat.add_to_group("cat_obj")
	cat.input_pickable = true
	# Godot 4: collision_mask  input_event
	cat.collision_layer = 4   # layer 3
	cat.collision_mask = 1    # mask layer 1

	# +
	var col := CollisionShape2D.new()
	col.position = Vector2(0, -38)
	var cat_shape := RectangleShape2D.new()
	cat_shape.size = Vector2(100, 85)
	col.shape = cat_shape
	cat.add_child(col)

	# catcat.png + Visuals
	var cat_visuals := Node2D.new()
	cat_visuals.name = "CatVisuals"
	cat.add_child(cat_visuals)

	var cat_sprite := Sprite2D.new()
	cat_sprite.name = "CatSprite"
	var cat_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/catcat.png"):
		cat_tex = load("res://assets/textures/catcat.png")
	elif ResourceLoader.exists("res://assets/textures/mao.png"):
		cat_tex = load("res://assets/textures/mao.png")
	if cat_tex:
		cat_sprite.texture = cat_tex
		cat_sprite.scale = Vector2(0.22, 0.22)
		cat_sprite.position = Vector2(0, -30)
		cat_visuals.add_child(cat_sprite)
	else:
		# 
		var body := ColorRect.new()
		body.name = "CatBody"
		body.size = Vector2(48, 36)
		body.position = Vector2(-24, -36)
		body.color = Color(0.85, 0.55, 0.25)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_visuals.add_child(body)
		# 
		var ear_l := ColorRect.new()
		ear_l.size = Vector2(13, 15)
		ear_l.position = Vector2(-22, -51)
		ear_l.color = Color(0.85, 0.55, 0.25)
		ear_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_visuals.add_child(ear_l)
		var ear_r := ColorRect.new()
		ear_r.size = Vector2(13, 15)
		ear_r.position = Vector2(9, -51)
		ear_r.color = Color(0.85, 0.55, 0.25)
		ear_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_visuals.add_child(ear_r)
		# 
		var eye_l := ColorRect.new()
		eye_l.size = Vector2(8, 8)
		eye_l.position = Vector2(-14, -28)
		eye_l.color = Color(0.1, 0.1, 0.1)
		eye_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_visuals.add_child(eye_l)
		var eye_r := ColorRect.new()
		eye_r.size = Vector2(8, 8)
		eye_r.position = Vector2(6, -28)
		eye_r.color = Color(0.1, 0.1, 0.1)
		eye_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_visuals.add_child(eye_r)
		# 
		var tail := ColorRect.new()
		tail.size = Vector2(22, 8)
		tail.position = Vector2(22, -24)
		tail.color = Color(0.75, 0.45, 0.2)
		tail.name = "Tail"
		tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cat_visuals.add_child(tail)

	# 
	var name_lbl := Label.new()
	name_lbl.text = "小猫"
	name_lbl.position = Vector2(-30, -74)
	name_lbl.size = Vector2(60, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat.add_child(name_lbl)

	# 
	cat.mouse_entered.connect(func():
		if not GameManager.game_over:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	)
	cat.mouse_exited.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	)

	#  → 
	cat.input_event.connect(func(_viewport, event, _shape_idx):
		if GameManager.game_over:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if ui_layer.has_method("_show_cat_panel"):
				ui_layer._show_cat_panel(cat.global_position)
	)

	# AI
	_start_cat_ai(cat)

	return cat


func on_storage_interact() -> void:
	if ui_layer.has_method("_toggle_storage"):
		ui_layer._toggle_storage()


func on_craft_interact() -> void:
	if ui_layer.has_method("_toggle_craft"):
		ui_layer._toggle_craft()

func on_trash_interact() -> void:
	if ui_layer.has_method("_toggle_trash"):
		ui_layer._toggle_trash()


# ====================  ====================
func on_door_interact() -> void:
	if GameManager.active_npc_data:
		#  → 
		_show_peephole_for_npc()
	else:
		_show_door_info_panel()


func _show_peephole_for_npc() -> void:
	""""""
	if _peephole_active or is_dialog_open or GameManager.is_exploring:
		return
	if GameManager.get_actions_left() < 1:
		GameManager.popup_message.emit("行动力不足，需要至少1点行动力")
		return
	is_dialog_open = true  # 
	_peephole_active = true
	GameManager.consume_actions(1)
	var peephole_scene: Node = load("res://scripts/components/peephole_scene.gd").new()
	add_child(peephole_scene)
	peephole_scene.peephole_result.connect(_on_peephole_result)
	peephole_scene.start_peephole(GameManager.active_npc_data)


func _show_door_info_panel() -> void:
	"""NPCCanvasLayer """
	for c in get_children():
		if c is CanvasLayer and c.name == "DoorInteractLayer":
			c.queue_free()
			break

	is_dialog_open = true

	var layer := CanvasLayer.new()
	layer.name = "DoorInteractLayer"
	layer.layer = 100
	add_child(layer)

	var vp := get_viewport().get_visible_rect()
	var pw := 400
	var ph := 300
	var panel := Panel.new()
	panel.name = "DoorInteractPanel"
	panel.position = Vector2((vp.size.x - pw) / 2, (vp.size.y - ph) / 2)
	panel.size = Vector2(pw, ph)

	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ds)
	layer.add_child(panel)

	# 
	var title := Label.new()
	title.text = "门"
	title.position = Vector2(0, 18)
	title.size = Vector2(pw, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	panel.add_child(title)

	# 状态
	var status := Label.new()
	status.text = "耐久 %d/%d    加固 Lv.%d" % [GameManager.door_hp, GameManager.door_max_hp, GameManager.door_reinforce_level]
	status.position = Vector2(0, 50)
	status.size = Vector2(pw, 24)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
	panel.add_child(status)

	var bw := pw - 80
	var bx := (pw - bw) / 2
	var by := 90
	var bs := 40
	var sp := 8

	# 
	var btn_reinforce := Button.new()
	btn_reinforce.text = "加固门（消耗1行动）"
	btn_reinforce.position = Vector2(bx, by)
	btn_reinforce.size = Vector2(bw, bs)
	_set_simple_btn(btn_reinforce, Color(0.18, 0.22, 0.28), Color(0.5, 0.52, 0.58))
	btn_reinforce.pressed.connect(_close_door_panel)
	btn_reinforce.pressed.connect(on_door_reinforce)
	panel.add_child(btn_reinforce)
	by += bs + sp

	# 
	var btn_explore := Button.new()
	btn_explore.text = "外出探索"
	btn_explore.position = Vector2(bx, by)
	btn_explore.size = Vector2(bw, bs)
	_set_simple_btn(btn_explore, Color(0.18, 0.22, 0.28), Color(0.5, 0.52, 0.58))
	btn_explore.pressed.connect(func(): _show_explore_picker(panel))
	panel.add_child(btn_explore)
	by += bs + sp

	# 
	var btn_repair := Button.new()
	btn_repair.text = "修理门（消耗1行动）"
	btn_repair.position = Vector2(bx, by)
	btn_repair.size = Vector2(bw, bs)
	_set_simple_btn(btn_repair, Color(0.18, 0.22, 0.28), Color(0.5, 0.52, 0.58))
	btn_repair.pressed.connect(_close_door_panel)
	btn_repair.pressed.connect(on_door_repair)
	panel.add_child(btn_repair)
	by += bs + sp

	# 
	var btn_close := Button.new()
	btn_close.text = "关闭"
	btn_close.position = Vector2(bx, by)
	btn_close.size = Vector2(bw, 36)
	_set_simple_btn(btn_close, Color(0.18, 0.22, 0.28), Color(0.5, 0.52, 0.58))
	btn_close.add_theme_font_size_override("font_size", 18)
	btn_close.pressed.connect(_close_door_panel)
	panel.add_child(btn_close)


func _set_simple_btn(btn: Button, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	var hover_s := style.duplicate()
	hover_s.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover_s)
	var pressed_s := style.duplicate()
	pressed_s.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_font_size_override("font_size", 20)


func _close_door_panel() -> void:
	for c in get_children():
		if c is CanvasLayer and c.name == "DoorInteractLayer":
			c.queue_free()
			break
	is_dialog_open = false


func _show_explore_picker(parent_panel: Panel) -> void:
	# 
	for c in parent_panel.get_children():
		if c is Button or c is Label:
			c.visible = false

	var parent_layer: CanvasLayer = parent_panel.get_parent() as CanvasLayer

	var pw := 400
	var title := Label.new()
	title.text = "选择探索地点"
	title.position = Vector2(0, 18)
	title.size = Vector2(pw, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	parent_panel.add_child(title)

	var bw := pw - 80
	var bx := (pw - bw) / 2
	var pos_y := 58
	for loc_id in GameManager.EXPLORE_LOCATIONS:
		var loc: Dictionary = GameManager.EXPLORE_LOCATIONS[loc_id]
		var btn := Button.new()
		btn.text = "%s  消耗%d行动" % [loc.get("name", loc_id), loc.get("time_actions", 1)]
		btn.position = Vector2(bx, pos_y)
		btn.size = Vector2(bw, 36)
		_set_simple_btn(btn, Color(0.16, 0.18, 0.26), Color(0.45, 0.48, 0.62))
		btn.pressed.connect(func():
			if is_instance_valid(parent_layer):
				parent_layer.queue_free()
			is_dialog_open = false
			on_explore(loc_id)
		)
		parent_panel.add_child(btn)
		pos_y += 42

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(bx, pos_y + 6)
	back_btn.size = Vector2(bw, 34)
	_set_simple_btn(back_btn, Color(0.12, 0.12, 0.14), Color(0.4, 0.4, 0.42))
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(func():
		#  call_deferred 
		_close_door_panel()
		await get_tree().process_frame
		if not is_dialog_open:
			_show_door_info_panel()
	)
	parent_panel.add_child(back_btn)


func on_door_reinforce() -> void:
	var msg: String = GameManager.reinforce_door()
	GameManager.popup_message.emit(msg)
	_after_action(0)


func on_door_repair() -> void:
	var msg: String = GameManager.repair_door()
	GameManager.popup_message.emit(msg)
	_after_action(0)


# ====================  ====================
func on_bed_interact() -> void:
	if GameManager.is_midnight():
		_sleep_to_morning()
	elif GameManager.is_night():
		_sleep_to_morning()
	else:
		GameManager.popup_message.emit("只有晚上才能睡觉...")


func _sleep_to_morning() -> void:
	# ===== 隐藏感染者变异——随机死一个NPC =====
	if not GameManager.is_in_guest_house:
		var hidden_result: Dictionary = GameManager.process_hidden_infected_night()
		if hidden_result["has_combat"]:
			# 显示变异事件文字
			for evt in hidden_result["events"]:
				GameManager.popup_message.emit(evt)
				await get_tree().create_timer(2.5).timeout
				if GameManager.game_over:
					return
			# 找一个非变异的NPC来杀
			var victim_name: String = ""
			var non_mutated: Array = []
			for npc2 in GameManager.room_npcs:
				if npc2.get("type", "") != "mutated" and npc2.get("type", "") != "hidden_infected":
					non_mutated.append(npc2)
			if non_mutated.size() > 0:
				var victim: Dictionary = non_mutated[randi() % non_mutated.size()]
				victim_name = victim.get("name", "???")
				GameManager.popup_message.emit("[color=red]%s来不及逃跑，被变异者杀死了。[/color]" % victim_name)
				await get_tree().create_timer(2.0).timeout
				if GameManager.game_over:
					return
			else:
				# 没有NPC可杀——玩家死
				var killer_name: String = hidden_result["names"][0] if hidden_result["names"].size() > 0 else "变异者"
				GameManager.popup_message.emit("[color=red]变异者攻击了你！你已经无处可逃...\n你被%s杀死了。[/color]" % killer_name)
				await get_tree().create_timer(2.0).timeout
				GameManager.trigger_game_over("你在睡梦中被%s杀死了..." % killer_name)
				return
			# 清理变异NPC和被害NPC
			var to_remove_all: Array = []
			for i in GameManager.room_npcs.size():
				var t: String = GameManager.room_npcs[i].get("type", "")
				var nm: String = GameManager.room_npcs[i].get("name", "")
				if t == "mutated" or (victim_name != "" and nm == victim_name):
					to_remove_all.append(i)
			to_remove_all.sort()
			to_remove_all.reverse()
			for idx in to_remove_all:
				GameManager.room_npcs.remove_at(idx)
			# 刷新NPC显示
			_clear_room_npcs()
			_add_room_npc_nodes()

	# 1
	await get_tree().create_timer(1.0).timeout
	if GameManager.game_over:
		return


	# ===== 梦境 =====
	GameManager.dream_triggered.emit()
	await GameManager.dream_ended  # 

	GameManager.current_hour = GameManager.MORNING_RESET
	GameManager.current_day += 1
	GameManager.actions_today = 0
	GameManager.must_sleep = false
	GameManager.reset_cat_daily()
	GameManager.reset_sister_daily()
	GameManager._update_zombie_level()
	GameManager.do_day_passive()
	GameManager.npcs_used_today.clear()
	GameManager.door_cooldown = 0.0
	night_phase_started = false
	_day_knock_count = 0
	_night_knock_count = 0
	_knock_timer = 0.0
	_knock_interval = 20.0  # 20
	GameManager.day_changed.emit(GameManager.current_day)
	GameManager.time_changed.emit(GameManager.current_day, GameManager.current_hour)
	GameManager.door_state_changed.emit(GameManager.door_hp, GameManager.door_max_hp, GameManager.door_reinforce_level)
	GameManager.popup_message.emit("--- 第 %d 天 ---\n丧尸等级: Lv.%d" % [GameManager.current_day, GameManager.zombie_level])
	if not GameManager.is_in_guest_house:
		_on_new_day()
	else:
		# NPC
		_day_knock_count = 0
		_night_knock_count = 0
		_guest_house_full_knock_count = 0
	
	# 10
	if not GameManager.is_in_guest_house:
		if GameManager.cat_days_without_food >= 1 and not GameManager.cat_dead:
			await get_tree().create_timer(15.0).timeout
			if GameManager.game_over:
				return
			GameManager.popup_message.emit("[color=red]小猫看起来很饿...它已经一天没吃东西了[/color]")
	
	# 20秒后有70%概率触发敲门
	if not GameManager.is_in_guest_house:
		await get_tree().create_timer(10.0).timeout
		if GameManager.game_over:
			return
		if randf() < 0.70:
			GameManager.popup_message.emit("—— 咚咚咚！")
			_door_knock_effect()
			await get_tree().create_timer(1.0).timeout
			if not GameManager.game_over:
				GameManager.trigger_knock()


# ==================== NPC ====================
func on_talk_to_room_npc(npc_node: Node2D) -> void:
	var npc_id := npc_node.get_instance_id()
	for rnpc in GameManager.room_npcs:
		if str(rnpc.get("_instance_id", "")) == str(npc_id):
			var msg := GameManager.talk_to_room_npc(rnpc)
			GameManager.popup_message.emit(msg)
			return
	GameManager.popup_message.emit("这个NPC看起来不想说话...")


func _on_npc_spawned(npc_data: Dictionary) -> void:
	"""NPCNPC"""
	call_deferred("_add_room_npc_nodes")


func _add_room_npc_nodes() -> void:
	_clear_room_npcs()
	# 5NPC
	var positions := [
		Vector2(250, 750), Vector2(420, 750), Vector2(600, 750),
		Vector2(780, 750), Vector2(960, 750),
	]
	var idx := 0
	for rnpc in GameManager.room_npcs:
		if idx >= positions.size() or idx >= GameManager.MAX_ROOM_NPCS:
			break
		var node := _create_room_npc_sprite(rnpc, positions[idx])
		room_npcs_parent.add_child(node)
		rnpc["_instance_id"] = node.get_instance_id()
		idx += 1


func _create_room_npc_sprite(rnpc: Dictionary, pos: Vector2) -> Node2D:
	"""NPC+——Area2D"""
	var click_area := Area2D.new()
	click_area.name = "RoomNPC_" + rnpc.get("name", "unknown")
	click_area.position = pos
	click_area.input_pickable = true
	# Godot 4  Area2D  input_eventcollision_mask 
	#  layer=3, mask=11
	click_area.collision_layer = 4  # layer 3
	click_area.collision_mask = 1   # mask layer 1 (/)

	# -150~0 + -182~-162
	var shape := CollisionShape2D.new()
	shape.position = Vector2(0, -85)  # NPC
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(120, 200)  # 
	shape.shape = rect_shape
	click_area.add_child(shape)

	var ntype: String = rnpc.get("type", "survivor")
	var name_text: String = rnpc.get("name", "???")

	# === NPC+ ===
	var body := ColorRect.new()
	body.size = Vector2(100, 150)
	body.position = Vector2(-50, -150)
	match ntype:
		"survivor":
			body.color = Color(0.25, 0.55, 0.3)   # =
		"imposter":
			body.color = Color(0.35, 0.35, 0.4)    # =
		"mutated":
			body.color = Color(0.6, 0.15, 0.1)      # =
		_:
			body.color = Color(0.45, 0.4, 0.3)
	body.name = "Body"
	click_area.add_child(body)

	# 
	var face := ColorRect.new()
	face.size = Vector2(44, 38)
	face.position = Vector2(-22, -130)
	face.color = Color(0.85, 0.75, 0.65, 0.9)
	face.name = "Face"
	click_area.add_child(face)

	# 
	var label := Label.new()
	if ntype == "mutated":
		label.text = name_text
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif ntype == "imposter":
		label.text = "? " + name_text
		label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.65))
	else:
		label.text = name_text
		label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	label.position = Vector2(-40, -182)
	label.add_theme_font_size_override("font_size", 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_area.add_child(label)

	# 
	click_area.mouse_entered.connect(func():
		if not GameManager.game_over:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	)
	click_area.mouse_exited.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	)

	#  → 
	var npc_name_ref: String = name_text
	click_area.input_event.connect(func(_viewport, event, _shape_idx):
		if GameManager.game_over:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_npc_interaction_menu(npc_name_ref, click_area.global_position)
	)

	# ===== NPC AI: + =====
	_start_npc_ai(click_area, pos)

	return click_area


var _npc_ai_timers: Dictionary = {}  # NPCID → {timer, state, origin}

# ========== NPC==========
var sister_npc: CharacterBody2D

func _start_npc_ai(npc_node: Node2D, origin_pos: Vector2) -> void:
	"""NPCAI"""
	var nid := npc_node.get_instance_id()
	_npc_ai_timers[nid] = {
		"timer": 0.0,
		"state": "idle",  # idle / walking
		"origin": origin_pos,
		"walk_target": origin_pos,
		"wait_time": randf_range(2.0, 5.0),  # 
		"walk_speed": randf_range(80.0, 120.0),  # 
	}
	# processtween
	_npc_ai_idle(npc_node)


func _npc_ai_idle(npc_node: Node2D) -> void:
	"""NPC"""
	if not is_instance_valid(npc_node):
		return
	var nid := npc_node.get_instance_id()
	if not _npc_ai_timers.has(nid):
		return

	var wait := randf_range(3.0, 8.0)
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(npc_node):
		return

	# 60%40%
	if randf() < 0.6:
		_npc_ai_walk(npc_node)
	else:
		_npc_ai_idle(npc_node)


func _npc_ai_walk(npc_node: Node2D) -> void:
	"""NPC"""
	if not is_instance_valid(npc_node):
		return
	var nid := npc_node.get_instance_id()
	if not _npc_ai_timers.has(nid):
		return

	var data: Dictionary = _npc_ai_timers[nid]
	var origin: Vector2 = data["origin"]

	# 
	var offset := Vector2(
		randf_range(-100.0, 100.0),
		0.0
	)
	var target: Vector2 = origin + offset

	# tween
	var tween := create_tween()
	tween.tween_property(npc_node, "position", target, randf_range(1.5, 3.0)).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		if is_instance_valid(npc_node):
			_npc_ai_idle(npc_node)
	)


# ===== AI:  =====
var _cat_origin: Vector2 = Vector2(80, 750)

func _start_cat_ai(cat_node: Area2D) -> void:
	"""AI"""
	_cat_origin = cat_node.position
	_cat_ai_idle(cat_node)


func _cat_ai_idle(cat_node: Area2D) -> void:
	""""""
	if not is_instance_valid(cat_node) or GameManager.cat_dead:
		return
	var wait := randf_range(1.5, 4.5)
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(cat_node) or GameManager.cat_dead:
		return
	# 70%30%
	if randf() < 0.7:
		_cat_ai_walk(cat_node)
	else:
		_cat_ai_idle(cat_node)


func _cat_ai_walk(cat_node: Area2D) -> void:
	""""""
	if not is_instance_valid(cat_node) or GameManager.cat_dead:
		return
	# 
	var offset := Vector2(
		randf_range(-160.0, 160.0),
		0.0
	)
	var target: Vector2 = _cat_origin + offset
	# 
	target.x = clampf(target.x, 40.0, 1180.0)
	target.y = _cat_origin.y  # 

	# 2.0~4.0
	var tween := create_tween()
	tween.tween_property(cat_node, "position", target, randf_range(2.0, 4.0)).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		if is_instance_valid(cat_node):
			_cat_ai_idle(cat_node)
	)


func _show_npc_interaction_menu(npc_name: String, npc_pos: Vector2) -> void:
	"""NPC /  /  / """
	# ui_layer
	if ui_layer.has_method("_show_npc_interact_panel"):
		ui_layer._show_npc_interact_panel(npc_name, npc_pos)


# ==================== NPCNPC====================
## NPC
var _sister_dialogue_lines: Array[String] = [
	"今天感觉怎么样？要好好照顾自己啊",
	"外面的世界越来越危险了...",
	"我好害怕...我们真的能活下去吗？",
	"谢谢你一直在保护我们...",
	"如果有一天我不在了...你一定要继续活下去",
	"你还记得爸妈的样子吗？我已经快忘了...",
	"别太勉强自己，休息也很重要",
	"有时候我会做噩梦...梦到门被撞开了...",
	"有你在身边，我感觉安心多了",
	"我们一起加油，一定能等到救援的！",
]
var _sister_chat_count: int = 0  # 


func _create_sister_npc() -> void:
	"""NPC——"""
	# 
	if is_instance_valid(sister_npc):
		sister_npc.queue_free()
		await get_tree().process_frame

	sister_npc = CharacterBody2D.new()
	sister_npc.name = "SisterNPC"
	sister_npc.position = Vector2(850, 750)  # 
	sister_npc.collision_layer = 0
	sister_npc.collision_mask = 0
	add_child(sister_npc)

	# ===  ===
	var visuals := Node2D.new()
	visuals.name = "Visuals"
	sister_npc.add_child(visuals)

	# === Sprite2D ===
	var portrait := Sprite2D.new()
	portrait.name = "Portrait"
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/sister_portrait.png"):
		tex = load("res://assets/textures/sister_portrait.png")
	elif ResourceLoader.exists("res://assets/textures/npc_2.png"):
		tex = load("res://assets/textures/npc_2.png")
	if tex:
		portrait.texture = tex
		portrait.scale = Vector2(0.25, 0.25)
		portrait.position = Vector2(0, -80)
		visuals.add_child(portrait)
	else:
		# 
		var body := ColorRect.new()
		body.name = "Body"
		body.size = Vector2(80, 130)
		body.position = Vector2(-40, -130)
		body.color = Color(0.85, 0.65, 0.75)
		visuals.add_child(body)

	# sister_npcvisuals
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "妹妹"
	name_label.position = Vector2(-30, -185)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.95))
	name_label.visible = true
	sister_npc.add_child(name_label)

	# ===  ===
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(80, 130)
	shape.shape = rect_shape
	shape.position = Vector2(0, -65)
	sister_npc.add_child(shape)

	# ===  ===
	var click_area := Area2D.new()
	click_area.name = "ClickArea"
	click_area.collision_layer = 4
	click_area.collision_mask = 1
	click_area.input_pickable = true

	var click_shape := CollisionShape2D.new()
	var click_rect := RectangleShape2D.new()
	click_rect.size = Vector2(120, 180)
	click_shape.shape = click_rect
	click_shape.position = Vector2(0, -85)
	click_area.add_child(click_shape)
	sister_npc.add_child(click_area)

	# 
	click_area.mouse_entered.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	)
	click_area.mouse_exited.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	)
	# 
	click_area.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_sister_clicked()
	)

	# AI
	_sister_ai_start()


# ========== AI ==========
var _sister_ai_target: Vector2 = Vector2.ZERO
var _sister_ai_idle: bool = true
var _sister_ai_speed: float = 60.0


func _sister_ai_start() -> void:
	"""AI"""
	var my_sister: CharacterBody2D = sister_npc
	_sister_ai_loop(my_sister)


func _sister_ai_loop(my_sister: CharacterBody2D) -> void:
	"""AI"""
	while is_instance_valid(my_sister):
		if randf() < 0.45:  # 45%
			_sister_ai_idle = true
			await get_tree().create_timer(randf_range(1.5, 5.0)).timeout
			if not is_instance_valid(my_sister):
				return
		else:  # 55%
			# x300~1050
			_sister_ai_target = Vector2(randf_range(300.0, 1050.0), my_sister.global_position.y)
			_sister_ai_idle = false

			# visuals
			var vis: Node2D = my_sister.get_node("Visuals")
			if _sister_ai_target.x > my_sister.global_position.x:
				vis.scale.x = abs(vis.scale.x)
			else:
				vis.scale.x = -abs(vis.scale.x)

			var walk_time := randf_range(2.0, 6.0)
			var elapsed := 0.0
			while elapsed < walk_time and is_instance_valid(my_sister):
				var dt := get_process_delta_time()
				if dt > 0.1:
					dt = 0.016
				elapsed += dt

				var current_pos: Vector2 = my_sister.global_position
				var dist: float = current_pos.distance_to(_sister_ai_target)
				if dist < 15.0:
					break  # 

				var dir: Vector2 = (_sister_ai_target - current_pos).normalized()
				my_sister.global_position += dir * _sister_ai_speed * dt

				# visuals
				var vis2: Node2D = my_sister.get_node("Visuals")
				if dir.x > 0.1:
					vis2.scale.x = abs(vis2.scale.x)
				elif dir.x < -0.1:
					vis2.scale.x = -abs(vis2.scale.x)

				await get_tree().process_frame


func _on_sister_clicked() -> void:
	""""""
	if not is_instance_valid(sister_npc) or is_dialog_open:
		return
	if GameManager.is_exploring:
		return  # 
	if GameManager.sister_dead:
		# 妹妹已经去世 — 显示面板（参考猫咪模式）
		if ui_layer.has_method("_show_sister_panel"):
			ui_layer._show_sister_panel(sister_npc.global_position)
		return

	# 
	if ui_layer.has_method("_show_sister_panel"):
		ui_layer._show_sister_panel(sister_npc.global_position)


func _clear_room_npcs() -> void:
	for n in room_npcs_parent.get_children():
		n.queue_free()


# ==================== (NPC) ====================
func _on_new_day() -> void:
	# 
	_day_knock_count = 0
	_night_knock_count = 0
	is_dialog_open = true  # 起床结算期间阻止敲门

	# === 收集所有消息 ===
	var report_lines: Array = []
	var has_event: bool = false

	# 标题
	report_lines.append("[center][color=#ffcc88]═══ 第 %d 天清晨 ═══[/color][/center]" % GameManager.current_day)
	report_lines.append("[center][color=#aaaaaa]丧尸等级: Lv.%d[/color][/center]" % GameManager.zombie_level)
	report_lines.append("")

	# NPC夜间事件
	var night_events: Array = GameManager.process_room_npc_events()
	if night_events.size() > 0:
		has_event = true
		report_lines.append("[color=#ccaa88]【屋内事件】[/color]")
		for ev in night_events:
			report_lines.append("  • %s" % ev)
		report_lines.append("")

	# NPC主动离开
	var kicked_msgs: Array = GameManager.get_kicked_npc_summary()
	if kicked_msgs.size() > 0:
		has_event = true
		for km in kicked_msgs:
			report_lines.append("  • %s" % km)
		report_lines.append("")

	# 突变NPC清理
	_cleanup_stale_mutated(report_lines)

	# NPC偷窃
	var theft_msg: String = GameManager.process_npc_theft()
	if theft_msg != "":
		has_event = true
		report_lines.append("[color=#ccaa88]【物品丢失】[/color]")
		report_lines.append("  • %s" % theft_msg)
		report_lines.append("")

	# 猫咪/妹妹状态（从day_report_messages收集）
	var daily_msgs: Array = GameManager.get_day_report_messages()
	if daily_msgs.size() > 0:
		has_event = true
		report_lines.append("[color=#ccaa88]【警示】[/color]")
		for dm in daily_msgs:
			report_lines.append("  • %s" % dm)
		report_lines.append("")
	GameManager.clear_day_report_messages()

	# 如果没有特殊事件，添加一条平安消息
	if not has_event:
		report_lines.append("[color=#88aa88]今夜平安无事。[/color]")

	# === 显示持久弹窗 ===
	_show_new_day_report(report_lines)


func _show_new_day_report(lines: Array) -> void:
	"""起床结算持久弹窗：不可点击外部关闭，只能在底部按关闭按钮关闭"""
	# 先清理旧的结算层
	for c in get_children():
		if c is CanvasLayer and c.name == "NewDayReportLayer":
			c.queue_free()

	var layer := CanvasLayer.new()
	layer.name = "NewDayReportLayer"
	layer.layer = 300
	add_child(layer)

	# 半透明暗色背景（不响应点击，不关闭）
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.size = get_viewport().get_visible_rect().size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	var vp := get_viewport().get_visible_rect()
	var pw := 520
	var ph := 520
	var panel := Panel.new()
	panel.position = Vector2((vp.size.x - pw) / 2, (vp.size.y - ph) / 2 - 20)
	panel.size = Vector2(pw, ph)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.07, 0.09, 0.97)
	ps.set_border_width_all(2)
	ps.border_color = Color(0.3, 0.28, 0.22)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	layer.add_child(panel)

	# 滚动区
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 14)
	scroll.size = Vector2(pw - 40, ph - 70)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.04, 0.03, 0.05, 0.0)
	scroll.add_theme_stylebox_override("panel", ss)
	panel.add_child(scroll)

	var text_label := RichTextLabel.new()
	text_label.name = "ReportText"
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_following = true
	text_label.selection_enabled = false
	text_label.add_theme_font_size_override("normal_font_size", 17)
	text_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	scroll.add_child(text_label)

	text_label.text = "\n".join(lines)

	# 关闭按钮（唯一关闭方式）
	var close_btn := Button.new()
	close_btn.text = "关闭    ✓"
	close_btn.size = Vector2(160, 38)
	close_btn.position = Vector2((pw - 160) / 2, ph - 48)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	var cbs := StyleBoxFlat.new()
	cbs.bg_color = Color(0.1, 0.15, 0.12)
	cbs.set_border_width_all(1)
	cbs.border_color = Color(0.3, 0.55, 0.4)
	cbs.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", cbs)
	var cbh := cbs.duplicate()
	cbh.bg_color = Color(0.15, 0.25, 0.18)
	cbh.border_color = Color(0.4, 0.7, 0.5)
	close_btn.add_theme_stylebox_override("hover", cbh)
	close_btn.pressed.connect(func():
		if is_instance_valid(layer):
			is_dialog_open = false
			# 刷新NPC节点
			_clear_room_npcs()
			_add_room_npc_nodes()
			layer.queue_free()
	)
	panel.add_child(close_btn)


func _cleanup_stale_mutated(morning_msgs: Array) -> void:
	"""NPC"""
	var to_remove: Array = []
	for i in GameManager.room_npcs.size():
		if GameManager.room_npcs[i].get("type", "") == "mutated":
			var name: String = GameManager.room_npcs[i].get("name", "???")
			morning_msgs.append("[color=red]%s已经彻底变异，在避难所里发狂了。[/color]" % name)
			to_remove.append(i)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		GameManager.room_npcs.remove_at(idx)


func _on_day_changed(day: int) -> void:
	GameManager.popup_message.emit("--- 第 %d 天 ---\n丧尸等级: Lv.%d" % [day, GameManager.zombie_level])


func _on_time_changed(_day: int, _hour: float) -> void:
	pass


# ====================  ====================
func _check_game_over() -> void:
	if GameManager.hp <= 0:
		GameManager.trigger_game_over("你的生命值耗尽了...")
	elif GameManager.sanity <= 0:
		GameManager.trigger_game_over("精神崩溃了...再也无法承受这个末日世界")
	elif GameManager.hunger <= 0:
		# 饥饿会扣血，hp<=20时死亡
		GameManager.trigger_game_over("饥饿而死...在这末日中，食物比武器更重要")


func _on_ending(ending_id: String, data: Dictionary) -> void:
	"""5"""
	set_process(false)
	# 
	for c in dialogue_layer.get_children():
		c.queue_free()
	for c in get_children():
		if c is CanvasLayer and c.name != "UILayer" and c.name != "DialogueLayer":
			c.queue_free()
	# 
	var es: CanvasLayer = CanvasLayer.new()
	es.set_script(load("res://scripts/components/ending_scene.gd"))
	es.name = "EndingScene"
	add_child(es)
	await get_tree().process_frame
	es.start_ending(ending_id, data)
	await es.ending_done
	# 
	_show_start_screen()


func _on_game_over(day: int, hour: float, reason: String, kills: int) -> void:
	#  emit
	if _game_over_handling:
		return
	_game_over_handling = true
	set_process(false)
	# UI
	if ui_layer.has_method("_close_sister_panel"):
		ui_layer._close_sister_panel()
	is_dialog_open = false
	# 
	for c in dialogue_layer.get_children():
		c.queue_free()
	#  CanvasLayer
	for c in get_children():
		if c is CanvasLayer and c.name != "UILayer" and c.name != "DialogueLayer":
			c.queue_free()
	# 
	var go_scene: CanvasLayer = CanvasLayer.new()
	go_scene.set_script(load("res://scripts/components/game_over_scene.gd"))
	go_scene.name = "GameOverScene"
	add_child(go_scene)
	await get_tree().process_frame
	go_scene.start_game_over(reason, day, hour, kills)
	# 
	var action: String = ""
	go_scene.game_over_action.connect(func(a: String): action = a)
	await go_scene.game_over_action
	if action == "menu":
		# 
		_game_over_handling = false
		_show_start_screen()
	elif action.begins_with("load_"):
		_game_over_handling = false
		var slot := int(action.split("_")[1])
		if ui_layer.has_method("_load_from_slot"):
			ui_layer._load_from_slot(slot)
	else:
		#  → 
		_game_over_handling = false
		_show_start_screen()
