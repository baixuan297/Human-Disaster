extends Node3D
class_name WeaponManager

## ═══════════════════════════════════════════════════════════════
## WeaponManager — 武器系统唯一入口（与 Player 解耦）
##
## 【设计原则】
##   - Player 只做两件事：调用本管理器的“请求类”API + 连接信号。
##   - 不持有任何武器节点引用；装备/切换/射击/换弹逻辑全部在此完成。
##
## 【调用链概览】
##   捡枪: WorldWeapon.pickup(weapon_manager)
##         → equip_weapon(data, weapon_scene, viewmodel_scene)
##         → 实例化 BaseWeapon + 动态创建 SubViewport(viewmodel)
##         → switch_to_slot() → 拔枪动画 → can_shoot = true
##
##   射击: Player 输入 → request_single_shoot() / request_auto_shoot()
##         → _do_shoot() → 射线取目标点 → 当前槽 BaseWeapon.attack()
##         → 扣弹、发 ammo_changed
##
## 【挂载位置】**CharacterBody3D（玩家根）** 的子节点，节点名建议 `Weapon_manager`。
##   - 在 _ready 中按路径解析 **FPCamera**（默认 `firstperson/nek/head/CameraRigFP/FPCamera`）
##   - viewmodel 每帧同步 `_main_camera` 的 basis；`_is_third_person_active()` 用 `not _main_camera.is_current()`
##   - 仍兼容：若父节点为 Camera3D（旧层级），则视父节点即 FPCamera
##
## 【节点绑定】自动解析（无需 Player.setup 传参）：
##   - 玩家根：父节点为 CharacterBody3D 时即 `_player`，否则沿父链查找
##   - 一摄瞄准：FPCamera 下 Aimray / aimrayend（weapon_bind_fp_* 可覆盖）
##   - 三摄瞄准：相对玩家根路径见 `PlayerViewPaths.THIRD_PERSON_AIMRAY`（weapon_bind_tp_* 可覆盖）
##
## 【禁止 autoload】若写入 project.godot autoload，父节点为根窗口，绑定会失败。
## ═══════════════════════════════════════════════════════════════

# 与 Fish_Man / CameraRigFP 默认结构一致
const _DEFAULT_FP_CAMERA_FROM_PLAYER := NodePath("firstperson/nek/head/CameraRigFP/FPCamera")
const _DEFAULT_FP_RAY_NAME := "Aimray"
const _DEFAULT_FP_RAY_END_NAME := "aimrayend"
const _DEFAULT_TP_RAY_FROM_PLAYER := PlayerViewPaths.THIRD_PERSON_AIMRAY
const _DEFAULT_TP_RAY_END_FROM_PLAYER := PlayerViewPaths.THIRD_PERSON_AIMRAY_END

# ──────────────────────────────────────────────────────────────
#  槽位常量（对外只暴露槽位索引，不暴露内部 _slots 结构）
# ──────────────────────────────────────────────────────────────

const SLOT_HAND:       int   = -1
const SLOT_PRIMARY:    int   = 0
const SLOT_SECONDARY:  int   = 1
## 收枪动画等待时间，需与 viewmodel 的 "raise" 倒放时长一致
const SWITCH_LOWER_WAIT: float = 0.35

# ──────────────────────────────────────────────────────────────
#  信号（由 Player 等订阅，实现 UI/音效等与武器逻辑解耦）
# ──────────────────────────────────────────────────────────────

## 当前装备武器弹药变化 → Player 转发给 UI（Update_Ammo）
signal ammo_changed(Current_Ammo: int, Reserve_Ammo: int)
## 射线/子弹命中敌人 → 准心反馈等
signal enemy_hit
## 弹匣打空但仍有储备 → 提示换弹
signal out_of_ammo
## 弹匣+储备均为 0 → 提示“弹药耗尽”
signal all_ammo_depleted
## 成功装备武器 → 可在此更新武器名/稀有度 UI
signal weapon_equipped(data: WeaponData, slot: int)
## 切换到徒手 → 隐藏弹药栏
signal switched_to_hand


# ──────────────────────────────────────────────────────────────
#  运行时引用（_ready 内 _bind_runtime_nodes 解析，或由 weapon_bind_* 覆盖）
# ──────────────────────────────────────────────────────────────

