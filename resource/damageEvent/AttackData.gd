#extends Resource
#class_name AttackData
#
#enum AttackType {
	#WEAPON,
	#SKILL,
#}
#
#@export var damage: float
#@export var source: AttackType
## 攻击发起者
#var source_node: Node
#
#@export var weapon_data: WeaponData = null
#@export var skill_data: SkillResource = null
#
#var body_part_multiplier: float = 1.0

extends Resource
class_name AttackData

enum AttackType {
	WEAPON,   # 武器攻击
	SKILL,    # 技能攻击
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


## 工厂方法：由 WeaponManager（射线命中）或 Bullet（弹体命中）调用，构造武器伤害数据
static func create_weapon_attack(weapon: WeaponData, attacker: Node = null) -> AttackData:
	var attack := AttackData.new()
	attack.source = AttackType.WEAPON
	attack.source_node = attacker
	attack.weapon_data = weapon
	attack.base_damage = weapon.Current_damage if weapon else 0
	# 注意：final_damage 需要在应用部位倍率后设置
	return attack


## 创建技能攻击数据
static func create_skill_attack(skill: SkillResource, skill_level: int, attacker: Node = null) -> AttackData:
	var attack := AttackData.new()
	attack.source = AttackType.SKILL
	attack.source_node = attacker
	attack.skill_data = skill
	attack.base_damage = skill.get_damage(skill_level) if skill else 0.0
	# 注意：final_damage 需要在应用部位倍率后设置
	return attack


## 伤害计算辅助方法
## 应用部位倍率（在命中检测后调用）
func apply_body_part_multiplier(multiplier: float) -> void:
	body_part_multiplier = multiplier
	
	# 根据攻击类型决定是否应用倍率
	match source:
		AttackType.WEAPON:
			# 武器攻击受部位倍率影响
			final_damage = base_damage * body_part_multiplier
		AttackType.SKILL:
			# 技能攻击不受部位倍率影响（根据您的设计）
			final_damage = base_damage
			# 如果技能也需要部位倍率，改为：
			# final_damage = base_damage * body_part_multiplier

## 调试信息
func get_debug_info() -> String:
	return "AttackData | Type: %s | Base: %.1f | Final: %.1f | Multiplier: %.2fx" % [
		AttackType.keys()[source],
		base_damage,
		final_damage,
		body_part_multiplier
	]
