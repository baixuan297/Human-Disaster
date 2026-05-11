## AttackData — 武器 / 技能 / 场景伤害统一攻击事件
##
## - `base_damage`：工厂方法根据来源（WeaponData / SkillResource / Hazard）写入的原始伤害。
## - `final_damage`：目标侧 `Stats.take_damage` 实际读取的值；工厂方法保证初始化时 `final_damage == base_damage`。
## - `apply_body_part_multiplier`：**仅** WEAPON 类型会根据部位倍率刷新 `final_damage`；
##   SKILL / HAZARD 不在此处动 `final_damage`，以避免覆盖施法者做过的暴击/基因加成。
extends Resource
class_name AttackData

enum AttackType {
	WEAPON,   # 武器攻击
	SKILL,    # 技能攻击
	HAZARD,   # 场景伤害（毒池、岩浆等）
}

@export var source: AttackType          # 攻击来源类型
var source_node: Node                   # 攻击发起者（用于追踪）

## 伤害数据
@export var base_damage: float = 0.0           # 基础伤害（技能/武器原始值）
@export var final_damage: float = 0.0          # 最终伤害（计算后的实际伤害）
@export var body_part_multiplier: float = 1.0  # 部位倍率

## 关联数据（用于伤害计算追溯）
@export var weapon_data: WeaponData = null
@export var skill_data: SkillResource = null

## 额外属性
var is_critical: bool = false           # 是否暴击
var element_type: int = -1              # 元素类型（如果需要）
var knockback_force: float = 0.0        # 击退力度
## 场景伤害子类型（对应 Hazard.HazardType：火/毒/荆棘等）
var hazard_sub_type: int = -1

const HAZARD_TYPE_NAMES: Array[String] = ["火", "毒", "荆棘", "其他"]

## 获取场景伤害子类型名称（用于日志/UI）
func get_hazard_type_name() -> String:
	if hazard_sub_type < 0 or hazard_sub_type >= HAZARD_TYPE_NAMES.size():
		return "未知"
	return HAZARD_TYPE_NAMES[hazard_sub_type]


## 工厂方法：由 WeaponManager（射线命中）或 Bullet（弹体命中）调用，构造武器伤害数据
static func create_weapon_attack(weapon: WeaponData, attacker: Node = null) -> AttackData:
	var attack := AttackData.new()
	attack.source = AttackType.WEAPON
	attack.source_node = attacker
	attack.weapon_data = weapon
	attack.base_damage = weapon.Current_damage if weapon else 0
	## 武器：final_damage 由命中 **EnemyBodyPart.apply_body_part_multiplier** 写入（与技能工厂不同）
	return attack


## 创建场景伤害数据（毒池、岩浆等 hazard）
## hazard_type 对应 Hazard.HazardType（FIRE/POISON/THORNS/OTHER），-1 表示未指定
static func create_hazard_attack(damage: float, hazard_node: Node = null, hazard_type: int = -1) -> AttackData:
	var attack := AttackData.new()
	attack.source = AttackType.HAZARD
	attack.source_node = hazard_node
	attack.base_damage = damage
	attack.final_damage = damage
	attack.body_part_multiplier = 1.0
	attack.hazard_sub_type = hazard_type
	return attack


## 创建技能攻击数据
static func create_skill_attack(skill: SkillResource, skill_level: int, attacker: Node = null) -> AttackData:
	var attack := AttackData.new()
	attack.source = AttackType.SKILL
	attack.source_node = attacker
	attack.skill_data = skill
	attack.base_damage = skill.get_damage(skill_level) if skill else 0.0
	## Stats.take_damage 只读 final_damage；投射物/AOE 等常不经部位倍率直接 apply_attack_data，此处必须与 base 同步。
	## 命中部位时 apply_body_part_multiplier 仍会按 SKILL 分支把 final_damage 写回 base_damage。
	attack.final_damage = attack.base_damage
	return attack


## 伤害计算辅助方法
## 应用部位倍率（在命中检测后调用）
##
## 注意：仅 WEAPON 根据部位倍率刷新 final_damage；SKILL / HAZARD 保留施法方已经算好的 final_damage
## （例如暴击加成、基因系数）。部位倍率对技能/场景伤害没有作用时应留空，避免覆盖。
func apply_body_part_multiplier(multiplier: float) -> void:
	body_part_multiplier = multiplier
	if source == AttackType.WEAPON:
		final_damage = base_damage * body_part_multiplier

## 调试信息
func get_debug_info() -> String:
	return "AttackData | Type: %s | Base: %.1f | Final: %.1f | Multiplier: %.2fx" % [
		AttackType.keys()[source],
		base_damage,
		final_damage,
		body_part_multiplier
	]
