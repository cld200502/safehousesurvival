extends CharacterBody2D

# ========== NPC/房间中的角色 + 对话 ==========
@export var npc_name = "???"
@export var npc_type = "survivor"  # survivor / imposter
@export var walk_speed = 40.0
@export var walk_chance = 0.3

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel

var walk_target = Vector2.ZERO
var walk_timer = 0.0
var idle_timer = 0.0
var facing_right = true
var room_left = 200.0
var room_right = 1100.0
var is_talking = false

# 对话数据
var dialogue_lines = []
var imposter_lines = []
var has_been_talked_to = false

# 点击回调
var _click_callback: Callable


func _ready():
	add_to_group("room_npc")
	name_label.text = npc_name
	name_label.visible = false
	_init_dialogue()
	_randomize_state()
	_add_click_area()


func _add_click_area():
	"""创建点击检测区域"""
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.collision_layer = 0
	area.collision_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 160)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)

	# 鼠标样式切换
	area.mouse_entered.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	)
	area.mouse_exited.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	)

	# 点击事件
	area.input_event.connect(func(_viewport: Viewport, event: InputEvent, _shape_idx: int):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_clicked()
	)


func _init_dialogue():
	if npc_type == "survivor":
		dialogue_lines = [
			"谢谢你收留我...",
			"我会尽力帮忙的。",
			"希望我们能一起活下去...",
			"今天天气不错...至少没有丧尸。",
			"你觉得救援什么时候会来...",
			"我有点饿了，还有吃的吗？",
			"这间房子真的很安全...",
			"谢谢你让我留在这里...",
		]
	else:  # imposter
		dialogue_lines = [
			"这里真不错啊...",
			"我只是路过而已...",
			"你们这里的物资储备很充足啊...",
		]
		imposter_lines = [
			"其实...我知道哪里有更多的物资。",
			"你相信我吗？",
			"有时候，为了生存，不得不做一些事...",
			"如果有一天我不见了，不要找我...",
		]


func _randomize_state():
	walk_timer = randf_range(2.0, 5.0)
	idle_timer = randf_range(1.0, 3.0)
	if randf() < walk_chance:
		_pick_new_walk_target()


func _pick_new_walk_target():
	walk_target.x = randf_range(room_left, room_right)
	walk_target.y = global_position.y
	if walk_target.x > global_position.x:
		facing_right = true
	else:
		facing_right = false
	_update_sprite_direction()


func _update_sprite_direction():
	if facing_right:
		sprite.scale.x = abs(sprite.scale.x)
	else:
		sprite.scale.x = -abs(sprite.scale.x)


func _physics_process(delta):
	if is_talking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	walk_timer -= delta

	if walk_timer <= 0:
		idle_timer -= delta
		if idle_timer <= 0:
			if randf() < walk_chance:
				_pick_new_walk_target()
				walk_timer = randf_range(3.0, 8.0)
			else:
				walk_target = Vector2.ZERO
				walk_timer = randf_range(2.0, 4.0)
			idle_timer = randf_range(1.0, 3.0)

	# 移动逻辑
	if walk_target != Vector2.ZERO:
		var dir = (walk_target - global_position).normalized()
		if abs(global_position.x - walk_target.x) < 10:
			walk_target = Vector2.ZERO
			velocity = Vector2.ZERO
		else:
			velocity.x = dir.x * walk_speed
			if dir.x > 0:
				facing_right = true
			else:
				facing_right = false
			_update_sprite_direction()
	else:
		velocity.x = 0

	velocity.y = 0
	move_and_slide()


func on_interact(callback_func: Callable) -> void:
	"""设置点击回调"""
	_click_callback = callback_func
	show_name(true)  # 显示名字


func _on_clicked() -> void:
	"""NPC被点击——显示对话"""
	if is_talking:
		return
	if not _click_callback or not _click_callback.is_valid():
		return
	is_talking = true
	show_name(false)

	var line: String
	if npc_type == "imposter" and has_been_talked_to and randf() < 0.4:
		line = imposter_lines[randi() % imposter_lines.size()]
	else:
		line = dialogue_lines[randi() % dialogue_lines.size()]

	has_been_talked_to = true

	# imposter可能背叛
	var is_betrayal = false
	if npc_type == "imposter" and has_been_talked_to and randf() < 0.15:
		is_betrayal = true
		line = "......(露出了诡异的微笑)\n\n你突然感到一阵寒意..."

	_click_callback.call(npc_name, line, npc_type, is_betrayal)

	is_talking = false


func show_name(show_it = true):
	name_label.visible = show_it


func set_room_bounds(left, right):
	room_left = left
	room_right = right
