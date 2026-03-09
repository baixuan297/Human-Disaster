extends HBoxContainer

## 在键盘的第几排 排数
@export var row_name: String = "row_0"
## 每排键盘按键内容
@export var json_path: String = "res://resource/keyBoard/keyboard_83.json"

## 缓存数据
var key_data: Dictionary = {}

func _ready():
	load_json()
	bind_row()
	
# 读取 JSON
func load_json():
	if not FileAccess.file_exists(json_path):
		push_error("JSON not found")
		return
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(text)
	if typeof(result) == TYPE_DICTIONARY:
		key_data = result


# 绑定数据
func bind_row():
	if not key_data.has(row_name):
		push_error("Row not found: " + row_name)
		return
	
	var row_array: Array = key_data[row_name]
	var children = get_children()
	
	for i in range(children.size()):
		var key_button = children[i]
		
		if i < row_array.size():
			var key_info: Dictionary = row_array[i]
			
			key_button.show()
			
			# 绑定名称
			key_button.key_name = key_info.get("name", "Key")
			
			# 绑定类型
			key_button.key_type = string_to_enum(key_info.get("type", "NORMAL"))
			
			# 如果有 custom_width
			if key_info.has("width"):
				key_button.custom_width = key_info["width"]
			
			key_button.update_visual()
		else:
			key_button.hide()


# 字符串转枚举
func string_to_enum(type_string_value: String) -> int:
	match type_string_value:
		"NORMAL":
			return 0
		"SPECIAL":
			return 1
		"SPECIAL_LONG":
			return 2
		"LONG":
			return 3
		"CUSTOM":
			return 4
		_:
			return 0
