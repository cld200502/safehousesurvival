extends Node
## AI对话管理器 (Autoload)
## 支持 OpenAI 兼容API/DeepSeek/OpenAI/Ollama 等

# ========== 配置 ==========
var ai_enabled: bool = false
var api_key: String = ""
var api_url: String = "https://api.deepseek.com/v1/chat/completions"
var ai_model: String = "deepseek-chat"
var ai_temperature: float = 0.85
var ai_max_tokens: int = 400

# ========== 内部状态 ==========
var _http_request: HTTPRequest
var _request_pending: bool = false
var _pending_callback: Callable
var _response_cache: Dictionary = {}  # 缓存近期回复

# ========== NPC对话提示词 ==========
const PROMPT_SYSTEM = """你是一个NPC角色扮演AI。

你必须严格扮演以下角色：

- 名字：{name}
- 性格：{personality}
- 说话风格：{speaking_style}
- 心情：{mood}
- 背景故事：{background}
- 隐藏的秘密：{secret}

规则：
1. 你必须完全代入这个NPC角色，用ta的性格和说话风格回复。
2. 回复长度控制在30-80字。
3. 不要承认自己是AI，不要说"作为一个人工智能"之类的话。
4. 如果对话涉及角色的秘密，要用暗示的方式，不要直接暴露——除非对话自然发展到该程度。
5. 保持末世废土的氛围。对话要真实、贴近生活，像真实的人在说话。颓废、疲惫、淡淡的死感。不要热血、不要中二、不要励志、不要说教。
6. 不要说"剧本"、"作者"等打破第四面墙的话。
7. 直接说话，不要用括号描述动作、表情或状态（如"（咳嗽）""（微笑）"等）。
8. 如果性格或说话风格没有明确指定，默认使用：疲惫、麻木、对世界不抱期待的普通人风格。"""


func _ready() -> void:
	_create_http_node()
	_load_config()


func _create_http_node() -> void:
	_http_request = HTTPRequest.new()
	_http_request.name = "AIHttpRequest"
	_http_request.timeout = 30.0  # 30
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func _load_config() -> void:
	var config_path := "user://ai_config.json"
	if FileAccess.file_exists(config_path):
		var f := FileAccess.open(config_path, FileAccess.READ)
		if f:
			var json_text := f.get_as_text()
			f.close()
			var json := JSON.new()
			var err := json.parse(json_text)
			if err == OK:
				var data: Dictionary = json.get_data()
				ai_enabled = data.get("enabled", false)
				api_key = data.get("api_key", "")
				api_url = data.get("api_url", "https://api.deepseek.com/v1/chat/completions")
				ai_model = data.get("model", "deepseek-chat")
				ai_temperature = float(data.get("temperature", 0.85))
				ai_max_tokens = int(data.get("max_tokens", 400))
				print("[AI] AI=", "" if ai_enabled else "")
			else:
				print("[AI] ")
	else:
		_save_config()  # 


func _save_config() -> void:
	var data := {
		"enabled": ai_enabled,
		"api_key": api_key,
		"api_url": api_url,
		"model": ai_model,
		"temperature": ai_temperature,
		"max_tokens": ai_max_tokens,
	}
	var json_text := JSON.stringify(data, "  ")
	var f := FileAccess.open("user://ai_config.json", FileAccess.WRITE)
	if f:
		f.store_string(json_text)
		f.close()


## 设置AI配置
func set_config(key_val: Dictionary) -> void:
	for k in key_val:
		match k:
			"enabled": ai_enabled = key_val[k]
			"api_key": api_key = key_val[k]
			"api_url": api_url = key_val[k]
			"model": ai_model = key_val[k]
			"temperature": ai_temperature = float(key_val[k])
			"max_tokens": ai_max_tokens = int(key_val[k])
	_save_config()
	print("[AI] AI已配置, 启用=", "是" if ai_enabled else "否")


## 检查AI是否可用
func is_ai_available() -> bool:
	return ai_enabled and api_key != "" and api_url != ""


