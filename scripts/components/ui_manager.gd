extends CanvasLayer
## UI——HUD

# ==========  ==========
var top_bar: Panel
var hp_bar: ColorRect
var hp_label: Label
var hunger_bar: ColorRect
var hunger_label: Label
var sanity_bar: ColorRect
var sanity_label: Label
var day_label: Label
var time_label: Label



# ==========  ==========
var popup_msg_panel: Panel
var popup_msg_label: RichTextLabel
var popup_msg_visible: bool = false

# ==========  ==========
var hotbar_panel: Panel
var equip_left_label: Label
var equip_right_label: Label
var hotbar_slots: Array = []  # 8
var hotbar_tooltip: Label

# ==========  ==========
var speed_btn: Button
var is_speed_5x: bool = false

# ========== ==========
var _button_layer: CanvasLayer

# ========== Shift ==========
var sprint_hint: Label

# ==========  ==========
var item_action_panel: Panel

# ========== NPC ==========
var _dialogue_ap_spent: int = 0

# ========== ==========
var dream_panel: Panel
var _dream_round: int = 0
var _dream_data: Dictionary = {}

# ========== () ==========
var inventory_panel: Panel
var inventory_list: VBoxContainer
var inventory_scroll: ScrollContainer

# ==========  ==========
var explore_panel: Panel

# ==========  ==========
var game_over_panel: Panel

# ==========  ==========
var popup_open: bool = false
var _sanity_low_warned: bool = false
var _hunger_low_warned: bool = false
var _hp_low_warned: bool = false

# ==========  ==========
var _on_send_pressed_sister: Callable
var _on_back_pressed_sister: Callable
var _on_text_submitted_sister: Callable

# ========== / ==========
var midnight_panel: Panel
var horde_panel: Panel

# ========== NPC ==========
var npc_interact_panel: Panel
# ==========  ==========
var cat_panel: Panel
# ==========  ==========
var sister_panel: Panel
# ========== NPC QTE  ==========
var _npc_qte_mode: String = ""  # "" / "check" / "extort"
var _npc_qte_npc_name: String = ""
var _npc_qte_pointer_pos: float = 0.0
var _npc_qte_direction: int = 1
var _npc_qte_speed: float = 300.0
var _npc_qte_result_emitted: bool = false
var _npc_qte_difficulty: String = "normal"
signal npc_spawned(npc_data: Dictionary)  # mainNPC

# ==========  ==========
var craft_panel: Panel

# ==========  ==========
var storage_panel: Panel

# ==========  ==========
var trash_panel: Panel

# ==========  ==========
var cabinet_panel: Panel

# ========== / ==========
var menu_panel: Panel
var menu_btn: Button
var save_mode: String = ""


func has_any_popup_open() -> bool:
	"""player"""
	return (
		(dream_panel and dream_panel.visible) or
		(inventory_panel and inventory_panel.visible) or
		(item_action_panel and item_action_panel.visible) or
		(explore_panel and explore_panel.visible) or
		(midnight_panel and midnight_panel.visible) or
		(horde_panel and horde_panel.visible) or
		(menu_panel and menu_panel.visible) or
		(game_over_panel and game_over_panel.visible) or
		(craft_panel and craft_panel.visible) or
		(storage_panel and storage_panel.visible) or
		(trash_panel and trash_panel.visible) or
		(cabinet_panel and cabinet_panel.visible) or
		(npc_interact_panel and npc_interact_panel.visible) or
		(sister_panel and sister_panel.visible)
	)


func _update_mouse_mode() -> void:
	var any_open: bool = (
		(popup_msg_visible) or
		(inventory_panel and inventory_panel.visible) or
		(item_action_panel and item_action_panel.visible) or
		(explore_panel and explore_panel.visible) or
		(midnight_panel and midnight_panel.visible) or
		(horde_panel and horde_panel.visible) or
		(menu_panel and menu_panel.visible) or
		(game_over_panel and game_over_panel.visible) or
		(craft_panel and craft_panel.visible) or
		(storage_panel and storage_panel.visible) or
		(trash_panel and trash_panel.visible) or
		(cabinet_panel and cabinet_panel.visible) or
		(npc_interact_panel and npc_interact_panel.visible)
	)
	if any_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)  # 


func _ready() -> void:
	#  CanvasLayer 
	_button_layer = CanvasLayer.new()
	_button_layer.name = "ButtonLayer"
	_button_layer.layer = 999
	add_child(_button_layer)

	_build_top_bar()
	_build_speed_btn()
	_build_popup_message()
	_build_hotbar()
	_build_sprint_hint()
	_build_inventory_panel()
	_build_item_action_panel()
	_build_cabinet_panel()
	_build_explore_panel()
	_build_game_over_panel()
	_build_midnight_panel()
	_build_horde_panel()
	_build_craft_panel()
	_build_storage_panel()
	_build_trash_panel()
	_build_npc_interact_panel()
	_build_dream_panel()
	_build_cat_panel()
	_build_sister_panel()
	_build_menu_button()
	_build_menu_panel()
	_connect_signals()
	hide_hud()


func _connect_signals() -> void:
	GameManager.hp_changed.connect(_update_hp)
	GameManager.hunger_changed.connect(_update_hunger)
	GameManager.sanity_changed.connect(_update_sanity)
	GameManager.time_changed.connect(_update_time)
	GameManager.inventory_updated.connect(_update_hotbar)
	GameManager.inventory_updated.connect(_update_inventory)
	GameManager.equipment_changed.connect(_update_hotbar)
	GameManager.storage_updated.connect(_update_storage_panel)
	GameManager.trash_updated.connect(_update_trash_panel)
	GameManager.message_shown.connect(_show_message)
	GameManager.popup_message.connect(_show_popup)
	GameManager.game_over_triggered.connect(_on_game_over)
	GameManager.dream_triggered.connect(_show_dream)
	GameManager.door_state_changed.connect(_update_door_display)


# ====================  ====================
func _build_popup_message() -> void:
	popup_msg_panel = Panel.new()
	popup_msg_panel.position = Vector2(240, 160)
	popup_msg_panel.size = Vector2(800, 400)
	popup_msg_panel.self_modulate = Color(0.02, 0.02, 0.04, 0.96)
	popup_msg_panel.visible = false
	popup_msg_panel.z_index = 50
	popup_msg_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # 
	add_child(popup_msg_panel)

	var hint := Label.new()
	hint.text = "[消息]"
	hint.position = Vector2(0, 3)
	hint.size = Vector2(800, 25)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	popup_msg_panel.add_child(hint)

	popup_msg_label = RichTextLabel.new()
	popup_msg_label.position = Vector2(30, 30)
	popup_msg_label.size = Vector2(740, 300)
	popup_msg_label.bbcode_enabled = true
	popup_msg_label.fit_content = true
	popup_msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_msg_label.add_theme_font_size_override("normal_font_size", 25)
	popup_msg_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	popup_msg_panel.add_child(popup_msg_label)


func _show_popup(text: String) -> void:
	if popup_msg_visible:
		# 
		popup_msg_label.text += "\n\n" + text
		return
	popup_msg_visible = true
	popup_msg_panel.visible = true
	popup_msg_label.text = text
	_update_mouse_mode()


func _dismiss_popup() -> void:
	popup_msg_visible = false
	popup_msg_panel.visible = false
	_update_mouse_mode()


func _show_message(text: String, _duration: float) -> void:
	""""""
	_show_popup(text)


# ====================  ====================
func _build_top_bar() -> void:
	top_bar = Panel.new()
	top_bar.position = Vector2(115, 6)   # (10,8)+90 
	top_bar.size = Vector2(1000, 64)     # 
	top_bar.self_modulate = Color(0, 0, 0, 0.75)
	add_child(top_bar)

	var container := HBoxContainer.new()
	container.position = Vector2(8, 6)
	container.size = Vector2(984, 52)
	container.add_theme_constant_override("separation", 12)
	top_bar.add_child(container)

	# HP
	var hp_section := VBoxContainer.new()
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 20)
	hp_label.add_theme_color_override("font_color", Color.RED)
	hp_label.text = "生命: 100/100"
	hp_section.add_child(hp_label)
	hp_bar = ColorRect.new()
	hp_bar.color = Color.RED
	hp_bar.size = Vector2(120, 14)
	hp_section.add_child(hp_bar)
	container.add_child(hp_section)

	# 
	var hunger_section := VBoxContainer.new()
	hunger_label = Label.new()
	hunger_label.add_theme_font_size_override("font_size", 20)
	hunger_label.add_theme_color_override("font_color", Color.ORANGE)
	hunger_label.text = "饱食: 100%"
	hunger_section.add_child(hunger_label)
	hunger_bar = ColorRect.new()
	hunger_bar.color = Color.ORANGE
	hunger_bar.size = Vector2(120, 14)
	hunger_section.add_child(hunger_bar)
	container.add_child(hunger_section)

	# 
	var sanity_section := VBoxContainer.new()
	sanity_label = Label.new()
	sanity_label.add_theme_font_size_override("font_size", 20)
	sanity_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
	sanity_label.text = "精神: 100%"
	sanity_section.add_child(sanity_label)
	sanity_bar = ColorRect.new()
	sanity_bar.color = Color(0.4, 0.6, 1.0)
	sanity_bar.size = Vector2(120, 14)
	sanity_section.add_child(sanity_bar)
	container.add_child(sanity_section)

	# 
	day_label = Label.new()
	day_label.add_theme_font_size_override("font_size", 22)
	day_label.add_theme_color_override("font_color", Color.WHITE)
	day_label.text = "第 1 天"
	container.add_child(day_label)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 25)
	time_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	time_label.text = "08:00"
	container.add_child(time_label)




# ====================  ====================
func _build_speed_btn() -> void:
	speed_btn = Button.new()
	speed_btn.text = "1倍速"
	speed_btn.position = Vector2(1180, 6)
	speed_btn.size = Vector2(90, 32)
	speed_btn.add_theme_font_size_override("font_size", 18)
	speed_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	speed_btn.pressed.connect(_toggle_speed)
	speed_btn.z_index = 1000  # 
	speed_btn.focus_mode = Control.FOCUS_NONE  # 
	_button_layer.add_child(speed_btn)


func _build_sprint_hint() -> void:
	sprint_hint = Label.new()
	sprint_hint.text = "按住Shift：加速×2"
	sprint_hint.position = Vector2(1045, 702)
	sprint_hint.size = Vector2(210, 28)
	sprint_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sprint_hint.add_theme_font_size_override("font_size", 15)
	sprint_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.5))
	add_child(sprint_hint)


func _toggle_speed() -> void:
	is_speed_5x = not is_speed_5x
	if is_speed_5x:
		speed_btn.text = "4倍速"
		speed_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	else:
		speed_btn.text = "1倍速"
		speed_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))


func _update_hp(current: float, max_val: float) -> void:
	var pct: float = clampf(current / max_val, 0.0, 1.0)
	hp_bar.size.x = 120.0 * pct
	hp_label.text = "生命: %d/%d" % [int(current), int(max_val)]
	var hp_pct := pct * 100.0
	if hp_pct <= 20.0 and hp_pct > 0 and not _hp_low_warned:
		_hp_low_warned = true
		_show_popup("[color=red][b]生命值过低 (%d%%)...[/b][/color]" % int(hp_pct))
	elif hp_pct > 30.0:
		_hp_low_warned = false  # 


func _update_hunger(current: float, max_val: float) -> void:
	var pct: float = clampf(current / max_val, 0.0, 1.0)
	hunger_bar.size.x = 120.0 * pct
	hunger_label.text = "饱食: %d%%" % int(current)
	var hunger_pct := pct * 100.0
	if hunger_pct <= 20.0 and hunger_pct > 0 and not _hunger_low_warned:
		_hunger_low_warned = true
		_show_popup("[color=orange][b]饥饿度不足 (%d%%)...[/b][/color]" % int(hunger_pct))
	elif hunger_pct > 30.0:
		_hunger_low_warned = false  # 


func _update_sanity(current: float) -> void:
	var pct: float = clampf(current / 100.0, 0.0, 1.0)
	sanity_bar.size.x = 120.0 * pct
	sanity_label.text = "理智: %d%%" % int(current)
	if current < 30:
		sanity_bar.color = Color(0.8, 0.2, 0.2)
	if current < 50 and not _sanity_low_warned:
		_sanity_low_warned = true
		_show_popup("[color=yellow]理智值低于 50%...[/color]")
	elif current >= 60:
		_sanity_low_warned = false  # 


func _update_time(day: int, hour: float) -> void:
	var h: int = int(hour) % 24
	var m: int = int((hour - floor(hour)) * 60)
	var acts: int = GameManager.get_actions_left()
	day_label.text = "第 %d 天" % day
	time_label.text = "%02d:%02d 行动:%d" % [h, m, acts]






# ====================  ====================
func _build_hotbar() -> void:
	hotbar_panel = Panel.new()
	hotbar_panel.position = Vector2(20, 600)
	hotbar_panel.size = Vector2(1240, 110)       # 
	hotbar_panel.self_modulate = Color(0.05, 0.04, 0.06, 0.92)
	add_child(hotbar_panel)

	hotbar_tooltip = Label.new()
	hotbar_tooltip.visible = false
	hotbar_tooltip.size = Vector2(180, 28)
	hotbar_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotbar_tooltip.add_theme_font_size_override("font_size", 18)
	hotbar_tooltip.add_theme_color_override("font_color", Color.WHITE)
	hotbar_panel.add_child(hotbar_tooltip)

	# === [ ] [8] ...... [ ] [ ] ===
	var root_hbox := HBoxContainer.new()
	root_hbox.position = Vector2(8, 22)
	root_hbox.add_theme_constant_override("separation", 16)
	hotbar_panel.add_child(root_hbox)

	# =====  =====
	# ""
	var backpack_label := Label.new()
	backpack_label.text = "背包\n"
	backpack_label.custom_minimum_size = Vector2(24, 70)
	backpack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	backpack_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	backpack_label.add_theme_font_size_override("font_size", 22)
	backpack_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	root_hbox.add_child(backpack_label)

	# 8
	var inv_slots_box := HBoxContainer.new()
	inv_slots_box.name = "slots_container"
	inv_slots_box.add_theme_constant_override("separation", 4)
	root_hbox.add_child(inv_slots_box)
	for i in range(GameManager.MAX_INVENTORY):
		var slot := _create_inventory_slot_box(i)
		inv_slots_box.add_child(slot)
		hotbar_slots.append(slot)

	# 
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(80, 1)   # 4080
	root_hbox.add_child(spacer1)

	# =====  =====
	# ""
	var equip_label := Label.new()
	equip_label.text = "装备\n"
	equip_label.custom_minimum_size = Vector2(24, 70)
	equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equip_label.add_theme_font_size_override("font_size", 22)
	equip_label.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	root_hbox.add_child(equip_label)

	#  + 
	var equip_box := HBoxContainer.new()
	equip_box.name = "equip_container"
	equip_box.add_theme_constant_override("separation", 20)
	root_hbox.add_child(equip_box)

	var left_slot := _create_equip_slot_box("left")
	equip_box.add_child(left_slot)
	var right_slot := _create_equip_slot_box("right")
	equip_box.add_child(right_slot)

	# I +  + 
	var hint_label := Label.new()
	hint_label.name = "hotbar_hint"
	hint_label.text = "按I键打开背包\n背包上限: 8\n丢弃物品(除安全屋外)不可找回"
	hint_label.custom_minimum_size = Vector2(220, 80)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.4, 0.38, 0.35))
	root_hbox.add_child(hint_label)


func _create_equip_slot_box(side: String) -> Panel:
	""""""
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(60, 60)
	slot.name = "equip_slot_%s" % side
	slot.self_modulate = Color(0.12, 0.11, 0.14, 0.95)
	var border: StyleBoxFlat = StyleBoxFlat.new()
	border.bg_color = Color(0.1, 0.09, 0.13, 0.95)
	border.border_color = Color(0.35, 0.32, 0.38, 0.8)
	border.set_border_width_all(1)
	border.set_corner_radius_all(3)
	slot.add_theme_stylebox_override("panel", border)

	# 
	var icon_rect: ColorRect = ColorRect.new()
	icon_rect.name = "icon_rect"
	icon_rect.position = Vector2(4, 4)
	icon_rect.size = Vector2(52, 28)
	icon_rect.color = Color(0.15, 0.15, 0.18, 0.8)
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_rect)

	# 
	var weapon_icon: ColorRect = ColorRect.new()
	weapon_icon.name = "weapon_icon"
	weapon_icon.position = Vector2(20, 34)
	weapon_icon.size = Vector2(20, 14)
	weapon_icon.color = Color(0.3, 0.3, 0.35, 0.7)
	weapon_icon.visible = false
	weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(weapon_icon)

	# tooltip — 14
	slot.mouse_entered.connect(func():
		var wid: String = GameManager.equip_left if side == "left" else GameManager.equip_right
		var txt: String = ""
		if wid == "":
			txt = ""
		else:
			var d: Dictionary = GameManager.ITEM_DATA.get(wid, {})
			txt = "%s (:%d)" % [d.get("name", wid), d.get("damage", 0)]
		_show_slot_tooltip(slot, txt)
	)
	slot.mouse_exited.connect(func(): hotbar_tooltip.visible = false)

	#  → 
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			GameManager.unequip_weapon(side)
	)

	return slot


func _create_inventory_slot_box(idx: int) -> Panel:
	""""""
	var slot: Panel = Panel.new()
	slot.custom_minimum_size = Vector2(60, 60)
	slot.name = "inv_slot_%d" % idx
	slot.self_modulate = Color(0.06, 0.06, 0.08, 0.95)
	var border: StyleBoxFlat = StyleBoxFlat.new()
	border.bg_color = Color(0.05, 0.05, 0.07, 0.9)
	border.border_color = Color(0.25, 0.23, 0.27, 0.6)
	border.set_border_width_all(1)
	border.set_corner_radius_all(2)
	slot.add_theme_stylebox_override("panel", border)

	# 
	var icon_rect: ColorRect = ColorRect.new()
	icon_rect.name = "icon_rect"
	icon_rect.position = Vector2(4, 4)
	icon_rect.size = Vector2(52, 28)
	icon_rect.color = Color(0.12, 0.12, 0.14, 0.7)
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon_rect)

	# 
	var item_icon: ColorRect = ColorRect.new()
	item_icon.name = "item_icon"
	item_icon.position = Vector2(20, 34)
	item_icon.size = Vector2(20, 14)
	item_icon.color = Color(0.3, 0.3, 0.35, 0.5)
	item_icon.visible = false
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(item_icon)

	# tooltip — 14
	slot.mouse_entered.connect(func():
		var txt: String = ""
		if idx < GameManager.inventory.size():
			var item: Dictionary = GameManager.inventory[idx]
			var d: Dictionary = GameManager.ITEM_DATA.get(item["id"], {})
			txt = "%s ×%d" % [d.get("name", item["id"]), item["amount"]]
			# P3: tooltip
			if GameManager.FOOD_CATEGORIES.has(item["id"]):
				var label: String = GameManager.get_food_label(item["id"], idx)
				if label != "":
					txt += " " + label
		else:
			txt = ""
		_show_slot_tooltip(slot, txt)
	)
	slot.mouse_exited.connect(func(): hotbar_tooltip.visible = false)

	# 
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_slot_clicked(idx)
	)

	return slot


func _update_hotbar() -> void:
	#  root_hbox > equip_container 
	var root_hbox: HBoxContainer = null
	for c in hotbar_panel.get_children():
		if c is HBoxContainer:
			root_hbox = c
			break
	if not root_hbox:
		return

	var equip_container: HBoxContainer = null
	for c in root_hbox.get_children():
		if c is HBoxContainer and c.name == "equip_container":
			equip_container = c
			break

	if equip_container and equip_container.get_child_count() >= 1:
		_update_equip_panel(equip_container.get_child(0), "left")
	if equip_container and equip_container.get_child_count() >= 2:
		_update_equip_panel(equip_container.get_child(1), "right")

	# 8hotbar_slots  Panel
	for i in range(hotbar_slots.size()):
		_update_inv_panel(hotbar_slots[i], i)


func _update_equip_panel(slot: Panel, side: String) -> void:
	var icon_rect: ColorRect = slot.get_node_or_null("icon_rect") as ColorRect
	var weapon_icon: ColorRect = slot.get_node_or_null("weapon_icon") as ColorRect
	var wid: String = GameManager.equip_left if side == "left" else GameManager.equip_right

	if wid == "":
		if icon_rect: icon_rect.visible = false
		if weapon_icon: weapon_icon.visible = false
	else:
		var d: Dictionary = GameManager.ITEM_DATA.get(wid, {})
		if icon_rect:
			icon_rect.visible = true
			icon_rect.color = Color(0.5, 0.25, 0.12, 0.85)
		if weapon_icon:
			weapon_icon.visible = true
			weapon_icon.color = Color(0.7, 0.35, 0.15, 0.9)


