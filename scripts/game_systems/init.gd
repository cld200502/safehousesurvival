extends Node2D

# ========== 游戏初始化 · 核心逻辑 ==========
# 2D场景 + 角色 + 时间系统 + QTE

# ===  ===
var current_day = 1
var current_hour = 8.0
var time_speed = 80.0
var game_over = false
var is_exploring = false

# ===  ===
var hp = 100
var max_hp = 100
var hunger = 100.0
var max_hunger = 100.0
var sanity = 100.0

# ===  ===
var kill_count = 0

# ===  ===
var npc_at_door = null
var door_cooldown = 0.0
var door_cooldown_max = 12.0
var active_npc_data = null

# ===  ===
var cabinet_items = {}

# === NPC ===
var room_npcs = []

# === NPC ===
var npc_pool = []

# ===  ===
var EXPLORE_LOCATIONS = {}
var explore_return_warning = false

# ===  ===
@onready var player = $Player
@onready var ui = $UIManager
@onready var dialogue_sys = $DialogueSystem
@onready var qte_sys = $QTESystem
@onready var game_data_node = $GameData
@onready var room_bg = $RoomBackground
var door_sprite: Sprite2D = null
@onready var door_area = $DoorArea
@onready var cabinets_parent = $Cabinets
@onready var room_npcs_parent = $RoomNPCs

# 
var start_screen = null
var game_started = false


# ====================  ====================
func _ready():
	randomize()
	game_started = false

	# 
	start_screen = get_node_or_null("StartScreen")
	if start_screen:
		start_screen.start_game.connect(_on_start_game_pressed)

	# 
	_draw_room_background()
	_setup_door()
	_setup_cabinets()
	_init_npc_pool()
	_init_explore_locations()
	_init_player()

	# 
	if start_screen:
		await start_screen.start_game
	else:
		# 
		_begin_game()


func _on_start_game_pressed():
	if game_started:
		return
	game_started = true
	_begin_game()


func _begin_game():
	ui.update_hp(hp, max_hp)
	ui.update_hunger(hunger, max_hunger)
	ui.update_sanity(sanity)
	ui.update_time_label(current_day, current_hour)
	ui.update_kills(kill_count)

	# 
	game_data_node.add_item("food", 2)
	game_data_node.add_item("cola", 1)

	# 
	await get_tree().create_timer(1.5).timeout
	dialogue_sys.show_event_dialogue(
		"???",
		"丧尸病毒在全球爆发已经一周了\n城市已经沦陷...\n\n你独自躲在这间安全屋里\n物资所剩无几\n窗外传来丧尸的嘶吼声...\n",
		[{"text": "活下去...", "result": "ok"}],
		_on_intro_end
	)


# ====================  ====================
func _can_spend_action():
	if game_over or not game_started:
		return false
	if hunger <= 0:
		ui.show_message("太饿了...没有力气行动", 1.5)
		return false
	if hp <= 5:
		ui.show_message("伤势太重...无法行动", 1.5)
		return false
	return true


# ====================  ====================
func _init_player():
	player.room_left = 120.0
	player.room_right = 1200.0
	player.ground_y = 590.0


# ====================  ====================
func _draw_room_background():
	var w = 1280
	var h = 720
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)

	# 
	var wall_tex = load("res://assets/textures/wallwall.png")

	if wall_tex:
		#  wall1.png 
		var wall_img = wall_tex.get_image()
		wall_img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(wall_img, Rect2i(0, 0, w, h), Vector2i(0, 0))

		# 
		_draw_window_overlay(img)

	else:
		# 
		_draw_procedural_background(img)

	room_bg.texture = ImageTexture.create_from_image(img)
	room_bg.position = Vector2(0, 0)
	room_bg.z_index = -10
	room_bg.centered = false


func _draw_window_overlay(img):
	var w = img.get_width()
	var wx = 620
	var wy = 100
	var ww = 140
	var wh = 160

	#  ""
	for x in range(wx + 5, wx + ww - 5):
		for y in range(wy + 5, wy + wh - 5):
			var sky = 0.4 + sin((x + current_day * 10) * 0.03) * 0.1
			img.set_pixel(x, y, Color(sky * 0.5, sky * 0.55, sky * 0.7, 0.85))

	# 
	for t in range(6):
		for x in range(wx, wx + ww):
			img.set_pixel(x, wy + t, Color(0.2, 0.16, 0.12))
			img.set_pixel(x, wy + wh - t, Color(0.2, 0.16, 0.12))
		for y in range(wy, wy + wh):
			img.set_pixel(wx + t, y, Color(0.2, 0.16, 0.12))
			img.set_pixel(wx + ww - t, y, Color(0.2, 0.16, 0.12))

	# 
	for x in range(wx, wx + ww):
		for y in range(wy + wh / 2 - 3, wy + wh / 2 + 3):
			img.set_pixel(x, y, Color(0.2, 0.16, 0.12))
	for y in range(wy, wy + wh):
		for x in range(wx + ww / 2 - 3, wx + ww / 2 + 3):
			img.set_pixel(x, y, Color(0.2, 0.16, 0.12))

	# 
	for i in range(20):
		var bx = wx + randi() % 130 + 5
		var by = wy + randi() % 150 + 5
		for dx in range(-2, 3):
			for dy in range(-4, 1):
				if randf() < 0.5:
					var px = bx + dx
					var py = by + dy
					if px > wx + 5 and px < wx + ww - 5 and py > wy + 5 and py < wy + wh - 5:
						img.set_pixel(px, py, Color(0.6, 0.05, 0.05, 0.5))


