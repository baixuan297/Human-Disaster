extends CanvasLayer
class_name GlobalMessage

## 全屏底部 Toast 提示。`project.godot` autoload 名为 **GBMssage**（历史拼写），调用 `GBMssage.show_message(...)`。

const _CORNER := 12
const _SHADOW_SIZE := 12

## 类型 → 背景基调、强调色（细描边 + 轻微混色）、正文色
const _PALETTE := {
	"info": {
		"accent": Color(0.35, 0.78, 1.0),
		"bg": Color(0.08, 0.10, 0.14, 0.93),
		"text": Color(0.93, 0.96, 1.0),
	},
	"success": {
		"accent": Color(0.32, 0.88, 0.52),
		"bg": Color(0.07, 0.12, 0.09, 0.93),
		"text": Color(0.9, 0.98, 0.93),
	},
	"warning": {
		"accent": Color(0.98, 0.72, 0.28),
		"bg": Color(0.12, 0.09, 0.06, 0.93),
		"text": Color(1.0, 0.96, 0.88),
	},
	"error": {
		"accent": Color(0.98, 0.35, 0.38),
		"bg": Color(0.12, 0.06, 0.07, 0.93),
		"text": Color(1.0, 0.93, 0.93),
	},
}

@onready var _toast_panel: PanelContainer = $ToastBar/CenterContainer/ToastPanel
@onready var messageLabel: Label = $ToastBar/CenterContainer/ToastPanel/MarginContainer/MessageLabel

@export var fade_time := 0.38
@export var display_time := 2.2

var _tween: Tween


func _ready() -> void:
	layer = maxi(layer, 80)
	_toast_panel.visible = false
	_toast_panel.modulate.a = 0.0
	messageLabel.visible = true


func show_message(text: String, message_type: String = "info") -> void:
	if _tween:
		_tween.kill()

	var pal: Dictionary = _PALETTE.get(message_type, _PALETTE["info"])
	var sb := _build_stylebox(pal)
	_toast_panel.remove_theme_stylebox_override("panel")
	_toast_panel.add_theme_stylebox_override("panel", sb)

	messageLabel.text = text
	messageLabel.add_theme_color_override("font_color", pal["text"])

	_toast_panel.visible = true
	_toast_panel.scale = Vector2(0.94, 0.94)
	call_deferred("_deferred_center_pivot")

	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_toast_panel, "modulate:a", 1.0, fade_time)
	var st_in := _tween.tween_property(_toast_panel, "scale", Vector2.ONE, fade_time)
	st_in.set_trans(Tween.TRANS_BACK)
	st_in.set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(display_time)
	_tween.set_parallel(true).set_ease(Tween.EASE_IN)
	_tween.tween_property(_toast_panel, "modulate:a", 0.0, fade_time * 0.9)
	_tween.tween_property(_toast_panel, "scale", Vector2(0.96, 0.96), fade_time * 0.9)
	_tween.chain().tween_callback(_on_message_hidden)


func _deferred_center_pivot() -> void:
	if not is_instance_valid(_toast_panel):
		return
	_toast_panel.pivot_offset = _toast_panel.size * 0.5


func _build_stylebox(pal: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var a: Color = pal["accent"]
	var base: Color = pal["bg"]
	# 背景混入少量强调色，避免单色死黑
	sb.bg_color = base.lerp(Color(a.r, a.g, a.b, base.a), 0.14)
	sb.set_corner_radius_all(_CORNER)
	sb.set_border_width_all(1)
	sb.border_color = Color(a.r, a.g, a.b, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.42)
	sb.shadow_size = _SHADOW_SIZE
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 4
	sb.content_margin_top = 4
	sb.content_margin_right = 4
	sb.content_margin_bottom = 4
	return sb


func _on_message_hidden() -> void:
	_toast_panel.visible = false