## 向AI请求NPC回复（使用独立HTTPRequest避免冲突）
func ask_npc(npc_data: Dictionary, player_message: String, callback: Callable) -> void:
	if not is_ai_available():
		callback.call("", false, "AI不可用，请检查API配置")
		return

	var npc_name: String = npc_data.get("name", "???")
	var personality: String = npc_data.get("personality", "")
	var speaking_style: String = npc_data.get("speaking_style", "")
	var mood: String = npc_data.get("mood", "")
	var background: String = _build_background(npc_data)
	var secret: String = npc_data.get("secret", "")

	# 
	var cache_key := "%s|%s" % [npc_name, player_message.hash()]
	if _response_cache.has(cache_key):
		var cached: Dictionary = _response_cache[cache_key]
		if Time.get_unix_time_from_system() - cached.get("time", 0) < 300:  # 5
			callback.call(cached.get("reply", ""), true, "")
			return

	var system_prompt := PROMPT_SYSTEM.format({
		"name": npc_name,
		"personality": personality,
		"speaking_style": speaking_style,
		"mood": mood,
		"background": background,
		"secret": secret,
	})

	var body := {
		"model": ai_model,
		"temperature": ai_temperature,
		"max_tokens": ai_max_tokens,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": ": " + player_message},
		],
	}

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	])

	# HTTPRequest
	var req := HTTPRequest.new()
	req.name = "AIRequest_%s" % npc_name
	req.timeout = 30.0  # 30
	add_child(req)
	req.request_completed.connect(_on_independent_request_completed.bind(callback, req), CONNECT_ONE_SHOT)
	var err := req.request(api_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		req.queue_free()
		callback.call("", false, "(: %d)" % err)
		return
	
	# 30
	var timer := get_tree().create_timer(35.0)
	timer.timeout.connect(func():
		if is_instance_valid(req):
			req.queue_free()
			callback.call("", false, "")
	, CONNECT_ONE_SHOT)


func _build_background(npc_data: Dictionary) -> String:
	var parts: Array[String] = []
	var backstory: Array = npc_data.get("backstory", [])
	for qa in backstory:
		var q: String = qa.get("q", "")
		var a: String = qa.get("a", "")
		if q != "" and a != "":
			parts.append("%s→ %s" % [q, a])

	var intro: String = npc_data.get("intro", "")
	if intro != "":
		parts.append(": %s" % intro)

	var lines: Array = npc_data.get("lines", [])
	for line in lines:
		var text: String = line.get("text", "")
		if text != "":
			parts.append(": %s" % text)

	var ntype: String = npc_data.get("type", "")
	match ntype:
		"survivor": parts.append("身份: 幸存者")
		"imposter": parts.append("身份: 伪装者（可能有隐藏目的）")
		"hidden_infected": parts.append("身份: 隐藏感染者")
		"zombie": parts.append("身份: 丧尸")

	var reward: String = npc_data.get("reward", "")
	if reward != "":
		var item_name: String = GameManager.ITEM_DATA.get(reward, {}).get("name", reward)
		parts.append(": %s" % item_name)

	return "\n".join(parts)


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_pending = false
	
	# 
	if not _pending_callback.is_valid():
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		var msg := ""
		match result:
			HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: msg = ""
			HTTPRequest.RESULT_CANT_CONNECT: msg = "AI"
			HTTPRequest.RESULT_CANT_RESOLVE: msg = ""
			HTTPRequest.RESULT_CONNECTION_ERROR: msg = ""
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: msg = "SSL/TLS"
			HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: msg = ""
			HTTPRequest.RESULT_REQUEST_FAILED: msg = ""
			HTTPRequest.RESULT_TIMEOUT: msg = ""
		_pending_callback.call("", false, msg)
		return

	var body_str := body.get_string_from_utf8()
	var json := JSON.new()
	var err := json.parse(body_str)
	if err != OK:
		_pending_callback.call("", false, "AI")
		return

	var data: Dictionary = json.get_data()
	if response_code != 200:
		var error_raw = data.get("error", {})
		var error_msg: String
		if error_raw is Dictionary:
			error_msg = error_raw.get("message", "(%d)" % response_code)
		else:
			error_msg = "(%d)" % response_code
		_pending_callback.call("", false, str(error_msg))
		return

	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		_pending_callback.call("", false, "AI")
		return

	var reply: String = choices[0].get("message", {}).get("content", "")
	if reply == "":
		_pending_callback.call("", false, "AI")
		return

	# 
	reply = reply.strip_edges()
	reply = reply.trim_prefix("\"").trim_suffix("\"")

	# 
	var cache_key := ""
	# key
	_pending_callback.call(reply, true, "")


func _on_independent_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, callback: Callable, req_node: HTTPRequest) -> void:
	"""HTTP"""
	req_node.queue_free()
	
	# 
	if not callback.is_valid():
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		var msg := ""
		match result:
			HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: msg = ""
			HTTPRequest.RESULT_CANT_CONNECT: msg = "AI"
			HTTPRequest.RESULT_CANT_RESOLVE: msg = ""
			HTTPRequest.RESULT_CONNECTION_ERROR: msg = ""
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: msg = "SSL/TLS"
			HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: msg = ""
			HTTPRequest.RESULT_REQUEST_FAILED: msg = ""
			HTTPRequest.RESULT_TIMEOUT: msg = ""
		callback.call("", false, msg)
		return

	var body_str := body.get_string_from_utf8()
	var json := JSON.new()
	var err := json.parse(body_str)
	if err != OK:
		callback.call("", false, "AI")
		return

	var data: Dictionary = json.get_data()
	if response_code != 200:
		var error_raw = data.get("error", {})
		var error_msg: String
		if error_raw is Dictionary:
			error_msg = error_raw.get("message", "(%d)" % response_code)
		else:
			error_msg = "(%d)" % response_code
		callback.call("", false, str(error_msg))
		return

	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		callback.call("", false, "AI")
		return

	var reply: String = choices[0].get("message", {}).get("content", "")
	if reply == "":
		callback.call("", false, "AI")
		return

	# 
	reply = reply.strip_edges()
	reply = reply.trim_prefix("\"").trim_suffix("\"")

	callback.call(reply, true, "")


