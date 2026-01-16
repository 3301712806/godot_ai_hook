# Godot Ai Hook

## 概要：用途和优点

Godot Ai Hook 是一个面向 Godot 4 的 AI 聊天插件，主要用于快速接入兼容 OpenAI Chat Completions 协议的模型（如部分云厂商的兼容接口、本地代理等）。
如果你想让主角和敌人都开口聊天、把 DeepSeek、豆包这类大模型一键接进游戏里，让背景显示文字更有特点，让 NPC 的对话更聪明、更有梗，那就选它就对了。

- 一行代码接入 ：通过 AiManage 节点，即可在任意 UI 控件中追加 AI 回复内容。
- 流式 / 非流式统一封装 ：同时提供 ChatNode （非流式 HTTPRequest）和 ChatStreamNode （流式 HTTPClient + SSE）两种实现，由 AiManage 统一管理。
  10→- 可视化测试面板 ：内置测试场景，支持：
  11→ - 一键连通性测试（返回 HTTP 状态码和错误信息）；
  12→ - 一键效果测试（多种控件展示流式输出和中断行为），并可定制文本生成流速（打字间隔与句子停顿）。
  13→- 系统提示词配置 ：通过 SystemPromptConfig 统一管理多个 System Prompt，使用 say_bind_key 以 key 方式调用。
  14→- 防御性设计 ：对 API Key、URL、Model、空内容、JSON 结构等进行多层校验，并统一在控制台输出错误信息，便于调试。
  15→ 提示：多数模型服务商都提供 OpenAI 兼容接口，本插件已尽量适配。但由于各家在输入输出实现上的差异，部分模型可能无法正常连接，敬请谅解。
  16→
  17→## 安全声明与免责声明

本项目仅实现 AI 调用逻辑，主要用于个人学习研究和游玩实验，**没有针对安全与合规做系统性的设计**，请在使用时自行做好安全防护与风险评估，包括但不限于：

- 妥善保管 API 密钥，不要将真实密钥提交到公开仓库或截图中泄露；
- 合理设置调用频率与配额，避免滥用接口或触发服务商风控；
- 结合业务场景对 AI 输出进行审核与过滤，避免直接将模型输出作为最终决策依据。

本项目只是一个方便调用 AI 服务的客户端封装，对调用模型生成的内容不承担任何责任；请您在遵守所在地区法律法规与服务商使用条款的前提下合理使用。

作者个人能力有限，代码中若有设计不当或实现问题，欢迎随时修改、提 Issue 或提交 PR。也非常欢迎 Fork 仓库，帮助这个小项目变得更好。

## 项目结构

```
addons/
└─ godot_ai_hook/
   ├─ plugin.cfg                 # 
   Godot 插件配置（名称、描述、入口脚
   本）
   ├─ plugin.gd                  # 
   EditorPlugin，注册菜单、打开测试面
   板和配置脚本
   │
   ├─ ai_config.gd               # 
   模型基础配置（url / api_key / 
   model / port）
   ├─ system_prompt_config.gd    # 
   System Prompt 配置字典（按 key 管
   理多种提示词）
   │
   ├─ ai_manage/
   │  ├─ ai_manage.gd            # 
   AiManage 核心管理节点（统一入口）
   │  └─ ai_manage.tscn          # 
   AiManage 场景
   │
   ├─ chat_node/
   │  ├─ chat_node.gd            # 
   非流式实现：HTTPRequest + 单次 
   JSON 响应
   │  └─ chat_node.tscn          # 
   ChatNode 场景
   │
   ├─ chat_stream_node/
   │  ├─ chat_stream_node.gd     # 
   流式实现：HTTPClient + SSE 文本流
   │  └─ chat_stream_node.tscn   # 
   ChatStreamNode 场景
   │
   └─ test/
      ├─ test.gd                 # 
      测试面板脚本（连接测试 + 效果测
      试）
      └─ test.tscn               # 
      测试面板场景
```

各核心脚本职责简述：

- AiManage ：
  - 对外接口： say(content, system_prompt) 、 say_bind_key(content, key)
  - 内部根据流式 / 非流式模式实例化 ChatStreamNode 或 ChatNode 。
  - 负责状态管理（防重复请求、传输中标记）、错误统一上报、取消传输等。
- ChatNode ：
  - 使用 HTTPRequest 发送一次性请求，解析完整 JSON 响应。
  - 出错时通过 parent.on_ai_error_occurred 回调。
- ChatStreamNode ：
  - 使用 HTTPClient 建立 HTTPS 连接，发送 stream: true 的请求。
  - 解析以 data: 开头的 SSE 文本流，识别 [DONE] 结束标记。
  - 将增量内容通过 parent.on_ai_reasoning_content_generated / on_ai_content_generated 回调。
- test/test.tscn + test.gd ：
  - 提供 UI 面板用于快速测试 API 连接和展示效果，并包含中断长文本生成的实验逻辑。

## 使用方法

### 1. 安装插件

1. 将 godot_ai_hook 文件夹放入项目的 addons/ 目录下。
2. 打开 Godot 编辑器，在 Project Settings > Plugins 中启用 Godot Ai Hook 插件。
3. 启用后，在编辑器工具栏会出现菜单项：
   - 打开测试面板
   - 打开模型配置脚本（ ai_config.gd ）
   - 打开提示词配置脚本（ system_prompt_config.gd ）

### 2. 配置模型参数 2.1 通过脚本直接配置（推荐给最终使用者）

打开 ai_config.gd ：

