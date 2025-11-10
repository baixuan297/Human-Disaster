extends CanvasLayer
class_name GlobalMessage

@onready var messageLabel: Label = $MessageLabel

@export var fade_time := 0.5
@export var display_time := 2.0

var _tween: Tween

## 颜色主题配置
var message_colors := {
	"info": Color(0.8, 0.8, 1.0),     # 淡蓝
	"success": Color(0.4, 1.0, 0.4),  # 绿色
	"warning": Color(1.0, 0.9, 0.4),  # 黄色
	"error": Color(1.0, 0.4, 0.4)     # 红色
}

func _ready() -> void:
	messageLabel.visible = false
	messageLabel.modulate.a = 0.0

func show_message(text: String, message_type: String = "info") -> void:
	if _tween:
		_tween.kill()

	messageLabel.text = text
	messageLabel.visible = true

	var color = message_colors.get(message_type, Color.WHITE)
	messageLabel.add_theme_color_override("font_color", color)

	_tween = create_tween()
	messageLabel.modulate.a = 0.0
	_tween.tween_property(messageLabel, "modulate:a", 1.0, fade_time) # 淡入
	_tween.tween_interval(display_time)
	_tween.tween_property(messageLabel, "modulate:a", 0.0, fade_time) # 淡出
	_tween.finished.connect(_on_message_hidden)

func _on_message_hidden() -> void:
	messageLabel.visible = false