# ========== AI ==========
# /AI
# AI

var _dream_messages: Array = []   #  [{"role":"user"/"assistant", "content":...}]
var _dream_state: Dictionary = {} # 

const DREAM_SYSTEM_PROMPT = """你是一个梦境叙述AI。

你正在为一个末世生存者编织一段梦境。梦境应该反映ta的心理状态。

当前状态：
- 第{day}天
- 屋内人数：{npc_count}
- 道德值：{morality}（负=邪恶，正=善良）
- 理智值：{sanity}/100
- 击杀数：{kills}
- 丧尸等级：Lv.{zombie_level}
- 屋内NPC：{npc_names}

梦境风格指引：
1. 你只需要写一段简短的梦境描述，80-150字左右，像一段小说片段。
2. 参考以下预设梦境格式：
   "你发现自己站在一条没有尽头的走廊里，两侧的门全部紧锁。远处传来若有若无的脚步声。"
   "你在避难所的镜子里看到了自己的倒影。但倒影的动作比你慢了一拍。当你停止动作时，倒影仍然在动。"
3. 梦境应该模糊、跳跃、不合逻辑，像真正的梦。
4. 反映玩家的心理状态——道德低则噩梦，道德高则可能是希望之梦或平静的梦。
5. 不要明确告诉玩家"这是一个梦"——让ta自己去感受。
6. 只输出梦境正文，不要任何前缀、问候语或解释。"""


func start_dream_dialogue(game_state: Dictionary, callback: Callable) -> void:
	""""""
	if not is_ai_available():
		callback.call("", false, "AI")
		return
	if _request_pending:
		callback.call("", false, "...")
		return

	_dream_state = game_state
	_dream_messages.clear()

	var npc_names: String = game_state.get("npc_names", "")
	var system_prompt := DREAM_SYSTEM_PROMPT.format({
		"day": str(game_state.get("day", 0)),
		"npc_count": str(game_state.get("npc_count", 0)),
		"morality": str(game_state.get("morality", 0)),
		"sanity": str(game_state.get("sanity", 50)),
		"kills": str(game_state.get("kills", 0)),
		"zombie_level": str(game_state.get("zombie_level", 1)),
		"npc_names": npc_names,
	})

	_dream_messages.append({"role": "system", "content": system_prompt})

	var body := {
		"model": ai_model,
		"temperature": 0.95,
		"max_tokens": 300,
		"messages": _dream_messages + [
			{"role": "user", "content": "80-150"},
		],
	}

	_pending_callback = func(text: String, success: bool, err: String):
		if success:
			_dream_messages.append({"role": "assistant", "content": text})
		callback.call(text, success, err)

	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func send_dream_message(player_text: String, callback: Callable) -> void:
	"""/AI"""
	if not is_ai_available():
		callback.call("", false, "AI")
		return
	if _request_pending:
		callback.call("", false, "...")
		return

	_dream_messages.append({"role": "user", "content": "" + player_text})

	var turn_count := 0
	for m in _dream_messages:
		if m["role"] == "user":
			turn_count += 1

	# 6
	var extra_instruction := ""
	if turn_count >= 8:
		extra_instruction = "\n"
	elif turn_count >= 6:
		extra_instruction = "\n"

	var body := {
		"model": ai_model,
		"temperature": 0.95,
		"max_tokens": 350,
		"messages": _dream_messages + [
			{"role": "system", "content": "%s50-120%s" % [player_text, extra_instruction]},
		],
	}

	_pending_callback = func(text: String, success: bool, err: String):
		if success:
			_dream_messages.append({"role": "assistant", "content": text})
		callback.call(text, success, err)

	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func end_dream_dialogue(callback: Callable) -> void:
	"""AI"""
	if not is_ai_available():
		callback.call("", false, "AI")
		return
	if _request_pending:
		callback.call("", false, "...")
		return

	var body := {
		"model": ai_model,
		"temperature": 0.9,
		"max_tokens": 300,
		"messages": _dream_messages + [
			{"role": "user", "content": "40-80"},
		],
	}

	_pending_callback = func(text: String, success: bool, err: String):
		if success:
			_dream_messages.append({"role": "assistant", "content": text})
		callback.call(text, success, err)

	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


