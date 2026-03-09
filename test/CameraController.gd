extends Node
## 相机与视角：鼠标转向、第一/三人称头部与俯仰、头部晃动（bob）。
## 由 InputController.mouse_moved 驱动 update_look；每帧由 Player 调 update_visual_effects。

const SPEED_MOUSE: float = 0.1
const SENSE_H: float = 0.15
const SENSE_V: float = 0.15
const BOB_SPEED_SPRINT: float = 22.0
const BOB_SPEED_WALK: float = 15.0
const BOB_SPEED_CROUCH: float = 10.0
const BOB_INTENSITY_SPRINT: float = 0.2
const BOB_INTENSITY_WALK: float = 0.1
const BOB_INTENSITY_CROUCH: float = 0.05

# 注入（Player 在 setup 时赋值）
var character_body: CharacterBody3D  # 第一人称非 freelook 时旋转身体
var nek: Node3D
var head: Node3D
var eyes: Node3D
var player_camera: Camera3D
var third_person: Camera3D
var t_person: Node3D
var speed_lerp: float = 10.0

var pitch: float = 0.0
var _bob_index: float = 0.0
var _bob_vector: Vector2 = Vector2.ZERO


func setup(
	p_character_body: CharacterBody3D,
	p_nek: Node3D,
	p_head: Node3D,
	p_eyes: Node3D,
	p_player_camera: Camera3D,
	p_third_person: Camera3D,
	p_t_person: Node3D,
	p_speed_lerp: float = 10.0
) -> void:
	character_body = p_character_body
	nek = p_nek
	head = p_head
	eyes = p_eyes
	player_camera = p_player_camera
	third_person = p_third_person
	t_person = p_t_person
	speed_lerp = p_speed_lerp


## 每帧由 Player 在收到 mouse_moved 时调用；is_first_person = player_camera.is_current()，freelook 来自 MovementComponent
func update_look(relative: Vector2, is_first_person: bool, freelook: bool = false) -> void:
	if is_first_person:
		if freelook and nek != null:
			nek.rotate_y(deg_to_rad(-relative.x * SPEED_MOUSE))
			nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		elif character_body != null:
			character_body.rotate_y(deg_to_rad(-relative.x * SPEED_MOUSE))
		if head != null:
			head.rotate_x(deg_to_rad(relative.y * SPEED_MOUSE))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	else:
		if nek != null:
			nek.rotate_y(deg_to_rad(-relative.x * SENSE_H))
		pitch = clamp(pitch - relative.y * SENSE_V, -50.0, 50.0)
		if t_person != null:
			t_person.rotation.x = deg_to_rad(pitch)


## 自由视角回正 + 头部晃动；current_state 使用 MovementComponent.PlayerState 枚举值
func update_visual_effects(
	delta: float,
	input_dir: Vector2,
	current_state: int,
	freelook: bool,
	is_on_floor: bool
) -> void:
	if not freelook and nek != null:
		nek.rotation.y = lerp(nek.rotation.y, 0.0, delta * speed_lerp)

	var bob_intensity: float
	var bob_speed: float
	match current_state:
		2:  # SPRINTING
			bob_intensity = BOB_INTENSITY_SPRINT
			bob_speed = BOB_SPEED_SPRINT
		1:  # WALKING
			bob_intensity = BOB_INTENSITY_WALK
			bob_speed = BOB_SPEED_WALK
		_:
			bob_intensity = BOB_INTENSITY_CROUCH
			bob_speed = BOB_SPEED_CROUCH

	_bob_index += bob_speed * delta
	if is_on_floor and current_state != 4 and input_dir != Vector2.ZERO:  # 4 = SLIDING
		_bob_vector.y = sin(_bob_index)
		_bob_vector.x = sin(_bob_index / 2.0) + 0.5
		if eyes != null:
			eyes.position.y = lerp(eyes.position.y, _bob_vector.y * (bob_intensity / 2.0), delta * speed_lerp)
			eyes.position.x = lerp(eyes.position.x, _bob_vector.x * bob_intensity, delta * speed_lerp)
	else:
		if eyes != null:
			eyes.position.y = lerp(eyes.position.y, 0.0, delta * speed_lerp)
			eyes.position.x = lerp(eyes.position.x, 0.0, delta * speed_lerp)
