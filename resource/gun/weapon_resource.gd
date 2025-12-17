extends Resource
class_name WeaponData

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

## 武器名字
@export var Weapon_name : String
## 子弹场景
@export var projectile_scene: PackedScene
## 武器稀有度
@export var rarity: Rarity = Rarity.COMMON
## 武器世界模型
@export var model_scene: PackedScene     

## 当前弹药
@export var Current_Ammo : int
## 储备弹药
@export var Reserve_Ammo : int
## 弹匣容量
@export var magazine : int
## 弹药最大数量
@export var Max_Ammo : int
## 自动开火
@export var Auto_Fire : bool

## 伤害
@export var Base_damage: int = 40
@export var Current_damage: int = 40
## 暴击率
@export var crit_rate: float = 0.1          
## 暴击伤害
@export var crit_multiplier: float = 1.5    
## 武器伤害类型
@export var element: ElementTyper = ElementTyper.PHYSICAL
## 射速
@export var fire_rate: float = 0.3


# TODO:
# 装填类型: 弹匣换弹, 边打边填充, 蓄能, 无限弹药
# 瞄准类型 手动瞄准 锁定瞄准

func _init() -> void:
	setup_weapon.call_deferred()
	
func setup_weapon():
	Current_damage = Base_damage
