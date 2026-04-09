extends Node
## 交互与捡物：检测交互、拾取、投掷；手持物体每帧跟随。
## Player 只调用 update() 与连接 InputController 的 interact_pressed / throw_pressed 到此组件。

# 注入
var interactable_ray: RayCast3D
var pickray: RayCast3D
var holdposition: Node3D
var joint: Generic6DOFJoint3D
var weapon_manager: Node  # 需 is_hand()、apply_ammo_supply
var player: Node  # 需 health、max_health、interact(door 等)

var pick_object: RigidBody3D = null


func setup(
	p_interactable_ray: RayCast3D,
	p_pickray: RayCast3D,
	p_holdposition: Node3D,
	p_joint: Generic6DOFJoint3D,
	p_weapon_manager: Node,
	p_player: Node
) -> void:
	interactable_ray = p_interactable_ray
	pickray = p_pickray
	holdposition = p_holdposition
	joint = p_joint
	weapon_manager = p_weapon_manager
	player = p_player


## 每帧调用：手持物体跟随 holdposition
func update() -> void:
	if pick_object == null:
		return
	var delta_pos := holdposition.global_transform.origin - pick_object.global_transform.origin
	pick_object.set_linear_velocity(delta_pos * 10.0)


## 交互键按下时由 Player 调用（或连到 InputController.interact_pressed）
func on_interact_pressed() -> void:
	var collider := interactable_ray.get_collider() if interactable_ray != null else null
	if collider == null:
		return

	# 可拾取武器：与门等统一走 interact(player)，由 WorldWeapon.interact() 内部调用 pickup(player.weapon_manager)
	if collider.is_in_group("weapon_pickup") and collider is WorldWeapon:
		collider.interact(player)
		return

	if not collider is Interactable:
		return

	if collider.is_in_group("ammo_apply_point"):
		weapon_manager.apply_ammo_supply()
		return

	if collider.is_in_group("machine"):
		player.health = player.max_health
		if player.has_signal("health_changed"):
			player.emit_signal("health_changed", player.health, player.max_health)
		return

	if collider.is_in_group("door"):
		collider.interact(player)
		return

	if collider.is_in_group("chest"):
		GameItemIds.grant_standard_test_bundle(InventoryManager)
		return

	# 未命中上述交互对象时，尝试用 pickray 拾取 RigidBody
	try_pickup_rigid()


## 投掷键按下且手持物体时由 Player 调用
func on_throw_pressed() -> void:
	if pick_object == null:
		return
	var knockback = pick_object.global_position - player.global_position
	pick_object.apply_central_impulse(knockback * 2.0)
	_remove_object()


func _pickup_object() -> void:
	var collider := pickray.get_collider() if pickray != null else null
	if collider == null or not collider is RigidBody3D:
		return
	if not weapon_manager.is_hand():
		return
	pick_object = collider
	if joint != null:
		joint.set_node_b(pick_object.get_path())


func _remove_object() -> void:
	pick_object = null
	if joint != null:
		joint.set_node_b(joint.get_path())


## 交互时若射线命中可捡 RigidBody，则拾取（与 on_interact_pressed 配合：先处理武器/门等，再尝试捡物）
func try_pickup_rigid() -> void:
	_pickup_object()
