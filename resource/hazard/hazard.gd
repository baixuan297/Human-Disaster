extends Resource
class_name Hazard

## 环境伤害类型
enum HazardType {
	FIRE,    # 火（岩浆等）
	POISON,  # 毒（毒池等）
	THORNS,  # 荆棘
	OTHER,   # 其他（待开发）
}

## 环境伤害资源：毒池、岩浆等可复用此资源配置伤害参数。
## 使用方式：在场景中 @export var hazard_data: Hazard，或创建 .tres 资源后注入。

## 伤害类型
@export var hazard_type: HazardType = HazardType.POISON
## 每次 tick 造成的伤害
@export var damage: float = 10.0
## 伤害间隔（秒）
@export var tick_interval: float = 0.5

func create_attack_data(hazard_node: Node = null) -> AttackData:
	return AttackData.create_hazard_attack(damage, hazard_node, int(hazard_type))
