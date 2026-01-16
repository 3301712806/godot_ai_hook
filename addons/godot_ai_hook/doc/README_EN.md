# Godot AI Hook

[简体中文](README.md) | [English](README_EN.md)

## Overview: Purpose & Benefits

**Godot AI Hook** is an AI chat plugin for **Godot 4**, designed to quickly integrate models that are **compatible with the OpenAI Chat Completions protocol**
(such as OpenAI-compatible APIs provided by cloud vendors).

If you want to easily bring large language models like **DeepSeek** or **Doubao** into your game, allowing:

* Protagonists and enemies to talk to each other
* NPCs to have their own “thoughts”
* Background text and narration to feel more vivid and dynamic

then this plugin works like an **AI hook** that can be attached directly to nodes — simple, intuitive, and Godot-native.

---

### Design Goal

Godot AI Hook is **not** an “all-in-one AI framework”.
Instead, it is designed around a very clear goal:

> **Attach AI to a Godot scene with minimal cognitive overhead.**

To achieve this, the plugin follows these principles:

---

### 1️⃣ Node-first: AI as a Node

In Godot, **everything is a node**.

Rather than providing a large set of static utility classes or complex APIs,
Godot AI Hook treats AI itself as a **node that can be attached, referenced, and managed**.

* `AiManage` is an **AI capability node**
* You simply add it to the scene tree
* UI elements, NPCs, and system logic can call it directly

This makes AI feel more like a **game component** instead of an external service.

---

### 2️⃣ Unified Abstraction for Streaming & Non-Streaming

Different scenarios require different output behaviors:

* Dialog boxes, subtitles → **streaming output**
* One-shot analysis, system prompts → **non-streaming output**

Internally, the plugin provides:

* `ChatNode` (non-streaming)
* `ChatStreamNode` (streaming)

But for users, there are only a few simple entry points:

```gdscript
ai_manage.say(...)
ai_manage.say_bind_key(...)
```

**The implementation may change, but the usage stays the same.**

---

### 3️⃣ Client-Oriented, Not Platform-Bound

Godot AI Hook is positioned as:

> **An AI invocation client, not an SDK for a specific model platform.**

Therefore:

* It does not bind to a specific model
* It does not depend on a specific cloud vendor
* Any **OpenAI Chat Completions–compatible API** is supported whenever possible

This allows you to:

* Freely switch between models (DeepSeek / Doubao / local models)
* Use cheaper models during development and replace them before release

---

### 4️⃣ Defensive Design, Not “Magic”

The plugin does not assume that:

* An API key always exists
* The network is always stable
* JSON responses are always valid

Instead, it aims to:

* Validate inputs and responses at every step
* Output clear error messages in the console
* Avoid silent failures

This is especially important during **development and learning phases**.

---

## 🎮 Use Cases

Godot AI Hook is particularly well-suited for the following scenarios:

---

### 🧙 NPC Dialogue & Personality-Driven Behavior

* Each NPC can use a different System Prompt
* Dialogue content is generated dynamically
* NPCs are no longer limited to static option trees

---

### 📜 Story Narration & Worldbuilding Text

* Streaming output is ideal for:

  * Story subtitles
  * World lore descriptions
  * Memories and inner monologues

Combined with a typewriter effect, this can greatly enhance immersion.

---

### 🧪 Prototyping & Gameplay Experiments

During early prototyping, you can:

* Skip writing full story scripts
* Avoid complex dialogue trees
* Use AI to quickly validate gameplay feel

---

### 🤖 In-Game AI Assistants & Guide Characters

* Tutorial assistants
* System hint characters
* “Fourth-wall-breaking” explainers

---

### 🛠️ Informal Uses (Tools & Experiments)

Although it is a game plugin, it can also be used for:

* AI-powered tools inside Godot
* Text generation testing
* AI behavior experiments

---

## ✨ One-Sentence Design Summary

> **Godot AI Hook does not try to teach you how to use AI.
> It simply turns AI into a Godot node you already understand.**

---

> **Note**
> Most model providers offer OpenAI-compatible APIs, and this plugin attempts to support them as much as possible.
> However, due to differences in request/response implementations, some models may not work correctly.

---

## Security Statement & Disclaimer

This project only implements **AI invocation logic** and is intended mainly for **personal learning, research, and experimental use**.
It is **not designed with comprehensive security or compliance guarantees**.

When using this plugin, please conduct your own risk assessment, including but not limited to:

* Keep API keys secure; never commit real keys to public repositories or expose them in screenshots
* Set reasonable request rates and quotas to avoid abuse or triggering provider limits
* Review and filter AI-generated output based on your application’s needs

This project is only a client-side wrapper for AI services and **does not take responsibility for generated content**.
Please use it in compliance with local laws and the terms of service of your model providers.

As the author’s abilities are limited, feedback is welcome. Feel free to:

* Open issues
* Submit pull requests
* Fork the repository and improve it together