func clear_dream_dialogue() -> void:
	_dream_messages.clear()
	_dream_state.clear()


# ========== AI生成NPC问题 ==========
const NPC_QUESTION_PROMPT = """你是NPC角色扮演AI。

你要用这个NPC的口吻向玩家提出一个问题。问题应该：
- 名字：{name}
- 类型：{npc_type}（survivor=幸存者, imposter=伪装者, hidden_infected=隐藏感染者, zombie=丧尸）
- 性格：{personality}
- 心情：{mood}
- 背景：{background}

规则：
1. 问题要符合NPC的性格和背景
2. 问题要有末世氛围，真实贴近生活，颓废、疲惫、淡淡的死感。不要日常寒暄，不要热血励志
3. 长度控制在20-50字
4. 只输出问题本身，不要加任何解释或前缀
5. 不要暴露你是AI，不要用"作为NPC"之类的表述
6. 用中文输出"""

func generate_npc_question(npc_data: Dictionary, callback: Callable) -> void:
	if not is_ai_available():
		callback.call("", false, "AI")
		return
	if _request_pending:
		callback.call("", false, "...")
		return

	var npc_name: String = npc_data.get("name", "???")
	var npc_type: String = npc_data.get("type", "survivor")
	var personality: String = npc_data.get("personality", "")
	var mood: String = npc_data.get("mood", "")
	var background: String = _build_background(npc_data)

	var system_prompt := NPC_QUESTION_PROMPT.format({
		"name": npc_name,
		"npc_type": npc_type,
		"personality": personality,
		"mood": mood,
		"background": background,
	})

	var body := {
		"model": ai_model,
		"temperature": 0.9,
		"max_tokens": 150,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": ""},
		],
	}

	_pending_callback = callback
	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


# ========== 屋主盘问问题 ==========
const OWNER_QUESTION_PROMPT = """你是NPC角色扮演AI，扮演一个颓废疲惫的屋主。

你要盘问一个想进屋的陌生人。问题应该：
- 名字：{name}
- 类型：{npc_type}
- 性格：{personality}
- 心情：{mood}
- 背景：{background}

规则：
1. 问题要有末世氛围，体现屋主疲惫而警惕的态度。真实贴近生活，像普通人会问的话
2. 语气颓废、冷漠，带着淡淡的死感。不要热血、不要中二、不要励志、不要说教
3. 长度控制在20-50字
4. 不要提"选项"、"选择"等词
5. 不要暴露你是AI
6. 只输出问题本身"""

func generate_owner_question(npc_data: Dictionary, callback: Callable) -> void:
	"""AI (question_text, success, error_msg)"""
	if not is_ai_available():
		callback.call("", false, "AI")
		return
	if _request_pending:
		callback.call("", false, "...")
		return

	var npc_name: String = npc_data.get("name", "???")
	var npc_type: String = npc_data.get("type", "survivor")
	var personality: String = npc_data.get("personality", "")
	var mood: String = npc_data.get("mood", "")
	var background: String = _build_background(npc_data)

	var system_prompt := OWNER_QUESTION_PROMPT.format({
		"name": npc_name,
		"npc_type": npc_type,
		"personality": personality,
		"mood": mood,
		"background": background,
	})

	var body := {
		"model": ai_model,
		"temperature": 0.85,
		"max_tokens": 120,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": ""},
		],
	}

	_pending_callback = callback
	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


