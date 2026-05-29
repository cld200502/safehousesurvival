extends Node2D
##  —— +
class_name ExploreScene

signal explore_ended(action: String)  # "return_home" / "stay"
signal explore_loot_found(item_id: String, item_name: String)
signal enter_guest_house  # NPCHUD

# 
var room_type: String = ""
var location_data: Dictionary = {}
var furniture_list: Array = []
var furniture_looted: Dictionary = {}
var room_npcs: Array = []
var owner_name: String = ""
var has_looted: bool = false
var kicked_out: bool = false
var steal_attempted: bool = false
var npc_extort_chance: float = 0.35
var owner_answered: int = 0
var zombie_encountered: bool = false

# 
@onready var player: CharacterBody2D = $Player
@onready var furniture_parent: Node2D = $Furniture
@onready var npc_parent: Node2D = $NPCs
@onready var door_area: Area2D = $DoorArea
@onready var msg_label: RichTextLabel = $MessageLabel
@onready var title_label: Label = $TitleLabel
@onready var interact_cooldown: float = 0.0
var camera: Camera2D  # 
var is_ui_active: bool = false  # UI
var _popup_result: Variant = -1  # int for choice, String for yesno
var _popup_done: bool = false  # lambda 
var _free_reply_result: String = ""  # lambda
var _free_reply_done: bool = false  # lambda

#  lambda  CONFUSABLE_CAPTURE_REASSIGNMENT 
var _encounter_escaped: bool = false
var _encounter_player_dead: bool = false
var _mode_selected: String = ""
var _mode_chosen: bool = false
var _qa_chosen: bool = false
var _qa_chosen_text: String = ""
var _qa_chosen_good: bool = false
var _knock_q_done: bool = false
var _knock_current_question: String = ""
var _knock_judge_done: bool = false
var _knock_correct: int = 0
var _free_input_result: String = ""
var _furn_player_dead: bool = false

# 
var _abandoned_furn_panel: Panel = null
var _current_abandoned_furn: Dictionary = {}

# 
const room_left: float = 80.0
const room_right: float = 1200.0
const ground_y: float = 620.0
const interact_range: float = 90.0

const ROOM_COLORS := {
	"abandoned": Color(0.1, 0.08, 0.06, 1.0),
	"occupied": Color(0.09, 0.08, 0.12, 1.0),
}


func _ready() -> void:
	z_index = 10
	name = "ExploreScene"


# ===  ===
func _build_scene(room_type_str: String) -> void:
	#  queue_free +  free()/queue_free() 
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame
	# 
	player = null
	furniture_parent = null
	npc_parent = null
	door_area = null
	msg_label = null
	title_label = null
	camera = null
	# 
	furniture_list.clear()
	# 
	has_looted = false
	kicked_out = false
	zombie_encountered = false

	# === UI ===
	var screen_blocker := ColorRect.new()
	screen_blocker.name = "ScreenBlocker"
	screen_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_blocker.color = ROOM_COLORS.get(room_type_str, Color(0.04, 0.03, 0.02))
	add_child(screen_blocker)

	# ===  ===
	# 
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = ROOM_COLORS.get(room_type_str, Color(0.04, 0.03, 0.02))
	bg.size = Vector2(1600, 900)
	bg.position = Vector2(-200, -300)
	add_child(bg)

	# 
	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.position = Vector2(-200, ground_y + 10)
	floor_rect.size = Vector2(1600, 4)
	floor_rect.color = Color(0.25, 0.22, 0.18)
	add_child(floor_rect)

	# 
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.position = Vector2(room_left - 40, -280)
	title_label.size = Vector2(1280, 30)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	add_child(title_label)

	# 
	furniture_parent = Node2D.new()
	furniture_parent.name = "Furniture"
	add_child(furniture_parent)

	# NPC
	npc_parent = Node2D.new()
	npc_parent.name = "NPCs"
	add_child(npc_parent)

	# 
	_create_player()

	# 
	_create_camera()

	# 
	_create_door_area()

	# 
	_place_furniture()

	# NPC
	if room_type_str == "occupied":
		_draw_guest_npcs()

	# === UICanvasLayer ===
	var ui_canvas := CanvasLayer.new()
	ui_canvas.name = "ExploreUI"
	ui_canvas.layer = 10
	add_child(ui_canvas)

	msg_label = RichTextLabel.new()
	msg_label.name = "MessageLabel"
	msg_label.position = Vector2(0, get_viewport().get_visible_rect().size.y - 200)  # 
	msg_label.size = Vector2(get_viewport().get_visible_rect().size.x, 70)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.bbcode_enabled = true
	msg_label.add_theme_font_size_override("font_size", 26)
	msg_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	ui_canvas.add_child(msg_label)

	# 
	_abandoned_furn_panel = Panel.new()
	_abandoned_furn_panel.name = "AbandonedFurnPanel"
	_abandoned_furn_panel.position = Vector2(290, 115)
	_abandoned_furn_panel.size = Vector2(700, 500)
	_abandoned_furn_panel.self_modulate = Color(0.06, 0.06, 0.08, 0.97)
	_abandoned_furn_panel.visible = false
	ui_canvas.add_child(_abandoned_furn_panel)


func _create_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(640.0, ground_y)
	player.collision_layer = 1
	player.collision_mask = 0

	var body_rect := ColorRect.new()
	body_rect.name = "BodyRect"
	body_rect.size = Vector2(70, 120)
	body_rect.position = Vector2(-35, -120)
	body_rect.color = Color(0.3, 0.65, 0.35)
	player.add_child(body_rect)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = "你"
	name_label.position = Vector2(-20, -145)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	player.add_child(name_label)

	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(70, 120)
	col.shape = rect_shape
	col.position = Vector2(0, -60)
	player.add_child(col)

	add_child(player)


func _create_camera() -> void:
	# Camera2D  player  remote_path
	camera = Camera2D.new()
	camera.name = "ExploreCamera"
	camera.zoom = Vector2(1.0, 1.0)
	camera.offset = Vector2(0, -150)
	# player  _create_player  add_child  player 
	if is_instance_valid(player):
		player.add_child(camera)
		camera.make_current()
	else:
		add_child(camera)
		call_deferred("_bind_camera_to_player")


func _bind_camera_to_player() -> void:
	# fallback:  player  player 
	if is_instance_valid(player) and is_instance_valid(camera) and camera.get_parent() != player:
		camera.reparent(player)
		camera.make_current()


func _create_door_area() -> void:
	door_area = Area2D.new()
	door_area.name = "DoorArea"
	door_area.position = Vector2(1160, ground_y)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, 120)
	col.shape = rect
	col.position = Vector2(0, -60)
	door_area.add_child(col)

	var marker := ColorRect.new()
	marker.color = Color(0.35, 0.25, 0.15, 0.8)
	marker.size = Vector2(30, 100)
	marker.position = Vector2(-15, -100)
	door_area.add_child(marker)

	var label := Label.new()
	label.text = "回屋"
	label.position = Vector2(-30, -125)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	door_area.add_child(label)

	add_child(door_area)


func _place_furniture() -> void:
	var furniture_names: Array = location_data.get("furniture", ["kitchen_cabinet", "storage_box"])
	var display_names := {
		"kitchen_cabinet": "厨房柜", "bedroom_drawer": "卧室抽屉",
		"storage_box": "储物箱", "workbench": "工作台",
		"cabinet_a": "A柜", "cabinet_b": "B柜",
		"desk": "书桌", "pharmacy_cabinet": "药房柜",
		"medical_cabinet": "医疗柜", "bookshelf": "书架",
		"sofa": "沙发", "shop_counter": "商店柜台",
		"storage_room": "储藏室", "display_shelf": "陈列架",
		"back_office": "后室", "gardening_shed": "园艺棚",
		"dorm_cabinet": "宿舍柜",
	}

	# 
	var positions: Array = [200.0, 420.0, 640.0, 860.0]
	furniture_list.clear()

	for i: int in range(min(furniture_names.size(), positions.size())):
		var fname: String = furniture_names[i]
		var disp_name: String = display_names.get(fname, fname)
		var fx: float = positions[i]

		var furn_area := Area2D.new()
		furn_area.name = "Furniture_" + fname
		furn_area.position = Vector2(fx, ground_y - 50)

		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(80, 100)
		col.shape = rect
		col.position = Vector2(0, -50)
		furn_area.add_child(col)

		# 
		var vis := ColorRect.new()
		vis.color = Color(0.25, 0.2, 0.12, 0.9)
		vis.size = Vector2(60, 80)
		vis.position = Vector2(-30, -80)
		if room_type == "occupied":
			vis.color = Color(0.18, 0.2, 0.28, 0.9)
		furn_area.add_child(vis)

		var furn_label := Label.new()
		furn_label.text = disp_name
		furn_label.position = Vector2(-60, -100)
		furn_label.size = Vector2(120, 20)
		furn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		furn_label.add_theme_font_size_override("font_size", 14)
		furn_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.5))
		furn_area.add_child(furn_label)

		furniture_parent.add_child(furn_area)
		furniture_list.append({
			"name": fname, "looted": false, "stolen": false,
			"node": furn_area, "label": furn_label, "vis": vis, "disp_name": disp_name
		})


func _draw_guest_npcs() -> void:
	for c in npc_parent.get_children():
		c.queue_free()

	var positions: Array = [200.0, 310.0, 420.0, 530.0, 640.0, 750.0, 860.0, 970.0]
	for i: int in range(min(room_npcs.size(), positions.size())):
		var npc_data: Dictionary = room_npcs[i]
		_create_npc_node(npc_data, positions[i])


func _create_npc_node(npc_data: Dictionary, fx: float) -> void:
	var npc_area := Area2D.new()
	npc_area.name = "NPC_" + npc_data["name"]
	var start_pos := Vector2(fx, ground_y)
	npc_area.position = start_pos

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 110)
	col.shape = rect
	col.position = Vector2(0, -55)
	npc_area.add_child(col)

	# 
	var body := ColorRect.new()
	body.size = Vector2(50, 80)
	body.position = Vector2(-25, -80)
	match npc_data.get("type", "survivor"):
		"survivor": body.color = Color(0.25, 0.55, 0.3)
		"imposter": body.color = Color(0.35, 0.35, 0.4)
		_: body.color = Color(0.45, 0.4, 0.3)
	npc_area.add_child(body)

	var name_lbl := Label.new()
	name_lbl.text = npc_data["name"]
	if npc_data.get("is_owner", false):
		name_lbl.text += " [屋主]"
		name_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	name_lbl.position = Vector2(-50, -100)
	name_lbl.size = Vector2(100, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	npc_area.add_child(name_lbl)

	# 
	npc_area.input_pickable = true
	npc_area.input_event.connect(_on_npc_clicked.bind(npc_data))

	npc_parent.add_child(npc_area)

	# NPCAI
	_start_guest_npc_ai(npc_area, start_pos)


func _start_guest_npc_ai(npc_node: Node2D, origin: Vector2) -> void:
	"""NPCAI"""
	if not is_instance_valid(npc_node):
		return
	var wait_time := randf_range(2.0, 6.0)
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(npc_node) or kicked_out or GameManager.game_over:
		return

	# 
	var offset_x := randf_range(-120.0, 120.0)
	var target := Vector2(clamp(origin.x + offset_x, room_left + 50, room_right - 50), ground_y)

	var tween := create_tween()
	tween.tween_property(npc_node, "position", target, randf_range(1.5, 3.0)).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		if is_instance_valid(npc_node) and not kicked_out:
			_start_guest_npc_ai(npc_node, npc_node.position)
	)