---

## Project Structure

```text
addons/
└─ godot_ai_hook/
   ├─ plugin.cfg                  # Godot plugin configuration (name, description, entry script)
   ├─ plugin.gd                   # EditorPlugin: registers menu items and opens test/config panels
   │
   ├─ ai_config.gd                # Base model configuration (url / api_key / model / port)
   ├─ system_prompt_config.gd     # System Prompt dictionary (managed by key)
   │
   ├─ ai_manage/
   │  ├─ ai_manage.gd             # Core AI management node (single entry point)
   │  └─ ai_manage.tscn           # AiManage scene
   │
   ├─ chat_node/
   │  ├─ chat_node.gd             # Non-streaming: HTTPRequest + single JSON response
   │  └─ chat_node.tscn           # ChatNode scene
   │
   ├─ chat_stream_node/
   │  ├─ chat_stream_node.gd      # Streaming: HTTPClient + SSE text stream
   │  └─ chat_stream_node.tscn    # ChatStreamNode scene
   │
   └─ test/
	  ├─ test.gd                  # Test panel logic (connection & output tests)
	  └─ test.tscn                # Test panel scene
```

---

### Core Script Responsibilities

#### AiManage

* Main public interfaces:

  * `say(content, system_prompt)`
  * `say_bind_key(content, key)`
  * `set_ai_stream_type(is_true)`

---

#### ChatNode

* Sends a single request using `HTTPRequest`
* Parses the full JSON response
* Reports errors via `parent.on_ai_error_occurred()`

---

#### ChatStreamNode

* Establishes an HTTPS connection using `HTTPClient`
* Sends requests with `stream: true`
* Parses SSE text streams starting with `data:`
* Detects the `[DONE]` end marker
* Pushes incremental output via:

  * `on_ai_reasoning_content_generated`
  * `on_ai_content_generated`

---

#### Test Panel

* Provides a UI for quickly testing API connectivity and output behavior
* Includes logic for interrupting long-running text generation

---

## Usage

### 1. Install the Plugin

Copy the `godot_ai_hook` folder into your project’s `addons` directory.

Then enable the plugin via:

**Menu → Project → Project Settings → Plugins**

---

### 2. Configure Model Information

In **Menu → Project → Tools**, you will find **AI Hook** related options.

![show\_config](https://github.com/user-attachments/assets/dc824f87-d92f-45d7-85bf-c56f2036a16a)

Click **AI Hook: Open Model Config Script** and fill in the configuration according to your model provider’s documentation.

![config\_ai](https://github.com/user-attachments/assets/7b94231e-50de-4797-a590-8fc0c7e21cbd)

---

### 3. Test Model Connectivity

Click **AI Hook: Open Test Panel**, then run the test scene.

![open\_test](https://github.com/user-attachments/assets/75117546-b25c-499d-8e0e-c2ef55a26846)

Successful connection example:

![test](https://github.com/user-attachments/assets/431d6c29-2927-41fb-af11-f4c04cd686d2)

---

### 4. Use Godot AI Hook

Select a text node in your scene and attach an `ai_manage` node as its child
(search for `ai_manage` with `Ctrl + A`).

![load\_ai\_manage](https://github.com/user-attachments/assets/e15d6fcd-dbd6-47ce-8ee7-6dead78bbfd0)

Reference the node in your script and call:

```gdscript
ai_manage.say("Your question here")
```

Run the scene to see the AI response.

![excute](https://github.com/user-attachments/assets/844156d8-e82f-46c7-82b2-eab4703cb579)
![it\_work!](https://github.com/user-attachments/assets/bbb93514-873c-429c-aa9f-309a4ef202af)

---

### 5. Use Custom System Prompts

Although you can pass a `system_prompt` directly:

```gdscript
ai_manage.say("Question content", system_prompt)
```

System Prompts are often long, so **using a config file with keys is recommended**.

Open **Menu → Project → Tools → AI Hook: Open System Prompt Config Script**:

![system\_prompt](https://github.com/user-attachments/assets/ba27dd85-aab4-4106-8282-54c9aca126ed)

Example usage:

```gdscript
ai_manage.say_bind_key("Hello, DeepSeek", "Friendly Catgirl")
```

Just like attaching a “catgirl AI hook” to your node 🐱

![it\_work\_again](https://github.com/user-attachments/assets/84d89bc2-e188-40e6-af84-abbc73b6a558)

---

### 6. Switch Between Streaming and Non-Streaming Modes

Example usage:

```gdscript
ai_manage.set_ai_stream_type(true)   # Enable streaming mode
ai_manage.set_ai_stream_type(false)  # Disable streaming mode (non-streaming)
```


## Support & Star ⭐

If this plugin helps you — even a little — feel free to give it a **Star** ⭐ on GitHub.

Your support is the biggest motivation for continued maintenance, bug fixes, and new features ❤️

---
