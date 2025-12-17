extends ProgressBar

var fillStyleBox: StyleBoxFlat

const HEALTH_BAR_COLOUR = preload("uid://qsatw440kv62")

func _ready() -> void:
	fillStyleBox = get_theme_stylebox("fill")


func _on_value_changed(new_value: float) -> void:
	fillStyleBox.bg_color = HEALTH_BAR_COLOUR.gradient.sample(new_value / max_value)
	if new_value == 0:
		self.queue_free()
