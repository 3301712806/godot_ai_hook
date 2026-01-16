extends Node

# chat_stream_node.gd
## 函数目录
# - set_system_prompt--设置当前请求使用的系统提示词
# - _load_config--从 AiConfig 同步最新的流式接口配置
# - send_chat_request--建立流式连接并开始一轮 SSE 聊天请求
# - _process--每帧轮询 HTTPClient 状态并处理超时与数据
# - _send_request--在连接建立后发送带 stream 标记的请求体
# - _read_stream_body--持续读取响应 body 并按块交给解析函数
# - _on_data--按行解析 SSE 文本并提取 data 负载
# - _handle_chunk--解析单个 JSON 块并分发给 AiManage
# - _stop_stream--停止流式轮询并关闭底层连接

@onready var parent = get_parent()

var api_key: String 
var model: String 
var host: String 
var path: String 
var port: int 

const STREAM_TIMEOUT := 20.0 # 秒

var _last_data_time := 0.0

var system_prompt := ""
var content := ""

var client := HTTPClient.new()
var buffer := ""

var _request_sent := false


# 设置当前请求使用的系统提示词
func set_system_prompt(prompt):
	system_prompt = prompt

# 从 AiConfig 同步最新的 api_key / model / host / path / port，可重定向配置来源
func _load_config():
	api_key = AiConfig.api_key
	model = AiConfig.model
	host= AiConfig.get_stream_url_host()
	path = AiConfig.get_stream_url_path()
	port = AiConfig.port
	
# 构建并发送一次流式请求，建立 HTTPClient 连接并开启轮询
func send_chat_request(content):
	_load_config()
	_last_data_time = Time.get_unix_time_from_system()

	self.content = content

	# -------- 基础参数校验 --------
	if api_key.is_empty():
		parent.on_ai_error_occurred("API_KEY 未设置")
		return

	if host.is_empty() or path.is_empty():
		parent.on_ai_error_occurred("Stream URL 配置错误")
		return

	if model.is_empty():
		parent.on_ai_error_occurred("Model 未设置")
		return

	if content.is_empty():
		parent.on_ai_error_occurred("发送内容为空")
		return

	# -------- 重置状态 --------
	buffer = ""
	_request_sent = false

	# -------- 建立连接 --------
	var err := client.connect_to_host(host, port, TLSOptions.client())
	if err != OK:
		parent.on_ai_error_occurred("连接主机失败: " + str(err))
		return

	set_process(true)


# 每帧轮询 HTTPClient 状态，处理超时、发送请求与读取数据
func _process(_delta):
	client.poll()
	# ⏱️ 超时检测
	if _last_data_time == 0:
		return
	if Time.get_unix_time_from_system() - _last_data_time > STREAM_TIMEOUT:
		parent.on_ai_error_occurred("AI 响应超时")
		_stop_stream()
		return
	match client.get_status():
		HTTPClient.STATUS_CONNECTING:
			pass

		HTTPClient.STATUS_CONNECTED:
			if not _request_sent:
				_send_request()

		HTTPClient.STATUS_REQUESTING:
			pass

		HTTPClient.STATUS_BODY:
			_read_stream_body()

		HTTPClient.STATUS_DISCONNECTED:
			parent.on_ai_error_occurred("连接中断")
			_stop_stream()

		_:
			pass


func _send_request():
	_request_sent = true

	var body := {
		"model": model,
		"stream": true,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": content}
		]
		
	}

	var headers := [
		"Host: %s" % host,
		"Content-Type: application/json",
		"Authorization: Bearer %s" % api_key,
		"Accept: text/event-stream"
	]

	var err := client.request(
		HTTPClient.METHOD_POST,
		path,
		headers,
		JSON.stringify(body)
	)

	if err != OK:
		parent.on_ai_error_occurred("请求发送失败: " + str(err))
		_stop_stream()


# 循环读取响应 body，将多次读取的字节流按块交给 _on_data 解析
# 注意：HTTPClient 可能一次只返回部分数据，这里通过循环与等待确保读完当前可用内容
func _read_stream_body():
	while true:
		# 等待状态进入 STATUS_BODY，保证可以安全读取响应体
		while client.get_status() != HTTPClient.STATUS_BODY:
			await get_tree().process_frame

		var chunk = client.read_response_body_chunk()
		# 如果本轮没有更多数据，跳出循环，等待下一帧再次进入 _read_stream_body
		if chunk.is_empty():
			break
		# 将读取到的一小块数据交给 _on_data 做文本拼接与逐行解析
		_on_data(chunk)


# 处理从服务器收到的一块字节数据，完成文本拼接与 SSE 行级解析
func _on_data(data: PackedByteArray):
	_last_data_time = Time.get_unix_time_from_system()

	var text := data.get_string_from_utf8()
	if text.is_empty():
		return

	buffer += text

	while buffer.find("\n") != -1:
		var i := buffer.find("\n")
		var line := buffer.substr(0, i).strip_edges()
		buffer = buffer.substr(i + 1)
		if line.is_empty():
			continue

		if not line.begins_with("data:"):
			continue

		var payload := line.substr(5).strip_edges()
		if payload == "[DONE]":
			parent.on_ai_generation_finished()
			_stop_stream()
			return

		_handle_chunk(payload)


# 解析单个 JSON 块，并将内容分发给 AiManage 回调
func _handle_chunk(json_text: String):
	var result = JSON.parse_string(json_text)
	if typeof(result) != TYPE_DICTIONARY:
		return

	if not result.has("choices") or result["choices"].is_empty():
		return

	var choice = result["choices"][0]
	if not choice.has("delta"):
		return

	var delta = choice["delta"]

	if typeof(delta) != TYPE_DICTIONARY:
		return

	if delta.has("reasoning_content"):
		parent.on_ai_reasoning_content_generated(delta["reasoning_content"])
	elif delta.has("content"):
		parent.on_ai_content_generated(delta["content"])


# 停止流式轮询并关闭底层 HTTP 连接
func _stop_stream():
	set_process(false)
	if client.get_status() != HTTPClient.STATUS_DISCONNECTED:
		client.close()
