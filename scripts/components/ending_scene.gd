extends CanvasLayer
## 结局场景 —— 10个预设结局 + AI结局

signal ending_done

var _ending_id: String = ""
var _data: Dictionary = {}
var _line_index: int = 0
var _lines: Array = []
var _text_label: RichTextLabel
var _title_label: Label
var _next_btn: Button
var _bg: ColorRect
var _stat_line: String = ""
var _vp_size: Vector2
var _npc_name_list: Array[String] = []  # 动态NPC名字列表


## 辅助：获取第N个NPC名字（越界返回"某人"）
func _npc(idx: int) -> String:
	if idx >= 0 and idx < _npc_name_list.size():
		return _npc_name_list[idx]
	return "某人"


## 辅助：获取随机NPC名字
func _rand_npc() -> String:
	if _npc_name_list.is_empty():
		return "某人"
	return _npc_name_list.pick_random()


## 辅助：获取所有NPC名字的中文列举
func _npc_list_str() -> String:
	if _npc_name_list.is_empty():
		return "没有人"
	return "、".join(_npc_name_list)


func _ready() -> void:
	_build_ui()
	visible = false


func start_ending(ending_id: String, data: Dictionary) -> void:
	_ending_id = ending_id
	_data = data
	_setup_lines()
	visible = true
	_show_next_line()


func _build_ui() -> void:
	layer = 250

	_vp_size = get_viewport().get_visible_rect().size

	# 黑色背景
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	_bg.size = _vp_size
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# 微弱光晕
	var glow := ColorRect.new()
	glow.position = Vector2(_vp_size.x * 0.2, _vp_size.y * 0.15)
	glow.size = Vector2(_vp_size.x * 0.6, _vp_size.y * 0.7)
	glow.color = Color(0.08, 0.01, 0.01, 0.15)
	add_child(glow)

	# 结局标题
	_title_label = Label.new()
	_title_label.size = Vector2(_vp_size.x, 60)
	_title_label.position = Vector2(0, 50)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	add_child(_title_label)

	# 分隔线
	var sep := ColorRect.new()
	sep.position = Vector2(_vp_size.x * 0.1, 118)
	sep.size = Vector2(_vp_size.x * 0.8, 1)
	sep.color = Color(0.15, 0.15, 0.15)
	add_child(sep)

	# 结局文字区域
	_text_label = RichTextLabel.new()
	_text_label.position = Vector2(_vp_size.x * 0.1, 140)
	_text_label.size = Vector2(_vp_size.x * 0.8, _vp_size.y - 220)
	_text_label.bbcode_enabled = true
	_text_label.fit_content = false
	_text_label.scroll_active = true
	_text_label.scroll_following = true
	_text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_text_label.selection_enabled = false
	_text_label.add_theme_font_size_override("normal_font_size", 22)
	_text_label.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	add_child(_text_label)

	# 下一页按钮
	_next_btn = Button.new()
	_next_btn.text = "按 [空格键] 继续"
	_next_btn.size = Vector2(200, 44)
	_next_btn.position = Vector2((_vp_size.x - 200) / 2, _vp_size.y - 130)
	_next_btn.add_theme_font_size_override("font_size", 22)
	_next_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	var nstyle := StyleBoxFlat.new()
	nstyle.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	nstyle.set_border_width_all(1)
	nstyle.border_color = Color(0.15, 0.15, 0.15)
	nstyle.set_corner_radius_all(4)
	_next_btn.add_theme_stylebox_override("normal", nstyle)
	var hstyle := StyleBoxFlat.new()
	hstyle.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	hstyle.border_color = Color(0.25, 0.25, 0.25)
	hstyle.set_border_width_all(1)
	hstyle.set_corner_radius_all(4)
	_next_btn.add_theme_stylebox_override("hover", hstyle)
	_next_btn.pressed.connect(_on_next)
	add_child(_next_btn)
	_next_btn.visible = false


