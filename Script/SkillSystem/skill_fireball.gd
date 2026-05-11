## 火球投射物效果 — 由 Skill.gd 以 `setup(resource, level, caster, duration)` 激活。
extends Node3D

@export var speed: float = 15.0

## 技能配置（由 Skill.gd 传入）
var skill_resource: SkillResource
var skill_level: int = 1
var caster: Node = null
var lifetime: float = 5.0
## 方向和目标
var direction: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO


## 统一 setup 签名；duration<=0 时使用内置默认生命周期（5 秒）
func setup(data: SkillResource, level: int = 1, _caster: Node = null, duration: float = 0.0) -> void:
	skill_resource = data
	skill_level = level
	caster = _caster
	if duration > 0.0:
		lifetime = duration

func set_target(target: Vector3):
	target_pos = target
	# 方向计算
	direction = (target_pos - global_position).normalized()

	# 确认方向
	look_at(target_pos, Vector3.UP)
	rotate_y(deg_to_rad(90))

	set_process(true)
	

func _process(delta: float):
	if direction == Vector3.ZERO:
		return
	global_position += direction * speed * delta

func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)


func _on_lifetime_expired() -> void:
	queue_free()


func _on_hit_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("enemy"):
		return
	_hit_target(body)


func _on_hit_area_area_entered(area: Area3D) -> void:
	if not area.is_in_group("enemy"):
		return
	_hit_target(area)


func _hit_target(target: Node3D) -> void:
	## create_skill_attack 已同步 final_damage；Skill.dispatch_attack 统一 apply_attack_data / take_damage / enemy_hit 路由。
	var attack := AttackData.create_skill_attack(skill_resource, skill_level, caster)
	Skill.dispatch_attack(target, attack)
	queue_free()
