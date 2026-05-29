extends Node
## 教程管理器 —— 分步引导玩家了解游戏系统
## 由 main.gd 在 _process 中触发

signal tutorial_step_changed(step: int, title: String, text: String)
signal tutorial_finished

# 
var tutorial_active: bool = false
var current_step: int = 0
var step_completed: bool = false
var tutorial_done: bool = false  # 

# 7
const TUTORIAL_STEPS: Array[Dictionary] = [
	{
		"title": "欢迎来到安全屋",
		"text": "丧尸病毒爆发，你被困在这间安全屋里。\n——\n\n使用 [A/D] 或方向键移动角色\n使用 [E] 键或空格键与物体互动",
		"trigger": "auto",       # 自动触发
		"highlight": "",          # UI元素高亮
	},
	{
		"title": "管理你的状态",
		"text": "注意左上角的生命、饥饿和精神值\n\n饥饿值会随时间流逝而下降\n通过打开 [I] 背包使用食物补充饥饿\n饥饿归零将导致死亡！",
		"trigger": "hunger_check",
		"highlight": "inventory",
	},
	{
		"title": "大门——你的防线",
		"text": "门是你与外界丧尸之间的唯一屏障\n\n走到门边按 [E] 可以查看门的状态\n加固和修复门能提升防御力\n门被破坏就意味着死亡...",
		"trigger": "door_intro",
		"highlight": "door",
	},
	{
		"title": "敲门声——有人来了",
		"text": "每隔一段时间会有人敲门\n——可能是幸存者、掠夺者或丧尸...\n\n按 [E] 去门边通过猫眼观察\n然后决定是否开门",
		"trigger": "knock_intro",
		"highlight": "peephole",
	},
	{
		"title": "外出探索",
		"text": "点击门面板中的「外出探索」可以离开安全屋\n\n外出会消耗时间和饥饿值\n但能找到食物、药品和武器\n注意：外出有概率遭遇丧尸！",
		"trigger": "explore_intro",
		"highlight": "explore",
	},
	{
		"title": "制作与合成",
		"text": "收集材料后可以在工作台制作物品\n\n工作台合成成功率为50%\n失败会消耗材料\n合理利用资源是关键！",
		"trigger": "craft_intro",
		"highlight": "craft",
	},
	{
		"title": "活下去",
		"text": "你已经掌握了基本生存技巧\n\n管理好你的资源\n谨慎对待每一个敲门声\n活过每一天，等待救援...\n\n祝你好运！",
		"trigger": "final",
		"highlight": "",
	},
]


func _ready() -> void:
	name = "TutorialManager"
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_tutorial() -> void:
	"""1"""
	if tutorial_done:
		return
	tutorial_active = true
	current_step = 0
	step_completed = false
	_show_current_step()


func advance_step() -> void:
	""""""
	if not tutorial_active or step_completed:
		return
	step_completed = true
	current_step += 1
	if current_step >= TUTORIAL_STEPS.size():
		tutorial_active = false
		tutorial_done = true
		tutorial_finished.emit()
	else:
		step_completed = false
		_show_current_step()


func _show_current_step() -> void:
	if current_step < TUTORIAL_STEPS.size():
		var step: Dictionary = TUTORIAL_STEPS[current_step]
		tutorial_step_changed.emit(current_step, step["title"], step["text"])


func get_current_step_data() -> Dictionary:
	if current_step < TUTORIAL_STEPS.size():
		return TUTORIAL_STEPS[current_step]
	return {}


func should_trigger_for(action: String) -> bool:
	""""""
	if not tutorial_active or tutorial_done or step_completed:
		return false
	var data := get_current_step_data()
	return data.get("trigger", "") == action


# ====================  ====================

func get_save_data() -> Dictionary:
	return {"tutorial_done": tutorial_done}


func load_save_data(data: Dictionary) -> void:
	tutorial_done = data.get("tutorial_done", false)