func _update_inv_panel(slot: Panel, idx: int) -> void:
	var icon_rect: ColorRect = slot.get_node_or_null("icon_rect") as ColorRect
	var item_icon: ColorRect = slot.get_node_or_null("item_icon") as ColorRect

	if idx < GameManager.inventory.size():
		var item: Dictionary = GameManager.inventory[idx]
		var d: Dictionary = GameManager.ITEM_DATA.get(item["id"], {})
		if icon_rect:
			icon_rect.visible = true
			var itype: String = d.get("type", "")
			match itype:
				"weapon": icon_rect.color = Color(0.6, 0.3, 0.1, 0.85)
				"consumable": icon_rect.color = Color(0.1, 0.5, 0.15, 0.85)
				"material": icon_rect.color = Color(0.5, 0.45, 0.1, 0.85)
				_: icon_rect.color = Color(0.3, 0.3, 0.35, 0.75)
			# P3: 
			if GameManager.FOOD_CATEGORIES.has(item["id"]):
				var spoil_status: int = GameManager._get_food_spoil_status(item["id"], idx)
				if spoil_status == 2:
					icon_rect.color = Color(0.5, 0.15, 0.15, 0.9)   # =
				elif spoil_status == 1:
					icon_rect.color = Color(0.6, 0.55, 0.15, 0.9)   # =
		if item_icon:
			item_icon.visible = true
			item_icon.color = Color(0.5, 0.5, 0.5, 0.6)
	else:
		if icon_rect: icon_rect.visible = false
		if item_icon: item_icon.visible = false


func _show_slot_tooltip(slot: Control, text: String) -> void:
	"""tooltip"""
	hotbar_tooltip.text = text
	# tooltip
	hotbar_tooltip.size.x = max(60, text.length() * 11 + 16)
	# slot
	var slot_global: Vector2 = slot.global_position
	var panel_global: Vector2 = hotbar_panel.global_position
	hotbar_tooltip.position = Vector2(
		slot_global.x - panel_global.x + (slot.size.x - hotbar_tooltip.size.x) / 2,
		slot_global.y - panel_global.y - 22
	)
	hotbar_tooltip.visible = true


func _on_slot_clicked(idx: int) -> void:
	""" → """
	if popup_open:
		return
	if idx >= GameManager.inventory.size():
		return
	_show_item_action_popup(idx)


# ====================  ====================

func _build_item_action_panel() -> void:
	item_action_panel = Panel.new()
	item_action_panel.position = Vector2(20, 350)
	item_action_panel.size = Vector2(360, 240)
	item_action_panel.self_modulate = Color(0.08, 0.08, 0.1, 0.97)
	item_action_panel.visible = false
	item_action_panel.name = "item_action_panel"
	add_child(item_action_panel)


func _show_item_action_popup(idx: int) -> void:
	"""///"""
	if not item_action_panel:
		_build_item_action_panel()

	# 
	for c in item_action_panel.get_children():
		c.queue_free()

	var item: Dictionary = GameManager.inventory[idx]
	var item_id: String = item["id"]
	var d: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
	var itype: String = d.get("type", "")
	var name_str: String = d.get("name", item_id)

	# 
	var title: Label = Label.new()
	title.text = "=== %s (x%d) ===" % [name_str, item["amount"]]
	title.position = Vector2(15, 12)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	item_action_panel.add_child(title)

	# 
	var desc_lbl: Label = Label.new()
	desc_lbl.text = d.get("desc", "")
	desc_lbl.position = Vector2(15, 44)
	desc_lbl.size = Vector2(440, 60)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 24)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	item_action_panel.add_child(desc_lbl)

	# 
	var btn_vbox := VBoxContainer.new()
	btn_vbox.position = Vector2(20, 114)
	btn_vbox.add_theme_constant_override("separation", 6)
	item_action_panel.add_child(btn_vbox)

	# 
	if itype == "weapon":
		var use_btn: Button = Button.new()
		use_btn.text = "装备武器"
		use_btn.add_theme_font_size_override("font_size", 24)
		use_btn.pressed.connect(func():
			var side: String = "right" if GameManager.equip_right == "" else "left"
			if GameManager.equip_left == "" and GameManager.equip_right == "":
				side = "right"
			elif GameManager.equip_left != "" and GameManager.equip_right != "":
				GameManager.unequip_weapon("right")
				side = "right"
			var msg: String = GameManager.equip_weapon(side, item_id)
			_show_popup(msg)
			_close_item_action()
		)
		btn_vbox.add_child(use_btn)

	elif itype == "consumable":
		var use_btn: Button = Button.new()
		use_btn.text = "使用"
		use_btn.pressed.connect(func():
			var msg: String = GameManager.use_item_by_index(idx)
			_show_popup(msg)
			_close_item_action()
		)
		btn_vbox.add_child(use_btn)

	# 
	if not GameManager.is_exploring and not GameManager.is_in_guest_house:
		var store_btn: Button = Button.new()
		store_btn.text = "放入仓库"
		store_btn.pressed.connect(func():
			GameManager.store_item(item_id, min(item["amount"], 99))
			_show_popup("已存入仓库")
			_close_item_action()
		)
		btn_vbox.add_child(store_btn)

	# 
	var cap_idx: int = idx
	var cap_item_id: String = item_id
	var cap_amount: int = item["amount"]
	var drop_btn: Button = Button.new()
	var is_outside: bool = GameManager.is_exploring or GameManager.is_in_guest_house
	if is_outside:
		drop_btn.text = "丢弃（全部）"
	else:
		drop_btn.text = "丢弃（全部）"
	drop_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	drop_btn.pressed.connect(func():
		if is_outside:
			# 
			GameManager.remove_item(cap_item_id, cap_amount)
			_show_popup("[color=red] %s ×%d[/color]" % [name_str, cap_amount])
		else:
			if GameManager.discard_to_trash(cap_item_id, cap_amount):
				_show_popup("已丢弃: %s ×%d" % [name_str, cap_amount])
		_close_item_action()
	)
	btn_vbox.add_child(drop_btn)

	# 
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_close_item_action)
	btn_vbox.add_child(close_btn)

	item_action_panel.visible = true
	popup_open = true
	_update_mouse_mode()


func _close_item_action() -> void:
	if item_action_panel:
		item_action_panel.visible = false
	popup_open = false
	_update_mouse_mode()


func _on_explore_pressed() -> void:
	if popup_open:
		return
	explore_panel.visible = not explore_panel.visible
	popup_open = explore_panel.visible
	_update_mouse_mode()


# ==================== () ====================
func _build_inventory_panel() -> void:
	inventory_panel = Panel.new()
	inventory_panel.position = Vector2(340, 120)
	inventory_panel.size = Vector2(640, 480)
	inventory_panel.self_modulate = Color(0.1, 0.1, 0.1, 0.95)
	inventory_panel.visible = false
	add_child(inventory_panel)

	var title := Label.new()
	title.text = "=== 物品栏 ==="
	title.position = Vector2(15, 10)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color.WHITE)
	inventory_panel.add_child(title)

	# ScrollContainer 
	inventory_scroll = ScrollContainer.new()
	inventory_scroll.position = Vector2(15, 42)
	inventory_scroll.size = Vector2(610, 360)
	inventory_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	inventory_panel.add_child(inventory_scroll)

	inventory_list = VBoxContainer.new()
	inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_list.add_theme_constant_override("separation", 4)
	inventory_scroll.add_child(inventory_list)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(15, 415)
	close_btn.size = Vector2(610, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func(): inventory_panel.visible = false; popup_open = false; _update_mouse_mode())
	inventory_panel.add_child(close_btn)

	_update_inventory()


func _update_inventory() -> void:
	# UI
	_update_hotbar()
	if not inventory_list:
		return
	# 
	for c in inventory_list.get_children():
		c.queue_free()

	for i in range(GameManager.inventory.size()):
		var item: Dictionary = GameManager.inventory[i]
		var item_id: String = item["id"]
		var data: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
		var item_name: String = data.get("name", item_id)
		var desc: String = data.get("desc", "")
		var itype: String = data.get("type", "")
		var amount: int = item["amount"]
		var is_equipped: bool = (item_id == GameManager.equip_left or item_id == GameManager.equip_right)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# 
		var type_label := Label.new()
		type_label.add_theme_font_size_override("font_size", 16)
		match itype:
			"consumable":
				type_label.text = "[食物]"
				type_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			"weapon":
				type_label.text = "[武器]"
				type_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			"material":
				type_label.text = "[材料]"
				type_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
			_:
				type_label.text = "[其他]"
				type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		type_label.add_theme_font_size_override("font_size", 16)
		row.add_child(type_label)

		# /
		var item_btn := Button.new()
		if is_equipped:
			item_btn.text = "%s x%d ()" % [item_name, amount]
			item_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		else:
			item_btn.text = "%s x%d - %s" % [item_name, amount, desc]
		item_btn.flat = true
		item_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_btn.add_theme_font_size_override("font_size", 18)
		var idx := i
		item_btn.pressed.connect(func(): _on_inventory_item_used(idx))
		row.add_child(item_btn)

		# 
		if itype == "consumable":
			var eat_btn := Button.new()
			eat_btn.text = "食用"
			eat_btn.custom_minimum_size = Vector2(55, 28)
			eat_btn.add_theme_font_size_override("font_size", 15)
			eat_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			var eat_idx := i
			eat_btn.pressed.connect(func():
				var msg: String = GameManager.use_item_by_index(eat_idx)
				_show_popup(msg)
				_update_inventory()
			)
			row.add_child(eat_btn)

		# 
		if itype == "weapon" and not is_equipped:
			var equip_btn := Button.new()
			equip_btn.text = "装备"
			equip_btn.custom_minimum_size = Vector2(55, 28)
			equip_btn.add_theme_font_size_override("font_size", 15)
			equip_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			var equip_idx := i
			equip_btn.pressed.connect(func():
				var side: String = "right" if GameManager.equip_right == "" else "left"
				var msg: String = GameManager.equip_weapon(side, GameManager.inventory[equip_idx]["id"])
				_show_popup(msg)
				_update_inventory()
			)
			row.add_child(equip_btn)

		# 
		if not is_equipped:
			var discard_btn := Button.new()
			discard_btn.text = "丢弃"
			discard_btn.custom_minimum_size = Vector2(55, 28)
			discard_btn.add_theme_font_size_override("font_size", 15)
			discard_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			var discard_idx := i
			discard_btn.pressed.connect(func(): _discard_item(discard_idx))
			row.add_child(discard_btn)

		inventory_list.add_child(row)


func _on_inventory_item_used(idx: int) -> void:
	if idx < 0 or idx >= GameManager.inventory.size():
		return
	var item: Dictionary = GameManager.inventory[idx]
	var item_id: String = item["id"]
	var data: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
	if data.get("type", "") == "weapon":
		var side: String = "right" if GameManager.equip_right == "" else "left"
		var msg: String = GameManager.equip_weapon(side, item_id)
		_show_popup(msg)
	else:
		var msg: String = GameManager.use_item_by_index(idx)
		_show_popup(msg)
	_update_inventory()


func _discard_item(idx: int) -> void:
	if idx < 0 or idx >= GameManager.inventory.size():
		return
	var item: Dictionary = GameManager.inventory[idx]
	var item_id: String = item["id"]
	var data: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
	var item_name: String = data.get("name", item_id)
	# 1
	item["amount"] = item["amount"] - 1
	if item["amount"] <= 0:
		GameManager.inventory.remove_at(idx)
		# 
		if item_id == GameManager.equip_left:
			GameManager.equip_left = ""
		if item_id == GameManager.equip_right:
			GameManager.equip_right = ""
	_show_popup("丢弃: %s" % item_name)
	_update_hotbar()
	_update_inventory()


# ==================== / ====================
func _build_craft_panel() -> void:
	craft_panel = Panel.new()
	craft_panel.position = Vector2(160, 110)
	craft_panel.size = Vector2(960, 500)
	craft_panel.self_modulate = Color(0.08, 0.08, 0.1, 0.97)
	craft_panel.visible = false
	craft_panel.z_index = 10
	add_child(craft_panel)


func _toggle_craft() -> void:
	if popup_open and not craft_panel.visible:
		return
	craft_panel.visible = not craft_panel.visible
	popup_open = craft_panel.visible
	_update_mouse_mode()
	if craft_panel.visible:
		_refresh_craft_panel()


