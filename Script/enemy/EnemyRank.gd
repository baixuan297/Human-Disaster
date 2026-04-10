extends RefCounted
class_name EnemyRank

## 与后端 `extra_data.enemy_rank` / `EnemyDefResponse.enemy_rank` 对齐的阶层乘子（数据驱动可后续迁到 JSON）

enum Rank { NORMAL, SPECIAL, ELITE, BOSS }


static func normalize_key(s: String) -> String:
	return str(s).strip_edges().to_upper()


static func from_string(s: String) -> Rank:
	match normalize_key(s):
		"SPECIAL", "SPECIAL_ENEMY":
			return Rank.SPECIAL
		"ELITE":
			return Rank.ELITE
		"BOSS", "MINI_BOSS":
			return Rank.BOSS
		_:
			return Rank.NORMAL


## 返回 hp / atk / def / exp 相对 NORMAL 的倍率
## BOSS 默认 ×1：策划已在 base_hp/base_atk 拉满；高层机制由 boss_phases、skills、behavior_tree 承担，避免与 JSON 数值双重放大
static func get_stat_multipliers(rank_key: String) -> Dictionary:
	match from_string(rank_key):
		Rank.SPECIAL:
			return {"hp": 1.2, "atk": 1.1, "def": 1.08, "exp": 1.15}
		Rank.ELITE:
			return {"hp": 1.45, "atk": 1.22, "def": 1.12, "exp": 1.4}
		Rank.BOSS:
			return {"hp": 1.0, "atk": 1.0, "def": 1.0, "exp": 1.0}
		_:
			return {"hp": 1.0, "atk": 1.0, "def": 1.0, "exp": 1.0}
