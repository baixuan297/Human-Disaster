extends Resource
class_name StatBuff

enum BuffType {
	Multiply,
	Add,
	# TODO: 减益
}

@export var stat: Stats.BuffableStats
# 增益量
@export var buff_amount: float
@export var buff_type: BuffType

func _init(_stat: Stats.BuffableStats = Stats.BuffableStats.MAX_HEALTH, 
			_buff_amount: float = 1.0,
			_buff_type: StatBuff.BuffType = BuffType.Multiply) -> void:
	stat = _stat
	buff_amount = buff_amount
	buff_type = buff_type