func _setup_lines() -> void:
	_lines.clear()

	# 预取房间里NPC的名字列表（用于动态插入结局文本）
	_npc_name_list.clear()
	for rnpc in GameManager.room_npcs:
		_npc_name_list.append(rnpc.get("name", "???"))

	# 根据结局ID设置文字
	match _ending_id:
		"sister_waltz":
			_setup_sister_waltz()
		"last_light":
			_setup_last_light()
		"silent_garden":
			_setup_silent_garden()
		"glass_cage":
			_setup_glass_cage()
		"mirror_hall":
			_setup_mirror_hall()
		"hollow_crown":
			_setup_hollow_crown()
		"ash_and_bone":
			_setup_ash_and_bone()
		"fading_echo":
			_setup_fading_echo()
		"threadbare_hope":
			_setup_threadbare_hope()
		"tomorrow_never":
			_setup_tomorrow_never()
		_:
			_setup_tomorrow_never()

	# 统计信息行
	var h: int = int(_data.get("hour", 8.0)) % 24
	var m: int = int((_data.get("hour", 8.0) - h) * 60)
	_stat_line = "[color=#444444]—— 记录结束 ——\n存活: %d 天  |  击杀: %d  |  屋内人数: %d  |  道德: %d\n时间: 第%d天 %02d:%02d[/color]" % [
		_data.get("day", 10),
		_data.get("kills", 0),
		_data.get("npc_count", 0),
		_data.get("morality", 0),
		_data.get("day", 10),
		h, m,
	]
	_lines.append(_stat_line)


# ==================== 结局1: 窗外有光（完美结局） ====================
func _setup_sister_waltz() -> void:
	_title_label.text = "灯火"
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))

	_lines.append_array([
		"",
		"第五天傍晚，对面的楼里亮了一盏灯。",
		"不是路灯，不是应急灯。",
		"是有人拧开了自家的台灯。",
		"",
		"你盯着看了很久。",
		"然后你开始收拾东西。",
		"",
		"屋里的人都在。",
		"%s个人，加上你是%s个。" % [_npc_name_list.size(), _npc_name_list.size() + 1],
		"有人问去哪。",
		"你说不知道，但灯亮了。",
		"",
		"路上很安静。",
		"你走在最前面，手里的棍子没有用上。",
		"身后有人小声在唱歌。",
		"调子跑了，词也记不全。",
		"但你没有打断。",
		"",
		"你想起以前上班的路线。",
		"每天早上七点四十出门，坐四站地铁。",
		"地铁口卖包子的阿姨认识你。",
		"你不知道她还在不在。",
		"",
		"你拐进了一条巷子。",
		"巷子尽头有一扇铁门。",
		"你推了一下。开了。",
		"",
		"铁门后面是一个院子。",
		"院子里种着菜。",
		"有人在浇菜。",
		"",
		"他抬起头，看了看你们。",
		"说了句「门关好，外面有蚊子。」",
		"然后继续浇菜。",
		"",
	])


# ==================== 结局2: 第七个人（高道德+多人） ====================
func _setup_last_light() -> void:
	_title_label.text = "檐下"
	_title_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))

	var n1 := _npc(0)
	var n2 := _npc(1) if _npc_name_list.size() > 1 else _rand_npc()
	var n3 := _npc(2) if _npc_name_list.size() > 2 else _rand_npc()

	_lines.append_array([
		"",
		"第一天只有你自己。",
		"第三天%s来了。第五天%s也到了。" % [n1, n2],
		"",
		"%s会修水管。" % n1,
		"%s以前在社区卫生站上班，能缝针。" % n2,
		"%s什么都不会，但他把所有人的鞋补了一遍。" % n3,
		"补得不好，但能穿了。",
		"",
		"你发现每个人都能做点什么。",
		"只要给他们一个不漏雨的屋顶。",
		"和一张能坐下来的椅子。",
		"",
		"晚上轮流守夜。",
		"两个人一班，四个小时换一次。",
		"你排了一张表贴在墙上。",
		"表下面有人画了一朵小花。",
		"不知道是谁。",
		"",
		"第六天早上，又有人敲门。",
		"一个男孩，大概十二三岁。",
		"校服上全是泥，抱着一只猫。",
		"他说猫已经三天没吃东西了。",
		"",
		"你让他进来了。",
		"猫也进来了。",
		"",
		"屋里现在是八个人，一只猫。",
		"猫蜷在窗台上。打呼噜。",
		"",
	])


# ==================== 结局3: 干净的手（不杀生+有同伴+精神稳定） ====================
func _setup_silent_garden() -> void:
	_title_label.text = "不染"
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.5))

	_lines.append_array([
		"",
		"刀只开过罐头。",
		"手只搬过东西，递过水，拉过摔倒的人。",
		"",
		"不是没有遇到过难事。",
		"第三天晚上，有人偷了药。",
		"你追出去，发现他蹲在楼梯间里哭。",
		"",
		"你没有骂他。",
		"你蹲下来问他要什么。",
		"他老婆在隔壁单元，烧到四十度。",
		"",
		"你给了他退烧药，还有半瓶矿泉水。",
		"他说他不知道怎么还。",
		"你说不用还。",
		"",
		"第五天他来了。",
		"带着老婆。",
		"老婆已经不烧了，怀里抱着两袋大米。",
		"",
		"那天晚上大家吃上了干饭。",
		"",
		"你坐在门口，看着碗里的米饭。",
		"你想起第一天你差点把门锁死。",
		"差点谁也不让进。",
		"",
		"你庆幸你没有。",
		"",
	])