func _refresh_craft_panel() -> void:
	#  queue_free get_node 
	for c in craft_panel.get_children():
		craft_panel.remove_child(c)
		c.queue_free()

	var title := Label.new()
	title.text = "=== 工作台 ==="
	title.position = Vector2(0, 8)
	title.size = Vector2(960, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	craft_panel.add_child(title)

	# 
	var tabs: Array[String] = ["武器", "食物", "药品", "其他"]
	var categories: Array[String] = ["weapon", "food", "medicine", "other"]
	var tab_btns: Array = []
	var tab_container := HBoxContainer.new()
	tab_container.position = Vector2(30, 45)
	tab_container.add_theme_constant_override("separation", 5)
	craft_panel.add_child(tab_container)

	for i in tabs.size():
		var tb := Button.new()
		tb.text = tabs[i]
		tb.size = Vector2(100, 28)
		tb.add_theme_font_size_override("font_size", 18)
		tb.pressed.connect(_show_craft_category.bind(categories[i]))
		tab_container.add_child(tb)
		tab_btns.append(tb)

	# 
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(15, 80)
	scroll.size = Vector2(930, 340)
	scroll.name = "recipe_scroll"
	craft_panel.add_child(scroll)

	# 
	_show_craft_category("weapon")

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(380, 440)
	close_btn.size = Vector2(200, 40)
	close_btn.pressed.connect(func(): craft_panel.visible = false; popup_open = false; _update_mouse_mode())
	craft_panel.add_child(close_btn)


func _show_craft_category(category: String) -> void:
	var scroll: ScrollContainer = craft_panel.get_node_or_null("recipe_scroll")
	if not scroll:
		return
	# 
	for c in scroll.get_children():
		scroll.remove_child(c)
		c.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	scroll.add_child(vbox)

	for recipe_id in GameManager.CRAFT_RECIPES:
		var recipe: Dictionary = GameManager.CRAFT_RECIPES[recipe_id]
		if recipe.get("category", "") != category:
			continue

		# === 1 +  +  +  ===
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# 
		var name_label := Label.new()
		name_label.size = Vector2(130, 28)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
		name_label.text = "制作: " + recipe.get("name", recipe_id)
		row.add_child(name_label)

		# 
		var result_data: Dictionary = GameManager.ITEM_DATA.get(recipe_id, {})
		var effect_text: String = ""
		var eff: String = result_data.get("effect", "")
		if eff != "":
			effect_text = _translate_effect(eff)
		elif result_data.get("type", "") == "weapon":
			effect_text = ":%d" % result_data.get("damage", 0)
		var eff_label := Label.new()
		eff_label.size = Vector2(140, 28)
		eff_label.add_theme_font_size_override("font_size", 20)
		eff_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
		eff_label.text = effect_text
		row.add_child(eff_label)

		#  + 
		var mats: Dictionary = recipe.get("materials", {})
		var can_craft: bool = true
		var mats_display: String = ""
		var missing_parts: Array[String] = []
		for mat_id in mats:
			var needed: int = mats[mat_id]
			var have: int = 0
			var inv_idx: int = GameManager.find_item(mat_id)
			if inv_idx >= 0:
				have += GameManager.inventory[inv_idx]["amount"]
			have += GameManager.storage.get(mat_id, 0)
			var mat_name: String = GameManager.ITEM_DATA.get(mat_id, {}).get("name", mat_id)
			if have >= needed:
				mats_display += "%s %d/%d    " % [mat_name, have, needed]
			else:
				mats_display += "[color=red]%s %d/%d[/color]    " % [mat_name, have, needed]
				can_craft = false
				missing_parts.append(" %s×%d (:%d)" % [mat_name, needed - have, have])

		var mats_inline := RichTextLabel.new()
		mats_inline.size = Vector2(400, 28)
		mats_inline.bbcode_enabled = true
		mats_inline.fit_content = true
		mats_inline.text = mats_display
		row.add_child(mats_inline)

		# 
		var craft_btn: Button = Button.new()
		craft_btn.size = Vector2(100, 32)
		craft_btn.add_theme_font_size_override("font_size", 21)
		if can_craft:
			craft_btn.text = "[制作]"
			craft_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			craft_btn.pressed.connect(_on_craft_btn.bind(recipe_id))
		else:
			craft_btn.text = "制作"
			craft_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
			craft_btn.disabled = true
		row.add_child(craft_btn)

		vbox.add_child(row)

		# 属性点
		var attr_label := Label.new()
		attr_label.custom_minimum_size = Vector2(900, 20)
		attr_label.add_theme_font_size_override("font_size", 16)
		attr_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		if result_data.get("type", "") == "weapon":
			attr_label.text = "攻击:%d" % result_data.get("damage", 0)
		else:
			attr_label.text = effect_text
		vbox.add_child(attr_label)

		# === 2 ===
		if not can_craft:
			var lack_row := HBoxContainer.new()
			var lack_label := Label.new()
			lack_label.custom_minimum_size = Vector2(900, 24)
			lack_label.add_theme_font_size_override("font_size", 18)
			lack_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
			# BBCodeLabel
			var lack_text: String = "   : "
			for part in missing_parts:
				lack_text += part + "  "
			lack_label.text = lack_text
			lack_row.add_child(lack_label)
			vbox.add_child(lack_row)


#  bind 
func _on_craft_btn(recipe_id: String) -> void:
	var msg: String = GameManager.craft_item(recipe_id)
	_show_popup(msg)
	_refresh_craft_panel()


func _translate_effect(effect_raw: String) -> String:
	""" 'hunger+40,sanity+5' """
	var parts: PackedStringArray = effect_raw.split(",", false)
	var cn_parts: Array[String] = []
	for p in parts:
		p = p.strip_edges()
		if p.begins_with("hp+"):
			cn_parts.append("+%s" % p.substr(3))
		elif p.begins_with("hunger+"):
			cn_parts.append("+%s" % p.substr(7))
		elif p.begins_with("sanity+"):
			cn_parts.append("+%s" % p.substr(7))
		else:
			cn_parts.append(p)
	return ",".join(cn_parts)


# ====================  ====================
func _build_storage_panel() -> void:
	storage_panel = Panel.new()
	storage_panel.position = Vector2(240, 80)
	storage_panel.size = Vector2(800, 550)
	storage_panel.self_modulate = Color(0.06, 0.06, 0.08, 0.97)
	storage_panel.visible = false
	storage_panel.z_index = 10
	add_child(storage_panel)


func _toggle_storage() -> void:
	# 
	if GameManager.is_exploring or GameManager.is_in_guest_house:
		return
	if popup_open and (not storage_panel.visible):
		return
	storage_panel.visible = not storage_panel.visible
	popup_open = storage_panel.visible
	_update_mouse_mode()
	if storage_panel.visible:
		_refresh_storage_panel()


func _refresh_storage_panel() -> void:
	for c in storage_panel.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "=== 仓库 ==="
	title.position = Vector2(0, 8)
	title.size = Vector2(800, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	storage_panel.add_child(title)

	# 
	var take_all_btn := Button.new()
	take_all_btn.text = "全部取出【Y】"
	take_all_btn.position = Vector2(380, 425)
	take_all_btn.size = Vector2(200, 40)
	take_all_btn.add_theme_font_size_override("font_size", 21)
	take_all_btn.pressed.connect(func(): _storage_take_all())
	if GameManager.storage.is_empty():
		take_all_btn.disabled = true
	storage_panel.add_child(take_all_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(15, 45)
	scroll.size = Vector2(770, 370)
	storage_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	if GameManager.storage.is_empty():
		var empty_label := Label.new()
		empty_label.text = "没有可存放的物品\n"
		empty_label.size = Vector2(750, 50)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(empty_label)
	else:
		for item_id in GameManager.storage:
			var amount: int = GameManager.storage[item_id]
			var data: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var name_label := Label.new()
			name_label.size = Vector2(150, 30)
			name_label.add_theme_font_size_override("font_size", 20)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			name_label.text = "%s ×%d" % [data.get("name", item_id), amount]
			row.add_child(name_label)

			var desc_label := Label.new()
			desc_label.size = Vector2(300, 30)
			desc_label.add_theme_font_size_override("font_size", 17)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			desc_label.text = data.get("desc", "")
			row.add_child(desc_label)

			var take_btn := Button.new()
			take_btn.text = "取出"
			take_btn.size = Vector2(60, 30)
			take_btn.add_theme_font_size_override("font_size", 17)
			if GameManager.inventory.size() >= GameManager.MAX_INVENTORY:
				take_btn.disabled = true
				take_btn.tooltip_text = "背包已满"
			take_btn.pressed.connect(func():
				if GameManager.take_from_storage(item_id):
					_update_inventory()
					_refresh_storage_panel()
					_show_popup("已取出: %s" % data.get("name", item_id))
			)
			row.add_child(take_btn)

			# 
			if data.get("type", "") == "consumable":
				var use_btn := Button.new()
				use_btn.text = "使用"
				use_btn.size = Vector2(80, 30)
				use_btn.add_theme_font_size_override("font_size", 17)
				use_btn.pressed.connect(func():
					if GameManager.inventory.size() >= GameManager.MAX_INVENTORY:
						# 背包满 → 直接从仓库消耗，不放入背包
						GameManager.storage[item_id] -= 1
						if GameManager.storage[item_id] <= 0:
							GameManager.storage.erase(item_id)
						GameManager._apply_item_effect(data)
						var eff: String = data.get("effect", "")
						var name_str: String = data.get("name", item_id)
						if eff == "":
							_show_popup("[color=green]%s[/color]" % name_str)
						else:
							_show_popup("[color=green]%s → %s[/color]" % [name_str, eff])
						GameManager.storage_updated.emit()
						_refresh_storage_panel()
					else:
						if GameManager.take_from_storage(item_id):
							var idx: int = GameManager.find_item(item_id)
							if idx >= 0:
								var msg: String = GameManager.use_item_by_index(idx)
								_show_popup(msg if msg != "" else "使用完成")
							_refresh_storage_panel()
				)
				row.add_child(use_btn)

			vbox.add_child(row)

	# 
	var put_title := Label.new()
	put_title.text = "--- 物品存放 ---"
	put_title.position = Vector2(15, 395)
	put_title.size = Vector2(250, 25)
	put_title.add_theme_font_size_override("font_size", 22)
	put_title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	storage_panel.add_child(put_title)

	# 
	var put_all_btn := Button.new()
	put_all_btn.text = " [Y]"
	put_all_btn.position = Vector2(585, 425)
	put_all_btn.size = Vector2(200, 40)
	put_all_btn.add_theme_font_size_override("font_size", 21)
	put_all_btn.pressed.connect(func(): _storage_put_all())
	storage_panel.add_child(put_all_btn)

	# 
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(310, 490)
	close_btn.size = Vector2(180, 40)
	close_btn.pressed.connect(func(): storage_panel.visible = false; popup_open = false; _update_mouse_mode())
	storage_panel.add_child(close_btn)

	if GameManager.inventory.is_empty():
		put_all_btn.disabled = true
	else:
		# 
		var inv_hbox: HBoxContainer = HBoxContainer.new()
		inv_hbox.position = Vector2(15, 458)
		inv_hbox.add_theme_constant_override("separation", 6)
		storage_panel.add_child(inv_hbox)

		for idx in range(GameManager.inventory.size()):
			var item: Dictionary = GameManager.inventory[idx]
			var item_id: String = item["id"]
			var d: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
			var put_btn: Button = Button.new()
			put_btn.text = "%s×%d" % [d.get("name", item_id).substr(0, 3), item["amount"]]
			put_btn.custom_minimum_size = Vector2(85, 30)
			put_btn.add_theme_font_size_override("font_size", 20)
			var cap_idx: int = idx
			put_btn.pressed.connect(func():
				if cap_idx < GameManager.inventory.size():
					var itm: Dictionary = GameManager.inventory[cap_idx]
					var iid: String = itm["id"]
					GameManager.store_item(iid, min(itm["amount"], 99))
					_show_popup("已存入仓库")
					_refresh_storage_panel()
			)
			inv_hbox.add_child(put_btn)


func _storage_put_all() -> void:
	"""全部存入仓库"""
	if GameManager.inventory.is_empty():
		_show_popup("背包已空，没有可存入的物品")
		return
	var count: int = GameManager.store_all_items()
	if count > 0:
		_update_inventory()
		_show_popup("已存入仓库: %d件物品" % count)
		_refresh_storage_panel()


func _storage_take_all() -> void:
	"""全部从仓库取出"""
	if GameManager.storage.is_empty():
		_show_popup("仓库已空，没有可拿取的物品")
		return
	if GameManager.inventory.size() >= GameManager.MAX_INVENTORY and not _can_stack_any():
		_show_popup("背包已满，无法取出物品")
		return
	var taken_count: int = 0
	var storage_keys: Array = GameManager.storage.keys().duplicate()
	for item_id in storage_keys:
		while GameManager.storage.has(item_id) and GameManager.storage[item_id] > 0:
			if GameManager.take_from_storage(item_id):
				taken_count += 1
			else:
				break
	_update_inventory()
	_refresh_storage_panel()
	if taken_count > 0:
		_show_popup("已从仓库取出: %d件物品" % taken_count)
	else:
		_show_popup("没有可拿取的物品")


func _can_stack_any() -> bool:
	""""""
	for item_id in GameManager.storage:
		if GameManager.find_item(item_id) >= 0:
			return true
	return false


func _update_storage_panel() -> void:
	if storage_panel and storage_panel.visible:
		_refresh_storage_panel()


# ====================  ====================
func _build_trash_panel() -> void:
	trash_panel = Panel.new()
	trash_panel.position = Vector2(240, 80)
	trash_panel.size = Vector2(800, 520)
	trash_panel.self_modulate = Color(0.06, 0.08, 0.06, 0.97)  # 
	trash_panel.visible = false
	trash_panel.z_index = 10
	add_child(trash_panel)


func _toggle_trash() -> void:
	if popup_open and not trash_panel.visible:
		return
	trash_panel.visible = not trash_panel.visible
	popup_open = trash_panel.visible
	_update_mouse_mode()
	if trash_panel.visible:
		_refresh_trash_panel()


func _refresh_trash_panel() -> void:
	for c in trash_panel.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "=== 垃圾桶 ==="
	title.position = Vector2(0, 25)
	title.size = Vector2(800, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	trash_panel.add_child(title)

	var hint := Label.new()
	hint.text = "丢弃的物品会暂时留在这里，可以捡回。"
	hint.position = Vector2(0, 70)
	hint.size = Vector2(800, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.5))
	trash_panel.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(15, 100)
	scroll.size = Vector2(770, 315)
	trash_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	if not GameManager.trash_bin.is_empty():
		for item_id in GameManager.trash_bin:
			var amount: int = GameManager.trash_bin[item_id]
			var data: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)

			var name_label := Label.new()
			name_label.size = Vector2(150, 30)
			name_label.add_theme_font_size_override("font_size", 20)
			name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			name_label.text = "%s ×%d" % [data.get("name", item_id), amount]
			row.add_child(name_label)

			var desc_label := Label.new()
			desc_label.size = Vector2(300, 30)
			desc_label.add_theme_font_size_override("font_size", 17)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			desc_label.text = data.get("desc", "")
			row.add_child(desc_label)

			var take_btn := Button.new()
			take_btn.text = "捡回"
			take_btn.size = Vector2(60, 30)
			take_btn.add_theme_font_size_override("font_size", 17)
			take_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			take_btn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if GameManager.inventory.size() >= GameManager.MAX_INVENTORY:
				take_btn.disabled = true
				take_btn.tooltip_text = "背包已满"
			take_btn.pressed.connect(func():
				if GameManager.take_from_trash(item_id):
					_refresh_trash_panel()
					_show_popup("已从垃圾桶取出: %s" % data.get("name", item_id))
			)
			row.add_child(take_btn)

			vbox.add_child(row)

	# 
	var btn_y: float = 430
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(160, btn_y)
	close_btn.size = Vector2(140, 40)
	close_btn.pressed.connect(func(): trash_panel.visible = false; popup_open = false; _update_mouse_mode())
	trash_panel.add_child(close_btn)

	# 
	var take_all_btn := Button.new()
	take_all_btn.text = "全部拾取"
	take_all_btn.position = Vector2(460, btn_y)
	take_all_btn.size = Vector2(180, 40)
	take_all_btn.add_theme_font_size_override("font_size", 20)
	take_all_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	if GameManager.trash_bin.is_empty():
		take_all_btn.disabled = true
	take_all_btn.pressed.connect(func():
		var taken: int = GameManager.take_all_from_trash()
		if taken > 0:
			_show_popup(" %d " % taken)
		_refresh_trash_panel()
	)
	trash_panel.add_child(take_all_btn)


func _update_trash_panel() -> void:
	if trash_panel and trash_panel.visible:
		_refresh_trash_panel()


# ====================  ====================
var current_cabinet_id: int = -1
var current_cabinet_items: Array = []

func _build_cabinet_panel() -> void:
	cabinet_panel = Panel.new()
	cabinet_panel.position = Vector2(290, 135)
	cabinet_panel.size = Vector2(700, 450)
	cabinet_panel.self_modulate = Color(0.06, 0.06, 0.08, 0.97)
	cabinet_panel.visible = false
	cabinet_panel.z_index = 10
	add_child(cabinet_panel)


func show_cabinet_panel(cab_id: int, items: Array) -> void:
	""""""
	if not cabinet_panel:
		_build_cabinet_panel()
	current_cabinet_id = cab_id
	current_cabinet_items = items

	for c in cabinet_panel.get_children():
		c.queue_free()

	var title: Label = Label.new()
	title.text = "=== 柜子 ==="
	title.position = Vector2(0, 8)
	title.size = Vector2(700, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	cabinet_panel.add_child(title)

	# 
	var count_lbl: Label = Label.new()
	count_lbl.name = "cab_count_label"
	count_lbl.text = "物品总数: %d" % items.size()
	count_lbl.position = Vector2(15, 38)
	count_lbl.add_theme_font_size_override("font_size", 17)
	count_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	cabinet_panel.add_child(count_lbl)

	# 
	var take_all_btn: Button = Button.new()
	take_all_btn.text = "全部拾取"
	take_all_btn.position = Vector2(500, 35)
	take_all_btn.size = Vector2(180, 30)
	take_all_btn.add_theme_font_size_override("font_size", 18)
	take_all_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	take_all_btn.pressed.connect(_cabinet_take_all)
	cabinet_panel.add_child(take_all_btn)

	# 
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.position = Vector2(15, 75)
	scroll.size = Vector2(670, 310)
	cabinet_panel.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	if items.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "储物柜是空的"
		empty_lbl.size = Vector2(650, 40)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 22)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		vbox.add_child(empty_lbl)
	else:
		for i in range(items.size()):
			var item_id: String = items[i]
			var d: Dictionary = GameManager.ITEM_DATA.get(item_id, {})
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			# 
			var icon: ColorRect = ColorRect.new()
			icon.custom_minimum_size = Vector2(28, 28)
			var itype: String = d.get("type", "")
			match itype:
				"weapon": icon.color = Color(0.6, 0.3, 0.1)
				"consumable": icon.color = Color(0.1, 0.5, 0.15)
				_: icon.color = Color(0.3, 0.3, 0.35)
			row.add_child(icon)

			# 
			var name_lbl: Label = Label.new()
			name_lbl.text = d.get("name", item_id)
			name_lbl.custom_minimum_size = Vector2(140, 28)
			name_lbl.add_theme_font_size_override("font_size", 18)
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
			row.add_child(name_lbl)

			# 
			var desc_lbl: Label = Label.new()
			desc_lbl.text = d.get("desc", "")
			desc_lbl.custom_minimum_size = Vector2(280, 28)
			desc_lbl.add_theme_font_size_override("font_size", 15)
			desc_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			row.add_child(desc_lbl)

			# 
			var take_btn: Button = Button.new()
			take_btn.text = "捡回"
			take_btn.custom_minimum_size = Vector2(60, 28)
			take_btn.add_theme_font_size_override("font_size", 17)
			var idx_capture: int = i  # 
			take_btn.pressed.connect(func(): _cabinet_take_one(idx_capture))
			row.add_child(take_btn)

			vbox.add_child(row)

	# 
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(250, 405)
	close_btn.size = Vector2(200, 36)
	close_btn.pressed.connect(func():
		cabinet_panel.visible = false
		popup_open = false
		_update_mouse_mode()
	)
	cabinet_panel.add_child(close_btn)

	cabinet_panel.visible = true
	popup_open = true
	_update_mouse_mode()


func _cabinet_take_one(idx: int) -> void:
	""""""
	if idx >= current_cabinet_items.size():
		return
	var item_id: String = current_cabinet_items[idx]
	current_cabinet_items.remove_at(idx)
	var added: bool = GameManager.add_item(item_id)
	if added:
		var name: String = GameManager.ITEM_DATA.get(item_id, {}).get("name", item_id)
		_show_popup("获得: %s" % name)
		_update_inventory()
		# GameManagercabinet_items
		if GameManager.cabinet_items.has(current_cabinet_id):
			GameManager.cabinet_items[current_cabinet_id] = current_cabinet_items
		# 
		show_cabinet_panel(current_cabinet_id, current_cabinet_items)


func _cabinet_take_all() -> void:
	""""""
	var taken: int = 0
	var skipped: int = 0
	for item_id in current_cabinet_items.duplicate():
		if GameManager.inventory.size() >= GameManager.MAX_INVENTORY:
			skipped += 1
		elif GameManager.add_item(item_id):
			taken += 1
			current_cabinet_items.erase(item_id)

	# 
	if GameManager.cabinet_items.has(current_cabinet_id):
		GameManager.cabinet_items[current_cabinet_id] = current_cabinet_items

	if taken > 0:
		_update_inventory()
		_show_popup(" %d %s" % [taken, (" (%d)" % skipped) if skipped > 0 else ""])
	else:
		_show_popup("没有可拿取的物品")

	show_cabinet_panel(current_cabinet_id, current_cabinet_items)


# ====================  ====================
func _build_explore_panel() -> void:
	explore_panel = Panel.new()
	explore_panel.position = Vector2(340, 120)
	explore_panel.size = Vector2(600, 450)
	explore_panel.self_modulate = Color(0.1, 0.1, 0.1, 0.95)
	explore_panel.visible = false
	add_child(explore_panel)

	var title := Label.new()
	title.text = "=== 外出探索 ==="
	title.position = Vector2(15, 10)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color.WHITE)
	explore_panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(15, 45)
	scroll.size = Vector2(570, 335)
	explore_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	for loc_id in GameManager.EXPLORE_LOCATIONS:
		var loc: Dictionary = GameManager.EXPLORE_LOCATIONS[loc_id]
		var section := VBoxContainer.new()
		var name_label := Label.new()
		name_label.text = loc.get("name", loc_id)
		name_label.add_theme_font_size_override("font_size", 21)
		name_label.add_theme_color_override("font_color", Color.YELLOW)
		section.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = loc.get("desc", "")
		desc_label.add_theme_font_size_override("font_size", 20)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.custom_minimum_size = Vector2(540, 0)
		section.add_child(desc_label)
		var go_btn := Button.new()
		var acts: int = loc.get("time_actions", 1)
		var rtype: String = loc.get("room_type", "")
		var type_tag: String = "废弃" if rtype == "abandoned" else ("有人" if rtype == "occupied" else "")
		go_btn.text = "%s (%dh, 危险度:%.0f%%) %s" % [loc.get("name", loc_id), acts, loc.get("danger", 0.0) * 100, ("[" + type_tag + "]" if type_tag != "" else "")]
		go_btn.size = Vector2(540, 30)
		go_btn.pressed.connect(_on_explore_go.bind(loc_id))
		section.add_child(go_btn)
		vbox.add_child(section)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(15, 395)
	close_btn.size = Vector2(570, 35)
	close_btn.pressed.connect(func(): explore_panel.visible = false; popup_open = false; _update_mouse_mode())
	explore_panel.add_child(close_btn)


func _on_explore_go(loc_id: String) -> void:
	explore_panel.visible = false
	popup_open = false
	_update_mouse_mode()
	var main: Node = get_parent()
	if main and main.has_method("on_explore"):
		main.on_explore(loc_id)


# ====================  ====================
func _build_game_over_panel() -> void:
	game_over_panel = Panel.new()
	game_over_panel.position = Vector2(240, 100)
	game_over_panel.size = Vector2(800, 500)
	game_over_panel.self_modulate = Color(0.05, 0.05, 0.05, 0.97)
	game_over_panel.visible = false
	add_child(game_over_panel)


func show_game_over(reason: String, kills: int) -> void:
	for c in game_over_panel.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "游戏结束"
	title.position = Vector2(250, 40)
	title.add_theme_font_size_override("font_size", 50)
	title.add_theme_color_override("font_color", Color.RED)
	game_over_panel.add_child(title)

	var reason_label := Label.new()
	reason_label.text = reason
	reason_label.position = Vector2(50, 120)
	reason_label.size = Vector2(700, 60)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 25)
	reason_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	game_over_panel.add_child(reason_label)

	var stats := Label.new()
	stats.text = "第 %d 天      |      击杀 %d 只丧尸" % [GameManager.current_day, kills]
	stats.position = Vector2(50, 200)
	stats.size = Vector2(700, 40)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 28)
	stats.add_theme_color_override("font_color", Color.WHITE)
	game_over_panel.add_child(stats)

	var restart_btn := Button.new()
	restart_btn.text = "重新开始"
	restart_btn.position = Vector2(250, 330)
	restart_btn.size = Vector2(300, 50)
	restart_btn.add_theme_font_size_override("font_size", 28)
	restart_btn.pressed.connect(_on_restart)
	game_over_panel.add_child(restart_btn)

	game_over_panel.visible = true
	_update_mouse_mode()


func _on_restart() -> void:
	game_over_panel.visible = false
	_update_mouse_mode()
	GameManager.game_over = false
	var main: Node = get_parent()
	if main and main.has_method("_show_start_screen"):
		main._show_start_screen()


func _on_game_over(_d, _h, _r, _k) -> void:
	pass


func _count_survivors() -> int:
	var count: int = 0
	for npc in GameManager.room_npcs:
		if npc.get("type", "") == "survivor":
			count += 1
	return count


func _count_imposters() -> int:
	var count: int = 0
	for npc in GameManager.room_npcs:
		if npc.get("type", "") == "imposter":
			count += 1
	return count


# ====================  ====================
func _build_midnight_panel() -> void:
	midnight_panel = Panel.new()
	midnight_panel.position = Vector2(340, 200)
	midnight_panel.size = Vector2(600, 320)
	midnight_panel.self_modulate = Color(0.05, 0.05, 0.1, 0.97)
	midnight_panel.visible = false
	add_child(midnight_panel)


func show_midnight_warning() -> void:
	if midnight_panel.visible:
		return
	popup_open = true
	for c in midnight_panel.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "有人在敲门"
	title.position = Vector2(0, 30)
	title.size = Vector2(600, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 39)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	midnight_panel.add_child(title)

	var text := Label.new()
	text.text = "你听到门外有敲门声。要不要让小丽去看看？\n(消耗1次行动)"
	text.position = Vector2(50, 90)
	text.size = Vector2(500, 120)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 22)
	text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	midnight_panel.add_child(text)

	var ok_btn := Button.new()
	ok_btn.text = "确定"
	ok_btn.position = Vector2(200, 240)
	ok_btn.size = Vector2(200, 45)
	ok_btn.add_theme_font_size_override("font_size", 25)
	ok_btn.pressed.connect(func():
		midnight_panel.visible = false
		popup_open = false
		_update_mouse_mode()
	)
	midnight_panel.add_child(ok_btn)
	midnight_panel.visible = true
	_update_mouse_mode()


# ====================  ====================
func _update_door_display(hp: int, max_hp: int, reinforce: int) -> void:
	pass  # HUD


# ====================  →  ====================
# show_door_panel, show_door_knock_panel, _build_knock_panel,
# _build_knock_alert_panel, show_knock_alert, show_knock_notification,
# _show_knock_dialogue_phase, _get_npc_door_dialogue, _on_npc_door_choice,
# _on_npc_stay_night, _on_npc_door_talk 
#  → (peephole_scene) → NPC(npc_encounter_scene)


# ====================  ====================
func _build_horde_panel() -> void:
	horde_panel = Panel.new()
	horde_panel.position = Vector2(250, 120)
	horde_panel.size = Vector2(700, 420)
	horde_panel.self_modulate = Color(0.08, 0.04, 0.04, 0.97)
	horde_panel.visible = false
	horde_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(horde_panel)


# ==================== NPC ====================
func _build_cat_panel() -> void:
	""""""
	cat_panel = Panel.new()
	cat_panel.position = Vector2(380, 220)
	cat_panel.size = Vector2(420, 370)
	cat_panel.self_modulate = Color(0.08, 0.06, 0.12, 0.96)
	cat_panel.visible = false
	cat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cat_panel)