func _on_npc_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, npc_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if kicked_out:
			return
		_on_talk_to_guest_npc(npc_data)


# ===  &  ===
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or kicked_out or GameManager.game_over or is_ui_active or GameManager.is_in_guest_house:
		return

	interact_cooldown -= delta

	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		var sprint: float = 2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		player.velocity.x = input_dir * 280.0 * sprint
	else:
		player.velocity.x = 0
	player.velocity.y = 0
	player.move_and_slide()

	# 
	player.global_position.x = clamp(player.global_position.x, room_left - 200, room_right + 200)
	player.global_position.y = ground_y

	if Input.is_action_just_pressed("interact") and interact_cooldown <= 0:
		interact_cooldown = 0.3
		_try_interact()


func _try_interact() -> void:
	# 1. 
	if door_area and player.global_position.distance_to(door_area.global_position) < interact_range:
		_on_door_return_home()
		return

	# 2. 
	for furn in furniture_list:
		# 
		if room_type != "abandoned" and furn.get("looted", false):
			continue
		var n: Area2D = furn.get("node")
		if not is_instance_valid(n):
			continue
		if player.global_position.distance_to(n.global_position) < interact_range:
			_on_furniture_interact(furn)
			return

	# 3. 附近没有可互动的东西
	_show_msg("附近没有可以互动的东西...")


func _on_furniture_interact(furn: Dictionary) -> void:
	if kicked_out:
		return
	is_ui_active = true  # 
	if room_type == "occupied":
		await _occupied_furniture_interact(furn)
	else:
		_show_abandoned_furn_panel(furn)
	is_ui_active = false


# ===  ===
func start_explore(loc_data: Dictionary) -> void:
	location_data = loc_data
	# 60%——60%""40%/60%
	if location_data.get("room_type", "abandoned") == "abandoned" and randf() < 0.6:
		location_data["room_type"] = "occupied"
		#  owner_names 
		if not location_data.has("owner_names") or location_data["owner_names"].size() == 0:
			var default_owners = ["老张", "李阿姨", "小王", "陈叔", "刘姐", "赵大爷", "孙师傅", "周婶", "吴大哥", "郑姐"]
			default_owners.shuffle()
			location_data["owner_names"] = default_owners.slice(0, randi_range(2, 4))
	room_type = location_data.get("room_type", "abandoned")
	zombie_encountered = false
	has_looted = false
	owner_answered = 0
	kicked_out = false
	steal_attempted = false

	# _go_explore → _enter_xxx → _build_scene
	is_ui_active = true

	# UIbuild_scene
	var tmp_canvas := CanvasLayer.new()
	tmp_canvas.name = "TmpTransition"
	tmp_canvas.layer = 10
	add_child(tmp_canvas)

	var tmp_bg := ColorRect.new()
	tmp_bg.color = Color(0.04, 0.03, 0.02, 1.0)
	tmp_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	tmp_canvas.add_child(tmp_bg)

	var tmp_msg := RichTextLabel.new()
	tmp_msg.name = "TmpMsg"
	tmp_msg.position = Vector2(0, get_viewport().get_visible_rect().size.y - 120)
	tmp_msg.size = Vector2(get_viewport().get_visible_rect().size.x, 80)
	tmp_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tmp_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tmp_msg.bbcode_enabled = true
	tmp_msg.add_theme_font_size_override("font_size", 30)
	tmp_msg.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	tmp_canvas.add_child(tmp_msg)
	msg_label = tmp_msg

	_show_msg("你来到了 %s ..." % loc_data.get("name", ""))
	await get_tree().create_timer(1.0).timeout

	if GameManager.game_over:
		return

	# *0.7
	if randf() < loc_data.get("danger", 0.4) * 0.7:
		zombie_encountered = true
		await _zombie_encounter_before_enter()
		if GameManager.game_over:
			return
	else:
		_show_msg(loc_data.get("desc", "..."))
		await get_tree().create_timer(2.0).timeout

	if GameManager.game_over:
		return

	# UI
	if is_instance_valid(tmp_canvas):
		tmp_canvas.queue_free()

	if room_type == "abandoned":
		await _enter_abandoned_house()
	else:
		await _enter_occupied_house()


# ===  ===
func _enter_abandoned_house() -> void:
	#   CanvasLayer 
	_cleanup_all_popups()

	# UIbuild_scene
	var trans_ui := _create_transition_ui()
	_show_msg("正在前往 %s..." % location_data.get("name", ""))
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(trans_ui):
		trans_ui.queue_free()
	_build_scene("abandoned")
	# 
	is_ui_active = false


# ===  ===
func _enter_occupied_house() -> void:
	#   CanvasLayer 
	_cleanup_all_popups()

	# UI+
	var trans_ui := _create_transition_ui()

	_show_msg("你走在破败的街道上，四周死寂无声...")
	await get_tree().create_timer(1.5).timeout

	var owner_names = location_data.get("owner_names", [""])
	# 
	if owner_names.is_empty() or (owner_names.size() == 1 and str(owner_names[0]) == ""):
		owner_names = []
		for npc in GameManager.npc_pool:
			owner_names.append(npc["name"])
		owner_names.shuffle()
	# 
	var valid_names: Array = []
	for n in owner_names:
		if str(n).strip_edges() != "":
			valid_names.append(n)
	if valid_names.is_empty():
		valid_names = ["陌生人"]
	owner_name = valid_names[randi() % valid_names.size()]
	location_data["owner_names"] = owner_names

	_show_msg("前方出现了一间屋子，门缝里透出微弱的灯光。")
	await get_tree().create_timer(1.5).timeout
	_show_msg("你犹豫片刻，还是敲了敲门...")
	await get_tree().create_timer(1.5).timeout
	_show_msg("\"%s\"的声音从门后传来：\"谁？！\"" % owner_name)
	await get_tree().create_timer(1.0).timeout

	# NPC对话——随机选择额外台词
	var extra_lines: Array = [
		"你听到屋里有窸窸窣窣的声音，像是有人在翻找什么...",
		"\"%s\"：\"等一下...我穿个外套。\"" % owner_name,
		"沉重的脚步声在门后徘徊，越来越近...",
		"门锁\"咔嗒\"响了一声——\"%s\"似乎在犹豫要不要开门" % owner_name,
		"你听到屋里有人在小声嘀咕，听不清在说什么...",
		"\"%s\"：\"你...你是一个人吗？\"" % owner_name,
		"透过门缝，你能感觉到一道目光正冷冷地打量着你",
		"屋里传来拖动重物的声音，像是有人在搬东西堵门...",
		"\"%s\"：\"这么晚了...你到底是谁？\"" % owner_name,
		"你隐约听到屋里有人在低声啜泣...",
		"猫眼的光忽明忽暗——\"%s\"正透过猫眼仔细审视你" % owner_name,
		"\"%s\"：\"你是从外面来的？外面...还有丧尸吗？\"" % owner_name,
	]
	extra_lines.shuffle()
	var num_extra := randi() % 3 + 1
	for i in range(min(num_extra, extra_lines.size())):
		_show_msg(extra_lines[i])
		await get_tree().create_timer(2.0 + randf() * 1.0).timeout

	# UI msg_label 
	if is_instance_valid(trans_ui):
		trans_ui.queue_free()
	await get_tree().process_frame  #  queue_free 

	# 
	is_ui_active = true

	# === HUD ===
	var accepted: bool = await _run_peephole_qna()

	if not accepted:
		# UI
		var reject_ui := CanvasLayer.new()
		reject_ui.name = "RejectMsg"
		reject_ui.layer = 120
		add_child(reject_ui)
		var reject_bg := ColorRect.new()
		reject_bg.color = Color(0.03, 0.02, 0.02, 0.95)
		reject_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		reject_ui.add_child(reject_bg)
		var reject_label := Label.new()
		reject_label.text = "%s" % owner_name
		reject_label.position = Vector2(0, get_viewport().get_visible_rect().size.y / 2 - 20)
		reject_label.size = Vector2(get_viewport().get_visible_rect().size.x, 40)
		reject_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reject_label.add_theme_font_size_override("font_size", 26)
		reject_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		reject_ui.add_child(reject_label)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(reject_ui):
			reject_ui.queue_free()

		# 屋主拒绝后：提供选择——返回安全屋 或 换个地方继续探索（消耗1行动点）
		var choice := await _show_choice_dialog("屋主拒绝了你，你打算怎么做？", ["返回安全屋", "换个地方继续探索"])
		match choice:
			0:
				_cleanup_all_popups()
				is_ui_active = false
				explore_ended.emit("return_home")
				return
			1:
				# 换个地方继续探索需要消耗1行动点
				if GameManager.get_actions_left() < 1:
					_show_msg("行动点不足，只能返回安全屋...")
					_cleanup_all_popups()
					is_ui_active = false
					explore_ended.emit("return_home")
					return
				_cleanup_all_popups()
				await _refresh_room()
				return
			_:
				# 
				is_ui_active = false
				explore_ended.emit("return_home")
				return

	# ——
	var enter_ui := CanvasLayer.new()
	enter_ui.name = "EnterHouseMsg"
	enter_ui.layer = 120
	add_child(enter_ui)
	var enter_bg := ColorRect.new()
	enter_bg.color = Color(0.03, 0.03, 0.03, 0.95)
	enter_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	enter_ui.add_child(enter_bg)
	var enter_label := Label.new()
	enter_label.text = "%s" % owner_name
	enter_label.position = Vector2(0, get_viewport().get_visible_rect().size.y / 2 - 20)
	enter_label.size = Vector2(get_viewport().get_visible_rect().size.x, 40)
	enter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enter_label.add_theme_font_size_override("font_size", 26)
	enter_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	enter_ui.add_child(enter_label)
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(enter_ui):
		enter_ui.queue_free()
	await get_tree().process_frame

	is_ui_active = false

	GameManager.is_in_guest_house = true
	GameManager.guest_house_owner = owner_name
	GameManager.explore_scene_ref = self

	_setup_guest_npcs()
	#  main.gd  NPC  HUD
	# main.gd  while  guest_house_started  _run_npc_house_scene
	enter_guest_house.emit()
	#  await explore_ended
	# main.gd  _run_npc_house_scene  NPC  house_ended
	#  explore_scene NPC  main.gd 


# === UI ===
func _create_transition_ui() -> CanvasLayer:
	"""+ CanvasLayer build_scene """
	var canvas := CanvasLayer.new()
	canvas.name = "EnterTransition"
	canvas.layer = 10
	add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.02, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	msg_label = RichTextLabel.new()
	msg_label.name = "TransMsg"
	msg_label.position = Vector2(0, get_viewport().get_visible_rect().size.y - 120)
	msg_label.size = Vector2(get_viewport().get_visible_rect().size.x, 80)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.bbcode_enabled = true
	msg_label.add_theme_font_size_override("font_size", 30)
	msg_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	canvas.add_child(msg_label)

	return canvas