func _draw_procedural_background(img):
	var w = img.get_width()
	var h = img.get_height()

	# 
	for x in range(w):
		for y in range(50):
			var shade = 0.2 + sin(x * 0.02) * 0.03
			img.set_pixel(x, y, Color(shade, shade * 0.9, shade * 0.8))

	for x in range(w):
		for y in range(48, 52):
			img.set_pixel(x, y, Color(0.12, 0.1, 0.08))

	# 
	for x in range(w):
		for y in range(50, 370):
			var shade = 0.35 + sin(x * 0.005 + y * 0.01) * 0.04 + sin(x * 0.03) * 0.02
			img.set_pixel(x, y, Color(shade, shade * 0.85, shade * 0.7))

	# 
	for x in range(w):
		for y in range(370, 720):
			var board_idx = int((y - 370) / 24)
			var shade = 0.25 + sin(x * 0.01 + board_idx * 0.7) * 0.04
			var gap_y = 370 + board_idx * 24
			if y - gap_y < 1:
				img.set_pixel(x, y, Color(0.08, 0.06, 0.04))
			else:
				img.set_pixel(x, y, Color(shade, shade * 0.65, shade * 0.45))

	# 
	_draw_window_overlay(img)


# ====================  ====================
func _setup_door():
	# 
	door_sprite = Sprite2D.new()
	door_sprite.name = "DoorSprite"
	add_child(door_sprite)

	var door_tex = load("res://assets/textures/menmen.png")
	if not door_tex:
		door_tex = load("res://assets/textures/men.png")  # 
	if not door_tex:
		door_tex = load("res://assets/textures/door.png")  # 
	if door_tex:
		door_sprite.texture = door_tex
		door_sprite.scale = Vector2(0.5, 0.5)
		door_sprite.position = Vector2(1200, 520)
		door_sprite.z_index = -1  # 
		door_sprite.visible = true
		# 
		var door_visual := door_area.get_node_or_null("DoorVisual") as ColorRect
		if door_visual:
			door_visual.visible = false
	else:
		push_warning("[init.gd] 未找到门纹理资源")

	door_area.position = Vector2(1290, 580)


# ====================  ====================
func _setup_cabinets():
	# 3
	var cab_positions = [
		Vector2(880, 480),
		Vector2(990, 480),
		Vector2(1100, 480),
	]
	var cab_names = ["储物柜", "药品柜", "工具柜"]

	_init_cabinet_items()

	# 
	var cab_tex = load("res://assets/textures/cabinet.png")
	if not cab_tex:
		push_warning("[init.gd]  cabinet.png ")

	for i in range(3):
		var cab = Sprite2D.new()
		cab.name = "cabinet_%d" % i
		cab.position = cab_positions[i]
		cab.texture = cab_tex
		cab.scale = Vector2(0.3, 0.35)
		cab.z_index = 0
		cab.add_to_group("cabinet")
		cabinets_parent.add_child(cab)

		# 
		var area = Area2D.new()
		area.name = "CabArea"
		area.position = cab_positions[i] + Vector2(0, -80)
		area.collision_layer = 0
		area.collision_mask = 0
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.size = Vector2(60, 160)
		col.shape = rect
		area.add_child(col)
		area.add_to_group("cabinet_area")
		add_child(area)

		# 
		var label = Label.new()
		label.name = "CabLabel"
		label.position = Vector2(-30, -100)
		label.text = cab_names[i]
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		label.add_theme_font_size_override("font_size", 15)
		cab.add_child(label)

		# 
		var key = "cabinet_%d" % i
		cabinet_items[key] = {
			"name": cab_names[i],
			"items": _gen_cabinet_items(),
			"searched": false,
			"sprite": cab,
		}


func _init_cabinet_items():
	pass


func _gen_cabinet_items():
	var pools = [
		["food", "cola", "knife", "medicine"],
		["medicine", "bandage", "food", "key"],
		["cola", "food", "food", "ammo"],
	]
	return pools[randi() % pools.size()]


