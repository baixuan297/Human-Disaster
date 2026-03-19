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
## 【挂载位置】必须为 Camera3D 子节点，以便 _is_third_person_active() 判断视角
##   Player/firstperson/nek/head/eyes/Camera3D/Weapon_manager (Node3D)
## ═══════════════════════════════════════════════════════════════

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
#  运行时注入（由 Player._ready → setup() 一次性注入，避免硬编码路径）
# ──────────────────────────────────────────────────────────────

var _player:           CharacterBody3D = null
var _world_root:       Node3D          = null  ## 子弹/弹道父节点，一般为 player.get_parent()
var _main_camera:      Camera3D        = null  ## 每帧同步 viewmodel 的 global_transform
var _aimray_first:     RayCast3D        = null
var _aimray_end_first:  Node3D          = null
var _aimray_third:     RayCast3D        = null
var _aimray_end_third:  Node3D          = null


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
#  公开 API：初始化（由 Player._ready 调用一次）
# ═══════════════════════════════════════════════════════════════

## 注入玩家、相机与射线引用，避免 WeaponManager 内硬编码节点路径。
## 调用方：Player._ready() 中 weapon_manager.setup(self, player_camera, ...)
func setup(
	player:           CharacterBody3D,
	main_camera:      Camera3D,
	aimray_first:     RayCast3D,
	aimray_end_first: Node3D,
	aimray_third:     RayCast3D,
	aimray_end_third: Node3D
) -> void:
	_player           = player
	_world_root       = player.get_parent()  # 子弹挂到场景根，不随相机移动
	_main_camera      = main_camera
	_aimray_first     = aimray_first
	_aimray_end_first = aimray_end_first
	_aimray_third     = aimray_third
	_aimray_end_third = aimray_end_third


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
	auto_switch:     bool = true
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
			_handle_raycast_impact(ray.get_collider(), target_pos, data)
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
func _handle_raycast_impact(collider: Node, _hit_point: Vector3, data: WeaponData) -> void:
	if collider == null:
		return
	if collider.is_in_group("enemy") and collider.has_method("enemy_hit"):
		var override_crit_rate: float = -1.0
		var override_crit_mult: float = -1.0
		if _player and _player.get("playerStats"):
			var s = _player.playerStats
			if s:
				override_crit_rate = s.current_critical_rate
				override_crit_mult = s.current_critical_damage
		var result := data.calculate_damage(override_crit_rate, override_crit_mult)
		var attack := AttackData.create_weapon_attack(data, _player)
		attack.base_damage = result[0]
		collider.enemy_hit(attack)
		enemy_hit.emit()
	if collider.is_in_group("moveObject") and collider is RigidBody3D:
		var push_dir := -_aimray_first.global_transform.basis.z.normalized()
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
	var cam := get_parent() as Camera3D
	return cam != null and not cam.is_current()

func _emit_current_ammo() -> void:
	var data := _get_current_data()
	if data != null:
		ammo_changed.emit(data.Current_Ammo, data.Reserve_Ammo)