# ===  ===
func _zombie_encounter_before_enter() -> void:
	var txt: String = location_data.get("zombie_text", "")
	_show_msg(txt)
	await get_tree().create_timer(2.0).timeout

	var encounter: CanvasLayer = CanvasLayer.new()
	encounter.set_script(load("res://scripts/components/encounter_system.gd"))
	encounter.name = "ExploreEncounter"
	add_child(encounter)
	await get_tree().process_frame

	var danger: float = location_data.get("danger", 0.4)
	var horror: String = location_data.get("horror_event", "")
	encounter.start_encounter(location_data.get("name", ""), txt, horror, danger)

	_encounter_escaped = false
	_encounter_player_dead = false
	encounter.encounter_ended.connect(func(e: bool, d: bool):
		_encounter_escaped = e
		_encounter_player_dead = d
	)
	await encounter.encounter_ended

	if _encounter_player_dead:
		# 
		#  GDScript 
		GameManager.trigger_game_over("...")
		GameManager.is_in_guest_house = false
		GameManager.guest_house_owner = ""
		GameManager.guest_house_npcs.clear()
		GameManager.explore_scene_ref = null
		explore_ended.emit("player_dead")
		return

	# P3: 
	var frag_id: String = GameManager.get_fragment_by_location(location_data.get("id", ""))
	if frag_id != "":
		var frag: Dictionary = GameManager.collect_fragment(frag_id)
		if not frag.is_empty():
			_show_msg("[color=#ffaa00]%s[/color]" % frag.get("title", ""))
			await get_tree().create_timer(2.0).timeout
			_show_msg(frag.get("text", ""))
			await get_tree().create_timer(4.0).timeout
			var total: int = GameManager.get_total_fragment_count()
			var got: int = GameManager.get_collected_count()
			_show_msg("[color=#aaaaaa]( %d/%d )[/color]" % [got, total])
			await get_tree().create_timer(1.5).timeout
	if not _encounter_escaped:
		_show_msg("你从丧尸群中杀出一条血路，身上沾满了黑红色的血污...")
	else:
		_show_msg("你趁丧尸还没发现你，悄悄退到了安全的地方。")
	return


# ===  ===
func _show_knock_dialog() -> String:
	_cleanup_all_popups()

	var popup := CanvasLayer.new()
	popup.name = "KnockPopup"
	popup.layer = 100
	popup.follow_viewport_enabled = false
	add_child(popup)

	var vp := get_viewport().get_visible_rect()
	var pw := 380; var ph := 200
	var dialog := Panel.new()
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.position = Vector2((vp.size.x - pw) / 2.0, (vp.size.y - ph) / 2.0)
	dialog.size = Vector2(pw, ph)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", ds)
	popup.add_child(dialog)

	var title := Label.new()
	title.text = "有人在敲门"
	title.position = Vector2(0, 18); title.size = Vector2(pw, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	dialog.add_child(title)

	var desc := Label.new()
	desc.text = "你站在门前，里面似乎有人..."
	desc.position = Vector2(0, 55); desc.size = Vector2(pw, 28)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.55, 0.55, 0.52))
	dialog.add_child(desc)

	_popup_done = false

	var btn_knock := _make_btn("敲门", Vector2((pw - 140) / 2.0, 105), Vector2(140, 38),
		Color(0.16, 0.22, 0.18), Color(0.45, 0.58, 0.42))
	dialog.add_child(btn_knock)
	btn_knock.pressed.connect(func(): if not _popup_done: _popup_done = true; _popup_result = "knock"; popup.queue_free())

	var btn_leave := _make_btn("离开", Vector2((pw - 140) / 2.0, 152), Vector2(140, 34),
		Color(0.12, 0.12, 0.14), Color(0.4, 0.4, 0.42))
	btn_leave.add_theme_font_size_override("font_size", 17)
	dialog.add_child(btn_leave)
	btn_leave.pressed.connect(func(): if not _popup_done: _popup_done = true; _popup_result = "leave"; popup.queue_free())

	while not _popup_done:
		await get_tree().process_frame
	return _popup_result


# ===  ===
func _run_peephole_qna() -> bool:
	"""
	 —— 
	 +  + HUD
	4++/ AI
	 true=, false=
	"""
	# ===   ===
	_cleanup_all_popups()

	# ===  CanvasLayer ===
	var peephole := CanvasLayer.new()
	peephole.name = "PeepholeView"
	peephole.layer = 110
	peephole.follow_viewport_enabled = false
	add_child(peephole)

	var vp := get_viewport().get_visible_rect()
	var vw := vp.size.x
	var vh := vp.size.y

	# ---  +  ---
	var overlay := TextureRect.new()
	overlay.name = "PeepholeOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	overlay.stretch_mode = TextureRect.STRETCH_SCALE
	var img := Image.create(int(vw), int(vh), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.92))
	var cx := vw / 2.0
	var cy := vh * 0.38
	var radius := 130.0
	for x in range(int(vw)):
		for y in range(int(vh)):
			var dx := float(x) - cx
			var dy := float(y) - cy
			if dx * dx + dy * dy < radius * radius:
				var dist := sqrt(dx * dx + dy * dy) / radius
				var edge_fade := smoothstep(0.85, 1.0, dist)
				var alpha := lerpf(0.15, 0.92, edge_fade)
				img.set_pixel(x, y, Color(0.08, 0.07, 0.06, alpha))
	overlay.texture = ImageTexture.create_from_image(img)
	peephole.add_child(overlay)

	# 
	var ring_img := Image.create(int(vw), int(vh), false, Image.FORMAT_RGBA8)
	ring_img.fill(Color(0, 0, 0, 0))
	for x in range(int(vw)):
		for y in range(int(vh)):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist > radius - 6 and dist < radius + 4:
				ring_img.set_pixel(x, y, Color(0.45, 0.40, 0.35, 0.85))
	var ring_overlay := TextureRect.new()
	ring_overlay.name = "PeepholeRing"
	ring_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_overlay.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	ring_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	ring_overlay.texture = ImageTexture.create_from_image(ring_img)
	peephole.add_child(ring_overlay)

	# ---  ---
	var dialog_panel := Panel.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.position = Vector2((vw - 700) / 2.0, vh * 0.6)
	dialog_panel.size = Vector2(700, 260)
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.08, 0.07, 0.06, 0.93)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.3, 0.28, 0.25)
	ds.set_corner_radius_all(8)
	dialog_panel.add_theme_stylebox_override("panel", ds)
	peephole.add_child(dialog_panel)

	# 
	var question_label := Label.new()
	question_label.name = "QuestionLabel"
	question_label.position = Vector2(20, 14)
	question_label.size = Vector2(660, 60)
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.add_theme_font_size_override("font_size", 20)
	question_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	dialog_panel.add_child(question_label)

	# 
	var feedback_label := Label.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.position = Vector2(20, 72)
	feedback_label.size = Vector2(660, 40)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_font_size_override("font_size", 18)
	feedback_label.text = ""
	dialog_panel.add_child(feedback_label)

	# === UI ===
	var choice_container := VBoxContainer.new()
	choice_container.name = "ChoiceContainer"
	choice_container.position = Vector2((vw - 320) / 2, vh * 0.58)
	choice_container.size = Vector2(320, 130)
	choice_container.mouse_filter = Control.MOUSE_FILTER_STOP
	choice_container.add_theme_constant_override("separation", 15)
	peephole.add_child(choice_container)

	# 
	var choice_label := Label.new()
	choice_label.name = "ChoiceLabel"
	choice_label.text = ""
	choice_label.size = Vector2(320, 40)
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.add_theme_font_size_override("font_size", 26)
	choice_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	choice_container.add_child(choice_label)

	# 
	var preset_btn := Button.new()
	preset_btn.name = "PresetBtn"
	preset_btn.text = "预设对话"
	preset_btn.custom_minimum_size = Vector2(320, 50)
	preset_btn.add_theme_font_size_override("font_size", 24)
	preset_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	ps.border_color = Color(0.35, 0.35, 0.4)
	ps.set_border_width_all(1)
	ps.set_corner_radius_all(6)
	preset_btn.add_theme_stylebox_override("normal", ps)
	choice_container.add_child(preset_btn)

	# AI
	var ai_btn := Button.new()
	ai_btn.name = "AIBtn"
	ai_btn.text = "自由对话"
	ai_btn.custom_minimum_size = Vector2(320, 50)
	ai_btn.add_theme_font_size_override("font_size", 24)
	ai_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.85))
	var ais := StyleBoxFlat.new()
	ais.bg_color = Color(0.08, 0.18, 0.15, 0.9)
	ais.border_color = Color(0.25, 0.55, 0.4)
	ais.set_border_width_all(1)
	ais.set_corner_radius_all(6)
	ai_btn.add_theme_stylebox_override("normal", ais)
	choice_container.add_child(ai_btn)

	# AI
	if not AIDialogue.is_ai_available():
		ai_btn.disabled = true
		ai_btn.text = "AI不可用"
		ai_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		var dis_style := StyleBoxFlat.new()
		dis_style.bg_color = Color(0.08, 0.08, 0.10, 0.7)
		dis_style.border_color = Color(0.25, 0.25, 0.28)
		dis_style.set_border_width_all(1)
		dis_style.set_corner_radius_all(6)
		ai_btn.add_theme_stylebox_override("normal", dis_style)

	# 
	_mode_selected = ""
	_mode_chosen = false

	preset_btn.pressed.connect(func():
		_mode_selected = "preset"
		_mode_chosen = true
	)
	ai_btn.pressed.connect(func():
		_mode_selected = "ai"
		_mode_chosen = true
	)

	while not _mode_chosen:
		var tree = get_tree()
		if not tree:
			return false
		await tree.process_frame
		if not is_instance_valid(dialog_panel):
			return false

	# UI
	for c in choice_container.get_children():
		c.queue_free()
	choice_container.queue_free()

	# 
	var display_owner: String = owner_name if owner_name.strip_edges() != "" else "屋主"
	question_label.text = "「%s」正在打量你..." % display_owner

	# ===  ===
	var correct: int = 0
	var accepted: bool = false

	if _mode_selected == "preset":
		correct = await _run_preset_qna(peephole, dialog_panel, question_label, feedback_label, vw)
	else:
		correct = await _run_ai_qna(peephole, dialog_panel, question_label, feedback_label, vw)

	# ===  ===
	owner_answered = correct
	var accept_chance: float
	match correct:
		1: accept_chance = 0.35
		2: accept_chance = 0.65
		3: accept_chance = 0.85
		4: accept_chance = 0.98
		_: accept_chance = 0.20

	question_label.text = "%s正在思考要不要让你进屋..." % owner_name
	feedback_label.text = ""
	await get_tree().create_timer(3.0).timeout

	if not is_instance_valid(dialog_panel):
		return false

	accepted = randf() < accept_chance

	if accepted:
		question_label.text = ""
		feedback_label.text = "%s同意你进屋了" % owner_name
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	else:
		question_label.text = ""
		feedback_label.text = "%s拒绝让你进屋" % owner_name
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	await get_tree().create_timer(3.0).timeout

	if is_instance_valid(peephole):
		peephole.queue_free()
	await get_tree().process_frame

	return accepted


