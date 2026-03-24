extends CanvasLayer

## ScreenEffect — 全屏闪白、淡入淡出、低血量等后处理层（autoload 场景 `screen_effect.tscn`）。
## 由战斗、过场或 UI 按需调用 `flash` / `fade_in` 等，避免在各处重复搭 CanvasLayer。

@onready var flash_rect: ColorRect = $Flash
@onready var fade_rect: ColorRect = $Fade
@onready var cutscene_fade_rect: ColorRect = $CutsceneFade
@onready var low_health_rect: ColorRect = $LowHealthEffect

var _low_health_tween: Tween

func _ready() -> void:
	# 用锚点铺满全屏，避免直接设 size 触发警告
	for rect in [flash_rect, fade_rect, cutscene_fade_rect, low_health_rect]:
		if rect:
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			rect.set_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 初始全部关闭
	flash_rect.visible = false
	fade_rect.visible = false
	cutscene_fade_rect.visible = false
	low_health_rect.visible = false
	
	# 默认颜色
	flash_rect.color = Color(1, 1, 1, 0)
	fade_rect.color = Color(0, 0, 0, 0)
	cutscene_fade_rect.color = Color(0, 0, 0, 0)
	low_health_rect.color = Color(1, 0, 0, 0)


## 屏幕闪白
func flash(color: Color = Color.WHITE, duration: float = 0.15) -> void:
	if duration <= 0.0:
		duration = 0.01
	flash_rect.visible = true
	flash_rect.color = Color(color.r, color.g, color.b, 1.0)
	
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, duration)
	tween.finished.connect(func():
		flash_rect.visible = false)


## 屏幕淡入
func fade_in(duration: float = 1.0, color: Color = Color.BLACK) -> void:
	if duration <= 0.0:
		duration = 0.01
	fade_rect.visible = true
	fade_rect.color = Color(color.r, color.g, color.b, 1.0)
	
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	tween.finished.connect(func():
		fade_rect.visible = false)


## 屏幕淡出（从透明 → 纯色，常用于切场景或死亡）
func fade_out(duration: float = 1.0, color: Color = Color.BLACK) -> void:
	if duration <= 0.0:
		duration = 0.01
	fade_rect.visible = true
	fade_rect.color = Color(color.r, color.g, color.b, 0.0)
	
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)


## 过场用慢速淡入/淡出（不影响普通黑场）
func cutscene_fade_in(duration: float = 2.0, color: Color = Color.BLACK) -> void:
	if duration <= 0.0:
		duration = 0.01
	cutscene_fade_rect.visible = true
	cutscene_fade_rect.color = Color(color.r, color.g, color.b, 1.0)
	
	var tween := create_tween()
	tween.tween_property(cutscene_fade_rect, "color:a", 0.0, duration)
	tween.finished.connect(func():
		cutscene_fade_rect.visible = false)


## 过场黑屏：先淡出到黑，保持黑屏 hold_seconds 秒，再自动淡入亮起。hold_seconds=0 则只黑不自动亮。
func cutscene_fade_out(duration: float = 2.0, color: Color = Color.BLACK, hold_seconds: float = 1.0) -> void:
	if duration <= 0.0:
		duration = 0.01
	cutscene_fade_rect.visible = true
	cutscene_fade_rect.color = Color(color.r, color.g, color.b, 0.0)
	
	var tween := create_tween()
	tween.tween_property(cutscene_fade_rect, "color:a", 1.0, duration)
	if hold_seconds > 0.0:
		tween.tween_interval(hold_seconds)
		tween.tween_property(cutscene_fade_rect, "color:a", 0.0, duration)
		tween.finished.connect(func():
			cutscene_fade_rect.visible = false)


## 低血量红边效果（intensity: 0~1）
func set_low_health_intensity(intensity: float) -> void:
	intensity = clamp(intensity, 0.0, 1.0)
	if _low_health_tween:
		_low_health_tween.kill()
		_low_health_tween = null
	
	if intensity <= 0.0:
		low_health_rect.visible = false
		low_health_rect.color.a = 0.0
		return
	
	low_health_rect.visible = true
	low_health_rect.color.a = intensity * 0.6
	
	# 轻微心跳效果
	_low_health_tween = create_tween().set_loops()
	_low_health_tween.tween_property(low_health_rect, "color:a", intensity * 0.8, 0.5)
	_low_health_tween.tween_property(low_health_rect, "color:a", intensity * 0.6, 0.5)
