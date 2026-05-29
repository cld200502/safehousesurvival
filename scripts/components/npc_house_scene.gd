extends Node2D
## NPC  ——  HUD  2D 
## ////
class_name NpcHouseScene

signal house_ended(action: String)  # "return_home" / "kicked_out"

# ===  ===
var owner_name: String = ""
var location_data: Dictionary = {}
var room_npcs: Array = []
var kicked_out: bool = false
var is_ui_active: bool = false
var furniture_list: Array = []
var house_npc_nodes: Array = []  # NPC Area2D
var has_looted: bool = false
var _popup_result: Variant = -1  # 
var _popup_done: bool = false  # 
var block_all_interaction: bool = false  # main.gd/
var block_furniture_only: bool = false   # main.gdNPC

# ===  ===
var player: CharacterBody2D
var camera: Camera2D
var furniture_parent: Node2D
var npc_parent: Node2D
var door_area: Area2D
var msg_label: RichTextLabel
var ui_canvas: CanvasLayer  # UI

# ===  ===
const room_left: float = 80.0
const room_right: float = 1200.0
const ground_y: float = 620.0
const interact_range: float = 90.0


func _ready() -> void:
	z_index = 10
	name = "NpcHouseScene"
	set_process_input(true)


func start_house(loc_data: Dictionary, owner: String, npcs: Array) -> void:
	"""NPC"""
	location_data = loc_data
	owner_name = owner
	room_npcs = npcs
	has_looted = false
	kicked_out = false

	is_ui_active = true  # 

	# ===  ===
	_build_house_scene()

	# 进入屋子——屋主欢迎台词
	_show_msg("%s: 进来吧，别踩到东西。" % owner_name)
	await get_tree().create_timer(1.5).timeout
	_show_msg("%s扫了你一眼，没再说什么。" % owner_name)
	await get_tree().create_timer(1).timeout

	is_ui_active = false


func _build_house_scene() -> void:
	"""++++NPC+UI"""

	# ===  ===
	var bg := ColorRect.new()
	bg.name = "HouseBg"
	bg.color = Color(0.12, 0.11, 0.09, 1.0)
	bg.size = Vector2(1600, 900)
	bg.position = Vector2(-200, -300)
	add_child(bg)

	# 
	var floor_line := ColorRect.new()
	floor_line.name = "Floor"
	floor_line.position = Vector2(-200, ground_y + 10)
	floor_line.size = Vector2(1600, 4)
	floor_line.color = Color(0.28, 0.24, 0.18)
	add_child(floor_line)

	# 
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "%s " % owner_name
	title.position = Vector2(room_left - 40, -280)
	title.size = Vector2(1280, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	add_child(title)

	# ===  ===
	furniture_parent = Node2D.new()
	furniture_parent.name = "Furniture"
	add_child(furniture_parent)
	_place_house_furniture()

	# === NPC ===
	npc_parent = Node2D.new()
	npc_parent.name = "NPCs"
	add_child(npc_parent)
	_draw_house_npcs()

	# ===  ===
	_create_player()

	# ===  ===
	_create_camera()

	# ===  ===
	_create_door_area()

	# === UI ===
	ui_canvas = CanvasLayer.new()
	ui_canvas.name = "HouseUI"
	ui_canvas.layer = 10
	add_child(ui_canvas)

	msg_label = RichTextLabel.new()
	msg_label.name = "MessageLabel"
	msg_label.position = Vector2(0, get_viewport().get_visible_rect().size.y - 200)
	msg_label.size = Vector2(get_viewport().get_visible_rect().size.x, 70)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.bbcode_enabled = true
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	ui_canvas.add_child(msg_label)


func _place_house_furniture() -> void:
	"""x2"""
	furniture_list.clear()

	# X
	var configs := [
		{
			"name": "床铺",
			"pos_x": 200.0,
			"color": Color(0.35, 0.25, 0.18),
			"group": "bed_obj",
			"w": 100, "h": 60,
			"desc": "一张简陋的床铺，可以休息",
			"loot_items": ["cloth"],
			"loot_weight": 8,
		},
		{
			"name": "储物箱",
			"pos_x": 420.0,
			"color": Color(0.55, 0.38, 0.12),
			"group": "storage_obj",
			"w": 90, "h": 100,
			"desc": "一个老旧的储物箱，里面可能有些物资",
			"loot_items": ["food", "wood_stick", "herb"],
			"loot_weight": 25,
		},
		{
			"name": "柜子",
			"pos_x": 620.0,
			"color": Color(0.4, 0.32, 0.22),
			"group": "cabinet_obj",
			"w": 70, "h": 95,
			"desc": "一个破旧的柜子，也许能找到有用的东西",
			"loot_items": ["tomato", "cola", "key"],
			"loot_weight": 15,
		},
		{
			"name": "垃圾桶",
			"pos_x": 820.0,
			"color": Color(0.25, 0.55, 0.25),
			"group": "trash_obj",
			"w": 55, "h": 70,
			"desc": "一个装满垃圾的桶，但也许有意外收获",
			"loot_items": ["glass_shard", "raw_meat"],
			"loot_weight": 12,
		},
		{
			"name": "书架",
			"pos_x": 1020.0,
			"color": Color(0.3, 0.22, 0.15),
			"group": "shelf_obj",
			"w": 65, "h": 105,
			"desc": "一个落满灰尘的书架",
			"loot_items": [],
			"loot_weight": 0,
		},
	]

	# 
	var base_positions := [200.0, 420.0, 620.0, 820.0, 1020.0]
	base_positions.shuffle()
	for i in range(configs.size()):
		configs[i]["pos_x"] = base_positions[i]

	for cfg in configs:
		var furn := _make_furniture_node(cfg)
		furniture_parent.add_child(furn)
		furniture_list.append({
			"name": cfg["name"],
			"node": furn,
			"label": furn.get_node_or_null("FurnLabel"),
			"vis": furn.get_node_or_null("FurnVis"),
			"disp_name": cfg["name"],
			"group": cfg.get("group", ""),
			"looted": false,
			"desc": cfg.get("desc", ""),
			"loot_items": cfg.get("loot_items", []),
			"loot_weight": cfg.get("loot_weight", 0),
			# /
		})


func _make_furniture_node(cfg: Dictionary) -> Area2D:
	""""""
	var area := Area2D.new()
	area.name = "Furn_" + cfg["name"]
	area.position = Vector2(cfg["pos_x"], ground_y - 30)
	area.add_to_group(cfg.get("group", "furn"))

	# 
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(cfg["w"] + 20, cfg["h"] + 20)
	col.shape = rect
	col.position = Vector2(0, -(cfg["h"] + 20) / 2)
	area.add_child(col)

	# 
	var vis := ColorRect.new()
	vis.name = "FurnVis"
	vis.size = Vector2(cfg["w"], cfg["h"])
	vis.position = Vector2(-cfg["w"] / 2.0, -cfg["h"])
	vis.color = cfg["color"]
	vis.color.a = 0.9
	area.add_child(vis)

	# 
	var lbl := Label.new()
	lbl.name = "FurnLabel"
	lbl.text = "[" + cfg["name"] + "]"
	lbl.position = Vector2(-50, -cfg["h"] - 25)
	lbl.size = Vector2(100, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.68, 0.5))
	area.add_child(lbl)

	return area


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
	camera = Camera2D.new()
	camera.name = "HouseCamera"
	camera.zoom = Vector2(1.0, 1.0)
	camera.offset = Vector2(0, -150)
	if is_instance_valid(player):
		player.add_child(camera)
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
	label.text = "大门"
	label.position = Vector2(-30, -125)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	door_area.add_child(label)

	add_child(door_area)


