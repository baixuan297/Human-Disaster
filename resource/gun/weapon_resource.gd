## TODO:
## 装填类型: 弹匣换弹, 边打边填充, 蓄能, 无限弹药
## 瞄准类型 手动瞄准 锁定瞄准


extends Resource
class_name WeaponData

## ═══════════════════════════════════════════════════════════════
## WeaponData — 武器纯数据资源（不引用任何 .tscn，避免循环依赖）
##
## 【使用方】WorldWeapon 引用 .tres；捡起时 duplicate() 传给 WeaponManager。
##          BaseWeapon / Bullet 使用注入的 data 做伤害与弹道。
## 【注意】场景引用（weapon_scene / viewmodel_scene）放在 WorldWeapon 上，不放在本资源中。
## ═══════════════════════════════════════════════════════════════

enum ElementTyper {
	PHYSICAL,
	LASER,
	DARK_MATTER,
	BIOLOGY,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

## 武器槽位类型（决定捡起后放入哪个槽）
enum WeaponSlot {
	PRIMARY,    ## 主武器槽（步枪、冲锋枪等）
	SECONDARY,  ## 副武器槽（手枪等）
}

# ──── 基础信息 ────

## 武器名字（用作字典 key，请保持唯一且不含空格）
@export var Weapon_name: String

## 武器稀有度（影响掉落权重和显示颜色）
@export var rarity: Rarity = Rarity.COMMON

## 武器槽位类型
@export var weapon_slot: WeaponSlot = WeaponSlot.PRIMARY

# ──── 场景引用 ────
## 子弹 / 弹道效果场景（继承 Bullet 或自定义弹道）
@export var projectile_scene: PackedScene

# ──── 弹药 ────

## 当前弹匣弹药
@export var Current_Ammo: int

## 储备弹药
@export var Reserve_Ammo: int

## 弹匣容量
@export var magazine: int

## 储备弹药上限
@export var Max_Ammo: int

## 是否自动连射（false = 半自动单发；true = 全自动）
@export var Auto_Fire: bool

# ──── 伤害 ────

## 基础伤害（不随等级/强化变化，用于重置）
@export var Base_damage: int = 40

## 当前实际伤害（可被强化 Buff 修改）
@export var Current_damage: int = 40

## 暴击率（0.0 ~ 1.0）
@export var crit_rate: float = 0.1

## 暴击伤害倍率（1.5 = 暴击造成 150% 伤害）
@export var crit_multiplier: float = 1.5

## 武器元素伤害类型
@export var element: ElementTyper = ElementTyper.PHYSICAL

# ──── 射击参数 ────

## 射速 — 两次射击之间的最小间隔（秒）
@export var fire_rate: float = 0.3

## 换弹时间（秒）— 应与 viewmodel 的 reload 动画时长一致
@export var reload_time: float = 1.5

## 武器音频数据
@export var audio_data: WeaponAudioData

# ═══════════════════════════════════════════════════════════════
#  运行时初始化
# ═══════════════════════════════════════════════════════════════

func _init() -> void:
	# 用 call_deferred 保证资源属性已全部加载完毕后再执行
	setup_weapon.call_deferred()


func setup_weapon() -> void:
	Current_damage = Base_damage


# ═══════════════════════════════════════════════════════════════
#  工具函数
# ═══════════════════════════════════════════════════════════════

## 计算本次伤害（含暴击判定）
## override_crit_rate: 外部暴击率覆盖（>=0 时使用，否则用武器自身 crit_rate）
## override_crit_mult: 外部暴击倍率覆盖（>=0 时使用，否则用武器自身 crit_multiplier）
## 返回 [final_damage: int, is_crit: bool]
func calculate_damage(override_crit_rate: float = -1.0, override_crit_mult: float = -1.0) -> Array:
	var effective_crit_rate := override_crit_rate if override_crit_rate >= 0.0 else crit_rate
	var effective_crit_mult := override_crit_mult if override_crit_mult >= 0.0 else crit_multiplier
	var is_crit := randf() < effective_crit_rate
	var dmg := int(Current_damage * (effective_crit_mult if is_crit else 1.0))
	return [dmg, is_crit]


## 是否还可以换弹（弹匣未满 且 有储备弹药）
func can_reload() -> bool:
	return Reserve_Ammo > 0 and Current_Ammo < magazine


## 弹匣是否耗尽
func is_empty() -> bool:
	return Current_Ammo <= 0


## 执行换弹计算（直接修改本资源数据，返回实际换弹数量）
func do_reload() -> int:
	var count := mini(magazine - Current_Ammo, Reserve_Ammo)
	Current_Ammo  += count
	Reserve_Ammo  -= count
	return count
