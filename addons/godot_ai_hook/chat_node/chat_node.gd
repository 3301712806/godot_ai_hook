class_name ChatNode
extends Node

# chat_node.gd
## 函数目录
# - set_system_prompt--设置当前请求使用的系统提示词
# - _load_config--从 AiConfig 同步最新的模型与接口配置
# - send_chat_request--构建并发送一次非流式 HTTP 请求
# - _on_request_completed--处理 HTTP 响应并解析模型结果
# - _safe_free_client--安全释放 HTTPRequest 节点引用

# API 配置常量
var url: String
var api_key: String
var model: String
@onready var parent = get_parent()

var system_prompt := ""
var client: HTTPRequest = null


# 设置当前请求使用的系统提示词
func set_system_prompt(prompt):
	system_prompt = prompt

# 从 AiConfig 同步最新的 api_key / model / url，可重定向配置来源
func _load_config():
	api_key = AiConfig.api_key
	model = AiConfig.model
	url = AiConfig.url

# 构建并发送一次非流式 HTTP 请求到模型服务
func send_chat_request(content: String):
	_load_config()

	# -------- 基础参数校验 --------
	if api_key.is_empty():
		parent.on_ai_error_occurred("API_KEY 为空")
		return

	if url.is_empty():
		parent.on_ai_error_occurred("API URL 为空")
		return

	if model.is_empty():
		parent.on_ai_error_occurred("Model 为空")
		return

	if content.is_empty():
		parent.on_ai_error_occurred("发送内容为空")
		return

	# -------- 创建 HTTPRequest --------
	client = HTTPRequest.new()
	add_child(client)
	client.request_completed.connect(_on_request_completed)

	# -------- 构建请求 --------
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	var body := {
		"model": model,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": content}
		]
	}

	var json_body := JSON.stringify(body)

	# -------- 发起请求 --------
	var err := client.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

	if err != OK:
		parent.on_ai_error_occurred(
			"HTTP 请求启动失败，错误码: " + str(err)
		)
		_safe_free_client()


# 处理 HTTPRequest 完成信号，校验并解析响应数据
func _on_request_completed(result, response_code, headers, body):
	# -------- 请求层失败 --------
	if result != HTTPRequest.RESULT_SUCCESS:
		parent.on_ai_error_occurred(
			"HTTP 请求失败 result=" + str(result)
		)
		_safe_free_client()
		return

	# -------- HTTP 状态码判断 --------
	if response_code != 200:
		var err_text = body.get_string_from_utf8()
		parent.on_ai_error_occurred(
			"HTTP 错误码: %d\n%s" % [response_code, err_text]
		)
		_safe_free_client()
		return

	# -------- 响应体解析 --------
	var text = body.get_string_from_utf8()
	if text.is_empty():
		parent.on_ai_error_occurred("返回内容为空")
		_safe_free_client()
		return

	var json := JSON.new()
	var parse_result := json.parse(text)
	if parse_result != OK:
		parent.on_ai_error_occurred(
			"JSON 解析失败: " + str(parse_result)
		)
		_safe_free_client()
		return

	var data = json.get_data()

	# -------- 结构防御 --------
	if not data.has("choices"):
		parent.on_ai_error_occurred("响应缺少 choices 字段")
		_safe_free_client()
		return

	if data["choices"].is_empty():
		parent.on_ai_error_occurred("choices 为空")
		_safe_free_client()
		return

	var choice = data["choices"][0]
	if not choice.has("message") or not choice["message"].has("content"):
		parent.on_ai_error_occurred("响应结构不完整")
		_safe_free_client()
		return

	# -------- 成功路径（原逻辑）--------
	var message_content = choice["message"]["content"]
	parent.on_ai_content_generated(message_content)
	parent.on_ai_generation_finished()

	_safe_free_client()


# 安全释放 HTTPRequest 节点，避免悬挂引用
func _safe_free_client():
	if client and is_instance_valid(client):
		client.queue_free()
	client = null