func _clear_all_npc_nodes() -> void:
	"""NPCArea2D"""
	for nd in house_npc_nodes:
		if is_instance_valid(nd.get("area")):
			nd["area"].queue_free()
	house_npc_nodes.clear()
	# npc_parentAI
	for c in npc_parent.get_children():
		c.queue_free()


func _draw_house_npcs() -> void:
	"""NPC"""
	var positions: Array = [300.0, 500.0, 700.0, 900.0]
	positions.shuffle()
	for i: int in range(min(room_npcs.size(), positions.size())):
		var npc_data: Dictionary = room_npcs[i]
		_make_npc_node(npc_data, positions[i])


func _make_npc_node(npc_data: Dictionary, fx: float) -> void:
	var npc_area := Area2D.new()
	npc_area.name = "NPC_" + npc_data["name"]
	npc_area.position = Vector2(fx, ground_y)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 160)  # NPC
	col.shape = rect
	col.position = Vector2(0, -80)
	npc_area.add_child(col)

	# 
	var body := ColorRect.new()
	body.size = Vector2(50, 80)
	body.position = Vector2(-25, -80)
	match npc_data.get("type", "survivor"):
		"survivor":
			if npc_data.get("is_owner", false):
				body.color = Color(0.5, 0.45, 0.25)  # 
			else:
				body.color = Color(0.25, 0.55, 0.3)
		"imposter": body.color = Color(0.35, 0.35, 0.4)
		_: body.color = Color(0.45, 0.4, 0.3)
	npc_area.add_child(body)

	var name_lbl := Label.new()
	name_lbl.text = npc_data["name"]
	if npc_data.get("is_owner", false):
		name_lbl.text += " [房主]"
		name_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	name_lbl.position = Vector2(-50, -100)
	name_lbl.size = Vector2(100, 20)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 15)
	npc_area.add_child(name_lbl)

	# 
	npc_area.collision_layer = 1
	npc_area.collision_mask = 0
	npc_area.input_pickable = true
	npc_area.input_event.connect(_on_npc_clicked.bind(npc_data))

	npc_parent.add_child(npc_area)
	house_npc_nodes.append({"area": npc_area, "data": npc_data})

	# AI
	_start_npc_ai(npc_area, npc_area.position)


func _start_npc_ai(npc_node: Node2D, origin: Vector2) -> void:
	if not is_instance_valid(npc_node):
		return
	var wait_time := randf_range(3.0, 8.0)
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(npc_node) or kicked_out or GameManager.game_over:
		return

	var offset_x := randf_range(-150.0, 150.0)
	var target := Vector2(clamp(origin.x + offset_x, room_left + 50, room_right - 50), ground_y)

	var tween := create_tween()
	tween.tween_property(npc_node, "position", target, randf_range(2.0, 4.0)).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func():
		if is_instance_valid(npc_node) and not kicked_out:
			_start_npc_ai(npc_node, npc_node.position)
	)


# ===  &  ===
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or kicked_out or GameManager.game_over:
		return
	if is_ui_active or block_all_interaction:
		return

	var input_dir := Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		var sprint: float = 2.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
		player.velocity.x = input_dir * 280.0 * sprint
	else:
		player.velocity.x = 0
	player.velocity.y = 0
	player.move_and_slide()

	player.global_position.x = clamp(player.global_position.x, room_left - 200, room_right + 200)
	player.global_position.y = ground_y

	if Input.is_action_just_pressed("interact") and not block_furniture_only:
		_try_interact()


func _input(event: InputEvent) -> void:
	"""NPC"""
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if kicked_out or is_ui_active or block_all_interaction:
		return

	var mouse_pos := get_global_mouse_position()
	for npc_entry in house_npc_nodes:
		var n: Area2D = npc_entry.get("area")
		if not is_instance_valid(n):
			continue
		if mouse_pos.distance_to(n.global_position) < 100:
			_on_talk_to_npc(npc_entry.get("data"))
			return


func _try_interact() -> void:
	# 1. 
	if door_area and player.global_position.distance_to(door_area.global_position) < interact_range:
		_on_door_interact()
		return

	# 2. block_furniture_only
	if not block_furniture_only:
		for furn in furniture_list:
			if furn.get("looted", false):
				continue
			var n: Area2D = furn.get("node")
			if not is_instance_valid(n):
				continue
			if player.global_position.distance_to(n.global_position) < interact_range:
				_on_furniture_interact(furn)
				return

	# 3. 没有可以互动的东西
	_show_msg("附近没有可以互动的东西...")


func _on_door_interact() -> void:
	is_ui_active = true
	var choice := await _show_choice_dialog("要离开这里吗？", ["离开", "留下"])
	match choice:
		0:
			_leave_house()
		_:
			_show_msg("你决定再待一会儿...")
	is_ui_active = false


func _on_furniture_interact(furn: Dictionary) -> void:
	if kicked_out:
		return
	is_ui_active = true

	var furn_name: String = furn.get("disp_name", "")
	var group: String = furn.get("group", "")
	_show_msg("%s%s..." % [owner_name, furn_name])
	await get_tree().create_timer(0.4).timeout

	# 
	if group == "bed_obj":
		var choice: int = await _show_choice_dialog("%s" % furn_name, ["休息", "翻找", "偷窃", "取消"])
		match choice:
			0:
				# 有人屋时，先询问屋主能不能睡
				await _ask_owner_for_sleep(furn)
			1:
				await _do_loot_furniture(furn)
			2:
				await _steal_furniture(furn)
	else:
		var choice: int = await _show_choice_dialog("%s" % furn_name, ["翻找", "偷窃", "取消"])
		match choice:
			0:
				await _do_loot_furniture(furn)
			1:
				await _steal_furniture(furn)

	is_ui_active = false