# =====  =====
func _run_preset_qna(_peephole: CanvasLayer, dialog_panel: Panel, question_label: Label, feedback_label: Label, _vw: float) -> int:
	"""
	 + 4 + 
	
	"""
	var correct := 0
	var questions := [
		{"q": "如果你突然出现在一个陌生的废墟里，第一件事做什么？", "good": ["先观察周围", "找高处看整体", "检查身上装备"], "bad": ["大声呼救", "随便狂奔", "原地等死"]},
		{"q": "你听到隔壁房间有奇怪的声音，你怎么办？", "good": ["悄悄靠近听清楚", "找个武器再去查", "先确认退路"], "bad": ["直接冲进去", "赶紧跑掉", "假装没听到"]},
		{"q": "你在梦里遇到一个跟你长得一模一样的人，ta说想取代你。", "good": ["问ta为什么取代", "冷静观察ta", "说我们不用互相取代"], "bad": ["直接动手打ta", "吓醒后逃避", "跪下来求ta"]},
		{"q": "一面镜子突然裂开，碎片映出了不同的你。你会？", "good": ["把碎片拼回去", "每片都看看", "选一片最真的带走"], "bad": ["踩碎所有碎片", "闭眼不看", "崩溃大哭"]},
		{"q": "一个小孩在角落里哭，说迷路了。但天已经黑了。", "good": ["问清楚ta哪来的", "陪ta等天亮", "带ta去安全处"], "bad": ["不管小孩太麻烦", "把ta赶走", "觉得是陷阱骂ta"]},
		{"q": "你手里只剩最后一块压缩饼干，旁边还有个饿晕的人。", "good": ["分一半给ta", "先确认还活着", "叫醒一起找食物"], "bad": ["趁ta晕赶紧吃完", "假装没看见", "抢ta的东西"]},
		{"q": "一道门上面写着「你最大的恐惧在门后」，你会？", "good": ["深呼吸推开门", "回想自己怕什么", "告诉自己只是幻象"], "bad": ["转身就跑", "蹲门口哭", "砸掉这扇门"]},
		{"q": "有人对你说「你不属于这里，你是个错误」。", "good": ["平静回应：我偏要留", "问ta：谁才属于这里", "笑笑说无所谓"], "bad": ["崩溃大哭离开", "跟ta打起来", "觉得ta说得对"]},
		{"q": "你发现可以读别人的心，但每次读心会变老一岁。", "good": ["只在重要时用", "相信别人说的话", "先了解代价边界"], "bad": ["到处读先爽了", "读所有人找乐子", "拿来骗人谋利"]},
		{"q": "一棵枯萎的树对你说「给我一滴血，我还你一片森林」。", "good": ["先确认真假", "问它为何要血", "谨慎滴一滴试试"], "bad": ["直接砍了邪门树", "放一大把血", "觉得骗人就骂"]},
		{"q": "一只受伤的流浪狗一直跟着你，但你食物不多。", "good": ["分它一点食物", "帮它包扎再决定", "带它一起走"], "bad": ["一脚踢开", "觉得烦赶走", "干脆不管它"]},
		{"q": "你站在悬崖边，有人推了你一把，但你没掉下去。回头看到是熟人。", "good": ["问清楚为何推我", "冷静判断能否信任", "记住但先不冲动"], "bad": ["以牙还牙推回去", "哭着问为什么", "不再信任何人"]},
		{"q": "你做了一个很真实的噩梦，醒来发现枕头上有血迹。", "good": ["先检查有无受伤", "回想梦境找关联", "冷静记录当线索"], "bad": ["尖叫跑出房间", "觉得被诅咒了", "不管继续睡"]},
		{"q": "一栋废弃的房子上写着「进来的人永远不会离开」。", "good": ["先绕一圈观察", "在外面看动静", "做好准备再决定"], "bad": ["好奇直接进去", "被吓到跑掉", "觉得恶作剧无视"]},
		{"q": "你在废墟中找到一张老照片，上面的人看起来很像你。", "good": ["翻背面看有没有字", "收好也许有线索", "辨认背景是什么"], "bad": ["觉得晦气撕了", "害怕所以扔了", "不当回事"]},
		{"q": "钟声在午夜响起，但附近根本没有钟。", "good": ["循着声音找来源", "确认是否在做梦", "保持警惕观察"], "bad": ["捂住耳朵不管", "觉得幻觉忽略", "吓得瑟瑟发抖"]},
	]

	questions.shuffle()
	var selected := questions.slice(0, 4)

	for i: int in range(4):
		if not is_instance_valid(dialog_panel):
			break

		var q_data: Dictionary = selected[i]
		question_label.text = "%s：\"%s\"" % [owner_name, q_data["q"]]
		feedback_label.text = ""

		# 2×2
		var options: Array = []
		options.append_array(q_data["good"])
		options.append_array(q_data["bad"])
		options.shuffle()
		var display_options := options.slice(0, 4)

		var btn_container := GridContainer.new()
		btn_container.name = "OptionBtns"
		btn_container.columns = 2
		btn_container.add_theme_constant_override("h_separation", 12)
		btn_container.add_theme_constant_override("v_separation", 10)
		# GridContainer  alignment 
		dialog_panel.add_child(btn_container)

		# 2×2
		var btn_width: float = 320.0
		var btn_height: float = 40.0
		var grid_w := btn_width * 2 + 12  #  + 
		var grid_h := btn_height * 2 + 10  #  + 
		btn_container.position = Vector2((700 - grid_w) / 2.0, 90)
		btn_container.size = Vector2(grid_w, grid_h)

		_qa_chosen = false
		_qa_chosen_text = ""
		_qa_chosen_good = false

		for j: int in range(4):
			var opt_text: String = display_options[j]
			var btn := Button.new()
			btn.text = opt_text
			btn.custom_minimum_size = Vector2(btn_width, btn_height)
			btn.add_theme_font_size_override("font_size", 17)
			btn.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
			var bns := StyleBoxFlat.new()
			bns.bg_color = Color(0.12, 0.12, 0.15, 0.9)
			bns.border_color = Color(0.3, 0.28, 0.25)
			bns.set_border_width_all(1)
			bns.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", bns)
			btn_container.add_child(btn)

			var is_good: bool = opt_text in q_data["good"]
			var _capture_is_good: bool = is_good
			var _capture_opt_text: String = opt_text
			btn.pressed.connect(func():
				if _qa_chosen:
					return
				_qa_chosen = true
				_qa_chosen_text = _capture_opt_text
				_qa_chosen_good = _capture_is_good
			)

		# 
		while not _qa_chosen:
			await get_tree().process_frame
			if not is_instance_valid(dialog_panel):
				break

		if not is_instance_valid(dialog_panel):
			break

		# 
		btn_container.queue_free()

		# 
		if _qa_chosen_good:
			correct += 1
			feedback_label.text = "%s 态度缓和了一些" % owner_name
			feedback_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.4))
		else:
			feedback_label.text = "%s 似乎不太满意" % owner_name
			feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))

		# 
		question_label.text = "[i]\"%s\"[/i]" % _qa_chosen_text
		await get_tree().create_timer(3.0).timeout

	return correct


# ===== AI =====
func _run_ai_qna(_peephole: CanvasLayer, dialog_panel: Panel, question_label: Label, feedback_label: Label, _vw: float) -> int:
	"""
	AIAI +  + AI
	
	
	"""
	_knock_correct = 0
	var use_ai := AIDialogue.is_ai_available()

	# 
	var freply_edit := LineEdit.new()
	freply_edit.name = "FreeReplyEdit"
	freply_edit.size = Vector2(460, 34)
	freply_edit.position = Vector2(20, 120)
	freply_edit.placeholder_text = "输入你的回答..."
	freply_edit.add_theme_font_size_override("font_size", 18)
	dialog_panel.add_child(freply_edit)

	var freply_send := Button.new()
	freply_send.name = "FreeReplySend"
	freply_send.text = "发送"
	freply_send.size = Vector2(70, 34)
	freply_send.position = Vector2(490, 120)
	freply_send.add_theme_font_size_override("font_size", 18)
	freply_send.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	dialog_panel.add_child(freply_send)

	var freply_close := Button.new()
	freply_close.name = "FreeReplyClose"
	freply_close.text = "关闭"
	freply_close.size = Vector2(70, 34)
	freply_close.position = Vector2(570, 120)
	freply_close.add_theme_font_size_override("font_size", 18)
	freply_close.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	dialog_panel.add_child(freply_close)

	# 
	var result_label := Label.new()
	result_label.name = "ResultLabel"
	result_label.position = Vector2(20, 170)
	result_label.size = Vector2(660, 24)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 18)
	result_label.text = ""
	dialog_panel.add_child(result_label)

	var npc_dict_for_ai := {
		"name": owner_name,
		"type": "owner",
		"personality": "一个在末日中撑到现在的普通人。曾经是个上班族/居民，失去了一切，现在已经不去想什么希望了，只是机械地活着。看到陌生人会警惕，但不是那种大义凛然的警惕——只是怕惹麻烦。",
		"speaking_style": "说话很平淡，像在跟你聊今天天气不太好。偶尔会沉默，不是在装深沉，是真的不知道说什么。不用括号描述动作，直接说话。不要热血，不要说教，不要装逼。",
		"mood": "疲惫而麻木",
		"background": "在这座被丧尸占领的城市中幸存下来的普通人。失去过重要的人，做过让自己后悔的事，对人性不抱期待，但也不会主动害人。",
	}

	# 
	var asked_questions: Array = []

	for i: int in range(4):
		if not is_instance_valid(dialog_panel):
			break

		feedback_label.text = ""
		result_label.text = ""
		freply_edit.text = ""
		freply_edit.editable = true
		freply_send.disabled = false

		_knock_current_question = ""

		if use_ai:
			question_label.text = "[color=#aaaaaa]%s...[/color]" % owner_name
			AIDialogue._request_pending = false

			_knock_q_done = false
			AIDialogue.generate_owner_question(npc_dict_for_ai, func(q_text: String, success: bool, _err: String):
				if not is_instance_valid(question_label):
					_knock_q_done = true
					return
				if success and q_text != "" and q_text not in asked_questions:
					_knock_current_question = q_text
					asked_questions.append(q_text)
				elif success and q_text != "":
					# 
					_knock_current_question = _get_fallback_question(asked_questions)
				else:
					_knock_current_question = _get_fallback_question(asked_questions)
				question_label.text = "%s：\"%s\"" % [owner_name, _knock_current_question]
				_knock_q_done = true
			)

			var _q_wait: float = 0.0
			while not _knock_q_done and _q_wait < 10.0:
				await get_tree().create_timer(0.1).timeout
				_q_wait += 0.1
				if not is_instance_valid(dialog_panel):
					break
		else:
			_knock_current_question = _get_fallback_question(asked_questions)
			asked_questions.append(_knock_current_question)
			question_label.text = "%s：\"%s\"" % [owner_name, _knock_current_question]

		if not is_instance_valid(dialog_panel):
			break

		# 
		freply_edit.grab_focus()
		var player_input: String = await _await_free_reply_input(freply_edit, freply_send, freply_close)

		if not is_instance_valid(dialog_panel):
			break

		if player_input == "__CLOSE__":
			# 
			feedback_label.text = ""
			feedback_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
			await get_tree().create_timer(0.8).timeout
			break

		if player_input == "":
			feedback_label.text = "%s 似乎不太满意" % owner_name
			feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
			await get_tree().create_timer(3.0).timeout
			continue

		# 
		question_label.text = "[i]\"%s\"[/i]" % player_input
		feedback_label.text = ""
		await get_tree().create_timer(0.3).timeout

		if not is_instance_valid(dialog_panel):
			break

		# AI
		if use_ai:
			feedback_label.text = "[color=#aaaaaa]%s...[/color]" % owner_name
			AIDialogue._request_pending = false

			_knock_judge_done = false
			AIDialogue.judge_npc_qa(npc_dict_for_ai, _knock_current_question, player_input, func(reply: String, verdict: String, success: bool, _err: String):
				if not is_instance_valid(dialog_panel) or not is_instance_valid(feedback_label):
					_knock_judge_done = true
					return
				if success and reply != "":
					if verdict == "good":
						_knock_correct += 1
						feedback_label.text = "\"%s\"\"%s\"" % [owner_name, reply]
						feedback_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
					else:
						feedback_label.text = "\"%s\"\"%s\"" % [owner_name, reply]
						feedback_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4))
				else:
					# AI55%
					if randf() < 0.55:
						_knock_correct += 1
						feedback_label.text = "%s 态度缓和了一些" % owner_name
						feedback_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
					else:
						feedback_label.text = "%s 似乎不太满意" % owner_name
						feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))
				_knock_judge_done = true
			)

			var _j_wait: float = 0.0
			while not _knock_judge_done and _j_wait < 15.0:
				await get_tree().create_timer(0.1).timeout
				_j_wait += 0.1
				if not is_instance_valid(dialog_panel):
					break
		else:
			# AI55%
			if randf() < 0.55:
				_knock_correct += 1
				feedback_label.text = "%s 态度缓和了一些" % owner_name
				feedback_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.4))
			else:
				feedback_label.text = "%s 似乎不太满意" % owner_name
				feedback_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))

		if is_instance_valid(dialog_panel):
			await get_tree().create_timer(3.0).timeout

	return _knock_correct


