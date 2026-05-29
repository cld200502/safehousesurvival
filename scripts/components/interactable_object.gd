extends StaticBody2D

# ==========  ==========

class_name InteractableObject

@export var object_name = ""
@export var object_type = "generic"
@export var search_difficulty = "normal"
@export var loot_table = []
@export var can_search_once = true

var searched = false
var qte_ref = null
var ui_ref = null

func _ready():
	add_to_group("interactable")
	qte_ref = get_tree().root.get_node_or_null("Main/QTESystem")
	ui_ref = get_tree().root.get_node_or_null("Main/UIManager")


func interact(player):
	if can_search_once and searched:
		ui_ref.show_message("%s" % object_name)
		return
	
	if not player.get("game_data"):
		player.game_data = get_tree().root.get_node_or_null("Main/GameData")
	
	if not player.game_data.spend_action():
		ui_ref.show_message("")
		return
	
	if qte_ref:
		qte_ref.qte_result.connect(_on_qte_result, CONNECT_ONE_SHOT)
		qte_ref.start_qte(search_difficulty)


func _on_qte_result(result_type, accuracy):
	var ui_ref = get_tree().root.get_node_or_null("Main/UIManager")
	var gd = get_tree().root.get_node_or_null("Main/GameData")
	
	if result_type == "perfect":
		_give_loot(gd, 2)
		ui_ref.show_message("")
	elif result_type == "good":
		_give_loot(gd, 1)
		ui_ref.show_message("")
	else:
		ui_ref.show_message("...")
	
	searched = true


func _give_loot(game_data, multiplier = 1):
	if loot_table.is_empty():
		loot_table = ["food", "food", "cola", "medicine", "knife"]
	
	var num_items = randi_range(1, 2) * multiplier
	for i in range(num_items):
		var item_id = loot_table[randi() % loot_table.size()]
		game_data.add_item(item_id, 1)
