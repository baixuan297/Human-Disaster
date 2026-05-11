extends CanvasLayer
class_name GlobalMessage

## 教程场景 [method push_tutorial_toast_layout] 专用：临时移动 ToastDock（退出教程时恢复场景内原布局）。
enum TutorialToastDockPlacement {
	## 不改动 ToastDock / Center（仅延长停留时间）
	KEEP_SCENE_LAYOUT,
	## 屏幕上方全宽条（多行教程文案）
	TOP_WIDE,
	## 屏幕右侧竖条
	RIGHT_SIDE,
	## 屏幕左侧竖条
	LEFT_SIDE,
}

## 全局 Toast 提示，默认贴在屏幕底部（项目 autoload 名：**GBMssage**，历史拼写）。
##
## 【用法】任意脚本：`GBMssage.show_message("提示文案", "error")`
## 【类型】`info` | `success` | `warning` | `error`，未知类型按 `info`。
##
## 【场景树】（见 GlobalMessage.tscn）
##   GlobalMessage (CanvasLayer，高层级绘制)
##   └── ToastDock      在场景中自行摆位（Custom / 预设均可）；默认不由脚本改写锚点
##       └── Center     VBox 顶对齐，卡片横向居中，避免长文案在 CenterContainer 内被垂直裁切
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
## 教程临时布局（顶栏/侧栏）时，消息区与**屏幕上沿**之间的留白（像素）
@export var tutorial_toast_viewport_top_margin: float = 32.0
## 教程顶栏（TOP_WIDE）时，条幅总高度 = 本值 + [member tutorial_toast_viewport_top_margin]（像素）
@export var tutorial_toast_top_strip_inner_height: float = 260.0
## 为 true（默认）时，脚本不修改 ToastDock 的锚点与 offset，避免与场景中 Custom 布局冲突或把提示挤出视口。
@export var preserve_toast_dock_layout: bool = true

@onready var _toast_dock: Control = $ToastDock
@onready var _toast_center: Control = $ToastDock/Center
@onready var _card: PanelContainer = $ToastDock/Center/ToastCard
@onready var _label: Label = $ToastDock/Center/ToastCard/MessageLabel

## 单条消息停留覆盖（秒）；小于 0 时使用 [member display_time]
var _hold_override_seconds: float = -1.0
## 教程场景：嵌套深度与恢复的默认停留时间
var _tutorial_layout_depth: int = 0
var _stash_display_time: float = -1.0
## 教程 push 前抓取的 ToastDock + Center 布局（pop 时写回）
var _tutorial_stashed_layout: Dictionary = {}
## 教程 push 前 ToastCard / MessageLabel 的 custom_minimum_size（pop 时写回）
var _tutorial_stashed_card_label_mins: Dictionary = {}
## 当前教程 Toast 摆放（用于自适应宽度与顶栏增高）
var _tutorial_active_placement: TutorialToastDockPlacement = TutorialToastDockPlacement.KEEP_SCENE_LAYOUT

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


## 将 ToastDock 设为贴顶/贴底全宽条（仅当 [member preserve_toast_dock_layout] 为 false 时生效）。
func set_toast_vertical_top(use_top: bool) -> void:
	if preserve_toast_dock_layout or not is_instance_valid(_toast_dock):
		return
	var d: Control = _toast_dock
	if use_top:
		d.set_anchors_preset(Control.PRESET_TOP_WIDE)
		d.offset_left = 0.0
		d.offset_top = 0.0
		d.offset_right = 0.0
		d.offset_bottom = 160.0
	else:
		d.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		d.offset_left = 0.0
		d.offset_top = -160.0
		d.offset_right = 0.0
		d.offset_bottom = 0.0


## 教程等场景：延长 [member display_time]，并按 [param placement] 临时摆放 Toast（退出时恢复原布局）。
## 与 [member preserve_toast_dock_layout] 无关：教程 push/pop 自成一对快照/恢复。可嵌套调用，须成对 [method pop_tutorial_toast_layout]。
func push_tutorial_toast_layout(
	long_display: float = 7.0,
	placement: TutorialToastDockPlacement = TutorialToastDockPlacement.TOP_WIDE,
) -> void:
	if _tutorial_layout_depth == 0:
		_tutorial_stashed_layout.clear()
		_tutorial_stashed_card_label_mins.clear()
		_stash_display_time = display_time
		display_time = maxf(long_display, 0.05)
		_tutorial_active_placement = placement
		if placement != TutorialToastDockPlacement.KEEP_SCENE_LAYOUT:
			_tutorial_stashed_card_label_mins = {
				"card": _card.custom_minimum_size,
				"label": _label.custom_minimum_size,
			}
			_tutorial_stashed_layout = {
				"dock": _capture_control_layout(_toast_dock),
				"center": _capture_control_layout(_toast_center),
			}
			_apply_tutorial_toast_placement(placement)
	_tutorial_layout_depth += 1
	call_deferred("_tutorial_schedule_toast_fit")


