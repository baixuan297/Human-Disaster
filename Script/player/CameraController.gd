extends Node
## FP：nek/head/bob；TP：Yaw/Pitch/SpringArm、跟随、避障、臂长（世界米÷scale.y）、锁定。不读 Input；子路径见 `PlayerViewPaths`。

const SPEED_MOUSE: float = 0.1
const BOB_SPEED_SPRINT: float = 22.0
const BOB_SPEED_WALK: float = 15.0
const BOB_SPEED_CROUCH: float = 10.0
const BOB_INTENSITY_SPRINT: float = 0.2
const BOB_INTENSITY_WALK: float = 0.1
const BOB_INTENSITY_CROUCH: float = 0.05

## 第三人称：俯仰角限制（度）
const TP_PITCH_MIN_DEG: float = -55.0
const TP_PITCH_MAX_DEG: float = 55.0
## 鼠标灵敏度（弧度/像素），与 FP 的 deg*SPEED_MOUSE 量级接近，避免像素 delta 过大时乱甩
const TP_LOOK_SENS: float = 0.002
## 跟随：枢轴目标为世界空间高度（米）；本地 position 会除以角色 scale.y（Fish_Man 根节点 scale=0.3 时必算）
const TP_PIVOT_HEIGHT_WORLD: float = 1.75
## 惯性：速度引起的本地偏移系数
const TP_FOLLOW_VELOCITY_LAG: float = 0.055
const TP_FOLLOW_POSITION_SMOOTH: float = 8.0
## SpringArm 臂长（世界空间米）；写入节点前除以 scale.y
const TP_SPRING_LENGTH_EXPLORE_WORLD: float = 5.25
const TP_SPRING_LENGTH_MELEE_WORLD: float = 3.35
const TP_SPRING_LENGTH_SMOOTH: float = 6.0
## 锁定目标时角色朝向平滑
const LOCK_ON_ROTATE_SPEED: float = 5.5

# 注入（Player 在 setup 时赋值）
var character_body: CharacterBody3D
var nek: Node3D
var head: Node3D
var camera_rig_fp: Node3D
var third_person: Camera3D
## 第三人称根节点（含 Yaw/Pitch/SpringArm）
var t_person: Node3D
var speed_lerp: float = 10.0
var _weapon_manager: Node = null

var _tp_yaw_pivot: Node3D = null
var _tp_pitch_pivot: Node3D = null
var _tp_spring_arm: SpringArm3D = null
var _tp_pitch_deg: float = -12.0
var _tp_follow_offset_local: Vector3 = Vector3.ZERO
var _tp_current_spring_length_world: float = TP_SPRING_LENGTH_EXPLORE_WORLD
var _lock_on_target: Node3D = null

var _bob_index: float = 0.0
var _bob_vector: Vector2 = Vector2.ZERO


func setup(
	p_character_body: CharacterBody3D,
	p_nek: Node3D,
	p_head: Node3D,
	p_camera_rig_fp: Node3D,
	p_third_person: Camera3D,
	p_t_person: Node3D,
	p_speed_lerp: float = 10.0,
	p_weapon_manager: Node = null
) -> void:
	character_body = p_character_body
	nek = p_nek
	head = p_head
	camera_rig_fp = p_camera_rig_fp
	third_person = p_third_person
	t_person = p_t_person
	speed_lerp = p_speed_lerp
	_weapon_manager = p_weapon_manager
	_resolve_third_person_pivots()


func _resolve_third_person_pivots() -> void:
	if t_person == null:
		return
	_tp_yaw_pivot = t_person.get_node_or_null(PlayerViewPaths.TP_REL_YAW) as Node3D
	_tp_pitch_pivot = t_person.get_node_or_null(PlayerViewPaths.TP_REL_PITCH) as Node3D
	_tp_spring_arm = t_person.get_node_or_null(PlayerViewPaths.TP_REL_SPRING_ARM) as SpringArm3D
	if _tp_spring_arm != null and character_body != null:
		_tp_spring_arm.add_excluded_object(character_body.get_rid())
		var sy0 := _tp_unified_scale_y()
		_tp_current_spring_length_world = _tp_spring_arm.spring_length * sy0


func set_lock_on_target(target: Node3D) -> void:
	_lock_on_target = target


func clear_lock_on_target() -> void:
	_lock_on_target = null


func has_lock_on_target() -> bool:
	return _lock_on_target != null and is_instance_valid(_lock_on_target)


func get_lock_on_target() -> Node3D:
	return _lock_on_target


func _tp_unified_scale_y() -> float:
	if character_body == null:
		return 1.0
	return maxf(absf(character_body.scale.y), 0.0001)


## 第三人称移动用的水平朝向基（仅 yaw，与相机一致）
func get_third_person_movement_basis() -> Basis:
	if third_person == null:
		return character_body.global_transform.basis
	var forward := -third_person.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 1.0e-6:
		return character_body.global_transform.basis
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	return Basis(right, Vector3.UP, -forward).orthonormalized()