## 相对 **玩家 CharacterBody3D** 的第一人称相机（留空则用默认 CameraRigFP/FPCamera）
@export_group("可选绑定（留空=自动）", "weapon_bind_")
@export var weapon_bind_fp_camera: NodePath = NodePath("")
## 相对 **本 WeaponManager 节点** 的一摄射线（留空则用 FPCamera 下默认子节点名）
@export var weapon_bind_fp_ray: NodePath = NodePath("")
@export var weapon_bind_fp_ray_end: NodePath = NodePath("")
## 相对 **CharacterBody3D（玩家根）** 的三摄射线；留空则用 `PlayerViewPaths.THIRD_PERSON_AIMRAY` 等默认路径
@export var weapon_bind_tp_ray: NodePath = NodePath("")
@export var weapon_bind_tp_ray_end: NodePath = NodePath("")

var _player: CharacterBody3D = null
var _world_root: Node3D = null  ## 子弹父节点，一般为 player.get_parent()
var _main_camera: Camera3D = null  ## 第一人称相机；每帧同步 viewmodel 旋转
var _aimray_first: RayCast3D = null
var _aimray_end_first: Node3D = null
var _aimray_third: RayCast3D = null
var _aimray_end_third: Node3D = null


# ──────────────────────────────────────────────────────────────
#  槽位数据（内部结构，外部仅通过 get_current_data() 等访问）
#  _slots[slot] = { "data": WeaponData, "weapon": BaseWeapon,
#                   "viewmodel": WeaponViewModel, "container": SubViewportContainer }
# ──────────────────────────────────────────────────────────────

var _slots: Dictionary = {
	SLOT_PRIMARY:   {"data": null, "weapon": null, "viewmodel": null, "container": null},
	SLOT_SECONDARY: {"data": null, "weapon": null, "viewmodel": null, "container": null},
}

var current_slot:   int  = SLOT_HAND
var can_shoot:      bool = false   ## 切换/换弹过程中为 false，防止误触
var _is_switching:  bool = false
## 本次按下射击键是否已播过空仓音，松开后重置，保证一次点击只播一次
var _dry_fire_played_this_trigger: bool = false


# ═══════════════════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		push_warning("WeaponManager: 无父节点，已跳过绑定。")
		return
	if not (parent_node is CharacterBody3D) and not (parent_node is Camera3D):
		push_warning(
			"WeaponManager: 父节点应为 CharacterBody3D 或（旧版）Camera3D，当前已跳过绑定；禁止加入 autoload。"
		)
		return
	_bind_runtime_nodes()


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_released("shoot"):
		_dry_fire_played_this_trigger = false
	# 只同步旋转，不复制主场景坐标（viewmodel 在独立 World3D 中，位置应保持原点附近）
	if _main_camera == null or current_slot == SLOT_HAND:
		return
	var vm := _get_current_viewmodel()
	if vm != null:
		vm.global_transform = Transform3D(_main_camera.global_transform.basis, Vector3.ZERO)


# ═══════════════════════════════════════════════════════════════
#  内部：自发现节点（_ready，早于 Player._ready）
# ═══════════════════════════════════════════════════════════════

