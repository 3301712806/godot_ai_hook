# test.gd
## 函数目录
# - _ready--初始化测试面板并绑定按钮信号
# - _load_from_config--从 AiConfig 读取初始模型与连接配置
# - _apply_temp_config--将 UI 输入临时写入 AiConfig 并做非空校验
# - _on_connect_test_pressed--执行一次非流式连通性测试
# - _on_connect_result--处理连通性测试的 HTTP 返回结果
# - _on_test_chat_pressed--顺序触发多种控件的效果测试及中断测试
# - _safe_free_http--安全释放测试用 HTTPRequest 节点
# - _log--向日志输出区域追加一行文本
# - _clear_log--清空日志输出内容
# 说明：用于在场景中可视化测试 AI 连接（API Key / Model / URL）
# 1. 输入配置并临时覆盖 AiConfig
# 2. 一键连接测试（非流式 HTTPRequest）
# 3. 一键效果测试（调用已挂载的 AiManage，流式 / 非流式）

extends Control

# =====================
# UI 节点（场景中需对应）
# =====================
@onready var model_input: LineEdit = $VBoxContainer/GridContainer/LineEdit
@onready var url_input: LineEdit = $VBoxContainer/GridContainer/LineEdit2
@onready var api_key_input: LineEdit = $VBoxContainer/GridContainer/LineEdit3

@onready var connect_btn: Button = $VBoxContainer/GridContainer/Button
@onready var test_chat_btn: Button = $VBoxContainer/GridContainer/Button2
@onready var connect_state_label: Label = $VBoxContainer/GridContainer/Label5

@onready var log_view: TextEdit = $VBoxContainer/TextEdit # 总体日志输出

# =====================
# 测试节点（均挂载 AiManage）
# =====================
@onready var test1 = $VBoxContainer/ScrollContainer/GridContainer2/LineEdit
@onready var test1_ai: AiManage = $VBoxContainer/ScrollContainer/GridContainer2/LineEdit/AiManage

@onready var test2 = $VBoxContainer/ScrollContainer/GridContainer2/RichTextLabel
@onready var test2_ai: AiManage = $VBoxContainer/ScrollContainer/GridContainer2/RichTextLabel/AiManage

@onready var test3 = $VBoxContainer/ScrollContainer/GridContainer2/CodeEdit
@onready var test3_ai: AiManage = $VBoxContainer/ScrollContainer/GridContainer2/CodeEdit/AiManage

@onready var test4 = $VBoxContainer/ScrollContainer/GridContainer2/TextEdit
@onready var test4_ai: AiManage = $VBoxContainer/ScrollContainer/GridContainer2/TextEdit/AiManage
@onready var not_stream =$VBoxContainer/ScrollContainer/GridContainer2/LineEdit4
@onready var not_stream_ai = $VBoxContainer/ScrollContainer/GridContainer2/LineEdit4/AiManage
@onready var err_test = $VBoxContainer/ScrollContainer/GridContainer2/LineEdit5
@onready var err_test_ai =  $VBoxContainer/ScrollContainer/GridContainer2/LineEdit5/AiManage
@onready var append_interval_time_box = $VBoxContainer/GridContainer/SpinBox
@onready var sentence_pause_extra_box = $VBoxContainer/GridContainer/SpinBox2
@onready var is_clean_before_reply_box: CheckBox = $VBoxContainer/GridContainer/CheckBox
# =====================
# 运行时变量
# =====================
@onready var append_interval_time = AiConfig.append_interval_time

#测试时，单词、句子停顿的步长最低为0.01s
@onready var  sentence_pause_extra = AiConfig.sentence_pause_extra
#测试用例之间的间隔
@export var interruption_time = 4#测试中断时间
@export var protect_time = 2#一些厂商会限制访问速度。
var _http: HTTPRequest = null


# 初始化测试面板，绑定按钮信号并加载初始配置
func _ready() -> void:
	is_clean_before_reply_box.button_pressed = AiConfig.is_clean_before_reply
	connect_btn.pressed.connect(_on_connect_test_pressed)
	test_chat_btn.pressed.connect(_on_test_chat_pressed)
	_load_from_config()
	_log("[Init] AI Connection Test Ready")


# =====================
# 配置读取 / 覆盖
# =====================
# 从 AiConfig 读取当前模型、URL 与密钥到输入框
func _load_from_config():
	model_input.text = AiConfig.model
	url_input.text = AiConfig.url
	api_key_input.text = AiConfig.api_key
	append_interval_time_box.value = AiConfig.append_interval_time
	sentence_pause_extra_box.value = AiConfig.sentence_pause_extra
	