# ==================== NPC ====================
func _init_npc_pool():
	npc_pool = [
		{"name": "王医生", "type": "survivor",
		 "intro": "...我是医生。让我进去的话，能帮你们处理伤口。",
		 "personality": "四十多岁的社区医生，妻子在第一天就没了。已经不想救任何人了，但手里还有绷带和药，不给人用又觉得浪费。说话像在自言自语。",
		 "speaking_style": "声音很轻，像是在省着力气说话。不用括号描述动作，直接说话。不要热血，不要励志。",
		 "qte_difficulty": "easy", "reward": "food", "avatar_idx": 0},
		{"name": "小李", "type": "survivor",
		 "intro": "让我进去吧...我已经在外面躲了好几天了...",
		 "personality": "二十出头的便利店店员，爸妈都联系不上了。不是想活，是不知道怎么去死。声音有点发抖，但不是在哭。",
		 "speaking_style": "声音很轻，经常停顿，像是在思考下一句值不值得说。不用括号描述动作，直接说话。不要热血。",
		 "qte_difficulty": "normal", "reward": "medicine", "avatar_idx": 1},
		{"name": "老陈", "type": "survivor",
		 "intro": "我以前当过兵...能帮忙守门。",
		 "personality": "退役老兵，四十多岁，身体还硬朗。战友都死了，他把他们的狗牌都挂在脖子上。不是想当英雄，只是不知道该干什么别的。",
		 "speaking_style": "话很少，每一句都像是从牙缝里挤出来的。不用括号描述动作，直接说话。不热血。",
		 "qte_difficulty": "hard", "reward": "knife", "avatar_idx": 2},
		{"name": "阿芳", "type": "survivor",
		 "intro": "我带了药品...只想要个安全的地方...",
		 "personality": "三十多岁的护士，离婚后独居，出事那天正好值夜班。见惯了病人在她面前咽气。现在看到活人反而有点不习惯。",
		 "speaking_style": "说话很平淡，像是在报病历。偶尔会沉默很久。不用括号描述动作，直接说话。",
		 "qte_difficulty": "normal", "reward": "medicine", "avatar_idx": 3},
		{"name": "小张", "type": "survivor",
		 "intro": "有人吗...我已经三天没吃东西了...",
		 "personality": "外卖骑手，二十多岁，出事的时侯正在送最后一单。电动车没电了，手机也没信号了。不是来求救的，就是路过看看有没有活人。",
		 "speaking_style": "声音沙哑，断断续续，像是嗓子已经干了很久。不用括号描述动作，直接说话。",
		 "qte_difficulty": "easy", "reward": "food", "avatar_idx": 4},
		{"name": "林姐", "type": "survivor",
		 "intro": "我这里有点物资，可以分你们...开门吧。",
		 "personality": "四十多岁的超市老板娘，老公在混乱中跑散了。店里还剩些东西，一个人也吃不完。不是慷慨，是觉得一个人活着也没什么意思。",
		 "speaking_style": "语气平淡，像是在跟你聊今天的菜价。不用括号描述动作，直接说话。",
		 "qte_difficulty": "easy", "reward": "cola", "avatar_idx": 5},
		# --- 伪装者 ---
		{"name": "赵队长", "type": "imposter",
		 "intro": "开门！我是救援队的！快点，这里不安全！",
		 "personality": "原本是小区的保安队长，末日之后发现自己没什么特长，只能靠抢。嘴上说是救援，其实是看上了别人家里的东西。心里也有点虚，但更怕饿死。",
		 "speaking_style": "假装有底气，但偶尔会露出心虚的停顿。不用括号描述动作，直接说话。",
		 "qte_difficulty": "hard", "reward": null, "avatar_idx": 6,
		 "fake_name": "赵队长"},
		{"name": "钱工", "type": "imposter",
		 "intro": "我在隔壁住了很久了...想过来看看你们还好吗。",
		 "personality": "原来是个会计，末日之后发现老实人活不下去。假装温和只是想让人放松警惕。自己也知道这样不对，但已经回不了头了。",
		 "speaking_style": "语气平和但偶尔漏出冷漠。不用括号描述动作，直接说话。",
		 "qte_difficulty": "extreme", "reward": null, "avatar_idx": 7,
		 "fake_name": "钱工"},
		# --- 丧尸 ---
		{"name": "???", "type": "zombie",
		 "intro": "......吼......",
		 "qte_difficulty": "normal", "reward": null, "avatar_idx": -1},
		{"name": "???", "type": "zombie",
		 "intro": "砰！砰！砰！\n（剧烈的撞门声，伴随着低沉的嘶吼）",
		 "qte_difficulty": "easy", "reward": null, "avatar_idx": -1},
	]


