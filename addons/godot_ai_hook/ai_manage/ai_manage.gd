extends Node
class_name AiManage

# ai_manage.gd
## 函数目录
# - say--使用给定内容和系统提示词发送一次 AI 请求
# - say_bind_key--通过配置中的 key 选择系统提示词并发送请求
# - _ready--节点进入场景时初始化，默认启用流式模式
# - set_ai_stream_type--在流式/非流式之间切换并重建内部节点
# - set_finished_transfer--更新当前是否在传输中的标记
# - get_finished_transfer_state--获取当前传输状态标记
# - send_chat_request--把请求广播给内部子节点并做并发与可用性检查
# - on_ai_request_started--标记一次新请求开始
# - _process--逐帧处理打字缓冲并按间隔输出字符
# - _enqueue_text--将模型输出加入打字缓冲
# - _append_text_safe--根据父节点类型安全地追加显示文本
# - on_ai_reasoning_content_generated--处理模型推理过程内容并输出
# - on_ai_content_generated--处理模型正式回复内容并输出
# - on_ai_generation_finished--在生成结束时重置传输状态
# - on_ai_error_occurred--统一处理并上报 AI 相关错误
# - cancel_ai_transfer--取消当前所有流式/非流式传输并清理资源
# - _exit_tree--节点被移除场景树时自动取消所有传输

@onready var chat_node_scene: PackedScene = preload("res://addons/godot_ai_hook/chat_node/chat_node.tscn")
@onready var chat_stream_node_scene: PackedScene = preload("res://addons/godot_ai_hook/chat_stream_node/chat_stream_node.tscn")

var chat_node: Node = null
var chat_stream_node: Node = null

@onready var parent = get_parent()

var system_prompt: String = ""
var is_finished_transfer := true
var typing_interval
var sentence_pause_extra
var append_buffer: String = ""
var _append_accumulator: float = 0.0
var _is_typing: bool = false
var is_clean_before_reply:bool = true
var model_para:Dictionary


	
# 使用给定内容和系统提示词触发一次 AI 请求
func say(content:String,system_prompt:String=""):
	send_chat_request(content, system_prompt)

# 通过配置表中的 key 选择系统提示词并发送请求
func say_bind_key(content:String,key:String):
	if content.is_empty(): 
		push_error("Content to send is empty")
		return 
	if key == null or key.is_empty():
		push_error("system_prompt key is empty")
		return
	system_prompt = SystemPromptConfig.system_prompt_dic.get(key,"")
	if system_prompt is not String:
		push_error("system_prompt must be a String, please check the value for this key in SystemPromptConfig.system_prompt_dic")
		return
	if system_prompt.is_empty() :
		push_error("SystemPromptConfig dictionary does not contain key %s"%key)
		return
	say(content,system_prompt)




# 节点进入场景树时初始化，默认启用流式生成模式
func _ready() -> void:
	# 默认流式
	set_ai_stream_type(true)
	_init_model_para_from_ai_config()
	
func set_clean_before_reply(is_true:bool):
	is_clean_before_reply =is_true
# 在流式 / 非流式模式间切换，并重建内部 Chat 节点
func set_ai_stream_type(is_true):
	# 如果正在生成，先标记结束，防止卡死
	if not is_finished_transfer:
		set_finished_transfer(true)


	# 安全清理旧节点
	for child in get_children():
		if is_instance_valid(child):
			child.queue_free()

	chat_node = null
	chat_stream_node = null

	# 实例化新节点
	if is_true:
		if chat_stream_node_scene == null:
			push_error("chat_stream_node_scene is not set")
			return
		chat_stream_node = chat_stream_node_scene.instantiate()
		add_child(chat_stream_node)
	else:
		if chat_node_scene == null:
			push_error("chat_node_scene is not set")
			return
		chat_node = chat_node_scene.instantiate()
		add_child(chat_node)


# 设置当前是否处于 AI 传输中的状态标记
func set_finished_transfer(is_true):
	is_finished_transfer = is_true

# 获取当前 AI 传输状态标记
func get_finished_transfer_state():
	return is_finished_transfer

	
# 将聊天请求广播给内部子节点，并做并发与可用性检查
func send_chat_request(content, system_prompt):
	typing_interval = AiConfig.append_interval_time
	sentence_pause_extra = AiConfig.sentence_pause_extra
	if is_clean_before_reply == true:
		clean_parent_text_content()
	# 防止重复请求
	if not is_finished_transfer:
		on_ai_error_occurred("AI is already generating")
		return

	on_ai_request_started()

	var has_sender := false

	for child in get_children():
		if not is_instance_valid(child):
			continue

		if not child.has_method("set_system_prompt") \
		or not child.has_method("send_chat_request"):
			continue

		child.set_system_prompt(system_prompt)
		child.set_model_para(model_para)
		child.send_chat_request(content)
		has_sender = true

	if not has_sender:
		on_ai_error_occurred("No available ChatNode found")
		return


