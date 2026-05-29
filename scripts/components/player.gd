extends CharacterBody2D

# ========== 玩家角色 + 移动交互 ==========
@export var move_speed: float = 280.0
@export var interact_range: float = 80.0

@onready var body_rect: ColorRect = $BodyRect
@onready var body_sprite: Sprite2D = $BodySprite
@onready var name_label: Label = $NameLabel

var is_alive: bool = true
var facing_right: bool = true
var interact_cooldown: float = 0.0

# 
var room_left: float = 120.0
var room_right: float = 1420.0
var ground_y: float = 750.0


func _ready() -> void:
	add_to_group("player")
	z_index = 1  # 
	
	# 移动端触控连接
	_connect_mobile_controls()
	
	# 
	if not body_sprite:
		body_sprite = Sprite2D.new()
		body_sprite.name = "BodySprite"
		var tex_path := "res://assets/textures/player_portrait.png"
		if ResourceLoader.exists(tex_path):
			body_sprite.texture = load(tex_path)
			body_sprite.scale = Vector2(0.65, 0.65)
			body_sprite.position = Vector2(0, -90)
		else:
			#  player_front.png
			body_sprite.texture = load("res://assets/textures/player_front.png")
			body_sprite.scale = Vector2(0.5, 0.5)
			body_sprite.position = Vector2(0, -80)
		add_child(body_sprite)

	if not body_rect:
		# 
		body_rect = ColorRect.new()
		body_rect.name = "BodyRect"
		body_rect.size = Vector2(100, 150)
		body_rect.position = Vector2(-50, -150)
		body_rect.color = Color(0.3, 0.7, 0.4)
		add_child(body_rect)
	else:
		# ColorRectsprite
		body_rect.visible = false
	if not name_label:
		name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = "玩家"
		name_label.position = Vector2(-35, -182)
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		add_child(name_label)


func _physics_process(delta: float) -> void:
	if not is_alive or GameManager.game_over or GameManager.is_horde_qte_active or _is_any_panel_open():
		return

	interact_cooldown -= delta

	var input_dir := Input.get_axis("move_left", "move_right")

	# 移动端摇杆输入（优先级低于键盘，叠加使用）
	var mobile_controls := _get_mobile_controls()
	if mobile_controls:
		var mobile_dir: float = mobile_controls.get_move_axis()
		if abs(mobile_dir) > abs(input_dir):
			input_dir = mobile_dir

	if input_dir != 0:
		var sprint: float = 2.0 if (Input.is_key_pressed(KEY_SHIFT) or (mobile_controls and mobile_controls.is_sprinting)) else 1.0
		velocity.x = input_dir * move_speed * sprint
		if input_dir > 0:
			facing_right = true
		else:
			facing_right = false
	else:
		velocity.x = 0
	
	# 
	if body_sprite:
		body_sprite.flip_h = not facing_right

	velocity.y = 0
	move_and_slide()

	# 
	global_position.x = clamp(global_position.x, room_left, room_right)
	global_position.y = ground_y

	# 
	if Input.is_action_just_pressed("interact") and interact_cooldown <= 0:
		interact_cooldown = 0.3
		_try_interact()


func _try_interact() -> void:
	# /npc_house_scene
	if GameManager.is_in_guest_house:
		return

	var main := get_parent()  # Player -> Main
	if not main:
		return

	# 1. 
	var door := main.get_node_or_null("DoorArea")
	if door and global_position.distance_to(door.global_position) < interact_range:
		if main.has_method("on_door_interact"):
			main.on_door_interact()
			return

	# 2. NPC —— 
	# NPCArea2D input_event

	# 3. 
	var cabinets_parent := main.get_node_or_null("Cabinets")
	if cabinets_parent:
		for cab in cabinets_parent.get_children():
			if not is_instance_valid(cab):
				continue
			if cab.is_in_group("cabinet"):
				if global_position.distance_to(cab.global_position) < interact_range:
					if main.has_method("on_cabinet_interact"):
						main.on_cabinet_interact(cab)
						return

	# 4. //
	var furniture_parent := main.get_node_or_null("Furniture")
	if furniture_parent:
		for obj in furniture_parent.get_children():
			if not is_instance_valid(obj):
				continue
			if global_position.distance_to(obj.global_position) < interact_range:
				if obj.is_in_group("storage_obj") and main.has_method("on_storage_interact"):
					main.on_storage_interact()
					return
				elif obj.is_in_group("craft_obj") and main.has_method("on_craft_interact"):
					main.on_craft_interact()
					return
				elif obj.is_in_group("trash_obj") and main.has_method("on_trash_interact"):
					main.on_trash_interact()
					return

	# 5. 
	var bed := main.get_node_or_null("BedArea")
	if bed and global_position.distance_to(bed.global_position) < interact_range:
		if main.has_method("on_bed_interact"):
			main.on_bed_interact()
			return

	# 6. 附近没有可互动对象
	GameManager.message_shown.emit("附近没有可以互动的东西...", 1.5)


func _is_any_panel_open() -> bool:
	"""UI/"""
	var main := get_parent()
	if not main:
		return false
	if main.get("is_dialog_open"):
		return true
	var ui_layer := main.get_node_or_null("UILayer")
	if ui_layer and ui_layer.has_method("has_any_popup_open"):
		return ui_layer.has_any_popup_open()
	return false


# ========== 移动端触控适配 ==========
var _mobile_ref: Node = null

func _connect_mobile_controls() -> void:
	# 延迟一帧等MobileControls创建
	await get_tree().process_frame
	var main_node := get_parent()
	if not main_node:
		return
	_mobile_ref = main_node.get_node_or_null("MobileControls")
	if _mobile_ref:
		_mobile_ref.interact_pressed.connect(func():
			if interact_cooldown <= 0 and is_alive and not GameManager.game_over:
				interact_cooldown = 0.3
				_try_interact()
		)
		_mobile_ref.inventory_pressed.connect(func():
			Input.action_press("inventory")
			await get_tree().create_timer(0.05).timeout
			Input.action_release("inventory")
		)


func _get_mobile_controls() -> Node:
	if not _mobile_ref:
		var main_node := get_parent()
		if main_node:
			_mobile_ref = main_node.get_node_or_null("MobileControls")
	return _mobile_ref
