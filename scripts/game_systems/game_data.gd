extends Node

# ========== 物品数据管理 ==========

signal item_picked_up(item_id)
signal item_used(item_id)

# 
var inventory = []

# 
var ITEM_DATA = {
	"food": {"name": "罐头", "type": "consumable", "effect": "hunger+30", "desc": "能填饱肚子"},
	"cola": {"name": "可乐", "type": "consumable", "effect": "sanity+20", "desc": "冰镇可乐，解渴提神"},
	"medicine": {"name": "急救药", "type": "consumable", "effect": "hp+30", "desc": "珍贵药品，治疗伤势"},
	"knife": {"name": "小刀", "type": "weapon", "damage": 15, "desc": "锋利的小刀，可以防身"},
	"bandage": {"name": "绷带", "type": "consumable", "effect": "hp+15", "desc": "止血包扎"},
	"key": {"name": "钥匙", "type": "key", "desc": "或许能打开某扇门"},
	"ammo": {"name": "弹药", "type": "ammo", "desc": "关键时刻能救命"},
	"note": {"name": "笔记", "type": "info", "desc": "一张写满潦草字迹的纸条"},
}


func _ready():
	randomize()
	add_item("food", 2)
	add_item("cola", 1)
	add_item("medicine", 1)


func add_item(item_id, amount = 1):
	var idx = find_item(item_id)
	if idx >= 0:
		inventory[idx]["amount"] += amount
	else:
		inventory.append({"id": item_id, "amount": amount})
	item_picked_up.emit(item_id)

	# UI
	var ui = get_node_or_null("/root/Main/UIManager")
	if ui:
		ui.refresh_inventory(inventory)


func remove_item(item_id, amount = 1):
	var idx = find_item(item_id)
	if idx < 0 or inventory[idx]["amount"] < amount:
		return false
	inventory[idx]["amount"] -= amount
	if inventory[idx]["amount"] <= 0:
		inventory.remove_at(idx)

	var ui = get_node_or_null("/root/Main/UIManager")
	if ui:
		ui.refresh_inventory(inventory)
	return true


func spend_action():
	""""""
	var main = get_node_or_null("/root/Main")
	if main and main.has_method("_can_spend_action"):
		return main._can_spend_action()
	return true  # 


func find_item(item_id):
	for i in range(inventory.size()):
		if inventory[i]["id"] == item_id:
			return i
	return -1


func has_item(item_id, amount = 1):
	var idx = find_item(item_id)
	if idx < 0:
		return false
	return inventory[idx]["amount"] >= amount


func use_item(item_id):
	if not has_item(item_id):
		return ""

	var data = ITEM_DATA.get(item_id, {})
	if data.get("type") != "consumable":
		return ""

	remove_item(item_id)

	var main = get_node_or_null("/root/Main")
	var effect = data.get("effect", "")
	if effect.begins_with("hp+") and main:
		main.hp = min(main.max_hp, main.hp + int(effect.substr(3)))
	elif effect.begins_with("hunger+") and main:
		main.hunger = min(main.max_hunger, main.hunger + float(effect.substr(7)))
	elif effect.begins_with("sanity+") and main:
		main.sanity = min(100.0, main.sanity + float(effect.substr(7)))

	item_used.emit(item_id)
	return "%s" % data.get("name", item_id)