func _bind_runtime_nodes() -> void:
	var parent_node := get_parent()

	if parent_node is CharacterBody3D:
		_player = parent_node as CharacterBody3D
	elif parent_node is Camera3D:
		# 旧层级：挂在 FPCamera 下
		_main_camera = parent_node as Camera3D
		_player = _find_character_body_ancestor()
	else:
		_player = _find_character_body_ancestor()

	if _player == null:
		push_error("WeaponManager: 未找到 CharacterBody3D，无法绑定玩家")
		return

	if _main_camera == null:
		var fp_path := weapon_bind_fp_camera if not weapon_bind_fp_camera.is_empty() else _DEFAULT_FP_CAMERA_FROM_PLAYER
		_main_camera = _player.get_node_or_null(fp_path) as Camera3D
		if _main_camera == null:
			push_error("WeaponManager: 未找到第一人称 FPCamera（路径 %s）" % fp_path)
			return

	_world_root = _player.get_parent() as Node3D

	# 一摄：默认 FPCamera 下子节点；可填相对本 WeaponManager 的 NodePath
	if weapon_bind_fp_ray.is_empty():
		_aimray_first = _main_camera.get_node_or_null(_DEFAULT_FP_RAY_NAME) as RayCast3D
	else:
		_aimray_first = get_node_or_null(weapon_bind_fp_ray) as RayCast3D

	if weapon_bind_fp_ray_end.is_empty():
		_aimray_end_first = _main_camera.get_node_or_null(_DEFAULT_FP_RAY_END_NAME) as Node3D
	else:
		_aimray_end_first = get_node_or_null(weapon_bind_fp_ray_end) as Node3D

	# 三摄：默认相对玩家根；可填相对玩家根的 NodePath
	var tp_ray_path := weapon_bind_tp_ray if not weapon_bind_tp_ray.is_empty() else _DEFAULT_TP_RAY_FROM_PLAYER
	var tp_end_path := weapon_bind_tp_ray_end if not weapon_bind_tp_ray_end.is_empty() else _DEFAULT_TP_RAY_END_FROM_PLAYER
	_aimray_third = _player.get_node_or_null(tp_ray_path) as RayCast3D
	_aimray_end_third = _player.get_node_or_null(tp_end_path) as Node3D

	if _aimray_first == null:
		push_warning("WeaponManager: 未找到第一人称 Aimray（%s），射击瞄准可能异常" % _DEFAULT_FP_RAY_NAME)
	if _aimray_end_first == null:
		push_warning("WeaponManager: 未找到第一人称 aimrayend（%s）" % _DEFAULT_FP_RAY_END_NAME)
	if _aimray_third == null:
		push_warning("WeaponManager: 未找到第三人称瞄准射线: %s" % tp_ray_path)
	if _aimray_end_third == null:
		push_warning("WeaponManager: 未找到第三人称瞄准终点: %s" % tp_end_path)


func _find_character_body_ancestor() -> CharacterBody3D:
	var n: Node = self
	while n:
		if n is CharacterBody3D:
			return n as CharacterBody3D
		n = n.get_parent()
	return null


# ═══════════════════════════════════════════════════════════════
#  公开 API：装备武器（仅由 WorldWeapon.pickup() 或测试调用）
#
#  解耦要点：weapon_scene / viewmodel_scene 由调用方传入，不放在 WeaponData 中，
#  避免 .tres 引用 .tscn 造成的循环依赖与加载顺序问题。
# ═══════════════════════════════════════════════════════════════

func equip_weapon(
	data:            WeaponData,
	weapon_scene:    PackedScene,
	viewmodel_scene: PackedScene,
	auto_switch:     bool = true,
	data_resource_path: String = ""
) -> void:
	if data == null:
		push_error("WeaponManager.equip_weapon: data 为 null")
		return
	if weapon_scene == null:
		push_error("WeaponManager: weapon_scene 为 null（检查 WorldWeapon 的 weapon_scene 字段）")
		return
	if viewmodel_scene == null:
		push_error("WeaponManager: viewmodel_scene 为 null（检查 WorldWeapon 的 viewmodel_scene 字段）")
		return

	var slot := _slot_from_data(data)

	# 同槽已有武器则先释放，再实例化新武器与 viewmodel
	_clear_slot(slot)

	# 实例化逻辑节点（负责射速冷却与子弹生成），并注入数据与父节点引用
	var new_weapon: BaseWeapon = weapon_scene.instantiate()
	new_weapon.setup(data, _player, _world_root)
	add_child(new_weapon)
	new_weapon.visible = false # **

	# 第一人称模型放在独立 SubViewport 中渲染；Container 挂到主 Viewport 下才能正确全屏
	var container := _create_viewmodel_container(viewmodel_scene)
	_player.get_viewport().add_child(container)
	container.visible = false

	var new_vm := _find_viewmodel_in_container(container)

	_slots[slot]["data"]      = data
	_slots[slot]["weapon"]    = new_weapon
	_slots[slot]["viewmodel"] = new_vm
	_slots[slot]["container"] = container
	# 存档用：优先用传入的 data_resource_path（WorldWeapon 捡起时 duplicate 会丢失 path）
	_slots[slot]["data_path"] = data_resource_path if data_resource_path != "" else (data.resource_path if data.resource_path != "" else "")
	_slots[slot]["weapon_scene_path"] = weapon_scene.resource_path if weapon_scene.resource_path != "" else ""
	_slots[slot]["viewmodel_scene_path"] = viewmodel_scene.resource_path if viewmodel_scene.resource_path != "" else ""

	weapon_equipped.emit(data, slot)

	if auto_switch:
		switch_to_slot.call_deferred(slot)


