class_name AiConfig
########################################################
############## 在这里填写你自己的模型配置 ################
# 1. url：填入兼容 OpenAI Chat Completions 的接口地址
static var url: String = "https://api.deepseek.com/chat/completions"

# 2. api_key：在本地项目中填写自己的密钥
#    请务必不要将真实密钥提交到公开仓库或截图中泄露

# 3. model：要使用的模型名称（参考服务商文档），修改下面的model_para
###||
###\/

# port：流式模式使用的端口，HTTPS 一般为 443
static var port:int = 443
########################################################

## AI API 调用参数配置字典
## 包含了主流大模型（GPT, DeepSeek, Claude, Qwen）通用的请求参数
static var model_para = {
	# --- 核心生成参数 ---
	
	"model": "deepseek-chat", # 指定使用的模型名称。可选值：deepseek-chat, deepseek-reasoner, gpt-4o, qwen-plus 等。
	
	"temperature": 1.0,       # 温度：控制回复的随机性。
							  # 可选值：0.0 ~ 2.0。0.0近乎确定（适合代码/逻辑），1.0+更具创意（适合小说/聊天）。
	
	"top_p": 1.0,             # 核采样：控制词汇的多样性。
							  # 可选值：0.0 ~ 1.0。0.1表示只从概率前10%的词中选。通常与 temperature 二选一调整。
	
	"max_tokens": 1024,       # 最大生成 Token 数：限制回答的总长度。
							  # 可选值：取决于模型窗口（通常1~4096，部分模型支持更长）。注意：设置过低可能导致 JSON 截断报错。
	
	# --- 行为控制参数 ---
	
	"stop": null,             # 停止符：遇到这些词时 AI 自动闭嘴。
							  # 可选值：null 或 数组 ["###", "End"]。常用于防止 AI 自言自语。
	
	"presence_penalty": 0.0,  # 话题新鲜度：惩罚已出现的话题，鼓励 AI 谈论新内容。
							  # 可选值：-2.0 ~ 2.0。正值越高，越不容易跑题或重复。
	
	"frequency_penalty": 0.0, # 词汇重复度：惩罚高频词汇。
							  # 可选值：-2.0 ~ 2.0。正值越高，越不容易出现“复读机”现象。
	
	# --- 格式与安全参数 ---
	
	"response_format": { "type": "text" }, # 返回格式：强制要求 AI 输出特定结构。
							  # 可选值：{ "type": "text" } 或 { "type": "json_object" }。开启 JSON 模式时 Prompt 必须包含 "json" 字样。
	
	"seed": null,             # 随机种子：用于复现结果。
							  # 可选值：整数。设置相同种子且温度为0时，回答基本固定。
	
	"user": "godot_player_1", # 用户标识：发送给厂商的 ID，用于区分终端用户。
							  # 可选值：任意字符串。有助于监控非法请求或统计单个玩家的消耗。
}
# 文本生成流速相关配置：
# - append_interval_time：逐字追加的基础间隔时间（秒）
# - sentence_pause_extra：在句号 / 感叹号 / 问号后额外停顿的时间（秒）
# 将它们调大，可以让角色“说话”更慢、更有停顿感；设为 0 则无停顿
static var append_interval_time:float = 0
static var sentence_pause_extra:float = 0
static var is_clean_before_reply:bool = true#展示ai回复前是否有必要清空父节点的文本，初始时设置，也可后期调用对应函数设置

# 仅做内部 URL 数据处理，一般无需修改
static func get_stream_url_host():
	var clean = url.replace("https://", "").replace("http://", "")
	var split_pos = clean.find("/")
	return clean.substr(0, split_pos)
		
static func get_stream_url_path():
	var clean = url.replace("https://", "").replace("http://", "")
	var split_pos = clean.find("/")
	return clean.substr(split_pos)