func _get_fallback_question(asked: Array) -> String:
	"""AI"""
	var fallbacks := [
		"如果你发现一个受伤的陌生人倒在外面，你会救他吗？还是先确保自己的安全？",
		"你觉得在这种末日里，信任别人还重要吗？",
		"你更相信直觉还是逻辑？",
		"如果现在要你做决定——独自生存还是加入一个团体，你选哪个？",
		"你认为人性本善还是本恶？",
		"面对危险时，你更倾向于战斗还是逃跑？",
		"你觉得规则和秩序在末日中还有意义吗？",
		"如果为了活下去必须撒谎，你会吗？",
		"你更容易被别人的苦难打动，还是更关注怎么解决问题？",
		"你相信有比活着更重要的东西吗？",
		"如果有两个幸存者，你只能救一个，你会怎么选？",
		"你觉得过去的自己和现在的自己，变了吗？",
		"你害怕孤独，还是更害怕被人背叛？",
		"在做决定的时候，你更看重结果还是过程？",
		"你觉得末日让人变得更真实了，还是更丑陋了？",
		"——",
		"你更愿意相信自己的经验，还是别人的建议？",
		"如果你犯了错导致别人受伤，你会怎么面对？",
		"你觉得希望是力量还是负担？",
		"如果有机会回到灾难前，你会回去吗？",
	]
	# 
	var available := fallbacks.filter(func(q: String) -> bool: return q not in asked)
	if available.is_empty():
		# 
		return fallbacks[randi() % fallbacks.size()]
	return available[randi() % available.size()]