# ========== AI生成NPC回答 ==========
const NPC_ANSWER_PROMPT = """你是NPC角色扮演AI。

根据玩家对NPC问题的回答，生成NPC的反应。

- 名字：{name}
- 类型：{npc_type}
- 性格：{personality}
- 心情：{mood}
- 背景：{background}

NPC问的问题：{last_question}
玩家的回答：{player_answer}

NPC的反应要求：
1. 根据NPC的性格和心情来回应
2. 回复长度控制在30-60字
3. 体现末世废土氛围，真实贴近生活，颓废、疲惫、淡淡的死感。不要热血、不要中二、不要励志
4. 不要暴露你是AI"""

func generate_npc_answer(npc_data: Dictionary, last_question: String, player_answer: String, callback: Callable) -> void:
	if not is_ai_available():
		callback.call("", false, "AI")
		return
	if _request_pending:
		callback.call("", false, "...")
		return

	var npc_name: String = npc_data.get("name", "???")
	var npc_type: String = npc_data.get("type", "survivor")
	var personality: String = npc_data.get("personality", "")
	var mood: String = npc_data.get("mood", "")
	var background: String = _build_background(npc_data)

	var system_prompt := NPC_ANSWER_PROMPT.format({
		"name": npc_name,
		"npc_type": npc_type,
		"personality": personality,
		"mood": mood,
		"background": background,
		"last_question": last_question,
		"player_answer": player_answer,
	})

	var body := {
		"model": ai_model,
		"temperature": 0.9,
		"max_tokens": 200,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": ""},
		],
	}

	_pending_callback = callback
	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


# ========== AI结局评价系统 ==========
const ENDING_SYSTEM_PROMPT = """你是一位末日幸存者的叙事者。请根据以下游戏数据，为玩家生成一段150-250字的个性化结局叙事。

游戏状态：
- 存活天数：第{day}天
- 避难所人数：{npc_count}人
- 道德值：{morality}（正值为善良，负值为邪恶）
- 理智值：{sanity}/100
- 击杀人类次数：{kills}
- 丧尸威胁等级：Lv.{zombie_level}
- 房门耐久：{door_hp}/{door_max}
- 避难所NPC：{npc_names}
- 妹妹状态：{sister_status}
- 已杀死NPC：{killed_names}
- 结局名称：{ending_title}

要求：
1. 以第二人称"你"叙事，语气沉静、富有哲思
2. 结合具体数值（道德高低、击杀数、NPC名字）生成个性化内容
3. 风格：恐怖末日文学，有画面感，不要鸡汤
4. 如果道德极低或击杀数多，描述角色的堕落和孤独
5. 如果道德高且保护了多人，描述人性在黑暗中闪耀
6. 如果理智值很低，描述精神崩溃边缘的幻觉和挣扎
7. 如果只有一个人或没有人，描述极致的孤独
8. 提及妹妹的状态（如果存在）
9. 字数：150-250字，不要超过
10. 直接输出结局叙事，不要带任何前缀说明"""

func generate_ending(game_state: Dictionary, callback: Callable) -> void:
	if not is_ai_available():
		callback.call("", false, "AI未配置")
		return
	if _request_pending:
		callback.call("", false, "请求进行中...")
		return

	var system_prompt := ENDING_SYSTEM_PROMPT.format({
		"day": str(game_state.get("day", 5)),
		"npc_count": str(game_state.get("npc_count", 0)),
		"morality": str(game_state.get("morality", 0)),
		"sanity": str(game_state.get("sanity", 50)),
		"kills": str(game_state.get("kills", 0)),
		"zombie_level": str(game_state.get("zombie_level", 1)),
		"door_hp": str(game_state.get("door_hp", 0)),
		"door_max": str(game_state.get("door_max", 100)),
		"npc_names": game_state.get("npc_names", "无"),
		"sister_status": game_state.get("sister_status", "未知"),
		"killed_names": game_state.get("killed_names", "无"),
		"ending_title": game_state.get("ending_title", ""),
	})

	var body := {
		"model": ai_model,
		"temperature": 0.9,
		"max_tokens": 600,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": ""},
		],
	}

	_pending_callback = callback
	_request_pending = true
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	_http_request.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))