func _ask_owner_for_sleep(_furn: Dictionary) -> void:
	"""有人屋时，先询问屋主能不能在床上休息"""
	_show_msg("\"%s，我能在床上休息一下吗？\"" % owner_name)
	await get_tree().create_timer(1.0).timeout
	
	# 60%概率同意
	if randf() < 0.6:
		_show_msg("%s \"行吧，别弄脏了。\"" % owner_name)
		await get_tree().create_timer(0.75).timeout
		await _do_sleep_on_bed(_furn)
	else:
		var refuse_msgs := [
			"%s \"不行，那是我睡觉的地方。\"" % owner_name,
			"%s \"抱歉，床铺不对外人开放。\"" % owner_name,
			"%s \"你睡地上吧，床是我的。\"" % owner_name,
		]
		_show_msg(refuse_msgs[randi() % refuse_msgs.size()])
		await get_tree().create_timer(1.0).timeout
		_show_msg("你只好打消了这个念头...")


func _do_sleep_on_bed(_furn: Dictionary) -> void:
	"""在床铺上休息"""
	if not GameManager.is_night():
		_show_msg("现在还不是晚上，无法休息...")
		return
	if GameManager.hp <= 20:
		_show_msg("你伤势太重，无法安心休息...")
		return

	var has_hidden: bool = false
	for npc in room_npcs:
		if npc.get("type", "") == "hidden_infected" and not npc.get("discovered", false) and not npc.get("is_owner", false):
			has_hidden = true
			break

	if has_hidden:
		_show_msg("\"晚安...\"\n%s" % owner_name)
		await get_tree().create_timer(0.75).timeout
		_show_msg("深夜，你听到了奇怪的声音...")
		await get_tree().create_timer(1).timeout

		var candidates := []
		for i in range(room_npcs.size()):
			var npc: Dictionary = room_npcs[i]
			if npc.get("is_owner", false):
				continue
			if npc.get("type", "") == "hidden_infected" and not npc.get("discovered", false):
				continue
			candidates.append(i)

		if candidates.size() > 0:
			if randf() < 0.7:
				var victim_idx: int = candidates[randi() % candidates.size()]
				var victim_name: String = room_npcs[victim_idx].get("name", "")
				var death_msgs := [
					"%s被%s杀死了..." % [victim_name, _get_hidden_name()],
					"%s发出了最后的惨叫..." % victim_name,
					"——%s倒在了血泊中..." % victim_name,
				]
				_show_msg(death_msgs[randi() % death_msgs.size()])
				await get_tree().create_timer(1.25).timeout
				GameManager.modify_sanity(-25)
				room_npcs.remove_at(victim_idx)
				_clear_all_npc_nodes()
				await get_tree().process_frame
				await get_tree().process_frame
				_draw_house_npcs()
				_show_msg("%s已经不在了..." % victim_name)
				await get_tree().create_timer(1).timeout
		else:
			_show_msg("你度过了一个平静的夜晚...")
			await get_tree().create_timer(0.75).timeout
	else:
		_show_msg("\"晚安，好好休息。\"\n%s" % owner_name)
		await get_tree().create_timer(0.75).timeout

	house_ended.emit("sleep")


func _get_hidden_name() -> String:
	""""""
	for npc in room_npcs:
		if npc.get("type", "") == "hidden_infected" and not npc.get("is_owner", false):
			return npc.get("name", "")
	return ""


func _do_loot_furniture(furn: Dictionary) -> void:
	"""翻找家具——获得物资"""
	_show_msg("%s允许你翻找他的东西..." % owner_name)
	await get_tree().create_timer(0.5).timeout

	var loot_items: Array = furn.get("loot_items", [])
	var loot_weight: int = furn.get("loot_weight", 10)
	var found := []

	if loot_items.size() > 0 and loot_weight > 0:
		for item_id in loot_items:
			if randf() < (loot_weight / 100.0) * 0.7:  # 70%
				if GameManager.add_item(item_id):
					var name: String = GameManager.ITEM_DATA.get(item_id, {}).get("name", item_id)
					found.append(name)

	if found.size() > 0:
		_show_msg("找到了: %s" % ", ".join(found))
	else:
		_show_msg("什么也没找到...")


func _steal_furniture(furn: Dictionary) -> void:
	"""偷窃家具——QTE判定"""
	_show_msg("你悄悄翻找%s..." % furn.get("disp_name", ""))
	GameManager.modify_morality(-5, "偷窃行为")
	await get_tree().create_timer(0.5).timeout

	# QTE 
	var qte_result: Dictionary = await _run_qte("小心不要被发现！", "hard", "steal")
	if qte_result.get("grade") == "miss":
		_show_msg("%s发现了你的偷窃行为！" % owner_name)
		await get_tree().create_timer(0.5)
		_kick_player_out("%s把你赶了出去！" % owner_name)
		return

	var loot_items: Array = furn.get("loot_items", [])
	var loot_weight: int = furn.get("loot_weight", 15)
	var found := []

	for item_id in loot_items:
		if randf() < loot_weight / 100.0:
			if GameManager.add_item(item_id):
				var item_name: String = GameManager.ITEM_DATA.get(item_id, {}).get("name", item_id)
				found.append(item_name)

	if found.size() > 0:
		_show_msg("偷到了: %s" % ", ".join(found))
	else:
		_show_msg("什么也没偷到...")


# === NPC  ===
func _on_npc_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, npc_data: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if kicked_out or is_ui_active or block_all_interaction:
			return
		_on_talk_to_npc(npc_data)