func pop_tutorial_toast_layout() -> void:
	_tutorial_layout_depth = maxi(_tutorial_layout_depth - 1, 0)
	if _tutorial_layout_depth == 0:
		if _stash_display_time >= 0.0:
			display_time = _stash_display_time
			_stash_display_time = -1.0
		if not _tutorial_stashed_layout.is_empty():
			_apply_control_layout(_toast_dock, _tutorial_stashed_layout["dock"] as Dictionary)
			_apply_control_layout(_toast_center, _tutorial_stashed_layout["center"] as Dictionary)
			_tutorial_stashed_layout.clear()
		if not _tutorial_stashed_card_label_mins.is_empty():
			_card.custom_minimum_size = _tutorial_stashed_card_label_mins["card"] as Vector2
			_label.custom_minimum_size = _tutorial_stashed_card_label_mins["label"] as Vector2
			_tutorial_stashed_card_label_mins.clear()
		_tutorial_active_placement = TutorialToastDockPlacement.KEEP_SCENE_LAYOUT


func _capture_control_layout(ctrl: Control) -> Dictionary:
	return {
		"layout_mode": ctrl.layout_mode,
		"anchor_left": ctrl.anchor_left,
		"anchor_top": ctrl.anchor_top,
		"anchor_right": ctrl.anchor_right,
		"anchor_bottom": ctrl.anchor_bottom,
		"offset_left": ctrl.offset_left,
		"offset_top": ctrl.offset_top,
		"offset_right": ctrl.offset_right,
		"offset_bottom": ctrl.offset_bottom,
		"grow_horizontal": ctrl.grow_horizontal,
		"grow_vertical": ctrl.grow_vertical,
	}


func _apply_control_layout(ctrl: Control, dict: Dictionary) -> void:
	if dict.is_empty():
		return
	ctrl.layout_mode = dict["layout_mode"] as int
	ctrl.anchor_left = dict["anchor_left"] as float
	ctrl.anchor_top = dict["anchor_top"] as float
	ctrl.anchor_right = dict["anchor_right"] as float
	ctrl.anchor_bottom = dict["anchor_bottom"] as float
	ctrl.offset_left = dict["offset_left"] as float
	ctrl.offset_top = dict["offset_top"] as float
	ctrl.offset_right = dict["offset_right"] as float
	ctrl.offset_bottom = dict["offset_bottom"] as float
	ctrl.grow_horizontal = dict["grow_horizontal"] as Control.GrowDirection
	ctrl.grow_vertical = dict["grow_vertical"] as Control.GrowDirection


func _normalize_center_fill_dock() -> void:
	var c := _toast_center
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0


func _apply_tutorial_toast_placement(placement: TutorialToastDockPlacement) -> void:
	if not is_instance_valid(_toast_dock):
		return
	var d := _toast_dock
	match placement:
		TutorialToastDockPlacement.KEEP_SCENE_LAYOUT:
			return
		TutorialToastDockPlacement.TOP_WIDE:
			d.set_anchors_preset(Control.PRESET_TOP_WIDE)
			var top_m: float = maxf(tutorial_toast_viewport_top_margin, 0.0)
			var strip_h: float = maxf(tutorial_toast_top_strip_inner_height, 80.0)
			d.offset_left = 0.0
			d.offset_top = top_m
			d.offset_right = 0.0
			d.offset_bottom = top_m + strip_h
			d.grow_horizontal = Control.GROW_DIRECTION_BOTH
			d.grow_vertical = Control.GROW_DIRECTION_END
		TutorialToastDockPlacement.RIGHT_SIDE:
			d.anchor_left = 1.0
			d.anchor_top = 0.0
			d.anchor_right = 1.0
			d.anchor_bottom = 1.0
			var side_top: float = 56.0 + maxf(tutorial_toast_viewport_top_margin, 0.0)
			d.offset_left = -492.0
			d.offset_top = side_top
			d.offset_right = -12.0
			d.offset_bottom = -side_top
			d.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			d.grow_vertical = Control.GROW_DIRECTION_BOTH
		TutorialToastDockPlacement.LEFT_SIDE:
			d.anchor_left = 0.0
			d.anchor_top = 0.0
			d.anchor_right = 0.0
			d.anchor_bottom = 1.0
			var side_top_l: float = 56.0 + maxf(tutorial_toast_viewport_top_margin, 0.0)
			d.offset_left = 12.0
			d.offset_top = side_top_l
			d.offset_right = 492.0
			d.offset_bottom = -side_top_l
			d.grow_horizontal = Control.GROW_DIRECTION_END
			d.grow_vertical = Control.GROW_DIRECTION_BOTH
	_normalize_center_fill_dock()


