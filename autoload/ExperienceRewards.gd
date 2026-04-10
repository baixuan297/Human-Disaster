extends Node

## 经验奖励统一入口：任务 / 探索 / 活动 / 击杀等均经此调用，便于按来源扩展倍率或埋点。
## 实际数值仍由 `Stats.gain_experience` / 门闸封顶处理。


func grant(stats: Stats, amount: float, source_key: String, context: Dictionary = {}) -> float:
	if stats == null or amount <= 0.0:
		return 0.0
	return stats.grant_experience_from_source_ctx(amount, source_key, context)