# ═══════════════════════════════════════════════════════════════
#  公开 API：武器切换（Player 通过 switch_to_primary/secondary/hand 调用）
# ═══════════════════════════════════════════════════════════════

## 切换槽位：收枪动画 → 等待 SWITCH_LOWER_WAIT → 显示新武器 → 拔枪动画 → 允许射击
func switch_to_slot(target_slot: int) -> void:
	if _is_switching or target_slot == current_slot:
		return
	if target_slot != SLOT_HAND and _slots.get(target_slot, {}).get("data") == null:
		return

	_is_switching = true
	can_shoot     = false

	# 1. 当前持枪则播放收枪动画并等待
	var old_vm        := _get_current_viewmodel()
	var old_container := _get_current_container()
	if old_vm != null:
		old_vm.play_lower()
		await get_tree().create_timer(SWITCH_LOWER_WAIT).timeout
	if old_container != null:
		old_container.visible = false

	# 2. 切换当前槽位
	current_slot = target_slot

	if target_slot == SLOT_HAND:
		switched_to_hand.emit()
		_is_switching = false
		return

	# 3. 装备音（有 audio_data 时播放，解耦：无音效资源的武器不报错）
	_play_equip(_get_current_data(), _player.global_position)

	# 4. 显示新武器 viewmodel 并播放拔枪动画，结束后允许射击
	var new_container := _get_current_container()
	var new_vm        := _get_current_viewmodel()
	if new_container != null:
		new_container.visible = true
	if new_vm != null:
		var raise_time := new_vm.play_raise()
		await get_tree().create_timer(raise_time).timeout

	_emit_current_ammo()
	can_shoot     = true
	_is_switching = false


func switch_to_primary()   -> void: await switch_to_slot(SLOT_PRIMARY)
func switch_to_secondary() -> void: await switch_to_slot(SLOT_SECONDARY)
func switch_to_hand()      -> void: await switch_to_slot(SLOT_HAND)

## 按槽位顺序循环切换：primary → secondary → hand → primary（空槽跳过）
func switch_to_next() -> void:
	var target := _get_cycled_slot(1)
	if target != current_slot:
		await switch_to_slot(target)

## 按槽位顺序逆向循环：primary → hand → secondary → primary
func switch_to_prev() -> void:
	var target := _get_cycled_slot(-1)
	if target != current_slot:
		await switch_to_slot(target)

## 获取循环中的下一/上一槽位，dir=1 为 next，-1 为 prev；空槽跳过
func _get_cycled_slot(dir: int) -> int:
	var cycle: Array[int] = []
	if has_weapon_in_slot(SLOT_PRIMARY):
		cycle.append(SLOT_PRIMARY)
	if has_weapon_in_slot(SLOT_SECONDARY):
		cycle.append(SLOT_SECONDARY)
	cycle.append(SLOT_HAND)
	if cycle.is_empty():
		return current_slot
	var idx: int = cycle.find(current_slot)
	if idx < 0:
		idx = 0
	idx = (idx + dir) % cycle.size()
	if idx < 0:
		idx += cycle.size()
	return cycle[idx]


# ═══════════════════════════════════════════════════════════════
#  公开 API：射击（Player 在 _input / _physics_process 中调用，不直接操作武器节点）
# ═══════════════════════════════════════════════════════════════

## 半自动：仅按下瞬间触发一发（手枪等）
func request_single_shoot() -> void:
	if not _can_fire():
		return
	var data := _get_current_data()
	if data == null or data.Auto_Fire:
		return
	_do_shoot(data)


## 全自动：按住每帧可触发（冲锋枪等），实际射速由 BaseWeapon.fire_rate 控制
func request_auto_shoot() -> void:
	if not _can_fire():
		return
	var data := _get_current_data()
	if data == null or not data.Auto_Fire:
		return
	_do_shoot(data)


# ═══════════════════════════════════════════════════════════════
#  公开 API：换弹 / 补给 / 晃动 / 查询
# ═══════════════════════════════════════════════════════════════

func request_reload() -> void:
	var data := _get_current_data()
	var vm   := _get_current_viewmodel()
	if data == null or vm == null or vm.is_reloading():
		return
	if not data.can_reload():
		if data.Reserve_Ammo <= 0:
			all_ammo_depleted.emit()
		return

	_play_reload(data, _player.global_position)
	can_shoot = false
	var reload_dur := vm.play_reload()
	await get_tree().create_timer(reload_dur).timeout

	data.do_reload()
	_emit_current_ammo()

	if data.Reserve_Ammo <= 0:
		out_of_ammo.emit()

	can_shoot = true