# ==================== 结局4: 单人公寓（独行但不作恶） ====================
func _setup_glass_cage() -> void:
	_title_label.text = "独居"
	_title_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))

	_lines.append_array([
		"",
		"你一个人住。",
		"门反锁了两道。窗户钉了木板。",
		"",
		"东西够吃很久。",
		"每天做的事不多：",
		"检查门窗、清点物资、听收音机、等天黑。",
		"",
		"有人敲过几次门。",
		"你从猫眼看过。",
		"有的浑身是血，有的看起来正常。",
		"你都没有开。",
		"",
		"你跟自己说这是最安全的办法。",
		"多一个人就多一份风险。",
		"这句话是对的。",
		"",
		"但第四天晚上你睡不着。",
		"不是因为害怕。",
		"是因为太安静了。",
		"",
		"你打开收音机。全是沙沙声。",
		"你翻抽屉找电池，翻出了一张旧照片。",
		"去年过年拍的。一桌子菜。七个人。",
		"你坐在最边上，正在给旁边的人倒酒。",
		"",
		"你看了一会儿。",
		"然后把第二道锁打开了。",
		"",
		"你没有开门。",
		"但你也没有再锁上。",
		"",
	])


# ==================== 结局5: 笔记本（有同伴+杀过人） ====================
func _setup_mirror_hall() -> void:
	_title_label.text = "三页纸"
	_title_label.add_theme_color_override("font_color", Color(0.55, 0.4, 0.6))

	_lines.append_array([
		"",
		"你杀过三个人。",
		"",
		"第一个想抢物资。你开了门，他冲进来。",
		"你其实可以不开门的。",
		"第二个威胁你收留的人。你动的手。",
		"第三个——你不愿意想。",
		"",
		"每次都有理由。",
		"每次你都觉得没有别的选择。",
		"",
		"但夜深的时候，你躺在地上。",
		"你数了数。三次。",
		"你觉得有些选择不是没有，",
		"是你没有想。",
		"",
		"屋里现在有五个人。",
		"他们觉得你可靠。你话不多，但什么事都能解决。",
		"他们不知道你解决过什么。",
		"",
		"第五天晚上轮到你守夜。",
		"你翻出一个笔记本，写了三个名字。",
		"然后你把那一页撕下来，叠好。",
		"放进了口袋里。",
		"",
		"你不知道这算什么。",
		"但你觉得你欠他们一个地方。",
		"哪怕只是一张纸。",
		"",
	])


# ==================== 结局6: 钥匙（人多但道德低） ====================
func _setup_hollow_crown() -> void:
	_title_label.text = "掌中之物"
	_title_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))

	var target := _rand_npc()

	_lines.append_array([
		"",
		"储物间的钥匙在你手上。",
		"一开始你觉得这没什么。",
		"总要有人管。",
		"",
		"你按人头分。一人一份。",
		"有人多做了一份工，你多给半份。",
		"有人抱怨，你少给半份。",
		"",
		"你发现少给比多给更有效。",
		"抱怨的人第二天就不抱怨了。",
		"不抱怨的人开始对你笑。",
		"那种笑很浅，不经过眼睛。",
		"",
		"第四天，你让%s出去找东西。" % target,
		"外面很危险。TA知道。你也知道。",
		"TA看了你一眼，什么都没说，出去了。",
		"回来的时候手上全是血。不是TA的。",
		"",
		"你把TA的配额加了一份。",
		"TA说了声谢谢。低着头。",
		"",
		"第五天早上，%s的床位是空的。" % target,
		"没有人问。",
		"",
		"你坐在角落里，手里攥着钥匙。",
		"钥匙不重。但你觉得手心很凉。",
		"",
	])


# ==================== 结局7: 空房间（多次杀戮+道德极低） ====================
func _setup_ash_and_bone() -> void:
	_title_label.text = "此间无人"
	_title_label.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))

	_lines.append_array([
		"",
		"屋里只有你一个人了。",
		"",
		"其他人是什么时候消失的，",
		"你记不太清了。",
		"",
		"物资堆在角落。够一个人活很久。",
		"你每天吃饭、喝水、坐着。",
		"",
		"你不开窗。不开灯。",
		"你不想看外面。",
		"也不想被外面看到。",
		"",
		"有时候你会听到隔壁有动静。",
		"像是有人在挪椅子。",
		"但隔壁是承重墙。没有房间。",
		"",
		"第五天。",
		"你发现手在抖。",
		"不是因为冷。不是因为饿。",
		"",
		"你把刀放在桌上。",
		"盯了很久。",
		"然后放回了抽屉。",
		"",
		"你没有死。",
		"但你也没有活着。",
		"你只是在这里。",
		"",
	])