func _show_cat_panel(cat_pos: Vector2) -> void:
	""" / """
	if GameManager.cat_dead:
		# 
		if popup_open and not cat_panel.visible:
			return
		for c in cat_panel.get_children():
			cat_panel.remove_child(c)
			c.queue_free()
		var title := Label.new()
		title.text = "猫咪已离去"
		title.position = Vector2(0, 14)
		title.size = Vector2(420, 36)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		cat_panel.add_child(title)
		var sep := ColorRect.new()
		sep.color = Color(0.3, 0.3, 0.3, 0.5)
		sep.position = Vector2(30, 56)
		sep.size = Vector2(360, 2)
		cat_panel.add_child(sep)
		var dead_label := Label.new()
		dead_label.text = "咪咪已经...不在了...\n\n它瘦小的身体蜷缩在角落里，\n再也不会动了。"
		dead_label.position = Vector2(30, 80)
		dead_label.size = Vector2(360, 140)
		dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dead_label.add_theme_font_size_override("font_size", 20)
		dead_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		cat_panel.add_child(dead_label)
		var close_btn := Button.new()
		close_btn.text = "关闭"
		close_btn.position = Vector2(135, 240)
		close_btn.size = Vector2(150, 40)
		close_btn.add_theme_font_size_override("font_size", 22)
		close_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		close_btn.pressed.connect(func():
			cat_panel.visible = false; popup_open = false; _update_mouse_mode()
		)
		cat_panel.add_child(close_btn)
		cat_panel.visible = true
		popup_open = true
		_update_mouse_mode()
		return
	if popup_open and not cat_panel.visible:
		return
	var main: Node = get_parent()
	if main and main.has_method("_set_dialog_locked"):
		main._set_dialog_locked(true)

	for c in cat_panel.get_children():
		cat_panel.remove_child(c)
		c.queue_free()

	# 
	var title := Label.new()
	title.text = "猫咪"
	title.position = Vector2(0, 14)
	title.size = Vector2(420, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	cat_panel.add_child(title)

	# 
	var mood_label := Label.new()
	mood_label.text = "心情: " + GameManager.get_cat_mood_label()
	mood_label.position = Vector2(0, 50)
	mood_label.size = Vector2(420, 26)
	mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mood_label.add_theme_font_size_override("font_size", 19)
	mood_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	cat_panel.add_child(mood_label)

	# 
	var sep := ColorRect.new()
	sep.position = Vector2(30, 82)
	sep.size = Vector2(360, 1)
	sep.color = Color(0.4, 0.35, 0.25, 0.6)
	cat_panel.add_child(sep)

	# 
	var ap_hint := Label.new()
	ap_hint.text = "剩余行动力: %d" % GameManager.get_actions_left()
	ap_hint.position = Vector2(0, 92)
	ap_hint.size = Vector2(420, 22)
	ap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_hint.add_theme_font_size_override("font_size", 16)
	ap_hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.45))
	cat_panel.add_child(ap_hint)

	# ===  ===
	var feed_btn: Button = Button.new()
	feed_btn.text = "喂食猫咪 (消耗1罐头)"
	feed_btn.position = Vector2(60, 128)
	feed_btn.size = Vector2(300, 48)
	feed_btn.add_theme_font_size_override("font_size", 21)
	feed_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	if GameManager.cat_fed_today:
		feed_btn.text = "喂食"
		feed_btn.disabled = true
		feed_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		feed_btn.pressed.connect(func():
			var result: String = GameManager.feed_cat()
			var dl: Label = cat_panel.get_node_or_null("CatDialogLabel") as Label
			if dl:
				dl.text = result
			mood_label.text = "心情: " + GameManager.get_cat_mood_label()
			ap_hint.text = "剩余行动力: %d" % GameManager.get_actions_left()
			if GameManager.cat_fed_today:
				feed_btn.text = "喂食"
				feed_btn.disabled = true
				feed_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		)
	cat_panel.add_child(feed_btn)

	# ===  ===
	var pet_btn: Button = Button.new()
	pet_btn.text = "抚摸猫咪 (消耗1行动点) [+10心情]"
	pet_btn.position = Vector2(60, 188)
	pet_btn.size = Vector2(300, 48)
	pet_btn.add_theme_font_size_override("font_size", 21)
	pet_btn.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	if GameManager.cat_petted_today:
		pet_btn.text = "抚摸"
		pet_btn.disabled = true
		pet_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		pet_btn.pressed.connect(func():
			var result: String = GameManager.pet_cat()
			var dl: Label = cat_panel.get_node_or_null("CatDialogLabel") as Label
			if dl:
				dl.text = result
			mood_label.text = "心情: " + GameManager.get_cat_mood_label()
			ap_hint.text = "行动力: %d" % GameManager.get_actions_left()
			if GameManager.cat_petted_today:
				pet_btn.text = "抚摸"
				pet_btn.disabled = true
				pet_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		)
	cat_panel.add_child(pet_btn)

	# 猫咪反馈文字
	var cat_dialog_label := Label.new()
	cat_dialog_label.name = "CatDialogLabel"
	cat_dialog_label.position = Vector2(30, 244)
	cat_dialog_label.size = Vector2(360, 44)
	cat_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_dialog_label.add_theme_font_size_override("font_size", 17)
	cat_dialog_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
	cat_panel.add_child(cat_dialog_label)

	# 
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(110, 308)
	close_btn.size = Vector2(200, 38)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		cat_panel.visible = false; popup_open = false; _update_mouse_mode()
		var main_close: Node = get_parent()
		if main_close and main_close.has_method("_set_dialog_locked"):
			main_close._set_dialog_locked(false)
	)
	cat_panel.add_child(close_btn)

	cat_panel.visible = true
	popup_open = true
	_update_mouse_mode()


var _cat_result_label: Label

func _show_cat_result(result_text: String) -> void:
	""""""
	# 
	if _cat_result_label and is_instance_valid(_cat_result_label):
		_cat_result_label.queue_free()

	_cat_result_label = Label.new()
	_cat_result_label.text = result_text
	_cat_result_label.position = Vector2(20, 246)
	_cat_result_label.size = Vector2(380, 44)
	_cat_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cat_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cat_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cat_result_label.add_theme_font_size_override("font_size", 15)
	_cat_result_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	cat_panel.add_child(_cat_result_label)


# ====================  ====================
func _build_sister_panel() -> void:
	""""""
	sister_panel = Panel.new()
	sister_panel.position = Vector2(360, 100)
	sister_panel.size = Vector2(500, 560)
	sister_panel.self_modulate = Color(0.08, 0.06, 0.12, 0.96)
	sister_panel.visible = false
	sister_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sister_panel)


func _close_sister_panel() -> void:
	""""""
	if is_instance_valid(sister_panel):
		sister_panel.visible = false
		for c in sister_panel.get_children():
			c.queue_free()
	popup_open = false
	_update_mouse_mode()


func _show_sister_panel(_sister_pos: Vector2) -> void:
	"""+"""
	if GameManager.sister_dead:
		# 
		if popup_open and not sister_panel.visible:
			return
		for c in sister_panel.get_children():
			sister_panel.remove_child(c)
			c.queue_free()
		var title := Label.new()
		title.text = "妹妹"
		title.position = Vector2(0, 14)
		title.size = Vector2(500, 36)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		sister_panel.add_child(title)
		var sep := ColorRect.new()
		sep.color = Color(0.3, 0.3, 0.3, 0.5)
		sep.position = Vector2(50, 56)
		sep.size = Vector2(400, 2)
		sister_panel.add_child(sep)
		var dead_label := Label.new()
		dead_label.text = "妹妹已经...不在了...\n\n她瘦小的身体蜷缩在角落里，\n再也不会动了。"
		dead_label.position = Vector2(50, 80)
		dead_label.size = Vector2(400, 140)
		dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dead_label.add_theme_font_size_override("font_size", 20)
		dead_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		sister_panel.add_child(dead_label)
		var close_btn := Button.new()
		close_btn.text = "关闭"
		close_btn.position = Vector2(175, 240)
		close_btn.size = Vector2(150, 40)
		close_btn.add_theme_font_size_override("font_size", 22)
		close_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		close_btn.pressed.connect(func():
			sister_panel.visible = false; popup_open = false; _update_mouse_mode()
		)
		sister_panel.add_child(close_btn)
		sister_panel.visible = true
		popup_open = true
		_update_mouse_mode()
		return
	if popup_open and not sister_panel.visible:
		return
	var main: Node = get_parent()
	if main and main.has_method("_set_dialog_locked"):
		main._set_dialog_locked(true)

	for c in sister_panel.get_children():
		sister_panel.remove_child(c)
		c.queue_free()

	# 
	var title := Label.new()
	title.text = "妹妹"
	title.position = Vector2(0, 14)
	title.size = Vector2(500, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.85))
	sister_panel.add_child(title)

	# 
	var status_label := Label.new()
	status_label.text = GameManager.get_sister_mood_label()
	status_label.position = Vector2(0, 50)
	status_label.size = Vector2(500, 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.8))
	status_label.name = "StatusLabel"
	sister_panel.add_child(status_label)

	# 
	var sep := ColorRect.new()
	sep.position = Vector2(30, 82)
	sep.size = Vector2(440, 1)
	sep.color = Color(0.4, 0.35, 0.25, 0.6)
	sister_panel.add_child(sep)

	# /
	var dialog_label := Label.new()
	dialog_label.name = "DialogLabel"
	dialog_label.position = Vector2(25, 95)
	dialog_label.size = Vector2(450, 80)
	dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_label.add_theme_font_size_override("font_size", 20)
	dialog_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	sister_panel.add_child(dialog_label)

	# 
	if GameManager.sister_saved:
		dialog_label.text = "外面越来越冷了...我好像病得更重了...."
	elif GameManager.sister_death_timer_active:
		dialog_label.text = "外面越来越冷了...我好像病得更重了...."
	elif GameManager.current_day >= 3:
		dialog_label.text = "外面越来越冷了...我好像病得更重了...."
	elif GameManager.current_day >= 2:
		dialog_label.text = "外面越来越冷了...我好像病得更重了...."
	else:
		dialog_label.text = "外面越来越冷了...我好像病得更重了...."

	# ===  ===
	var y_offset := 175
	if not GameManager.sister_quest_items.is_empty() and GameManager.sister_quest_count() > 0:
		var quest_label := Label.new()
		quest_label.name = "QuestLabel"
		quest_label.text = "妹妹想要: " + GameManager.get_sister_quest_label()
		quest_label.position = Vector2(25, y_offset)
		quest_label.size = Vector2(450, 30)
		quest_label.add_theme_font_size_override("font_size", 20)
		quest_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
		sister_panel.add_child(quest_label)
		y_offset += 30

	# ===  ===
	for i in range(GameManager.sister_quests_completed, GameManager.sister_quest_items.size()):
		var qid := GameManager.sister_quest_items[i]
		var qname: String = GameManager.ITEM_DATA.get(qid, {}).get("name", "???")
		var idx_deliver := GameManager.find_item(qid)
		if idx_deliver >= 0:
			var deliver_btn: Button = Button.new()
			deliver_btn.text = " %s" % qname
			deliver_btn.position = Vector2(60, y_offset)
			deliver_btn.size = Vector2(380, 36)
			deliver_btn.add_theme_font_size_override("font_size", 20)
			deliver_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			var item_id_final: String = qid
			deliver_btn.pressed.connect(func():
				var result := GameManager.complete_sister_gift(item_id_final)
				dialog_label.text = result
				status_label.text = GameManager.get_sister_mood_label()
				# 
				_show_sister_panel(_sister_pos)
			)
			sister_panel.add_child(deliver_btn)
			y_offset += 42

	y_offset = maxi(y_offset, 240)

	# ===  ===
	var ask_btn: Button = Button.new()
	ask_btn.text = "询问妹妹想要什么"
	ask_btn.position = Vector2(100, y_offset)
	ask_btn.size = Vector2(300, 44)
	ask_btn.add_theme_font_size_override("font_size", 20)
	ask_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
	ask_btn.pressed.connect(func():
		dialog_label.text = GameManager.ask_sister_for_quest()
		# 
		_show_sister_panel(_sister_pos)
	)
	sister_panel.add_child(ask_btn)
	y_offset += 52

	# ===  ===
	var gift_btn: Button = Button.new()
	gift_btn.text = "赠送物品"
	gift_btn.position = Vector2(100, y_offset)
	gift_btn.size = Vector2(300, 44)
	gift_btn.add_theme_font_size_override("font_size", 20)
	gift_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.65))
	if GameManager.sister_dead:
		gift_btn.text = "赠送物品"
		gift_btn.disabled = true
		gift_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		gift_btn.pressed.connect(func():
			_show_sister_gift_selector()
		)
	sister_panel.add_child(gift_btn)
	y_offset += 54

	# AI
	var ai_btn: Button = Button.new()
	ai_btn.text = "AI对话"
	ai_btn.position = Vector2(100, y_offset)
	ai_btn.size = Vector2(300, 44)
	ai_btn.add_theme_font_size_override("font_size", 20)
	ai_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.9))
	ai_btn.pressed.connect(func():
		_sister_ai_dialogue()
	)
	sister_panel.add_child(ai_btn)
	y_offset += 54

	# 
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(150, y_offset + 6)
	close_btn.size = Vector2(200, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	close_btn.pressed.connect(func():
		sister_panel.visible = false; popup_open = false; _update_mouse_mode()
		var main_close: Node = get_parent()
		if main_close and main_close.has_method("_set_dialog_locked"):
			main_close._set_dialog_locked(false)
	)
	sister_panel.add_child(close_btn)

	sister_panel.visible = true
	popup_open = true
	_update_mouse_mode()


func _sister_ai_dialogue() -> void:
	"""AI — NPC AI"""
	var npc_dict := {
		"name": "妹妹",
		"type": "survivor",
		"personality": "生病的小女孩，身体虚弱，但她很坚强，不想让你担心。",
		"speaking_style": "语气虚弱但直接。不用括号描述动作，直接说话。",
		"mood": GameManager.get_sister_mood_label(),
		"background": "和你一起在这个末世中求生。妹妹生病了，需要感冒药和草药膏来治疗。她大部分时间都躺在床上休息，偶尔会在房间里走动。她很懂事，不想给你添麻烦。",
		"secret": "妹妹其实知道自己病得很重，但她不想让你担心，所以总是说自己没事。她偷偷藏了一个布娃娃，那是妈妈留给她的最后一件东西。",
	}

	if not AIDialogue.is_ai_available():
		GameManager.popup_message.emit("[color=red]AI服务暂不可用，请配置API密钥[/color]", 3.0)
		return

	if GameManager.get_actions_left() < 1:
		GameManager.popup_message.emit("[color=red]行动力不足！[/color]", 2.0)
		return

	# 
	AIDialogue._request_pending = false

	# ===  ===
	for c in sister_panel.get_children():
		sister_panel.remove_child(c)
		c.queue_free()

	# 
	var title := Label.new()
	title.text = "AI对话 - 妹妹"
	title.position = Vector2(0, 14)
	title.size = Vector2(500, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.85))
	sister_panel.add_child(title)

	# 
	var sep := ColorRect.new()
	sep.position = Vector2(20, 50)
	sep.size = Vector2(460, 1)
	sep.color = Color(0.4, 0.35, 0.25, 0.6)
	sister_panel.add_child(sep)

	# === AI ===
	var reply_area := RichTextLabel.new()
	reply_area.name = "AIChatReply"
	reply_area.position = Vector2(20, 58)
	reply_area.size = Vector2(460, 260)
	reply_area.bbcode_enabled = true
	reply_area.add_theme_font_size_override("normal_font_size", 24)
	reply_area.add_theme_color_override("default_color", Color(0.9, 0.88, 0.8))
	reply_area.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply_area.scroll_active = true
	reply_area.selection_enabled = true
	reply_area.text = "[color=gray]...[/color]"
	sister_panel.add_child(reply_area)

	# 
	var status_label := Label.new()
	status_label.name = "AIChatStatus"
	status_label.position = Vector2(20, 325)
	status_label.size = Vector2(460, 26)
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	sister_panel.add_child(status_label)

	# 
	var input_edit := LineEdit.new()
	input_edit.name = "AIChatInput"
	input_edit.position = Vector2(20, 360)
	input_edit.size = Vector2(350, 40)
	input_edit.placeholder_text = "输入你的话，与妹妹对话吧..."
	input_edit.add_theme_font_size_override("font_size", 24)
	sister_panel.add_child(input_edit)

	# 
	var send_btn := Button.new()
	send_btn.text = "发送"
	send_btn.position = Vector2(380, 360)
	send_btn.size = Vector2(100, 40)
	send_btn.add_theme_font_size_override("font_size", 24)
	send_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	sister_panel.add_child(send_btn)

	# 
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(180, 445)
	back_btn.size = Vector2(140, 36)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	back_btn.pressed.connect(func():
		sister_panel.visible = false
		popup_open = false
		_show_sister_panel(Vector2.ZERO)
	)
	sister_panel.add_child(back_btn)

	# === lambda===
	var _reply_area: RichTextLabel = reply_area
	var _status_label: Label = status_label
	var _input_edit: LineEdit = input_edit

	input_edit.text_submitted.connect(func(text: String):
		if text.strip_edges() != "":
			_request_sister_ai_reply(npc_dict, text.strip_edges(), _reply_area, _status_label, _input_edit)
			input_edit.text = ""
	)
	send_btn.pressed.connect(func():
		var text: String = input_edit.text.strip_edges()
		if text != "":
			_request_sister_ai_reply(npc_dict, text, _reply_area, _status_label, _input_edit)
			input_edit.text = ""
	)

	input_edit.grab_focus()


func _request_sister_ai_reply(npc_dict: Dictionary, player_msg: String,
		reply_area: RichTextLabel, status_label: Label, input_edit: LineEdit) -> void:
	"""AI _request_ai_reply"""
	if not AIDialogue.is_ai_available():
		reply_area.text = "[color=red]AI服务暂不可用，请稍后再试[/color]"
		return

	# 
	if GameManager.sanity < 2.0:
		reply_area.text = "[color=red]精神不足，无法进行对话[/color]"
		return

	GameManager.modify_sanity(-2.0)

	# 
	reply_area.text = "[color=yellow]妹妹正在思考...—— [/color]"
	status_label.text = "AI正在思考..."
	input_edit.editable = false

	var _reply_area: RichTextLabel = reply_area
	var _status_label: Label = status_label
	var _input_edit: LineEdit = input_edit

	AIDialogue.ask_npc(npc_dict, player_msg, func(reply: String, success: bool, error_msg: String):
		if not is_instance_valid(_reply_area):
			return
		if success:
			var display_text := ""
			if player_msg.length() > 30:
				display_text += player_msg.substr(0, 28) + "..."
			else:
				display_text += player_msg
			display_text += "\n\n"
			display_text += "[color=#FF99CC][b][/b]: %s[/color]" % reply
			_reply_area.text = display_text
			_status_label.text = ""
		else:
			var err_display := "[color=red]AI"
			if error_msg != "":
				err_display += ": %s" % error_msg
			err_display += "[/color]\n\n[color=gray]"
			if error_msg.contains("") or error_msg.contains("") or error_msg.contains("CORS"):
				err_display += "AI\nAI"
			else:
				err_display += "API"
			err_display += "[/color]"
			_reply_area.text = err_display
			_status_label.text = ""
		_input_edit.editable = true
		_input_edit.grab_focus()
	)


func _show_sister_text_input() -> String:
	"""AI"""
	var vp := get_viewport().get_visible_rect()
	var popup := CanvasLayer.new()
	popup.name = "SisterTextInput"
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
	label.text = "输入你的问题"
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
	edit.text_submitted.connect(func(_t: String):
		result = edit.text.strip_edges()
		done = true
		popup.queue_free()
	)

	while not done:
		await get_tree().process_frame

	return result


func _show_sister_gift_selector() -> void:
	""""""
	# 
	for c in sister_panel.get_children():
		if c is Button or c is Label or c is ColorRect:
			if c.name != "DialogLabel" and c.name != "StatusLabel":
				c.queue_free()

	# 
	var all_items: Array[Dictionary] = []
	for item in GameManager.inventory:
		var info: Dictionary = GameManager.ITEM_DATA.get(item["id"], {})
		if not info.is_empty():
			all_items.append({"id": item["id"], "name": info["name"], "count": item.get("amount", 1)})

	if all_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "没有可用的物品..."
		empty_label.position = Vector2(100, 200)
		empty_label.size = Vector2(300, 30)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 20)
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		sister_panel.add_child(empty_label)
		return

	# 
	var want_label := Label.new()
	want_label.position = Vector2(25, 195)
	want_label.size = Vector2(450, 28)
	want_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	want_label.add_theme_font_size_override("font_size", 20)
	want_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.55))
	if not GameManager.sister_quest_items.is_empty() and GameManager.sister_quest_count() > 0:
		want_label.text = " " + GameManager.get_sister_quest_label()
	else:
		want_label.text = "想要物品..."
	sister_panel.add_child(want_label)

	# 
	var hint := Label.new()
	hint.text = "选择要给予的物品"
	hint.position = Vector2(25, 228)
	hint.size = Vector2(450, 26)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	sister_panel.add_child(hint)

	var y_offset := 260
	for i in mini(all_items.size(), 5):
		var item_data: Dictionary = all_items[i]
		var item_btn := Button.new()
		item_btn.text = "%s ×%d" % [item_data["name"], item_data["count"]]
		item_btn.position = Vector2(50, y_offset)
		item_btn.size = Vector2(400, 36)
		item_btn.add_theme_font_size_override("font_size", 20)
		item_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
		var item_id_final: String = item_data["id"]
		var dlg_label: Label = sister_panel.get_node_or_null("DialogLabel") as Label
		var status_lbl: Label = sister_panel.get_node_or_null("StatusLabel") as Label
		item_btn.pressed.connect(func():
			var result := GameManager.complete_sister_gift(item_id_final)
			if dlg_label:
				dlg_label.text = result
			if status_lbl:
				status_lbl.text = GameManager.get_sister_mood_label()
			# /
			for c in sister_panel.get_children():
				var c_name: String = (c as Node).name if c else ""
				if c is Button and c_name != "close_btn":
					c.queue_free()
				elif c is Label and c_name != "DialogLabel" and c_name != "StatusLabel":
					c.queue_free()
			# 
			var done_close: Button = Button.new()
			done_close.text = " "
			done_close.position = Vector2(150, 310)
			done_close.size = Vector2(200, 40)
			done_close.add_theme_font_size_override("font_size", 20)
			done_close.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			done_close.pressed.connect(func():
				sister_panel.visible = false; popup_open = false; _update_mouse_mode()
				var md: Node = get_parent()
				if md and md.has_method("_set_dialog_locked"):
					md._set_dialog_locked(false)
			)
			sister_panel.add_child(done_close)
		)
		sister_panel.add_child(item_btn)
		y_offset += 40

	# 
	var back_btn: Button = Button.new()
	back_btn.text = "↩ "
	back_btn.position = Vector2(150, y_offset + 6)
	back_btn.size = Vector2(200, 40)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.85))
	back_btn.pressed.connect(func():
		_show_sister_panel(Vector2.ZERO)
	)
	sister_panel.add_child(back_btn)