# ========== AI ==========
const JUDGE_QA_PROMPT = """你是一个末日幸存者NPC。根据以下角色设定，评判玩家对你的问题的回答：

角色设定：
- 名字：{name}
- 类型：{npc_type}
- 性格：{personality}
- 心情：{mood}
- 背景：{background}

你问的问题是：{question}
玩家的回答是：{player_answer}

请以这个NPC的口吻做出反应。要求：
- 语气颓废、疲惫、带着淡淡的死感。真实贴近生活，不要热血、不要中二、不要励志、不要说教
- reaction：NPC对玩家回答的口头反应，20-50字

输出JSON格式：
{{"verdict":"good|bad","reaction":"NPC的口头反应，20-50字"}}

说明：
- good：回答让你觉得可以信任或产生了共鸣
- bad：回答让你更加警惕或失望

注意：
- reaction必须是NPC直接说的话，不要括号描述
- 只输出JSON"""

func judge_npc_qa(npc_data: Dictionary, question: String, player_answer: String, callback: Callable) -> void:
	"""AI (npc_reply, verdict, success, error)
	callback: func(reply: String, verdict: String, success: bool, error_msg: String)"""
	if not is_ai_available():
		callback.call("", "bad", false, "AI")
		return

	var npc_name: String = npc_data.get("name", "???")
	var npc_type: String = npc_data.get("type", "survivor")
	var personality: String = npc_data.get("personality", "")
	var mood: String = npc_data.get("mood", "")
	var background: String = _build_background(npc_data)

	var system_prompt := JUDGE_QA_PROMPT.format({
		"name": npc_name,
		"npc_type": npc_type,
		"personality": personality,
		"mood": mood,
		"background": background,
		"question": question,
		"player_answer": player_answer,
	})

	var body := {
		"model": ai_model,
		"temperature": 0.5,  # 
		"max_tokens": 200,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": "JSON"},
		],
	}

	# HTTPRequest
	var req := HTTPRequest.new()
	req.name = "AIJudge_%s" % npc_name
	req.timeout = 30.0  # 30
	add_child(req)

	# AIJSON
	var wrapped_callback = func(text: String, success: bool, err: String):
		if not success:
			callback.call(text, "bad", false, err)
			return
		var parsed := _parse_judge_response(text)
		callback.call(parsed["reaction"], parsed["verdict"], true, "")

	req.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, resp_body: PackedByteArray):
		_on_independent_request_completed(result, response_code, headers, resp_body, wrapped_callback, req)
	, CONNECT_ONE_SHOT)

	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + api_key])
	var err := req.request(api_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		req.queue_free()
		callback.call("", "bad", false, "(: %d)" % err)
		return
	
	# 35
	var timer := get_tree().create_timer(35.0)
	timer.timeout.connect(func():
		if is_instance_valid(req):
			req.queue_free()
			callback.call("", "bad", false, "")
	, CONNECT_ONE_SHOT)


func _parse_judge_response(raw_text: String) -> Dictionary:
	"""AIverdictreaction"""
	var default := {"verdict": "bad", "reaction": raw_text.strip_edges() if raw_text != "" else "..."}
	if raw_text == "":
		return default

	# JSON```json
	var json_str := raw_text.strip_edges()
	
	# markdown
	for marker in ["```json", "```"]:
		if json_str.begins_with(marker):
			json_str = json_str.substr(marker.length())
		if json_str.ends_with("```"):
			json_str = json_str.substr(0, json_str.length() - 3).strip_edges()

	#  {  }
	var start_idx := json_str.find("{")
	var end_idx := json_str.rfind("}")
	if start_idx < 0 or end_idx < 0:
		return default
	json_str = json_str.substr(start_idx, end_idx - start_idx + 1)

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK:
		return default

	var data: Dictionary = json.get_data()
	var verdict: String = str(data.get("verdict", "bad")).to_lower()
	var reaction: String = str(data.get("reaction", raw_text)).strip_edges()
	if verdict != "good":
		verdict = "bad"
	if reaction == "":
		reaction = raw_text.strip_edges()
	return {"verdict": verdict, "reaction": reaction}


## 
func clear_cache() -> void:
	_response_cache.clear()


## 
var _conversation_history: Dictionary = {}  # npc_name -> Array[{"role":..., "content":...}]

func get_history(npc_name: String) -> Array:
	return _conversation_history.get(npc_name, [])

func add_to_history(npc_name: String, role: String, content: String) -> void:
	if not _conversation_history.has(npc_name):
		_conversation_history[npc_name] = []
	_conversation_history[npc_name].append({"role": role, "content": content})

func clear_history(npc_name: String) -> void:
	_conversation_history.erase(npc_name)