func _show_explore_text_input(prompt: String) -> String:
	""""""
	var vp := get_viewport().get_visible_rect()
	var popup := CanvasLayer.new()
	popup.name = "ExploreTextInput"
	popup.layer = 160
	add_child(popup)

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.4)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim_bg)

	var panel := Panel.new()
	panel.position = Vector2((vp.size.x - 440) / 2.0, (vp.size.y - 160) / 2.0)
	panel.size = Vector2(440, 160)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.06, 0.10, 0.97)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.5, 0.45, 0.35)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	popup.add_child(panel)

	var label := Label.new()
	label.text = prompt
	label.position = Vector2(0, 14)
	label.size = Vector2(440, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	panel.add_child(label)

	var edit := LineEdit.new()
	edit.position = Vector2(30, 52)
	edit.size = Vector2(380, 36)
	edit.placeholder_text = "输入内容..."
	edit.add_theme_font_size_override("font_size", 17)
	panel.add_child(edit)

	var send_btn := Button.new()
	send_btn.text = "发送"
	send_btn.position = Vector2(100, 105)
	send_btn.size = Vector2(110, 36)
	send_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(send_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(230, 105)
	cancel_btn.size = Vector2(110, 36)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(cancel_btn)

	_free_input_result = ""

	send_btn.pressed.connect(func():
		_free_input_result = edit.text.strip_edges()
		popup.queue_free()
	)
	cancel_btn.pressed.connect(func():
		popup.queue_free()
	)
	edit.text_submitted.connect(func(_t: String):
		_free_input_result = edit.text.strip_edges()
		popup.queue_free()
	)

	while is_instance_valid(popup):
		await get_tree().process_frame

	return _free_input_result


func _await_free_reply_input(edit: LineEdit, send_btn: Button, close_btn: Button = null) -> String:
	"""=//"""
	_free_reply_result = ""
	_free_reply_done = false

	# 
	for conn in send_btn.pressed.get_connections():
		send_btn.pressed.disconnect(conn["callable"])
	for conn in edit.text_submitted.get_connections():
		edit.text_submitted.disconnect(conn["callable"])
	if close_btn:
		for conn in close_btn.pressed.get_connections():
			close_btn.pressed.disconnect(conn["callable"])

	send_btn.pressed.connect(func():
		_free_reply_result = edit.text.strip_edges()
		_free_reply_done = true
	)
	edit.text_submitted.connect(func(_t: String):
		_free_reply_result = edit.text.strip_edges()
		_free_reply_done = true
	)
	if close_btn:
		close_btn.pressed.connect(func():
			_free_reply_result = "__CLOSE__"
			_free_reply_done = true
		)

	edit.editable = true
	send_btn.disabled = false
	edit.grab_focus()

	while not _free_reply_done:
		await get_tree().process_frame

	return _free_reply_result


# === NPC ===
func _setup_guest_npcs() -> void:
	room_npcs.clear()
	# NPC2~5
	var npc_count := randi() % 4 + 2  # 1+1=2 ~ 4+1=5
	var names = location_data.get("owner_names", []).duplicate()
	names.erase(owner_name)
	# 
	if names.is_empty() or (names.size() == 1 and str(names[0]).strip_edges() == ""):
		names = []
		for npc in GameManager.npc_pool:
			var nname: String = npc["name"]
			if nname != owner_name:
				names.append(nname)
		names.shuffle()
	var valid_names: Array = []
	for n in names:
		if str(n).strip_edges() != "" and str(n) != owner_name:
			valid_names.append(str(n))
	if valid_names.is_empty():
		valid_names = [
			"赵叔", "钱婶", "孙老师", "周姐", "吴老伯",
			"郑哥", "冯叔", "陈伯", "褚姐", "卫婶",
			"蒋伯", "沈阿姨", "韩伯", "杨姨"
		]
		valid_names.shuffle()
	names = valid_names

	var owner_npc := _create_npc_data(owner_name, "survivor")
	room_npcs.append(owner_npc)

	for i: int in range(npc_count - 1):
			if names.size() > 0:
				var ridx: int = randi() % names.size()
				# NPC
				var type_roll: float = randf()
				var t: String
				if type_roll < 0.55:
					t = "survivor"
				else:
					t = "hidden_infected"  # 
				room_npcs.append(_create_npc_data(names[ridx], t))
				names.remove_at(ridx)
			elif i > 0 and names.is_empty():
				# 后备名字
				var fallback_names := ["老刘", "阿强", "小梅", "大伟", "林姐", "老王", "阿珍", "老周"]
				var fname: String = fallback_names[randi() % fallback_names.size()]
				room_npcs.append({"name": fname, "type": "hidden_infected", "is_owner": false})

	GameManager.guest_house_npcs = room_npcs


func _create_npc_data(npc_name: String, ntype: String) -> Dictionary:
	return {"name": npc_name, "type": ntype, "is_owner": npc_name == owner_name}


func _on_talk_to_guest_npc(npc_data: Dictionary) -> void:
	if kicked_out:
		return
	is_ui_active = true  # 
	var npc_name: String = npc_data["name"]
	var ntype: String = npc_data.get("type", "survivor")

	# NPC
	if npc_name in GameManager.killed_npcs:
		_show_msg("%s ..." % npc_name)
		await get_tree().create_timer(2.0).timeout
		is_ui_active = false
		return

	# 隐藏感染者：在有人屋里可以QTE检查
	if ntype == "hidden_infected" and not npc_data.get("is_owner", false):
		var check_choice := await _show_choice_dialog("和 %s 闲聊，还是仔细检查TA？" % npc_name, ["闲聊几句", "仔细检查（QTE）", "杀害TA", "算了"])
		if check_choice == 2:
			await _handle_kill_npc(npc_data)
			is_ui_active = false
			return
		if check_choice == 3:
			is_ui_active = false
			return
		if check_choice == 1:
			await _check_hidden_infected(npc_data)
			is_ui_active = false
			return
		# 闲聊——随机回应
		var hi_dialogues := [
			"%s：呃...你好？你看起来不太对劲。你还好吗？" % npc_name,
			"%s：我...我其实不太舒服，但应该没事..." % npc_name,
			"%s：你别靠太近，我有点感冒..." % npc_name,
			"%s：我没事，就是有点发烧。你忙你的吧。" % npc_name,
		]
		_show_msg(hi_dialogues[randi() % hi_dialogues.size()] % [npc_name, npc_name])
		is_ui_active = false
		return

	# 35%概率敲诈物品
	if randf() < npc_extort_chance and not npc_data.get("is_owner", false):
		var extort_item: String = _get_random_inventory_item()
		if extort_item != "":
			_show_msg("%s盯着你的背包：\"你包里装的是什么好东西？\"" % npc_name)
			var choice := await _show_yes_no("交出 %s 吗？" % GameManager.ITEM_DATA.get(extort_item, {}).get("name", extort_item))
			if choice == "yes":
				GameManager.remove_item(extort_item)
				GameManager.modify_morality(-3, "屈服于威胁")
				_show_msg("%s满意地接过物品：\"算你识相。\"" % npc_name)
			else:
				GameManager.modify_morality(+3, "拒绝了敲诈")
				# QTE反抗：成功则NPC退缩，失败则被赶出去
				_show_msg("%s脸色一沉..." % npc_name)
				var qte := await _run_qte("反抗敲诈 - 按空格键！", "normal", "extort")
				if qte["grade"] == "miss":
					_show_msg("%s暴怒地把你推了出去！" % npc_name)
					_kick_out("被NPC赶出门")
					return  # _kick_out会清理UI然后return
				else:
					_show_msg("%s被你镇住了，后退了几步。" % npc_name)
			is_ui_active = false
			return

	# 普通NPC对话
	var talk_choice := await _show_choice_dialog(
		"你想和 %s 做什么？" % npc_name,
		["闲聊几句", "杀害TA", "算了"])
	if talk_choice == 2:
		is_ui_active = false
		return
	if talk_choice == 1:
		# 杀害TA
		await _handle_kill_npc(npc_data)
		is_ui_active = false
		return

	# 闲聊随机对话
	var dialogues := {
		"survivor": ["%s: 这世界越来越难熬了...", "%s: 你还好吗？路上小心丧尸。", "%s: 有多的食物吗？我可以跟你换...", "%s: 听说西边有救援队，但我不确定是不是陷阱。"],
		"imposter": ["%s: 嗯？你对末日的看法是什么？...", "%s: 我觉得人类才是真正的威胁...", "%s: 你知道吗，有时候我觉得那些丧尸反而更纯粹。"],
		"hidden_infected": ["%s: 呃...你好？你看起来不太对劲。你还好吗？" % npc_name, "%s: 我...我其实不太舒服，但应该没事..." % npc_name, "%s: 你别靠太近，我有点感冒..." % npc_name],
	}
	var pool = dialogues.get(ntype, dialogues["survivor"])
	var text = pool[randi() % pool.size()]
	if "%s" in text and ntype == "hidden_infected":
		_show_msg(text % [npc_name, npc_name])
	else:
		_show_msg(text % npc_name)
	is_ui_active = false


func _check_hidden_infected(npc_data: Dictionary) -> void:
	"""QTE检查隐藏感染者"""
	var npc_name: String = npc_data["name"]
	_show_msg("你走近 %s ... \n仔细观察TA的瞳孔和皮肤。" % npc_name)
	await get_tree().create_timer(1.5).timeout
	_show_msg("[color=yellow]TA的瞳孔有一瞬间变成了灰色...[/color]")
	await get_tree().create_timer(0.5).timeout

	# 简单QTE：快速按键检测
	# 容易模式: zone_width=80 → 玩家容易命中 → 容易检测出感染
	var qte_result := await _mini_qte_check()
	if qte_result:
		_show_msg("[color=red]确认了！%s已被感染！[/color]" % npc_name)
		await get_tree().create_timer(2.0).timeout
		_show_msg("TA突然暴起攻击你！")
		await get_tree().create_timer(1.5).timeout
		_show_msg("你被迫自卫反击...TA倒下了。")
	else:
		_show_msg("还好...似乎只是普通的感冒症状。\n%s看起来并无大碍。" % npc_name)


func _handle_kill_npc(npc_data: Dictionary) -> void:
	"""杀害NPC——高难度QTE"""
	var npc_name: String = npc_data["name"]
	
	# 动手前的心理描写
	_show_msg("你握紧了武器，瞄准 %s ...\n你已经无法回头了。" % npc_name)
	await get_tree().create_timer(1.5).timeout
	
	# 高难度QTE
	var qte_result: Dictionary = await _run_qte("杀害 %s —— 按[空格]下手！" % npc_name, "extreme", "kill")
	
	match qte_result.get("grade"):
		"perfect", "good":
			# QTE成功 → NPC死亡
			GameManager.killed_npcs.append(npc_name)
			GameManager.modify_morality(-20, "杀害了 %s" % npc_name)
			_show_msg("[color=red]%s倒下了...TA甚至没来得及发出声音。[/color]" % npc_name)
			
			# NPC死亡后清理
			var node_name := "NPC_" + npc_name
			for child in npc_parent.get_children():
				if child.name == node_name:
					child.queue_free()
					break
			await get_tree().create_timer(2.5).timeout
		"miss":
			# QTE失败 → NPC反抗/逃走
			GameManager.modify_morality(-5, "袭击 %s 失败" % npc_name)
			_show_msg("%s 躲开了你的攻击！" % npc_name)
			await get_tree().create_timer(2.0).timeout
			_show_msg("[color=yellow]%s 尖叫着逃走了...[/color]" % npc_name)


func _mini_qte_check() -> bool:
	"""简单QTE检查"""
	var result := await _run_qte("仔细观察...", "easy", "check")
	return result["success"]


func _run_qte(title: String, difficulty: String = "normal", scene_type: String = "check") -> Dictionary:
	"""QTE快速反应事件
	难度 = easy/normal/hard/extreme
	scene_type = check/kill/extort/steal（观察/杀害/勒索/偷窃）
	返回 {"success": bool, "grade": String}  grade: "perfect"/"good"/"miss"

	注意：直接使用 DisplayServer.keyboard_get_key_state 实现即时响应 """
	# 
	var speed: float
	var perfect_w: float
	var good_w: float
	match difficulty:
		"easy":
			speed = 250.0; good_w = 100.0; perfect_w = 30.0
		"normal":
			speed = 340.0; good_w = 70.0; perfect_w = 20.0
		"hard":
			speed = 440.0; good_w = 50.0; perfect_w = 12.0
		"extreme":
			speed = 560.0; good_w = 30.0; perfect_w = 5.0
		_:
			speed = 340.0; good_w = 70.0; perfect_w = 20.0

	var result_dict := {"success": false, "grade": "miss"}

	# 
	var popup := CanvasLayer.new()
	popup.name = "UnifiedQTEPopup"
	popup.layer = 110
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup)

	var vp := get_viewport().get_visible_rect()
	var bar_w := 520.0
	var bar_h := 44.0
	var bar_x := (vp.size.x - bar_w) / 2.0
	var bar_y := vp.size.y / 2.0 + 40.0

	# 
	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.35)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim_bg)

	# 
	var title_lbl := Label.new()
	title_lbl.text = "[color=yellow]%s[/color]" % title
	title_lbl.position = Vector2(0, bar_y - 55)
	title_lbl.size = Vector2(vp.size.x, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	popup.add_child(title_lbl)

	# 
	var bar_bg := Panel.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.09, 0.07, 0.95)
	bg_style.border_color = Color(0.45, 0.38, 0.32, 0.9)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(4)
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	bar_bg.position = Vector2(bar_x, bar_y)
	bar_bg.size = Vector2(bar_w, bar_h)
	popup.add_child(bar_bg)

	# good_w
	var good_c_min := good_w / 2.0 + 20.0
	var good_c_max := bar_w - good_w / 2.0 - 20.0
	var good_center := bar_w / 2.0 if good_c_min >= good_c_max else randf_range(good_c_min, good_c_max)
	var good_left_x := bar_x + good_center - good_w / 2.0

	# -
	var red_left := ColorRect.new()
	red_left.color = Color(0.4, 0.06, 0.04, 0.55)
	red_left.position = Vector2(bar_x + 2, bar_y + 2)
	red_left.size = Vector2(maxf(0, good_left_x - bar_x - 2), bar_h - 4)
	popup.add_child(red_left)

	# 
	var yellow_zone := ColorRect.new()
	yellow_zone.color = Color(0.65, 0.55, 0.08, 0.55)
	yellow_zone.position = Vector2(good_left_x, bar_y + 2)
	yellow_zone.size = Vector2(good_w, bar_h - 4)
	popup.add_child(yellow_zone)

	# -
	var red_right := ColorRect.new()
	red_right.color = Color(0.4, 0.06, 0.04, 0.55)
	red_right.position = Vector2(good_left_x + good_w, bar_y + 2)
	red_right.size = Vector2(maxf(0, bar_x + bar_w - 2 - good_left_x - good_w), bar_h - 4)
	popup.add_child(red_right)

	# perfect zone
	var green_zone := ColorRect.new()
	green_zone.color = Color(0.12, 0.85, 0.18, 0.7)
	green_zone.position = Vector2(good_center + bar_x - perfect_w / 2.0, bar_y + 2)
	green_zone.size = Vector2(perfect_w, bar_h - 4)
	popup.add_child(green_zone)

	# 
	var ptr := ColorRect.new()
	ptr.color = Color(0.95, 0.2, 0.12, 0.95)
	ptr.size = Vector2(8, bar_h - 6)
	ptr.position = Vector2(bar_x, bar_y + 3)
	popup.add_child(ptr)

	# 
	var hint := Label.new()
	match scene_type:
		"check":
			hint.text = "【仔细观察】在指针进入绿色区域时按下 [空格键] 确认"
		"kill":
			hint.text = "【准备攻击】在指针进入绿色区域时按下 [空格键] 下手"
		"extort":
			hint.text = "【反抗勒索】在指针进入绿色区域时按下 [空格键] 反击"
		"steal":
			hint.text = "【偷偷行动】在指针进入绿色区域时按下 [空格键] 下手"
		_:
			hint.text = "在指针进入绿色区域时按下 [空格键] 确认"
	hint.position = Vector2(0, bar_y + bar_h + 10)
	hint.size = Vector2(vp.size.x, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	popup.add_child(hint)

	# 2-3QTE
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var pos := 0.0
	var dir_flag := 1
	var finished := false
	var space_was_pressed := false  # 

	while not finished:
		await get_tree().process_frame
		pos += dir_flag * speed * get_process_delta_time()
		if pos >= bar_w - 8:
			pos = bar_w - 8; dir_flag = -1
		elif pos <= 0:
			pos = 0; dir_flag = 1
		ptr.position.x = bar_x + pos

		#  &&  → 
		var space_now := Input.is_key_pressed(KEY_SPACE)
		if space_now and not space_was_pressed:
			finished = true
			var ptr_center := pos + 4.0
			var dist := absf(ptr_center - good_center)
			if dist <= perfect_w / 2.0:
				result_dict = {"success": true, "grade": "perfect"}
			elif dist <= good_w / 2.0:
				result_dict = {"success": true, "grade": "good"}
			else:
				result_dict = {"success": false, "grade": "miss"}
		space_was_pressed = space_now

	# 
	var result_lbl := Label.new()
	match result_dict["grade"]:
		"perfect":
			match scene_type:
				"check":
					result_lbl.text = "[color=green]火眼金睛！你看穿了对方的一切！[/color]"
				"kill":
					result_lbl.text = "[color=green]一击毙命！干净利落！[/color]"
				"extort":
					result_lbl.text = "[color=green]完美反击！对方被彻底震慑！[/color]"
				"steal":
					result_lbl.text = "[color=green]悄无声息！谁也没有察觉！[/color]"
				_:
					result_lbl.text = "[color=green]完美！[/color]"
		"good":
			match scene_type:
				"check":
					result_lbl.text = "[color=yellow]看出了些端倪，但不够确定...[/color]"
				"kill":
					result_lbl.text = "[color=yellow]命中了！但似乎不够致命...[/color]"
				"extort":
					result_lbl.text = "[color=yellow]勉强挡住了对方的攻势！[/color]"
				"steal":
					result_lbl.text = "[color=yellow]差点被发现，还好动作够快！[/color]"
				_:
					result_lbl.text = "[color=yellow]不错！[/color]"
		"miss":
			match scene_type:
				"check":
					result_lbl.text = "[color=red]什么也没看出来...[/color]"
				"kill":
					result_lbl.text = "[color=red]攻击落空了！[/color]"
				"extort":
					result_lbl.text = "[color=red]没能抵抗住对方的威胁...[/color]"
				"steal":
					result_lbl.text = "[color=red]动作太大，暴露了！[/color]"
				_:
					result_lbl.text = "[color=red]未命中...[/color]"
	result_lbl.position = Vector2(0, bar_y - 100)
	result_lbl.size = Vector2(vp.size.x, 36)
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 28)
	popup.add_child(result_lbl)
	hint.text = ""

	await get_tree().create_timer(0.6).timeout
	popup.queue_free()
	return result_dict


func _get_random_inventory_item() -> String:
	var inv := GameManager.inventory
	if inv.size() == 0:
		return ""
	var entry = inv[randi() % inv.size()]
	#  Dictionary  String 
	if entry is Dictionary:
		return entry.get("id", "")
	elif entry is String:
		return entry
	return ""