func _build_npc_interact_panel() -> void:
	npc_interact_panel = Panel.new()
	npc_interact_panel.position = Vector2(340, 160)
	npc_interact_panel.size = Vector2(580, 660)
	npc_interact_panel.self_modulate = Color(0.06, 0.05, 0.08, 0.96)
	npc_interact_panel.visible = false
	npc_interact_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(npc_interact_panel)


func _show_npc_interact_panel(npc_name: String, npc_pos: Vector2) -> void:
	"""NPC /  /  / """
	_npc_qte_mode = ""
	if popup_open and not npc_interact_panel.visible:
		return
	#  main.gd NPC
	var main: Node = get_parent()
	if main and main.has_method("_set_dialog_locked"):
		main._set_dialog_locked(true)
	for c in npc_interact_panel.get_children():
		npc_interact_panel.remove_child(c)
		c.queue_free()

	var npc := GameManager.get_room_npc_by_name(npc_name)
	if npc.is_empty():
		return
	var ntype: String = npc.get("type", "survivor")

	var title := Label.new()
	title.text = npc_name
	title.position = Vector2(0, 14)
	title.size = Vector2(540, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	match ntype:
		"survivor": title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		"imposter": title.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
		"mutated": title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_: title.add_theme_color_override("font_color", Color.WHITE)
	npc_interact_panel.add_child(title)

	# 
	var info_label := Label.new()
	info_label.position = Vector2(20, 54)
	info_label.size = Vector2(500, 26)
	var type_text: String = ""
	match ntype:
		"survivor": type_text = "[幸存者]"
		"imposter": type_text = "[伪装者]"
		"mutated": type_text = "[变异]"
		_: type_text = "[未知]"
	var extorted_text: String = ""
	if npc.get("was_extorted", false):
		extorted_text = "  [被勒索] 将在第"
		if npc.has("leave_day"):
			extorted_text += "  %d" % npc["leave_day"]
	info_label.text = "%s   |   房间: %d/%d人%s" % [type_text, GameManager.room_npcs.size(), GameManager.MAX_ROOM_NPCS, extorted_text]
	info_label.add_theme_font_size_override("font_size", 17)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	npc_interact_panel.add_child(info_label)

	# ===  ===
	var sep := ColorRect.new()
	sep.position = Vector2(20, 86)
	sep.size = Vector2(500, 2)
	sep.color = Color(0.3, 0.3, 0.35, 0.6)
	npc_interact_panel.add_child(sep)

	# === 32 +  ===
	var btn_w := 165
	var btn_h := 44
	var col1_x := 30
	var col2_x := 205
	var col3_x := 380
	var row1_y := 100
	var row2_y := 152
	var gap := 8

	# AI
	var ai_available: bool = AIDialogue.is_ai_available()

	# 1)  → 
	var talk_btn: Button = Button.new()
	talk_btn.text = "杀害"
	talk_btn.position = Vector2(col1_x, row1_y)
	talk_btn.size = Vector2(btn_w, btn_h)
	talk_btn.add_theme_font_size_override("font_size", 19)
	talk_btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	talk_btn.tooltip_text = "杀害该NPC"
	talk_btn.pressed.connect(func(): _kill_shelter_npc(npc_name))
	npc_interact_panel.add_child(talk_btn)

	# 2)  → QTE
	var check_btn: Button = Button.new()
	check_btn.text = "检查（1行动点）"
	check_btn.position = Vector2(col2_x, row1_y)
	check_btn.size = Vector2(btn_w, btn_h)
	check_btn.add_theme_font_size_override("font_size", 19)
	check_btn.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	check_btn.tooltip_text = "NPC [QTE]"
	check_btn.pressed.connect(func(): _npc_start_qte("check", npc_name))
	npc_interact_panel.add_child(check_btn)

	# 2.5) AI → 
	var ai_talk_btn: Button = Button.new()
	ai_talk_btn.text = "AI对话"
	ai_talk_btn.position = Vector2(col3_x, row1_y)
	ai_talk_btn.size = Vector2(btn_w, btn_h)
	ai_talk_btn.add_theme_font_size_override("font_size", 19)
	if ai_available:
		ai_talk_btn.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
		ai_talk_btn.tooltip_text = "与NPC进行AI对话"
	else:
		ai_talk_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		ai_talk_btn.tooltip_text = "AI服务暂不可用"
	ai_talk_btn.pressed.connect(func(): _show_ai_chat_panel(npc_name))
	npc_interact_panel.add_child(ai_talk_btn)

	# 3) 询问 -> 提问
	var ask_btn: Button = Button.new()
	ask_btn.text = "提问"
	ask_btn.position = Vector2(col2_x, row2_y)
	ask_btn.size = Vector2(btn_w, btn_h)
	ask_btn.add_theme_font_size_override("font_size", 19)
	ask_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	ask_btn.tooltip_text = "询问NPC"
	var has_backstory: bool = not npc.get("backstory", []).is_empty()
	ask_btn.disabled = not has_backstory
	if not has_backstory:
		ask_btn.tooltip_text = "该NPC没有可询问的内容"
	ask_btn.pressed.connect(func(): _npc_show_questions(npc_name))
	npc_interact_panel.add_child(ask_btn)

	# 勒索 → QTE
	var extort_btn: Button = Button.new()
	extort_btn.text = "勒索"
	extort_btn.position = Vector2(col1_x, row2_y)
	extort_btn.size = Vector2(btn_w, btn_h)
	extort_btn.add_theme_font_size_override("font_size", 20)
	if npc.get("was_extorted", false):
		extort_btn.text = "已勒索"
		extort_btn.disabled = true
		extort_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		extort_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
		extort_btn.tooltip_text = "勒索NPC [QTE]"
		extort_btn.pressed.connect(func(): _npc_start_qte("extort", npc_name))
	npc_interact_panel.add_child(extort_btn)

	# 驱逐
	var kick_btn: Button = Button.new()
	kick_btn.text = "驱逐"
	kick_btn.position = Vector2(col3_x, row2_y)
	kick_btn.size = Vector2(btn_w, btn_h)
	kick_btn.add_theme_font_size_override("font_size", 20)
	kick_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	kick_btn.tooltip_text = "驱逐NPC"
	kick_btn.pressed.connect(func(): _npc_action_kick(npc_name))
	npc_interact_panel.add_child(kick_btn)

	# 关闭
	var close_btn: Button = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(180, 204)
	close_btn.size = Vector2(180, 36)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(func():
		npc_interact_panel.visible = false; popup_open = false; _update_mouse_mode()
		# 
		var main_close: Node = get_parent()
		if main_close and main_close.has_method("_set_dialog_locked"):
			main_close._set_dialog_locked(false)
	)
	npc_interact_panel.add_child(close_btn)

	# 
	var hint := Label.new()
	hint.text = "剩余行动力: %d" % GameManager.get_actions_left()
	hint.position = Vector2(0, 280)
	hint.size = Vector2(540, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	npc_interact_panel.add_child(hint)

	npc_interact_panel.visible = true
	popup_open = true
	_update_mouse_mode()


# ==================== NPC  ====================
func _npc_show_questions(npc_name: String) -> void:
	"""3"""
	for c in npc_interact_panel.get_children():
		npc_interact_panel.remove_child(c)
		c.queue_free()

	var npc := GameManager.get_room_npc_by_name(npc_name)
	var backstory: Array = npc.get("backstory", [])
	var asked: int = npc.get("asked_count", 0)

	# 
	var title := Label.new()
	title.text = "AI对话 - 妹妹" + npc_name + "  ( %d/3)" % min(asked, backstory.size())
	title.position = Vector2(0, 14)
	title.size = Vector2(540, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	npc_interact_panel.add_child(title)

	# 
	var sep := ColorRect.new()
	sep.position = Vector2(20, 52)
	sep.size = Vector2(500, 1)
	sep.color = Color(0.3, 0.35, 0.4, 0.5)
	npc_interact_panel.add_child(sep)

	var y := 70
	var btn_w := 500
	var btn_h := 44

	for i in range(backstory.size()):
		var qa: Dictionary = backstory[i]
		var q_text: String = qa.get("q", "???")
		var locked: bool = i > asked

		var q_btn: Button = Button.new()
		if locked:
			q_btn.text = "???"
		else:
			q_btn.text = "%d. %s" % [i + 1, q_text]
		q_btn.position = Vector2(20, y)
		q_btn.size = Vector2(btn_w, btn_h)
		q_btn.add_theme_font_size_override("font_size", 18)
		q_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		q_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if locked:
			q_btn.disabled = true
			q_btn.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
		else:
			var qi: int = i
			q_btn.pressed.connect(func():
				var answer: String = GameManager.ask_npc_question(npc_name, qi)
				_npc_show_answer(answer, npc_name)
			)
		npc_interact_panel.add_child(q_btn)
		y += 50

	if asked >= backstory.size() and not backstory.is_empty():
		var done_label := Label.new()
		done_label.text = "没有更多问题了"
		done_label.position = Vector2(0, y + 6)
		done_label.size = Vector2(540, 24)
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_label.add_theme_font_size_override("font_size", 17)
		done_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		npc_interact_panel.add_child(done_label)

	# 
	var back_btn: Button = Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(180, 270)
	back_btn.size = Vector2(180, 38)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(func(): _show_npc_interact_panel(npc_name, Vector2.ZERO))
	npc_interact_panel.add_child(back_btn)


func _npc_show_answer(answer: String, npc_name: String) -> void:
	"""NPC"""
	for c in npc_interact_panel.get_children():
		npc_interact_panel.remove_child(c)
		c.queue_free()

	# 2%
	GameManager.modify_sanity(-2.0)

	var label := RichTextLabel.new()
	label.text = answer
	label.position = Vector2(20, 20)
	label.size = Vector2(500, 220)
	label.fit_content = true
	label.bbcode_enabled = true
	# RichTextLabel
	npc_interact_panel.add_child(label)

	var continue_btn: Button = Button.new()
	continue_btn.text = "← "
	continue_btn.position = Vector2(170, 260)
	continue_btn.size = Vector2(200, 38)
	continue_btn.add_theme_font_size_override("font_size", 19)
	continue_btn.pressed.connect(func(): _npc_show_questions(npc_name))
	npc_interact_panel.add_child(continue_btn)


# ==================== NPC QTE  ====================
func _npc_start_qte(mode: String, npc_name: String) -> void:
	"""NPCQTE: check  extort"""
	if mode == "check" and GameManager.get_actions_left() < 1:
		_show_popup("行动力不足，检查NPC需要1点行动力")
		return

	_npc_qte_mode = mode
	_npc_qte_npc_name = npc_name
	_npc_qte_result_emitted = false

	# 
	match mode:
		"check":
			_npc_qte_difficulty = "normal"
			_npc_qte_speed = 504.0
		"extort":
			_npc_qte_difficulty = "hard"
			_npc_qte_speed = 588.0

	_npc_qte_pointer_pos = 50.0
	_npc_qte_direction = 1
	_npc_draw_qte()


func _npc_draw_qte() -> void:
	""" npc_interact_panel QTE"""
	for c in npc_interact_panel.get_children():
		npc_interact_panel.remove_child(c)
		c.queue_free()

	var mode_text: String = "" if _npc_qte_mode == "check" else ""
	var title := Label.new()
	title.text = "=== %s ===" % mode_text
	title.position = Vector2(0, 16)
	title.size = Vector2(540, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	npc_interact_panel.add_child(title)

	var hint := Label.new()
	var mode_label: String = ""
	match _npc_qte_mode:
		"check": mode_label = "检查"
		"extort": mode_label = "勒索"
		_: mode_label = _npc_qte_mode
	hint.text = " [%s]" % mode_label
	hint.position = Vector2(0, 52)
	hint.size = Vector2(540, 24)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	npc_interact_panel.add_child(hint)

	# === QTE  ===
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(50, 100)
	bar_bg.size = Vector2(440, 50)
	bar_bg.color = Color(0.08, 0.08, 0.1, 0.95)
	npc_interact_panel.add_child(bar_bg)

	#  ():  220  320
	var success_zone := ColorRect.new()
	success_zone.position = Vector2(235, 102)
	success_zone.size = Vector2(70, 46)
	success_zone.color = Color(0.0, 0.65, 0.0, 0.5)
	npc_interact_panel.add_child(success_zone)

	#  ()
	var perfect_zone := ColorRect.new()
	perfect_zone.position = Vector2(255, 102)
	perfect_zone.size = Vector2(30, 46)
	perfect_zone.color = Color(0.0, 0.9, 0.0, 0.4)
	npc_interact_panel.add_child(perfect_zone)

	# 
	var fail_left := Label.new()
	fail_left.text = "失败"
	fail_left.position = Vector2(80, 120)
	fail_left.size = Vector2(60, 20)
	fail_left.add_theme_font_size_override("font_size", 15)
	fail_left.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
	npc_interact_panel.add_child(fail_left)

	var success_label := Label.new()
	success_label.text = "成功"
	success_label.position = Vector2(245, 115)
	success_label.size = Vector2(60, 20)
	success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	success_label.add_theme_font_size_override("font_size", 15)
	success_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	npc_interact_panel.add_child(success_label)

	var fail_right := Label.new()
	fail_right.text = "失败"
	fail_right.position = Vector2(400, 120)
	fail_right.size = Vector2(60, 20)
	fail_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fail_right.add_theme_font_size_override("font_size", 15)
	fail_right.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
	npc_interact_panel.add_child(fail_right)

	# 
	var pointer := ColorRect.new()
	pointer.position = Vector2(_npc_qte_pointer_pos + 50, 98)
	pointer.size = Vector2(4, 54)
	pointer.color = Color(1.0, 0.8, 0.2)
	pointer.name = "_qte_pointer"
	npc_interact_panel.add_child(pointer)

	# 
	var result_label := Label.new()
	result_label.position = Vector2(0, 170)
	result_label.size = Vector2(540, 30)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 22)
	result_label.text = "结果"
	result_label.name = "_qte_result"
	npc_interact_panel.add_child(result_label)


func _process(delta: float) -> void:
	#  Engine.time_scale GameManager
	var target_scale := 4.0 if is_speed_5x else 1.0
	if Engine.time_scale != target_scale:
		Engine.time_scale = target_scale

	# NPC QTE 
	if _npc_qte_mode != "" and not _npc_qte_result_emitted:
		_npc_qte_pointer_pos += _npc_qte_speed * delta * _npc_qte_direction
		if _npc_qte_pointer_pos >= 440:
			_npc_qte_pointer_pos = 440
			_npc_qte_direction = -1
		elif _npc_qte_pointer_pos <= 0:
			_npc_qte_pointer_pos = 0
			_npc_qte_direction = 1
		# 
		var ptr := npc_interact_panel.get_node_or_null("_qte_pointer")
		if ptr is ColorRect:
			ptr.position.x = _npc_qte_pointer_pos + 50


func _npc_qte_check_result() -> void:
	"""QTE"""
	if _npc_qte_mode == "" or _npc_qte_result_emitted:
		return
	_npc_qte_result_emitted = true

	var result_label := npc_interact_panel.get_node_or_null("_qte_result") as Label
	var success: bool = false
	var perfect: bool = false

	# pos(0~440)x=50
	# x: 235~305 → : 185~255
	# x: 255~285 → : 205~235
	var ptr_center := _npc_qte_pointer_pos + 2.0
	if ptr_center >= 185 and ptr_center <= 255:
		success = true
		# : 205-235
		if ptr_center >= 205 and ptr_center <= 235:
			perfect = true

	if perfect:
		if is_instance_valid(result_label):
			result_label.text = "暴击!"
			result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	elif success:
		if is_instance_valid(result_label):
			result_label.text = "命中!"
			result_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		if is_instance_valid(result_label):
			result_label.text = "未命中..."
			result_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	# 
	get_tree().create_timer(1.2).timeout.connect(func(): _npc_qte_handle_result(success))


func _npc_qte_handle_result(success: bool) -> void:
	"""QTENPC"""
	var mode := _npc_qte_mode
	var npc_name := _npc_qte_npc_name
	_npc_qte_mode = ""

	match mode:
		"check":
			_process_npc_qte_check_result(success, npc_name)
		"extort":
			_npc_qte_extort_result(success, npc_name)


func _process_npc_qte_check_result(success: bool, npc_name: String) -> void:
	"""QTE检查结果处理"""
	GameManager.consume_actions(1)
	npc_interact_panel.visible = false
	popup_open = false
	_update_mouse_mode()
	# 解锁对话
	var main_chk: Node = get_parent()
	if main_chk and main_chk.has_method("_set_dialog_locked"):
		main_chk._set_dialog_locked(false)

	if not success:
		_show_popup("[color=yellow]检查失败...\n%s警惕地后退了一步。\n你没看出什么异常。[/color]" % npc_name)
		return

	var result: int = GameManager.check_npc_mutation(npc_name)
	match result:
		0:
			_show_popup("[color=green]仔细检查完毕。\n%s看起来一切正常。\n瞳孔、呼吸、肤色均无异样。[/color]" % npc_name)
		1:
			if randf() < 0.7:
				_show_popup("[color=yellow]%s有些不对劲...\n[color=yellow]TA的瞳孔似乎有一瞬间变色了，但不确定是不是光线问题。[/color]" % npc_name)
			else:
				_show_popup("[color=orange]检查结果可疑。\n%s的行为和眼神有些异常...\n[color=yellow]TA可能是隐藏感染者！[/color]" % npc_name)
		2:
			_show_popup("[color=red]确认了！\n%s已经变异！\nTA的皮肤下有什么东西在蠕动...\n[color=red]快离开TA！[/color]" % npc_name)
		_:
			_show_popup("[color=gray]检查结果未知...\n%s的状态无法判断。[/color]" % npc_name)


func _npc_show_vague_hint(npc_name: String) -> void:
	var hints := [
		"[color=yellow]%s的瞳孔似乎有一瞬间变成了灰色...\n也许是光线问题？你不太确定。[/color]" % npc_name,
		"[color=yellow]%s的体温偏低...你的手碰到TA时感觉一阵凉意。\nTA笑了笑说只是有点冷。[/color]" % npc_name,
		"[color=yellow]%s总是在你背后盯着你看。\n每次你回头，TA都立刻移开视线。[/color]" % npc_name,
		"[color=yellow]你闻到%s身上有一股淡淡的腐臭味...\nTA解释说是在外面弄脏了衣服。[/color]" % npc_name,
		"[color=yellow]%s说昨晚做了很奇怪的梦。\n梦里的TA在吃生肉，醒来后满嘴都是铁锈味。[/color]" % npc_name,
		"[color=yellow]%s的嘴角偶尔会不受控制地抽搐一下。\nTA似乎自己都没有注意到。[/color]" % npc_name,
		"[color=yellow]%s房间里的灯半夜亮了好几次。\nTA说失眠，但你注意到TA的影子形状有些奇怪。[/color]" % npc_name,
		"[color=yellow]%s不再吃东西了。\nTA说没胃口，但你看得出来...TA在看着你的手臂。[/color]" % npc_name,
	]
	_show_popup(hints.pick_random())


func _npc_qte_extort_result(success: bool, npc_name: String) -> void:
	"""QTE"""
	npc_interact_panel.visible = false
	popup_open = false
	_update_mouse_mode()
	# 
	var main_ext: Node = get_parent()
	if main_ext and main_ext.has_method("_set_dialog_locked"):
		main_ext._set_dialog_locked(false)

	var msg: String = GameManager.extort_room_npc(npc_name, success)
	_show_popup(msg)


# ==================== NPC  ====================
func _npc_action_kick(npc_name: String) -> void:
	"""驱逐NPC离开避难所"""
	GameManager.remove_room_npc(npc_name)
	npc_interact_panel.visible = false; popup_open = false; _update_mouse_mode()
	# 解锁对话框
	var main_kick: Node = get_parent()
	if main_kick and main_kick.has_method("_set_dialog_locked"):
		main_kick._set_dialog_locked(false)
	_show_popup("[color=yellow]%s被驱逐了。\nTA收拾好行李，默默离开了避难所...\n门在TA身后关上了。[/color]" % npc_name)
	npc_spawned.emit({"name": "_refresh"})


# ==================== NPC  ====================
func _kill_shelter_npc(npc_name: String) -> void:
	"""安全屋中杀害收留的NPC"""
	var npc := GameManager.get_room_npc_by_name(npc_name)
	if npc.is_empty():
		return
	
	npc_interact_panel.visible = false
	popup_open = false
	_update_mouse_mode()
	
	# QTE（"你已经无法回头了"已集成到QTE面板内）
	var success: bool = await _run_inline_qte("击杀%s —— [空格键确认]" % npc_name)
	
	if success:
		GameManager.killed_npcs.append(npc_name)
		GameManager.modify_morality(-20, "杀死了 %s" % npc_name)
		_show_popup("[color=red]%s被你杀死了...[/color]" % npc_name)
		GameManager.remove_room_npc(npc_name)
		npc_spawned.emit({"name": "_refresh"})
	else:
		_show_popup("[color=yellow]%s躲开了你的攻击！\n%s愤怒地看着你...[/color]" % [npc_name, npc_name])
		GameManager.modify_morality(-5, "攻击了 %s " % npc_name)
	
	# 
	var main_node: Node = get_parent()
	if main_node and main_node.has_method("_set_dialog_locked"):
		main_node._set_dialog_locked(false)


func _run_inline_qte(title: String) -> bool:
	"""内联QTE小游戏（杀害NPC用）
	返回: true=成功, false=失败"""
	var vp_size := get_viewport().get_visible_rect().size
	var bar_w := 480.0
	var bar_h := 40.0
	var bar_x := (vp_size.x - bar_w) / 2.0
	var bar_y := vp_size.y * 0.6

	# QTE UI
	var qte_layer := Control.new()
	qte_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	qte_layer.position = Vector2(0, 0)
	qte_layer.size = vp_size
	add_child(qte_layer)

	# 全屏暗色遮罩
	var dark_bg := ColorRect.new()
	dark_bg.color = Color(0, 0, 0, 0.6)
	dark_bg.size = vp_size
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	qte_layer.add_child(dark_bg)

	# 标题 — 居中在上方
	# 红色警告文字
	var warn_lbl := Label.new()
	warn_lbl.text = "你已经无法回头了。"
	warn_lbl.position = Vector2(bar_x, bar_y - 80)
	warn_lbl.size = Vector2(bar_w, 30)
	warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_lbl.add_theme_font_size_override("font_size", 22)
	warn_lbl.add_theme_color_override("font_color", Color.RED)
	qte_layer.add_child(warn_lbl)
	# 标题
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.position = Vector2(bar_x, bar_y - 50)
	title_lbl.size = Vector2(bar_w, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	qte_layer.add_child(title_lbl)

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(bar_x, bar_y)
	bar_bg.size = Vector2(bar_w, bar_h)
	bar_bg.color = Color(0.15, 0.08, 0.08, 0.95)
	qte_layer.add_child(bar_bg)

	var zone_w := 24.0
	var zone_center: float = randf_range(zone_w, bar_w - zone_w)
	var good_zone := ColorRect.new()
	good_zone.position = Vector2(bar_x + zone_center - zone_w / 2.0, bar_y)
	good_zone.size = Vector2(zone_w, bar_h)
	good_zone.color = Color(0.15, 0.7, 0.2)
	qte_layer.add_child(good_zone)

	var slider_w := 12.0
	var slider := ColorRect.new()
	slider.position = Vector2(bar_x, bar_y - 2)
	slider.size = Vector2(slider_w, bar_h + 4)
	slider.color = Color(1.0, 0.2, 0.1)
	qte_layer.add_child(slider)

	var hint_lbl := Label.new()
	hint_lbl.text = "[ 空格键攻击 ]"
	hint_lbl.position = Vector2(bar_x, bar_y + bar_h + 15)
	hint_lbl.size = Vector2(bar_w, 30)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_font_size_override("font_size", 20)
	hint_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	qte_layer.add_child(hint_lbl)

	var speed := 560.0
	var direction := 1.0
	var slider_x := 0.0
	var done := false
	var success := false

	while not done:
		await get_tree().process_frame
		slider_x += speed * direction * 0.016

		if slider_x >= bar_w - slider_w:
			slider_x = bar_w - slider_w
			direction = -1.0
		elif slider_x <= 0:
			slider_x = 0
			direction = 1.0

		slider.position.x = bar_x + slider_x

		if Input.is_key_pressed(KEY_SPACE):
			var slider_center := slider_x + slider_w / 2.0
			var diff: float = abs(slider_center - zone_center)
			success = diff <= zone_w / 2.0

			if success:
				slider.color = Color(0.2, 1.0, 0.2)
				hint_lbl.text = "命中！"
			else:
				slider.color = Color(0.4, 0.4, 0.4)
				hint_lbl.text = "未命中..."

			await get_tree().create_timer(0.8).timeout
			done = true

	qte_layer.queue_free()
	return success


func _npc_show_talk(npc_name: String) -> void:
	"""-2AP/-2"""
	for c in npc_interact_panel.get_children():
		npc_interact_panel.remove_child(c)
		c.queue_free()

	var npc := GameManager.get_room_npc_by_name(npc_name)
	if npc.is_empty():
		return

	# 
	var title := Label.new()
	title.text = "与 %s 对话 " % npc_name
	title.position = Vector2(0, 10)
	title.size = Vector2(540, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	npc_interact_panel.add_child(title)

	# 
	var ap_label := Label.new()
	ap_label.name = "DialogueApLabel"
	ap_label.text = "行动力: %d | 精神: 0 (每次对话 -2AP -2精神)" % GameManager.get_actions_left()
	ap_label.position = Vector2(0, 44)
	ap_label.size = Vector2(580, 28)
	ap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_label.add_theme_font_size_override("font_size", 24)
	ap_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45))
	npc_interact_panel.add_child(ap_label)

	# 
	var sep := ColorRect.new()
	sep.position = Vector2(20, 80)
	sep.size = Vector2(540, 1)
	sep.color = Color(0.3, 0.35, 0.4, 0.5)
	npc_interact_panel.add_child(sep)

	# 
	var ntype: String = npc.get("type", "survivor")
	_dialogue_ap_spent = 0
	var topic: Dictionary = GameManager.get_npc_random_topic(ntype)
	if topic.is_empty():
		_show_fallback_talk(npc, npc_name)
		return

	var intro_text: String = topic.get("intro", "") % npc_name
	var intro_lbl := Label.new()
	intro_lbl.text = intro_text
	intro_lbl.position = Vector2(20, 94)
	intro_lbl.size = Vector2(540, 70)
	intro_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_lbl.add_theme_font_size_override("font_size", 24)
	intro_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.75))
	npc_interact_panel.add_child(intro_lbl)

	var reply_area := Label.new()
	reply_area.name = "DialogueReply"
	reply_area.text = ""
	reply_area.position = Vector2(20, 172)
	reply_area.size = Vector2(540, 80)
	reply_area.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply_area.add_theme_font_size_override("font_size", 24)
	reply_area.add_theme_color_override("font_color", Color(0.75, 0.82, 0.9))
	npc_interact_panel.add_child(reply_area)

	var options: Array = topic.get("options", [])
	var btn_start_y := 262
	var idx := 0
	for opt in options:
		var opt_data: Dictionary = opt as Dictionary
		var opt_btn: Button = Button.new()
		opt_btn.text = opt_data.get("text", "")
		opt_btn.position = Vector2(30, btn_start_y + idx * 54)
		opt_btn.size = Vector2(520, 46)
		opt_btn.add_theme_font_size_override("font_size", 24)
		opt_btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		var captured_btn: Button = opt_btn
		opt_btn.pressed.connect(func(): _on_dialogue_option_selected(
			npc_name, ntype, opt_data, reply_area, ap_label, captured_btn
		))
		npc_interact_panel.add_child(opt_btn)
		idx += 1

	var back_btn: Button = Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(170, btn_start_y + idx * 54 + 10)
	back_btn.size = Vector2(240, 42)
	back_btn.add_theme_font_size_override("font_size", 24)
	back_btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6))
	back_btn.pressed.connect(func(): _show_npc_interact_panel(npc_name, Vector2.ZERO))
	npc_interact_panel.add_child(back_btn)


