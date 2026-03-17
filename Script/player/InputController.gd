extends Node
## 输入层：统一处理 InputMap，通过信号与 getter 输出，便于与教程/按键配置解耦。
## Player 只连接信号或轮询 get_move_input() / is_shoot_held()，不直接读 Input。

# ──── 技能键（与 project 输入 action 一致，扩展时只改此处）
const SKILL_KEYS: Array[StringName] = [&"Skill1", &"Skill2", &"Skill3"]

# ──── 信号：一次性操作（just_pressed 时发射）
signal interact_pressed
signal throw_pressed
signal shoot_pressed
signal reload_pressed
signal change_person_pressed
signal change_weapon_primary_pressed
signal change_weapon_secondary_pressed
signal change_hand_pressed
signal next_weapon_pressed
signal prev_weapon_pressed
signal skill_slot_pressed(slot_index: int)
signal mouse_moved(relative: Vector2)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if TutorialManager.is_look_allowed():
			mouse_moved.emit(Vector2(event.relative.x, event.relative.y))
		return

	if event.is_action_pressed("change_person") and TutorialManager.is_action_allowed(&"change_person"):
		change_person_pressed.emit()
	if Input.is_action_just_pressed("shoot") and TutorialManager.is_action_allowed(&"shoot"):
		shoot_pressed.emit()
	if Input.is_action_just_pressed("reload") and TutorialManager.is_action_allowed(&"reload"):
		reload_pressed.emit()
	if Input.is_action_just_pressed("interactable") and TutorialManager.is_action_allowed(&"interactable"):
		interact_pressed.emit()
	if event.is_action_pressed("rightclick"):
		throw_pressed.emit()

	if Input.is_action_just_pressed("change_weapon1") and TutorialManager.is_action_allowed(&"change_weapon1"):
		change_weapon_primary_pressed.emit()
	if Input.is_action_just_pressed("change_weapon2") and TutorialManager.is_action_allowed(&"change_weapon2"):
		change_weapon_secondary_pressed.emit()
	if Input.is_action_just_pressed("change_hand") and TutorialManager.is_action_allowed(&"change_hand"):
		change_hand_pressed.emit()
	if Input.is_action_just_pressed("next_weapon") and TutorialManager.is_action_allowed(&"next_weapon"):
		next_weapon_pressed.emit()
	if Input.is_action_just_pressed("prev_weapon") and TutorialManager.is_action_allowed(&"prev_weapon"):
		prev_weapon_pressed.emit()

	for i in SKILL_KEYS.size():
		if Input.is_action_just_pressed(SKILL_KEYS[i]) and TutorialManager.is_action_allowed(SKILL_KEYS[i]):
			skill_slot_pressed.emit(i)
			break


## 每帧轮询：移动输入（教程下只返回已解锁的 WASD）
func get_move_input() -> Vector2:
	if not TutorialManager.is_in_tutorial():
		return Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var v := Vector2.ZERO
	if TutorialManager.is_action_allowed(&"move_forward"):
		v.y -= Input.get_action_strength("move_forward")
	if TutorialManager.is_action_allowed(&"move_back"):
		v.y += Input.get_action_strength("move_back")
	if TutorialManager.is_action_allowed(&"move_left"):
		v.x -= Input.get_action_strength("move_left")
	if TutorialManager.is_action_allowed(&"move_right"):
		v.x += Input.get_action_strength("move_right")
	return v.clamp(Vector2(-1, -1), Vector2(1, 1))


## 按住射击（全自动武器用）
func is_shoot_held() -> bool:
	return TutorialManager.is_action_allowed(&"shoot") and Input.is_action_pressed("shoot")


## 半自动单发（just_pressed 时由外部在信号里调一次 request_single_shoot）
func is_shoot_just_pressed() -> bool:
	return TutorialManager.is_action_allowed(&"shoot") and Input.is_action_just_pressed("shoot")
