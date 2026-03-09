extends Node3D
class_name BaseWeapon

## ═══════════════════════════════════════════════════════════════
## BaseWeapon — 武器逻辑节点基类（仅负责射速冷却与子弹生成）
##
## 【职责边界】不处理输入、不持有 viewmodel；由 WeaponManager 调用 attack(muzzle, target)。
## 【扩展点】子类可重写 _fire_projectile() 实现不同弹道（抛物线、激光等）。
##
## 【调用链】WeaponManager._do_shoot() → 取 muzzle/target → 本节点 attack()
##           → _fire_projectile() → 实例化 data.projectile_scene 并初始化。
## ═══════════════════════════════════════════════════════════════

## 武器数据（由 setup() 注入，不在编辑器中赋值）
@export var data: WeaponData

## 射速门控：开火后为 false，fire_rate 计时结束后恢复 true
var can_fire: bool = true

var _shooter:    Node3D = null  ## 发射者，用于 AttackData 与友伤判定
var _world_root: Node3D = null  ## 子弹父节点，避免子弹挂在武器下随相机移动


# ═══════════════════════════════════════════════════════════════
#  公开 API：初始化（仅由 WeaponManager.equip_weapon 调用）
# ═══════════════════════════════════════════════════════════════

## 装备时注入：数据副本、玩家节点、子弹挂载父节点。
func setup(weapon_data: WeaponData, shooter: Node3D, world_root: Node3D) -> void:
	data        = weapon_data
	_shooter    = shooter
	_world_root = world_root


# ═══════════════════════════════════════════════════════════════
#  公开 API：攻击（仅由 WeaponManager._do_shoot 调用）
#
#  muzzle_pos / target_pos 由 WeaponManager 根据射线与 viewmodel 计算得到。
# ═══════════════════════════════════════════════════════════════

func attack(muzzle_pos: Vector3, target_pos: Vector3) -> void:
	if not can_fire:
		return
	if data == null:
		push_error("BaseWeapon [%s]: data 为 null" % name)
		return
	if data.is_empty():
		return

	can_fire = false
	_fire_projectile(muzzle_pos, target_pos)

	await get_tree().create_timer(data.fire_rate).timeout
	can_fire = true


# ═══════════════════════════════════════════════════════════════
#  内部：子弹生成（子类可重写以实现不同弹道类型）
# ═══════════════════════════════════════════════════════════════

## 实例化 data.projectile_scene，挂到 _world_root，并调用子弹的初始化接口。
## 优先使用 init_with_data(target, weapon_data, shooter)，否则回退到 set_velocity(target)。
func _fire_projectile(muzzle_pos: Vector3, target_pos: Vector3) -> void:
	if data.projectile_scene == null:
		push_warning("BaseWeapon [%s]: projectile_scene 未设置" % data.Weapon_name)
		return
	if _world_root == null:
		push_error("BaseWeapon [%s]: _world_root 未注入" % name)
		return

	var proj: Node3D = data.projectile_scene.instantiate()
	_world_root.add_child(proj)
	proj.global_position = muzzle_pos

	if proj.has_method("init_with_data"):
		proj.init_with_data(target_pos, data, _shooter)
	elif proj.has_method("set_velocity"):
		proj.set_velocity(target_pos)
