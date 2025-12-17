## 技能资源类 - 定义技能的基础属性和成长曲线
class_name SkillResource
extends Resource

## 基础属性
@export var skill_name: String = "UNAMED"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_level: int = 10

## 基础数值（等级1时的值）
@export_group("基础属性")
@export var base_damage: float = 100.0
@export var base_attack_power: float = 50.0
@export var base_cooldown: float = 5.0
@export var base_range: float = 10.0
@export var base_duration: float = 0.0  # 持续时间（DOT技能用）

## 成长曲线 - 使用Curve来定义属性随等级的变化
# 伤害成长曲线
var damage_curve: Curve = preload("uid://dhrfo4kt856rm")
# 攻击力成长曲线
var attack_power_curve: Curve = preload("uid://c0ar6aktm63xs")
# 冷却时间曲线
var cooldown_curve: Curve = preload("uid://c66dwanolmcsw")
# 范围成长曲线
var range_curve: Curve = preload("uid://bwlmeqdei8i1l")
# 持续时间成长曲线
var duration_curve: Curve = preload("uid://br5sdwgii24u2")

## 技能类型
enum SkillType {
	# 瞬发技能
	INSTANT,
	# 投射物技能
	PROJECTILE,
	# 范围伤害
	AOE,
	# 持续伤害
	DOT,
	# 增益技能
	BUFF,
	# 减益技能
	DEBUFF,
}
@export var skill_type: SkillType = SkillType.INSTANT

## 特效资源
@export_group("特效")
## 施法特效
@export var cast_effect: PackedScene
## 命中特效
@export var hit_effect: PackedScene
## 施法音效
@export var cast_sound: AudioStream
## 命中音效
@export var hit_sound: AudioStream

# 在这里替代了stat中的current值 试试看会不会更加的简洁
## 根据等级获取技能属性
func get_damage(level: int) -> float:
	return _calculate_value(base_damage, damage_curve, level)

func get_attack_power(level: int) -> float:
	return _calculate_value(base_attack_power, attack_power_curve, level)

func get_cooldown(level: int) -> float:
	return _calculate_value(base_cooldown, cooldown_curve, level)

func get_range(level: int) -> float:
	return _calculate_value(base_range, range_curve, level)

func get_duration(level: int) -> float:
	return _calculate_value(base_duration, duration_curve, level)

## 计算具体数值的内部方法
func _calculate_value(base_value: float, curve: Curve, level: int) -> float:
	if curve == null:
		return base_value
	
	# 将等级归一化到0-1之间
	var normalized_level = (level - 1) / float(max_level - 1)
	# 使用曲线采样获取倍率
	var multiplier = curve.sample(normalized_level)
		
	return base_value * multiplier


## 获取技能的完整信息 用来调试
func get_skill_info(level: int) -> Dictionary:
	return {
		"name": skill_name,
		"description": description,
		"level": level,
		"damage": get_damage(level),
		"attack_power": get_attack_power(level),
		"cooldown": get_cooldown(level),
		"range": get_range(level),
		"duration": get_duration(level),
		"type": SkillType.keys()[skill_type]
	}
