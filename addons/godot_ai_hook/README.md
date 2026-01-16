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
将godot_ai_hook文件夹下载到自己的addons文件夹里。
记得在 菜单栏/项目/项目设置/插件 中启动插件

### 2. 配置模型文件
可以在 菜单栏/项目/工具 中看到带AI Hook的选项

![show_config](https://github.com/user-attachments/assets/dc824f87-d92f-45d7-85bf-c56f2036a16a)

点击 （AI Hook: 打开模型配置脚本），这里可以配置模型信息，请查看各模型提供商文档。

![config_ai](https://github.com/user-attachments/assets/7b94231e-50de-4797-a590-8fc0c7e21cbd)

### 3. 测试模型连接是否成功
点击（AI Hook: 打开测试面板），将跳转到测试面板节点，再点击运行场景，这里有个简陋的测试面板，可以测试连接效果

![open_test](https://github.com/user-attachments/assets/75117546-b25c-499d-8e0e-c2ef55a26846)

测试成功

![test](https://github.com/user-attachments/assets/431d6c29-2927-41fb-af11-f4c04cd686d2)

### 4.使用 godot ai hook
来到正题，这时可以使用插件了，打开个文本节点，在它下面挂载个 ai_manage节点（ctrl+a)+输入框输入ai应该就能看到了。

![load_ai_manage](https://github.com/user-attachments/assets/e15d6fcd-dbd6-47ce-8ee7-6dead78bbfd0)


在场景脚本里引用 ai_manage 节点，添加 ai_manage 节点.say("你想问的问题") 再运行这个场景就可以看到回答了。

![excute](https://github.com/user-attachments/assets/844156d8-e82f-46c7-82b2-eab4703cb579)

![it_work!](https://github.com/user-attachments/assets/bbb93514-873c-429c-aa9f-309a4ef202af)


### 5.设置自定义的系统提示词 system_prompt
你可以使用 ai_manage 节点.say("你想问的问题"，system_prompt) ，不过 system_prompt 往往很长，更推荐在 system_prompt 配置文件字典添加 key + 定制 system_prompt 来设置 system_prompt 。
在 菜单栏/项目/工具 里打开 AI Hook: 打开提示词配置脚本。

![system_prompt](https://github.com/user-attachments/assets/ba27dd85-aab4-4106-8282-54c9aca126ed)

按字典格式填写就行。
运行 ai_manage节点.say_bind_key("你好啊，deepseek","友情猫娘")，就像一个猫娘钩子挂在节点上。

![it_work_again](https://github.com/user-attachments/assets/84d89bc2-e188-40e6-af84-abbc73b6a558)



## 支持与 Star


如果这个插件对你有帮助，或者在你的项目中起到了哪怕一点点作用，欢迎在仓库里点一个 ⭐ Star。

你的 Star 是对作者最大的鼓励，也会让我更有动力继续维护、修复问题并尝试加入更多实用的小功能。