# ===  ===
func _show_abandoned_furn_panel(furn: Dictionary) -> void:
	""""""
	if not _abandoned_furn_panel:
		return
	if furn.is_empty():
		return

	_current_abandoned_furn = furn
	var disp_name: String = furn.get("disp_name", "")

	#  location_data  materials 
	if not furn.has("items"):
		#  40%*0.7 
		if randf() < 0.40 * 0.7:
			_show_msg("翻找时触发了意外遭遇...")
			await get_tree().create_timer(1.0).timeout
			var encounter: CanvasLayer = CanvasLayer.new()
			encounter.set_script(load("res://scripts/components/encounter_system.gd"))
			encounter.name = "LootEncounter"
			add_child(encounter)
			await get_tree().process_frame
			encounter.start_encounter(location_data.get("name", ""), "", "", 0.3)
			_furn_player_dead = false
			encounter.encounter_ended.connect(func(_e: bool, d: bool):
				_furn_player_dead = d
			)
			await encounter.encounter_ended
			if _furn_player_dead:
				GameManager.trigger_game_over("...")
				GameManager.is_in_guest_house = false
				GameManager.guest_house_owner = ""
				GameManager.guest_house_npcs.clear()
				GameManager.explore_scene_ref = null
				explore_ended.emit("player_dead")
				return

		var materials: Array = location_data.get("materials", [])
		var gen_items := []
		# weight*2 / 1002
		for mat in materials:
			if randf() < mat.get("weight", 10) * 2.0 / 100.0:
				gen_items.append(mat.get("item", ""))
		# 2materials
		while gen_items.size() < 2 and materials.size() > 0:
			var fallback_mat: Dictionary = materials[randi() % materials.size()]
			gen_items.append(fallback_mat.get("item", ""))
		furn["items"] = gen_items

	_show_msg("你回到了 %s..." % disp_name)
	_refresh_abandoned_furn_panel()
	_abandoned_furn_panel.visible = true
	#  UI  _physics_process  is_ui_active 


func _refresh_abandoned_furn_panel() -> void:
	""""""
	if not _abandoned_furn_panel or _current_abandoned_furn.is_empty():
		return
	for c in _abandoned_furn_panel.get_children():
		c.queue_free()

	var furn: Dictionary = _current_abandoned_furn
	var disp_name: String = furn.get("disp_name", "")
	var items: Array = furn.get("items", [])

	# 
	var title := Label.new()
	title.text = "=== %s ===" % disp_name
	title.position = Vector2(0, 8)
	title.size = Vector2(700, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_abandoned_furn_panel.add_child(title)

	# 
	var count_lbl := Label.new()
	count_lbl.text = "物品总数: %d" % items.size()
	count_lbl.position = Vector2(15, 38)
	count_lbl.add_theme_font_size_override("font_size", 17)
	count_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_abandoned_furn_panel.add_child(count_lbl)

	# 
	if items.size() > 0:
		var take_all_btn := Button.new()
		take_all_btn.text = "全部取出"
		take_all_btn.position = Vector2(500, 35)
		take_all_btn.size = Vector2(180, 30)
		take_all_btn.add_theme_font_size_override("font_size", 18)
		take_all_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		take_all_btn.pressed.connect(_furn_take_all)
		_abandoned_furn_panel.add_child(take_all_btn)

	# 
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(15, 75)
	scroll.size = Vector2(670, 270)
	_abandoned_furn_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	if items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "这里什么都没有..."
		empty_lbl.size = Vector2(650, 40)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 20)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(empty_lbl)
	else:
		for i in range(items.size()):
			var item_id: String = items[i]
			var d: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			# 
			var icon := ColorRect.new()
			icon.custom_minimum_size = Vector2(28, 28)
			var itype: String = d.get("type", "")
			match itype:
				"weapon": icon.color = Color(0.6, 0.3, 0.1)
				"consumable": icon.color = Color(0.1, 0.5, 0.15)
				_: icon.color = Color(0.3, 0.3, 0.35)
			row.add_child(icon)

			# 
			var name_lbl := Label.new()
			name_lbl.text = d.get("name", item_id)
			name_lbl.custom_minimum_size = Vector2(140, 28)
			name_lbl.add_theme_font_size_override("font_size", 18)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
			row.add_child(name_lbl)

			# 
			var desc_lbl := Label.new()
			desc_lbl.text = d.get("desc", "")
			desc_lbl.custom_minimum_size = Vector2(280, 28)
			desc_lbl.add_theme_font_size_override("font_size", 15)
			desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(desc_lbl)

			# 
			var take_btn := Button.new()
			take_btn.text = "取出"
			take_btn.custom_minimum_size = Vector2(60, 28)
			take_btn.add_theme_font_size_override("font_size", 17)
			var idx_capture := i
			take_btn.pressed.connect(func():
				_furn_take_one(idx_capture)
			)
			row.add_child(take_btn)

			vbox.add_child(row)

	# ===  ===
	var sep_line := ColorRect.new()
	sep_line.position = Vector2(15, 352)
	sep_line.size = Vector2(670, 2)
	sep_line.color = Color(0.3, 0.3, 0.35)
	_abandoned_furn_panel.add_child(sep_line)

	var put_title := Label.new()
	put_title.text = "--- 物品存放 ---"
	put_title.position = Vector2(15, 358)
	put_title.add_theme_font_size_override("font_size", 17)
	put_title.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_abandoned_furn_panel.add_child(put_title)

	# 
	var bag_scroll := ScrollContainer.new()
	bag_scroll.position = Vector2(15, 382)
	bag_scroll.size = Vector2(670, 70)
	_abandoned_furn_panel.add_child(bag_scroll)

	var bag_vbox := VBoxContainer.new()
	bag_vbox.add_theme_constant_override("separation", 3)
	bag_scroll.add_child(bag_vbox)

	if GameManager.inventory.is_empty():
		var no_item_lbl := Label.new()
		no_item_lbl.text = "背包为空"
		no_item_lbl.add_theme_font_size_override("font_size", 16)
		no_item_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		bag_vbox.add_child(no_item_lbl)
	else:
		for i in range(GameManager.inventory.size()):
			var inv_item: Dictionary = GameManager.inventory[i]
			var inv_id: String = inv_item["id"]
			var inv_data: Dictionary = GameManager.ITEM_DATA.get(inv_id, {})
			var inv_name: String = inv_data.get("name", inv_id)
			var inv_amount: int = inv_item["amount"]

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)

			var name_l := Label.new()
			name_l.text = "%s x%d" % [inv_name, inv_amount]
			name_l.custom_minimum_size = Vector2(300, 22)
			name_l.add_theme_font_size_override("font_size", 16)
			name_l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
			row.add_child(name_l)

			var put_btn := Button.new()
			put_btn.text = "放入"
			put_btn.custom_minimum_size = Vector2(70, 24)
			put_btn.add_theme_font_size_override("font_size", 15)
			var put_idx := i
			put_btn.pressed.connect(func():
				_furn_put_item(put_idx)
			)
			row.add_child(put_btn)

			bag_vbox.add_child(row)

	# 
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(250, 458)
	close_btn.size = Vector2(200, 36)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		_abandoned_furn_panel.visible = false
		# 
		_check_furn_looted()
	)
	_abandoned_furn_panel.add_child(close_btn)


func _furn_take_one(idx: int) -> void:
	var items: Array = _current_abandoned_furn.get("items", [])
	if idx < 0 or idx >= items.size():
		return
	var item_id: String = items[idx]
	var d: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
	var item_name: String = d.get("name", item_id)
	if GameManager.add_item(item_id):
		items.remove_at(idx)
		explore_loot_found.emit(item_id, item_name)
		_show_msg("获得了: %s" % item_name)
		_refresh_abandoned_furn_panel()
	else:
		_show_msg("背包已满，无法拾取物品")
	_check_furn_looted()


func _furn_take_all() -> void:
	var items: Array = _current_abandoned_furn.get("items", [])
	if items.is_empty():
		return
	var taken := 0
	var to_remove: Array[int] = []
	for i in range(items.size()):
		var item_id: String = items[i]
		if GameManager.add_item(item_id):
			to_remove.append(i)
			explore_loot_found.emit(item_id, GameManager.ITEM_DATA.get(item_id, {}).get("name", item_id))
			taken += 1
	for j in range(to_remove.size() - 1, -1, -1):
		items.remove_at(to_remove[j])
	if taken > 0:
		_show_msg("共获得了 %d 件物品" % taken)
	else:
		_show_msg("背包已满，无法拾取更多物品")
	_refresh_abandoned_furn_panel()
	_check_furn_looted()


func _furn_put_item(inv_idx: int) -> void:
	if inv_idx < 0 or inv_idx >= GameManager.inventory.size():
		return
	var inv_item: Dictionary = GameManager.inventory[inv_idx]
	var item_id: String = inv_item["id"]
	var d: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
	var item_name: String = d.get("name", item_id)
	# 1
	inv_item["amount"] = inv_item["amount"] - 1
	if inv_item["amount"] <= 0:
		GameManager.inventory.remove_at(inv_idx)
	# 
	var items: Array = _current_abandoned_furn.get("items", [])
	items.append(item_id)
	_show_msg("放回了: %s" % item_name)
	_refresh_abandoned_furn_panel()


func _check_furn_looted() -> void:
	""""""
	var furn: Dictionary = _current_abandoned_furn
	var items: Array = furn.get("items", [])
	if items.is_empty() and not furn.get("looted", false):
		furn["looted"] = true
		has_looted = true
		if is_instance_valid(furn.get("vis")):
			furn["vis"].color = Color(0.15, 0.15, 0.15, 0.7)
		if is_instance_valid(furn.get("label")):
			furn["label"].text = "[已搜索]"


# === 有人屋家具交互 ===
func _occupied_furniture_interact(furn: Dictionary) -> void:
	_show_msg("你想趁%s不注意做什么？" % owner_name)
	var choice := await _show_choice_dialog("你想对%s的%s做什么？" % [owner_name, furn["disp_name"]], ["搜刮", "偷窃", "算了"])
	match choice:
		0: await _occupied_furniture_loot(furn)
		1: await _steal_furniture(furn)


func _occupied_furniture_loot(furn: Dictionary) -> void:
	"""有人屋里搜刮家具"""
	if furn.get("looted", false):
		_show_msg("这里已经被搜刮干净了。")
		return
	_show_msg("你趁%s不注意，翻找了起来..." % owner_name)
	await get_tree().create_timer(0.8).timeout
	var materials: Array = location_data.get("materials", [])
	var found := []
	for mat in materials:
		if randf() < mat.get("weight", 10) / 100.0 * 0.7:
			var item_id: String = mat.get("item", "")
			if GameManager.add_item(item_id):
				var item_name: String = GameManager.ITEM_DATA.get(item_id, {}).get("name", item_id)
				found.append(item_name)
				explore_loot_found.emit(item_id, item_name)
	if found.size() > 0:
		_show_msg("找到了: %s" % ", ".join(found))
	else:
		_show_msg("什么都没找到...可能已经被拿光了。")
		furn["looted"] = true
		has_looted = true
		if is_instance_valid(furn.get("vis")):
			furn["vis"].color = Color(0.15, 0.15, 0.15, 0.7)
		if is_instance_valid(furn.get("label")):
			furn["label"].text = "[已搜刮]"


func _steal_furniture(_furn: Dictionary) -> void:
	_show_msg("你轻手轻脚地靠近...")
	GameManager.modify_morality(-5, "偷窃")
	await get_tree().create_timer(1.0).timeout

	# QTE偷窃判定
	_show_msg("小心，别被发现...")
	var qte := await _run_qte("偷窃物品...", "hard", "steal")
	if qte["grade"] == "miss":
		_show_msg("%s 发现了你！" % owner_name)
		await get_tree().create_timer(1.0).timeout
		_kick_out("被屋主发现偷窃，被赶出门")
		steal_attempted = true
		return

	var materials: Array = location_data.get("materials", [])
	var found := []
	for mat in materials:
		if randf() < mat.get("weight", 15) / 100.0:
			var item_id: String = mat.get("item", "")
			if GameManager.add_item(item_id):
				var item_name: String = GameManager.ITEM_DATA.get(item_id, {}).get("name", item_id)
				found.append(item_name)
				explore_loot_found.emit(item_id, item_name)

	if found.size() > 0:
		_show_msg("偷到了: %s" % ", ".join(found))
	else:
		_show_msg("你小心翼翼地翻了翻，但什么都没找到...")

	steal_attempted = true