# 在一次 AI 请求开始时更新状态
func on_ai_request_started():
	set_finished_transfer(false)

# 逐帧处理打字缓冲，将字符按设定间隔输出到父节点
func _process(delta: float) -> void:
	if not _is_typing:
		set_process(false)
		return

	if append_buffer.is_empty():
		_is_typing = false
		set_process(false)
		return

	_append_accumulator += delta
	if _append_accumulator < typing_interval:
		return
	var ch := append_buffer.substr(0, 1)
	append_buffer = append_buffer.substr(1)
	_append_text_safe(ch)

	if ch == "." or ch == "。" or ch == "!" or ch == "！" or ch == "?" or ch == "？":
		_append_accumulator = -sentence_pause_extra
	else:
		_append_accumulator = 0.0


# 将新文本加入打字缓冲，并启动打字机式输出
func _enqueue_text(text: String):
	if text == null or text.is_empty():
		return
	append_buffer += text
	if not _is_typing:
		_is_typing = true
		set_process(true)

# 判断节点是否具备文本读写能力
func _has_text_interface(node: Object) -> bool:
	return node != null \
		and node.has_method("set_text") \
		and node.has_method("get_text") \
		and typeof(node.get_text()) == TYPE_STRING
# 清空父节点的文本内容
func clean_parent_text_content():
	if parent == null:
		push_error("AiManage: parent is null, cannot clear text")
		return

	# 优先使用 set_text 接口：适用于 Label/LineEdit/TextEdit/RichTextLabel 以及自定义控件
	if _has_text_interface(parent):
		parent.set_text("")
		return

	# 某些控件只提供 clear() 来清空，例如你自己写的控件
	if parent.has_method("clear"):
		parent.clear()
		return

	push_error("AiManage: parent type does not support clearing text, type = " + parent.get_class() + "\nYou can implement clear logic for this node type in ai_manage.gd")

# 根据父节点控件类型安全地立即追加一段文本
func _append_text_safe(text: String):
	if parent == null:
		push_error("AiManage: parent is null")
		return

	# 通用 set_text/get_text 接口
	if _has_text_interface(parent):
		var old_text = parent.get_text()
		if old_text == null:
			old_text = ""
		parent.set_text(str(old_text) + text)
		return

	# 某些控件有 append_text（如 RichTextLabel）
	if parent.has_method("append_text"):
		parent.append_text(text)
		return

	push_error(
		"AiManage: parent does not support appending text, type = " + parent.get_class() + "\nYou can implement append logic for this node type in ai_manage.gd"
	)

# 处理模型的推理过程内容并加入打字缓冲
func on_ai_reasoning_content_generated(reasoning_content):
	_enqueue_text(reasoning_content)


# 处理模型的正式回复内容并加入打字缓冲
func on_ai_content_generated(content):
	_enqueue_text(content)


# 在 AI 生成结束时重置传输状态
func on_ai_generation_finished():
	set_finished_transfer(true)


# 在出现 AI 相关错误时重置状态并打印错误信息
func on_ai_error_occurred(err_msg):
	set_finished_transfer(true)
	_is_typing = false
	append_buffer = ""
	set_process(false)
	push_error("AI Error: " + str(err_msg))

# 取消当前所有流式/非流式 AI 传输，并尝试释放资源
func cancel_ai_transfer():
	is_finished_transfer = true

	for child in get_children():
		if not is_instance_valid(child):
			continue
		if child.has_method("_stop_stream"):
			# 流式节点：停止流
			child._stop_stream()
		if child.has_method("_safe_free_client"):
			# 非流式节点：释放 HTTPRequest
			child._safe_free_client()
# 当节点离开场景树时自动取消所有 AI 传输
func _exit_tree() -> void:
	cancel_ai_transfer()
	
	
#统一管理通用配置
func _init_model_para_from_ai_config():
	model_para = AiConfig.model_para
#set model para很多模型在开启 response_format: { "type": "json_object" } 时，要求提示词中必须包含 "json" 关键词
func set_response_format_is_json(flat:bool):
	if flat == true:
		model_para.set("response_format",{"type":"json_object"})
	else :
		model_para.set("response_format",{"type":"text"})