# ═══════════════════════════════════════════════════════════════
#  公开 API：补给 / 晃动 / 查询
# ═══════════════════════════════════════════════════════════════

## 弹药补给站交互：将当前武器弹匣与储备补满，并通知 UI
func apply_ammo_supply() -> void:
	var data := _get_current_data()
	if data == null:
		return
	data.Current_Ammo = data.magazine
	data.Reserve_Ammo = data.Max_Ammo
	_emit_current_ammo()

## 将鼠标位移传给当前 viewmodel，用于第一人称枪身晃动（由 Player._input MouseMotion 调用）
func apply_sway(mouse_delta: Vector2) -> void:
	var vm: WeaponViewModel = _get_current_viewmodel()
	if vm != null:
		vm.sway(mouse_delta)

func is_hand() -> bool:
	return current_slot == SLOT_HAND

func get_current_data() -> WeaponData:
	return _get_current_data()

func has_weapon_in_slot(slot: int) -> bool:
	return _slots.get(slot, {}).get("data") != null


## 退出存档：当前槽位、各槽弹药与资源路径（随 stats 一并 POST 到后端 loadout 字段）
func get_serializable_loadout() -> Dictionary:
	var slots_out := {}
	for slot in [SLOT_PRIMARY, SLOT_SECONDARY]:
		var s: Dictionary = _slots.get(slot, {})
		var d: WeaponData = s.get("data")
		if d == null:
			continue
		slots_out[str(slot)] = {
			"data_path": s.get("data_path", ""),
			"weapon_scene_path": s.get("weapon_scene_path", ""),
			"viewmodel_scene_path": s.get("viewmodel_scene_path", ""),
			"current_ammo": d.Current_Ammo,
			"reserve_ammo": d.Reserve_Ammo,
		}
	return {"version": 1, "current_slot": current_slot, "slots": slots_out}


## 读档：先清空双槽再按存档装备，最后切回记录的槽位（需 await）
func apply_loadout_from_dict(loadout: Dictionary) -> void:
	if loadout.get("version", 0) < 1 or _player == null:
		return
	for slot in [SLOT_PRIMARY, SLOT_SECONDARY]:
		_clear_slot(slot)
	current_slot = SLOT_HAND
	can_shoot = false
	_is_switching = false

	var slots_data: Dictionary = loadout.get("slots", {})
	for slot_key in slots_data:
		var slot: int = int(slot_key)
		if slot != SLOT_PRIMARY and slot != SLOT_SECONDARY:
			continue
		var entry: Dictionary = slots_data[slot_key]
		var dp: String = str(entry.get("data_path", ""))
		var wsp: String = str(entry.get("weapon_scene_path", ""))
		var vsp: String = str(entry.get("viewmodel_scene_path", ""))
		if wsp.is_empty() or vsp.is_empty() or dp.is_empty():
			continue
		if not ResourceLoader.exists(dp) or not ResourceLoader.exists(wsp) or not ResourceLoader.exists(vsp):
			push_warning("[WeaponManager] 读档跳过槽 %d：资源缺失 %s" % [slot, dp])
			continue
		var base_res = load(dp)
		if not (base_res is WeaponData):
			continue
		var wdata: WeaponData = (base_res as WeaponData).duplicate(true)
		# 显式处理弹药：0 是有效值，必须区分「key 不存在」与「值为 0」
		# 兼容 reserveAmmo（驼峰）与 reserve_ammo（蛇形）
		var curr = entry.get("current_ammo", entry.get("currentAmmo"))
		var resv = entry.get("reserve_ammo", entry.get("reserveAmmo"))
		wdata.Current_Ammo = int(curr) if curr != null else wdata.magazine
		wdata.Reserve_Ammo = int(resv) if resv != null else wdata.Max_Ammo
		var ws: PackedScene = load(wsp) as PackedScene
		var vs: PackedScene = load(vsp) as PackedScene
		if ws == null or vs == null:
			continue
		equip_weapon(wdata, ws, vs, false, dp)

	var target_slot: int = int(loadout.get("current_slot", SLOT_HAND))
	if target_slot != current_slot:
		await switch_to_slot(target_slot)
	# 徒手槽或未走拔枪动画分支时，保证可再次操作
	if current_slot == SLOT_HAND:
		can_shoot = true
		_is_switching = false


