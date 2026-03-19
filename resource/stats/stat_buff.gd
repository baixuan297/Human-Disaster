extends Resource
class_name StatBuff

## StatBuff — 属性增益/减益描述符
##
## 使用方式：
##   var buff = StatBuff.new(Stats.BuffableStats.ATTACK, 20.0, StatBuff.BuffType.Add)
##   stats.add_buff(buff)
##
## 临时 Buff（自动到期）：
##   stats.add_temporary_buff(buff, 5.0)  # 5 秒后自动移除


enum BuffType {
	Add,       ## 叠加：current_stat += buff_amount
	Multiply,  ## 乘算：current_stat *= (1 + buff_amount)，正数增益负数减益
}

## 作用的属性
@export var stat:        Stats.BuffableStats
## 增益量（Add 模式为绝对值；Multiply 模式为倍率，0.5 = +50%，-0.3 = -30%）
@export var buff_amount: float
## 增益类型
@export var buff_type:   BuffType

## 来源节点（可选，用于追踪）
var source_node: Node = null

## ── Bug 修复 ──────────────────────────────────────────────────────────────────
## 原 L17-18：buff_amount = buff_amount / buff_type = buff_type（自赋值，值永远是默认值）
## 修复：_参数名 → 字段名
## ─────────────────────────────────────────────────────────────────────────────
func _init(
	_stat:        Stats.BuffableStats = Stats.BuffableStats.MAX_HEALTH,
	_buff_amount: float               = 0.0,
	_buff_type:   BuffType            = BuffType.Add
) -> void:
	stat        = _stat
	buff_amount = _buff_amount  ## 修复点
	buff_type   = _buff_type    ## 修复点


## 快速构造：叠加型（常用）
static func make_add(stat_type: Stats.BuffableStats, amount: float) -> StatBuff:
	return StatBuff.new(stat_type, amount, BuffType.Add)


## 快速构造：乘算型（百分比增益/减益）
static func make_multiply(stat_type: Stats.BuffableStats, multiplier: float) -> StatBuff:
	return StatBuff.new(stat_type, multiplier, BuffType.Multiply)


func get_debug_info() -> String:
	var type_str := "Add" if buff_type == BuffType.Add else "Multiply"
	return "StatBuff[%s] %s %.2f" % [Stats.BuffableStats.keys()[stat], type_str, buff_amount]