func _on_dialogue_option_selected(npc_name: String, ntype: String,
		opt_data: Dictionary, reply_area: Label, ap_label: Label, clicked_btn: Button) -> void:
	if GameManager.sanity < 2.0:
		reply_area.text = "[color=red]精神不足，无法对话[/color]"
		return
	GameManager.modify_sanity(-2.0)  # 消耗精神
	var moral_delta: int = opt_data.get("morality_delta", 0)
	if moral_delta != 0:
		GameManager.modify_morality(moral_delta, "")
	var reply: String = opt_data.get("reply", "...")
	reply_area.text = "%s: %s" % [npc_name, reply]
	ap_label.text = "行动点剩余: %d | 已对话: %d (每次 -2AP -2精神)" % [
		GameManager.get_actions_left(), _dialogue_ap_spent]
	clicked_btn.disabled = true
	clicked_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	if moral_delta > 0:
		reply_area.text += "\n[color=gold][+ %d][/color]" % moral_delta
	elif moral_delta < 0:
		reply_area.text += "\n[color=red][ %d][/color]" % moral_delta


func _show_fallback_talk(npc: Dictionary, npc_name: String) -> void:
	# 
	var talk_text: String = GameManager.talk_to_room_npc(npc)
	var content := Label.new()
	content.text = talk_text
	content.position = Vector2(20, 20)
	content.size = Vector2(500, 140)
	content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_font_size_override("font_size", 18)
	content.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	npc_interact_panel.add_child(content)
	var back_btn: Button = Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(170, 220)
	back_btn.size = Vector2(200, 38)
	back_btn.add_theme_font_size_override("font_size", 19)
	back_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	back_btn.pressed.connect(func(): _show_npc_interact_panel(npc_name, Vector2.ZERO))
	npc_interact_panel.add_child(back_btn)


func start_zombie_horde_qte(difficulty: String, total_rounds: int) -> int:
	GameManager.is_horde_qte_active = true
	var wins: int = 0
	for round_idx in range(total_rounds):
		if GameManager.game_over:
			GameManager.is_horde_qte_active = false
			horde_panel.visible = false
			_update_mouse_mode()
			return wins
		var win: bool = await _run_horde_qte_round(difficulty, round_idx + 1, total_rounds)
		if win:
			wins += 1
	GameManager.is_horde_qte_active = false
	horde_panel.visible = false
	_update_mouse_mode()
	return wins


