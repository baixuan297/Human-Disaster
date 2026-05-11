extends RigidBody3D
class_name WorldWeapon

## ═══════════════════════════════════════════════════════════════
## WorldWeapon — 场景中可捡拾的武器实体（与 WeaponManager 解耦）
##
## 【解耦要点：数据与场景分离】
##   - WeaponData.tres 只存数值（弹药、伤害、射速等），不引用任何 .tscn。
##   - 场景引用由本节点持有：weapon_scene / viewmodel_scene / model_scene，
##     避免 .tres 引用 .tscn 造成的循环依赖与加载顺序问题。
#### 【调用链】Player 射线检测 "weapon_pickup" / "Interactable" → collider.interact(player)
##           → pickup(player.weapon_manager) → equip_weapon(...) → 本节点 queue_free()
##
## 【推荐场景树】
##   WorldWeapon (RigidBody3D)
##   └── CollisionShape3D
##   （展示模型由 model_scene 在 _ready 中动态实例化）
## ═══════════════════════════════════════════════════════════════

signal picked_up(weapon_data: WeaponData)

# ──── 数据（纯资源，无场景引用）────
## 武器数值与配置，来自 .tres；捡起时 duplicate() 保证每人弹药独立
@export var weapon_data: WeaponData

# ──── 场景引用（由本节点持有，捡起时传给 WeaponManager）────
## 武器逻辑场景，根节点须为 BaseWeapon 子类
@export var weapon_scene: PackedScene
## 第一人称视图模型场景，根节点须为 WeaponViewModel 子类
@export var viewmodel_scene: PackedScene
## 世界中 3D 展示模型（可选），_ready 时实例化到本节点下
@export var model_scene: PackedScene

# ──── 交互提示（与 Interactable 一致，由 interactray 射线命中时显示）────
@export var prompt_action: StringName = &"interactable"
@export var prompt_text: String = "Pick Up"

# ──── 行为选项 ────
## 生成时是否重置为满弹
@export var reset_ammo_on_spawn:   bool = true
## 捡起后是否立刻切换到此武器  
@export var auto_switch_on_pickup: bool = true
## 重新登录/加载场景时是否再次刷新（false=拾取后永久消失，true=每次加载都出现）
@export var respawn_on_reload: bool = false
## true：静止在地面（关卡掉落物）；false：刚生成时可受物理与冲量（玩家丢弃）
@export var start_frozen: bool = true
## false：关闭悬浮与自转（与 start_frozen=false 搭配用于丢弃物）
@export var enable_pickup_idle_motion: bool = true

## 运行时丢弃等：duplicate 后 resource_path 可能为空，此处供 equip_weapon 读档路径用
var pickup_data_resource_path: String = ""

# ──── 展示效果（悬浮旋转）────
@export var rotation_speed:   float = 1.2
@export var float_amplitude:  float = 0.08
@export var float_frequency:  float = 1.5

var _float_timer:   float = 0.0
var _origin_y:      float = 0.0
var _is_picking_up: bool  = false


## 由 WeaponManager 等在代码里生成地面可捡武器：世界展示模型 + 拾取碰撞体（弹药由 `weapon_data` 保留，`reset_ammo_on_spawn=false`）
## `world_display_scene` 为空时用 `weapon_scn` 作为展示（与关卡内 pistol/mp7 预制体一致，实例会设为纯展示、无碰撞）
static func create_runtime_pickup(
	data: WeaponData,
	weapon_scn: PackedScene,
	viewmodel_scn: PackedScene,
	persist_data_path: String,
	world_display_scene: PackedScene = null
) -> WorldWeapon:
	var w := WorldWeapon.new()
	w.start_frozen = false
	w.enable_pickup_idle_motion = false
	w.reset_ammo_on_spawn = false
	w.auto_switch_on_pickup = false
	w.respawn_on_reload = true
	w.collision_layer = 16
	w.collision_mask = 35
	w.weapon_data = data
	w.weapon_scene = weapon_scn
	w.viewmodel_scene = viewmodel_scn
	w.pickup_data_resource_path = persist_data_path
	if data != null and not data.Weapon_name.is_empty():
		w.prompt_text = data.Weapon_name

	var display_scn: PackedScene = world_display_scene if world_display_scene != null else weapon_scn
	var display_root: Node = display_scn.instantiate()
	if display_root != null:
		_apply_inert_pickup_display(display_root)
		w.add_child(display_root)
	else:
		push_warning("[WorldWeapon] create_runtime_pickup: 无法实例化展示场景")

	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.45, 0.16, 0.55)
	col.shape = sh
	col.position.y = 0.08
	w.add_child(col)
	return w