# ==================== 结局8: 天亮（精神崩溃边缘+有同伴） ====================
func _setup_fading_echo() -> void:
	_title_label.text = "破晓之前"
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.55))

	var n1 := _npc(0)
	var n2 := _npc(1) if _npc_name_list.size() > 1 else _rand_npc()

	_lines.append_array([
		"",
		"你已经好几天没睡了。",
		"",
		"不是不想睡。",
		"是闭上眼睛就会回到第一天。",
		"门外全是撞击声。你把门反锁了。",
		"你没有去开门。你躲进了里屋。",
		"你蹲在墙角。",
		"听着门板的声音一点点变弱。",
		"",
		"这件事你没有跟任何人说过。",
		"",
		"屋里还有%s个人。" % _npc_name_list.size(),
		"他们轮流照顾你。",
		"%s给你倒了水，放了一片药在旁边。" % n1,
		"%s把窗帘拉上了，说暗一点好睡。" % n2,
		"",
		"你吃了一片。睡了几个小时。",
		"醒来的时候有人在哭。",
		"不是你。是%s。" % n1,
		"",
		"%s坐在角落里，抱着一个空背包。" % n1,
		"TA说TA的家人第一天就失散了。",
		"TA说TA每天都能听到家人在叫TA的名字。",
		"",
		"你坐在TA旁边。没有说话。",
		"你们就这样坐着。",
		"从凌晨坐到窗帘缝里透进来光。",
		"",
		"天亮以后，你煮了两碗面。",
		"一碗给TA，一碗给自己。",
		"面有点坨了。但你们吃完了。",
		"",
	])


# ==================== 结局9: 两个人（一个同伴+道德平庸） ====================
func _setup_threadbare_hope() -> void:
	_title_label.text = "行路"
	_title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.45))

	var partner := _npc(0)

	_lines.append_array([
		"",
		"屋里只剩你和%s了。" % partner,
		"其他人有的找到了家人，有的跟了别的队伍。",
		"",
		"%s没走。你也没走。" % partner,
		"说不上为什么。",
		"可能是都没想好去哪。",
		"",
		"你们每天做的事很简单。",
		"%s修东西。你找吃的。" % partner,
		"有时候一整天说不到十句话。",
		"",
		"但你知道%s早上先喝水再吃饼。" % partner,
		"%s知道你喜欢坐在靠窗的位置。" % partner,
		"这些不是聊出来的。",
		"是待久了就记住了。",
		"",
		"第五天，收音机里说北边有个安置点。",
		"四十公里。走路大概两天。",
		"",
		"你看着%s。" % partner,
		"%s看着你。" % partner,
		"TA说：「走不走？」",
		"",
		"你们收拾了两个背包。",
		"四瓶水，一把刀，一个手电。",
		"",
		"出门的时候%s说：" % partner,
		"「万一走不到呢？」",
		"你说：「那就在路上。」",
		"",
		"TA想了想，点了下头。",
		"",
		"你们走进了楼道。",
		"脚步声很轻。但有两个人的。",
		"",
	])


# ==================== 结局10: 第五天（兜底结局） ====================
func _setup_tomorrow_never() -> void:
	_title_label.text = "如常"
	_title_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))

	_lines.append_array([
		"",
		"第五天了。",
		"你还在。",
		"",
		"东西还有一些。",
		"门还结实。",
		"外面的动静比前两天小了。",
		"不知道是往别处去了，还是变少了。",
		"",
		"你做了很多决定。",
		"有些对了。有些没有。",
		"大部分你当时分不清。",
		"现在也分不清。",
		"",
		"你帮过一些人。",
		"也推开过一些人。",
		"你记得他们的脸。",
		"但有些名字模糊了。",
		"",
		"收音机里的声音越来越少了。",
		"从一天三次变成一天一次。",
		"从一天一次变成两天一次。",
		"今天没有响。",
		"",
		"你站在窗边。",
		"外面像是傍晚，也可能是清晨。",
		"云很厚，看不出太阳在哪。",
		"",
		"你走到门口，摸了摸锁。",
		"",
		"锁是好的。",
		"你也是。",
		"",
	])


