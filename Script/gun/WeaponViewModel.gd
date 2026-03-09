extends Node3D
class_name WeaponViewModel

## ═══════════════════════════════════════════════════════════════
## WeaponViewModel — 第一人称武器视图模型基类
##
## 【职责】仅负责：枪身晃动、开火/换弹/拔枪动画、提供 muzzle 世界坐标。
##         不参与射击逻辑与弹药计算，由 WeaponManager 统一调度。
##
## 【契约：节点与动画名】
##   子类场景必须包含（路径可在子类中重写 @onready）：
##     - 名为 "rig" 的 Node3D（晃动骨架）
##     - rig 下 AnimationPlayer，且包含动画: "fire" / "reload" / "raise"
##     - 用于子弹起点的 Marker3D（本基类默认 $rig/gun/pistol/Muzzle；
##       其他武器可重写 get_muzzle_global_position() 或 _muzzle 路径）
##
## 【场景树示例】
##   WeaponViewModel (Camera3D)  ← 根节点，每帧与主相机 global_transform 同步
##   └── rig (Node3D)
##       └── gun
##           ├── AnimationPlayer
##           ├── Muzzle (Marker3D)
##           └── pistol (或 mp7 等)  ← 若 Muzzle 在更深层，子类重写 _muzzle 路径
## ═══════════════════════════════════════════════════════════════

const SWAY_SENSITIVITY: float = 0.00005
const SWAY_RETURN_SPEED: float = 10.0

# ──── 节点引用（子类若结构不同可重写 get_muzzle_global_position）────
@onready var gunrig: Node3D = $rig
@onready var _anim: AnimationPlayer = $rig/gun/AnimationPlayer
## 子弹生成点；手枪为 pistol/Muzzle，其他武器可在子类中改为对应路径
@onready var _muzzle: Marker3D = $rig/gun/Muzzle


func _ready() -> void:
	if _anim != null:
		_anim.animation_finished.connect(_on_animation_finished)


func _on_animation_finished(anim_name: StringName) -> void:
	# fire 动画结束后重置根节点位移，避免相机留在后坐力位置导致“射击后消失”（旋转由 WeaponManager 与主相机同步）
	if anim_name == &"fire":
		position = Vector3.ZERO


func _process(delta: float) -> void:
	gunrig.position = Vector3(
		lerp(gunrig.position.x, 0.0, delta * SWAY_RETURN_SPEED),
		lerp(gunrig.position.y, 0.0, delta * SWAY_RETURN_SPEED),
		lerp(gunrig.position.z, 0.0, delta * SWAY_RETURN_SPEED)
	)


# ═══════════════════════════════════════════════════════════════
#  公开 API：晃动（由 WeaponManager.apply_sway 转发 Player 鼠标位移）
# ═══════════════════════════════════════════════════════════════

func sway(sway_amount: Vector2) -> void:
	gunrig.position.x += sway_amount.x * SWAY_SENSITIVITY
	gunrig.position.y += sway_amount.y * SWAY_SENSITIVITY
	gunrig.position.z += sway_amount.y * SWAY_SENSITIVITY


# ═══════════════════════════════════════════════════════════════
#  公开 API：动画（由 WeaponManager 在射击/换弹/切换时调用）
# ═══════════════════════════════════════════════════════════════

func play_fire() -> void:
	if _anim == null or is_reloading():
		return
	#_anim.stop()
	_anim.play("fire")

## 返回动画时长，供 WeaponManager 做 await 换弹等待
func play_reload() -> float:
	if _anim == null:
		return 1.5
	_anim.stop()
	_anim.play("reload")
	return _anim.get_animation("reload").length if _anim.has_animation("reload") else 1.5

func play_raise() -> float:
	if _anim == null:
		return 0.4
	_anim.stop()
	_anim.play("raise")
	return _anim.get_animation("raise").length if _anim.has_animation("raise") else 0.4

func play_lower() -> float:
	if _anim == null:
		return 0.4
	_anim.stop()
	_anim.play_backwards("raise")
	return _anim.get_animation("raise").length if _anim.has_animation("raise") else 0.4


# ═══════════════════════════════════════════════════════════════
#  公开 API：状态查询（WeaponManager 用于防止换弹中开火等）
# ═══════════════════════════════════════════════════════════════

func is_reloading() -> bool:
	return _anim != null and _anim.is_playing() and _anim.current_animation == "reload"

func is_firing() -> bool:
	return _anim != null and _anim.is_playing() and _anim.current_animation == "fire"

## 子弹生成的世界坐标；子类若 Muzzle 路径不同可重写此方法
func get_muzzle_global_position() -> Vector3:
	if _muzzle != null:
		return _muzzle.global_position
	return gunrig.global_position