func _on_talk_to_npc(npc_data: Dictionary) -> void:
	if kicked_out:
		return
	is_ui_active = true

	var npc_name: String = npc_data["name"]
	var ntype: String = npc_data.get("type", "survivor")

	# NPC
	if npc_name in GameManager.killed_npcs:
		_show_msg("%s已经死了..." % npc_name)
		await get_tree().create_timer(2.0).timeout
		is_ui_active = false
		return

	# 隐藏感染者
	if ntype == "hidden_infected" and not npc_data.get("is_owner", false):
		# 已被发现
		if npc_data.get("discovered", false):
			var tell_choice2 := await _show_choice_dialog(
				"%s是隐藏感染者！" % npc_name,
				["告诉%s" % owner_name, "保持沉默"])
			if tell_choice2 == 0:
				await _report_to_owner(npc_data)
			else:
				_show_msg("你选择了沉默...")
			is_ui_active = false
			return

		var check_choice := await _show_choice_dialog(
			"与 %s 交谈" % npc_name,
			["打招呼", "仔细观察", "杀死他", "AI对话", "离开"])
		if check_choice == 2:
			# 杀死NPC
			await _handle_kill_npc(npc_data)
			is_ui_active = false
			return
		if check_choice == 4:
			is_ui_active = false
			return
		if check_choice == 3:
			# AI对话
			await _npc_ai_dialogue(npc_data)
			is_ui_active = false
			return
		if check_choice == 1:
			# 仔细观察
			block_furniture_only = true
			await _check_hidden_infected(npc_data)
			block_furniture_only = false
			is_ui_active = false
			return
		# 打招呼
		var hi_msgs := [
			"%s: 你好...",
			"%s: 有什么事吗？",
			"%s: ...",
		]
		_show_msg(hi_msgs[randi() % hi_msgs.size()] % npc_name)
		is_ui_active = false
		return

	# 房主对话
	if npc_data.get("is_owner", false):
		await _owner_dialogue(npc_data)
		is_ui_active = false
		return

	# 普通NPC对话选项///AI对话/离开
	var talk_choice := await _show_choice_dialog(
		"与 %s 交谈" % npc_name,
		["打招呼", "仔细观察", "杀死他", "AI对话", "离开"])
	if talk_choice == 4:
		is_ui_active = false
		return
	if talk_choice == 2:
		# 杀死NPC
		await _handle_kill_npc(npc_data)
		is_ui_active = false
		return
	if talk_choice == 3:
		# AI对话
		await _npc_ai_dialogue(npc_data)
		is_ui_active = false
		return
	if talk_choice == 1:
		# QTE观察
		block_furniture_only = true
		_show_msg("你仔细观察%s..." % npc_name)
		await get_tree().create_timer(0.5).timeout
		var qte_result: Dictionary = await _run_qte("仔细观察 %s ..." % npc_name, "normal", "check")
		match qte_result.get("grade"):
			"perfect", "good":
				var observe_msgs := _get_npc_observe_lines(npc_data)
				_show_msg(observe_msgs[randi() % observe_msgs.size()] % npc_name)
			_:
				_show_msg("没能看出%s有什么异常..." % npc_name)
		await get_tree().create_timer(0.75).timeout
		block_furniture_only = false
		is_ui_active = false
		return

	# 打招呼
	var dialogues := {
		"survivor": [
			"\"你好，我是新来的。\"",
			"\"这里安全吗？\"",
			"\"%s是个好人。\"" % owner_name,
			"\"...\"",
			"\"谢谢你们的收留。\"",
		],
		"hidden_infected": [
			"\"你好...\"",
			"\"...\"",
			"\"%s人不错。\"" % owner_name,
		],
	}
	var msgs: Array = dialogues.get(ntype, dialogues["survivor"])
	_show_msg("%s: %s" % [npc_name, msgs[randi() % msgs.size()]])

	is_ui_active = false


func _handle_kill_npc(npc_data: Dictionary) -> void:
	"""杀死NPC——QTE判定"""
	var npc_name: String = npc_data["name"]
	
	# 准备攻击
	_show_msg("[color=red]你决定对%s下手...[/color]" % npc_name)
	await get_tree().create_timer(1.5).timeout
	
	# QTE
	var qte_result: Dictionary = await _run_qte("攻击 %s —— [空格键确认]" % npc_name, "extreme", "kill")
	
	match qte_result.get("grade"):
		"perfect", "good":
			# QTE成功 → 杀死NPC
			GameManager.killed_npcs.append(npc_name)
			GameManager.modify_morality(-20, "杀死了 %s" % npc_name)
			_show_msg("[color=red]%s被你杀死了...[/color]" % npc_name)
			
			# 移除NPC节点
			for entry in house_npc_nodes:
				if entry.get("data", {}).get("name", "") == npc_name:
					var area: Area2D = entry.get("area")
					if is_instance_valid(area):
						area.queue_free()
					house_npc_nodes.erase(entry)
					break
			await get_tree().create_timer(2.5).timeout
		"miss":
			# QTE失败 → NPC反击
			GameManager.modify_morality(-5, "攻击了 %s " % npc_name)
			_show_msg("%s躲开了你的攻击！" % npc_name)
			await get_tree().create_timer(2.0).timeout
			_show_msg("[color=yellow]%s愤怒地看着你...[/color]" % npc_name)


func _owner_dialogue(_npc_data: Dictionary) -> void:
	"""与房主对话"""
	# 准备8个话题
	var all_topics := [
		{
			"topic": "关于这个房子",
			"lines": [
				"上个月找到的，之前的房主已经不在了。",
				"把窗户都封死了，虽然暗了点。",
				"不大，但至少不漏雨。",
			]
		},
		{
			"topic": "关于物资",
			"lines": [
				"东西越来越少了。",
				"囤了一点，但不知道能撑几天。",
				"你要找什么就翻吧，我也不太在意了。",
			]
		},
		{
			"topic": "关于外面的情况",
			"lines": [
				"外面一天比一天安静。",
				"不是好兆头。安静说明它们吃饱了。",
				"听说军队早就撤了，没人会来了。",
			]
		},
		{
			"topic": "关于其他幸存者",
			"lines": [
				"见过几个活人，但后来都没了。",
				"有的死在路上，有的...说不清。",
				"活人比死人难猜，你懂吧。",
			]
		},
		{
			"topic": "关于感染者",
			"lines": [
				"它们以前也是人，这个你知道吧。",
				"有人被咬了还装没事，你小心点。",
				"要是发现我不对劲，别犹豫。",
			]
		},
		{
			"topic": "关于未来",
			"lines": [
				"未来？这两个字很久没想过了。",
				"现在就过一天算一天吧。",
				"等哪天灯灭了，大概就结束了。",
			]
		},
		{
			"topic": "关于你",
			"lines": [
				"你看起来也没睡好。",
				"能活到现在的人，都有点故事吧。",
				"我不问你，你也别问我。",
			]
		},
		{
			"topic": "关于睡觉",
			"lines": [
				"夜里别出去，它们晚上更清醒。",
				"你要是想睡，那边有个角落。",
				"我帮你听着动静，反正我也睡不着。",
			]
		},
	]

	# 随机选4个话题
	all_topics.shuffle()
	var selected_topics := all_topics.slice(0, 4)

	# 构建菜单选项
	var menu_options := []
	for t in selected_topics:
		menu_options.append("%s" % t["topic"])
	menu_options.append("AI对话")
	menu_options.append("离开")

	while true:
		var choice: int = await _show_choice_dialog(
			"与 %s 交谈" % owner_name,
			menu_options
		)

		if choice == selected_topics.size():
			# AI对话
			await _npc_ai_dialogue(_npc_data)
			if kicked_out or GameManager.game_over:
				return
			continue
		if choice < 0 or choice >= selected_topics.size():
			break

		var topic_data: Dictionary = selected_topics[choice]
		var lines: Array = topic_data["lines"]

		# 随机说2-3句
		var count := randi_range(2, 3)
		lines.shuffle()
		for i in range(count):
			if i >= lines.size():
				break
			_show_msg("%s: %s" % [owner_name, lines[i]])
			await get_tree().create_timer(1).timeout
			if kicked_out or GameManager.game_over:
				return

		# 玩家回复选项
		var replies := ["点头", "询问更多", "保持沉默"]
		var reply_choice: int = await _show_choice_dialog("你的回应", replies)
		match reply_choice:
			0:
				_show_msg("%s: 嗯。" % owner_name)
				await get_tree().create_timer(0.5).timeout
			1:
				var extra_lines := ["还想知道什么？", "算了，不说了。"]
				_show_msg("%s: %s" % [owner_name, extra_lines[randi() % extra_lines.size()]])
				await get_tree().create_timer(0.5).timeout
			2:
				_show_msg("%s没再说话。" % owner_name)
				await get_tree().create_timer(0.5).timeout

		if kicked_out or GameManager.game_over:
			return

	_show_msg("%s: 行吧，想聊随时来。" % owner_name)