# ====================  ====================
func _init_explore_locations():
	EXPLORE_LOCATIONS = {
		"convenience": {
			"name": "便利店",
			"desc": "24小时便利店\n橱窗已经破碎，但货架上似乎还有残留的物资\n周围安静得可怕",
			"time_cost": 2.0,
			"danger": 0.2,
			"items": ["food", "food", "cola", "food"],
			"horror_event": "\n你弯腰拾起罐头的时候...\n余光瞥见角落的阴影中有什么在动...\n\n你屏住呼吸，慢慢后退...\n——\n一阵寒风从破碎的窗户灌入\n货架上的空罐子被吹落在地，发出清脆的响声",
		},
		"pharmacy": {
			"name": "药房",
			"desc": "社区药房\n药柜被翻得一片狼藉\n但角落里似乎还有被遗漏的药品",
			"time_cost": 2.0,
			"danger": 0.25,
			"items": ["medicine", "bandage", "medicine", "bandage"],
			"horror_event": "\n药房深处传来奇怪的声响\n像是有人在用指甲刮墙壁...\n\n你加快脚步离开了",
		},
		"apartment": {
			"name": "302公寓",
			"desc": "居民楼302室\n门虚掩着，里面似乎发生过激烈的搏斗\n墙上溅满了暗红色的污渍",
			"time_cost": 2.0,
			"danger": 0.4,
			"items": ["knife", "key", "ammo", "note"],
			"horror_event": "\n你走进卧室...\n——\n衣柜突然剧烈晃动！\n\n有什么东西在里面！\n你立刻退了出来，头也不回地离开了这间公寓",
		},
		"police": {
			"name": "警察局",
			"desc": "城区警察局\n大门被撞开了，里面一片混乱\n但枪械室的铁门似乎还完好无损...",
			"time_cost": 2.0,
			"danger": 0.55,
			"items": ["ammo", "knife", "ammo", "key"],
			"horror_event": "\n走廊里到处都是干涸的血迹\n警徽散落一地...\n\n——\n拐角处传来沉重的脚步声\n那不是活人的步伐\n\n你屏住呼吸，贴着墙壁慢慢移动\n终于在对方发现你之前溜了出去",
		},
		"garage": {
			"name": "地下车库",
			"desc": "公寓地下车库\n漆黑一片，只有你的手电筒照亮前方几步\n空气中弥漫着汽油和腐烂的气味",
			"time_cost": 2.0,
			"danger": 0.35,
			"items": ["food", "cola", "medicine", "ammo"],
			"horror_event": "\n黑暗中你踢到了什么东西\n——\n手电筒照过去...\n那是一具早已腐烂的尸体\n旁边散落着几瓶没开过的矿泉水和一包压缩饼干\n\n你匆匆拾起物资，头也不回地跑向出口\n\n身后似乎有影子在晃动...\n但你不敢回头确认",
		},
	}


# ====================  ====================
func _process(delta):
	if game_over or not game_started:
		return

	if not is_exploring:
		current_hour += delta / time_speed
		if current_hour >= 24.0:
			current_hour = 0.0
			current_day += 1
			_on_new_day()

		# 
		hunger -= delta / time_speed * 1.5
		hunger = clamp(hunger, 0, max_hunger)

		# UI
		ui.update_hp(hp, max_hp)
		ui.update_hunger(hunger, max_hunger)
		ui.update_sanity(sanity)
		ui.update_time_label(current_day, current_hour)

		# 
		if door_cooldown > 0:
			door_cooldown -= delta
		elif active_npc_data == null and current_hour >= 18.0 and not is_exploring:
			# 6
			if randf() < delta * 0.06:
				_trigger_knock_event()

		# 
		if hunger <= 0:
			hp -= delta * 4
			if hp <= 0:
				_on_game_over("饥饿而死...\n在这末日中，食物比武器更重要")




# ====================  ====================
func _on_new_day():
	ui.show_message("—— 第 %d 天 ——" % current_day, 2.5)
	# 
	for key in cabinet_items:
		if cabinet_items[key].get("sprite"):
			var cab = cabinet_items[key]
			cab["searched"] = false
			cab["items"] = _gen_cabinet_items()
			var label = cab["sprite"].get_node_or_null("CabLabel")
			if label:
				label.text = cab["name"]
				label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))

	hp = min(max_hp, hp + 5)
	sanity = min(100, sanity + 5)
	explore_return_warning = false


# ====================  ====================
func _trigger_knock_event():
	if active_npc_data != null or door_cooldown > 0 or is_exploring:
		return

	var pool = npc_pool.duplicate()
	pool.shuffle()
	active_npc_data = pool[0]

	ui.show_message("—— 咚咚咚...有人在敲门...", 1.5)
	await get_tree().create_timer(1.2).timeout

	# NPC
	var npc_tex = _load_npc_avatar(active_npc_data.get("avatar_idx", 0))

	dialogue_sys.show_event_dialogue(
		"门外的人",
		"%s" % active_npc_data["intro"],
		[
			{"text": "开门", "result": "open"},
			{"text": "假装不在", "result": "ignore"},
			{"text": "猫眼观察", "result": "peek"},
		],
		_handle_knock_choice,
		npc_tex
	)