# 将输入框中的配置写回 AiConfig，并做非空校验
func _apply_temp_config() -> bool:
	var model := model_input.text.strip_edges()
	var url := url_input.text.strip_edges()
	var api_key := api_key_input.text.strip_edges()
	var typing_interval := float(append_interval_time_box.value)
	var sentence_pause := float(sentence_pause_extra_box.value)


	if model.is_empty() or url.is_empty() or api_key.is_empty():
		_log("[Error] Model / URL / API Key 不能为空")
		return false

	if typing_interval < 0.0 or sentence_pause < 0.0:
		_log("[Error] 打字间隔 / 句子停顿 不能为负数")
		return false

	# 临时覆盖（仅测试用）
	AiConfig.model = model
	AiConfig.url = url
	AiConfig.api_key = api_key
	AiConfig.append_interval_time = typing_interval
	AiConfig.sentence_pause_extra = sentence_pause
	return true


# =====================
# 一键连接测试（非流式）
# =====================
# 使用 HTTPRequest 向当前配置的模型发送 ping 请求，验证连通性
func _on_connect_test_pressed():
	_clear_log()
	connect_state_label.text = "测试中..."

	if not _apply_temp_config():
		connect_state_label.text = "配置错误"
		return

	_log("[Test] 开始连接测试")

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_connect_result)

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % AiConfig.api_key
	]

	var body := {
		"model": AiConfig.model,
		"messages": [
			{"role": "user", "content": "ping"}
		]
	}

	var err := _http.request(
		AiConfig.url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)

	if err != OK:
		_log("[Error] HTTP 请求启动失败: " + str(err))
		connect_state_label.text = "启动失败"


# 处理连通性测试的 HTTP 返回结果并更新界面状态
func _on_connect_result(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("[Fail] 网络层失败 result=" + str(result))
		connect_state_label.text = "网络失败"
		_safe_free_http()
		return

	_log("[HTTP] response_code=" + str(response_code))

	if response_code == 200:
		_log("[OK] 连接成功，API 可用")
		connect_state_label.text = "连接成功"
	else:
		_log("[Fail] 连接失败，返回内容：")
		_log(body.get_string_from_utf8())
		connect_state_label.text = "连接失败"

	_safe_free_http()


# =====================
# 一键效果测试（AiManage）
# =====================
# 依次触发多种展示控件的生成测试，并附带一次中断行为测试
func _on_test_chat_pressed():
	_log("\n[Test] 开始效果测试（AiManage）")

	if not _apply_temp_config():
		return

	var clean_before_reply := is_clean_before_reply_box.button_pressed
	_log("[Test] 打字间隔=%.2f, 句子停顿=%.2f, 清空前文=%s" % [AiConfig.append_interval_time, AiConfig.sentence_pause_extra, str(clean_before_reply)])

	test1_ai.set_clean_before_reply(clean_before_reply)
	test2_ai.set_clean_before_reply(clean_before_reply)
	test3_ai.set_clean_before_reply(clean_before_reply)
	test4_ai.set_clean_before_reply(clean_before_reply)
	not_stream_ai.set_clean_before_reply(clean_before_reply)
	err_test_ai.set_clean_before_reply(clean_before_reply)

	# 统一触发生成
	var prompt := "这是一个连接与显示测试，请简短回复。"
	
	test1_ai.say(prompt)
	await get_tree().create_timer(protect_time).timeout
	test2_ai.say(prompt)
	await get_tree().create_timer(protect_time).timeout
	test3_ai.say(prompt)
	await get_tree().create_timer(protect_time).timeout
	test4_ai.say(prompt)
	await get_tree().create_timer(protect_time).timeout
	not_stream_ai.set_ai_stream_type(false)
	not_stream_ai.say(prompt)
	
	 # 中断测试逻辑
	if not is_instance_valid(err_test_ai) or err_test_ai.get_parent() == null:
	 # AiManage 已经不在节点树里
		err_test.text = "节点销毁，下面为中断后内容:\n" + err_test.text
		return

	# 还有有效 AiManage，开始一次长文本测试并在 3 秒后中断
	err_test.text = ""
	err_test_ai.say("请生成长文章，越长越好")

	await get_tree().create_timer(interruption_time).timeout

	if is_instance_valid(err_test_ai):
		err_test_ai.queue_free()
	
	

# =====================
# 工具函数
# =====================
# 安全释放测试用 HTTPRequest 节点
func _safe_free_http():
	if _http and is_instance_valid(_http):
		_http.queue_free()
	_http = null


# 向日志输出区域追加一行文本
func _log(text: String):
	log_view.text += text + "\n"


# 清空日志输出
func _clear_log():
	log_view.text = ""
