extends Control

signal deleted
signal cancelled

func _on_delete_item_pressed() -> void:
	deleted.emit()

func _on_cancel_pressed() -> void:
	cancelled.emit() 