## 由 Player 在 mouse_moved 时调用；`is_first_person` 由 Player 按当前激活相机显式传入（勿仅用 FP is_current 推断）。
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
		_update_third_person_look(relative)


func _update_third_person_look(relative: Vector2) -> void:
	if _tp_yaw_pivot != null:
		_tp_yaw_pivot.rotate_y(-relative.x * TP_LOOK_SENS)
	_tp_pitch_deg = clamp(
		_tp_pitch_deg - rad_to_deg(relative.y * TP_LOOK_SENS), TP_PITCH_MIN_DEG, TP_PITCH_MAX_DEG
	)
	if _tp_pitch_pivot != null:
		_tp_pitch_pivot.rotation.x = deg_to_rad(_tp_pitch_deg)


## 第三人称：跟随、避障臂长、锁定；须在 movement_component.process 之后调用
func update_third_person_camera(delta: float) -> void:
	if third_person == null or not third_person.is_current():
		return
	if t_person == null or character_body == null:
		return

	var sy := _tp_unified_scale_y()
	var target_pivot := Vector3(0.0, TP_PIVOT_HEIGHT_WORLD / sy, 0.0)
	var horizontal_vel := Vector3(character_body.velocity.x, 0.0, character_body.velocity.z)
	var local_vel := character_body.global_transform.basis.inverse() * horizontal_vel
	var lag := Vector3(-local_vel.x, 0.0, -local_vel.z) * TP_FOLLOW_VELOCITY_LAG
	_tp_follow_offset_local = _tp_follow_offset_local.lerp(lag, clampf(delta * TP_FOLLOW_POSITION_SMOOTH, 0.0, 1.0))
	t_person.rotation = Vector3.ZERO
	t_person.position = t_person.position.lerp(target_pivot + _tp_follow_offset_local, clampf(delta * TP_FOLLOW_POSITION_SMOOTH, 0.0, 1.0))

	_update_lock_on_rotation(delta)
	_update_dynamic_spring_length(delta)


func _update_lock_on_rotation(delta: float) -> void:
	if _lock_on_target == null or not is_instance_valid(_lock_on_target):
		return
	if character_body == null or _tp_yaw_pivot == null:
		return
	var p := character_body.global_position
	var t := _lock_on_target.global_position
	var dx := t.x - p.x
	var dz := t.z - p.z
	if dx * dx + dz * dz < 0.01:
		return
	# 只转 Yaw 枢轴（本地 Y），勿转 CharacterBody3D。世界方位 = 角色 Y + 本地 yaw；目标在身后一侧用 +π。
	var want_cam_yaw_world := atan2(dx, dz) + PI
	var target_local_yaw := want_cam_yaw_world - character_body.rotation.y
	_tp_yaw_pivot.rotation.y = lerp_angle(
		_tp_yaw_pivot.rotation.y, target_local_yaw, clampf(delta * LOCK_ON_ROTATE_SPEED, 0.0, 1.0)
	)


func _update_dynamic_spring_length(delta: float) -> void:
	if _tp_spring_arm == null:
		return
	var wants_melee := false
	if _weapon_manager is WeaponManager:
		wants_melee = (_weapon_manager as WeaponManager).is_hand()
	var target_len_world := TP_SPRING_LENGTH_MELEE_WORLD if wants_melee else TP_SPRING_LENGTH_EXPLORE_WORLD
	_tp_current_spring_length_world = lerpf(
		_tp_current_spring_length_world, target_len_world, clampf(delta * TP_SPRING_LENGTH_SMOOTH, 0.0, 1.0)
	)
	_tp_spring_arm.spring_length = _tp_current_spring_length_world / _tp_unified_scale_y()


## 自由视角回正 + 头部晃动；current_state 使用 MovementComponent.PlayerState 枚举值
func update_visual_effects(
	delta: float,
	input_dir: Vector2,
	current_state: int,
	freelook: bool,
	is_on_floor: bool
) -> void:
	var is_third_person := third_person != null and third_person.is_current()
	if not freelook and nek != null and not is_third_person:
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
		if camera_rig_fp != null:
			camera_rig_fp.position.y = lerp(camera_rig_fp.position.y, _bob_vector.y * (bob_intensity / 2.0), delta * speed_lerp)
			camera_rig_fp.position.x = lerp(camera_rig_fp.position.x, _bob_vector.x * bob_intensity, delta * speed_lerp)
	else:
		if camera_rig_fp != null:
			camera_rig_fp.position.y = lerp(camera_rig_fp.position.y, 0.0, delta * speed_lerp)
			camera_rig_fp.position.x = lerp(camera_rig_fp.position.x, 0.0, delta * speed_lerp)