# ═══════════════════════════════════════════════════════════════
#  内部：射击执行（统一入口，半自动/全自动仅区分由谁调用）
# ═══════════════════════════════════════════════════════════════

func _do_shoot(data: WeaponData) -> void:
	var vm     := _get_current_viewmodel()
	var weapon := _get_current_weapon()
	if vm == null or weapon == null or vm.is_reloading():
		return

	# 提前算枪口位置（空仓音与射击音都用此位置）
	var muzzle_pos := _viewmodel_muzzle_to_world(vm)

	if data.is_empty():
		if not _dry_fire_played_this_trigger:
			_play_dry_fire(data, muzzle_pos)
			_dry_fire_played_this_trigger = true
		request_reload()
		return

	if vm.is_firing():
		return

	vm.play_fire()

	# 根据第一/三人称选择射线与终点节点，取 muzzle 与 target 供 BaseWeapon.attack
	var is_third   := _is_third_person_active()
	var ray        := _aimray_third    if is_third else _aimray_first
	var ray_end    := _aimray_end_third if is_third else _aimray_end_first
	var target_pos := Vector3.ZERO

	if ray != null and ray.is_colliding():
		target_pos = ray.get_collision_point()
		if data.Auto_Fire:
			_handle_raycast_impact(ray.get_collider(), target_pos, data, ray)
	else:
		target_pos = ray_end.global_position if ray_end != null \
				else muzzle_pos + _player.global_transform.basis.z * -100.0

	weapon.attack(muzzle_pos, target_pos)
	_play_weapon_shoot(data, muzzle_pos)

	data.Current_Ammo -= 1
	_emit_current_ammo()


## 将 viewmodel 的枪口位置转换到主场景世界坐标（从枪口射出，而非相机中心）
func _viewmodel_muzzle_to_world(vm: WeaponViewModel) -> Vector3:
	var muzzle_in_viewport: Vector3 = vm.get_muzzle_global_position()
	# viewport 内 muzzle 已是“旋转后”的向量，需用 viewmodel 逆变换得到枪口相对根节点的本地偏移
	var muzzle_local: Vector3 = (vm.global_transform.affine_inverse() * muzzle_in_viewport)
	return _main_camera.global_position + _main_camera.global_transform.basis * muzzle_local


## 射线命中时的伤害与推力（敌人用 AttackData，可移动物用冲量）
func _handle_raycast_impact(collider: Node, _hit_point: Vector3, data: WeaponData, aim_ray: RayCast3D = null) -> void:
	if collider == null:
		return
	if collider.is_in_group("enemy") and collider.has_method("enemy_hit"):
		var override_crit_rate: float = -1.0
		var override_crit_mult: float = -1.0
		if _player and _player.get("player_stats"):
			var s = _player.player_stats
			if s:
				override_crit_rate = s.current_critical_rate
				override_crit_mult = s.current_critical_damage
		var result := data.calculate_damage(override_crit_rate, override_crit_mult)
		var attack := AttackData.create_weapon_attack(data, _player)
		attack.base_damage = result[0]
		collider.enemy_hit(attack)
		enemy_hit.emit()
	if collider.is_in_group("moveObject") and collider is RigidBody3D:
		var r: RayCast3D = aim_ray if aim_ray != null else _aimray_first
		if r == null:
			return
		var push_dir := -r.global_transform.basis.z.normalized()
		collider.apply_central_impulse(push_dir * 5.0)


# ═══════════════════════════════════════════════════════════════
#  内部：武器音效（仅当 WeaponData.audio_data 存在时播放，无资源武器不报错）
# ═══════════════════════════════════════════════════════════════

func _play_weapon_shoot(data: WeaponData, sound_position: Vector3) -> void:
	if data == null or data.audio_data == null:
		return
	AudioManager.play_weapon_shoot(sound_position, data.audio_data)


func _play_dry_fire(data: WeaponData, sound_position: Vector3) -> void:
	if data == null or data.audio_data == null or data.audio_data.dry_fire_stream == null:
		return
	AudioManager.play_dry_fire(sound_position, data.audio_data.dry_fire_stream)


func _play_reload(data: WeaponData, sound_position: Vector3) -> void:
	if data == null or data.audio_data == null or data.audio_data.reload_stream == null:
		return
	AudioManager.play_reload(sound_position, data.audio_data.reload_stream)


