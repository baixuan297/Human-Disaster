extends CanvasLayer
class_name GlobalMessage

## 全局底部 Toast 提示（项目 autoload 名：**GBMssage**，历史拼写）。
##
## 【用法】任意脚本：`GBMssage.show_message("提示文案", "error")`
## 【类型】`info` | `success` | `warning` | `error`，未知类型按 `info`。
##
## 【场景树】（见 GlobalMessage.tscn）
##   GlobalMessage (CanvasLayer，高层级绘制)
##   └── ToastDock      贴底全宽条，限定 Toast 区域
##       └── Center     水平居中卡片
##           └── ToastCard (PanelContainer) + MessageLabel
##
## 【输入】子控件默认会拦截点击；`_ready` 中对 ToastDock 子树 `propagate_call` 设为
## `MOUSE_FILTER_IGNORE`，避免挡住下层背包、输入框等 UI。

## Autoload 名：**GBMssage**（历史拼写）。用法：`GBMssage.show_message("…", "error")`。

## CanvasLayer 最低层级，确保高于多数游戏 UI，又不必写死过大数值。
const _MIN_LAYER := 80
## 面板圆角半径（像素）
const _CORNER_PX := 14
## 面板阴影扩散（像素）
const _SHADOW_PX := 10
## StyleBoxFlat 内容边距：左、上、右、下（像素），替代额外 MarginContainer
const _CONTENT := Vector4i(20, 14, 20, 14)

## 消息类型 → 配色：`accent` 描边与背景混色；`bg` 底色；`text` 标签字色
const _PALETTE: Dictionary = {
	"info": {
		"accent": Color(0.38, 0.80, 1.0),
		"bg": Color(0.07, 0.09, 0.13, 0.94),
		"text": Color(0.94, 0.97, 1.0),
	},
	"success": {
		"accent": Color(0.30, 0.90, 0.55),
		"bg": Color(0.06, 0.11, 0.08, 0.94),
		"text": Color(0.91, 0.99, 0.94),
	},
	"warning": {
		"accent": Color(1.0, 0.74, 0.26),
		"bg": Color(0.11, 0.08, 0.05, 0.94),
		"text": Color(1.0, 0.97, 0.90),
	},
	"error": {
		"accent": Color(1.0, 0.38, 0.40),
		"bg": Color(0.11, 0.05, 0.06, 0.94),
		"text": Color(1.0, 0.94, 0.94),
	},
}

## 淡入/淡出时长（秒）
@export var fade_time := 0.35
## 完全显示后保持时长（秒），再开始淡出（用 Timer 实现，避免 Tween.chain + tween_interval 在部分版本下异常变短）
@export var display_time := 2.5

@onready var _card: PanelContainer = $ToastDock/Center/ToastCard
@onready var _label: Label = $ToastDock/Center/ToastCard/MessageLabel

## 当前动画；新消息前会 kill，避免叠加
var _tween: Tween
## 停留阶段计时（不用 Tween.tween_interval，与并行/链式组合更稳定）
var _hold_timer: Timer
## 各 message_type 对应的 StyleBoxFlat，_ready 预构建，避免每次 show 分配
var _styles: Dictionary = {}


func _ready() -> void:
	layer = maxi(layer, _MIN_LAYER)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_hold_timer.timeout.connect(_run_fade_out_tween)
	add_child(_hold_timer)
	_toast_ignore_input_recursive($ToastDock)
	for palette_key: String in _PALETTE:
		_styles[palette_key] = _make_panel_style(_PALETTE[palette_key])
	_card.visible = false
	_card.modulate.a = 0.0


## 显示一条 Toast。[param text] 正文；[param message_type] 见文件头类型说明。
func show_message(text: String, message_type: String = "info") -> void:
	var resolved_kind: String = message_type if _PALETTE.has(message_type) else "info"
	_hold_timer.stop()
	if _tween:
		_tween.kill()

	_card.add_theme_stylebox_override("panel", _styles[resolved_kind])
	_label.text = text
	_label.add_theme_color_override("font_color", _PALETTE[resolved_kind]["text"])

	_card.visible = true
	_card.scale = Vector2(0.93, 0.93)
	call_deferred("_sync_card_pivot")
	_run_toast_tween()


## 整棵 UI 子树设为忽略鼠标，使事件穿透到下层 Control。
func _toast_ignore_input_recursive(root: Node) -> void:
	root.propagate_call(&"set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])


## 缩放动画以卡片中心为轴，需在布局完成后根据 size 设置 pivot。
func _sync_card_pivot() -> void:
	if is_instance_valid(_card):
		_card.pivot_offset = _card.size * 0.5


## 淡入 + 轻微放大 →（Timer 等待 display_time）→ 淡出，见 `_run_fade_out_tween`。
func _run_toast_tween() -> void:
	_tween = create_tween()
	_tween.set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_card, "modulate:a", 1.0, fade_time)
	var scale_in := _tween.tween_property(_card, "scale", Vector2.ONE, fade_time)
	scale_in.set_trans(Tween.TRANS_BACK)
	scale_in.set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(_start_hold_timer)


func _start_hold_timer() -> void:
	var hold_seconds: float = maxf(display_time, 0.0)
	_hold_timer.wait_time = hold_seconds if hold_seconds > 0.0 else 0.05
	_hold_timer.start()


func _run_fade_out_tween() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(_card, "modulate:a", 0.0, fade_time * 0.88)
	_tween.tween_property(_card, "scale", Vector2(0.97, 0.97), fade_time * 0.88)
	_tween.chain().tween_callback(_hide_card)


## 由 _PALETTE 条目生成扁平圆角面板样式（含阴影与内边距）。
func _make_panel_style(palette: Dictionary) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var accent_color: Color = palette["accent"]
	var background_color: Color = palette["bg"]
	style.bg_color = background_color.lerp(Color(accent_color.r, accent_color.g, accent_color.b, background_color.a), 0.12)
	style.set_corner_radius_all(_CORNER_PX)
	style.set_border_width_all(1)
	style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.5)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = _SHADOW_PX
	style.shadow_offset = Vector2(0, 3)
	style.content_margin_left = _CONTENT.x
	style.content_margin_top = _CONTENT.y
	style.content_margin_right = _CONTENT.z
	style.content_margin_bottom = _CONTENT.w
	return style


func _hide_card() -> void:
	_card.visible = false
