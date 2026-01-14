extends Resource
class_name AttackData

enum AttackType {
	WEAPON,
	SKILL,
}

@export var damage: float
@export var source: AttackType
# 攻击发起者
var source_node: Node

@export var weapon_data: WeaponData = null
@export var skill_data: SkillResource = null

var body_part_multiplier: float = 1.0