func _handle_knock_choice(choice):
	match choice:
		"open": _on_open_door()
		"ignore": _on_ignore_door()
		"peek": _on_peek_door()


func _on_open_door():
	var npc = active_npc_data
	if npc == null:
		return
	match npc["type"]:
		"survivor": _door_survivor(npc)
		"imposter": _door_imposter(npc)
		"zombie": _door_zombie(npc)


func _door_survivor(npc):
	var npc_tex = _load_npc_avatar(npc.get("avatar_idx", 0))
	dialogue_sys.show_event_dialogue(
		npc["name"],
		"我是%s，请让我进去避难！\n" % npc["name"],
		[
			{"text": "让他进来", "result": "accept"},
			{"text": "质疑身份——QTE验证", "result": "qte"},
		],
		_on_door_survivor_choice.bind(npc),
		npc_tex
	)


func _on_door_survivor_choice(choice, npc):
	match choice:
		"accept":
			_receive_survivor(npc)
		"qte":
			_start_id_qte(npc)


func _receive_survivor(npc):
	if npc.has("reward") and npc["reward"]:
		game_data_node.add_item(npc["reward"], 1)
		var item_data = game_data_node.ITEM_DATA.get(npc["reward"], {})
		ui.show_message("获得: %s" % item_data.get("name", npc["reward"]), 2.0)

	# NPC
	_spawn_room_npc(npc)

	dialogue_sys.show_event_dialogue(
		npc["name"],
		"谢谢你...我会尽我所能帮忙的\n——%s" % npc["name"],
		[{"text": "好的", "result": "ok"}],
		func(_c): _end_door_event()
	)


func _door_imposter(npc):
	var npc_tex = _load_npc_avatar(npc.get("avatar_idx", 6))
	var fname: String = npc.get("fake_name", "")
	dialogue_sys.show_event_dialogue(
		fname,
		"呵呵...终于让我进来了\n\n你们这里的物资看起来很丰富嘛...\n可惜马上就是我的了！\n",
		[{"text": "战斗！", "result": "fight"}],
		func(_c): _start_combat_qte(npc, "imposter")
		,
		npc_tex
	)


func _door_zombie(npc):
	var npc_tex = _load_npc_avatar(-1)
	dialogue_sys.show_event_dialogue(
		"!!!",
		"门外的不是人！\n\n——一只丧尸正在撞门！",
		[{"text": "迎战！", "result": "fight"}],
		func(_c): _start_combat_qte(npc, "zombie")
		,
		npc_tex
	)


func _on_ignore_door():
	dialogue_sys.show_event_dialogue(
		"",
		"你假装不在家\n\n门外的声音渐渐远去了...",
		[{"text": "...但愿他们走了", "result": "ok"}],
		_on_ignore_door_end
	)


func _on_peek_door():
	var npc = active_npc_data
	var peek_text = "...\n"

	if npc["type"] == "zombie":
		peek_text += "\n门外是一只可怕的丧尸！\n它的脸紧贴着猫眼...\n"
		sanity = max(0, sanity - 10)
	elif npc["type"] == "imposter":
		peek_text += "\n这个人看起来不对劲...\n——\n眼神闪烁，衣着可疑\n...最好小心行事"
		sanity = max(0, sanity - 8)
	else:
		peek_text += "%s\n看起来是个普通的幸存者\n似乎没有恶意\n" % npc["name"]

	dialogue_sys.show_event_dialogue(
		"",
		peek_text,
		[{"text": "", "result": "open"}, {"text": "", "result": "ignore"}],
		_handle_knock_choice
	)


# ==================== QTE ====================
func _start_id_qte(npc):
	qte_sys.connect("qte_result", _on_id_qte_result.bind(npc), CONNECT_ONE_SHOT)
	qte_sys.start_qte(npc.get("qte_difficulty", "normal"))


func _on_id_qte_result(result, _accuracy, npc):
	if result == "perfect":
		if npc["type"] == "survivor":
			dialogue_sys.show_event_dialogue(
				"",
				"身份验证通过\n——对方看起来是诚实的幸存者\n",
				[{"text": "让他进来", "result": "accept"}],
				func(_c): _receive_survivor(npc)
			)
		else:
			dialogue_sys.show_event_dialogue(
				"",
				"——你识破了对方的伪装！\n\n这个人在说谎！",
				[{"text": "战斗！", "result": "fight"}],
				func(_c): _start_combat_qte(npc, npc["type"])
			)
	elif result == "good":
		if npc["type"] == "survivor":
			dialogue_sys.show_event_dialogue(
				"", "看起来没什么问题",
				[{"text": "让他进来", "result": "accept"}],
				func(_c): _receive_survivor(npc)
			)
		else:
			sanity = max(0, sanity - 15)
			dialogue_sys.show_event_dialogue(
				"",
				"对方似乎有点可疑...\n但你不太确定\n\n还是小心为妙...",
				[{"text": "还是算了...", "result": "ok"}],
				_on_id_good_fail.bind(npc)
			)
	else:
		dialogue_sys.show_event_dialogue(
			"",
			"你无法确定对方的身份...\n",
			[{"text": "冒险开门", "result": "accept"}, {"text": "安全起见拒绝", "result": "ignore"}],
			_on_id_fail_choice.bind(npc)
		)