func _run_horde_qte_round(difficulty: String, round_num: int, total: int) -> bool:
	for c in horde_panel.get_children():
		c.queue_free()

	var speed: float
	var zone_width: float
	var perfect_width: float
	match difficulty:
		"easy":
			speed = 180.0; zone_width = 80.0; perfect_width = 28.0
		"normal":
			speed = 280.0; zone_width = 55.0; perfect_width = 18.0
		"hard":
			speed = 400.0; zone_width = 35.0; perfect_width = 10.0
		_:
			speed = 280.0; zone_width = 55.0; perfect_width = 18.0

	var player_dmg: int = GameManager.get_total_damage()
	if player_dmg > 0:
		zone_width += player_dmg * 0.5

	var helpers: int = GameManager.get_combat_npcs()
	speed = maxf(100.0, speed - helpers * 20.0)
	zone_width = minf(120.0, zone_width + helpers * 8.0)

	# ======  ======
	var title := Label.new()
	title.text = "[color=red]QTE判定结果[/color]"
	title.position = Vector2(0, 8)
	title.size = Vector2(600, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	horde_panel.add_child(title)

	var round_label := Label.new()
	round_label.text = "第 %d / %d 回合   Lv.%d" % [round_num, total, GameManager.zombie_level]
	round_label.position = Vector2(0, 40)
	round_label.size = Vector2(600, 22)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 21)
	round_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	horde_panel.add_child(round_label)

	var desc_texts: Array[String] = [
		"...",
		"",
		"",
	]
	var desc_label := Label.new()
	desc_label.text = desc_texts[clampi(round_num - 1, 0, desc_texts.size() - 1)]
	desc_label.position = Vector2(0, 68)
	desc_label.size = Vector2(600, 20)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	horde_panel.add_child(desc_label)

	# ====== QTE  () ======
	var bar_x: float = 50.0
	var bar_y: float = 110.0
	var bar_w: float = 500.0
	var bar_h: float = 40.0

	# 
	var bg_rect: ColorRect = ColorRect.new()
	bg_rect.position = Vector2(bar_x, bar_y)
	bg_rect.size = Vector2(bar_w, bar_h)
	bg_rect.color = Color(0.12, 0.10, 0.08, 0.95)
	# 
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	bg_style.border_color = Color(0.4, 0.35, 0.3, 0.9)
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(4)
	var bg_panel: Panel = Panel.new()
	bg_panel.position = Vector2(bar_x, bar_y)
	bg_panel.size = Vector2(bar_w, bar_h)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	horde_panel.add_child(bg_panel)

	# 
	var target_center: float = randf_range(zone_width, bar_w - zone_width)
	var target_panel: Panel = Panel.new()
	var target_style: StyleBoxFlat = StyleBoxFlat.new()
	target_style.bg_color = Color(0.15, 0.65, 0.2, 0.6)
	target_style.border_color = Color(0.3, 0.9, 0.35, 0.85)
	target_style.set_border_width_all(1)
	target_style.set_corner_radius_all(3)
	target_panel.add_theme_stylebox_override("panel", target_style)
	target_panel.position = Vector2(bar_x + target_center - zone_width / 2.0, bar_y + 2)
	target_panel.size = Vector2(zone_width, bar_h - 4)
	horde_panel.add_child(target_panel)

	# 
	var perf_panel: Panel = Panel.new()
	var perf_style: StyleBoxFlat = StyleBoxFlat.new()
	perf_style.bg_color = Color(0.2, 1.0, 0.25, 0.65)
	perf_style.border_color = Color(0.6, 1.0, 0.5, 0.95)
	perf_style.set_border_width_all(1)
	perf_style.set_corner_radius_all(2)
	perf_panel.add_theme_stylebox_override("panel", perf_style)
	perf_panel.position = Vector2(bar_x + target_center - perfect_width / 2.0, bar_y + 6)
	perf_panel.size = Vector2(perfect_width, bar_h - 12)
	horde_panel.add_child(perf_panel)

	# 
	var pointer: Panel = Panel.new()
	var ptr_style: StyleBoxFlat = StyleBoxFlat.new()
	ptr_style.bg_color = Color(0.95, 0.2, 0.12, 0.95)
	ptr_style.border_color = Color(1.0, 0.5, 0.4, 0.95)
	ptr_style.set_border_width_all(1)
	ptr_style.set_corner_radius_all(2)
	pointer.add_theme_stylebox_override("panel", ptr_style)
	pointer.position = Vector2(bar_x, bar_y + 4)
	pointer.size = Vector2(14, bar_h - 8)
	horde_panel.add_child(pointer)

	# 
	var result_label := Label.new()
	result_label.position = Vector2(0, bar_y + bar_h + 16)
	result_label.size = Vector2(600, 30)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 25)
	horde_panel.add_child(result_label)

	var hint := Label.new()
	hint.text = " [QTE攻击]  (+%d NPC×%d)" % [GameManager.get_total_damage(), helpers]
	hint.position = Vector2(0, bar_y + bar_h + 48)
	hint.size = Vector2(600, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	horde_panel.add_child(hint)

	horde_panel.visible = true
	_update_mouse_mode()

	# 
	var pos: float = 0.0
	var direction: int = 1  # 1=, -1=
	var running: bool = true
	var won: bool = false

	while running:
		await get_tree().process_frame
		if not is_instance_valid(horde_panel) or not is_instance_valid(pointer):
			return false
		pos += direction * speed * get_process_delta_time()
		# 
		if pos >= bar_w - 14:
			pos = bar_w - 14
			direction = -1
		elif pos <= 0:
			pos = 0
			direction = 1
		pointer.position.x = bar_x + pos

		if Input.is_key_pressed(KEY_SPACE):
			var ptr_center: float = pos + 7.0  # 
			var diff: float = abs(ptr_center - target_center)
			running = false
			if diff <= perfect_width / 2.0:
				won = true
				result_label.text = "[color=green]完美命中！[/color]"
			elif diff <= zone_width / 2.0:
				won = true
				result_label.text = "[color=yellow]命中[/color]"
			else:
				won = false
				result_label.text = "[color=red]未命中[/color]"
			await get_tree().create_timer(1.0).timeout

	horde_panel.visible = false
	return won


# ====================  ====================
func _build_menu_button() -> void:
	menu_btn = Button.new()
	menu_btn.text = "菜单"
	menu_btn.position = Vector2(10, 8)  # 
	menu_btn.size = Vector2(90, 44)
	menu_btn.z_index = 1000  # 
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.pressed.connect(_toggle_menu)
	_button_layer.add_child(menu_btn)


# ==================== / ====================
func _build_menu_panel() -> void:
	# 
	var menu_dim := ColorRect.new()
	menu_dim.name = "MenuDim"
	menu_dim.color = Color(0, 0, 0, 0.4)
	menu_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_dim.visible = false
	_button_layer.add_child(menu_dim)
	# 
	menu_panel = Panel.new()
	menu_panel.position = Vector2(240, 80)
	menu_panel.size = Vector2(800, 560)
	menu_panel.self_modulate = Color(0.05, 0.05, 0.08, 0.97)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.z_index = 1  # 
	menu_panel.visible = false
	_button_layer.add_child(menu_panel)


func _hide_menu_dim() -> void:
	var dim := get_node_or_null("MenuDim")
	if dim:
		dim.visible = false

func _toggle_menu() -> void:
	if popup_open and not menu_panel.visible:
		return
	menu_panel.visible = not menu_panel.visible
	# /
	var dim := get_node_or_null("MenuDim")
	if dim:
		dim.visible = menu_panel.visible
	popup_open = menu_panel.visible
	_update_mouse_mode()
	if menu_panel.visible:
		_refresh_menu_panel()



func _refresh_menu_panel() -> void:
	for c in menu_panel.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "=== 游戏菜单 ==="
	title.position = Vector2(0, 12)
	title.size = Vector2(800, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color.WHITE)
	menu_panel.add_child(title)

	var tabs: Array[String] = ["存档", "读档", "AI设置", "重新开始", "退出游戏"]
	var tab_start_x: int = 30
	for i in tabs.size():
		var tb := Button.new()
		tb.text = tabs[i]
		tb.position = Vector2(tab_start_x + i * 150, 58)
		tb.size = Vector2(140, 36)
		tb.add_theme_font_size_override("font_size", 20)
		tb.pressed.connect(_on_menu_tab.bind(i))
		menu_panel.add_child(tb)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(40, 100)
	grid.size = Vector2(720, 360)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	menu_panel.add_child(grid)

	for slot_idx in range(8):
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(168, 170)
		slot_panel.self_modulate = Color(0.15, 0.15, 0.18, 0.9)
		grid.add_child(slot_panel)

		var no_label := Label.new()
		no_label.text = "存档 %d" % (slot_idx + 1)
		no_label.position = Vector2(4, 4)
		no_label.add_theme_font_size_override("font_size", 18)
		no_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		slot_panel.add_child(no_label)

		var save_info := _get_save_info(slot_idx + 1)
		var info_label := Label.new()
		info_label.position = Vector2(4, 26)
		info_label.size = Vector2(160, 100)
		info_label.add_theme_font_size_override("font_size", 17)
		info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		if save_info.is_empty():
			info_label.text = "空存档"
		else:
			info_label.text = "第%d天 %s\nHP:%d 击杀:%d" % [save_info.get("day", 1), save_info.get("time", "8:00"), save_info.get("hp", 100), save_info.get("kills", 0)]
		slot_panel.add_child(info_label)

		var act_btn := Button.new()
		act_btn.position = Vector2(8, 134)
		act_btn.size = Vector2(152, 30)
		act_btn.add_theme_font_size_override("font_size", 17)
		if save_info.is_empty():
			act_btn.text = "存档"
			act_btn.pressed.connect(_save_to_slot.bind(slot_idx + 1, slot_panel))
		else:
			act_btn.text = "读取/覆盖"
			act_btn.pressed.connect(_on_slot_action.bind(slot_idx + 1))
		slot_panel.add_child(act_btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(300, 510)
	close_btn.size = Vector2(200, 40)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func(): menu_panel.visible = false; _hide_menu_dim(); popup_open = false; _update_mouse_mode())
	menu_panel.add_child(close_btn)


func _on_menu_tab(idx: int) -> void:
	match idx:
		0, 1:
			_refresh_menu_panel()
		2:
			_show_ai_settings()
		3:
			menu_panel.visible = false; _hide_menu_dim(); popup_open = false; _update_mouse_mode()
			GameManager.game_over = false
			var main: Node = get_parent()
			if main and main.has_method("_show_start_screen"):
				main._show_start_screen()
		4:
			get_tree().quit()


func _on_slot_action(slot: int) -> void:
	var save_info: Dictionary = _get_save_info(slot)
	if save_info.is_empty():
		_save_to_slot(slot, null)
	else:
		_show_slot_choice(slot)


# ==================== AI ====================
func _show_ai_settings() -> void:
	"""AI"""
	for c in menu_panel.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "=== AI对话设置 ==="
	title.position = Vector2(0, 12)
	title.size = Vector2(800, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	menu_panel.add_child(title)

	var desc := RichTextLabel.new()
	desc.text = """[color=#BBBBBB]AI对话为可选功能，不配置也能正常游戏，NPC将使用预设对话。
启用后NPC会根据性格智能生成回复，体验更沉浸。[/color]"""
	desc.position = Vector2(40, 60)
	desc.size = Vector2(720, 80)
	desc.bbcode_enabled = true
	desc.add_theme_font_size_override("normal_font_size", 18)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_panel.add_child(desc)

	var y_start := 150
	var line_h := 44
	var label_w := 140
	var field_w := 480
	var field_x := 200

	# --- AI ---
	var status_panel := Panel.new()
	status_panel.position = Vector2(40, y_start)
	status_panel.size = Vector2(720, 30)
	var sp_style := StyleBoxFlat.new()
	sp_style.set_corner_radius_all(4)
	sp_style.set_border_width_all(1)
	if AIDialogue.is_ai_available():
		sp_style.bg_color = Color(0.05, 0.15, 0.08, 0.85)
		sp_style.border_color = Color(0.3, 0.8, 0.4, 0.9)
	else:
		sp_style.bg_color = Color(0.12, 0.08, 0.08, 0.85)
		sp_style.border_color = Color(0.5, 0.25, 0.25, 0.9)
	status_panel.add_theme_stylebox_override("panel", sp_style)
	menu_panel.add_child(status_panel)

	var status_label := Label.new()
	status_label.position = Vector2(10, 2)
	status_label.size = Vector2(700, 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 16)
	if AIDialogue.is_ai_available():
		status_label.text = "AI已启用 — 所有AI对话功能正常运作"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	else:
		status_label.text = "AI未启用 — 需要配置API"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	status_panel.add_child(status_label)

	y_start += 30 + 10

	# ---  ---
	var enabled_label := Label.new()
	enabled_label.text = "AI对话开关:"
	enabled_label.position = Vector2(40, y_start)
	enabled_label.size = Vector2(label_w, line_h)
	enabled_label.add_theme_font_size_override("font_size", 20)
	enabled_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	menu_panel.add_child(enabled_label)

	var enabled_box := CheckBox.new()
	enabled_box.text = "启用（需填入API密钥后开启）"
	enabled_box.position = Vector2(field_x, y_start)
	enabled_box.size = Vector2(500, line_h)
	enabled_box.button_pressed = AIDialogue.ai_enabled
	enabled_box.add_theme_font_size_override("font_size", 18)
	menu_panel.add_child(enabled_box)

	# --- API URL ---
	y_start += line_h + 8
	var url_label := Label.new()
	url_label.text = "API地址:"
	url_label.position = Vector2(40, y_start)
	url_label.size = Vector2(label_w, line_h)
	url_label.add_theme_font_size_override("font_size", 20)
	url_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	menu_panel.add_child(url_label)

	var url_edit := LineEdit.new()
	url_edit.text = AIDialogue.api_url
	url_edit.position = Vector2(field_x, y_start)
	url_edit.size = Vector2(field_w, 32)
	url_edit.add_theme_font_size_override("font_size", 16)
	menu_panel.add_child(url_edit)

	# --- API Key ---
	y_start += line_h + 8
	var key_label := Label.new()
	key_label.text = "API密钥:"
	key_label.position = Vector2(40, y_start)
	key_label.size = Vector2(label_w, line_h)
	key_label.add_theme_font_size_override("font_size", 20)
	key_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	menu_panel.add_child(key_label)

	var key_edit := LineEdit.new()
	key_edit.text = AIDialogue.api_key
	key_edit.secret = true
	key_edit.position = Vector2(field_x, y_start)
	key_edit.size = Vector2(field_w, 32)
	key_edit.add_theme_font_size_override("font_size", 16)
	key_edit.placeholder_text = "sk-xxxxxxxxxxxxxxxx"
	menu_panel.add_child(key_edit)

	# ---  ---
	y_start += line_h + 8
	var model_label := Label.new()
	model_label.text = "模型名称:"
	model_label.position = Vector2(40, y_start)
	model_label.size = Vector2(label_w, line_h)
	model_label.add_theme_font_size_override("font_size", 20)
	model_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	menu_panel.add_child(model_label)

	var model_edit := LineEdit.new()
	model_edit.text = AIDialogue.ai_model
	model_edit.position = Vector2(field_x, y_start)
	model_edit.size = Vector2(field_w, 32)
	model_edit.add_theme_font_size_override("font_size", 16)
	menu_panel.add_child(model_edit)

	# ---  ---
	y_start += line_h + 8
	var temp_label := Label.new()
	temp_label.text = "创意度(0-2):"
	temp_label.position = Vector2(40, y_start)
	temp_label.size = Vector2(label_w, line_h)
	temp_label.add_theme_font_size_override("font_size", 20)
	temp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	menu_panel.add_child(temp_label)

	var temp_slider := HSlider.new()
	temp_slider.min_value = 0.0
	temp_slider.max_value = 2.0
	temp_slider.step = 0.05
	temp_slider.value = AIDialogue.ai_temperature
	temp_slider.position = Vector2(field_x, y_start + 2)
	temp_slider.size = Vector2(300, 20)
	menu_panel.add_child(temp_slider)

	var temp_value := Label.new()
	temp_value.text = "%.2f" % AIDialogue.ai_temperature
	temp_value.position = Vector2(field_x + 310, y_start)
	temp_value.size = Vector2(80, 24)
	temp_value.add_theme_font_size_override("font_size", 18)
	temp_value.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	menu_panel.add_child(temp_value)
	temp_slider.value_changed.connect(func(v: float): temp_value.text = "%.2f" % v)

	# ---  ---
	y_start += line_h + 16
	var preset_label := Label.new()
	preset_label.text = "快速预设:"
	preset_label.position = Vector2(40, y_start)
	preset_label.size = Vector2(label_w, 30)
	preset_label.add_theme_font_size_override("font_size", 20)
	preset_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	menu_panel.add_child(preset_label)

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
		menu_panel.add_child(pbtn)
		px += 132

	# ---  ---
	var save_btn := Button.new()
	save_btn.text = "保存设置"
	save_btn.position = Vector2(290, 460)
	save_btn.size = Vector2(220, 48)
	save_btn.add_theme_font_size_override("font_size", 22)
	save_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
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
		# 
		_show_ai_settings()
		_show_popup("[color=green]AI[/color]\n\n%s\nNPCAI" % (
			"[color=#88FF88]AI[/color]" if config["enabled"] and config["api_key"] != "" else "[color=red]AI[/color]"
		))
	)
	menu_panel.add_child(save_btn)

	# 
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(300, 520)
	back_btn.size = Vector2(200, 38)
	back_btn.add_theme_font_size_override("font_size", 20)
	back_btn.pressed.connect(_refresh_menu_panel)
	menu_panel.add_child(back_btn)


func _show_slot_choice(slot: int) -> void:
	var choice_panel := Panel.new()
	choice_panel.position = Vector2(70, 70)
	choice_panel.size = Vector2(660, 420)
	choice_panel.self_modulate = Color(0.1, 0.1, 0.15, 0.99)
	choice_panel.z_index = 10
	menu_panel.add_child(choice_panel)

	var label := Label.new()
	label.text = "存档 %d" % slot
	label.position = Vector2(0, 30); label.size = Vector2(660, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 25)
	label.add_theme_color_override("font_color", Color.WHITE)
	choice_panel.add_child(label)

	var save_btn := Button.new()
	save_btn.text = "保存"; save_btn.position = Vector2(180, 120); save_btn.size = Vector2(300, 50)
	save_btn.add_theme_font_size_override("font_size", 25)
	save_btn.pressed.connect(func(): _save_to_slot(slot, null); choice_panel.queue_free(); await get_tree().process_frame; _refresh_menu_panel())
	choice_panel.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "读取"; load_btn.position = Vector2(180, 190); load_btn.size = Vector2(300, 50)
	load_btn.add_theme_font_size_override("font_size", 25)
	load_btn.pressed.connect(func(): _load_from_slot(slot); choice_panel.queue_free(); menu_panel.visible = false; _hide_menu_dim(); popup_open = false)
	choice_panel.add_child(load_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"; cancel_btn.position = Vector2(180, 280); cancel_btn.size = Vector2(300, 50)
	cancel_btn.add_theme_font_size_override("font_size", 25)
	cancel_btn.pressed.connect(func(): choice_panel.queue_free())
	choice_panel.add_child(cancel_btn)


func _save_to_slot(slot: int, _slot_panel = null) -> void:
	if not GameManager.game_started or GameManager.game_over:
		_show_popup("无法存档：游戏未开始或已结束")
		return
	var data: Dictionary = {
		"day": GameManager.current_day, "hour": GameManager.current_hour,
		"hp": GameManager.hp, "hunger": GameManager.hunger, "sanity": GameManager.sanity,
		"kills": GameManager.kill_count, "actions": GameManager.actions_today,
		"door_cd": GameManager.door_cooldown, "door_hp": GameManager.door_hp,
		"door_max_hp": GameManager.door_max_hp, "door_reinforce": GameManager.door_reinforce_level,
		"door_reinforced_today": GameManager.door_reinforced_today,
		"inventory": GameManager.inventory.duplicate(true),
		"cabinet_items": _serialize_cabinet_items(),
		"room_npcs": GameManager.room_npcs.duplicate(true),
		"storage": GameManager.storage.duplicate(true),
		"equip_left": GameManager.equip_left, "equip_right": GameManager.equip_right,
		"zombie_level": GameManager.zombie_level,
	}
	var file: FileAccess = FileAccess.open("user://save_%d.json" % slot, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		_show_popup("已保存到存档%d" % slot)
	if _slot_panel:
		_refresh_menu_panel()


func _load_from_slot(slot: int) -> void:
	var file: FileAccess = FileAccess.open("user://save_%d.json" % slot, FileAccess.READ)
	if not file:
		_show_popup("存档%d不存在" % slot)
		return
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		_show_popup("存档%d损坏，无法读取" % slot)
		return
	var data = json.get_data()
	GameManager.hp = data.get("hp", 100)
	GameManager.hunger = data.get("hunger", 100.0)
	GameManager.sanity = data.get("sanity", 100.0)
	GameManager.kill_count = data.get("kills", 0)
	GameManager.current_day = data.get("day", 1)
	GameManager.current_hour = data.get("hour", 8.0)
	GameManager.actions_today = data.get("actions", 0)
	GameManager.door_cooldown = data.get("door_cd", 0.0)
	GameManager.door_hp = data.get("door_hp", 100)
	GameManager.door_max_hp = data.get("door_max_hp", 100)
	GameManager.door_reinforce_level = data.get("door_reinforce", 0)
	GameManager.door_reinforced_today = data.get("door_reinforced_today", false)
	GameManager.inventory = data.get("inventory", [])
	GameManager.room_npcs = data.get("room_npcs", [])
	GameManager.storage = data.get("storage", {})
	GameManager.equip_left = data.get("equip_left", "")
	GameManager.equip_right = data.get("equip_right", "")
	GameManager.zombie_level = data.get("zombie_level", 1)
	GameManager.cabinet_items = _deserialize_cabinet_items(data.get("cabinet_items", {}))
	GameManager.active_npc_data = {}
	GameManager.npcs_used_today.clear()
	GameManager.game_over = false
	GameManager.game_started = true
	GameManager.is_exploring = false

	GameManager.hp_changed.emit(GameManager.hp, GameManager.max_hp)
	GameManager.hunger_changed.emit(GameManager.hunger, GameManager.max_hunger)
	GameManager.sanity_changed.emit(GameManager.sanity)
	GameManager.kills_changed.emit(GameManager.kill_count)
	GameManager.time_changed.emit(GameManager.current_day, GameManager.current_hour)
	GameManager.door_state_changed.emit(GameManager.door_hp, GameManager.door_max_hp, GameManager.door_reinforce_level)
	GameManager.inventory_updated.emit()
	GameManager.equipment_changed.emit()
	GameManager.storage_updated.emit()
	_show_popup(" %d " % slot)

	var main: Node = get_parent()
	if main and main.has_method("resume_from_load"):
		main.resume_from_load()
	else:
		show_hud()


func _get_save_info(slot: int) -> Dictionary:
	var file: FileAccess = FileAccess.open("user://save_%d.json" % slot, FileAccess.READ)
	if not file:
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
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


func _serialize_cabinet_items() -> Dictionary:
	var result: Dictionary = {}
	for key in GameManager.cabinet_items:
		result[str(key)] = GameManager.cabinet_items[key]
	return result


func _deserialize_cabinet_items(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in data:
		result[int(key)] = data[key]
	return result


# ==================== HUD/ ====================
func hide_hud() -> void:
	top_bar.visible = false
	hotbar_panel.visible = false
	sprint_hint.visible = false
	#  menu_btn  speed_btn


func show_hud() -> void:
	# 
	_close_all_panels()
	# NPC QTE
	_npc_qte_mode = ""
	_npc_qte_result_emitted = false
	popup_open = false
	popup_msg_visible = false
	# HUD
	top_bar.visible = true
	hotbar_panel.visible = true
	menu_btn.visible = true
	sprint_hint.visible = true
	# HUDreset_game
	_update_hp(GameManager.hp, GameManager.max_hp)
	_update_hunger(GameManager.hunger, GameManager.max_hunger)
	_update_sanity(GameManager.sanity)
	_update_time(GameManager.current_day, GameManager.current_hour)
	_update_mouse_mode()
	_update_hotbar()


func _close_all_panels() -> void:
	"""/"""
	if inventory_panel: inventory_panel.visible = false
	if item_action_panel: item_action_panel.visible = false
	if explore_panel: explore_panel.visible = false
	if midnight_panel: midnight_panel.visible = false
	if horde_panel: horde_panel.visible = false
	if menu_panel: menu_panel.visible = false
	if game_over_panel: game_over_panel.visible = false
	if craft_panel: craft_panel.visible = false
	if storage_panel: storage_panel.visible = false
	if trash_panel: trash_panel.visible = false
	if cabinet_panel: cabinet_panel.visible = false
	if npc_interact_panel: npc_interact_panel.visible = false
	if popup_msg_panel: popup_msg_panel.visible = false


# ====================  ====================
func _input(event: InputEvent) -> void:
	# NPC QTE 
	if _npc_qte_mode != "" and not _npc_qte_result_emitted:
		if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
			_npc_qte_check_result()
			return
		# 移动端：触屏点击也触发QTE确认
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			_npc_qte_check_result()
			return
		return
	# ESC /
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if popup_msg_visible:
			_dismiss_popup()
			return
		_toggle_fullscreen()
		return
	if GameManager.game_over or not GameManager.game_started:
		return
	# Y T 
	if storage_panel and storage_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_Y:
				_storage_put_all()
				return
			if event.keycode == KEY_T:
				_storage_take_all()
				return
	# 
	if popup_msg_visible:
		if (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_dismiss_popup()
		return
	if event.is_action_pressed("inventory"):
		if inventory_panel.visible:
			inventory_panel.visible = false
			popup_open = false
		else:
			_update_inventory()
			inventory_panel.visible = true
			popup_open = true
		_update_mouse_mode()
		return


func _toggle_fullscreen() -> void:
	if get_window().mode == Window.MODE_MAXIMIZED:
		get_window().mode = Window.MODE_WINDOWED
	else:
		get_window().mode = Window.MODE_MAXIMIZED


# ==================== ====================
func _build_dream_panel() -> void:
	dream_panel = Panel.new()
	dream_panel.position = Vector2(0, 0)
	dream_panel.size = Vector2.ZERO
	dream_panel.visible = false
	dream_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# 用 ColorRect 做背景，确保不透明
	var bg := ColorRect.new()
	bg.name = "DreamBg"
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vsize := get_viewport().get_visible_rect().size
	bg.position = Vector2.ZERO
	bg.size = vsize
	dream_panel.add_child(bg)
	add_child(dream_panel)


func _show_dream() -> void:
	""" + 4Q&A"""
	_close_all_panels()
	hide_hud()
	popup_open = true

	for c in dream_panel.get_children():
		if c.name == "DreamBg":
			continue
		dream_panel.remove_child(c)
		c.queue_free()

	_dream_data = GameManager.get_random_dream()
	if _dream_data.is_empty():
		_end_dream()
		return

	# 
	var vsize := get_viewport().get_visible_rect().size
	dream_panel.size = vsize
	var bg := dream_panel.get_node_or_null("DreamBg")
	if bg:
		bg.size = vsize
	move_child(dream_panel, get_child_count() - 1)

	# 
	var dream_label := Label.new()
	dream_label.name = "DreamHeader"
	dream_label.text = "· 梦 ·"
	dream_label.position = Vector2(0, 60)
	dream_label.size = Vector2(vsize.x, 80)
	dream_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dream_label.add_theme_font_size_override("font_size", 40)
	dream_label.add_theme_color_override("font_color", Color.WHITE)
	dream_panel.add_child(dream_label)

	# 
	var title := Label.new()
	title.name = "DreamTitle"
	title.text = "~ " + _dream_data.get("title", "") + " ~"
	title.position = Vector2(0, 200)
	title.size = Vector2(vsize.x, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.visible = false
	dream_panel.add_child(title)

	dream_panel.visible = true
	_update_mouse_mode()

	# 
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(title):
		title.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(title):
		title.visible = false

	# 
	var intro := Label.new()
	intro.name = "DreamIntro"
	intro.text = _dream_data.get("intro", "")
	intro.position = Vector2(80, 220)
	intro.size = Vector2(vsize.x - 160, 200)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 22)
	intro.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	dream_panel.add_child(intro)

	await get_tree().create_timer(0.8).timeout

	# AI
	_show_dream_mode_choice()


# ========== AI ==========
var _dream_chat_vbox: Control = null
var _dream_chat_scroll: ScrollContainer = null
var _dream_input_edit: LineEdit = null
var _dream_turn_count: int = 0
var _dream_ai_running: bool = false
var _dream_wakeup_btn: Button = null

func _show_dream_mode_choice() -> void:
	"""/AI"""
	var vsize := get_viewport().get_visible_rect().size

	var choice_label := Label.new()
	choice_label.name = "DreamChoiceLabel"
	choice_label.text = "选择梦境"
	choice_label.position = Vector2(0, 400)
	choice_label.size = Vector2(vsize.x, 50)
	choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_label.add_theme_font_size_override("font_size", 30)
	choice_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	dream_panel.add_child(choice_label)

	# 
	var normal_btn := Button.new()
	normal_btn.name = "DreamBtnNormal"
	normal_btn.text = "普通梦境"
	normal_btn.position = Vector2((vsize.x - 320) / 2, 470)
	normal_btn.size = Vector2(320, 50)
	normal_btn.add_theme_font_size_override("font_size", 24)
	normal_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	ns.border_color = Color(0.35, 0.35, 0.4)
	ns.set_border_width_all(1)
	ns.set_corner_radius_all(6)
	normal_btn.add_theme_stylebox_override("normal", ns)
	normal_btn.pressed.connect(func():
		_clear_dream_choice_ui()
		_dream_round = 0
		_start_dream_round(_dream_round)
	)
	dream_panel.add_child(normal_btn)

	# AI
	var ai_btn := Button.new()
	ai_btn.name = "DreamBtnAI"
	ai_btn.text = "AI对话"
	ai_btn.position = Vector2((vsize.x - 320) / 2, 535)
	ai_btn.size = Vector2(320, 50)
	ai_btn.add_theme_font_size_override("font_size", 24)
	ai_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.85))
	var ais := StyleBoxFlat.new()
	ais.bg_color = Color(0.08, 0.18, 0.15, 0.9)
	ais.border_color = Color(0.25, 0.55, 0.4)
	ais.set_border_width_all(1)
	ais.set_corner_radius_all(6)
	ai_btn.add_theme_stylebox_override("normal", ais)
	ai_btn.pressed.connect(func():
		_clear_dream_choice_ui()
		_start_interactive_dream()
	)
	dream_panel.add_child(ai_btn)

	# AIAI
	if not AIDialogue.is_ai_available():
		ai_btn.disabled = true
		ai_btn.text = "AI互动梦境（需配置API）"
		ai_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		var dis_style := StyleBoxFlat.new()
		dis_style.bg_color = Color(0.08, 0.08, 0.10, 0.7)
		dis_style.border_color = Color(0.25, 0.25, 0.28)
		dis_style.set_border_width_all(1)
		dis_style.set_corner_radius_all(6)
		ai_btn.add_theme_stylebox_override("normal", dis_style)


func _clear_dream_choice_ui() -> void:
	var to_remove: Array = []
	for c in dream_panel.get_children():
		if c.name in ["DreamChoiceLabel", "DreamBtnNormal", "DreamBtnAI"]:
			to_remove.append(c)
	for c in to_remove:
		dream_panel.remove_child(c)
		c.queue_free()


func _start_interactive_dream() -> void:
	"""AI — +RichTextLabel"""
	var vsize := get_viewport().get_visible_rect().size
	_dream_turn_count = 0
	_dream_ai_running = false

	# UIchildren
	var to_remove: Array = []
	for c in dream_panel.get_children():
		if c.name in ["DreamTitle", "DreamIntro", "DreamHeader", "DreamChoiceLabel", "DreamBtnNormal", "DreamBtnAI"]:
			to_remove.append(c)
	for c in to_remove:
		dream_panel.remove_child(c)
		c.queue_free()

	#  — 
	var title := Label.new()
	title.name = "DreamChatTitle"
	title.text = "AI对话 - 妹妹"
	title.position = Vector2(0, 14)
	title.size = Vector2(vsize.x, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.7, 0.65, 1.0))
	dream_panel.add_child(title)

	# 
	var sep := ColorRect.new()
	sep.name = "DreamChatSep"
	sep.position = Vector2(60, 50)
	sep.size = Vector2(vsize.x - 120, 1)
	sep.color = Color(0.25, 0.22, 0.35, 0.6)
	dream_panel.add_child(sep)

	# === AIRichTextLabel ===
	var reply_area := RichTextLabel.new()
	reply_area.name = "DreamChatReply"
	reply_area.position = Vector2(60, 58)
	reply_area.size = Vector2(vsize.x - 120, 260)
	reply_area.bbcode_enabled = true
	reply_area.add_theme_font_size_override("normal_font_size", 24)
	reply_area.add_theme_color_override("default_color", Color(0.9, 0.88, 0.8))
	reply_area.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply_area.scroll_active = true
	reply_area.selection_enabled = true
	reply_area.text = "[color=gray]阅读梦境描述，在梦中行动或说话...[/color]"
	dream_panel.add_child(reply_area)

	# 
	var status_label := Label.new()
	status_label.name = "DreamChatStatus"
	status_label.position = Vector2(60, 325)
	status_label.size = Vector2(vsize.x - 120, 26)
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	dream_panel.add_child(status_label)

	#  — 
	_dream_input_edit = LineEdit.new()
	_dream_input_edit.name = "DreamInput"
	_dream_input_edit.position = Vector2(60, 395)
	_dream_input_edit.size = Vector2(vsize.x - 260, 40)
	_dream_input_edit.placeholder_text = "在下方输入你想说的话..."
	_dream_input_edit.add_theme_font_size_override("font_size", 24)
	_dream_input_edit.editable = false  # AI
	_dream_input_edit.text_submitted.connect(func(_t: String): _on_dream_send())
	dream_panel.add_child(_dream_input_edit)

	# 
	var send_btn := Button.new()
	send_btn.name = "DreamSendBtn"
	send_btn.text = "发送"
	send_btn.position = Vector2(vsize.x - 190, 395)
	send_btn.size = Vector2(100, 40)
	send_btn.add_theme_font_size_override("font_size", 24)
	send_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	send_btn.pressed.connect(_on_dream_send)
	dream_panel.add_child(send_btn)

	#  — 
	_dream_wakeup_btn = Button.new()
	_dream_wakeup_btn.name = "DreamWakeup"
	_dream_wakeup_btn.text = "← "
	_dream_wakeup_btn.position = Vector2((vsize.x - 160) / 2, 480)
	_dream_wakeup_btn.size = Vector2(160, 36)
	_dream_wakeup_btn.add_theme_font_size_override("font_size", 24)
	_dream_wakeup_btn.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	_dream_wakeup_btn.pressed.connect(_on_dream_wakeup_pressed)
	dream_panel.add_child(_dream_wakeup_btn)

	# 
	var npc_names_list: Array[String] = []
	for rnpc in GameManager.room_npcs:
		npc_names_list.append(rnpc.get("name", "???"))
	var npc_names: String = ", ".join(npc_names_list) if not npc_names_list.is_empty() else ""

	var game_state := {
		"day": GameManager.current_day,
		"npc_count": GameManager.room_npcs.size(),
		"morality": GameManager.morality,
		"sanity": GameManager.sanity,
		"kills": GameManager.kill_count,
		"zombie_level": GameManager.zombie_level,
		"npc_names": npc_names,
	}

	# 
	var _reply: RichTextLabel = reply_area
	var _status: Label = status_label
	var _edit: LineEdit = _dream_input_edit

	_dream_ai_running = true
	_reply.text = "[color=#aaaaaa]正在进入梦境...[/color]"
	if is_instance_valid(_status):
		_status.text = "AI正在生成梦境..."
	AIDialogue.start_dream_dialogue(game_state, func(text: String, success: bool, _err: String):
		_dream_ai_running = false
		if not is_instance_valid(dream_panel):
			return
		if success and text != "":
			_reply.text = "[color=#BBAAFF]梦境[/color]\n\n" + text
			if is_instance_valid(_status):
				_status.text = "[color=#888888]输入你的行动[/color]"
			# 
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(_edit):
				_edit.editable = true
				_edit.grab_focus()
		else:
			_reply.text = "[color=#BBAAFF]梦境[/color]\n\n梦境消散了..."
			_dream_turn_count = 0
			if is_instance_valid(_status):
				_status.text = "[color=#888888]梦境已结束[/color]"
			await get_tree().create_timer(0.5).timeout
			if is_instance_valid(_edit):
				_edit.editable = true
				_edit.grab_focus()
	)


func _on_dream_send() -> void:
	""" — +NPC"""
	if _dream_ai_running:
		return
	if not is_instance_valid(_dream_input_edit):
		return
	var text := _dream_input_edit.text.strip_edges()
	if text == "":
		return
	_dream_input_edit.text = ""
	_dream_turn_count += 1

	# 10
	if _dream_turn_count >= 10:
		# reply_area
		var _reply := dream_panel.get_node_or_null("DreamChatReply") as RichTextLabel
		if _reply:
			_reply.text = "%s\n\n[color=#aaaaaa]...[/color]" % (text.substr(0, min(text.length(), 30)))
		_dream_input_edit.editable = false
		return

	#  — 
	var _reply := dream_panel.get_node_or_null("DreamChatReply") as RichTextLabel
	var _status := dream_panel.get_node_or_null("DreamChatStatus") as Label
	if _reply:
		_reply.text = "[color=yellow]梦境正在展开...—— [/color]"
	if _status:
		_status.text = "AI正在思考..."
	_dream_input_edit.editable = false

	var _edit: LineEdit = _dream_input_edit
	var _reply_cap: RichTextLabel = _reply
	var _status_cap: Label = _status
	var _msg: String = text

	_dream_ai_running = true
	AIDialogue.send_dream_message(text, func(reply: String, success: bool, _err: String):
		_dream_ai_running = false
		if not is_instance_valid(dream_panel):
			return
		if success and reply != "":
			var display_text := ""
			if _msg.length() > 30:
				display_text += _msg.substr(0, 28) + "..."
			else:
				display_text += _msg
			display_text += "\n\n"
			display_text += "[color=#AA99FF][b][/b]: %s[/color]" % reply
			if is_instance_valid(_reply_cap):
				_reply_cap.text = display_text
			if is_instance_valid(_status_cap):
				_status_cap.text = ""
			# 
			var sanity_loss := randi() % 4 + 2
			GameManager.modify_sanity(-sanity_loss)
		else:
			var err_text := "%s\n\n[color=red]" % (_msg.substr(0, min(_msg.length(), 30)))
			if _err != "":
				err_text += ": %s" % _err
			err_text += "[/color]\n\n[color=gray]"
			if _err.contains("") or _err.contains("") or _err.contains("CORS"):
				err_text += "AI\nAI"
			else:
				err_text += "..."
			err_text += "[/color]"
			if is_instance_valid(_reply_cap):
				_reply_cap.text = err_text
			if is_instance_valid(_status_cap):
				_status_cap.text = ""
		# 
		if is_instance_valid(_edit):
			_edit.editable = true
			_edit.grab_focus()
	)


func _on_dream_wakeup_pressed() -> void:
	""" — """
	if not is_instance_valid(_dream_wakeup_btn):
		return

	# 
	if is_instance_valid(_dream_input_edit):
		_dream_input_edit.editable = false
	_dream_wakeup_btn.disabled = true
	_dream_wakeup_btn.text = "..."

	_dream_turn_count = 999

	# 
	if AIDialogue._request_pending:
		AIDialogue._request_pending = false
	_dream_ai_running = false

	# end_dream_dialogue
	AIDialogue.end_dream_dialogue(func(text: String, success: bool, _err: String):
		if not is_instance_valid(dream_panel):
			return
		var _reply := dream_panel.get_node_or_null("DreamChatReply") as RichTextLabel
		if success and text != "" and is_instance_valid(_reply):
			_reply.text = text
		# 
		await get_tree().create_timer(12.0).timeout
		if is_instance_valid(dream_panel):
			_cleanup_dream_chat_ui()
			_end_dream()
	)


func _cleanup_dream_chat_ui() -> void:
	"""UI"""
	var to_remove: Array = []
	for c in dream_panel.get_children():
		if c.name in ["DreamChatTitle", "DreamChatSep", "DreamChatReply", "DreamChatStatus", "DreamInput", "DreamSendBtn", "DreamWakeup"]:
			to_remove.append(c)
	for c in to_remove:
		dream_panel.remove_child(c)
		c.queue_free()
	_dream_chat_scroll = null
	_dream_chat_vbox = null
	_dream_input_edit = null
	_dream_wakeup_btn = null
	_dream_turn_count = 0
	AIDialogue.clear_dream_dialogue()


func _start_dream_round(round_index: int) -> void:
	"""NQ&A + 4"""
	_dream_round = round_index
	var rounds: Array = _dream_data.get("rounds", [])
	if round_index >= rounds.size():
		_end_dream()
		return

	# UIremove_childqueue_free
	var to_remove: Array = []
	for c in dream_panel.get_children():
		if c is Button or c.name in ["DreamReply", "DreamIntro", "DreamTitle", "DreamHeader", "DreamChoiceLabel", "DreamBtnNormal", "DreamBtnAI"]:
			to_remove.append(c)
	for c in to_remove:
		dream_panel.remove_child(c)
		c.queue_free()

	# 
	move_child(dream_panel, get_child_count() - 1)

	var round_data: Dictionary = rounds[round_index] as Dictionary

	# 
	var question := Label.new()
	question.name = "DreamIntro"
	question.text = round_data.get("question", "")
	question.position = Vector2(80, 180)
	var vsize2 := get_viewport().get_visible_rect().size
	question.size = Vector2(vsize2.x - 160, 250)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.add_theme_font_size_override("font_size", 22)
	question.add_theme_color_override("font_color", Color.WHITE)
	dream_panel.add_child(question)

	await get_tree().create_timer(1.5).timeout

	# 4
	_show_dream_buttons()


func _show_dream_buttons() -> void:
	"""4"""
	var rounds: Array = _dream_data.get("rounds", [])
	if _dream_round >= rounds.size():
		_end_dream()
		return

	var round_data: Dictionary = rounds[_dream_round] as Dictionary
	var options: Array = round_data.get("options", [])
	if options.is_empty():
		_end_dream()
		return

	# 
	move_child(dream_panel, get_child_count() - 1)

	var start_y: int = 360
	var btn_height: int = 52
	var btn_width: int = 700
	var spacing: int = 14
	var vsize := get_viewport().get_visible_rect().size
	var btn_x: float = (vsize.x - btn_width) / 2.0

	for i in options.size():
		var opt: Dictionary = options[i] as Dictionary
		var btn := Button.new()
		btn.name = "DreamBtn" + str(i)
		btn.text = str(i + 1) + ". " + opt.get("text", "")
		btn.position = Vector2(btn_x, start_y + (btn_height + spacing) * i)
		btn.size = Vector2(btn_width, btn_height)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.75, 0.75))
		# 
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.18, 0.18, 0.22, 0.95)
		style.border_color = Color(0.4, 0.4, 0.45)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.28, 0.28, 0.35, 0.95)
		hover_style.border_color = Color(0.55, 0.55, 0.6)
		hover_style.set_border_width_all(1)
		hover_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = Color(0.38, 0.38, 0.45, 0.95)
		pressed_style.border_color = Color(0.65, 0.65, 0.7)
		pressed_style.set_border_width_all(1)
		pressed_style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("pressed", pressed_style)

		btn.pressed.connect(_on_dream_option_pressed.bind(opt))
		dream_panel.add_child(btn)


