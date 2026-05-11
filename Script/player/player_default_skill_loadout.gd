extends Resource
class_name PlayerDefaultSkillLoadout

## 默认技能栏配置（测试或关卡内覆盖）；与 **SkillManager**、**Player._setup_skills** 配合使用。说明见 **docs/SKILL_SYSTEM.md**。
@export var entries: Array[PlayerDefaultSkillBarEntry] = []


static func create_test_loadout() -> PlayerDefaultSkillLoadout:
	var loadout := PlayerDefaultSkillLoadout.new()
	var fire := PlayerDefaultSkillBarEntry.new()
	fire.skill_resource = preload("res://resource/skill/Fireball.tres")
	fire.skill_bar_slot = 0
	fire.use_caster_position_as_target = false
	var bolt := PlayerDefaultSkillBarEntry.new()
	bolt.skill_resource = preload("res://resource/skill/Lightning.tres")
	bolt.skill_bar_slot = 1
	bolt.use_caster_position_as_target = false
	var heal := PlayerDefaultSkillBarEntry.new()
	heal.skill_resource = preload("res://resource/skill/GroupHealingSkill.tres")
	heal.skill_bar_slot = 2
	heal.use_caster_position_as_target = true
	loadout.entries = [fire, bolt, heal]
	return loadout


func get_use_caster_position_for_slot(slot: int) -> bool:
	for e in entries:
		if e != null and e.skill_bar_slot == slot:
			return e.use_caster_position_as_target
	return false