## 显示一条 Toast。[param text] 正文；[param message_type] 见文件头类型说明。
## [param hold_seconds] 本条停留秒数；小于 0 时使用 [member display_time]。
func show_message(text: String, message_type: String = "info", hold_seconds: float = -1.0) -> void:
	var resolved_kind: String = message_type if _PALETTE.has(message_type) else "info"
	_hold_override_seconds = hold_seconds
	_hold_timer.stop()
	if _tween:
		_tween.kill()

	_card.add_theme_stylebox_override("panel", _styles[resolved_kind])
	_label.text = text
	_label.add_theme_color_override("font_color", _PALETTE[resolved_kind]["text"])

	_card.visible = true
	_card.scale = Vector2(0.93, 0.93)
	call_deferred("_sync_card_pivot")
	if _tutorial_layout_depth > 0:
		call_deferred("_tutorial_schedule_toast_fit")
	_run_toast_tween()


func _tutorial_schedule_toast_fit() -> void:
	if _tutorial_layout_depth <= 0:
		return
	call_deferred("_tutorial_run_toast_fit_deferred")


func _tutorial_run_toast_fit_deferred() -> void:
	if _tutorial_layout_depth <= 0:
		return
	_tutorial_fit_toast_widths_for_viewport()
	await get_tree().process_frame
	if _tutorial_layout_depth <= 0:
		return
	_tutorial_fit_toast_heights_for_top_strip()
	call_deferred("_sync_card_pivot")


func _tutorial_fit_toast_widths_for_viewport() -> void:
	if _tutorial_layout_depth <= 0 or not is_instance_valid(_toast_dock):
		return
	var vps: Vector2 = get_viewport().get_visible_rect().size
	var dock_w: float = _toast_dock.size.x
	if dock_w < 64.0:
		match _tutorial_active_placement:
			TutorialToastDockPlacement.TOP_WIDE:
				dock_w = vps.x
			TutorialToastDockPlacement.RIGHT_SIDE, TutorialToastDockPlacement.LEFT_SIDE:
				dock_w = minf(520.0, vps.x * 0.96)
			_:
				dock_w = maxf(200.0, vps.x - 48.0)
	var side_inset: float = 20.0
	var max_w: float = minf(vps.x - 32.0, dock_w - side_inset * 2.0)
	max_w = maxf(220.0, max_w)
	_card.custom_minimum_size = Vector2(max_w, 0.0)
	var label_w: float = maxf(160.0, max_w - float(_CONTENT.x + _CONTENT.z) - 8.0)
	_label.custom_minimum_size = Vector2(label_w, 0.0)


func _tutorial_fit_toast_heights_for_top_strip() -> void:
	if _tutorial_layout_depth <= 0:
		return
	if _tutorial_active_placement != TutorialToastDockPlacement.TOP_WIDE:
		return
	var vps: Vector2 = get_viewport().get_visible_rect().size
	var top_m: float = maxf(tutorial_toast_viewport_top_margin, 0.0)
	var ch: float = _label.get_line_height()
	# 备用方案
	#var ch: float = _label.get_minimum_size().y
	if ch < 4.0:
		ch = 4.0
	var inner: float = ch + float(_CONTENT.y + _CONTENT.w) + 28.0
	var floor_strip: float = maxf(120.0, tutorial_toast_top_strip_inner_height)
	var max_strip: float = maxf(floor_strip + 1.0, vps.y * 0.94 - top_m)
	inner = clampf(inner, floor_strip, max_strip)
	_toast_dock.offset_top = top_m
	_toast_dock.offset_bottom = top_m + inner


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
	var base_hold: float = display_time if _hold_override_seconds < 0.0 else _hold_override_seconds
	_hold_override_seconds = -1.0
	var hold_seconds: float = maxf(base_hold, 0.0)
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


## 立即结束当前 Toast（停止计时与动画并隐藏），用于教程「按任意键继续」等。
func dismiss_current_toast() -> void:
	_hold_timer.stop()
	if _tween:
		_tween.kill()
		_tween = null
	if is_instance_valid(_card):
		_card.modulate.a = 0.0
		_card.visible = false


## 与 [method dismiss_current_toast] 相同，供无法持有节点引用时调用。
static func dismiss_toast() -> void:
	var st := Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return
	var node := st.root.get_node_or_null(^"GBMssage")
	if node is GlobalMessage:
		(node as GlobalMessage).dismiss_current_toast()


## 任意脚本中安全弹出 Toast（通过场景树根解析 Autoload GBMssage；树未就绪则忽略）。
## [param hold_seconds] 本条停留秒数；小于 0 时使用节点上的 [member GlobalMessage.display_time]。
static func emit_toast(text: String, message_type: String = "info", hold_seconds: float = -1.0) -> void:
	var st := Engine.get_main_loop() as SceneTree
	if st == null or st.root == null:
		return
	var node := st.root.get_node_or_null(^"GBMssage")
	if node is GlobalMessage:
		(node as GlobalMessage).show_message(text, message_type, hold_seconds)