func _on_dream_option_pressed(opt: Dictionary) -> void:
	""""""
	# DreamReplyremove_childqueue_free
	var to_remove: Array = []
	for c in dream_panel.get_children():
		if c is Button or c.name in ["DreamReply", "DreamIntro"]:
			to_remove.append(c)
	for c in to_remove:
		dream_panel.remove_child(c)
		c.queue_free()

	# 
	var reply_text: String = opt.get("reply", "")
	var reply := Label.new()
	reply.name = "DreamReply"
	reply.text = reply_text
	var vsize_reply := get_viewport().get_visible_rect().size
	reply.position = Vector2(100, 200)
	reply.size = Vector2(vsize_reply.x - 200, 120)
	reply.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply.add_theme_font_size_override("font_size", 26)
	reply.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	dream_panel.add_child(reply)

	# /
	var sanity_delta: int = opt.get("sanity", 0)
	var moral_delta: int = opt.get("morality", 0)
	GameManager.modify_sanity(float(sanity_delta) * 0.5)
	if moral_delta != 0:
		GameManager.modify_morality(moral_delta, "")

	await get_tree().create_timer(2.5).timeout

	# 
	_dream_round += 1
	var rounds: Array = _dream_data.get("rounds", [])
	if _dream_round < rounds.size():
		_start_dream_round(_dream_round)
	else:
		_end_dream()


func _end_dream() -> void:
	""""""
	# 
	var to_remove: Array = []
	for c in dream_panel.get_children():
		if c.name == "DreamReply":
			to_remove.append(c)
	for c in to_remove:
		dream_panel.remove_child(c)
		c.queue_free()

	# 
	var end_lbl := Label.new()
	end_lbl.name = "DreamEnd"
	end_lbl.text = "你醒了，但不清楚自己是否还在梦中\n"
	end_lbl.position = Vector2(0, 290)
	var vsize3 := get_viewport().get_visible_rect().size
	end_lbl.size = Vector2(vsize3.x, 70)
	end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_lbl.add_theme_font_size_override("font_size", 28)
	end_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	dream_panel.add_child(end_lbl)

	await get_tree().create_timer(3.0).timeout

	# 
	for c in dream_panel.get_children():
		if c.name == "DreamBg":
			continue
		c.queue_free()
	dream_panel.visible = false
	popup_open = false
	show_hud()
	_update_mouse_mode()
	_dream_round = 0
	_dream_data.clear()

	# 
	GameManager.dream_ended.emit()


# ==================== AI ====================
# ========== NPC AI==========
var _npc_chat_reply_area: RichTextLabel = null
var _npc_chat_status_label: Label = null
var _npc_chat_input_edit: LineEdit = null
var _npc_chat_npc_name: String = ""

func _show_ai_chat_panel(npc_name: String) -> void:
	"""AI — AI"""
	AIDialogue._request_pending = false
	for c in npc_interact_panel.get_children():
		npc_interact_panel.remove_child(c)
		c.queue_free()

	var npc := GameManager.get_room_npc_by_name(npc_name)
	if npc.is_empty():
		_show_npc_interact_panel(npc_name, Vector2.ZERO)
		return

	_npc_chat_npc_name = npc_name

	# 
	var title := Label.new()
	title.text = "与 %s 对话" % npc_name
	title.position = Vector2(0, 8)
	title.size = Vector2(540, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))
	npc_interact_panel.add_child(title)

	# 
	var sep := ColorRect.new()
	sep.position = Vector2(15, 42)
	sep.size = Vector2(550, 1)
	sep.color = Color(0.3, 0.35, 0.4, 0.5)
	npc_interact_panel.add_child(sep)

	# AI
	_npc_chat_reply_area = RichTextLabel.new()
	_npc_chat_reply_area.name = "AIChatReply"
	_npc_chat_reply_area.position = Vector2(15, 50)
	_npc_chat_reply_area.size = Vector2(550, 200)
	_npc_chat_reply_area.bbcode_enabled = true
	_npc_chat_reply_area.add_theme_font_size_override("normal_font_size", 18)
	_npc_chat_reply_area.add_theme_color_override("default_color", Color(0.9, 0.88, 0.8))
	_npc_chat_reply_area.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_npc_chat_reply_area.scroll_active = true
	_npc_chat_reply_area.text = "[color=gray]%s...[/color]" % npc_name
	npc_interact_panel.add_child(_npc_chat_reply_area)

	# 
	_npc_chat_status_label = Label.new()
	_npc_chat_status_label.name = "AIChatStatus"
	_npc_chat_status_label.position = Vector2(15, 258)
	_npc_chat_status_label.size = Vector2(550, 22)
	_npc_chat_status_label.add_theme_font_size_override("font_size", 15)
	_npc_chat_status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	npc_interact_panel.add_child(_npc_chat_status_label)

	# 
	_npc_chat_input_edit = LineEdit.new()
	_npc_chat_input_edit.name = "AIChatInput"
	_npc_chat_input_edit.position = Vector2(15, 290)
	_npc_chat_input_edit.size = Vector2(430, 36)
	_npc_chat_input_edit.placeholder_text = "输入你想说的话..."
	_npc_chat_input_edit.add_theme_font_size_override("font_size", 18)
	npc_interact_panel.add_child(_npc_chat_input_edit)

	# 
	var send_btn := Button.new()
	send_btn.text = "发送"
	send_btn.position = Vector2(450, 290)
	send_btn.size = Vector2(110, 36)
	send_btn.add_theme_font_size_override("font_size", 18)
	send_btn.add_theme_color_override("font_color", Color(0.7, 0.9, 0.8))
	send_btn.pressed.connect(_on_npc_chat_send_pressed)
	npc_interact_panel.add_child(send_btn)

	# 
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.position = Vector2(170, 370)
	back_btn.size = Vector2(240, 38)
	back_btn.add_theme_font_size_override("font_size", 19)
	back_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	back_btn.pressed.connect(func():
		_npc_chat_reply_area = null
		_npc_chat_status_label = null
		_npc_chat_input_edit = null
		_show_npc_interact_panel(npc_name, Vector2.ZERO)
	)
	npc_interact_panel.add_child(back_btn)

	# AI
	if not AIDialogue.is_ai_available():
		var no_ai := Label.new()
		no_ai.text = "[color=red]AI服务暂不可用[/color]\n → 请配置AI API密钥"
		no_ai.position = Vector2(15, 130)
		no_ai.size = Vector2(550, 50)
		no_ai.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_ai.add_theme_font_size_override("font_size", 16)
		npc_interact_panel.add_child(no_ai)
		_npc_chat_input_edit.editable = false
		send_btn.disabled = true
	else:
		_npc_chat_input_edit.grab_focus()


func _on_npc_chat_send_pressed() -> void:
	""""""
	if not is_instance_valid(_npc_chat_input_edit):
		return
	var text: String = _npc_chat_input_edit.text.strip_edges()
	if text == "":
		return
	_npc_chat_input_edit.text = ""
	_request_npc_ai_reply(_npc_chat_npc_name, text)


func _request_npc_ai_reply(npc_name: String, player_msg: String) -> void:
	"""AI —  _request_sister_ai_reply"""
	if not AIDialogue.is_ai_available():
		if is_instance_valid(_npc_chat_reply_area):
			_npc_chat_reply_area.text = "[color=red]AI服务暂不可用，请稍后再试[/color]"
		return

	var npc := GameManager.get_room_npc_by_name(npc_name)
	if npc.is_empty():
		return

	if GameManager.sanity < 2.0:
		if is_instance_valid(_npc_chat_reply_area):
			_npc_chat_reply_area.text = "[color=red]精神不足，无法进行对话[/color]"
		return

	GameManager.modify_sanity(-2.0)

	if is_instance_valid(_npc_chat_reply_area):
		_npc_chat_reply_area.text = "[color=yellow]%s正在思考...—— %s [/color]" % [npc_name, npc_name]
	if is_instance_valid(_npc_chat_status_label):
		_npc_chat_status_label.text = "AI正在思考..."
	if is_instance_valid(_npc_chat_input_edit):
		_npc_chat_input_edit.editable = false

	AIDialogue.ask_npc(npc, player_msg, func(reply: String, success: bool, error_msg: String):
		if not is_instance_valid(_npc_chat_reply_area):
			return
		if success:
			var display_text := ""
			if player_msg.length() > 30:
				display_text += player_msg.substr(0, 28) + "..."
			else:
				display_text += player_msg
			display_text += "\n\n"
			display_text += "[color=#88FFAA]%s[/color]: %s" % [npc_name, reply]
			_npc_chat_reply_area.text = display_text
			if is_instance_valid(_npc_chat_status_label):
				_npc_chat_status_label.text = ""
		else:
			var err_display := "[color=red]"
			if error_msg != "":
				err_display += ": %s" % error_msg
			err_display += "[/color]\n\n[color=gray]"
			# 
			if error_msg.contains("") or error_msg.contains("") or error_msg.contains("CORS"):
				err_display += "AI\nAI"
			else:
				err_display += "API"
			err_display += "[/color]"
			_npc_chat_reply_area.text = err_display
			if is_instance_valid(_npc_chat_status_label):
				_npc_chat_status_label.text = ""
		# 
		if is_instance_valid(_npc_chat_input_edit):
			_npc_chat_input_edit.editable = true
			_npc_chat_input_edit.grab_focus()
	)
