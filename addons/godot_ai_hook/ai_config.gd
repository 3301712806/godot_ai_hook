class_name AiConfig
########################################################
############## 在这里填写你自己的模型配置 ################
# 1. url：填入兼容 OpenAI Chat Completions 的接口地址
static var url: String = "https://api.deepseek.com/chat/completions"

# 2. api_key：在本地项目中填写自己的密钥
#    请务必不要将真实密钥提交到公开仓库或截图中泄露
static var api_key: String = ""

# 3. model：要使用的模型名称（参考服务商文档）
static var model: String = "deepseek-chat"

# 4. port：流式模式使用的端口，HTTPS 一般为 443
static var port:int = 443
########################################################
# 文本生成流速相关配置：
# - append_interval_time：逐字追加的基础间隔时间（秒）
# - sentence_pause_extra：在句号 / 感叹号 / 问号后额外停顿的时间（秒）
# 将它们调大，可以让角色“说话”更慢、更有停顿感；设为 0 则无停顿
static var append_interval_time:float = 0.1
static var sentence_pause_extra:float = 0.2
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