func _play_equip(data: WeaponData, sound_position: Vector3) -> void:
	if data == null or data.audio_data == null or data.audio_data.equip_stream == null:
		return
	AudioManager.play_equip(sound_position, data.audio_data.equip_stream)


# ═══════════════════════════════════════════════════════════════
#  内部：SubViewport 动态创建（第一人称武器单独一层渲染，避免与场景深度冲突）
# ═══════════════════════════════════════════════════════════════

func _create_viewmodel_container(viewmodel_scene: PackedScene) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	# 必须使用独立世界，否则会渲染主场景导致“捡枪后出现和当前场景一样的画面”
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = true
	viewport.size = DisplayServer.window_get_size()

	get_tree().root.size_changed.connect(func() -> void:
		if is_instance_valid(viewport):
			viewport.size = DisplayServer.window_get_size()
	)

	# 独立 World3D 无默认光照，会导致 viewmodel 全黑：添加环境光 + 平行光
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0, 0, 0, 0)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(1, 1, 1)
	env_res.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env_res
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.0
	viewport.add_child(light)

	var vm: WeaponViewModel = viewmodel_scene.instantiate()
	viewport.add_child(vm)
	container.add_child(viewport)
	return container


func _find_viewmodel_in_container(container: SubViewportContainer) -> WeaponViewModel:
	for child in container.get_children():
		if child is SubViewport:
			for subchild in child.get_children():
				if subchild is WeaponViewModel:
					return subchild
	push_error("WeaponManager: 在 SubViewportContainer 中找不到 WeaponViewModel")
	return null


# ═══════════════════════════════════════════════════════════════
#  内部：槽位与当前引用
# ═══════════════════════════════════════════════════════════════

## 释放所有 viewmodel 容器与武器节点（场景切换时调用，避免 viewmodel 残留在根 viewport）
func clear_all_viewmodels() -> void:
	for slot in [SLOT_PRIMARY, SLOT_SECONDARY]:
		var s = _slots[slot]
		if s["weapon"] != null:
			s["weapon"].queue_free()
			s["weapon"] = null
		if s["container"] != null:
			s["container"].queue_free()
			s["container"] = null
		s["viewmodel"] = null
		s["data"] = null
		s["data_path"] = ""
		s["weapon_scene_path"] = ""
		s["viewmodel_scene_path"] = ""
	current_slot = SLOT_HAND
	can_shoot = false
	_is_switching = false


func _clear_slot(slot: int) -> void:
	var s = _slots[slot]
	if s["weapon"] != null:
		s["weapon"].queue_free()
		s["weapon"] = null
	if s["container"] != null:
		s["container"].queue_free()
		s["container"] = null
	s["viewmodel"] = null
	s["data"]      = null
	s["data_path"] = ""
	s["weapon_scene_path"] = ""
	s["viewmodel_scene_path"] = ""


func _can_fire() -> bool:
	return can_shoot and not _is_switching

func _get_current_viewmodel() -> WeaponViewModel:
	if current_slot == SLOT_HAND:
		return null
	return _slots.get(current_slot, {}).get("viewmodel", null)

func _get_current_weapon() -> BaseWeapon:
	if current_slot == SLOT_HAND:
		return null
	return _slots.get(current_slot, {}).get("weapon", null)

func _get_current_container() -> SubViewportContainer:
	if current_slot == SLOT_HAND:
		return null
	return _slots.get(current_slot, {}).get("container", null)

func _get_current_data() -> WeaponData:
	if current_slot == SLOT_HAND:
		return null
	return _slots.get(current_slot, {}).get("data", null)

func _slot_from_data(data: WeaponData) -> int:
	match data.weapon_slot:
		WeaponData.WeaponSlot.PRIMARY:   return SLOT_PRIMARY
		WeaponData.WeaponSlot.SECONDARY: return SLOT_SECONDARY
		_:                               return SLOT_PRIMARY

## 判断当前是否为第三人称（本节点挂载在 Camera3D 下，父节点即主相机）
func _is_third_person_active() -> bool:
	if _main_camera == null:
		return false
	return not _main_camera.is_current()

func _emit_current_ammo() -> void:
	var data := _get_current_data()
	if data != null:
		ammo_changed.emit(data.Current_Ammo, data.Reserve_Ammo)
