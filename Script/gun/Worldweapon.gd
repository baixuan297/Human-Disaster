#extends Node3D
#
#@export var data: WeaponData
#var can_fire: bool = true
#
#func attack(_owner) -> void:
	#if not can_fire:
		#return
	#can_fire = false
#
	##fire_projectile(_owner)
#
	#await get_tree().create_timer(data.fire_rate).timeout
	#can_fire = true

extends RigidBody3D
class_name WorldWeapon

## ═══════════════════════════════════════════════════════════════
## WorldWeapon — 场景中可捡拾的武器实体（与 WeaponManager 解耦）
##
## 【解耦要点：数据与场景分离】
##   - WeaponData.tres 只存数值（弹药、伤害、射速等），不引用任何 .tscn。
##   - 场景引用由本节点持有：weapon_scene / viewmodel_scene / model_scene，
##     避免 .tres 引用 .tscn 造成的循环依赖与加载顺序问题。
##
## 【调用链】Player 射线检测 "weapon_pickup" 分组 → collider.pickup(weapon_manager)
##           → equip_weapon(data.duplicate(), weapon_scene, viewmodel_scene)
##           → 本节点 queue_free()，武器逻辑转入 WeaponManager 槽位。
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

# ──── 行为选项 ────
## 生成时是否重置为满弹
@export var reset_ammo_on_spawn:   bool = true
## 捡起后是否立刻切换到此武器  
@export var auto_switch_on_pickup: bool = true

# ──── 展示效果（悬浮旋转）────
@export var rotation_speed:   float = 1.2
@export var float_amplitude:  float = 0.08
@export var float_frequency:  float = 1.5

var _float_timer:   float = 0.0
var _origin_y:      float = 0.0
var _is_picking_up: bool  = false


func _ready() -> void:
	add_to_group("weapon_pickup")

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

	_origin_y = global_position.y
	freeze    = true


func _process(delta: float) -> void:
	if _is_picking_up:
		return
	_float_timer += delta
	if float_amplitude > 0.0:
		global_position.y = _origin_y + sin(_float_timer * float_frequency) * float_amplitude
	if rotation_speed > 0.0:
		rotate_y(rotation_speed * delta)


# ═══════════════════════════════════════════════════════════════
#  公开 API（仅由 Player 交互射线检测后调用）
# ═══════════════════════════════════════════════════════════════

## 捡起武器：将数据副本与场景引用交给 WeaponManager，本节点随后销毁。
## 使用 duplicate() 保证玩家之间的弹药状态互不影响（若多人或存档读档）。
func pickup(weapon_manager: WeaponManager) -> void:
	if _is_picking_up or weapon_data == null:
		return

	_is_picking_up = true
	picked_up.emit(weapon_data)

	weapon_manager.equip_weapon(
		weapon_data.duplicate(),
		weapon_scene,
		viewmodel_scene,
		auto_switch_on_pickup
	)

	queue_free()