# ==================== QTE ====================
func _start_combat_qte(npc, enemy_type):
	qte_sys.connect("qte_result", _on_combat_qte_result.bind(npc, enemy_type), CONNECT_ONE_SHOT)
	qte_sys.start_qte("hard")


func _on_combat_qte_result(result, _accuracy, _npc, enemy_type):
	if result == "perfect" or result == "good":
		kill_count += 1
		ui.update_kills(kill_count)
		var em = "完美击杀！" if result == "perfect" else "击杀成功！"
		ui.show_message(em, 1.5)
		var reward = "food" if randf() > 0.5 else "ammo"
		game_data_node.add_item(reward, 1)
		var name = game_data_node.ITEM_DATA[reward]["name"]
		ui.show_message("获得战利品: %s" % name, 2.0)
		_end_door_event()
	else:
		hp -= 30
		ui.show_message("-30 HP", 1.5)
		if hp <= 0:
			_on_game_over("%s...\n" % ("被伪装者杀害了" if enemy_type == "imposter" else "被丧尸杀死了"))
			return
		dialogue_sys.show_event_dialogue(
			"!!!", "攻击未能命中！再来一次！",
			[{"text": "再次攻击", "result": "retry"}],
			func(_c): _start_combat_qte(_npc, enemy_type)
		)


func _end_door_event():
	active_npc_data = null
	npc_at_door = null
	door_cooldown = door_cooldown_max


# ==================== NPC ====================
func on_talk_to_room_npc(npc_node):
	if dialogue_sys.is_showing:
		return

	npc_node.show_name(false)
	# NPC
	var npc_tex = null
	var sprite = npc_node.get_node_or_null("Sprite")
	if sprite and sprite.texture:
		npc_tex = sprite.texture

	npc_node.on_interact(func(npc_name, line, npc_type, is_betrayal):
		if is_betrayal:
			dialogue_sys.show_event_dialogue(
				npc_name, line,
				[{"text": "——该死！", "result": "fight"}],
				_on_room_npc_betrayal.bind(npc_node, npc_tex)
			)
		else:
			dialogue_sys.show_event_dialogue(
				npc_name, line,
				[{"text": "我明白了...", "result": "ok"}],
				func(_c): pass
				,
				npc_tex
			)
	)


func _start_combat_qte_for_room_npc(npc_node):
	qte_sys.connect("qte_result", func(result, _acc):
		if result == "perfect" or result == "good":
			kill_count += 1
			ui.update_kills(kill_count)
			ui.show_message("击败了叛变的同伴！", 2.0)
		else:
			hp -= 20
			ui.show_message("没能击败对方...-20 HP", 2.0)
			if hp <= 0:
				_on_game_over("被叛变的同伴杀死了...")
	, CONNECT_ONE_SHOT)
	qte_sys.start_qte("hard")


# ==================== NPC ====================
func _spawn_room_npc(npc_data):
	var npc_script = load("res://scripts/components/npc_room.gd")
	var npc = CharacterBody2D.new()
	npc.set_script(npc_script)
	npc.name = "RoomNPC_%s" % npc_data["name"]
	npc.position = Vector2(randf_range(250, 950), 545)

	var sprite = Sprite2D.new()
	sprite.name = "Sprite"

	# NPC
	var avatar_idx = npc_data.get("avatar_idx", 0)
	var tex_path = "res://assets/textures/npc_%d.png" % avatar_idx
	var tex = load(tex_path)
	if not tex:
		tex = load("res://assets/textures/npc_0.png")
	sprite.texture = tex
	sprite.scale = Vector2(0.4, 0.4)
	sprite.position = Vector2(0, -35)
	npc.add_child(sprite)

	# 
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(30, 60)
	col.shape = rect
	col.position = Vector2(0, -30)
	npc.add_child(col)

	# 
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.position = Vector2(-30, -60)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	name_label.add_theme_font_size_override("font_size", 15)
	npc.add_child(name_label)

	room_npcs_parent.add_child(npc)

	npc.npc_name = npc_data["name"]
	npc.npc_type = npc_data["type"]
	npc.set_room_bounds(200, 1100)

	# 
	npc.on_interact(func(npc_name_val, line, npc_type, is_betrayal):
		if is_betrayal:
			dialogue_sys.show_event_dialogue(
				npc_name_val, line,
				[{"text": "——该死！", "result": "fight"}],
				_on_room_npc_betrayal.bind(npc, sprite.texture)
			)
		else:
			dialogue_sys.show_event_dialogue(
				npc_name_val, line,
				[{"text": "我明白了...", "result": "ok"}],
				func(_c): pass,
				sprite.texture
			)
	)

	room_npcs.append(npc)


