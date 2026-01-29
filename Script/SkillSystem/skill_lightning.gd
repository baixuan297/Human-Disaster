extends Node3D

## 技能配置
var skill_resource: SkillResource
var skill_level: int = 1
var caster: Node = null

var duration: float = 3.0
var tick_interval: float = 0.25    # 伤害触发间隔
var timer: float = 0.0
var tick_timer: float = 0.0

# 记录当前在 AOE 范围内的敌人
var targets_in_range: Array[Node3D] = []

func _ready() -> void:
	# 设置初始生存定时器
	get_tree().create_timer(duration).timeout.connect(func(): queue_free())

## 初始化数据（由 Skill 脚本调用）
func setup(data: SkillResource, level: int, _caster: Node, _duration: float = 3.0) -> void:
	skill_resource = data
	skill_level = level
	caster = _caster
	duration = _duration

func _process(delta: float) -> void:
	tick_timer += delta
	
	# 周期性造成伤害
	if tick_timer >= tick_interval:
		_apply_tick_damage()
		tick_timer = 0.0

## 核心伤害逻辑
func _apply_tick_damage() -> void:
	if targets_in_range.is_empty():
		return
		
	for target in targets_in_range:
		# 确保目标依然有效（没被销毁）且有受伤方法
		if is_instance_valid(target) and target.has_method("enemy_hit"):
			var attack = AttackData.create_skill_attack(skill_resource, skill_level, caster)
			
			# 如果你希望持续伤害是总伤害的一部分，可以在这里调整
			# attack.base_damage *= 0.5 
			
			target.enemy_hit(attack)
			
	# 可以在这里播放“雷击”视觉抖动或声音
	# print("⚡ 闪电轰击中... 目标数量: ", targets_in_range.size())

func _on_hit_area_area_entered(area: Area3D) -> void:
	if area.is_in_group("enemy") and not targets_in_range.has(area):
		targets_in_range.append(area)