```
static var url: String = "https://
your-openai-compatible-endpoint/
chat/completions"
static var api_key: String = 
""        # 在这里填入自己的密钥
static var model: String = 
"your-model-name"
static var port: int = 443
```

注意：

- 不要 在开源仓库中提交真实的密钥；
- 确保服务端接口兼容 OpenAI Chat Completions 的请求结构。 2.2 通过测试面板临时配置（调试用）

1. 在插件菜单中选择“打开测试面板”，运行场景。
2. 在面板顶部填入：
   - model
   - url
   - secret_key
3. 点击“一键测试”：
   - 如果 HTTP code = 200，则说明可用；
   - 否则日志会打印具体错误信息。
	 测试面板不会持久化配置，只会临时覆盖 AiConfig 的静态变量，方便调试不同模型 / URL。

### 3. 在场景中使用 AiManage 3.1 挂载 AiManage 节点

1. 在需要显示 AI 内容的控件下添加子节点：
   - 支持的父节点类型： Label 、 LineEdit 、 TextEdit 、 RichTextLabel 等。
2. 在该控件下实例化 AiManage 场景（ ai_manage.tscn ）。
   AiManage 会自动在 \_ready() 中默认启用 流式模式 。
   3.2 切换流式 / 非流式
   在脚本中访问 AiManage ，例如：

```
@onready var ai: AiManage = $Label/
AiManage

# 使用流式
ai.set_ai_stream_type(true)

# 使用非流式（单次 HTTP 请求）
ai.set_ai_stream_type(false)
```

切换模式时，会自动清理旧节点并实例化对应的 ChatStreamNode / ChatNode 。
3.3 发送请求：直接传入 system_prompt

````
ai.say("你好，可以帮我写一段故事吗？")
ai.say("请用三句话描述一只猫。", "你是
一位温柔风格的中文写作助手。")
``` 3.4 发送请求：使用 system_prompt key
在 system_prompt_config.gd 中配置：

````

static var 
system_prompt_dic:Dictionary = {
    "友情猫娘提示词": "……非常长的猫娘
     角色设定  prompt ……",
    "严谨翻译助手": "你是一个严谨的中英
     互译助手，要求……",
}

```
然后在代码中：

```

ai.say_bind_key("你好呀", "友情猫娘提
示词")
ai.say_bind_key("请帮我翻译成英文：今
天天气很好。", "严谨翻译助手")

```
AiManage 会：

- 检查 key 是否存在、对应 value 是否为字符串且非空；
- 出错时在控制台给出明确报错信息。
### 4. 错误处理与中断
- 任意错误（网络 / HTTP 状态码 / JSON 解析 / 结构缺失）都会通过：
  - AiManage.on_ai_error_occurred(err_msg) → 统一 push_error("AI Error: ...") ；
- 可以调用：
```

ai.cancel_ai_transfer()

```
- 会尝试：
  - 对流式节点调用 _stop_stream() ，停止轮询与连接；
  - 对非流式节点调用 _safe_free_client() ，释放 HTTPRequest。
## 使用案例（示例结构）
本章节只提供 文本框架 ，你可以根据需要插入运行截图，例如： ![效果测试界面](docs/test_panel.png) 。

### 案例一：Label 显示非流式回复
目标： 在一个 Label 中显示一次性完整回复。

步骤示例：

1. 在场景中创建一个 Label ，命名为 ResultLabel 。
2. 将 AiManage 场景拖拽为 ResultLabel 的子节点。
3. 在父节点脚本中编写：
```

@onready var ai: AiManage = 
$ResultLabel/AiManage

func _ready():
    ai.set_ai_stream_type(false) # 
     使用非流式

func _on_Button_pressed():
    ai.say("你好，请介绍一下这个游戏场
     景。")

```
截图占位：非流式输出展示 ![非流式示例](docs/example_non_stream.png)

### 案例二：RichTextLabel 显示流式滚动回复
目标： 在一个 RichTextLabel 中实时看到逐字生成的内容。

1. 在场景中创建 RichTextLabel ，命名为 ChatOutput 。
2. 将 AiManage 场景拖拽为 ChatOutput 的子节点。
3. 在父节点脚本中：
```

@onready var ai: AiManage = 
$ChatOutput/AiManage

func _ready():
    ai.set_ai_stream_type(true) # 
     默认也是  true，这里显式说明

func _on_Button_pressed():
    ai.say("请用分条的方式说明一下这个
     关卡应该怎么玩。")

```
截图占位：流式输出逐步追加的效果 ![流式示例](docs/example_stream.png)

### 案例三：使用测试面板做综合调试
目标： 使用内置测试面板快速检查 API 是否配置正确，以及观察中断行为。

1. 在插件菜单中打开测试面板场景 test.tscn 并运行。
2. 在顶部填入 model / url / secret_key ，点击「一键测试」：
   - 查看 HTTP code 和返回体，判断是否配置正确。
3. 点击「一键效果测试」：
   - 观察四种不同控件 + 1 个非流式输出区的表现；
   - 可在测试面板中调节文本展示流速（例如打字间隔与句子停顿）；
   - 面板会在一段时间后自动启动一次“长文本 + 中断”的测试，用于确认 cancel_ai_transfer 等逻辑是否正常。
截图占位：测试面板整体界面 ![测试面板](docs/example_test_panel.png)
```

## 支持与 Star

如果这个插件对你有帮助，或者在你的项目中起到了哪怕一点点作用，欢迎在仓库里点一个 ⭐ Star。

你的 Star 是对作者最大的鼓励，也会让我更有动力继续维护、修复问题并尝试加入更多实用的小功能。
