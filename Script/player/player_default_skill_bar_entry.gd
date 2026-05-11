extends Resource
class_name PlayerDefaultSkillBarEntry

## 本地 SkillResource（效果、图标、运行时 skill_name）
@export var skill_resource: SkillResource
## 快捷栏槽位，小于 0 表示仅学会不上栏
@export var skill_bar_slot: int = -1
## 为 true 时该槽释放使用玩家位置作为目标参考（如自身脚下治疗）
@export var use_caster_position_as_target: bool = false
