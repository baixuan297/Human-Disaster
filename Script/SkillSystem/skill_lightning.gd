extends Node3D

## 技能配置
var skill_resource: SkillResource
var skill_level: int = 1
var caster: Node = null

var duration: float = 3.0
## 伤害与音效触发间隔（秒）
var tick_interval: float = 0.25
var tick_timer: float = 0.0

var targets_in_range: Array[Node3D] = []

func _ready() -> void:
	get_tree().create_timer(duration).timeout.connect(func(): queue_free())

## 统一 setup 签名；duration<=0 时保留默认值（3 秒），便于手动实例化调试
func setup(data: SkillResource, level: int, _caster: Node, _duration: float = 0.0) -> void:
	skill_resource = data
	skill_level = level
	caster = _caster
	if _duration > 0.0:
		duration = _duration

func _process(delta: float) -> void:
	tick_timer += delta
	if tick_timer >= tick_interval:
		_apply_tick_damage()
		tick_timer = 0.0


func _apply_tick_damage() -> void:
	_play_tick_sound()
	targets_in_range = targets_in_range.filter(func(n): return is_instance_valid(n))
	if targets_in_range.is_empty():
		return
	for target in targets_in_range:
		## 与 skill_fireball 相同：依赖 create_skill_attack 写入的 final_damage
		var attack := AttackData.create_skill_attack(skill_resource, skill_level, caster)
		Skill.dispatch_attack(target, attack)


func _on_hit_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemy") and not targets_in_range.has(body):
		targets_in_range.append(body)


func _on_hit_area_body_exited(body: Node3D) -> void:
	targets_in_range.erase(body)


func _play_tick_sound() -> void:
	if skill_resource == null or caster == null:
		return
	var stream: AudioStream = skill_resource.hit_sound if skill_resource.hit_sound != null else skill_resource.cast_sound
	if stream == null:
		return
	var audio_player := AudioStreamPlayer3D.new()
	audio_player.stream = stream
	add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
