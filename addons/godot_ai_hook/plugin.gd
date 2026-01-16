@tool
# plugin.gd
## 函数目录
# - _enter_tree--插件启用时注册工具栏菜单
# - _exit_tree--插件禁用时移除工具栏菜单
# - _on_open_test_panel--在当前场景中实例化测试面板
# - _on_open_config_script--在脚本编辑器中打开配置脚本

extends EditorPlugin


# 插件启用时注册工具栏菜单
func _enter_tree() -> void:
	add_tool_menu_item("AI Hook: 打开测试面板", _on_open_test_panel)
	add_tool_menu_item("AI Hook: 打开模型配置脚本", _on_open_config_script)
	add_tool_menu_item("AI Hook: 打开提示词配置脚本", _on_open_system_prompt_config_script)


# 插件禁用时移除工具栏菜单
func _exit_tree() -> void:
	remove_tool_menu_item("AI Hook: 打开测试面板")
	remove_tool_menu_item("AI Hook: 打开模型配置脚本")
	remove_tool_menu_item("AI Hook: 打开提示词配置脚本")


# 在编辑器中打开测试面板场景
func _on_open_test_panel() -> void:
	var scene_path := "res://addons/godot_ai_hook/test/test.tscn"
	if not ResourceLoader.exists(scene_path):
		push_error("Godot Ai Hook: 测试场景丢失: %s" % scene_path)
		return

	var editor := get_editor_interface()
	editor.set_main_screen_editor("2D")
	editor.open_scene_from_path(scene_path)


# 在脚本编辑器中打开配置脚本
func _on_open_config_script() -> void:
	var script_path := "res://addons/godot_ai_hook/ai_config.gd"
	if not ResourceLoader.exists(script_path):
		push_error("Godot Ai Hook: 配置脚本丢失: %s" % script_path)
		return

	var script := load(script_path)
	if script == null:
		push_error("Godot Ai Hook: 无法加载配置脚本")
		return

	var editor := get_editor_interface()
	editor.set_main_screen_editor("Script")
	editor.edit_script(script)

func _on_open_system_prompt_config_script() -> void:
	var script_path := "res://addons/godot_ai_hook/system_prompt_config.gd"
	if not ResourceLoader.exists(script_path):
		push_error("Godot Ai Hook: 配置脚本丢失: %s" % script_path)
		return

	var script := load(script_path)
	if script == null:
		push_error("Godot Ai Hook: 无法加载配置脚本")
		return

	var editor := get_editor_interface()
	editor.set_main_screen_editor("Script")
	editor.edit_script(script)