# ==================== 显示逻辑 ====================
func _show_next_line() -> void:
	if _line_index >= _lines.size():
		_show_done()
		return

	# 逐行显示文字
	var display_text: String = ""
	for i in range(_line_index + 1):
		display_text += _lines[i] + "\n"

	_text_label.text = display_text
	_line_index += 1

	# 显示继续按钮
	if not _next_btn.visible:
		_next_btn.visible = true
	_next_btn.disabled = false
	_next_btn.text = "按 [空格键] 继续"

	# 滚动到最新行
	await get_tree().process_frame
	_text_label.scroll_to_line(_text_label.get_line_count() - 1)


func _on_next() -> void:
	if _line_index >= _lines.size():
		# 所有文字显示完毕，显示AI/返回按钮
		_show_done()
		return

	_next_btn.disabled = true
	_show_next_line()


func _show_done() -> void:
	# AI可用时显示AI评价和返回菜单
	if AIDialogue.is_ai_available():
		_next_btn.visible = false

		# AI评价按钮
		var ai_btn := Button.new()
		ai_btn.name = "AIEndingBtn"
		ai_btn.text = "AI叙事结局"
		ai_btn.size = Vector2(240, 44)
		ai_btn.position = Vector2((_vp_size.x - 520) / 2, _vp_size.y - 130)
		ai_btn.add_theme_font_size_override("font_size", 22)
		ai_btn.add_theme_color_override("font_color", Color(0.5, 1.0, 0.85))
		var ai_style := StyleBoxFlat.new()
		ai_style.bg_color = Color(0.05, 0.12, 0.10, 0.9)
		ai_style.set_border_width_all(1)
		ai_style.border_color = Color(0.25, 0.55, 0.4)
		ai_style.set_corner_radius_all(4)
		ai_btn.add_theme_stylebox_override("normal", ai_style)
		ai_btn.pressed.connect(_on_ai_ending)
		add_child(ai_btn)

		# 返回主菜单按钮
		var menu_btn := Button.new()
		menu_btn.name = "MenuBtn"
		menu_btn.text = "返回主菜单"
		menu_btn.size = Vector2(240, 44)
		menu_btn.position = Vector2((_vp_size.x) / 2, _vp_size.y - 130)
		menu_btn.add_theme_font_size_override("font_size", 22)
		menu_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		var ms := StyleBoxFlat.new()
		ms.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		ms.set_border_width_all(1)
		ms.border_color = Color(0.15, 0.15, 0.15)
		ms.set_corner_radius_all(4)
		menu_btn.add_theme_stylebox_override("normal", ms)
		menu_btn.pressed.connect(func():
			ending_done.emit()
			queue_free()
		)
		add_child(menu_btn)
	else:
		_next_btn.text = "返回主菜单"
		_next_btn.disabled = false
		_next_btn.visible = true


func _on_ai_ending() -> void:
	"""AI生成结局评价——根据游戏事件生成个性化结局"""
	# 隐藏所有按钮
	for c in get_children():
		if c is Button:
			c.visible = false

	# 等待提示
	_text_label.text = "[color=#555555]AI正在生成个性化结局... 请稍候...[/color]"

	var npc_names_list: Array[String] = []
	for rnpc in GameManager.room_npcs:
		npc_names_list.append(rnpc.get("name", "???"))
	var npc_names: String = ", ".join(npc_names_list) if not npc_names_list.is_empty() else "无"

	var killed_names_list: Array[String] = []
	for kn in GameManager.killed_npcs:
		killed_names_list.append(kn)
	var killed_names: String = ", ".join(killed_names_list) if not killed_names_list.is_empty() else "无"

	var game_state := {
		"day": _data.get("day", 5),
		"npc_count": _data.get("npc_count", 0),
		"morality": _data.get("morality", 0),
		"sanity": _data.get("sanity", 50),
		"kills": _data.get("kills", 0),
		"zombie_level": _data.get("zombie_level", 1),
		"door_hp": _data.get("door_hp", 0),
		"door_max": _data.get("door_max", 100),
		"npc_names": npc_names,
		"killed_names": killed_names,
		"sister_status": GameManager.get_sister_mood_label(),
		"ending_id": _ending_id,
		"ending_title": _title_label.text,
	}

	AIDialogue.generate_ending(game_state, func(text: String, success: bool, _err: String):
		if success:
			# AI生成的评价
			_text_label.text = text + "\n\n" + _stat_line
		else:
			_text_label.text = "[color=red]AI生成失败，请检查API配置[/color]\n\n" + _stat_line

		# 显示返回菜单按钮
		for c in get_children():
			if c is Button and c.name == "MenuBtn":
				c.visible = true
	)
