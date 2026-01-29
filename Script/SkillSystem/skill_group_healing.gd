extends Node3D

var skill_resource: SkillResource
var skill_level: int = 1
var caster: Node = null

var duration: float = 5.0
var tick_interval: float = 1.0 # 每秒触发一次
var tick_timer: float = 0.0

# 记录当前在范围内的合法目标
var allies_in_range: Array[Node3D] = []

func setup(data: SkillResource, level: int, _caster: Node, _duration: float) -> void:
	skill_resource = data
	skill_level = level
	caster = _caster
	duration = _duration

func _ready() -> void:
	# 到期自动销毁
	get_tree().create_timer(duration).timeout.connect(queue_free)

func _process(delta: float) -> void:
	tick_timer += delta
	if tick_timer >= tick_interval:
		_apply_buff_tick()
		tick_timer = 0.0

func _apply_buff_tick() -> void:
	# 清理无效引用
	allies_in_range = allies_in_range.filter(func(node): return is_instance_valid(node))
	
	for target in allies_in_range:
		# 这里调用目标身上的回复/Buff方法
		if target.has_method("apply_healing"):
			var amount = skill_resource.base_damage * skill_level 
			target.apply_healing(amount) # , caster 这个可以作为如果角色身上有增益buff可以加回血效果
		
		# 或者直接复用你的 apply_buff
		elif target.has_method("apply_buff"):
			target.apply_buff(skill_resource, skill_level, caster)



func _on_area_3d_body_entered(body: Node3D) -> void:
	# 判断是否为玩家或友军组
	if body.is_in_group("Player") or body.is_in_group("friendly"):
		if not allies_in_range.has(body):
			allies_in_range.append(body)