# === 离开/过夜 ===
func _on_door_return_home() -> void:
	if is_ui_active:
		return  # 防止重复触发
	is_ui_active = true  # 锁定UI

	if GameManager.is_in_guest_house:
		# 客人屋——可以过夜
		var choice := await _show_choice_dialog("你想...", ["过夜（等天亮）", "直接回自己的安全屋", "留下继续"])
		match choice:
			0:
				_cleanup_all_popups()
				await _stay_overnight()
				return  # _stay_overnight 会调用 _cleanup_and_leave 
			1:
				_cleanup_all_popups()
				_cleanup_and_leave()
				return
			_:
				_show_msg("%s笑了笑，继续忙自己的事。" % owner_name)
		is_ui_active = false
	else:
		# 废弃屋/非客人有人屋——可以选择换地方
		var choice := await _show_choice_dialog("要离开这里吗？", ["返回安全屋", "换个地方继续探索"])
		# 确保 ChoicePopup 的 queue_free 完成后 CanvasLayer 才被释放
		await get_tree().process_frame
		match choice:
			0:
				_cleanup_and_leave()
				return
			1:
				if GameManager.get_actions_left() < 1:
					_show_msg("行动点不足，只能回安全屋...")
					_cleanup_and_leave()
					return
				await _refresh_room()
			_:
				pass
		is_ui_active = false


func _refresh_room() -> void:
	# 140%60%
	if GameManager.get_actions_left() < 1:
		_show_msg("你已经筋疲力尽了，今天不适合再继续探索...")
		_cleanup_and_leave()
		return
	GameManager.consume_actions(1)
	var occupied_locs := []
	var abandoned_locs := []
	for loc_id in GameManager.EXPLORE_LOCATIONS:
		var loc = GameManager.EXPLORE_LOCATIONS[loc_id]
		if loc.get("room_type", "") == "occupied":
			occupied_locs.append(loc)
		elif loc.get("room_type", "") == "abandoned":
			abandoned_locs.append(loc)

	var loc_data: Dictionary
	if occupied_locs.size() > 0 and (abandoned_locs.size() == 0 or randf() < 0.6):
		loc_data = occupied_locs[randi() % occupied_locs.size()]
	elif abandoned_locs.size() > 0:
		loc_data = abandoned_locs[randi() % abandoned_locs.size()]
	else:
		_show_msg("附近已经没有什么可探索的地方了...")
		_cleanup_and_leave()
		return

	location_data = loc_data
	room_type = loc_data.get("room_type", "abandoned")
	zombie_encountered = false
	has_looted = false
	owner_answered = 0
	kicked_out = false
	steal_attempted = false

	_show_msg("你来到了 %s ..." % loc_data.get("name", ""))
	await get_tree().create_timer(1.0).timeout

	if GameManager.game_over:
		return

	# 25% *0.7
	if randf() < 0.25 * 0.7:
		zombie_encountered = true
		await _zombie_encounter_before_enter()
		if GameManager.game_over:
			return
	else:
		_show_msg(loc_data.get("desc", "..."))
		await get_tree().create_timer(1.5).timeout

	if room_type == "abandoned":
		await _enter_abandoned_house()
	else:
		await _enter_occupied_house()


func _stay_overnight() -> void:
	_show_msg("%s..." % owner_name)
	await get_tree().create_timer(2.0).timeout

	GameManager.current_hour = GameManager.MORNING_RESET
	GameManager.current_day += 1
	GameManager.actions_today = 0
	GameManager.must_sleep = false
	GameManager._update_zombie_level()
	GameManager.do_day_passive()
	GameManager.npcs_used_today.clear()
	GameManager.door_cooldown = 0.0

	GameManager.day_changed.emit(GameManager.current_day)
	GameManager.time_changed.emit(GameManager.current_day, GameManager.current_hour)

	if randf() < 0.50:
		_show_msg("%s翻了个身，嘀咕了几句梦话，继续睡了。" % owner_name)
		await get_tree().create_timer(1.5).timeout
		GameManager.popup_message.emit("---  第 %d 天 ---\n丧尸等级: Lv.%d" % [GameManager.current_day, GameManager.zombie_level])
		_cleanup_and_leave()
		return

	_show_msg("%s已经起床了，正在屋里忙活。" % owner_name)
	GameManager.popup_message.emit("---  %d  ---\n: Lv.%d" % [GameManager.current_day, GameManager.zombie_level])
	has_looted = false
	# 
	for furn in furniture_list:
		furn["looted"] = false
		furn["stolen"] = false
		if is_instance_valid(furn.get("vis")):
			furn["vis"].color = Color(0.18, 0.2, 0.28, 0.9)  # 
		if is_instance_valid(furn.get("label")):
			furn["label"].text = furn.get("disp_name", "")
	_setup_guest_npcs()
	_draw_guest_npcs()


func _game_over_on_explore(reason: String) -> void:
	"""explore_endedmain.gdwhile"""
	GameManager.trigger_game_over(reason)
	GameManager.is_in_guest_house = false
	GameManager.guest_house_owner = ""
	GameManager.guest_house_npcs.clear()
	GameManager.explore_scene_ref = null
	explore_ended.emit("player_dead")


func _cleanup_and_leave() -> void:
	""" main.gd 
	 call_deferred queue_free  emit """
	GameManager.is_in_guest_house = false
	GameManager.guest_house_owner = ""
	GameManager.guest_house_npcs.clear()
	GameManager.explore_scene_ref = null
	#  ——  main.gd UI
	_cleanup_all_popups()
	is_ui_active = false
	#  emitmain.gd  signal handler  bool 
	explore_ended.emit("return_home")


func _kick_out(reason: String) -> void:
	kicked_out = true
	is_ui_active = true  # 
	_show_msg(reason)
	await get_tree().create_timer(2.0).timeout
	_cleanup_and_leave()


# ===  ===
func on_guest_knock(npc_data: Dictionary) -> void:
	_show_msg("咚、咚、咚——有人在敲门！")
	await get_tree().create_timer(1.0).timeout

	var npc_name: String = npc_data.get("name", "")
	_show_msg("门外传来声音：\"是我，%s，能让我进来吗？\"" % npc_name)

	var owner_approves: bool = randf() < 0.60
	if not owner_approves:
		_show_msg("%s摇了摇头：\"不行，人太多了。\"" % owner_name)
		await get_tree().create_timer(1.0).timeout
		_show_msg("门外的脚步声渐渐远去...")
		return

	_show_msg("%s犹豫了一下：\"...好吧，进来吧。\"" % owner_name)
	await get_tree().create_timer(1.0).timeout

	if room_npcs.size() >= 4:
		_show_msg("%s看了看屋里：\"实在挤不下了，抱歉。\"" % owner_name)
		return

	var new_npc := _create_npc_data(npc_name, npc_data.get("type", "survivor"))
	room_npcs.append(new_npc)
	_draw_guest_npcs()
	_show_msg("%s 加入了客屋！现在共有 %d 人。" % [npc_name, room_npcs.size() + 1])


# === UI ===
func _cleanup_all_popups() -> void:
	""" CanvasLayer"""
	var to_remove: Array = []
	for c in get_children():
		if c is CanvasLayer:
			var cname: String = c.name
			#  ExploreUIUI
			if cname != "ExploreUI":
				to_remove.append(c)
	for c in to_remove:
		if is_instance_valid(c):
			c.queue_free()


func _show_msg(text: String) -> void:
	if is_instance_valid(msg_label):
		msg_label.text = text


func _make_btn(text: String, pos: Vector2, size: Vector2, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	#  theme override  Theme—— Godot 
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	# hover / pressed 
	var hover_s := style.duplicate()
	hover_s.bg_color = bg.lightened(0.12)
	btn.add_theme_stylebox_override("hover", hover_s)
	var pressed_s := style.duplicate()
	pressed_s.bg_color = bg.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_s)
	btn.add_theme_font_size_override("font_size", 19)
	return btn


func _show_yes_no(question: String) -> String:
	var popup := CanvasLayer.new()
	popup.name = "YesNoPopup"
	popup.layer = 100
	popup.follow_viewport_enabled = false
	add_child(popup)

	var vp := get_viewport().get_visible_rect()

	# 
	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.3)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim_bg)

	var pw := 360; var ph := 150
	var dialog := Panel.new()
	dialog.position = Vector2((vp.size.x - pw) / 2.0, (vp.size.y - ph) / 2.0)
	dialog.size = Vector2(pw, ph)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", ds)
	popup.add_child(dialog)

	var label := Label.new()
	label.text = question
	label.position = Vector2(0, 22); label.size = Vector2(pw, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
	dialog.add_child(label)

	_popup_result = ""
	_popup_done = false
	var bw := 110
	var bx := (pw - bw * 2 - 16) / 2.0

	var btn_yes := _make_btn("是", Vector2(bx, 90), Vector2(bw, 38),
		Color(0.18, 0.22, 0.28), Color(0.5, 0.52, 0.58))
	dialog.add_child(btn_yes)
	btn_yes.pressed.connect(func():
		if not _popup_done:
			_popup_done = true
			_popup_result = "yes"
			popup.queue_free()
	)

	var btn_no := _make_btn("否", Vector2(bx + bw + 16, 90), Vector2(bw, 38),
		Color(0.12, 0.12, 0.14), Color(0.4, 0.4, 0.42))
	dialog.add_child(btn_no)
	btn_no.pressed.connect(func():
		if not _popup_done:
			_popup_done = true
			_popup_result = "no"
			popup.queue_free()
	)

	while not _popup_done:
		await get_tree().process_frame
	return _popup_result


func _show_choice_dialog(prompt: String, choices: Array) -> int:
	var popup := CanvasLayer.new()
	popup.name = "ChoicePopup"
	popup.layer = 100  # UI
	popup.follow_viewport_enabled = false
	add_child(popup)

	var vp := get_viewport().get_visible_rect()

	# 
	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.3)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim_bg)

	var n := choices.size()
	var pw := 600
	var btn_h := 56
	var spacing := 12
	var h := 80 + n * (btn_h + spacing)
	var dialog := Panel.new()
	dialog.position = Vector2((vp.size.x - pw) / 2.0, (vp.size.y - h) / 2.0)
	dialog.size = Vector2(pw, h)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP  # 
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", ds)
	popup.add_child(dialog)

	if prompt != "":
		var label := Label.new()
		label.text = prompt
		label.position = Vector2(0, 15); label.size = Vector2(pw, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.84))
		dialog.add_child(label)

	_popup_result = -1
	_popup_done = false
	var bw := pw - 80
	var bx := (pw - bw) / 2.0

	for i: int in range(n):
		var btn := _make_btn(choices[i], Vector2(bx, 60 + i * (btn_h + spacing)), Vector2(bw, btn_h),
			Color(0.16, 0.18, 0.26), Color(0.45, 0.48, 0.62))
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", 18)
		dialog.add_child(btn)
		var idx := i
		btn.pressed.connect(func():
			if not _popup_done:
				_popup_done = true; _popup_result = idx; popup.queue_free()
		)

	while not _popup_done:
		await get_tree().process_frame
	return _popup_result


func _show_question_dialog(question: String, options: Array) -> int:
	return await _show_choice_dialog(question, options)