# NPC AIlambda
var _house_chat_active: bool = false
var _house_npc_dict: Dictionary = {}
var _house_npc_name: String = ""
var _house_chat_panel: Panel = null
var _house_chat_reply: RichTextLabel = null
var _house_input: LineEdit = null
var _house_send_btn: Button = null
var _house_close_btn: Button = null
var _house_ai_running: bool = false

func _npc_ai_dialogue(npc_data: Dictionary) -> void:
	"""NPCAI — +RichTextLabel"""
	var npc_name: String = npc_data["name"]
	_house_npc_dict = {
		"name": npc_name,
		"type": npc_data.get("type", "survivor"),
		"personality": npc_data.get("personality", ""),
		"mood": npc_data.get("mood", ""),
	}
	_house_npc_name = npc_name
	_house_ai_running = false

	if not AIDialogue.is_ai_available():
		_show_msg("[color=red]AI服务暂不可用，请配置API密钥[/color]")
		await get_tree().create_timer(2.5).timeout
		return

	if GameManager.sanity < 2.0:
		_show_msg("[color=red]你的精神已经崩溃，无法正常交流...[/color]")
		await get_tree().create_timer(2.0).timeout
		return

	# 
	AIDialogue._request_pending = false

	# UI
	_remove_house_chat_ui()

	var vsize := get_viewport().get_visible_rect().size

	# 
	var dim_bg := ColorRect.new()
	dim_bg.name = "HouseChatDim"
	dim_bg.color = Color(0, 0, 0, 0.55)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_canvas.add_child(dim_bg)

	#  — 
	_house_chat_panel = Panel.new()
	_house_chat_panel.name = "HouseChatPanel"
	_house_chat_panel.position = Vector2((vsize.x - 500) / 2, (vsize.y - 560) / 2)
	_house_chat_panel.size = Vector2(500, 560)
	_house_chat_panel.self_modulate = Color(0.08, 0.06, 0.12, 0.96)
	_house_chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_canvas.add_child(_house_chat_panel)

	#  — 
	var title := Label.new()
	title.name = "HouseChatTitle"
	title.text = "  %s " % npc_name
	title.position = Vector2(0, 14)
	title.size = Vector2(500, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	_house_chat_panel.add_child(title)

	# 
	var sep := ColorRect.new()
	sep.name = "HouseChatSep"
	sep.position = Vector2(20, 50)
	sep.size = Vector2(460, 1)
	sep.color = Color(0.4, 0.35, 0.25, 0.6)
	_house_chat_panel.add_child(sep)

	# === AIRichTextLabel ===
	_house_chat_reply = RichTextLabel.new()
	_house_chat_reply.name = "HouseChatReply"
	_house_chat_reply.position = Vector2(20, 58)
	_house_chat_reply.size = Vector2(460, 260)
	_house_chat_reply.bbcode_enabled = true
	_house_chat_reply.add_theme_font_size_override("normal_font_size", 24)
	_house_chat_reply.add_theme_color_override("default_color", Color(0.9, 0.88, 0.8))
	_house_chat_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_chat_reply.scroll_active = true
	_house_chat_reply.selection_enabled = true
	_house_chat_reply.text = "[color=#aaaaaa]%s...[/color]" % npc_name
	_house_chat_panel.add_child(_house_chat_reply)

	# 
	var status_label := Label.new()
	status_label.name = "HouseChatStatus"
	status_label.position = Vector2(20, 325)
	status_label.size = Vector2(460, 26)
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_house_chat_panel.add_child(status_label)

	#  — 
	_house_input = LineEdit.new()
	_house_input.name = "HouseChatInput"
	_house_input.position = Vector2(20, 360)
	_house_input.size = Vector2(350, 40)
	_house_input.placeholder_text = "%s..." % npc_name
	_house_input.add_theme_font_size_override("font_size", 24)
	_house_input.editable = false  # AI
	_house_chat_panel.add_child(_house_input)

	# 
	_house_send_btn = Button.new()
	_house_send_btn.name = "HouseChatSend"
	_house_send_btn.text = "发送"
	_house_send_btn.position = Vector2(380, 360)
	_house_send_btn.size = Vector2(100, 40)
	_house_send_btn.add_theme_font_size_override("font_size", 24)
	_house_send_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	_house_send_btn.disabled = true  # 等待AI响应
	_house_chat_panel.add_child(_house_send_btn)

	# 
	_house_close_btn = Button.new()
	_house_close_btn.name = "HouseChatClose"
	_house_close_btn.text = "关闭"
	_house_close_btn.position = Vector2(180, 445)
	_house_close_btn.size = Vector2(140, 36)
	_house_close_btn.add_theme_font_size_override("font_size", 24)
	_house_close_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_house_chat_panel.add_child(_house_close_btn)

	_house_chat_active = true

	# 
	_house_input.text_submitted.connect(_on_house_chat_send)
	_house_send_btn.pressed.connect(_on_house_chat_send)
	_house_close_btn.pressed.connect(_on_house_chat_close)

	# AI
	_generate_npc_opening(npc_name, status_label)


func _generate_npc_opening(npc_name: String, status_label: Label) -> void:
	"""AINPCNPC"""
	if not AIDialogue.is_ai_available():
		# AI不可用
		_house_chat_reply.text = "%s: 你好..." % npc_name
		_house_input.editable = true
		_house_send_btn.disabled = false
		_house_input.grab_focus()
		return

	if is_instance_valid(status_label):
		status_label.text = "AI正在思考..."

	var npc_dict_copy: Dictionary = _house_npc_dict.duplicate()
	AIDialogue.ask_npc(npc_dict_copy, "", func(reply: String, success: bool, _err: String):
		if not _house_chat_active:
			return
		if not is_instance_valid(_house_chat_reply):
			return
		if success and reply != "":
			_house_chat_reply.text = "[color=#88FFAA][b]%s[/b]: %s[/color]" % [npc_name, reply]
		else:
			_house_chat_reply.text = "%s ..." % npc_name
		if is_instance_valid(status_label):
			status_label.text = ""
		# 
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(_house_input):
			_house_input.editable = true
			_house_input.grab_focus()
		if is_instance_valid(_house_send_btn):
			_house_send_btn.disabled = false
	)


func _on_house_chat_send(_text: String = "") -> void:
	""" — +NPC"""
	if not _house_chat_active:
		return
	if not is_instance_valid(_house_input):
		return
	if _house_ai_running:
		return

	var msg: String = _house_input.text.strip_edges()
	if msg == "":
		return
	_house_input.text = ""

	if GameManager.sanity < 2.0:
		_house_chat_reply.text = "[color=red][/color]"
		_house_input.editable = true
		_house_send_btn.disabled = false
		return

	GameManager.modify_sanity(-2.0)

	#  — 
	_house_chat_reply.text = "[color=yellow]...—— %s[/color]" % _house_npc_name
	_house_input.editable = false
	_house_send_btn.disabled = true

	var status_label := _house_chat_panel.get_node_or_null("HouseChatStatus") as Label
	if status_label:
		status_label.text = "正在思考..."

	_house_ai_running = true
	var _reply_area: RichTextLabel = _house_chat_reply
	var _input_edit: LineEdit = _house_input
	var _send_btn: Button = _house_send_btn
	var _status_label: Label = status_label

	AIDialogue.ask_npc(_house_npc_dict, msg, func(reply: String, success: bool, error_msg: String):
		_house_ai_running = false
		if not _house_chat_active:
			return
		if not is_instance_valid(_reply_area):
			return
		if success:
			var display_text := ""
			if msg.length() > 30:
				display_text += msg.substr(0, 28) + "..."
			else:
				display_text += msg
			display_text += "\n\n"
			display_text += "[color=#88FFAA][b]%s[/b]: %s[/color]" % [_house_npc_name, reply]
			_reply_area.text = display_text
			if is_instance_valid(_status_label):
				_status_label.text = ""
		else:
			if error_msg != "":
				_reply_area.text = "[color=red]AI: %s[/color]" % error_msg
			else:
				_reply_area.text = "[color=red]AI服务暂不可用，请稍后再试[/color]"
			if is_instance_valid(_status_label):
				_status_label.text = ""
		if is_instance_valid(_input_edit):
			_input_edit.editable = true
			_input_edit.grab_focus()
		if is_instance_valid(_send_btn):
			_send_btn.disabled = false
	)


func _on_house_chat_close() -> void:
	"""AI"""
	_house_chat_active = false
	_remove_house_chat_ui()


func _remove_house_chat_ui() -> void:
	""""""
	# 
	var dim := ui_canvas.get_node_or_null("HouseChatDim")
	if dim:
		dim.queue_free()
	# 
	if is_instance_valid(_house_chat_panel):
		_house_chat_panel.queue_free()
		_house_chat_panel = null

	_house_chat_reply = null
	_house_input = null
	_house_send_btn = null
	_house_close_btn = null


func _show_text_input(npc_name: String) -> String:
	"""="""
	var vp := get_viewport().get_visible_rect()
	var popup := CanvasLayer.new()
	popup.name = "TextInputPopup"
	popup.layer = 100
	add_child(popup)

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.4)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.add_child(dim_bg)

	var panel := Panel.new()
	panel.position = Vector2((vp.size.x - 400) / 2, (vp.size.y - 160) / 2)
	panel.size = Vector2(400, 160)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.1, 0.1, 0.13, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", ds)
	popup.add_child(panel)

	var label := Label.new()
	label.text = " %s " % npc_name
	label.position = Vector2(0, 14)
	label.size = Vector2(400, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	panel.add_child(label)

	var edit := LineEdit.new()
	edit.position = Vector2(30, 52)
	edit.size = Vector2(340, 34)
	edit.placeholder_text = "输入内容..."
	edit.add_theme_font_size_override("font_size", 16)
	panel.add_child(edit)

	var send_btn := Button.new()
	send_btn.text = "发送"
	send_btn.position = Vector2(90, 100)
	send_btn.size = Vector2(100, 34)
	send_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(send_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(210, 100)
	cancel_btn.size = Vector2(100, 34)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	panel.add_child(cancel_btn)

	var result: String = ""
	var done := false

	send_btn.pressed.connect(func():
		result = edit.text.strip_edges()
		done = true
		popup.queue_free()
	)
	cancel_btn.pressed.connect(func():
		done = true
		popup.queue_free()
	)

	# 
	edit.text_submitted.connect(func(_t: String):
		result = edit.text.strip_edges()
		done = true
		popup.queue_free()
	)

	while not done:
		await get_tree().process_frame

	return result


func _get_npc_observe_lines(npc_data: Dictionary) -> Array[String]:
	"""NPC"""
	var ntype: String = npc_data.get("type", "survivor")
	match ntype:
		"survivor":
			return [
				"%s",
				"%sTA",
				"%sTA",
			]
		"raider":
			return [
				"%s眼神凶狠，看起来不怀好意...",
				"%s似乎正在打量这个房间。",
				"%s身上带着武器，让人感到不安。",
			]
		_:
			return [
				"%s静静地站在那里...",
				"%s看起来行为有些异常。",
				"%s似乎在掩饰什么...",
			]


func _check_hidden_infected(npc_data: Dictionary) -> void:
	"""QTEperfect/good"""
	_show_msg("%s..." % npc_data["name"])
	var qte_result: Dictionary = await _run_qte("...", "normal", "check")
	match qte_result.get("grade"):
		"perfect", "good":
			#  QTE60%
			if randf() < 0.6:
				_show_msg("%s..." % npc_data["name"])
				await get_tree().create_timer(0.75).timeout
				# 
				npc_data["discovered"] = true
				# 
				var tell_choice := await _show_choice_dialog(
					"%s%s" % [npc_data["name"], owner_name],
					["", ""])
				if tell_choice == 0:
					await _report_to_owner(npc_data)
					is_ui_active = false
					return
				else:
					_show_msg("你决定暂时不声张...")
			else:
				_show_msg("%s看起来只是个普通人..." % npc_data["name"])
		_:
			_show_msg("你没能看出%s有什么异常..." % npc_data["name"])


func _report_to_owner(npc_data: Dictionary) -> void:
	""""""
	var npc_name: String = npc_data.get("name", "")
	_show_msg("%s听完后脸色一变，仔细打量着%s..." % [owner_name, npc_name])
	await get_tree().create_timer(0.75).timeout

	_show_msg("%s开始质问%s..." % [owner_name, npc_name])
	await get_tree().create_timer(0.5).timeout

	# 房主反应
	if randf() < 0.75:
		_show_msg("%s\"这个人不对劲！立刻离开这里！\"" % owner_name)
		await get_tree().create_timer(0.75).timeout
		# 驱赶感染者
		_kick_out_hidden(npc_data, npc_name)
	else:
		_show_msg("\"我不是感染者！\"%s辩解道..." % npc_name)
		await get_tree().create_timer(0.75).timeout
		_show_msg("房主将信将疑地看着他...")


func _kick_out_hidden(npc_data: Dictionary, npc_name: String) -> void:
	"""驱赶隐藏感染者"""
	_show_msg("%s愤怒地将%s赶出了房间！" % [owner_name, npc_name])
	await get_tree().create_timer(0.6).timeout

	# 感染者反应
	var reactions := [
		"你...你会后悔的！",
		"我记住你们了...",
		"别让我再碰到你们！",
	]
	_show_msg("%s: %s" % [npc_name, reactions[randi() % reactions.size()]])
	await get_tree().create_timer(0.75).timeout

	# room_npcs
	var remove_idx := -1
	for i in room_npcs.size():
		if room_npcs[i].get("name", "") == npc_name:
			remove_idx = i
			break

	if remove_idx >= 0:
		room_npcs.remove_at(remove_idx)

	# NPCAI
	_clear_all_npc_nodes()
	# queue_free
	await get_tree().process_frame
	await get_tree().process_frame
	_draw_house_npcs()

	_show_msg(" %d " % room_npcs.size())
	await get_tree().create_timer(0.75).timeout

	_show_msg("%s \"...\"" % owner_name)


func _give_item_to_extorter(npc_name: String) -> void:
	"""交出物品给勒索者"""
	var inventory: Variant = GameManager.inventory
	if inventory.size() == 0:
		_show_msg("你身上什么也没有...")
		return

	# 随机交出一个物品
	var inv_keys: Array = []
	for k in inventory:
		inv_keys.append(k)
	inv_keys.shuffle()
	var given_id: String = inv_keys[0]
	var count: int = inventory[given_id]

	GameManager.remove_item(given_id, 1)
	var item_name: String = GameManager.ITEM_DATA.get(given_id, {}).get("name", given_id)
	_show_msg("你把 %s 交给了 %s" % [item_name, npc_name])
	_show_msg("%s满意地收下了物品。" % npc_name)


func _qte_calm_down(npc_name: String) -> void:
	"""QTE"""
	var qte_result: Dictionary = await _run_qte("...", "normal", "check")
	match qte_result.get("grade"):
		"perfect", "good":
			_show_msg("%sTA" % npc_name)
			GameManager.modify_morality(2, "")
		_:
			_show_msg("...TA")
			GameManager.modify_hp(-5)
			GameManager.modify_sanity(-10)


# === / ===
func _leave_house() -> void:
	_show_msg("%s: 走吧，注意看路。" % owner_name)
	await get_tree().create_timer(0.5).timeout
	_cleanup_and_exit("return_home")


func _kick_player_out(reason: String) -> void:
	kicked_out = true
	is_ui_active = true
	_show_msg(reason)
	await get_tree().create_timer(1).timeout
	_cleanup_and_exit("kicked_out")


func _cleanup_and_exit(action: String) -> void:
	GameManager.is_in_guest_house = false
	GameManager.guest_house_owner = ""
	GameManager.guest_house_npcs.clear()
	GameManager.explore_scene_ref = null
	house_ended.emit(action)


# === Q&A ===
func accept_knocker(npc_data: Dictionary) -> void:
	"""接受敲门者进入"""
	if kicked_out:
		return
	is_ui_active = true

	var npc_name: String = npc_data.get("name", "")
	var npc_type: String = npc_data.get("type", "survivor")

	_show_msg("有人在敲门..." % owner_name)
	await get_tree().create_timer(0.5).timeout

	_show_msg("%s请求进入%s的房子..." % [npc_name, owner_name])
	await get_tree().create_timer(0.75).timeout

	if room_npcs.size() >= 5:
		_show_msg("%s \"人太多了，不能再收了...\"" % owner_name)
		await get_tree().create_timer(0.75).timeout
		_show_msg("\n%s失望地离开了..." % npc_name)
		await get_tree().create_timer(0.75).timeout
		is_ui_active = false
		block_all_interaction = false
		return

	# 70%概率同意，30%概率拒绝
	var agree_chance: float = 0.7

	if randf() < agree_chance:
		_show_msg("%s \"进来吧，小心点。\"" % owner_name)
		await get_tree().create_timer(0.5).timeout

		# 添加NPC到房间
		var new_npc := {
			"name": npc_name,
			"type": npc_type,
			"is_owner": false  # 不是房主
		}
		room_npcs.append(new_npc)

		# 刷新NPC显示
		_clear_all_npc_nodes()
		await get_tree().process_frame
		await get_tree().process_frame
		_draw_house_npcs()

		_show_msg("现在房间里有 %d 个人了。" % room_npcs.size())
		await get_tree().create_timer(0.75).timeout

		# 房主的评价
		_ask_owner_advice(npc_name, npc_type)
	else:
		# 拒绝
		var refuse_msgs := [
			"%s \"对不起，这里满了。\"" % owner_name,
			"%s \"我们不接收陌生人了。\"" % owner_name,
			"%s \"抱歉，你还是去别处吧。\"" % owner_name,
		]
		_show_msg(refuse_msgs[randi() % refuse_msgs.size()])
		await get_tree().create_timer(0.75).timeout
		_show_msg("%s无奈地离开了..." % npc_name)
		is_ui_active = false
		block_all_interaction = false


func get_room_npc_count() -> int:
	return room_npcs.size()


func _ask_owner_advice(npc_name: String, npc_type: String) -> void:
	"""房主对新来者的评价"""
	# 根据NPC类型给出不同评价
	var reactions: Array[String] = []
	match npc_type:
		"survivor":
			reactions = [
				"%s \"看起来是个好人，应该没问题。\"",
				"%s \"大家互相帮助才能活下去。\"",
				"%s \"多一个人多一份力量。\"",
				"%s \"希望他不会惹麻烦...\"",
			]
		"hidden_infected":
			reactions = [
				"%s \"这个人看起来有些奇怪...\"",
				"%s \"我觉得他不对劲，大家小心点。\"",
				"%s \"希望是我想多了...\"",
			]
		_:
			reactions = [
				"%s \"我们看看情况再说。\"",
			]

	var advice := reactions[randi() % reactions.size()]
	_show_msg(advice % owner_name)
	await get_tree().create_timer(1).timeout

	# 返回main.gd中的对话
	is_ui_active = false
	block_all_interaction = false


# === UI  ===
func _show_msg(text: String) -> void:
	if is_instance_valid(msg_label):
		msg_label.text = text
		# 3
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(msg_label) and msg_label.text == text:
			msg_label.text = ""


func _run_qte(prompt_text: String, difficulty: String, _scene_type: String = "check") -> Dictionary:
	"""QTE 场景类型: check/kill/extort/steal"""
	#  QTE 
	var vp_size := get_viewport().get_visible_rect().size
	var qte_layer := CanvasLayer.new()
	qte_layer.name = "QTELayer"
	qte_layer.layer = 100
	add_child(qte_layer)

	var qte_bg := Panel.new()
	qte_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.03, 0.02, 0.92)
	qte_bg.add_theme_stylebox_override("panel", bg_style)
	qte_layer.add_child(qte_bg)

	# 
	var hint := Label.new()
	hint.text = prompt_text
	hint.position = Vector2(0, vp_size.y * 0.3)
	hint.size = Vector2(vp_size.x, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	qte_layer.add_child(hint)

	# QTE 
	var bar_w := 520.0
	var bar_h := 14.0
	var bar_x := (vp_size.x - bar_w) / 2.0
	var bar_y := vp_size.y * 0.52

	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_bg.position = Vector2(bar_x, bar_y)
	bar_bg.color = Color(0.3, 0.2, 0.2)
	qte_layer.add_child(bar_bg)

	# good zone
	var speed: float
	var good_w: float
	var perfect_w: float
	match difficulty:
		"easy": speed = 250.0; good_w = 100.0; perfect_w = 30.0
		"normal": speed = 420.0; good_w = 70.0; perfect_w = 18.0
		"extreme": speed = 560.0; good_w = 30.0; perfect_w = 5.0
		_: speed = 440.0; good_w = 50.0; perfect_w = 10.0

		#  = good zone 
	var good_center := bar_w / 2.0  # bar_x
	var good_zone := ColorRect.new()
	good_zone.size = Vector2(good_w, bar_h)
	good_zone.position = Vector2(bar_x + good_center - good_w / 2.0, bar_y)
	good_zone.color = Color(0.15, 0.55, 0.2)  # 
	qte_layer.add_child(good_zone)

	# 
	var perfect_center := bar_w / 2.0  # bar_x
	var perfect_zone := ColorRect.new()
	perfect_zone.size = Vector2(perfect_w, bar_h)
	perfect_zone.position = Vector2(bar_x + perfect_center - perfect_w / 2.0, bar_y)
	perfect_zone.color = Color(0.3, 0.8, 0.35)  # 
	qte_layer.add_child(perfect_zone)

	# 
	var ptr := ColorRect.new()
	ptr.size = Vector2(8, bar_h + 8)
	ptr.position = Vector2(bar_x - 4, bar_y - 4)
	ptr.color = Color(0.9, 0.3, 0.3)
	qte_layer.add_child(ptr)

	# 按键提示
	var space_hint := Label.new()
	match _scene_type:
		"check":
			space_hint.text = "【仔细观察】在指针进入绿色区域时按下 [空格键] 确认"
		"kill":
			space_hint.text = "【准备攻击】在指针进入绿色区域时按下 [空格键] 下手"
		"extort":
			space_hint.text = "【反抗勒索】在指针进入绿色区域时按下 [空格键] 反击"
		"steal":
			space_hint.text = "【偷偷行动】在指针进入绿色区域时按下 [空格键] 下手"
		_:
			space_hint.text = "在指针进入绿色区域时按下 [空格键] 确认"
	space_hint.position = Vector2(0, bar_y + 35)
	space_hint.size = Vector2(vp_size.x, 25)
	space_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	space_hint.add_theme_font_size_override("font_size", 17)
	space_hint.add_theme_color_override("font_color", Color(0.5, 0.48, 0.42))
	qte_layer.add_child(space_hint)

	# 
	var pos := 0.0
	var dir_flag := 1
	var finished := false
	var result_dict: Dictionary = {}
	var space_was_pressed := false

	while not finished:
		await get_tree().process_frame
		pos += dir_flag * speed * get_process_delta_time()
		if pos >= bar_w - 8:
			pos = bar_w - 8; dir_flag = -1
		elif pos <= 0:
			pos = 0; dir_flag = 1
		ptr.position.x = bar_x + pos

		var space_now := Input.is_key_pressed(KEY_SPACE)
		if space_now and not space_was_pressed:
			finished = true
			var ptr_center := pos + 4.0
			# 
			var good_left := good_center - good_w / 2.0
			var good_right := good_center + good_w / 2.0
			if ptr_center >= good_left and ptr_center <= good_right:
				#  → 
				if absf(ptr_center - perfect_center) <= perfect_w / 2.0:
					result_dict = {"success": true, "grade": "perfect"}
				else:
					result_dict = {"success": true, "grade": "good"}
			else:
				result_dict = {"success": false, "grade": "miss"}
		space_was_pressed = space_now

	qte_layer.queue_free()
	return result_dict


func _show_choice_dialog(prompt: String, choices: Array) -> int:
	"""显示选择对话框，返回用户选择的索引，-1表示取消"""
	var popup := CanvasLayer.new()
	popup.name = "ChoicePopup"
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

	var n := choices.size()
	var pw := 400
	var h := 55 + n * 42
	if prompt != "":
		h += 36
	var dialog := Panel.new()
	dialog.position = Vector2((vp.size.x - pw) / 2, (vp.size.y - h) / 2)
	dialog.size = Vector2(pw, h)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.12, 0.12, 0.14, 0.96)
	ds.set_border_width_all(1)
	ds.border_color = Color(0.35, 0.35, 0.38)
	ds.set_corner_radius_all(6)
	dialog.add_theme_stylebox_override("panel", ds)
	popup.add_child(dialog)

	var yo := 18.0
	if prompt != "":
		var plabel := Label.new()
		plabel.text = prompt
		plabel.position = Vector2(0, yo); plabel.size = Vector2(pw, 30)
		plabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plabel.add_theme_font_size_override("font_size", 19)
		plabel.add_theme_color_override("font_color", Color(0.82, 0.8, 0.76))
		dialog.add_child(plabel)
		yo += 34.0

	_popup_result = -1
	_popup_done = false
	var bw: float = min(pw - 40, 300)

	for i: int in range(n):
		var btn := Button.new()
		btn.text = choices[i]
		btn.position = Vector2((pw - bw) / 2, yo + i * 40)
		btn.size = Vector2(bw, 36)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.2, 0.26)
		style.set_border_width_all(1)
		style.border_color = Color(0.45, 0.48, 0.55)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.bg_color = Color(0.2, 0.24, 0.31)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_font_size_override("font_size", 18)
		dialog.add_child(btn)
		btn.pressed.connect(func():
			if _popup_done: return
			_popup_done = true; _popup_result = i; popup.queue_free()
		)

	while not _popup_done:
		await get_tree().process_frame
	return _popup_result