static func _apply_inert_pickup_display(root: Node) -> void:
	## 根节点禁用逻辑帧即可让 INHERIT 子节点停止 _process；仅对 CollisionObject3D 清零碰撞，避免逐节点改 process_mode
	root.process_mode = Node.PROCESS_MODE_DISABLED
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var cur = stack.pop_back()
		if cur == null:
			continue
		if cur is CollisionObject3D:
			var co := cur as CollisionObject3D
			co.collision_layer = 0
			co.collision_mask = 0
		for ch in cur.get_children():
			if ch is Node:
				stack.append(ch as Node)


func _ready() -> void:
	# 供 InteractionComponent 识别可拾取武器；Interactable 供 interactray 显示「拾取 [E]」提示
	add_to_group("weapon_pickup")
	add_to_group("Interactable")

	# 若已拾取且未设置可刷新，则隐藏（延迟到场景状态就绪后检查）
	call_deferred("_check_collected")

	if weapon_data == null:
		push_error("WorldWeapon [%s]: weapon_data 未设置" % name)
		return
	if weapon_scene == null:
		push_error("WorldWeapon [%s]: weapon_scene 未设置" % name)
		return
	if viewmodel_scene == null:
		push_error("WorldWeapon [%s]: viewmodel_scene 未设置" % name)
		return

	if reset_ammo_on_spawn:
		weapon_data.Current_Ammo = weapon_data.magazine
		weapon_data.Reserve_Ammo = weapon_data.Max_Ammo

	if model_scene != null:
		add_child(model_scene.instantiate())

	freeze = start_frozen
	if enable_pickup_idle_motion:
		_origin_y = global_position.y
	else:
		set_process(false)


func _process(delta: float) -> void:
	if _is_picking_up or not enable_pickup_idle_motion:
		return
	_float_timer += delta
	if float_amplitude > 0.0:
		global_position.y = _origin_y + sin(_float_timer * float_frequency) * float_amplitude
	if rotation_speed > 0.0:
		rotate_y(rotation_speed * delta)


# ═══════════════════════════════════════════════════════════════
#  Interactable 接口（与 interact.gd 一致，供 interactray 显示提示并调用）
# ═══════════════════════════════════════════════════════════════

## 返回当前按键的提示文案，供交互射线 UI 显示（格式与 interact.gd 的 Interactable 一致）
func get_prompt() -> String:
	var key_name := ""
	for action in InputMap.action_get_events(prompt_action):
		if action is InputEventKey:
			key_name = OS.get_keycode_string(action.physical_keycode)
	return prompt_text + "\n\n[" + key_name + "]"


## 玩家按交互键时由 InteractionComponent 调用。从 player 取 weapon_manager 后转发到 pickup()，
## 与门、机器等统一走 interact(player) 流程。
func interact(player_node: Node = null) -> void:
	if player_node == null:
		return
	var wm = player_node.get("weapon_manager")
	if wm is WeaponManager:
		pickup(wm)


# ═══════════════════════════════════════════════════════════════
#  公开 API（仅由 interact(player) 或直接 pickup 调用）
# ═══════════════════════════════════════════════════════════════

## 捡起武器：将数据副本与场景引用交给 WeaponManager，本节点随后销毁。
## 使用 duplicate() 保证玩家之间的弹药状态互不影响（若多人或存档读档）。
func pickup(weapon_manager: WeaponManager) -> void:
	if _is_picking_up or weapon_data == null:
		return

	_is_picking_up = true
	picked_up.emit(weapon_data)

	# 存档用：duplicate 会丢失 resource_path，需传入原始路径供读档恢复
	## deep duplicate：保留 wheel_icon 等 @export 引用，避免浅拷贝丢字段导致轮盘不显示图标
	var path_for_save := pickup_data_resource_path
	if path_for_save.is_empty():
		path_for_save = weapon_data.resource_path
	weapon_manager.equip_weapon(
		weapon_data.duplicate(true),
		weapon_scene,
		viewmodel_scene,
		auto_switch_on_pickup,
		path_for_save,
		true,
		model_scene
	)

	# 记录已拾取，重登后不再刷新（除非 respawn_on_reload=true）
	if not respawn_on_reload:
		var scene_root = get_tree().current_scene
		var scene_path = scene_root.scene_file_path if scene_root and scene_root.scene_file_path else ""
		var node_path := str(scene_root.get_path_to(self)) if scene_root else str(get_path())
		CharacterDataManager.record_pickable_collected(scene_path, node_path)

	queue_free()


## 检查是否已被拾取，若是则隐藏（重登后不再出现）
func _check_collected() -> void:
	CharacterDataManager.call_when_scene_state_ready(_do_check_collected)


func _do_check_collected() -> void:
	if respawn_on_reload or not is_inside_tree():
		return
	var scene_root = get_tree().current_scene
	if scene_root == null:
		return
	var scene_path = scene_root.scene_file_path if scene_root.scene_file_path else ""
	var node_path := str(scene_root.get_path_to(self))
	var id_str = scene_path + "|" + node_path
	if id_str in CharacterDataManager.get_collected_pickables():
		queue_free()
