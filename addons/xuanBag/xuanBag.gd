@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_autoload_singleton("InventoryManager", "res://addons/xuanBag/scripts/InventoryManager.gd")
	print("xuanBag Plugin Enabled")


func _exit_tree() -> void:
	remove_autoload_singleton("InventoryManager")
	print("xuanBag Plugin Disabled")
