extends Node
## 移动与状态机：从 InputController 取输入，更新状态与速度，驱动 CharacterBody3D。
## 滑铲、蹲、跑、跳跃集中在此；动画由 current_state 驱动。音效由 MovementAudioComponent 根据状态驱动。

signal landed
signal jumped
signal crouched

enum PlayerState {
	IDLE,
	WALKING,
	SPRINTING,
	CROUCHING,
	SLIDING,
	IN_AIR,
}

# ──── 常量
const JUMP_VELOCITY: float = 5.0
const SPEED_WALK: float = 5.0
const SPEED_RUN: float = 8.0
const SPEED_CROUCH: float = 2.0
const SLIDE_TIME_MAX: float = 1.0
const SLIDE_SPEED: float = 10.0
const HEAD_HEIGHT: float = 1.0

var speed_lerp: float = 10.0
var air_lerp: float = 3.0

# ──── 注入（由 Player 在 setup 时赋值）
var character: CharacterBody3D
var input_controller: Node  # 需实现 get_move_input() -> Vector2
var raycast3d: RayCast3D
var collision_stand: CollisionShape3D
var collision_crouch: CollisionShape3D
var head: Node3D
var animation_tree: AnimationTree
var player_mesh: Node3D

# ──── 状态与运行时
var current_state: PlayerState = PlayerState.IDLE
var freelook: bool = false
var SPEED_Normal: float = SPEED_WALK
var direction: Vector3 = Vector3.ZERO
var slide_timer: float = SLIDE_TIME_MAX
var slide_vector: Vector2 = Vector2.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(
	p_character: CharacterBody3D,
	p_input_controller: Node,
	p_raycast3d: RayCast3D,
	p_collision_stand: CollisionShape3D,
	p_collision_crouch: CollisionShape3D,
	p_head: Node3D,
	p_animation_tree: AnimationTree,
	p_player_mesh: Node3D
) -> void:
	character = p_character
	input_controller = p_input_controller
	raycast3d = p_raycast3d
	collision_stand = p_collision_stand
	collision_crouch = p_collision_crouch
	head = p_head
	animation_tree = p_animation_tree
	player_mesh = p_player_mesh


func process(delta: float) -> void:
	if character == null or input_controller == null:
		return
	# 自由视角：按键或滑铲中为 true
	freelook = (TutorialManager.is_action_allowed(&"free_look") and Input.is_action_pressed("free_look")) or current_state == PlayerState.SLIDING
	var input_dir: Vector2 = input_controller.get_move_input()
	_update_animation()
	_apply_gravity(delta)
	_update_movement_state(input_dir, delta)
	_apply_velocity(input_dir, delta)
	character.move_and_slide()


func _transition_to(new_state: PlayerState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	if new_state == PlayerState.CROUCHING:
		crouched.emit()


func _update_movement_state(input_dir: Vector2, delta: float) -> void:
	if current_state == PlayerState.IN_AIR and character.is_on_floor():
		_transition_to(PlayerState.IDLE)
		landed.emit()

	if current_state == PlayerState.SLIDING:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_transition_to(PlayerState.IDLE)
			freelook = false

	var crouch_pressed := TutorialManager.is_action_allowed(&"crouch") and Input.is_action_pressed("crouch")
	if crouch_pressed or current_state == PlayerState.SLIDING:
		_enter_crouch_or_slide(input_dir, delta)
	elif character.is_on_floor() and (raycast3d == null or not raycast3d.is_colliding()):
		_enter_stand_states(input_dir, delta)

	var jump_allowed := current_state not in [PlayerState.CROUCHING, PlayerState.SLIDING]
	if jump_allowed and TutorialManager.is_action_allowed(&"jump") and Input.is_action_just_pressed("jump") and character.is_on_floor():
		character.velocity.y = JUMP_VELOCITY
		_transition_to(PlayerState.IN_AIR)
		jumped.emit()
		if animation_tree != null:
			animation_tree.set("parameters/JumpShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _enter_crouch_or_slide(input_dir: Vector2, _delta: float) -> void:
	SPEED_Normal = lerp(SPEED_Normal, SPEED_CROUCH, _delta * speed_lerp)
	if head != null:
		head.position.y = lerp(head.position.y, -1.6 + HEAD_HEIGHT, _delta * speed_lerp)
	if collision_stand != null:
		collision_stand.disabled = true
	if collision_crouch != null:
		collision_crouch.disabled = false

	if current_state == PlayerState.SPRINTING and input_dir != Vector2.ZERO and current_state != PlayerState.SLIDING:
		_transition_to(PlayerState.SLIDING)
		slide_timer = SLIDE_TIME_MAX
		slide_vector = input_dir
		freelook = true
	elif current_state != PlayerState.SLIDING:
		_transition_to(PlayerState.CROUCHING)


func _enter_stand_states(input_dir: Vector2, delta: float) -> void:
	if collision_stand != null:
		collision_stand.disabled = false
	if collision_crouch != null:
		collision_crouch.disabled = true
	if head != null:
		head.position.y = lerp(head.position.y, 0.0, delta * speed_lerp)

	if input_dir == Vector2.ZERO:
		_transition_to(PlayerState.IDLE)
	elif TutorialManager.is_action_allowed(&"Run") and Input.is_action_pressed("Run") and Input.is_action_pressed("move_forward"):
		SPEED_Normal = lerp(SPEED_Normal, SPEED_RUN, delta * speed_lerp)
		_transition_to(PlayerState.SPRINTING)
	else:
		SPEED_Normal = lerp(SPEED_Normal, SPEED_WALK, delta * speed_lerp)
		_transition_to(PlayerState.WALKING)


func _apply_gravity(delta: float) -> void:
	if not character.is_on_floor():
		character.velocity.y -= gravity * delta


func _apply_velocity(input_dir: Vector2, delta: float) -> void:
	var basis := character.transform.basis
	var target_dir := (basis * Vector3(-input_dir.x, 0.0, -input_dir.y)).normalized()
	if character.is_on_floor():
		direction = lerp(direction, target_dir, delta * speed_lerp)
	elif input_dir != Vector2.ZERO:
		direction = lerp(direction, target_dir, delta * air_lerp)

	if current_state == PlayerState.SLIDING:
		direction = (basis * Vector3(slide_vector.x, 0.0, slide_vector.y)).normalized()
		SPEED_Normal = slide_timer * SLIDE_SPEED

	if direction.length_squared() > 0.01:
		character.velocity.x = direction.x * SPEED_Normal
		character.velocity.z = direction.z * SPEED_Normal
		if current_state in [PlayerState.WALKING, PlayerState.SPRINTING] and player_mesh != null:
			# 第三人称时由 Player 根据当前相机切换 look_at，此处仅第一人称不转 body
			pass
	else:
		character.velocity.x = move_toward(character.velocity.x, 0.0, SPEED_Normal)
		character.velocity.z = move_toward(character.velocity.z, 0.0, SPEED_Normal)


func _update_animation() -> void:
	if animation_tree == null:
		return
	match current_state:
		PlayerState.IDLE, PlayerState.IN_AIR:
			animation_tree.set("parameters/Movement/transition_request", "Idle")
		PlayerState.WALKING:
			animation_tree.set("parameters/Movement/transition_request", "Walk")
		PlayerState.SPRINTING:
			animation_tree.set("parameters/Movement/transition_request", "Run")
		PlayerState.CROUCHING, PlayerState.SLIDING:
			animation_tree.set("parameters/Movement/transition_request", "Crouch")