# ====================  ====================
func on_cabinet_interact(cabinet_sprite):
	var cab_key = cabinet_sprite.name
	if not cabinet_items.has(cab_key):
		return

	var cab_data = cabinet_items[cab_key]
	if cab_data["searched"]:
		ui.show_message("%s已经被搜过了" % cab_data["name"], 1.5)
		return

	cab_data["searched"] = true
	var label = cabinet_sprite.get_node_or_null("CabLabel")
	if label:
		label.text = cab_data["name"] + " (已搜索)"
		label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))

	var items = cab_data["items"].duplicate()
	items.shuffle()
	var found_items = []
	for i in range(min(2, items.size())):
		var item_id = items[i]
		game_data_node.add_item(item_id, 1)
		var item_data = game_data_node.ITEM_DATA.get(item_id, {})
		found_items.append(item_data.get("name", item_id))

	hunger = max(0, hunger - 3)

	var found_text = "翻找%s...\n" % cab_data["name"]
	for item_name in found_items:
		found_text += "-  %s\n" % item_name
	found_text += "\n"

		dialogue_sys.show_event_dialogue(
			"", found_text,
			[{"text": "收好", "result": "ok"}],
			func(_c): pass
		)
	ui.update_hunger(hunger, max_hunger)


# ====================  ====================
func on_door_interact():
	if active_npc_data != null:
		dialogue_sys.show_event_dialogue(
			"",
			"门外有人，你要怎么做？",
			[{"text": "开门", "result": "open"}, {"text": "假装不在", "result": "ignore"}],
			_handle_knock_choice
		)
	else:
		ui.show_message("外面暂时没有动静", 1.5)


# ====================  ====================
func start_exploration():
	if is_exploring:
		return

	_show_location_picker()


func _show_location_picker():
	var options = []
	for key in EXPLORE_LOCATIONS:
		var loc = EXPLORE_LOCATIONS[key]
		options.append({
			"text": "%s (~%.1fh)" % [loc["name"], loc["time_cost"]],
			"result": key
		})
	options.append({"text": "算了，不出去了", "result": "cancel"})

	dialogue_sys.show_event_dialogue(
		"选择探索地点",
		"当前时间: 第%d天 %02d:%02d" % [current_day, int(current_hour), int((current_hour - int(current_hour)) * 60)],
		options,
		_on_explore_location_chosen
	)


func _on_explore_location_chosen(key):
	if key == "cancel":
		return

	var loc = EXPLORE_LOCATIONS[key]
	var time_needed = loc["time_cost"]

	is_exploring = true
	explore_return_warning = false

	# 
	var desc_text = "你离开了安全屋...\n\n目的地: %s\n%s\n\n小心前进...\n" % [loc["name"], loc["desc"]]
	dialogue_sys.show_event_dialogue(
		"",
		desc_text,
		[{"text": "继续前进...", "result": "continue"}],
		func(_c): _process_exploration(key, loc)
	)


func _process_exploration(key, loc):
	var time_needed = loc["time_cost"]
	current_hour += time_needed
	hunger = max(0, hunger - 8)

	# 
	if randf() < loc["danger"]:
		dialogue_sys.show_event_dialogue(
			"!!!",
			"在%s遇到了丧尸！准备战斗...\n" % loc["name"],
			[{"text": "迎战！", "result": "fight"}],
			_on_explore_encounter.bind(loc)
		)
	else:
		_find_explore_items(loc)
		_show_horror_event(loc)
		_end_exploration()


func _process_exploration_retry(loc):
	qte_sys.connect("qte_result", _on_explore_retry_qte.bind(loc), CONNECT_ONE_SHOT)
	qte_sys.start_qte("hard")


func _find_explore_items(loc):
	var items = loc["items"].duplicate()
	items.shuffle()
	var found = []
	for i in range(min(randi() % 3 + 1, items.size())):
		var item_id = items[i]
		game_data_node.add_item(item_id, 1)
		var item_data = game_data_node.ITEM_DATA.get(item_id, {})
		found.append(item_data.get("name", item_id))

	if found.size() > 0:
		var text = "在%s找到了:\n" % loc["name"]
		for f in found:
			text += "- %s\n" % f
		ui.show_message(text, 3.0)


func _show_horror_event(loc):
	if loc.has("horror_event"):
		dialogue_sys.show_event_dialogue(
			"探索中...",
			loc["horror_event"],
			[{"text": "赶紧离开...", "result": "leave"}],
			func(_c): pass
		)


func _end_exploration():
	is_exploring = false
	explore_return_warning = false

	ui.update_hp(hp, max_hp)
	ui.update_hunger(hunger, max_hunger)
	ui.update_sanity(sanity)
	ui.update_time_label(current_day, current_hour)


# ====================  ====================
func _on_game_over(reason):
	game_over = true
	var final_text = "第%d天 %02d:%02d\n%s\n\n存活了 %d 天\n击杀了 %d 只丧尸" % [
		current_day, int(current_hour), int((current_hour - int(current_hour)) * 60),
		reason, current_day, kill_count
	]
	ui.show_game_over(current_day, current_hour, final_text, kill_count)


func _input(event):
	if game_over and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			get_tree().reload_current_scene()


# ====================  () ====================
func use_inventory_item(item_idx):
	var gd = game_data_node
	if item_idx >= gd.inventory.size():
		return ""

	var item = gd.inventory[item_idx]
	var item_id = item["id"]
	var data = gd.ITEM_DATA.get(item_id, {})

	if data.get("type") != "consumable":
		return "%s" % data.get("name", item_id)

	gd.remove_item(item_id)

	var effect = data.get("effect", "")
	if effect.begins_with("hp+"):
		hp = min(max_hp, hp + int(effect.substr(3)))
	elif effect.begins_with("hunger+"):
		hunger = min(max_hunger, hunger + float(effect.substr(7)))
	elif effect.begins_with("sanity+"):
		sanity = min(100.0, sanity + float(effect.substr(7)))

	ui.update_hp(hp, max_hp)
	ui.update_hunger(hunger, max_hunger)
	ui.update_sanity(sanity)
	ui.refresh_inventory(gd.inventory)

	return "%s" % data.get("name", item_id)



# ==================== Lambda  lambda  ====================
func _on_intro_end(_c):
	await get_tree().create_timer(1.5).timeout
	ui.show_message("新的一天开始了...努力活下去吧...", 3.0)


func _on_ignore_door_end(_c):
	_end_door_event()
	sanity = max(0, sanity - 3)
	if randf() < 0.2:
		ui.show_message("门外似乎传来了低沉的嘶吼声...", 2.0)


func _on_id_good_fail(_c, npc):
	hp -= 20
	ui.show_message("-20 HP", 2.0)
	_end_door_event()


func _on_id_fail_choice(choice, npc):
	if choice == "accept":
		if npc["type"] != "survivor":
			sanity = max(0, sanity - 15)
			hp -= 25
			ui.show_message("-25 HP", 2.0)
		else:
			_receive_survivor(npc)
			return
	_end_door_event()


func _on_room_npc_betrayal(_c, npc_node, npc_tex):
	hp -= 25
	ui.show_message("-25 HP", 2.0)
	if hp <= 0:
		_on_game_over("被叛变的同伴杀死了\n")
		return
	npc_node.queue_free()
	room_npcs.erase(npc_node)
	_start_combat_qte_for_room_npc(npc_node)


func _on_explore_encounter(_c, loc):
	qte_sys.connect("qte_result", _on_explore_qte_result.bind(loc), CONNECT_ONE_SHOT)
	qte_sys.start_qte("hard")


func _on_explore_qte_result(result, _acc, loc):
	if result == "perfect" or result == "good":
		kill_count += 1
		ui.update_kills(kill_count)
		ui.show_message("击败了丧尸！", 1.5)
		_find_explore_items(loc)
		_show_horror_event(loc)
		_end_exploration()
	else:
		hp -= 25
		ui.show_message("-25 HP", 1.5)
		if hp <= 0:
			_on_game_over("在%s被丧尸杀死...\n" % loc["name"])
			return
		dialogue_sys.show_event_dialogue(
			"!!!", "没能击败丧尸，再来一次！",
			[{"text": "再次攻击", "result": "retry"}],
			func(_c2): _process_exploration_retry(loc)
		)


func _on_explore_retry_qte(result, _acc, loc):
	if result == "perfect" or result == "good":
		kill_count += 1
		ui.update_kills(kill_count)
		ui.show_message("勉强击败了丧尸！", 1.5)
		_find_explore_items(loc)
		_show_horror_event(loc)
		_end_exploration()
	else:
		hp -= 20
		ui.show_message("-20 HP", 1.5)
		if hp <= 0:
			_on_game_over("在%s被丧尸杀死..." % loc["name"])
			return
		kill_count += 1
		ui.update_kills(kill_count)
		ui.show_message("拼死击杀！", 1.5)
		_find_explore_items(loc)
		_show_horror_event(loc)
		_end_exploration()


# ==================== NPC ====================
func _load_npc_avatar(avatar_idx):
	var tex = null
	if avatar_idx < 0:
		tex = load("res://assets/textures/zombie_front.png")
		if not tex:
			tex = load("res://assets/textures/zombie_type0.png")
	elif avatar_idx <= 8:
		tex = load("res://assets/textures/npc_%d.png" % avatar_idx)

	return tex
